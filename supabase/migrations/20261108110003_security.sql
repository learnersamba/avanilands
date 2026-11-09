-- Phase 1: who can see and change what (docs/01-architecture.md §6).
-- Visitors never read base tables that hold private data; they read the
-- public_* views and call search_properties. Admins work on the tables
-- directly, limited by RLS. Every table has RLS on.

create trigger property_amenities_audit
  after insert or delete on public.property_amenities
  for each row execute function private.audit_row('property_amenity');

-- ---------------------------------------------------------------------------
-- RLS on
-- ---------------------------------------------------------------------------
alter table public.admin_users enable row level security;
alter table public.site_settings enable row level security;
alter table public.property_types enable row level security;
alter table public.locations enable row level security;
alter table public.amenities enable row level security;
alter table public.properties enable row level security;
alter table public.property_slug_history enable row level security;
alter table public.property_amenities enable row level security;
alter table public.property_nearby_places enable row level security;
alter table public.property_images enable row level security;
alter table public.property_videos enable row level security;
alter table public.property_documents enable row level security;
alter table public.enquiries enable row level security;
alter table public.enquiry_notes enable row level security;
alter table public.audit_logs enable row level security;

-- ---------------------------------------------------------------------------
-- Table privileges. Visitors (anon) get nothing on private tables at all.
-- ---------------------------------------------------------------------------
revoke all on public.admin_users, public.site_settings, public.properties,
  public.property_slug_history, public.property_documents, public.enquiries,
  public.enquiry_notes, public.audit_logs
  from anon;

-- The audit log is append-only, and only triggers append.
revoke insert, update, delete, truncate on public.audit_logs from authenticated;
-- Enquiries arrive through submit_enquiry; status changes go through
-- update_enquiry_status so every change gets a note. Admins may only reassign.
revoke insert, update, delete, truncate on public.enquiries from authenticated;
grant update (assigned_to) on public.enquiries to authenticated;
revoke update, delete, truncate on public.enquiry_notes from authenticated;
-- Slug history is maintained by the properties trigger.
revoke insert, update, delete, truncate on public.property_slug_history from authenticated;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
create policy "admins read admins" on public.admin_users
  for select to authenticated using ((select public.is_admin()));
create policy "super admins add admins" on public.admin_users
  for insert to authenticated with check ((select public.is_super_admin()));
create policy "super admins update admins" on public.admin_users
  for update to authenticated
  using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

create policy "admins read settings" on public.site_settings
  for select to authenticated using ((select public.is_admin()));
create policy "super admins update settings" on public.site_settings
  for update to authenticated
  using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

-- Lookups: everyone sees active rows; admins see and change all.
create policy "read property types" on public.property_types
  for select using (is_active or (select public.is_admin()));
create policy "admins write property types" on public.property_types
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "read locations" on public.locations
  for select using (is_active or (select public.is_admin()));
create policy "admins write locations" on public.locations
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "read amenities" on public.amenities
  for select using (is_active or (select public.is_admin()));
create policy "admins write amenities" on public.amenities
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

-- Properties: admins only (visitors use public_properties). No delete
-- policy: drafts are removed with delete_draft_property.
create policy "admins read properties" on public.properties
  for select to authenticated using ((select public.is_admin()));
create policy "admins add properties" on public.properties
  for insert to authenticated with check ((select public.is_admin()));
create policy "admins update properties" on public.properties
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "admins read slug history" on public.property_slug_history
  for select to authenticated using ((select public.is_admin()));

-- Child rows of published properties are public; admins manage all.
create policy "read amenities of visible properties" on public.property_amenities
  for select using (private.property_is_public(property_id) or (select public.is_admin()));
create policy "admins write property amenities" on public.property_amenities
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "read nearby places of visible properties" on public.property_nearby_places
  for select using (private.property_is_public(property_id) or (select public.is_admin()));
create policy "admins write nearby places" on public.property_nearby_places
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "read images of visible properties" on public.property_images
  for select using (private.property_is_public(property_id) or (select public.is_admin()));
create policy "admins write images" on public.property_images
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "read videos of visible properties" on public.property_videos
  for select using (private.property_is_public(property_id) or (select public.is_admin()));
create policy "admins write videos" on public.property_videos
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

-- Documents: admins only (visitors use public_property_documents).
create policy "admins manage documents" on public.property_documents
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "admins read enquiries" on public.enquiries
  for select to authenticated using ((select public.is_admin()));
create policy "admins reassign enquiries" on public.enquiries
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "admins read enquiry notes" on public.enquiry_notes
  for select to authenticated using ((select public.is_admin()));

create policy "admins read audit log" on public.audit_logs
  for select to authenticated using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Public read model. These views run as their owner, so they read the
-- private tables but expose only safe columns of published rows.
-- ---------------------------------------------------------------------------
create view public.public_properties as
select
  p.id,
  p.code,
  p.slug,
  p.title,
  p.property_type_id,
  t.name     as type_name,
  t.slug     as type_slug,
  t.seo_slug as type_seo_slug,
  p.description,
  p.location_id,
  l.city,
  l.district,
  l.state,
  l.slug     as location_slug,
  p.locality,
  case when p.show_exact_location then p.address end as address,
  p.pincode,
  -- Approximate (~1 km) unless the admin allows the exact pin.
  case when p.show_exact_location then p.latitude else round(p.latitude, 2) end as latitude,
  case when p.show_exact_location then p.longitude else round(p.longitude, 2) end as longitude,
  p.show_exact_location,
  p.area_value,
  p.area_unit,
  p.area_sqft,
  p.length_ft,
  p.width_ft,
  p.dimensions_text,
  p.price_type,
  case when p.price_type = 'total' then p.price end as price,
  case when p.price_type = 'total' then p.price_per_unit end as price_per_unit,
  case when p.price_type = 'total' then p.price_per_unit_unit end as price_per_unit_unit,
  p.is_negotiable,
  p.facing,
  p.road_width_ft,
  p.is_corner,
  p.water_available,
  p.water_source,
  p.electricity_available,
  p.approval_type,
  p.approval_number,
  p.rera_number,
  p.legal_notes,
  p.highlights,
  p.availability,
  p.is_featured,
  p.featured_rank,
  p.seo_title,
  p.seo_description,
  p.published_at,
  p.updated_at,
  c.path_thumb  as cover_thumb,
  c.path_medium as cover_medium,
  c.path_large  as cover_large,
  coalesce(c.alt_text, p.title) as cover_alt,
  (select count(*)::int from public.property_images i where i.property_id = p.id) as image_count
from public.properties p
join public.property_types t on t.id = p.property_type_id
join public.locations l on l.id = p.location_id
left join public.property_images c on c.property_id = p.id and c.is_cover
where p.publish_state = 'published';

create view public.public_property_documents as
select d.id, d.property_id, d.doc_type, d.title, d.mime_type, d.size_bytes, d.sort_order
from public.property_documents d
join public.properties p on p.id = d.property_id
where d.is_public and p.publish_state = 'published';

create view public.public_site_settings as
select company_name, phone, whatsapp, email, address, office_hours, social_links,
       seo_title, seo_description
from public.site_settings
where id = 1;

revoke all on public.public_properties, public.public_property_documents, public.public_site_settings
  from anon, authenticated;
grant select on public.public_properties, public.public_property_documents, public.public_site_settings
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Search (website listing). Filters are optional; sold properties appear
-- only when asked for. Returns {"total": n, "page": n, "page_size": n, "items": [...]}.
-- ---------------------------------------------------------------------------
create function public.search_properties(
  p_q text default null,
  p_type_ids smallint[] default null,
  p_location_ids uuid[] default null,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_area_min_sqft numeric default null,
  p_area_max_sqft numeric default null,
  p_road_width_min numeric default null,
  p_facings public.facing[] default null,
  p_availability public.availability[] default null,
  p_amenity_ids smallint[] default null,
  p_approved_only boolean default false,
  p_featured_only boolean default false,
  p_sort text default 'newest',
  p_page int default 1,
  p_page_size int default 12
)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_q text := nullif(btrim(p_q), '');
  v_like text;
  v_tsq tsquery;
  v_sort text := coalesce(p_sort, 'newest');
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 12), 1), 24);
  v_avail public.availability[] := coalesce(
    nullif(p_availability, '{}'), array['available', 'reserved']::public.availability[]);
  v_amenities smallint[] := array(select distinct a from unnest(p_amenity_ids) a where a is not null);
  v_total int;
  v_items jsonb;
begin
  if v_sort not in ('newest', 'price_asc', 'price_desc', 'area_asc', 'area_desc', 'featured') then
    raise exception 'Unknown sort: %', v_sort using errcode = '22023';
  end if;
  if v_q is not null then
    v_q := left(v_q, 100);
    v_like := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    v_tsq := websearch_to_tsquery('simple', v_q);
  end if;

  with filtered as (
    select p.id, p.published_at, p.price, p.price_type, p.area_sqft, p.is_featured, p.featured_rank
    from public.properties p
    join public.locations l on l.id = p.location_id
    join public.property_types t on t.id = p.property_type_id
    where p.publish_state = 'published'
      and p.availability = any (v_avail)
      and (v_q is null
           or p.search_vector @@ v_tsq
           or l.city ilike v_like or l.district ilike v_like or t.name ilike v_like
           or p.locality ilike v_like or p.title ilike v_like
           or p.title operator(extensions.%) v_q
           or p.locality operator(extensions.%) v_q
           or l.city operator(extensions.%) v_q)
      and (coalesce(cardinality(p_type_ids), 0) = 0 or p.property_type_id = any (p_type_ids))
      and (coalesce(cardinality(p_location_ids), 0) = 0 or p.location_id = any (p_location_ids))
      and (p_price_min is null or (p.price_type = 'total' and p.price >= p_price_min))
      and (p_price_max is null or (p.price_type = 'total' and p.price <= p_price_max))
      and (p_area_min_sqft is null or p.area_sqft >= p_area_min_sqft)
      and (p_area_max_sqft is null or p.area_sqft <= p_area_max_sqft)
      and (p_road_width_min is null or p.road_width_ft >= p_road_width_min)
      and (coalesce(cardinality(p_facings), 0) = 0 or p.facing = any (p_facings))
      and (not coalesce(p_approved_only, false) or p.approval_type <> 'not_applicable')
      and (not coalesce(p_featured_only, false) or p.is_featured)
      and (cardinality(v_amenities) = 0 or (
        select count(*) from public.property_amenities pa
        where pa.property_id = p.id and pa.amenity_id = any (v_amenities)
      ) = cardinality(v_amenities))
  ),
  ranked as (
    select f.id, row_number() over (order by
      case when v_sort = 'price_asc' then case when f.price_type = 'total' then f.price end end asc nulls last,
      case when v_sort = 'price_desc' then case when f.price_type = 'total' then f.price end end desc nulls last,
      case when v_sort = 'area_asc' then f.area_sqft end asc nulls last,
      case when v_sort = 'area_desc' then f.area_sqft end desc nulls last,
      case when v_sort = 'featured' then not f.is_featured end asc,
      case when v_sort = 'featured' then f.featured_rank end asc nulls last,
      f.published_at desc, f.id) as rn
    from filtered f
  )
  select
    (select count(*) from filtered),
    coalesce(jsonb_agg(
      to_jsonb(pp) - array['description', 'legal_notes', 'address', 'seo_title', 'seo_description']
      order by r.rn), '[]'::jsonb)
  into v_total, v_items
  from ranked r
  join public.public_properties pp on pp.id = r.id
  where r.rn > (v_page - 1) * v_size and r.rn <= v_page * v_size;

  return jsonb_build_object('total', v_total, 'page', v_page, 'page_size', v_size, 'items', v_items);
end;
$$;

-- ---------------------------------------------------------------------------
-- Function privileges (Postgres lets everyone execute new functions by default)
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;

grant execute on function public.health() to anon, authenticated;
grant execute on function public.area_to_sqft(numeric, public.area_unit) to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_super_admin() to anon, authenticated;
grant execute on function public.resolve_property_slug(text) to anon, authenticated;
grant execute on function public.search_properties(
  text, smallint[], uuid[], numeric, numeric, numeric, numeric, numeric,
  public.facing[], public.availability[], smallint[], boolean, boolean, text, int, int
) to anon, authenticated;

-- Admin functions (each also checks is_admin itself).
grant execute on function public.set_cover_image(uuid) to authenticated;
grant execute on function public.reorder_property_images(uuid, uuid[]) to authenticated;
grant execute on function public.set_primary_video(uuid) to authenticated;
grant execute on function public.delete_draft_property(uuid) to authenticated;
grant execute on function public.dashboard_summary() to authenticated;
grant execute on function public.update_enquiry_status(uuid, public.enquiry_status, text) to authenticated;
grant execute on function public.add_enquiry_note(uuid, text) to authenticated;

-- Website server only.
grant execute on function public.submit_enquiry(
  text, text, text, uuid, text, public.contact_method, text, text, uuid, uuid
) to service_role;

-- Helpers used inside RLS policies and constraints.
grant execute on function private.property_is_public(uuid) to anon, authenticated;
grant execute on function private.text_list_ok(text[], int, int) to anon, authenticated;

-- Functions created later are not executable by visitors unless granted.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage buckets (docs/02-database.md §8)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('property-media', 'property-media', true, 50 * 1024 * 1024,
    array['image/webp', 'image/jpeg', 'image/png', 'video/mp4']),
  ('property-documents', 'property-documents', false, 20 * 1024 * 1024,
    array['application/pdf', 'image/jpeg', 'image/png']),
  ('site-assets', 'site-assets', true, 5 * 1024 * 1024,
    array['image/webp', 'image/jpeg', 'image/png', 'image/svg+xml'])
on conflict (id) do nothing;

-- Public buckets serve files by URL without a policy; listing and all
-- writes are for admins only. Private documents: admins only.
create policy "admins read site files" on storage.objects
  for select to authenticated
  using (bucket_id in ('property-media', 'property-documents', 'site-assets') and (select public.is_admin()));
create policy "admins upload site files" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('property-media', 'property-documents', 'site-assets') and (select public.is_admin()));
create policy "admins update site files" on storage.objects
  for update to authenticated
  using (bucket_id in ('property-media', 'property-documents', 'site-assets') and (select public.is_admin()))
  with check (bucket_id in ('property-media', 'property-documents', 'site-assets') and (select public.is_admin()));
create policy "admins delete site files" on storage.objects
  for delete to authenticated
  using (bucket_id in ('property-media', 'property-documents', 'site-assets') and (select public.is_admin()));
