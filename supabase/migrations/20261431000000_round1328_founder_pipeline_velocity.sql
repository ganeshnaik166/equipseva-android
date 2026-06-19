BEGIN;
-- r1328 — Founder pipeline velocity tracker.
-- Read-only aggregator across hospital_chains (sales pipeline funnel) and
-- amc_contracts (closed-won lifecycle). NO new tables.
--
-- Pipeline stage mapping:
--   prospects        = hospital_chains.status IN ('prospecting')
--   in_negotiation   = hospital_chains.status IN ('negotiating')
--   signed_not_active= hospital_chains.status IN ('signed','onboarding')
--   active           = hospital_chains.status IN ('live','active')
--                      OR amc_contracts.status = 'active'
--   paused           = hospital_chains.status IN ('paused')
--                      OR amc_contracts.status IN ('paused','renewal_failed')
--   churned_30d      = hospital_chains.status IN ('churned','offboarded')
--                      OR amc_contracts.status IN ('cancelled','expired')
--                      WHERE deactivated_at > now() - 30 days
--
-- Velocity windows derived from amc_contracts created_at, activated_at,
-- deactivated_at. days_lead_to_signed = activated_at - created_at proxy.

DROP FUNCTION IF EXISTS public.founder_pipeline_velocity_summary();
CREATE OR REPLACE FUNCTION public.founder_pipeline_velocity_summary()
RETURNS TABLE (
  pipeline_total_prospects        bigint,
  pipeline_in_negotiation         bigint,
  pipeline_signed_not_active      bigint,
  pipeline_active                 bigint,
  pipeline_paused                 bigint,
  pipeline_churned_30d            bigint,
  median_days_lead_to_signed      numeric,
  median_days_signed_to_active    numeric,
  median_days_active_lifetime     numeric,
  win_rate_pct_30d                numeric,
  win_rate_pct_90d                numeric,
  total_pipeline_value_rupees     numeric,
  qualified_pipeline_value_rupees numeric,
  closed_won_value_30d_rupees     numeric,
  cycle_time_p50_days             numeric,
  cycle_time_p90_days             numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_chain_prospects bigint;
  v_chain_negotiate bigint;
  v_chain_signed    bigint;
  v_chain_active    bigint;
  v_chain_paused    bigint;
  v_chain_churned   bigint;
  v_amc_active      bigint;
  v_amc_paused      bigint;
  v_amc_churned     bigint;
  v_med_lead_signed numeric;
  v_med_sign_active numeric;
  v_med_lifetime    numeric;
  v_win_30          numeric;
  v_win_90          numeric;
  v_total_val       numeric;
  v_qualified_val   numeric;
  v_closed_30       numeric;
  v_cycle_p50       numeric;
  v_cycle_p90       numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT
    count(*) FILTER (WHERE c.status = 'prospecting'),
    count(*) FILTER (WHERE c.status = 'negotiating'),
    count(*) FILTER (WHERE c.status IN ('signed','onboarding')),
    count(*) FILTER (WHERE c.status IN ('live','active')),
    count(*) FILTER (WHERE c.status = 'paused'),
    count(*) FILTER (WHERE c.status IN ('churned','offboarded')
                      AND c.updated_at > now() - interval '30 days')
  INTO v_chain_prospects, v_chain_negotiate, v_chain_signed,
       v_chain_active, v_chain_paused, v_chain_churned
  FROM public.hospital_chains c;

  SELECT
    count(*) FILTER (WHERE status = 'active'),
    count(*) FILTER (WHERE status IN ('paused','renewal_failed')),
    count(*) FILTER (WHERE status IN ('cancelled','expired')
                      AND deactivated_at > now() - interval '30 days')
  INTO v_amc_active, v_amc_paused, v_amc_churned
  FROM public.amc_contracts;

  SELECT
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (activated_at - created_at))/86400.0
    )
  INTO v_med_lead_signed
  FROM public.amc_contracts
  WHERE activated_at IS NOT NULL
    AND activated_at >= created_at
    AND created_at > now() - interval '180 days';

  SELECT
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (activated_at - created_at))/86400.0
    )
  INTO v_med_sign_active
  FROM public.amc_contracts
  WHERE activated_at IS NOT NULL
    AND activated_at >= created_at;

  SELECT
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (COALESCE(deactivated_at, now()) - activated_at))/86400.0
    )
  INTO v_med_lifetime
  FROM public.amc_contracts
  WHERE activated_at IS NOT NULL;

  WITH win_30 AS (
    SELECT
      count(*) FILTER (WHERE activated_at > now() - interval '30 days')::numeric AS won,
      count(*) FILTER (WHERE created_at    > now() - interval '30 days')::numeric AS opened
    FROM public.amc_contracts
  )
  SELECT
    CASE WHEN opened > 0 THEN round((won * 100.0) / opened, 2) ELSE 0 END
  INTO v_win_30 FROM win_30;

  WITH win_90 AS (
    SELECT
      count(*) FILTER (WHERE activated_at > now() - interval '90 days')::numeric AS won,
      count(*) FILTER (WHERE created_at    > now() - interval '90 days')::numeric AS opened
    FROM public.amc_contracts
  )
  SELECT
    CASE WHEN opened > 0 THEN round((won * 100.0) / opened, 2) ELSE 0 END
  INTO v_win_90 FROM win_90;

  SELECT
    COALESCE(SUM(
      COALESCE(default_monthly_fee_rupees, 0)
      * GREATEST(COALESCE(total_hospitals_target, 1), 1)
      * 12
    ), 0)::numeric
  INTO v_total_val
  FROM public.hospital_chains
  WHERE status IN ('prospecting','negotiating','signed','onboarding');

  SELECT
    COALESCE(SUM(
      COALESCE(default_monthly_fee_rupees, 0)
      * GREATEST(COALESCE(total_hospitals_target, 1), 1)
      * 12
    ), 0)::numeric
  INTO v_qualified_val
  FROM public.hospital_chains
  WHERE status IN ('negotiating','signed','onboarding');

  SELECT
    COALESCE(SUM(monthly_fee_rupees * 12), 0)::numeric
  INTO v_closed_30
  FROM public.amc_contracts
  WHERE activated_at > now() - interval '30 days';

  SELECT
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (activated_at - created_at))/86400.0
    ),
    percentile_cont(0.9) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (activated_at - created_at))/86400.0
    )
  INTO v_cycle_p50, v_cycle_p90
  FROM public.amc_contracts
  WHERE activated_at IS NOT NULL
    AND activated_at >= created_at
    AND created_at > now() - interval '365 days';

  RETURN QUERY SELECT
    (v_chain_prospects)::bigint,
    (v_chain_negotiate)::bigint,
    (v_chain_signed)::bigint,
    (v_chain_active + v_amc_active)::bigint,
    (v_chain_paused + v_amc_paused)::bigint,
    (v_chain_churned + v_amc_churned)::bigint,
    COALESCE(v_med_lead_signed, 0)::numeric,
    COALESCE(v_med_sign_active, 0)::numeric,
    COALESCE(v_med_lifetime, 0)::numeric,
    COALESCE(v_win_30, 0)::numeric,
    COALESCE(v_win_90, 0)::numeric,
    COALESCE(v_total_val, 0)::numeric,
    COALESCE(v_qualified_val, 0)::numeric,
    COALESCE(v_closed_30, 0)::numeric,
    COALESCE(v_cycle_p50, 0)::numeric,
    COALESCE(v_cycle_p90, 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pipeline_velocity_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pipeline_velocity_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_pipeline_velocity_by_chain(int);
CREATE OR REPLACE FUNCTION public.founder_pipeline_velocity_by_chain(p_limit int DEFAULT 30)
RETURNS TABLE (
  chain_id                 uuid,
  chain_name               text,
  stage                    text,
  default_amc_tier         text,
  default_monthly_fee_rupees numeric,
  total_hospitals_target   int,
  hospitals_onboarded_count int,
  pipeline_value_rupees    numeric,
  days_in_current_stage    int,
  created_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.status::text,
    c.default_amc_tier::text,
    c.default_monthly_fee_rupees,
    c.total_hospitals_target,
    c.hospitals_onboarded_count,
    (COALESCE(c.default_monthly_fee_rupees, 0)
      * GREATEST(COALESCE(c.total_hospitals_target, 1), 1)
      * 12)::numeric,
    GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(c.updated_at, c.created_at)))::int),
    c.created_at
  FROM public.hospital_chains c
  ORDER BY
    CASE c.status
      WHEN 'negotiating' THEN 1
      WHEN 'signed'      THEN 2
      WHEN 'onboarding'  THEN 3
      WHEN 'prospecting' THEN 4
      WHEN 'live'        THEN 5
      WHEN 'active'      THEN 6
      WHEN 'paused'      THEN 7
      WHEN 'churned'     THEN 8
      WHEN 'offboarded'  THEN 9
      ELSE 99
    END,
    c.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pipeline_velocity_by_chain(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pipeline_velocity_by_chain(int) TO authenticated;

COMMIT;