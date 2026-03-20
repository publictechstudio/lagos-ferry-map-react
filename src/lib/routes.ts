import { sql } from "./db";
import type { Route } from "@/types/route";

export async function getRoutes(): Promise<Route[]> {
  const rows = await sql`
    SELECT
      r.route_id,
      r.modified_at,
      r.operator,
      r.payment_options,
      r.boat_types,
      r.weekend_equals_weekday_schedule,
      r.saturday_equals_sunday_schedule,
      r.total_base_duration,
      r.total_base_cost,
      r.hyacinth_season_disruption,
      r.rain,
      r.geom,
      r.route_stops,
      r.stop_names,
      r.additional_notes,
      r.contact_name,
      r.contact_email,
      r.origin,
      r.destination,
      f1.facility_name AS origin_name,
      f2.facility_name AS destination_name,
      f1.facility_name_short AS origin_name_short,
      f2.facility_name_short AS destination_name_short
    FROM routes r
    LEFT JOIN facilities f1 ON r.origin = f1.facility_id
    LEFT JOIN facilities f2 ON r.destination = f2.facility_id
    WHERE r.geom IS NOT NULL
    ORDER BY r.route_id
  `;
  return rows as Route[];
}

export async function getRouteById(id: number): Promise<Route | null> {
  const rows = await sql`
    SELECT
      r.route_id,
      r.modified_at,
      r.operator,
      r.payment_options,
      r.boat_types,
      r.weekend_equals_weekday_schedule,
      r.saturday_equals_sunday_schedule,
      r.total_base_duration,
      r.total_base_cost,
      r.hyacinth_season_disruption,
      r.rain,
      r.geom,
      r.route_stops,
      r.stop_names,
      r.additional_notes,
      r.contact_name,
      r.contact_email,
      r.origin,
      r.destination,
      f1.facility_name AS origin_name,
      f2.facility_name AS destination_name,
      f1.facility_name_short AS origin_name_short,
      f2.facility_name_short AS destination_name_short
    FROM routes r
    LEFT JOIN facilities f1 ON r.origin = f1.facility_id
    LEFT JOIN facilities f2 ON r.destination = f2.facility_id
    WHERE r.route_id = ${id}
      AND r.geom IS NOT NULL
  `;
  return (rows[0] as Route) ?? null;
}
