import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toRouteSlug } from "@/lib/routeSlug";
import { formatNaira } from "@/lib/format";
import { getRoutePanelData } from "@/lib/routePanel";
import { isPlannedOmiEkoRoute } from "@/lib/omiEko";

export const revalidate = 60;

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
      const planned = isPlannedOmiEkoRoute(route);
      // Planned routes have a placeholder duration and no real fare, so leave both out
      const title = planned
        ? `${route.origin_name} → ${route.destination_name} (planned Omi Eko route)`
        : `${route.origin_name} → ${route.destination_name}`;
      const fare = route.last_stop_cost != null ? ` from ${formatNaira(route.last_stop_cost)}` : "";
      const duration =
        route.total_base_duration != null
          ? ` in ~${route.total_base_duration} min`
          : "";
      const description = planned
        ? `Planned ferry route from ${route.origin_name} to ${route.destination_name}, proposed under the Lagos State Government's Omi Eko ferry expansion. Not yet in service. See the ferry routes running today on the Lagos Ferry Map.`
        : `Ferry route from ${route.origin_name} to ${route.destination_name}${duration}${fare}. View schedule, stops, and pricing on the Lagos Ferry Map.`;

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

  const isPlannedOmiEko = initialSelectedRoute != null && isPlannedOmiEkoRoute(initialSelectedRoute);
  const initialRoutePanelData =
    initialSelectedRoute && !isPlannedOmiEko
      ? await getRoutePanelData(initialSelectedRoute.route_id)
      : null;

  const jsonLd = initialSelectedRoute && !isPlannedOmiEko
    ? {
        "@context": "https://schema.org",
        "@type": "BusRoute",
        name: `${initialSelectedRoute.origin_name ?? ""} to ${initialSelectedRoute.destination_name ?? ""} Ferry`,
        ...(initialSelectedRoute.operator && {
          provider: { "@type": "Organization", name: initialSelectedRoute.operator },
        }),
        ...(initialSelectedRoute.total_base_duration != null && {
          estimatedDuration: `PT${initialSelectedRoute.total_base_duration}M`,
        }),
        ...(initialSelectedRoute.last_stop_cost != null && {
          offers: {
            "@type": "Offer",
            price: String(initialSelectedRoute.last_stop_cost),
            priceCurrency: "NGN",
          },
        }),
        ...(initialRoutePanelData && initialRoutePanelData.stops.length > 0 && {
          itinerary: initialRoutePanelData.stops.map((s) => ({
            "@type": "BusStop",
            name: s.facility_name ?? "Stop",
            ...(s.lga && {
              containedInPlace: { "@type": "AdministrativeArea", name: `${s.lga} LGA, Lagos` },
            }),
          })),
        }),
      }
    : null;

  return (
    <>
      {jsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      )}
      <section className="flex flex-col" style={{ height: "calc(100vh - 64px)" }}>
        <div className="flex-1 min-h-0">
          <MapWrapper
            facilities={facilities}
            routes={routes}
            initialSelected={null}
            initialSelectedRoute={initialSelectedRoute}
            initialRoutePanelData={initialRoutePanelData}
          />
        </div>
      </section>
    </>
  );
}
