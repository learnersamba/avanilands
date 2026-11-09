-- Phase 9 security review: visitors (anon) still had Supabase's default
-- insert/update/delete/truncate grants on the publicly readable tables.
-- Row level security refused the writes, but it does not apply to TRUNCATE,
-- so take the grants away, and stop new tables from getting them.
revoke insert, update, delete, truncate on all tables in schema public from anon;
revoke truncate on all tables in schema public from authenticated;

alter default privileges in schema public revoke insert, update, delete, truncate on tables from anon;
alter default privileges in schema public revoke truncate on tables from authenticated;
