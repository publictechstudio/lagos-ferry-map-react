import { NextResponse } from "next/server";

/** Permanently redirect old /sitemap.txt to the canonical XML sitemap. */
export function GET() {
  return NextResponse.redirect(
    new URL("/sitemap.xml", process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com"),
    { status: 301 }
  );
}
