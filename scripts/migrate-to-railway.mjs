/**
 * Migrates all tables from Neon to Railway.
 *
 * Usage:
 *   NEON_DATABASE_URL="postgresql://..." \
 *   RAILWAY_DATABASE_URL="postgresql://..." \
 *   node scripts/migrate-to-railway.mjs
 */
import postgres from "postgres";

const NEON_URL = process.env.NEON_DATABASE_URL;
const RAILWAY_URL = process.env.RAILWAY_DATABASE_URL;

if (!NEON_URL || !RAILWAY_URL) {
  console.error("Both NEON_DATABASE_URL and RAILWAY_DATABASE_URL must be set.");
  process.exit(1);
}

const src = postgres(NEON_URL, { ssl: "require", max: 1 });
const dst = postgres(RAILWAY_URL, { ssl: { rejectUnauthorized: false }, max: 1 });

console.log("Connecting to both databases…");
await src`SELECT 1`;
await dst`SELECT 1`;
console.log("Connected.");

// ── 1. Get all user tables ───────────────────────────────────────────────────
const tables = await src`
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
  ORDER BY table_name
`;
console.log("Tables found:", tables.map((t) => t.table_name).join(", "));

// ── 2. Recreate schema on Railway ────────────────────────────────────────────
for (const { table_name } of tables) {
  const cols = await src`
    SELECT
      column_name,
      data_type,
      character_maximum_length,
      numeric_precision,
      numeric_scale,
      is_nullable,
      column_default,
      udt_name
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = ${table_name}
    ORDER BY ordinal_position
  `;

  const pkCols = await src`
    SELECT kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema = 'public'
      AND tc.table_name = ${table_name}
    ORDER BY kcu.ordinal_position
  `;
  const pkSet = new Set(pkCols.map((r) => r.column_name));

  const colDefs = cols.map((c) => {
    let type;
    if (c.udt_name === "geometry") {
      type = "text";
    } else if (c.data_type === "ARRAY") {
      type = `${c.udt_name.replace(/^_/, "")}[]`;
    } else if (c.data_type === "character varying") {
      type = c.character_maximum_length ? `varchar(${c.character_maximum_length})` : "varchar";
    } else if (c.data_type === "character") {
      type = c.character_maximum_length ? `char(${c.character_maximum_length})` : "char";
    } else if (c.data_type === "numeric") {
      type = c.numeric_precision ? `numeric(${c.numeric_precision},${c.numeric_scale ?? 0})` : "numeric";
    } else if (c.data_type === "USER-DEFINED") {
      type = c.udt_name;
    } else {
      type = c.data_type;
    }

    let defaultExpr = c.column_default ?? null;
    if (defaultExpr?.startsWith("nextval(")) {
      if (type === "integer") type = "serial";
      else if (type === "bigint") type = "bigserial";
      else if (type === "smallint") type = "smallserial";
      defaultExpr = null;
    }

    let def = `  "${c.column_name}" ${type}`;
    if (defaultExpr) def += ` DEFAULT ${defaultExpr}`;
    if (c.is_nullable === "NO" && !pkSet.has(c.column_name)) def += " NOT NULL";
    return def;
  });

  if (pkCols.length > 0) {
    colDefs.push(`  PRIMARY KEY (${pkCols.map((r) => `"${r.column_name}"`).join(", ")})`);
  }

  const createSQL = `CREATE TABLE IF NOT EXISTS "${table_name}" (\n${colDefs.join(",\n")}\n)`;
  console.log(`  Creating table "${table_name}"…`);
  await dst.unsafe(`DROP TABLE IF EXISTS "${table_name}" CASCADE`);
  await dst.unsafe(createSQL);
}

// ── 3. Copy data ─────────────────────────────────────────────────────────────
for (const { table_name } of tables) {
  const rows = await src.unsafe(`SELECT * FROM "${table_name}"`);
  if (rows.length === 0) {
    console.log(`  "${table_name}": 0 rows, skipping.`);
    continue;
  }

  const cols = Object.keys(rows[0]);
  const BATCH = 500;
  let inserted = 0;

  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH);
    await dst`INSERT INTO ${dst(table_name)} ${dst(batch, cols)}`;
    inserted += batch.length;
  }
  console.log(`  "${table_name}": ${inserted} rows copied.`);
}

await src.end();
await dst.end();
console.log("\n✓ Migration complete.");
