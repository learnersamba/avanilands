-- Phase 16: recording page views without personal data, and the reports.
begin;
create extension if not exists pgtap with schema extensions;

select plan(27);

create temp table t (name text primary key, value text);
grant all on t to authenticated, anon, service_role;
delete from public.page_views;

-- Two visitors (as the web server hashes them).
insert into t values
  ('a', encode(sha256('visitor a'::bytea), 'hex')),
  ('b', encode(sha256('visitor b'::bytea), 'hex'));

-- ===========================================================================
-- Only the website (secret key) records
-- ===========================================================================
set local role anon;
select throws_ok($$ select public.track_page_view((select value from t where name = 'a'), '/') $$,
  '42501', null, 'visitors cannot record page views directly');
reset role;
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000001"}';
select throws_ok($$ select * from public.page_views $$, '42501', null, 'not even admins read raw page views');
reset role;

set local role service_role;
select ok(public.track_page_view((select value from t where name = 'a'),
  '/land/200-sq-yd-east-facing-plot-in-anandapuram-visakhapatnam', true, 'www.google.co.in', 'mobile'),
  'a property page is recorded');
select public.track_page_view((select value from t where name = 'a'), '/land', false, 'www.google.co.in', 'mobile',
  array['visakhapatnam', 'nowhere', 'anakapalli'], array['plots']);
select public.track_page_view((select value from t where name = 'a'), '/plots-for-sale/vizianagaram', false, null, 'mobile');
select public.track_page_view((select value from t where name = 'b'), '/land/240-sq-yd-plot-in-vizianagaram-hidden', true, null, 'desktop');
select public.track_page_view((select value from t where name = 'b'), '/land-for-sale/kakinada', false, null, 'desktop');
select is(public.track_page_view('not a hash', '/'), false, 'a malformed visitor is ignored');
select is(public.track_page_view((select value from t where name = 'b'), 'https://evil.example/'), false, '…and so is a malformed address');
reset role;

select is((select p.code from public.page_views v join public.properties p on p.id = v.property_id
           where v.path like '/land/200-%'), 'AL-0001', 'the property is found from the address');
select is((select referrer_host || ' ' || device || ' ' || entry from public.page_views where path like '/land/200-%'),
  'www.google.co.in mobile true', 'the first page keeps where the visit came from and the device');
select is((select referrer_host from public.page_views where path = '/land'), null,
  'later pages don''t repeat the source');
select is((select array_agg(l.slug order by l.slug) from public.page_views v
           cross join unnest(v.location_ids) as x(id) join public.locations l on l.id = x.id where v.path = '/land'),
  array['anakapalli', 'visakhapatnam'], 'searched places are recorded (unknown ones ignored)');
select is((select array_agg(l.slug) || array_agg(pt.seo_slug) from public.page_views v
           join public.locations l on l.id = v.location_ids[1]
           join public.property_types pt on pt.id = v.type_ids[1]
           where v.path = '/plots-for-sale/vizianagaram'), array['vizianagaram', 'plots'],
  'a landing page counts as a search for its place and land type');
select is((select property_id from public.page_views where path like '/land/240-%'), null,
  'a hidden property is not linked');

-- ===========================================================================
-- Nothing personal: visitors are re-hashed with a daily salt
-- ===========================================================================
select is((select count(distinct visitor)::int from public.page_views), 2, 'pages of the same visitor are linked within the day');
select ok(not exists (select 1 from public.page_views v join t on t.value = v.visitor),
  'the stored visitor is not what the website sent');
insert into private.analytics_salts values ((now() at time zone 'Asia/Kolkata')::date - 5, 'old');
update private.analytics_salts set salt = 'next day' where day = (now() at time zone 'Asia/Kolkata')::date;
set local role service_role;
select public.track_page_view((select value from t where name = 'a'), '/about');
reset role;
select is((select count(distinct visitor)::int from public.page_views), 3,
  'with a new salt the same person can''t be linked to earlier visits');
select is((select count(*)::int from private.analytics_salts), 1, 'old salts are deleted');

-- A runaway script stops counting at 1,000 pages a day.
insert into public.page_views (path, visitor)
select '/', (select visitor from public.page_views where path = '/about') from generate_series(1, 999);
set local role service_role;
select is(public.track_page_view((select value from t where name = 'a'), '/faq'), false,
  'more than 1,000 pages a day from one visitor are ignored');
reset role;
delete from public.page_views where path in ('/', '/about');

-- ===========================================================================
-- The report (admins)
-- ===========================================================================
-- A sale today.
update public.bookings set status = 'completed', completed_at = now(), agreed_price = 5400000
where property_id = '10000000-0000-4000-a000-000000000007';

set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000009"}';
select throws_ok($$ select public.analytics_report(current_date - 6, current_date) $$, '42501', null,
  'customers cannot see the reports');
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000002"}';
insert into t select 'r', public.analytics_report((now() at time zone 'Asia/Kolkata')::date - 6,
                                                  (now() at time zone 'Asia/Kolkata')::date)::text;
select throws_ok($$ select public.analytics_report(current_date, current_date - 1) $$, '22023', null,
  'a range must run forwards');
select throws_ok($$ select public.analytics_report(current_date - 400, current_date) $$, '22023', null,
  '…and cover at most a year');
reset role;

select is((select value::jsonb -> 'totals' ->> 'visitors' from t where name = 'r'), '2', 'visitors');
select is((select (value::jsonb -> 'totals') - 'visitors' - 'enquiries' - 'site_visits' - 'saves' - 'bookings'
           - 'whatsapp_taps' - 'call_taps' from t where name = 'r'),
  '{"sales": 1, "searches": 3, "page_views": 5, "sales_value": 5400000, "property_views": 1, "property_viewers": 1}'::jsonb,
  'page views, searches and sales add up');
select is((select (p ->> 'views') || '/' || (p ->> 'viewers') from t, jsonb_array_elements(value::jsonb -> 'properties') p
           where name = 'r' and p ->> 'code' = 'AL-0001'), '1/1', 'per property: views and viewers');
select is((select p ->> 'sales' from t, jsonb_array_elements(value::jsonb -> 'properties') p
           where name = 'r' and p ->> 'code' = 'AL-0007'), '1', '…and sales');
select is((select value::jsonb -> 'sources' from t where name = 'r'),
  '[{"source": "Direct / unknown", "visits": 1}, {"source": "Search engines", "visits": 1}]'::jsonb,
  'sources come from the first page of each visit');
select is((select jsonb_array_length(value::jsonb -> 'daily') from t where name = 'r'), 7, 'one row per day');

set local role authenticated;
select is((public.dashboard_summary() ->> 'visitors_last_7_days')::int, 2, 'the dashboard shows the week''s visitors');
reset role;

-- ===========================================================================
-- Clean-up: raw page views go after 13 months
-- ===========================================================================
update public.page_views set viewed_on = viewed_on - interval '14 months' where path = '/land';
set local role service_role;
select is(public.cleanup_analytics(), 1, 'page views older than 13 months are deleted');
reset role;

select * from finish();
rollback;
