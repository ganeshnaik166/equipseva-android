BEGIN;

-- ============================================================================
-- Round 1968 — Engineer Customer Satisfaction Score
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_csat_scores_r1968 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  total_jobs int NOT NULL DEFAULT 0,
  csat_responses_count int NOT NULL DEFAULT 0,
  avg_csat_score numeric(4,2) NOT NULL DEFAULT 0,
  promoter_count int NOT NULL DEFAULT 0,
  detractor_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','needs_review','promoted','at_risk')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_csat_scores_r1968_engineer ON public.engineer_csat_scores_r1968(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_csat_scores_r1968_status ON public.engineer_csat_scores_r1968(status);
CREATE INDEX IF NOT EXISTS idx_engineer_csat_scores_r1968_captured_at ON public.engineer_csat_scores_r1968(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_csat_action_log_r1968 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.engineer_csat_scores_r1968(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','bonused','promoted','escalated','recognition')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_csat_action_log_r1968_score ON public.engineer_csat_action_log_r1968(score_id);
CREATE INDEX IF NOT EXISTS idx_engineer_csat_action_log_r1968_taken_at ON public.engineer_csat_action_log_r1968(taken_at DESC);

ALTER TABLE public.engineer_csat_scores_r1968 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_csat_action_log_r1968 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_csat_scores_r1968_founder ON public.engineer_csat_scores_r1968;
CREATE POLICY engineer_csat_scores_r1968_founder ON public.engineer_csat_scores_r1968
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS engineer_csat_action_log_r1968_founder ON public.engineer_csat_action_log_r1968;
CREATE POLICY engineer_csat_action_log_r1968_founder ON public.engineer_csat_action_log_r1968
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_engineer_csat_scores_r1968(p_status text DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_label text,
  total_jobs int,
  csat_responses_count int,
  avg_csat_score numeric,
  promoter_count int,
  detractor_count int,
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
    SELECT s.id, s.engineer_user_id, s.period_label, s.total_jobs, s.csat_responses_count,
           s.avg_csat_score, s.promoter_count, s.detractor_count, s.status, s.captured_at
    FROM public.engineer_csat_scores_r1968 s
    WHERE (p_status IS NULL OR s.status = p_status)
    ORDER BY s.captured_at DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_engineer_csat_score_r1968(
  p_engineer_user_id uuid,
  p_period_label text,
  p_total_jobs int,
  p_csat_responses_count int,
  p_avg_csat_score numeric,
  p_promoter_count int,
  p_detractor_count int,
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
  INSERT INTO public.engineer_csat_scores_r1968(
    engineer_user_id, period_label, total_jobs, csat_responses_count,
    avg_csat_score, promoter_count, detractor_count, status
  ) VALUES (
    p_engineer_user_id, p_period_label, p_total_jobs, p_csat_responses_count,
    p_avg_csat_score, p_promoter_count, p_detractor_count, COALESCE(p_status, 'on_track')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engineer_csat_score_r1968',
          jsonb_build_object('score_id', v_id, 'engineer_user_id', p_engineer_user_id, 'period_label', p_period_label));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_engineer_csat_actions_r1968(p_score_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  score_id uuid,
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
    SELECT a.id, a.score_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_csat_action_log_r1968 a
    WHERE (p_score_id IS NULL OR a.score_id = p_score_id)
    ORDER BY a.taken_at DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_engineer_csat_action_r1968(
  p_score_id uuid,
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
  INSERT INTO public.engineer_csat_action_log_r1968(score_id, action_type, by_email, notes_md)
  VALUES (p_score_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_engineer_csat_action_r1968',
          jsonb_build_object('action_id', v_id, 'score_id', p_score_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_engineer_csat_status_r1968(p_score_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_csat_scores_r1968
    SET status = p_status, updated_at = now()
    WHERE id = p_score_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_engineer_csat_status_r1968',
          jsonb_build_object('score_id', p_score_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_engineer_csat_scorers_r1968(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_label text,
  avg_csat_score numeric,
  promoter_count int,
  total_jobs int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.engineer_user_id, s.period_label, s.avg_csat_score,
           s.promoter_count, s.total_jobs, s.status
    FROM public.engineer_csat_scores_r1968 s
    ORDER BY s.avg_csat_score DESC, s.promoter_count DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_engineer_csat_actions_r1968(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  score_id uuid,
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
    SELECT a.id, a.score_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_csat_action_log_r1968 a
    ORDER BY a.taken_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_engineer_csat_scores_r1968(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_csat_scores_r1968(text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_csat_score_r1968(uuid, text, int, int, numeric, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_engineer_csat_score_r1968(uuid, text, int, int, numeric, int, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_engineer_csat_actions_r1968(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_csat_actions_r1968(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_csat_action_r1968(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_engineer_csat_action_r1968(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_engineer_csat_status_r1968(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_engineer_csat_status_r1968(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_engineer_csat_scorers_r1968(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engineer_csat_scorers_r1968(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_engineer_csat_actions_r1968(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_engineer_csat_actions_r1968(int) TO authenticated;

COMMIT;
