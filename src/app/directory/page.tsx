import type { Metadata } from "next";
import { getFacilities, getAllFacilityDestinations } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";
import { FacilitiesTable } from "@/components/FacilitiesTable";
import { RoutesTable } from "@/components/RoutesTable";
import type { Facility } from "@/types/facility";
import type { Route } from "@/types/route";

export const revalidate = 0;

export const metadata: Metadata = {
  title: "Lagos Ferry Terminals & Routes | Complete Directory",
  description:
    "Directory of every active Lagos ferry terminal, grouped by LGA, with ferry route connections. Find out how to travel by ferry between Victoria Island (VI), Apapa, CMS, Ikorodu, Badore, Ajah, Lekki, and more. Covers routes, schedules, and terminal details across Lagos Lagoon.",
  openGraph: {
    type: "website",
    title: "Lagos Ferry Terminals & Routes | Complete Directory",
    description:
      "Find Lagos ferry terminals and their routes. Plan ferry journeys between Victoria Island, Apapa, CMS, Ikorodu, Badore, Ajah, and more. Full directory grouped by Local Government Area.",
    url: "/directory",
  },
  twitter: {
    card: "summary",
    title: "Lagos Ferry Terminals & Routes | Complete Directory",
    description:
      "Find Lagos ferry terminals and their routes. Plan ferry journeys between Victoria Island, Apapa, CMS, Ikorodu, Badore, Ajah, and more.",
  },
  alternates: { canonical: "/directory" },
};

const BASE_URL = "https://lagosferries.com";

function buildFacilitiesJsonLd(facilities: Facility[], destinationMap: Map<number, string[]>) {
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Lagos Ferry Terminals",
    description: "Directory of active ferry terminals in Lagos, Nigeria.",
    numberOfItems: facilities.length,
    itemListElement: facilities.map((f, i) => {
      const dests = destinationMap.get(f.facility_id) ?? [];
      const destText = dests.length > 0 ? ` Serves ferry routes to: ${dests.join(", ")}.` : "";
      return {
        "@type": "ListItem",
        position: i + 1,
        item: {
          "@type": "CivicStructure",
          "@id": `${BASE_URL}/map/${toFacilitySlug(f)}`,
          url: `${BASE_URL}/map/${toFacilitySlug(f)}`,
          name: f.facility_name ?? "Unnamed facility",
          description: `Ferry terminal in ${f.lga ?? "Lagos"}, Lagos, Nigeria.${destText}`,
          address: {
            "@type": "PostalAddress",
            addressLocality: f.lga ?? "Lagos",
            addressRegion: "Lagos",
            addressCountry: "NG",
          },
        },
      };
    }),
  };
}

function buildRoutesJsonLd(routes: Route[]) {
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Lagos Ferry Routes",
    description: "Active ferry routes across Lagos Lagoon, Nigeria.",
    numberOfItems: routes.length,
    itemListElement: routes.map((r, i) => ({
      "@type": "ListItem",
      position: i + 1,
      item: {
        "@type": "Service",
        "@id": `${BASE_URL}/map/route/${toRouteSlug(r)}`,
        url: `${BASE_URL}/map/route/${toRouteSlug(r)}`,
        name: `${r.origin_name ?? "Unknown"} → ${r.destination_name ?? "Unknown"} ferry`,
        description: `Ferry route from ${r.origin_name ?? "Unknown"} to ${r.destination_name ?? "Unknown"} in Lagos, Nigeria${r.operator ? `, operated by ${r.operator.split(":")[0].trim()}` : ""}.`,
        provider: r.operator
          ? { "@type": "Organization", name: r.operator.split(":")[0].trim() }
          : undefined,
        areaServed: { "@type": "City", name: "Lagos", addressCountry: "NG" },
      },
    })),
  };
}

function buildBreadcrumbJsonLd() {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: BASE_URL },
      { "@type": "ListItem", position: 2, name: "Directory", item: `${BASE_URL}/directory` },
    ],
  };
}

export default async function DirectoryPage() {
  const [facilities, routes, facilityDestinations] = await Promise.all([
    getFacilities(),
    getRoutes(),
    getAllFacilityDestinations(),
  ]);

  const destinationMap = new Map<number, string[]>();
  for (const { facility_id, destination_name } of facilityDestinations) {
    if (!destinationMap.has(facility_id)) destinationMap.set(facility_id, []);
    destinationMap.get(facility_id)!.push(destination_name);
  }

  const sortedFacilities = [...facilities].sort((a, b) => {
    const lgaComp = (a.lga ?? "").localeCompare(b.lga ?? "");
    if (lgaComp !== 0) return lgaComp;
    return (a.facility_name ?? "").localeCompare(b.facility_name ?? "");
  });

  const sortedRoutes = [...routes].sort((a, b) => {
    const originComp = (a.origin_name ?? "").localeCompare(b.origin_name ?? "");
    if (originComp !== 0) return originComp;
    return (a.destination_name ?? "").localeCompare(b.destination_name ?? "");
  });

  const activeRouteCount = routes.filter(
    (r) => !(r.omi_eko && r.total_base_duration === 9999)
  ).length;

  const lgaCount = new Set(facilities.map((f) => f.lga)).size;

  // Convert Map to plain Record for client component serialization
  const destRecord: Record<number, string[]> = {};
  for (const [id, dests] of destinationMap) destRecord[id] = dests;

  const facilitiesJsonLd = buildFacilitiesJsonLd(facilities, destinationMap);
  const routesJsonLd = buildRoutesJsonLd(sortedRoutes);
  const breadcrumbJsonLd = buildBreadcrumbJsonLd();

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(facilitiesJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(routesJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }} />

      <section className="max-w-5xl mx-auto px-4 py-10">

        <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-3">
          Lagos Ferry Terminals &amp; Routes
        </h1>
        <p className="text-base leading-6 text-on-surface-variant mb-4 max-w-2xl">
          Directory of all active ferry terminals in Lagos, Nigeria — with route connections and
          facility details. Use this guide to plan ferry journeys across Lagos Lagoon, including
          routes between Victoria Island (VI), Apapa, CMS, Ikorodu, Badore, Ajah, Lekki, and more.
        </p>

        <div className="flex items-center gap-2 text-sm text-on-surface-variant mb-10 flex-wrap">
          <a href="#facilities" className="flex items-center gap-2 hover:text-primary transition-colors">
            <span className="font-medium text-on-surface">{facilities.length}</span>
            <span>facilities</span>
          </a>
          <span className="text-outline-variant mx-1">·</span>
          <a href="#routes" className="flex items-center gap-2 hover:text-primary transition-colors">
            <span className="font-medium text-on-surface">{activeRouteCount}</span>
            <span>active route{activeRouteCount !== 1 ? "s" : ""}</span>
          </a>
          <span className="text-outline-variant mx-1">·</span>
          <span className="font-medium text-on-surface">{lgaCount}</span>
          <span>LGA{lgaCount !== 1 ? "s" : ""}</span>
        </div>

        <div className="mb-12">
          <h2 id="facilities" className="text-xl font-medium text-on-surface mb-2">Facilities</h2>
          <p className="text-xs leading-6 text-on-surface-variant mb-2 max-w-2xl">Click on a facility to see full details</p>
          <FacilitiesTable facilities={sortedFacilities} destinationMap={destRecord} />
        </div>

        <div>
          <h2 id="routes" className="text-xl font-medium text-on-surface mb-2">Routes</h2>
          <p className="text-xs leading-6 text-on-surface-variant mb-2 max-w-2xl">Click on a route to see full details and schedule</p>
          <RoutesTable routes={sortedRoutes} />
        </div>

      </section>
    </>
  );
}
