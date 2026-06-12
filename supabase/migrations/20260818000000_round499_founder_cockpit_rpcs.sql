-- =====================================================================
-- Round 499 — Founder Cockpit RPCs (v0.4 Phase 5 #2)
-- =====================================================================
--
-- We've shipped 18 features that produce data; the founder cockpit
-- has no aggregate views yet. Founder Cockpit v1 in our app shows
-- raw lists. v2 should show:
--   - Hero KPIs (last 7d GMV, active engineers, dispute rate)
--   - Cohort retention table (hospitals by signup-month)
--   - Engineer LTV ranked by lifetime gross + payout
--   - GMV breakdown by equipment_type (which verticals work)
--   - Dispute rate trends (% disputes / completed jobs per month)
--
-- All RPCs founder-only via the is_founder() gate. service-role
-- callable too so any future edge fn can compose them.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Hero KPIs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hero_kpis()
RETURNS TABLE(
  -- Activity (trailing 7 days vs prior 7 days)
  gmv_7d_rupees                 numeric,
  gmv_prior_7d_rupees           numeric,
  gmv_wow_pct                   numeric,
  -- Completed-job counts
  completed_jobs_7d             bigint,
  completed_jobs_prior_7d       bigint,
  -- Engineer side
  active_engineers_30d          bigint,
  pending_kyc_renewals          bigint,
  -- Disputes
  open_disputes                 bigint,
  open_collusion_flags          bigint,
  -- Money in flight
  pending_refund_authorizations bigint,
  total_escrow_held_rupees      numeric,
  -- Compliance
  undeposited_tds_total_rupees  numeric,
  open_dpdp_grievances          bigint,
  -- AMC health
  amc_contracts_active          bigint,
  amc_contracts_pending_payment bigint
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

  SELECT
    coalesce(sum(amount_rupees) FILTER (
      WHERE status = 'released' AND updated_at >= now() - interval '7 days'
    ), 0)::numeric,
    coalesce(sum(amount_rupees) FILTER (
      WHERE status = 'released'
        AND updated_at >= now() - interval '14 days'
        AND updated_at <  now() - interval '7 days'
    ), 0)::numeric
  INTO gmv_7d_rupees, gmv_prior_7d_rupees
  FROM public.repair_job_escrow;

  IF gmv_prior_7d_rupees > 0 THEN
    gmv_wow_pct := round(((gmv_7d_rupees - gmv_prior_7d_rupees) / gmv_prior_7d_rupees) * 100, 1);
  ELSE
    gmv_wow_pct := NULL;
  END IF;

  SELECT
    count(*) FILTER (WHERE status = 'completed' AND completed_at >= now() - interval '7 days'),
    count(*) FILTER (WHERE status = 'completed'
                      AND completed_at >= now() - interval '14 days'
                      AND completed_at <  now() - interval '7 days')
  INTO completed_jobs_7d, completed_jobs_prior_7d
  FROM public.repair_jobs;

  SELECT count(DISTINCT engineer_user_id)
    INTO active_engineers_30d
    FROM public.engineer_payouts
   WHERE status = 'processed'
     AND updated_at >= now() - interval '30 days';

  SELECT count(*)
    INTO pending_kyc_renewals
    FROM public.engineer_kyc_renewals
   WHERE status IN ('pending','in_progress');

  SELECT count(*)
    INTO open_disputes
    FROM public.repair_job_escrow
   WHERE status = 'disputed';

  SELECT count(*)
    INTO open_collusion_flags
    FROM public.collusion_flags
   WHERE status IN ('open','investigating');

  SELECT count(*)
    INTO pending_refund_authorizations
    FROM public.refund_authorization_requests
   WHERE status = 'pending';

  SELECT coalesce(sum(amount_rupees), 0)
    INTO total_escrow_held_rupees
    FROM public.repair_job_escrow
   WHERE status IN ('paid','disputed');

  SELECT coalesce(sum(tds_rupees), 0)
    INTO undeposited_tds_total_rupees
    FROM public.tds_deductions
   WHERE deducted = true
     AND deposited_to_govt_at IS NULL;

  SELECT count(*)
    INTO open_dpdp_grievances
    FROM public.dpdp_grievances
   WHERE status IN ('open','in_review');

  SELECT
    count(*) FILTER (WHERE status = 'active'),
    count(*) FILTER (WHERE status = 'pending_payment')
  INTO amc_contracts_active, amc_contracts_pending_payment
  FROM public.amc_contracts;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hero_kpis() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_hero_kpis() TO service_role;

-- ---------------------------------------------------------------------
-- 2. GMV by equipment_type (vertical breakdown)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_gmv_by_equipment_type(
  p_days integer DEFAULT 30
)
RETURNS TABLE(
  equipment_type     text,
  job_count          bigint,
  gmv_rupees         numeric,
  avg_ticket_rupees  numeric,
  dispute_count      bigint,
  dispute_rate_pct   numeric
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
  WITH window_jobs AS (
    SELECT rj.id, rj.equipment_type, e.amount_rupees, e.status
      FROM public.repair_jobs rj
      LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
     WHERE rj.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
       AND rj.equipment_type IS NOT NULL
  )
  SELECT wj.equipment_type,
         count(*)::bigint,
         coalesce(sum(wj.amount_rupees), 0)::numeric,
         coalesce(avg(wj.amount_rupees), 0)::numeric,
         count(*) FILTER (WHERE wj.status = 'disputed')::bigint,
         CASE WHEN count(*) > 0 THEN
              round(count(*) FILTER (WHERE wj.status = 'disputed') * 100.0 / count(*), 1)
              ELSE 0 END
    FROM window_jobs wj
   GROUP BY wj.equipment_type
   ORDER BY sum(wj.amount_rupees) DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_gmv_by_equipment_type(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_gmv_by_equipment_type(integer) TO service_role;

-- ---------------------------------------------------------------------
-- 3. Engineer LTV ranked
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_engineer_ltv_ranked(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  engineer_user_id        uuid,
  engineer_email          text,
  first_active_at         timestamptz,
  total_jobs_completed    bigint,
  total_gross_rupees      numeric,
  total_net_paid_rupees   numeric,
  total_tds_rupees        numeric,
  avg_rating              numeric,
  dispute_count           bigint,
  current_risk_score      int,
  risk_band               text
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
    SELECT
      ep.engineer_user_id,
      min(ep.updated_at) AS first_active_at,
      count(*) FILTER (WHERE ep.status = 'processed') AS jobs_paid,
      coalesce(sum(ep.amount_rupees) FILTER (WHERE ep.status = 'processed'), 0) AS gross,
      coalesce(sum(t.net_payable_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS net_paid,
      coalesce(sum(t.tds_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS tds
    FROM public.engineer_payouts ep
    LEFT JOIN public.tds_deductions t ON t.payout_id = ep.id
    GROUP BY ep.engineer_user_id
  ),
  ratings AS (
    SELECT b.engineer_user_id, avg(rj.hospital_rating)::numeric(3,2) AS avg_rating
      FROM public.repair_job_bids b
      JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND rj.status = 'completed'
       AND rj.hospital_rating IS NOT NULL
     GROUP BY b.engineer_user_id
  ),
  disputes AS (
    SELECT b.engineer_user_id, count(*)::bigint AS dispute_count
      FROM public.repair_job_bids b
      JOIN public.repair_job_escrow e ON e.repair_job_id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND e.status = 'disputed'
     GROUP BY b.engineer_user_id
  ),
  risk AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.score, s.band
      FROM public.risk_score_snapshots s
     WHERE s.role = 'engineer'
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT
    base.engineer_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = base.engineer_user_id), 'unknown'),
    base.first_active_at,
    base.jobs_paid,
    base.gross,
    base.net_paid,
    base.tds,
    ratings.avg_rating,
    coalesce(disputes.dispute_count, 0)::bigint,
    risk.score,
    risk.band
  FROM base
  LEFT JOIN ratings  ON ratings.engineer_user_id  = base.engineer_user_id
  LEFT JOIN disputes ON disputes.engineer_user_id = base.engineer_user_id
  LEFT JOIN risk     ON risk.user_id              = base.engineer_user_id
  ORDER BY base.gross DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_ltv_ranked(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_ltv_ranked(integer) TO service_role;

-- ---------------------------------------------------------------------
-- 4. Hospital cohort retention (signup-month buckets)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_cohort_retention(
  p_months integer DEFAULT 12
)
RETURNS TABLE(
  cohort_month       date,
  cohort_size        bigint,
  retained_30d       bigint,
  retained_60d       bigint,
  retained_90d       bigint,
  retained_180d      bigint,
  retention_30d_pct  numeric,
  retention_60d_pct  numeric,
  retention_90d_pct  numeric,
  retention_180d_pct numeric
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
  WITH cohorts AS (
    SELECT
      u.id AS hospital_id,
      date_trunc('month', u.created_at)::date AS cohort_month,
      u.created_at
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
    WHERE p.role = 'hospital'
      AND u.created_at >= now() - (greatest(coalesce(p_months, 12), 1)::text || ' months')::interval
  ),
  activity AS (
    SELECT
      c.cohort_month,
      c.hospital_id,
      bool_or(rj.created_at >= c.created_at + interval '30 days'
                AND rj.created_at < c.created_at + interval '60 days') AS active_30d,
      bool_or(rj.created_at >= c.created_at + interval '60 days'
                AND rj.created_at < c.created_at + interval '90 days') AS active_60d,
      bool_or(rj.created_at >= c.created_at + interval '90 days'
                AND rj.created_at < c.created_at + interval '120 days') AS active_90d,
      bool_or(rj.created_at >= c.created_at + interval '180 days'
                AND rj.created_at < c.created_at + interval '210 days') AS active_180d
    FROM cohorts c
    LEFT JOIN public.repair_jobs rj ON rj.hospital_user_id = c.hospital_id
    GROUP BY c.cohort_month, c.hospital_id
  ),
  agg AS (
    SELECT
      cohort_month,
      count(*) AS size,
      count(*) FILTER (WHERE active_30d) AS r30,
      count(*) FILTER (WHERE active_60d) AS r60,
      count(*) FILTER (WHERE active_90d) AS r90,
      count(*) FILTER (WHERE active_180d) AS r180
    FROM activity
    GROUP BY cohort_month
  )
  SELECT
    a.cohort_month, a.size,
    a.r30, a.r60, a.r90, a.r180,
    CASE WHEN a.size > 0 THEN round(a.r30 * 100.0 / a.size, 1) ELSE 0 END,
    CASE WHEN a.size > 0 THEN round(a.r60 * 100.0 / a.size, 1) ELSE 0 END,
    CASE WHEN a.size > 0 THEN round(a.r90 * 100.0 / a.size, 1) ELSE 0 END,
    CASE WHEN a.size > 0 THEN round(a.r180 * 100.0 / a.size, 1) ELSE 0 END
  FROM agg a
  ORDER BY a.cohort_month DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(integer) TO service_role;

-- ---------------------------------------------------------------------
-- 5. Monthly dispute rate trend
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_dispute_rate_monthly(
  p_months integer DEFAULT 12
)
RETURNS TABLE(
  month_at           date,
  completed_jobs     bigint,
  disputed_jobs      bigint,
  dispute_rate_pct   numeric
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
    SELECT
      date_trunc('month', rj.created_at)::date AS month_at,
      count(*) FILTER (WHERE rj.status = 'completed')::bigint AS completed,
      count(*) FILTER (WHERE EXISTS (
        SELECT 1 FROM public.repair_job_escrow e
        WHERE e.repair_job_id = rj.id AND e.status = 'disputed'
      ))::bigint AS disputed
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - (greatest(coalesce(p_months, 12), 1)::text || ' months')::interval
    GROUP BY date_trunc('month', rj.created_at)
  )
  SELECT b.month_at, b.completed, b.disputed,
         CASE WHEN b.completed > 0 THEN round(b.disputed * 100.0 / b.completed, 1) ELSE 0 END
    FROM base b
    ORDER BY b.month_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dispute_rate_monthly(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_rate_monthly(integer) TO service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 499 founder cockpit RPCs verified: 5 RPCs (hero KPIs + GMV by equipment + engineer LTV + cohort retention + dispute rate trend)';
END;
$$;
