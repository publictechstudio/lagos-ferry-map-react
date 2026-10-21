import type { Metadata } from "next";
import { permanentRedirect } from "next/navigation";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toRouteSlug } from "@/lib/routeSlug";
import { getRoutePanelData } from "@/lib/routePanel";
import { isPlannedOmiEkoRoute } from "@/lib/omiEko";
import { routeDescription, routePageTitle } from "@/lib/routeName";
import { buildRouteFaqs, faqPlainText } from "@/lib/routeFaqs";

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
      const title = routePageTitle(route);
      const description = routeDescription(route);

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

  // Only the leading id is used for lookup, so any text after it would serve this page.
  // Send outdated or mistyped slugs (e.g. after a facility rename) to the one real URL.
  if (initialSelectedRoute && slug !== toRouteSlug(initialSelectedRoute)) {
    permanentRedirect(`/map/route/${toRouteSlug(initialSelectedRoute)}`);
  }

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
        // Freshness signal for crawlers; not shown on the page
        ...(initialSelectedRoute.modified_at && {
          dateModified: new Date(initialSelectedRoute.modified_at).toISOString(),
        }),
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

  // Same questions the panel shows, so the structured data matches the visible page
  const faqs = initialSelectedRoute
    ? buildRouteFaqs(
        initialSelectedRoute,
        initialRoutePanelData?.periods ?? [],
        initialRoutePanelData?.stops ?? [],
        routes,
      )
    : [];
  const faqJsonLd = faqs.length > 0
    ? {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        mainEntity: faqs.map((faq) => ({
          "@type": "Question",
          name: faq.question,
          acceptedAnswer: { "@type": "Answer", text: faqPlainText(faq) },
        })),
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
      {faqJsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
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
