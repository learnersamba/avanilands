# Phase 5 — Website: design, layout, homepage, static pages ✅

**Goal:** the website looks premium and the homepage works with real data.
**Depends on:** Phase 1 (data). Can run alongside Phases 2–4.

## Checklist
### Design first
- [x] Clickable prototype of Home, Explore, Property details (desktop + mobile) following [03-design.md](../03-design.md)
- [x] **Owner approves the design** (decision 48, 2026-11-08) — screenshots in `docs/design-review/`

### Foundation
- [x] Tailwind theme tokens (colours, fonts, spacing, radius), fonts via `next/font`
- [x] Components: Button, Badge (status), PropertyCard, Price, Area, Section heading, Container, Skeletons, Empty state
- [x] Formatting helpers: Indian prices (₹45,00,000 / ₹45 L / ₹1.2 Cr), area with sq ft, dates
- [x] Supabase server client, typed queries (hand-written types in `web/src/lib/data.ts`; generated types later if the schema grows)
- [x] Header (desktop + mobile menu), footer (settings-driven contact info, locations, policy links)
- [x] Floating WhatsApp button; click-to-call
- [x] Secure headers + CSP in `next.config`
- [x] Error page, 404 page, loading states

### Homepage (sections from [00-requirements.md §6](../00-requirements.md))
- [x] Hero with search (location, type, budget) → goes to `/land?...`
- [x] Featured, recently added, popular locations (live data)
- [x] Why choose us, verification/trust, how buying works, testimonials, FAQ, contact CTA (static content in code until the CMS phase; testimonials hidden when empty)

### Static pages
- [x] About, Contact (form wired in Phase 8), FAQ (with FAQPage JSON-LD), Terms, Privacy, Disclaimer — owner supplies text; placeholders marked clearly

## Done when
Homepage renders real seed data, looks like the approved design on 360 px to 1536 px, and scores ≥ 90 for performance and accessibility in Lighthouse (mobile).

## Notes (2026-11-08)
- **Design approach** (docs/03-design.md): forest green + sand gold, Fraunces headings, Inter text, and a faint survey-map "contour lines" pattern on dark sections instead of stock photos. Everything mobile-first.
- **Pages built**: Home (live data), Locations, About, Contact, FAQ (with FAQPage structured data), Terms, Privacy, Disclaimer, 404 and error pages.
- **Design previews with live data** (so the owner can click through the whole journey): `/land` (filters shown but not working yet — Phase 6) and `/land/[slug]` (gallery, overview, highlights, description, video, amenities, location, documents, sticky enquiry panel, phone action bar, related land; map / photo viewer / downloads in Phase 7, enquiry sending in Phase 8). Both carry a "Design preview" banner and are hidden from Google until finished.
- Listing address parameters chosen for Phase 6: `?city=<location-slug>&type=<type-seo-slug>&budget=<min>-<max>` (rupees). The home search already uses them.
- **Data** (`web/src/lib/data.ts`): only the public views/functions; every read is `"use cache"` with `cacheLife("hours")` and tags (`properties`, `locations`, `settings`, `property:<slug>`) ready for Phase 7's instant refresh. Until then admin changes show within the hour (or after a rebuild).
- **Photos**: plain `<img>` with `srcSet` over the three sizes from Phase 4 (no Next.js image optimiser needed).
- **Security headers** in `web/next.config.ts`: CSP (Supabase, YouTube, map tiles allowed), HSTS in production, no framing, no sniffing, strict referrer, permissions off.
- **Sample photos**: `tool/seed_photos.sh` draws simple "sky over land" placeholders with ffmpeg and uploads them for the sample properties (local only). Run it after `supabase db reset`. (Fixed: ffmpeg was reading the loop's input — needs `-nostdin`.)
- **Copy marked PLACEHOLDER** in `web/src/content/site.ts` (about story, mission, vision, two FAQ answers) and the legal pages need the owner's real text. The trust claims (clear titles, approved layouts, documents traced 30 years…) must be confirmed by the owner.
- Sample YouTube video removed from the seed (it was a famous music video); the video section appears once a real video is added.
- **Lighthouse (mobile, production build)**: Home 94 / 100 / 100 / 100 (performance / accessibility / best practices / SEO); Contact 99 / 100 / 100 / 100; previews 92 / 100 / 100 / 63 (SEO low only because previews are deliberately hidden from Google). Fixed on the way: gold text too faint on light backgrounds (new darker gold `sand-dark`), reserved badge contrast, heading font trimmed to one weight, small tap targets.
- Checked in Chrome at 1440 px and 390 px: no horizontal scrolling on any page; no console errors.
- **For Phase 7**: an unknown property address shows the "not found" page but with status 200 (the page streams); make it a real 404.
