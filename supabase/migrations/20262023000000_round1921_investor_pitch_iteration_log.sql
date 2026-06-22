BEGIN;

-- =====================================================================
-- Round 1921 — Investor Pitch Iteration Log
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_pitch_iterations_r1921 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_label text NOT NULL,
  pitched_to_md text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','used_in_meeting','archived','superseded')),
  feedback_summary_md text,
  drafted_at timestamptz NOT NULL DEFAULT now(),
  last_pitched_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ipi_r1921_status
  ON public.investor_pitch_iterations_r1921 (status);
CREATE INDEX IF NOT EXISTS idx_ipi_r1921_drafted_at
  ON public.investor_pitch_iterations_r1921 (drafted_at DESC);

ALTER TABLE public.investor_pitch_iterations_r1921 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ipi_r1921_founder_all ON public.investor_pitch_iterations_r1921;
CREATE POLICY ipi_r1921_founder_all ON public.investor_pitch_iterations_r1921
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_pitch_feedback_r1921 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iteration_id uuid NOT NULL REFERENCES public.investor_pitch_iterations_r1921(id) ON DELETE CASCADE,
  feedback_type text NOT NULL
    CHECK (feedback_type IN ('positive','concern','suggestion','objection')),
  feedback_md text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  by_investor_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ipf_r1921_iteration_id
  ON public.investor_pitch_feedback_r1921 (iteration_id);
CREATE INDEX IF NOT EXISTS idx_ipf_r1921_received_at
  ON public.investor_pitch_feedback_r1921 (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_ipf_r1921_type
  ON public.investor_pitch_feedback_r1921 (feedback_type);

ALTER TABLE public.investor_pitch_feedback_r1921 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ipf_r1921_founder_all ON public.investor_pitch_feedback_r1921;
CREATE POLICY ipf_r1921_founder_all ON public.investor_pitch_feedback_r1921
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPCs
-- =====================================================================

CREATE OR REPLACE FUNCTION public.list_pitch_iterations_r1921(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  version_label text,
  pitched_to_md text,
  status text,
  feedback_summary_md text,
  drafted_at timestamptz,
  last_pitched_at timestamptz,
  feedback_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.version_label,
    i.pitched_to_md,
    i.status,
    i.feedback_summary_md,
    i.drafted_at,
    i.last_pitched_at,
    (SELECT COUNT(*) FROM public.investor_pitch_feedback_r1921 f WHERE f.iteration_id = i.id)::int AS feedback_count
  FROM public.investor_pitch_iterations_r1921 i
  ORDER BY i.drafted_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_pitch_iteration_r1921(
  p_version_label text,
  p_pitched_to_md text,
  p_status text DEFAULT 'draft',
  p_feedback_summary_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_pitch_iterations_r1921(
    version_label, pitched_to_md, status, feedback_summary_md
  ) VALUES (
    p_version_label, p_pitched_to_md, COALESCE(p_status, 'draft'), p_feedback_summary_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_pitch_iteration_r1921',
    jsonb_build_object('id', v_id, 'version_label', p_version_label, 'status', p_status),
    now()
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_pitch_feedback_r1921(
  p_iteration_id uuid DEFAULT NULL,
  p_limit int DEFAULT 200
)
RETURNS TABLE(
  id uuid,
  iteration_id uuid,
  version_label text,
  feedback_type text,
  feedback_md text,
  received_at timestamptz,
  by_investor_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.iteration_id,
    i.version_label,
    f.feedback_type,
    f.feedback_md,
    f.received_at,
    f.by_investor_email
  FROM public.investor_pitch_feedback_r1921 f
  JOIN public.investor_pitch_iterations_r1921 i ON i.id = f.iteration_id
  WHERE (p_iteration_id IS NULL OR f.iteration_id = p_iteration_id)
  ORDER BY f.received_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_pitch_feedback_r1921(
  p_iteration_id uuid,
  p_feedback_type text,
  p_feedback_md text,
  p_by_investor_email text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_pitch_feedback_r1921(
    iteration_id, feedback_type, feedback_md, by_investor_email
  ) VALUES (
    p_iteration_id, p_feedback_type, p_feedback_md, p_by_investor_email
  ) RETURNING id INTO v_id;

  UPDATE public.investor_pitch_iterations_r1921
  SET last_pitched_at = now(), updated_at = now()
  WHERE id = p_iteration_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_pitch_feedback_r1921',
    jsonb_build_object('id', v_id, 'iteration_id', p_iteration_id, 'feedback_type', p_feedback_type),
    now()
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_pitch_iteration_archived_r1921(p_iteration_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_pitch_iterations_r1921
  SET status = 'archived', updated_at = now()
  WHERE id = p_iteration_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_pitch_iteration_archived_r1921',
    jsonb_build_object('iteration_id', p_iteration_id),
    now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.top_pitch_objections_r1921(p_limit int DEFAULT 20)
RETURNS TABLE(
  feedback_type text,
  occurrences int,
  last_received timestamptz,
  sample_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    f.feedback_type,
    COUNT(*)::int AS occurrences,
    MAX(f.received_at) AS last_received,
    (ARRAY_AGG(f.feedback_md ORDER BY f.received_at DESC))[1] AS sample_md
  FROM public.investor_pitch_feedback_r1921 f
  WHERE f.feedback_type IN ('objection','concern')
  GROUP BY f.feedback_type
  ORDER BY occurrences DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_pitch_feedback_r1921(p_days int DEFAULT 30, p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  iteration_id uuid,
  version_label text,
  feedback_type text,
  feedback_md text,
  received_at timestamptz,
  by_investor_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.iteration_id,
    i.version_label,
    f.feedback_type,
    f.feedback_md,
    f.received_at,
    f.by_investor_email
  FROM public.investor_pitch_feedback_r1921 f
  JOIN public.investor_pitch_iterations_r1921 i ON i.id = f.iteration_id
  WHERE f.received_at >= now() - (GREATEST(p_days, 1) || ' days')::interval
  ORDER BY f.received_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- =====================================================================
-- Permissions
-- =====================================================================

REVOKE EXECUTE ON FUNCTION public.list_pitch_iterations_r1921(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_pitch_iterations_r1921(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_pitch_iteration_r1921(text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_pitch_iteration_r1921(text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_pitch_feedback_r1921(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_pitch_feedback_r1921(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_pitch_feedback_r1921(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_pitch_feedback_r1921(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_pitch_iteration_archived_r1921(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_pitch_iteration_archived_r1921(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_pitch_objections_r1921(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_pitch_objections_r1921(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_pitch_feedback_r1921(int, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recent_pitch_feedback_r1921(int, int) TO authenticated;

COMMIT;
