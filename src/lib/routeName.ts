import type { Route } from "@/types/route";
import { formatMinutes, formatNaira } from "./format";
import { isPlannedOmiEkoRoute } from "./omiEko";
import { operatorInfo } from "./operators";

/** ⇄ when the route runs both ways (has a return schedule), → when it is one-way. */
export function routeArrow(route: Pick<Route, "has_return">): string {
  return route.has_return ? "⇄" : "→";
}

/** "Origin ⇄ Destination" with full facility names. */
export function routeName(
  route: Pick<Route, "origin_name" | "destination_name" | "has_return">,
): string {
  return `${route.origin_name ?? "Origin"} ${routeArrow(route)} ${route.destination_name ?? "Destination"}`;
}

/**
 * Page title for a route. Several routes share the same two ends (e.g. a LagFerry
 * and a licensed commercial service, or a running and a planned route), so the
 * title carries what tells them apart: operator, duration and fare, or "planned".
 * Uses short names to keep the differences within what search results display.
 */
export function routePageTitle(route: Route): string {
  const ends = `${route.origin_name_short ?? route.origin_name ?? "Origin"} ${routeArrow(route)} ${route.destination_name_short ?? route.destination_name ?? "Destination"} ferry`;
  if (isPlannedOmiEkoRoute(route)) return `${ends}: planned Omi Eko route`;

  const details = [
    operatorInfo(route.operator)?.label,
    formatMinutes(route.total_base_duration),
    route.last_stop_cost != null ? `from ${formatNaira(route.last_stop_cost)}` : null,
  ].filter(Boolean);
  return details.length > 0 ? `${ends}: ${details.join(", ")}` : ends;
}

/** Search-result description for a route page. */
export function routeDescription(route: Route): string {
  const origin = route.origin_name ?? "Origin";
  const destination = route.destination_name ?? "Destination";

  if (isPlannedOmiEkoRoute(route)) {
    return `Planned ferry route from ${origin} to ${destination}, proposed under the Lagos State Government's Omi Eko ferry expansion. Not yet in service. See the ferry routes running today on the Lagos Ferry Map.`;
  }

  const trip = route.has_return
    ? `Ferry both ways between ${origin} and ${destination}`
    : `One-way ferry from ${origin} to ${destination}`;
  const operator = operatorInfo(route.operator)?.inSentence;
  const duration = formatMinutes(route.total_base_duration);
  const fare = route.last_stop_cost != null ? `from ${formatNaira(route.last_stop_cost)}` : null;
  const facts = [duration && `about ${duration}`, fare].filter(Boolean).join(", ");

  return `${trip}${operator ? `, run by ${operator}` : ""}${facts ? `: ${facts}` : ""}. View schedule, stops, and fares on the Lagos Ferry Map.`;
}
