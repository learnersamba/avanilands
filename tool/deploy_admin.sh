#!/usr/bin/env bash
# Builds the admin panel for an environment and publishes it on Firebase
# Hosting (decision 131). First time on a computer: npx firebase-tools login
# Usage: tool/deploy_admin.sh <env-file> [firebase-project]
#   e.g. tool/deploy_admin.sh admin/env/production.json        (project: avanilands)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="${1:?usage: tool/deploy_admin.sh <env-file> [firebase-project]}"
project="${2:-avanilands}"
"$root/tool/build_admin.sh" "$env_file"
npx -y firebase-tools@latest deploy --only hosting --project "$project" \
  --config "$root/admin/build/firebase.json" \
  --message "admin $(git -C "$root" rev-parse --short HEAD)"
