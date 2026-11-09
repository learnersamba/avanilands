#!/usr/bin/env bash
# Creates placeholder "landscape" photos for the sample properties in
# supabase/seed.sql (paths starting with seed/) and uploads them to the
# local Supabase. Local development only. Needs ffmpeg with libwebp.
# Usage: tool/seed_photos.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

api="$(supabase status -o env 2>/dev/null | grep '^API_URL=' | cut -d'"' -f2)"
key="$(supabase status -o env 2>/dev/null | grep '^SECRET_KEY=' | cut -d'"' -f2)"
[[ -n "$api" && -n "$key" ]] || { echo "Start Supabase first (supabase start)." >&2; exit 1; }
case "$api" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "Refusing: not a local Supabase ($api)." >&2; exit 1;; esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Sky and land colours, cycled per photo: green fields, red soil, golden crops, orchard, dry land.
lands=("4f7d3a:8fb35a" "8a4b2a:c27a4a" "a88a3a:dcc070" "2f5d34:6f9a4c" "9c7b52:cdb48a")
skies=("8ec5e8:e8f4fb" "9fc9e0:f3efe2" "b7d3e6:fdf6e3")

rows="$(curl -sf "$api/rest/v1/property_images?select=path_thumb,path_medium,path_large&path_thumb=like.seed/*&order=property_id,sort_order" \
  -H "apikey: $key" -H "Authorization: Bearer $key")"
count="$(echo "$rows" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')"
echo "Making $count placeholder photos…"

i=0
echo "$rows" | python3 -c 'import sys,json
for r in json.load(sys.stdin): print(r["path_thumb"], r["path_medium"], r["path_large"])' |
while read -r thumb medium large; do
  land="${lands[$((i % ${#lands[@]}))]}"
  sky="${skies[$((i % ${#skies[@]}))]}"
  horizon=$((520 + (i * 37) % 160))
  src="$work/$i.png"
  ffmpeg -nostdin -loglevel error -y \
    -f lavfi -i "gradients=s=2000x${horizon}:c0=0x${sky%%:*}:c1=0x${sky##*:}:x0=0:y0=0:x1=0:y1=${horizon}:nb_colors=2:d=1" \
    -f lavfi -i "gradients=s=2000x$((1500 - horizon)):c0=0x${land##*:}:c1=0x${land%%:*}:x0=0:y0=0:x1=600:y1=$((1500 - horizon)):nb_colors=2:d=1" \
    -filter_complex "[0][1]vstack=inputs=2,noise=alls=3:allf=u,drawtext=text='Sample photo':font=Sans:fontsize=56:fontcolor=white@0.85:x=60:y=h-110" \
    -frames:v 1 "$src"
  for pair in "$thumb:400" "$medium:1200" "$large:2000"; do
    path="${pair%%:*}"; width="${pair##*:}"
    out="$work/$i-$width.webp"
    ffmpeg -nostdin -loglevel error -y -i "$src" -vf "scale=${width}:-2" -quality 80 "$out"
    curl -sS --fail-with-body -o /dev/null -X POST "$api/storage/v1/object/property-media/$path" \
      -H "apikey: $key" -H "Authorization: Bearer $key" \
      -H "Content-Type: image/webp" -H "x-upsert: true" -H "cache-control: max-age=31536000" \
      --data-binary @"$out"
  done
  i=$((i + 1))
done
# Placeholder PDFs for the sample documents (private bucket).
docs="$(curl -sf "$api/rest/v1/property_documents?select=storage_path,title&storage_path=like.seed/*" \
  -H "apikey: $key" -H "Authorization: Bearer $key")"
echo "$docs" | python3 -c 'import sys,json
for d in json.load(sys.stdin): print(d["storage_path"] + "\t" + d["title"])' |
while IFS=$'\t' read -r path title; do
  pdf="$work/doc.pdf"
  printf '%%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj 4 0 obj<</Length 60>>stream\nBT /F1 20 Tf 72 760 Td (Sample document: %s) Tj ET\nendstream endobj 5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj trailer<</Root 1 0 R>>\n%%%%EOF\n' "$title" > "$pdf"
  curl -sS --fail-with-body -o /dev/null -X POST "$api/storage/v1/object/property-documents/$path" \
    -H "apikey: $key" -H "Authorization: Bearer $key" -H "Content-Type: application/pdf" -H "x-upsert: true" \
    --data-binary @"$pdf" < /dev/null
done
echo "Done."
