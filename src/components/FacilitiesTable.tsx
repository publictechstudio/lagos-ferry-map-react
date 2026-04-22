"use client";

import { useState } from "react";
import Link from "next/link";
import { ClickableRow } from "@/components/ClickableRow";
import { toFacilitySlug } from "@/lib/facilitySlug";
import type { Facility } from "@/types/facility";

function facilityLabel(facility: Facility): "future-omi-eko" | "charter-only" | null {
  const isCharterOnly = facility.category?.includes("Charter only") ?? false;
  const isFutureOmiEko =
    (facility.category?.includes("Future Omi Eko") ?? false) ||
    (isCharterOnly && facility.omi_eko === "Yes");
  if (isFutureOmiEko) return "future-omi-eko";
  if (isCharterOnly) return "charter-only";
  return null;
}

function destinationText(facility: Facility, destinationMap: Record<number, string[]>): string {
  const label = facilityLabel(facility);
  if (label === "future-omi-eko") return "Future OMI EKO";
  if (label === "charter-only") return "Charter Only";
  return (destinationMap[facility.facility_id] ?? []).join(" ");
}

function FilterIcon({ active }: { active: boolean }) {
  return (
    <svg
      width="14" height="14" viewBox="0 0 24 24" fill="currentColor"
      className={active ? "text-primary" : "text-on-surface-variant/50"}
    >
      <path d="M4.25 5.61C6.27 8.2 10 13 10 13v6c0 .55.45 1 1 1h2c.55 0 1-.45 1-1v-6s3.72-4.8 5.74-7.39A.998.998 0 0 0 18.95 4H5.04a1 1 0 0 0-.79 1.61z" />
    </svg>
  );
}

type FilterKey = "lga" | "name" | "type" | "destinations";

function FilterTh({
  label, value, open, onToggle, onChange,
}: {
  label: string;
  value: string;
  open: boolean;
  onToggle: () => void;
  onChange: (v: string) => void;
}) {
  return (
    <th className="text-left px-4 py-3 whitespace-nowrap">
      <div className="flex items-center gap-1.5">
        <span className="font-medium text-on-surface-variant text-xs uppercase tracking-wide">{label}</span>
        <button
          onClick={onToggle}
          className="shrink-0 p-0.5 rounded hover:bg-on-surface/10 transition-colors"
          aria-label={`Filter by ${label}`}
        >
          <FilterIcon active={value !== ""} />
        </button>
      </div>
      {open && (
        <input
          autoFocus
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Filter…"
          className="mt-1.5 w-full bg-transparent border-b border-outline-variant text-sm text-on-surface placeholder:text-on-surface-variant/40 focus:outline-none focus:border-primary pb-0.5"
        />
      )}
    </th>
  );
}

export function FacilitiesTable({
  facilities,
  destinationMap,
}: {
  facilities: Facility[];
  destinationMap: Record<number, string[]>;
}) {
  const [filters, setFilters] = useState<Record<FilterKey, string>>({
    lga: "", name: "", type: "", destinations: "",
  });
  const [open, setOpen] = useState<Record<FilterKey, boolean>>({
    lga: false, name: false, type: false, destinations: false,
  });

  const toggle = (key: FilterKey) =>
    setOpen((prev) => ({ ...prev, [key]: !prev[key] }));

  const setFilter = (key: FilterKey) => (v: string) =>
    setFilters((prev) => ({ ...prev, [key]: v }));

  const visible = facilities.filter((f) => {
    const lga = f.lga ?? "";
    const name = f.facility_name ?? "";
    const type = f.facility_type ?? "";
    const dests = destinationText(f, destinationMap);
    return (
      lga.toLowerCase().includes(filters.lga.toLowerCase()) &&
      name.toLowerCase().includes(filters.name.toLowerCase()) &&
      type.toLowerCase().includes(filters.type.toLowerCase()) &&
      dests.toLowerCase().includes(filters.destinations.toLowerCase())
    );
  });

  return (
    <div className="rounded-xl border border-outline-variant overflow-hidden">
      <div className="overflow-y-auto max-h-[900px]">
        <table className="w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface-variant border-b border-outline-variant">
            <tr>
              <FilterTh label="LGA" value={filters.lga} open={open.lga} onToggle={() => toggle("lga")} onChange={setFilter("lga")} />
              <FilterTh label="Facility Name" value={filters.name} open={open.name} onToggle={() => toggle("name")} onChange={setFilter("name")} />
              <FilterTh label="Facility Type" value={filters.type} open={open.type} onToggle={() => toggle("type")} onChange={setFilter("type")} />
              <FilterTh label="Destinations" value={filters.destinations} open={open.destinations} onToggle={() => toggle("destinations")} onChange={setFilter("destinations")} />
            </tr>
          </thead>
          <tbody className="divide-y divide-outline-variant/60">
            {visible.map((facility) => {
              const destinations = destinationMap[facility.facility_id] ?? [];
              const label = facilityLabel(facility);
              const href = `/map/${toFacilitySlug(facility)}`;
              return (
                <ClickableRow key={facility.facility_id} href={href}>
                  <td className="px-4 py-3 text-on-surface-variant whitespace-nowrap align-top">{facility.lga ?? "—"}</td>
                  <td className="px-4 py-3 align-top">
                    <Link href={href} className="font-medium text-on-surface group-hover:text-primary transition-colors">
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
                          <span key={dest} className="px-2 py-0.5 rounded-full bg-surface-variant text-on-surface-variant text-xs">
                            {dest}
                          </span>
                        ))}
                      </div>
                    )}
                    {label === null && destinations.length === 0 && (
                      <span className="text-on-surface-variant/50">—</span>
                    )}
                  </td>
                </ClickableRow>
              );
            })}
            {visible.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-on-surface-variant/60 text-sm">
                  No facilities match the current filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
