import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import type { ConnectingRoute } from "@/types/connectingRoute";

export const revalidate = 3600;

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ facilityId: string; destinationId: string }> }
) {
  const { facilityId, destinationId } = await params;
  const fId = parseInt(facilityId, 10);
  const dId = parseInt(destinationId, 10);

  if (isNaN(fId) || isNaN(dId)) {
    return NextResponse.json({ error: "Invalid ID" }, { status: 400 });
  }

  const rows = await sql`
    SELECT DISTINCT
      r.route_id,
      r.operator,
      r.total_base_cost,
      r.total_base_duration,
      f1.facility_name AS origin_name,
      f2.facility_name AS destination_name,
      CASE WHEN rs1.stop_order < rs2.stop_order THEN 'Inbound' ELSE 'Outbound' END AS travel_direction
    FROM route_stops rs1
    JOIN route_stops rs2
      ON rs1.route_id = rs2.route_id
    JOIN routes r
      ON r.route_id = rs1.route_id
    LEFT JOIN facilities f1 ON f1.facility_id = r.origin
    LEFT JOIN facilities f2 ON f2.facility_id = r.destination
    WHERE rs1.stop_id = ${fId}
      AND rs2.stop_id = ${dId}
    ORDER BY r.route_id
  `;

  return NextResponse.json(rows as ConnectingRoute[]);
}
