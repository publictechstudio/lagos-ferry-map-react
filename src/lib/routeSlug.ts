/** Build the URL slug for a route: just the numeric id. */
export function toRouteSlug(route: { route_id: number }): string {
  return String(route.route_id);
}
