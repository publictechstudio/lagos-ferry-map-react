import { NextResponse } from "next/server";
import { getFacilityPanelData } from "@/lib/facilityPanel";

export const revalidate = 60;

/** Same data the facility page renders on the server, for when the user picks a facility on the map. */
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ facilityId: string }> }
) {
  const { facilityId } = await params;
  const id = parseInt(facilityId, 10);
  if (isNaN(id)) {
    return NextResponse.json({ error: "Invalid facility ID" }, { status: 400 });
  }
  return NextResponse.json(await getFacilityPanelData(id));
}
