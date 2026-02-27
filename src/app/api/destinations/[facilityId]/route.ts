import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import type { Destination } from "@/types/destination";

export const revalidate = 3600;

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ facilityId: string }> }
) {
  const { facilityId } = await params;
  const id = parseInt(facilityId, 10);

  if (isNaN(id)) {
    return NextResponse.json({ error: "Invalid facility ID" }, { status: 400 });
  }

  const rows = await sql`
    SELECT
      f.facility_id,
      f.facility_name,
      f.facility_lat::float AS facility_lat,
      f.facility_lon::float  AS facility_lon,
      f.lga,
      f.facility_type
    FROM facility_destinations fd
    JOIN facilities f ON f.facility_id = fd.destination_id
    WHERE fd.facility_id = ${id}
      AND f.status IS NOT NULL
      AND f.status != 'not_in_use'
    ORDER BY f.lga, f.facility_name
  `;

  return NextResponse.json(rows as Destination[]);
}
