-- Truth snapshot: every row-level security policy in schema public with the
-- exact USING / WITH CHECK text and the roles it applies to.
--
-- Why this exists: a policy that quietly widens (a dropped `auth.uid() =`
-- comparison, a `true` USING clause, a missing WITH CHECK on INSERT) is a
-- cross-tenant leak that no migration error will ever report. Capturing the
-- normalised expression text turns any such change into a one-line diff. The
-- runner sorts on (table_name, policy_name) and writes TSV.
--
-- Read-only. Works on the local stack and on prod via `supabase db query --linked`.
select
  pol.tablename                                         as table_name,
  pol.policyname                                        as policy_name,
  pol.cmd                                               as command,
  pol.permissive                                        as permissive,
  coalesce(array_to_string(pol.roles, ','), '')         as roles,
  regexp_replace(coalesce(pol.qual, ''),       '\s+', ' ', 'g') as using_expr,
  regexp_replace(coalesce(pol.with_check, ''), '\s+', ' ', 'g') as with_check_expr
from pg_policies pol
where pol.schemaname = 'public'
order by 1, 2;
