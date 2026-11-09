-- Phase 7: property page routing and cache-refresh triggers.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select is(public.property_route('200-sq-yd-east-facing-plot-in-anandapuram-visakhapatnam') ->> 'state', 'published',
  'published slug resolves');
select is(public.property_route('nope-not-a-property'), null, 'unknown slug → null (404)');
select is(public.property_route('240-sq-yd-plot-in-vizianagaram-hidden'), null, 'hidden property → null (404)');
select is(public.property_route('old-listing-150-sq-yd-plot-in-pendurthi-visakhapatnam') ->> 'state', 'archived',
  'archived property → archived (no longer available)');
select is(public.property_route('old-listing-150-sq-yd-plot-in-pendurthi-visakhapatnam') ->> 'city', 'Visakhapatnam',
  'archived route carries the city for "similar land"');

-- An old slug points at the current one.
reset role;
update public.properties set slug = 'anandapuram-200-sq-yd-east-facing'
where id = '10000000-0000-4000-a000-000000000001';
set local role anon;
select is(public.property_route('200-sq-yd-east-facing-plot-in-anandapuram-visakhapatnam') ->> 'slug',
  'anandapuram-200-sq-yd-east-facing', 'old slug → current slug (301)');

reset role;
select is((select count(*)::int from pg_trigger where tgname like '%_notify_website'), 14,
  'refresh triggers on the 14 tables the website shows (10 + 4 content tables, Phase 14)');
select ok(
  (select count(*) from net.http_request_queue) >= 1,
  'a change queues a refresh request to the website'
);

select * from finish();
rollback;
