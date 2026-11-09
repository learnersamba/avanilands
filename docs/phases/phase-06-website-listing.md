# Phase 6 — Website: explore, search, filter, sort, locations ✅

**Goal:** customers find the right land fast.
**Depends on:** Phase 5.

## Checklist
- [x] `/land` page backed by `search_properties` (server-rendered)
- [x] Search box: name, code, city, locality, type (typo-tolerant)
- [x] Filters: type, location, price range, area range with unit selector (converted to sq ft), road width, facing, availability, amenities, approved only
- [x] Sort: newest, price ↑↓, area ↑↓, featured
- [x] All filter/sort/page state in the URL (`?type=plots&city=visakhapatnam&page=2`); back button works — full list of address parameters in `web/src/lib/listing.ts`
- [x] Desktop filter column; mobile filter sheet with live "Show N results"
- [x] Active filter chips, clear all, result count
- [x] Pagination 12 per page with proper links (`rel` prev/next, canonical ignores sort)
- [x] Empty state with "clear filters" and contact CTA
- [x] Landing pages: `/land-for-sale/[city]` and `/[type]-for-sale/[city]` (e.g. `/plots-for-sale/visakhapatnam`) with intro text, unique title/description; hidden from Google while empty
- [x] `/locations` page and per-location cards with counts
- [x] Cover thumbnails with `srcset`, lazy loading below the fold, fixed aspect ratio (no layout shift)

## Done when
Every filter and sort gives correct results against the seed data (checked by automated tests), the URL can be copied and reopened with the same results, and the page stays fast with 500 test properties.

## Notes (2026-11-08)
- **Address parameters** (`web/src/lib/listing.ts`, 16 unit tests): `q`, `type` (type web words, comma list), `city` (location slugs), `min`/`max` (rupees; the home page's `budget=min-max` also works), `area_min`/`area_max` + `unit`, `road`, `facing`, `avail`, `amenity`, `approved=1`, `sort`, `page`. Bad values are dropped, reversed ranges swapped, unknown places match nothing (never everything). Repeated keys from a plain form submit are accepted.
- **Filters** are one real GET form: works without JavaScript (an "Apply filters" button appears); with JavaScript, choices apply at once and typed fields on Enter / leaving the field. Phones get a full-screen sheet with a live "Show N results" count (a server action asks the database), applied with one tap. Active filters show as removable chips (plain links).
- **Indexing**: `/land` and the landing pages are indexed; filtered / sorted variants are `noindex, follow` with a canonical that ignores sorting. Next.js streams page metadata into the body for browsers and Googlebot (documented behaviour; only bots that can't run JavaScript get it in `<head>`). Lighthouse flags this as "no meta description" on `/land` — review in Phase 7.
- **Builds**: only the newest 50 property pages are pre-built; the rest are built on first visit and cached. With all 509 test properties pre-built, the local database refused connections during the build.
- Location cards and footer links now go to `/land-for-sale/<city>`.
- **Speed with 509 properties** (`tool/load_test_properties.sql`): every search in the database under 10 ms (text, typo-tolerant, price + page 3, area + facing + road, amenities + approved, sold); production pages served in 4–250 ms uncached; listing HTML 27 KB compressed (phone filter sheet is only built when opened); Lighthouse mobile: listing 94 / 100 / 100 / 91, landing page 95 / 100 / 100 / 100.
- **Correctness**: for 8 addresses (search, types, place + availability, budget, area in cents, road + facing + approved, amenities incl. sold) the count on the page equals the database search called with hand-written arguments. Interaction checks in Chrome (16, all pass): tick type → address, results and heading change; combine filters; sort by price; remove a chip; Back restores; search on Enter; phone sheet live counts (3 → 4 with sold land) and apply.
- Fixed while testing: Enter in the search box did nothing (forms with several fields need a submit button), "Price on request" squeezed cards (Phase 5 follow-up), oversized build.
- Load-test data removed afterwards (`supabase db reset` + `tool/seed_photos.sh`); 105 database tests pass.
- Paging on landing pages continues on `/land?…&page=2` (most places have under 12 listings for now).
