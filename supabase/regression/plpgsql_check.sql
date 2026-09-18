-- plpgsql_check sweep over every plpgsql function in schema public.
--
-- Why this exists: a wrong column name, a renamed table or an impossible cast in
-- a plpgsql body is not a syntax error. It compiles, it ships, and it only raises
-- when that line is finally reached — which for a founder-gated branch can be
-- never, or once, at 2am. A manual sweep in an earlier round took 576 broken
-- functions down to 15 accounted-for ones, and nothing pinned the result.
--
-- HOW TO RUN. `plpgsql_check` is available on the project but not installed, so
-- this script installs it, sweeps, and the teardown at the bottom removes it
-- again — net zero. Run the three parts as three separate `supabase db query
-- --linked -f` invocations (the CLI returns only the last statement's rows, and
-- the sweep needs several calls to stay inside statement_timeout):
--
--   1. everything up to the SWEEP marker, once      (installs + scaffolds)
--   2. the chunk call, repeatedly until done = targets  (~2000 per call, ~25s)
--   3. the TRIGGER SWEEP, once, then the REPORT, then the TEARDOWN
--
-- Per-function isolation matters: plpgsql_check itself raises on a function it
-- cannot analyse, and one such raise would abort a whole chunk and hide every
-- finding in it. A "could not check" is recorded as exactly that — it must never
-- read as "checked and clean".
--
-- Trigger functions are the trap. plpgsql_check refuses a trigger function with
-- 22023 unless it is given the relation the trigger fires on, and there were 77
-- of them. Sweeping them properly is how round 3825's defect was found, so the
-- trigger pass below is not optional.

-- ============================== SETUP ==============================
CREATE EXTENSION IF NOT EXISTS plpgsql_check WITH SCHEMA extensions;

DROP TABLE IF EXISTS public._eqs_pc_findings;
CREATE TABLE public._eqs_pc_findings (
  fn_oid oid not null, signature text not null, level text, message text,
  detail text, sqlstate text, swept_at timestamptz not null default now()
);
REVOKE ALL ON public._eqs_pc_findings FROM PUBLIC, anon, authenticated;

DROP TABLE IF EXISTS public._eqs_pc_progress;
CREATE TABLE public._eqs_pc_progress (
  fn_oid oid primary key, checked_at timestamptz not null default now(), errored text
);
REVOKE ALL ON public._eqs_pc_progress FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._eqs_pc_sweep(p_limit int)
RETURNS int
LANGUAGE plpgsql
SET search_path = public, extensions, pg_temp
AS $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.oid::regprocedure::text AS sig
      FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
     WHERE p.pronamespace = 'public'::regnamespace AND l.lanname = 'plpgsql' AND p.prokind = 'f'
       AND NOT EXISTS (SELECT 1 FROM public._eqs_pc_progress g WHERE g.fn_oid = p.oid)
     ORDER BY p.oid LIMIT p_limit
  LOOP
    BEGIN
      INSERT INTO public._eqs_pc_findings (fn_oid, signature, level, message, detail, sqlstate)
      SELECT r.oid, r.sig, c.level, c.message, c.detail, c.sqlstate
        FROM extensions.plpgsql_check_function_tb(r.oid) c;
      INSERT INTO public._eqs_pc_progress (fn_oid) VALUES (r.oid);
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO public._eqs_pc_progress (fn_oid, errored) VALUES (r.oid, SQLSTATE || ' ' || SQLERRM);
    END;
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;
REVOKE ALL ON FUNCTION public._eqs_pc_sweep(int) FROM PUBLIC, anon, authenticated;

-- ============================== SWEEP ==============================
-- Repeat until `done` equals `targets`.
select jsonb_pretty(jsonb_build_object(
  'swept',   public._eqs_pc_sweep(2000),
  'done',    (select count(*) from public._eqs_pc_progress),
  'targets', (select count(*) from pg_proc p join pg_language l on l.oid=p.prolang
               where p.pronamespace='public'::regnamespace and l.lanname='plpgsql' and p.prokind='f'),
  'findings',(select count(*) from public._eqs_pc_findings),
  'checker_errors', (select count(*) from public._eqs_pc_progress where errored is not null)
)) as progress;

-- ========================== TRIGGER SWEEP ==========================
DROP TABLE IF EXISTS public._eqs_pc_trig;
CREATE TABLE public._eqs_pc_trig (
  signature text, relname text, level text, message text, detail text, sqlstate text, checker_error text
);
REVOKE ALL ON public._eqs_pc_trig FROM PUBLIC, anon, authenticated;

DO $sweep$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT p.oid AS fnoid, p.oid::regprocedure::text AS sig,
           t.tgrelid AS relid, t.tgrelid::regclass::text AS relname
      FROM pg_proc p
      JOIN pg_trigger t ON t.tgfoid = p.oid
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE p.pronamespace = 'public'::regnamespace AND NOT t.tgisinternal AND n.nspname = 'public'
     ORDER BY 2, 4
  LOOP
    BEGIN
      INSERT INTO public._eqs_pc_trig (signature, relname, level, message, detail, sqlstate)
      SELECT r.sig, r.relname, c.level, c.message, c.detail, c.sqlstate
        FROM extensions.plpgsql_check_function_tb(r.fnoid, r.relid) c;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO public._eqs_pc_trig (signature, relname, checker_error)
      VALUES (r.sig, r.relname, SQLSTATE || ' ' || SQLERRM);
    END;
  END LOOP;
END;
$sweep$;

-- ============================== REPORT ==============================
-- Compare this against allow/plpgsql_errors.txt; any signature+sqlstate not in
-- that file is a new finding and must be fixed or added with a written reason.
select signature || E'\t' || coalesce(level,'') || E'\t' || coalesce(sqlstate,'') || E'\t'
       || replace(coalesce(message,''), E'\n', ' ') as row
  from public._eqs_pc_findings where level = 'error'
union all
select signature || ' @' || relname || E'\t' || coalesce(level,'') || E'\t' || coalesce(sqlstate,'') || E'\t'
       || replace(coalesce(message,''), E'\n',' ')
  from public._eqs_pc_trig where level = 'error'
order by 1;

-- ============================= TEARDOWN =============================
-- Leave nothing behind. Run this even if the sweep failed half way.
DROP FUNCTION IF EXISTS public._eqs_pc_sweep(int);
DROP TABLE IF EXISTS public._eqs_pc_findings;
DROP TABLE IF EXISTS public._eqs_pc_progress;
DROP TABLE IF EXISTS public._eqs_pc_trig;
DROP EXTENSION IF EXISTS plpgsql_check;
