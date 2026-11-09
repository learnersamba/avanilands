-- Local development seed (runs on `supabase db reset`).
-- NEVER run on production: test logins and made-up properties.
--
-- Test logins (local only):
--   super@avanilands.test   / LocalSuper#2611    Super Admin
--   admin@avanilands.test   / LocalAdmin#2611    Admin
--   visitor@avanilands.test / LocalVisitor#2611  signed-in non-admin (for security tests)
--
-- Fixed ids used by supabase/tests:
--   users      00000000-0000-4000-a000-00000000000{1,2,9}
--   locations  20000000-0000-4000-a000-0000000000NN
--   properties 10000000-0000-4000-a000-0000000000NN
--
-- Image paths point at seed/{property-id}/… in bucket property-media.
-- The files themselves are added in Phase 5 (placeholder artwork).

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
do $$
declare
  u record;
begin
  for u in
    select * from (values
      ('00000000-0000-4000-a000-000000000001'::uuid, 'super@avanilands.test', 'LocalSuper#2611', 'Sita Super', 'super_admin'::public.admin_role),
      ('00000000-0000-4000-a000-000000000002'::uuid, 'admin@avanilands.test', 'LocalAdmin#2611', 'Ravi Admin', 'admin'),
      ('00000000-0000-4000-a000-000000000009'::uuid, 'visitor@avanilands.test', 'LocalVisitor#2611', 'Vani Visitor', null)
    ) as t(id, email, password, name, role)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
      extensions.crypt(u.password, extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', jsonb_build_object('name', u.name), now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
            'email', now(), now(), now());
    if u.role is not null then
      insert into public.admin_users (user_id, full_name, email, role) values (u.id, u.name, u.email, u.role);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
update public.site_settings set
  phone = '+91 90000 00000',
  whatsapp = '919000000000',
  email = 'sales@avanilands.test',
  address = 'Door 1-2-3, Beach Road, Visakhapatnam, Andhra Pradesh 530017',
  office_hours = 'Mon–Sat, 9:30 am – 6:30 pm',
  sales_notify_emails = array['sales@avanilands.test'],
  seo_title = 'Avanilands — Verified land for sale in Andhra Pradesh',
  seo_description = 'Approved plots, agricultural and farm land sold directly by Avanilands. Clear titles, no brokers.';

-- ---------------------------------------------------------------------------
-- Locations (Kakinada is inactive, to test hiding)
-- ---------------------------------------------------------------------------
insert into public.locations (id, state, district, city, slug, description, is_popular, sort_order, is_active) values
  ('20000000-0000-4000-a000-000000000001', 'Andhra Pradesh', 'Visakhapatnam', 'Visakhapatnam', 'visakhapatnam',
   'The port city of Andhra Pradesh, growing fast along the Beach Road and NH-16 corridors.', true, 1, true),
  ('20000000-0000-4000-a000-000000000002', 'Andhra Pradesh', 'Anakapalli', 'Anakapalli', 'anakapalli',
   'Fertile farm land and the Atchutapuram industrial belt, 35 km from Visakhapatnam.', true, 2, true),
  ('20000000-0000-4000-a000-000000000003', 'Andhra Pradesh', 'Vizianagaram', 'Vizianagaram', 'vizianagaram',
   'Quiet town close to the new Bhogapuram airport.', true, 3, true),
  ('20000000-0000-4000-a000-000000000004', 'Andhra Pradesh', 'Srikakulam', 'Srikakulam', 'srikakulam',
   'Affordable plots in the northernmost district of Andhra Pradesh.', false, 4, true),
  ('20000000-0000-4000-a000-000000000005', 'Andhra Pradesh', 'Kakinada', 'Kakinada', 'kakinada',
   'Coming soon.', false, 5, false);

-- ---------------------------------------------------------------------------
-- Properties (all start as drafts; published below once they have photos)
-- ---------------------------------------------------------------------------
insert into public.properties (
  id, title, property_type_id, description, location_id, locality, address, pincode,
  latitude, longitude, show_exact_location, area_value, area_unit, length_ft, width_ft, dimensions_text,
  price_type, price, price_per_unit, price_per_unit_unit, is_negotiable, facing, road_width_ft, is_corner,
  water_available, water_source, electricity_available, approval_type, approval_number, rera_number,
  legal_notes, internal_notes, highlights, availability, is_featured, featured_rank
)
select
  v.id::uuid, v.title, (select t.id from public.property_types t where t.slug = v.type_slug), v.description,
  v.location_id::uuid, v.locality, v.address, v.pincode, v.lat, v.lng, v.exact, v.area_value,
  v.area_unit::public.area_unit, v.length_ft, v.width_ft, v.dimensions,
  v.price_type::public.price_type, v.price, v.ppu, v.ppu_unit::public.area_unit, v.negotiable,
  v.facing::public.facing, v.road_width, v.corner, v.water, v.water_source, v.electricity,
  v.approval::public.approval_type, v.approval_no, v.rera, v.legal, v.internal, v.highlights,
  v.availability::public.availability, v.featured, v.rank
from (values
  -- 01 Residential, Visakhapatnam, featured #1, exact location
  ('10000000-0000-4000-a000-000000000001', '200 Sq Yd East Facing Plot in Anandapuram', 'residential-plot',
   'A ready-to-build residential plot in a VMRDA-approved layout, 3 km from the Anandapuram junction on NH-16. Black-top roads, drainage and street lights are complete.',
   '20000000-0000-4000-a000-000000000001', 'Anandapuram', 'Plot 42, Green Meadows Layout, Anandapuram', '531163',
   17.871234, 83.374567, true, 200.000, 'sq_yd', 30.00, 60.00, '30 × 60 ft',
   'total', 3600000.00, 18000.00, 'sq_yd', true, 'east', 40.00, false,
   true, 'Municipal', true, 'vmrda', 'VMRDA/LP/123/2024', null,
   'Clear title. Registered sale deed and encumbrance certificate available.', 'Owner prefers full payment within 60 days.',
   array['East facing', '40 ft BT road', '3 km from NH-16', 'VMRDA approved'], 'available', true, 1),
  -- 02 Residential, cents, featured #2
  ('10000000-0000-4000-a000-000000000002', '25 Cent Residential Plot near NH-16', 'residential-plot',
   'Large corner plot in Bheemunipatnam, ideal for an independent house with garden. Five minutes from the beach road.',
   '20000000-0000-4000-a000-000000000001', 'Bheemunipatnam', 'Survey No. 88/2, Bheemunipatnam', '531163',
   17.889012, 83.451234, false, 25.000, 'cent', null, null, 'Irregular, corner',
   'total', 4500000.00, 180000.00, 'cent', false, 'north_east', 33.00, true,
   true, 'Borewell', true, 'panchayat', 'BMP/2023/45', null,
   'Patta and passbook available.', null,
   array['Corner plot', 'Near the beach', 'Panchayat approved'], 'available', true, 2),
  -- 03 Agricultural, acres
  ('10000000-0000-4000-a000-000000000003', '2 Acre Agricultural Land in Chodavaram', 'agricultural-land',
   'Fertile red soil with a working borewell and power connection. Currently growing sugarcane.',
   '20000000-0000-4000-a000-000000000002', 'Chodavaram', null, '531036',
   17.833456, 82.950123, false, 2.000, 'acre', null, null, null,
   'total', 7000000.00, 3500000.00, 'acre', true, null, 20.00, false,
   true, 'Borewell', true, 'not_applicable', null, null,
   'Patta, 1-B and adangal available.', 'Seller is NRI; power of attorney with brother.',
   array['Borewell with 3 HP motor', 'Red soil', 'Road access'], 'available', false, null),
  -- 04 Farm land, Vizianagaram, featured #3
  ('10000000-0000-4000-a000-000000000004', '1 Acre Managed Farm Land near Bhogapuram Airport', 'farm-land',
   'Managed farm plot with drip irrigation, fencing and a caretaker. Weekend farmhouse permitted.',
   '20000000-0000-4000-a000-000000000003', 'Bhogapuram', null, '535216',
   18.031234, 83.495678, false, 1.000, 'acre', null, null, null,
   'total', 3200000.00, null, null, false, null, 30.00, false,
   true, 'Drip irrigation', true, 'other', null, null,
   null, null,
   array['8 km from new airport', 'Drip irrigation', 'Caretaker included'], 'available', true, 3),
  -- 05 Commercial, price on request
  ('10000000-0000-4000-a000-000000000005', '600 Sq Yd Commercial Land on Gajuwaka Main Road', 'commercial-land',
   'Main road frontage, suitable for showroom or hospital.',
   '20000000-0000-4000-a000-000000000001', 'Gajuwaka', 'Main Road, Gajuwaka', '530026',
   17.690123, 83.210456, true, 600.000, 'sq_yd', 60.00, 90.00, '60 × 90 ft',
   'on_request', null, null, null, true, 'south', 80.00, false,
   true, 'Municipal', true, 'vmrda', 'VMRDA/BP/987/2022', null,
   null, null,
   array['80 ft main road', 'Commercial zone'], 'available', false, null),
  -- 06 Industrial, Anakapalli
  ('10000000-0000-4000-a000-000000000006', '3 Acre Industrial Land near Atchutapuram SEZ', 'industrial-land',
   'Level land in the industrial corridor with 3-phase power and a 60 ft approach road.',
   '20000000-0000-4000-a000-000000000002', 'Atchutapuram', null, '531011',
   17.560123, 82.970456, false, 3.000, 'acre', null, null, null,
   'total', 24000000.00, 8000000.00, 'acre', true, 'west', 60.00, false,
   false, null, true, 'apcrda', null, null,
   null, null,
   array['Industrial zone', '3-phase power', 'Near SEZ'], 'available', false, null),
  -- 07 Villa plot, reserved
  ('10000000-0000-4000-a000-000000000007', '300 Sq Yd Villa Plot in Gated Community, Madhurawada', 'villa-plot',
   'Premium villa plot in a gated community with clubhouse and 24×7 security.',
   '20000000-0000-4000-a000-000000000001', 'Madhurawada', 'Phase 2, Hill View Enclave, Madhurawada', '530048',
   17.820456, 83.350789, false, 300.000, 'sq_yd', 45.00, 60.00, '45 × 60 ft',
   'total', 5400000.00, 18000.00, 'sq_yd', false, 'north', 40.00, false,
   true, 'Municipal', true, 'rera', 'VMRDA/LP/456/2023', 'P02400012345',
   'RERA registered project.', null,
   array['Gated community', 'Clubhouse', 'RERA registered'], 'reserved', false, null),
  -- 08 Residential, Srikakulam, sold
  ('10000000-0000-4000-a000-000000000008', '167 Sq Yd Plot in Srikakulam Town', 'residential-plot',
   'Compact plot close to the bus stand and schools.',
   '20000000-0000-4000-a000-000000000004', 'Arasavalli', null, '532001',
   18.300123, 83.900456, false, 167.000, 'sq_yd', 30.00, 50.00, '30 × 50 ft',
   'total', 1800000.00, null, null, false, 'east', 30.00, false,
   true, 'Municipal', true, 'dtcp', 'DTCP/SKL/77/2021', null,
   null, null,
   array['Near bus stand'], 'sold', false, null),
  -- 09 Agricultural, guntas
  ('10000000-0000-4000-a000-000000000009', '20 Gunta Mango Orchard near Anakapalli', 'agricultural-land',
   'Half-acre mango orchard with 40 bearing trees.',
   '20000000-0000-4000-a000-000000000002', 'Kasimkota', null, '531031',
   17.700123, 82.990456, false, 20.000, 'gunta', null, null, null,
   'total', 2500000.00, null, null, true, null, null, false,
   true, 'Borewell', false, 'not_applicable', null, null,
   null, null,
   array['40 mango trees'], 'available', false, null),
  -- 10 Hidden
  ('10000000-0000-4000-a000-000000000010', '240 Sq Yd Plot in Vizianagaram (hidden)', 'residential-plot',
   'Hidden while documents are rechecked.',
   '20000000-0000-4000-a000-000000000003', 'Cantonment', null, '535003',
   18.110123, 83.400456, false, 240.000, 'sq_yd', null, null, null,
   'total', 2900000.00, null, null, false, 'south_east', 30.00, false,
   null, null, null, 'dtcp', null, null,
   null, 'Title query pending with lawyer.',
   '{}', 'available', false, null),
  -- 11 Draft (no photos yet)
  ('10000000-0000-4000-a000-000000000011', 'Draft: 500 Sq Yd Plot in Kommadi', 'residential-plot',
   null,
   '20000000-0000-4000-a000-000000000001', 'Kommadi', null, null,
   null, null, false, null, 'sq_yd', null, null, null,
   'total', null, null, null, false, null, null, false,
   null, null, null, 'not_applicable', null, null,
   null, null,
   '{}', 'available', false, null),
  -- 12 Archived
  ('10000000-0000-4000-a000-000000000012', 'Old Listing: 150 Sq Yd Plot in Pendurthi', 'residential-plot',
   'No longer offered.',
   '20000000-0000-4000-a000-000000000001', 'Pendurthi', null, '531173',
   17.800123, 83.200456, false, 150.000, 'sq_yd', null, null, null,
   'total', 1500000.00, null, null, false, 'west', 30.00, false,
   null, null, null, 'vmrda', null, null,
   null, null,
   '{}', 'available', false, null)
) as v(id, title, type_slug, description, location_id, locality, address, pincode, lat, lng, exact,
       area_value, area_unit, length_ft, width_ft, dimensions, price_type, price, ppu, ppu_unit, negotiable,
       facing, road_width, corner, water, water_source, electricity, approval, approval_no, rera, legal,
       internal, highlights, availability, featured, rank);

-- Photos: 3 per property (none for the draft).
insert into public.property_images (property_id, path_thumb, path_medium, path_large, width, height, alt_text)
select p.id,
       format('seed/%s/%s-thumb.webp', p.id, n),
       format('seed/%s/%s-medium.webp', p.id, n),
       format('seed/%s/%s-large.webp', p.id, n),
       2000, 1500,
       case n when 1 then p.title || ' — view of the plot' end
from public.properties p
cross join generate_series(1, 3) as n
where p.id <> '10000000-0000-4000-a000-000000000011'
order by p.id, n;

-- No sample videos: add a real property video from the admin panel to see the video section.

-- Documents: one public brochure and one private title deed on property 01.
insert into public.property_documents (property_id, doc_type, title, storage_path, mime_type, size_bytes, is_public) values
  ('10000000-0000-4000-a000-000000000001', 'brochure', 'Layout brochure',
   'seed/10000000-0000-4000-a000-000000000001/brochure.pdf', 'application/pdf', 524288, true),
  ('10000000-0000-4000-a000-000000000001', 'title_document', 'Registered sale deed',
   'seed/10000000-0000-4000-a000-000000000001/sale-deed.pdf', 'application/pdf', 1048576, false),
  ('10000000-0000-4000-a000-000000000010', 'brochure', 'Brochure of a hidden property',
   'seed/10000000-0000-4000-a000-000000000010/brochure.pdf', 'application/pdf', 524288, true);

-- Amenities.
insert into public.property_amenities (property_id, amenity_id)
select '10000000-0000-4000-a000-000000000001'::uuid, a.id from public.amenities a
where a.name in ('BT / CC roads', 'Underground drainage', 'Street lights', 'Water connection', 'Electricity connection')
union all
select '10000000-0000-4000-a000-000000000007'::uuid, a.id from public.amenities a
where a.name in ('Gated community', 'Compound wall', 'BT / CC roads', 'Park / open space', '24×7 security', 'Street lights')
union all
select '10000000-0000-4000-a000-000000000003'::uuid, a.id from public.amenities a
where a.name in ('Borewell', 'Electricity connection');

-- Nearby places.
insert into public.property_nearby_places (property_id, name, category, distance_km, sort_order) values
  ('10000000-0000-4000-a000-000000000001', 'NH-16 Anandapuram junction', 'highway', 3.0, 1),
  ('10000000-0000-4000-a000-000000000001', 'GITAM University', 'college', 9.5, 2),
  ('10000000-0000-4000-a000-000000000001', 'Visakhapatnam Airport', 'airport', 28.0, 3),
  ('10000000-0000-4000-a000-000000000007', 'Madhurawada bus stop', 'bus_stop', 1.2, 1);

-- Publish (the trigger checks for a cover photo and creates the slug).
update public.properties set publish_state = 'published'
where id not in ('10000000-0000-4000-a000-000000000010',
                 '10000000-0000-4000-a000-000000000011',
                 '10000000-0000-4000-a000-000000000012');
update public.properties set publish_state = 'hidden' where id = '10000000-0000-4000-a000-000000000010';
update public.properties set publish_state = 'archived' where id = '10000000-0000-4000-a000-000000000012';

-- Stagger publish dates so "newest" sorting is predictable: 01 newest … 09 oldest.
-- (The trigger normally keeps published_at fixed, so switch it off briefly.)
alter table public.properties disable trigger properties_before_write;
update public.properties
set published_at = now() - (right(id::text, 2)::int || ' days')::interval
where published_at is not null;
alter table public.properties enable trigger properties_before_write;

-- Sample enquiries.
select public.submit_enquiry('Lakshmi Devi', '+91 98765 43210', 'Is the price negotiable?',
  '10000000-0000-4000-a000-000000000001', 'lakshmi@example.com', 'whatsapp', 'property_page');
select public.submit_enquiry('Ravi Kumar', '9123456789', 'Please call me about farm land.',
  '10000000-0000-4000-a000-000000000004', null, 'phone', 'property_page');
select public.submit_enquiry('Anil Varma', '09988776655', 'Looking for commercial land in Vizag.',
  null, 'anil@example.com', 'email', 'contact_page');

-- Sample site visits (Phase 10), dated from today so they stay current:
-- one waiting for confirmation, one confirmed for tomorrow (reminder due),
-- one done last week.
insert into public.site_visits (property_id, name, phone, email, visitors, visit_date, slot, message, status)
values
  ('10000000-0000-4000-a000-000000000001', 'Lakshmi Devi', '9876543210', 'lakshmi@example.com', 2,
   (now() at time zone 'Asia/Kolkata')::date + 3, '10:00', 'Coming with my husband.', 'requested'),
  ('10000000-0000-4000-a000-000000000003', 'Prasad Rao', '9440012345', 'prasad@example.com', 1,
   (now() at time zone 'Asia/Kolkata')::date + 1, '15:00', null, 'confirmed'),
  ('10000000-0000-4000-a000-000000000004', 'Ravi Kumar', '9123456789', null, 3,
   (now() at time zone 'Asia/Kolkata')::date - 5, '12:00', 'Want to see the mango trees.', 'completed');

-- Sample bookings (Phase 13): AL-0007 is reserved because a booking holds it
-- (booking amount asked for); a request on AL-0006 waits for approval.
insert into public.bookings (property_id, source, name, phone, email, status, agreed_price, booking_amount,
                             approved_by, approved_at, created_by, assigned_to, created_at)
values
  ('10000000-0000-4000-a000-000000000007', 'admin', 'Kiran Reddy', '9440055667', 'kiran@example.com',
   'payment_pending', 5400000, 200000, '00000000-0000-4000-a000-000000000001', now() - interval '2 days',
   '00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000002', now() - interval '4 days'),
  ('10000000-0000-4000-a000-000000000006', 'admin', 'Sri Lakshmi Industries', '9866012345', 'accounts@srilakshmi.example',
   'pending_approval', null, null, null, null,
   '00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000002', now() - interval '1 day');

-- Demo website statistics (Phase 16) for the last 120 days, so the Analytics
-- page has something to show locally. Visitors are fake daily hashes.
select setseed(0.16);
with published as (
  select array_agg(p.id order by p.code) as ids, array_agg(p.slug order by p.code) as slugs, count(*)::int as n
  from public.properties p where p.publish_state = 'published'
), places as (
  select array_agg(l.slug order by l.sort_order, l.city) as slugs, count(*)::int as n from public.locations l
), visitors as (
  select d.day, v.n as num,
         encode(sha256(convert_to('demo:' || d.day || ':' || v.n, 'UTF8')), 'hex') as visitor,
         (array['mobile', 'mobile', 'mobile', 'mobile', 'desktop', 'desktop', 'tablet'])[1 + floor(random() * 7)::int] as device,
         (array[null, null, null, 'www.google.com', 'www.google.com', 'www.google.co.in', 'www.bing.com',
                'l.facebook.com', 'www.instagram.com', 'www.youtube.com', 'www.magicbricks.com'])[1 + floor(random() * 11)::int] as referrer,
         1 + floor(random() * 5)::int as pages
  from (select generate_series((now() at time zone 'Asia/Kolkata')::date - 119,
                               (now() at time zone 'Asia/Kolkata')::date, interval '1 day')::date as day) d
  cross join lateral generate_series(1, 14 + floor(random() * 20)::int
                                        + case when extract(isodow from d.day) >= 6 then 10 else 0 end) as v(n)
), pages as (
  select v.*, g.page, random() as pick, random() as which, random() as which2
  from visitors v cross join lateral generate_series(1, v.pages) as g(page)
)
insert into public.page_views (viewed_on, created_at, path, property_id, location_ids, type_ids, is_search,
                               entry, referrer_host, device, visitor)
select x.day,
       ((x.day + time '08:00' + x.page * interval '2 minutes' + x.num * interval '7 minutes')
         at time zone 'Asia/Kolkata'),
       x.path, x.property_id,
       coalesce((select array_agg(l.id) from public.locations l where l.slug = x.place), '{}'),
       '{}', x.place is not null, x.page = 1,
       case when x.page = 1 then x.referrer end, x.device, x.visitor
from (
  select pg.*,
         case when pg.pick < 0.45 then pp.ids[1 + floor(pp.n * pg.which ^ 2)::int] end as property_id,
         case when pg.pick >= 0.45 and pg.pick < 0.75 then pl.slugs[1 + floor(pl.n * pg.which ^ 2)::int] end as place,
         case
           when pg.pick < 0.45 then '/land/' || pp.slugs[1 + floor(pp.n * pg.which ^ 2)::int]
           when pg.pick < 0.62 then '/land'
           when pg.pick < 0.75 then '/land-for-sale/' || pl.slugs[1 + floor(pl.n * pg.which ^ 2)::int]
           when pg.pick < 0.90 then '/'
           else (array['/about', '/contact', '/faq'])[1 + floor(pg.which2 * 3)::int]
         end as path
  from pages pg, published pp, places pl
) x;

-- Website cache refresh (Phase 7): local website address and a local-only secret.
-- The same secret is REVALIDATE_SECRET in web/.env.local.
select vault.create_secret('http://host.docker.internal:3100/api/revalidate', 'website_revalidate_url');
select vault.create_secret('71365b10819b7d44749e7bd1c58d8230cb00224f2bd04b2e', 'website_revalidate_secret');
