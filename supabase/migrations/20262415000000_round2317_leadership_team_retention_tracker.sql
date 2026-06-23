BEGIN;

CREATE TABLE IF NOT EXISTS public.leadership_team_members_r2317 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  role_title text NOT NULL,
  department text NOT NULL DEFAULT 'general',
  reports_to_member_id uuid REFERENCES public.leadership_team_members_r2317(id) ON DELETE SET NULL,
  hired_on date NOT NULL,
  is_direct_report boolean NOT NULL DEFAULT true,
  comp_band text,
  last_satisfaction_score int CHECK (last_satisfaction_score IS NULL OR (last_satisfaction_score BETWEEN 1 AND 10)),
  last_satisfaction_at timestamptz,
  retention_risk_score int NOT NULL DEFAULT 0 CHECK (retention_risk_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','at_risk','on_notice','departed')),
  departed_on date,
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.leadership_retention_plays_r2317 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.leadership_team_members_r2317(id) ON DELETE CASCADE,
  play_type text NOT NULL CHECK (play_type IN ('one_on_one','comp_review','equity_grant','promotion','scope_expansion','sabbatical','recognition','offsite','coaching','exit_interview','other')),
  play_summary text NOT NULL,
  played_on date NOT NULL DEFAULT CURRENT_DATE,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','positive','neutral','negative')),
  followup_due_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.leadership_team_members_r2317 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leadership_retention_plays_r2317 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_members_r2317 ON public.leadership_team_members_r2317;
CREATE POLICY founder_all_members_r2317 ON public.leadership_team_members_r2317
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_plays_r2317 ON public.leadership_retention_plays_r2317;
CREATE POLICY founder_all_plays_r2317 ON public.leadership_retention_plays_r2317
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list team members with tenure + play counts
CREATE OR REPLACE FUNCTION public.list_team_members_r2317()
RETURNS TABLE (
  id uuid,
  full_name text,
  role_title text,
  department text,
  is_direct_report boolean,
  hired_on date,
  tenure_days int,
  last_satisfaction_score int,
  last_satisfaction_at timestamptz,
  retention_risk_score int,
  status text,
  play_count int,
  open_followup_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.full_name, m.role_title, m.department, m.is_direct_report, m.hired_on,
    (CURRENT_DATE - m.hired_on)::int AS tenure_days,
    m.last_satisfaction_score, m.last_satisfaction_at, m.retention_risk_score, m.status,
    (SELECT (COUNT(*))::int FROM public.leadership_retention_plays_r2317 p WHERE p.member_id = m.id) AS play_count,
    (SELECT (COUNT(*))::int FROM public.leadership_retention_plays_r2317 p
       WHERE p.member_id = m.id AND p.followup_due_on IS NOT NULL AND p.followup_due_on <= CURRENT_DATE AND p.outcome='pending') AS open_followup_count
  FROM public.leadership_team_members_r2317 m
  ORDER BY m.retention_risk_score DESC, m.hired_on ASC;
END;
$$;

-- RPC 2: add team member
CREATE OR REPLACE FUNCTION public.add_team_member_r2317(
  p_full_name text,
  p_role_title text,
  p_department text,
  p_hired_on date,
  p_is_direct_report boolean,
  p_comp_band text,
  p_member_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.leadership_team_members_r2317 (full_name, role_title, department, hired_on, is_direct_report, comp_band, member_user_id)
  VALUES (p_full_name, p_role_title, COALESCE(p_department,'general'), p_hired_on, COALESCE(p_is_direct_report, true), p_comp_band, p_member_user_id)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_team_member_r2317', jsonb_build_object('member_id', v_id, 'name', p_full_name, 'role', p_role_title));
  RETURN v_id;
END;
$$;

-- RPC 3: record satisfaction signal & recompute risk score
CREATE OR REPLACE FUNCTION public.record_satisfaction_r2317(
  p_member_id uuid,
  p_score int,
  p_notes_md text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_risk int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score IS NULL OR p_score < 1 OR p_score > 10 THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;
  v_risk := GREATEST(0, LEAST(100, (10 - p_score) * 10));
  UPDATE public.leadership_team_members_r2317
  SET last_satisfaction_score = p_score,
      last_satisfaction_at = now(),
      retention_risk_score = v_risk,
      status = CASE
        WHEN v_risk >= 70 THEN 'at_risk'
        WHEN v_risk >= 40 THEN 'at_risk'
        ELSE status
      END,
      notes_md = CASE WHEN COALESCE(p_notes_md,'') = '' THEN notes_md ELSE notes_md || E'\n---\n' || p_notes_md END,
      updated_at = now()
  WHERE id = p_member_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_satisfaction_r2317', jsonb_build_object('member_id', p_member_id, 'score', p_score, 'risk', v_risk));
END;
$$;

-- RPC 4: log retention play
CREATE OR REPLACE FUNCTION public.log_retention_play_r2317(
  p_member_id uuid,
  p_play_type text,
  p_play_summary text,
  p_followup_due_on date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.leadership_retention_plays_r2317 (member_id, play_type, play_summary, followup_due_on)
  VALUES (p_member_id, p_play_type, p_play_summary, p_followup_due_on)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_retention_play_r2317', jsonb_build_object('play_id', v_id, 'member_id', p_member_id, 'play_type', p_play_type));
  RETURN v_id;
END;
$$;

-- RPC 5: list recent plays
CREATE OR REPLACE FUNCTION public.list_recent_plays_r2317()
RETURNS TABLE (
  id uuid,
  member_id uuid,
  full_name text,
  role_title text,
  play_type text,
  play_summary text,
  played_on date,
  outcome text,
  followup_due_on date
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.member_id, m.full_name, m.role_title, p.play_type, p.play_summary,
    p.played_on, p.outcome, p.followup_due_on
  FROM public.leadership_retention_plays_r2317 p
  JOIN public.leadership_team_members_r2317 m ON m.id = p.member_id
  ORDER BY p.played_on DESC, p.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 6: at-risk roster (top retention risks)
CREATE OR REPLACE FUNCTION public.at_risk_roster_r2317()
RETURNS TABLE (
  id uuid,
  full_name text,
  role_title text,
  department text,
  tenure_days int,
  last_satisfaction_score int,
  retention_risk_score int,
  status text,
  last_play_on date,
  last_play_type text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.full_name, m.role_title, m.department,
    (CURRENT_DATE - m.hired_on)::int AS tenure_days,
    m.last_satisfaction_score, m.retention_risk_score, m.status,
    (SELECT p.played_on FROM public.leadership_retention_plays_r2317 p WHERE p.member_id = m.id ORDER BY p.played_on DESC LIMIT 1) AS last_play_on,
    (SELECT p.play_type FROM public.leadership_retention_plays_r2317 p WHERE p.member_id = m.id ORDER BY p.played_on DESC LIMIT 1) AS last_play_type
  FROM public.leadership_team_members_r2317 m
  WHERE m.status IN ('active','at_risk','on_notice')
    AND m.retention_risk_score >= 40
  ORDER BY m.retention_risk_score DESC
  LIMIT 50;
END;
$$;

-- RPC 7: department retention summary
CREATE OR REPLACE FUNCTION public.department_retention_summary_r2317()
RETURNS TABLE (
  department text,
  headcount int,
  direct_reports int,
  active_members int,
  at_risk_members int,
  on_notice_members int,
  departed_members int,
  avg_tenure_days int,
  avg_satisfaction numeric,
  avg_risk_score numeric,
  plays_last_30d int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.department,
    (COUNT(*))::int AS headcount,
    (COUNT(*) FILTER (WHERE m.is_direct_report))::int AS direct_reports,
    (COUNT(*) FILTER (WHERE m.status='active'))::int AS active_members,
    (COUNT(*) FILTER (WHERE m.status='at_risk'))::int AS at_risk_members,
    (COUNT(*) FILTER (WHERE m.status='on_notice'))::int AS on_notice_members,
    (COUNT(*) FILTER (WHERE m.status='departed'))::int AS departed_members,
    (AVG(CURRENT_DATE - m.hired_on))::int AS avg_tenure_days,
    ROUND(AVG(m.last_satisfaction_score)::numeric, 2) AS avg_satisfaction,
    ROUND(AVG(m.retention_risk_score)::numeric, 2) AS avg_risk_score,
    (SELECT (COUNT(*))::int FROM public.leadership_retention_plays_r2317 p
       JOIN public.leadership_team_members_r2317 m2 ON m2.id = p.member_id
       WHERE m2.department = m.department
         AND p.played_on >= CURRENT_DATE - INTERVAL '30 days') AS plays_last_30d
  FROM public.leadership_team_members_r2317 m
  GROUP BY m.department
  ORDER BY at_risk_members DESC, headcount DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_team_members_r2317() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_team_member_r2317(text, text, text, date, boolean, text, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_satisfaction_r2317(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_retention_play_r2317(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_recent_plays_r2317() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_roster_r2317() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.department_retention_summary_r2317() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_team_members_r2317() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_team_member_r2317(text, text, text, date, boolean, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_satisfaction_r2317(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_retention_play_r2317(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_recent_plays_r2317() TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_roster_r2317() TO authenticated;
GRANT EXECUTE ON FUNCTION public.department_retention_summary_r2317() TO authenticated;

COMMIT;
