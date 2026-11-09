#!/usr/bin/env bash
# Builds the admin panel exactly as it is hosted and serves it locally
# (SPA routing + the _headers file, so the security headers are tested too).
# Usage: tool/serve_admin.sh [port] [env-file]   (defaults: 3101, admin/env/local.json)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:-3101}"; env_file="${2:-$root/admin/env/local.json}"
"$root/tool/build_admin.sh" "$env_file"
exec python3 "$root/tool/spa_server.py" "$root/admin/build/web" "$port"
