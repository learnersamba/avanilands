-- Phase 8: live enquiry alerts and contact taps.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

select ok(
  exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'enquiries'),
  'enquiries are published for live alerts'
);
select ok(
  not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
              and tablename not in ('enquiries', 'site_visits', 'bookings', 'notifications')),
  'nothing else is published (site visits joined in Phase 10, bookings in 13, notifications in 15)'
);

-- Website server records taps.
set local role service_role;
select lives_ok($$ select public.log_contact_tap('whatsapp', '10000000-0000-4000-a000-000000000001') $$,
  'website can record a WhatsApp tap');
select lives_ok($$ select public.log_contact_tap('call', '10000000-0000-4000-a000-000000000010') $$,
  'tap on a hidden property is recorded without the property');
select throws_ok($$ select public.log_contact_tap('email') $$, '23514', null, 'unknown channel refused');
reset role;
select is((select property_id from public.contact_taps where channel = 'call' order by id desc limit 1), null,
  'hidden property not linked');

-- Visitors can't record or read taps directly.
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select throws_ok($$ select public.log_contact_tap('whatsapp') $$, '42501', null, 'visitors cannot call it directly');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';
select is((public.dashboard_summary() ->> 'whatsapp_taps_last_7_days')::int, 1, 'dashboard counts taps');

select * from finish();
rollback;
