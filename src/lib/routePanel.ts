import { sql } from "./db";
import type { RouteStop } from "@/types/routeStop";
import type { RoutePeriod } from "@/types/routePeriod";

export type RoutePanelData = {
  stops: RouteStop[];
  periods: RoutePeriod[];
};

export async function getRoutePanelData(routeId: number): Promise<RoutePanelData> {
  const [stopRows, periodRows] = await Promise.all([
    sql`
      SELECT
        rs.route_stop_id,
        rs.route_id,
        rs.stop_id,
        rs.stop_order,
        rs.duration_to_stop,
        rs.cost_to_stop::text AS cost_to_stop,
        rs.is_stop_mandatory,
        f.facility_name,
        f.lga
      FROM route_stops rs
      LEFT JOIN facilities f ON rs.stop_id = f.facility_id
      WHERE rs.route_id = ${routeId}
      ORDER BY rs.stop_order
    `,
    sql`
      SELECT *
      FROM route_periods
      WHERE route_id = ${routeId}
      ORDER BY direction_id, start_time
    `,
  ]);

  return {
    stops: stopRows as RouteStop[],
    periods: periodRows as RoutePeriod[],
  };
}
