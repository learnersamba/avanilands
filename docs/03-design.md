# Design Direction — Avanilands

> Proposed direction. Before building the website (Phase 5) we make a clickable design prototype of the home, listing and details pages, and the owner approves it. Brand colours and logo replace the placeholders once the owner sends them.

## 1. Feel

Premium · professional · trustworthy · modern · land-focused · clean · easy · mobile-first.
**Not** a classifieds look: no crowded grids of tiny ads, no "Post your ad" buttons, no seller names. It should feel like the official website of a serious land company.

## 2. Visual language (placeholder until branding is final)

| Element | Proposal |
|---------|----------|
| Primary colour | Deep forest green `#1F4D3A` — land, growth, stability |
| Accent | Warm sand gold `#C8A15A` — premium, used sparingly (badges, lines, key buttons) |
| Background | Soft off-white `#FAF8F3`; white cards; charcoal text `#1E2422` |
| Status colours | Available green · Reserved amber · Sold slate grey (never red — sold is a success) |
| Headings | Elegant serif (e.g. *Fraunces* or *Playfair Display*) |
| Body | Clean sans-serif (e.g. *Inter*), 16 px minimum on mobile |
| Imagery | Large, real aerial/drone and ground photos of our land; no stock-photo people |
| Shapes | Generous white space, 12–16 px rounded corners, thin gold dividers, soft shadows |
| Icons | Simple line icons (area, road, compass for facing, water drop, bolt, shield for approval) |
| Motion | Subtle fades and image zoom on hover; nothing flashy |

## 3. Key screens

### Header (all pages)
Logo · Explore Land · Locations · About · Contact · phone number · **"Talk to us" (WhatsApp)** button. Mobile: logo + menu + call icon; a sticky bottom bar on property pages with **Call · WhatsApp · Enquire**.

### Home
1. **Hero:** full-width aerial photo/video, headline such as "Own verified land, directly from the developer", search bar (location · type · budget) with a "Search" button.
2. **Trust strip:** e.g. "100% clear titles · Approved layouts · No brokers · Site visits arranged" (only claims the business can back up).
3. **Featured properties** (admin-chosen, carousel on mobile).
4. **Popular locations** (photo tiles with property counts).
5. **Why choose us** (4 points with icons).
6. **Verification / trust:** how each property is checked (title, approvals, survey) — with real document types.
7. **How buying works:** Enquire → Site visit → Booking → Documentation → Registration (5 steps).
8. **Recently added.**
9. **Testimonials** (real ones only; hidden if none).
10. **FAQ** (top 5) → link to full FAQ.
11. **Contact CTA band** with phone, WhatsApp and a short form.
12. **Footer:** company details, quick links, locations, policies, legal disclaimer, RERA numbers if applicable.

### Explore land (`/land`)
- Desktop: filters in a left column, results grid (3 columns) on the right, sort dropdown and result count on top.
- Mobile: search on top, **Filters** button opens a full-screen sheet with "Show N results"; 1-column cards.
- Active filters shown as removable chips. Empty state suggests clearing filters or contacting sales.

### Property card
```
┌─────────────────────────────┐
│  [cover photo 4:3]  AVAILABLE│  ← status badge top-right
│                     ★ Featured│
├─────────────────────────────┤
│ Residential Plot · AL-0012   │  ← type + code (small)
│ 25 Cent Plot near NH-16      │  ← title (serif)
│ 📍 Anandapuram, Visakhapatnam│
│ ▭ 25 cents (10,890 sq ft)    │
│ ★ East facing, 40 ft road    │  ← one highlight
│ ₹45,00,000   Negotiable      │
│ [ View details → ]           │
└─────────────────────────────┘
```
Area always shows the original unit, plus sq ft in brackets. Prices in Indian format (₹45,00,000 or ₹45 L, ₹1.2 Cr on cards).

### Property details (`/land/[slug]`)
- **Top:** gallery (1 large + 4 small on desktop, swipe on mobile; full-screen viewer), video tab.
- **Title block:** title, location, code, status badge, price (big), per-unit price, negotiable tag; Save and Share icons.
- **Right sticky panel (desktop) / bottom bar (mobile):** Enquire form, Call, WhatsApp (pre-filled message with property code), Schedule site visit (later).
- **Sections:** Overview grid (icons) → Highlights → Description → Amenities → Location map (exact pin or approximate circle) + "Get directions" → Nearby places (distance list) → Documents & approvals (approval type and number, public documents to download, "more documents shared during the site visit") → Related properties.
- **Reserved:** amber banner "This property is reserved — ask us about similar land". **Sold:** grey banner, no form, related properties first.

### Other pages
About (story, mission, vision, values, team photos optional) · Locations (cards per city) · Contact (form, map of office, hours) · FAQ (grouped accordions) · Terms / Privacy / Disclaimer.

## 4. Admin panel look

Clean, desktop-first business tool using the same green/gold palette:
- Left sidebar: Dashboard · Properties · Enquiries · Locations · Types & Amenities · Settings · Admin users · Activity log.
- Top bar: search by property code or enquiry reference, new-enquiry bell, profile.
- Dashboard: number cards (Total, Available, Reserved, Sold, Draft, New enquiries) + recent activity + latest enquiries.
- Property editor: one page with section tabs (Basic · Location · Size & price · Details · Highlights · Media · Documents · SEO · Status), autosave as draft, "Preview on website" and "Publish" buttons; publish checklist shows what's missing.
- Media manager: drag-to-reorder grid, star to set cover, per-image alt text, upload progress, retry on failure.

## 5. Accessibility

Colour contrast AA, visible focus, labels on all inputs, keyboard-usable gallery and filters, alt text on images, no information shown by colour alone (badges have text).
