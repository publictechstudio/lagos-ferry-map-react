import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";

export const revalidate = 3600;

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
      return {
        title: `${route.origin_name} → ${route.destination_name} — Lagos Ferry Map`,
      };
    }
  }
  return { title: "Ferry Route — Lagos Ferry Map" };
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
