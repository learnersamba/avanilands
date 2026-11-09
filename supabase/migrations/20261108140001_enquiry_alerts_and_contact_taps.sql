-- Phase 8: live "new enquiry" alerts in the admin panel, and counting
-- WhatsApp / call taps on the website (no personal data).

-- Admins receive new enquiries over Supabase Realtime. RLS still applies:
-- only active admins get the rows.
alter publication supabase_realtime add table public.enquiries;

-- ---------------------------------------------------------------------------
-- Contact taps: one row per tap on a WhatsApp or call button.
-- ---------------------------------------------------------------------------
create table public.contact_taps (
  id          bigint generated always as identity primary key,
  property_id uuid references public.properties (id) on delete set null,
  channel     text not null check (channel in ('whatsapp', 'call')),
  created_at  timestamptz not null default now()
);
create index contact_taps_created_idx on public.contact_taps (created_at desc);
create index contact_taps_property_idx on public.contact_taps (property_id, created_at desc);

alter table public.contact_taps enable row level security;
revoke all on public.contact_taps from anon;
revoke insert, update, delete, truncate on public.contact_taps from authenticated;
create policy "admins read contact taps" on public.contact_taps
  for select to authenticated using ((select public.is_admin()));

-- Called by the website server (secret key) only. Unknown or unpublished
-- properties are recorded without a property.
create function public.log_contact_tap(p_channel text, p_property_id uuid default null)
returns void
language sql security definer set search_path = '' as $$
  insert into public.contact_taps (channel, property_id)
  values (
    p_channel,
    (select p.id from public.properties p where p.id = p_property_id and p.publish_state = 'published')
  );
$$;

revoke execute on function public.log_contact_tap(text, uuid) from public, anon, authenticated;
grant execute on function public.log_contact_tap(text, uuid) to service_role;

-- Dashboard: add taps in the last 7 days.
create or replace function public.dashboard_summary()
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
      (select count(*) from public.enquiries e where e.created_at > now() - interval '7 days'),
    'whatsapp_taps_last_7_days',
      (select count(*) from public.contact_taps t where t.channel = 'whatsapp' and t.created_at > now() - interval '7 days'),
    'call_taps_last_7_days',
      (select count(*) from public.contact_taps t where t.channel = 'call' and t.created_at > now() - interval '7 days')
  );
end;
$$;
