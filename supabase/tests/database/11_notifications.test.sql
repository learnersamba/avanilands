-- Phase 15: who gets notified, what they can see, saved-land emails.
begin;
create extension if not exists pgtap with schema extensions;

select plan(23);

create temp table t (name text primary key, value text);
grant all on t to authenticated, anon, service_role;
delete from public.notifications;

-- Customer A (seed visitor) saves AL-0002 and AL-0003; emails off for nothing yet.
insert into public.customer_profiles (user_id, full_name, phone) values
  ('00000000-0000-4000-a000-000000000009', 'Vani Visitor', '9876500011');
insert into public.saved_properties (user_id, property_id) values
  ('00000000-0000-4000-a000-000000000009', '10000000-0000-4000-a000-000000000002'),
  ('00000000-0000-4000-a000-000000000009', '10000000-0000-4000-a000-000000000003');

-- ===========================================================================
-- A website enquiry from the signed-in customer
-- ===========================================================================
set local role service_role;
select public.submit_enquiry('Vani', '9876500011', 'Hello', '10000000-0000-4000-a000-000000000002',
  'visitor@avanilands.test', 'phone', 'property_page', null, null, '00000000-0000-4000-a000-000000000009');
reset role;
select is((select count(*)::int from public.notifications where kind = 'enquiry'
             and user_id in (select user_id from public.admin_users)), 2, 'both admins hear about a new enquiry');
select is((select title from public.notifications where user_id = '00000000-0000-4000-a000-000000000009'),
  'We received your enquiry ' || (select reference from public.enquiries order by created_at desc limit 1),
  'the customer gets a "received" update');

-- An admin answers: the customer hears, the admin who did it doesn't get a copy
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000002"}';
select public.update_enquiry_status((select id from public.enquiries order by created_at desc limit 1), 'contacted', 'Called');
reset role;
select is((select count(*)::int from public.notifications where user_id = '00000000-0000-4000-a000-000000000009'
             and title like 'We''re in touch%'), 1, 'the customer is told the team got in touch');

-- ===========================================================================
-- Saved land changes
-- ===========================================================================
update public.properties set price = 4200000 where id = '10000000-0000-4000-a000-000000000002';
select is((select title || ' | ' || body from public.notifications
           where kind = 'saved_land' order by id desc limit 1),
  'Price lowered: AL-0002 | 25 Cent Residential Plot near NH-16: ₹45,00,000 → ₹42,00,000.',
  'a price drop on saved land is announced in rupees');
select is((select email_status from public.notifications where kind = 'saved_land' order by id desc limit 1),
  'pending', '…and queued for email');
select is((select link from public.notifications where kind = 'saved_land' order by id desc limit 1),
  '/land/25-cent-residential-plot-near-nh-16-visakhapatnam', '…with a link to the property');

update public.customer_profiles set email_updates = false where user_id = '00000000-0000-4000-a000-000000000009';
update public.properties set availability = 'reserved' where id = '10000000-0000-4000-a000-000000000003';
select is((select title || ' | ' || coalesce(email_status, 'no email') from public.notifications
           where kind = 'saved_land' order by id desc limit 1),
  'AL-0003 is now reserved | no email', 'with emails switched off: in-app only');
update public.properties set publish_state = 'hidden' where id = '10000000-0000-4000-a000-000000000003';
select is((select title || ' | ' || coalesce(link, 'no link') from public.notifications
           where kind = 'saved_land' order by id desc limit 1),
  'AL-0003 is no longer on the website | no link', 'taken off the website: no link to a missing page');
update public.properties set title = title || ' ' where id = '10000000-0000-4000-a000-000000000002';
select is((select count(*)::int from public.notifications where kind = 'saved_land'), 3,
  'other edits don''t notify anyone');

-- ===========================================================================
-- Payments and new customers notify the other admins
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000001"}';
insert into t select 'b', public.create_booking('10000000-0000-4000-a000-000000000004', 'Ravi Kumar', '9123456789')::text;
select public.update_booking((select value::uuid from t where name = 'b'), 'approve');
select public.update_booking((select value::uuid from t where name = 'b'), 'request_payment', null, 100000);
select public.update_booking((select value::uuid from t where name = 'b'), 'record_payment', null, 100000,
  (now() at time zone 'Asia/Kolkata')::date, 'upi', 'UTR1');
reset role;
select is((select array_agg(user_id::text) from public.notifications where kind = 'payment'),
  '{00000000-0000-4000-a000-000000000002}'::text[], 'a payment notifies the other admin, not the one who recorded it');
select is((select body from public.notifications where kind = 'payment'), '₹1,00,000 · Ravi Kumar · AL-0004',
  'with the amount');
select is((select count(*)::int from public.notifications where kind = 'booking'
             and user_id in (select user_id from public.admin_users)), 0,
  'bookings the team starts itself don''t alert the team');

-- The customer verifies their own email (nobody else is signed in).
set local request.jwt.claims to '{}';
insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000000c0',
        'authenticated', 'authenticated', 'newbuyer@example.com', now(), now());
update auth.users set email_confirmed_at = now() where id = '00000000-0000-4000-a000-0000000000c0';
select is((select count(*)::int from public.notifications where kind = 'customer' and body = 'newbuyer@example.com'), 2,
  'a newly verified customer notifies both admins');
update auth.users set email_confirmed_at = now() where id = '00000000-0000-4000-a000-000000000002';
select is((select count(*)::int from public.notifications where kind = 'customer'), 2, 'staff accounts don''t count as customers');

-- ===========================================================================
-- Everyone sees only their own and can only mark them read
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}';
select is((select count(*)::int from public.notifications where user_id <> '00000000-0000-4000-a000-000000000009'), 0,
  'a customer sees only their own notifications');
select ok((select count(*) from public.notifications) >= 5, '…and does see theirs');
select lives_ok($$ update public.notifications set read_at = now() where read_at is null $$, 'they can mark them read');
select throws_ok($$ update public.notifications set title = 'Hacked' $$, '42501', null, '…but not change them');
select throws_ok($$ insert into public.notifications (user_id, kind, title)
                    values ('00000000-0000-4000-a000-000000000001', 'enquiry', 'Fake') $$, '42501', null,
  '…or create them');
select throws_ok($$ select * from public.claim_notification_emails() $$, '42501', null, '…or take the email queue');
reset role;

-- ===========================================================================
-- Email queue and clean-up (website, secret key)
-- ===========================================================================
set local role service_role;
select is((select count(*)::int from public.claim_notification_emails()), 1, 'the website claims the one queued email');
select is((select count(*)::int from public.claim_notification_emails()), 0, '…only once');
reset role;
update public.notifications set created_at = now() - interval '91 days' where kind = 'enquiry';
set local role service_role;
select ok(public.cleanup_notifications() >= 3, 'notifications older than 90 days are cleaned up');
reset role;

select * from finish();
rollback;
