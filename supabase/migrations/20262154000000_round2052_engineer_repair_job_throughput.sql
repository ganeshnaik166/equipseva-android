BEGIN;

-- ============================================================================
-- Round 2052 — Engineer Repair Job Throughput
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_repair_job_throughput_r2052 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  total_jobs_completed int NOT NULL DEFAULT 0,
  avg_minutes_per_job int NOT NULL DEFAULT 0,
  first_time_fix_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('high_throughput','normal','declining','at_risk')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_er_throughput_r2052_engineer ON public.engineer_repair_job_throughput_r2052(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_er_throughput_r2052_status ON public.engineer_repair_job_throughput_r2052(status);
CREATE INDEX IF NOT EXISTS idx_er_throughput_r2052_captured ON public.engineer_repair_job_throughput_r2052(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_throughput_action_log_r2052 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  throughput_id uuid NOT NULL REFERENCES public.engineer_repair_job_throughput_r2052(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','training_added','escalated','recognized','promoted')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_er_throughput_action_r2052_throughput ON public.engineer_throughput_action_log_r2052(throughput_id);
CREATE INDEX IF NOT EXISTS idx_er_throughput_action_r2052_type ON public.engineer_throughput_action_log_r2052(action_type);
CREATE INDEX IF NOT EXISTS idx_er_throughput_action_r2052_taken ON public.engineer_throughput_action_log_r2052(taken_at DESC);

ALTER TABLE public.engineer_repair_job_throughput_r2052 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_throughput_action_log_r2052 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_er_throughput_r2052 ON public.engineer_repair_job_throughput_r2052;
CREATE POLICY founder_all_er_throughput_r2052 ON public.engineer_repair_job_throughput_r2052
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_er_throughput_action_r2052 ON public.engineer_throughput_action_log_r2052;
CREATE POLICY founder_all_er_throughput_action_r2052 ON public.engineer_throughput_action_log_r2052
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_throughputs_r2052()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_label text,
  total_jobs_completed int,
  avg_minutes_per_job int,
  first_time_fix_rate_pct numeric,
  status text,
  captured_at timestamptz
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
  SELECT t.id, t.engineer_user_id, t.period_label, t.total_jobs_completed,
         t.avg_minutes_per_job, t.first_time_fix_rate_pct, t.status, t.captured_at
  FROM public.engineer_repair_job_throughput_r2052 t
  ORDER BY t.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_throughput_r2052(
  p_engineer_user_id uuid,
  p_period_label text,
  p_total_jobs_completed int,
  p_avg_minutes_per_job int,
  p_first_time_fix_rate_pct numeric,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_repair_job_throughput_r2052(
    engineer_user_id, period_label, total_jobs_completed,
    avg_minutes_per_job, first_time_fix_rate_pct, status
  )
  VALUES (
    p_engineer_user_id, p_period_label, p_total_jobs_completed,
    p_avg_minutes_per_job, p_first_time_fix_rate_pct, COALESCE(p_status,'normal')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_throughput_r2052',
    jsonb_build_object('throughput_id', v_id, 'engineer_user_id', p_engineer_user_id, 'period_label', p_period_label)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2052(p_throughput_id uuid)
RETURNS TABLE (
  id uuid,
  throughput_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.throughput_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_throughput_action_log_r2052 a
  WHERE a.throughput_id = p_throughput_id
  ORDER BY a.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2052(
  p_throughput_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.engineer_throughput_action_log_r2052(
    throughput_id, action_type, by_email, notes_md
  )
  VALUES (p_throughput_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r2052',
    jsonb_build_object('action_id', v_id, 'throughput_id', p_throughput_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2052(
  p_throughput_id uuid,
  p_status text
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
  UPDATE public.engineer_repair_job_throughput_r2052
  SET status = p_status, updated_at = now()
  WHERE id = p_throughput_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2052',
    jsonb_build_object('throughput_id', p_throughput_id, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.top_throughput_r2052()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_label text,
  total_jobs_completed int,
  avg_minutes_per_job int,
  first_time_fix_rate_pct numeric,
  status text,
  captured_at timestamptz
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
  SELECT t.id, t.engineer_user_id, t.period_label, t.total_jobs_completed,
         t.avg_minutes_per_job, t.first_time_fix_rate_pct, t.status, t.captured_at
  FROM public.engineer_repair_job_throughput_r2052 t
  ORDER BY t.total_jobs_completed DESC, t.first_time_fix_rate_pct DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2052()
RETURNS TABLE (
  id uuid,
  throughput_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.throughput_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_throughput_action_log_r2052 a
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_throughputs_r2052() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_throughput_r2052(uuid, text, int, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2052(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2052(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2052(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_throughput_r2052() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2052() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_throughputs_r2052() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_throughput_r2052(uuid, text, int, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2052(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2052(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2052(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_throughput_r2052() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2052() TO authenticated;

COMMIT;
