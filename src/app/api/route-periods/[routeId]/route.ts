import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import type { RoutePeriod } from "@/types/routePeriod";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ routeId: string }> }
) {
  const { routeId } = await params;
  const id = parseInt(routeId, 10);
  if (isNaN(id)) return NextResponse.json([], { status: 400 });

  const rows = await sql`
    SELECT *
    FROM route_periods
    WHERE route_id = ${id}
    ORDER BY direction_id, start_time
  `;
  return NextResponse.json(rows as RoutePeriod[]);
}
