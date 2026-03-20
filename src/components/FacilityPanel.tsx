"use client";

import { useEffect, useState } from "react";
import type { Facility } from "@/types/facility";
import type { Destination } from "@/types/destination";
import type { ConnectingRoute } from "@/types/connectingRoute";
import type { RoutePeriod } from "@/types/routePeriod";
import Link from "next/link";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";
import PlaceIcon from '@mui/icons-material/Place';
import DirectionsBoatIcon from "@mui/icons-material/DirectionsBoat";

const REPORT_FORM_URL =
  "https://docs.google.com/forms/d/e/1FAIpQLSfCkMgguEE1GJ_WhWXBaIKhaILOICt1UqiA85r0m4yz_eEmAw/viewform";

const OPERATOR_MAP: Record<string, { label: string; tooltip: string }> = {
  "LagFerry/Government: Operated by the government": {
    label: "LagFerry",
    tooltip: "Operated by the government",
  },
  "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)": {
    label: "Licensed Commercial",
    tooltip: "Licensed commercial operators under the jurisdiction/licensed by LASWA or NIWA",
  },
  "Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)": {
    label: "Unlicensed Commercial",
    tooltip: "Unlicensed commercial operators not under the jurisdiction/licensed by LASWA or NIWA",
  },
};

/** Key attributes shown inline under the title. */
const KEY_ATTRS: { key: keyof Facility; label: string }[] = [
  { key: "lga",       label: "LGA" },
  { key: "quality",   label: "Facility Quality" },
  { key: "facility_type", label: "Type" },
];

function summarizePeriods(periods: RoutePeriod[]): string {
  if (periods.length === 0) return "";

  // Aggregate active days and morning/evening flags across all periods
  let mo = false, tu = false, we = false, th = false, fr = false, sa = false, su = false;
  let hasMorning = false, hasEvening = false;
  for (const p of periods) {
    if (p.monday)    mo = true;
    if (p.tuesday)   tu = true;
    if (p.wednesday) we = true;
    if (p.thursday)  th = true;
    if (p.friday)    fr = true;
    if (p.saturday)  sa = true;
    if (p.sunday)    su = true;
    if (p.morning_service) hasMorning = true;
    if (p.evening_service) hasEvening = true;
  }

  // Format the day range
  let days: string;
  if (mo && tu && we && th && fr && sa && su)  days = "Daily";
  else if (mo && tu && we && th && fr && !sa && !su) days = "Mon–Fri";
  else if (!mo && !tu && !we && !th && !fr && sa && su) days = "Sat–Sun";
  else if (mo && tu && we && th && fr && sa && !su)  days = "Mon–Sat";
  else {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    days = names.filter((_, i) => [mo, tu, we, th, fr, sa, su][i]).join(", ");
  }

  // Format the time-of-day coverage
  const time =
    hasMorning && hasEvening ? "all day" :
    hasMorning               ? "mornings only" :
    hasEvening               ? "evenings only" : "";

  return time ? `${days} · ${time}` : days;
}

function routeDisplayNames(route: ConnectingRoute): { from: string; to: string } {
  if (route.travel_direction === "Outbound") {
    return {
      from: route.destination_name_short ?? "?",
      to:   route.origin_name_short      ?? "?",
    };
  }
  return {
    from: route.origin_name_short      ?? "?",
    to:   route.destination_name_short ?? "?",
  };
}

function OperatorLabel({ operator }: { operator: string | null }) {
  if (!operator) return <span>—</span>;
  const mapped = OPERATOR_MAP[operator];
  if (!mapped) return <span>{operator}</span>;
  return (
    <span className="inline-flex items-center gap-1">
      {mapped.label}
      <span className="relative group/tip cursor-help shrink-0">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" className="text-on-surface-variant/50">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
        </svg>
        <span className="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 w-48 rounded bg-on-surface px-2.5 py-1.5 text-[11px] leading-4 text-surface shadow-md opacity-0 group-hover/tip:opacity-100 transition-opacity z-50">
          {mapped.tooltip}
        </span>
      </span>
    </span>
  );
}

interface DestinationCardProps {
  dest: Destination;
  facility: Facility;
  routesByDest: Map<number, ConnectingRoute[]>;
  periodsByRoute: Map<number, RoutePeriod[]>;
}

function DestinationCard({ dest, facility, routesByDest, periodsByRoute }: DestinationCardProps) {
  const [open, setOpen] = useState(false);
  const routes = routesByDest.get(dest.facility_id);

  return (
    <div className="rounded-xl border border-outline-variant bg-surface overflow-hidden">
      {/* Accordion trigger */}
      <button
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="w-full flex items-center justify-between gap-3 px-4 py-3 text-left hover:bg-on-surface/[0.04] transition-colors"
      >
        <span className="text-[15px] font-semibold text-on-surface leading-5">
          {dest.facility_name ?? "Unnamed"}
        </span>
        <svg
          viewBox="0 0 24 24"
          fill="currentColor"
          className={`w-4 h-4 shrink-0 text-on-surface-variant transition-transform duration-200 ${open ? "rotate-180" : ""}`}
          aria-hidden
        >
          <path d="M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z" />
        </svg>
      </button>

      {/* Collapsible body */}
      {open && (
        <>
          {/* View on map link */}
          <a
            href={`/map/${toFacilitySlug(dest)}`}
            className="flex items-center gap-2 px-4 py-2.5 text-primary text-sm hover:bg-primary/[0.06] transition-colors border-t border-outline-variant/60"
          >
            <PlaceIcon sx={{ fontSize: 16 }} className="shrink-0" />
            More info on this destination
          </a>

          {/* Connecting routes */}
          <div className="border-t border-outline-variant/60">
            <div className="flex items-center gap-2 px-4 pt-2.5 pb-1 text-on-surface-variant text-sm">
              <DirectionsBoatIcon sx={{ fontSize: 16 }} className="shrink-0" />
              <span>Routes that will take you from {facility.facility_name_short} to {dest.facility_name_short ?? "destination"}</span>
            </div>
            {!routes ? (
              <p className="px-4 pb-2.5 text-xs text-on-surface-variant/60">Loading routes…</p>
            ) : routes.length === 0 ? (
              <p className="px-4 pb-2.5 text-xs text-on-surface-variant/60">No direct routes recorded.</p>
            ) : (
              <div className="pb-3 overflow-x-auto">
                <table className="w-full text-xs border-collapse">
                  <thead>
                    <tr className="border-b border-outline-variant/60 text-on-surface-variant/70 text-left">
                      <th className="px-4 py-1.5 font-medium">Route</th>
                      <th className="px-2 py-1.5 font-medium">Operator</th>
                      <th className="px-2 py-1.5 font-medium">Price</th>
                      <th className="px-2 py-1.5 font-medium">Schedule</th>
                      <th className="px-2 py-1.5 font-medium"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {routes.map((r) => {
                      const allPeriods = periodsByRoute.get(r.route_id) ?? [];
                      const periods = allPeriods.filter((p) => p.direction_id === r.travel_direction);
                      const schedule = summarizePeriods(periods);
                      const { from, to } = routeDisplayNames(r);
                      return (
                        <tr key={r.route_id} className="border-b border-outline-variant/40 last:border-b-0 align-top">
                          <td className="px-4 py-2">
                            <Link href={`/map/route/${toRouteSlug(r)}`} className="font-medium text-primary hover:underline underline-offset-2">
                              {from} → {to}
                            </Link>
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant">
                            <OperatorLabel operator={r.operator} />
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant whitespace-nowrap">
                            {r.total_base_cost != null ? `₦${r.total_base_cost.toLocaleString()}` : "—"}
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant">
                            {schedule || "—"}
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant">
                            <Link href={`/map/route/${toRouteSlug(r)}`} className="font-medium text-primary hover:underline underline-offset-2">
                              Click for full details
                            </Link>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function groupByLGA(destinations: Destination[]): [string, Destination[]][] {
  const map = new Map<string, Destination[]>();
  for (const d of destinations) {
    const lga = d.lga ?? "Unknown";
    if (!map.has(lga)) map.set(lga, []);
    map.get(lga)!.push(d);
  }
  return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b));
}

interface Props {
  facility: Facility;
  onClose: () => void;
}

export default function FacilityPanel({ facility, onClose }: Props) {
  const [destinations, setDestinations] = useState<Destination[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [routesByDest, setRoutesByDest] = useState<Map<number, ConnectingRoute[]>>(new Map());
  const [periodsByRoute, setPeriodsByRoute] = useState<Map<number, RoutePeriod[]>>(new Map());

  useEffect(() => {
    setLoading(true);
    setDestinations(null);
    setRoutesByDest(new Map());
    setPeriodsByRoute(new Map());
    fetch(`/api/facility-panel/${facility.facility_id}`)
      .then((r) => r.json())
      .then(({ destinations, routesByDest, periodsByRoute }: {
        destinations: Destination[];
        routesByDest: Record<string, ConnectingRoute[]>;
        periodsByRoute: Record<string, RoutePeriod[]>;
      }) => {
        setDestinations(destinations);
        setRoutesByDest(new Map(Object.entries(routesByDest).map(([k, v]) => [Number(k), v])));
        setPeriodsByRoute(new Map(Object.entries(periodsByRoute).map(([k, v]) => [Number(k), v])));
        setLoading(false);
      })
      .catch(() => {
        setDestinations([]);
        setLoading(false);
      });
  }, [facility.facility_id]);

  const keyAttrValues = KEY_ATTRS.filter(
    ({ key }) => facility[key] != null && facility[key] !== ""
  );

  const groups = groupByLGA(destinations ?? []);

  return (
    /*
     * Layout contract (set by parent MapWrapper):
     *   mobile  (flex-col parent): h-1/2, full width
     *   desktop (flex-row parent): h-full, w-1/2
     */
    <div className="h-2/3 shrink-0 md:h-full md:w-1/2 flex flex-col bg-surface border-t border-outline-variant md:border-t-0 md:border-l overflow-hidden">

      {/* Mobile drag handle */}
      <div className="md:hidden flex justify-center pt-2.5 pb-1 shrink-0">
        <div className="w-8 h-1 rounded-full bg-on-surface-variant/30" />
      </div>

      {/* Type label + close button */}
      <div className="flex items-center justify-between px-4 pt-4 pb-1 shrink-0">
        <div className="flex items-center gap-1.5 text-on-surface-variant">
          <PlaceIcon sx={{ fontSize: 16 }} className="shrink-0" />
          <span className="text-sm">{facility.facility_type ?? "Ferry Facility"}</span>
        </div>
                <div className="inline-flex items-center">
          {/* Report data issue */}
          <div className="inline-flex items-center mb-0 w-42 text-xs font-semibold leading-6 text-white bg-[#012c57] group-hover:bg-[#1976D2] rounded-full px-5 py-2.5 transition-colors duration-200">
            <a
              href={REPORT_FORM_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5"
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                <path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" />
              </svg>
              Report a data issue
            </a>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-on-surface/8 text-on-surface-variant transition-colors"
            aria-label="Close"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
        </div>
      </div>

      {/* Facility name */}
      <h1 className="px-4 pb-2 text-[22px] font-bold leading-7 text-on-surface shrink-0">
        {facility.facility_name ?? "Unnamed Facility"}
      </h1>

      {/* Scrollable body */}
      <div className="overflow-y-auto flex-1 px-4 py-4">

        {/* Two-column on desktop: image left, key attrs right */}
        <div className="md:flex md:gap-4 mb-4">
          {/* Image */}
          {facility.image_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={facility.image_url}
              alt={facility.facility_name ?? "Facility"}
              className="w-full h-48 object-cover rounded-lg mb-3 md:mb-0 md:w-1/2 md:shrink-0"
            />
          )}

          {/* Key attributes + Google Maps link */}
          <div className="flex flex-col justify-start h-48 rounded-lg mb-3 md:mb-0 md:w-1/2 md:shrink-0 bg-primary/[0.1]">
            {keyAttrValues.length > 0 && (
              <div className="text-sm text-on-surface-variant mb-3 flex flex-col gap-1 px-4 py-4">
                {keyAttrValues.map(({ key, label }) => (
                  <p key={key as string}>
                    <span className="font-semibold text-on-surface">{label}:</span>{" "}
                    {String(facility[key])}
                  </p>
                ))}
              </div>
            )}

            {facility.google_maps_url && (
              <a
                href={facility.google_maps_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center px-4 text-primary text-sm font-medium hover:underline underline-offset-2"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z" />
                </svg>
                View on Google Maps
              </a>
            )}
          </div>
        </div>

        {/* ── Destinations section ─────────────────────────────────── */}
        <h3 className="text-[15px] font-semibold text-on-surface mb-3 leading-5">
          From this facility, you can get to the following destinations
        </h3>

        {loading ? (
          <div className="flex items-center gap-2 text-on-surface-variant text-sm py-4">
            <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin shrink-0" />
            Loading destinations…
          </div>
        ) : groups.length === 0 ? (
          <p className="text-sm text-on-surface-variant py-2">
            No destinations recorded for this facility.
          </p>
        ) : (
          <div className="flex flex-col gap-5">
            {groups.map(([lga, items]) => (
              <div key={lga}>
                {/* LGA section header */}
                <p className="text-[13px] text-on-surface-variant mb-2">
                  {lga} LGA
                </p>

                {/* Destination cards */}
                <div className="flex flex-col gap-2">
                  {items.map((dest) => (
                    <DestinationCard
                      key={dest.facility_id}
                      dest={dest}
                      facility={facility}
                      routesByDest={routesByDest}
                      periodsByRoute={periodsByRoute}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
