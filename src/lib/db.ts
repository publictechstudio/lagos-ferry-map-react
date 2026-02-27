import { neon } from "@neondatabase/serverless";

const dbUrl = process.env.NEON_DATABASE_URL || process.env.DATABASE_URL;

if (!dbUrl) {
  throw new Error("NEON_DATABASE_URL environment variable is not set");
}

export const sql = neon(dbUrl);
