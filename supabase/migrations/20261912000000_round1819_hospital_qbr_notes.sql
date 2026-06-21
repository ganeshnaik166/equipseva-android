BEGIN;

-- =========================================================================
-- Round 1819 — Hospital Quarterly Business Review Notes
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_qbr_notes_r1819 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter text NOT NULL,
  qbr_date date NOT NULL DEFAULT current_date,
  attendees text[] NOT NULL DEFAULT ARRAY[]::text[],
  wins_md text,
  concerns_md text,
  goals_md text,
  action_items_md text,
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 10),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_qbr_notes_r1819_hospital
  ON public.hospital_qbr_notes_r1819 (hospital_user_id, qbr_date DESC);

CREATE INDEX IF NOT EXISTS idx_hospital_qbr_notes_r1819_quarter
  ON public.hospital_qbr_notes_r1819 (quarter);

CREATE TABLE IF NOT EXISTS public.hospital_qbr_followup_tasks_r1819 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qbr_id uuid NOT NULL REFERENCES public.hospital_qbr_notes_r1819(id) ON DELETE CASCADE,
  task_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_qbr_followup_tasks_r1819_qbr
  ON public.hospital_qbr_followup_tasks_r1819 (qbr_id);

CREATE INDEX IF NOT EXISTS idx_hospital_qbr_followup_tasks_r1819_status
  ON public.hospital_qbr_followup_tasks_r1819 (status, due_date);

ALTER TABLE public.hospital_qbr_notes_r1819 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_qbr_followup_tasks_r1819 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_qbr_notes_r1819 ON public.hospital_qbr_notes_r1819;
CREATE POLICY founder_all_qbr_notes_r1819 ON public.hospital_qbr_notes_r1819
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_qbr_followups_r1819 ON public.hospital_qbr_followup_tasks_r1819;
CREATE POLICY founder_all_qbr_followups_r1819 ON public.hospital_qbr_followup_tasks_r1819
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_qbrs_r1819(int);
CREATE OR REPLACE FUNCTION public.list_qbrs_r1819(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  hospital_org text,
  quarter text,
  qbr_date date,
  attendees text[],
  satisfaction_score int,
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
  SELECT
    q.id,
    q.hospital_user_id,
    p.email,
    o.name,
    q.quarter,
    q.qbr_date,
    q.attendees,
    q.satisfaction_score,
    q.recorded_at
  FROM public.hospital_qbr_notes_r1819 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY q.qbr_date DESC, q.recorded_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

DROP FUNCTION IF EXISTS public.log_qbr_r1819(uuid, text, date, text[], text, text, text, text, int);
CREATE OR REPLACE FUNCTION public.log_qbr_r1819(
  p_hospital_user_id uuid,
  p_quarter text,
  p_qbr_date date,
  p_attendees text[],
  p_wins_md text,
  p_concerns_md text,
  p_goals_md text,
  p_action_items_md text,
  p_satisfaction_score int
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
  INSERT INTO public.hospital_qbr_notes_r1819
    (hospital_user_id, quarter, qbr_date, attendees, wins_md, concerns_md, goals_md, action_items_md, satisfaction_score)
  VALUES
    (p_hospital_user_id, p_quarter, p_qbr_date, COALESCE(p_attendees, ARRAY[]::text[]),
     p_wins_md, p_concerns_md, p_goals_md, p_action_items_md, p_satisfaction_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_qbr_r1819',
          jsonb_build_object('qbr_id', v_id, 'hospital_user_id', p_hospital_user_id, 'quarter', p_quarter));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_followups_r1819(uuid);
CREATE OR REPLACE FUNCTION public.list_followups_r1819(p_qbr_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  qbr_id uuid,
  hospital_email text,
  quarter text,
  task_text text,
  owner_email text,
  due_date date,
  status text,
  completed_at timestamptz,
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
    f.id,
    f.qbr_id,
    p.email,
    q.quarter,
    f.task_text,
    f.owner_email,
    f.due_date,
    f.status,
    f.completed_at,
    f.created_at
  FROM public.hospital_qbr_followup_tasks_r1819 f
  JOIN public.hospital_qbr_notes_r1819 q ON q.id = f.qbr_id
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  WHERE p_qbr_id IS NULL OR f.qbr_id = p_qbr_id
  ORDER BY
    CASE f.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    f.due_date NULLS LAST,
    f.created_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_followup_r1819(uuid, text, text, date);
CREATE OR REPLACE FUNCTION public.log_followup_r1819(
  p_qbr_id uuid,
  p_task_text text,
  p_owner_email text,
  p_due_date date
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
  INSERT INTO public.hospital_qbr_followup_tasks_r1819
    (qbr_id, task_text, owner_email, due_date)
  VALUES
    (p_qbr_id, p_task_text, p_owner_email, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_followup_r1819',
          jsonb_build_object('followup_id', v_id, 'qbr_id', p_qbr_id, 'owner_email', p_owner_email));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.complete_followup_r1819(uuid, text);
CREATE OR REPLACE FUNCTION public.complete_followup_r1819(
  p_followup_id uuid,
  p_new_status text
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
  IF p_new_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;
  UPDATE public.hospital_qbr_followup_tasks_r1819
  SET status = p_new_status,
      completed_at = CASE WHEN p_new_status = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_followup_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_followup_r1819',
          jsonb_build_object('followup_id', p_followup_id, 'status', p_new_status));
END;
$$;

DROP FUNCTION IF EXISTS public.hospital_qbr_summary_r1819();
CREATE OR REPLACE FUNCTION public.hospital_qbr_summary_r1819()
RETURNS TABLE (
  total_qbrs int,
  unique_hospitals int,
  avg_satisfaction numeric,
  open_followups int,
  overdue_followups int,
  done_followups int
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
    (SELECT COUNT(*)::int FROM public.hospital_qbr_notes_r1819),
    (SELECT COUNT(DISTINCT hospital_user_id)::int FROM public.hospital_qbr_notes_r1819),
    (SELECT ROUND(AVG(satisfaction_score)::numeric, 2) FROM public.hospital_qbr_notes_r1819 WHERE satisfaction_score IS NOT NULL),
    (SELECT (COUNT(*) FILTER (WHERE status = 'open'))::int FROM public.hospital_qbr_followup_tasks_r1819),
    (SELECT (COUNT(*) FILTER (WHERE status = 'open' AND due_date IS NOT NULL AND due_date < current_date))::int FROM public.hospital_qbr_followup_tasks_r1819),
    (SELECT (COUNT(*) FILTER (WHERE status = 'done'))::int FROM public.hospital_qbr_followup_tasks_r1819);
END;
$$;

DROP FUNCTION IF EXISTS public.recent_qbrs_r1819(int);
CREATE OR REPLACE FUNCTION public.recent_qbrs_r1819(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  hospital_email text,
  hospital_org text,
  quarter text,
  qbr_date date,
  satisfaction_score int,
  open_followup_count int,
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
  SELECT
    q.id,
    p.email,
    o.name,
    q.quarter,
    q.qbr_date,
    q.satisfaction_score,
    (SELECT (COUNT(*) FILTER (WHERE f.status = 'open'))::int
       FROM public.hospital_qbr_followup_tasks_r1819 f
      WHERE f.qbr_id = q.id),
    q.recorded_at
  FROM public.hospital_qbr_notes_r1819 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE q.qbr_date >= current_date - (GREATEST(p_days,1) || ' days')::interval
  ORDER BY q.qbr_date DESC
  LIMIT 100;
END;
$$;

-- =========================================================================
-- Permissions
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_qbrs_r1819(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_qbr_r1819(uuid, text, date, text[], text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_followups_r1819(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_followup_r1819(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_followup_r1819(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hospital_qbr_summary_r1819() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_qbrs_r1819(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_qbrs_r1819(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_qbr_r1819(uuid, text, date, text[], text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_followups_r1819(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_followup_r1819(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_followup_r1819(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hospital_qbr_summary_r1819() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_qbrs_r1819(int) TO authenticated;

COMMIT;