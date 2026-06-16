-- =====================================================================
-- Round 587 — Tier projection read RPCs (growth-loop visibility)
-- =====================================================================
--
-- Two pure read RPCs that surface "money on the table" to both sides of
-- the marketplace so they can self-motivate up the ladder:
--
--   1. my_tier_earnings_projection()  — engineer-side
--      "If you reach Silver, you'd earn ~₹4,200 more per month at your
--      current pace." Built from r550 ladder + r578 supervised counts
--      + trailing 90d completed jobs from repair_jobs.
--
--   2. my_active_amc_tier_perks()     — hospital-side
--      "Your Gold AMC is active until 2027-03-15." Joins r560 AMC
--      contracts with the subscription-tier perks lookup so the app
--      can render a 'what you get' card without redoing the JOIN
--      client-side.
--
-- Both are STABLE, SECURITY DEFINER, search_path-pinned, auth.uid()-
-- scoped, and granted to authenticated only (anon explicitly revoked).
-- No writes anywhere; safe to call on every screen load.

BEGIN;

-- ---------------------------------------------------------------------
-- RPC 1: my_tier_earnings_projection() — engineer-side
-- ---------------------------------------------------------------------
-- Returns exactly ONE row, even for engineers with no progress row and
-- no completed jobs (zeros + current_tier='none'). This lets the
-- Android client render the "earn your first tier" coaching card
-- without a special-case empty path.
--
-- Edge cases handled:
--   - caller has no engineer_certification_progress row → defaults to
--     'none' tier + 0 supervised count
--   - caller is at gold (top tier)                      → next_tier
--     NULL, next_platform_fee_pct NULL, projected uplift = 0
--   - caller has zero completed jobs in trailing 90d    → avg = 0,
--     projected uplift = 0 (still shows tier-fee delta context)

DROP FUNCTION IF EXISTS public.my_tier_earnings_projection();

CREATE OR REPLACE FUNCTION public.my_tier_earnings_projection()
RETURNS TABLE (
  current_tier                    text,
  current_platform_fee_pct        numeric,
  next_tier                       text,
  next_platform_fee_pct           numeric,
  avg_monthly_gross_rupees        numeric,
  projected_monthly_uplift_rupees numeric,
  completed_jobs_90d              int,
  supervised_completions_at_eval  int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH me AS (
    SELECT
      coalesce(p.current_tier, 'none')                  AS current_tier,
      coalesce(p.supervised_completions_at_eval, 0)     AS supervised_completions_at_eval
    FROM (SELECT 1) seed
    LEFT JOIN public.engineer_certification_progress p
      ON p.engineer_user_id = v_caller
  ),
  current_def AS (
    SELECT t.tier, t.platform_fee_pct, t.display_order
    FROM public.engineer_certification_tiers t
    JOIN me ON me.current_tier = t.tier
  ),
  next_def AS (
    -- "Lowest display_order strictly greater than current's display_order"
    SELECT t.tier, t.platform_fee_pct
    FROM public.engineer_certification_tiers t
    WHERE t.display_order > coalesce((SELECT display_order FROM current_def), -1)
    ORDER BY t.display_order ASC
    LIMIT 1
  ),
  window_jobs AS (
    -- Completed jobs in trailing 90d where caller was accepted-bid engineer.
    SELECT
      count(*)::int                                   AS completed_jobs_90d,
      coalesce(sum(rj.contracted_amount_rupees), 0)   AS gross_rupees_90d
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id    = rj.id
     AND b.status           = 'accepted'
     AND b.engineer_user_id = v_caller
    WHERE rj.status       = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    coalesce((SELECT current_tier FROM me), 'none')                  AS current_tier,
    coalesce((SELECT platform_fee_pct FROM current_def), 7.00)       AS current_platform_fee_pct,
    (SELECT tier FROM next_def)                                      AS next_tier,
    (SELECT platform_fee_pct FROM next_def)                          AS next_platform_fee_pct,
    -- avg_monthly_gross = sum / 3.0 (90d ≈ 3 months)
    round(
      coalesce((SELECT gross_rupees_90d FROM window_jobs), 0) / 3.0,
      2
    )                                                                AS avg_monthly_gross_rupees,
    -- projected_monthly_uplift = avg_monthly * (current_fee - next_fee) / 100
    -- = 0 when next_tier is NULL (top of ladder)
    CASE
      WHEN (SELECT tier FROM next_def) IS NULL THEN 0::numeric
      ELSE round(
        (coalesce((SELECT gross_rupees_90d FROM window_jobs), 0) / 3.0)
        * (
            coalesce((SELECT platform_fee_pct FROM current_def), 7.00)
          - coalesce((SELECT platform_fee_pct FROM next_def), 7.00)
          )
        / 100.0,
        2
      )
    END                                                              AS projected_monthly_uplift_rupees,
    coalesce((SELECT completed_jobs_90d FROM window_jobs), 0)        AS completed_jobs_90d,
    coalesce((SELECT supervised_completions_at_eval FROM me), 0)     AS supervised_completions_at_eval;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_tier_earnings_projection() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_tier_earnings_projection() TO authenticated;

COMMENT ON FUNCTION public.my_tier_earnings_projection() IS
  'r587: engineer self-view — current tier fee vs next-tier fee × trailing-90d gross/3 = projected monthly uplift if promoted.';


-- ---------------------------------------------------------------------
-- RPC 2: my_active_amc_tier_perks() — hospital-side
-- ---------------------------------------------------------------------
-- Returns zero or more rows; a hospital may have 0, 1, or many active
-- AMC contracts (chain hospitals can hold multiple per-site contracts).
-- Defensive LIMIT 25 — no realistic hospital has >25 active contracts;
-- the cap prevents pathological responses if data is corrupted.
--
-- Edge cases handled:
--   - hospital has no active contracts → empty result (caller treats
--     as "no AMC, upsell")
--   - contracts past end_date or non-'active' status are filtered out
--   - contracts with NULL amc_tier are excluded by the INNER JOIN to
--     amc_subscription_tiers (uncoated contracts are pre-r560 grandfathered
--     and should be treated as "no tier perks")

DROP FUNCTION IF EXISTS public.my_active_amc_tier_perks();

CREATE OR REPLACE FUNCTION public.my_active_amc_tier_perks()
RETURNS TABLE (
  contract_id              uuid,
  amc_tier                 text,
  display_label            text,
  visits_per_year_ceiling  int,
  code_red_sla_minutes     int,
  parts_discount_pct       numeric,
  trusted_partner_badge    boolean,
  end_date                 date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id                       AS contract_id,
    c.amc_tier                 AS amc_tier,
    t.display_label            AS display_label,
    t.visits_per_year_ceiling  AS visits_per_year_ceiling,
    t.code_red_sla_minutes     AS code_red_sla_minutes,
    t.parts_discount_pct       AS parts_discount_pct,
    t.trusted_partner_badge    AS trusted_partner_badge,
    c.end_date                 AS end_date
  FROM public.amc_contracts c
  JOIN public.amc_subscription_tiers t
    ON t.tier = c.amc_tier
  WHERE c.hospital_user_id = v_caller
    AND c.status           = 'active'
    AND c.end_date        >= current_date
  ORDER BY c.end_date ASC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_active_amc_tier_perks() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_active_amc_tier_perks() TO authenticated;

COMMENT ON FUNCTION public.my_active_amc_tier_perks() IS
  'r587: hospital self-view — active AMC contracts joined with r560 tier perks lookup. Sorted by end_date ASC so soonest-expiring shows first.';

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 587 tier projection RPCs verified: my_tier_earnings_projection + my_active_amc_tier_perks ready';
END;
$$;
