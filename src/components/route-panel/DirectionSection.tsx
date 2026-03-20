import type { RouteStop } from "@/types/routeStop";
import type { RoutePeriod } from "@/types/routePeriod";
import { directionSuffix, groupByDays } from "./helpers";
import StopDiagram from "./StopDiagram";
import ScheduleTable from "./ScheduleTable";
import PriceTable from "./PriceTable";

/** One direction section (Inbound or Outbound). */
export default function DirectionSection({
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
