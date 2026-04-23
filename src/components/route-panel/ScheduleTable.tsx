import type { RoutePeriod } from "@/types/routePeriod";
import { formatDaySchedule, formatTime } from "./helpers";

/** Schedule table for one group of periods sharing the same day combination. */
export default function ScheduleTable({ periods }: { periods: RoutePeriod[] }) {
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
                {p.average_daily_boat_departures === 1
                  ? `Departure at ${formatTime(p.start_time)}`
                  : p.end_time
                  ? `${formatTime(p.start_time)} – ${formatTime(p.end_time)}`
                  : formatTime(p.start_time)}
              </td>
              <td className="px-3 py-2 text-on-surface">
                {p.average_daily_boat_departures === 1
                  ? "Single departure (only 1 boat)"
                  : p.frequency
                  ? `Every ${p.frequency} mins`
                  : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="mt-1 text-[11px] italic text-on-surface-variant">
        Note: Departure times are estimates. Actual departures depend on passenger demand, with boats typically waiting until they are full.
      </p>
    </div>
  );
}
