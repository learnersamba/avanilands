-- Phase 1: website search and enquiries.
begin;
create extension if not exists pgtap with schema extensions;

select plan(35);

-- ===========================================================================
-- Search (as a visitor)
-- ===========================================================================
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select is((public.search_properties() ->> 'total')::int, 8, 'default: available and reserved, not sold');
select is((public.search_properties(p_availability => array['sold']::public.availability[]) ->> 'total')::int,
  1, 'sold only when asked for');
select is(public.search_properties() -> 'items' -> 0 ->> 'code', 'AL-0001', 'newest first by default');
select is(jsonb_array_length(public.search_properties(p_page_size => 3) -> 'items'), 3, 'page size respected');
select is(public.search_properties(p_page => 3, p_page_size => 3) -> 'items' -> 1 ->> 'code', 'AL-0009',
  'pagination: page 3, second item');
select is(jsonb_array_length(public.search_properties(p_page_size => 500) -> 'items'), 8, 'page size capped at 24');
select is(public.search_properties() -> 'items' -> 0 -> 'internal_notes', null, 'no internal notes in results');
select is(public.search_properties() -> 'items' -> 0 -> 'description', null, 'cards carry no long text');

select is((public.search_properties(p_type_ids => array[(select id from public.property_types
  where slug = 'agricultural-land')]) ->> 'total')::int, 2, 'type filter');
select is((public.search_properties(p_location_ids => array['20000000-0000-4000-a000-000000000002'::uuid])
  ->> 'total')::int, 3, 'location filter');
select is((public.search_properties(p_price_min => 3000000, p_price_max => 5000000) ->> 'total')::int, 3,
  'price range (skips price-on-request)');
select is((public.search_properties(p_area_min_sqft => 40000) ->> 'total')::int, 3, 'area filter across units');
select is((public.search_properties(p_road_width_min => 60) ->> 'total')::int, 2, 'road width filter');
select is((public.search_properties(p_facings => array['east', 'north']::public.facing[]) ->> 'total')::int, 2,
  'facing filter');
select is((public.search_properties(p_approved_only => true) ->> 'total')::int, 6, 'approved only');
select is((public.search_properties(p_featured_only => true) ->> 'total')::int, 3, 'featured only');
select is((public.search_properties(p_amenity_ids => array(select id from public.amenities
  where name in ('Gated community', '24×7 security'))) ->> 'total')::int, 1, 'must have all chosen amenities');

select is(public.search_properties(p_sort => 'price_asc') -> 'items' -> 0 ->> 'code', 'AL-0009', 'cheapest first');
select is(public.search_properties(p_sort => 'price_desc') -> 'items' -> 0 ->> 'code', 'AL-0006', 'dearest first');
select is(public.search_properties(p_sort => 'price_asc') -> 'items' -> 7 ->> 'code', 'AL-0005',
  'price-on-request last');
select is(public.search_properties(p_sort => 'area_desc') -> 'items' -> 0 ->> 'code', 'AL-0006', 'largest first');
select is(public.search_properties(p_sort => 'featured') -> 'items' -> 2 ->> 'code', 'AL-0004',
  'featured order by rank');
select throws_ok($$ select public.search_properties(p_sort => 'random') $$, '22023', null, 'unknown sort refused');

select is((public.search_properties(p_q => 'Anakapalli') ->> 'total')::int, 3, 'search by city');
select is((public.search_properties(p_q => 'Madhuravada') ->> 'total')::int, 1, 'typo-tolerant locality search');
select is((public.search_properties(p_q => 'AL-0003') -> 'items' -> 0 ->> 'code'), 'AL-0003', 'search by code');
select is((public.search_properties(p_q => '100%_plot') ->> 'total')::int, 0, 'wildcards in the query are literal');

-- ===========================================================================
-- Enquiries (website server = service_role)
-- ===========================================================================
set local role service_role;

select matches(public.submit_enquiry('Suresh Babu', '+91 90123 45678', 'Interested',
  '10000000-0000-4000-a000-000000000002') ->> 'reference', '^ENQ-[0-9]{6}$', 'enquiry saved with a reference');
select is((select phone from public.enquiries where name = 'Suresh Babu'), '9012345678', 'phone stored as 10 digits');

select throws_ok($$ select public.submit_enquiry('Suresh Babu', '12345') $$, '22023', 'invalid_phone',
  'invalid phone refused');
select throws_ok($$ select public.submit_enquiry('Suresh Babu', '9012345678', null,
  '10000000-0000-4000-a000-000000000008') $$, 'P0002', 'property_unavailable', 'no enquiries on sold land');

select is(
  public.submit_enquiry('Meena', '9876501234', null, null, null, 'phone', 'contact_page', null,
    '50000000-0000-4000-a000-000000000001') ->> 'reference',
  public.submit_enquiry('Meena', '9876501234', null, null, null, 'phone', 'contact_page', null,
    '50000000-0000-4000-a000-000000000001') ->> 'reference',
  'same idempotency key returns the same enquiry');

do $$ begin perform public.submit_enquiry('Flood', '9555500000', 'spam ' || n) from generate_series(1, 5) n; end $$;
select throws_ok($$ select public.submit_enquiry('Flood', '9555500000', 'spam 6') $$, 'P0001', 'rate_limited',
  'sixth enquiry in an hour from the same phone refused');

-- ===========================================================================
-- Admin handles the enquiry
-- ===========================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-4000-a000-000000000002", "role": "authenticated"}';

select throws_ok($$ update public.enquiries set status = 'closed' $$, '42501', null,
  'status only changes through update_enquiry_status');
do $$ begin
  perform public.update_enquiry_status((select id from public.enquiries where reference = 'ENQ-000001'),
    'contacted', 'Called, will visit on Sunday');
end $$;
select results_eq($$
  select status_from::text, status_to::text, note from public.enquiry_notes
  where enquiry_id = (select id from public.enquiries where reference = 'ENQ-000001')
$$, $$ values ('new', 'contacted', 'Called, will visit on Sunday') $$, 'status change saved with a note');

select * from finish();
rollback;
