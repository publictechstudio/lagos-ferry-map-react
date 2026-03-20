"use client";

import { type Dispatch, type SetStateAction, useEffect, useRef, useState } from "react";
import type { Facility } from "@/types/facility";
import { CATEGORY_STYLES, COLOR_OMI_EKO } from "./LeafletMap";

interface FacilityListProps {
  facilities: Facility[];
  selected: Facility | null;
  onSelect: (facility: Facility) => void;
  hiddenLayers: Set<string>;
  setHiddenLayers: Dispatch<SetStateAction<Set<string>>>;
  onCollapsedChange?: (collapsed: boolean) => void;
}

type LegendItem = {
  key: string;
  color: string;
  label: string;
  info: string;
  icon?: "star";
};

const LEGEND_GROUPS: { active: LegendItem[]; other: LegendItem[] } = {
  active: [
    { key: "Ferry facility: Developed", color: CATEGORY_STYLES["Ferry facility: Developed"].color, label: "Developed", info: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Facilities with permanent structures and regular service." },
    { key: "Ferry facility: Less developed", color: CATEGORY_STYLES["Ferry facility: Less developed"].color, label: "Less Developed", info: "Lorem ipsum dolor sit amet. Facilities with basic infrastructure and limited amenities." },
  ],
  other: [
    { key: "Charter only", color: CATEGORY_STYLES["Charter only"].color, label: "Charter Only", info: "Lorem ipsum dolor sit amet. Locations offering private charter boat services only." },
    { key: "Omi Eko", color: COLOR_OMI_EKO, label: "Omi Eko", info: "Lorem ipsum dolor sit amet. Facilities participating in the Omi Eko programme.", icon: "star" },
  ],
};

function LegendRow({
  layerKey, color, label, info, icon, hiddenLayers, setHiddenLayers,
}: LegendItem & { layerKey: string; hiddenLayers: Set<string>; setHiddenLayers: Dispatch<SetStateAction<Set<string>>> }) {
  const visible = !hiddenLayers.has(layerKey);
  return (
    <div className="flex items-center gap-2">
      <label className="flex items-center gap-2 cursor-pointer flex-1 min-w-0">
        <input
          type="checkbox"
          checked={visible}
          onChange={() => setHiddenLayers((prev) => {
            const next = new Set(prev);
            if (next.has(layerKey)) next.delete(layerKey); else next.add(layerKey);
            return next;
          })}
          className="h-3.5 w-3.5 shrink-0 rounded accent-on-surface-variant"
        />
        {icon === "star" ? (
          <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden className={`shrink-0 ${visible ? "opacity-100" : "opacity-40"}`}>
            <polygon
              points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"
              fill={color} stroke="#000000" strokeWidth="2" strokeLinejoin="round"
            />
          </svg>
        ) : (
          <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden className={`shrink-0 ${visible ? "opacity-100" : "opacity-40"}`}>
            <circle cx="7" cy="7" r="5.5" fill={color} fillOpacity={0.8} stroke="white" strokeWidth="1.5" />
          </svg>
        )}
        <span className={`text-xs truncate ${visible ? "text-on-surface-variant" : "text-on-surface-variant/50"}`}>
          {label}
        </span>
      </label>
      <span className="relative shrink-0 group">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" className="text-on-surface-variant/40 hover:text-on-surface-variant cursor-help transition-colors" aria-label={`Info: ${label}`}>
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
        </svg>
        <span className="pointer-events-none absolute right-6 top-1/2 -translate-y-1/2 z-[950] w-48 rounded-lg bg-on-surface text-surface text-[11px] leading-snug px-3 py-2 shadow-elevation-3 opacity-0 group-hover:opacity-100 transition-opacity">
          {info}
        </span>
      </span>
    </div>
  );
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
  hiddenLayers,
  setHiddenLayers,
  onCollapsedChange,
}: FacilityListProps) {
  // Track which LGA groups are open; collapsed by default
  const groups = groupByLGA(facilities);
  const [open, setOpen] = useState<Set<string>>(() => new Set());
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    onCollapsedChange?.(collapsed);
  }, [collapsed, onCollapsedChange]);

  // Search state
  const [query, setQuery] = useState("");
  const [showSuggestions, setShowSuggestions] = useState(false);
  const searchRef = useRef<HTMLDivElement>(null);

  const { suggestions, lgaStartIndex } = (() => {
    const q = query.trim().toLowerCase();
    if (!q) return { suggestions: [] as Facility[], lgaStartIndex: -1 };
    const nameMatches = facilities.filter((f) =>
      (f.facility_name ?? "").toLowerCase().includes(q)
    );
    const nameMatchIds = new Set(nameMatches.map((f) => f.facility_id));
    const lgaMatches = facilities.filter(
      (f) =>
        !nameMatchIds.has(f.facility_id) &&
        (f.lga ?? "").toLowerCase().includes(q)
    );
    const combined = [...nameMatches, ...lgaMatches].slice(0, 8);
    const lgaStart =
      lgaMatches.length > 0 && nameMatches.length < combined.length
        ? Math.min(nameMatches.length, combined.length)
        : -1;
    return { suggestions: combined, lgaStartIndex: lgaStart };
  })();

  function handleSuggestionSelect(facility: Facility) {
    onSelect(facility);
    setQuery("");
    setShowSuggestions(false);
  }

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
        // Mobile — flex child at bottom of column; height collapses to just the handle
        "shrink-0",
        collapsed ? "h-10" : "h-[50vh]",
        "transition-[height] duration-300 ease-in-out",
        // Desktop — absolute left panel inside the map container (height always full)
        "md:absolute md:inset-y-0 md:left-0 md:right-auto md:h-full md:w-72",
        // z-[1001] sits above Leaflet's attribution/control layer (z-1000)
        // overflow-visible on mobile so search suggestions can extend above the panel
        "z-[1001] flex flex-col overflow-visible md:overflow-hidden",
        "bg-surface shadow-elevation-3",
        // Mobile: rounded top corners only; desktop: rounded right corners
        "rounded-t-[20px] md:rounded-t-none md:rounded-r-none md:rounded-l-xl",
      ].join(" ")}
    >
      {/* Mobile drag handle — tap to collapse / expand */}
      <button
        className="md:hidden flex justify-center pt-2.5 pb-1 shrink-0 w-full"
        onClick={() => setCollapsed((c) => !c)}
        aria-label={collapsed ? "Expand facilities list" : "Collapse facilities list"}
      >
        <div className="w-8 h-1 rounded-full bg-on-surface-variant/30" />
      </button>

      {/* Panel header + list — hidden while collapsed on mobile */}
      {!collapsed && (
        <>
      {/* Panel header */}
      <div className="px-4 py-3 border-b border-outline-variant shrink-0">
        <p className="text-xs text-on-surface-variant mt-0.5">
          Click the map to explore or search for a ferry facility by name
        </p>

        {/* Facility search */}
        <div ref={searchRef} className="relative mt-3">
          <div className="relative">
            <svg
              className="absolute left-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant pointer-events-none"
              width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden
            >
              <path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14" />
            </svg>
            <input
              type="search"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setShowSuggestions(true);
              }}
              onFocus={() => setShowSuggestions(true)}
              onBlur={() => setTimeout(() => setShowSuggestions(false), 150)}
              onKeyDown={(e) => {
                if (e.key === "Escape") { setQuery(""); setShowSuggestions(false); }
              }}
              placeholder="e.g. Five Cowries Creek"
              className="w-full pl-8 pr-3 py-1.5 text-[13px] bg-surface-variant rounded-lg border border-outline-variant focus:outline-none focus:border-primary text-on-surface placeholder:text-on-surface-variant/60"
            />
          </div>

          {/* Suggestions dropdown */}
          {showSuggestions && suggestions.length > 0 && (
            <ul className="absolute left-0 right-0 bottom-full mb-1 md:bottom-auto md:mb-0 md:top-full md:mt-1 bg-surface border border-outline-variant rounded-lg shadow-elevation-2 overflow-hidden z-10">
              {suggestions.map((facility, i) => (
                <>
                  {i === lgaStartIndex && (
                    <li key="lga-divider" className="px-3 py-1 border-t border-outline-variant bg-surface-variant/50">
                      <span className="text-[10px] font-medium uppercase tracking-wide text-on-surface-variant">
                        Facilities in matching LGA
                      </span>
                    </li>
                  )}
                  <li key={facility.facility_id}>
                    <button
                      onMouseDown={() => handleSuggestionSelect(facility)}
                      className="w-full text-left px-3 py-2 flex items-center gap-2 hover:bg-on-surface/[0.06] transition-colors"
                    >
                      <span
                        className="w-2 h-2 rounded-full shrink-0"
                        style={{
                          backgroundColor: facility.quality?.toLowerCase().startsWith("less")
                            ? "#8B2000"
                            : "#1A1A1A",
                        }}
                      />
                      <span className="text-[13px] text-on-surface truncate">
                        {facility.facility_name ?? "Unnamed"}
                      </span>
                      <span className="text-[11px] text-on-surface-variant ml-auto shrink-0">
                        {facility.lga}
                      </span>
                    </button>
                  </li>
                </>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* Scrollable list */}
      <div className="overflow-y-auto flex-1">
        {/* ── Map layers legend ── */}
        <div className="px-4 pt-3 pb-2 border-b border-outline-variant">
          <p className="text-[13px] font-medium text-on-surface mb-2">Map Layers</p>

          <p className="text-[11px] font-semibold text-on-surface-variant/70 uppercase tracking-wide mb-1">
            Active Ferry Facilities
          </p>
          <div className="flex flex-col gap-1.5 mb-2.5">
            {LEGEND_GROUPS.active.map(({ key, color, label, info }) => (
              <LegendRow key={key} layerKey={key} color={color} label={label} info={info} hiddenLayers={hiddenLayers} setHiddenLayers={setHiddenLayers} />
            ))}
          </div>

          <p className="text-[11px] font-semibold text-on-surface-variant/70 uppercase tracking-wide mb-1">
            Other
          </p>
          <div className="flex flex-col gap-1.5">
            {LEGEND_GROUPS.other.map(({ key, color, label, info, icon }) => (
              <LegendRow key={key} layerKey={key} color={color} label={label} info={info} icon={icon} hiddenLayers={hiddenLayers} setHiddenLayers={setHiddenLayers} />
            ))}
          </div>
        </div>

        <div className="px-4 pt-3">
          <p className="text-xs text-on-surface-variant">
            Explore by LGA
          </p>
        </div>
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
        </>
      )}
    </div>
  );
}
