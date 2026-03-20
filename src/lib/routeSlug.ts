/** Build the URL slug for a route: just the numeric id. */
export function toRouteSlug(route: { 
  route_id: number;
  origin_name: string | null;
  destination_name: string | null;
}): string {
    const origin_name = route.origin_name ?? "unnamed";
    const origin_slug = origin_name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "");
    const destination_name = route.destination_name ?? "unnamed";
    const destination_slug = destination_name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "");
    return `${route.route_id}-${origin_slug}-${destination_slug}`;
}
