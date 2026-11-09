-- Phase 10: site visit booking rules, admin actions, reminders and emails.
begin;
create extension if not exists pgtap with schema extensions;

select plan(38);

-- Known settings for the test: every day bookable, three slots, no holidays.
update public.site_settings set visit_days = '{1,2,3,4,5,6,7}', visit_slots = '{10:00,12:00,15:00}',
  visit_closed_dates = '{}', visit_days_ahead = 30;

create temp table t (name text primary key, value text);
grant all on t to anon, authenticated, service_role;
insert into t values ('tomorrow', ((now() at time zone 'Asia/Kolkata')::date + 1)::text),
                     ('in3', ((now() at time zone 'Asia/Kolkata')::date + 3)::text),
                     ('today', ((now() at time zone 'Asia/Kolkata')::date)::text);

-- ===========================================================================
-- Website (service role) booking rules
-- ===========================================================================
set local role service_role;

create function pg_temp.book(p_property text, p_phone text, p_date date, p_slot text,
                             p_key uuid default gen_random_uuid(), p_ip text default null)
returns jsonb language sql as $$
  select public.submit_site_visit(p_property::uuid, 'Test Visitor', p_phone, p_date, p_slot,
                                  2::smallint, 'Visitor@Example.com', 'Hi', p_ip, p_key)
$$;

insert into t select 'key', gen_random_uuid()::text;
insert into t select 'first', pg_temp.book('10000000-0000-4000-a000-000000000002', '+91 90000 11111',
  (select value::date from t where name = 'in3'), '12:00', (select value::uuid from t where name = 'key'))::text;

select matches((select value::jsonb ->> 'reference' from t where name = 'first'), '^SV-\d{6}$',
  'a valid request gets an SV- reference');
select is((select phone || '|' || email || '|' || visitors || '|' || status from public.site_visits
           where reference = (select value::jsonb ->> 'reference' from t where name = 'first')),
  '9000011111|visitor@example.com|2|requested', 'phone and email are cleaned; status is requested');
select is(pg_temp.book('10000000-0000-4000-a000-000000000002', '9000011111',
            (select value::date from t where name = 'in3'), '12:00', (select value::uuid from t where name = 'key')) ->> 'duplicate',
  'true', 'sending the same form twice gives the same visit');
select is(pg_temp.book('10000000-0000-4000-a000-000000000002', '9000011111',
            (select value::date from t where name = 'tomorrow'), '10:00') ->> 'already_booked',
  'true', 'asking again for the same property returns the open request');
select is((select count(*)::int from public.site_visits where phone = '9000011111'), 1, '…without a second row');

select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (select value::date from t where name = 'today'), '10:00') $$,
  '22023', 'invalid_date', 'today cannot be booked (from tomorrow only)');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (now() at time zone 'Asia/Kolkata')::date - 1, '10:00') $$,
  '22023', 'invalid_date', 'past dates are refused');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (now() at time zone 'Asia/Kolkata')::date + 31, '10:00') $$,
  '22023', 'invalid_date', 'more than 30 days ahead is refused');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (select value::date from t where name = 'tomorrow'), '11:00') $$,
  '22023', 'invalid_slot', 'unknown time slots are refused');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000008', '9000022222',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  'P0002', 'property_unavailable', 'sold land cannot be visited');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000010', '9000022222',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  'P0002', 'property_unavailable', 'hidden land cannot be visited');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '12345',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  '22023', 'invalid_phone', 'bad phone numbers are refused');

reset role;
update public.site_settings set visit_days = array(
  select d::smallint from generate_series(1, 7) d
  where d <> extract(isodow from (select value::date from t where name = 'tomorrow')));
set local role service_role;
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  '22023', 'closed_day', 'days without visits are refused');
reset role;
update public.site_settings set visit_days = '{1,2,3,4,5,6,7}',
  visit_closed_dates = array[(select value::date from t where name = 'tomorrow')];
set local role service_role;
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000002', '9000022222',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  '22023', 'closed_day', 'holidays are refused');
reset role;
update public.site_settings set visit_closed_dates = '{}';
set local role service_role;

-- 3 an hour per phone (different properties)
select lives_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000001', '9000033333',
                   (select value::date from t where name = 'tomorrow'), '10:00') $$, 'rate: 1st');
select lives_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000003', '9000033333',
                   (select value::date from t where name = 'tomorrow'), '10:00') $$, 'rate: 2nd');
select lives_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000004', '9000033333',
                   (select value::date from t where name = 'tomorrow'), '10:00') $$, 'rate: 3rd');
select throws_ok($$ select pg_temp.book('10000000-0000-4000-a000-000000000005', '9000033333',
                    (select value::date from t where name = 'tomorrow'), '10:00') $$,
  'P0001', 'rate_limited', 'the 4th request in an hour from one phone is refused');
reset role;

-- ===========================================================================
-- Visitors
-- ===========================================================================
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select throws_ok($$ select public.submit_site_visit('10000000-0000-4000-a000-000000000002', 'X', '9000044444',
                    current_date + 2, '10:00') $$, '42501', null,
  'visitors cannot book directly (only through the website server)');
select is((select visit_slots from public.public_site_settings), '{10:00,12:00,15:00}'::text[],
  'visitors can see the time slots');
reset role;

update public.site_settings set visit_closed_dates = array[current_date - 10, current_date + 10];
set local role anon;
select is((select cardinality(visit_closed_dates) from public.public_site_settings), 1,
  'past holidays are not shown');
reset role;

set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}';
select is((select count(*)::int from public.site_visits), 0, 'signed-in non-admins see no visits');
select throws_ok($$ select public.update_site_visit((select id from public.site_visits limit 1), 'cancel') $$,
  null, null, 'non-admins cannot change a visit');
reset role;

-- ===========================================================================
-- Admin actions
-- ===========================================================================
insert into t select 'visit', id::text from public.site_visits
  where reference = (select value::jsonb ->> 'reference' from t where name = 'first');

set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000002"}';

select lives_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'confirm',
                   'Called, they will come with family') $$, 'admin confirms a request');
select is((select status::text from public.site_visits where id = (select value::uuid from t where name = 'visit')),
  'confirmed', 'status is confirmed');
select throws_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'confirm') $$,
  '22023', null, 'cannot confirm twice');
select throws_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'complete') $$,
  '22023', 'This visit is still in the future.', 'cannot complete a future visit');
select throws_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'reschedule',
                    null, (now() at time zone 'Asia/Kolkata')::date - 1, '10:00') $$,
  '22023', null, 'cannot move a visit into the past');
select lives_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'reschedule',
                   'Customer asked for Sunday', (select value::date from t where name = 'in3') + 1, '16:30') $$,
  'admin moves the visit to a special time');
select is((select moved_from || ' → ' || moved_to from public.site_visit_notes
           where site_visit_id = (select value::uuid from t where name = 'visit') and moved_to is not null),
  (select value from t where name = 'in3') || ' 12:00 → ' || ((select value::date from t where name = 'in3') + 1)::text || ' 16:30',
  'the timeline records the old and new time');
select throws_ok($$ update public.site_visits set status = 'completed'
                    where id = (select value::uuid from t where name = 'visit') $$,
  '42501', null, 'status can only change through the actions');
select lives_ok($$ update public.site_visits set assigned_to = '00000000-0000-4000-a000-000000000002'
                   where id = (select value::uuid from t where name = 'visit') $$, 'admins can reassign');
select lives_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'cancel',
                   'Customer bought elsewhere') $$, 'admin cancels');
select throws_ok($$ select public.update_site_visit((select value::uuid from t where name = 'visit'), 'confirm') $$,
  '22023', null, 'a cancelled visit cannot be confirmed');
reset role;

select is((select array_agg(convert_from(body, 'utf8')::jsonb ->> 'event' order by id) from net.http_request_queue
           where url like '%/api/site-visits/notify'
             and convert_from(body, 'utf8')::jsonb ->> 'id' = (select value from t where name = 'visit')),
  '{confirmed,rescheduled,cancelled}'::text[], 'the website is told to email the customer on each change');
select is((select array_agg(action order by id) from public.audit_logs
           where entity_id = (select value from t where name = 'visit')),
  '{site_visit.requested,site_visit.status_changed,site_visit.rescheduled,site_visit.assigned,site_visit.status_changed}'::text[],
  'every step is in the activity log');

-- ===========================================================================
-- Reminders (website daily job)
-- ===========================================================================
set local role service_role;
select is((select count(*)::int from public.claim_site_visit_reminders()), 1,
  'the confirmed visit tomorrow (seed) is claimed for a reminder');
select is((select count(*)::int from public.claim_site_visit_reminders()), 0, '…only once');
reset role;

select * from finish();
rollback;
