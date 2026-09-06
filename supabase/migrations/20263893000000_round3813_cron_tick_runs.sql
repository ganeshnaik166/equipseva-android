-- =====================================================================
-- Round 3813 -- cron_tick_runs: persist every scheduled-run outcome
-- =====================================================================
--
-- WHY: the first post-deploy cron-tick-daily run (2026-09-06 07:43 UTC)
-- FAILED, and the only record of WHICH slot failed and WHY is the HTTP
-- body cron-tick returned into that GitHub run's log -- which requires
-- GitHub auth to read. From the database side there was NO evidence at
-- all: this project runs zero pg_cron, so there is no cron.job_run_details
-- to consult. The diagnosis had to be made by re-executing all 24 daily
-- RPCs by hand (all clean) and inferring a transient PostgREST
-- schema-cache reload from timing. Inference is not a run log.
--
-- This table is the run log. cron-tick appends one row per invocation --
-- slot group, ok flag, every per-slot result including error_code for the
-- failures, wall time -- as a best-effort write that can never fail the
-- run itself. Effects:
--   * a failing slot is diagnosable with one SELECT, no GitHub access
--   * the founder /cron-status page finally has real data to show
--     (founder_cron_status() reads pg_cron, which does not exist here)
--   * "did the daily group run today?" stops being a question
--
-- SECURITY: service_role (the only writer) bypasses RLS. Reads are
-- founder-only via is_founder(); authenticated has no grant at all, so
-- there is no per-row policy surface for engineers/hospitals.
-- Retention: rows are tiny; a purge lives in the daily group's existing
-- retention sweeps' spirit but is deliberately NOT added here -- at ~30
-- rows/day this is years before it matters, and the audit value of a full
-- history outweighs it for now.

BEGIN;

CREATE TABLE IF NOT EXISTS public.cron_tick_runs (
  id           bigserial PRIMARY KEY,
  slot         text        NOT NULL,          -- group or single slot requested
  targets      text[]      NOT NULL DEFAULT '{}',
  ok           boolean     NOT NULL,
  failed_slots text[]      NOT NULL DEFAULT '{}',
  results      jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- per-slot {slot, ok, rows|error_code, duration_ms}
  duration_ms  integer,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cron_tick_runs_created_idx ON public.cron_tick_runs (created_at DESC);
CREATE INDEX IF NOT EXISTS cron_tick_runs_failed_idx  ON public.cron_tick_runs (created_at DESC) WHERE NOT ok;

ALTER TABLE public.cron_tick_runs ENABLE ROW LEVEL SECURITY;

-- Supabase default privileges would otherwise hand anon/authenticated
-- table grants on creation (the round3791 lesson applies to tables too).
REVOKE ALL ON public.cron_tick_runs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.cron_tick_runs TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.cron_tick_runs_id_seq TO service_role;
GRANT SELECT ON public.cron_tick_runs TO authenticated;   -- gated by the policy below

DROP POLICY IF EXISTS cron_tick_runs_founder_read ON public.cron_tick_runs;
CREATE POLICY cron_tick_runs_founder_read ON public.cron_tick_runs
  FOR SELECT TO authenticated
  USING (public.is_founder());

COMMENT ON TABLE public.cron_tick_runs IS
  'round3813: one row per cron-tick edge-function invocation (the pg_cron substitute). Written best-effort by the function with service_role; founder-readable. Query failed_slots/results.error_code to diagnose a red scheduled run without GitHub access.';

-- Founder-facing reader for the console: recent runs, newest first.
CREATE OR REPLACE FUNCTION public.founder_cron_tick_recent(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id bigint, slot text, ok boolean, failed_slots text[], targets_count integer,
  duration_ms integer, created_at timestamptz, results jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.slot, r.ok, r.failed_slots,
         coalesce(array_length(r.targets, 1), 0)::integer AS targets_count,
         r.duration_ms, r.created_at, r.results
    FROM public.cron_tick_runs r
   ORDER BY r.created_at DESC
   LIMIT greatest(1, least(coalesce(p_limit, 50), 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_cron_tick_recent(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cron_tick_recent(integer) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- VERIFY (inside the transaction; a write probe that is rolled back)
-- ---------------------------------------------------------------------
DO $gate$
DECLARE v_n int; v_anon boolean; v_auth_ins boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname='cron_tick_runs'
                   AND relnamespace='public'::regnamespace AND relrowsecurity) THEN
    RAISE EXCEPTION 'round 3813 VERIFY FAILED: RLS not enabled';
  END IF;
  -- anon must have nothing; authenticated must not be able to write
  SELECT has_table_privilege('anon', 'public.cron_tick_runs', 'SELECT') INTO v_anon;
  SELECT has_table_privilege('authenticated', 'public.cron_tick_runs', 'INSERT') INTO v_auth_ins;
  IF v_anon OR v_auth_ins THEN
    RAISE EXCEPTION 'round 3813 VERIFY FAILED: grants too wide (anon select=% auth insert=%)', v_anon, v_auth_ins;
  END IF;
  -- service_role write probe, rolled back via sentinel
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
    INSERT INTO public.cron_tick_runs (slot, targets, ok, failed_slots, results, duration_ms)
    VALUES ('probe', ARRAY['x'], false, ARRAY['x'], '[{"slot":"x","ok":false,"error_code":"PROBE"}]'::jsonb, 1);
    SELECT count(*) INTO v_n FROM public.cron_tick_runs WHERE slot='probe';
    IF v_n <> 1 THEN RAISE EXCEPTION 'round 3813 VERIFY FAILED: probe insert not visible'; END IF;
    -- founder reader sees it; a plain authenticated non-founder must not
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                        'email','ganesh1431.dhanavath@gmail.com')::text, true);
    SELECT count(*) INTO v_n FROM public.founder_cron_tick_recent(5) WHERE slot='probe';
    IF v_n <> 1 THEN RAISE EXCEPTION 'round 3813 VERIFY FAILED: founder reader did not return the probe row'; END IF;
    RAISE EXCEPTION 'R3813_PROBE_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'R3813_PROBE_ROLLBACK' THEN RAISE; END IF;
  END;
  SELECT count(*) INTO v_n FROM public.cron_tick_runs WHERE slot='probe';
  IF v_n <> 0 THEN RAISE EXCEPTION 'round 3813 VERIFY FAILED: probe row leaked'; END IF;
  RAISE NOTICE 'round 3813 verified: table + RLS + grants + founder reader, write probe rolled back';
END
$gate$;

COMMIT;
