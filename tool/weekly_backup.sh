#!/usr/bin/env bash
# Weekly off-site backup: database + every stored file → one dated archive,
# copied to a second provider with rclone (e.g. Cloudflare R2 or Backblaze B2).
# Keeps the last 8 archives locally and remotely. See docs/RECOVERY.md.
#
# Environment:
#   BACKUP_DB_URL        session pooler connection string (omit = local database)
#   SUPABASE_URL, SUPABASE_SECRET_KEY   for the files (omit = web/.env.local)
#   BACKUP_DIR           where archives are kept (default ~/avanilands-backups)
#   RCLONE_REMOTE        e.g. r2:avanilands-backups (omit = keep locally only)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${BACKUP_DIR:-$HOME/avanilands-backups}"
stamp="$(date -u +%Y-%m-%d)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$root/tool/backup_db.sh" "$work/backup-$stamp/db" ${BACKUP_DB_URL:+"$BACKUP_DB_URL"} > /dev/null
node "$root/tool/backup_files.mjs" backup "$work/backup-$stamp/files"
mkdir -p "$dir"
tar -czf "$dir/backup-$stamp.tar.gz" -C "$work" "backup-$stamp"
echo "Archive: $dir/backup-$stamp.tar.gz ($(du -h "$dir/backup-$stamp.tar.gz" | cut -f1))"

ls -1t "$dir"/backup-*.tar.gz | tail -n +9 | xargs -r rm --
if [[ -n "${RCLONE_REMOTE:-}" ]]; then
  rclone copy "$dir/backup-$stamp.tar.gz" "$RCLONE_REMOTE"
  rclone delete "$RCLONE_REMOTE" --min-age 60d
  echo "Copied to $RCLONE_REMOTE"
fi
