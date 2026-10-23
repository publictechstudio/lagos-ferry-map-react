import type { Metadata } from "next";
import Link from "next/link";
import FaqList from "@/components/FaqList";
import { faqPageJsonLd } from "@/lib/faq";
import { getFaqs, type StoredFaq } from "@/lib/faqs";
import { REPORT_FORM_URL } from "@/lib/constants";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "Lagos Ferry FAQs: Routes, Fares, Timetables and Safety",
  description:
    "Answers to common questions about Lagos ferries: Ikorodu, Badore, Tarkwa Bay, Ilashe and Benin Republic boats, fares, timetables, water hyacinth season, safety and how to pay.",
  alternates: { canonical: "/faq" },
  openGraph: {
    title: "Lagos Ferry FAQs — Lagos Ferry Map",
    description:
      "Answers to common questions about Lagos ferries: routes, fares, timetables, water hyacinth season and safety.",
  },
};

/** Section order and headings for faqs.topic. Topics not listed here follow, titled from the slug. */
const TOPICS: Record<string, string> = {
  general: "Lagos ferries in general",
  ikorodu: "Ikorodu ferries",
  "badore-lekki": "Badore, Ajah and the Lekki axis",
  "tarkwa-bay": "Tarkwa Bay",
  "ojo-ilashe-badagry": "Ojo and Ilashe",
  "cross-border": "Boats to Benin Republic",
};

function topicHeading(topic: string): string {
  return (
    TOPICS[topic] ??
    topic.replace(/-/g, " ").replace(/^\w/, (c) => c.toUpperCase())
  );
}

function groupByTopic(faqs: StoredFaq[]): [string, StoredFaq[]][] {
  const groups = new Map<string, StoredFaq[]>();
  for (const faq of faqs) {
    if (!groups.has(faq.topic)) groups.set(faq.topic, []);
    groups.get(faq.topic)!.push(faq);
  }
  const order = Object.keys(TOPICS);
  const rank = (t: string) =>
    order.includes(t) ? order.indexOf(t) : order.length;
  return [...groups].sort(([a], [b]) => rank(a) - rank(b));
}

const linkClass = "text-primary underline underline-offset-2 hover:opacity-70";

export default async function FaqPage() {
  const faqs = await getFaqs();
  const groups = groupByTopic(faqs);
  const jsonLd = faqPageJsonLd(faqs);

  return (
    <>
      {jsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      )}
      <section className="max-w-4xl mx-auto px-4 py-16">
        <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-3">
          Lagos ferry questions and answers
        </h1>
        <p className="text-base leading-6 text-on-surface-variant mb-3">
          Answers to the questions people ask most about ferries in Lagos.
          Timetables and fares for every route are on the{" "}
          <Link href="/map" className={linkClass}>
            interactive map
          </Link>{" "}
          and in the{" "}
          <Link href="/directory" className={linkClass}>
            directory of terminals and routes
          </Link>
          .
        </p>
        <p className="text-base leading-6 text-on-surface-variant mb-8">
          Something wrong or missing?{" "}
          <a
            href={REPORT_FORM_URL}
            className={linkClass}
            target="_blank"
            rel="noopener noreferrer"
          >
            Let us know
          </a>
          .
        </p>

        {groups.length === 0 ? (
          <p className="text-base leading-6 text-on-surface-variant">
            No questions have been published yet.
          </p>
        ) : (
          <>
            {/* Jump links to each section */}
            <nav
              aria-label="FAQ sections"
              className="mb-10 flex flex-wrap gap-2"
            >
              {groups.map(([topic]) => (
                <a
                  key={topic}
                  href={`#${topic}`}
                  className="px-3 py-1 rounded-full bg-surface-variant text-on-surface-variant text-sm hover:text-primary transition-colors"
                >
                  {topicHeading(topic)}
                </a>
              ))}
            </nav>

            {groups.map(([topic, items]) => (
              <div key={topic} className="mb-12">
                <h2
                  id={topic}
                  className="text-xl font-medium text-on-surface mb-2 scroll-mt-20"
                >
                  {topicHeading(topic)}
                </h2>
                <FaqList faqs={items} variant="page" />
              </div>
            ))}
          </>
        )}
      </section>
    </>
  );
}
