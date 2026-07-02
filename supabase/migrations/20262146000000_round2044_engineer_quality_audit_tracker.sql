BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_quality_audit_r2044 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  audit_score int NOT NULL CHECK (audit_score BETWEEN 0 AND 100),
  audit_category text NOT NULL CHECK (audit_category IN ('work_quality','safety','customer_handling','documentation','cleanup')),
  status text NOT NULL DEFAULT 'passed' CHECK (status IN ('passed','needs_improvement','failed','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eqa_r2044_engineer ON public.engineer_quality_audit_r2044(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eqa_r2044_status ON public.engineer_quality_audit_r2044(status);
CREATE INDEX IF NOT EXISTS idx_eqa_r2044_date ON public.engineer_quality_audit_r2044(audit_date DESC);

CREATE TABLE IF NOT EXISTS public.engineer_audit_action_log_r2044 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.engineer_quality_audit_r2044(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','retrained','recognition','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eaal_r2044_audit ON public.engineer_audit_action_log_r2044(audit_id);
CREATE INDEX IF NOT EXISTS idx_eaal_r2044_taken ON public.engineer_audit_action_log_r2044(taken_at DESC);

ALTER TABLE public.engineer_quality_audit_r2044 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_audit_action_log_r2044 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eqa_r2044 ON public.engineer_quality_audit_r2044;
CREATE POLICY founder_all_eqa_r2044 ON public.engineer_quality_audit_r2044
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eaal_r2044 ON public.engineer_audit_action_log_r2044;
CREATE POLICY founder_all_eaal_r2044 ON public.engineer_audit_action_log_r2044
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_audits_r2044(int);
CREATE OR REPLACE FUNCTION public.list_audits_r2044(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  audit_date date,
  audit_score int,
  audit_category text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_user_id, p.email, a.audit_date, a.audit_score, a.audit_category, a.status, a.captured_at
    FROM public.engineer_quality_audit_r2044 a
    LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
    ORDER BY a.captured_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

DROP FUNCTION IF EXISTS public.log_audit_r2044(uuid, date, int, text, text);
CREATE OR REPLACE FUNCTION public.log_audit_r2044(
  p_engineer_user_id uuid,
  p_audit_date date,
  p_audit_score int,
  p_audit_category text,
  p_status text
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
  INSERT INTO public.engineer_quality_audit_r2044(engineer_user_id, audit_date, audit_score, audit_category, status)
  VALUES (p_engineer_user_id, p_audit_date, p_audit_score, p_audit_category, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2044.log_audit',
          jsonb_build_object('audit_id', v_id, 'engineer_user_id', p_engineer_user_id, 'score', p_audit_score, 'category', p_audit_category, 'status', p_status));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r2044(uuid, int);
CREATE OR REPLACE FUNCTION public.list_actions_r2044(p_audit_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  audit_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_audit_action_log_r2044 l
    WHERE (p_audit_id IS NULL OR l.audit_id = p_audit_id)
    ORDER BY l.taken_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r2044(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2044(
  p_audit_id uuid,
  p_action_type text,
  p_notes_md text
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
  INSERT INTO public.engineer_audit_action_log_r2044(audit_id, action_type, by_email, notes_md)
  VALUES (p_audit_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r2044.log_action',
          jsonb_build_object('action_id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r2044(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2044(p_audit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_quality_audit_r2044
     SET status = p_status, updated_at = now()
   WHERE id = p_audit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2044.mark_status',
          jsonb_build_object('audit_id', p_audit_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.failed_audits_r2044(int);
CREATE OR REPLACE FUNCTION public.failed_audits_r2044(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  audit_date date,
  audit_score int,
  audit_category text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_user_id, p.email, a.audit_date, a.audit_score, a.audit_category, a.status
    FROM public.engineer_quality_audit_r2044 a
    LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
    WHERE a.status IN ('failed','escalated','needs_improvement')
    ORDER BY a.captured_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r2044(int);
CREATE OR REPLACE FUNCTION public.recent_actions_r2044(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  audit_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.engineer_audit_action_log_r2044 l
    ORDER BY l.taken_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_audits_r2044(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r2044(uuid, date, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2044(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2044(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2044(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.failed_audits_r2044(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2044(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r2044(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r2044(uuid, date, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2044(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2044(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2044(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.failed_audits_r2044(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2044(int) TO authenticated;

COMMIT;
