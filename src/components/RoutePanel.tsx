"use client";

import { useEffect, useState } from "react";
import type { Route } from "@/types/route";
import type { RouteStop } from "@/types/routeStop";
import type { RoutePeriod } from "@/types/routePeriod";
import DirectionsBoatIcon from "@mui/icons-material/DirectionsBoat";
import { toRouteSlug } from "@/lib/routeSlug";
import PanelShell from "./PanelShell";
import LoadingSpinner from "./LoadingSpinner";
import { formatMinutes } from "./route-panel/helpers";
import DirectionSection from "./route-panel/DirectionSection";

// ── Main component ────────────────────────────────────────────────────────────

interface Props {
  route: Route;
  onClose: () => void;
}

export default function RoutePanel({ route, onClose }: Props) {
  const [stops, setStops] = useState<RouteStop[] | null>(null);
  const [periods, setPeriods] = useState<RoutePeriod[] | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    setStops(null);
    setPeriods(null);

    Promise.all([
      fetch(`/api/route-stops/${route.route_id}`).then((r) => r.json()),
      fetch(`/api/route-periods/${route.route_id}`).then((r) => r.json()),
    ])
      .then(([stopsData, periodsData]) => {
        setStops(stopsData as RouteStop[]);
        setPeriods(periodsData as RoutePeriod[]);
        setLoading(false);
      })
      .catch(() => {
        setStops([]);
        setPeriods([]);
        setLoading(false);
      });
  }, [route.route_id]);

  // Inbound: stops in order (origin → destination)
  const inboundStops = stops ?? [];
  // Outbound: stops in reverse (destination → origin), durations shifted
  const outboundStops = [...inboundStops].reverse().map((stop, idx) => {
    // duration for reversed stop idx = duration_to_stop of the next stop in forward order
    const forwardNext = inboundStops[inboundStops.length - 1 - idx];
    return {
      ...stop,
      duration_to_stop: idx === 0 ? 0 : (forwardNext?.duration_to_stop ?? 0),
    };
  });

  const inboundPeriods = (periods ?? []).filter((p) => p.direction_id === "Inbound");
  const outboundPeriods = (periods ?? []).filter((p) => p.direction_id === "Outbound");

  const inboundLabel = `${route.origin_name ?? "Origin"} to ${route.destination_name ?? "Destination"}`;
  const outboundLabel = `${route.destination_name ?? "Destination"} to ${route.origin_name ?? "Origin"}`;

  return (
    <PanelShell
      typeIcon={<DirectionsBoatIcon sx={{ fontSize: 16 }} className="shrink-0" />}
      typeLabel="Ferry Route"
      reportSlug={toRouteSlug(route)}
      onClose={onClose}
    >

      {/* Scrollable body */}
      <div className="overflow-y-auto flex-1 px-4 py-3">
        {/* Route label */}
        <h1 className="px-2 pb-4 text-[22px] font-bold leading-7 text-on-surface shrink-0">
          {route.origin_name_short ?? "Origin"} to {route.destination_name_short ?? "Destination"} ⇄ {route.destination_name_short ?? "Destination"} to {route.origin_name_short ?? "Origin"}
        </h1>

        {/* ── Route header card ──────────────────────────────────────── */}
        <div className="border border-outline-variant rounded-xl p-4 mb-4">
          {/* Operator */}
          {route.operator && (
            <div className="mb-2">
              <p className="text-[11px] font-semibold text-on-surface-variant uppercase tracking-wide mb-0.5">
                Operator:
              </p>
              <p className="text-sm font-semibold text-on-surface">{route.operator}</p>
            </div>
          )}

          {/* Placeholder description */}
          <p className="text-[12px] text-on-surface-variant leading-relaxed mb-3">
            This route connects ferry terminals along the Lagos waterways. Check the schedule below for departure times and frequency.
          </p>

          {/* Total duration + Boat types */}
          <div className="grid grid-cols-2 gap-3 border-t border-outline-variant pt-3">
            {route.total_base_duration != null && (
              <div>
                <p className="text-[11px] font-semibold text-on-surface-variant uppercase tracking-wide mb-0.5">
                  Total duration:
                </p>
                <p className="text-sm text-on-surface">{formatMinutes(route.total_base_duration)}</p>
              </div>
            )}
            {route.boat_types && (
              <div>
                <p className="text-[11px] font-semibold text-on-surface-variant uppercase tracking-wide mb-0.5">
                  Types of boats:
                </p>
                <p className="text-sm text-on-surface">{route.boat_types}</p>
              </div>
            )}
          </div>
        </div>

        {/* ── Loading state ──────────────────────────────────────────── */}
        {loading && (
          <LoadingSpinner message="Loading route details…" />
        )}

        {/* ── Direction sections ─────────────────────────────────────── */}
        {!loading && (
          <>
            {/* Inbound */}
            {(inboundStops.length > 0 || inboundPeriods.length > 0) && (
              <DirectionSection
                label={inboundLabel}
                stops={inboundStops}
                periods={inboundPeriods}
                paymentOptions={route.payment_options}
              />
            )}

            {/* Outbound */}
            {(outboundStops.length > 0 || outboundPeriods.length > 0) && (
              <DirectionSection
                label={outboundLabel}
                stops={outboundStops}
                periods={outboundPeriods}
                paymentOptions={route.payment_options}
              />
            )}
          </>
        )}

        {/* ── Disruptions ────────────────────────────────────────────── */}
        {(route.rain || route.hyacinth_season_disruption) && (
          <div className="mb-4">
            <h3 className="text-[13px] font-semibold text-on-surface mb-2">Disruptions:</h3>
            <ul className="list-disc list-inside flex flex-col gap-1.5">
              {route.rain && (
                <li className="text-[12px] text-on-surface-variant leading-relaxed">
                  <span className="font-semibold text-on-surface">Rain:</span> {route.rain}
                </li>
              )}
              {route.hyacinth_season_disruption && (
                <li className="text-[12px] text-on-surface-variant leading-relaxed">
                  <span className="font-semibold text-on-surface">Water hyacinth:</span>{" "}
                  {route.hyacinth_season_disruption}
                </li>
              )}
            </ul>
          </div>
        )}

        {/* ── Additional notes ───────────────────────────────────────── */}
        {route.additional_notes && (
          <div className="mb-4">
            <h3 className="text-[13px] font-semibold text-on-surface mb-1">Additional notes</h3>
            <p className="text-[12px] text-on-surface-variant leading-relaxed whitespace-pre-line">
              {route.additional_notes}
            </p>
          </div>
        )}

      </div>
    </PanelShell>
  );
}
