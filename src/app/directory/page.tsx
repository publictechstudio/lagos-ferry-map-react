import type { Metadata } from "next";
import Link from "next/link";
import { getFacilities } from "@/lib/facilities";
import { toFacilitySlug } from "@/lib/facilitySlug";
import type { Facility } from "@/types/facility";

export const metadata: Metadata = {
  title: "Directory — Lagos Ferry Map",
  description: "Directory of all active Lagos ferry facilities, grouped by Local Government Area.",
};

export const revalidate = 3600;

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
  developed:      "bg-[#1A1A1A]/10 text-[#1A1A1A]",
  "less developed": "bg-[#8B2000]/10 text-[#8B2000]",
};

function qualityStyle(quality: string | null): string {
  return QUALITY_STYLE[quality?.toLowerCase() ?? ""] ?? "bg-surface-variant text-on-surface-variant";
}

export default async function DirectoryPage() {
  const facilities = await getFacilities();
  const groups = groupByLGA(facilities);

  return (
    <section className="max-w-5xl mx-auto px-4 py-12">
      {/* Page header */}
      <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-1">
        Ferry Directory
      </h1>
      <p className="text-base leading-6 text-on-surface-variant mb-10">
        {facilities.length} active facilit{facilities.length !== 1 ? "ies" : "y"} across{" "}
        {groups.length} LGA{groups.length !== 1 ? "s" : ""}.
      </p>

      <div className="flex flex-col gap-10">
        {groups.map(([lga, items]) => (
          <div key={lga}>
            {/* LGA heading */}
            <div className="flex items-center gap-3 mb-3">
              <h2 className="text-[18px] font-medium text-on-surface">{lga}</h2>
              <span className="text-sm text-on-surface-variant">
                {items.length} facilit{items.length !== 1 ? "ies" : "y"}
              </span>
            </div>

            {/* Facility rows */}
            <div className="rounded-xl border border-outline-variant overflow-hidden divide-y divide-outline-variant">
              {items.map((facility) => (
                <Link
                  key={facility.facility_id}
                  href={`/map/${toFacilitySlug(facility)}`}
                  className="flex items-center justify-between gap-4 px-5 py-4 bg-surface hover:bg-on-surface/[0.04] transition-colors group"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {/* Quality dot */}
                    <span
                      className="w-2.5 h-2.5 rounded-full shrink-0"
                      style={{
                        backgroundColor: facility.quality?.toLowerCase().startsWith("less")
                          ? "#8B2000"
                          : "#1A1A1A",
                      }}
                    />
                    <span className="text-[15px] font-medium text-on-surface group-hover:text-primary transition-colors truncate">
                      {facility.facility_name ?? "Unnamed"}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {/* Facility type chip */}
                    {facility.facility_type && (
                      <span className="hidden sm:inline-flex px-2.5 py-1 rounded-lg bg-primary-container text-on-primary-container text-xs font-medium tracking-[0.1px]">
                        {facility.facility_type}
                      </span>
                    )}
                    {/* Quality chip */}
                    {facility.quality && (
                      <span className={`hidden sm:inline-flex px-2.5 py-1 rounded-lg text-xs font-medium tracking-[0.1px] ${qualityStyle(facility.quality)}`}>
                        {facility.quality}
                      </span>
                    )}
                    {/* Chevron */}
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" className="text-outline">
                      <path d="M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z" />
                    </svg>
                  </div>
                </Link>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
