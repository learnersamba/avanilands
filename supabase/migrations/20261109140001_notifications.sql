-- Phase 15: notifications. One row per person per event, written by the
-- database (triggers) so no screen can forget one. Customers see theirs in
-- My account; admins in the admin panel's bell. Saved-land changes are also
-- emailed (queued here, sent by the website).

create table public.notifications (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         text not null check (kind in ('enquiry', 'site_visit', 'booking', 'saved_land', 'customer', 'payment')),
  title        text not null check (length(title) <= 200),
  body         text check (length(body) <= 500),
  -- Customers: a website path (/account, /land/…); admins: an admin panel path.
  link         text check (link ~ '^/[a-z0-9]' and length(link) <= 300),
  email_status text check (email_status in ('pending', 'sending', 'sent', 'failed')),
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;
create index notifications_email_idx on public.notifications (id) where email_status = 'pending';

alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
create policy "people read their own notifications" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy "people mark their own notifications read" on public.notifications
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.notifications;

-- Customers can turn off saved-land emails (on by default).
alter table public.customer_profiles add column email_updates boolean not null default true;
grant update (email_updates) on public.customer_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- ₹45,00,000 (Indian grouping), for notification text.
create function private.inr(p_value numeric)
returns text
language plpgsql immutable set search_path = '' as $$
declare
  v_digits text := round(p_value)::bigint::text;
  v_last3 text;
  v_rest text;
  v_out text := '';
begin
  if p_value is null then
    return null;
  end if;
  if length(v_digits) <= 3 then
    return '₹' || v_digits;
  end if;
  v_last3 := right(v_digits, 3);
  v_rest := left(v_digits, length(v_digits) - 3);
  while length(v_rest) > 2 loop
    v_out := ',' || right(v_rest, 2) || v_out;
    v_rest := left(v_rest, length(v_rest) - 2);
  end loop;
  return '₹' || v_rest || v_out || ',' || v_last3;
end;
$$;

create function private.notify_user(
  p_user_id uuid, p_kind text, p_title text, p_body text, p_link text, p_email boolean default false
)
returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, kind, title, body, link, email_status)
  select p_user_id, p_kind, left(p_title, 200), left(p_body, 500), p_link,
         case when p_email then 'pending' end
  where p_user_id is not null;
$$;

-- Every active admin except the one who did it.
create function private.notify_admins(p_kind text, p_title text, p_body text, p_link text)
returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, kind, title, body, link)
  select a.user_id, p_kind, left(p_title, 200), left(p_body, 500), p_link
  from public.admin_users a
  where a.is_active and a.user_id is distinct from (select auth.uid());
$$;

create function private.property_code(p_property_id uuid)
returns text
language sql stable security definer set search_path = '' as $$
  select p.code from public.properties p where p.id = p_property_id;
$$;

revoke execute on function private.inr(numeric), private.notify_user(uuid, text, text, text, text, boolean),
  private.notify_admins(text, text, text, text), private.property_code(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Enquiries
-- ---------------------------------------------------------------------------
create function private.notifications_for_enquiry()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_about text := coalesce(private.property_code(new.property_id), 'general enquiry');
begin
  if tg_op = 'INSERT' then
    perform private.notify_admins('enquiry', 'New enquiry ' || new.reference,
      new.name || ' · ' || v_about, '/enquiries/' || new.id);
    perform private.notify_user(new.customer_id, 'enquiry', 'We received your enquiry ' || new.reference,
      'About ' || v_about || '. Our team will contact you soon.', '/account');
  elsif old.status = 'new' and new.status <> 'new' and new.customer_id is not null then
    perform private.notify_user(new.customer_id, 'enquiry', 'We''re in touch about ' || new.reference,
      'Our team has been in touch about ' || v_about || '.', '/account');
  end if;
  return null;
end;
$$;
create trigger enquiries_notifications
  after insert or update of status on public.enquiries
  for each row execute function private.notifications_for_enquiry();

-- ---------------------------------------------------------------------------
-- Site visits
-- ---------------------------------------------------------------------------
create function private.notifications_for_site_visit()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := private.property_code(new.property_id);
  v_when text := to_char(new.visit_date, 'Dy DD Mon') || ', ' || new.slot;
begin
  if tg_op = 'INSERT' then
    perform private.notify_admins('site_visit', 'Site visit request ' || new.reference,
      new.name || ' · ' || v_code || ' · ' || v_when, '/site-visits/' || new.id);
    perform private.notify_user(new.customer_id, 'site_visit', 'Site visit requested: ' || v_code,
      v_when || '. We''ll call you to confirm.', '/account');
  elsif new.customer_id is not null then
    if new.visit_date <> old.visit_date or new.slot <> old.slot then
      perform private.notify_user(new.customer_id, 'site_visit', 'Your site visit has a new time',
        v_code || ' · ' || v_when, '/account');
    elsif new.status <> old.status then
      perform private.notify_user(new.customer_id, 'site_visit',
        case new.status
          when 'confirmed' then 'Site visit confirmed: ' || v_code
          when 'cancelled' then 'Site visit cancelled: ' || v_code
          when 'completed' then 'Thanks for visiting ' || v_code
          else 'Site visit update: ' || v_code end,
        v_when, '/account');
    end if;
  end if;
  return null;
end;
$$;
create trigger site_visits_notifications
  after insert or update of status, visit_date, slot on public.site_visits
  for each row execute function private.notifications_for_site_visit();

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
create function private.notifications_for_booking()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := private.property_code(new.property_id);
begin
  if tg_op = 'INSERT' then
    if new.source = 'website' then
      perform private.notify_admins('booking', 'Booking request ' || new.reference,
        new.name || ' · ' || v_code, '/bookings/' || new.id);
    end if;
    perform private.notify_user(new.customer_id, 'booking',
      case when new.source = 'website' then 'Booking request received: ' || v_code
           else 'Booking started for ' || v_code end,
      'Reference ' || new.reference || '. Our team will call you.', '/account');
  elsif new.status <> old.status then
    if new.status = 'reserved' then
      perform private.notify_admins('payment', 'Payment recorded: ' || new.reference,
        coalesce(private.inr(new.amount_received), '') || ' · ' || new.name || ' · ' || v_code,
        '/bookings/' || new.id);
    end if;
    perform private.notify_user(new.customer_id, 'booking',
      case new.status
        when 'pending_approval' then 'Your booking is being approved'
        when 'approved' then 'Booking approved — ' || v_code || ' is reserved for you'
        when 'payment_pending' then 'Booking amount for ' || v_code || ': ' || coalesce(private.inr(new.booking_amount), '')
        when 'reserved' then 'Payment received — thank you'
        when 'completed' then 'Congratulations — the sale of ' || v_code || ' is complete'
        when 'cancelled' then 'Your booking for ' || v_code || ' was cancelled'
        else 'Booking update: ' || v_code end,
      'Reference ' || new.reference
        || case when new.status = 'payment_pending'
                then '. We''ll call you from our official number with how to pay. Never pay into a personal account.'
                else '.' end,
      '/account');
  end if;
  return null;
end;
$$;
create trigger bookings_notifications
  after insert or update of status on public.bookings
  for each row execute function private.notifications_for_booking();

-- ---------------------------------------------------------------------------
-- Saved land: tell everyone who saved it (in-app, and email if they want)
-- ---------------------------------------------------------------------------
create function private.notifications_for_saved_land()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_title text;
  v_body text;
  v_link text := case when new.publish_state = 'published' and new.slug is not null then '/land/' || new.slug end;
begin
  if old.publish_state = 'published' and new.publish_state <> 'published' then
    v_title := new.code || ' is no longer on the website';
    v_body := new.title || ' has been taken off the website.';
  elsif new.publish_state <> 'published' then
    return null;
  elsif new.availability <> old.availability then
    v_title := case new.availability
      when 'reserved' then new.code || ' is now reserved'
      when 'sold' then new.code || ' has been sold'
      else new.code || ' is available again' end;
    v_body := new.title || case new.availability
      when 'reserved' then ' was booked by another buyer. We''ll tell you if it becomes available again.'
      when 'sold' then ' has been sold. Have a look at similar land.'
      else ' can be booked again.' end;
  elsif new.price is distinct from old.price and new.price_type = 'total' and old.price_type = 'total' then
    v_title := 'Price ' || case when new.price < old.price then 'lowered' else 'changed' end || ': ' || new.code;
    v_body := new.title || ': ' || private.inr(old.price) || ' → ' || private.inr(new.price) || '.';
  else
    return null;
  end if;

  perform private.notify_user(s.user_id, 'saved_land', v_title, v_body, v_link,
                              coalesce(c.email_updates, true))
  from public.saved_properties s
  left join public.customer_profiles c on c.user_id = s.user_id
  where s.property_id = new.id;
  return null;
end;
$$;
create trigger properties_saved_land_notifications
  after update of availability, price, publish_state on public.properties
  for each row execute function private.notifications_for_saved_land();

-- ---------------------------------------------------------------------------
-- New customer accounts (email verified, not staff)
-- ---------------------------------------------------------------------------
create function private.notifications_for_new_customer()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.email_confirmed_at is null and new.email_confirmed_at is not null
     and not exists (select 1 from public.admin_users a where a.user_id = new.id) then
    perform private.notify_admins('customer', 'New customer account', new.email, null);
  end if;
  return null;
end;
$$;
create trigger on_auth_user_verified_notify_admins
  after update of email_confirmed_at on auth.users
  for each row execute function private.notifications_for_new_customer();

-- ---------------------------------------------------------------------------
-- Emails (saved land): the website claims and sends them
-- ---------------------------------------------------------------------------
create function private.notify_website_emails()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from new_rows where email_status = 'pending') then
    return null;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'website_revalidate_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'website_revalidate_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  perform net.http_post(
    url := regexp_replace(v_url, '/api/revalidate$', '/api/notifications/send'),
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-revalidate-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;
revoke execute on function private.notify_website_emails() from public, anon, authenticated;
create trigger notifications_send_emails
  after insert on public.notifications
  referencing new table as new_rows
  for each statement execute function private.notify_website_emails();

-- Website: take the queued emails (each only once) with the person's email.
create function public.claim_notification_emails(p_limit int default 50)
returns table (id bigint, email text, name text, title text, body text, link text)
language sql security definer set search_path = '' as $$
  with claimed as (
    update public.notifications n set email_status = 'sending'
    where n.id in (select q.id from public.notifications q where q.email_status = 'pending'
                   order by q.id limit p_limit for update skip locked)
    returning n.id, n.user_id, n.title, n.body, n.link
  )
  select c.id, u.email, coalesce(p.full_name, ''), c.title, c.body, c.link
  from claimed c
  join auth.users u on u.id = c.user_id
  left join public.customer_profiles p on p.user_id = c.user_id;
$$;

create function public.finish_notification_emails(p_sent bigint[], p_failed bigint[])
returns void
language sql security definer set search_path = '' as $$
  update public.notifications set email_status = 'sent' where id = any (p_sent);
  update public.notifications set email_status = 'failed' where id = any (p_failed);
$$;

-- Daily job: old notifications go after 90 days.
create function public.cleanup_notifications()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  delete from public.notifications where created_at < now() - interval '90 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.claim_notification_emails(int), public.finish_notification_emails(bigint[], bigint[]),
  public.cleanup_notifications() from public, anon, authenticated;
grant execute on function public.claim_notification_emails(int), public.finish_notification_emails(bigint[], bigint[]),
  public.cleanup_notifications() to service_role;
