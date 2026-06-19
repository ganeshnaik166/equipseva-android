BEGIN;
-- r1383: Founder customer onboarding funnel
-- Per-hospital onboarding lifecycle tracker: lead -> qualified -> contract -> kyc -> first-visit -> active
-- Surfaces conversion %, median days to activation, blockers, and lead-source mix.



-- ---------------------------------------------------------------------------
-- Table: founder_hospital_onboarding_runs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_hospital_onboarding_runs (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id             uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  funnel_stage                text DEFAULT 'lead' CHECK (funnel_stage IN (
                                'lead','qualified','contract_signed','kyc_complete',
                                'first_visit_scheduled','first_visit_completed',
                                'active','dormant','churned')),
  stage_entered_at            timestamptz DEFAULT now(),
  lead_source                 text,
  kyc_completed_at            timestamptz,
  contract_signed_at          timestamptz,
  first_visit_completed_at    timestamptz,
  activated_at                timestamptz,
  churned_at                  timestamptz,
  blocker_reason              text,
  owner_user_id               uuid REFERENCES auth.users(id),
  notes                       text,
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),
  UNIQUE(hospital_org_id)
);

CREATE INDEX IF NOT EXISTS founder_hospital_onboarding_runs_stage_idx
  ON public.founder_hospital_onboarding_runs(funnel_stage);
CREATE INDEX IF NOT EXISTS founder_hospital_onboarding_runs_entered_idx
  ON public.founder_hospital_onboarding_runs(stage_entered_at DESC);
CREATE INDEX IF NOT EXISTS founder_hospital_onboarding_runs_source_idx
  ON public.founder_hospital_onboarding_runs(lead_source);

ALTER TABLE public.founder_hospital_onboarding_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_hospital_onboarding_runs_founder_all
  ON public.founder_hospital_onboarding_runs;
CREATE POLICY founder_hospital_onboarding_runs_founder_all
  ON public.founder_hospital_onboarding_runs
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- RPC: founder_customer_onboarding_funnel_summary
-- 16 KPIs of funnel state across all hospitals.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_customer_onboarding_funnel_summary();
CREATE OR REPLACE FUNCTION public.founder_customer_onboarding_funnel_summary()
RETURNS TABLE (
  total_runs                            bigint,
  lead_count                            bigint,
  qualified_count                       bigint,
  contract_signed_count                 bigint,
  kyc_complete_count                    bigint,
  first_visit_scheduled_count           bigint,
  first_visit_completed_count           bigint,
  active_count                          bigint,
  dormant_count                         bigint,
  churned_count                         bigint,
  conversion_pct_lead_to_active         numeric,
  conversion_pct_contract_to_active     numeric,
  median_days_lead_to_active            numeric,
  blocked_count                         bigint,
  top_lead_source                       text,
  generated_at                          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_hospital_onboarding_runs
  ),
  src AS (
    SELECT lead_source, count(*) AS n
      FROM base
     WHERE lead_source IS NOT NULL
     GROUP BY lead_source
     ORDER BY n DESC
     LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM base)::bigint                                                              AS total_runs,
    (SELECT count(*) FROM base WHERE funnel_stage = 'lead')::bigint                                  AS lead_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'qualified')::bigint                             AS qualified_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'contract_signed')::bigint                       AS contract_signed_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'kyc_complete')::bigint                          AS kyc_complete_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'first_visit_scheduled')::bigint                 AS first_visit_scheduled_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'first_visit_completed')::bigint                 AS first_visit_completed_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'active')::bigint                                AS active_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'dormant')::bigint                               AS dormant_count,
    (SELECT count(*) FROM base WHERE funnel_stage = 'churned')::bigint                               AS churned_count,
    CASE
      WHEN (SELECT count(*) FROM base) > 0
      THEN round(100.0 * (SELECT count(*) FROM base WHERE funnel_stage = 'active')
                / NULLIF((SELECT count(*) FROM base), 0), 2)
      ELSE 0
    END                                                                                              AS conversion_pct_lead_to_active,
    CASE
      WHEN (SELECT count(*) FROM base WHERE contract_signed_at IS NOT NULL) > 0
      THEN round(100.0 * (SELECT count(*) FROM base WHERE funnel_stage = 'active' AND contract_signed_at IS NOT NULL)
                / NULLIF((SELECT count(*) FROM base WHERE contract_signed_at IS NOT NULL), 0), 2)
      ELSE 0
    END                                                                                              AS conversion_pct_contract_to_active,
    COALESCE((
      SELECT round(
        (percentile_cont(0.5) WITHIN GROUP (
           ORDER BY extract(epoch FROM (activated_at - created_at)) / 86400.0
        ))::numeric, 1)
        FROM base
       WHERE activated_at IS NOT NULL
    ), 0)                                                                                            AS median_days_lead_to_active,
    (SELECT count(*) FROM base WHERE blocker_reason IS NOT NULL AND blocker_reason <> '')::bigint    AS blocked_count,
    (SELECT lead_source FROM src)                                                                    AS top_lead_source,
    now()                                                                                            AS generated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_customer_onboarding_funnel_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_customer_onboarding_funnel_summary() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: founder_customer_onboarding_funnel_recent
-- Recent run ledger (optionally filtered by stage).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_customer_onboarding_funnel_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_customer_onboarding_funnel_recent(
  p_stage text DEFAULT NULL,
  p_limit int  DEFAULT 100
)
RETURNS TABLE (
  id                          uuid,
  hospital_org_id             uuid,
  hospital_name               text,
  hospital_city               text,
  funnel_stage                text,
  stage_entered_at            timestamptz,
  lead_source                 text,
  kyc_completed_at            timestamptz,
  contract_signed_at          timestamptz,
  first_visit_completed_at    timestamptz,
  activated_at                timestamptz,
  churned_at                  timestamptz,
  blocker_reason              text,
  notes                       text,
  age_days                    numeric,
  created_at                  timestamptz,
  updated_at                  timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.hospital_org_id,
    o.name                                                                AS hospital_name,
    o.city                                                                AS hospital_city,
    r.funnel_stage,
    r.stage_entered_at,
    r.lead_source,
    r.kyc_completed_at,
    r.contract_signed_at,
    r.first_visit_completed_at,
    r.activated_at,
    r.churned_at,
    r.blocker_reason,
    r.notes,
    round((extract(epoch FROM (now() - r.created_at)) / 86400.0)::numeric, 1) AS age_days,
    r.created_at,
    r.updated_at
  FROM public.founder_hospital_onboarding_runs r
  LEFT JOIN public.organizations o ON o.id = r.hospital_org_id
  WHERE (p_stage IS NULL OR r.funnel_stage = p_stage)
  ORDER BY r.stage_entered_at DESC NULLS LAST, r.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_customer_onboarding_funnel_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_customer_onboarding_funnel_recent(text, int) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: log_founder_onboarding_register
-- Register (or no-op) a hospital into the funnel at the lead stage.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_onboarding_register(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_onboarding_register(
  p_org_id      uuid,
  p_lead_source text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'p_org_id required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.founder_hospital_onboarding_runs (hospital_org_id, lead_source)
  VALUES (p_org_id, p_lead_source)
  ON CONFLICT (hospital_org_id) DO UPDATE
    SET lead_source = COALESCE(EXCLUDED.lead_source, public.founder_hospital_onboarding_runs.lead_source),
        updated_at  = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_onboarding_register(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_onboarding_register(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC: log_founder_onboarding_advance
-- Advance a run to a new stage; stamps the matching timestamp.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_onboarding_advance(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_onboarding_advance(
  p_id             uuid,
  p_new_stage      text,
  p_blocker_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL OR p_new_stage IS NULL THEN
    RAISE EXCEPTION 'p_id and p_new_stage required' USING ERRCODE = '22023';
  END IF;

  IF p_new_stage NOT IN ('lead','qualified','contract_signed','kyc_complete',
                         'first_visit_scheduled','first_visit_completed',
                         'active','dormant','churned') THEN
    RAISE EXCEPTION 'invalid stage %', p_new_stage USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_hospital_onboarding_runs
     SET funnel_stage             = p_new_stage,
         stage_entered_at         = now(),
         blocker_reason           = p_blocker_reason,
         kyc_completed_at         = CASE WHEN p_new_stage = 'kyc_complete'           AND kyc_completed_at         IS NULL THEN now() ELSE kyc_completed_at         END,
         contract_signed_at       = CASE WHEN p_new_stage = 'contract_signed'        AND contract_signed_at       IS NULL THEN now() ELSE contract_signed_at       END,
         first_visit_completed_at = CASE WHEN p_new_stage = 'first_visit_completed'  AND first_visit_completed_at IS NULL THEN now() ELSE first_visit_completed_at END,
         activated_at             = CASE WHEN p_new_stage = 'active'                 AND activated_at             IS NULL THEN now() ELSE activated_at             END,
         churned_at               = CASE WHEN p_new_stage = 'churned'                AND churned_at               IS NULL THEN now() ELSE churned_at               END,
         updated_at               = now()
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_onboarding_advance(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_onboarding_advance(uuid, text, text) TO authenticated;

COMMIT;