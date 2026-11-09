-- Phase 13: booking steps, who may take them, the property following the
-- booking, the guard, and two approvals racing for one property.
begin;
create extension if not exists pgtap with schema extensions;

select plan(39);

create temp table t (name text primary key, value text);
grant all on t to authenticated, anon, service_role;

-- Customer A = seed visitor (…0009); B = another customer.
insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-0000000000b0',
        'authenticated', 'authenticated', 'bina@example.com', now(), now(), now());

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'authenticated', 'sub', p_id)::text, true);
$$;
grant execute on function pg_temp.as_user(text) to authenticated;

-- ===========================================================================
-- Customer requests
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000009');
select throws_ok($$ select public.request_booking('10000000-0000-4000-a000-000000000002') $$,
  '22023', 'profile_incomplete', 'a customer needs a name and mobile before booking');
insert into public.customer_profiles (full_name, phone) values ('Vani Visitor', '9876500011');
insert into t select 'a1', public.request_booking('10000000-0000-4000-a000-000000000002', 'Ready to book after the visit') ->> 'reference';
select matches((select value from t where name = 'a1'), '^BKG-\d{6}$', 'request gets a BKG- reference');
select is(public.request_booking('10000000-0000-4000-a000-000000000002') ->> 'already_requested', 'true',
  'asking again for the same property returns the open request');
select throws_ok($$ select public.request_booking('10000000-0000-4000-a000-000000000007') $$,
  'P0002', 'property_unavailable', 'reserved land cannot be booked');
select throws_ok($$ select public.request_booking('10000000-0000-4000-a000-000000000008') $$,
  'P0002', 'property_unavailable', 'sold land cannot be booked');
select throws_ok($$ select public.request_booking('10000000-0000-4000-a000-000000000010') $$,
  'P0002', 'property_unavailable', 'hidden land cannot be booked');
select is((public.my_requests() -> 'bookings' -> 0 ->> 'status'), 'requested', 'the customer sees their request');
select is((select count(*)::int from public.bookings), 0, 'customers can''t read the bookings table');
select throws_ok($$ select public.update_booking((select null::uuid), 'approve') $$, '42501', null,
  'customers can''t move bookings');
reset role;

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select throws_ok($$ select public.request_booking('10000000-0000-4000-a000-000000000002') $$, '42501', null,
  'visitors must sign in to book');
reset role;

insert into t select 'a1_id', id::text from public.bookings where reference = (select value from t where name = 'a1');

-- ===========================================================================
-- Admin steps
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000002'); -- admin (not super)
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'send_for_approval',
                   'Visited twice, ready') $$, 'an admin sends the request for approval');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'approve') $$,
  '42501', 'Only a super admin can approve a booking.', 'an admin cannot approve');
-- A second customer's booking for the same property, started by the team
insert into t select 'b1', public.create_booking('10000000-0000-4000-a000-000000000002', 'Bina Rao', '+91 90000 22222',
  'bina@example.com', null, 4400000, 'Also interested')::text;
reset role;

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000001'); -- super admin
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'approve',
                   'Approved at ₹45 L', p_agreed_price => 4500000) $$, 'a super admin approves');
reset role;
select is((select availability::text from public.properties where id = '10000000-0000-4000-a000-000000000002'),
  'reserved', 'approving reserves the property in the same step');

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000001');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'b1'), 'approve') $$,
  '22023', null, 'a second booking for a reserved property cannot be approved');
select throws_ok($$ select public.create_booking('10000000-0000-4000-a000-000000000002', 'X Y', '9000033333') $$,
  '22023', null, 'and no new booking can start for it');
select throws_ok($$ update public.properties set availability = 'available'
                    where id = '10000000-0000-4000-a000-000000000002' $$,
  '23514', null, 'nobody can mark it available by hand while the booking holds it');
select throws_ok($$ update public.properties set publish_state = 'archived'
                    where id = '10000000-0000-4000-a000-000000000002' $$,
  '23514', null, '…or archive it');
reset role;

-- Even bypassing the functions, the database won't let two bookings hold one property.
select throws_ok($$ update public.bookings set status = 'approved' where id = (select value::uuid from t where name = 'b1') $$,
  '23505', null, 'two bookings can never hold the same property (unique index)');

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000002'); -- admin
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'request_payment') $$,
  '22023', 'Enter the booking amount.', 'asking for payment needs an amount');
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'request_payment',
                   'Bank details shared by phone', 100000) $$, 'admin asks for ₹1,00,000');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'record_payment',
                    null, 100000, (now() at time zone 'Asia/Kolkata')::date + 1, 'bank_transfer') $$,
  '22023', null, 'a payment date in the future is refused');
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'record_payment',
                   'Received in company account', 100000, (now() at time zone 'Asia/Kolkata')::date, 'bank_transfer', 'UTR123456') $$,
  'admin records the payment');
select is((select status || '|' || amount_received || '|' || payment_reference from public.bookings
           where id = (select value::uuid from t where name = 'a1_id')),
  'reserved|100000.00|UTR123456', 'booking is Reserved with the payment recorded');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'complete') $$,
  '42501', null, 'an admin cannot complete a sale');
reset role;

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000001');
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'a1_id'), 'complete',
                   'Sale deed registered') $$, 'a super admin completes the sale');
reset role;
select is((select availability::text from public.properties where id = '10000000-0000-4000-a000-000000000002'),
  'sold', 'completing marks the property sold');

-- ===========================================================================
-- Cancelling a held booking frees the property
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000001');
insert into t select 'c1', public.create_booking('10000000-0000-4000-a000-000000000004', 'Ravi Kumar', '9123456789')::text;
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'c1'), 'approve') $$,
  'super admin approves straight from a request');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'c1'), 'cancel') $$,
  '22023', 'Say why the booking is cancelled.', 'cancelling needs a reason');
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'c1'), 'cancel',
                   'Loan not approved') $$, 'cancelled with a reason');
reset role;
select is((select availability::text from public.properties where id = '10000000-0000-4000-a000-000000000004'),
  'available', 'the property is available again');

-- Two approvals for one property: the first wins, the second is refused
set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000001');
insert into t select 'r1', public.create_booking('10000000-0000-4000-a000-000000000005', 'First Buyer', '9000044441')::text;
insert into t select 'r2', public.create_booking('10000000-0000-4000-a000-000000000005', 'Second Buyer', '9000044442')::text;
select lives_ok($$ select public.update_booking((select value::uuid from t where name = 'r1'), 'approve') $$, 'first approval wins');
select throws_ok($$ select public.update_booking((select value::uuid from t where name = 'r2'), 'approve') $$,
  '22023', null, 'second approval for the same property is refused');
reset role;

-- ===========================================================================
-- Customers: own bookings only; withdrawing
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-0000000000b0');
select is(jsonb_array_length(public.my_requests() -> 'bookings'), 0, 'another customer sees none of A''s bookings');
select throws_ok($$ select public.cancel_my_booking((select value from t where name = 'a1')) $$,
  'P0002', null, '…and cannot cancel them');
reset role;

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-a000-000000000009');
insert into t select 'a2', public.request_booking('10000000-0000-4000-a000-000000000009') ->> 'reference';
select lives_ok($$ select public.cancel_my_booking((select value from t where name = 'a2')) $$,
  'a customer can withdraw a request before approval');
select throws_ok($$ select public.cancel_my_booking((select value from t where name = 'a1')) $$,
  '22023', null, '…but not a completed booking');
reset role;

-- ===========================================================================
-- Emails and the log
-- ===========================================================================
select is((select array_agg(convert_from(body, 'utf8')::jsonb ->> 'event' order by id) from net.http_request_queue
           where url like '%/api/bookings/notify'
             and convert_from(body, 'utf8')::jsonb ->> 'id' = (select value from t where name = 'a1_id')),
  '{requested,pending_approval,approved,payment_pending,reserved,completed}'::text[],
  'the website is told at every step (emails)');
select is((select count(*)::int from public.audit_logs where entity_id = (select value from t where name = 'a1_id')
             and action = 'booking.status_changed'), 5, 'every step is in the activity log');

select * from finish();
rollback;
