import { Fragment } from "react";
import Link from "next/link";
import type { RouteStop } from "@/types/routeStop";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { formatMinutes } from "./helpers";

const STOPS_PER_ROW = 4;

/** Renders one stop circle + label, linked to the facility page. */
function StopNode({
  stop,
  globalIdx,
  isFirst,
  isLast,
}: {
  stop: RouteStop;
  globalIdx: number;
  isFirst: boolean;
  isLast: boolean;
}) {
  const isMandatory = stop.is_stop_mandatory === "Yes";
  return (
    <div className="flex flex-col items-center w-[76px] shrink-0">
      {(isFirst || isLast) ? (
        <span className="text-[9px] text-on-surface-variant mb-0.5 text-center whitespace-nowrap">
          {isFirst ? "Route Origin" : "Route Destination"}
        </span>
      ) : (
        <div className="mb-[17px]" />
      )}

      <Link
        href={`/map/${toFacilitySlug({ facility_id: stop.stop_id, facility_name: stop.facility_name })}`}
        className="flex flex-col items-center group"
      >
        <div
          className={`w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold border-2 shrink-0 transition-opacity group-hover:opacity-70 ${
            isMandatory
              ? "bg-on-surface text-surface border-on-surface"
              : "bg-surface-variant text-on-surface-variant border-on-surface-variant"
          }`}
        >
          {globalIdx + 1}
        </div>
        <p className="text-[11px] text-on-surface text-center mt-1.5 leading-tight max-w-[76px] group-hover:text-primary transition-colors">
          {stop.facility_name ?? `Stop #${stop.stop_id}`}
          {stop.lga && <span className="block text-on-surface-variant">({stop.lga})</span>}
        </p>
      </Link>

      {!isMandatory && (
        <p className="text-[10px] text-on-surface-variant italic text-center mt-1 leading-tight max-w-[76px]">
          * Only stops here if passengers request it
        </p>
      )}
    </div>
  );
}

/** Horizontal connector with optional duration label and configurable arrow direction. */
function Connector({ durationLabel, direction }: { durationLabel: string | null; direction: "right" | "left" }) {
  return (
    <div className="flex flex-col items-center flex-1 min-w-[32px] self-start mt-[14px]">
      <div className="h-3 flex items-center justify-center mb-1">
        {durationLabel && (
          <span className="text-[11px] text-on-surface-variant whitespace-nowrap px-1">{durationLabel}</span>
        )}
      </div>
      <div className="flex items-center w-full">
        {direction === "right" ? (
          <>
            <div className="h-0.5 flex-1 bg-on-surface" />
            <svg width="8" height="8" viewBox="0 0 8 8" className="text-on-surface shrink-0 -ml-px">
              <path d="M0 0 L8 4 L0 8 Z" fill="currentColor" />
            </svg>
          </>
        ) : (
          <>
            <svg width="8" height="8" viewBox="0 0 8 8" className="text-on-surface shrink-0 -mr-px">
              <path d="M8 0 L0 4 L8 8 Z" fill="currentColor" />
            </svg>
            <div className="h-0.5 flex-1 bg-on-surface" />
          </>
        )}
      </div>
    </div>
  );
}

/** Vertical turn connector between snake rows. Aligned under the last displayed stop (38px = half of 76px stop width). */
function TurnConnector({ side, durationLabel }: { side: "right" | "left"; durationLabel: string | null }) {
  return (
    <div className={`flex py-1 ${side === "right" ? "justify-end pr-[38px]" : "justify-start pl-[38px]"}`}>
      <div className="flex flex-col items-center">
        {durationLabel && (
          <span className="text-[11px] text-on-surface-variant whitespace-nowrap px-1 mb-0.5">{durationLabel}</span>
        )}
        <div className="w-0.5 h-5 bg-on-surface" />
        <svg width="8" height="8" viewBox="0 0 8 8" className="text-on-surface shrink-0 -mt-px">
          <path d="M0 0 L8 0 L4 8 Z" fill="currentColor" />
        </svg>
      </div>
    </div>
  );
}

/** Stop diagram that wraps into a snake layout when stops exceed one row. */
export default function StopDiagram({ stops }: { stops: RouteStop[] }) {
  if (stops.length === 0) return null;

  // Chunk into rows
  const rows: RouteStop[][] = [];
  for (let i = 0; i < stops.length; i += STOPS_PER_ROW) {
    rows.push(stops.slice(i, i + STOPS_PER_ROW));
  }

  const totalStops = stops.length;

  return (
    <div className="py-2 w-full">
      {rows.map((rowStops, rowIdx) => {
        const isEvenRow = rowIdx % 2 === 0;
        // Odd rows display stops right-to-left so travel continues from the turn side
        const displayStops = isEvenRow ? rowStops : [...rowStops].reverse();
        const rowStartIdx = rowIdx * STOPS_PER_ROW;

        // Global index in the full stops array for a given display position
        const globalIdx = (displayIdx: number) =>
          isEvenRow
            ? rowStartIdx + displayIdx
            : rowStartIdx + (rowStops.length - 1 - displayIdx);

        // Duration for the horizontal connector before display position n (n > 0)
        // Even row: the stop at display[n] carries duration_to_stop for the leg arriving at it
        // Odd row: the stop at display[n-1] carries the duration for the leg (it's the logically later stop)
        const connectorDuration = (n: number): string | null => {
          const d = isEvenRow
            ? displayStops[n].duration_to_stop
            : displayStops[n - 1].duration_to_stop;
          return d > 0 ? formatMinutes(d) : null;
        };

        // Turn connector between this row and the next
        const hasNextRow = rowIdx < rows.length - 1;
        const nextRowFirst = hasNextRow ? rows[rowIdx + 1][0] : null;
        const turnDuration = nextRowFirst && nextRowFirst.duration_to_stop > 0
          ? formatMinutes(nextRowFirst.duration_to_stop)
          : null;
        // Even rows turn on the right (last displayed stop is rightmost)
        // Odd rows turn on the left (last logical stop is displayed leftmost)
        const turnSide = isEvenRow ? "right" : "left";

        return (
          <div key={rowIdx}>
            <div className="flex items-start w-full">
              {displayStops.map((stop, displayIdx) => {
                const gIdx = globalIdx(displayIdx);
                return (
                  <Fragment key={stop.route_stop_id}>
                    {displayIdx > 0 && (
                      <Connector
                        durationLabel={connectorDuration(displayIdx)}
                        direction={isEvenRow ? "right" : "left"}
                      />
                    )}
                    <StopNode
                      stop={stop}
                      globalIdx={gIdx}
                      isFirst={gIdx === 0}
                      isLast={gIdx === totalStops - 1}
                    />
                  </Fragment>
                );
              })}
            </div>

            {hasNextRow && (
              <TurnConnector side={turnSide} durationLabel={turnDuration} />
            )}
          </div>
        );
      })}
    </div>
  );
}
