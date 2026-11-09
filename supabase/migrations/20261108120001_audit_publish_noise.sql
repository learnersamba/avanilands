-- Phase 2: the first publish creates the slug; that is part of "Published",
-- not a separate "Updated …: slug" entry in the activity log.

create or replace function private.audit_property()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_changes jsonb;
  v_ignore text[] := array[
    'price', 'price_type', 'publish_state', 'availability', 'updated_at', 'updated_by',
    'search_vector', 'area_sqft', 'published_at', 'archived_at', 'reserved_at', 'sold_at'];
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
        'from', old.publish_state, 'to', new.publish_state, 'slug', new.slug));
  end if;

  if new.availability <> old.availability then
    perform private.write_audit('property.marked_' || new.availability::text, 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code,
        'from', old.availability, 'to', new.availability));
  end if;

  if old.slug is null then
    v_ignore := array_append(v_ignore, 'slug');
  end if;
  v_changes := private.jsonb_changes(to_jsonb(old), to_jsonb(new), v_ignore);
  if v_changes <> '{}'::jsonb then
    perform private.write_audit('property.updated', 'property', new.id::text,
      jsonb_build_object('property_id', new.id, 'code', new.code, 'changes', v_changes));
  end if;
  return null;
end;
$$;

revoke execute on function private.audit_property() from public, anon, authenticated;
