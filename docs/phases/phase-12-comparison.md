# Phase 12 — Property comparison

**Goal:** a buyer picks up to 3 properties and sees them side by side, on a phone or a laptop, and can send the comparison to family as a link.
**Depends on:** Phases 6, 7, 11.

## Rules (decisions 89–93)
- Up to **3** properties. Picks are kept **on the device** (no sign-in needed); adding a 4th asks to remove one first.
- The comparison page address lists the property codes (`/compare?codes=AL-0001,AL-0003`), so it can be **shared** on WhatsApp and opens the same for anyone. It is not indexed by search engines.
- Rows: photo, price, price per sq ft (worked out so different units compare fairly), area, size/dimensions, type, place, road width, facing, corner, water, electricity, approval (+ RERA number), availability, amenities, highlights, and how far apart the properties are.
- The **best value** in a row is marked (lowest price per sq ft, widest road, biggest area); rows where everything is the same can be hidden.
- Properties that are no longer published are left out with a short note; sold land can still be compared.
- Distances between properties use the same location the property page shows (approximate where the exact spot is private), so they are "about" figures.

## Checklist
- [x] Comparison rules as plain functions (price per sq ft, best values, distances, reading the address) + unit tests
- [x] "Compare" button on property cards and the property page; a compare tray at the bottom with the picks and "Compare now"
- [x] `/compare` page: side-by-side table, sticky first column, scrolls sideways on phones; remove / add more; WhatsApp share; "only differences" switch
- [x] "Compare saved land" from My account (2–3 saved)
- [x] No database changes (all of it is public data); `/compare` noindex

## Done when
On a phone: add three properties from the listing → tray shows 3 → a 4th is refused politely → compare page shows them side by side with the cheapest per sq ft marked → share link opens the same comparison in a fresh browser → removing one updates the page and the link.

## Notes (2026-11-09)
- **Code:** `lib/compare.ts` (reading the address, price per sq ft, best values, distances; unit tests in `compare.test.ts`), `lib/compare-store.ts` (picks in the browser, shared between tabs), `getComparison()` in `lib/data.ts` (cached; properties + amenities in the order asked, plus missing codes), `components/compare/*` (button, tray, page controls), `app/compare/page.tsx`. The tray sits above the property page's phone action bar and hides on `/compare`.
- **Phones:** the table scrolls sideways inside the page (narrow sticky label column, ~180 px per property); the page itself never scrolls sideways. Columns are equal width so photos line up.
- **Checked:** 201 database, 60 website, 73 admin tests; security check; enquiry, listing and account flows still pass. Compare flow: 3 picks → 4th refused → compare now → best value marked → only-differences hides matching rows → shared link opens the same in a fresh browser (noindex) → remove one (page and device list update) → hidden code noted → tray above the action bar.
