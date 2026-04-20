import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";

export const metadata: Metadata = {
  title: "Lagos Ferry Map — Interactive Route & Terminal Map",
  description:
    "Explore every active ferry route and terminal in Lagos on an interactive map. Search by address or facility name, filter by operator, and view fares, schedules, and terminal details for routes across Lagos Lagoon.",
  openGraph: {
    title: "Lagos Ferry Map — Interactive Route & Terminal Map",
    description:
      "Interactive map of all Lagos ferry routes, terminals, schedules, and fares. Search facilities, filter layers, and plan your water-transit journey.",
  },
  alternates: { canonical: "/map" },
};

const mapJsonLd = {
  "@context": "https://schema.org",
  "@type": "WebApplication",
  name: "Lagos Ferry Map",
  description:
    "Interactive map of all ferry routes, terminals, schedules, and fares in Lagos, Nigeria.",
  applicationCategory: "TravelApplication",
  operatingSystem: "Web",
  url: "https://lagosferries.com/map",
  featureList: [
    "Interactive ferry terminal and route map",
    "Address proximity search for nearest terminals",
    "Facility name and LGA search",
    "Layer toggles for operators and terminal types",
    "Fare and schedule details per route",
  ],
  areaServed: {
    "@type": "City",
    name: "Lagos",
    containedInPlace: { "@type": "Country", name: "Nigeria" },
  },
};

export const revalidate = 60;

export default async function MapPage() {
  const [facilities, routes] = await Promise.all([getFacilities(), getRoutes()]);

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(mapJsonLd) }}
      />
    <section className="flex flex-col" style={{ height: "calc(100vh - 64px)" }}>
      <div className="flex-1 min-h-0">
        <MapWrapper
          facilities={facilities}
          routes={routes}
          initialSelected={null}
          initialSelectedRoute={null}
        />
      </div>
    </section>
    </>
  );
}
