BEGIN;

-- =====================================================================
-- Round 1700 — Engineer Retention Risk Score
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_retention_risk_r1700 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tenure_months int NOT NULL DEFAULT 0,
  months_since_raise int NOT NULL DEFAULT 0,
  complaint_count int NOT NULL DEFAULT 0,
  recent_market_offer_count int NOT NULL DEFAULT 0,
  risk_score int NOT NULL DEFAULT 0 CHECK (risk_score >= 0 AND risk_score <= 100),
  risk_band text NOT NULL CHECK (risk_band IN ('low','med','high')),
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_err_r1700_engineer ON public.engineer_retention_risk_r1700(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_err_r1700_band ON public.engineer_retention_risk_r1700(risk_band);
CREATE INDEX IF NOT EXISTS idx_err_r1700_computed ON public.engineer_retention_risk_r1700(computed_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_retention_actions_r1700 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_id uuid NOT NULL REFERENCES public.engineer_retention_risk_r1700(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('counter_offer','conversation','raise','promote','let_go')),
  action_at timestamptz NOT NULL DEFAULT now(),
  founder_note text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_era_r1700_risk ON public.engineer_retention_actions_r1700(risk_id);
CREATE INDEX IF NOT EXISTS idx_era_r1700_status ON public.engineer_retention_actions_r1700(status);
CREATE INDEX IF NOT EXISTS idx_era_r1700_action_at ON public.engineer_retention_actions_r1700(action_at DESC);

ALTER TABLE public.engineer_retention_risk_r1700 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_retention_actions_r1700 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_err_r1700 ON public.engineer_retention_risk_r1700;
CREATE POLICY founder_all_err_r1700 ON public.engineer_retention_risk_r1700
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_era_r1700 ON public.engineer_retention_actions_r1700;
CREATE POLICY founder_all_era_r1700 ON public.engineer_retention_actions_r1700
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_risks
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_risks_r1700()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  tenure_months int,
  months_since_raise int,
  complaint_count int,
  recent_market_offer_count int,
  risk_score int,
  risk_band text,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, p.email::text,
         r.tenure_months, r.months_since_raise, r.complaint_count,
         r.recent_market_offer_count, r.risk_score, r.risk_band, r.computed_at
  FROM public.engineer_retention_risk_r1700 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.risk_score DESC, r.computed_at DESC;
END;
$$;

-- =====================================================================
-- RPC 2: compute_risk
-- =====================================================================
CREATE OR REPLACE FUNCTION public.compute_risk_r1700(
  p_engineer_user_id uuid,
  p_tenure_months int,
  p_months_since_raise int,
  p_complaint_count int,
  p_recent_market_offer_count int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_score int;
  v_band text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_score := LEAST(100,
    (CASE WHEN p_months_since_raise > 18 THEN 30
          WHEN p_months_since_raise > 12 THEN 20
          WHEN p_months_since_raise > 6 THEN 10 ELSE 0 END)
    + (p_complaint_count * 8)
    + (p_recent_market_offer_count * 15)
    + (CASE WHEN p_tenure_months < 6 THEN 15
            WHEN p_tenure_months < 12 THEN 8 ELSE 0 END)
  );

  v_band := CASE WHEN v_score >= 60 THEN 'high'
                 WHEN v_score >= 30 THEN 'med'
                 ELSE 'low' END;

  INSERT INTO public.engineer_retention_risk_r1700 (
    engineer_user_id, tenure_months, months_since_raise,
    complaint_count, recent_market_offer_count, risk_score, risk_band
  ) VALUES (
    p_engineer_user_id, p_tenure_months, p_months_since_raise,
    p_complaint_count, p_recent_market_offer_count, v_score, v_band
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'compute_risk_r1700',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'score', v_score, 'band', v_band));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1700(p_risk_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  risk_id uuid,
  engineer_email text,
  action_type text,
  action_at timestamptz,
  founder_note text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.risk_id, p.email::text, a.action_type, a.action_at, a.founder_note, a.status
  FROM public.engineer_retention_actions_r1700 a
  LEFT JOIN public.engineer_retention_risk_r1700 r ON r.id = a.risk_id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE (p_risk_id IS NULL OR a.risk_id = p_risk_id)
  ORDER BY a.action_at DESC;
END;
$$;

-- =====================================================================
-- RPC 4: log_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1700(
  p_risk_id uuid,
  p_action_type text,
  p_founder_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_retention_actions_r1700 (risk_id, action_type, founder_note, status)
  VALUES (p_risk_id, p_action_type, p_founder_note, 'planned')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1700',
          jsonb_build_object('id', v_id, 'risk_id', p_risk_id, 'type', p_action_type));
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: complete_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.complete_action_r1700(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_retention_actions_r1700
  SET status = 'done', updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_action_r1700',
          jsonb_build_object('id', p_action_id));
END;
$$;

-- =====================================================================
-- RPC 6: high_risk_engineers
-- =====================================================================
CREATE OR REPLACE FUNCTION public.high_risk_engineers_r1700()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  risk_score int,
  risk_band text,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, p.email::text, r.risk_score, r.risk_band, r.computed_at
  FROM public.engineer_retention_risk_r1700 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.risk_band = 'high'
  ORDER BY r.risk_score DESC, r.computed_at DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- RPC 7: recent_retention_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_retention_actions_r1700()
RETURNS TABLE (
  id uuid,
  risk_id uuid,
  engineer_email text,
  action_type text,
  action_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.risk_id, p.email::text, a.action_type, a.action_at, a.status
  FROM public.engineer_retention_actions_r1700 a
  LEFT JOIN public.engineer_retention_risk_r1700 r ON r.id = a.risk_id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY a.action_at DESC
  LIMIT 30;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_risks_r1700() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compute_risk_r1700(uuid,int,int,int,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1700(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1700(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_action_r1700(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_risk_engineers_r1700() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_retention_actions_r1700() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_risks_r1700() TO authenticated;
GRANT EXECUTE ON FUNCTION public.compute_risk_r1700(uuid,int,int,int,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1700(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1700(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_action_r1700(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_risk_engineers_r1700() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_retention_actions_r1700() TO authenticated;

COMMIT;