BEGIN;

-- ============================================================================
-- Round 1918 — Founder Board Member Tracker
-- Tables: founder_board_members_r1918 + founder_board_meeting_attendance_r1918
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_board_members_r1918 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_name text NOT NULL,
  member_email text,
  role text NOT NULL CHECK (role IN ('chair','independent','investor_designate','observer','founder')),
  voting_rights boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','resigned','term_ended')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  term_end_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_board_meeting_attendance_r1918 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.founder_board_members_r1918(id) ON DELETE CASCADE,
  meeting_date date NOT NULL,
  attended boolean NOT NULL DEFAULT false,
  contribution_score int CHECK (contribution_score BETWEEN 0 AND 10),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbm_r1918_status ON public.founder_board_members_r1918(status);
CREATE INDEX IF NOT EXISTS idx_fbma_r1918_member ON public.founder_board_meeting_attendance_r1918(member_id);
CREATE INDEX IF NOT EXISTS idx_fbma_r1918_date ON public.founder_board_meeting_attendance_r1918(meeting_date DESC);

ALTER TABLE public.founder_board_members_r1918 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_board_meeting_attendance_r1918 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fbm_r1918_founder_all ON public.founder_board_members_r1918;
CREATE POLICY fbm_r1918_founder_all ON public.founder_board_members_r1918
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fbma_r1918_founder_all ON public.founder_board_meeting_attendance_r1918;
CREATE POLICY fbma_r1918_founder_all ON public.founder_board_meeting_attendance_r1918
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_members
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_board_members_r1918()
RETURNS TABLE (
  id uuid,
  member_name text,
  member_email text,
  role text,
  voting_rights boolean,
  status text,
  joined_at timestamptz,
  term_end_date date
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
  SELECT m.id, m.member_name, m.member_email, m.role, m.voting_rights, m.status, m.joined_at, m.term_end_date
  FROM public.founder_board_members_r1918 m
  ORDER BY m.status ASC, m.joined_at DESC;
END;
$$;

-- ============================================================================
-- RPC 2: log_member
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_board_member_r1918(
  p_member_name text,
  p_member_email text,
  p_role text,
  p_voting_rights boolean,
  p_term_end_date date
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
  INSERT INTO public.founder_board_members_r1918(member_name, member_email, role, voting_rights, term_end_date)
  VALUES (p_member_name, p_member_email, p_role, p_voting_rights, p_term_end_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_board_member_r1918',
    jsonb_build_object('id', v_id, 'name', p_member_name, 'role', p_role));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_attendance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_board_attendance_r1918()
RETURNS TABLE (
  id uuid,
  member_id uuid,
  member_name text,
  meeting_date date,
  attended boolean,
  contribution_score int,
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
  SELECT a.id, a.member_id, m.member_name, a.meeting_date, a.attended, a.contribution_score, a.notes_md
  FROM public.founder_board_meeting_attendance_r1918 a
  JOIN public.founder_board_members_r1918 m ON m.id = a.member_id
  ORDER BY a.meeting_date DESC, m.member_name ASC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_attendance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_board_attendance_r1918(
  p_member_id uuid,
  p_meeting_date date,
  p_attended boolean,
  p_contribution_score int,
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
  INSERT INTO public.founder_board_meeting_attendance_r1918(member_id, meeting_date, attended, contribution_score, notes_md)
  VALUES (p_member_id, p_meeting_date, p_attended, p_contribution_score, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_board_attendance_r1918',
    jsonb_build_object('id', v_id, 'member_id', p_member_id, 'meeting_date', p_meeting_date, 'attended', p_attended));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_resigned
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_board_member_resigned_r1918(p_member_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_board_members_r1918
  SET status = 'resigned', updated_at = now()
  WHERE id = p_member_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_board_member_resigned_r1918',
    jsonb_build_object('member_id', p_member_id));
END;
$$;

-- ============================================================================
-- RPC 6: missed_recent — members who missed at least 2 of last 4 meetings
-- ============================================================================
CREATE OR REPLACE FUNCTION public.missed_recent_board_r1918()
RETURNS TABLE (
  member_id uuid,
  member_name text,
  role text,
  total_recent int,
  missed_count int
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
  WITH recent AS (
    SELECT DISTINCT meeting_date
    FROM public.founder_board_meeting_attendance_r1918
    ORDER BY meeting_date DESC
    LIMIT 4
  )
  SELECT
    m.id,
    m.member_name,
    m.role,
    (COUNT(*) FILTER (WHERE a.meeting_date IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE a.attended = false))::int
  FROM public.founder_board_members_r1918 m
  LEFT JOIN public.founder_board_meeting_attendance_r1918 a
    ON a.member_id = m.id AND a.meeting_date IN (SELECT meeting_date FROM recent)
  WHERE m.status = 'active'
  GROUP BY m.id, m.member_name, m.role
  HAVING (COUNT(*) FILTER (WHERE a.attended = false))::int >= 2
  ORDER BY (COUNT(*) FILTER (WHERE a.attended = false))::int DESC;
END;
$$;

-- ============================================================================
-- RPC 7: recent_attendance — last 20 attendance entries
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_board_attendance_r1918()
RETURNS TABLE (
  member_name text,
  role text,
  meeting_date date,
  attended boolean,
  contribution_score int
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
  SELECT m.member_name, m.role, a.meeting_date, a.attended, a.contribution_score
  FROM public.founder_board_meeting_attendance_r1918 a
  JOIN public.founder_board_members_r1918 m ON m.id = a.member_id
  ORDER BY a.meeting_date DESC, m.member_name ASC
  LIMIT 20;
END;
$$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_board_members_r1918() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_board_member_r1918(text, text, text, boolean, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_board_attendance_r1918() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_board_attendance_r1918(uuid, date, boolean, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_board_member_resigned_r1918(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.missed_recent_board_r1918() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_board_attendance_r1918() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_board_members_r1918() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_board_member_r1918(text, text, text, boolean, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_board_attendance_r1918() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_board_attendance_r1918(uuid, date, boolean, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_board_member_resigned_r1918(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.missed_recent_board_r1918() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_board_attendance_r1918() TO authenticated;

COMMIT;
