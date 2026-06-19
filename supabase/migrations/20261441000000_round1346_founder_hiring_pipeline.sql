BEGIN;
-- r1340 — Founder hiring pipeline tracker.
-- Internal recruiting surface. Tracks engineer + ops candidate funnel
-- (sourced → applied → screened → interview → offered → onboarding → active),
-- per-candidate timestamps, source attribution, conversion + cycle-time KPIs.
-- Strictly founder-only. Not customer-facing.

-- ============================================================================
-- TABLE: founder_hiring_candidates
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_hiring_candidates (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_name        text NOT NULL,
  candidate_phone       text UNIQUE,
  candidate_city        text,
  role                  text NOT NULL DEFAULT 'biomedical_engineer' CHECK (role IN (
                          'biomedical_engineer','field_supervisor','operations_lead',
                          'sales','marketing','founder_admin','other')),
  source                text CHECK (source IN (
                          'referral','linkedin','naukri','indeed','college','direct','other')),
  funnel_stage          text NOT NULL DEFAULT 'sourced' CHECK (funnel_stage IN (
                          'sourced','applied','screened','interview_1','interview_2',
                          'offered','onboarding','active','rejected','withdrawn')),
  sourced_at            timestamptz NOT NULL DEFAULT now(),
  applied_at            timestamptz,
  interview_at          timestamptz,
  offered_at            timestamptz,
  onboarded_at          timestamptz,
  active_at             timestamptz,
  rejected_at           timestamptz,
  rejected_reason       text,
  expected_tier         text,
  notes                 text,
  recruiter_user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_hiring_candidates IS
  'Founder-only recruiting funnel. Engineer + ops candidate pipeline. Not customer-facing.';

CREATE INDEX IF NOT EXISTS idx_founder_hiring_stage   ON public.founder_hiring_candidates (funnel_stage, sourced_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_hiring_source  ON public.founder_hiring_candidates (source, sourced_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_hiring_role    ON public.founder_hiring_candidates (role, sourced_at DESC);

ALTER TABLE public.founder_hiring_candidates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_hiring_no_direct ON public.founder_hiring_candidates;
CREATE POLICY founder_hiring_no_direct ON public.founder_hiring_candidates FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_hiring_candidates FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC: founder_hiring_pipeline_summary — 15 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hiring_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_hiring_pipeline_summary()
RETURNS TABLE (
  total_candidates                 bigint,
  sourced_count                    bigint,
  applied_count                    bigint,
  screened_count                   bigint,
  interviewed_count                bigint,
  offered_count                    bigint,
  onboarding_count                 bigint,
  active_count                     bigint,
  rejected_count                   bigint,
  withdrawn_count                  bigint,
  conversion_pct_sourced_to_active numeric,
  conversion_pct_applied_to_active numeric,
  median_days_sourced_to_active    numeric,
  top_source                       text,
  top_source_count                 bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total       bigint;
  v_active      bigint;
  v_applied     bigint;
  v_median_days numeric;
  v_top_src     text;
  v_top_src_n   bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT count(*) INTO v_total FROM public.founder_hiring_candidates;
  SELECT count(*) INTO v_active FROM public.founder_hiring_candidates WHERE funnel_stage='active';
  SELECT count(*) INTO v_applied FROM public.founder_hiring_candidates WHERE applied_at IS NOT NULL;

  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (active_at - sourced_at))/86400.0)
    INTO v_median_days
    FROM public.founder_hiring_candidates
    WHERE active_at IS NOT NULL AND sourced_at IS NOT NULL;

  SELECT source, count(*)
    INTO v_top_src, v_top_src_n
    FROM public.founder_hiring_candidates
    WHERE source IS NOT NULL
    GROUP BY source
    ORDER BY count(*) DESC NULLS LAST
    LIMIT 1;

  RETURN QUERY
  SELECT
    v_total,
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='sourced'),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='applied'),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='screened'),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage IN ('interview_1','interview_2')),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='offered'),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='onboarding'),
    v_active,
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='rejected'),
    (SELECT count(*) FROM public.founder_hiring_candidates WHERE funnel_stage='withdrawn'),
    CASE WHEN v_total=0 THEN 0 ELSE ROUND(100.0 * v_active / v_total, 2) END,
    CASE WHEN v_applied=0 THEN 0 ELSE ROUND(100.0 * v_active / v_applied, 2) END,
    COALESCE(ROUND(v_median_days, 1), 0),
    COALESCE(v_top_src, 'n/a'),
    COALESCE(v_top_src_n, 0::bigint);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_hiring_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hiring_pipeline_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_hiring_pipeline_candidates(p_limit) — candidate ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hiring_pipeline_candidates(int);
CREATE OR REPLACE FUNCTION public.founder_hiring_pipeline_candidates(p_limit int DEFAULT 100)
RETURNS TABLE (
  id              uuid,
  candidate_name  text,
  candidate_phone text,
  candidate_city  text,
  role            text,
  source          text,
  funnel_stage    text,
  sourced_at      timestamptz,
  applied_at      timestamptz,
  offered_at      timestamptz,
  active_at       timestamptz,
  rejected_at     timestamptz,
  rejected_reason text,
  expected_tier   text,
  days_in_funnel  numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.candidate_name,
    c.candidate_phone,
    c.candidate_city,
    c.role,
    c.source,
    c.funnel_stage,
    c.sourced_at,
    c.applied_at,
    c.offered_at,
    c.active_at,
    c.rejected_at,
    c.rejected_reason,
    c.expected_tier,
    ROUND(EXTRACT(EPOCH FROM (COALESCE(c.active_at, c.rejected_at, now()) - c.sourced_at))/86400.0, 1)
  FROM public.founder_hiring_candidates c
  ORDER BY
    CASE c.funnel_stage
      WHEN 'offered'     THEN 1
      WHEN 'interview_2' THEN 2
      WHEN 'interview_1' THEN 3
      WHEN 'screened'    THEN 4
      WHEN 'onboarding'  THEN 5
      WHEN 'applied'     THEN 6
      WHEN 'sourced'     THEN 7
      WHEN 'active'      THEN 8
      ELSE 9
    END,
    c.sourced_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_hiring_pipeline_candidates(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hiring_pipeline_candidates(int) TO authenticated;

-- ============================================================================
-- RPC: founder_hiring_pipeline_by_source — source breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hiring_pipeline_by_source();
CREATE OR REPLACE FUNCTION public.founder_hiring_pipeline_by_source()
RETURNS TABLE (
  source            text,
  candidates        bigint,
  active            bigint,
  rejected          bigint,
  in_pipeline       bigint,
  conversion_pct    numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(c.source, 'unspecified'),
    count(*),
    count(*) FILTER (WHERE c.funnel_stage='active'),
    count(*) FILTER (WHERE c.funnel_stage IN ('rejected','withdrawn')),
    count(*) FILTER (WHERE c.funnel_stage NOT IN ('active','rejected','withdrawn')),
    CASE WHEN count(*)=0 THEN 0
         ELSE ROUND(100.0 * count(*) FILTER (WHERE c.funnel_stage='active') / count(*), 2)
    END
  FROM public.founder_hiring_candidates c
  GROUP BY COALESCE(c.source, 'unspecified')
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_hiring_pipeline_by_source() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hiring_pipeline_by_source() TO authenticated;

-- ============================================================================
-- WRITE RPC: log_founder_hiring_register
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_hiring_register(text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_hiring_register(
  p_name   text,
  p_phone  text,
  p_city   text,
  p_role   text,
  p_source text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_name IS NULL OR length(trim(p_name))=0 THEN
    RAISE EXCEPTION 'candidate_name required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_hiring_candidates (candidate_name, candidate_phone, candidate_city, role, source, recruiter_user_id)
  VALUES (trim(p_name), NULLIF(trim(p_phone), ''), NULLIF(trim(p_city), ''),
          COALESCE(p_role, 'biomedical_engineer'), p_source, auth.uid())
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hiring_register(text, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hiring_register(text, text, text, text, text) TO authenticated;

-- ============================================================================
-- WRITE RPC: log_founder_hiring_advance
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_hiring_advance(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_hiring_advance(
  p_candidate_id uuid,
  p_new_stage    text,
  p_note         text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_stage NOT IN ('sourced','applied','screened','interview_1','interview_2','offered','onboarding','active','rejected','withdrawn') THEN
    RAISE EXCEPTION 'invalid funnel_stage %', p_new_stage USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_hiring_candidates SET
    funnel_stage   = p_new_stage,
    applied_at     = CASE WHEN p_new_stage='applied'     AND applied_at   IS NULL THEN now() ELSE applied_at   END,
    interview_at   = CASE WHEN p_new_stage IN ('interview_1','interview_2') AND interview_at IS NULL THEN now() ELSE interview_at END,
    offered_at     = CASE WHEN p_new_stage='offered'     AND offered_at   IS NULL THEN now() ELSE offered_at   END,
    onboarded_at   = CASE WHEN p_new_stage='onboarding'  AND onboarded_at IS NULL THEN now() ELSE onboarded_at END,
    active_at      = CASE WHEN p_new_stage='active'      AND active_at    IS NULL THEN now() ELSE active_at    END,
    notes          = CASE WHEN p_note IS NOT NULL THEN COALESCE(notes || E'\n', '') || p_note ELSE notes END,
    updated_at     = now()
  WHERE id = p_candidate_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hiring_advance(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hiring_advance(uuid, text, text) TO authenticated;

-- ============================================================================
-- WRITE RPC: log_founder_hiring_reject
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_hiring_reject(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_hiring_reject(
  p_candidate_id uuid,
  p_reason       text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_hiring_candidates SET
    funnel_stage    = 'rejected',
    rejected_at     = COALESCE(rejected_at, now()),
    rejected_reason = COALESCE(p_reason, rejected_reason),
    updated_at      = now()
  WHERE id = p_candidate_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_hiring_reject(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_hiring_reject(uuid, text) TO authenticated;

COMMIT;