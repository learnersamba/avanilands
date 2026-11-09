-- Phase 1: what visitors (anon) and signed-in non-admins can and cannot do.
-- Run with: supabase test db   (needs the seed from supabase db reset)
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

-- ===========================================================================
-- Anonymous visitor
-- ===========================================================================
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select is((select count(*)::int from public.public_properties), 9,
  'anon sees the 9 published properties (not draft, hidden or archived)');
select is((select count(*)::int from public.public_properties where availability = 'sold'), 1,
  'sold properties stay visible');
select hasnt_column('public', 'public_properties', 'internal_notes', 'public view has no internal notes');
select hasnt_column('public', 'public_properties', 'created_by', 'public view has no admin ids');

select is(
  (select latitude from public.public_properties where id = '10000000-0000-4000-a000-000000000002'),
  17.89::numeric, 'approximate latitude when exact location is off');
select is(
  (select address from public.public_properties where id = '10000000-0000-4000-a000-000000000002'),
  null, 'address hidden when exact location is off');
select is(
  (select latitude from public.public_properties where id = '10000000-0000-4000-a000-000000000001'),
  17.871234::numeric, 'exact latitude when allowed');
select is(
  (select price from public.public_properties where id = '10000000-0000-4000-a000-000000000005'),
  null, 'no price for price-on-request');
select is(
  (select cover_thumb from public.public_properties where id = '10000000-0000-4000-a000-000000000001'),
  'seed/10000000-0000-4000-a000-000000000001/1-thumb.webp', 'cover photo is the first one');

select throws_ok($$ select count(*) from public.properties $$, '42501', null,
  'anon cannot read the properties table');
select throws_ok($$ select count(*) from public.enquiries $$, '42501', null, 'anon cannot read enquiries');
select throws_ok($$ select count(*) from public.audit_logs $$, '42501', null, 'anon cannot read the audit log');
select throws_ok($$ select count(*) from public.admin_users $$, '42501', null, 'anon cannot read admins');
select throws_ok($$ select count(*) from public.property_documents $$, '42501', null,
  'anon cannot read document storage paths');
select throws_ok($$ select count(*) from public.site_settings $$, '42501', null,
  'anon cannot read private settings');

select is((select count(*)::int from public.public_property_documents), 1,
  'only public documents of published properties are listed');
select is((select count(*)::int from public.property_images
           where property_id in ('10000000-0000-4000-a000-000000000010', '10000000-0000-4000-a000-000000000012')),
  0, 'photos of hidden and archived properties are not public');
select is((select count(*)::int from public.property_images), 27, 'photos of published properties are public');
select is((select count(*)::int from public.locations), 4, 'inactive locations are hidden');
select is((select count(*)::int from public.property_types), 6, 'property types are public');
select is((select company_name from public.public_site_settings), 'Avanilands', 'public settings readable');

select is(public.resolve_property_slug('200-sq-yd-east-facing-plot-in-anandapuram-visakhapatnam'),
  '200-sq-yd-east-facing-plot-in-anandapuram-visakhapatnam', 'slug resolves');
select is(public.resolve_property_slug('240-sq-yd-plot-in-vizianagaram-hidden'), null,
  'hidden property slug does not resolve');

select throws_ok($$
  insert into public.locations (state, district, city, slug) values ('X', 'Yy', 'Zz', 'zz')
$$, '42501', null, 'anon cannot add locations');
select throws_ok($$ select public.submit_enquiry('Spam Bot', '9000000001') $$, '42501', null,
  'anon cannot call submit_enquiry directly');
select throws_ok($$ select public.dashboard_summary() $$, '42501', null, 'anon cannot read the dashboard');

-- ===========================================================================
-- Signed-in user who is not an admin
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000009", "role": "authenticated"}';

select is(public.is_admin(), false, 'visitor is not an admin');
select is((select count(*)::int from public.properties), 0, 'visitor sees no rows in properties');
select is((select count(*)::int from public.enquiries), 0, 'visitor sees no enquiries');
select is((select count(*)::int from public.audit_logs), 0, 'visitor sees no audit log');

select throws_ok($$
  insert into public.properties (title, property_type_id, location_id)
  values ('My own land for sale', 1, '20000000-0000-4000-a000-000000000001')
$$, '42501', null, 'visitor cannot list a property');

update public.properties set price = 1 where id = '10000000-0000-4000-a000-000000000001';
select is((select price from public.public_properties where id = '10000000-0000-4000-a000-000000000001'),
  3600000.00::numeric, 'visitor cannot change prices');

select throws_ok($$ select public.dashboard_summary() $$, '42501', 'Only admins can do this.',
  'visitor cannot read the dashboard');

select throws_ok($$
  insert into storage.objects (bucket_id, name, owner) values ('property-media', 'hack.webp', auth.uid())
$$, '42501', null, 'visitor cannot upload files');

select * from finish();
rollback;
