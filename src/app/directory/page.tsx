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

function groupByLGA(facilities: Facility[]): [string, Facility[]][] {
  const map = new Map<string, Facility[]>();
  for (const f of facilities) {
    const lga = f.lga ?? "Unknown LGA";
    if (!map.has(lga)) map.set(lga, []);
    map.get(lga)!.push(f);
  }
  return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b));
}

const QUALITY_STYLE: Record<string, string> = {
  developed: "bg-[#1A1A1A]/10 text-[#1A1A1A]",
  "less developed": "bg-[#8B2000]/10 text-[#8B2000]",
};

function qualityStyle(quality: string | null): string {
  return (
    QUALITY_STYLE[quality?.toLowerCase() ?? ""] ??
    "bg-surface-variant text-on-surface-variant"
  );
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
  const groups = groupByLGA(facilities);
  const activeRouteCount = routes.filter(
    (r) => !(r.omi_eko && r.total_base_duration === 9999)
  ).length;
  const jsonLd = buildJsonLd(facilities, destinationMap);

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <section className="max-w-5xl mx-auto px-4 py-12">

        {/* Page header */}
        <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-3">
          Lagos Ferry Terminals &amp; Routes
        </h1>
        <p className="text-base leading-6 text-on-surface-variant mb-4 max-w-2xl">
          Directory of all active ferry terminals in Lagos, Nigeria — with route connections and
          facility details. Use this guide to plan ferry journeys across Lagos Lagoon, including
          routes between Victoria Island (VI), Apapa, CMS, Ikorodu, Badore, Ajah, Lekki, and more.
        </p>

        {/* Stats bar */}
        <div className="flex items-center gap-2 text-sm text-on-surface-variant mb-10 flex-wrap">
          <span className="font-medium text-on-surface">{facilities.length}</span>
          <span>facilities</span>
          <span className="text-outline-variant mx-1">·</span>
          <span className="font-medium text-on-surface">{activeRouteCount}</span>
          <span>active route{activeRouteCount !== 1 ? "s" : ""}</span>
          <span className="text-outline-variant mx-1">·</span>
          <span className="font-medium text-on-surface">{groups.length}</span>
          <span>LGA{groups.length !== 1 ? "s" : ""}</span>
        </div>

        <div className="flex flex-col gap-10">
          {groups.map(([lga, items]) => (
            <div key={lga}>

              {/* LGA heading */}
              <div className="flex items-center gap-3 mb-3">
                <h2 className="text-[18px] font-medium text-on-surface">{lga}</h2>
                <span className="text-sm text-on-surface-variant">
                  {items.length} {items.length !== 1 ? "facilities" : "facility"}
                </span>
              </div>

              {/* Facility cards */}
              <div className="rounded-xl border border-outline-variant overflow-hidden divide-y divide-outline-variant">
                {items.map((facility) => {
                  const destinations = destinationMap.get(facility.facility_id) ?? [];
                  return (
                    <Link
                      key={facility.facility_id}
                      href={`/map/${toFacilitySlug(facility)}`}
                      className="flex flex-col gap-2 px-5 py-4 bg-surface hover:bg-on-surface/[0.04] transition-colors group"
                    >
                      {/* Name + badges row */}
                      <div className="flex items-center justify-between gap-4">
                        <div className="flex items-center gap-3 min-w-0">
                          <span className="text-[15px] font-medium text-on-surface group-hover:text-primary transition-colors truncate">
                            {facility.facility_name ?? "Unnamed"}
                          </span>
                          {(() => {
                            const isCharterOnly = facility.category?.includes("Charter only") ?? false;
                            const isFutureOmiEko = (facility.category?.includes("Future Omi Eko") ?? false) || (isCharterOnly && facility.omi_eko === "Yes");
                            if (isFutureOmiEko) return (
                              <span className="shrink-0 px-2 py-1 rounded-full bg-[#7B3F00]/15 text-[#7B3F00] text-xs font-bold">
                                Future OMI EKO
                              </span>
                            );
                            if (isCharterOnly) return (
                              <span className="shrink-0 px-2 py-1 rounded-full bg-[#7B3F00]/15 text-[#7B3F00] text-xs font-bold">
                                Charter Only
                              </span>
                            );
                            return null;
                          })()}
                          {facility.facility_type && (
                            <span className="hidden sm:inline-flex px-2 py-1 rounded-full bg-primary-container/50 text-on-primary-container text-xs font-medium tracking-[0.1px]">
                              {facility.facility_type} ({facility.quality})
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          <svg
                            width="16"
                            height="16"
                            viewBox="0 0 24 24"
                            fill="currentColor"
                            className="text-outline"
                          >
                            <path d="M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z" />
                          </svg>
                        </div>
                      </div>

                      {/* Destinations row */}
                      {destinations.length > 0 && (
                        <div className="flex flex-wrap items-center gap-1.5">
                          <span className="text-[11px] font-medium text-on-surface-variant/70 uppercase tracking-wide mr-0.5">
                            Routes to:
                          </span>
                          {destinations.map((dest) => (
                            <span
                              key={dest}
                              className="px-2 py-0.5 rounded-full bg-surface-variant text-on-surface-variant text-[12px]"
                            >
                              {dest}
                            </span>
                          ))}
                        </div>
                      )}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}
