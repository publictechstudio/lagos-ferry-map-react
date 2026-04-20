import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toRouteSlug } from "@/lib/routeSlug";
import { formatNaira } from "@/lib/format";

export const revalidate = 0;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const routeId = parseInt(slug, 10);

  if (!isNaN(routeId)) {
    const routes = await getRoutes();
    const route = routes.find((r) => r.route_id === routeId);

    if (route?.origin_name && route?.destination_name) {
      const title = `${route.origin_name} → ${route.destination_name}`;
      const fare = route.total_base_cost != null ? ` from ${formatNaira(route.total_base_cost)}` : "";
      const duration =
        route.total_base_duration != null
          ? ` in ~${route.total_base_duration} min`
          : "";
      const description = `Ferry route from ${route.origin_name} to ${route.destination_name}${duration}${fare}. View schedule, stops, and pricing on the Lagos Ferry Map.`;

      return {
        title,
        description,
        openGraph: {
          title: `${title} — Lagos Ferry Map`,
          description,
          url: `/map/route/${toRouteSlug(route)}`,
        },
        alternates: { canonical: `/map/route/${toRouteSlug(route)}` },
      };
    }
  }

  return {
    title: "Ferry Route",
    description:
      "View ferry route details, schedule, stops, and pricing on the Lagos Ferry Map.",
  };
}

export default async function RouteMapPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const [facilities, routes, { slug }] = await Promise.all([
    getFacilities(),
    getRoutes(),
    params,
  ]);

  const routeId = parseInt(slug, 10);
  const initialSelectedRoute = !isNaN(routeId)
    ? (routes.find((r) => r.route_id === routeId) ?? null)
    : null;

  return (
    <section className="flex flex-col" style={{ height: "calc(100vh - 64px)" }}>
      <div className="flex-1 min-h-0">
        <MapWrapper
          facilities={facilities}
          routes={routes}
          initialSelected={null}
          initialSelectedRoute={initialSelectedRoute}
        />
      </div>
    </section>
  );
}
