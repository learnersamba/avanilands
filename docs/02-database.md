# Database Design — Avanilands

PostgreSQL on Supabase. All tables live in `public` with **RLS enabled**. Times are `timestamptz`. Money is `numeric(14,2)` in rupees. IDs are `uuid` unless noted.

Legend: **MVP** = built in Phases 1–9 · *later* = added in the phase named.

## 1. Enums

| Enum | Values |
|------|--------|
| `admin_role` | `super_admin`, `admin` (*later:* `property_manager`, `sales_manager`, `content_manager`) |
| `publish_state` | `draft`, `published`, `hidden`, `archived` |
| `availability` | `available`, `reserved`, `sold` |
| `area_unit` | `sq_ft`, `sq_yd`, `sq_m`, `cent`, `gunta`, `acre` |
| `price_type` | `total`, `on_request` |
| `facing` | `north`, `south`, `east`, `west`, `north_east`, `north_west`, `south_east`, `south_west` |
| `approval_type` | `dtcp`, `vmrda`, `hmda`, `apcrda`, `panchayat`, `rera`, `not_applicable`, `other` |
| `media_video_kind` | `youtube`, `upload` |
| `document_type` | `brochure`, `layout_plan`, `approval`, `title_document`, `encumbrance`, `other` |
| `nearby_category` | `school`, `college`, `hospital`, `bus_stop`, `railway_station`, `airport`, `highway`, `market`, `landmark`, `other` |
| `enquiry_status` | `new`, `contacted`, `follow_up`, `interested`, `not_interested`, `converted`, `closed` |
| `contact_method` | `phone`, `whatsapp`, `email` |

### Area conversion (to square feet)
| Unit | sq ft |
|------|-------|
| sq_ft | 1 |
| sq_yd | 9 |
| sq_m | 10.7639 |
| cent | 435.6 |
| gunta | 1,089 |
| acre | 43,560 |

Implemented as an `immutable` SQL function `area_to_sqft(value, unit)` used by a generated column.

## 2. Access and admins — MVP

### `admin_users`
| Column | Type | Notes |
|--------|------|-------|
| user_id | uuid PK | FK → `auth.users(id)` on delete cascade |
| full_name | text not null | |
| role | admin_role not null default `admin` | |
| is_active | boolean not null default true | inactive admins fail `is_admin()` |
| created_at, updated_at | timestamptz | |

Helper functions (`security definer`, `stable`):
- `is_admin()` → current user is an active admin (any role).
- `is_super_admin()` → active and role = `super_admin`.

RLS: admins read all rows; only super admins insert/update; nobody deletes (deactivate instead); a super admin cannot deactivate themself.

### `site_settings` (single row, id = 1)
Company name, phone, WhatsApp number, email, office address, office hours, social links, sales notification email(s), default SEO title/description.
RLS: public read of public fields via the view `public_site_settings`; super admin update.

## 3. Lookups — MVP

### `property_types`
`id smallint identity PK`, `name text unique`, `slug text unique`, `seo_slug text unique` (e.g. `plots`, `agricultural-land`), `sort_order int`, `is_active bool`.

### `locations` (city / town level — used for filters and landing pages)
`id uuid PK`, `state text`, `district text`, `city text`, `slug text unique` (e.g. `visakhapatnam`), `description text`, `cover_image_path text`, `is_popular bool`, `sort_order int`, `is_active bool`, timestamps.
Unique on `(state, district, city)`.

### `amenities`
`id smallint identity PK`, `name text unique` (Gated community, Compound wall, Avenue plantation, BT roads, Underground drainage, Street lights, Water connection, Electricity connection, Park, 24×7 security…), `icon text`, `sort_order`, `is_active`.

RLS for all lookups: public read of active rows; admin full access.

## 4. Properties — MVP

### `properties`
| Group | Column | Type / rule |
|-------|--------|-------------|
| Identity | id | uuid PK |
| | code | text unique, set by trigger from a sequence: `AL-0001` |
| | slug | text unique, nullable until first publish; `^[a-z0-9-]+$` |
| Basic | title | text not null, 5–120 chars |
| | property_type_id | FK → property_types, not null |
| | description | text (plain text / limited Markdown), ≤ 10,000 chars |
| Location | location_id | FK → locations, not null |
| | locality | text (area / village) |
| | address | text |
| | pincode | text, 6 digits |
| | latitude, longitude | numeric(9,6), both null or both set, valid ranges |
| | show_exact_location | bool default false |
| Size | area_value | numeric(12,3) > 0 |
| | area_unit | area_unit |
| | area_sqft | numeric generated always as `area_to_sqft(area_value, area_unit)` stored |
| | length_ft, width_ft | numeric(8,2) > 0, optional |
| | dimensions_text | text optional (for irregular plots, e.g. "40 × 60 ft, corner") |
| Pricing | price_type | price_type default `total` |
| | price | numeric(14,2); required and > 0 when price_type = `total` |
| | price_per_unit | numeric(14,2) optional |
| | price_per_unit_unit | area_unit optional (both set or both null) |
| | is_negotiable | bool default false |
| Details | facing | facing, optional |
| | road_width_ft | numeric(6,2) optional |
| | is_corner | bool default false |
| | water_available | bool, optional (null = not specified) |
| | water_source | text optional (borewell, municipal, canal…) |
| | electricity_available | bool, optional |
| | approval_type | approval_type default `not_applicable` |
| | approval_number | text optional |
| | rera_number | text optional |
| | legal_notes | text — public legal summary ("Clear title, patta available") |
| | internal_notes | text — **admin only**, never in public views |
| Highlights | highlights | text[] (max 8, each ≤ 80 chars) |
| Status | publish_state | publish_state default `draft` |
| | availability | availability default `available` |
| | is_featured | bool default false |
| | featured_rank | int optional |
| SEO | seo_title, seo_description | text optional overrides |
| Search | search_vector | tsvector generated from title, code, locality, description, (city/type joined via trigger-maintained `search_text`) |
| Audit | created_by, updated_by | uuid FK → admin_users |
| | created_at, updated_at, published_at, reserved_at, sold_at, archived_at | timestamptz |

**Rules (enforced in the database):**
- Publishing requires: title, type, location, area, price (or on-request), **a cover image**, and a slug (auto-generated if missing, made unique with a suffix).
- Only `publish_state = 'published'` rows are visible to the public.
- `availability = 'sold'` sets `sold_at`; going from sold back to available needs a super admin.
- Hard delete only when `publish_state = 'draft'` and there are no enquiries (function `delete_draft_property`). Otherwise archive.
- Price changes are written to the audit log with old and new values.

**Indexes:**
- `(publish_state, availability, property_type_id, location_id)` for the main listing filter
- `(publish_state, price)`, `(publish_state, area_sqft)`, `(publish_state, published_at desc)`
- partial `(featured_rank) where is_featured and publish_state = 'published'`
- GIN on `search_vector`; trigram (`pg_trgm`) GIN on `locality` and `title` for typo-tolerant search
- `slug` unique, `code` unique

### `property_slug_history`
`slug text PK`, `property_id FK`, `created_at`. Old slugs redirect to the current one.

### `property_amenities`
`property_id FK`, `amenity_id FK`, PK on both.

### `property_nearby_places`
`id`, `property_id FK cascade`, `name text`, `category nearby_category`, `distance_km numeric(6,2)`, `sort_order`.

### `property_images`
| Column | Notes |
|--------|-------|
| id | uuid PK |
| property_id | FK cascade |
| path_thumb, path_medium, path_large | Storage paths in `property-media` (400 / 1200 / 2000 px WebP) |
| width, height | of the large image |
| alt_text | text, falls back to the property title |
| sort_order | int |
| is_cover | bool; **partial unique index**: one cover per property |
| created_at, created_by | |

Setting a new cover un-sets the old one in the same function (`set_cover_image`). Reordering uses `reorder_property_images(property_id, ids[])`.

### `property_videos`
`id`, `property_id FK cascade`, `kind media_video_kind`, `youtube_id text` (for youtube) or `storage_path text` (for upload), `title`, `is_primary` (one per property), `sort_order`, timestamps.

### `property_documents`
`id`, `property_id FK cascade`, `doc_type document_type`, `title text`, `storage_path text` (bucket `property-documents`, **private**), `mime_type`, `size_bytes`, `is_public bool default false`, `sort_order`, timestamps.

## 5. Enquiries — MVP

### `enquiries`
| Column | Notes |
|--------|-------|
| id | uuid PK |
| reference | text unique, `ENQ-000123` |
| property_id | FK → properties **on delete restrict**, nullable (general enquiry from the contact page) |
| customer_id | FK → auth.users, nullable (*later*, logged-in customers) |
| name | text 2–80 |
| phone | text, Indian mobile `^[6-9][0-9]{9}$` (stored without +91) |
| email | text optional, valid format |
| preferred_contact | contact_method default `phone` |
| message | text ≤ 1,000 |
| status | enquiry_status default `new` |
| assigned_to | FK → admin_users, optional |
| source | text: `property_page`, `contact_page`, `whatsapp_click` |
| ip_hash | text — salted hash, for rate limiting only |
| created_at, updated_at, last_contacted_at | |

Indexes: `(status, created_at desc)`, `(property_id)`, `(phone)`, `(ip_hash, created_at)`.

### `enquiry_notes`
`id`, `enquiry_id FK cascade`, `admin_id FK`, `note text`, `status_from`, `status_to` (when the note came with a status change), `created_at`. Gives a follow-up history.

**RPCs:**
- `submit_enquiry(...)` — `security definer`, executable by `service_role` only (called from the Next.js server with the secret key). Checks the property is published and not sold, applies the rate limit, inserts, returns the reference.
- `update_enquiry_status(id, status, note)` — admin only; writes a note row.

RLS: no public access at all. Admins read and update.

## 6. Audit — MVP

### `audit_logs`
`id bigint identity PK`, `actor_id uuid` (admin or null for system), `action text` (e.g. `property.created`, `property.price_changed`, `property.published`, `property.marked_sold`, `image.uploaded`, `image.deleted`, `enquiry.status_changed`), `entity_type text`, `entity_id uuid`, `details jsonb` (old/new values), `created_at`.
Written by triggers; admins can read; **nobody** can update or delete (not even super admins via the API).
Index: `(entity_type, entity_id, created_at desc)`, `(created_at desc)`.

## 7. Public read model — MVP

The website never reads base tables directly for listings. It uses:
- view `public_properties` — published rows only, **without** `internal_notes`, `created_by`, `updated_by`; latitude/longitude rounded to ~1 km when `show_exact_location` is false.
- RPC `search_properties(q, type_ids, location_ids, price_min, price_max, area_min_sqft, area_max_sqft, road_width_min, facings, availability, amenity_ids, approved_only, sort, page, page_size)` → rows + total count. Page size max 24.
- view `public_property_documents` — only `is_public` documents of published properties (metadata only, no paths).

## 8. Storage buckets — MVP

| Bucket | Public? | Allowed types | Max size | Write |
|--------|---------|---------------|----------|-------|
| `property-media` | public read | image/webp, image/jpeg, image/png, video/mp4 | 50 MB | admin |
| `property-documents` | **private** | application/pdf, image/jpeg, image/png | 20 MB | admin |
| `site-assets` | public read | images, svg | 5 MB | admin |

Paths: `property-media/{property_id}/{image_id}-{size}.webp`. Deleting an image row also deletes its files (function + admin app clean-up).

## 9. Later tables (designed now, built in later phases)

| Table | Phase | Purpose |
|-------|-------|---------|
| `site_visits` | 10 | property, customer details, date, time slot, visitors count, message, status (`requested`, `confirmed`, `rescheduled`, `completed`, `cancelled`), admin notes, confirmed date/time |
| `profiles` | 11 | customer profile (name, phone) linked to `auth.users` |
| `favorites` | 11 | customer ↔ property, unique pair |
| `recently_viewed` | 11 | customer ↔ property with viewed_at (last 20) |
| `bookings` | 13 | property, customer, status (`requested`, `pending_approval`, `approved`, `payment_pending`, `reserved`, `cancelled`, `completed`), amounts, admin notes. Approving sets the property to reserved; completing sets it to sold — inside one transaction; only one active booking per property (partial unique index) |
| `faqs`, `testimonials`, `banners`, `content_pages`, `homepage_sections` | 14 | CMS |
| `notifications` | 15 | recipient, type, title, body, link, read_at |
| `property_views`, `search_events` | 16 | analytics (daily rolled-up counts, no personal data) |
| `payments` | 17 | booking, gateway, amount, status (`pending`, `successful`, `failed`, `refunded`, `cancelled`), transaction id, receipt |

## 10. Entity relationships (MVP)

```
property_types 1──* properties *──1 locations
properties 1──* property_images
properties 1──* property_videos
properties 1──* property_documents
properties 1──* property_nearby_places
properties *──* amenities            (property_amenities)
properties 1──* enquiries 1──* enquiry_notes
admin_users 1──* enquiry_notes, audit_logs, properties(created_by)
```
