# Phase 16 — Analytics

**Goal:** the team can see what the website brings in, and what turns into sales. That covers how many people visit, which land they look at, where they search, how many enquire, visit, save and book, and how much of it ends in a sale. From the plan: *property views, unique visitors, enquiries, site visits, saves, bookings, sales per property; funnel and conversion rates, top searched locations, top properties, date ranges, CSV export.*

## What is measured
| Number | Where it comes from |
|--------|--------------------|
| Visitors, page views, property views | **New:** the website records each page shown (no cookies, nothing personal) |
| Searched locations / land types | **New:** the same record: `city` / `type` filters on /land, and the location landing pages |
| Sources (Google, WhatsApp, Facebook, direct…) and devices | **New:** only the first page of a visit carries where it came from (domain only) |
| Enquiries, site visit requests, saves, booking requests, sales | Already in the database (Phases 8, 10, 11, 13). A sale is a booking marked **completed** |
| WhatsApp / call taps | Already counted since Phase 8 |

## Rules (decisions 118–124)
- **First-party and cookieless.** The website counts its own page views: no Google Analytics, no cookies, no consent banner. IP addresses and browser details are never stored. The web server turns them into a hash, and the database hashes that again with a **random salt that changes every day and is deleted after two days**. Afterwards nobody, not even us, can link a visitor across days or work back to an IP.
- **Unique visitors are counted per day:** someone who comes back on another day counts again. Ranges add up the daily visitors.
- **Not counted:** search-engine bots and link previews, browsers that send *Do Not Track* / *Global Privacy Control*, content previews (`/preview`), and anything past 1,000 pages per visitor per day.
- **The funnel compares totals, not people:** visitors → property viewers → enquiries + site visit requests → booking requests → sales. No individual is followed through it.
- **Dates are in India time.** A range can cover up to 366 days, and each figure is compared with the same-length period just before it.
- Raw page views are kept for **13 months**, then deleted by the daily job.
- **Every admin** can see analytics.

## Checklist
### Database
- [x] `page_views` (nobody reads or writes it directly; admins see it through the report), daily salts (private), `track_page_view` (website only) resolving property / locations / types itself
- [x] `analytics_report(from, to)`: totals plus previous period, daily series, funnel, every property with activity, top locations / types, sources, devices
- [x] `cleanup_analytics()` in the daily job; dashboard gets "visitors (7 days)"
- [x] Demo page views in the local seed; pgTAP tests (incl. exposure scan)

### Website
- [x] Page tracker (every page, in-app navigation too) → `/api/track` (same-site only, bots / DNT / GPC skipped)
- [x] Unit tests for bot, device, referrer and filter parsing
- [x] Privacy policy default text mentions cookieless statistics

### Admin
- [x] **Analytics** page: range presets + custom, number tiles with change, daily chart, funnel with conversion rates, top properties (sortable), locations, land types, sources, devices
- [x] CSV export: per property and per day
- [x] Dashboard tile

## Done when
Browsing the website on a phone and a laptop (a property page, a city search, a location page) shows up in the admin's Analytics within seconds. The visit is counted with the right device, property, location and source, and a bot or a Do Not Track browser isn't counted. The enquiry, visit, save and booking numbers match the records. The CSV exports open in Excel. Nothing in `page_views` can identify a person.

## Notes (2026-11-09)
- **Database:** `20261109150001_analytics.sql`: `page_views` (no direct access for anyone; admins read through the report), `private.analytics_salts`, `track_page_view` (website only; finds the property from `/land/<slug>`, places and land types from the `/land` filters and `/<type>-for-sale/<place>` pages, ignores hidden or unknown ones; 1,000 pages per visitor per day), `analytics_report(from, to)` (India-time days, at most 366; totals plus the period before, daily rows, every published or active property, places, land types, sources from the first page of a visit, devices), `cleanup_analytics` (13 months), `dashboard_summary.visitors_last_7_days`, a privacy policy section (and the same in the website's fallback text). The local seed adds 120 days of demo page views. Tests: `12_analytics.test.sql` (29); the exposure scan covers the new table and functions.
- **Website:** `PageTracker` in the layout (each address once, including in-app navigation; paging and sorting the same search isn't new; the referrer only on the first page and only from other sites) → `POST /api/track` (skips cross-site requests, bots, DNT / GPC and oversized bodies; always answers 204). `lib/analytics.ts` holds the parsing (10 unit tests); `visitorClient()` holds the first hash; the daily job also runs `cleanup_analytics`. Three new security checks.
- **Admin:** `/analytics` (all admins). Range chips plus a date picker, kept in the address. Number tiles show the change, with screen-reader labels. Also a daily bar chart, the funnel, a sortable property table (top 10 or all, row opens the property), and lists of places, land types, sources and devices. Export menu: per property and per day. The report view is a separate widget so it can be tested. Dashboard tile "Website visitors". Tests: 7 (ranges, changes, funnel, CSV, widget sorting).
- **Checked:**
  - 319 database, 81 website and 95 admin tests; 62 security checks; production build (54 pages).
  - Earlier flows: enquiry, listing, compare, account and notifications.
  - Tracking check:
    - A phone arriving from Google browsed home → a search → paging → a property (in the app) → a landing page. That counted 4 page views with the right property, places, land type, source and device.
    - A desktop visit counted as a direct visit.
    - Paging, a preview page, a Do Not Track browser and a headless (bot) browser were not counted.
  - Journey:
    - The admin had Analytics open; a new phone visitor appeared after Refresh (+1 visitor, +1 property view).
    - The same phone on the same day was not counted twice.
    - Both CSV files downloaded with the right rows.
    - A chosen October range showed its dates and compared with the 31 days before.
  - Screens checked at 1440 px and 390 px. A narrow-card overflow found by the widget test was fixed.
- **Not covered:** sales only appear once bookings are marked completed; the local demo has none, so the Sales tile was checked by database tests only.
