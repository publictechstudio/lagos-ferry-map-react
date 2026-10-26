import { sql } from "./db";

/** Version and build time of the feed served at /gtfs.zip (src/app/gtfs.zip/route.ts). */
export async function getFeedInfo(): Promise<{ version: string | null; updatedAt: Date | null }> {
  const rows = await sql<{ version: string | null; updated_at: Date | null }[]>`
    SELECT version, updated_at FROM gtfs_zip_cache WHERE id = 1
  `;
  return { version: rows[0]?.version ?? null, updatedAt: rows[0]?.updated_at ?? null };
}
