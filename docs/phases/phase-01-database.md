# Phase 1 — Database, security and seed data ✅

**Goal:** the full MVP schema from [02-database.md](../02-database.md), locked down with RLS, tested.
**Depends on:** Phase 0.

## Checklist
### Schema
- [x] Extensions: `pg_trgm` (`unaccent` dropped: names are plain English/Telugu transliterations, and it can't be used in a stored search column)
- [x] Enums (§1) and `area_to_sqft()`
- [x] `admin_users`, `is_admin()`, `is_super_admin()`
- [x] `site_settings` + `public_site_settings` view
- [x] `property_types`, `locations`, `amenities`
- [x] `properties` with all columns, CHECK constraints, generated `area_sqft`, code sequence trigger, `updated_at` trigger
- [x] `property_slug_history`, `property_amenities`, `property_nearby_places`
- [x] `property_images` (one-cover partial unique index), `property_videos`, `property_documents`
- [x] `enquiries` (reference sequence), `enquiry_notes`
- [x] `audit_logs` + audit triggers on properties (incl. price and status changes), images, videos, documents, enquiries, settings, admin users
- [x] All indexes from §4–6

### Functions
- [x] Publish and status rules — done by the `properties_before_write` trigger, so admins simply update `publish_state` / `availability` (see notes)
- [x] `delete_draft_property(id)`
- [x] `set_cover_image`, `reorder_property_images`
- [x] `search_properties(...)` with filters, sort, pagination, total count
- [x] `submit_enquiry(...)` (service role only, rate limit) and `update_enquiry_status(...)`
- [x] `dashboard_summary()` — counts for the admin dashboard

### Security
- [x] RLS on every table; public reads only through `public_properties`, `public_property_documents`, active lookups
- [x] `internal_notes` and admin columns never in public views
- [x] Approximate coordinates when `show_exact_location = false`
- [x] Storage buckets `property-media`, `property-documents` (private), `site-assets` with MIME/size limits and admin-only write policies
- [x] Auth: email sign-ups **disabled**; admins created by invite only

### Seed (local only)
- [x] 6 property types, ~12 amenities, 4–5 locations, 1 super admin, ~12 sample properties across types/statuses with placeholder images

### Tests (pgTAP)
- [x] Anonymous user: sees only published properties; cannot read enquiries, drafts, internal notes, private documents, audit logs; cannot write anything
- [x] Non-admin signed-in user: same as anonymous
- [x] Admin: full property CRUD; cannot edit audit logs; cannot manage admin users
- [x] Super admin: manages admin users; can revert sold → available
- [x] Publish rules, delete rules, one-cover rule, area conversion, search filters and sorting, enquiry rate limit

## Done when
All pgTAP tests pass on a fresh `supabase db reset`.

## Notes (2026-11-08)
- Migrations: `20261108110001_schema.sql` (enums, tables, constraints, indexes, starter types and amenities), `…110002_functions.sql` (role checks, rule triggers, audit, admin and website functions), `…110003_security.sql` (RLS, privileges, public views, `search_properties`, storage buckets).
- **Status rules live in a trigger, not separate functions.** The admin app just updates `publish_state` or `availability`; the trigger checks for a cover photo, creates the slug, sets the dates, stops "published → draft", and only lets a super admin undo a sale. A direct API call can't skip them.
- Rule errors come back as plain sentences (e.g. "Add a cover image before publishing.") that the admin app can show as they are. Website errors from `submit_enquiry` are short keys: `invalid_phone`, `property_unavailable`, `rate_limited`.
- Visitors read `public_properties`, `public_property_documents` and `public_site_settings`. These views run as their owner, so they can read private tables but only expose safe columns of published rows (Supabase's dashboard may flag them as "security definer views"; that is intended).
- `search_properties` hides sold land unless asked (`p_availability => '{sold}'`), puts price-on-request last when sorting by price, caps pages at 24, and treats `%` and `_` in the search box as plain text.
- Function privileges: new functions in `public` are **not** callable by visitors or signed-in users until granted. Every later migration must add its own `grant execute`.
- Property types and amenities are inserted by the migration (production gets them too). Locations, users and properties are in `seed.sql` (local only).
- Seed photos point at `seed/{property-id}/…` files that don't exist yet; Phase 5 adds placeholder artwork.
- Local test logins are listed at the top of `supabase/seed.sql`.
- Tests: `supabase test db` → 3 files, **105 checks, all pass**. `supabase db lint`: no issues.
