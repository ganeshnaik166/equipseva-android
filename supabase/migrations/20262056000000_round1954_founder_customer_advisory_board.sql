BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_advisory_board_r1954 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_name text NOT NULL,
  member_email text NOT NULL,
  organization text NOT NULL,
  role text NOT NULL,
  joined_at date NOT NULL DEFAULT current_date,
  status text NOT NULL CHECK (status IN ('active','inactive','term_ended','resigned')),
  term_length_months int NOT NULL DEFAULT 12,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_cab_meeting_log_r1954 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.founder_customer_advisory_board_r1954(id) ON DELETE CASCADE,
  meeting_date date NOT NULL,
  topic_md text NOT NULL,
  attended boolean NOT NULL DEFAULT true,
  contribution_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_advisory_board_r1954 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_cab_meeting_log_r1954 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cab_r1954 ON public.founder_customer_advisory_board_r1954;
CREATE POLICY founder_all_cab_r1954 ON public.founder_customer_advisory_board_r1954
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_meet_r1954 ON public.founder_cab_meeting_log_r1954;
CREATE POLICY founder_all_meet_r1954 ON public.founder_cab_meeting_log_r1954
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_members
CREATE OR REPLACE FUNCTION public.list_cab_members_r1954()
RETURNS TABLE (
  id uuid,
  member_name text,
  member_email text,
  organization text,
  role text,
  joined_at date,
  status text,
  term_length_months int
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
  SELECT m.id, m.member_name, m.member_email, m.organization, m.role,
         m.joined_at, m.status, m.term_length_months
  FROM public.founder_customer_advisory_board_r1954 m
  ORDER BY m.joined_at DESC;
END;
$$;

-- 2. log_member
CREATE OR REPLACE FUNCTION public.log_cab_member_r1954(
  p_member_name text,
  p_member_email text,
  p_organization text,
  p_role text,
  p_term_length_months int DEFAULT 12
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
  INSERT INTO public.founder_customer_advisory_board_r1954
    (member_name, member_email, organization, role, status, term_length_months)
  VALUES
    (p_member_name, p_member_email, p_organization, p_role, 'active', p_term_length_months)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cab_member_r1954',
          jsonb_build_object('id', v_id, 'member_email', p_member_email, 'organization', p_organization));
  RETURN v_id;
END;
$$;

-- 3. list_meetings
CREATE OR REPLACE FUNCTION public.list_cab_meetings_r1954()
RETURNS TABLE (
  id uuid,
  member_id uuid,
  member_name text,
  meeting_date date,
  topic_md text,
  attended boolean,
  contribution_md text,
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
  SELECT l.id, l.member_id, m.member_name, l.meeting_date, l.topic_md,
         l.attended, l.contribution_md, l.recorded_at
  FROM public.founder_cab_meeting_log_r1954 l
  LEFT JOIN public.founder_customer_advisory_board_r1954 m ON m.id = l.member_id
  ORDER BY l.meeting_date DESC, l.recorded_at DESC;
END;
$$;

-- 4. log_meeting
CREATE OR REPLACE FUNCTION public.log_cab_meeting_r1954(
  p_member_id uuid,
  p_meeting_date date,
  p_topic_md text,
  p_attended boolean DEFAULT true,
  p_contribution_md text DEFAULT NULL
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
  INSERT INTO public.founder_cab_meeting_log_r1954
    (member_id, meeting_date, topic_md, attended, contribution_md)
  VALUES
    (p_member_id, p_meeting_date, p_topic_md, p_attended, p_contribution_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cab_meeting_r1954',
          jsonb_build_object('id', v_id, 'member_id', p_member_id, 'meeting_date', p_meeting_date));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_cab_status_r1954(
  p_member_id uuid,
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
  IF p_status NOT IN ('active','inactive','term_ended','resigned') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_customer_advisory_board_r1954
  SET status = p_status, updated_at = now()
  WHERE id = p_member_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_cab_status_r1954',
          jsonb_build_object('member_id', p_member_id, 'status', p_status));
END;
$$;

-- 6. top_contributors
CREATE OR REPLACE FUNCTION public.top_cab_contributors_r1954()
RETURNS TABLE (
  member_id uuid,
  member_name text,
  organization text,
  meetings_attended bigint,
  total_meetings bigint
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
  SELECT m.id AS member_id, m.member_name, m.organization,
         COUNT(l.id) FILTER (WHERE l.attended) AS meetings_attended,
         COUNT(l.id) AS total_meetings
  FROM public.founder_customer_advisory_board_r1954 m
  LEFT JOIN public.founder_cab_meeting_log_r1954 l ON l.member_id = m.id
  GROUP BY m.id, m.member_name, m.organization
  ORDER BY meetings_attended DESC, m.member_name ASC
  LIMIT 25;
END;
$$;

-- 7. recent_meetings
CREATE OR REPLACE FUNCTION public.recent_cab_meetings_r1954()
RETURNS TABLE (
  id uuid,
  member_name text,
  organization text,
  meeting_date date,
  topic_md text,
  attended boolean
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
  SELECT l.id, m.member_name, m.organization, l.meeting_date, l.topic_md, l.attended
  FROM public.founder_cab_meeting_log_r1954 l
  LEFT JOIN public.founder_customer_advisory_board_r1954 m ON m.id = l.member_id
  WHERE l.meeting_date >= current_date - INTERVAL '90 days'
  ORDER BY l.meeting_date DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cab_members_r1954() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cab_member_r1954(text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_cab_meetings_r1954() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cab_meeting_r1954(uuid, date, text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_cab_status_r1954(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_cab_contributors_r1954() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_cab_meetings_r1954() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cab_members_r1954() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cab_member_r1954(text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_cab_meetings_r1954() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cab_meeting_r1954(uuid, date, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_cab_status_r1954(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_cab_contributors_r1954() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_cab_meetings_r1954() TO authenticated;

COMMIT;
