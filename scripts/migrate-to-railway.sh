#!/usr/bin/env bash
# Dumps data from Neon and restores it to Railway.
#
# Usage:
#   NEON_DATABASE_URL="postgresql://..." \
#   RAILWAY_DATABASE_URL="postgresql://..." \
#   ./scripts/migrate-to-railway.sh
set -euo pipefail

: "${NEON_DATABASE_URL:?NEON_DATABASE_URL must be set}"
: "${RAILWAY_DATABASE_URL:?RAILWAY_DATABASE_URL must be set}"

DUMP_FILE="neon_dump_$(date +%Y%m%d_%H%M%S).sql"

echo "▶ Dumping from Neon → $DUMP_FILE"
pg_dump "$NEON_DATABASE_URL" \
  --no-owner \
  --no-acl \
  -f "$DUMP_FILE"

echo "▶ Restoring to Railway…"
psql "$RAILWAY_DATABASE_URL" -f "$DUMP_FILE"

echo "✓ Migration complete. Dump saved to $DUMP_FILE"
