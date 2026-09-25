import { NextResponse } from "next/server";
import { legacyRoutePath } from "@/lib/legacyRedirect";

export const dynamic = "force-dynamic";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ rest: string }> },
) {
  const { rest } = await params;
  const path = await legacyRoutePath(decodeURIComponent(rest));
  return NextResponse.redirect(new URL(path, request.url), 301);
}
