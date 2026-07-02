BEGIN;

-- ============================================================================
-- Round 2201: Founder cash-position daily snapshot
-- Tracks bank balance, MRR run-rate, runway months, burn alerts
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_cash_snapshots_r2201 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL DEFAULT current_date,
  bank_balance_rupees numeric(14,2) NOT NULL DEFAULT 0,
  mrr_rupees numeric(14,2) NOT NULL DEFAULT 0,
  monthly_burn_rupees numeric(14,2) NOT NULL DEFAULT 0,
  runway_months numeric(8,2) NOT NULL DEFAULT 0,
  cash_in_rupees numeric(14,2) NOT NULL DEFAULT 0,
  cash_out_rupees numeric(14,2) NOT NULL DEFAULT 0,
  ar_outstanding_rupees numeric(14,2) NOT NULL DEFAULT 0,
  ap_outstanding_rupees numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_snap_r2201_date
  ON public.founder_cash_snapshots_r2201(snapshot_date DESC);

CREATE TABLE IF NOT EXISTS public.founder_burn_alerts_r2201 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_category text NOT NULL CHECK (alert_category IN ('runway_short','burn_spike','mrr_drop','ar_aging','bank_low','other')),
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  title text NOT NULL,
  detail text,
  metric_value_rupees numeric(14,2),
  threshold_value_rupees numeric(14,2),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved','muted')),
  raised_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  raised_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution_note text
);

CREATE INDEX IF NOT EXISTS idx_burn_alerts_r2201_status
  ON public.founder_burn_alerts_r2201(status, raised_at DESC);

CREATE INDEX IF NOT EXISTS idx_burn_alerts_r2201_severity
  ON public.founder_burn_alerts_r2201(severity, raised_at DESC);

ALTER TABLE public.founder_cash_snapshots_r2201 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_burn_alerts_r2201 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_cash_snapshots_r2201;
CREATE POLICY founder_all ON public.founder_cash_snapshots_r2201
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_burn_alerts_r2201;
CREATE POLICY founder_all ON public.founder_burn_alerts_r2201
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_cash_snapshots_r2201
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_cash_snapshots_r2201()
RETURNS TABLE (
  id uuid,
  snapshot_date date,
  bank_balance_rupees numeric,
  mrr_rupees numeric,
  monthly_burn_rupees numeric,
  runway_months numeric,
  ar_outstanding_rupees numeric,
  ap_outstanding_rupees numeric,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.snapshot_date, s.bank_balance_rupees, s.mrr_rupees,
           s.monthly_burn_rupees, s.runway_months, s.ar_outstanding_rupees,
           s.ap_outstanding_rupees, s.notes, s.created_at
    FROM public.founder_cash_snapshots_r2201 s
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 90;
END;
$$;

-- ============================================================================
-- RPC 2: recent_actions_r2201
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2201()
RETURNS TABLE (
  id uuid,
  actor_email text,
  op_name text,
  after_value jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.actor_email, l.op_name, l.after_value, l.created_at
    FROM public.founder_action_log l
    WHERE l.op_name LIKE 'op_r2201%'
    ORDER BY l.created_at DESC
    LIMIT 50;
END;
$$;

-- ============================================================================
-- RPC 3: top_burn_alert_categories_r2201
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_burn_alert_categories_r2201()
RETURNS TABLE (
  alert_category text,
  total_count int,
  open_count int,
  critical_count int,
  last_raised_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.alert_category,
           COUNT(*)::int AS total_count,
           (COUNT(*) FILTER (WHERE a.status = 'open'))::int AS open_count,
           (COUNT(*) FILTER (WHERE a.severity = 'critical'))::int AS critical_count,
           MAX(a.raised_at) AS last_raised_at
    FROM public.founder_burn_alerts_r2201 a
    GROUP BY a.alert_category
    ORDER BY total_count DESC
    LIMIT 20;
END;
$$;

-- ============================================================================
-- RPC 4: log_cash_snapshot_r2201
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_cash_snapshot_r2201(
  p_bank_balance numeric,
  p_mrr numeric,
  p_monthly_burn numeric,
  p_ar_outstanding numeric,
  p_ap_outstanding numeric,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_runway numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_monthly_burn > 0 THEN
    v_runway := ROUND(p_bank_balance / p_monthly_burn, 2);
  ELSE
    v_runway := 999;
  END IF;

  INSERT INTO public.founder_cash_snapshots_r2201(
    bank_balance_rupees, mrr_rupees, monthly_burn_rupees, runway_months,
    ar_outstanding_rupees, ap_outstanding_rupees, notes, recorded_by
  ) VALUES (
    COALESCE(p_bank_balance,0), COALESCE(p_mrr,0), COALESCE(p_monthly_burn,0),
    v_runway, COALESCE(p_ar_outstanding,0), COALESCE(p_ap_outstanding,0),
    p_notes, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2201_log_snapshot',
    jsonb_build_object('id', v_id, 'bank', p_bank_balance, 'burn', p_monthly_burn, 'runway', v_runway));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: log_action_r2201 — raise a burn alert
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r2201(
  p_category text,
  p_severity text,
  p_title text,
  p_detail text,
  p_metric numeric,
  p_threshold numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_burn_alerts_r2201(
    alert_category, severity, title, detail,
    metric_value_rupees, threshold_value_rupees, raised_by
  ) VALUES (
    COALESCE(p_category,'other'), COALESCE(p_severity,'medium'),
    p_title, p_detail, p_metric, p_threshold, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2201_raise_alert',
    jsonb_build_object('id', v_id, 'category', p_category, 'severity', p_severity));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 6: mark_status_r2201 — update burn alert status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2201(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('open','acknowledged','resolved','muted') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE public.founder_burn_alerts_r2201
  SET status = p_status,
      resolved_at = CASE WHEN p_status = 'resolved' THEN now() ELSE resolved_at END
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2201_mark_status',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 7: cash_position_summary_r2201 — aggregate health snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cash_position_summary_r2201()
RETURNS TABLE (
  latest_bank_rupees numeric,
  latest_mrr_rupees numeric,
  latest_burn_rupees numeric,
  latest_runway_months numeric,
  snapshots_30d int,
  open_alerts int,
  critical_alerts int,
  avg_runway_30d numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT s.bank_balance_rupees, s.mrr_rupees, s.monthly_burn_rupees, s.runway_months
    FROM public.founder_cash_snapshots_r2201 s
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 1
  ),
  snap_agg AS (
    SELECT COUNT(*)::int AS c30,
           ROUND(AVG(s.runway_months)::numeric, 2) AS avg_run
    FROM public.founder_cash_snapshots_r2201 s
    WHERE s.snapshot_date >= current_date - INTERVAL '30 days'
  ),
  alert_agg AS (
    SELECT (COUNT(*) FILTER (WHERE a.status = 'open'))::int AS open_c,
           (COUNT(*) FILTER (WHERE a.severity = 'critical' AND a.status = 'open'))::int AS crit_c
    FROM public.founder_burn_alerts_r2201 a
  )
  SELECT COALESCE((SELECT bank_balance_rupees FROM latest), 0),
         COALESCE((SELECT mrr_rupees FROM latest), 0),
         COALESCE((SELECT monthly_burn_rupees FROM latest), 0),
         COALESCE((SELECT runway_months FROM latest), 0),
         COALESCE((SELECT c30 FROM snap_agg), 0),
         COALESCE((SELECT open_c FROM alert_agg), 0),
         COALESCE((SELECT crit_c FROM alert_agg), 0),
         COALESCE((SELECT avg_run FROM snap_agg), 0);
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE ALL ON FUNCTION public.list_cash_snapshots_r2201() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2201() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_burn_alert_categories_r2201() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_cash_snapshot_r2201(numeric,numeric,numeric,numeric,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2201(text,text,text,text,numeric,numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2201(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cash_position_summary_r2201() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cash_snapshots_r2201() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2201() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_burn_alert_categories_r2201() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cash_snapshot_r2201(numeric,numeric,numeric,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2201(text,text,text,text,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2201(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cash_position_summary_r2201() TO authenticated;

COMMIT;
