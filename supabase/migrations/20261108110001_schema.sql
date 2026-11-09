-- Phase 1: core MVP schema (docs/02-database.md).
-- Rules that need other tables live in triggers (…_functions.sql);
-- access rules live in …_security.sql.

create extension if not exists pg_trgm with schema extensions;

-- Internal helpers live in `private`, which the API does not expose.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.admin_role as enum ('super_admin', 'admin');
create type public.publish_state as enum ('draft', 'published', 'hidden', 'archived');
create type public.availability as enum ('available', 'reserved', 'sold');
create type public.area_unit as enum ('sq_ft', 'sq_yd', 'sq_m', 'cent', 'gunta', 'acre');
create type public.price_type as enum ('total', 'on_request');
create type public.facing as enum (
  'north', 'south', 'east', 'west', 'north_east', 'north_west', 'south_east', 'south_west'
);
create type public.approval_type as enum (
  'dtcp', 'vmrda', 'hmda', 'apcrda', 'panchayat', 'rera', 'not_applicable', 'other'
);
create type public.media_video_kind as enum ('youtube', 'upload');
create type public.document_type as enum (
  'brochure', 'layout_plan', 'approval', 'title_document', 'encumbrance', 'other'
);
create type public.nearby_category as enum (
  'school', 'college', 'hospital', 'bus_stop', 'railway_station', 'airport',
  'highway', 'market', 'landmark', 'other'
);
create type public.enquiry_status as enum (
  'new', 'contacted', 'follow_up', 'interested', 'not_interested', 'converted', 'closed'
);
create type public.contact_method as enum ('phone', 'whatsapp', 'email');

-- ---------------------------------------------------------------------------
-- Pure helpers (immutable, usable in constraints and generated columns)
-- ---------------------------------------------------------------------------

-- Square feet in one unit: 1 cent = 435.6 sq ft, 1 gunta = 1,089, 1 acre = 43,560.
create function public.area_to_sqft(p_value numeric, p_unit public.area_unit)
returns numeric
language sql immutable parallel safe set search_path = '' as $$
  select round(p_value * case p_unit
    when 'sq_ft' then 1
    when 'sq_yd' then 9
    when 'sq_m'  then 10.7639
    when 'cent'  then 435.6
    when 'gunta' then 1089
    when 'acre'  then 43560
  end, 3);
$$;

-- A short list of non-blank strings: at most max_items, each at most max_len.
create function private.text_list_ok(p_items text[], p_max_items int, p_max_len int)
returns boolean
language sql immutable parallel safe set search_path = '' as $$
  select coalesce(cardinality(p_items), 0) <= p_max_items
     and not exists (
       select 1 from unnest(p_items) x
       where x is null or length(btrim(x)) = 0 or length(x) > p_max_len
     );
$$;
grant execute on function private.text_list_ok(text[], int, int) to anon, authenticated, service_role;

create function private.slugify(p_text text)
returns text
language sql immutable parallel safe set search_path = '' as $$
  select coalesce(
    nullif(btrim(regexp_replace(lower(coalesce(p_text, '')), '[^a-z0-9]+', '-', 'g'), '-'), ''),
    'property'
  );
$$;

-- ---------------------------------------------------------------------------
-- Admins and settings
-- ---------------------------------------------------------------------------
create table public.admin_users (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (length(btrim(full_name)) between 1 and 80),
  email      text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role       public.admin_role not null default 'admin',
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Exactly one row (id = 1). Public fields are exposed through public_site_settings.
create table public.site_settings (
  id                  smallint primary key default 1 check (id = 1),
  company_name        text not null default 'Avanilands' check (length(company_name) between 1 and 80),
  phone               text check (length(phone) <= 20),
  whatsapp            text check (whatsapp ~ '^[0-9]{10,13}$'),
  email               text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  address             text check (length(address) <= 300),
  office_hours        text check (length(office_hours) <= 120),
  social_links        jsonb not null default '{}'::jsonb check (jsonb_typeof(social_links) = 'object'),
  sales_notify_emails text[] not null default '{}' check (private.text_list_ok(sales_notify_emails, 5, 120)),
  seo_title           text check (length(seo_title) <= 70),
  seo_description     text check (length(seo_description) <= 170),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------
create table public.property_types (
  id         smallint generated always as identity primary key,
  name       text not null unique check (length(btrim(name)) between 2 and 60),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  -- Used in landing page URLs: /{seo_slug}-for-sale/{city}
  seo_slug   text not null unique check (seo_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.locations (
  id               uuid primary key default gen_random_uuid(),
  state            text not null check (length(btrim(state)) between 2 and 60),
  district         text not null check (length(btrim(district)) between 2 and 60),
  city             text not null check (length(btrim(city)) between 2 and 60),
  slug             text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description      text check (length(description) <= 2000),
  cover_image_path text,
  is_popular       boolean not null default false,
  sort_order       int not null default 0,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (state, district, city)
);

create table public.amenities (
  id         smallint generated always as identity primary key,
  name       text not null unique check (length(btrim(name)) between 2 and 60),
  icon       text check (length(icon) <= 40),
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------
create sequence public.property_code_seq;

create table public.properties (
  id                    uuid primary key default gen_random_uuid(),
  code                  text not null unique
                          default ('AL-' || lpad(nextval('public.property_code_seq')::text, 4, '0')),
  slug                  text unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) <= 100),

  -- Basic
  title                 text not null check (length(btrim(title)) between 5 and 120),
  property_type_id      smallint not null references public.property_types (id),
  description           text check (length(description) <= 10000),

  -- Location
  location_id           uuid not null references public.locations (id),
  locality              text check (length(locality) <= 120),
  address               text check (length(address) <= 300),
  pincode               text check (pincode ~ '^[1-9][0-9]{5}$'),
  latitude              numeric(9, 6) check (latitude between -90 and 90),
  longitude             numeric(9, 6) check (longitude between -180 and 180),
  show_exact_location   boolean not null default false,

  -- Size (area_sqft lets filters and sorting work across units)
  area_value            numeric(12, 3) check (area_value > 0),
  area_unit             public.area_unit not null default 'sq_yd',
  area_sqft             numeric(16, 3) generated always as (public.area_to_sqft(area_value, area_unit)) stored,
  length_ft             numeric(8, 2) check (length_ft > 0),
  width_ft              numeric(8, 2) check (width_ft > 0),
  dimensions_text       text check (length(dimensions_text) <= 120),

  -- Pricing (rupees)
  price_type            public.price_type not null default 'total',
  price                 numeric(14, 2) check (price > 0),
  price_per_unit        numeric(14, 2) check (price_per_unit > 0),
  price_per_unit_unit   public.area_unit,
  is_negotiable         boolean not null default false,

  -- Details
  facing                public.facing,
  road_width_ft         numeric(6, 2) check (road_width_ft > 0),
  is_corner             boolean not null default false,
  water_available       boolean,
  water_source          text check (length(water_source) <= 80),
  electricity_available boolean,
  approval_type         public.approval_type not null default 'not_applicable',
  approval_number       text check (length(approval_number) <= 80),
  rera_number           text check (length(rera_number) <= 80),
  legal_notes           text check (length(legal_notes) <= 2000),
  internal_notes        text check (length(internal_notes) <= 5000), -- admin only, never public
  highlights            text[] not null default '{}' check (private.text_list_ok(highlights, 8, 80)),

  -- Status
  publish_state         public.publish_state not null default 'draft',
  availability          public.availability not null default 'available',
  is_featured           boolean not null default false,
  featured_rank         int check (featured_rank > 0),

  -- SEO overrides
  seo_title             text check (length(seo_title) <= 70),
  seo_description       text check (length(seo_description) <= 170),

  search_vector         tsvector generated always as (to_tsvector('simple',
                          coalesce(code, '') || ' ' || coalesce(title, '') || ' ' ||
                          coalesce(locality, '') || ' ' || coalesce(address, '') || ' ' ||
                          coalesce(description, ''))) stored,

  -- Set by triggers
  created_by            uuid references public.admin_users (user_id) on delete set null,
  updated_by            uuid references public.admin_users (user_id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  published_at          timestamptz,
  reserved_at           timestamptz,
  sold_at               timestamptz,
  archived_at           timestamptz,

  constraint coordinates_together check ((latitude is null) = (longitude is null)),
  constraint per_unit_price_together check ((price_per_unit is null) = (price_per_unit_unit is null)),
  -- Drafts may be incomplete; anything else needs size, price and a URL.
  constraint area_required_after_draft check (publish_state = 'draft' or area_value is not null),
  constraint price_required_after_draft check (
    publish_state = 'draft' or price_type = 'on_request' or price is not null
  ),
  constraint slug_required_after_draft check (publish_state = 'draft' or slug is not null)
);

create index properties_listing_idx
  on public.properties (publish_state, availability, property_type_id, location_id);
create index properties_price_idx on public.properties (publish_state, price);
create index properties_area_idx on public.properties (publish_state, area_sqft);
create index properties_published_idx on public.properties (publish_state, published_at desc);
create index properties_featured_idx on public.properties (featured_rank)
  where is_featured and publish_state = 'published';
create index properties_search_idx on public.properties using gin (search_vector);
create index properties_title_trgm_idx on public.properties using gin (title extensions.gin_trgm_ops);
create index properties_locality_trgm_idx on public.properties using gin (locality extensions.gin_trgm_ops);
create index properties_location_idx on public.properties (location_id);
create index properties_type_idx on public.properties (property_type_id);

-- Old URLs keep working: /land/{old-slug} redirects to the current slug.
create table public.property_slug_history (
  slug        text primary key,
  property_id uuid not null references public.properties (id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index property_slug_history_property_idx on public.property_slug_history (property_id);

create table public.property_amenities (
  property_id uuid not null references public.properties (id) on delete cascade,
  amenity_id  smallint not null references public.amenities (id),
  primary key (property_id, amenity_id)
);
create index property_amenities_amenity_idx on public.property_amenities (amenity_id);

create table public.property_nearby_places (
  id          uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  name        text not null check (length(btrim(name)) between 2 and 80),
  category    public.nearby_category not null default 'other',
  distance_km numeric(6, 2) check (distance_km >= 0),
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index property_nearby_places_property_idx on public.property_nearby_places (property_id, sort_order);

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------
create table public.property_images (
  id          uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  path_thumb  text not null,  -- 400 px WebP in bucket property-media
  path_medium text not null,  -- 1200 px
  path_large  text not null,  -- 2000 px
  width       int check (width > 0),
  height      int check (height > 0),
  alt_text    text check (length(alt_text) <= 160),
  sort_order  int not null default 0,
  is_cover    boolean not null default false,
  created_by  uuid references public.admin_users (user_id) on delete set null,
  created_at  timestamptz not null default now()
);
create index property_images_property_idx on public.property_images (property_id, sort_order);
create unique index property_images_one_cover_idx on public.property_images (property_id) where is_cover;

create table public.property_videos (
  id           uuid primary key default gen_random_uuid(),
  property_id  uuid not null references public.properties (id) on delete cascade,
  kind         public.media_video_kind not null,
  youtube_id   text check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  storage_path text,
  title        text check (length(title) <= 120),
  is_primary   boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint video_source check (
    (kind = 'youtube' and youtube_id is not null and storage_path is null) or
    (kind = 'upload' and storage_path is not null and youtube_id is null)
  )
);
create index property_videos_property_idx on public.property_videos (property_id, sort_order);
create unique index property_videos_one_primary_idx on public.property_videos (property_id) where is_primary;

create table public.property_documents (
  id           uuid primary key default gen_random_uuid(),
  property_id  uuid not null references public.properties (id) on delete cascade,
  doc_type     public.document_type not null default 'other',
  title        text not null check (length(btrim(title)) between 2 and 120),
  storage_path text not null unique,  -- bucket property-documents (private)
  mime_type    text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  size_bytes   int not null check (size_bytes > 0 and size_bytes <= 20 * 1024 * 1024),
  is_public    boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index property_documents_property_idx on public.property_documents (property_id, sort_order);

-- ---------------------------------------------------------------------------
-- Enquiries
-- ---------------------------------------------------------------------------
create sequence public.enquiry_reference_seq;

create table public.enquiries (
  id                uuid primary key default gen_random_uuid(),
  reference         text not null unique
                      default ('ENQ-' || lpad(nextval('public.enquiry_reference_seq')::text, 6, '0')),
  -- Null = general enquiry (contact page). Properties with enquiries can't be deleted.
  property_id       uuid references public.properties (id) on delete restrict,
  customer_id       uuid references auth.users (id) on delete set null,
  name              text not null check (length(btrim(name)) between 2 and 80),
  phone             text not null check (phone ~ '^[6-9][0-9]{9}$'), -- Indian mobile, no +91
  email             text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  preferred_contact public.contact_method not null default 'phone',
  message           text check (length(message) <= 1000),
  status            public.enquiry_status not null default 'new',
  assigned_to       uuid references public.admin_users (user_id) on delete set null,
  source            text not null default 'property_page'
                      check (source in ('property_page', 'contact_page', 'whatsapp_click')),
  ip_hash           text check (length(ip_hash) <= 128), -- salted hash, rate limiting only
  idempotency_key   uuid unique,                          -- stops double submits
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  last_contacted_at timestamptz
);
create index enquiries_status_idx on public.enquiries (status, created_at desc);
create index enquiries_property_idx on public.enquiries (property_id);
create index enquiries_phone_idx on public.enquiries (phone, created_at desc);
create index enquiries_ip_idx on public.enquiries (ip_hash, created_at desc) where ip_hash is not null;

create table public.enquiry_notes (
  id          uuid primary key default gen_random_uuid(),
  enquiry_id  uuid not null references public.enquiries (id) on delete cascade,
  admin_id    uuid references public.admin_users (user_id) on delete set null,
  note        text check (length(btrim(note)) between 1 and 2000),
  status_from public.enquiry_status,
  status_to   public.enquiry_status,
  created_at  timestamptz not null default now(),
  constraint note_or_status check (note is not null or status_to is not null)
);
create index enquiry_notes_enquiry_idx on public.enquiry_notes (enquiry_id, created_at);

-- ---------------------------------------------------------------------------
-- Audit log (written only by triggers and functions)
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid,          -- admin user id; null = system / website visitor
  action      text not null, -- e.g. property.price_changed
  entity_type text not null, -- e.g. property, image, enquiry
  entity_id   text,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index audit_logs_entity_idx on public.audit_logs (entity_type, entity_id, created_at desc);
create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_property_idx on public.audit_logs ((details ->> 'property_id'))
  where details ? 'property_id';
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Starter reference data (production needs these too)
-- ---------------------------------------------------------------------------
insert into public.site_settings (id) values (1);

insert into public.property_types (name, slug, seo_slug, sort_order) values
  ('Residential Plot', 'residential-plot', 'plots', 1),
  ('Villa Plot', 'villa-plot', 'villa-plots', 2),
  ('Agricultural Land', 'agricultural-land', 'agricultural-land', 3),
  ('Farm Land', 'farm-land', 'farm-land', 4),
  ('Commercial Land', 'commercial-land', 'commercial-land', 5),
  ('Industrial Land', 'industrial-land', 'industrial-land', 6);

insert into public.amenities (name, icon, sort_order) values
  ('Gated community', 'gate', 1),
  ('Compound wall', 'wall', 2),
  ('BT / CC roads', 'road', 3),
  ('Underground drainage', 'drain', 4),
  ('Street lights', 'light', 5),
  ('Water connection', 'water', 6),
  ('Electricity connection', 'bolt', 7),
  ('Avenue plantation', 'tree', 8),
  ('Park / open space', 'park', 9),
  ('24×7 security', 'shield', 10),
  ('Borewell', 'well', 11),
  ('Fencing', 'fence', 12);
