-- Launch on the free plans (decision 132).
--
-- 1. Raw page views are kept about 6 months instead of 13 (decision 122):
--    the free plan's 500 MB database, and still enough for "last 90 days"
--    compared with the 90 days before.
-- 2. The website's daily job (site visit reminders, clean-up) is started by
--    the database's own scheduler (pg_cron) instead of Vercel Cron, so the
--    website can run on any host. It calls GET /api/site-visits/reminders
--    with "Authorization: Bearer <CRON_SECRET>". Needs two Vault secrets
--    (DEPLOY.md step 1.8): website_revalidate_url (already there) and
--    website_cron_secret (same value as the website's CRON_SECRET). Without
--    them the job does nothing (local development, tests).

create or replace function public.cleanup_analytics()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  delete from public.page_views where viewed_on < v_today - interval '6 months';
  get diagnostics v_count = row_count;
  delete from private.analytics_salts where day < v_today - 1;
  return v_count;
end;
$$;

create extension if not exists pg_cron with schema pg_catalog;

create function private.run_daily_website_job()
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'website_revalidate_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'website_cron_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  return net.http_get(
    url := regexp_replace(v_url, '/api/revalidate$', '/api/site-visits/reminders'),
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_secret),
    timeout_milliseconds := 30000
  );
end;
$$;

revoke execute on function private.run_daily_website_job() from public, anon, authenticated, service_role;

-- 09:00 India time, like the old Vercel Cron (03:30 UTC). Same name = updated, not doubled.
select cron.schedule('website-daily-job', '30 3 * * *', 'select private.run_daily_website_job()');
