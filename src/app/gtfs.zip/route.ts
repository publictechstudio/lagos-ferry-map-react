import { sql } from "@/lib/db";
import { NextResponse } from "next/server";

export async function GET() {
  const rows = await sql`SELECT zip_data, version, updated_at FROM gtfs_zip_cache WHERE id = 1`;
  if (!rows.length || !rows[0].zip_data) {
    return new NextResponse("GTFS feed not available", { status: 404 });
  }
  return new NextResponse(rows[0].zip_data, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": 'attachment; filename="gtfs.zip"',
      "Cache-Control": "public, max-age=3600",
    },
  });
}
