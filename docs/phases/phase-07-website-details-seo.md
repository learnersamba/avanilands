# Phase 7 — Website: property details, map and SEO ✅

**Goal:** the property page gives every important detail and ranks well on Google.
**Depends on:** Phase 6 and Phase 4 (media).

## Checklist
### Details page `/land/[slug]`
- [x] Gallery: hero + thumbnails, swipe on mobile, full-screen viewer with keyboard support; works with 0, 1 or many images (placeholder artwork when none)
- [x] Video tab with YouTube lite embed / MP4 player; hidden when no video
- [x] Title block: title, code, location, status badge, price, per-unit price, negotiable
- [x] Overview grid, highlights, description, amenities, nearby places (hidden when empty)
- [x] Map (Leaflet, lazy): exact pin or approximate circle; hidden when no coordinates; "Get directions" only for exact locations
- [x] Documents & approvals: approval info, public documents via `/api/documents/[id]` (signed 5-min link)
- [x] Sticky enquiry panel (desktop) / bottom bar Call · WhatsApp · Enquire (mobile); WhatsApp message pre-filled with code and title
- [x] Reserved and Sold banners and behaviour (decision 10)
- [x] Related properties (same type or location)
- [x] Old slug → 301 redirect; unknown/unpublished → 404; archived → 410 "no longer available" page with related properties (done in `web/src/proxy.ts`, see notes)

### SEO
- [x] `generateMetadata`: title, description, canonical, Open Graph + Twitter card with cover image
- [x] JSON-LD: Organization (site-wide), RealEstateListing/Offer/Place, BreadcrumbList
- [x] `sitemap.xml` (properties, locations, landing pages, static pages) and `robots.txt`
- [x] Heading order and alt text checked

### Freshness
- [x] `/api/revalidate` (secret header) + database triggers (pg_net) on properties, images, videos, documents, amenities, nearby places, locations, types, settings → pages update within seconds of an admin change

## Done when
An admin change (price, photo, status) shows on the live page within a minute; Google's Rich Results test shows no errors; Lighthouse mobile ≥ 90 on a details page with 20 images.

## Notes (2026-11-08)
- **Property page** (`web/src/app/land/[slug]/page.tsx` + `web/src/components/property/`): photo grid on desktop and swipe strip on phones, full-screen viewer (arrows, swipe, Esc, large size); YouTube "lite" player (privacy-enhanced `youtube-nocookie`, loads only when tapped) or MP4; Leaflet map loaded only when scrolled to — pin + "Get directions" when the exact location is allowed, otherwise a ~1 km circle and no directions; public documents link to `/api/documents/<id>`; preview banners removed; a placeholder shaped like the page so nothing jumps while it loads.
- **Routing before the page** (`web/src/proxy.ts`, database function `property_route`): current link → page; old link → 301; archived → 410 page with similar land; hidden / draft / unknown / malformed → real 404. Answers are remembered for 1 minute per server. This also fixes the Phase 5/6 "404 page with status 200".
- **Documents** (`/api/documents/<id>`): only public documents of published properties; redirects to a 5-minute signed link that downloads with a readable file name; private, hidden-property and malformed ids → 404. Uses the secret key on the server only (`web/src/lib/supabase/admin.ts`).
- **Instant refresh**: migration `20261108130001_website_routing_and_refresh.sql` adds statement-level triggers that POST `{"table": …}` to the website (via `pg_net`, after commit). Address and secret come from **Supabase Vault** (`website_revalidate_url`, `website_revalidate_secret`) — the local pair is in `supabase/seed.sql`, the secret is `REVALIDATE_SECRET` in `web/.env.local`. Production must create its own pair (Phase 9). `/api/revalidate` checks the secret in constant time and refreshes only known tags (`web/src/lib/revalidate-tags.ts`). Tested: a price change showed on the page within 1 second.
- **SEO**: per-property title, description, canonical, Open Graph + Twitter image (cover photo); structured data RealEstateAgent (every page), RealEstateListing with Offer and Place (exact position only when allowed), BreadcrumbList; `sitemap.xml` (home, listing, landing pages with land on sale, every published property with last-modified, static pages) and `robots.txt` (blocks `/api/` and the 404/410 helper pages). `htmlLimitedBots: /.*/` puts metadata in `<head>` for every visitor (Google ignores canonical links outside `<head>`).
- **Map tiles**: OpenStreetMap by default; set `NEXT_PUBLIC_MAP_TILE_URL` / `NEXT_PUBLIC_MAP_ATTRIBUTION` to a provider plan before launch (the security policy follows automatically). Map code and styles load only with the map (it was slowing first paint).
- **Tests**: 25 website unit tests (9 new: structured data, refresh tags), 113 database tests (8 new: routing and refresh triggers), 21 property-page checks in Chrome (viewer, video, map exact/approximate, document download, private document hidden, phone strip/viewer/action bar, no sideways scroll), all earlier listing checks still pass.
- **Lighthouse (mobile)**: property page 91–93 / 100 / 100 / 100; with 20 photos 90–93 / 100 / 100 / 100 (≈640 KB); first visit right after a cache refresh 87–88 (content streams in; no layout jump). The 410 page can't be scored (Lighthouse skips non-200 pages).
- **Not done here**: Google's Rich Results test needs a public address (run it after launch, Phase 9). Enquiry form still sends from Phase 8.
