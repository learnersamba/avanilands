-- Phase 7: property page routing (redirects, 404, "no longer available")
-- and telling the website to refresh its cache when data changes.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- Routing for /land/<slug>. Returns null for unknown, draft and hidden
-- properties (→ 404). For an old slug it returns the current one (→ 301).
-- Archived properties return only what the "no longer available" page needs.
-- ---------------------------------------------------------------------------
create function public.property_route(p_slug text)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'slug', p.slug,
    'state', p.publish_state,
    'title', p.title,
    'city', l.city,
    'property_type_id', p.property_type_id,
    'location_id', p.location_id
  )
  from public.properties p
  join public.locations l on l.id = p.location_id
  where p.publish_state in ('published', 'archived')
    and (
      p.slug = p_slug
      or p.id = (select h.property_id from public.property_slug_history h where h.slug = p_slug)
    )
  limit 1;
$$;

revoke execute on function public.property_route(text) from public, anon, authenticated;
grant execute on function public.property_route(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Cache refresh. After any change to data the website shows, POST
-- {"table": "<name>"} to the website's /api/revalidate. The address and
-- shared secret live in Supabase Vault (one pair per environment):
--   select vault.create_secret('https://…/api/revalidate', 'website_revalidate_url');
--   select vault.create_secret('<random>', 'website_revalidate_secret');
-- Without them nothing is sent. pg_net sends after the transaction commits.
-- ---------------------------------------------------------------------------
create function private.notify_website()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'website_revalidate_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'website_revalidate_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('table', tg_table_name),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-revalidate-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;

revoke execute on function private.notify_website() from public, anon, authenticated;

-- One request per statement, not per row (reordering 40 photos = 1 request).
do $$
declare
  t text;
begin
  foreach t in array array[
    'properties', 'property_images', 'property_videos', 'property_documents',
    'property_amenities', 'property_nearby_places', 'locations', 'property_types',
    'amenities', 'site_settings'
  ] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
       for each statement execute function private.notify_website()',
      t || '_notify_website', t
    );
  end loop;
end;
$$;
