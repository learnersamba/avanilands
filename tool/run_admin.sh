#!/usr/bin/env bash
# Runs the Flutter admin panel on a local web server (default port 3101).
set -euo pipefail
cd "$(dirname "$0")/../admin"
exec flutter run -d web-server --web-hostname 127.0.0.1 --web-port "${1:-3101}" \
  --dart-define-from-file=env/local.json
