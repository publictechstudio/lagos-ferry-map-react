import type { Metadata } from "next";
import Link from "next/link";
import { getFacilities, getAllFacilityDestinations } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toFacilitySlug } from "@/lib/facilitySlug";
import type { Facility } from "@/types/facility";

export const revalidate = 0;

export const metadata: Metadata = {
  title: "Lagos Ferry Terminals & Routes | Complete Directory",
  description:
    "Directory of every active Lagos ferry terminal, grouped by LGA, with ferry route connections. Find out how to travel by ferry between Victoria Island (VI), Apapa, CMS, Ikorodu, Badore, Ajah, Lekki, and more. Covers routes, schedules, and terminal details across Lagos Lagoon.",
  openGraph: {
    title: "Lagos Ferry Terminals & Routes | Complete Directory",
    description:
      "Find Lagos ferry terminals and their routes. Plan ferry journeys between Victoria Island, Apapa, CMS, Ikorodu, Badore, Ajah, and more. Full directory grouped by Local Government Area.",
  },
  alternates: { canonical: "/directory" },
};

function buildJsonLd(facilities: Facility[], destinationMap: Map<number, string[]>) {
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Lagos Ferry Terminals & Routes",
    description:
      "Directory of active ferry terminals in Lagos, Nigeria, with route connections across Lagos Lagoon.",
    numberOfItems: facilities.length,
    itemListElement: facilities.map((f, i) => {
      const dests = destinationMap.get(f.facility_id) ?? [];
      const destText = dests.length > 0 ? ` Serves ferry routes to: ${dests.join(", ")}.` : "";
      return {
        "@type": "ListItem",
        position: i + 1,
        item: {
          "@type": "CivicStructure",
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

function facilityLabel(facility: Facility): "future-omi-eko" | "charter-only" | null {
  const isCharterOnly = facility.category?.includes("Charter only") ?? false;
  const isFutureOmiEko =
    (facility.category?.includes("Future Omi Eko") ?? false) ||
    (isCharterOnly && facility.omi_eko === "Yes");
  if (isFutureOmiEko) return "future-omi-eko";
  if (isCharterOnly) return "charter-only";
  return null;
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

  const jsonLd = buildJsonLd(facilities, destinationMap);

  const lgaCount = new Set(facilities.map((f) => f.lga)).size;

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

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
          <span className="font-medium text-on-surface">{facilities.length}</span>
          <span>facilities</span>
          <span className="text-outline-variant mx-1">·</span>
          <span className="font-medium text-on-surface">{activeRouteCount}</span>
          <span>active route{activeRouteCount !== 1 ? "s" : ""}</span>
          <span className="text-outline-variant mx-1">·</span>
          <span className="font-medium text-on-surface">{lgaCount}</span>
          <span>LGA{lgaCount !== 1 ? "s" : ""}</span>
        </div>

        {/* Facilities section */}
        <div className="mb-12">
          <h2 className="text-xl font-medium text-on-surface mb-4">Facilities</h2>
          <div className="rounded-xl border border-outline-variant overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-surface-variant/50 border-b border-outline-variant">
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide whitespace-nowrap">LGA</th>
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide whitespace-nowrap">Facility Name</th>
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide whitespace-nowrap">Facility Type</th>
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide">Destinations</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/60">
                {sortedFacilities.map((facility) => {
                  const destinations = destinationMap.get(facility.facility_id) ?? [];
                  const label = facilityLabel(facility);
                  return (
                    <tr key={facility.facility_id} className="bg-surface hover:bg-on-surface/[0.03] transition-colors">
                      <td className="px-4 py-3 text-on-surface-variant whitespace-nowrap align-top">{facility.lga ?? "—"}</td>
                      <td className="px-4 py-3 align-top">
                        <Link
                          href={`/map/${toFacilitySlug(facility)}`}
                          className="text-on-surface hover:text-primary transition-colors font-medium"
                        >
                          {facility.facility_name ?? "Unnamed"}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-on-surface-variant align-top whitespace-nowrap">
                        {facility.facility_type ?? "—"}
                      </td>
                      <td className="px-4 py-3 align-top">
                        {label === "future-omi-eko" && (
                          <span className="inline-flex px-2 py-0.5 rounded-full bg-[#7B3F00]/15 text-[#7B3F00] text-xs font-bold">
                            Future OMI EKO
                          </span>
                        )}
                        {label === "charter-only" && (
                          <span className="inline-flex px-2 py-0.5 rounded-full bg-[#7B3F00]/15 text-[#7B3F00] text-xs font-bold">
                            Charter Only
                          </span>
                        )}
                        {label === null && destinations.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {destinations.map((dest) => (
                              <span
                                key={dest}
                                className="px-2 py-0.5 rounded-full bg-surface-variant text-on-surface-variant text-xs"
                              >
                                {dest}
                              </span>
                            ))}
                          </div>
                        )}
                        {label === null && destinations.length === 0 && (
                          <span className="text-on-surface-variant/50">—</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Routes section */}
        <div>
          <h2 className="text-xl font-medium text-on-surface mb-4">Routes</h2>
          <div className="rounded-xl border border-outline-variant overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-surface-variant/50 border-b border-outline-variant">
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide whitespace-nowrap">Origin</th>
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide whitespace-nowrap">Destination</th>
                  <th className="text-left px-4 py-3 font-medium text-on-surface-variant text-xs uppercase tracking-wide">Operator</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/60">
                {sortedRoutes.map((route) => (
                  <tr key={route.route_id} className="bg-surface hover:bg-on-surface/[0.03] transition-colors">
                    <td className="px-4 py-3 text-on-surface whitespace-nowrap">{route.origin_name ?? "—"}</td>
                    <td className="px-4 py-3 text-on-surface whitespace-nowrap">{route.destination_name ?? "—"}</td>
                    <td className="px-4 py-3 text-on-surface-variant">{route.operator ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </section>
    </>
  );
}
