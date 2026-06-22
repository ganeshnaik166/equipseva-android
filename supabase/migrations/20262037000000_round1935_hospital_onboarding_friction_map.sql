BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_onboarding_friction_r1935 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  stage text NOT NULL CHECK (stage IN ('signup','legal','integration','training','first_job','billing_setup')),
  friction_score int NOT NULL CHECK (friction_score BETWEEN 1 AND 10),
  blocker_md text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolving','resolved','escalated')),
  surfaced_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_onboarding_action_log_r1935 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  friction_id uuid NOT NULL REFERENCES public.hospital_onboarding_friction_r1935(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('info_provided','escalation','workaround','feature_request','training_offered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hofr1935_hospital ON public.hospital_onboarding_friction_r1935(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hofr1935_stage ON public.hospital_onboarding_friction_r1935(stage);
CREATE INDEX IF NOT EXISTS idx_hofr1935_status ON public.hospital_onboarding_friction_r1935(status);
CREATE INDEX IF NOT EXISTS idx_hoalr1935_friction ON public.hospital_onboarding_action_log_r1935(friction_id);

ALTER TABLE public.hospital_onboarding_friction_r1935 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_onboarding_action_log_r1935 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hofr1935_founder_all ON public.hospital_onboarding_friction_r1935;
CREATE POLICY hofr1935_founder_all ON public.hospital_onboarding_friction_r1935
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hoalr1935_founder_all ON public.hospital_onboarding_action_log_r1935;
CREATE POLICY hoalr1935_founder_all ON public.hospital_onboarding_action_log_r1935
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_frictions
CREATE OR REPLACE FUNCTION public.list_frictions_r1935()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  stage text,
  friction_score int,
  blocker_md text,
  status text,
  surfaced_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_id, p.email, f.stage, f.friction_score, f.blocker_md, f.status, f.surfaced_at, f.resolved_at
    FROM public.hospital_onboarding_friction_r1935 f
    LEFT JOIN public.profiles p ON p.id = f.hospital_id
    ORDER BY f.surfaced_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_friction
CREATE OR REPLACE FUNCTION public.log_friction_r1935(
  p_hospital_id uuid,
  p_stage text,
  p_friction_score int,
  p_blocker_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_onboarding_friction_r1935(hospital_id, stage, friction_score, blocker_md)
  VALUES (p_hospital_id, p_stage, p_friction_score, p_blocker_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_friction_r1935',
    jsonb_build_object('friction_id', v_id, 'hospital_id', p_hospital_id, 'stage', p_stage, 'score', p_friction_score));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1935(p_friction_id uuid)
RETURNS TABLE (
  id uuid,
  friction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.friction_id, a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_onboarding_action_log_r1935 a
    WHERE a.friction_id = p_friction_id
    ORDER BY a.taken_at DESC;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r1935(
  p_friction_id uuid,
  p_action_type text,
  p_outcome_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_onboarding_action_log_r1935(friction_id, action_type, by_email, outcome_md)
  VALUES (p_friction_id, p_action_type, v_email, p_outcome_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r1935',
    jsonb_build_object('action_id', v_id, 'friction_id', p_friction_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_resolved
CREATE OR REPLACE FUNCTION public.mark_resolved_r1935(p_friction_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_onboarding_friction_r1935
  SET status = 'resolved', resolved_at = now(), updated_at = now()
  WHERE id = p_friction_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_resolved_r1935',
    jsonb_build_object('friction_id', p_friction_id));
END;
$$;

-- RPC 6: top_friction_stages
CREATE OR REPLACE FUNCTION public.top_friction_stages_r1935()
RETURNS TABLE (
  stage text,
  open_count bigint,
  avg_score numeric,
  max_score int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.stage,
           count(*) FILTER (WHERE f.status IN ('open','resolving','escalated'))::bigint AS open_count,
           round(avg(f.friction_score)::numeric, 2) AS avg_score,
           max(f.friction_score) AS max_score
    FROM public.hospital_onboarding_friction_r1935 f
    GROUP BY f.stage
    ORDER BY open_count DESC, avg_score DESC;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1935()
RETURNS TABLE (
  id uuid,
  friction_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text,
  stage text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.friction_id, a.action_type, a.taken_at, a.by_email, a.outcome_md, f.stage
    FROM public.hospital_onboarding_action_log_r1935 a
    LEFT JOIN public.hospital_onboarding_friction_r1935 f ON f.id = a.friction_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_frictions_r1935() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_friction_r1935(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1935(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1935(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_resolved_r1935(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_friction_stages_r1935() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1935() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_frictions_r1935() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_friction_r1935(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1935(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1935(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_resolved_r1935(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_friction_stages_r1935() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1935() TO authenticated;

COMMIT;
