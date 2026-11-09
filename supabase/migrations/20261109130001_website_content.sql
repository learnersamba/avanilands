-- Phase 14: website content managed in the admin panel (CMS). Page texts
-- have a draft and a published version; FAQs, testimonials and banners are
-- published one by one. Super admins edit; the website reads published only.

-- ---------------------------------------------------------------------------
-- Page texts
-- ---------------------------------------------------------------------------

-- Why a content value is not acceptable, or null. Text only: every string
-- is limited, lists are short, icons and image paths come from fixed sets.
create function private.content_problem(p_key text, p_value jsonb)
returns text
language plpgsql immutable set search_path = '' as $$
begin
  if p_value is null then
    return null;
  end if;
  if jsonb_typeof(p_value) <> 'object' then
    return 'Content must be an object.';
  end if;
  if exists (select 1 from jsonb_path_query(p_value, 'strict $.** ? (@.type() == "string")') s
             where length(s #>> '{}') > 4000) then
    return 'A text is too long (4,000 characters at most).';
  end if;
  if exists (select 1 from jsonb_path_query(p_value, 'strict $.** ? (@.type() == "array")') a
             where jsonb_array_length(a) > 20) then
    return 'A list is too long (20 items at most).';
  end if;
  if exists (select 1 from jsonb_path_query(p_value, 'lax $.**.icon') i
             where not (i #>> '{}' = any (array['shield', 'stamp', 'handshake', 'map', 'badge', 'file', 'ruler', 'users']))) then
    return 'Unknown icon.';
  end if;
  if p_value ? 'image_path' and jsonb_typeof(p_value -> 'image_path') = 'string'
     and (p_value ->> 'image_path') !~ '^content/[a-z0-9/_-]+\.(webp|jpg|png)$' then
    return 'Images must be uploaded through the admin panel.';
  end if;
  if p_key = 'home.hero' and coalesce(btrim(p_value ->> 'title'), '') = '' then
    return 'The homepage needs a title.';
  end if;
  if p_key = 'about' and coalesce(btrim(p_value ->> 'intro'), '') = '' then
    return 'The About page needs an introduction.';
  end if;
  if p_key like 'legal.%' and coalesce(jsonb_array_length(p_value -> 'sections'), 0) = 0 then
    return 'A legal page needs at least one section.';
  end if;
  return null;
end;
$$;

create table public.content_blocks (
  key          text primary key check (key in ('home.hero', 'home.trust_points', 'home.why_us', 'home.verification', 'home.steps', 'about', 'legal.terms', 'legal.privacy', 'legal.disclaimer')),
  published    jsonb not null,
  draft        jsonb,
  published_at timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references public.admin_users (user_id) on delete set null,
  constraint published_ok check (private.content_problem(key, published) is null),
  constraint draft_ok check (private.content_problem(key, draft) is null)
);

create function private.content_before_update()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce((select auth.uid()), old.updated_by);
  -- Friendly message instead of the bare constraint name.
  if private.content_problem(new.key, new.draft) is not null then
    raise exception '%', private.content_problem(new.key, new.draft) using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger content_blocks_before_update
  before update on public.content_blocks
  for each row execute function private.content_before_update();

-- What the website reads: published values only (never drafts).
create view public.public_content as
select key, published as value, published_at from public.content_blocks;

-- ---------------------------------------------------------------------------
-- FAQs, testimonials, banners
-- ---------------------------------------------------------------------------
create table public.faqs (
  id           uuid primary key default gen_random_uuid(),
  question     text not null check (length(btrim(question)) between 5 and 200),
  answer       text not null check (length(btrim(answer)) between 2 and 2000),
  show_on_home boolean not null default false,
  is_published boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Only real customers, with their permission (Consumer Protection rules on
-- fake reviews): a testimonial can't be published without consent recorded.
create table public.testimonials (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(btrim(name)) between 2 and 80),
  place        text check (length(place) <= 80),
  quote        text not null check (length(btrim(quote)) between 10 and 600),
  rating       smallint check (rating between 1 and 5),
  photo_path   text check (photo_path ~ '^content/[a-z0-9/_-]+\.(webp|jpg|png)$'),
  property_id  uuid references public.properties (id) on delete set null,
  has_consent  boolean not null default false,
  consent_note text check (length(consent_note) <= 200),
  is_published boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint published_needs_consent check (not is_published or has_consent)
);

create table public.banners (
  id           uuid primary key default gen_random_uuid(),
  title        text not null check (length(btrim(title)) between 2 and 80),
  text         text check (length(text) <= 200),
  link_url     text check (link_url ~ '^(/[a-z0-9]|/$|https://)' and length(link_url) <= 300),
  link_label   text check (length(link_label) <= 30),
  image_path   text check (image_path ~ '^content/[a-z0-9/_-]+\.(webp|jpg|png)$'),
  starts_at    timestamptz,
  ends_at      timestamptz,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint schedule_ok check (ends_at is null or starts_at is null or ends_at > starts_at)
);

do $$
declare
  t text;
begin
  foreach t in array array['faqs', 'testimonials', 'banners'] loop
    execute format('create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
                   t || '_updated_at', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Security: everyone reads what's published; admins read everything;
-- super admins change it.
-- ---------------------------------------------------------------------------
alter table public.content_blocks enable row level security;
alter table public.faqs enable row level security;
alter table public.testimonials enable row level security;
alter table public.banners enable row level security;

revoke all on public.content_blocks from anon, authenticated;
grant select on public.content_blocks to authenticated;
grant update (draft) on public.content_blocks to authenticated;
create policy "admins read content" on public.content_blocks
  for select to authenticated using ((select public.is_admin()));
create policy "super admins edit drafts" on public.content_blocks
  for update to authenticated using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

revoke all on public.public_content from anon, authenticated;
grant select on public.public_content to anon, authenticated;

revoke all on public.faqs, public.testimonials, public.banners from anon, authenticated;
grant select on public.faqs, public.testimonials, public.banners to anon, authenticated;
grant insert, update, delete on public.faqs, public.testimonials, public.banners to authenticated;

create policy "read published faqs" on public.faqs
  for select using (is_published or (select public.is_admin()));
create policy "super admins change faqs" on public.faqs
  for all to authenticated using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

create policy "read published testimonials" on public.testimonials
  for select using ((is_published and has_consent) or (select public.is_admin()));
create policy "super admins change testimonials" on public.testimonials
  for all to authenticated using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

create policy "read current banners" on public.banners
  for select using (
    (is_active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()))
    or (select public.is_admin()));
create policy "super admins change banners" on public.banners
  for all to authenticated using ((select public.is_super_admin())) with check ((select public.is_super_admin()));

-- ---------------------------------------------------------------------------
-- Publishing, previews, ordering
-- ---------------------------------------------------------------------------
create function public.publish_content(p_key text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if not public.is_super_admin() then
    raise exception 'Only a super admin can publish website content.' using errcode = '42501';
  end if;
  update public.content_blocks
  set published = draft, draft = null, published_at = now()
  where key = p_key and draft is not null;
  if not found then
    raise exception 'There are no changes to publish.' using errcode = '22023';
  end if;
  perform private.write_audit('content.published', 'content', p_key, jsonb_build_object('name', p_key));
end;
$$;

create function public.discard_content_draft(p_key text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if not public.is_super_admin() then
    raise exception 'Only a super admin can change website content.' using errcode = '42501';
  end if;
  update public.content_blocks set draft = null where key = p_key;
end;
$$;

-- Private preview links (one hour). The website checks them with its secret key.
create table public.content_previews (
  token      uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.admin_users (user_id) on delete cascade,
  expires_at timestamptz not null default now() + interval '1 hour'
);
alter table public.content_previews enable row level security;
revoke all on public.content_previews from anon, authenticated;

create function public.create_content_preview()
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_token uuid;
begin
  perform private.require_admin();
  delete from public.content_previews where expires_at < now();
  insert into public.content_previews (created_by) values ((select auth.uid())) returning token into v_token;
  return v_token;
end;
$$;

-- Saves a new order (FAQs, testimonials or banners): ids in display order.
create function public.reorder_content(p_table text, p_ids uuid[])
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if not public.is_super_admin() then
    raise exception 'Only a super admin can change website content.' using errcode = '42501';
  end if;
  if p_table not in ('faqs', 'testimonials', 'banners') then
    raise exception 'Unknown list.' using errcode = '22023';
  end if;
  execute format(
    'update public.%I t set sort_order = o.n from unnest($1) with ordinality as o(id, n) where t.id = o.id',
    p_table) using p_ids;
end;
$$;

revoke execute on function public.publish_content(text) from public, anon;
revoke execute on function public.discard_content_draft(text) from public, anon;
revoke execute on function public.create_content_preview() from public, anon;
revoke execute on function public.reorder_content(text, uuid[]) from public, anon;
grant execute on function public.publish_content(text), public.discard_content_draft(text),
  public.create_content_preview(), public.reorder_content(text, uuid[]) to authenticated;
-- Pure text check (reads no data). Editors need to run it: the table's
-- CHECK constraints call it with their permissions.
revoke execute on function private.content_problem(text, jsonb) from public, anon;
grant execute on function private.content_problem(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Activity log and website refresh
-- ---------------------------------------------------------------------------
create trigger faqs_audit after insert or update or delete on public.faqs
  for each row execute function private.audit_row('faq');
create trigger testimonials_audit after insert or update or delete on public.testimonials
  for each row execute function private.audit_row('testimonial');
create trigger banners_audit after insert or update or delete on public.banners
  for each row execute function private.audit_row('banner');

do $$
declare
  t text;
begin
  foreach t in array array['content_blocks', 'faqs', 'testimonials', 'banners'] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
       for each statement execute function private.notify_website()',
      t || '_notify_website', t
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Starting content: today's website text (PLACEHOLDER lines still marked)
-- ---------------------------------------------------------------------------
insert into public.content_blocks (key, published) values
  ('home.hero', $json${"eyebrow": "Verified land · Andhra Pradesh", "title": "Own verified land, directly from us", "subtitle": "Approved plots, farm land and agricultural land with clear titles. No brokers, no middlemen — just honest land and a team that walks the site with you.", "image_path": null}$json$::jsonb),
  ('home.trust_points', $json${"items": [{"icon": "shield", "title": "Clear titles", "text": "Every document checked before we list"}, {"icon": "stamp", "title": "Approved layouts", "text": "DTCP, VMRDA and RERA where applicable"}, {"icon": "handshake", "title": "No brokers", "text": "You deal with us directly"}, {"icon": "map", "title": "Site visits arranged", "text": "We show you the land in person"}]}$json$::jsonb),
  ('home.why_us', $json${"items": [{"icon": "badge", "title": "We own what we sell", "text": "Every property on this website belongs to us. No third-party listings, no surprises about who you are dealing with."}, {"icon": "file", "title": "Paperwork you can check", "text": "Title, encumbrance, approvals and survey details are shared before you pay anything."}, {"icon": "ruler", "title": "Measured and marked", "text": "Boundaries, dimensions and road widths are stated exactly — what you see is what you register."}, {"icon": "users", "title": "One team, start to finish", "text": "The same people answer your enquiry, show you the site and help with registration."}]}$json$::jsonb),
  ('home.verification', $json${"items": ["Title deed and link documents traced back at least 30 years", "Encumbrance certificate (EC) — no loans or disputes on the land", "Survey number, extent and boundaries matched with revenue records", "Layout and building approvals (DTCP / VMRDA / RERA) where they apply", "Physical inspection: access road, water and power on site"]}$json$::jsonb),
  ('home.steps', $json${"items": [{"title": "Enquire", "text": "Ask about any property by phone, WhatsApp or the enquiry form."}, {"title": "Visit the site", "text": "We arrange a visit and walk the land with you."}, {"title": "Book", "text": "Reserve the property with a booking amount once you are sure."}, {"title": "Documentation", "text": "We share all documents for your lawyer to verify."}, {"title": "Registration", "text": "Complete payment and register the land in your name."}]}$json$::jsonb),
  ('about', $json${"intro": "PLACEHOLDER — Avanilands sells land it owns, directly to buyers, across Andhra Pradesh. Replace this with the company's story: who started it, when, and why.", "mission": "PLACEHOLDER — To make buying land simple, transparent and safe for every family.", "vision": "PLACEHOLDER — To be the most trusted name for land in Andhra Pradesh.", "values": [{"title": "Honesty", "text": "We say what we know, and we show you the papers."}, {"title": "Clarity", "text": "Exact measurements, fixed prices, no hidden charges."}, {"title": "Care", "text": "We stay with you from the first call to registration."}], "image_path": null}$json$::jsonb),
  ('legal.terms', $json${"title": "Terms of use", "sections": [{"heading": "About this website", "text": "This website shows land owned and sold by the company. Information is provided to help you decide whether to enquire; it is not an offer or a contract."}, {"heading": "Accuracy", "text": "We take care to keep details, prices and availability correct, but they can change. The registered sale documents are the final word on any property."}, {"heading": "Bookings and payments", "text": "No booking or sale is complete until it is confirmed in writing by the company. Payment terms are agreed separately for each property."}, {"heading": "Use of content", "text": "Photos, text and documents on this website belong to the company and may not be copied for commercial use."}], "final": false}$json$::jsonb),
  ('legal.privacy', $json${"title": "Privacy policy", "sections": [{"heading": "What we collect", "text": "When you send an enquiry we keep your name, phone number, optional email and message, and which property you asked about."}, {"heading": "How we use it", "text": "Only to answer your enquiry, arrange site visits and follow up on your interest. We do not sell or share your details with other companies."}, {"heading": "How long we keep it", "text": "Enquiries are kept while they are useful for your purchase and for our records, then deleted or anonymised."}, {"heading": "Your choices", "text": "You can ask us to see, correct or delete your details at any time using the contact page."}], "final": false}$json$::jsonb),
  ('legal.disclaimer', $json${"title": "Disclaimer", "sections": [{"heading": "Photos and maps", "text": "Photos are for illustration and may not show the current condition of a property. Map locations may be approximate until shared with you directly."}, {"heading": "Approvals", "text": "Approval and registration numbers are shown as issued. Buyers should verify all documents independently with their own legal advisor before purchase."}, {"heading": "Prices", "text": "Prices exclude registration charges, stamp duty and other government fees unless stated otherwise."}], "final": false}$json$::jsonb);

insert into public.faqs (question, answer, show_on_home, sort_order) values
  ($txt$Do you sell land on behalf of other owners?$txt$, $txt$No. Every property on this website is owned by us. We do not list land for brokers, agents or other sellers.$txt$, true, 1),
  ($txt$Can I see the documents before booking?$txt$, $txt$Yes. Approval details are on each property page, and we share copies of the title and other documents during or after your site visit.$txt$, true, 2),
  ($txt$How do I arrange a site visit?$txt$, $txt$Send an enquiry or message us on WhatsApp with the property code (for example AL-0001). We will fix a time that suits you.$txt$, true, 3),
  ($txt$Is the price negotiable?$txt$, $txt$Properties marked “Negotiable” are open to discussion. For others, the listed price is final.$txt$, true, 4),
  ($txt$What does “Reserved” mean?$txt$, $txt$Another buyer has booked the property. You can still enquire — we will tell you if it becomes available again and suggest similar land.$txt$, true, 5),
  ($txt$Do you help with bank loans?$txt$, $txt$PLACEHOLDER — the owner should confirm whether loan assistance is offered.$txt$, false, 6),
  ($txt$How long does registration take?$txt$, $txt$PLACEHOLDER — usually a few weeks after full payment, depending on the sub-registrar office.$txt$, false, 7);
