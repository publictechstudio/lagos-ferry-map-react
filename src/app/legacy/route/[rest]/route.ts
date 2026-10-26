import { NextResponse } from "next/server";
import { legacyRoutePath } from "@/lib/legacyRedirect";
import { SITE_URL } from "@/lib/constants";

export const dynamic = "force-dynamic";

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ rest: string }> },
) {
  const { rest } = await params;
  const path = await legacyRoutePath(decodeURIComponent(rest));
  // Not request.url: behind the proxy it is an internal address, and the redirect would point there
  return NextResponse.redirect(new URL(path, SITE_URL), 301);
}
