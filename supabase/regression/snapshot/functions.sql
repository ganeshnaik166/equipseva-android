-- Truth snapshot: every function in schema public, one row per overload.
--
-- Why this exists: SECURITY DEFINER RPCs have shipped without GRANT EXECUTE TO
-- authenticated more than once (every real caller then gets 42501, silently), and
-- Supabase's default privileges publish EXECUTE on any freshly created function
-- to anon/authenticated unless the migration revokes it. Neither mistake is
-- visible in a green migration run; both are visible in this row set. The runner
-- sorts on `signature` and writes the rows as TSV so a diff against the committed
-- baseline is one object per line.
--
-- Read-only. Works on the local stack and on prod via `supabase db query --linked`.
select
  p.oid::regprocedure::text                         as signature,
  l.lanname                                         as language,
  p.prokind                                         as kind,
  p.prosecdef                                       as security_definer,
  p.provolatile                                     as volatility,
  pg_get_userbyid(p.proowner)                       as owner,
  coalesce(array_to_string(p.proconfig, ' '), '')   as proconfig,
  (select bool_or(a.grantee = 0)
     from unnest(coalesce(p.proacl, array[]::aclitem[])) x, aclexplode(array[x]) a
    where a.privilege_type = 'EXECUTE')             as exec_public,
  has_function_privilege('anon',          p.oid, 'EXECUTE') as exec_anon,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as exec_authenticated,
  has_function_privilege('service_role',  p.oid, 'EXECUTE') as exec_service_role,
  md5(replace(p.prosrc, E'\r\n', E'\n'))            as body_md5
from pg_proc p
join pg_language l on l.oid = p.prolang
where p.pronamespace = 'public'::regnamespace
order by 1;
