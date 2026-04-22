"use client";

import { useState } from "react";
import Link from "next/link";
import { ClickableRow } from "@/components/ClickableRow";
import { toRouteSlug } from "@/lib/routeSlug";
import type { Route } from "@/types/route";

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

type FilterKey = "origin" | "destination" | "operator";

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

export function RoutesTable({ routes }: { routes: Route[] }) {
  const [filters, setFilters] = useState<Record<FilterKey, string>>({
    origin: "", destination: "", operator: "",
  });
  const [open, setOpen] = useState<Record<FilterKey, boolean>>({
    origin: false, destination: false, operator: false,
  });

  const toggle = (key: FilterKey) =>
    setOpen((prev) => ({ ...prev, [key]: !prev[key] }));

  const setFilter = (key: FilterKey) => (v: string) =>
    setFilters((prev) => ({ ...prev, [key]: v }));

  const visible = routes.filter((r) => {
    const origin = r.origin_name ?? "";
    const destination = r.destination_name ?? "";
    const operator = r.operator ?? "";
    return (
      origin.toLowerCase().includes(filters.origin.toLowerCase()) &&
      destination.toLowerCase().includes(filters.destination.toLowerCase()) &&
      operator.toLowerCase().includes(filters.operator.toLowerCase())
    );
  });

  return (
    <div className="rounded-xl border border-outline-variant overflow-hidden">
      <div className="overflow-y-auto max-h-[900px]">
        <table className="w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface-variant border-b border-outline-variant">
            <tr>
              <FilterTh label="Origin" value={filters.origin} open={open.origin} onToggle={() => toggle("origin")} onChange={setFilter("origin")} />
              <FilterTh label="Destination" value={filters.destination} open={open.destination} onToggle={() => toggle("destination")} onChange={setFilter("destination")} />
              <FilterTh label="Operator" value={filters.operator} open={open.operator} onToggle={() => toggle("operator")} onChange={setFilter("operator")} />
            </tr>
          </thead>
          <tbody className="divide-y divide-outline-variant/60">
            {visible.map((route) => (
              <ClickableRow key={route.route_id} href={`/map/route/${toRouteSlug(route)}`}>
                <td className="px-4 py-3 text-on-surface whitespace-nowrap">
                  <Link href={`/map/route/${toRouteSlug(route)}`} className="group-hover:text-primary transition-colors">
                    {route.origin_name ?? "—"}
                  </Link>
                </td>
                <td className="px-4 py-3 text-on-surface whitespace-nowrap">{route.destination_name ?? "—"}</td>
                <td className="px-4 py-3 text-on-surface-variant">
                  {(() => {
                    const op = route.operator ?? "";
                    const idx = op.indexOf(":");
                    if (idx === -1) return op || "—";
                    const before = op.slice(0, idx).trim();
                    const after = op.slice(idx + 1).trim();
                    return (
                      <span className="flex items-center gap-1.5">
                        <span>{before}</span>
                        {after && (
                          <span className="group relative shrink-0">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" className="text-on-surface-variant/40 group-hover:text-on-surface-variant transition-colors cursor-default">
                              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/>
                            </svg>
                            <span className="pointer-events-none absolute bottom-full right-0 mb-1.5 w-max max-w-[220px] rounded-lg bg-on-surface px-3 py-1.5 text-xs text-surface opacity-0 group-hover:opacity-100 transition-opacity z-20 text-center leading-snug">
                              {after}
                            </span>
                          </span>
                        )}
                      </span>
                    );
                  })()}
                </td>
              </ClickableRow>
            ))}
            {visible.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-6 text-center text-on-surface-variant/60 text-sm">
                  No routes match the current filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
