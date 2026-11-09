-- Phase 13: bookings. The owner's flow: Requested → Pending approval →
-- Approved (property Reserved) → Payment pending → Reserved (payment
-- recorded) → Completed (property Sold); Cancelled from any open step.
-- Payments happen offline (company process); only the record is kept here.

create type public.booking_status as enum (
  'requested', 'pending_approval', 'approved', 'payment_pending', 'reserved', 'completed', 'cancelled'
);

create sequence public.booking_reference_seq;

create table public.bookings (
  id                uuid primary key default gen_random_uuid(),
  reference         text not null unique
                      default ('BKG-' || lpad(nextval('public.booking_reference_seq')::text, 6, '0')),
  property_id       uuid not null references public.properties (id) on delete restrict,
  customer_id       uuid references auth.users (id) on delete set null,
  site_visit_id     uuid references public.site_visits (id) on delete set null,
  source            text not null default 'website' check (source in ('website', 'admin')),
  name              text not null check (length(btrim(name)) between 2 and 80),
  phone             text not null check (phone ~ '^[6-9][0-9]{9}$'),
  email             text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  message           text check (length(message) <= 1000),
  status            public.booking_status not null default 'requested',
  agreed_price      numeric(14, 2) check (agreed_price > 0),
  booking_amount    numeric(14, 2) check (booking_amount > 0),
  amount_received   numeric(14, 2) check (amount_received > 0),
  received_on       date,
  payment_method    text check (payment_method in ('bank_transfer', 'upi', 'cheque', 'demand_draft', 'cash', 'loan', 'other')),
  payment_reference text check (length(payment_reference) <= 120),
  assigned_to       uuid references public.admin_users (user_id) on delete set null,
  approved_by       uuid references public.admin_users (user_id) on delete set null,
  approved_at       timestamptz,
  completed_at      timestamptz,
  cancelled_reason  text check (length(cancelled_reason) <= 1000),
  idempotency_key   uuid unique,
  created_by        uuid references public.admin_users (user_id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- One booking holds a property at a time. Two approvals racing for the same
-- property can't both succeed: the second hits this index.
create unique index bookings_one_holding_per_property on public.bookings (property_id)
  where status in ('approved', 'payment_pending', 'reserved');
create index bookings_status_idx on public.bookings (status, created_at desc);
create index bookings_property_idx on public.bookings (property_id, created_at desc);
create index bookings_customer_idx on public.bookings (customer_id, created_at desc) where customer_id is not null;

create trigger bookings_updated_at
  before update on public.bookings
  for each row execute function private.set_updated_at();

create table public.booking_notes (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings (id) on delete cascade,
  admin_id    uuid references public.admin_users (user_id) on delete set null,
  note        text check (length(btrim(note)) between 1 and 2000),
  status_from public.booking_status,
  status_to   public.booking_status,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  constraint note_or_change check (note is not null or status_to is not null)
);
create index booking_notes_booking_idx on public.booking_notes (booking_id, created_at);

alter table public.bookings enable row level security;
alter table public.booking_notes enable row level security;
revoke all on public.bookings, public.booking_notes from anon;
revoke insert, update, delete, truncate on public.bookings, public.booking_notes from authenticated;
grant update (assigned_to) on public.bookings to authenticated;

create policy "admins read bookings" on public.bookings
  for select to authenticated using ((select public.is_admin()));
create policy "admins reassign bookings" on public.bookings
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admins read booking notes" on public.booking_notes
  for select to authenticated using ((select public.is_admin()));

alter publication supabase_realtime add table public.bookings;

-- ---------------------------------------------------------------------------
-- Guard: while a booking holds a property, only the booking's own steps may
-- change its availability, and it can't be archived.
-- ---------------------------------------------------------------------------
create function private.property_booking_guard()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('bk.booking_step', true), '') = 'on' then
    return new;
  end if;
  if (new.availability <> old.availability
      or (new.publish_state = 'archived' and old.publish_state <> 'archived'))
     and exists (select 1 from public.bookings b
                 where b.property_id = new.id and b.status in ('approved', 'payment_pending', 'reserved')) then
    raise exception 'A booking holds this property. Change it from the booking (complete or cancel it).'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger properties_booking_guard
  before update on public.properties
  for each row execute function private.property_booking_guard();

-- Called only from the booking functions below.
create function private.set_property_availability(p_property_id uuid, p_availability public.availability)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('bk.booking_step', 'on', true);
  update public.properties set availability = p_availability where id = p_property_id;
  perform set_config('bk.booking_step', '', true);
end;
$$;
revoke execute on function private.set_property_availability(uuid, public.availability) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Customer: request a booking (signed in, name and mobile in their profile)
-- ---------------------------------------------------------------------------
create function public.request_booking(
  p_property_id uuid,
  p_message text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.customer_profiles;
  v_email text;
  v_existing public.bookings;
  v_id uuid;
  v_reference text;
begin
  if v_uid is null then
    raise exception 'sign_in_required' using errcode = '42501';
  end if;
  if p_idempotency_key is not null then
    select * into v_existing from public.bookings b
    where b.idempotency_key = p_idempotency_key and b.customer_id = v_uid;
    if found then
      return jsonb_build_object('reference', v_existing.reference, 'duplicate', true);
    end if;
  end if;
  select * into v_profile from public.customer_profiles c where c.user_id = v_uid;
  if v_profile.full_name is null or v_profile.phone is null then
    raise exception 'profile_incomplete' using errcode = '22023';
  end if;
  select u.email into v_email from auth.users u where u.id = v_uid and u.email_confirmed_at is not null;

  if not exists (select 1 from public.properties p
                 where p.id = p_property_id and p.publish_state = 'published' and p.availability = 'available') then
    raise exception 'property_unavailable' using errcode = 'P0002';
  end if;

  select * into v_existing from public.bookings b
  where b.customer_id = v_uid and b.property_id = p_property_id and b.status not in ('completed', 'cancelled')
  limit 1;
  if found then
    return jsonb_build_object('reference', v_existing.reference, 'duplicate', true, 'already_requested', true);
  end if;

  if (select count(*) from public.bookings b
      where b.customer_id = v_uid and b.created_at > now() - interval '1 day') >= 3 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.bookings (property_id, customer_id, source, name, phone, email, message, idempotency_key)
  values (p_property_id, v_uid, 'website', v_profile.full_name, v_profile.phone, lower(v_email),
          nullif(btrim(p_message), ''), p_idempotency_key)
  returning id, reference into v_id, v_reference;
  return jsonb_build_object('reference', v_reference, 'duplicate', false);
end;
$$;

-- Customer: withdraw their own request before it is approved.
create function public.cancel_my_booking(p_reference text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v public.bookings;
begin
  select * into v from public.bookings b
  where b.reference = p_reference and b.customer_id = (select auth.uid()) for update;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
  if v.status not in ('requested', 'pending_approval') then
    raise exception 'Please call us to cancel: this booking is already approved.' using errcode = '22023';
  end if;
  update public.bookings set status = 'cancelled', cancelled_reason = 'Withdrawn by the customer'
  where id = v.id;
  insert into public.booking_notes (booking_id, note, status_from, status_to)
  values (v.id, 'Withdrawn by the customer on the website', v.status, 'cancelled');
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: start a booking for a customer (e.g. after a site visit)
-- ---------------------------------------------------------------------------
create function public.create_booking(
  p_property_id uuid,
  p_name text,
  p_phone text,
  p_email text default null,
  p_site_visit_id uuid default null,
  p_agreed_price numeric default null,
  p_note text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_customer uuid;
  v_id uuid;
begin
  perform private.require_admin();
  if length(v_phone) = 12 and left(v_phone, 2) = '91' then
    v_phone := substr(v_phone, 3);
  end if;
  if v_phone !~ '^[6-9][0-9]{9}$' then
    raise exception 'Enter a 10-digit Indian mobile number.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.properties p
                 where p.id = p_property_id and p.publish_state <> 'archived' and p.availability = 'available') then
    raise exception 'This property is not available for booking (reserved, sold or archived).' using errcode = '22023';
  end if;
  if p_site_visit_id is not null then
    select s.customer_id into v_customer from public.site_visits s where s.id = p_site_visit_id;
  end if;
  insert into public.bookings (property_id, customer_id, site_visit_id, source, name, phone, email,
                               agreed_price, created_by, assigned_to)
  values (p_property_id, v_customer, p_site_visit_id, 'admin', btrim(p_name), v_phone,
          nullif(lower(btrim(p_email)), ''), p_agreed_price, (select auth.uid()), (select auth.uid()))
  returning id into v_id;
  insert into public.booking_notes (booking_id, admin_id, note)
  values (v_id, (select auth.uid()), coalesce(nullif(btrim(p_note), ''), 'Booking started by the team'));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: move a booking one step. Property status changes in the same
-- transaction; the property row is locked so two approvals queue up.
-- ---------------------------------------------------------------------------
create function public.update_booking(
  p_booking_id uuid,
  p_action text,
  p_note text default null,
  p_amount numeric default null,
  p_received_on date default null,
  p_payment_method text default null,
  p_payment_reference text default null,
  p_agreed_price numeric default null
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v public.bookings;
  v_property public.properties;
  v_to public.booking_status;
  v_details jsonb := '{}'::jsonb;
begin
  perform private.require_admin();
  select * into v from public.bookings b where b.id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
  -- Lock the property: a second approval for it waits here, then sees Reserved.
  select * into v_property from public.properties p where p.id = v.property_id for update;

  case p_action
    when 'send_for_approval' then
      if v.status <> 'requested' then
        raise exception 'Only new requests can be sent for approval.' using errcode = '22023';
      end if;
      v_to := 'pending_approval';
    when 'approve' then
      if not public.is_super_admin() then
        raise exception 'Only a super admin can approve a booking.' using errcode = '42501';
      end if;
      if v.status not in ('requested', 'pending_approval') then
        raise exception 'This booking is not waiting for approval.' using errcode = '22023';
      end if;
      if v_property.availability <> 'available' or v_property.publish_state = 'archived' then
        raise exception 'The property is no longer available (another booking holds it, or it is sold). Cancel this request instead.'
          using errcode = '22023';
      end if;
      v_to := 'approved';
    when 'request_payment' then
      if v.status <> 'approved' then
        raise exception 'Ask for the booking amount after approval.' using errcode = '22023';
      end if;
      if p_amount is null or p_amount <= 0 then
        raise exception 'Enter the booking amount.' using errcode = '22023';
      end if;
      v_to := 'payment_pending';
      v_details := jsonb_build_object('booking_amount', p_amount);
    when 'record_payment' then
      if v.status <> 'payment_pending' then
        raise exception 'Record the payment once the booking amount was asked for.' using errcode = '22023';
      end if;
      if p_amount is null or p_amount <= 0 or p_received_on is null or p_payment_method is null then
        raise exception 'Enter the amount received, the date and how it was paid.' using errcode = '22023';
      end if;
      if p_received_on > (now() at time zone 'Asia/Kolkata')::date then
        raise exception 'The payment date can''t be in the future.' using errcode = '22023';
      end if;
      v_to := 'reserved';
      v_details := jsonb_strip_nulls(jsonb_build_object('amount_received', p_amount, 'received_on', p_received_on,
        'payment_method', p_payment_method, 'payment_reference', nullif(btrim(p_payment_reference), '')));
    when 'complete' then
      if not public.is_super_admin() then
        raise exception 'Only a super admin can complete a sale.' using errcode = '42501';
      end if;
      if v.status <> 'reserved' then
        raise exception 'Complete the sale after the booking amount is received.' using errcode = '22023';
      end if;
      v_to := 'completed';
    when 'cancel' then
      if v.status in ('completed', 'cancelled') then
        raise exception 'This booking is already finished.' using errcode = '22023';
      end if;
      if nullif(btrim(p_note), '') is null then
        raise exception 'Say why the booking is cancelled.' using errcode = '22023';
      end if;
      v_to := 'cancelled';
    else
      raise exception 'Unknown action.' using errcode = '22023';
  end case;

  update public.bookings set
    status = v_to,
    approved_by = case when v_to = 'approved' then (select auth.uid()) else approved_by end,
    approved_at = case when v_to = 'approved' then now() else approved_at end,
    completed_at = case when v_to = 'completed' then now() else completed_at end,
    booking_amount = case when v_to = 'payment_pending' then p_amount else booking_amount end,
    amount_received = case when v_to = 'reserved' then p_amount else amount_received end,
    received_on = case when v_to = 'reserved' then p_received_on else received_on end,
    payment_method = case when v_to = 'reserved' then p_payment_method else payment_method end,
    payment_reference = case when v_to = 'reserved' then nullif(btrim(p_payment_reference), '') else payment_reference end,
    agreed_price = coalesce(p_agreed_price, agreed_price),
    cancelled_reason = case when v_to = 'cancelled' then btrim(p_note) else cancelled_reason end
  where id = v.id;

  -- The property follows the booking.
  if v_to = 'approved' then
    perform private.set_property_availability(v.property_id, 'reserved');
  elsif v_to = 'completed' then
    perform private.set_property_availability(v.property_id, 'sold');
  elsif v_to = 'cancelled' and v.status in ('approved', 'payment_pending', 'reserved') then
    perform private.set_property_availability(v.property_id, 'available');
  end if;

  insert into public.booking_notes (booking_id, admin_id, note, status_from, status_to, details)
  values (v.id, (select auth.uid()), nullif(btrim(p_note), ''), v.status, v_to, v_details);
end;
$$;

create function public.add_booking_note(p_booking_id uuid, p_note text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform private.require_admin();
  if not exists (select 1 from public.bookings b where b.id = p_booking_id) then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;
  insert into public.booking_notes (booking_id, admin_id, note)
  values (p_booking_id, (select auth.uid()), btrim(p_note))
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.request_booking(uuid, text, uuid) from public, anon;
grant execute on function public.request_booking(uuid, text, uuid) to authenticated;
revoke execute on function public.cancel_my_booking(text) from public, anon;
grant execute on function public.cancel_my_booking(text) to authenticated;
revoke execute on function public.create_booking(uuid, text, text, text, uuid, numeric, text) from public, anon;
grant execute on function public.create_booking(uuid, text, text, text, uuid, numeric, text) to authenticated;
revoke execute on function public.update_booking(uuid, text, text, numeric, date, text, text, numeric) from public, anon;
grant execute on function public.update_booking(uuid, text, text, numeric, date, text, text, numeric) to authenticated;
revoke execute on function public.add_booking_note(uuid, text) from public, anon;
grant execute on function public.add_booking_note(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Activity log
-- ---------------------------------------------------------------------------
create function private.audit_booking()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_base jsonb := jsonb_build_object('reference', new.reference, 'property_id', new.property_id);
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('booking.requested', 'booking', new.id::text,
      v_base || jsonb_build_object('source', new.source));
  else
    if new.status <> old.status then
      perform private.write_audit('booking.status_changed', 'booking', new.id::text,
        v_base || jsonb_build_object('from', old.status, 'to', new.status));
    end if;
    if new.assigned_to is distinct from old.assigned_to then
      perform private.write_audit('booking.assigned', 'booking', new.id::text,
        v_base || jsonb_build_object('from', old.assigned_to, 'to', new.assigned_to));
    end if;
  end if;
  return null;
end;
$$;

create trigger bookings_audit
  after insert or update on public.bookings
  for each row execute function private.audit_booking();

-- ---------------------------------------------------------------------------
-- Emails (sent by the website): sales on a new website request; the customer
-- on each step. Same address and secret as the cache refresh.
-- ---------------------------------------------------------------------------
create function private.notify_booking_change()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
  v_event text;
begin
  if tg_op = 'INSERT' then
    v_event := 'requested';
  elsif new.status <> old.status then
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
    url := regexp_replace(v_url, '/api/revalidate$', '/api/bookings/notify'),
    body := jsonb_build_object('id', new.id, 'event', v_event),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-revalidate-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;
revoke execute on function private.notify_booking_change() from public, anon, authenticated;

create trigger bookings_notify
  after insert or update on public.bookings
  for each row execute function private.notify_booking_change();

-- ---------------------------------------------------------------------------
-- Customers' history now includes bookings
-- ---------------------------------------------------------------------------
create or replace function public.my_requests()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'enquiries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reference', e.reference, 'created_at', e.created_at, 'status', e.status,
        'message', e.message, 'property', private.customer_property(e.property_id))
        order by e.created_at desc)
      from public.enquiries e where e.customer_id = (select auth.uid())), '[]'::jsonb),
    'site_visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reference', s.reference, 'created_at', s.created_at, 'status', s.status,
        'visit_date', s.visit_date, 'slot', s.slot, 'visitors', s.visitors,
        'property', private.customer_property(s.property_id))
        order by s.visit_date desc, s.slot desc)
      from public.site_visits s where s.customer_id = (select auth.uid())), '[]'::jsonb),
    'bookings', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reference', b.reference, 'created_at', b.created_at, 'status', b.status,
        'agreed_price', b.agreed_price, 'booking_amount', b.booking_amount,
        'amount_received', b.amount_received,
        'property', private.customer_property(b.property_id))
        order by b.created_at desc)
      from public.bookings b where b.customer_id = (select auth.uid())), '[]'::jsonb)
  );
$$;

-- Signing in also links bookings the team started with the same email.
create or replace function public.link_my_guest_requests()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_email text;
  v_enquiries integer;
  v_visits integer;
  v_bookings integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select lower(u.email) into v_email from auth.users u
  where u.id = (select auth.uid()) and u.email_confirmed_at is not null;
  if v_email is null then
    return 0;
  end if;
  update public.enquiries set customer_id = (select auth.uid())
  where customer_id is null and lower(email) = v_email;
  get diagnostics v_enquiries = row_count;
  update public.site_visits set customer_id = (select auth.uid())
  where customer_id is null and lower(email) = v_email;
  get diagnostics v_visits = row_count;
  update public.bookings set customer_id = (select auth.uid())
  where customer_id is null and lower(email) = v_email;
  get diagnostics v_bookings = row_count;
  return v_enquiries + v_visits + v_bookings;
end;
$$;

-- ---------------------------------------------------------------------------
-- Dashboard
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
         and s.visit_date between v_today and v_today + 7),
    'bookings_to_review',
      (select count(*) from public.bookings b where b.status in ('requested', 'pending_approval')),
    'bookings_in_progress',
      (select count(*) from public.bookings b where b.status in ('approved', 'payment_pending', 'reserved'))
  );
end;
$$;
