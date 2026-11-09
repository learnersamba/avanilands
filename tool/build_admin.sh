#!/usr/bin/env bash
# Builds the admin panel for hosting (Cloudflare Pages): release build with
# everything self-hosted (no Google CDN), plus _headers (security headers,
# Content-Security-Policy for this environment's Supabase) and _redirects
# (all app routes → index.html).
# Usage: tool/build_admin.sh [env-file]   (default admin/env/local.json)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="${1:-$root/admin/env/local.json}"
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
echo "Built admin/build/web with _headers and _redirects for $supabase_url"
