import { sql } from "./db";
import type { Terminal } from "@/types/terminal";

export async function getTerminals(): Promise<Terminal[]> {
  const rows = await sql`
    SELECT id, name, area, description, lat, lng
    FROM ferry_terminals
    ORDER BY name
  `;
  return rows as Terminal[];
}
