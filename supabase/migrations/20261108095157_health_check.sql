-- Phase 0: a tiny function both apps call to prove they can reach the database.
create or replace function public.health()
returns text
language sql
stable
set search_path = ''
as $$
  select 'ok'::text;
$$;

revoke all on function public.health() from public;
grant execute on function public.health() to anon, authenticated;
