-- Phase 11: optional customer accounts. Customers sign in with an email
-- code, save properties and see their own enquiries and site visits.
-- Staff access is unchanged: it still comes only from admin_users.

-- ---------------------------------------------------------------------------
-- Profiles and saved properties: each customer sees and changes only their own
-- ---------------------------------------------------------------------------
create table public.customer_profiles (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  full_name  text check (length(btrim(full_name)) between 2 and 80),
  phone      text check (phone ~ '^[6-9][0-9]{9}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger customer_profiles_updated_at
  before update on public.customer_profiles
  for each row execute function private.set_updated_at();

create table public.saved_properties (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, property_id)
);
create index saved_properties_property_idx on public.saved_properties (property_id);

alter table public.customer_profiles enable row level security;
alter table public.saved_properties enable row level security;
revoke all on public.customer_profiles, public.saved_properties from anon;
revoke all on public.customer_profiles, public.saved_properties from authenticated;
grant select, insert on public.customer_profiles to authenticated;
grant update (full_name, phone) on public.customer_profiles to authenticated;
grant select, insert, delete on public.saved_properties to authenticated;

create policy "customers read own profile" on public.customer_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "customers add own profile" on public.customer_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "customers update own profile" on public.customer_profiles
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "admins read customer profiles" on public.customer_profiles
  for select to authenticated using ((select public.is_admin()));

create policy "customers read own saved properties" on public.saved_properties
  for select to authenticated using (user_id = (select auth.uid()));
-- Only published (visible) properties can be saved.
create policy "customers save visible properties" on public.saved_properties
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.property_is_public(property_id));
create policy "customers remove own saved properties" on public.saved_properties
  for delete to authenticated using (user_id = (select auth.uid()));
create policy "admins read saved properties" on public.saved_properties
  for select to authenticated using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Requests linked to an account
-- ---------------------------------------------------------------------------
alter table public.site_visits
  add column customer_id uuid references auth.users (id) on delete set null;
create index site_visits_customer_idx on public.site_visits (customer_id, created_at desc) where customer_id is not null;
create index enquiries_customer_idx on public.enquiries (customer_id, created_at desc) where customer_id is not null;
create index enquiries_email_idx on public.enquiries (lower(email)) where customer_id is null and email is not null;
create index site_visits_email_idx on public.site_visits (lower(email)) where customer_id is null and email is not null;

-- Website: booking now records the signed-in customer (null for guests).
drop function public.submit_site_visit(uuid, text, text, date, text, smallint, text, text, text, uuid);
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
  p_idempotency_key uuid default null,
  p_customer_id uuid default null
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
    property_id, name, phone, email, visitors, visit_date, slot, message, ip_hash, idempotency_key,
    customer_id
  ) values (
    p_property_id, btrim(p_name), v_phone, nullif(lower(btrim(p_email)), ''), coalesce(p_visitors, 1),
    p_visit_date, p_slot, nullif(btrim(p_message), ''), p_ip_hash, p_idempotency_key,
    p_customer_id
  )
  returning id, reference into v_id, v_reference;

  return jsonb_build_object('id', v_id, 'reference', v_reference, 'duplicate', false,
    'visit_date', p_visit_date, 'slot', p_slot);
end;
$$;
revoke execute on function public.submit_site_visit(uuid, text, text, date, text, smallint, text, text, text, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.submit_site_visit(uuid, text, text, date, text, smallint, text, text, text, uuid, uuid)
  to service_role;

-- Code and title always; the page address only while the property is public.
create function private.customer_property(p_property_id uuid)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('code', p.code, 'title', p.title,
           'slug', case when private.property_is_public(p.id) then p.slug end,
           'availability', p.availability)
  from public.properties p where p.id = p_property_id;
$$;
revoke execute on function private.customer_property(uuid) from public, anon, authenticated;

-- Customer: their own enquiries and site visits, with only the fields a
-- customer should see (no staff notes, assignments or internal ids).
create function public.my_requests()
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
      from public.site_visits s where s.customer_id = (select auth.uid())), '[]'::jsonb)
  );
$$;

-- Customer: after signing in, attach earlier guest enquiries and visits sent
-- with the same (verified) email. Returns how many were linked.
create function public.link_my_guest_requests()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_email text;
  v_enquiries integer;
  v_visits integer;
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
  return v_enquiries + v_visits;
end;
$$;

revoke execute on function public.my_requests() from public, anon;
grant execute on function public.my_requests() to authenticated;
revoke execute on function public.link_my_guest_requests() from public, anon;
grant execute on function public.link_my_guest_requests() to authenticated;
