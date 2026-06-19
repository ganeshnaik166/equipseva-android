BEGIN;
-- Audit-driven sweep fix (r1163). Adversarial workflow w3gkpbc6w surfaced 23
-- confirmed bugs across founder console RPCs. Root cause: Postgres plpgsql does
-- not validate column refs at CREATE FUNCTION time, so fns ship green even with
-- broken refs. r1085 swept the c.tier/c.amount_inr bugs on amc_contracts but
-- MISSED r1043 and left an entire class of engineer_payouts bugs untouched.
--
-- Real engineer_payouts columns (confirmed from r422 schema + r856 generated col):
--   • amount_paise (NOT NULL bigint) — source of truth
--   • amount_rupees (generated numeric(12,2) = round(amount_paise/100.0, 2))
--   • engineer_user_id (NOT engineer_id) — FKs auth.users.id
--   • status CHECK: 'queued','processing','processed','failed','cancelled' (no 'paid')
--
-- repair_jobs.engineer_id is FK to engineers.id (NOT profiles/auth.users.id).
-- engineers.user_id bridges to profiles.id. So queries like
--   `j.engineer_id = profile.id` are silently false.
--
-- This migration DROPs and re-CREATEs each broken RPC with correct refs.

-- ============================================================================
-- 1. r1043 — founder_amc_tier_current_snapshot (omitted from r1085 sweep)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_amc_tier_current_snapshot();
CREATE OR REPLACE FUNCTION public.founder_amc_tier_current_snapshot()
RETURNS TABLE (tier text, active_cnt bigint, paused_cnt bigint, expired_cnt bigint, avg_amount_inr numeric, total_mrr_inr numeric, avg_pool_inr numeric, avg_days_to_end numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(c.amc_tier, 'unknown')::text                                                       AS tier,
    count(*) FILTER (WHERE c.status = 'active')::bigint                                          AS active_cnt,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                                          AS paused_cnt,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                                         AS expired_cnt,
    round(avg(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active')::numeric, 2)              AS avg_amount_inr,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active'), 0)::numeric           AS total_mrr_inr,
    round(
      avg(coalesce(
        (SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0
      )) FILTER (WHERE c.status = 'active')::numeric,
      2
    )                                                                                            AS avg_pool_inr,
    round(
      avg((c.end_date - (now() AT TIME ZONE 'Asia/Kolkata')::date)::numeric)
        FILTER (WHERE c.status = 'active' AND c.end_date IS NOT NULL)::numeric,
      1
    )                                                                                            AS avg_days_to_end
  FROM public.amc_contracts c
  GROUP BY coalesce(c.amc_tier, 'unknown')
  ORDER BY total_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_tier_current_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_tier_current_snapshot() TO authenticated;

-- ============================================================================
-- 2. r1055 — founder_amc_paused_aging (CTE column-name mismatch)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_amc_paused_aging();
CREATE OR REPLACE FUNCTION public.founder_amc_paused_aging()
RETURNS TABLE (bucket text, bucket_order int, cnt bigint, frozen_mrr_inr numeric, oldest_paused_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN c.updated_at >= now() - interval '7 days'   THEN '<7d'
        WHEN c.updated_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN c.updated_at >= now() - interval '30 days'  THEN '14-30d'
        WHEN c.updated_at >= now() - interval '60 days'  THEN '30-60d'
        WHEN c.updated_at >= now() - interval '90 days'  THEN '60-90d'
        ELSE '>90d'
      END                                          AS bucket,
      CASE
        WHEN c.updated_at >= now() - interval '7 days'   THEN 1
        WHEN c.updated_at >= now() - interval '14 days'  THEN 2
        WHEN c.updated_at >= now() - interval '30 days'  THEN 3
        WHEN c.updated_at >= now() - interval '60 days'  THEN 4
        WHEN c.updated_at >= now() - interval '90 days'  THEN 5
        ELSE 6
      END                                          AS bucket_order,
      c.monthly_fee_rupees AS amount_inr,
      c.updated_at         AS updated_at
    FROM public.amc_contracts c
    WHERE c.status = 'paused'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    coalesce(sum(a.amount_inr), 0)::numeric                AS frozen_mrr_inr,
    min(a.updated_at)                                      AS oldest_paused_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_paused_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_paused_aging() TO authenticated;

-- ============================================================================
-- 3. r994 — founder_payouts_stuck_aging (p.amount_inr → p.amount_rupees)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payouts_stuck_aging();
CREATE OR REPLACE FUNCTION public.founder_payouts_stuck_aging()
RETURNS TABLE (bucket text, bucket_order int, cnt bigint, amount_inr bigint, oldest_queued_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN p.queued_at >= now() - interval '24 hours' THEN '<24h'
        WHEN p.queued_at >= now() - interval '3 days'   THEN '1-3d'
        WHEN p.queued_at >= now() - interval '7 days'   THEN '3-7d'
        WHEN p.queued_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN p.queued_at >= now() - interval '30 days'  THEN '14-30d'
        ELSE '>30d'
      END                                                 AS bucket,
      CASE
        WHEN p.queued_at >= now() - interval '24 hours' THEN 1
        WHEN p.queued_at >= now() - interval '3 days'   THEN 2
        WHEN p.queued_at >= now() - interval '7 days'   THEN 3
        WHEN p.queued_at >= now() - interval '14 days'  THEN 4
        WHEN p.queued_at >= now() - interval '30 days'  THEN 5
        ELSE 6
      END                                                 AS bucket_order,
      p.amount_rupees                                     AS amount_inr,
      p.queued_at
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued', 'processing')
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                                    AS cnt,
    coalesce(sum(a.amount_inr), 0)::bigint                              AS amount_inr,
    min(a.queued_at)                                                    AS oldest_queued_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_stuck_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_stuck_aging() TO authenticated;

-- ============================================================================
-- 4. founder_critical_cockpit — fix engineer_payouts.amount_inr + engineers FK bug
--    (most recent live version is r1085; this supersedes with both fixes)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_critical_cockpit();
CREATE OR REPLACE FUNCTION public.founder_critical_cockpit()
RETURNS TABLE (
  payouts_stuck_over_7d        bigint, payouts_stuck_inr            numeric,
  code_red_stuck_over_4h       bigint,
  spare_parts_stuck_over_7d    bigint, spare_parts_stuck_inr        numeric,
  jobs_unassigned_over_1d      bigint,
  bids_stuck_over_1d           bigint,
  escrow_held_over_14d         bigint, escrow_held_inr              numeric,
  engineers_no_jobs_90d        bigint,
  hospitals_no_jobs_90d        bigint,
  amc_renewing_30d             bigint, amc_renewing_mrr_inr         numeric,
  amc_pool_zero_balance        bigint, amc_pool_zero_mrr_inr        numeric,
  kyc_pending_over_7d          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status NOT IN ('resolved','timed_out') AND created_at < now() - interval '4 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE engineer_id IS NULL AND status IN ('open','posted') AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status IN ('submitted','pending') AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT sum(amount)::numeric FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    -- engineers_no_jobs_90d — fixed FK join (was j.engineer_id = profile.id, never matched)
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE NOT EXISTS (
                SELECT 1 FROM public.repair_jobs j
                WHERE j.engineer_id = e.id
                  AND j.status = 'completed'
                  AND j.completed_at >= now() - interval '90 days'
              )), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital'
              AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id AND j.created_at >= now() - interval '90 days')), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30 AND c.status IN ('active','paused')), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30 AND c.status IN ('active','paused')), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'active'
              AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.status = 'active'
              AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers e WHERE coalesce(e.verification_status, 'pending') = 'pending' AND e.created_at < now() - interval '7 days'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_critical_cockpit() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_critical_cockpit() TO authenticated;

-- ============================================================================
-- 5. r1002 — founder_critical_actions (engineer_id/amount_inr → engineer_user_id/amount_rupees)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_critical_actions();
CREATE OR REPLACE FUNCTION public.founder_critical_actions()
RETURNS TABLE (surface text, item_id uuid, item_label text, amount_inr numeric, created_at timestamptz, age_days int, severity text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  (
    SELECT
      'payout'::text                                                                        AS surface,
      p.id::uuid                                                                            AS item_id,
      ('payout to ' || coalesce((SELECT full_name FROM public.profiles WHERE id = p.engineer_user_id), '?')) AS item_label,
      p.amount_rupees::numeric                                                              AS amount_inr,
      p.queued_at                                                                           AS created_at,
      extract(day from (now() - p.queued_at))::int                                          AS age_days,
      CASE WHEN p.queued_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END    AS severity
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued','processing')
      AND p.queued_at < now() - interval '7 days'
    ORDER BY p.queued_at ASC
    LIMIT 20
  )
  UNION ALL
  (
    SELECT 'code_red'::text, r.id::uuid, ('code red request')::text, NULL::numeric, r.created_at,
      extract(day from (now() - r.created_at))::int,
      CASE WHEN r.created_at < now() - interval '24 hours' THEN 'critical' ELSE 'warn' END
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved','timed_out') AND r.created_at < now() - interval '4 hours'
    ORDER BY r.created_at ASC LIMIT 20
  )
  UNION ALL
  (
    SELECT 'spare_part'::text, o.id::uuid, ('order ' || coalesce(o.order_number, o.id::text)),
      o.total_amount::numeric, o.created_at, extract(day from (now() - o.created_at))::int,
      CASE WHEN o.created_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status,'') = 'paid'
      AND coalesce(o.order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
      AND o.created_at < now() - interval '7 days'
    ORDER BY o.created_at ASC LIMIT 20
  )
  UNION ALL
  (
    SELECT 'escrow'::text, e.id::uuid, ('escrow for job ' || e.repair_job_id::text),
      e.amount::numeric, e.created_at, extract(day from (now() - e.created_at))::int,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 'critical' ELSE 'warn' END
    FROM public.repair_job_escrow e
    WHERE e.status = 'held' AND e.created_at < now() - interval '14 days'
    ORDER BY e.created_at ASC LIMIT 20
  )
  ORDER BY 7 DESC, 5 ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_critical_actions() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_critical_actions() TO authenticated;

-- ============================================================================
-- 6. r1004 — founder_payout_success_funnel_90d (5x amount_inr → amount_rupees)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payout_success_funnel_90d();
CREATE OR REPLACE FUNCTION public.founder_payout_success_funnel_90d()
RETURNS TABLE (stage text, stage_order int, payouts bigint, total_inr numeric, pct_of_queued numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_q bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_q FROM public.engineer_payouts WHERE queued_at >= now() - interval '90 days';
  IF v_q IS NULL THEN v_q := 0; END IF;
  RETURN QUERY
  WITH cohort AS (SELECT * FROM public.engineer_payouts WHERE queued_at >= now() - interval '90 days'),
  stages AS (
    SELECT 'Queued (denominator)'::text AS stage, 0 AS stage_order, count(*)::bigint AS payouts, coalesce(sum(amount_rupees),0)::numeric AS total_inr FROM cohort
    UNION ALL SELECT 'Processing', 1, count(*) FILTER (WHERE status = 'processing')::bigint, coalesce(sum(amount_rupees) FILTER (WHERE status = 'processing'),0)::numeric FROM cohort
    UNION ALL SELECT 'Processed ✓', 2, count(*) FILTER (WHERE status IN ('processed','paid'))::bigint, coalesce(sum(amount_rupees) FILTER (WHERE status IN ('processed','paid')),0)::numeric FROM cohort
    UNION ALL SELECT 'Failed ✗', 3, count(*) FILTER (WHERE status = 'failed')::bigint, coalesce(sum(amount_rupees) FILTER (WHERE status = 'failed'),0)::numeric FROM cohort
    UNION ALL SELECT 'Still queued (no progress)', 4, count(*) FILTER (WHERE status = 'queued')::bigint, coalesce(sum(amount_rupees) FILTER (WHERE status = 'queued'),0)::numeric FROM cohort
  )
  SELECT s.stage, s.stage_order, s.payouts, s.total_inr,
    CASE WHEN v_q = 0 THEN 0::numeric ELSE round(100.0 * s.payouts / v_q, 1) END
  FROM stages s ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_success_funnel_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_success_funnel_90d() TO authenticated;

-- ============================================================================
-- 7. r1005 — founder_engineer_onboarding_funnel (po.engineer_id → engineer_user_id)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_onboarding_funnel();
CREATE OR REPLACE FUNCTION public.founder_engineer_onboarding_funnel()
RETURNS TABLE (stage text, stage_order int, engineers bigint, pct_of_signups numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_signups bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_signups FROM public.profiles WHERE role = 'engineer';
  IF v_signups IS NULL THEN v_signups := 0; END IF;
  RETURN QUERY
  WITH stages AS (
    SELECT '1. Signed up'::text AS stage, 1 AS stage_order, v_signups AS engineers
    UNION ALL SELECT '2. Profile started (bio or city)', 2,
      (SELECT count(*)::bigint FROM public.engineers e JOIN public.profiles p ON p.id = e.user_id
       WHERE p.role = 'engineer' AND (coalesce(trim(e.bio), '') <> '' OR coalesce(trim(e.city), '') <> ''))
    UNION ALL SELECT '3. Verified', 3,
      (SELECT count(*)::bigint FROM public.engineers e JOIN public.profiles p ON p.id = e.user_id
       WHERE p.role = 'engineer' AND e.verification_status = 'verified')
    UNION ALL SELECT '4. First bid placed', 4,
      (SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b
       JOIN public.profiles p ON p.id = b.engineer_user_id WHERE p.role = 'engineer')
    UNION ALL SELECT '5. First job completed', 5,
      (SELECT count(DISTINCT j.engineer_id)::bigint FROM public.repair_jobs j WHERE j.engineer_id IS NOT NULL AND j.status = 'completed')
    UNION ALL SELECT '6. First payout processed', 6,
      (SELECT count(DISTINCT po.engineer_user_id)::bigint FROM public.engineer_payouts po WHERE po.status IN ('processed','paid'))
  )
  SELECT s.stage, s.stage_order, s.engineers,
    CASE WHEN v_signups = 0 THEN 0::numeric ELSE round(100.0 * s.engineers / v_signups, 1) END
  FROM stages s ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() TO authenticated;

-- ============================================================================
-- 8. r1032 — founder_failed_payouts_recent (amount_inr + engineer_id)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_failed_payouts_recent();
CREATE OR REPLACE FUNCTION public.founder_failed_payouts_recent()
RETURNS TABLE (payout_id uuid, engineer_name text, amount_inr bigint, failure_reason text, queued_at timestamptz, age_h int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id, coalesce(pr.full_name, '(no name)')::text, p.amount_rupees::bigint,
    coalesce(p.failure_reason, '(no reason)')::text, p.queued_at,
    extract(hour from (now() - p.queued_at))::int
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status = 'failed' AND p.queued_at >= now() - interval '90 days'
  ORDER BY p.queued_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_failed_payouts_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_failed_payouts_recent() TO authenticated;

-- ============================================================================
-- 9. r1033 — founder_failed_payouts_by_reason_90d (amount_inr + engineer_id)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_failed_payouts_by_reason_90d();
CREATE OR REPLACE FUNCTION public.founder_failed_payouts_by_reason_90d()
RETURNS TABLE (failure_reason text, cnt bigint, total_inr numeric, distinct_engs bigint, last_failed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.failure_reason, '(no reason)')::text,
    count(*)::bigint,
    coalesce(sum(p.amount_rupees), 0)::numeric,
    count(DISTINCT p.engineer_user_id)::bigint,
    max(p.queued_at)
  FROM public.engineer_payouts p
  WHERE p.status = 'failed' AND p.queued_at >= now() - interval '90 days'
  GROUP BY coalesce(p.failure_reason, '(no reason)')
  ORDER BY count(*) DESC LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_failed_payouts_by_reason_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_failed_payouts_by_reason_90d() TO authenticated;

-- ============================================================================
-- 10/11. r1068/r1070 — founder_payouts_cumulative (amount_inr → amount_rupees)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payouts_cumulative();
CREATE OR REPLACE FUNCTION public.founder_payouts_cumulative()
RETURNS TABLE (month_ist date, paid_count bigint, paid_rupees numeric, cum_count bigint, cum_rupees numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(date_trunc('month', now() - interval '11 months')::date, date_trunc('month', now())::date, interval '1 month')::date AS month_ist
  ),
  monthly AS (
    SELECT m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS paid_count,
      coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS paid_rupees
    FROM months m
  )
  SELECT m.month_ist, m.paid_count, m.paid_rupees,
    sum(m.paid_count) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::bigint  AS cum_count,
    sum(m.paid_rupees) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric AS cum_rupees
  FROM monthly m ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_cumulative() TO authenticated;

-- ============================================================================
-- 12. r1077 — founder_payouts_pending_by_engineer (engineer_id + amount_inr)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payouts_pending_by_engineer();
CREATE OR REPLACE FUNCTION public.founder_payouts_pending_by_engineer()
RETURNS TABLE (engineer_name text, pending_cnt bigint, pending_inr numeric, oldest_queued_at timestamptz, failed_cnt_90d bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(pr.full_name, '(no name)')::text,
    count(*)::bigint,
    coalesce(sum(p.amount_rupees), 0)::numeric,
    min(p.queued_at),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p2
              WHERE p2.engineer_user_id = p.engineer_user_id AND p2.status = 'failed'
                AND p2.queued_at >= now() - interval '90 days'), 0)::bigint
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status IN ('queued','processing')
  GROUP BY pr.full_name, p.engineer_user_id
  ORDER BY sum(p.amount_rupees) DESC NULLS LAST LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_pending_by_engineer() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_pending_by_engineer() TO authenticated;

-- ============================================================================
-- 13. r1087 — founder_payouts_by_hour_7d (amount_inr)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payouts_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_hour_7d()
RETURNS TABLE (hour_ist int, queued bigint, processed bigint, failed bigint, total_inr numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH hours AS (SELECT generate_series(0, 23) AS hour_ist)
  SELECT h.hour_ist,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.queued_at >= now() - interval '7 days' AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0) AS queued,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND p.queued_at >= now() - interval '7 days' AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0) AS processed,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND p.queued_at >= now() - interval '7 days' AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0) AS failed,
    coalesce((SELECT sum(p.amount_rupees)::numeric FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND p.queued_at >= now() - interval '7 days' AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0) AS total_inr
  FROM hours h ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_hour_7d() TO authenticated;

-- ============================================================================
-- 14. r1103 — founder_payouts_by_week_13wk (amount_inr)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payouts_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_week_13wk()
RETURNS TABLE (week_start date, queued bigint, processed bigint, failed bigint, total_inr numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (SELECT generate_series(date_trunc('week', now() - interval '12 weeks')::date, date_trunc('week', now())::date, interval '1 week')::date AS week_start)
  SELECT w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE date_trunc('week', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND date_trunc('week', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND date_trunc('week', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0),
    coalesce((SELECT sum(p.amount_rupees)::numeric FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND date_trunc('week', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
  FROM weeks w ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_week_13wk() TO authenticated;

-- ============================================================================
-- 15. r1154 — founder_engineers_with_no_payouts (engineer_id = e.id, double bug)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineers_with_no_payouts();
CREATE OR REPLACE FUNCTION public.founder_engineers_with_no_payouts()
RETURNS TABLE (total_engineers bigint, verified_engineers bigint, with_zero_payouts_ever bigint, with_zero_payouts_pct numeric, with_at_least_one_paid bigint, with_only_failed_payouts bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_tot FROM public.engineers;
  IF v_tot IS NULL THEN v_tot := 0; END IF;
  RETURN QUERY
  SELECT
    v_tot,
    coalesce((SELECT count(*)::bigint FROM public.engineers e WHERE e.verification_status = 'verified'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_user_id = e.user_id)), 0),
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.engineers e
                                      WHERE NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_user_id = e.user_id)), 0)
                    / v_tot, 1) END,
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_user_id = e.user_id AND p.status IN ('processed','paid'))), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_user_id = e.user_id AND p.status = 'failed')
                AND NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_user_id = e.user_id AND p.status IN ('processed','paid'))), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_with_no_payouts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_with_no_payouts() TO authenticated;

-- ============================================================================
-- 16. r992 — founder_engineers_no_jobs_30d (FK bug: CTE e from profiles → use engineers)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineers_no_jobs_30d();
CREATE OR REPLACE FUNCTION public.founder_engineers_no_jobs_30d()
RETURNS TABLE (total_engineers bigint, no_jobs_30d bigint, no_jobs_30d_pct numeric, no_jobs_60d bigint, no_jobs_60d_pct numeric, no_jobs_90d bigint, no_jobs_90d_pct numeric, never_had_a_job bigint, never_had_a_job_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO tot
  FROM public.engineers eng JOIN public.profiles p ON p.id = eng.user_id AND p.role = 'engineer';
  IF tot IS NULL THEN tot := 0; END IF;
  RETURN QUERY
  WITH e AS (
    SELECT eng.id, eng.created_at
    FROM public.engineers eng JOIN public.profiles p ON p.id = eng.user_id AND p.role = 'engineer'
  ),
  last_job AS (
    SELECT j.engineer_id, max(j.completed_at) AS last_completed_at
    FROM public.repair_jobs j WHERE j.engineer_id IS NOT NULL AND j.status = 'completed'
    GROUP BY j.engineer_id
  )
  SELECT
    tot,
    count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '30 days')::bigint,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '30 days') / tot, 1) END,
    count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '60 days')::bigint,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '60 days') / tot, 1) END,
    count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '90 days')::bigint,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '90 days') / tot, 1) END,
    count(*) FILTER (WHERE l.last_completed_at IS NULL)::bigint,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_completed_at IS NULL) / tot, 1) END
  FROM e LEFT JOIN last_job l ON l.engineer_id = e.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_no_jobs_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_no_jobs_30d() TO authenticated;

COMMIT;
