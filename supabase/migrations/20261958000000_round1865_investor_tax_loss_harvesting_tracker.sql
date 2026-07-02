BEGIN;

-- =========================================================================
-- Round 1865 — Investor Tax-Loss Harvesting Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_tax_loss_harvesting_r1865 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fiscal_year int NOT NULL,
  total_realized_gain_rupees bigint NOT NULL DEFAULT 0,
  total_realized_loss_rupees bigint NOT NULL DEFAULT 0,
  harvest_strategy_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('active','planned','superseded')),
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_tlh_r1865_investor ON public.investor_tax_loss_harvesting_r1865(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_tlh_r1865_status ON public.investor_tax_loss_harvesting_r1865(status);
CREATE INDEX IF NOT EXISTS idx_inv_tlh_r1865_fy ON public.investor_tax_loss_harvesting_r1865(fiscal_year);

ALTER TABLE public.investor_tax_loss_harvesting_r1865 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_inv_tlh_r1865 ON public.investor_tax_loss_harvesting_r1865;
CREATE POLICY p_founder_all_inv_tlh_r1865
  ON public.investor_tax_loss_harvesting_r1865
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_tax_loss_recommendations_r1865 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.investor_tax_loss_harvesting_r1865(id) ON DELETE CASCADE,
  recommendation text NOT NULL,
  urgency text NOT NULL DEFAULT 'info' CHECK (urgency IN ('critical','important','info')),
  estimated_savings_rupees bigint NOT NULL DEFAULT 0,
  founder_decision text CHECK (founder_decision IN ('accepted','declined','deferred')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_tlh_rec_r1865_plan ON public.investor_tax_loss_recommendations_r1865(plan_id);
CREATE INDEX IF NOT EXISTS idx_inv_tlh_rec_r1865_urgency ON public.investor_tax_loss_recommendations_r1865(urgency);
CREATE INDEX IF NOT EXISTS idx_inv_tlh_rec_r1865_decision ON public.investor_tax_loss_recommendations_r1865(founder_decision);

ALTER TABLE public.investor_tax_loss_recommendations_r1865 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_inv_tlh_rec_r1865 ON public.investor_tax_loss_recommendations_r1865;
CREATE POLICY p_founder_all_inv_tlh_rec_r1865
  ON public.investor_tax_loss_recommendations_r1865
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_plans
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_list_plans(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  fiscal_year int,
  total_realized_gain_rupees bigint,
  total_realized_loss_rupees bigint,
  net_position_rupees bigint,
  harvest_strategy_md text,
  status text,
  last_assessed_at timestamptz,
  recommendations_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    h.id,
    h.investor_id,
    p.email AS investor_email,
    h.fiscal_year,
    h.total_realized_gain_rupees,
    h.total_realized_loss_rupees,
    (h.total_realized_gain_rupees - h.total_realized_loss_rupees) AS net_position_rupees,
    h.harvest_strategy_md,
    h.status,
    h.last_assessed_at,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865 r WHERE r.plan_id = h.id)::int AS recommendations_count
  FROM public.investor_tax_loss_harvesting_r1865 h
  LEFT JOIN public.profiles p ON p.id = h.investor_id
  WHERE p_status IS NULL OR h.status = p_status
  ORDER BY h.fiscal_year DESC, h.updated_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_list_plans(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_list_plans(text) TO authenticated;

-- =========================================================================
-- RPC 2: save_plan
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_save_plan(
  p_investor_id uuid,
  p_fiscal_year int,
  p_total_realized_gain_rupees bigint,
  p_total_realized_loss_rupees bigint,
  p_harvest_strategy_md text,
  p_status text DEFAULT 'planned'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_tax_loss_harvesting_r1865(
    investor_id, fiscal_year, total_realized_gain_rupees, total_realized_loss_rupees,
    harvest_strategy_md, status, last_assessed_at
  )
  VALUES (
    p_investor_id, p_fiscal_year,
    COALESCE(p_total_realized_gain_rupees, 0),
    COALESCE(p_total_realized_loss_rupees, 0),
    p_harvest_strategy_md, COALESCE(p_status, 'planned'), now()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1865_save_plan',
    jsonb_build_object(
      'id', v_id,
      'investor_id', p_investor_id,
      'fiscal_year', p_fiscal_year,
      'total_realized_gain_rupees', p_total_realized_gain_rupees,
      'total_realized_loss_rupees', p_total_realized_loss_rupees,
      'status', p_status
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_save_plan(uuid, int, bigint, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_save_plan(uuid, int, bigint, bigint, text, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_recommendations
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_list_recommendations(p_plan_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  investor_email text,
  fiscal_year int,
  recommendation text,
  urgency text,
  estimated_savings_rupees bigint,
  founder_decision text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.plan_id,
    p.email AS investor_email,
    h.fiscal_year,
    r.recommendation,
    r.urgency,
    r.estimated_savings_rupees,
    r.founder_decision,
    r.decided_at,
    r.created_at
  FROM public.investor_tax_loss_recommendations_r1865 r
  JOIN public.investor_tax_loss_harvesting_r1865 h ON h.id = r.plan_id
  LEFT JOIN public.profiles p ON p.id = h.investor_id
  WHERE p_plan_id IS NULL OR r.plan_id = p_plan_id
  ORDER BY
    CASE r.urgency WHEN 'critical' THEN 1 WHEN 'important' THEN 2 ELSE 3 END,
    r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_list_recommendations(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_list_recommendations(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_recommendation
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_log_recommendation(
  p_plan_id uuid,
  p_recommendation text,
  p_urgency text DEFAULT 'info',
  p_estimated_savings_rupees bigint DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_tax_loss_recommendations_r1865(
    plan_id, recommendation, urgency, estimated_savings_rupees
  )
  VALUES (
    p_plan_id, p_recommendation, COALESCE(p_urgency, 'info'),
    COALESCE(p_estimated_savings_rupees, 0)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1865_log_recommendation',
    jsonb_build_object(
      'id', v_id,
      'plan_id', p_plan_id,
      'recommendation', p_recommendation,
      'urgency', p_urgency,
      'estimated_savings_rupees', p_estimated_savings_rupees
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_log_recommendation(uuid, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_log_recommendation(uuid, text, text, bigint) TO authenticated;

-- =========================================================================
-- RPC 5: decide_recommendation
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_decide_recommendation(
  p_recommendation_id uuid,
  p_founder_decision text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_founder_decision NOT IN ('accepted','declined','deferred') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;

  v_email := (auth.jwt()->>'email');

  UPDATE public.investor_tax_loss_recommendations_r1865
  SET founder_decision = p_founder_decision,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_recommendation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r1865_decide_recommendation',
    jsonb_build_object(
      'recommendation_id', p_recommendation_id,
      'founder_decision', p_founder_decision
    ));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_decide_recommendation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_decide_recommendation(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 6: total_savings_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_total_savings_summary()
RETURNS TABLE (
  total_plans int,
  active_plans int,
  planned_plans int,
  superseded_plans int,
  total_recommendations int,
  accepted_count int,
  declined_count int,
  deferred_count int,
  pending_count int,
  total_estimated_savings_rupees bigint,
  accepted_savings_rupees bigint,
  total_realized_gain_rupees bigint,
  total_realized_loss_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.investor_tax_loss_harvesting_r1865)::int AS total_plans,
    (SELECT COUNT(*) FROM public.investor_tax_loss_harvesting_r1865 WHERE status = 'active')::int AS active_plans,
    (SELECT COUNT(*) FROM public.investor_tax_loss_harvesting_r1865 WHERE status = 'planned')::int AS planned_plans,
    (SELECT COUNT(*) FROM public.investor_tax_loss_harvesting_r1865 WHERE status = 'superseded')::int AS superseded_plans,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865)::int AS total_recommendations,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865 WHERE founder_decision = 'accepted')::int AS accepted_count,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865 WHERE founder_decision = 'declined')::int AS declined_count,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865 WHERE founder_decision = 'deferred')::int AS deferred_count,
    (SELECT COUNT(*) FROM public.investor_tax_loss_recommendations_r1865 WHERE founder_decision IS NULL)::int AS pending_count,
    (SELECT COALESCE(SUM(estimated_savings_rupees), 0) FROM public.investor_tax_loss_recommendations_r1865)::bigint AS total_estimated_savings_rupees,
    (SELECT COALESCE(SUM(estimated_savings_rupees), 0) FROM public.investor_tax_loss_recommendations_r1865 WHERE founder_decision = 'accepted')::bigint AS accepted_savings_rupees,
    (SELECT COALESCE(SUM(total_realized_gain_rupees), 0) FROM public.investor_tax_loss_harvesting_r1865)::bigint AS total_realized_gain_rupees,
    (SELECT COALESCE(SUM(total_realized_loss_rupees), 0) FROM public.investor_tax_loss_harvesting_r1865)::bigint AS total_realized_loss_rupees;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_total_savings_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_total_savings_summary() TO authenticated;

-- =========================================================================
-- RPC 7: urgent_recommendations
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1865_urgent_recommendations(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  investor_email text,
  fiscal_year int,
  recommendation text,
  urgency text,
  estimated_savings_rupees bigint,
  founder_decision text,
  created_at timestamptz,
  days_pending int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.plan_id,
    p.email AS investor_email,
    h.fiscal_year,
    r.recommendation,
    r.urgency,
    r.estimated_savings_rupees,
    r.founder_decision,
    r.created_at,
    EXTRACT(DAY FROM (now() - r.created_at))::int AS days_pending
  FROM public.investor_tax_loss_recommendations_r1865 r
  JOIN public.investor_tax_loss_harvesting_r1865 h ON h.id = r.plan_id
  LEFT JOIN public.profiles p ON p.id = h.investor_id
  WHERE r.founder_decision IS NULL
    AND r.urgency IN ('critical','important')
  ORDER BY
    CASE r.urgency WHEN 'critical' THEN 1 WHEN 'important' THEN 2 ELSE 3 END,
    r.estimated_savings_rupees DESC,
    r.created_at ASC
  LIMIT COALESCE(p_limit, 10);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1865_urgent_recommendations(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1865_urgent_recommendations(int) TO authenticated;

COMMIT;