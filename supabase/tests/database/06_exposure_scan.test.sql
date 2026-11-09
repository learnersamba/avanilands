-- Phase 9 security review: scans EVERY public table, policy and function, so
-- anything added later without protection fails here (not just the cases we
-- thought of). Run with: supabase test db   (needs the seed)
begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

-- ===========================================================================
-- Catalog checks
-- ===========================================================================
select is(
  (select coalesce(array_agg(c.relname::text order by c.relname), '{}')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  '{}'::text[], 'every public table has row level security');

select is(
  (select coalesce(array_agg(format('%s.%s', tablename, policyname) order by 1), '{}')
     from pg_policies
    where schemaname in ('public', 'storage')
      and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
      and coalesce(qual, '') || coalesce(with_check, '')
          !~ '(is_(super_)?admin|user_id = \( SELECT auth\.uid\(\))'),
  '{}'::text[], 'every policy that allows writing requires an admin, or limits a customer to their own rows');

select is(
  (select coalesce(array_agg(format('%s:%s', c.relname, p.priv) order by 1), '{}')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
     cross join unnest(array['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) as p(priv)
    where n.nspname = 'public' and c.relkind in ('r', 'v')
      and has_table_privilege('anon', c.oid, p.priv)),
  '{}'::text[], 'visitors (anon) have no write privilege on any table or view');

select is(
  (select coalesce(array_agg(c.relname::text order by 1), '{}')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'TRUNCATE')),
  '{}'::text[], 'signed-in users cannot truncate any table (RLS does not cover TRUNCATE)');

select is(
  (select coalesce(array_agg(c.relname::text order by 1), '{}')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v'
      and has_table_privilege('authenticated', c.oid, 'INSERT')),
  '{}'::text[], 'public views cannot be written through');

select is(
  (select coalesce(array_agg(p.proname::text order by 1), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
      and p.proname not in ('area_to_sqft', 'health', 'is_admin', 'is_super_admin',
                            'property_route', 'resolve_property_slug', 'search_properties')),
  '{}'::text[], 'visitors can call only the public read functions');

select is(
  (select coalesce(array_agg(p.proname::text order by 1), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and has_function_privilege('authenticated', p.oid, 'execute')
      and not has_function_privilege('anon', p.oid, 'execute')
      and p.prosrc !~ 'require_admin'
      -- Customer functions: only ever about the signed-in customer.
      and not (p.proname in ('my_requests', 'link_my_guest_requests', 'request_booking', 'cancel_my_booking') and p.prosrc ~ 'auth\.uid\(\)')),
  '{}'::text[], 'every signed-in-only function checks for an admin (or is a customer''s own-data function)');

select is(
  (select coalesce(array_agg(p.proname::text order by 1), '{}')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
                      where cfg like 'search_path=%')),
  '{}'::text[], 'every security definer function pins its search_path');

select is(
  (select coalesce(array_agg(id order by 1), '{}')
     from storage.buckets where file_size_limit is null or allowed_mime_types is null),
  '{}'::text[], 'every storage bucket limits file size and type');

-- ===========================================================================
-- Behaviour: a signed-in non-admin tries everything on every table
-- ===========================================================================
create temp table scan_result (problem text);
grant insert on scan_result to authenticated, anon;

-- Another customer's data, which the signed-in non-admin below must not reach.
insert into public.customer_profiles (user_id, full_name, phone)
  values ('00000000-0000-4000-a000-000000000001', 'Someone Else', '9000099999');
insert into public.saved_properties (user_id, property_id)
  values ('00000000-0000-4000-a000-000000000001', '10000000-0000-4000-a000-000000000001');

do $$
declare
  t record;
  who text;
  n bigint;
  first_col text;
begin
  foreach who in array array['anon', 'authenticated'] loop
    execute format('set local role %I', who);
    perform set_config('request.jwt.claims',
      case who when 'anon' then '{"role":"anon"}'
      else '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}' end, true);

    for t in
      select c.relname, c.relkind,
             -- Customer tables: a customer may use their own rows, never others'.
             exists (select 1 from pg_attribute a where a.attrelid = c.oid
                       and a.attname = 'user_id' and not a.attisdropped) and c.relkind = 'r' as owned,
             -- Readable by everyone on purpose: lookups, public views and the
             -- photos/videos/places of published properties.
             exists (select 1 from pg_policies pp where pp.schemaname = 'public'
                       and pp.tablename = c.relname and pp.cmd = 'SELECT'
                       and 'public' = any (pp.roles)) or c.relkind = 'v' as public_read
        from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
       where ns.nspname = 'public' and c.relkind in ('r', 'v')
    loop
      -- Read
      begin
        execute format('select count(*) from public.%I %s', t.relname,
          case when t.owned then 'where user_id is distinct from auth.uid()' else '' end) into n;
        if n > 0 and not t.public_read then
          insert into scan_result values (format('%s reads %s rows of %s', who, n, t.relname));
        end if;
      exception when insufficient_privilege then null;
      end;

      if t.relkind = 'v' then continue; end if;

      -- Change every row (a no-op change), then delete every row
      select a.attname into first_col from pg_attribute a
       where a.attrelid = format('public.%I', t.relname)::regclass and a.attnum > 0
         and not a.attisdropped and a.attidentity = '' and a.attgenerated = ''
       order by a.attnum limit 1;
      begin
        execute format('update public.%I set %I = %I %s', t.relname, first_col, first_col,
          case when t.owned then 'where user_id is distinct from auth.uid()' else '' end);
        get diagnostics n = row_count;
        if n > 0 then
          insert into scan_result values (format('%s updated %s rows of %s', who, n, t.relname));
        end if;
      exception when others then null;
      end;
      begin
        execute format('delete from public.%I %s', t.relname,
          case when t.owned then 'where user_id is distinct from auth.uid()' else '' end);
        get diagnostics n = row_count;
        if n > 0 then
          insert into scan_result values (format('%s deleted %s rows of %s', who, n, t.relname));
        end if;
      exception when others then null;
      end;
      -- (A customer adding their own row is allowed; covered in 08_customer_accounts.)
      if t.owned and who = 'authenticated' then continue; end if;
      begin
        execute format('insert into public.%I default values', t.relname);
        insert into scan_result values (format('%s inserted into %s', who, t.relname));
      exception when insufficient_privilege or check_violation or raise_exception then null;
        -- (RLS refusals are insufficient_privilege; anything else is reported below)
      when others then
        if sqlstate not in ('23502', '23503', '23514', 'P0001') then
          insert into scan_result values (format('%s insert into %s gave %s', who, t.relname, sqlstate));
        end if;
      end;
    end loop;
    execute 'reset role';
  end loop;
end;
$$;

select is((select coalesce(array_agg(problem order by 1), '{}') from scan_result),
  '{}'::text[], 'visitors and signed-in non-admins cannot read private rows or change any row');

-- The not-null / foreign key errors above happen before RLS would refuse, so
-- confirm inserts with valid-looking data are refused too.
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}';
select throws_ok($$ insert into public.locations (city, district, state, slug)
                    values ('X', 'Y', 'Andhra Pradesh', 'x-y') $$,
  '42501', null, 'non-admin cannot add a location');
select throws_ok($$ insert into public.admin_users (user_id, full_name, email, role)
                    values ('00000000-0000-4000-a000-000000000009', 'Me', 'v@x.test', 'super_admin') $$,
  '42501', null, 'non-admin cannot make themselves an admin');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('property-media', 'x/evil.webp') $$,
  '42501', null, 'non-admin cannot upload photos');
select throws_ok($$ select public.dashboard_summary() $$, null, null,
  'non-admin cannot read the dashboard');
select throws_ok($$ select public.update_enquiry_status(
                      (select id from public.enquiries limit 1), 'closed', null) $$,
  null, null, 'non-admin cannot change an enquiry');
reset role;

select * from finish();
rollback;
