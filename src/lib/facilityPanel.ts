import { sql } from "./db";
import type { Destination } from "@/types/destination";
import type { ConnectingRoute } from "@/types/connectingRoute";
import type { RoutePeriod } from "@/types/routePeriod";

export type FacilityPanelData = {
  destinations: Destination[];
  routesByDest: Record<number, ConnectingRoute[]>;
  periodsByRoute: Record<number, RoutePeriod[]>;
};

export async function getFacilityPanelData(id: number): Promise<FacilityPanelData> {
  const destRows = await sql`
    SELECT
      f.facility_id,
      f.facility_name,
      f.facility_name_short,
      f.facility_lat::float AS facility_lat,
      f.facility_lon::float AS facility_lon,
      f.lga,
      f.facility_type
    FROM facility_destinations fd
    JOIN facilities f ON f.facility_id = fd.destination_id
    WHERE fd.facility_id = ${id}
      AND f.status IS NOT NULL
      AND f.status != 'not_in_use'
      AND fd.is_charter IS FALSE
    ORDER BY f.lga, f.facility_name
  `;

  const destinations = destRows as Destination[];

  if (destinations.length === 0) {
    return { destinations: [], routesByDest: {}, periodsByRoute: {} };
  }

  const destIds = destinations.map((d) => d.facility_id);

  const routeRows = await sql`
    SELECT DISTINCT
      rs2.stop_id AS dest_id,
      r.route_id,
      r.operator,
      r.total_base_cost,
      r.total_base_duration,
      f1.facility_name AS origin_name,
      f2.facility_name AS destination_name,
      f1.facility_name_short AS origin_name_short,
      f2.facility_name_short AS destination_name_short,
      CASE WHEN rs1.stop_order < rs2.stop_order THEN 0 ELSE 1 END AS travel_direction
    FROM route_stops rs1
    JOIN route_stops rs2
      ON rs2.route_id = rs1.route_id
      AND rs2.stop_id = ANY(${destIds})
    JOIN routes r ON r.route_id = rs1.route_id
    LEFT JOIN facilities f1 ON f1.facility_id = r.origin
    LEFT JOIN facilities f2 ON f2.facility_id = r.destination
    WHERE rs1.stop_id = ${id}
      AND rs1.route_id NOT IN (
        SELECT DISTINCT route_id FROM routes WHERE total_base_duration = 9999 AND omi_eko = TRUE
      )
  `;

  const routesByDest: Record<number, ConnectingRoute[]> = {};
  const uniqueRouteIds = new Set<number>();

  for (const row of routeRows as (ConnectingRoute & { dest_id: number })[]) {
    const { dest_id, ...route } = row;
    if (!routesByDest[dest_id]) routesByDest[dest_id] = [];
    routesByDest[dest_id].push(route as ConnectingRoute);
    uniqueRouteIds.add(route.route_id);
  }

  if (uniqueRouteIds.size === 0) {
    return { destinations, routesByDest, periodsByRoute: {} };
  }

  const routeIds = [...uniqueRouteIds];

  const periodRows = await sql`
    SELECT *
    FROM route_periods
    WHERE route_id = ANY(${routeIds})
      AND route_id NOT IN (
        SELECT DISTINCT route_id FROM routes WHERE total_base_duration = 9999 AND omi_eko = TRUE
      )
    ORDER BY route_id, direction_id, start_time
  `;

  const periodsByRoute: Record<number, RoutePeriod[]> = {};
  for (const row of periodRows as RoutePeriod[]) {
    if (!periodsByRoute[row.route_id]) periodsByRoute[row.route_id] = [];
    periodsByRoute[row.route_id].push(row);
  }

  return { destinations, routesByDest, periodsByRoute };
}
