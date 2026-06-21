BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_health_scores_r1691 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  window_start date NOT NULL,
  avg_rating numeric(3,2),
  nps_score int,
  payment_lag_days int,
  open_tickets int,
  health_score int NOT NULL CHECK (health_score BETWEEN 0 AND 100),
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hhs_r1691_hospital ON public.hospital_health_scores_r1691(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hhs_r1691_score ON public.hospital_health_scores_r1691(health_score);
CREATE INDEX IF NOT EXISTS idx_hhs_r1691_window ON public.hospital_health_scores_r1691(window_start DESC);

CREATE TABLE IF NOT EXISTS public.hospital_health_review_actions_r1691 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.hospital_health_scores_r1691(id) ON DELETE CASCADE,
  action text NOT NULL,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done')),
  due_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hhra_r1691_score ON public.hospital_health_review_actions_r1691(score_id);
CREATE INDEX IF NOT EXISTS idx_hhra_r1691_status ON public.hospital_health_review_actions_r1691(status);

ALTER TABLE public.hospital_health_scores_r1691 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_health_review_actions_r1691 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hhs_r1691 ON public.hospital_health_scores_r1691;
CREATE POLICY founder_all_hhs_r1691 ON public.hospital_health_scores_r1691
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hhra_r1691 ON public.hospital_health_review_actions_r1691;
CREATE POLICY founder_all_hhra_r1691 ON public.hospital_health_review_actions_r1691
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_scores
CREATE OR REPLACE FUNCTION public.list_hospital_health_scores_r1691()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  window_start date,
  avg_rating numeric,
  nps_score int,
  payment_lag_days int,
  open_tickets int,
  health_score int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.hospital_user_id,
         COALESCE(o.name, p.email, h.hospital_user_id::text) AS hospital_name,
         h.window_start, h.avg_rating, h.nps_score, h.payment_lag_days,
         h.open_tickets, h.health_score, h.computed_at
  FROM public.hospital_health_scores_r1691 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY h.computed_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: compute_score
CREATE OR REPLACE FUNCTION public.compute_hospital_health_score_r1691(
  p_hospital_user_id uuid,
  p_window_start date,
  p_avg_rating numeric,
  p_nps_score int,
  p_payment_lag_days int,
  p_open_tickets int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_score int;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_score := GREATEST(0, LEAST(100,
    ((COALESCE(p_avg_rating, 3.0) / 5.0) * 30)::int +
    ((COALESCE(p_nps_score, 0) + 100) * 30 / 200)::int +
    GREATEST(0, 20 - COALESCE(p_payment_lag_days, 0)) +
    GREATEST(0, 20 - COALESCE(p_open_tickets, 0) * 4)
  ));

  INSERT INTO public.hospital_health_scores_r1691
    (hospital_user_id, window_start, avg_rating, nps_score, payment_lag_days, open_tickets, health_score)
  VALUES (p_hospital_user_id, p_window_start, p_avg_rating, p_nps_score, p_payment_lag_days, p_open_tickets, v_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'compute_hospital_health_score_r1691',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'health_score', v_score));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_hospital_health_actions_r1691(p_score_id uuid)
RETURNS TABLE (
  id uuid,
  score_id uuid,
  action text,
  owner_email text,
  status text,
  due_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.score_id, a.action, a.owner_email, a.status, a.due_at, a.created_at
  FROM public.hospital_health_review_actions_r1691 a
  WHERE a.score_id = p_score_id
  ORDER BY a.created_at DESC;
END;
$$;

-- RPC 4: add_action
CREATE OR REPLACE FUNCTION public.add_hospital_health_action_r1691(
  p_score_id uuid,
  p_action text,
  p_owner_email text,
  p_due_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_health_review_actions_r1691 (score_id, action, owner_email, due_at)
  VALUES (p_score_id, p_action, p_owner_email, p_due_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_hospital_health_action_r1691',
    jsonb_build_object('id', v_id, 'score_id', p_score_id, 'action', p_action));

  RETURN v_id;
END;
$$;

-- RPC 5: complete_action
CREATE OR REPLACE FUNCTION public.complete_hospital_health_action_r1691(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_health_review_actions_r1691
  SET status = 'done', updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_hospital_health_action_r1691',
    jsonb_build_object('id', p_action_id));
END;
$$;

-- RPC 6: top_at_risk
CREATE OR REPLACE FUNCTION public.top_at_risk_hospitals_r1691()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  health_score int,
  avg_rating numeric,
  payment_lag_days int,
  open_tickets int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.hospital_user_id,
         COALESCE(o.name, p.email, h.hospital_user_id::text) AS hospital_name,
         h.health_score, h.avg_rating, h.payment_lag_days, h.open_tickets, h.computed_at
  FROM public.hospital_health_scores_r1691 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE h.health_score < 50
  ORDER BY h.health_score ASC, h.computed_at DESC
  LIMIT 50;
END;
$$;

-- RPC 7: healthy_hospitals
CREATE OR REPLACE FUNCTION public.healthy_hospitals_r1691()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  health_score int,
  avg_rating numeric,
  nps_score int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.hospital_user_id,
         COALESCE(o.name, p.email, h.hospital_user_id::text) AS hospital_name,
         h.health_score, h.avg_rating, h.nps_score, h.computed_at
  FROM public.hospital_health_scores_r1691 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE h.health_score >= 80
  ORDER BY h.health_score DESC, h.computed_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_hospital_health_scores_r1691() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compute_hospital_health_score_r1691(uuid, date, numeric, int, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_hospital_health_actions_r1691(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_hospital_health_action_r1691(uuid, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_hospital_health_action_r1691(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_hospitals_r1691() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.healthy_hospitals_r1691() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_health_scores_r1691() TO authenticated;
GRANT EXECUTE ON FUNCTION public.compute_hospital_health_score_r1691(uuid, date, numeric, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hospital_health_actions_r1691(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_hospital_health_action_r1691(uuid, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_hospital_health_action_r1691(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_at_risk_hospitals_r1691() TO authenticated;
GRANT EXECUTE ON FUNCTION public.healthy_hospitals_r1691() TO authenticated;

COMMIT;