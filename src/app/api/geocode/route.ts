import { NextRequest, NextResponse } from "next/server";

export const runtime = "edge";

export type PlaceSuggestion = { place_id: string; description: string };

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get("q")?.trim();
  if (!q) return NextResponse.json([]);

  const key = process.env.GOOGLE_MAPS_API_KEY;
  if (!key) return NextResponse.json([]);

  const url = new URL("https://maps.googleapis.com/maps/api/place/autocomplete/json");
  url.searchParams.set("input", q);
  url.searchParams.set("key", key);
  url.searchParams.set("components", "country:ng");
  url.searchParams.set("location", "6.5243793,3.3792057"); // Lagos centre
  url.searchParams.set("radius", "50000"); // bias within 50 km
  url.searchParams.set("language", "en");

  const res = await fetch(url.toString());
  if (!res.ok) return NextResponse.json([]);

  const data = await res.json() as { predictions?: { place_id: string; description: string }[] };
  const suggestions: PlaceSuggestion[] = (data.predictions ?? []).map((p) => ({
    place_id: p.place_id,
    description: p.description,
  }));

  return NextResponse.json(suggestions);
}
