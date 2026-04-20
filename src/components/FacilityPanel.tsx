"use client";

import { useEffect, useState } from "react";
import type { Facility } from "@/types/facility";
import type { Destination } from "@/types/destination";
import type { ConnectingRoute } from "@/types/connectingRoute";
import type { RoutePeriod } from "@/types/routePeriod";
import Link from "next/link";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";
import type { FacilityPanelData } from "@/lib/facilityPanel";
import PanelShell from "./PanelShell";
import LoadingSpinner from "./LoadingSpinner";
import { groupByLGA } from "@/lib/groupByLGA";
import { formatNaira } from "@/lib/format";
import PlaceIcon from '@mui/icons-material/Place';
import DirectionsBoatIcon from "@mui/icons-material/DirectionsBoat";

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
  if (mo && tu && we && th && fr && sa && su)  days = "Mon-Sun";
  else if (mo && tu && we && th && fr && !sa && !su) days = "Mon–Fri";
  else if (!mo && !tu && !we && !th && !fr && sa && su) days = "Sat–Sun";
  else if (mo && tu && we && th && fr && sa && !su)  days = "Mon–Sat";
  else {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    days = names.filter((_, i) => [mo, tu, we, th, fr, sa, su][i]).join(", ");
  }

  // Format the time-of-day coverage
  const time =
    hasMorning && hasEvening ? "All day" :
    hasMorning               ? "Morning only" :
    hasEvening               ? "Evening only" : "";

  return time ? `${days} · ${time}` : days;
}

function routeDisplayNames(route: ConnectingRoute): { from: string; to: string } {
  if (route.travel_direction == 0) {
    return {
      from: route.origin_name_short ?? "?",
      to:   route.destination_name_short ?? "?",
    };
  }
  return {
    from: route.destination_name_short ?? "?",
    to:   route.origin_name_short ?? "?",
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
        <span className="pointer-events-none absolute top-full right-0 mt-1.5 w-48 rounded bg-on-surface px-2.5 py-1.5 text-[11px] leading-4 text-surface shadow-md opacity-0 group-hover/tip:opacity-100 transition-opacity z-50">
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
    <div className="rounded-xl border border-outline-variant bg-surface overflow-visible">
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
              <div className="pb-3 overflow-visible">
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
                      console.log(`[FacilityPanel] route_id=${r.route_id} travel_direction="${r.travel_direction}" — allPeriods:`, allPeriods.length, "direction_ids in allPeriods:", allPeriods.map(p => ({ direction_id: p.direction_id, type: typeof p.direction_id })), "matched periods after filter:", periods.length);
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
                            {r.total_base_cost != null ? formatNaira(r.total_base_cost) : "—"}
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant">
                            {schedule || "—"}
                          </td>
                          <td className="px-2 py-2 text-on-surface-variant">
                            <Link href={`/map/route/${toRouteSlug(r)}`} className="font-medium text-primary hover:underline underline-offset-2">
                              View full details
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


interface Props {
  facility: Facility;
  onClose: () => void;
  preloadedData?: FacilityPanelData | null;
}

export default function FacilityPanel({ facility, onClose, preloadedData }: Props) {
  const [destinations, setDestinations] = useState<Destination[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [routesByDest, setRoutesByDest] = useState<Map<number, ConnectingRoute[]>>(new Map());
  const [periodsByRoute, setPeriodsByRoute] = useState<Map<number, RoutePeriod[]>>(new Map());

  useEffect(() => {
    // Use server-provided data immediately — no network request needed
    if (preloadedData) {
      setDestinations(preloadedData.destinations);
      setRoutesByDest(new Map(Object.entries(preloadedData.routesByDest).map(([k, v]) => [Number(k), v])));
      setPeriodsByRoute(new Map(Object.entries(preloadedData.periodsByRoute).map(([k, v]) => [Number(k), v])));
      setLoading(false);
      return;
    }

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
  }, [facility.facility_id, preloadedData]);

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
    <PanelShell
      typeIcon={<PlaceIcon sx={{ fontSize: 16 }} className="shrink-0" />}
      typeLabel={facility.facility_type ?? "Ferry Facility"}
      reportSlug={toFacilitySlug(facility)}
      onClose={onClose}
    >

      {/* Facility name */}
      <h1 className="px-4 pb-2 text-[22px] font-bold leading-7 text-on-surface shrink-0">
        {facility.facility_name ?? "Unnamed Facility"}
      </h1>

      {/* Scrollable body */}
      <div className="overflow-y-auto flex-1 px-4 py-4">

        {/* Two-column on desktop: image left, key attrs right */}
        <div className="md:flex md:gap-4 mb-4">
          {/* Image */}
          {facility.gcs_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={facility.gcs_url}
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
        {(() => {
          const isCharterOnly = facility.category?.includes("Charter only") ?? false;
          const isFutureOmiEko = (facility.category?.includes("Future Omi Eko") ?? false) || (isCharterOnly && facility.omi_eko === "Yes");
          const isOmiEko = !isCharterOnly && facility.omi_eko === "Yes";

          if (isCharterOnly || isFutureOmiEko) {
            return (
              <>
                {isCharterOnly && (
                  <p className="text-sm text-on-surface-variant py-2">
                    This is a charter-only facility. At this location, you can hire a private boat to take you anywhere, including popular destinations like the beach.
                  </p>
                )}
                {isFutureOmiEko && (
                  <p className="text-sm text-on-surface-variant py-2">
                    This location has tentatively been prioritized for the Lagos State government OMI EKO ferry network upgrading plan. Currently, there are no ferry services here, but they are planned to be operating here in the future.
                  </p>
                )}
              </>
            );
          }

          return (
            <>
              {isOmiEko && (
                <p className="text-sm text-on-surface-variant mb-4 pb-4 border-b border-outline-variant">
                  This location has been prioritized for the Lagos State government OMI EKO ferry network upgrading plan, so the facility is likely to get additional investment and upgrades.
                </p>
              )}
              <h3 className="text-[15px] font-semibold text-on-surface mb-3 leading-5">
                From this facility, you can get to the following destinations
              </h3>
              {loading ? (
                <LoadingSpinner message="Loading destinations…" />
              ) : groups.length === 0 ? (
                <p className="text-sm text-on-surface-variant py-2">
                  No destinations recorded for this facility.
                </p>
              ) : (
                <div className="flex flex-col gap-5">
                  {groups.map(([lga, items]) => (
                    <div key={lga}>
                      <p className="text-[13px] text-on-surface-variant mb-2">
                        {lga} LGA
                      </p>
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
            </>
          );
        })()}
      </div>
    </PanelShell>
  );
}
