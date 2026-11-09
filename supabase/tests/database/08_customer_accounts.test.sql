-- Phase 11: customer accounts. Customers see and change only their own data.
begin;
create extension if not exists pgtap with schema extensions;

select plan(27);

-- Customer A = the seed's signed-in non-admin (verified email).
-- Customer B = a new account whose email isn't verified yet.
insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000000b0',
        'authenticated', 'authenticated', 'bina@example.com', now(), now());

-- Guest requests sent earlier with A's email (before A had an account)
set local role service_role;
create temp table t (name text primary key, value text);
insert into t select 'enquiry', public.submit_enquiry('Vani', '9876500011', 'Is the road paved?',
  '10000000-0000-4000-a000-000000000002', 'Visitor@Avanilands.test', 'phone', 'property_page') ->> 'reference';
insert into t select 'visit', public.submit_site_visit('10000000-0000-4000-a000-000000000003', 'Vani', '9876500011',
  (select min(d)::date from generate_series((now() at time zone 'Asia/Kolkata')::date + 1,
     (now() at time zone 'Asia/Kolkata')::date + 10, interval '1 day') d where extract(isodow from d) < 7),
  '10:00', 1::smallint, 'visitor@avanilands.test') ->> 'reference';
reset role;
grant select on t to authenticated, anon;

-- ===========================================================================
-- Customer A
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}';

select lives_ok($$ insert into public.customer_profiles (full_name, phone) values ('Vani Visitor', '9876500011') $$,
  'a customer creates their profile');
select is((select full_name from public.customer_profiles), 'Vani Visitor', 'and reads it back');
select throws_ok($$ insert into public.customer_profiles (user_id, full_name)
                    values ('00000000-0000-4000-a000-0000000000b0', 'Fake') $$,
  '42501', null, 'cannot create a profile for someone else');
select lives_ok($$ update public.customer_profiles set phone = '9876500012' $$, 'can change own mobile');
select throws_ok($$ update public.customer_profiles set user_id = '00000000-0000-4000-a000-0000000000b0' $$,
  '42501', null, 'cannot move the profile to another account');
select throws_ok($$ select public.dashboard_summary() $$, null, null, 'a customer is not an admin');

select lives_ok($$ insert into public.saved_properties (property_id) values ('10000000-0000-4000-a000-000000000001') $$,
  'saves a published property');
select lives_ok($$ insert into public.saved_properties (property_id) values ('10000000-0000-4000-a000-000000000008') $$,
  'saves a sold (still visible) property');
select throws_ok($$ insert into public.saved_properties (property_id) values ('10000000-0000-4000-a000-000000000010') $$,
  '42501', null, 'cannot save a hidden property');
select throws_ok($$ insert into public.saved_properties (property_id) values ('10000000-0000-4000-a000-000000000011') $$,
  '42501', null, 'cannot save a draft');
select throws_ok($$ insert into public.saved_properties (user_id, property_id)
                    values ('00000000-0000-4000-a000-0000000000b0', '10000000-0000-4000-a000-000000000002') $$,
  '42501', null, 'cannot save into someone else''s list');
select is((select count(*)::int from public.saved_properties), 2, 'sees own saved properties');

select is(jsonb_array_length(public.my_requests() -> 'enquiries'), 0, 'guest enquiries are not shown before linking');
select is(public.link_my_guest_requests(), 2, 'signing in links the earlier enquiry and visit sent with this email');
select is(public.link_my_guest_requests(), 0, 'linking again changes nothing');
select is((public.my_requests() -> 'enquiries' -> 0 ->> 'reference'), (select value from t where name = 'enquiry'),
  'the enquiry is in their history');
select is((public.my_requests() -> 'site_visits' -> 0 ->> 'reference'), (select value from t where name = 'visit'),
  'the site visit is in their history');
select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.my_requests() -> 'enquiries' -> 0) k),
  '{created_at,message,property,reference,status}'::text[],
  'customers see only customer-friendly fields (no staff notes, assignments or ids)');
select is((select count(*)::int from public.enquiries), 0, 'customers still cannot read the enquiries table');
reset role;

-- ===========================================================================
-- Customer B (another customer, email not verified)
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-0000000000b0"}';
select is((select count(*)::int from public.customer_profiles), 0, 'another customer cannot see A''s profile');
select is((select count(*)::int from public.saved_properties), 0, '…or A''s saved properties');
select is(jsonb_array_length(public.my_requests() -> 'enquiries'), 0, '…or A''s enquiries');
delete from public.saved_properties;
select is(public.link_my_guest_requests(), 0, 'an unverified email links nothing');
reset role;
select is((select count(*)::int from public.saved_properties where user_id = '00000000-0000-4000-a000-000000000009'),
  2, '…and cannot remove A''s saved properties');

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select throws_ok($$ select public.my_requests() $$, '42501', null, 'visitors have no history to ask for');
reset role;

-- ===========================================================================
-- Deleting an account
-- ===========================================================================
delete from auth.users where id = '00000000-0000-4000-a000-000000000009';
select is((select count(*)::int from public.customer_profiles where user_id = '00000000-0000-4000-a000-000000000009')
        + (select count(*)::int from public.saved_properties where user_id = '00000000-0000-4000-a000-000000000009'),
  0, 'deleting an account removes the profile and saved properties');
select is((select count(*)::int from public.enquiries where reference = (select value from t where name = 'enquiry')
             and customer_id is null), 1,
  'the enquiry stays with the team, no longer linked to an account');

select * from finish();
rollback;
