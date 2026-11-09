-- Phase 1: property rules for admins and super admins.
begin;
create extension if not exists pgtap with schema extensions;

select plan(36);

-- ===========================================================================
-- Admin
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';

select is(public.is_admin(), true, 'admin is an admin');
select is(public.is_super_admin(), false, 'admin is not a super admin');

-- Create a draft
select lives_ok($$
  insert into public.properties (id, title, property_type_id, location_id, area_value, area_unit, price)
  values ('30000000-0000-4000-a000-000000000001', '25 Cent Test Plot Anandapuram',
          (select id from public.property_types where slug = 'residential-plot'),
          '20000000-0000-4000-a000-000000000001', 25, 'cent', 4000000)
$$, 'admin creates a draft');
select matches((select code from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  '^AL-[0-9]{4}$', 'property code is generated');
select is((select created_by from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  '00000000-0000-4000-a000-000000000002'::uuid, 'created_by is the admin');
select is((select area_sqft from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  10890.000::numeric, '25 cents = 10,890 sq ft');

select throws_ok($$
  insert into public.properties (title, property_type_id, location_id, publish_state)
  values ('Straight to published', 1, '20000000-0000-4000-a000-000000000001', 'published')
$$, '23514', 'New properties start as drafts. Add a cover image, then publish.', 'new properties must be drafts');

select throws_ok($$
  update public.properties set publish_state = 'published' where id = '30000000-0000-4000-a000-000000000001'
$$, '23514', 'Add a cover image before publishing.', 'cannot publish without a cover photo');

-- Photos
insert into public.property_images (id, property_id, path_thumb, path_medium, path_large) values
  ('40000000-0000-4000-a000-000000000001', '30000000-0000-4000-a000-000000000001', 't/1-t', 't/1-m', 't/1-l'),
  ('40000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000001', 't/2-t', 't/2-m', 't/2-l'),
  ('40000000-0000-4000-a000-000000000003', '30000000-0000-4000-a000-000000000001', 't/3-t', 't/3-m', 't/3-l');
select is((select is_cover from public.property_images where id = '40000000-0000-4000-a000-000000000001'),
  true, 'first photo becomes the cover');
select is((select array_agg(sort_order order by id) from public.property_images
           where property_id = '30000000-0000-4000-a000-000000000001'),
  array[1, 2, 3], 'photos are numbered in upload order');

select lives_ok($$ select public.set_cover_image('40000000-0000-4000-a000-000000000002') $$, 'change cover');
select is((select array_agg(id order by id) from public.property_images
           where property_id = '30000000-0000-4000-a000-000000000001' and is_cover),
  array['40000000-0000-4000-a000-000000000002'::uuid], 'exactly one cover after the change');

select lives_ok($$ select public.reorder_property_images('30000000-0000-4000-a000-000000000001', array[
  '40000000-0000-4000-a000-000000000003', '40000000-0000-4000-a000-000000000001',
  '40000000-0000-4000-a000-000000000002']::uuid[]) $$, 'reorder photos');
select is((select sort_order from public.property_images where id = '40000000-0000-4000-a000-000000000003'),
  1, 'new order saved');
select throws_ok($$ select public.reorder_property_images('30000000-0000-4000-a000-000000000001',
  array['40000000-0000-4000-a000-000000000003']::uuid[]) $$, '22023', null, 'reorder must list every photo');

-- Publish
select lives_ok($$
  update public.properties set publish_state = 'published' where id = '30000000-0000-4000-a000-000000000001'
$$, 'publish with a cover photo');
select is((select slug from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  '25-cent-test-plot-anandapuram-visakhapatnam', 'slug made from title and city');
select isnt((select published_at from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  null, 'published_at set');

-- Same title → unique slug
insert into public.properties (id, title, property_type_id, location_id, area_value, price)
values ('30000000-0000-4000-a000-000000000002', '25 Cent Test Plot Anandapuram', 1,
        '20000000-0000-4000-a000-000000000001', 100, 1000000);
update public.properties set publish_state = 'hidden' where id = '30000000-0000-4000-a000-000000000002';
select is((select slug from public.properties where id = '30000000-0000-4000-a000-000000000002'),
  '25-cent-test-plot-anandapuram-visakhapatnam-2', 'duplicate slug gets a number');

-- Slug change keeps the old URL working
update public.properties set slug = 'anandapuram-25-cent-plot' where id = '30000000-0000-4000-a000-000000000001';
select is(public.resolve_property_slug('25-cent-test-plot-anandapuram-visakhapatnam'),
  'anandapuram-25-cent-plot', 'old slug resolves to the new one');
select throws_ok($$
  update public.properties set slug = '25-cent-test-plot-anandapuram-visakhapatnam'
  where id = '30000000-0000-4000-a000-000000000002'
$$, '23505', null, 'another property cannot take an old slug');

-- Price and status changes are logged
update public.properties set price = 4200000 where id = '30000000-0000-4000-a000-000000000001';
select is((select (details ->> 'new_price')::numeric from public.audit_logs
           where action = 'property.price_changed' and entity_id = '30000000-0000-4000-a000-000000000001'),
  4200000::numeric, 'price change logged with the new price');

update public.properties set availability = 'reserved' where id = '30000000-0000-4000-a000-000000000001';
select isnt((select reserved_at from public.properties where id = '30000000-0000-4000-a000-000000000001'),
  null, 'reserved_at set');
update public.properties set availability = 'sold' where id = '30000000-0000-4000-a000-000000000001';
select is((select array_agg(action order by id) from public.audit_logs
           where entity_id = '30000000-0000-4000-a000-000000000001' and action like 'property.marked_%'),
  array['property.marked_reserved', 'property.marked_sold'], 'reserved and sold logged');
select throws_ok($$
  update public.properties set availability = 'available' where id = '30000000-0000-4000-a000-000000000001'
$$, '42501', 'Only a super admin can change a sold property back.', 'admin cannot undo a sale');
select throws_ok($$
  update public.properties set publish_state = 'draft' where id = '30000000-0000-4000-a000-000000000001'
$$, '23514', null, 'published property cannot go back to draft');

-- Photo rules on a published property
delete from public.property_images where id in ('40000000-0000-4000-a000-000000000001', '40000000-0000-4000-a000-000000000003');
select throws_ok($$
  delete from public.property_images where id = '40000000-0000-4000-a000-000000000002'
$$, '23514', null, 'cannot delete the only photo of a published property');

-- Deleting
select throws_ok($$ select public.delete_draft_property('30000000-0000-4000-a000-000000000001') $$,
  '23514', null, 'published property cannot be deleted');
select throws_ok($$ select public.delete_draft_property('10000000-0000-4000-a000-000000000001') $$,
  '23514', null, 'published seed property cannot be deleted either');
select is(public.delete_draft_property('10000000-0000-4000-a000-000000000011'),
  '{"media": [], "documents": []}'::jsonb, 'empty draft deleted');

delete from public.properties where id = '30000000-0000-4000-a000-000000000002';
select is((select count(*)::int from public.properties where id = '30000000-0000-4000-a000-000000000002'),
  1, 'no direct deletes, even for admins');

-- Audit log is read-only
select throws_ok($$ update public.audit_logs set action = 'x' $$, '42501', null, 'audit log cannot be edited');
select throws_ok($$ delete from public.audit_logs $$, '42501', null, 'audit log cannot be deleted');

-- Admins cannot manage admins
update public.admin_users set role = 'super_admin' where user_id = '00000000-0000-4000-a000-000000000002';
select is((select role::text from public.admin_users where user_id = '00000000-0000-4000-a000-000000000002'),
  'admin', 'admin cannot promote themself');

-- ===========================================================================
-- Super admin
-- ===========================================================================
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000001", "role": "authenticated"}';

select lives_ok($$
  update public.properties set availability = 'available' where id = '30000000-0000-4000-a000-000000000001'
$$, 'super admin can undo a sale');
select throws_ok($$
  update public.admin_users set is_active = false where user_id = '00000000-0000-4000-a000-000000000001'
$$, '42501', 'You cannot change your own role or deactivate yourself.', 'super admin cannot deactivate themself');

select * from finish();
rollback;
