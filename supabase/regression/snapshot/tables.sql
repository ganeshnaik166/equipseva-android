-- Truth snapshot: every ordinary table in schema public with its RLS flags and
-- the table-level privileges each API role holds.
--
-- Why this exists: a table created without ENABLE ROW LEVEL SECURITY is readable
-- by every authenticated user through PostgREST, and a grant added for debugging
-- silently survives. Both were found by hand in past audits; this row set makes
-- them a diff. The runner sorts on `table_name` and writes TSV.
--
-- Read-only. Works on the local stack and on prod via `supabase db query --linked`.
select
  c.relname                                   as table_name,
  c.relrowsecurity                            as rls_enabled,
  c.relforcerowsecurity                       as rls_forced,
  pg_get_userbyid(c.relowner)                 as owner,
  (select count(*) from pg_policy pol where pol.polrelid = c.oid) as policy_count,
  has_table_privilege('anon',          c.oid, 'SELECT') as anon_select,
  has_table_privilege('anon',          c.oid, 'INSERT') as anon_insert,
  has_table_privilege('anon',          c.oid, 'UPDATE') as anon_update,
  has_table_privilege('anon',          c.oid, 'DELETE') as anon_delete,
  has_table_privilege('authenticated', c.oid, 'SELECT') as auth_select,
  has_table_privilege('authenticated', c.oid, 'INSERT') as auth_insert,
  has_table_privilege('authenticated', c.oid, 'UPDATE') as auth_update,
  has_table_privilege('authenticated', c.oid, 'DELETE') as auth_delete,
  has_table_privilege('service_role',  c.oid, 'SELECT') as service_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
order by 1;
