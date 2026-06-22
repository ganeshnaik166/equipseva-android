BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_personal_decisions_r1922 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_label text NOT NULL,
  context_md text,
  decided_at timestamptz NOT NULL DEFAULT now(),
  reasoning_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','reversed','wins','losses')),
  retro_at timestamptz,
  retro_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_decision_alternatives_r1922 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_personal_decisions_r1922(id) ON DELETE CASCADE,
  alternative_md text NOT NULL,
  why_rejected_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_decisions_r1922 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_alternatives_r1922 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_decisions_r1922 ON public.founder_personal_decisions_r1922;
CREATE POLICY founder_all_decisions_r1922 ON public.founder_personal_decisions_r1922
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_alternatives_r1922 ON public.founder_decision_alternatives_r1922;
CREATE POLICY founder_all_alternatives_r1922 ON public.founder_decision_alternatives_r1922
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_decisions
CREATE OR REPLACE FUNCTION public.list_decisions_r1922()
RETURNS TABLE (
  id uuid,
  decision_label text,
  context_md text,
  decided_at timestamptz,
  reasoning_md text,
  status text,
  retro_at timestamptz,
  retro_md text
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
  SELECT d.id, d.decision_label, d.context_md, d.decided_at, d.reasoning_md, d.status, d.retro_at, d.retro_md
  FROM public.founder_personal_decisions_r1922 d
  ORDER BY d.decided_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_decision
CREATE OR REPLACE FUNCTION public.log_decision_r1922(
  p_label text,
  p_context_md text,
  p_reasoning_md text
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
  INSERT INTO public.founder_personal_decisions_r1922 (decision_label, context_md, reasoning_md)
  VALUES (p_label, p_context_md, p_reasoning_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decision_r1922',
          jsonb_build_object('id', v_id, 'label', p_label));

  RETURN v_id;
END;
$$;

-- 3. list_alternatives
CREATE OR REPLACE FUNCTION public.list_alternatives_r1922(p_decision_id uuid)
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  alternative_md text,
  why_rejected_md text,
  recorded_at timestamptz
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
  SELECT a.id, a.decision_id, a.alternative_md, a.why_rejected_md, a.recorded_at
  FROM public.founder_decision_alternatives_r1922 a
  WHERE a.decision_id = p_decision_id
  ORDER BY a.recorded_at DESC;
END;
$$;

-- 4. log_alternative
CREATE OR REPLACE FUNCTION public.log_alternative_r1922(
  p_decision_id uuid,
  p_alternative_md text,
  p_why_rejected_md text
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
  INSERT INTO public.founder_decision_alternatives_r1922 (decision_id, alternative_md, why_rejected_md)
  VALUES (p_decision_id, p_alternative_md, p_why_rejected_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_alternative_r1922',
          jsonb_build_object('id', v_id, 'decision_id', p_decision_id));

  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1922(
  p_decision_id uuid,
  p_status text,
  p_retro_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('active','reversed','wins','losses') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_personal_decisions_r1922
  SET status = p_status,
      retro_md = COALESCE(p_retro_md, retro_md),
      retro_at = CASE WHEN p_status IN ('reversed','wins','losses') THEN now() ELSE retro_at END,
      updated_at = now()
  WHERE id = p_decision_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1922',
          jsonb_build_object('id', p_decision_id, 'status', p_status));
END;
$$;

-- 6. decisions_by_status
CREATE OR REPLACE FUNCTION public.decisions_by_status_r1922()
RETURNS TABLE (
  status text,
  decision_count bigint
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
  SELECT d.status, count(*)::bigint AS decision_count
  FROM public.founder_personal_decisions_r1922 d
  GROUP BY d.status
  ORDER BY d.status;
END;
$$;

-- 7. recent_retros
CREATE OR REPLACE FUNCTION public.recent_retros_r1922()
RETURNS TABLE (
  id uuid,
  decision_label text,
  status text,
  retro_at timestamptz,
  retro_md text
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
  SELECT d.id, d.decision_label, d.status, d.retro_at, d.retro_md
  FROM public.founder_personal_decisions_r1922 d
  WHERE d.retro_at IS NOT NULL
  ORDER BY d.retro_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_decisions_r1922() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r1922(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_alternatives_r1922(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_alternative_r1922(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1922(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decisions_by_status_r1922() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_retros_r1922() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decisions_r1922() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r1922(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_alternatives_r1922(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_alternative_r1922(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1922(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decisions_by_status_r1922() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_retros_r1922() TO authenticated;

COMMIT;
