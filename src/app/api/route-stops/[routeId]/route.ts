import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import type { RouteStop } from "@/types/routeStop";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ routeId: string }> }
) {
  const { routeId } = await params;
  const id = parseInt(routeId, 10);
  if (isNaN(id)) return NextResponse.json([], { status: 400 });

  const rows = await sql`
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
    WHERE rs.route_id = ${id}
    ORDER BY rs.stop_order
  `;
  return NextResponse.json(rows as RouteStop[]);
}
