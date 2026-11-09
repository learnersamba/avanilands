-- Adds 500 published "Load test" properties for speed checks (local only).
-- Remove them with:  delete from public.properties where title like 'Load test%';
-- Run:  docker exec -i supabase_db_avanilands psql -U postgres -f - < tool/load_test_properties.sql

do $$
declare
  v_id uuid;
  v_types smallint[] := array(select id from public.property_types order by id);
  v_locations uuid[] := array(select id from public.locations where is_active order by sort_order);
  v_units public.area_unit[] := array['sq_yd', 'cent', 'acre', 'gunta', 'sq_ft']::public.area_unit[];
  v_facings public.facing[] := array['north', 'south', 'east', 'west', 'north_east', 'south_west']::public.facing[];
  v_photo record;
begin
  -- Reuse an existing sample photo for every test property.
  select path_thumb, path_medium, path_large into v_photo
  from public.property_images where path_thumb like 'seed/%' limit 1;

  for n in 1..500 loop
    insert into public.properties (
      title, property_type_id, location_id, locality, area_value, area_unit,
      price_type, price, facing, road_width_ft, approval_type, highlights, is_negotiable, description
    ) values (
      format('Load test plot %s near %s', n, (array['the highway', 'the beach', 'the airport', 'the town'])[1 + n % 4]),
      v_types[1 + n % array_length(v_types, 1)],
      v_locations[1 + (n * 7) % array_length(v_locations, 1)],
      (array['Anandapuram', 'Madhurawada', 'Kommadi', 'Sabbavaram', 'Pendurthi'])[1 + n % 5],
      (50 + (n * 37) % 950)::numeric / case when n % 5 = 2 then 100 else 1 end,
      v_units[1 + n % 5],
      case when n % 17 = 0 then 'on_request'::public.price_type else 'total'::public.price_type end,
      case when n % 17 = 0 then null else 500000 + (n * 104729) % 30000000 end,
      v_facings[1 + n % 6],
      (array[20, 30, 33, 40, 60, 80])[1 + n % 6],
      (array['dtcp', 'vmrda', 'panchayat', 'not_applicable'])[1 + n % 4]::public.approval_type,
      array['Test highlight'],
      n % 3 = 0,
      'Generated for a speed test.'
    ) returning id into v_id;

    insert into public.property_images (property_id, path_thumb, path_medium, path_large, width, height)
    values (v_id, v_photo.path_thumb, v_photo.path_medium, v_photo.path_large, 2000, 1500);

    if n % 4 = 0 then
      insert into public.property_amenities (property_id, amenity_id)
      select v_id, id from public.amenities order by id limit 1 + n % 3;
    end if;

    update public.properties
    set publish_state = 'published',
        availability = (array['available', 'available', 'available', 'reserved', 'sold'])[1 + n % 5]::public.availability
    where id = v_id;
  end loop;
end;
$$;
