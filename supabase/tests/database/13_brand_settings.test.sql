-- Brand and company details: editable by the Super Admin only, public through the view.
begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

-- Defaults are the final brand
select is((select tagline from public.site_settings where id = 1), 'Find Your Space. Build Your Future.', 'tagline default');
select is((select descriptor from public.site_settings where id = 1), 'Real Estate & Property Platform', 'descriptor default');
select is((select legal_name from public.site_settings where id = 1), 'Tirupa Technologies Pvt. Ltd.', 'legal name default');

-- A normal admin can't change them (the update touches no row)
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';
with u as (update public.site_settings set tagline = 'Admin edit' where id = 1 returning 1)
select is((select count(*) from u), 0::bigint, 'an admin cannot edit the tagline');

-- The Super Admin can
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000001", "role": "authenticated"}';
update public.site_settings
   set tagline = 'Find Your Space.', gst_number = '37ABCDE1234F1Z5', rera_number = 'P01100001234',
       registered_address = '1-2-3, Beach Road, Visakhapatnam'
 where id = 1;
select is((select gst_number from public.site_settings where id = 1), '37ABCDE1234F1Z5', 'the Super Admin can save details');

select throws_ok($$ update public.site_settings set gst_number = '37abcde1234f1z5' $$, '23514', null, 'GST number must be 15 capital letters or digits');
select throws_ok($$ update public.site_settings set tagline = '  ' $$, '23514', null, 'tagline cannot be blank');
select throws_ok($$ update public.site_settings set descriptor = repeat('x', 61) $$, '23514', null, 'descriptor length is limited');

-- Visitors see them through the public view, but still not the table
reset role;
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is((select tagline from public.public_site_settings), 'Find Your Space.', 'visitors read the tagline');
select is((select rera_number from public.public_site_settings), 'P01100001234', 'visitors read the RERA number');
select throws_ok($$ select gst_number from public.site_settings $$, '42501', null, 'visitors cannot read the settings table');

reset role;
select * from finish();
rollback;
