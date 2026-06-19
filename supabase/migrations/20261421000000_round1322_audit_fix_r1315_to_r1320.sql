BEGIN;
-- r1322 — MASSIVE audit-fix sweep for r1315..r1320 from workflow wy5uvmh9p.
-- 14 confirmed CRITICAL bugs across all 6 heavy ships from this batch.
--
-- Pattern of failure: workflow design agents hallucinated table/column names
-- that don't exist in the schema. plpgsql doesn't validate at CREATE FUNCTION
-- time so every RPC installed cleanly and would have failed at first runtime
-- call.

-- ============================================================================
-- 1. r1315 founder_morning_digest_v2 — engineer_payouts.status='paid_out'
--    is not in the CHECK (queued/processing/processed/failed/cancelled).
--    Use 'processed'.
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_morning_digest_v2();
CREATE OR REPLACE FUNCTION public.founder_morning_digest_v2()
RETURNS TABLE (
  top_actions          jsonb,
  mrr_today            numeric,
  mrr_yesterday        numeric,
  mrr_7d_ago           numeric,
  mrr_30d_ago          numeric,
  mrr_delta_pct_dod    numeric,
  mrr_delta_pct_wow    numeric,
  active_alerts        jsonb,
  milestones_24h       jsonb,
  cron_health          jsonb,
  generated_at         timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_actions   jsonb;
  v_mrr_today     numeric;
  v_mrr_yest      numeric;
  v_mrr_7d        numeric;
  v_mrr_30d       numeric;
  v_alerts        jsonb;
  v_milestones    jsonb;
  v_cron          jsonb;
  v_code_red      int;
  v_stuck_payouts int;
  v_open_inc      int;
  v_jobs_24h      int;
  v_amcs_24h      int;
  v_payouts_24h   int;
  v_cron_fails    int := 0;
  v_cron_total    int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.priority_score DESC), '[]'::jsonb)
    INTO v_top_actions
  FROM (
    SELECT 'code_red'::text AS action_type, cr.id::text AS ref_id,
           cr.equipment_label AS title,
           cr.minutes_open AS metric,
           (100 + COALESCE(cr.minutes_open, 0))::numeric AS priority_score
    FROM public.code_red_requests cr
    WHERE cr.status NOT IN ('resolved','timed_out')
    UNION ALL
    SELECT 'stuck_payout'::text, ep.id::text,
           ('Payout queued >14d · ' || (ep.amount_rupees::text) || ' INR'),
           EXTRACT(EPOCH FROM (now() - ep.created_at))::int / 86400,
           (60 + EXTRACT(EPOCH FROM (now() - ep.created_at))::numeric / 86400)
    FROM public.engineer_payouts ep
    WHERE ep.status = 'queued' AND ep.created_at < now() - interval '14 days'
    UNION ALL
    SELECT 'open_incident'::text, fi.id::text,
           COALESCE(fi.title, 'Incident'),
           EXTRACT(EPOCH FROM (now() - fi.opened_at))::int / 3600,
           (80 + EXTRACT(EPOCH FROM (now() - fi.opened_at))::numeric / 3600)
    FROM public.founder_incidents fi
    WHERE fi.status = 'open'
    LIMIT 10
  ) t;

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_today
  FROM public.amc_contracts WHERE status = 'active';

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_yest
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '1 day'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '1 day');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_7d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '7 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '7 days');

  SELECT COALESCE(SUM(monthly_fee_rupees), 0) INTO v_mrr_30d
  FROM public.amc_contracts
  WHERE activated_at < now() - interval '30 days'
    AND (deactivated_at IS NULL OR deactivated_at > now() - interval '30 days');

  SELECT count(*) INTO v_code_red FROM public.code_red_requests
  WHERE status NOT IN ('resolved','timed_out');

  SELECT count(*) INTO v_stuck_payouts FROM public.engineer_payouts
  WHERE status = 'queued' AND created_at < now() - interval '14 days';

  SELECT count(*) INTO v_open_inc FROM public.founder_incidents WHERE status = 'open';

  v_alerts := jsonb_build_array(
    jsonb_build_object('kind','code_red_open',     'count', v_code_red,      'severity','critical'),
    jsonb_build_object('kind','stuck_payouts_14d', 'count', v_stuck_payouts, 'severity','high'),
    jsonb_build_object('kind','open_incidents',    'count', v_open_inc,      'severity','high')
  );

  SELECT count(*) INTO v_jobs_24h FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at > now() - interval '24 hours';

  SELECT count(*) INTO v_amcs_24h FROM public.amc_contracts
  WHERE activated_at > now() - interval '24 hours';

  -- r1322 FIX: engineer_payouts.status 'paid_out' → 'processed' (CHECK constraint)
  SELECT count(*) INTO v_payouts_24h FROM public.engineer_payouts
  WHERE status = 'processed' AND updated_at > now() - interval '24 hours';

  v_milestones := jsonb_build_array(
    jsonb_build_object('kind','jobs_completed', 'count', v_jobs_24h),
    jsonb_build_object('kind','amcs_activated', 'count', v_amcs_24h),
    jsonb_build_object('kind','payouts_paid',   'count', v_payouts_24h)
  );

  BEGIN
    EXECUTE $q$
      SELECT count(*) FILTER (WHERE status = 'failed'), count(*)
      FROM cron.job_run_details WHERE start_time > now() - interval '24 hours'
    $q$ INTO v_cron_fails, v_cron_total;
  EXCEPTION WHEN OTHERS THEN
    v_cron_fails := 0; v_cron_total := 0;
  END;

  v_cron := jsonb_build_object(
    'runs_24h',     v_cron_total,
    'failures_24h', v_cron_fails,
    'failure_rate', CASE WHEN v_cron_total > 0
                         THEN ROUND((v_cron_fails::numeric / v_cron_total::numeric) * 100, 2)
                         ELSE 0 END
  );

  RETURN QUERY SELECT
    v_top_actions, v_mrr_today, v_mrr_yest, v_mrr_7d, v_mrr_30d,
    CASE WHEN v_mrr_yest > 0
         THEN ROUND(((v_mrr_today - v_mrr_yest) / v_mrr_yest) * 100, 2) ELSE 0 END,
    CASE WHEN v_mrr_7d > 0
         THEN ROUND(((v_mrr_today - v_mrr_7d) / v_mrr_7d) * 100, 2) ELSE 0 END,
    v_alerts, v_milestones, v_cron, now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_morning_digest_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_morning_digest_v2() TO authenticated;

-- ============================================================================
-- 2. r1316 founder_gst_quarterly_prep — gst_invoices column names wrong
--    invoice_date → issued_at
--    buyer_gstin → recipient_gstin
--    taxable_value_rupees → taxable_amount_rupees
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_gst_quarterly_prep(date);
CREATE OR REPLACE FUNCTION public.founder_gst_quarterly_prep(p_quarter_start date)
RETURNS TABLE (
  quarter_label text, period_start date, period_end date,
  b2b_invoice_count bigint, b2b_taxable_value_rupees numeric,
  b2b_igst_rupees numeric, b2b_cgst_rupees numeric, b2b_sgst_rupees numeric,
  b2c_invoice_count bigint, b2c_taxable_value_rupees numeric,
  b2c_igst_rupees numeric, b2c_cgst_rupees numeric, b2c_sgst_rupees numeric,
  nil_rated_count bigint, hsn_distinct_count bigint,
  total_outward_taxable_rupees numeric, total_igst_rupees numeric,
  total_cgst_rupees numeric, total_sgst_rupees numeric,
  itc_eligible_rupees numeric, net_tax_payable_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_period_end date := (p_quarter_start + interval '3 months' - interval '1 day')::date;
  v_q_label text := 'Q' || to_char(p_quarter_start, 'Q') || '-FY' || to_char(p_quarter_start, 'YY') || '-' || to_char(p_quarter_start + interval '1 year', 'YY');
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH inv AS (
    SELECT g.* FROM public.gst_invoices g
    WHERE g.issued_at::date >= p_quarter_start
      AND g.issued_at::date <= v_period_end
      AND COALESCE(g.status::text, '') <> 'cancelled'
  ),
  b2b AS (
    SELECT
      COUNT(*)::bigint AS cnt,
      COALESCE(SUM(COALESCE(taxable_amount_rupees,0)),0)::numeric AS tax_val,
      COALESCE(SUM(COALESCE(igst_rupees,0)),0)::numeric AS igst,
      COALESCE(SUM(COALESCE(cgst_rupees,0)),0)::numeric AS cgst,
      COALESCE(SUM(COALESCE(sgst_rupees,0)),0)::numeric AS sgst
    FROM inv WHERE recipient_gstin IS NOT NULL
  ),
  b2c AS (
    SELECT
      COUNT(*)::bigint AS cnt,
      COALESCE(SUM(COALESCE(taxable_amount_rupees,0)),0)::numeric AS tax_val,
      COALESCE(SUM(COALESCE(igst_rupees,0)),0)::numeric AS igst,
      COALESCE(SUM(COALESCE(cgst_rupees,0)),0)::numeric AS cgst,
      COALESCE(SUM(COALESCE(sgst_rupees,0)),0)::numeric AS sgst
    FROM inv WHERE recipient_gstin IS NULL
  ),
  meta AS (
    SELECT
      COUNT(*) FILTER (WHERE COALESCE(taxable_amount_rupees,0) = 0)::bigint AS nil_cnt,
      COUNT(DISTINCT hsn_code)::bigint AS hsn_cnt
    FROM inv
  )
  SELECT
    v_q_label, p_quarter_start, v_period_end,
    b2b.cnt, b2b.tax_val, b2b.igst, b2b.cgst, b2b.sgst,
    b2c.cnt, b2c.tax_val, b2c.igst, b2c.cgst, b2c.sgst,
    meta.nil_cnt, meta.hsn_cnt,
    (b2b.tax_val + b2c.tax_val)::numeric,
    (b2b.igst + b2c.igst)::numeric,
    (b2b.cgst + b2c.cgst)::numeric,
    (b2b.sgst + b2c.sgst)::numeric,
    0::numeric,
    (b2b.igst + b2c.igst + b2b.cgst + b2c.cgst + b2b.sgst + b2c.sgst)::numeric
  FROM b2b, b2c, meta;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gst_quarterly_prep(date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_gst_quarterly_prep(date) TO authenticated;

-- log_founder_gst_filing_draft also references the wrong columns. Repoint it.
DROP FUNCTION IF EXISTS public.log_founder_gst_filing_draft(text, date);
CREATE OR REPLACE FUNCTION public.log_founder_gst_filing_draft(p_quarter_label text, p_quarter_start date)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_period_end date := (p_quarter_start + interval '3 months' - interval '1 day')::date;
  v_payload jsonb;
  v_taxable numeric := 0;
  v_igst    numeric := 0;
  v_cgst    numeric := 0;
  v_sgst    numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT
    COALESCE(SUM(COALESCE(taxable_amount_rupees,0)),0),
    COALESCE(SUM(COALESCE(igst_rupees,0)),0),
    COALESCE(SUM(COALESCE(cgst_rupees,0)),0),
    COALESCE(SUM(COALESCE(sgst_rupees,0)),0)
    INTO v_taxable, v_igst, v_cgst, v_sgst
  FROM public.gst_invoices g
  WHERE g.issued_at::date >= p_quarter_start
    AND g.issued_at::date <= v_period_end
    AND COALESCE(g.status::text, '') <> 'cancelled';

  v_payload := jsonb_build_object(
    'quarter_label', p_quarter_label,
    'period_start', p_quarter_start,
    'period_end', v_period_end,
    'total_outward_taxable_rupees', v_taxable,
    'total_igst_rupees', v_igst,
    'total_cgst_rupees', v_cgst,
    'total_sgst_rupees', v_sgst
  );

  INSERT INTO public.founder_gst_filings (
    quarter_label, period_start, period_end,
    gstr1_payload, gstr3b_payload,
    total_outward_taxable_rupees, total_igst_rupees,
    total_cgst_rupees, total_sgst_rupees
  ) VALUES (
    p_quarter_label, p_quarter_start, v_period_end,
    v_payload, v_payload,
    v_taxable, v_igst, v_cgst, v_sgst
  )
  ON CONFLICT (quarter_label) DO UPDATE
    SET gstr1_payload = EXCLUDED.gstr1_payload,
        gstr3b_payload = EXCLUDED.gstr3b_payload,
        total_outward_taxable_rupees = EXCLUDED.total_outward_taxable_rupees,
        total_igst_rupees = EXCLUDED.total_igst_rupees,
        total_cgst_rupees = EXCLUDED.total_cgst_rupees,
        total_sgst_rupees = EXCLUDED.total_sgst_rupees,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_gst_filing_draft(text, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_gst_filing_draft(text, date) TO authenticated;

-- ============================================================================
-- 3. r1317 founder_weekly_board_pack — multiple non-existent table/column refs.
--    code_red_events → code_red_requests
--    spot_audit_invites → spot_audit_invitations LEFT JOIN spot_audit_responses
--    engineer_payouts status='paid_out' → 'processed'
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_weekly_board_pack(date);
CREATE OR REPLACE FUNCTION public.founder_weekly_board_pack(p_week_end date DEFAULT current_date)
RETURNS TABLE (
  payload jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_week_start date := p_week_end - INTERVAL '6 days';
  v_4wk_ago    date := p_week_end - INTERVAL '28 days';
  v_result     jsonb;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  WITH
    rev AS (
      SELECT
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'captured' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_gmv,
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'captured' AND method IN ('upi','cash') AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS cash_collected,
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'refunded' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS refunds_issued
      FROM public.payments
    ),
    payouts_week AS (
      -- r1322 FIX: 'paid_out' → 'processed'
      SELECT COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_payouts,
             COUNT(*) FILTER (WHERE status IN ('queued','processing'))::int AS open_payouts
      FROM public.engineer_payouts
    ),
    mrr_now AS (
      SELECT COALESCE(SUM(monthly_fee_rupees), 0)::numeric AS mrr
      FROM public.amc_contracts
      WHERE status = 'active' AND (start_date IS NULL OR start_date <= p_week_end)
        AND (end_date IS NULL OR end_date >= p_week_end)
    ),
    mrr_4wk AS (
      SELECT COALESCE(SUM(monthly_fee_rupees), 0)::numeric AS mrr
      FROM public.amc_contracts
      WHERE (start_date IS NULL OR start_date <= v_4wk_ago)
        AND (end_date IS NULL OR end_date >= v_4wk_ago)
        AND status IN ('active','churned')
    ),
    amc AS (
      SELECT
        COUNT(*) FILTER (WHERE status = 'active' AND (end_date IS NULL OR end_date >= p_week_end))::int AS active_eop,
        COUNT(*) FILTER (WHERE start_date BETWEEN v_week_start AND p_week_end)::int AS signed_week,
        COUNT(*) FILTER (WHERE end_date BETWEEN v_week_start AND p_week_end AND status = 'churned')::int AS churned_week
      FROM public.amc_contracts
    ),
    eng AS (
      SELECT
        COUNT(*) FILTER (WHERE verification_status::text = 'verified')::int AS active_eop,
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS added_week,
        COUNT(*) FILTER (WHERE verification_status::text = 'suspended' AND updated_at::date BETWEEN v_week_start AND p_week_end)::int AS churned_week
      FROM public.engineers
    ),
    eng_jobs AS (
      SELECT COUNT(*)::int AS completed_week
      FROM public.repair_jobs
      WHERE completed_at::date BETWEEN v_week_start AND p_week_end
    ),
    hosp AS (
      SELECT
        COUNT(DISTINCT o.id) FILTER (WHERE o.kind = 'hospital')::int AS active_eop,
        COUNT(DISTINCT o.id) FILTER (WHERE o.kind = 'hospital' AND o.created_at::date BETWEEN v_week_start AND p_week_end)::int AS added_week
      FROM public.organizations o
    ),
    top_state AS (
      SELECT o.state AS state_name, COUNT(rj.id)::int AS jobs_count
      FROM public.repair_jobs rj
      JOIN public.organizations o ON o.id = rj.hospital_org_id
      WHERE rj.completed_at::date BETWEEN v_week_start AND p_week_end
      GROUP BY o.state
      ORDER BY jobs_count DESC
      LIMIT 1
    ),
    ops AS (
      SELECT
        COUNT(*) FILTER (WHERE completed_at::date BETWEEN v_week_start AND p_week_end)::int AS completed_week,
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS initiated_week,
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600.0) FILTER (WHERE completed_at::date BETWEEN v_week_start AND p_week_end)::numeric AS avg_complete_hours
      FROM public.repair_jobs
    ),
    code_red AS (
      -- r1322 FIX: code_red_events doesn't exist → code_red_requests
      SELECT COUNT(*)::int AS cnt
      FROM public.code_red_requests
      WHERE created_at::date BETWEEN v_week_start AND p_week_end
    ),
    disputes AS (
      SELECT
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS week_count,
        COUNT(*) FILTER (WHERE status = 'open')::int AS open_count
      FROM public.disputes
    ),
    grievances AS (
      SELECT
        COUNT(*) FILTER (WHERE created_at::date BETWEEN v_week_start AND p_week_end)::int AS week_count,
        COUNT(*) FILTER (WHERE status IN ('open','in_review'))::int AS open_count
      FROM public.dpdp_grievances
    ),
    incidents AS (
      SELECT COUNT(*) FILTER (WHERE resolved_at IS NULL)::int AS open_count
      FROM public.founder_incidents
    ),
    -- r1322 FIX: spot_audit_invites doesn't exist → invitations LEFT JOIN responses
    audit AS (
      SELECT
        AVG(sr.rating)::numeric AS avg_rating,
        COUNT(*) FILTER (WHERE si.created_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_sent,
        COUNT(sr.id) FILTER (WHERE sr.responded_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_responded
      FROM public.spot_audit_invitations si
      LEFT JOIN public.spot_audit_responses sr ON sr.invitation_id = si.id
      WHERE si.created_at::date BETWEEN v_week_start AND p_week_end
    )
  SELECT jsonb_build_object(
    'week_end', p_week_end,
    'week_start', v_week_start,
    'weekly_gmv_rupees', rev.weekly_gmv,
    'weekly_payouts_rupees', payouts_week.weekly_payouts,
    'weekly_take_rate_pct', CASE WHEN rev.weekly_gmv > 0 THEN ROUND(((rev.weekly_gmv - payouts_week.weekly_payouts) / rev.weekly_gmv) * 100, 2) ELSE 0 END,
    'mrr_eop', mrr_now.mrr,
    'mrr_eop_4wk_ago', mrr_4wk.mrr,
    'mrr_delta_pct_4wk', CASE WHEN mrr_4wk.mrr > 0 THEN ROUND(((mrr_now.mrr - mrr_4wk.mrr) / mrr_4wk.mrr) * 100, 2) ELSE NULL END,
    'amc_active_count_eop', amc.active_eop,
    'amc_signed_this_week', amc.signed_week,
    'amc_churned_this_week', amc.churned_week,
    'amc_net_new', amc.signed_week - amc.churned_week,
    'engineers_active_count_eop', eng.active_eop,
    'engineers_added_this_week', eng.added_week,
    'engineers_churned_this_week', eng.churned_week,
    'engineer_jobs_completed_week', eng_jobs.completed_week,
    'hospitals_active_count_eop', hosp.active_eop,
    'hospitals_added_this_week', hosp.added_week,
    'top_state_by_jobs', COALESCE(top_state.state_name, '—'),
    'top_state_jobs_count', COALESCE(top_state.jobs_count, 0),
    'jobs_completed_this_week', ops.completed_week,
    'jobs_initiated_this_week', ops.initiated_week,
    'average_completion_hours', ROUND(COALESCE(ops.avg_complete_hours, 0), 1),
    'code_red_count_this_week', code_red.cnt,
    'dispute_count_this_week', disputes.week_count,
    'open_disputes_count', disputes.open_count,
    'dpdp_grievance_count_this_week', grievances.week_count,
    'open_grievances_count', grievances.open_count,
    'spot_audit_rating_avg_week', ROUND(COALESCE(audit.avg_rating, 0), 2),
    'spot_audit_invites_sent_week', audit.invites_sent,
    'spot_audit_invites_responded_week', audit.invites_responded,
    'cash_collected_this_week', rev.cash_collected,
    'refunds_issued_this_week', rev.refunds_issued,
    'open_payouts_count', payouts_week.open_payouts,
    'open_incidents_count', incidents.open_count,
    'generated_at', now()
  ) INTO v_result
  FROM rev, payouts_week, mrr_now, mrr_4wk, amc, eng, eng_jobs, hosp,
       LATERAL (SELECT state_name, jobs_count FROM top_state UNION ALL SELECT NULL, 0 LIMIT 1) top_state,
       ops, code_red, disputes, grievances, incidents, audit;

  RETURN QUERY SELECT v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_weekly_board_pack(date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_weekly_board_pack(date) TO authenticated;

-- ============================================================================
-- 4. r1318 founder_amc_churn_scores — 4 non-existent tables
--    amc_scheduled_visits / amc_disputes / code_red_incidents / amc_payments
--    Replace with empty CTEs (zero default) — signals computed from existing
--    sources only. Future migration can wire real overdue visits + payments.
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_amc_churn_scores(int);
CREATE OR REPLACE FUNCTION public.founder_amc_churn_scores(p_limit int DEFAULT 100)
RETURNS TABLE (
  contract_id uuid,
  hospital_org_id uuid,
  hospital_name text,
  amc_tier text,
  monthly_fee_rupees numeric,
  activated_at timestamptz,
  days_active int,
  last_repair_completed_at timestamptz,
  days_since_last_visit int,
  overdue_visits_count int,
  payment_overdue_days int,
  sla_breaches_count int,
  open_disputes_count int,
  code_red_count_180d int,
  churn_score numeric,
  churn_band text,
  primary_signal text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      c.id AS contract_id,
      c.hospital_org_id,
      COALESCE(o.name, '—') AS hospital_name,
      c.amc_tier::text AS amc_tier,
      c.monthly_fee_rupees,
      c.activated_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - c.activated_at))::int) AS days_active
    FROM public.amc_contracts c
    LEFT JOIN public.organizations o ON o.id = c.hospital_org_id
    WHERE c.status = 'active'
  ),
  last_visit AS (
    SELECT rj.amc_contract_id AS contract_id, MAX(rj.completed_at) AS last_repair_completed_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL AND rj.completed_at IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  -- r1322 FIX: amc_sla_breaches uses credit_issued_rupees + detected_at;
  -- table exists but joins on amc_contract_id only when set.
  sla AS (
    SELECT b.amc_contract_id AS contract_id, COUNT(*)::int AS sla_breaches_count
    FROM public.amc_sla_breaches b
    WHERE b.amc_contract_id IS NOT NULL
    GROUP BY b.amc_contract_id
  ),
  -- r1322 FIX: code_red_incidents → code_red_requests (no amc_contract_id join,
  -- so we go through repair_jobs to find which contract a Code Red belongs to)
  code_red AS (
    SELECT rj.amc_contract_id AS contract_id, COUNT(DISTINCT crr.id)::int AS code_red_count_180d
    FROM public.code_red_requests crr
    JOIN public.repair_jobs rj ON rj.id = crr.repair_job_id
    WHERE crr.created_at >= now() - interval '180 days'
      AND rj.amc_contract_id IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  joined AS (
    SELECT
      b.contract_id, b.hospital_org_id, b.hospital_name, b.amc_tier,
      b.monthly_fee_rupees, b.activated_at, b.days_active,
      lv.last_repair_completed_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(lv.last_repair_completed_at, b.activated_at)))::int) AS days_since_last_visit,
      0::int AS overdue_visits_count,           -- amc_scheduled_visits table does not exist
      0::int AS payment_overdue_days,           -- amc_payments table does not exist
      COALESCE(sla.sla_breaches_count, 0) AS sla_breaches_count,
      0::int AS open_disputes_count,            -- amc_disputes table does not exist
      COALESCE(cr.code_red_count_180d, 0) AS code_red_count_180d
    FROM base b
    LEFT JOIN last_visit lv ON lv.contract_id = b.contract_id
    LEFT JOIN sla           ON sla.contract_id = b.contract_id
    LEFT JOIN code_red cr   ON cr.contract_id  = b.contract_id
  ),
  scored AS (
    SELECT j.*,
      LEAST(1.0, GREATEST(0.0,
          LEAST(1.0, j.days_since_last_visit::numeric / 90.0) * 0.35
        + LEAST(1.0, j.sla_breaches_count::numeric / 5.0)     * 0.30
        + LEAST(1.0, j.code_red_count_180d::numeric / 3.0)    * 0.35
      )) AS churn_score_raw
    FROM joined j
  )
  SELECT
    s.contract_id, s.hospital_org_id, s.hospital_name, s.amc_tier,
    s.monthly_fee_rupees, s.activated_at, s.days_active,
    s.last_repair_completed_at, s.days_since_last_visit,
    s.overdue_visits_count, s.payment_overdue_days, s.sla_breaches_count,
    s.open_disputes_count, s.code_red_count_180d,
    ROUND(s.churn_score_raw, 4) AS churn_score,
    CASE WHEN s.churn_score_raw >= 0.75 THEN 'critical'
         WHEN s.churn_score_raw >= 0.50 THEN 'high'
         WHEN s.churn_score_raw >= 0.25 THEN 'medium'
         ELSE 'low' END AS churn_band,
    CASE WHEN s.code_red_count_180d  >= 2 THEN 'multiple code-red incidents'
         WHEN s.sla_breaches_count   >= 3 THEN 'sla breach pattern'
         WHEN s.days_since_last_visit >= 60 THEN 'no visit ' || s.days_since_last_visit::text || 'd'
         ELSE 'baseline' END AS primary_signal
  FROM scored s
  ORDER BY s.churn_score_raw DESC, s.monthly_fee_rupees DESC NULLS LAST
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_scores(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_scores(int) TO authenticated;

-- Also fix founder_amc_churn_summary which has the same broken refs
DROP FUNCTION IF EXISTS public.founder_amc_churn_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_churn_summary()
RETURNS TABLE (
  total_active_contracts bigint,
  critical_band bigint,
  high_band bigint,
  medium_band bigint,
  low_band bigint,
  total_arr_at_risk_critical_rupees numeric,
  total_arr_at_risk_high_rupees     numeric,
  median_churn_score                numeric,
  contracts_with_overdue_visit      bigint,
  contracts_with_payment_overdue    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH s AS (SELECT * FROM public.founder_amc_churn_scores(10000))
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE churn_band = 'critical')::bigint,
    count(*) FILTER (WHERE churn_band = 'high')::bigint,
    count(*) FILTER (WHERE churn_band = 'medium')::bigint,
    count(*) FILTER (WHERE churn_band = 'low')::bigint,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE churn_band = 'critical'), 0)::numeric,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE churn_band = 'high'), 0)::numeric,
    COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY churn_score), 0)::numeric,
    0::bigint,
    0::bigint
  FROM s;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_summary() TO authenticated;

-- ============================================================================
-- 5. r1320 founder_tier_1_home_metadata — wrong columns
--    founder_priority_actions has NO status column (only action_taken)
--    founder_incidents.created_at doesn't exist (use opened_at)
--    founder_incidents.severity is p0..p3 (not 'critical')
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tier_1_home_metadata();
CREATE OR REPLACE FUNCTION public.founder_tier_1_home_metadata()
RETURNS TABLE (
  last_action_at timestamptz,
  total_open_incidents bigint,
  total_critical_alerts bigint,
  cron_failure_rate_24h_pct numeric,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH last_act AS (
    -- r1322 FIX: founder_priority_actions has no status column
    SELECT MAX(created_at) AS last_action_at FROM public.founder_priority_actions
  ),
  inc AS (
    -- r1322 FIX: founder_incidents uses opened_at not created_at; severity is p0..p3
    SELECT COUNT(*) FILTER (WHERE status = 'open') AS open_count,
           COUNT(*) FILTER (WHERE status = 'open' AND severity = 'p0') AS crit_count
    FROM public.founder_incidents
    WHERE opened_at > now() - interval '30 days'
  ),
  cron AS (
    SELECT CASE WHEN COUNT(*) = 0 THEN 0::numeric
                ELSE ROUND((COUNT(*) FILTER (WHERE status = 'failed'))::numeric
                           / COUNT(*)::numeric * 100, 2) END AS fail_pct
    FROM cron.job_run_details
    WHERE start_time > now() - interval '24 hours'
  )
  SELECT
    last_act.last_action_at,
    COALESCE(inc.open_count, 0)::bigint,
    COALESCE(inc.crit_count, 0)::bigint,
    COALESCE(cron.fail_pct, 0)::numeric,
    now()
  FROM last_act, inc, cron;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_1_home_metadata() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_1_home_metadata() TO authenticated;

COMMIT;
