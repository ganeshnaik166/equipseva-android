BEGIN;
-- Sweep fix: r991/r1003/r1011/r1013/r1029/r1031/r1038/r1043 used
-- non-existent columns `c.tier` and `c.amount_inr` on public.amc_contracts.
-- Real columns are `c.amc_tier` (text) and `c.monthly_fee_rupees` (numeric).
-- supabase db push doesn't validate plpgsql column refs at CREATE time,
-- so the fns were created successfully but throw at runtime when the
-- founder console hits them. Re-create each with correct refs.

-- 1. r991 — /amc-renewal-window-30d
DROP FUNCTION IF EXISTS public.founder_amc_renewal_window_30d();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_window_30d()
RETURNS TABLE (tier text, total bigint, active bigint, paused bigint, expired bigint, total_mrr_inr bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(c.amc_tier, 'unknown')::text                                                    AS tier,
    count(*)::bigint                                                                          AS total,
    count(*) FILTER (WHERE c.status = 'active')::bigint                                       AS active,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                                       AS paused,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                                      AS expired,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status IN ('active','paused')), 0)::bigint AS total_mrr_inr
  FROM public.amc_contracts c
  WHERE c.end_date IS NOT NULL
    AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
    AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30
  GROUP BY coalesce(c.amc_tier, 'unknown')
  ORDER BY total_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_window_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_window_30d() TO authenticated;

-- 2. r1011 — /amc-pool-zero-balance
DROP FUNCTION IF EXISTS public.founder_amc_pool_zero_balance();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_zero_balance()
RETURNS TABLE (tier text, total_active_amcs bigint, zero_balance_cnt bigint, zero_balance_pct numeric, blocked_mrr_inr bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, c.amc_tier AS tier, c.monthly_fee_rupees,
           coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS bal
    FROM public.amc_contracts c WHERE c.status = 'active'
  )
  SELECT
    coalesce(a.tier, 'unknown')::text                                  AS tier,
    count(*)::bigint                                                    AS total_active_amcs,
    count(*) FILTER (WHERE a.bal <= 0)::bigint                          AS zero_balance_cnt,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE a.bal <= 0) / count(*), 1) END AS zero_balance_pct,
    coalesce(sum(a.monthly_fee_rupees) FILTER (WHERE a.bal <= 0), 0)::bigint AS blocked_mrr_inr
  FROM active a
  GROUP BY coalesce(a.tier, 'unknown')
  ORDER BY blocked_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_zero_balance() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_zero_balance() TO authenticated;

-- 3. r1013 — /critical-cockpit expanded (14 fields, uses both c.amount_inr and the pool join)
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
    coalesce((SELECT sum(amount_inr)::numeric FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status NOT IN ('resolved','timed_out') AND created_at < now() - interval '4 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE engineer_id IS NULL AND status IN ('open','posted') AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status IN ('submitted','pending') AND created_at < now() - interval '1 day'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT sum(amount)::numeric FROM public.repair_job_escrow WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'engineer'
              AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.engineer_id = p.id AND j.status = 'completed' AND j.completed_at >= now() - interval '90 days')), 0),
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

-- 4. r1031 — /amc-pool-burn-rate-by-tier (used coalesce(c.tier))
DROP FUNCTION IF EXISTS public.founder_amc_pool_burn_rate_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_burn_rate_by_tier()
RETURNS TABLE (tier text, active_amcs bigint, total_balance_inr numeric, debits_last_30d_inr numeric, avg_monthly_burn_per_amc numeric, est_months_to_zero numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, coalesce(c.amc_tier, 'unknown')::text AS tier,
           coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS bal
    FROM public.amc_contracts c WHERE c.status = 'active'
  ),
  debits AS (
    SELECT coalesce(c.amc_tier, 'unknown')::text AS tier, sum(pp.amount_rupees)::numeric AS debit_inr
    FROM public.amc_payment_pool pp
    JOIN public.amc_contracts c ON c.id = pp.amc_contract_id
    WHERE pp.ledger_kind = 'debit' AND pp.created_at >= now() - interval '30 days'
    GROUP BY coalesce(c.amc_tier, 'unknown')
  )
  SELECT a.tier, count(*)::bigint AS active_amcs, sum(a.bal)::numeric AS total_balance_inr,
         coalesce(d.debit_inr, 0)::numeric AS debits_last_30d_inr,
         CASE WHEN count(*) = 0 THEN 0::numeric ELSE round(coalesce(d.debit_inr, 0)::numeric / count(*), 2) END AS avg_monthly_burn_per_amc,
         CASE WHEN coalesce(d.debit_inr, 0) = 0 THEN 0::numeric ELSE round(sum(a.bal)::numeric / coalesce(d.debit_inr, 1), 1) END AS est_months_to_zero
  FROM active a LEFT JOIN debits d ON d.tier = a.tier
  GROUP BY a.tier, d.debit_inr
  ORDER BY est_months_to_zero ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_burn_rate_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_burn_rate_by_tier() TO authenticated;

-- 5. r1029 — /state-coverage (used c.amount_inr in amc_states CTE)
DROP FUNCTION IF EXISTS public.founder_state_coverage();
CREATE OR REPLACE FUNCTION public.founder_state_coverage()
RETURNS TABLE (state text, engineers_total bigint, engineers_verified bigint, hospitals_total bigint, amcs_active bigint, amcs_active_mrr_inr numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH eng_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state,
           count(*)::bigint AS total,
           count(*) FILTER (WHERE e.verification_status = 'verified')::bigint AS verified
    FROM public.engineers e JOIN public.profiles p ON p.id = e.user_id
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  hosp_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state, count(*)::bigint AS total
    FROM public.profiles p WHERE p.role = 'hospital'
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  amc_states AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)')::text AS state, count(*)::bigint AS cnt,
           coalesce(sum(c.monthly_fee_rupees), 0)::numeric AS mrr
    FROM public.amc_contracts c JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE c.status = 'active'
    GROUP BY coalesce(nullif(trim(p.state), ''), '(unknown)')
  ),
  all_states AS (SELECT state FROM eng_states UNION SELECT state FROM hosp_states UNION SELECT state FROM amc_states)
  SELECT a.state,
         coalesce(es.total, 0)::bigint, coalesce(es.verified, 0)::bigint,
         coalesce(hs.total, 0)::bigint,
         coalesce(amcs.cnt, 0)::bigint, coalesce(amcs.mrr, 0)::numeric
  FROM all_states a
  LEFT JOIN eng_states es ON es.state = a.state
  LEFT JOIN hosp_states hs ON hs.state = a.state
  LEFT JOIN amc_states amcs ON amcs.state = a.state
  ORDER BY (coalesce(es.total,0) + coalesce(hs.total,0) + coalesce(amcs.cnt,0)) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_state_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_state_coverage() TO authenticated;

-- 6. r1038 — /amc-contracts-by-day-30d (used c.amount_inr + c.tier)
DROP FUNCTION IF EXISTS public.founder_amc_contracts_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_amc_contracts_by_day_30d()
RETURNS TABLE (day_ist date, new_amcs bigint, total_mrr_inr numeric, distinct_tiers bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT count(DISTINCT c.amc_tier)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)
  FROM days d ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_contracts_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_contracts_by_day_30d() TO authenticated;

-- 7. r1003 — /amc-renewal-funnel-90d
DROP FUNCTION IF EXISTS public.founder_amc_renewal_funnel_90d();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_funnel_90d()
RETURNS TABLE (stage text, stage_order int, contracts bigint, total_mrr_inr numeric, pct_of_due numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_due bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_due FROM public.amc_contracts c
  WHERE c.end_date IS NOT NULL
    AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - 90
    AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date;
  IF v_due IS NULL THEN v_due := 0; END IF;
  RETURN QUERY
  WITH due AS (
    SELECT * FROM public.amc_contracts c
    WHERE c.end_date IS NOT NULL
      AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - 90
      AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date
  ),
  stages AS (
    SELECT 'Due (denominator)'::text AS stage, 0 AS stage_order, count(*)::bigint AS contracts, coalesce(sum(monthly_fee_rupees),0)::numeric AS total_mrr_inr FROM due
    UNION ALL SELECT 'Notify stage 1 sent', 1, count(*) FILTER (WHERE renewal_notifications_sent >= 1)::bigint, coalesce(sum(monthly_fee_rupees) FILTER (WHERE renewal_notifications_sent >= 1),0)::numeric FROM due
    UNION ALL SELECT 'Notify stage 2 sent', 2, count(*) FILTER (WHERE renewal_notifications_sent >= 2)::bigint, coalesce(sum(monthly_fee_rupees) FILTER (WHERE renewal_notifications_sent >= 2),0)::numeric FROM due
    UNION ALL SELECT 'Notify stage 3 sent', 3, count(*) FILTER (WHERE renewal_notifications_sent >= 3)::bigint, coalesce(sum(monthly_fee_rupees) FILTER (WHERE renewal_notifications_sent >= 3),0)::numeric FROM due
    UNION ALL SELECT 'Renewed (status=active and end_date pushed forward)', 4, count(*) FILTER (WHERE status = 'active')::bigint, coalesce(sum(monthly_fee_rupees) FILTER (WHERE status = 'active'),0)::numeric FROM due
    UNION ALL SELECT 'Expired (never renewed)', 5, count(*) FILTER (WHERE status = 'expired')::bigint, coalesce(sum(monthly_fee_rupees) FILTER (WHERE status = 'expired'),0)::numeric FROM due
  )
  SELECT s.stage, s.stage_order, s.contracts, s.total_mrr_inr,
         CASE WHEN v_due = 0 THEN 0::numeric ELSE round(100.0 * s.contracts / v_due, 1) END
  FROM stages s ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_funnel_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_funnel_90d() TO authenticated;

-- 8. r1054 — /amc-renewal-rate-by-month
DROP FUNCTION IF EXISTS public.founder_amc_renewal_rate_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_rate_by_month()
RETURNS TABLE (month_ist date, due_cnt bigint, renewed_cnt bigint, expired_cnt bigint, renewal_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(date_trunc('month', now() - interval '5 months')::date, date_trunc('month', now())::date, interval '1 month')::date AS month_ist
  )
  SELECT m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist), 0) AS due_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist AND c.status = 'active'), 0) AS renewed_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist AND c.status = 'expired'), 0) AS expired_cnt,
    CASE WHEN coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist), 0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist AND c.status = 'active'), 0)
                    / coalesce((SELECT count(*)::numeric FROM public.amc_contracts c WHERE c.end_date IS NOT NULL AND date_trunc('month', c.end_date)::date = m.month_ist), 1), 1)
    END AS renewal_pct
  FROM months m ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_month() TO authenticated;

-- 9. r1035 — /amc-revenue-projection (used amount_inr)
DROP FUNCTION IF EXISTS public.founder_amc_revenue_projection();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_projection()
RETURNS TABLE (metric text, metric_order int, value_inr numeric, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_active_mrr numeric := 0; v_expiring_30d_mrr numeric := 0;
  v_expiring_60d_mrr numeric := 0; v_expiring_90d_mrr numeric := 0; v_new_30d_mrr numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_active_mrr FROM public.amc_contracts WHERE status = 'active';
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_expiring_30d_mrr FROM public.amc_contracts
    WHERE status = 'active' AND end_date IS NOT NULL AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_expiring_60d_mrr FROM public.amc_contracts
    WHERE status = 'active' AND end_date IS NOT NULL AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 60;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_expiring_90d_mrr FROM public.amc_contracts
    WHERE status = 'active' AND end_date IS NOT NULL AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 90;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_new_30d_mrr FROM public.amc_contracts
    WHERE status IN ('active','paused') AND created_at >= now() - interval '30 days';
  RETURN QUERY VALUES
    ('Current MRR (active contracts)'::text, 1, v_active_mrr, 'baseline'::text),
    ('MRR expiring next 30d', 2, v_expiring_30d_mrr, 'at risk if no renewal'),
    ('MRR expiring next 60d', 3, v_expiring_60d_mrr, 'medium-term risk'),
    ('MRR expiring next 90d', 4, v_expiring_90d_mrr, 'long-term risk'),
    ('New MRR added last 30d', 5, v_new_30d_mrr, 'growth signal'),
    ('Projected MRR 30d forward (active - expiring30 + new30)', 6, v_active_mrr - v_expiring_30d_mrr + v_new_30d_mrr, 'if no renewals + same growth'),
    ('Projected MRR 90d forward (active - expiring90 + 3*new30)', 7, v_active_mrr - v_expiring_90d_mrr + 3 * v_new_30d_mrr, 'optimistic - renewals = 0');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_projection() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_projection() TO authenticated;

COMMIT;
