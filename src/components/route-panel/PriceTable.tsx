import type { RouteStop } from "@/types/routeStop";
import { formatStopCost, isFlat } from "./helpers";

/** Price table for one direction. */
export default function PriceTable({
  stops,
  paymentOptions,
  originName,
  destinationName,
  totalOnly = false,
}: {
  stops: RouteStop[];
  paymentOptions: string | null;
  originName: string;
  destinationName: string;
  totalOnly?: boolean;
}) {
  if (stops.length < 2) return null;

  const flat = isFlat(stops);
  const paymentNote = paymentOptions ? ` (${paymentOptions})` : "";
  const showTotal = !totalOnly && stops.length > 2;

  // The last stop in route_stops is the authoritative total cost for the
  // route — it must always match the per-leg rows above it.
  const lastLegCost = stops[stops.length - 1].cost_to_stop;
  const totalCost = `${formatStopCost(lastLegCost) || "—"}${paymentNote}`;

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
          {totalOnly && flat ? (
            <tr>
              <td className="px-3 py-2 text-on-surface-variant">Flat rate for all stops</td>
              <td className="px-3 py-2 text-on-surface font-medium">
                {formatStopCost(stops[1].cost_to_stop)}
                {paymentNote}
              </td>
            </tr>
          ) : totalOnly ? (
            <tr>
              <td className="px-3 py-2 text-on-surface-variant">
                {originName} → {destinationName}
              </td>
              <td className="px-3 py-2 text-on-surface font-medium">{totalCost}</td>
            </tr>
          ) : flat ? (
            <tr>
              <td className="px-3 py-2 text-on-surface-variant">Flat rate for all stops</td>
              <td className="px-3 py-2 text-on-surface font-medium">
                {formatStopCost(stops[1].cost_to_stop)}
                {paymentNote}
              </td>
            </tr>
          ) : (
            stops.slice(1).map((stop, i) => {
              return (
                <tr key={stop.route_stop_id} className="border-b border-outline-variant last:border-0">
                  <td className="px-3 py-2 text-on-surface-variant">
                    {originName} → {stop.facility_name ?? `Stop ${i + 2}`}
                  </td>
                  <td className="px-3 py-2 text-on-surface font-medium">
                    {formatStopCost(stop.cost_to_stop) || "—"}
                    {i === 0 ? paymentNote : ""}
                  </td>
                </tr>
              );
            })
          )}
          {showTotal && (
            <tr className="border-t border-outline-variant bg-surface-variant/50">
              <td className="px-3 py-2 text-on-surface font-semibold">
                {originName} → {destinationName} (total)
              </td>
              <td className="px-3 py-2 text-on-surface font-semibold">
                {formatStopCost(lastLegCost) || "—"}
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
