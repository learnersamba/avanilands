-- Decision 133: Meta advertising — settings switch, lead attribution, and
-- sales results queued for the Conversions API.
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

-- Settings ---------------------------------------------------------------------
select is((select meta_ads_enabled from public.site_settings where id = 1), false,
  'advertising is off until a Super Admin switches it on');
select is((select meta_ads_enabled from public.public_site_settings), false,
  'the website can read the switch');

select ok((select published::text like '%Advertising on Facebook and Instagram%'
            from public.content_blocks where key = 'legal.privacy'),
  'the privacy policy explains Meta advertising');

-- Two enquiries: one from a visitor who allowed ad cookies, one who did not.
insert into public.enquiries (id, name, phone, email, property_id) values
  ('a0000000-0000-4000-a000-0000000000e1', 'Consented Buyer', '9000011111', 'buyer@example.com',
   '10000000-0000-4000-a000-000000000001'),
  ('a0000000-0000-4000-a000-0000000000e2', 'Private Buyer', '9000022222', null, null);

set local role service_role;
select lives_ok($$
  insert into public.lead_attribution (enquiry_id, utm_source, utm_campaign, landing_path, ad_consent, consent_at, meta_fbc, meta_fbp)
  values ('a0000000-0000-4000-a000-0000000000e1', 'facebook', 'vizag-plots', '/land', true, now(),
          'fb.1.1764000000000.IwAR0abcdefghijk', 'fb.1.1764000000000.1234567890')
$$, 'the website records the campaign and, with consent, Meta''s ids');
select throws_ok($$
  insert into public.lead_attribution (enquiry_id, ad_consent, meta_fbp)
  values ('a0000000-0000-4000-a000-0000000000e2', false, 'fb.1.1764000000000.1234567890')
$$, '23514', null, 'Meta''s ids are refused without consent');
select lives_ok($$
  insert into public.lead_attribution (enquiry_id, utm_source, ad_consent)
  values ('a0000000-0000-4000-a000-0000000000e2', 'instagram', false)
$$, 'campaign tags alone are fine without consent');
reset role;

-- Admin marks the consented enquiry Interested while advertising is off.
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e1', 'contacted');
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e1', 'interested');
reset role;
select is((select count(*)::int from public.meta_event_queue), 0, 'nothing is queued while advertising is off');

update public.site_settings set meta_ads_enabled = true where id = 1;

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e1', 'converted');
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e1', 'follow_up');
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e1', 'converted');
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e2', 'interested');
select public.update_enquiry_status('a0000000-0000-4000-a000-0000000000e2', 'converted');
-- Admins can read where a lead came from, but not the queue.
select is((select utm_campaign from public.lead_attribution where enquiry_id = 'a0000000-0000-4000-a000-0000000000e1'),
  'vizag-plots', 'admins see the campaign');
select throws_ok($$ select count(*) from public.meta_event_queue $$, '42501', null, 'admins cannot read the queue');
select throws_ok($$ select public.claim_meta_events(10) $$, '42501', null, 'admins cannot claim events');
select throws_ok($$ insert into public.lead_attribution (enquiry_id, ad_consent) values ('a0000000-0000-4000-a000-0000000000e2', true) $$,
  '42501', null, 'admins cannot write attribution');
reset role;

select is((select array_agg(event_name order by id) from public.meta_event_queue),
  '{ConvertedLead}'::text[],
  'converting the consented lead queues one ConvertedLead (a second time does nothing); the other lead nothing');

set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select throws_ok($$ select count(*) from public.lead_attribution $$, '42501', null, 'visitors cannot read attribution');
reset role;

-- The website claims and sends --------------------------------------------------
set local role service_role;
select is(
  (select jsonb_build_object('phone', phone, 'email', email, 'fbc', fbc, 'code', property_code)
     from public.claim_meta_events(10)),
  (select jsonb_build_object('phone', '9000011111', 'email', 'buyer@example.com',
                             'fbc', 'fb.1.1764000000000.IwAR0abcdefghijk', 'code', p.code)
     from public.properties p where p.id = '10000000-0000-4000-a000-000000000001'),
  'claiming returns what Meta needs to match the person');
select is((select count(*)::int from public.claim_meta_events(10)), 0, 'a claimed event is not handed out twice');
select public.finish_meta_events((select array_agg(id) from public.meta_event_queue), '{}', null);
select is((select status from public.meta_event_queue limit 1), 'sent', 'sent events are marked');
reset role;

-- Clean-up ----------------------------------------------------------------------
update public.lead_attribution set created_at = now() - interval '181 days'
where enquiry_id = 'a0000000-0000-4000-a000-0000000000e1';
set local role service_role;
select is(public.cleanup_meta_data(), 1, 'Meta''s ids are cleared after 180 days');
reset role;
select is((select array[meta_fbc, meta_fbp, utm_campaign] from public.lead_attribution
           where enquiry_id = 'a0000000-0000-4000-a000-0000000000e1'),
  array[null, null, 'vizag-plots'], 'the campaign stays with the enquiry');

select * from finish();
rollback;
