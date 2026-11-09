-- Phase 16: website statistics and reports.
--
-- The website records each page shown (no cookies). The web server turns the
-- visitor's IP and browser into a salted hash (`p_client`); here it is hashed
-- again with a random salt that changes every day and is deleted after two
-- days, so a visitor can't be followed across days or traced back to an IP.
-- Enquiries, site visits, saves and bookings come from their own tables.

create table private.analytics_salts (
  day  date primary key,
  salt text not null
);
revoke all on private.analytics_salts from public, anon, authenticated;

create table public.page_views (
  id            bigint generated always as identity primary key,
  viewed_on     date not null default (now() at time zone 'Asia/Kolkata')::date,
  created_at    timestamptz not null default now(),
  path          text not null check (path ~ '^/' and length(path) <= 300),
  property_id   uuid references public.properties (id) on delete set null,
  location_ids  uuid[] not null default '{}',     -- searched or landed on
  type_ids      smallint[] not null default '{}',
  is_search     boolean not null default false,   -- /land or a location landing page
  entry         boolean not null default false,   -- first page of a visit (carries the source)
  referrer_host text check (length(referrer_host) <= 100),
  device        text check (device in ('mobile', 'tablet', 'desktop')),
  visitor       text not null check (visitor ~ '^[0-9a-f]{64}$')  -- changes every day
);
create index page_views_day_idx on public.page_views (viewed_on, visitor);
create index page_views_property_idx on public.page_views (property_id, viewed_on) where property_id is not null;

-- Nobody reads or writes it directly: the website records through
-- track_page_view, admins read through analytics_report.
alter table public.page_views enable row level security;
revoke all on public.page_views from anon, authenticated;

-- ===========================================================================
-- Recording (website server, secret key)
-- ===========================================================================
create function public.track_page_view(
  p_client         text,
  p_path           text,
  p_entry          boolean default false,
  p_referrer_host  text default null,
  p_device         text default null,
  p_location_slugs text[] default null,
  p_type_slugs     text[] default null
)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_today    date := (now() at time zone 'Asia/Kolkata')::date;
  v_salt     text;
  v_visitor  text;
  v_property uuid;
  v_landing  text[];
  v_location_slugs text[] := '{}';
  v_type_slugs     text[] := '{}';
  v_is_search boolean := false;
begin
  if p_client is null or p_client !~ '^[0-9a-f]{64}$'
     or p_path is null or p_path !~ '^/' or length(p_path) > 300 then
    return false;
  end if;

  -- Today's salt; yesterday's is kept for visits crossing midnight.
  insert into private.analytics_salts (day, salt)
  values (v_today, gen_random_uuid()::text || gen_random_uuid()::text)
  on conflict (day) do nothing;
  delete from private.analytics_salts where day < v_today - 1;
  select s.salt into v_salt from private.analytics_salts s where s.day = v_today;
  v_visitor := encode(sha256(convert_to(v_salt || ':' || p_client, 'UTF8')), 'hex');

  -- A runaway script doesn't get to fill the table.
  if (select count(*) from public.page_views v where v.viewed_on = v_today and v.visitor = v_visitor) >= 1000 then
    return false;
  end if;

  if p_path ~ '^/land/[a-z0-9-]+$' then
    select p.id into v_property from public.properties p
    where p.slug = substring(p_path from 7) and p.publish_state = 'published';
  elsif p_path = '/land' then
    v_is_search := true;
    v_location_slugs := coalesce(p_location_slugs[1:10], '{}');
    v_type_slugs := coalesce(p_type_slugs[1:10], '{}');
  else
    v_landing := regexp_match(p_path, '^/([a-z0-9-]+)-for-sale/([a-z0-9-]+)$');
    if v_landing is not null then
      v_is_search := true;
      v_location_slugs := array[v_landing[2]];
      v_type_slugs := case when v_landing[1] = 'land' then '{}' else array[v_landing[1]] end;
    end if;
  end if;

  insert into public.page_views (path, property_id, location_ids, type_ids, is_search, entry,
                                 referrer_host, device, visitor)
  values (
    p_path,
    v_property,
    coalesce((select array_agg(l.id) from public.locations l where l.slug = any (v_location_slugs)), '{}'),
    coalesce((select array_agg(t.id) from public.property_types t where t.seo_slug = any (v_type_slugs)), '{}'),
    v_is_search,
    coalesce(p_entry, false),
    case when p_entry and p_referrer_host ~ '^[a-z0-9.-]{1,100}$' then p_referrer_host end,
    case when p_device in ('mobile', 'tablet', 'desktop') then p_device end,
    v_visitor
  );
  return true;
end;
$$;

-- Daily job: raw page views go after 13 months.
create function public.cleanup_analytics()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  delete from public.page_views where viewed_on < v_today - interval '13 months';
  get diagnostics v_count = row_count;
  delete from private.analytics_salts where day < v_today - 1;
  return v_count;
end;
$$;

revoke execute on function public.track_page_view(text, text, boolean, text, text, text[], text[]),
  public.cleanup_analytics() from public, anon, authenticated;
grant execute on function public.track_page_view(text, text, boolean, text, text, text[], text[]),
  public.cleanup_analytics() to service_role;

-- ===========================================================================
-- Reports (admins)
-- ===========================================================================

-- Where a visit came from, from the referring domain.
create function private.source_label(p_host text)
returns text
language sql immutable set search_path = '' as $$
  select case
    when p_host is null then 'Direct / unknown'
    when p_host ~ '(^|\.)(google|bing|yahoo|duckduckgo|ecosia|yandex|baidu)\.' then 'Search engines'
    when p_host ~ '(^|\.)(whatsapp\.com|wa\.me)$' then 'WhatsApp'
    when p_host ~ '(^|\.)(facebook\.com|fb\.com|instagram\.com|t\.co|x\.com|twitter\.com|linkedin\.com|lnkd\.in|youtube\.com|threads\.net|pinterest\.com|reddit\.com)$'
      then 'Social media'
    else regexp_replace(p_host, '^www\.', '')
  end;
$$;

-- India-time day range → timestamps.
create function private.ist_start(p_day date)
returns timestamptz
language sql immutable set search_path = '' as $$
  select p_day::timestamp at time zone 'Asia/Kolkata';
$$;

create function private.analytics_totals(p_from date, p_to date)
returns jsonb
language sql stable set search_path = '' as $$
  with bounds as (
    select private.ist_start(p_from) as t0, private.ist_start(p_to + 1) as t1
  ), views as (
    select count(distinct v.visitor) as visitors,
           count(*) as page_views,
           count(*) filter (where v.property_id is not null) as property_views,
           count(distinct v.visitor) filter (where v.property_id is not null) as property_viewers,
           count(*) filter (where v.is_search) as searches
    from public.page_views v where v.viewed_on between p_from and p_to
  )
  select jsonb_build_object(
    'visitors', views.visitors,
    'page_views', views.page_views,
    'property_views', views.property_views,
    'property_viewers', views.property_viewers,
    'searches', views.searches,
    'enquiries', (select count(*) from public.enquiries e where e.created_at >= b.t0 and e.created_at < b.t1),
    'site_visits', (select count(*) from public.site_visits s where s.created_at >= b.t0 and s.created_at < b.t1),
    'saves', (select count(*) from public.saved_properties s where s.created_at >= b.t0 and s.created_at < b.t1),
    'bookings', (select count(*) from public.bookings k where k.created_at >= b.t0 and k.created_at < b.t1),
    'sales', (select count(*) from public.bookings k
              where k.status = 'completed' and k.completed_at >= b.t0 and k.completed_at < b.t1),
    'sales_value', (select coalesce(sum(k.agreed_price), 0) from public.bookings k
                    where k.status = 'completed' and k.completed_at >= b.t0 and k.completed_at < b.t1),
    'whatsapp_taps', (select count(*) from public.contact_taps t
                      where t.channel = 'whatsapp' and t.created_at >= b.t0 and t.created_at < b.t1),
    'call_taps', (select count(*) from public.contact_taps t
                  where t.channel = 'call' and t.created_at >= b.t0 and t.created_at < b.t1)
  )
  from views, bounds b;
$$;

create function public.analytics_report(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_days int;
  v_t0 timestamptz;
  v_t1 timestamptz;
begin
  perform private.require_admin();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from >= 366 then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  v_days := p_to - p_from + 1;
  v_t0 := private.ist_start(p_from);
  v_t1 := private.ist_start(p_to + 1);

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', private.analytics_totals(p_from, p_to),
    'previous', private.analytics_totals(p_from - v_days, p_from - 1),

    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'day', d.day,
               'visitors', coalesce(v.visitors, 0),
               'page_views', coalesce(v.page_views, 0),
               'property_views', coalesce(v.property_views, 0),
               'enquiries', (select count(*) from public.enquiries e
                             where e.created_at >= private.ist_start(d.day) and e.created_at < private.ist_start(d.day + 1)),
               'site_visits', (select count(*) from public.site_visits s
                               where s.created_at >= private.ist_start(d.day) and s.created_at < private.ist_start(d.day + 1)),
               'bookings', (select count(*) from public.bookings k
                            where k.created_at >= private.ist_start(d.day) and k.created_at < private.ist_start(d.day + 1))
             ) order by d.day), '[]')
      from (select generate_series(p_from, p_to, interval '1 day')::date as day) d
      left join (
        select pv.viewed_on, count(distinct pv.visitor) as visitors, count(*) as page_views,
               count(*) filter (where pv.property_id is not null) as property_views
        from public.page_views pv where pv.viewed_on between p_from and p_to
        group by pv.viewed_on
      ) v on v.viewed_on = d.day
    ),

    -- Every property that is on the website or had any activity.
    'properties', (
      select coalesce(jsonb_agg(row_to_json(r)::jsonb order by r.views desc, r.enquiries desc, r.code), '[]')
      from (
        select p.id, p.code, p.title, p.slug, p.availability, p.publish_state,
               coalesce(v.views, 0) as views,
               coalesce(v.viewers, 0) as viewers,
               (select count(*) from public.enquiries e
                where e.property_id = p.id and e.created_at >= v_t0 and e.created_at < v_t1) as enquiries,
               (select count(*) from public.site_visits s
                where s.property_id = p.id and s.created_at >= v_t0 and s.created_at < v_t1) as site_visits,
               (select count(*) from public.saved_properties s
                where s.property_id = p.id and s.created_at >= v_t0 and s.created_at < v_t1) as saves,
               (select count(*) from public.bookings k
                where k.property_id = p.id and k.created_at >= v_t0 and k.created_at < v_t1) as bookings,
               (select count(*) from public.bookings k
                where k.property_id = p.id and k.status = 'completed'
                  and k.completed_at >= v_t0 and k.completed_at < v_t1) as sales
        from public.properties p
        left join (
          select pv.property_id, count(*) as views, count(distinct pv.visitor) as viewers
          from public.page_views pv
          where pv.viewed_on between p_from and p_to and pv.property_id is not null
          group by pv.property_id
        ) v on v.property_id = p.id
      ) r
      where r.publish_state = 'published'
         or r.views + r.enquiries + r.site_visits + r.saves + r.bookings + r.sales > 0
    ),

    -- Searched (filters and landing pages) and viewed (property pages) per place / land type.
    'locations', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'name', l.city, 'district', l.district, 'searches', x.searches, 'property_views', x.property_views
             ) order by x.searches + x.property_views desc, l.city), '[]')
      from public.locations l
      join (
        select loc as location_id, sum(searches)::int as searches, sum(property_views)::int as property_views
        from (
          select unnest(pv.location_ids) as loc, 1 as searches, 0 as property_views
          from public.page_views pv where pv.viewed_on between p_from and p_to and pv.is_search
          union all
          select p.location_id, 0, 1
          from public.page_views pv join public.properties p on p.id = pv.property_id
          where pv.viewed_on between p_from and p_to
        ) u group by loc
      ) x on x.location_id = l.id
    ),
    'types', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'name', t.name, 'searches', x.searches, 'property_views', x.property_views
             ) order by x.searches + x.property_views desc, t.name), '[]')
      from public.property_types t
      join (
        select type_id, sum(searches)::int as searches, sum(property_views)::int as property_views
        from (
          select unnest(pv.type_ids) as type_id, 1 as searches, 0 as property_views
          from public.page_views pv where pv.viewed_on between p_from and p_to and pv.is_search
          union all
          select p.property_type_id, 0, 1
          from public.page_views pv join public.properties p on p.id = pv.property_id
          where pv.viewed_on between p_from and p_to
        ) u group by type_id
      ) x on x.type_id = t.id
    ),

    'sources', (
      select coalesce(jsonb_agg(jsonb_build_object('source', s.source, 'visits', s.visits)
                                order by s.visits desc, s.source), '[]')
      from (
        select private.source_label(pv.referrer_host) as source, count(*) as visits
        from public.page_views pv where pv.viewed_on between p_from and p_to and pv.entry
        group by 1
      ) s
    ),
    'devices', (
      select coalesce(jsonb_agg(jsonb_build_object('device', d.device, 'visitors', d.visitors)
                                order by d.visitors desc), '[]')
      from (
        select coalesce(pv.device, 'unknown') as device, count(distinct pv.visitor) as visitors
        from public.page_views pv where pv.viewed_on between p_from and p_to
        group by 1
      ) d
    )
  );
end;
$$;

revoke execute on function public.analytics_report(date, date) from public, anon;
grant execute on function public.analytics_report(date, date) to authenticated;

-- ===========================================================================
-- Dashboard: website visitors in the last 7 days
-- ===========================================================================
create or replace function public.dashboard_summary()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  perform private.require_admin();
  select jsonb_build_object(
    'total',       count(*) filter (where publish_state <> 'archived'),
    'draft',       count(*) filter (where publish_state = 'draft'),
    'published',   count(*) filter (where publish_state = 'published'),
    'hidden',      count(*) filter (where publish_state = 'hidden'),
    'archived',    count(*) filter (where publish_state = 'archived'),
    'available',   count(*) filter (where publish_state = 'published' and availability = 'available'),
    'reserved',    count(*) filter (where publish_state <> 'archived' and availability = 'reserved'),
    'sold',        count(*) filter (where publish_state <> 'archived' and availability = 'sold')
  ) into v_result
  from public.properties;

  return v_result || jsonb_build_object(
    'new_enquiries', (select count(*) from public.enquiries e where e.status = 'new'),
    'enquiries_last_7_days',
      (select count(*) from public.enquiries e where e.created_at > now() - interval '7 days'),
    'whatsapp_taps_last_7_days',
      (select count(*) from public.contact_taps t where t.channel = 'whatsapp' and t.created_at > now() - interval '7 days'),
    'call_taps_last_7_days',
      (select count(*) from public.contact_taps t where t.channel = 'call' and t.created_at > now() - interval '7 days'),
    'requested_site_visits',
      (select count(*) from public.site_visits s where s.status = 'requested'),
    'site_visits_next_7_days',
      (select count(*) from public.site_visits s where s.status = 'confirmed'
         and s.visit_date between v_today and v_today + 7),
    'bookings_to_review',
      (select count(*) from public.bookings b where b.status in ('requested', 'pending_approval')),
    'bookings_in_progress',
      (select count(*) from public.bookings b where b.status in ('approved', 'payment_pending', 'reserved')),
    -- Daily visitors added up (a visitor is counted once per day).
    'visitors_last_7_days',
      (select count(*) from (select distinct v.viewed_on, v.visitor from public.page_views v
                             where v.viewed_on > v_today - 7) d)
  );
end;
$$;

-- ===========================================================================
-- Privacy policy: say how visits are counted (unless already edited to).
-- ===========================================================================
update public.content_blocks
set published = jsonb_insert(published, '{sections,2}', $json${"heading": "Website statistics", "text": "We count page visits to see which land and places interest people, without cookies. We don't store your IP address or anything else that identifies you, and visits can't be linked from one day to the next. Browsers that send Do Not Track or Global Privacy Control are not counted."}$json$::jsonb)
where key = 'legal.privacy' and published::text not like '%Website statistics%';
