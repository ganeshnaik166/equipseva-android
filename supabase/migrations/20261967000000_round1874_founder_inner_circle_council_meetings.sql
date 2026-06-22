BEGIN;

-- =====================================================================
-- Round 1874 — Founder Inner Circle Council Meetings
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_inner_council_meetings_r1874 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_date date NOT NULL,
  meeting_label text NOT NULL,
  attendee_emails text[] NOT NULL DEFAULT '{}',
  topic text NOT NULL,
  key_decisions_md text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','held','cancelled')),
  held_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_inner_council_decisions_r1874 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.founder_inner_council_meetings_r1874(id) ON DELETE CASCADE,
  decision_text text NOT NULL,
  decision_owner_email text NOT NULL,
  decision_status text NOT NULL DEFAULT 'open' CHECK (decision_status IN ('open','in_progress','done','dropped')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_inner_council_meetings_r1874 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_inner_council_decisions_r1874 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_meetings_r1874 ON public.founder_inner_council_meetings_r1874;
CREATE POLICY founder_all_meetings_r1874 ON public.founder_inner_council_meetings_r1874
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_decisions_r1874 ON public.founder_inner_council_decisions_r1874;
CREATE POLICY founder_all_decisions_r1874 ON public.founder_inner_council_decisions_r1874
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_meetings
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_list_meetings();
CREATE OR REPLACE FUNCTION public.r1874_list_meetings()
RETURNS TABLE (
  id uuid,
  meeting_date date,
  meeting_label text,
  attendee_emails text[],
  topic text,
  key_decisions_md text,
  status text,
  held_at timestamptz,
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
    SELECT m.id, m.meeting_date, m.meeting_label, m.attendee_emails, m.topic,
           m.key_decisions_md, m.status, m.held_at, m.created_at
    FROM public.founder_inner_council_meetings_r1874 m
    ORDER BY m.meeting_date DESC, m.created_at DESC
    LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 2: schedule_meeting
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_schedule_meeting(date, text, text[], text, text);
CREATE OR REPLACE FUNCTION public.r1874_schedule_meeting(
  p_meeting_date date,
  p_meeting_label text,
  p_attendee_emails text[],
  p_topic text,
  p_key_decisions_md text
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
  INSERT INTO public.founder_inner_council_meetings_r1874
    (meeting_date, meeting_label, attendee_emails, topic, key_decisions_md, status)
  VALUES (p_meeting_date, p_meeting_label, COALESCE(p_attendee_emails, '{}'), p_topic, p_key_decisions_md, 'scheduled')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1874_schedule_meeting',
          jsonb_build_object('meeting_id', v_id, 'meeting_date', p_meeting_date, 'topic', p_topic));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_decisions
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_list_decisions(uuid);
CREATE OR REPLACE FUNCTION public.r1874_list_decisions(p_meeting_id uuid)
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  decision_text text,
  decision_owner_email text,
  decision_status text,
  decided_at timestamptz
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
    SELECT d.id, d.meeting_id, d.decision_text, d.decision_owner_email, d.decision_status, d.decided_at
    FROM public.founder_inner_council_decisions_r1874 d
    WHERE d.meeting_id = p_meeting_id
    ORDER BY d.decided_at DESC;
END;
$$;

-- =====================================================================
-- RPC 4: log_decision
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_log_decision(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r1874_log_decision(
  p_meeting_id uuid,
  p_decision_text text,
  p_decision_owner_email text,
  p_decision_status text
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
  IF p_decision_status NOT IN ('open','in_progress','done','dropped') THEN
    RAISE EXCEPTION 'invalid decision_status';
  END IF;
  INSERT INTO public.founder_inner_council_decisions_r1874
    (meeting_id, decision_text, decision_owner_email, decision_status)
  VALUES (p_meeting_id, p_decision_text, p_decision_owner_email, p_decision_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1874_log_decision',
          jsonb_build_object('decision_id', v_id, 'meeting_id', p_meeting_id, 'owner', p_decision_owner_email));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_held
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_mark_held(uuid);
CREATE OR REPLACE FUNCTION public.r1874_mark_held(p_meeting_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_inner_council_meetings_r1874
  SET status = 'held', held_at = now(), updated_at = now()
  WHERE id = p_meeting_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1874_mark_held',
          jsonb_build_object('meeting_id', p_meeting_id));
END;
$$;

-- =====================================================================
-- RPC 6: recent_meetings
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_recent_meetings();
CREATE OR REPLACE FUNCTION public.r1874_recent_meetings()
RETURNS TABLE (
  id uuid,
  meeting_date date,
  meeting_label text,
  topic text,
  status text,
  attendee_count int,
  decision_count int
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
    SELECT m.id,
           m.meeting_date,
           m.meeting_label,
           m.topic,
           m.status,
           COALESCE(array_length(m.attendee_emails, 1), 0)::int AS attendee_count,
           (SELECT COUNT(*) FROM public.founder_inner_council_decisions_r1874 d WHERE d.meeting_id = m.id)::int AS decision_count
    FROM public.founder_inner_council_meetings_r1874 m
    WHERE m.meeting_date >= (CURRENT_DATE - INTERVAL '60 days')
    ORDER BY m.meeting_date DESC
    LIMIT 30;
END;
$$;

-- =====================================================================
-- RPC 7: open_decisions
-- =====================================================================
DROP FUNCTION IF EXISTS public.r1874_open_decisions();
CREATE OR REPLACE FUNCTION public.r1874_open_decisions()
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  meeting_label text,
  meeting_date date,
  decision_text text,
  decision_owner_email text,
  decision_status text,
  decided_at timestamptz
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
    SELECT d.id, d.meeting_id, m.meeting_label, m.meeting_date,
           d.decision_text, d.decision_owner_email, d.decision_status, d.decided_at
    FROM public.founder_inner_council_decisions_r1874 d
    JOIN public.founder_inner_council_meetings_r1874 m ON m.id = d.meeting_id
    WHERE d.decision_status IN ('open','in_progress')
    ORDER BY d.decided_at DESC
    LIMIT 100;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.r1874_list_meetings() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_list_meetings() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_schedule_meeting(date, text, text[], text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_schedule_meeting(date, text, text[], text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_list_decisions(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_list_decisions(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_log_decision(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_log_decision(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_mark_held(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_mark_held(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_recent_meetings() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_recent_meetings() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.r1874_open_decisions() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.r1874_open_decisions() TO authenticated;

COMMIT;