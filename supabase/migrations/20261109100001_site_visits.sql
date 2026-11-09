-- Phase 10: site visits. Customers request a visit on the website; the team
-- confirms, reschedules, completes or cancels it in the admin panel. Dates
-- and times are India time (Asia/Kolkata).

-- ---------------------------------------------------------------------------
-- Settings: when visits can be booked
-- ---------------------------------------------------------------------------
alter table public.site_settings
  -- ISO weekdays: 1 = Monday … 7 = Sunday
  add column visit_days smallint[] not null default '{1,2,3,4,5,6}'
    check (visit_days <@ '{1,2,3,4,5,6,7}'::smallint[] and cardinality(visit_days) between 1 and 7),
  -- Start times, 24-hour "HH:MM"
  add column visit_slots text[] not null default '{10:00,12:00,15:00}'
    check (cardinality(visit_slots) between 1 and 12
           and array_to_string(visit_slots, ',') ~ '^([01][0-9]|2[0-3]):[0-5][0-9](,([01][0-9]|2[0-3]):[0-5][0-9])*$'),
  -- Holidays and other days without visits
  add column visit_closed_dates date[] not null default '{}' check (cardinality(visit_closed_dates) <= 100),
  add column visit_days_ahead smallint not null default 30 check (visit_days_ahead between 1 and 90);

-- Columns can only be added at the end of a view.
create or replace view public.public_site_settings as
select company_name, phone, whatsapp, email, address, office_hours, social_links,
       seo_title, seo_description,
       visit_days, visit_slots,
       array(select d from unnest(visit_closed_dates) d
             where d > (now() at time zone 'Asia/Kolkata')::date order by d) as visit_closed_dates,
       visit_days_ahead
from public.site_settings
where id = 1;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create type public.site_visit_status as enum ('requested', 'confirmed', 'completed', 'no_show', 'cancelled');

create sequence public.site_visit_reference_seq;

create table public.site_visits (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique
                     default ('SV-' || lpad(nextval('public.site_visit_reference_seq')::text, 6, '0')),
  -- Properties with visits can't be deleted (archive instead).
  property_id      uuid not null references public.properties (id) on delete restrict,
  name             text not null check (length(btrim(name)) between 2 and 80),
  phone            text not null check (phone ~ '^[6-9][0-9]{9}$'),
  email            text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  visitors         smallint not null default 1 check (visitors between 1 and 20),
  visit_date       date not null,
  slot             text not null check (slot ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  message          text check (length(message) <= 1000),
  status           public.site_visit_status not null default 'requested',
  assigned_to      uuid references public.admin_users (user_id) on delete set null,
  ip_hash          text check (length(ip_hash) <= 128),
  idempotency_key  uuid unique,
  reminder_sent_at timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index site_visits_date_idx on public.site_visits (visit_date, slot);
create index site_visits_status_idx on public.site_visits (status, visit_date);
create index site_visits_property_idx on public.site_visits (property_id, visit_date desc);
create index site_visits_phone_idx on public.site_visits (phone, created_at desc);
create index site_visits_ip_idx on public.site_visits (ip_hash, created_at desc) where ip_hash is not null;

create trigger site_visits_updated_at
  before update on public.site_visits
  for each row execute function private.set_updated_at();

create table public.site_visit_notes (
  id            uuid primary key default gen_random_uuid(),
  site_visit_id uuid not null references public.site_visits (id) on delete cascade,
  admin_id      uuid references public.admin_users (user_id) on delete set null,
  note          text check (length(btrim(note)) between 1 and 2000),
  status_from   public.site_visit_status,
  status_to     public.site_visit_status,
  -- Set when the visit was moved: "2026-11-14 10:00"
  moved_from    text,
  moved_to      text,
  created_at    timestamptz not null default now(),
  constraint note_or_change check (note is not null or status_to is not null or moved_to is not null)
);
create index site_visit_notes_visit_idx on public.site_visit_notes (site_visit_id, created_at);

-- ---------------------------------------------------------------------------
-- Security: admins read; changes only through the functions below, except
-- reassigning (the assigned_to column), like enquiries.
-- ---------------------------------------------------------------------------
alter table public.site_visits enable row level security;
alter table public.site_visit_notes enable row level security;
revoke all on public.site_visits, public.site_visit_notes from anon;
revoke insert, update, delete, truncate on public.site_visits, public.site_visit_notes from authenticated;
grant update (assigned_to) on public.site_visits to authenticated;

create policy "admins read site visits" on public.site_visits
  for select to authenticated using ((select public.is_admin()));
create policy "admins reassign site visits" on public.site_visits
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admins read site visit notes" on public.site_visit_notes
  for select to authenticated using ((select public.is_admin()));

alter publication supabase_realtime add table public.site_visits;

-- ---------------------------------------------------------------------------
-- Rules
-- ---------------------------------------------------------------------------

-- Why a website booking for this date and slot isn't allowed, or null if it is.
create function private.site_visit_time_problem(p_date date, p_slot text)
returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v public.site_settings;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  select * into v from public.site_settings where id = 1;
  if p_date is null or p_date <= v_today or p_date > v_today + v.visit_days_ahead then
    return 'invalid_date';
  end if;
  if not (extract(isodow from p_date)::smallint = any (v.visit_days)) or p_date = any (v.visit_closed_dates) then
    return 'closed_day';
  end if;
  if p_slot is null or not (p_slot = any (v.visit_slots)) then
    return 'invalid_slot';
  end if;
  return null;
end;
$$;
revoke execute on function private.site_visit_time_problem(date, text) from public, anon, authenticated;

-- Website: request a visit. Called only by the website server (secret key)
-- after its own validation and bot check.
create function public.submit_site_visit(
  p_property_id uuid,
  p_name text,
  p_phone text,
  p_visit_date date,
  p_slot text,
  p_visitors smallint default 1,
  p_email text default null,
  p_message text default null,
  p_ip_hash text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_existing public.site_visits;
  v_problem text;
  v_id uuid;
  v_reference text;
begin
  if p_idempotency_key is not null then
    select * into v_existing from public.site_visits s where s.idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('id', v_existing.id, 'reference', v_existing.reference, 'duplicate', true,
        'visit_date', v_existing.visit_date, 'slot', v_existing.slot);
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

  if not exists (
    select 1 from public.properties p
    where p.id = p_property_id and p.publish_state = 'published' and p.availability <> 'sold'
  ) then
    raise exception 'property_unavailable' using errcode = 'P0002';
  end if;

  v_problem := private.site_visit_time_problem(p_visit_date, p_slot);
  if v_problem is not null then
    raise exception '%', v_problem using errcode = '22023';
  end if;

  -- Already waiting for a visit to this property: give the same reference.
  select * into v_existing from public.site_visits s
  where s.phone = v_phone and s.property_id = p_property_id
    and s.status in ('requested', 'confirmed')
    and s.visit_date >= (now() at time zone 'Asia/Kolkata')::date
  order by s.created_at desc limit 1;
  if found then
    return jsonb_build_object('id', v_existing.id, 'reference', v_existing.reference, 'duplicate', true,
      'already_booked', true, 'visit_date', v_existing.visit_date, 'slot', v_existing.slot);
  end if;

  if (select count(*) from public.site_visits s
      where s.phone = v_phone and s.created_at > now() - interval '1 hour') >= 3
     or (p_ip_hash is not null and (select count(*) from public.site_visits s
      where s.ip_hash = p_ip_hash and s.created_at > now() - interval '1 hour') >= 5) then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.site_visits (
    property_id, name, phone, email, visitors, visit_date, slot, message, ip_hash, idempotency_key
  ) values (
    p_property_id, btrim(p_name), v_phone, nullif(lower(btrim(p_email)), ''), coalesce(p_visitors, 1),
    p_visit_date, p_slot, nullif(btrim(p_message), ''), p_ip_hash, p_idempotency_key
  )
  returning id, reference into v_id, v_reference;

  return jsonb_build_object('id', v_id, 'reference', v_reference, 'duplicate', false,
    'visit_date', p_visit_date, 'slot', p_slot);
end;
$$;

-- Admin: confirm / reschedule / complete / no_show / cancel, with an optional
-- note. Rescheduling (any future date and time) leaves the visit Confirmed.
create function public.update_site_visit(
  p_site_visit_id uuid,
  p_action text,
  p_note text default null,
  p_visit_date date default null,
  p_slot text default null
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v public.site_visits;
  v_to public.site_visit_status;
  v_moved_from text;
  v_moved_to text;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  perform private.require_admin();
  select * into v from public.site_visits s where s.id = p_site_visit_id for update;
  if not found then
    raise exception 'Site visit not found.' using errcode = 'P0002';
  end if;

  case p_action
    when 'confirm' then
      if v.status <> 'requested' then
        raise exception 'Only requested visits can be confirmed.' using errcode = '22023';
      end if;
      v_to := 'confirmed';
    when 'reschedule' then
      if v.status not in ('requested', 'confirmed') then
        raise exception 'Only requested or confirmed visits can be moved.' using errcode = '22023';
      end if;
      if p_visit_date is null or p_visit_date < v_today then
        raise exception 'Choose today or a later date.' using errcode = '22023';
      end if;
      if p_slot is null or p_slot !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        raise exception 'Choose a time.' using errcode = '22023';
      end if;
      if p_visit_date = v.visit_date and p_slot = v.slot then
        raise exception 'That is the current time of the visit.' using errcode = '22023';
      end if;
      v_to := 'confirmed';
      v_moved_from := v.visit_date::text || ' ' || v.slot;
      v_moved_to := p_visit_date::text || ' ' || p_slot;
    when 'complete', 'no_show' then
      if v.status <> 'confirmed' then
        raise exception 'Only confirmed visits can be marked as done.' using errcode = '22023';
      end if;
      if v.visit_date > v_today then
        raise exception 'This visit is still in the future.' using errcode = '22023';
      end if;
      v_to := case p_action when 'complete' then 'completed' else 'no_show' end::public.site_visit_status;
    when 'cancel' then
      if v.status not in ('requested', 'confirmed') then
        raise exception 'This visit is already finished.' using errcode = '22023';
      end if;
      v_to := 'cancelled';
    else
      raise exception 'Unknown action.' using errcode = '22023';
  end case;

  update public.site_visits set
    status = v_to,
    visit_date = coalesce(case when p_action = 'reschedule' then p_visit_date end, visit_date),
    slot = coalesce(case when p_action = 'reschedule' then p_slot end, slot),
    reminder_sent_at = case when p_action = 'reschedule' then null else reminder_sent_at end
  where id = p_site_visit_id;

  insert into public.site_visit_notes (site_visit_id, admin_id, note, status_from, status_to, moved_from, moved_to)
  values (p_site_visit_id, (select auth.uid()), nullif(btrim(p_note), ''),
          case when v_to <> v.status then v.status end,
          case when v_to <> v.status then v_to end,
          v_moved_from, v_moved_to);
end;
$$;

-- Admin: add a follow-up note.
create function public.add_site_visit_note(p_site_visit_id uuid, p_note text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  if not exists (select 1 from public.site_visits s where s.id = p_site_visit_id) then
    raise exception 'Site visit not found.' using errcode = 'P0002';
  end if;
  insert into public.site_visit_notes (site_visit_id, admin_id, note)
  values (p_site_visit_id, (select auth.uid()), btrim(p_note))
  returning id into v_id;
  return v_id;
end;
$$;

-- Website (daily job): confirmed visits tomorrow that haven't had a reminder.
-- Marks them as reminded and returns them, so two runs never send twice.
create function public.claim_site_visit_reminders()
returns setof public.site_visits
language sql security definer set search_path = '' as $$
  update public.site_visits s set reminder_sent_at = now()
  where s.status = 'confirmed' and s.reminder_sent_at is null
    and s.visit_date = (now() at time zone 'Asia/Kolkata')::date + 1
  returning s.*;
$$;

revoke execute on function public.submit_site_visit(uuid, text, text, date, text, smallint, text, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.submit_site_visit(uuid, text, text, date, text, smallint, text, text, text, uuid)
  to service_role;
revoke execute on function public.claim_site_visit_reminders() from public, anon, authenticated;
grant execute on function public.claim_site_visit_reminders() to service_role;
revoke execute on function public.update_site_visit(uuid, text, text, date, text) from public, anon;
grant execute on function public.update_site_visit(uuid, text, text, date, text) to authenticated;
revoke execute on function public.add_site_visit_note(uuid, text) from public, anon;
grant execute on function public.add_site_visit_note(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Activity log
-- ---------------------------------------------------------------------------
create function private.audit_site_visit()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_base jsonb := jsonb_build_object('reference', new.reference, 'property_id', new.property_id);
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('site_visit.requested', 'site_visit', new.id::text,
      v_base || jsonb_build_object('visit_date', new.visit_date, 'slot', new.slot));
  else
    if new.visit_date <> old.visit_date or new.slot <> old.slot then
      perform private.write_audit('site_visit.rescheduled', 'site_visit', new.id::text,
        v_base || jsonb_build_object('from', old.visit_date::text || ' ' || old.slot,
                                     'to', new.visit_date::text || ' ' || new.slot));
    end if;
    if new.status <> old.status then
      perform private.write_audit('site_visit.status_changed', 'site_visit', new.id::text,
        v_base || jsonb_build_object('from', old.status, 'to', new.status));
    end if;
    if new.assigned_to is distinct from old.assigned_to then
      perform private.write_audit('site_visit.assigned', 'site_visit', new.id::text,
        v_base || jsonb_build_object('from', old.assigned_to, 'to', new.assigned_to));
    end if;
  end if;
  return null;
end;
$$;

create trigger site_visits_audit
  after insert or update on public.site_visits
  for each row execute function private.audit_site_visit();

-- ---------------------------------------------------------------------------
-- Customer emails: tell the website when a visit is confirmed, moved or
-- cancelled (it sends the email). Same address and secret as the cache refresh.
-- ---------------------------------------------------------------------------
create function private.notify_site_visit_change()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
  v_event text;
begin
  if new.visit_date <> old.visit_date or new.slot <> old.slot then
    v_event := 'rescheduled';
  elsif new.status <> old.status and new.status in ('confirmed', 'cancelled') then
    v_event := new.status::text;
  else
    return null;
  end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'website_revalidate_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'website_revalidate_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  perform net.http_post(
    url := regexp_replace(v_url, '/api/revalidate$', '/api/site-visits/notify'),
    body := jsonb_build_object('id', new.id, 'event', v_event),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-revalidate-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;
revoke execute on function private.notify_site_visit_change() from public, anon, authenticated;

create trigger site_visits_notify_customer
  after update on public.site_visits
  for each row execute function private.notify_site_visit_change();

-- ---------------------------------------------------------------------------
-- Dashboard: add visit counts
-- ---------------------------------------------------------------------------
create or replace function public.dashboard_summary()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
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
      (select count(*) from public.contact_taps t where t.channel = 'call' and t.created_at > now() - interval '7 days'),
    'requested_site_visits',
      (select count(*) from public.site_visits s where s.status = 'requested'),
    'site_visits_next_7_days',
      (select count(*) from public.site_visits s where s.status = 'confirmed'
         and s.visit_date between v_today and v_today + 7)
  );
end;
$$;

