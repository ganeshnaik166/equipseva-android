BEGIN;

-- =====================================================================
-- Round 1982: Founder Daily Standup Tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_daily_standups_r1982 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  standup_date date NOT NULL,
  attendees text[] NOT NULL DEFAULT '{}',
  main_topics_md text,
  blockers_md text,
  status text NOT NULL DEFAULT 'held' CHECK (status IN ('held','skipped','postponed')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fds_r1982_date ON public.founder_daily_standups_r1982 (standup_date DESC);
CREATE INDEX IF NOT EXISTS idx_fds_r1982_status ON public.founder_daily_standups_r1982 (status);

CREATE TABLE IF NOT EXISTS public.founder_standup_outcome_log_r1982 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  standup_id uuid NOT NULL REFERENCES public.founder_daily_standups_r1982(id) ON DELETE CASCADE,
  outcome_type text NOT NULL CHECK (outcome_type IN ('decision_made','blocker_resolved','escalation','celebration','pivot')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsol_r1982_standup ON public.founder_standup_outcome_log_r1982 (standup_id);
CREATE INDEX IF NOT EXISTS idx_fsol_r1982_taken ON public.founder_standup_outcome_log_r1982 (taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsol_r1982_type ON public.founder_standup_outcome_log_r1982 (outcome_type);

ALTER TABLE public.founder_daily_standups_r1982 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_standup_outcome_log_r1982 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fds_r1982 ON public.founder_daily_standups_r1982;
CREATE POLICY founder_all_fds_r1982 ON public.founder_daily_standups_r1982
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fsol_r1982 ON public.founder_standup_outcome_log_r1982;
CREATE POLICY founder_all_fsol_r1982 ON public.founder_standup_outcome_log_r1982
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_standups
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_standups_r1982(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  standup_date date,
  attendees text[],
  attendee_count int,
  main_topics_md text,
  blockers_md text,
  status text,
  recorded_at timestamptz,
  outcome_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.standup_date, s.attendees, COALESCE(array_length(s.attendees,1),0)::int,
         s.main_topics_md, s.blockers_md, s.status, s.recorded_at,
         (SELECT COUNT(*) FROM public.founder_standup_outcome_log_r1982 o WHERE o.standup_id = s.id)
  FROM public.founder_daily_standups_r1982 s
  ORDER BY s.standup_date DESC, s.recorded_at DESC
  LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_standups_r1982(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_standups_r1982(int) TO authenticated;

-- =====================================================================
-- RPC 2: log_standup
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_standup_r1982(
  p_standup_date date,
  p_attendees text[],
  p_main_topics_md text,
  p_blockers_md text,
  p_status text DEFAULT 'held'
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

  INSERT INTO public.founder_daily_standups_r1982
    (standup_date, attendees, main_topics_md, blockers_md, status)
  VALUES (p_standup_date, COALESCE(p_attendees,'{}'), p_main_topics_md, p_blockers_md, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_standup_r1982',
    jsonb_build_object('standup_id', v_id, 'date', p_standup_date, 'status', p_status));

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_standup_r1982(date, text[], text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_standup_r1982(date, text[], text, text, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_outcomes
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_outcomes_r1982(p_standup_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  standup_id uuid,
  standup_date date,
  outcome_type text,
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
  SELECT o.id, o.standup_id, s.standup_date, o.outcome_type, o.taken_at, o.by_email, o.notes_md
  FROM public.founder_standup_outcome_log_r1982 o
  JOIN public.founder_daily_standups_r1982 s ON s.id = o.standup_id
  WHERE p_standup_id IS NULL OR o.standup_id = p_standup_id
  ORDER BY o.taken_at DESC
  LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_outcomes_r1982(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r1982(uuid, int) TO authenticated;

-- =====================================================================
-- RPC 4: log_outcome
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_outcome_r1982(
  p_standup_id uuid,
  p_outcome_type text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_standup_outcome_log_r1982
    (standup_id, outcome_type, by_email, notes_md)
  VALUES (p_standup_id, p_outcome_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outcome_r1982',
    jsonb_build_object('outcome_id', v_id, 'standup_id', p_standup_id, 'type', p_outcome_type));

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_outcome_r1982(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_outcome_r1982(uuid, text, text, text) TO authenticated;

-- =====================================================================
-- RPC 5: mark_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r1982(p_standup_id uuid, p_status text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_daily_standups_r1982
  SET status = p_status, updated_at = now()
  WHERE id = p_standup_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1982',
    jsonb_build_object('standup_id', p_standup_id, 'status', p_status));

  RETURN FOUND;
END $$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r1982(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r1982(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: attendance_trend
-- =====================================================================
CREATE OR REPLACE FUNCTION public.attendance_trend_r1982(p_days int DEFAULT 30)
RETURNS TABLE (
  standup_date date,
  attendee_count int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.standup_date, COALESCE(array_length(s.attendees,1),0)::int, s.status
  FROM public.founder_daily_standups_r1982 s
  WHERE s.standup_date >= (CURRENT_DATE - p_days)
  ORDER BY s.standup_date DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.attendance_trend_r1982(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attendance_trend_r1982(int) TO authenticated;

-- =====================================================================
-- RPC 7: recent_outcomes
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_outcomes_r1982(p_limit int DEFAULT 25)
RETURNS TABLE (
  outcome_type text,
  outcome_count bigint,
  last_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outcome_type, COUNT(*)::bigint, MAX(o.taken_at)
  FROM public.founder_standup_outcome_log_r1982 o
  GROUP BY o.outcome_type
  ORDER BY MAX(o.taken_at) DESC
  LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.recent_outcomes_r1982(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_outcomes_r1982(int) TO authenticated;

COMMIT;
