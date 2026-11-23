-- Decision 132: 6-month page views and the daily job from the database scheduler.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

-- Daily job ------------------------------------------------------------------
select is((select schedule from cron.job where jobname = 'website-daily-job'), '30 3 * * *',
  'the daily job runs at 09:00 India time');
select is((select count(*)::int from cron.job where jobname = 'website-daily-job'), 1,
  'scheduled once');

select is(private.run_daily_website_job(), null,
  'without the cron secret in Vault the job does nothing');

select vault.create_secret('test-cron-secret-0123456789abcdef', 'website_cron_secret');
select isnt(private.run_daily_website_job(), null, 'with it, the website is called');
select is(
  (select jsonb_build_array(method, url, headers ->> 'Authorization')
     from net.http_request_queue order by id desc limit 1),
  jsonb_build_array('GET', 'http://host.docker.internal:3100/api/site-visits/reminders',
                    'Bearer test-cron-secret-0123456789abcdef'),
  'GET /api/site-visits/reminders with the cron secret');

select ok(
  not has_function_privilege('anon', 'private.run_daily_website_job()', 'execute')
  and not has_function_privilege('authenticated', 'private.run_daily_website_job()', 'execute'),
  'visitors and customers cannot start the job');

-- Page views kept 6 months ----------------------------------------------------
insert into public.page_views (viewed_on, path, visitor) values
  ((now() at time zone 'Asia/Kolkata')::date - interval '7 months', '/old', repeat('a', 64)),
  ((now() at time zone 'Asia/Kolkata')::date - interval '5 months', '/recent', repeat('b', 64));
select is(public.cleanup_analytics() >= 1, true, 'the clean-up removes page views older than 6 months');
select is((select array_agg(path order by path) from public.page_views where path in ('/old', '/recent')),
  '{/recent}'::text[], 'and keeps the last 6 months');

select * from finish();
rollback;
