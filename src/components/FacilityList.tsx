"use client";

import { useState } from "react";
import type { Facility } from "@/types/facility";

interface FacilityListProps {
  facilities: Facility[];
  selected: Facility | null;
  onSelect: (facility: Facility) => void;
}

/** Group facilities by LGA, preserving alphabetical order within each group. */
function groupByLGA(facilities: Facility[]): [string, Facility[]][] {
  const map = new Map<string, Facility[]>();
  for (const f of facilities) {
    const lga = f.lga ?? "Unknown LGA";
    if (!map.has(lga)) map.set(lga, []);
    map.get(lga)!.push(f);
  }
  return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b));
}

export default function FacilityList({
  facilities,
  selected,
  onSelect,
}: FacilityListProps) {
  // Track which LGA groups are open; collapsed by default
  const groups = groupByLGA(facilities);
  const [open, setOpen] = useState<Set<string>>(() => new Set());

  function toggle(lga: string) {
    setOpen((prev) => {
      const next = new Set(prev);
      if (next.has(lga)) next.delete(lga);
      else next.add(lga);
      return next;
    });
  }

  return (
    /*
     * Desktop: absolute left panel (sits over the map).
     * Mobile:  fixed bottom sheet covering the bottom half of the viewport.
     *
     * The parent div in MapWrapper must be `relative` for `md:absolute` to work.
     */
    <div
      className={[
        // Mobile — fixed bottom sheet
        "fixed bottom-0 left-0 right-0 h-[50vh]",
        // Desktop — absolute left panel inside the map container
        "md:absolute md:inset-y-0 md:left-0 md:right-auto md:h-full md:w-72",
        // Shared styles
        "z-[800] flex flex-col",
        "bg-surface shadow-elevation-3",
        // Mobile: rounded top corners only; desktop: rounded right corners
        "rounded-t-[20px] md:rounded-t-none md:rounded-r-none md:rounded-l-xl",
      ].join(" ")}
    >
      {/* Mobile drag handle */}
      <div className="md:hidden flex justify-center pt-2.5 pb-1 shrink-0">
        <div className="w-8 h-1 rounded-full bg-on-surface-variant/30" />
      </div>

      {/* Panel header */}
      <div className="px-4 py-3 border-b border-outline-variant shrink-0">
        <p className="text-xs text-on-surface-variant mt-0.5">
          Click the map or explore ferry facilities by LGA
        </p>
      </div>

      {/* Scrollable list */}
      <div className="overflow-y-auto flex-1">
        {groups.map(([lga, items]) => (
          <div key={lga}>
            {/* LGA accordion header */}
            <button
              onClick={() => toggle(lga)}
              className="w-full flex items-center justify-between px-4 py-2.5 text-left hover:bg-on-surface/[0.06] transition-colors"
              aria-expanded={open.has(lga)}
            >
              <span className="text-[13px] font-medium tracking-[0.1px] text-on-surface">
                {lga}
              </span>
              <span className="flex items-center gap-1.5">
                <span className="text-[11px] text-on-surface-variant">
                  {items.length}
                </span>
                {/* Chevron rotates when open */}
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  className={`text-on-surface-variant transition-transform duration-200 ${
                    open.has(lga) ? "rotate-180" : ""
                  }`}
                >
                  <path d="M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6z" />
                </svg>
              </span>
            </button>

            {/* Facility rows */}
            {open.has(lga) && (
              <ul>
                {items.map((facility) => {
                  const isSelected = selected?.facility_id === facility.facility_id;
                  return (
                    <li key={facility.facility_id}>
                      <button
                        onClick={() => onSelect(facility)}
                        className={[
                          "w-full text-left px-6 py-2 flex items-center gap-2 transition-colors",
                          isSelected
                            ? "bg-primary/[0.12] text-primary"
                            : "hover:bg-on-surface/[0.06] text-on-surface",
                        ].join(" ")}
                      >
                        {/* Quality dot */}
                        <span
                          className="w-2 h-2 rounded-full shrink-0"
                          style={{
                            backgroundColor:
                              facility.quality?.toLowerCase().startsWith("less")
                                ? "#8B2000"
                                : "#1A1A1A",
                          }}
                        />
                        <span className="text-[13px] leading-5 truncate">
                          {facility.facility_name ?? "Unnamed"}
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
