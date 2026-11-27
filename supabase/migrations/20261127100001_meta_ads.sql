-- Meta (Facebook / Instagram) advertising — decision 133.
--
-- 1. Settings → Advertising: one switch (Super Admin). Off by default: the
--    website stays cookie-free until it is on AND the website has a pixel id.
-- 2. lead_attribution: which campaign (utm tags) brought each enquiry / site
--    visit request, whether the visitor allowed advertising cookies, and only
--    then Meta's click / browser ids (needed to report sales results later).
--    One row per request, deleted with it. Ids are cleared after 180 days.
-- 3. meta_event_queue: sales results for Meta. When the team marks an
--    enquiry Interested or Converted, or a site visit Completed, and the
--    customer had allowed advertising cookies, an event is queued and the
--    website sends it (POST /api/meta/send, same Vault secrets as the cache
--    refresh). Each result is sent once; failures are retried by the daily
--    job (5 tries). No names, phones or emails are stored in the queue: the
--    website reads them when sending and hashes them (SHA-256).

-- ---------------------------------------------------------------------------
-- 1. Settings switch
-- ---------------------------------------------------------------------------
alter table public.site_settings
  add column meta_ads_enabled boolean not null default false;

-- Columns can only be added at the end of a view. Public: the website needs it
-- to decide whether to ask for consent at all.
create or replace view public.public_site_settings as
select company_name, phone, whatsapp, email, address, office_hours, social_links,
       seo_title, seo_description,
       visit_days, visit_slots,
       array(select d from unnest(visit_closed_dates) d
             where d > (now() at time zone 'Asia/Kolkata')::date order by d) as visit_closed_dates,
       visit_days_ahead,
       legal_name, tagline, descriptor, registered_address, gst_number, rera_number,
       meta_ads_enabled
from public.site_settings
where id = 1;

-- ---------------------------------------------------------------------------
-- 2. Where leads came from
-- ---------------------------------------------------------------------------
create table public.lead_attribution (
  id             bigint generated always as identity primary key,
  enquiry_id     uuid unique references public.enquiries (id) on delete cascade,
  site_visit_id  uuid unique references public.site_visits (id) on delete cascade,
  utm_source     text check (length(utm_source) <= 100),
  utm_medium     text check (length(utm_medium) <= 100),
  utm_campaign   text check (length(utm_campaign) <= 200),
  utm_content    text check (length(utm_content) <= 200),
  utm_term       text check (length(utm_term) <= 100),
  landing_path   text check (landing_path like '/%' and length(landing_path) <= 300),
  -- The visitor's answer to the advertising-cookie question when they sent the form.
  ad_consent     boolean not null default false,
  consent_at     timestamptz,
  -- Meta's ids, only with consent (checked here too).
  meta_fbc       text check (meta_fbc ~ '^fb\.[0-9]\.[0-9]+\.[A-Za-z0-9_-]{10,500}$'),
  meta_fbp       text check (meta_fbp ~ '^fb\.[0-9]\.[0-9]+\.[0-9]+$'),
  created_at     timestamptz not null default now(),
  constraint one_request check (num_nonnulls(enquiry_id, site_visit_id) = 1),
  constraint ids_need_consent check (ad_consent or (meta_fbc is null and meta_fbp is null))
);
create index lead_attribution_campaign_idx on public.lead_attribution (utm_campaign, created_at desc)
  where utm_campaign is not null;

alter table public.lead_attribution enable row level security;
revoke all on public.lead_attribution from anon;
-- Written only by the website server (secret key); admins read.
revoke insert, update, delete, truncate on public.lead_attribution from authenticated;
create policy "admins read lead attribution" on public.lead_attribution
  for select to authenticated using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- 3. Sales results for Meta
-- ---------------------------------------------------------------------------
create table public.meta_event_queue (
  id             bigint generated always as identity primary key,
  event_name     text not null check (event_name in ('QualifiedLead', 'ConvertedLead', 'SiteVisitCompleted')),
  -- One event per request and result, ever (Meta also de-duplicates by it).
  event_id       text not null unique check (length(event_id) <= 100),
  enquiry_id     uuid references public.enquiries (id) on delete cascade,
  site_visit_id  uuid references public.site_visits (id) on delete cascade,
  status         text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts       smallint not null default 0,
  last_error     text check (length(last_error) <= 300),
  claimed_at     timestamptz,
  sent_at        timestamptz,
  created_at     timestamptz not null default now(),
  constraint one_request check (num_nonnulls(enquiry_id, site_visit_id) = 1)
);
create index meta_event_queue_open_idx on public.meta_event_queue (status, id)
  where status in ('pending', 'sending', 'failed');

alter table public.meta_event_queue enable row level security;
-- Website server only (secret key); no policies, so nobody else reads or writes.
revoke all on public.meta_event_queue from anon, authenticated;

-- Queue an event when a status change is a sales result Meta should learn from.
create function private.queue_meta_event()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_kind text := case tg_table_name when 'enquiries' then 'enquiry' else 'site_visit' end;
  v_event text;
begin
  if new.status is not distinct from old.status then
    return null;
  end if;
  v_event := case v_kind || ':' || new.status::text
    when 'enquiry:interested' then 'QualifiedLead'
    when 'enquiry:converted' then 'ConvertedLead'
    when 'site_visit:completed' then 'SiteVisitCompleted'
  end;
  if v_event is null
     or not coalesce((select s.meta_ads_enabled from public.site_settings s where s.id = 1), false)
     or not exists (select 1 from public.lead_attribution a
                    where a.ad_consent
                      and (case v_kind when 'enquiry' then a.enquiry_id else a.site_visit_id end) = new.id) then
    return null;
  end if;
  insert into public.meta_event_queue (event_name, event_id, enquiry_id, site_visit_id)
  values (v_event,
          v_kind || '-' || new.id::text || '-' || new.status::text,
          case v_kind when 'enquiry' then new.id end,
          case v_kind when 'site_visit' then new.id end)
  on conflict (event_id) do nothing;
  return null;
end;
$$;
revoke execute on function private.queue_meta_event() from public, anon, authenticated;

create trigger enquiries_queue_meta_event
  after update of status on public.enquiries
  for each row execute function private.queue_meta_event();
create trigger site_visits_queue_meta_event
  after update of status on public.site_visits
  for each row execute function private.queue_meta_event();

-- Ask the website to send what was queued (after the transaction commits).
create function private.notify_meta_events()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from new_rows) then
    return null;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'website_revalidate_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'website_revalidate_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;
  perform net.http_post(
    url := regexp_replace(v_url, '/api/revalidate$', '/api/meta/send'),
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-revalidate-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;
revoke execute on function private.notify_meta_events() from public, anon, authenticated;
create trigger meta_event_queue_send
  after insert on public.meta_event_queue
  referencing new table as new_rows
  for each statement execute function private.notify_meta_events();

-- Website: take events to send (each only once; stuck or failed ones again,
-- at most 5 tries), with what Meta needs to match the person. Only while the
-- customer's consent is on record.
create function public.claim_meta_events(p_limit int default 200)
returns table (id bigint, event_name text, event_id text, created_at timestamptz,
               phone text, email text, fbc text, fbp text, property_code text)
language sql security definer set search_path = '' as $$
  with claimed as (
    update public.meta_event_queue q
    set status = 'sending', claimed_at = now(), attempts = q.attempts + 1
    where q.id in (
      select o.id from public.meta_event_queue o
      where (o.status = 'pending'
             or (o.status = 'failed' and o.attempts < 5)
             or (o.status = 'sending' and o.claimed_at < now() - interval '10 minutes' and o.attempts < 5))
        -- Meta accepts server events up to 7 days old.
        and o.created_at > now() - interval '7 days'
      order by o.id
      limit least(greatest(p_limit, 1), 1000)
      for update skip locked)
    returning q.id, q.event_name, q.event_id, q.created_at, q.enquiry_id, q.site_visit_id
  )
  select c.id, c.event_name, c.event_id, c.created_at,
         coalesce(e.phone, v.phone), coalesce(e.email, v.email),
         a.meta_fbc, a.meta_fbp, p.code
  from claimed c
  left join public.enquiries e on e.id = c.enquiry_id
  left join public.site_visits v on v.id = c.site_visit_id
  join public.lead_attribution a
    on a.ad_consent and (a.enquiry_id = c.enquiry_id or a.site_visit_id = c.site_visit_id)
  left join public.properties p on p.id = coalesce(e.property_id, v.property_id);
$$;

create function public.finish_meta_events(p_sent bigint[], p_failed bigint[], p_error text default null)
returns void
language sql security definer set search_path = '' as $$
  update public.meta_event_queue set status = 'sent', sent_at = now(), last_error = null
  where id = any (p_sent);
  update public.meta_event_queue set status = 'failed', last_error = left(p_error, 300)
  where id = any (p_failed);
$$;

-- Daily job: keep Meta's ids only as long as they are useful (Meta accepts
-- results up to 7 days after they happen; sales can take months, so 180 days),
-- and the queue 90 days. Campaign tags stay with the request.
create function public.cleanup_meta_data()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  update public.lead_attribution set meta_fbc = null, meta_fbp = null
  where created_at < now() - interval '180 days' and (meta_fbc is not null or meta_fbp is not null);
  get diagnostics v_count = row_count;
  delete from public.meta_event_queue where created_at < now() - interval '90 days';
  -- Never sent and too old for Meta: mark them so nobody wonders.
  update public.meta_event_queue set status = 'failed', last_error = coalesce(last_error, 'expired')
  where status in ('pending', 'sending') and created_at < now() - interval '7 days';
  return v_count;
end;
$$;

revoke execute on function public.claim_meta_events(int) from public, anon, authenticated;
revoke execute on function public.finish_meta_events(bigint[], bigint[], text) from public, anon, authenticated;
revoke execute on function public.cleanup_meta_data() from public, anon, authenticated;
grant execute on function public.claim_meta_events(int) to service_role;
grant execute on function public.finish_meta_events(bigint[], bigint[], text) to service_role;
grant execute on function public.cleanup_meta_data() to service_role;
