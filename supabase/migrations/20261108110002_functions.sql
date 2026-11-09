-- Phase 1: role checks, business-rule triggers, audit log and API functions.
-- Rules are enforced here so no screen (or direct API call) can skip them.

-- ---------------------------------------------------------------------------
-- Role checks
-- ---------------------------------------------------------------------------
create function public.is_admin()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.admin_users a
    where a.user_id = (select auth.uid()) and a.is_active
  );
$$;

create function public.is_super_admin()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.admin_users a
    where a.user_id = (select auth.uid()) and a.is_active and a.role = 'super_admin'
  );
$$;

create function private.require_admin()
returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can do this.' using errcode = '42501';
  end if;
end;
$$;

-- A property visitors may see (used by RLS on child tables).
create function private.property_is_public(p_property_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.properties p
    where p.id = p_property_id and p.publish_state = 'published'
  );
$$;

-- ---------------------------------------------------------------------------
-- Audit helpers
-- ---------------------------------------------------------------------------
create function private.write_audit(
  p_action text, p_entity_type text, p_entity_id text, p_details jsonb default '{}'::jsonb
)
returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values ((select auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_details, '{}'::jsonb));
$$;

-- {"field": {"old": …, "new": …}} for every changed key not in p_ignore.
create function private.jsonb_changes(p_old jsonb, p_new jsonb, p_ignore text[] default '{}')
returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_object_agg(n.key, jsonb_build_object('old', p_old -> n.key, 'new', n.value)), '{}'::jsonb)
  from jsonb_each(p_new) n
  where not (n.key = any (p_ignore))
    and (p_old -> n.key) is distinct from n.value;
$$;

create function private.set_updated_at()
returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Generic audit trigger. TG_ARGV[0] = entity type (image, location, …).
-- Keeps property_id in details so a property's history includes its media.
create function private.audit_row()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_type text := tg_argv[0];
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_details jsonb := '{}'::jsonb;
  v_changes jsonb;
begin
  if v_row ? 'property_id' then
    v_details := jsonb_build_object('property_id', v_row ->> 'property_id');
  end if;

  if tg_op = 'INSERT' then
    perform private.write_audit(v_type || '.created', v_type, coalesce(v_row ->> 'id', v_row ->> 'property_id'),
      v_details || jsonb_strip_nulls(jsonb_build_object(
        'name', coalesce(v_row ->> 'name', v_row ->> 'title', v_row ->> 'city'))));
  elsif tg_op = 'DELETE' then
    perform private.write_audit(v_type || '.deleted', v_type, coalesce(v_row ->> 'id', v_row ->> 'property_id'),
      v_details || jsonb_strip_nulls(jsonb_build_object(
        'name', coalesce(v_row ->> 'name', v_row ->> 'title', v_row ->> 'city'))));
  else
    v_changes := private.jsonb_changes(to_jsonb(old), to_jsonb(new), array['updated_at', 'sort_order']);
    if v_changes <> '{}'::jsonb then
      perform private.write_audit(v_type || '.updated', v_type, coalesce(v_row ->> 'id', v_row ->> 'property_id'),
        v_details || jsonb_build_object('changes', v_changes));
    end if;
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------

-- Slug from the title plus the city (unless the title already names it),
-- made unique across current and old slugs.
create function private.unique_property_slug(p_title text, p_location_id uuid, p_property_id uuid)
returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_base text := private.slugify(p_title);
  v_city text;
  v_candidate text;
  v_n int := 1;
begin
  select private.slugify(l.city) into v_city from public.locations l where l.id = p_location_id;
  if v_city is not null and position(v_city in v_base) = 0 then
    v_base := v_base || '-' || v_city;
  end if;
  v_base := btrim(left(v_base, 90), '-');
  v_candidate := v_base;
  while exists (select 1 from public.properties p where p.slug = v_candidate and p.id <> p_property_id)
     or exists (select 1 from public.property_slug_history h
                where h.slug = v_candidate and h.property_id <> p_property_id) loop
    v_n := v_n + 1;
    v_candidate := v_base || '-' || v_n;
  end loop;
  return v_candidate;
end;
$$;

create function private.properties_before_write()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' then
    if new.publish_state <> 'draft' then
      raise exception 'New properties start as drafts. Add a cover image, then publish.'
        using errcode = '23514';
    end if;
    new.created_by := v_uid;
    new.updated_by := v_uid;
    new.created_at := now();
    new.updated_at := now();
    new.published_at := null;
    new.archived_at := null;
    new.reserved_at := case when new.availability = 'reserved' then now() end;
    new.sold_at := case when new.availability = 'sold' then now() end;
  else
    new.id := old.id;
    new.code := old.code;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_by := coalesce(v_uid, old.updated_by);
    new.updated_at := now();

    if old.publish_state <> 'draft' and new.publish_state = 'draft' then
      raise exception 'A published property cannot go back to draft. Hide it instead.'
        using errcode = '23514';
    end if;
    if old.availability = 'sold' and new.availability <> 'sold'
       and v_uid is not null and not public.is_super_admin() then
      raise exception 'Only a super admin can change a sold property back.' using errcode = '42501';
    end if;

    new.published_at := case
      when new.publish_state = 'published' and old.published_at is null then now()
      else old.published_at end;
    new.archived_at := case
      when new.publish_state <> 'archived' then null
      when old.publish_state = 'archived' then old.archived_at
      else now() end;
    new.reserved_at := case
      when new.availability <> 'reserved' then null
      when old.availability = 'reserved' then old.reserved_at
      else now() end;
    new.sold_at := case
      when new.availability <> 'sold' then null
      when old.availability = 'sold' then old.sold_at
      else now() end;
  end if;

  if new.publish_state = 'archived' then
    new.is_featured := false;
  end if;
  if not new.is_featured then
    new.featured_rank := null;
  end if;

  -- URL: generated on first leaving draft; kept for good after that.
  if new.publish_state <> 'draft' and new.slug is null then
    if tg_op = 'UPDATE' and old.slug is not null then
      raise exception 'The web address (slug) cannot be removed.' using errcode = '23514';
    end if;
    new.slug := private.unique_property_slug(new.title, new.location_id, new.id);
  end if;
  if new.slug is not null and exists (
    select 1 from public.property_slug_history h where h.slug = new.slug and h.property_id <> new.id
  ) then
    raise exception 'This web address was used by another property. Choose a different one.'
      using errcode = '23505';
  end if;
  if tg_op = 'UPDATE' and old.slug is not null and new.slug is distinct from old.slug then
    insert into public.property_slug_history (slug, property_id) values (old.slug, new.id)
      on conflict (slug) do update set property_id = excluded.property_id, created_at = now();
    delete from public.property_slug_history h where h.slug = new.slug and h.property_id = new.id;
  end if;

  if new.publish_state = 'published' and (tg_op = 'INSERT' or old.publish_state <> 'published')
     and not exists (select 1 from public.property_images i where i.property_id = new.id and i.is_cover) then
    raise exception 'Add a cover image before publishing.' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger properties_before_write
  before insert or update on public.properties
  for each row execute function private.properties_before_write();

create function private.audit_property()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_changes jsonb;
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('property.created', 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code, 'title', new.title));
    return null;
  elsif tg_op = 'DELETE' then
    perform private.write_audit('property.deleted', 'property', old.id::text,
      jsonb_build_object('property_id', old.id, 'code', old.code, 'title', old.title));
    return null;
  end if;

  if new.price is distinct from old.price or new.price_type is distinct from old.price_type then
    perform private.write_audit('property.price_changed', 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code,
        'old_price', old.price, 'new_price', new.price,
        'old_price_type', old.price_type, 'new_price_type', new.price_type));
  end if;

  if new.publish_state <> old.publish_state then
    perform private.write_audit(
      'property.' || case
        when new.publish_state = 'published' then 'published'
        when old.publish_state = 'published' and new.publish_state = 'hidden' then 'unpublished'
        else new.publish_state::text end,
      'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code,
        'from', old.publish_state, 'to', new.publish_state));
  end if;

  if new.availability <> old.availability then
    perform private.write_audit('property.marked_' || new.availability::text, 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code,
        'from', old.availability, 'to', new.availability));
  end if;

  v_changes := private.jsonb_changes(to_jsonb(old), to_jsonb(new), array[
    'price', 'price_type', 'publish_state', 'availability', 'updated_at', 'updated_by',
    'search_vector', 'area_sqft', 'published_at', 'archived_at', 'reserved_at', 'sold_at']);
  if v_changes <> '{}'::jsonb then
    perform private.write_audit('property.updated', 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code, 'changes', v_changes));
  end if;
  return null;
end;
$$;

create trigger properties_audit
  after insert or update or delete on public.properties
  for each row execute function private.audit_property();

-- ---------------------------------------------------------------------------
-- Images: max 40, first one becomes cover, cover moves on when deleted
-- ---------------------------------------------------------------------------
create function private.images_before_insert()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.properties p where p.id = new.property_id for update;
  if (select count(*) from public.property_images i where i.property_id = new.property_id) >= 40 then
    raise exception 'A property can have at most 40 photos.' using errcode = '23514';
  end if;
  new.created_by := (select auth.uid());
  new.sort_order := coalesce(
    (select max(i.sort_order) from public.property_images i where i.property_id = new.property_id), 0) + 1;
  if not exists (select 1 from public.property_images i where i.property_id = new.property_id and i.is_cover) then
    new.is_cover := true;
  elsif new.is_cover then
    raise exception 'Use set_cover_image to change the cover photo.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger property_images_before_insert
  before insert on public.property_images
  for each row execute function private.images_before_insert();

create function private.images_before_delete()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.is_cover
     and private.property_is_public(old.property_id)
     and not exists (select 1 from public.property_images i
                     where i.property_id = old.property_id and i.id <> old.id) then
    raise exception 'This is the only photo of a published property. Add another photo or unpublish it first.'
      using errcode = '23514';
  end if;
  return old;
end;
$$;

create trigger property_images_before_delete
  before delete on public.property_images
  for each row execute function private.images_before_delete();

create function private.images_after_delete()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Skip when the whole property is being deleted.
  if old.is_cover and exists (select 1 from public.properties p where p.id = old.property_id) then
    update public.property_images set is_cover = true
    where id = (select i.id from public.property_images i
                where i.property_id = old.property_id
                order by i.sort_order, i.created_at limit 1);
  end if;
  return null;
end;
$$;

create trigger property_images_after_delete
  after delete on public.property_images
  for each row execute function private.images_after_delete();

create trigger property_images_audit
  after insert or update or delete on public.property_images
  for each row execute function private.audit_row('image');

-- ---------------------------------------------------------------------------
-- Videos: first one becomes primary, primary moves on when deleted
-- ---------------------------------------------------------------------------
create function private.videos_before_insert()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.properties p where p.id = new.property_id for update;
  new.sort_order := coalesce(
    (select max(v.sort_order) from public.property_videos v where v.property_id = new.property_id), 0) + 1;
  if not exists (select 1 from public.property_videos v where v.property_id = new.property_id and v.is_primary) then
    new.is_primary := true;
  elsif new.is_primary then
    raise exception 'Use set_primary_video to change the main video.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger property_videos_before_insert
  before insert on public.property_videos
  for each row execute function private.videos_before_insert();

create function private.videos_after_delete()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.is_primary and exists (select 1 from public.properties p where p.id = old.property_id) then
    update public.property_videos set is_primary = true
    where id = (select v.id from public.property_videos v
                where v.property_id = old.property_id
                order by v.sort_order, v.created_at limit 1);
  end if;
  return null;
end;
$$;

create trigger property_videos_after_delete
  after delete on public.property_videos
  for each row execute function private.videos_after_delete();

create trigger property_videos_updated_at
  before update on public.property_videos
  for each row execute function private.set_updated_at();
create trigger property_videos_audit
  after insert or update or delete on public.property_videos
  for each row execute function private.audit_row('video');

create trigger property_documents_updated_at
  before update on public.property_documents
  for each row execute function private.set_updated_at();
create trigger property_documents_audit
  after insert or update or delete on public.property_documents
  for each row execute function private.audit_row('document');

create trigger property_nearby_places_audit
  after insert or update or delete on public.property_nearby_places
  for each row execute function private.audit_row('nearby_place');

-- ---------------------------------------------------------------------------
-- Lookups and settings
-- ---------------------------------------------------------------------------
create trigger locations_updated_at
  before update on public.locations
  for each row execute function private.set_updated_at();
create trigger locations_audit
  after insert or update or delete on public.locations
  for each row execute function private.audit_row('location');
create trigger property_types_audit
  after insert or update or delete on public.property_types
  for each row execute function private.audit_row('property_type');
create trigger amenities_audit
  after insert or update or delete on public.amenities
  for each row execute function private.audit_row('amenity');

create trigger site_settings_updated_at
  before update on public.site_settings
  for each row execute function private.set_updated_at();
create trigger site_settings_audit
  after update on public.site_settings
  for each row execute function private.audit_row('settings');

-- ---------------------------------------------------------------------------
-- Admin users: no self-demotion; always one active super admin
-- ---------------------------------------------------------------------------
create function private.admin_users_before_update()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.user_id := old.user_id;
  new.created_at := old.created_at;
  new.updated_at := now();
  if old.user_id = (select auth.uid()) and (new.role <> old.role or not new.is_active) then
    raise exception 'You cannot change your own role or deactivate yourself.' using errcode = '42501';
  end if;
  if old.role = 'super_admin' and old.is_active
     and (new.role <> 'super_admin' or not new.is_active)
     and not exists (select 1 from public.admin_users a
                     where a.role = 'super_admin' and a.is_active and a.user_id <> old.user_id) then
    raise exception 'At least one active super admin is required.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger admin_users_before_update
  before update on public.admin_users
  for each row execute function private.admin_users_before_update();

create function private.audit_admin_user()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('admin.added', 'admin', new.user_id::text,
      jsonb_build_object('email', new.email, 'role', new.role));
  else
    if new.role <> old.role then
      perform private.write_audit('admin.role_changed', 'admin', new.user_id::text,
        jsonb_build_object('email', new.email, 'from', old.role, 'to', new.role));
    end if;
    if new.is_active <> old.is_active then
      perform private.write_audit(case when new.is_active then 'admin.reactivated' else 'admin.deactivated' end,
        'admin', new.user_id::text, jsonb_build_object('email', new.email));
    end if;
  end if;
  return null;
end;
$$;

create trigger admin_users_audit
  after insert or update on public.admin_users
  for each row execute function private.audit_admin_user();

-- ---------------------------------------------------------------------------
-- Enquiries
-- ---------------------------------------------------------------------------
create trigger enquiries_updated_at
  before update on public.enquiries
  for each row execute function private.set_updated_at();

-- No phone numbers or names in the audit log.
create function private.audit_enquiry()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('enquiry.received', 'enquiry', new.id::text,
      jsonb_strip_nulls(jsonb_build_object('reference', new.reference, 'property_id', new.property_id,
        'source', new.source)));
  else
    if new.status <> old.status then
      perform private.write_audit('enquiry.status_changed', 'enquiry', new.id::text,
        jsonb_strip_nulls(jsonb_build_object('reference', new.reference, 'property_id', new.property_id,
          'from', old.status, 'to', new.status)));
    end if;
    if new.assigned_to is distinct from old.assigned_to then
      perform private.write_audit('enquiry.assigned', 'enquiry', new.id::text,
        jsonb_build_object('reference', new.reference, 'from', old.assigned_to, 'to', new.assigned_to));
    end if;
  end if;
  return null;
end;
$$;

create trigger enquiries_audit
  after insert or update on public.enquiries
  for each row execute function private.audit_enquiry();

-- ===========================================================================
-- API functions
-- ===========================================================================

-- Admin: make one photo the cover.
create function public.set_cover_image(p_image_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_property_id uuid;
begin
  perform private.require_admin();
  select i.property_id into v_property_id from public.property_images i where i.id = p_image_id;
  if v_property_id is null then
    raise exception 'Photo not found.' using errcode = 'P0002';
  end if;
  update public.property_images set is_cover = false
  where property_id = v_property_id and is_cover and id <> p_image_id;
  update public.property_images set is_cover = true where id = p_image_id and not is_cover;
end;
$$;

-- Admin: save a new photo order (must list every photo of the property once).
create function public.reorder_property_images(p_property_id uuid, p_image_ids uuid[])
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if (select coalesce(array_agg(i.id order by i.id), '{}') from public.property_images i
      where i.property_id = p_property_id)
     is distinct from
     (select coalesce(array_agg(x order by x), '{}') from unnest(p_image_ids) x) then
    raise exception 'The new order must include every photo of this property exactly once.'
      using errcode = '22023';
  end if;
  update public.property_images i set sort_order = o.n
  from unnest(p_image_ids) with ordinality as o(id, n)
  where i.id = o.id;
  perform private.write_audit('images.reordered', 'property', p_property_id::text,
    jsonb_build_object('property_id', p_property_id));
end;
$$;

-- Admin: make one video the main video.
create function public.set_primary_video(p_video_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_property_id uuid;
begin
  perform private.require_admin();
  select v.property_id into v_property_id from public.property_videos v where v.id = p_video_id;
  if v_property_id is null then
    raise exception 'Video not found.' using errcode = 'P0002';
  end if;
  update public.property_videos set is_primary = false
  where property_id = v_property_id and is_primary and id <> p_video_id;
  update public.property_videos set is_primary = true where id = p_video_id and not is_primary;
end;
$$;

-- Admin: delete a draft that never had enquiries. Returns the storage paths
-- the admin app must remove: {"media": [...], "documents": [...]}.
create function public.delete_draft_property(p_property_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_state public.publish_state;
  v_media text[];
  v_documents text[];
begin
  perform private.require_admin();
  select p.publish_state into v_state from public.properties p where p.id = p_property_id for update;
  if v_state is null then
    raise exception 'Property not found.' using errcode = 'P0002';
  end if;
  if v_state <> 'draft' then
    raise exception 'Only drafts can be deleted. Archive this property instead.' using errcode = '23514';
  end if;
  if exists (select 1 from public.enquiries e where e.property_id = p_property_id) then
    raise exception 'This property has enquiries. Archive it instead.' using errcode = '23503';
  end if;

  select coalesce(array_agg(x), '{}') into v_media from (
    select unnest(array[i.path_thumb, i.path_medium, i.path_large]) as x
    from public.property_images i where i.property_id = p_property_id
    union all
    select v.storage_path from public.property_videos v
    where v.property_id = p_property_id and v.storage_path is not null
  ) m;
  select coalesce(array_agg(d.storage_path), '{}') into v_documents
  from public.property_documents d where d.property_id = p_property_id;

  delete from public.properties where id = p_property_id;
  return jsonb_build_object('media', to_jsonb(v_media), 'documents', to_jsonb(v_documents));
end;
$$;

-- Admin dashboard numbers.
create function public.dashboard_summary()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
begin
  perform private.require_admin();
  select jsonb_build_object(
    'total',       count(*) filter (where publish_state <> 'archived'),
    'draft',       count(*) filter (where publish_state = 'draft'),
    'published',   count(*) filter (where publish_state = 'published'),
    'hidden',      count(*) filter (where publish_state = 'hidden'),
    'archived',    count(*) filter (where publish_state = 'archived'),
    'available',   count(*) filter (where publish_state = 'published' and availability = 'available'),
    'reserved',    count(*) filter (where publish_state <> 'archived' and availability = 'reserved'),
    'sold',        count(*) filter (where publish_state <> 'archived' and availability = 'sold')
  ) into v_result
  from public.properties;

  return v_result || jsonb_build_object(
    'new_enquiries', (select count(*) from public.enquiries e where e.status = 'new'),
    'enquiries_last_7_days',
      (select count(*) from public.enquiries e where e.created_at > now() - interval '7 days')
  );
end;
$$;

-- Website: current slug for a slug (follows old slugs). Null = not found.
create function public.resolve_property_slug(p_slug text)
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select p.slug from public.properties p
     where p.slug = p_slug and p.publish_state in ('published', 'archived')),
    (select p.slug from public.property_slug_history h
     join public.properties p on p.id = h.property_id
     where h.slug = p_slug and p.publish_state in ('published', 'archived'))
  );
$$;

-- Website: submit an enquiry. Called only by the website server (secret key)
-- after validation and the bot check. Errors use stable message keys.
create function public.submit_enquiry(
  p_name text,
  p_phone text,
  p_message text default null,
  p_property_id uuid default null,
  p_email text default null,
  p_preferred_contact public.contact_method default 'phone',
  p_source text default 'property_page',
  p_ip_hash text default null,
  p_idempotency_key uuid default null,
  p_customer_id uuid default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_existing public.enquiries;
  v_id uuid;
  v_reference text;
begin
  if p_idempotency_key is not null then
    select * into v_existing from public.enquiries e where e.idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('id', v_existing.id, 'reference', v_existing.reference, 'duplicate', true);
    end if;
  end if;

  if length(v_phone) = 12 and left(v_phone, 2) = '91' then
    v_phone := substr(v_phone, 3);
  elsif length(v_phone) = 11 and left(v_phone, 1) = '0' then
    v_phone := substr(v_phone, 2);
  end if;
  if v_phone !~ '^[6-9][0-9]{9}$' then
    raise exception 'invalid_phone' using errcode = '22023';
  end if;

  if p_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id = p_property_id and p.publish_state = 'published' and p.availability <> 'sold'
  ) then
    raise exception 'property_unavailable' using errcode = 'P0002';
  end if;

  if (select count(*) from public.enquiries e
      where e.phone = v_phone and e.created_at > now() - interval '1 hour') >= 5
     or (p_ip_hash is not null and (select count(*) from public.enquiries e
      where e.ip_hash = p_ip_hash and e.created_at > now() - interval '1 hour') >= 5) then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.enquiries (
    property_id, customer_id, name, phone, email, preferred_contact, message,
    source, ip_hash, idempotency_key
  ) values (
    p_property_id, p_customer_id, btrim(p_name), v_phone, nullif(lower(btrim(p_email)), ''),
    coalesce(p_preferred_contact, 'phone'), nullif(btrim(p_message), ''),
    coalesce(p_source, 'property_page'), p_ip_hash, p_idempotency_key
  )
  returning id, reference into v_id, v_reference;

  return jsonb_build_object('id', v_id, 'reference', v_reference, 'duplicate', false);
end;
$$;

-- Admin: change an enquiry's status, optionally with a note.
create function public.update_enquiry_status(
  p_enquiry_id uuid, p_status public.enquiry_status, p_note text default null
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_old public.enquiry_status;
begin
  perform private.require_admin();
  select e.status into v_old from public.enquiries e where e.id = p_enquiry_id for update;
  if v_old is null then
    raise exception 'Enquiry not found.' using errcode = 'P0002';
  end if;
  if v_old = p_status and nullif(btrim(p_note), '') is null then
    return;
  end if;

  update public.enquiries set
    status = p_status,
    last_contacted_at = case when p_status <> 'new' and p_status <> v_old then now() else last_contacted_at end
  where id = p_enquiry_id;

  insert into public.enquiry_notes (enquiry_id, admin_id, note, status_from, status_to)
  values (p_enquiry_id, (select auth.uid()), nullif(btrim(p_note), ''),
          case when p_status <> v_old then v_old end,
          case when p_status <> v_old then p_status end);
end;
$$;

-- Admin: add a follow-up note.
create function public.add_enquiry_note(p_enquiry_id uuid, p_note text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  if not exists (select 1 from public.enquiries e where e.id = p_enquiry_id) then
    raise exception 'Enquiry not found.' using errcode = 'P0002';
  end if;
  insert into public.enquiry_notes (enquiry_id, admin_id, note)
  values (p_enquiry_id, (select auth.uid()), btrim(p_note))
  returning id into v_id;
  return v_id;
end;
$$;
