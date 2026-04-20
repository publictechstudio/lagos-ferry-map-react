import { NextRequest, NextResponse } from "next/server";

export const runtime = "edge";

export type PlaceLocation = { lat: number; lon: number; display_name: string };

export async function GET(req: NextRequest) {
  const placeId = req.nextUrl.searchParams.get("place_id")?.trim();
  if (!placeId) return NextResponse.json(null);

  const key = process.env.GOOGLE_MAPS_API_KEY;
  if (!key) return NextResponse.json(null);

  const url = new URL("https://maps.googleapis.com/maps/api/place/details/json");
  url.searchParams.set("place_id", placeId);
  url.searchParams.set("fields", "geometry,name,formatted_address");
  url.searchParams.set("key", key);

  const res = await fetch(url.toString());
  if (!res.ok) return NextResponse.json(null);

  const data = await res.json() as {
    result?: {
      geometry?: { location?: { lat: number; lng: number } };
      name?: string;
      formatted_address?: string;
    };
  };

  const loc = data.result?.geometry?.location;
  if (!loc) return NextResponse.json(null);

  return NextResponse.json({
    lat: loc.lat,
    lon: loc.lng,
    display_name: data.result?.name ?? data.result?.formatted_address ?? "",
  } satisfies PlaceLocation);
}
