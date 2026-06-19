BEGIN;

-- =====================================================================
-- r1317 — founder weekly board pack
-- Auto-generated KPI snapshot for investor/board reporting cadence.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_weekly_board_pack_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_end date NOT NULL UNIQUE,
  generated_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb NOT NULL,
  generated_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  shared_with_board boolean NOT NULL DEFAULT false,
  shared_at timestamptz NULL,
  shared_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_fwbp_log_week_end ON public.founder_weekly_board_pack_log (week_end DESC);

ALTER TABLE public.founder_weekly_board_pack_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwbp_log_founder_read ON public.founder_weekly_board_pack_log;
CREATE POLICY fwbp_log_founder_read ON public.founder_weekly_board_pack_log
  FOR SELECT TO authenticated USING (public.is_founder());

-- ---------------------------------------------------------------------
-- Main RPC: founder_weekly_board_pack(p_week_end)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_weekly_board_pack(date);

CREATE OR REPLACE FUNCTION public.founder_weekly_board_pack(p_week_end date DEFAULT current_date)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week_start date := p_week_end - INTERVAL '6 days';
  v_4wk_ago date := p_week_end - INTERVAL '28 days';
  v_result jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  WITH
    rev AS (
      SELECT
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'captured' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_gmv,
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'captured' AND method IN ('upi','cash') AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS cash_collected,
        COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'refunded' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS refunds_issued
      FROM public.payments
    ),
    payouts_week AS (
      SELECT COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'paid_out' AND created_at::date BETWEEN v_week_start AND p_week_end), 0)::numeric AS weekly_payouts,
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
      SELECT COUNT(*)::int AS cnt
      FROM public.code_red_events
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
    audit AS (
      SELECT
        AVG(rating)::numeric AS avg_rating,
        COUNT(*) FILTER (WHERE invited_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_sent,
        COUNT(*) FILTER (WHERE responded_at::date BETWEEN v_week_start AND p_week_end)::int AS invites_responded
      FROM public.spot_audit_invites
      WHERE invited_at::date BETWEEN v_week_start AND p_week_end
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
    'top_state_by_jobs', COALESCE((SELECT state_name FROM top_state), 'n/a'),
    'top_state_jobs_count', COALESCE((SELECT jobs_count FROM top_state), 0),
    'jobs_completed_this_week', ops.completed_week,
    'jobs_initiated_this_week', ops.initiated_week,
    'average_completion_hours', ROUND(COALESCE(ops.avg_complete_hours, 0), 1),
    'code_red_count_this_week', code_red.cnt,
    'dispute_count_this_week', disputes.week_count,
    'dpdp_grievance_count_this_week', grievances.week_count,
    'spot_audit_rating_avg_week', ROUND(COALESCE(audit.avg_rating, 0), 2),
    'spot_audit_invites_sent_week', COALESCE(audit.invites_sent, 0),
    'spot_audit_invites_responded_week', COALESCE(audit.invites_responded, 0),
    'cash_collected_this_week', rev.cash_collected,
    'refunds_issued_this_week', rev.refunds_issued,
    'open_payouts_count', payouts_week.open_payouts,
    'open_disputes_count', disputes.open_count,
    'open_incidents_count', incidents.open_count,
    'open_grievances_count', grievances.open_count
  ) INTO v_result
  FROM rev, payouts_week, mrr_now, mrr_4wk, amc, eng, eng_jobs, hosp, ops, code_red, disputes, grievances, incidents, audit;

  -- Upsert log row for audit / board-shared toggling
  INSERT INTO public.founder_weekly_board_pack_log (week_end, payload, generated_by)
  VALUES (p_week_end, v_result, auth.uid())
  ON CONFLICT (week_end) DO UPDATE
    SET payload = EXCLUDED.payload, generated_at = now(), generated_by = auth.uid();

  -- Merge sharing flags into output
  SELECT v_result
    || jsonb_build_object(
         'shared_with_board', l.shared_with_board,
         'shared_at', l.shared_at
       )
    INTO v_result
  FROM public.founder_weekly_board_pack_log l
  WHERE l.week_end = p_week_end;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_weekly_board_pack(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_weekly_board_pack(date) TO authenticated;

-- ---------------------------------------------------------------------
-- History RPC: 13-week time series of top 10 KPIs
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_weekly_board_pack_history(int);

CREATE OR REPLACE FUNCTION public.founder_weekly_board_pack_history(p_weeks int DEFAULT 13)
RETURNS TABLE (
  week_end date,
  weekly_gmv_rupees numeric,
  weekly_payouts_rupees numeric,
  mrr_eop numeric,
  amc_active_count_eop int,
  amc_net_new int,
  engineers_active_count_eop int,
  hospitals_active_count_eop int,
  jobs_completed_this_week int,
  code_red_count_this_week int,
  spot_audit_rating_avg_week numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_w int;
  v_we date;
  v_payload jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  FOR v_w IN 0 .. (LEAST(p_weeks, 52) - 1) LOOP
    v_we := current_date - (v_w * 7);
    SELECT l.payload INTO v_payload
      FROM public.founder_weekly_board_pack_log l
     WHERE l.week_end = v_we;

    IF v_payload IS NULL THEN
      CONTINUE;
    END IF;

    week_end := v_we;
    weekly_gmv_rupees := COALESCE((v_payload->>'weekly_gmv_rupees')::numeric, 0);
    weekly_payouts_rupees := COALESCE((v_payload->>'weekly_payouts_rupees')::numeric, 0);
    mrr_eop := COALESCE((v_payload->>'mrr_eop')::numeric, 0);
    amc_active_count_eop := COALESCE((v_payload->>'amc_active_count_eop')::int, 0);
    amc_net_new := COALESCE((v_payload->>'amc_net_new')::int, 0);
    engineers_active_count_eop := COALESCE((v_payload->>'engineers_active_count_eop')::int, 0);
    hospitals_active_count_eop := COALESCE((v_payload->>'hospitals_active_count_eop')::int, 0);
    jobs_completed_this_week := COALESCE((v_payload->>'jobs_completed_this_week')::int, 0);
    code_red_count_this_week := COALESCE((v_payload->>'code_red_count_this_week')::int, 0);
    spot_audit_rating_avg_week := COALESCE((v_payload->>'spot_audit_rating_avg_week')::numeric, 0);
    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_weekly_board_pack_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_weekly_board_pack_history(int) TO authenticated;

-- ---------------------------------------------------------------------
-- Mark week as board-shared
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_founder_board_pack_shared(date);

CREATE OR REPLACE FUNCTION public.log_founder_board_pack_shared(p_week_end date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.founder_weekly_board_pack_log%ROWTYPE;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_weekly_board_pack_log
     SET shared_with_board = true,
         shared_at = now(),
         shared_by = auth.uid()
   WHERE week_end = p_week_end
   RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no board pack log for week_end=%', p_week_end USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'week_end', v_row.week_end,
    'shared_at', v_row.shared_at
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_board_pack_shared(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_board_pack_shared(date) TO authenticated;

COMMIT;