-- Round 720 — fix engineer_payouts.status filters across 6 RPCs
--
-- engineer_payouts.status enum is ('queued','processing','processed',
-- 'failed','cancelled'). There is NO 'paid' or 'completed' or 'reversed'
-- value. Multiple founder RPCs filtered on status='paid' and silently
-- returned 0 rows / Rs.0 totals.
--
-- This migration replaces the broken filters across:
--   * founder_payout_settlement_latency (r624)
--   * founder_engineer_payout_history   (r658)
--   * founder_payout_fail_reasons       (r666)
--   * founder_payouts_by_day_trend      (r686)
--   * founder_payouts_by_month          (r697)
--   * founder_platform_pulse            (r700)
--
-- The correct success status is 'processed'. Failure remains 'failed'.
BEGIN;

-- ---------------------------------------------------------------------
-- r624 — payout settlement latency
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payout_settlement_latency();
CREATE OR REPLACE FUNCTION public.founder_payout_settlement_latency()
RETURNS TABLE (
  window_label  text,
  paid_count    bigint,
  avg_hours     numeric,
  p50_hours     numeric,
  p90_hours     numeric,
  pending_count bigint,
  failed_count  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paid AS (
    SELECT
      queued_at,
      extract(epoch FROM (processed_at - queued_at)) / 3600.0 AS hours
    FROM public.engineer_payouts
    WHERE status = 'processed'
      AND queued_at >= now() - interval '90 days'
      AND processed_at IS NOT NULL
      AND processed_at >= queued_at
  ),
  w7  AS (SELECT * FROM paid WHERE queued_at >= now() - interval '7 days'),
  w30 AS (SELECT * FROM paid WHERE queued_at >= now() - interval '30 days')
  SELECT
    '7d'::text,
    (SELECT count(*)::bigint FROM w7),
    coalesce((SELECT round(avg(hours)::numeric, 1) FROM w7), 0),
    coalesce((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM w7), 0),
    coalesce((SELECT round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM w7), 0),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at >= now() - interval '7 days'),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'failed' AND queued_at >= now() - interval '7 days')
  UNION ALL SELECT
    '30d',
    (SELECT count(*)::bigint FROM w30),
    coalesce((SELECT round(avg(hours)::numeric, 1) FROM w30), 0),
    coalesce((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM w30), 0),
    coalesce((SELECT round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM w30), 0),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at >= now() - interval '30 days'),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'failed' AND queued_at >= now() - interval '30 days')
  UNION ALL SELECT
    '90d',
    (SELECT count(*)::bigint FROM paid),
    coalesce((SELECT round(avg(hours)::numeric, 1) FROM paid), 0),
    coalesce((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM paid), 0),
    coalesce((SELECT round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours))::numeric, 1) FROM paid), 0),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status IN ('queued','processing') AND queued_at >= now() - interval '90 days'),
    (SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'failed' AND queued_at >= now() - interval '90 days');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_settlement_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_settlement_latency() TO authenticated;

-- ---------------------------------------------------------------------
-- r658 — engineer payout history (status='processed', not 'paid')
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_engineer_payout_history();
CREATE OR REPLACE FUNCTION public.founder_engineer_payout_history()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  paid_30d_rupees   numeric,
  paid_90d_rupees   numeric,
  paid_lifetime     numeric,
  payouts_lifetime  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.engineer_user_id, p.amount_paise, p.queued_at
    FROM public.engineer_payouts p
    WHERE p.status = 'processed'
  )
  SELECT
    b.engineer_user_id,
    coalesce(pr.full_name, '(engineer)'),
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '30 days'), 0)::numeric / 100.0, 2),
    round(coalesce(sum(b.amount_paise) FILTER (WHERE b.queued_at >= now() - interval '90 days'), 0)::numeric / 100.0, 2),
    round(coalesce(sum(b.amount_paise), 0)::numeric / 100.0, 2),
    count(*)::bigint
  FROM base b
  LEFT JOIN public.profiles pr ON pr.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, pr.full_name
  ORDER BY paid_lifetime DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_payout_history() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_payout_history() TO authenticated;

-- ---------------------------------------------------------------------
-- r666 — payout fail reasons (drop bogus 'reversed' status)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payout_fail_reasons();
CREATE OR REPLACE FUNCTION public.founder_payout_fail_reasons()
RETURNS TABLE (
  razorpayx_status text,
  cnt              bigint,
  total_rupees     numeric,
  oldest_age_days  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.razorpayx_status, '(null)'),
    count(*)::bigint,
    round(coalesce(sum(p.amount_paise), 0)::numeric / 100.0, 2),
    (extract(epoch FROM (now() - min(p.queued_at)))::int / 86400)
  FROM public.engineer_payouts p
  WHERE p.status IN ('failed','queued','processing','cancelled')
  GROUP BY coalesce(p.razorpayx_status, '(null)')
  ORDER BY cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_fail_reasons() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_fail_reasons() TO authenticated;

-- ---------------------------------------------------------------------
-- r686 — payouts by day trend (paid → processed)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_by_day_trend();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_day_trend()
RETURNS TABLE (
  day_ist        date,
  paid_count     bigint,
  paid_rupees    numeric,
  failed_count   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.status = 'processed'
         AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT round(sum(p.amount_paise)::numeric / 100.0, 2)::numeric FROM public.engineer_payouts p
       WHERE p.status = 'processed'
         AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.status = 'failed'
         AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_day_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_day_trend() TO authenticated;

-- ---------------------------------------------------------------------
-- r697 — payouts by month (paid → processed)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_payouts_by_month();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_month()
RETURNS TABLE (
  month_ist     date,
  paid_count    bigint,
  paid_rupees   numeric,
  failed_count  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.status = 'processed'
         AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT round(sum(p.amount_paise)::numeric / 100.0, 2)::numeric FROM public.engineer_payouts p
       WHERE p.status = 'processed'
         AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::numeric,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.status = 'failed'
         AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_month() TO authenticated;

-- ---------------------------------------------------------------------
-- r700 — platform pulse (paid → processed for v_paid_30d)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_platform_pulse();
CREATE OR REPLACE FUNCTION public.founder_platform_pulse()
RETURNS TABLE (
  metric         text,
  value_text     text,
  value_numeric  numeric,
  ord            int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_engineers bigint;
  v_verified_engineers bigint;
  v_total_hospitals bigint;
  v_active_amcs bigint;
  v_total_mrr numeric;
  v_jobs_30d bigint;
  v_completed_30d bigint;
  v_gross_30d numeric;
  v_signups_30d bigint;
  v_paid_30d numeric;
  v_disputes_open bigint;
  v_escrow_held numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total_engineers FROM public.engineers;
  SELECT count(*)::bigint INTO v_verified_engineers FROM public.engineers WHERE verification_status = 'verified';
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_total_hospitals FROM public.repair_jobs;
  SELECT count(*)::bigint INTO v_active_amcs FROM public.amc_contracts WHERE status = 'active';
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total_mrr FROM public.amc_contracts WHERE status = 'active';
  SELECT count(*)::bigint INTO v_jobs_30d FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_completed_30d FROM public.repair_jobs
    WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_gross_30d FROM public.repair_jobs
    WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_signups_30d FROM auth.users WHERE created_at >= now() - interval '30 days';
  SELECT coalesce(round(sum(amount_paise)::numeric / 100.0, 2), 0)::numeric INTO v_paid_30d
    FROM public.engineer_payouts WHERE status = 'processed' AND queued_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_disputes_open FROM public.dispute_evidence_packs WHERE status = 'submitted';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_escrow_held FROM public.repair_job_escrow WHERE status IN ('pending','held','in_dispute');

  RETURN QUERY
  SELECT * FROM (VALUES
    ('Total engineers'::text,      v_total_engineers::text,           v_total_engineers::numeric,    1),
    ('Verified engineers'::text,    v_verified_engineers::text,        v_verified_engineers::numeric, 2),
    ('Hospitals (ever-active)'::text, v_total_hospitals::text,         v_total_hospitals::numeric,    3),
    ('Active AMCs'::text,           v_active_amcs::text,               v_active_amcs::numeric,        4),
    ('Total MRR'::text,             v_total_mrr::text,                 v_total_mrr,                   5),
    ('Jobs posted (30d)'::text,     v_jobs_30d::text,                  v_jobs_30d::numeric,           6),
    ('Jobs completed (30d)'::text,  v_completed_30d::text,             v_completed_30d::numeric,      7),
    ('GMV (30d)'::text,             v_gross_30d::text,                 v_gross_30d,                   8),
    ('Signups (30d)'::text,         v_signups_30d::text,               v_signups_30d::numeric,        9),
    ('Engineer payouts (30d)'::text, v_paid_30d::text,                 v_paid_30d,                   10),
    ('Open disputes'::text,         v_disputes_open::text,             v_disputes_open::numeric,     11),
    ('Live escrow balance'::text,   v_escrow_held::text,               v_escrow_held,                12)
  ) AS t(metric, value_text, value_numeric, ord);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_platform_pulse() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_platform_pulse() TO authenticated;

COMMIT;
