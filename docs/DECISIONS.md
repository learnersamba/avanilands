# Decisions Log — Avanilands

Every confirmed decision is recorded here. Read this before starting any phase.
**Status:** ✅ confirmed by the owner · 🟡 proposed default — the owner should confirm or change it (see *Open questions* at the bottom).

## Confirmed and proposed decisions

| # | Date | Status | Decision | Reason |
|---|------|--------|----------|--------|
| 1 | 2026-11-08 | ✅ | **Next.js** for the customer website | Server-rendered pages Google can read; fast; best fit for SEO-heavy property pages |
| 2 | 2026-11-08 | ✅ | **Flutter (web)** for the admin panel | Owner knows it from Godavari Ghaatu; can become a mobile app later |
| 3 | 2026-11-08 | ✅ | **Supabase** as the backend (Postgres, Auth, Storage, Edge Functions) | Replaces the FastAPI + Postgres + object storage in the original plan; one service, free to start |
| 4 | 2026-11-08 | ✅ | **No git** until the repo name is final | Owner's choice |
| 5 | 2026-11-08 | ↩ | Working brand name **BhoomiKart**; property codes looked like `BK-0001` | Replaced by 128 |
| 6 | 2026-11-08 | 🟡 | Property status is split into **two fields**: **publish state** (Draft, Published, Hidden, Archived) and **availability** (Available, Reserved, Sold) | The original single list mixes two ideas. A published property can be Reserved; a draft can't be "Sold" in any useful way. Two fields keep filters and rules simple. All 7 original statuses still exist |
| 7 | 2026-11-08 | 🟡 | Property types at launch: Residential Plots, Agricultural Land, Commercial Land, Industrial Land, Farm Land, Villa Plots. Stored in a table the admin can edit | Matches the plan; admin can hide types not needed |
| 8 | 2026-11-08 | 🟡 | Area units: **sq ft, sq yards, sq metres, cents, guntas, acres**. Every area is also saved in sq ft so filters and sorting work across units | Units used in Andhra Pradesh and Telangana |
| 9 | 2026-11-08 | 🟡 | Price is the **total price in ₹**. Optional "price per unit" shown alongside (e.g. ₹18,000 / sq yd). "Price on request" allowed. "Negotiable" flag | Customers compare totals; per-unit is how land is often quoted locally |
| 10 | 2026-11-08 | 🟡 | Reserved properties stay visible with a **Reserved** badge and still accept enquiries ("ask about similar"). Sold properties stay visible with a **Sold** badge, no enquiry form, and show related properties; the admin hides them when ready | Builds trust (shows real sales) without wasting leads |
| 11 | 2026-11-08 | 🟡 | **Delete** only for drafts that have no enquiries. Everything else is **archived** (hidden everywhere, kept for history) | Enquiries and audit history keep working |
| 12 | 2026-11-08 | 🟡 | URL slug is generated from the title when first published and **does not change** after that; later changes add a redirect | Keeps Google links and shared links working |
| 13 | 2026-11-08 | 🟡 | Customers browse and enquire **without an account** in the MVP | Matches the plan; least friction |
| 14 | 2026-11-08 | 🟡 | Enquiries go through a **Next.js server action**: validation → Cloudflare Turnstile bot check → rate limit → database. No direct public writes to the database | Stops spam and protects the database |
| 15 | 2026-11-08 | 🟡 | New enquiry → **email to the sales inbox** (Resend, free tier) + live badge in the admin panel | Email is free and reliable; WhatsApp/SMS alerts later |
| 16 | 2026-11-08 | 🟡 | Contact methods on the site: **phone call, WhatsApp, email, enquiry form**, office address | WhatsApp is how most Indian buyers prefer to talk |
| 17 | 2026-11-08 | 🟡 | Maps: **OpenStreetMap-based maps (Leaflet on the website, flutter_map in admin)** with a free tile provider. Google Maps later if needed | Free; Google Maps needs billing set up and costs per load |
| 18 | 2026-11-08 | 🟡 | Each property has a **"show exact location"** switch. When off, the website shows only an approximate circle, not the pin | Protects sites before sale; the plan says not to expose sensitive location data |
| 19 | 2026-11-08 | 🟡 | Documents are **private by default**. Public documents are served through short-lived links created by the website server; private ones only to admins | Never expose legal files by accident |
| 20 | 2026-11-08 | 🟡 | Videos: **YouTube links** (unlisted is fine) are the main option; direct upload allowed up to 50 MB | Video hosting and bandwidth are free on YouTube; Supabase storage bandwidth costs money |
| 21 | 2026-11-08 | 🟡 | Images are shrunk **in the admin browser** to WebP in 3 sizes (400, 1200, 2000 px) before upload | Fast pages without paid image resizing; same approach that worked for Godavari Ghaatu |
| 22 | 2026-11-08 | 🟡 | Admin roles in v1: **Super Admin** and **Admin**. Super Admin also manages admin users and settings. More roles later | Plan says don't overcomplicate v1 |
| 23 | 2026-11-08 | 🟡 | Admins are **invited by email** by a Super Admin; nobody can sign up as an admin | Admin access is never self-service |
| 24 | 2026-11-08 | 🟡 | Audit log is written by **database triggers**, not by the app | It can't be skipped or faked by any screen |
| 25 | 2026-11-08 | 🟡 | **English only** for the MVP | Telugu can be added later |
| 26 | 2026-11-08 | 🟡 | Online payments are **out of the MVP**. Bookings and payments come after site visits and accounts | Matches the plan; needs legal and accounting input |
| 27 | 2026-11-08 | 🟡 | Hosting: website on **Vercel** (Pro plan at launch, ~$20/month, because the free plan is non-commercial only); admin on **Cloudflare Pages** (free) | Vercel runs Next.js best. Free alternative: Cloudflare for the website too, with more setup |
| 28 | 2026-11-08 | 🟡 | Supabase **Free plan** during development, **Pro plan** (~$25/month) at launch | Free plan has no backups and pauses when idle |
| 29 | 2026-11-08 | 🟡 | Environments: local Supabase on this laptop → a cloud **staging** project → a cloud **production** project | The plan asks for dev, staging and production |
| 30 | 2026-11-08 | 🟡 | Approval info is structured: approval type (DTCP, VMRDA, HMDA, APCRDA, Panchayat, RERA, Not applicable, Other), approval number, RERA number | Lets customers filter by "approved" and builds trust |
| 31 | 2026-11-08 | ✅ | Local ports: website **3100**, admin **3101**, Supabase **564xx** | Runs alongside Godavari Ghaatu (553xx) and other local projects without clashes |
| 32 | 2026-11-08 | ✅ | Use Supabase's **publishable key** in both apps and the **secret key** on the website server (not the legacy anon / service-role JWT keys) | Current Supabase recommendation; the Flutter SDK has deprecated `anonKey`; secret keys can be rotated one by one |
| 33 | 2026-11-08 | ✅ | Next.js **16** with **Cache Components** on (project default) | Static page shell with streamed live parts — fast pages; the website uses `"use cache"` + revalidation in later phases |
| 34 | 2026-11-08 | ✅ | Publishing and status rules are enforced by a **database trigger**; the admin app changes status by updating the field | One place for the rules; no API call can skip them |
| 35 | 2026-11-08 | 🟡 | The website listing shows **Available and Reserved** land by default; Sold only when the visitor filters for it | Sold land builds trust on its own page and in "recently sold", but shouldn't crowd search results |
| 36 | 2026-11-08 | ✅ | Visitors read safe **views** (`public_properties` …), never the private tables | Column-level safety (internal notes, exact pins, document paths) that row rules alone can't give |
| 37 | 2026-11-08 | ✅ | New database functions are private by default; each must be granted explicitly | Stops an admin function being exposed by accident |
| 38 | 2026-11-08 | ✅ | Property types and amenities ship in the migration; locations and properties are entered by the owner | Reference lists are the same everywhere; real locations are business data |
| 39 | 2026-11-08 | ✅ | Admin passwords: at least 10 characters with letters and a number; invited admins must set one before using the panel | Admin accounts control the whole site |
| 40 | 2026-11-08 | ✅ | Admin app uses plain Riverpod providers (no code generation) | Fewer build steps; the app is small enough |
| 41 | 2026-11-08 | ✅ | Deactivating an admin cuts their database access immediately (RLS); the app signs them out on their next page load | No waiting for sessions to expire |
| 42 | 2026-11-08 | ✅ | Admin map uses OpenStreetMap's own tile server; the public website will use a tile provider with a free plan (Phase 7) | OSM's server is fine for a few admins but not for public traffic |
| 43 | 2026-11-08 | ✅ | Status (publish state, availability) is changed with dedicated buttons, never with "Save changes"; unsaved edits are saved first | Each status change is a deliberate, logged action |
| 44 | 2026-11-08 | ✅ | Admin property search matches code, title, locality, city and district | Staff search the way customers describe places |
| 45 | 2026-11-08 | ✅ | Photos, videos and documents save immediately (no "Save changes") | Uploads are real files; holding them until a form save would risk losing them |
| 46 | 2026-11-08 | ✅ | Uploads use the Storage API directly from the browser to show progress | The Supabase SDK has no progress; limits and permissions are still enforced by Storage |
| 47 | 2026-11-08 | ✅ | Location cover photos: one 1600 px WebP each, in the public `site-assets` bucket | Used as banners on location pages; one size is enough |
| 48 | 2026-11-08 | ✅ | Website look: forest green + sand gold, Fraunces + Inter, survey-map contour pattern instead of stock photos | **Approved by the owner** (screenshots in docs/design-review/) |
| 49 | 2026-11-08 | ✅ | Listing filters live in the address: `?city=…&type=…&budget=min-max` | Shareable links and Google-friendly landing pages |
| 50 | 2026-11-08 | ✅ | Website pages are cached for up to an hour; Phase 7 adds instant refresh when an admin saves | Fast pages without hammering the database |
| 51 | 2026-11-08 | ✅ | Landing pages: `/land-for-sale/<city>` and `/<type>-for-sale/<city>`; filtered `/land` results are not indexed | One clean page per place/type for Google; endless filter combinations stay out of search results |
| 52 | 2026-11-08 | ✅ | Only the newest 50 property pages are pre-built; others are built on first visit and cached | Fast, reliable deploys however many properties there are |
| 53 | 2026-11-08 | ✅ | Website unit tests use Vitest (`npm test` in `web/`) | Light, works with the TypeScript setup |
| 54 | 2026-11-08 | ✅ | Property links are checked before the page renders (Next.js proxy): old → 301, archived → 410 page with similar land, unknown → 404 | Streaming pages always answer 200; search engines need the real status |
| 55 | 2026-11-08 | ✅ | Database triggers call the website's `/api/revalidate` (pg_net); address and secret live in Supabase Vault per environment | Admin changes show on the website within seconds without rebuilding |
| 56 | 2026-11-08 | ✅ | YouTube videos play through `youtube-nocookie.com` and load only when tapped | Privacy, and about 1 MB less on every property page |
| 57 | 2026-11-08 | ↩ | ~~Page metadata always goes in `<head>` (`htmlLimitedBots: /.*/`)~~ replaced by decision 127 | Google only trusts canonical links in `<head>` |
| 58 | 2026-11-08 | ✅ | Enquiry limit: 5 per hour per phone and per visitor IP (IP stored only as a salted hash) | Stops spam without storing personal data |
| 59 | 2026-11-08 | ✅ | Emails are sent after the visitor sees the confirmation (`after()`); the enquiry is saved even if email fails | The visitor never waits for or loses an enquiry because of email |
| 60 | 2026-11-08 | ✅ | WhatsApp/call taps are counted (channel, property, time only) in `contact_taps` | Shows interest that never becomes a form enquiry |
| 61 | 2026-11-08 | ✅ | Status changes and notes only through database functions; admins can directly change only who it's assigned to | Every follow-up step is in the timeline and the activity log |
| 62 | 2026-11-08 | ✅ | Desktop alerts are opt-in per browser ("Turn on desktop alerts"); in-panel messages always show | Browsers block unasked notification prompts |
| 63 | 2026-11-08 | ✅ | CSV exports mark formula-like cells as text and include a byte-order mark | Safe in Excel; Telugu and ₹ show correctly |
| 64 | 2026-11-09 | ✅ | A database test scans **every** table, policy and function (RLS on, writes need an admin, visitor-callable functions on an allowlist, `search_path` pinned) | New tables or functions can't go live unprotected by accident |
| 65 | 2026-11-09 | ✅ | Visitors (anon) have no write grants at all, and nobody but the owner role can TRUNCATE | RLS doesn't cover TRUNCATE; found by the scan |
| 66 | 2026-11-09 | ✅ | Admin panel is self-hosted (no Google CDN) and ships `_headers` with a strict CSP generated per environment (`tool/build_admin.sh`) | Fewer outside dependencies; CSP tested against the real app |
| 67 | 2026-11-09 | 🟡 | Weekly off-site archive (database + all files) to a second provider, 8 kept, on top of Supabase's daily database backups | Supabase backups don't include stored files and live with the same company |
| 68 | 2026-11-09 | ✅ | Restore = schema from migrations + data-only dump loaded in one transaction (`tool/restore_db.sh`) | Same steps for any new project; all-or-nothing |
| 69 | 2026-11-09 | ✅ | Branded admin invite / password-reset emails sent through Resend SMTP in production | Supabase's built-in email is rate-limited and unbranded |
| 70 | 2026-11-09 | 🟡 | No Sentry at launch: Vercel logs + Supabase logs/advisors; add Sentry if errors become hard to trace | Keeps the browser code small; free tools cover MVP traffic |
| 71 | 2026-11-09 | ✅ | If the enquiry can't reach the server, the form keeps the typed details and says so; pressing send again restarts a stuck bot check | Phones lose signal; found in Phase 9 testing |
| 72 | 2026-11-09 | 🟡 | Site visits are bookable from **tomorrow** up to **30 days** ahead, **Mon–Sat**, at **10:00, 12:00 and 15:00**, India time — all changeable in Settings, plus holidays | Gives the team a day to arrange each visit |
| 73 | 2026-11-09 | ✅ | Visit statuses: Requested → Confirmed → Completed / No-show; Cancelled from Requested or Confirmed. Rescheduling is an action (recorded old → new), not a status | Simple for staff; the timeline keeps the history |
| 74 | 2026-11-09 | 🟡 | No limit on visits per time slot: the team confirms every visit by phone | Low volume; avoids turning customers away for a full slot |
| 75 | 2026-11-09 | ✅ | Staff may move a visit to any future date and time, not only the website's slots | Special arrangements happen |
| 76 | 2026-11-09 | ✅ | One open request per phone per property (asking again returns the same SV- reference); 3 requests an hour per phone, 5 per visitor IP | Stops duplicates and spam |
| 77 | 2026-11-09 | ✅ | Customer emails on confirm / move / cancel are triggered by the database (same secret as the cache refresh), so they go out whichever screen made the change | The admin panel never holds email keys |
| 78 | 2026-11-09 | ✅ | Day-before reminders: Vercel Cron at 9:00 India time calls `/api/site-visits/reminders` (`CRON_SECRET`); each visit is claimed once | A rerun never sends twice |
| 79 | 2026-11-09 | 🟡 | Visit emails include "Get directions" only for properties whose exact location is public; otherwise the team shares the meeting point by phone | Keeps decision 18's location privacy |
| 80 | 2026-11-09 | 🟡 | Customers sign in with **email + a 6-digit code** (no passwords). Phone sign-in later (needs an SMS provider and DLT registration) | Nothing to forget or leak; works on every phone |
| 81 | 2026-11-09 | ✅ | Accounts stay **optional**: guests enquire and book exactly as before (decision 13 still holds) | No extra step between a buyer and the team |
| 82 | 2026-11-09 | ✅ | Signing in links earlier guest requests sent with the **same verified email**; requests sent while signed in are linked automatically | The code proves the email belongs to them |
| 83 | 2026-11-09 | ✅ | Customers read their requests only through `my_requests()` (plain fields, plain status words); never the staff tables, notes or assignments | Staff-only details can't leak |
| 84 | 2026-11-09 | ✅ | Recently viewed is kept in the **browser only** | Nothing stored about browsing |
| 85 | 2026-11-09 | 🟡 | **Delete account** removes the profile and saved land; enquiries and visits stay with the team, unlinked. Staff accounts can't be deleted this way | Right to erasure, while the team can still reply |
| 86 | 2026-11-09 | ✅ | Supabase sign-ups are on (customers), with email confirmation required for any sign-up; staff access still comes only from `admin_users` | A customer account never opens the admin panel |
| 87 | 2026-11-09 | 🟡 | Sign-in code emails are limited by Supabase's per-hour email limit (production: set to ~100/hour with Resend); add a bot check in front if abused | Stops sending floods of codes |
| 88 | 2026-11-09 | ✅ | Pages stay cached for everyone; personal parts (header, hearts, pre-filled forms, My account) load in the browser | Signing in never slows the public site |
| 89 | 2026-11-09 | ✅ | Compare up to **3** properties; picks kept on the device (no sign-in) | Three fit side by side; anyone can use it |
| 90 | 2026-11-09 | ✅ | The comparison address lists the codes (`/compare?codes=AL-0001,AL-0003`) so it can be shared; it is **noindex** but not blocked in robots.txt | Families decide together on WhatsApp; link previews still work |
| 91 | 2026-11-09 | ✅ | Compare by **price per sq ft** (worked out from total price and area) and mark the best price, value, area and road | Plots in cents, acres and sq yd can't be compared by headline price |
| 92 | 2026-11-09 | ✅ | Distances between compared properties are straight-line and use the same (possibly approximate) location the property page shows | Keeps decision 18's location privacy |
| 93 | 2026-11-09 | ✅ | Unpublished properties in a shared link are left out with a note; sold land can still be compared | Old links never break or show hidden land |
| 94 | 2026-11-09 | ✅ | Booking steps are the owner's list: Requested → Pending approval → Approved → Payment pending → Reserved → Completed; Cancelled from any open step | Matches the plan's booking status list |
| 95 | 2026-11-09 | 🟡 | **Super admins** approve bookings and complete sales; any admin sends for approval, asks for the booking amount, records payments and cancels | The two steps that change what the property is are a manager's call |
| 96 | 2026-11-09 | ✅ | Approving makes the property **Reserved**, completing makes it **Sold**, cancelling a held booking makes it **Available** — in the same database transaction | The website can never disagree with the booking |
| 97 | 2026-11-09 | ✅ | **One booking holds a property** at a time (unique index + row lock); other requests may wait in the queue | Two buyers can't both be approved for one plot, even at the same second |
| 98 | 2026-11-09 | ✅ | While a booking holds a property, its availability can't be changed by hand and it can't be archived | Status changes go through the booking |
| 99 | 2026-11-09 | 🟡 | Customers must be **signed in** (with name and mobile) to request a booking; at most 3 requests a day; one open request per property | A booking is a serious step; the team needs a verified contact |
| 100 | 2026-11-09 | ✅ | **No online payments** yet: the team records amount, date, method and reference (UTR / cheque number) — never card or full bank details | Owner's plan: company process first; gateway in Phase 17 |
| 101 | 2026-11-09 | ✅ | Payment instructions are **never** shown on the website or emailed; every booking email warns customers never to pay into a personal account | Land-sale payment fraud is common |
| 102 | 2026-11-09 | ✅ | Staff can start a booking from a site visit or an enquiry; customers can withdraw their own request before approval | Most bookings start in conversation, not online |
| 103 | 2026-11-09 | 🟡 | Only **super admins** edit website content; other admins can read it | It speaks for the company (and includes the legal pages) |
| 104 | 2026-11-09 | ✅ | Page texts have a **draft** and a **published** version: save draft → private **preview** link (1 hour, noindex) → publish; discard throws the draft away | Nothing half-written ever reaches visitors |
| 105 | 2026-11-09 | ✅ | FAQs, testimonials and banners are published one by one and ordered by dragging | Lists change often; drafts would slow the team down |
| 106 | 2026-11-09 | ✅ | **Testimonials only from real customers with their permission**: can't be published until consent is ticked (and how it was given noted) | India's Consumer Protection rules on fake reviews |
| 107 | 2026-11-09 | ✅ | Banners: title, text, optional link (a page here or `https://` only), photo, from / until dates; the website follows the dates within about a minute; up to 3 shown | Promotions without code changes; no unsafe links |
| 108 | 2026-11-09 | ✅ | Text only, no HTML (blank lines become paragraphs); images only from our own uploads; icons from a fixed set | Nothing typed can run as code on the website |
| 109 | 2026-11-09 | 🟡 | Hero: a photo only (no video) | A background video would slow the home page on phones |
| 110 | 2026-11-09 | ✅ | The database starts with today's website text; if content can't be loaded, the website falls back to the built-in text | The website looks the same until someone edits it, and never breaks |
| 111 | 2026-11-09 | ✅ | Notifications are written by **database triggers**, one row per person; each person sees only theirs and can only mark them read | No screen can forget one; nobody sees anyone else's |
| 112 | 2026-11-09 | ✅ | Admin notifications go to every active admin **except the one who did it**; bookings the team starts itself don't alert the team | Only news is news |
| 113 | 2026-11-09 | 🟡 | **Saved-land changes** (price, reserved, sold, available again, taken off the website) are notified in-app and **emailed by default**; one switch in My account turns the emails off | Buyers want to know; easy to stop |
| 114 | 2026-11-09 | ✅ | The admin bell now counts **unread notifications** (it used to count new enquiries; those stay on the dashboard) | One place for everything new |
| 115 | 2026-11-09 | 🟡 | Notifications are deleted after **90 days** (daily job) | Keeps personal data no longer than needed |
| 116 | 2026-11-09 | ✅ | Seen updates in My account are marked read when the page opens (still labelled New until the customer leaves the page) | No separate "mark read" chore for customers |
| 117 | 2026-11-09 | ✅ | WhatsApp Business messages and phone push notifications are left for later | They need a WhatsApp Business account / a mobile app |
| 118 | 2026-11-09 | ✅ | Website statistics are **counted by our own website and database**, without cookies, instead of Google Analytics / Vercel Analytics / Plausible | Nothing about visitors goes to a third party; no consent banner; enquiries, visits and sales sit in the same database, so the funnel and per-property numbers come for free |
| 119 | 2026-11-09 | ✅ | Visitors are identified only by a **double hash**: the web server hashes IP + browser with a secret, the database hashes that again with a **random salt that changes daily and is deleted after two days** | Afterwards nobody, not even us, can link visits across days or work back to an IP address |
| 120 | 2026-11-09 | ✅ | So **unique visitors are counted per day**; a range adds up the daily visitors | Follows from 119; said on the page itself |
| 121 | 2026-11-09 | ✅ | Not counted: bots and link previews, browsers sending Do Not Track / Global Privacy Control, content previews, more than 1,000 pages per visitor per day; paging or sorting the same /land search is not a new page view | Honest numbers; respects people who opt out |
| 122 | 2026-11-09 | 🟡 | Raw page views are kept **13 months**, then deleted by the daily job | Allows comparing with the same month last year; owner can shorten |
| 123 | 2026-11-09 | ✅ | A **sale** is a booking marked completed (counted on its completion date); the funnel compares totals for the period and follows nobody | Matches how the team records sales; no tracking of individuals |
| 124 | 2026-11-09 | ✅ | **Every admin** can see Analytics | The whole team works on sales; no further roles are planned (decision 126) |
| 125 | 2026-11-09 | ✅ | **Online payments (Phase 17) are postponed** by the owner. Payments stay offline (bank transfer, UPI, cheque…) and the team records them in Bookings | Owner's decision; also needs legal/accounting sign-off first |
| 126 | 2026-11-09 | ✅ | **No more admin roles (Phase 18 dropped).** The panel keeps two roles: Super Admin (settings, admin users, website content, approving bookings) and Admin (everything else) | Owner's decision: a small team doesn't need more |
| 127 | 2026-11-09 | ✅ | Metadata goes in `<head>` for **crawlers and link previews** (Next.js's list plus Googlebot); people's browsers get it streamed | Blocking metadata for every visitor stopped Next.js from building a static first view of /land and property pages ("did not produce a static shell" in development). Google still sees canonical links and noindex in `<head>` |
| 128 | 2026-11-09 | ✅ | Final name **Avanilands**, a brand of **Tirupa Technologies Pvt. Ltd.**, "Real Estate & Property Platform". Tagline **"Find Your Space. Build Your Future."** Property codes are now `AL-0001`; references (ENQ-, SV-, BKG-) unchanged. The tagline and parent company show in the website footer | Owner's brand decision. Later categories (apartments, villas, houses, commercial, developments) are a future direction only; the platform still sells land |
| 129 | 2026-11-09 | ✅ | Code lives in the git repository **JonnadaRaju/Avanilands** on GitHub, branch `main` | Name fixed, so git can start (it was held back until then) |

## Open questions for the owner

Answer what you can; anything left open uses the 🟡 default above.

1. **Brand:** final website name, logo, and brand colours (if you have them)?
2. **Locations:** which state(s), districts and cities do you sell in at launch? (The plan's example is Visakhapatnam.)
3. **Property types:** keep all six? Is "Farm Land" different from "Agricultural Land" for you (e.g. managed farm plots for city buyers)?
4. **Area units:** which units do your sales team actually quote? Anything missing (e.g. hectares, ankanams)?
5. **Price:** do you ever want to hide prices ("Price on request")? Show per-unit price, total, or both?
6. **Contact:** sales phone number, WhatsApp number, email address, office address and hours?
7. **Location privacy:** show exact map pins for all properties, or approximate areas by default?
8. **Documents:** which documents may customers see (brochure, layout plan, approval copy)? Which must stay private?
9. **Legal:** are your layouts DTCP/VMRDA/RERA approved? Any registration numbers or disclaimers that must appear on the site? (Please check with your legal advisor — RERA-registered projects usually must show the RERA number in every advert.)
10. **Hosting:** OK with Vercel Pro (~$20/month) for the website, or should we keep it free on Cloudflare?
11. **Maps:** free OpenStreetMap maps OK for launch, or must it be Google Maps?
12. **Design:** any websites you like the look of (real-estate or otherwise)?
