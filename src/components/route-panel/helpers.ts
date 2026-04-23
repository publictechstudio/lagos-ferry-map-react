import type { RoutePeriod } from "@/types/routePeriod";
import type { RouteStop } from "@/types/routeStop";
import { formatNaira } from "@/lib/format";

export function formatTime(timeStr: string): string {
  const [h, m] = timeStr.split(":");
  const hour = parseInt(h, 10);
  const minute = m;
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
  return `${h12}:${minute} ${ampm}`;
}

export function formatMinutes(mins: number | null): string | null {
  if (mins == null) return null;
  if (mins < 60) return `${mins} min`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return m === 0 ? `${h} hr` : `${h} hr ${m} min`;
}

export function formatDaySchedule(p: RoutePeriod): string {
  const days = [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday, p.saturday, p.sunday];
  const names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  const active = days.map((on, i) => ({ on, name: names[i] })).filter((d) => d.on);

  if (active.length === 7) return "Daily";
  if (active.length === 0) return "";

  const weekdays = [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday];
  const weekend = [p.saturday, p.sunday];
  const allWeekdays = weekdays.every(Boolean);
  const noWeekdays = weekdays.every((d) => !d);
  const allWeekend = weekend.every(Boolean);
  const noWeekend = weekend.every((d) => !d);

  if (allWeekdays && noWeekend) return "Monday – Friday";
  if (allWeekdays && p.saturday && !p.sunday) return "Monday – Saturday";
  if (allWeekdays && allWeekend) return "Daily";
  if (noWeekdays && allWeekend) return "Saturday and Sunday";
  if (noWeekdays && p.saturday && !p.sunday) return "Saturdays only.";
  if (noWeekdays && !p.saturday && p.sunday) return "Sundays only.";

  return active.map((d) => d.name).join(", ");
}

/** Unique key representing which days of the week a period runs. */
export function dayKey(p: RoutePeriod): string {
  return [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday, p.saturday, p.sunday]
    .map((v) => (v ? "1" : "0"))
    .join("");
}

/** Group periods into tables by their day combination. */
export function groupByDays(periods: RoutePeriod[]): Map<string, RoutePeriod[]> {
  const map = new Map<string, RoutePeriod[]>();
  for (const p of periods) {
    const k = dayKey(p);
    if (!map.has(k)) map.set(k, []);
    map.get(k)!.push(p);
  }
  return map;
}

/** Direction suffix based on whether service is morning/evening only. */
export function directionSuffix(periods: RoutePeriod[]): string {
  const allMorning = periods.length > 0 && periods.every((p) => p.morning_service && !p.evening_service);
  const allEvening = periods.length > 0 && periods.every((p) => !p.morning_service && p.evening_service);
  if (allMorning) return " (MORNINGS ONLY)";
  if (allEvening) return " (EVENINGS ONLY)";
  return "";
}

/** Format cost_to_stop (string from DB) as Naira or empty string. */
export function formatStopCost(cost: string): string {
  const n = parseFloat(cost);
  if (isNaN(n) || n === 0) return "";
  return formatNaira(n);
}

/** Determine if all non-origin segments share the same cost. */
export function isFlat(stops: RouteStop[]): boolean {
  const costs = stops.slice(1).map((s) => parseFloat(s.cost_to_stop));
  return costs.length > 0 && costs.every((c) => c === costs[0]);
}
