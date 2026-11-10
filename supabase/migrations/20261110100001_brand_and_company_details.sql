-- Brand and company details (docs/DECISIONS.md 130). The tagline, the line under the
-- logo and the parent company were written in the website code; now the Super Admin
-- edits them in Settings. Registered address, GST and RERA numbers are optional and
-- shown in the footer, on Contact and on the legal pages when filled in.

alter table public.site_settings
  add column legal_name         text not null default 'Tirupa Technologies Pvt. Ltd.'
                                  check (length(btrim(legal_name)) between 1 and 120),
  add column tagline            text not null default 'Find Your Space. Build Your Future.'
                                  check (length(btrim(tagline)) between 1 and 80),
  add column descriptor         text not null default 'Real Estate & Property Platform'
                                  check (length(btrim(descriptor)) between 1 and 60),
  add column registered_address text check (length(registered_address) <= 300),
  add column gst_number         text check (gst_number ~ '^[0-9A-Z]{15}$'),
  add column rera_number        text check (length(rera_number) <= 60);

-- Columns can only be added at the end of a view. Everything here is meant for the public.
create or replace view public.public_site_settings as
select company_name, phone, whatsapp, email, address, office_hours, social_links,
       seo_title, seo_description,
       visit_days, visit_slots,
       array(select d from unnest(visit_closed_dates) d
             where d > (now() at time zone 'Asia/Kolkata')::date order by d) as visit_closed_dates,
       visit_days_ahead,
       legal_name, tagline, descriptor, registered_address, gst_number, rera_number
from public.site_settings
where id = 1;
