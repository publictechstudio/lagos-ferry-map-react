import type { Route } from "@/types/route";
import type { RoutePeriod } from "@/types/routePeriod";
import type { RouteStop } from "@/types/routeStop";
import { toFacilitySlug } from "./facilitySlug";
import { formatMonthYear, formatNaira, formatTime } from "./format";
import { isPlannedOmiEkoRoute } from "./omiEko";
import { operatorInfo } from "./operators";
import { toRouteSlug } from "./routeSlug";

/** A piece of answer text: plain, a link to another page on the site, or the key fact in bold. */
export type FaqPart = string | { text: string; href: string } | { text: string; bold: true };
export type Faq = { question: string; answer: FaqPart[] };

/**
 * Questions and answers for a route page, built from its data. Each answer leads
 * with the direct answer and names both ends and the operator, so it still makes
 * sense when a search engine quotes it on its own. Client-safe (no DB import).
 */
export function buildRouteFaqs(
  route: Route,
  periods: RoutePeriod[],
  stops: RouteStop[],
  allRoutes: Route[],
): Faq[] {
  const siblings = allRoutes.filter(
    (r) => r.route_id !== route.route_id && !isPlannedOmiEkoRoute(r) && sameEnds(r, route),
  );

  if (isPlannedOmiEkoRoute(route)) return [plannedFaq(route, siblings, allRoutes)];

  return [
    durationFaq(route, stops, siblings),
    fareFaq(route, siblings),
    firstDepartureFaq(route, periods),
    weekendFaq(route, periods),
    disruptionsFaq(route),
  ].filter((f): f is Faq => f !== null);
}

/** The answer as plain text, for structured data. */
export function faqPlainText(faq: Faq): string {
  return faq.answer.map((p) => (typeof p === "string" ? p : p.text)).join("");
}

// ── Helpers ────────────────────────────────────────────────────────────────────

/** The direct answer (duration, fare, time, yes/no), shown in bold. */
const bold = (text: string): FaqPart => ({ text, bold: true });

const DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

type Days = boolean[]; // Monday..Sunday

function ends(route: Route) {
  return {
    o: route.origin_name_short ?? route.origin_name ?? "the origin",
    d: route.destination_name_short ?? route.destination_name ?? "the destination",
  };
}

function sameEnds(a: Route, b: Route): boolean {
  return (
    (a.origin === b.origin && a.destination === b.destination) ||
    (a.origin === b.destination && a.destination === b.origin)
  );
}

/** "LagFerry" or e.g. "licensed commercial", for use mid-sentence. */
function operatorWord(route: Route): string | null {
  const label = operatorInfo(route.operator)?.label;
  if (!label) return null;
  return label === "LagFerry" ? label : label.toLowerCase();
}

/**
 * Descriptive link to another route, e.g. "the licensed commercial Ikorodu/Ipakodo to
 * Five Cowries/Falomo ferry". When it has the same operator as the running route being
 * described (`from`), its duration is added so the two don't read as the same service.
 * Pass `operator: false` when the sentence already names the operator.
 */
function routeLink(route: Route, { from, operator = true }: { from?: Route; operator?: boolean } = {}): FaqPart {
  const { o, d } = ends(route);
  const word = operatorWord(route);
  const sameOperator =
    from && !isPlannedOmiEkoRoute(from) && operatorWord(from) === word && route.total_base_duration != null;
  const length = sameOperator ? `${route.total_base_duration}-minute ` : "";
  const op = operator && word ? `${word} ` : "";
  return { text: `the ${length}${op}${o} to ${d} ferry`, href: `/map/route/${toRouteSlug(route)}` };
}

/** Link to a facility page, labelled with its full name. */
function facilityLink(id: number, name: string | null): FaqPart {
  return { text: name ?? "this facility", href: `/map/${toFacilitySlug({ facility_id: id, facility_name: name })}` };
}

/** Prose duration: "30 minutes", "2 hours 30 minutes". */
function durationWords(mins: number): string {
  if (mins < 60) return `${mins} minutes`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  const hours = `${h} hour${h === 1 ? "" : "s"}`;
  return m === 0 ? hours : `${hours} ${m} minutes`;
}

function periodDays(p: RoutePeriod): Days {
  return [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday, p.saturday, p.sunday];
}

/** "every day", "on weekdays", "at weekends", "on Mondays, Wednesdays and Fridays"… */
function daysPhrase(days: Days): string {
  const on = days.map((v, i) => (v ? i : -1)).filter((i) => i >= 0);
  const key = days.map((v) => (v ? "1" : "0")).join("");
  if (on.length === 7) return "every day";
  if (key === "1111100") return "on weekdays";
  if (key === "1111110") return "from Monday to Saturday";
  if (key === "0000011") return "at weekends";
  return `on ${listJoin(on.map((i) => `${DAY_NAMES[i]}s`))}`;
}

function listJoin(items: string[], last = "and"): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} ${last} ${items[items.length - 1]}`;
}

function earliest(periods: RoutePeriod[]): RoutePeriod {
  return [...periods].sort((a, b) => a.start_time.localeCompare(b.start_time))[0];
}

/** Payment methods in prose: "cash or bank transfer", "Cowry card". */
function paymentWords(options: string | null): string | null {
  if (!options) return null;
  const methods = options
    .split(",")
    .map((m) => m.trim())
    .filter(Boolean)
    .map((m) => (/cowry/i.test(m) ? "Cowry card" : m.toLowerCase()));
  return methods.length > 0 ? listJoin(methods, "or") : null;
}

const MAX_NAMED_STOPS = 4;

/** ", stopping at A, B and C" with links to each stop's facility page, or "" for a direct route. */
function stopsOnTheWay(stops: RouteStop[]): FaqPart[] {
  const outbound = stops
    .filter((s) => s.direction_id == 0)
    .sort((a, b) => a.stop_order - b.stop_order)
    .slice(1, -1); // drop origin and destination
  if (outbound.length === 0) return [];

  const named = outbound.slice(0, MAX_NAMED_STOPS).map((s): FaqPart => ({
    text: s.facility_name ?? "an unnamed stop",
    href: `/map/${toFacilitySlug({ facility_id: s.stop_id, facility_name: s.facility_name })}`,
  }));
  const lead = outbound.length > MAX_NAMED_STOPS
    ? `, with ${outbound.length} stops on the way, including `
    : ", stopping at ";
  const parts: FaqPart[] = [lead];
  named.forEach((stop, i) => {
    if (i > 0) parts.push(i === named.length - 1 ? " and " : ", ");
    parts.push(stop);
  });
  return parts;
}

// routes.boat_types is a comma-separated list from a fixed set of survey options
const BOATS: Record<string, string> = {
  banana: "banana boats",
  "wooden boats": "wooden boats",
  "fibre boat": "fibre boats",
  covered: "covered boats",
  catamaran: "catamarans",
  "speed boats": "speed boats",
};

/** "catamarans, covered boats and banana boats" */
function boatWords(boatTypes: string | null): string | null {
  if (!boatTypes) return null;
  const types = boatTypes
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean)
    .map((t) => BOATS[t] ?? t);
  return types.length > 0 ? listJoin(types) : null;
}

// ── Questions ──────────────────────────────────────────────────────────────────

function durationFaq(route: Route, stops: RouteStop[], siblings: Route[]): Faq | null {
  if (route.total_base_duration == null) return null;
  const { o, d } = ends(route);
  const operator = operatorInfo(route.operator)?.inSentence;
  const fare = route.last_stop_cost != null ? formatNaira(route.last_stop_cost) : null;

  const answer: FaqPart[] = [
    `The ${o} to ${d} ferry takes about `,
    bold(durationWords(route.total_base_duration)),
    ...stopsOnTheWay(stops),
    ".",
  ];
  if (operator) answer.push(` It is run by ${operator}${fare ? `, and the full trip costs ${fare}` : ""}.`);
  const boats = boatWords(route.boat_types);
  if (boats) answer.push(` The route uses ${boats}.`);

  if (route.has_return) {
    answer.push(" Boats run in both directions.");
  } else {
    const reverse = siblings.find((s) => s.origin === route.destination && s.destination === route.origin);
    answer.push(
      ...(reverse
        ? [` This service runs one way only. For the trip back, see `, routeLink(reverse, { from: route }), "."]
        : [` This service runs one way only, from ${o} to ${d}.`]),
    );
  }
  return { question: `How long is the ferry from ${o} to ${d}?`, answer };
}

function fareFaq(route: Route, siblings: Route[]): Faq | null {
  if (route.last_stop_cost == null) return null;
  const { o, d } = ends(route);
  const operator = operatorInfo(route.operator)?.inSentence;
  const payment = paymentWords(route.payment_options);
  const updated = route.modified_at ? formatMonthYear(route.modified_at) : null;

  const answer: FaqPart[] = [
    `A ticket for the full ${o} to ${d} ferry trip costs `,
    bold(formatNaira(route.last_stop_cost)),
    `${operator ? ` with ${operator}` : ""}${updated ? ` (fare last updated ${updated})` : ""}.`,
  ];
  if (payment) answer.push(` You can pay by ${payment}.`);

  // Other services on the same crossing, so riders can compare
  for (const s of siblings.filter((s) => s.last_stop_cost != null).slice(0, 2)) {
    const price = Number(s.last_stop_cost) === Number(route.last_stop_cost)
      ? "charges the same fare"
      : `costs ${formatNaira(s.last_stop_cost!)}`;
    const isReturnTrip = !route.has_return && s.origin === route.destination && s.destination === route.origin;
    const word = operatorWord(s);

    if (isReturnTrip) {
      answer.push(" The return trip, ", routeLink(s, { operator: false }), `, ${price}.`);
    } else if (word && word === operatorWord(route)) {
      answer.push(` Another ${word} service on this crossing, `, routeLink(s, { from: route, operator: false }), `, ${price}.`);
    } else {
      answer.push(" ", capitalise(routeLink(s)), ` ${price}.`);
    }
  }
  return { question: `How much is the ferry from ${o} to ${d}?`, answer };
}

/** Earliest period, preferring the weekday timetable: it is what most riders ask about. */
function firstPeriod(periods: RoutePeriod[]): RoutePeriod | null {
  if (periods.length === 0) return null;
  const weekday = periods.filter((p) => p.monday);
  return earliest(weekday.length > 0 ? weekday : periods);
}

function lastEnd(periods: RoutePeriod[]): string {
  return periods.map((p) => p.end_time ?? p.start_time).sort().at(-1)!;
}

function firstDepartureFaq(route: Route, periods: RoutePeriod[]): Faq | null {
  const outbound = periods.filter((p) => p.direction_id == 0);
  const returns = periods.filter((p) => p.direction_id == 1);
  const first = firstPeriod(outbound);
  if (!first) return null;
  const firstBack = firstPeriod(returns);
  const { o, d } = ends(route);
  const when = daysPhrase(periodDays(first));
  const sameStart = firstBack?.start_time === first.start_time;

  const answer: FaqPart[] = [];
  if (outbound.length === 1 && first.average_daily_boat_departures === 1) {
    answer.push(`There is one ferry a day from ${o} to ${d}, leaving at `, bold(formatTime(first.start_time)), ` ${when}.`);
  } else {
    answer.push(
      `The first ferry from ${o} to ${d} leaves at `,
      bold(formatTime(first.start_time)),
      sameStart ? ` ${when}, and the first boat back from ${d} leaves at the same time.` : ` ${when}.`,
    );
    const until = lastEnd(outbound);
    const bothWays = sameStart && lastEnd(returns) === until;
    const frequencies = new Set(outbound.map((p) => p.frequency).filter(Boolean));
    const every = frequencies.size === 1 ? `, with a boat about every ${[...frequencies][0]} minutes` : "";
    answer.push(` Boats run${bothWays ? " both ways" : ""} until about ${formatTime(until)}${every}.`);
  }

  if (outbound.every((p) => p.morning_service && !p.evening_service)) {
    answer.push(" It is a morning service only.");
  }
  if (firstBack && !sameStart) {
    answer.push(` The first boat back from ${d} to ${o} leaves at ${formatTime(firstBack.start_time)}.`);
  }
  return { question: `What time is the first ferry from ${o} to ${d}?`, answer };
}

function weekendFaq(route: Route, periods: RoutePeriod[]): Faq | null {
  if (periods.length === 0) return null;
  const { o, d } = ends(route);
  const days: Days = DAY_NAMES.map((_, i) => periods.some((p) => periodDays(p)[i]));
  const [sat, sun] = [days[5], days[6]];
  const firstOn = (dayIndex: number) => {
    const onDay = periods.filter((p) => p.direction_id == 0 && periodDays(p)[dayIndex]);
    return onDay.length > 0 ? formatTime(earliest(onDay).start_time) : null;
  };

  const answer: FaqPart[] = [];
  if (sat && sun) {
    answer.push(bold("Yes."), ` The ${o} to ${d} ferry runs on Saturdays and Sundays.`);
    if (route.weekend_equals_weekday_schedule === "Yes") {
      answer.push(" The weekend timetable is the same as on weekdays.");
    } else {
      const satFirst = firstOn(5);
      answer.push(` The weekend timetable differs from weekdays${satFirst ? `; the first Saturday boat leaves ${o} at ${satFirst}` : ""}.`);
    }
  } else if (sat || sun) {
    const [yes, no, idx] = sat ? ["Saturdays", "Sundays", 5] as const : ["Sundays", "Saturdays", 6] as const;
    const first = firstOn(idx);
    answer.push(`The ${o} to ${d} ferry runs on `, bold(yes), ` but not on ${no}.`);
    if (first) answer.push(` The first ${yes.slice(0, -1)} boat leaves ${o} at ${first}.`);
  } else {
    answer.push(bold("No."), ` The ${o} to ${d} ferry runs ${daysPhrase(days)} only, with no boats on Saturdays or Sundays.`);
  }
  return { question: `Does the ${o} to ${d} ferry run at weekends?`, answer };
}

// routes.rain and routes.hyacinth_season_disruption hold one of a fixed set of survey
// answers. Each becomes a sentence about `ferry` ("the X to Y ferry", or "the route"
// after the first mention), flagged by whether it is a disruption.
type Note = { sentence: (ferry: string) => string; disrupts: boolean | null };

const RAIN: Record<string, Note> = {
  "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.": {
    sentence: (f) => `Boats on ${f} keep running in the rain, unless it is heavy enough to make navigation unsafe.`,
    disrupts: false,
  },
  "All boats are suspended.": {
    sentence: (f) => `All boats on ${f} stop running when it rains.`,
    disrupts: true,
  },
  "Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.": {
    sentence: (f) => `Only covered boats on ${f} keep running in the rain, and they stop too if it gets heavy enough to make navigation unsafe.`,
    disrupts: true,
  },
};

const HYACINTH: Record<string, Note> = {
  "No, this route doesn't get disrupted and still works during the water hyacinth season": {
    sentence: (f) => `Water hyacinth season does not affect ${f}.`,
    disrupts: false,
  },
  "Yes, this route gets disrupted BUT still works during the water hyacinth season": {
    sentence: (f) => `During water hyacinth season, ${f} is disrupted but keeps running.`,
    disrupts: true,
  },
  "Yes, this route gets disrupted and doesn't work during the water hyacinth season": {
    sentence: (f) => `${capitaliseText(f)} stops running during water hyacinth season, when the weed blocks the water.`,
    disrupts: true,
  },
};

function disruptionsFaq(route: Route): Faq | null {
  const notes: Note[] = [];
  if (route.rain) {
    const raw = route.rain;
    notes.push(RAIN[raw] ?? { sentence: (f) => `Rain on ${f}: ${raw}`, disrupts: null });
  }
  if (route.hyacinth_season_disruption) {
    const raw = route.hyacinth_season_disruption;
    notes.push(HYACINTH[raw] ?? { sentence: (f) => `Water hyacinth season on ${f}: ${raw}`, disrupts: null });
  }
  if (notes.length === 0) return null;
  const { o, d } = ends(route);

  // Disruptions first, so the answer leads with what riders need to know
  notes.sort((a, b) => Number(b.disrupts === true) - Number(a.disrupts === true));
  const lead = notes.some((n) => n.disrupts === true)
    ? "Yes."
    : notes.every((n) => n.disrupts === false)
      ? "No major ones."
      : null;
  const sentences = notes.map((n, i) => n.sentence(i === 0 ? `the ${o} to ${d} ferry` : "the route")).join(" ");
  return {
    question: `Are there any disruptions on the ${o} to ${d} ferry?`,
    answer: lead ? [bold(lead), ` ${sentences}`] : [sentences],
  };
}

function plannedFaq(route: Route, siblings: Route[], allRoutes: Route[]): Faq {
  const { o, d } = ends(route);
  const answer: FaqPart[] = [
    bold("Not yet."),
    ` The ${o} to ${d} route is planned under the Lagos State Government's Omi Eko ferry expansion and has no timetable or fares yet.`,
  ];

  if (siblings.length > 0) {
    answer.push(" Until it opens, you can make the same trip on ");
    siblings.slice(0, 2).forEach((s, i) => answer.push(...(i > 0 ? [" or "] : []), routeLink(s, { from: route })));
    answer.push(".");
    return { question: `Is the ${o} to ${d} Omi Eko ferry running yet?`, answer };
  }

  // No running service between the two ends: point to whichever end has boats today
  const served = (id: number | null) =>
    id != null &&
    allRoutes.some(
      (r) => !isPlannedOmiEkoRoute(r) && (r.origin === id || r.destination === id || r.stop_names?.includes(id)),
    );
  const servedEnds = [
    served(route.origin) ? facilityLink(route.origin!, route.origin_name) : null,
    served(route.destination) ? facilityLink(route.destination!, route.destination_name) : null,
  ].filter((p): p is FaqPart => p !== null);

  if (servedEnds.length > 0) {
    answer.push(` No ferry runs directly between ${o} and ${d} today, but you can see where boats from `);
    servedEnds.forEach((link, i) => answer.push(...(i > 0 ? [" and "] : []), link));
    answer.push(" go.");
  } else {
    answer.push(
      ` The Lagos Ferry Map has no ferry serving ${o} or ${d} yet. See `,
      { text: "the ferry routes running today", href: "/directory#routes" },
      ".",
    );
  }
  return { question: `Is the ${o} to ${d} Omi Eko ferry running yet?`, answer };
}

function capitaliseText(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function capitalise(part: FaqPart): FaqPart {
  return typeof part === "string" ? capitaliseText(part) : { ...part, text: capitaliseText(part.text) };
}
