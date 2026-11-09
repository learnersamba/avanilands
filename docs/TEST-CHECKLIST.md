# Test checklist (owner's plan → what was tested)

✅ tested and passing · 🔁 automated (re-runs with the test suites) · 📱 still to do by hand on real devices · ⏭ not in the MVP (no screen exists yet)

How the automated parts run: `supabase test db` (319 database tests), `cd web && npm test` (81), `cd admin && flutter test` (95), `node tool/security_check.mjs` (62 HTTP checks). Browser checks were done in Chrome (desktop 1440 px and phone 390 px) with Playwright during each phase; results are in each phase file's Notes.

## Customer

| Item | Status | How |
|------|--------|-----|
| Homepage | ✅ | Phase 5 browser checks; Lighthouse 90+ mobile |
| Navigation (header, phone menu, footer) | ✅ | Phase 5 |
| Property listing (paging, 24 per page) | ✅ | Phase 6, with 509 properties |
| Search | ✅ 🔁 | Phase 6; database search tests |
| Filters (type, place, price, area, road width, facing, availability, amenities, approved, featured) | ✅ 🔁 | Phase 6; counts matched the database |
| Sorting | ✅ 🔁 | Phase 6 |
| Property details | ✅ | Phase 7 |
| Gallery (viewer, keyboard, phone swipe) | ✅ | Phase 7 + Phase 9 re-run |
| Video (privacy player, loads on tap) | ✅ | Phase 7 |
| Map (lazy, exact pin vs approximate circle, directions) | ✅ | Phase 7 + Phase 9 re-run |
| Enquiry (property page and contact page, desktop and phone) | ✅ | Phase 8 journey |
| Site visit booking | ✅ 🔁 | Phase 10 journey (phone); database rule tests; available-days unit tests |
| Login / registration (email code) | ✅ 🔁 | Phase 11 journey; database tests |
| Wishlist (saved land) | ✅ 🔁 | Phase 11 journey; owner-only rules tested with a second customer |
| Comparison | ✅ | Phase 12 flow (phone + desktop, shared link, remove, hidden code) |
| Page views counted without cookies (bots, Do Not Track, previews skipped) | ✅ 🔁 | Phase 16 check (phone + desktop); unit and database tests |
| Notifications (customer updates, saved-land emails, admin bell) | ✅ 🔁 | Phase 15 journey; 23 database tests |
| Mobile responsiveness (no sideways scrolling, action bar) | ✅ 📱 | 390 px emulation; real devices below |

## Admin

| Item | Status | How |
|------|--------|-----|
| Login / logout / forgot password / invite | ✅ 🔁 | Phase 2; redirect + login widget tests |
| Dashboard | ✅ | Phase 2, Phase 8 (tap counts) |
| Create / edit property | ✅ | Phase 3 |
| Publish / unpublish / archive | ✅ 🔁 | Phase 3, Phase 8 journey; database rule tests |
| Delete property (drafts without enquiries only) | ✅ 🔁 | Database tests |
| Change price / status | ✅ 🔁 | Phase 3; logged in history (activity text tests) |
| Upload / delete / reorder images, change cover | ✅ | Phase 4 |
| Upload / delete video (YouTube + file) | ✅ | Phase 4 |
| Upload documents (public / private) | ✅ 🔁 | Phase 4; private documents checked by security_check |
| Manage enquiries (list, filters, status + note, assign, CSV, live alert) | ✅ | Phase 8 |
| Manage website content (settings, locations, types, amenities) | ✅ | Phase 2–3 |
| Website content: home, About, FAQs, testimonials, banners, legal pages (draft → preview → publish) | ✅ 🔁 | Phase 14 journey; 29 database tests |
| Manage site visits (confirm, move, done, cancel, notes, assign, calendar) | ✅ | Phase 10 journey |
| Analytics (ranges, numbers, funnel, per property, places, sources, devices, CSV) | ✅ 🔁 | Phase 16 journey; 29 database tests; report widget and CSV tests |
| Manage bookings (every step, roles, payment record, start from a visit) | ✅ 🔁 | Phase 13 journey; 39 database tests |

## Negative tests

| Item | Status | How |
|------|--------|-----|
| Invalid input / missing required fields | ✅ 🔁 | Form validators (web + admin unit tests); database checks |
| Unauthorized API calls (visitor, signed-in non-admin) | ✅ 🔁 | Exposure scan (every table, policy and function) + security_check |
| Invalid file types / oversized files | ✅ 🔁 | Admin rules tests; storage limits by direct API calls (security_check) |
| Duplicate records (double-submit, duplicate slugs/codes) | ✅ 🔁 | Idempotency key; unique constraints in database tests |
| Invalid property IDs / addresses | ✅ | Real 404 pages (Phase 7) |
| Deleted / archived property access | ✅ 🔁 | 410 "no longer available" page; routing tests |
| Enquiry about a sold property | ✅ 🔁 | Form hidden on sold pages; database refuses it (`property_unavailable`) |
| Sold / reserved property booking | ✅ 🔁 | Refused by the database; booking page explains; no booking link on the property |
| Property becomes reserved during booking (two buyers at once) | ✅ 🔁 | Two real simultaneous approvals: one wins, the other is refused |
| Reserved property | ✅ | Still accepts enquiries with "ask about similar" wording (decision 10) |
| Unauthorized admin access (non-admin account) | ✅ 🔁 | Signed out with an explanation; redirect tests |
| Expired sessions / invalid tokens | ✅ 🔁 | Forged token refused (security_check); expired session → sign-in page |
| Spam: 6th enquiry in an hour (phone, IP); missing bot check | ✅ 🔁 | Phase 8 journey; Turnstile unit tests |

## Edge cases

| Item | Status | How |
|------|--------|-----|
| No images / one / many | ✅ | Placeholder artwork; phone strip; 20-photo Lighthouse run |
| No video / no map coordinates / no nearby places | ✅ | Sections simply don't show |
| Price changed | ✅ | Website updates within seconds; history shows old → new |
| Becomes sold while a customer is viewing | ✅ 🔁 | Enquiry is refused with a friendly message (`property_unavailable`) |
| Customer sends several enquiries | ✅ 🔁 | Allowed up to 5 an hour; then a friendly message |
| Admin archives a property with enquiries | ✅ 🔁 | Allowed; enquiries kept; delete refused |
| Network failure during upload | ✅ | Upload shows the error and can be retried (Phase 4) |
| Network failure during enquiry | ✅ | Typed details kept; message to try again or WhatsApp |

## Devices and browsers 📱

Automated checks covered Chrome only. Before launch, on **staging**, someone opens the home page, a listing with filters, a property page (photos, map), and sends one enquiry on each:

| Device | Browser | Done by / date |
|--------|---------|----------------|
| Small Android (360 px) | Chrome | |
| Standard Android | Chrome | |
| iPhone | Safari | |
| Tablet | Safari or Chrome | |
| Laptop | Chrome, Firefox, Edge | |
| Large desktop | Chrome | |
| Admin panel on a laptop | Chrome, Edge | |
| Admin panel on a phone (check enquiries, call / WhatsApp) | Chrome / Safari | |

## Before launch (from the plan)

Functional ✅ · Security ✅ (local; repeat on staging) · Performance ✅ (Lighthouse 90+) · Mobile 📱 · Browsers 📱 · SEO ✅ (sitemap, structured data, canonical links; Search Console at launch) · Analytics, backups on production, admin access, domain, SSL, production environment → [DEPLOY.md](DEPLOY.md) § 9.
