-- Phase 14: website content (CMS).
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

-- ===========================================================================
-- Visitors see only what is published
-- ===========================================================================
update public.content_blocks set draft = jsonb_set(published, '{title}', '"Secret draft title"')
where key = 'home.hero';

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select is((select count(*)::int from public.public_content), 9, 'visitors read the 9 published page texts');
select is((select value ->> 'title' from public.public_content where key = 'home.hero'),
  'Own verified land, directly from us', 'visitors see the published title, not the draft');
select throws_ok($$ select draft from public.content_blocks $$, '42501', null, 'visitors can''t read drafts');
select is((select count(*)::int from public.faqs), 7, 'visitors read the published FAQs');
select throws_ok($$ select * from public.content_previews $$, '42501', null, 'preview tokens are private');
select throws_ok($$ select public.create_content_preview() $$, '42501', null, 'visitors can''t make preview links');
reset role;

-- ===========================================================================
-- Plain admins read but can't change
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000002"}';
select is((select draft ->> 'title' from public.content_blocks where key = 'home.hero'), 'Secret draft title',
  'admins can read drafts');
update public.content_blocks set draft = '{"title":"Admin edit"}' where key = 'home.hero';
select throws_ok($$ insert into public.faqs (question, answer) values ('Admin question?', 'Answer') $$,
  '42501', null, 'plain admins can''t add FAQs');
select throws_ok($$ select public.publish_content('home.hero') $$, '42501', null, 'plain admins can''t publish');
select throws_ok($$ select public.reorder_content('faqs', array[]::uuid[]) $$, '42501', null, '…or reorder');
select isnt(public.create_content_preview(), null, 'admins can make a preview link');
reset role;
select is((select draft ->> 'title' from public.content_blocks where key = 'home.hero'), 'Secret draft title',
  'the plain admin''s edit changed nothing');

-- ===========================================================================
-- Super admins: drafts are checked, then published
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000001"}';
select throws_ok($$ update public.content_blocks set draft = '{"title":""}' where key = 'home.hero' $$,
  '23514', 'The homepage needs a title.', 'the hero needs a title');
select throws_ok($$ update public.content_blocks set draft = jsonb_build_object('title', repeat('x', 4001))
                    where key = 'home.hero' $$, '23514', null, 'very long text is refused');
select throws_ok($$ update public.content_blocks set draft = '{"title":"T","image_path":"https://evil.example/x.png"}'
                    where key = 'home.hero' $$, '23514', 'Images must be uploaded through the admin panel.',
  'images only from our own uploads');
select throws_ok($$ update public.content_blocks
                    set draft = '{"items":[{"icon":"<script>","title":"x","text":"y"}]}' where key = 'home.why_us' $$,
  '23514', 'Unknown icon.', 'only known icons');
select lives_ok($$ update public.content_blocks
                   set draft = '{"eyebrow":"New","title":"Plots near Vizag airport","subtitle":"Clear titles","image_path":"content/hero/abc.webp"}'
                   where key = 'home.hero' $$, 'a super admin saves a draft');
select lives_ok($$ select public.publish_content('home.hero') $$, 'and publishes it');
select throws_ok($$ select public.publish_content('home.hero') $$, '22023', 'There are no changes to publish.',
  'nothing to publish twice');
reset role;
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select is((select value ->> 'title' from public.public_content where key = 'home.hero'), 'Plots near Vizag airport',
  'visitors now see the published change');
reset role;

-- ===========================================================================
-- Testimonials, banners, ordering
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"role":"authenticated","sub":"00000000-0000-4000-a000-000000000001"}';
select throws_ok($$ insert into public.testimonials (name, quote, is_published)
                    values ('Kumar', 'Very honest people, clear documents.', true) $$,
  '23514', null, 'a testimonial can''t be published without the customer''s consent');
insert into public.testimonials (name, place, quote, has_consent, consent_note, is_published)
values ('Kumar Swamy', 'Visakhapatnam', 'Very honest people, clear documents.', true, 'Agreed on WhatsApp, 9 Nov', true),
       ('Draft Person', null, 'Not shown yet because it is not published.', true, null, false);
select throws_ok($$ insert into public.banners (title, link_url) values ('Bad link', 'javascript:alert(1)') $$,
  '23514', null, 'banner links can''t run code');
select throws_ok($$ insert into public.banners (title, link_url) values ('Other site', '//evil.example') $$,
  '23514', null, 'banner links can''t point to another site without https');
insert into public.banners (title, link_url, starts_at, ends_at) values
  ('Now showing', '/land', now() - interval '1 day', now() + interval '1 day'),
  ('Starts tomorrow', '/land', now() + interval '1 day', null),
  ('Ended', 'https://example.com', now() - interval '3 days', now() - interval '1 day');
select lives_ok($$ select public.reorder_content('faqs',
                   array(select id from public.faqs order by sort_order desc)) $$, 'super admin reorders FAQs');
select throws_ok($$ select public.reorder_content('properties', array[]::uuid[]) $$, '22023', null,
  'only content lists can be reordered');
reset role;
select is((select question from public.faqs order by sort_order limit 1), 'How long does registration take?',
  'the new order is saved');

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';
select is((select array_agg(name) from public.testimonials), '{"Kumar Swamy"}'::text[],
  'visitors see only published testimonials with consent');
select is((select array_agg(title) from public.banners), '{"Now showing"}'::text[],
  'visitors see only banners inside their dates');
reset role;

select is((select count(*)::int from public.audit_logs where action = 'content.published'), 1,
  'publishing is in the activity log');

select * from finish();
rollback;
