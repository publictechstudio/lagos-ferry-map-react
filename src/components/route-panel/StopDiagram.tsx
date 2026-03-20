import { Fragment } from "react";
import type { RouteStop } from "@/types/routeStop";
import { formatMinutes } from "./helpers";

/** Horizontal stop diagram matching wireframe. */
export default function StopDiagram({ stops }: { stops: RouteStop[] }) {
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
