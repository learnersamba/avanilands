#!/usr/bin/env bash
# Database backup: roles, schema and data as three plain SQL files (readable,
# restorable into any Supabase project). See docs/RECOVERY.md.
# Usage: tool/backup_db.sh <out-dir> [db-url]
#   db-url: the project's "Session pooler" connection string (Supabase
#   dashboard → Connect). Omit it to back up the local database.
set -euo pipefail
out="${1:?usage: tool/backup_db.sh <out-dir> [db-url]}"
mkdir -p "$out"
if [[ $# -ge 2 ]]; then source=(--db-url "$2"); else source=(--local); fi
supabase db dump "${source[@]}" --role-only -f "$out/roles.sql" < /dev/null
supabase db dump "${source[@]}" -f "$out/schema.sql" < /dev/null
# Supabase-internal storage tables we don't use (and can't write when restoring).
skip=storage.buckets_analytics,storage.buckets_vectors,storage.vector_indexes,storage.iceberg_namespaces,storage.iceberg_tables,storage.s3_multipart_uploads,storage.s3_multipart_uploads_parts,supabase_functions.hooks
supabase db dump "${source[@]}" --data-only --use-copy -x "$skip" -f "$out/data.sql" < /dev/null
ls -l "$out"
