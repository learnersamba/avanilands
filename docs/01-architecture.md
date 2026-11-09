# Architecture — Avanilands

## 1. Overview

The original plan proposed Next.js + FastAPI + PostgreSQL + object storage. With the confirmed stack, **Supabase is the backend**: it gives us PostgreSQL, authentication, file storage and server functions in one service, so there is no separate FastAPI server to build or host.

```
                ┌──────────────────────────────┐
 Customers ───► │  Website — Next.js (Vercel)  │
                │  • pages rendered on server   │
                │  • server actions (enquiry)   │
                │  • /api/revalidate, /api/doc  │
                └──────────────┬───────────────┘
                               │ publishable key (read published)
                               │ secret key (server only: enquiries, signed URLs)
                ┌──────────────▼───────────────┐
                │           Supabase            │
                │  Postgres + RLS + RPCs        │
                │  Auth (admins; customers later)│
                │  Storage (media, documents)   │
                │  Edge Functions (invites)     │
                │  DB webhooks → revalidate     │
                └──────────────▲───────────────┘
                               │ user JWT (admin role checked by RLS)
                ┌──────────────┴───────────────┐
 Admins ──────► │ Admin — Flutter web (CF Pages)│
                └──────────────────────────────┘

 Side services: Resend (email) · Cloudflare Turnstile (bot check) · map tiles (OpenStreetMap-based)
```

## 2. Folder layout

```
Avanilands/
  web/                  Next.js website (TypeScript, App Router)
  admin/                Flutter web admin panel
  supabase/
    migrations/         SQL schema, RLS, functions, triggers (one file per change)
    functions/          Edge Functions (Deno) e.g. invite-admin
    tests/              pgTAP database tests
    seed.sql            dev seed: types, amenities, locations, sample properties
  docs/                 these planning docs
```

## 3. The website (`web/`)

| Concern | Choice |
|---------|--------|
| Framework | Next.js 16 (Cache Components on), App Router, TypeScript, React Server Components |
| Styling | Tailwind CSS + a small set of our own components (premium look, no generic template feel) |
| Data | `@supabase/ssr` client with the **publishable key** (cookie-less for public pages); RLS only returns published data |
| Forms | Server Actions + `zod` validation |
| Bot check | Cloudflare Turnstile on enquiry forms |
| Images | Pre-sized WebP from Storage (thumb / medium / large) with `srcset`; lazy loading |
| Maps | Leaflet (loaded only on the details page, only when scrolled into view) |
| Video | YouTube "lite" embed (loads the player only on click) |
| Caching | Pages cached and rebuilt on demand: a Supabase database webhook calls `/api/revalidate` (secret header) when a property, image or location changes |
| Email | Resend from server code only |

**Secrets** (`SUPABASE_SECRET_KEY`, `RESEND_API_KEY`, `TURNSTILE_SECRET_KEY`, `REVALIDATE_SECRET`) are only used in server code and never sent to the browser. Anything prefixed `NEXT_PUBLIC_` is public by design (Supabase URL, publishable key, Turnstile site key).

### Enquiry flow
```
Form (browser) → Server Action
  1. zod validation (name, Indian phone, email optional, message length)
  2. Turnstile token check
  3. rate limit: max 5 enquiries per phone and per IP per hour (checked in the database)
  4. RPC submit_enquiry (secret key) → row in enquiries, property must be published and not sold
  5. email to sales inbox (failure is logged, never blocks the customer)
  6. show confirmation + WhatsApp shortcut
```

### Public documents
`/api/documents/[id]` checks the document is public **and** its property is published, then redirects to a signed Storage URL valid for 5 minutes. Private documents are never reachable from the website.

## 4. The admin panel (`admin/`)

| Concern | Choice |
|---------|--------|
| Framework | Flutter web (same versions as Godavari Ghaatu) |
| State / routing | Riverpod 3 + go_router |
| Backend | `supabase_flutter` with the signed-in admin's session |
| Login | Email + password. After login the app calls `is_admin()`; anyone who isn't an active admin is signed out immediately |
| Maps | `flutter_map` for the location picker (tap to drop a pin, or type coordinates) |
| Images | Picked in the browser, shrunk to WebP 400 / 1200 / 2000 px, uploaded to Storage, then a row is added to `property_images` |
| Live updates | Supabase Realtime on `enquiries` for the "new enquiry" badge |
| Hosting | Cloudflare Pages, separate address (e.g. `admin.<domain>`), `noindex` |

The admin app is only a convenience. **Every rule is enforced in the database** (RLS policies, constraints, functions), so a customer calling the API directly with their own login can't do admin things.

## 5. SEO

- Clean URLs: `/land/[slug]`, `/plots-for-sale/[city]`, `/[type-slug]-for-sale/[city]`.
- `generateMetadata` per page: title, description, canonical URL, Open Graph image (property cover).
- JSON-LD structured data: `Organization` site-wide, `RealEstateListing` + `Offer` + `Place` (geo only when exact location is shown) on details pages, `BreadcrumbList`, `FAQPage` on FAQ.
- `sitemap.xml` generated from published properties and locations; `robots.txt` blocks `/api`, `/account`.
- One `<h1>` per page, ordered headings, alt text on every image (admin enters it; falls back to the title).
- Old slugs redirect (301) to the current slug.

## 6. Security

| Requirement | How |
|-------------|-----|
| Secure authentication, password hashing, sessions | Supabase Auth (bcrypt, short-lived JWT + refresh tokens). Sign-ups **off** until customer accounts phase |
| Authorization / RBAC | `admin_users` table + `is_admin()` / `is_super_admin()` SQL functions used in every RLS policy |
| API authorization | RLS on **every** table; no table is readable or writable without a policy. Admin-only RPCs check `is_admin()` themselves |
| Never trust the frontend | Status changes, publishing rules and price changes are validated by database functions and constraints |
| Input validation | zod on the website, form validation in admin, CHECK constraints in the database |
| File uploads | Storage bucket policies: admin-only writes, allowed MIME types and max size per bucket; checked again in the admin app |
| Rate limiting | Enquiry limits in the database; Supabase Auth rate limits; Vercel/Cloudflare edge protection |
| CSRF | Server Actions check the request origin; Supabase calls use bearer tokens, not cookies-only |
| XSS | React escapes output; descriptions are plain text or sanitised Markdown; strict Content-Security-Policy |
| SQL injection | Only parameterised queries via PostgREST / RPC; no string-built SQL |
| Secure headers / HTTPS | HSTS, CSP, X-Frame-Options, Referrer-Policy, Permissions-Policy set in `next.config`; both hosts are HTTPS only |
| Secrets | `.env.local` (git-ignored) locally; host dashboards in staging/production; never hard-coded |
| Backups | Supabase Pro daily backups (7 days); weekly Storage copy to a second provider; written restore steps (Phase 9) |
| Audit logs | Database triggers on properties, media, enquiries, statuses, settings and admin users |

## 7. Environments

| Env | Supabase | Website | Admin |
|-----|----------|---------|-------|
| Local | Supabase CLI (Docker) on this laptop | `npm run dev` | `flutter run -d chrome` |
| Staging | Cloud project "avanilands-staging" (Free plan, Mumbai) | Vercel preview | Cloudflare Pages preview |
| Production | Cloud project "avanilands-prod" (Pro plan, Mumbai) | Vercel production + custom domain | Cloudflare Pages + `admin.` subdomain |

Database changes only go through migration files, applied local → staging → production.

## 8. Running costs (estimate)

| Item | Development | After launch |
|------|-------------|--------------|
| Supabase | Free | Pro ~$25/month |
| Website hosting | Free (Vercel Hobby, non-commercial while building) | Vercel Pro ~$20/month (or Cloudflare, free) |
| Admin hosting | Free (Cloudflare Pages) | Free |
| Email (Resend) | Free (3,000/month) | Free at our volume |
| Bot check (Turnstile) | Free | Free |
| Maps | Free tier | Free tier; Google Maps only if chosen |
| Domain | — | ~₹800–1,500/year |

## 9. Modularity

- Each feature area (properties, media, enquiries, site visits, bookings, CMS…) has its own migration files, its own folder in `web/` and in `admin/lib/features/`.
- Later phases add tables and screens; they don't change MVP tables except by adding columns.
- Lookup lists (types, amenities, locations) are tables, not hard-coded, so the admin can change them without a code release.
