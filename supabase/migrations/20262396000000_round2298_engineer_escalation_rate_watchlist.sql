BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_escalation_watchlist_r2298 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  observation_window_start date NOT NULL,
  observation_window_end date NOT NULL,
  total_jobs_in_window int NOT NULL DEFAULT 0,
  escalations_in_window int NOT NULL DEFAULT 0,
  escalation_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  prior_window_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  rate_delta_pct numeric(6,2) NOT NULL DEFAULT 0,
  severity text NOT NULL DEFAULT 'amber' CHECK (severity IN ('red','amber','yellow','green')),
  watchlist_status text NOT NULL DEFAULT 'active' CHECK (watchlist_status IN ('active','coaching','probation','cleared','terminated')),
  last_reviewed_at timestamptz,
  last_reviewed_by text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eew_r2298_engineer ON public.engineer_escalation_watchlist_r2298(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eew_r2298_severity ON public.engineer_escalation_watchlist_r2298(severity, watchlist_status);

ALTER TABLE public.engineer_escalation_watchlist_r2298 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eew_r2298_founder_all ON public.engineer_escalation_watchlist_r2298;
CREATE POLICY eew_r2298_founder_all ON public.engineer_escalation_watchlist_r2298
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_coaching_outcomes_r2298 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  watchlist_id uuid NOT NULL REFERENCES public.engineer_escalation_watchlist_r2298(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  coaching_plan text NOT NULL,
  coaching_assigned_at timestamptz NOT NULL DEFAULT now(),
  coaching_assigned_by text,
  target_metric text NOT NULL DEFAULT 'reduce_escalation_rate',
  target_value_pct numeric(6,2),
  outcome text NOT NULL DEFAULT 'in_progress' CHECK (outcome IN ('in_progress','improved','no_change','worsened','escalated','closed')),
  outcome_recorded_at timestamptz,
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eco_r2298_watchlist ON public.engineer_coaching_outcomes_r2298(watchlist_id);
CREATE INDEX IF NOT EXISTS idx_eco_r2298_engineer ON public.engineer_coaching_outcomes_r2298(engineer_user_id);

ALTER TABLE public.engineer_coaching_outcomes_r2298 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eco_r2298_founder_all ON public.engineer_coaching_outcomes_r2298;
CREATE POLICY eco_r2298_founder_all ON public.engineer_coaching_outcomes_r2298
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list watchlist
CREATE OR REPLACE FUNCTION public.r2298_list_watchlist()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  total_jobs_in_window int,
  escalations_in_window int,
  escalation_rate_pct numeric,
  prior_window_rate_pct numeric,
  rate_delta_pct numeric,
  severity text,
  watchlist_status text,
  last_reviewed_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.engineer_user_id, p.email::text AS engineer_email,
         w.total_jobs_in_window, w.escalations_in_window, w.escalation_rate_pct,
         w.prior_window_rate_pct, w.rate_delta_pct, w.severity, w.watchlist_status,
         w.last_reviewed_at, w.notes, w.created_at
  FROM public.engineer_escalation_watchlist_r2298 w
  LEFT JOIN public.profiles p ON p.id = w.engineer_user_id
  ORDER BY w.rate_delta_pct DESC NULLS LAST, w.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_list_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_list_watchlist() TO authenticated;

-- RPC 2: severity summary
CREATE OR REPLACE FUNCTION public.r2298_severity_summary()
RETURNS TABLE (severity text, watchlist_status text, n bigint, avg_rate numeric, avg_delta numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.severity, w.watchlist_status, COUNT(*)::bigint,
         ROUND(AVG(w.escalation_rate_pct)::numeric, 2),
         ROUND(AVG(w.rate_delta_pct)::numeric, 2)
  FROM public.engineer_escalation_watchlist_r2298 w
  GROUP BY w.severity, w.watchlist_status
  ORDER BY w.severity, w.watchlist_status;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_severity_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_severity_summary() TO authenticated;

-- RPC 3: add to watchlist
CREATE OR REPLACE FUNCTION public.r2298_add_to_watchlist(
  p_engineer_user_id uuid,
  p_window_start date,
  p_window_end date,
  p_total_jobs int,
  p_escalations int,
  p_prior_rate numeric,
  p_severity text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_rate numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_rate := CASE WHEN p_total_jobs > 0 THEN ROUND((p_escalations::numeric / p_total_jobs::numeric) * 100, 2) ELSE 0 END;
  INSERT INTO public.engineer_escalation_watchlist_r2298(
    engineer_user_id, observation_window_start, observation_window_end,
    total_jobs_in_window, escalations_in_window, escalation_rate_pct,
    prior_window_rate_pct, rate_delta_pct, severity, notes
  ) VALUES (
    p_engineer_user_id, p_window_start, p_window_end,
    p_total_jobs, p_escalations, v_rate,
    COALESCE(p_prior_rate, 0), v_rate - COALESCE(p_prior_rate, 0),
    COALESCE(p_severity, 'amber'), p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_add_to_watchlist(uuid, date, date, int, int, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_add_to_watchlist(uuid, date, date, int, int, numeric, text, text) TO authenticated;

-- RPC 4: assign coaching
CREATE OR REPLACE FUNCTION public.r2298_assign_coaching(
  p_watchlist_id uuid,
  p_plan text,
  p_target_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_engineer uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT engineer_user_id INTO v_engineer FROM public.engineer_escalation_watchlist_r2298 WHERE id = p_watchlist_id;
  IF v_engineer IS NULL THEN RAISE EXCEPTION 'watchlist row not found'; END IF;
  INSERT INTO public.engineer_coaching_outcomes_r2298(
    watchlist_id, engineer_user_id, coaching_plan, coaching_assigned_by, target_value_pct
  ) VALUES (
    p_watchlist_id, v_engineer, p_plan, (auth.jwt()->>'email'), p_target_pct
  )
  RETURNING id INTO v_id;
  UPDATE public.engineer_escalation_watchlist_r2298
     SET watchlist_status = 'coaching', updated_at = now()
   WHERE id = p_watchlist_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_assign_coaching(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_assign_coaching(uuid, text, numeric) TO authenticated;

-- RPC 5: record outcome
CREATE OR REPLACE FUNCTION public.r2298_record_outcome(
  p_outcome_id uuid,
  p_outcome text,
  p_outcome_notes text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_coaching_outcomes_r2298
     SET outcome = p_outcome,
         outcome_recorded_at = now(),
         outcome_notes = p_outcome_notes,
         updated_at = now()
   WHERE id = p_outcome_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_record_outcome(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_record_outcome(uuid, text, text) TO authenticated;

-- RPC 6: update watchlist status
CREATE OR REPLACE FUNCTION public.r2298_update_status(
  p_watchlist_id uuid,
  p_status text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_escalation_watchlist_r2298
     SET watchlist_status = p_status,
         notes = COALESCE(p_notes, notes),
         last_reviewed_at = now(),
         last_reviewed_by = (auth.jwt()->>'email'),
         updated_at = now()
   WHERE id = p_watchlist_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_update_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_update_status(uuid, text, text) TO authenticated;

-- RPC 7: list coaching outcomes for a watchlist row
CREATE OR REPLACE FUNCTION public.r2298_list_outcomes(p_watchlist_id uuid)
RETURNS TABLE (
  id uuid,
  coaching_plan text,
  coaching_assigned_at timestamptz,
  coaching_assigned_by text,
  target_value_pct numeric,
  outcome text,
  outcome_recorded_at timestamptz,
  outcome_notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.coaching_plan, o.coaching_assigned_at, o.coaching_assigned_by,
         o.target_value_pct, o.outcome, o.outcome_recorded_at, o.outcome_notes
  FROM public.engineer_coaching_outcomes_r2298 o
  WHERE o.watchlist_id = p_watchlist_id
  ORDER BY o.coaching_assigned_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2298_list_outcomes(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2298_list_outcomes(uuid) TO authenticated;

COMMIT;
