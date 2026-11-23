#!/usr/bin/env bash
# Builds the admin panel for hosting: release build with everything
# self-hosted (no Google CDN), plus the security headers (Content-Security-
# Policy for this environment's Supabase) and app routing (all routes →
# index.html) as build/firebase.json (Firebase Hosting, decision 131; deploy
# with tool/deploy_admin.sh) and as _headers/_redirects (Cloudflare Pages,
# and tool/serve_admin.sh locally).
# Usage: tool/build_admin.sh [env-file]   (default admin/env/local.json)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="${1:-$root/admin/env/local.json}"
# Absolute, so a relative path still works after the cd into admin/ below.
env_file="$(cd "$(dirname "$env_file")" && pwd)/$(basename "$env_file")"
supabase_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_URL"])' "$env_file")"
realtime_url="${supabase_url/http/ws}"

cd "$root/admin"
flutter build web --release --no-web-resources-cdn --dart-define-from-file="$env_file"

csp="default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; \
img-src 'self' data: blob: $supabase_url https://*.tile.openstreetmap.org https://tile.openstreetmap.org https://img.youtube.com; \
font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' $supabase_url $realtime_url https://fonts.gstatic.com https://tile.openstreetmap.org; media-src 'self' blob: $supabase_url; \
worker-src 'self' blob:; frame-src 'none'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

cat > build/web/_headers <<HEADERS
/*
  Content-Security-Policy: $csp
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
  X-Robots-Tag: noindex, nofollow
HEADERS
printf '/*  /index.html  200\n' > build/web/_redirects

# Firebase Hosting: same headers. Every file is revalidated (cheap: unchanged
# files answer 304), so staff get the new version right after a deploy
# instead of an hour-old cached page.
CSP="$csp" python3 - <<'PY'
import json, os
security = [
    {"key": "Content-Security-Policy", "value": os.environ["CSP"]},
    {"key": "X-Content-Type-Options", "value": "nosniff"},
    {"key": "X-Frame-Options", "value": "DENY"},
    {"key": "Referrer-Policy", "value": "strict-origin-when-cross-origin"},
    {"key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=(), payment=()"},
    {"key": "X-Robots-Tag", "value": "noindex, nofollow"},
    {"key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains"},
]
config = {"hosting": {
    "public": "web",
    "ignore": ["_headers", "_redirects"],
    "rewrites": [{"source": "**", "destination": "/index.html"}],
    "headers": [
        {"source": "**", "headers": [*security, {"key": "Cache-Control", "value": "no-cache"}]},
    ],
}}
with open("build/firebase.json", "w") as f:
    json.dump(config, f, indent=2)
PY
echo "Built admin/build/web (+ firebase.json, _headers, _redirects) for $supabase_url"
