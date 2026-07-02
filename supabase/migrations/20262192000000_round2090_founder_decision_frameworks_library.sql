BEGIN;

-- Table 1: frameworks library
CREATE TABLE IF NOT EXISTS public.founder_decision_frameworks_library_r2090 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_label text NOT NULL,
  framework_md text NOT NULL,
  framework_type text NOT NULL CHECK (framework_type IN ('pros_cons','cost_benefit','regret_minimization','eisenhower_matrix','reversibility','two_way_door')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decision_frameworks_library_r2090 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2090_lib ON public.founder_decision_frameworks_library_r2090;
CREATE POLICY founder_all_r2090_lib ON public.founder_decision_frameworks_library_r2090
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: application log
CREATE TABLE IF NOT EXISTS public.founder_framework_application_log_r2090 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_id uuid NOT NULL REFERENCES public.founder_decision_frameworks_library_r2090(id) ON DELETE CASCADE,
  decision_context_md text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text NOT NULL CHECK (outcome IN ('used','discarded','modified','inspired_new')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_framework_application_log_r2090 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2090_log ON public.founder_framework_application_log_r2090;
CREATE POLICY founder_all_r2090_log ON public.founder_framework_application_log_r2090
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_frameworks
CREATE OR REPLACE FUNCTION public.list_frameworks_r2090()
RETURNS TABLE(id uuid, framework_label text, framework_type text, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.framework_label, f.framework_type, f.status, f.captured_at
    FROM public.founder_decision_frameworks_library_r2090 f
    ORDER BY f.captured_at DESC;
END;
$$;

-- RPC 2: log_framework
CREATE OR REPLACE FUNCTION public.log_framework_r2090(
  p_label text,
  p_md text,
  p_type text
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
  INSERT INTO public.founder_decision_frameworks_library_r2090(framework_label, framework_md, framework_type)
  VALUES (p_label, p_md, p_type)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_framework_r2090', jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type));

  RETURN v_id;
END;
$$;

-- RPC 3: list_applications
CREATE OR REPLACE FUNCTION public.list_applications_r2090(p_framework_id uuid)
RETURNS TABLE(id uuid, framework_id uuid, decision_context_md text, applied_at timestamptz, by_email text, outcome text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.framework_id, a.decision_context_md, a.applied_at, a.by_email, a.outcome
    FROM public.founder_framework_application_log_r2090 a
    WHERE a.framework_id = p_framework_id
    ORDER BY a.applied_at DESC;
END;
$$;

-- RPC 4: log_application
CREATE OR REPLACE FUNCTION public.log_application_r2090(
  p_framework_id uuid,
  p_context_md text,
  p_outcome text
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
  INSERT INTO public.founder_framework_application_log_r2090(framework_id, decision_context_md, by_email, outcome)
  VALUES (p_framework_id, p_context_md, v_email, p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_application_r2090', jsonb_build_object('id', v_id, 'framework_id', p_framework_id, 'outcome', p_outcome));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2090(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_decision_frameworks_library_r2090
  SET status = p_status, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2090', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- RPC 6: most_used
CREATE OR REPLACE FUNCTION public.most_used_r2090()
RETURNS TABLE(framework_id uuid, framework_label text, framework_type text, application_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.framework_label, f.framework_type, COUNT(a.id)::bigint AS application_count
    FROM public.founder_decision_frameworks_library_r2090 f
    LEFT JOIN public.founder_framework_application_log_r2090 a ON a.framework_id = f.id
    GROUP BY f.id, f.framework_label, f.framework_type
    ORDER BY application_count DESC, f.framework_label ASC
    LIMIT 20;
END;
$$;

-- RPC 7: recent_applications
CREATE OR REPLACE FUNCTION public.recent_applications_r2090()
RETURNS TABLE(id uuid, framework_id uuid, framework_label text, decision_context_md text, applied_at timestamptz, by_email text, outcome text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.framework_id, f.framework_label, a.decision_context_md, a.applied_at, a.by_email, a.outcome
    FROM public.founder_framework_application_log_r2090 a
    JOIN public.founder_decision_frameworks_library_r2090 f ON f.id = a.framework_id
    ORDER BY a.applied_at DESC
    LIMIT 50;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_frameworks_r2090() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_framework_r2090(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_applications_r2090(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_application_r2090(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2090(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.most_used_r2090() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_applications_r2090() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_frameworks_r2090() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_framework_r2090(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_applications_r2090(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_application_r2090(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2090(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.most_used_r2090() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_applications_r2090() TO authenticated;

COMMIT;
