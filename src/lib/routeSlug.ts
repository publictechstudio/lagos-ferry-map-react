import { toKebab } from "./slug";

/** Build the URL slug for a route: `{id}-{origin}-{destination}` */
export function toRouteSlug(route: {
  route_id: number;
  origin_name: string | null;
  destination_name: string | null;
}): string {
  const origin = toKebab(route.origin_name ?? "unnamed");
  const destination = toKebab(route.destination_name ?? "unnamed");
  return `${route.route_id}-${origin}-${destination}`;
}
