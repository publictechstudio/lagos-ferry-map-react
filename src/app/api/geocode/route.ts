import { NextRequest, NextResponse } from "next/server";

export const runtime = "edge";

export type GeoResult = { lat: number; lon: number; display_name: string };

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get("q")?.trim();
  if (!q) return NextResponse.json([]);

  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", q);
  url.searchParams.set("format", "json");
  url.searchParams.set("countrycodes", "ng");
  // Lagos bounding box: west, north, east, south
  url.searchParams.set("viewbox", "3.0,6.8,4.1,6.2");
  url.searchParams.set("bounded", "1");
  url.searchParams.set("limit", "5");

  const res = await fetch(url.toString(), {
    headers: {
      "User-Agent": "LagosFerriesMap/1.0 (publictech.studio)",
      "Accept-Language": "en",
    },
  });

  if (!res.ok) return NextResponse.json([]);

  const data = await res.json() as { lat: string; lon: string; display_name: string }[];
  const results: GeoResult[] = data.map((r) => ({
    lat: parseFloat(r.lat),
    lon: parseFloat(r.lon),
    display_name: r.display_name,
  }));

  return NextResponse.json(results);
}
