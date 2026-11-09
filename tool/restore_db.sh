#!/usr/bin/env bash
# Loads a data backup (from tool/backup_db.sh) into a database that already
# has the schema (a new project after `supabase db push`, or local after
# `supabase db reset --no-seed`). Empties every table in the backup first,
# then loads it in one transaction: it either all works or nothing changes.
# See docs/RECOVERY.md.
# Usage: tool/restore_db.sh <backup-dir> <db-url>
set -euo pipefail
dir="${1:?usage: tool/restore_db.sh <backup-dir> <db-url>}"
url="${2:?usage: tool/restore_db.sh <backup-dir> <db-url>}"
data="$dir/data.sql"
[[ -f "$data" ]] || { echo "No $data" >&2; exit 1; }

tables="$(grep -o '^COPY "[a-z_]*"\."[a-z_]*"' "$data" | cut -c6- | paste -sd, -)"
if command -v psql > /dev/null; then
  run_psql() { psql "$url" "$@"; }
else
  # No local psql: use the Postgres client from the Supabase image.
  image="${PSQL_IMAGE:-public.ecr.aws/supabase/postgres:17.6.1.167}"
  run_psql() { docker run --rm -i --network host --entrypoint psql "$image" "$url" "$@"; }
fi

{
  echo "set session_replication_role = replica;"   # skip triggers (audit log, website refresh)
  echo "truncate $tables cascade;"
  cat "$data"
} | run_psql -v ON_ERROR_STOP=1 --single-transaction -q
echo "Restored data from $data"
