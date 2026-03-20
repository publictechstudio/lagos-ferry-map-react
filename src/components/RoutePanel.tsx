"use client";

import { Fragment, useEffect, useState } from "react";
import type { Route } from "@/types/route";
import type { RouteStop } from "@/types/routeStop";
import type { RoutePeriod } from "@/types/routePeriod";
import DirectionsBoatIcon from "@mui/icons-material/DirectionsBoat";

const REPORT_FORM_URL =
  "https://docs.google.com/forms/d/e/1FAIpQLSfCkMgguEE1GJ_WhWXBaIKhaILOICt1UqiA85r0m4yz_eEmAw/viewform";

// ── Helpers ──────────────────────────────────────────────────────────────────

function formatTime(timeStr: string): string {
  const [h, m] = timeStr.split(":");
  const hour = parseInt(h, 10);
  const minute = m;
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
  return `${h12}:${minute} ${ampm}`;
}

function formatMinutes(mins: number | null): string | null {
  if (mins == null) return null;
  if (mins < 60) return `${mins} min`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return m === 0 ? `${h} hr` : `${h} hr ${m} min`;
}

function formatDaySchedule(p: RoutePeriod): string {
  const days = [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday, p.saturday, p.sunday];
  const names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  const active = days.map((on, i) => ({ on, name: names[i] })).filter((d) => d.on);

  if (active.length === 7) return "Daily";
  if (active.length === 0) return "";

  const weekdays = [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday];
  const weekend = [p.saturday, p.sunday];
  const allWeekdays = weekdays.every(Boolean);
  const noWeekdays = weekdays.every((d) => !d);
  const allWeekend = weekend.every(Boolean);
  const noWeekend = weekend.every((d) => !d);

  if (allWeekdays && noWeekend) return "Monday – Friday. Does not operate on weekends.";
  if (allWeekdays && p.saturday && !p.sunday) return "Monday – Saturday. Does not operate on Sundays.";
  if (allWeekdays && allWeekend) return "Daily";
  if (noWeekdays && allWeekend) return "Weekends only. Does not operate on weekdays.";
  if (noWeekdays && p.saturday && !p.sunday) return "Saturdays only.";
  if (noWeekdays && !p.saturday && p.sunday) return "Sundays only.";

  // Fallback: list active day names
  return active.map((d) => d.name).join(", ");
}

/** Unique key representing which days of the week a period runs. */
function dayKey(p: RoutePeriod): string {
  return [p.monday, p.tuesday, p.wednesday, p.thursday, p.friday, p.saturday, p.sunday]
    .map((v) => (v ? "1" : "0"))
    .join("");
}

/** Group periods into tables by their day combination. */
function groupByDays(periods: RoutePeriod[]): Map<string, RoutePeriod[]> {
  const map = new Map<string, RoutePeriod[]>();
  for (const p of periods) {
    const k = dayKey(p);
    if (!map.has(k)) map.set(k, []);
    map.get(k)!.push(p);
  }
  return map;
}

/** Direction suffix based on whether service is morning/evening only. */
function directionSuffix(periods: RoutePeriod[]): string {
  const allMorning = periods.length > 0 && periods.every((p) => p.morning_service && !p.evening_service);
  const allEvening = periods.length > 0 && periods.every((p) => !p.morning_service && p.evening_service);
  if (allMorning) return " (MORNINGS ONLY)";
  if (allEvening) return " (EVENINGS ONLY)";
  return "";
}

/** Format cost_to_stop (string from DB) as Naira or "Free". */
function formatStopCost(cost: string): string {
  const n = parseFloat(cost);
  if (isNaN(n) || n === 0) return "";
  return `₦${n.toLocaleString()}`;
}

/** Determine if all non-origin segments share the same cost. */
function isFlat(stops: RouteStop[]): boolean {
  const costs = stops.slice(1).map((s) => parseFloat(s.cost_to_stop));
  return costs.length > 0 && costs.every((c) => c === costs[0]);
}

// ── Sub-components ────────────────────────────────────────────────────────────

/** Horizontal stop diagram matching wireframe. */
function StopDiagram({ stops }: { stops: RouteStop[] }) {
  if (stops.length === 0) return null;

  return (
    <div className="flex items-start w-full py-2">
      {stops.map((stop, idx) => {
        const isFirst = idx === 0;
        const isLast = idx === stops.length - 1;
        const isMandatory = stop.is_stop_mandatory === "Yes";
        const durationLabel = stop.duration_to_stop > 0 ? formatMinutes(stop.duration_to_stop) : null;

        return (
          <Fragment key={stop.route_stop_id}>
            {/* Connector line + duration label (before this stop) */}
            {!isFirst && (
              <div className="flex flex-col items-center flex-1 min-w-[32px] self-start mt-[14px]">
                {/* Fixed-height label area — arrow stays at consistent height with or without a label */}
                <div className="h-3 flex items-center justify-center mb-1">
                  {durationLabel && (
                    <span className="text-[11px] text-on-surface-variant whitespace-nowrap px-1">
                      {durationLabel}
                    </span>
                  )}
                </div>
                {/* Arrow line */}
                <div className="flex items-center w-full">
                  <div className="h-0.5 flex-1 bg-on-surface" />
                  <svg width="8" height="8" viewBox="0 0 8 8" className="text-on-surface shrink-0 -ml-px">
                    <path d="M0 0 L8 4 L0 8 Z" fill="currentColor" />
                  </svg>
                </div>
              </div>
            )}

            {/* Stop circle + label */}
            <div className="flex flex-col items-center w-[76px] shrink-0">
              {/* "Route Origin / Destination" label */}
              {(isFirst || isLast) && (
                <span className="text-[9px] text-on-surface-variant mb-0.5 text-center whitespace-nowrap">
                  {isFirst ? "Route Origin" : "Route Destination"}
                </span>
              )}
              {!isFirst && !isLast && <div className="mb-[17px]" />}

              {/* Circle */}
              <div
                className={`w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold border-2 shrink-0 ${
                  isMandatory
                    ? "bg-on-surface text-surface border-on-surface"
                    : "bg-surface-variant text-on-surface-variant border-on-surface-variant"
                }`}
              >
                {idx + 1}
              </div>

              {/* Stop name */}
              <p className="text-[11px] text-on-surface text-center mt-1.5 leading-tight max-w-[76px]">
                {stop.facility_name ?? `Stop #${stop.stop_id}`}
                {stop.lga && (
                  <span className="block text-on-surface-variant">({stop.lga})</span>
                )}
              </p>

              {/* Optional stop note */}
              {!isMandatory && (
                <p className="text-[10px] text-on-surface-variant italic text-center mt-1 leading-tight max-w-[76px]">
                  * Only stops here if passengers request it
                </p>
              )}
            </div>
          </Fragment>
        );
      })}
    </div>
  );
}

/** Schedule table for one group of periods sharing the same day combination. */
function ScheduleTable({ periods }: { periods: RoutePeriod[] }) {
  const dayLabel = periods.length > 0 ? formatDaySchedule(periods[0]) : "";

  return (
    <div className="mb-3">
      <p className="text-[12px] font-semibold text-on-surface mb-1.5">
        Schedule: {dayLabel}
      </p>
      <table className="w-full text-[12px] border border-outline-variant rounded-lg overflow-hidden">
        <thead>
          <tr className="bg-surface-variant">
            <th className="text-left px-3 py-2 font-semibold text-on-surface border-b border-outline-variant">
              Departure period
            </th>
            <th className="text-left px-3 py-2 font-semibold text-on-surface border-b border-outline-variant">
              Frequency (wait time)
            </th>
          </tr>
        </thead>
        <tbody>
          {periods.map((p) => (
            <tr key={p.route_period_id} className="border-b border-outline-variant last:border-0">
              <td className="px-3 py-2 text-on-surface">
                {p.single_daily_departure
                  ? `Departure at ${formatTime(p.start_time)}`
                  : p.end_time
                  ? `${formatTime(p.start_time)} – ${formatTime(p.end_time)}`
                  : formatTime(p.start_time)}
              </td>
              <td className="px-3 py-2 text-on-surface">
                {p.single_daily_departure
                  ? "Single departure"
                  : p.frequency
                  ? `Every ${p.frequency} mins`
                  : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Price table for one direction. */
function PriceTable({
  stops,
  paymentOptions,
}: {
  stops: RouteStop[];
  paymentOptions: string | null;
}) {
  if (stops.length < 2) return null;

  const flat = isFlat(stops);
  const paymentNote = paymentOptions ? ` (${paymentOptions})` : "";

  return (
    <div className="mb-3">
      <table className="w-full text-[12px] border border-outline-variant rounded-lg overflow-hidden">
        <thead>
          <tr className="bg-surface-variant">
            <th
              colSpan={2}
              className="text-left px-3 py-2 font-semibold text-on-surface border-b border-outline-variant"
            >
              Price
            </th>
          </tr>
        </thead>
        <tbody>
          {flat ? (
            <tr>
              <td className="px-3 py-2 text-on-surface-variant">Flat rate for all stops</td>
              <td className="px-3 py-2 text-on-surface font-medium">
                {formatStopCost(stops[1].cost_to_stop)}
                {paymentNote}
              </td>
            </tr>
          ) : (
            stops.slice(1).map((stop, i) => {
              const from = stops[i];
              return (
                <tr key={stop.route_stop_id} className="border-b border-outline-variant last:border-0">
                  <td className="px-3 py-2 text-on-surface-variant">
                    {from.facility_name ?? `Stop ${i + 1}`} → {stop.facility_name ?? `Stop ${i + 2}`}
                  </td>
                  <td className="px-3 py-2 text-on-surface font-medium">
                    {formatStopCost(stop.cost_to_stop) || "—"}
                    {i === 0 ? paymentNote : ""}
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}

/** One direction section (Inbound or Outbound). */
function DirectionSection({
  label,
  stops,
  periods,
  paymentOptions,
}: {
  label: string;
  stops: RouteStop[];
  periods: RoutePeriod[];
  paymentOptions: string | null;
}) {
  const suffix = directionSuffix(periods);
  const dayGroups = groupByDays(periods);

  return (
    <div className="rounded-xl border border-outline-variant bg-primary/[0.04] overflow-hidden mb-4">
      {/* Direction header */}
      <div className="bg-primary/[0.10] px-4 py-2.5">
        <h3 className="text-[13px] font-bold text-on-surface leading-snug">
          {label}
          {suffix && (
            <span className="font-normal text-on-surface-variant ml-1">{suffix}</span>
          )}
        </h3>
      </div>

      <div className="px-4 py-3">
        {/* Stop diagram */}
        <StopDiagram stops={stops} />

        {/* Schedule tables — one per unique day combination */}
        {dayGroups.size > 0 ? (
          Array.from(dayGroups.values()).map((group, i) => (
            <ScheduleTable key={i} periods={group} />
          ))
        ) : (
          <p className="text-[12px] text-on-surface-variant italic mb-3">
            No schedule data available.
          </p>
        )}

        {/* Price table */}
        <PriceTable stops={stops} paymentOptions={paymentOptions} />
      </div>
    </div>
  );
}

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

  const title =
    route.origin_name_short && route.destination_name_short
      ? `${route.origin_name_short} to ${route.destination_name_short}`
      : "Ferry Route";

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
    <div className="h-2/3 shrink-0 md:h-full md:w-1/2 flex flex-col bg-surface border-t border-outline-variant md:border-t-0 md:border-l overflow-hidden">

      {/* Mobile drag handle */}
      <div className="md:hidden flex justify-center pt-2.5 pb-1 shrink-0">
        <div className="w-8 h-1 rounded-full bg-on-surface-variant/30" />
      </div>

      {/* Type label + close button */}
      <div className="flex items-center justify-between px-4 pt-4 pb-1 shrink-0">
        <div className="flex items-center gap-1.5 text-on-surface-variant">
          <DirectionsBoatIcon sx={{ fontSize: 16 }} className="shrink-0" />
          <span className="text-sm">Ferry Route</span>
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
          <div className="flex items-center gap-2 text-on-surface-variant text-sm py-4">
            <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin shrink-0" />
            Loading route details…
          </div>
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
    </div>
  );
}
