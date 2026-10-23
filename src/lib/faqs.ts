import { sql } from "./db";
import { parseAnswer, type Faq } from "./faq";
import { toFacilitySlug } from "./facilitySlug";
import { toRouteSlug } from "./routeSlug";

export type StoredFaq = Faq & { topic: string; updatedAt: Date };

type FaqRow = {
  question: string;
  answer: string;
  topic: string;
  published: boolean;
  updated_at: Date;
};

/** Postgres error code for a missing table. */
const UNDEFINED_TABLE = "42P01";

/** Answers link to pages by id, e.g. [the Ikorodu ferry](route:8) or [Badore](facility:200). */
const PAGE_LINK = /\]\((route|facility):(\d+)\)/g;

/**
 * Swap route:/facility: links for the pages' current URLs, so answers never hold
 * slugs that go stale when a place is renamed. Links to archived or unknown pages
 * are left as they are, and parseAnswer then shows their text without a link.
 */
async function resolvePageLinks(answers: string[]): Promise<string[]> {
  const ids = { route: new Set<number>(), facility: new Set<number>() };
  for (const answer of answers) {
    for (const [, kind, id] of answer.matchAll(PAGE_LINK)) ids[kind as "route" | "facility"].add(Number(id));
  }
  if (ids.route.size === 0 && ids.facility.size === 0) return answers;

  const [routeRows, facilityRows] = await Promise.all([
    ids.route.size === 0
      ? []
      : sql<{ route_id: number; origin_name: string | null; destination_name: string | null }[]>`
          SELECT r.route_id, f1.facility_name AS origin_name, f2.facility_name AS destination_name
          FROM routes r
          LEFT JOIN facilities f1 ON f1.facility_id = r.origin
          LEFT JOIN facilities f2 ON f2.facility_id = r.destination
          WHERE r.route_id = ANY(${[...ids.route]}) AND NOT COALESCE(r.archived, FALSE)
        `,
    ids.facility.size === 0
      ? []
      : sql<{ facility_id: number; facility_name: string | null }[]>`
          SELECT facility_id, facility_name FROM facilities WHERE facility_id = ANY(${[...ids.facility]})
        `,
  ]);
  const hrefs = new Map<string, string>([
    ...routeRows.map((r) => [`route:${r.route_id}`, `/map/route/${toRouteSlug(r)}`] as const),
    ...facilityRows.map((f) => [`facility:${f.facility_id}`, `/map/${toFacilitySlug(f)}`] as const),
  ]);
  return answers.map((answer) =>
    answer.replace(PAGE_LINK, (link, kind, id) => {
      const href = hrefs.get(`${kind}:${id}`);
      return href ? `](${href})` : link;
    }),
  );
}

/**
 * Hand-written FAQs from the faqs table, shown on the /faq page. Only published rows,
 * except in development, where drafts are included (flagged) so they can be reviewed locally.
 */
export async function getFaqs(): Promise<StoredFaq[]> {
  const showDrafts = process.env.NODE_ENV === "development";
  try {
    const rows = await sql<FaqRow[]>`
      SELECT question, answer, topic, published, updated_at
      FROM faqs
      WHERE published OR ${showDrafts}
      ORDER BY topic, sort_order, faq_id
    `;
    const answers = await resolvePageLinks(rows.map((r) => r.answer));
    return rows.map((r, i) => ({
      question: r.question,
      answer: parseAnswer(answers[i]),
      topic: r.topic,
      updatedAt: r.updated_at,
      ...(!r.published && { draft: true }),
    }));
  } catch (err) {
    // The table comes from a DB migration; pages render without hand-written FAQs until it runs
    if ((err as { code?: string }).code === UNDEFINED_TABLE) {
      console.warn("faqs table not found; skipping hand-written FAQs");
      return [];
    }
    throw err;
  }
}
