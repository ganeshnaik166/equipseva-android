BEGIN;

-- ============================================================================
-- r1533 — Founder Engineer Payout Cadence Optimizer
-- Analyze preferred payout cadence per engineer; correlate balance vs cycle.
-- ============================================================================

-- Table 1: per-engineer cadence preferences (founder-curated + derived)
CREATE TABLE IF NOT EXISTS public.founder_engineer_payout_cadence_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  preferred_cadence text NOT NULL DEFAULT 'weekly' CHECK (preferred_cadence IN ('weekly','biweekly','monthly','on_demand')),
  preferred_day_of_week int CHECK (preferred_day_of_week BETWEEN 0 AND 6),
  preferred_day_of_month int CHECK (preferred_day_of_month BETWEEN 1 AND 28),
  min_payout_rupees int NOT NULL DEFAULT 500 CHECK (min_payout_rupees >= 0),
  notes text,
  set_by_founder_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_fepc_v2_engineer ON public.founder_engineer_payout_cadence_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_fepc_v2_cadence ON public.founder_engineer_payout_cadence_v2(preferred_cadence);

ALTER TABLE public.founder_engineer_payout_cadence_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fepc_v2_founder_all ON public.founder_engineer_payout_cadence_v2;
CREATE POLICY fepc_v2_founder_all ON public.founder_engineer_payout_cadence_v2
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: rolling snapshot of cadence health per engineer
CREATE TABLE IF NOT EXISTS public.founder_engineer_payout_cadence_snapshots_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  observed_cadence text,
  median_gap_days numeric(10,2),
  avg_balance_rupees int,
  payouts_last_90d int NOT NULL DEFAULT 0,
  cadence_match_score numeric(5,2),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_fepcs_v2_engineer ON public.founder_engineer_payout_cadence_snapshots_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_fepcs_v2_at ON public.founder_engineer_payout_cadence_snapshots_v2(snapshot_at DESC);

ALTER TABLE public.founder_engineer_payout_cadence_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fepcs_v2_founder_all ON public.founder_engineer_payout_cadence_snapshots_v2;
CREATE POLICY fepcs_v2_founder_all ON public.founder_engineer_payout_cadence_snapshots_v2
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- log helpers (3)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_cadence_set(
  p_engineer_id uuid,
  p_cadence text,
  p_min_payout int
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cadence_set',
    jsonb_build_object('engineer_id', p_engineer_id, 'cadence', p_cadence, 'min_payout_rupees', p_min_payout));
END;$$;

CREATE OR REPLACE FUNCTION public.log_founder_cadence_snapshot(
  p_engineer_id uuid,
  p_observed text,
  p_match_score numeric
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cadence_snapshot',
    jsonb_build_object('engineer_id', p_engineer_id, 'observed', p_observed, 'match_score', p_match_score));
END;$$;

CREATE OR REPLACE FUNCTION public.log_founder_cadence_clear(
  p_engineer_id uuid
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cadence_clear',
    jsonb_build_object('engineer_id', p_engineer_id));
END;$$;

-- ============================================================================
-- Read RPC 1: KPIs roll-up
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_kpis()
RETURNS TABLE (
  total_engineers int,
  with_preference int,
  weekly_count int,
  biweekly_count int,
  monthly_count int,
  on_demand_count int,
  total_pending_payouts int,
  total_pending_rupees bigint,
  total_paid_90d_rupees bigint,
  median_gap_days numeric,
  avg_match_score numeric,
  engineers_overdue int,
  engineers_below_min int,
  snapshots_total int,
  snapshots_last_7d int,
  avg_min_payout_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH eng AS (
    SELECT id FROM public.engineers
  ),
  pref AS (
    SELECT preferred_cadence, min_payout_rupees FROM public.founder_engineer_payout_cadence_v2
  ),
  payouts AS (
    SELECT
      COUNT(*) FILTER (WHERE paid_at IS NULL)::int AS pending_n,
      COALESCE(SUM(amount_rupees) FILTER (WHERE paid_at IS NULL), 0)::bigint AS pending_sum,
      COALESCE(SUM(amount_rupees) FILTER (WHERE paid_at IS NOT NULL AND paid_at > now() - interval '90 days'), 0)::bigint AS paid_90d_sum
    FROM public.engineer_payouts
  ),
  gaps AS (
    SELECT engineer_id,
      EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (PARTITION BY engineer_user_id ORDER BY created_at)))/86400.0 AS gap_days,
      engineer_user_id
    FROM public.engineer_payouts
    WHERE paid_at IS NOT NULL AND paid_at > now() - interval '180 days'
  ),
  snaps AS (
    SELECT median_gap_days, cadence_match_score, snapshot_at FROM public.founder_engineer_payout_cadence_snapshots_v2
  )
  SELECT
    (SELECT COUNT(*) FROM eng)::int,
    (SELECT COUNT(*) FROM pref)::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='weekly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='biweekly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='monthly')::int,
    (SELECT COUNT(*) FROM pref WHERE preferred_cadence='on_demand')::int,
    (SELECT pending_n FROM payouts),
    (SELECT pending_sum FROM payouts),
    (SELECT paid_90d_sum FROM payouts),
    (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_days) FROM gaps WHERE gap_days IS NOT NULL),
    (SELECT AVG(cadence_match_score) FROM snaps),
    (SELECT COUNT(DISTINCT engineer_user_id) FROM public.engineer_payouts WHERE paid_at IS NULL AND created_at < now() - interval '14 days')::int,
    (SELECT COUNT(*) FROM public.founder_engineer_payout_cadence_v2 c
      WHERE EXISTS (
        SELECT 1 FROM public.engineers e WHERE e.id=c.engineer_id
        AND COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts p WHERE p.engineer_user_id=e.user_id AND p.paid_at IS NULL),0) < c.min_payout_rupees
      ))::int,
    (SELECT COUNT(*) FROM snaps)::int,
    (SELECT COUNT(*) FROM snaps WHERE snapshot_at > now() - interval '7 days')::int,
    (SELECT AVG(min_payout_rupees) FROM pref);
END;$$;

-- ============================================================================
-- Read RPC 2: per-engineer roster
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_roster()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_email text,
  preferred_cadence text,
  min_payout_rupees int,
  pending_count int,
  pending_rupees bigint,
  last_payout_at timestamptz,
  days_since_last numeric,
  cached_tier text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.id AS engineer_id,
    COALESCE(p.full_name, p.email, e.id::text) AS engineer_name,
    p.email,
    COALESCE(c.preferred_cadence, 'unset') AS preferred_cadence,
    COALESCE(c.min_payout_rupees, 0) AS min_payout_rupees,
    COALESCE((SELECT COUNT(*)::int FROM public.engineer_payouts ep WHERE ep.engineer_user_id=e.user_id AND ep.paid_at IS NULL), 0),
    COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts ep WHERE ep.engineer_user_id=e.user_id AND ep.paid_at IS NULL), 0)::bigint,
    (SELECT MAX(paid_at) FROM public.engineer_payouts ep WHERE ep.engineer_user_id=e.user_id AND ep.paid_at IS NOT NULL),
    EXTRACT(EPOCH FROM (now() - (SELECT MAX(paid_at) FROM public.engineer_payouts ep WHERE ep.engineer_user_id=e.user_id AND ep.paid_at IS NOT NULL)))/86400.0,
    e.cached_highest_tier
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN public.founder_engineer_payout_cadence_v2 c ON c.engineer_id = e.id
  ORDER BY (COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts ep WHERE ep.engineer_user_id=e.user_id AND ep.paid_at IS NULL),0)) DESC NULLS LAST
  LIMIT 200;
END;$$;

-- ============================================================================
-- Read RPC 3: cadence-mismatch alerts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_mismatches()
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  preferred_cadence text,
  observed_cadence text,
  median_gap_days numeric,
  match_score numeric,
  snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.engineer_id)
    s.engineer_id,
    COALESCE(p.full_name, p.email, s.engineer_id::text),
    c.preferred_cadence,
    s.observed_cadence,
    s.median_gap_days,
    s.cadence_match_score,
    s.snapshot_at
  FROM public.founder_engineer_payout_cadence_snapshots_v2 s
  LEFT JOIN public.founder_engineer_payout_cadence_v2 c ON c.engineer_id = s.engineer_id
  LEFT JOIN public.engineers e ON e.id = s.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE s.cadence_match_score IS NOT NULL AND s.cadence_match_score < 70
  ORDER BY s.engineer_id, s.snapshot_at DESC
  LIMIT 100;
END;$$;

-- ============================================================================
-- Read RPC 4: recent snapshots
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_recent_snapshots()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  snapshot_at timestamptz,
  observed_cadence text,
  median_gap_days numeric,
  avg_balance_rupees int,
  payouts_last_90d int,
  match_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.engineer_id,
    COALESCE(p.full_name, p.email, s.engineer_id::text),
    s.snapshot_at,
    s.observed_cadence,
    s.median_gap_days,
    s.avg_balance_rupees,
    s.payouts_last_90d,
    s.cadence_match_score
  FROM public.founder_engineer_payout_cadence_snapshots_v2 s
  LEFT JOIN public.engineers e ON e.id = s.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY s.snapshot_at DESC
  LIMIT 100;
END;$$;

-- ============================================================================
-- Write RPC 1: set/upsert preference
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_set(
  p_engineer_id uuid,
  p_cadence text,
  p_min_payout int,
  p_dow int DEFAULT NULL,
  p_dom int DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_engineer_payout_cadence_v2 (
    engineer_id, preferred_cadence, preferred_day_of_week, preferred_day_of_month,
    min_payout_rupees, notes, set_by_founder_user_id
  ) VALUES (
    p_engineer_id, p_cadence, p_dow, p_dom, p_min_payout, p_notes, auth.uid()
  )
  ON CONFLICT (engineer_id) DO UPDATE SET
    preferred_cadence = EXCLUDED.preferred_cadence,
    preferred_day_of_week = EXCLUDED.preferred_day_of_week,
    preferred_day_of_month = EXCLUDED.preferred_day_of_month,
    min_payout_rupees = EXCLUDED.min_payout_rupees,
    notes = EXCLUDED.notes,
    set_by_founder_user_id = auth.uid(),
    updated_at = now()
  RETURNING id INTO v_id;
  PERFORM public.log_founder_cadence_set(p_engineer_id, p_cadence, p_min_payout);
  RETURN v_id;
END;$$;

-- ============================================================================
-- Write RPC 2: clear preference
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_clear(
  p_engineer_id uuid
) RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM public.founder_engineer_payout_cadence_v2 WHERE engineer_id = p_engineer_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM public.log_founder_cadence_clear(p_engineer_id);
  RETURN v_n;
END;$$;

-- ============================================================================
-- Write RPC 3: capture snapshot for an engineer
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_payout_cadence_capture(
  p_engineer_id uuid
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid;
  v_observed text;
  v_median numeric;
  v_avg_bal int;
  v_count int;
  v_pref text;
  v_score numeric;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT user_id INTO v_user FROM public.engineers WHERE id = p_engineer_id;
  IF v_user IS NULL THEN RAISE EXCEPTION 'engineer not found'; END IF;

  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY g.gap)
  INTO v_median
  FROM (
    SELECT EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (ORDER BY created_at)))/86400.0 AS gap
    FROM public.engineer_payouts
    WHERE engineer_user_id = v_user AND paid_at IS NOT NULL AND paid_at > now() - interval '180 days'
  ) g
  WHERE g.gap IS NOT NULL;

  SELECT COUNT(*)::int, COALESCE(AVG(amount_rupees),0)::int
  INTO v_count, v_avg_bal
  FROM public.engineer_payouts
  WHERE engineer_user_id = v_user AND paid_at IS NOT NULL AND paid_at > now() - interval '90 days';

  v_observed := CASE
    WHEN v_median IS NULL THEN 'unknown'
    WHEN v_median <= 9 THEN 'weekly'
    WHEN v_median <= 18 THEN 'biweekly'
    WHEN v_median <= 35 THEN 'monthly'
    ELSE 'on_demand'
  END;

  SELECT preferred_cadence INTO v_pref FROM public.founder_engineer_payout_cadence_v2 WHERE engineer_id = p_engineer_id;
  v_score := CASE WHEN v_pref IS NULL THEN NULL
                  WHEN v_pref = v_observed THEN 100.0
                  ELSE 40.0 END;

  INSERT INTO public.founder_engineer_payout_cadence_snapshots_v2 (
    engineer_id, observed_cadence, median_gap_days, avg_balance_rupees,
    payouts_last_90d, cadence_match_score
  ) VALUES (
    p_engineer_id, v_observed, v_median, v_avg_bal, v_count, v_score
  ) RETURNING id INTO v_id;

  PERFORM public.log_founder_cadence_snapshot(p_engineer_id, v_observed, v_score);
  RETURN v_id;
END;$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_kpis() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_roster() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_mismatches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_mismatches() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_recent_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_recent_snapshots() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_set(uuid, text, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_set(uuid, text, int, int, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_clear(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_clear(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_payout_cadence_capture(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payout_cadence_capture(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_founder_cadence_set(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cadence_set(uuid, text, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.log_founder_cadence_snapshot(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cadence_snapshot(uuid, text, numeric) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.log_founder_cadence_clear(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cadence_clear(uuid) TO authenticated;

COMMIT;