# Requirements — Avanilands

> Source: the owner's "Land Selling Platform — Complete Implementation Plan" (2026-11-08).
> This file is the short, checkable version of that plan. Business choices and open questions live in [DECISIONS.md](DECISIONS.md).

## 1. What we are building

A **premium, company-owned land-selling website**. Only our company lists land. It is **not** a marketplace like OLX.

Two parts:

| Part | Who uses it | Tech |
|------|-------------|------|
| Customer website | Buyers and prospective buyers | Next.js |
| Admin panel | Our company's authorised staff only | Flutter (web) |

Both use one **Supabase** backend (Postgres database, Auth, Storage, Edge Functions).

## 2. Hard rules (never break these)

1. No third-party sellers, owners, brokers or agents. There is no "post your property" anywhere.
2. Customers cannot add, list, sell or publish land, and cannot become sellers or agents.
3. Only authorised admins create and change properties, media and website content.
4. Admin features and admin data are never reachable by customers. **The database enforces this (RLS)**, not just the screens.
5. Private documents and private location details are never public unless the admin marks them public.
6. Build the core flow first (discover → view → enquire → admin follows up). No extra features before it works.
7. Build in modules, so later features don't need a rewrite.

## 3. Core business flow

```
Admin adds property → Admin publishes → Customer finds it → Customer views details
→ Customer enquires / books a site visit → Sales team follows up → Booking
→ Property Reserved → Documentation → Purchase → Property Sold
```

## 4. MVP scope (first launch)

The MVP is done when this journey works end to end in production:

```
Admin adds property → publishes → customer discovers it → views it
→ submits an enquiry → admin receives it → admin contacts the customer
```

| # | MVP feature | Phase |
|---|-------------|-------|
| 1 | Admin login (separate from customers) | 2 |
| 2 | Admin dashboard (counts + recent activity) | 2 |
| 3 | Property create / edit / view / archive / delete rules | 3 |
| 4 | Property images (upload, reorder, cover, replace, delete) + videos + documents | 4 |
| 5 | Property status management (publish state + availability) | 3 |
| 6 | Customer homepage | 5 |
| 7 | Property listing with search, filters, sort, pagination | 6 |
| 8 | Property details page with gallery, video, map | 7 |
| 9 | SEO basics (clean URLs, metadata, sitemap, robots, structured data) | 7 |
| 10 | Customer enquiry form | 8 |
| 11 | Admin enquiry management (status, notes) | 8 |
| 12 | Responsive design (mobile-first website) | all |
| 13 | Basic security (RLS, validation, rate limit, bot check, secure headers) | all |
| 14 | Testing | 9 |
| 15 | Deployment | 9 |

## 5. After MVP (in this order)

Site visits → Customer accounts (profile, saved properties, enquiry history, recently viewed) → Comparison → Bookings → CMS (homepage, about, FAQ, testimonials, banners) → Notifications → Analytics → Online payments → More admin roles.

See [phases/ROADMAP.md](phases/ROADMAP.md).

## 6. Customer website pages

| Page | URL | MVP? |
|------|-----|------|
| Home | `/` | ✅ |
| Explore properties | `/land` | ✅ |
| Property details | `/land/[slug]` e.g. `/land/25-cent-residential-plot-visakhapatnam` | ✅ |
| Location / type landing pages | `/plots-for-sale/[city]`, `/agricultural-land-for-sale/[city]` | ✅ (simple) |
| Locations | `/locations` | ✅ |
| About us | `/about` | ✅ (static text) |
| Contact | `/contact` | ✅ |
| FAQ | `/faq` | ✅ (static text) |
| Terms, privacy, disclaimer | `/terms`, `/privacy`, `/disclaimer` | ✅ (static text) |
| Login / register | `/login`, `/register` | Later |
| Customer dashboard, saved, enquiries, site visits | `/account/...` | Later |
| Compare | `/compare` | Later |

"Static text" pages become admin-editable in the CMS phase.

### Homepage sections
Premium hero with land-focused headline and search · Featured properties · Recently added · Popular locations · Why choose us · Verification / trust section · How buying works · Testimonials (static until CMS) · FAQ · Contact CTA · Footer.

### Property card
Cover image · Title · Location · Area · Price · Type · One key highlight · Availability badge · "View details".

### Search, filter, sort
- **Search by:** location, city, locality, property name, property type.
- **Filter by:** type, location, price range, area range (any unit), road width, facing, availability, amenities, approval status.
- **Sort by:** newest, price ↑, price ↓, area ↑, area ↓, featured.
- Server-side, paginated (12 per page), filters kept in the URL so results can be shared and indexed.

### Property details page (top to bottom)
Media (gallery + video) → Title → Location → Price → Overview (area, dimensions, type, road width, facing, water, electricity, approval) → Highlights → Description → Amenities → Map → Nearby places → Documents / legal info → Enquiry + Contact + WhatsApp → Schedule site visit (later) → Save (later) → Related properties.

## 7. Admin panel

### Dashboard
Total / available / reserved / sold / draft properties · new enquiries · pending site visits (later) · recent activity.

### Properties
Add · edit · view · publish · unpublish · hide · archive · delete (drafts only) · change price · change status · mark reserved · mark sold.

**Create property form sections:** Basic info · Location (with map picker) · Size · Pricing · Property details · Highlights and nearby places · Media · Status · SEO (optional overrides).

### Media
- **Images:** upload (many at once), delete, reorder, set cover, replace, alt text.
- **Videos:** add YouTube link (recommended) or upload, remove, set primary.
- **Documents:** brochure, layout plan, approval documents, title documents, other. Each is **private by default**; admin can mark a document public.
- Validate type and size on upload.

### Enquiries
List with filters → detail → contact details, property, message, date, status, notes history.
Statuses: New → Contacted → Follow-up → Interested / Not interested → Converted → Closed.

### Also in MVP
Locations, property types and amenities lists · Contact settings (phone, WhatsApp, email, address) · Admin users (super admin invites admins) · Audit log viewer.

## 8. Non-functional requirements

- **Security:** see [01-architecture.md §6](01-architecture.md#6-security).
- **Performance:** server-rendered pages, optimised thumbnails, lazy-loaded images and video, paginated queries, indexed filters. Target Lighthouse ≥ 90 on mobile for home, listing and details.
- **Responsive:** website mobile-first; admin works on tablet, but desktop comes first. Test at 360, 390, 768, 1280, 1536 px wide.
- **SEO:** see [01-architecture.md §5](01-architecture.md#5-seo).
- **Reliability:** daily database backups (Supabase Pro), storage backups, written recovery steps.
- **Environments:** local development → staging (trial) → production. No secrets in code.
- **Audit:** every important admin action is logged automatically by the database.
