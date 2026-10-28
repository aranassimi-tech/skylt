#!/usr/bin/env bash
# Runs the RLS tests against a throwaway database.
#   With Supabase CLI running locally:  DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres npm run test:rls
#     (run `supabase db reset` first; the test rolls back its own changes)
#   With a plain local PostgreSQL:       npm run test:rls
#     (creates a temporary database, applies the shim, migrations and seed, then drops it)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${DATABASE_URL:-}" ]; then
  psql "$DATABASE_URL" -X -f supabase/tests/rls.test.sql
  exit 0
fi

DB="skyltstudio_rls_$$"
createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT
run() { psql -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run -f supabase/tests/supabase-shim.sql
for f in supabase/migrations/*.sql; do run -f "$f"; done
run -f supabase/seed.sql
psql -X -d "$DB" -f supabase/tests/rls.test.sql
