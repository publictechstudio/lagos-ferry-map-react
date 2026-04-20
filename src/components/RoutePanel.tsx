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
  preloadedStops?: RouteStop[] | null;
  preloadedPeriods?: RoutePeriod[] | null;
}

export default function RoutePanel({ route, onClose, preloadedStops, preloadedPeriods }: Props) {
  const isPlannedOmiEko = route.omi_eko === true && route.total_base_duration === 9999;

  const [stops, setStops] = useState<RouteStop[] | null>(null);
  const [periods, setPeriods] = useState<RoutePeriod[] | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (isPlannedOmiEko) return;

    // Use server-provided data immediately — no network request needed
    if (preloadedStops != null && preloadedPeriods != null) {
      setStops(preloadedStops);
      setPeriods(preloadedPeriods);
      setLoading(false);
      return;
    }

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
  }, [route.route_id, isPlannedOmiEko, preloadedStops, preloadedPeriods]);

  if (isPlannedOmiEko) {
    return (
      <PanelShell
        typeIcon={<DirectionsBoatIcon sx={{ fontSize: 16 }} className="shrink-0" />}
        typeLabel="Ferry Route"
        reportSlug={toRouteSlug(route)}
        onClose={onClose}
      >
        <div className="overflow-y-auto flex-1 px-4 py-3">
          <h1 className="px-2 pb-4 text-[22px] font-bold leading-7 text-on-surface shrink-0">
            {route.origin_name_short ?? "Origin"} to {route.destination_name_short ?? "Destination"}
          </h1>
          <p className="px-2 text-sm text-on-surface-variant leading-relaxed">
            This route is tentatively planned as part of the Lagos State government OMI EKO ferry expansion.
          </p>
        </div>
      </PanelShell>
    );
  }

  // outbound: stops in order (origin → destination)
  const outboundStops = stops ?? [];
  // return: stops in reverse (destination → origin), durations and costs shifted
  const returnStops = [...outboundStops].reverse().map((stop, idx) => {
    const forwardNext = outboundStops[outboundStops.length - 1 - idx];
    return {
      ...stop,
      duration_to_stop: idx === 0 ? 0 : (forwardNext?.duration_to_stop ?? 0),
      cost_to_stop: idx === 0 ? "0" : (forwardNext?.cost_to_stop ?? "0"),
    };
  });

  const outboundPeriods = (periods ?? []).filter((p) => p.direction_id == 0);
  const returnPeriods = (periods ?? []).filter((p) => p.direction_id == 1);
  console.log(`[RoutePanel] direction_id values in periods:`, (periods ?? []).map(p => ({ id: p.route_period_id, direction_id: p.direction_id, type: typeof p.direction_id })));
  console.log(`[RoutePanel] outboundPeriods (direction_id==='0'):`, outboundPeriods.length, "returnPeriods (direction_id==='1'):", returnPeriods.length);

  const outboundLabel = `${route.origin_name ?? "Origin"} to ${route.destination_name ?? "Destination"}`;
  const returnLabel = `${route.destination_name ?? "Destination"} to ${route.origin_name ?? "Origin"}`;

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
          {route.origin_name_short ?? "Origin"} ⇄ {route.destination_name_short ?? "Destination"}
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
            {/* outbound */}
            {(outboundStops.length > 0 || outboundPeriods.length > 0) && (
              <DirectionSection
                label={outboundLabel}
                stops={outboundStops}
                periods={outboundPeriods}
                paymentOptions={route.payment_options}
                totalBaseCost={route.total_base_cost}
                originName={route.origin_name_short ?? route.origin_name ?? "Origin"}
                destinationName={route.destination_name_short ?? route.destination_name ?? "Destination"}
              />
            )}

            {/* return */}
            {(returnStops.length > 0 || returnPeriods.length > 0) && (
              <DirectionSection
                label={returnLabel}
                stops={returnStops}
                periods={returnPeriods}
                paymentOptions={route.payment_options}
                totalBaseCost={route.total_base_cost}
                originName={route.destination_name_short ?? route.destination_name ?? "Destination"}
                destinationName={route.origin_name_short ?? route.origin_name ?? "Origin"}
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

      </div>
    </PanelShell>
  );
}
