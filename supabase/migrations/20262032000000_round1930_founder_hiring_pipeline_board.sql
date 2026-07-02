BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_hiring_pipeline_r1930 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_label text NOT NULL,
  candidate_name text NOT NULL,
  candidate_email text,
  stage text NOT NULL CHECK (stage IN ('sourced','screen','interview','onsite','reference','offer','joined','dropped')),
  status text NOT NULL CHECK (status IN ('active','joined','dropped','declined')),
  sourced_at timestamptz NOT NULL DEFAULT now(),
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  fit_score int CHECK (fit_score >= 0 AND fit_score <= 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_hiring_activity_log_r1930 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.founder_hiring_pipeline_r1930(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('sourcing_note','interview_held','reference_called','offer_sent','feedback_logged')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_hiring_pipeline_r1930 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_hiring_activity_log_r1930 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_hiring_pipeline_r1930_founder ON public.founder_hiring_pipeline_r1930;
CREATE POLICY founder_hiring_pipeline_r1930_founder ON public.founder_hiring_pipeline_r1930
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_hiring_activity_log_r1930_founder ON public.founder_hiring_activity_log_r1930;
CREATE POLICY founder_hiring_activity_log_r1930_founder ON public.founder_hiring_activity_log_r1930
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.fhp_r1930_list_candidates(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, role_label text, candidate_name text, candidate_email text, stage text, status text, sourced_at timestamptz, last_activity_at timestamptz, fit_score int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.role_label, c.candidate_name, c.candidate_email, c.stage, c.status, c.sourced_at, c.last_activity_at, c.fit_score
      FROM public.founder_hiring_pipeline_r1930 c
      ORDER BY c.last_activity_at DESC
      LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_log_candidate(p_role text, p_name text, p_email text, p_stage text, p_status text, p_fit int)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_hiring_pipeline_r1930(role_label, candidate_name, candidate_email, stage, status, fit_score)
    VALUES (p_role, p_name, p_email, p_stage, p_status, p_fit)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'fhp_r1930_log_candidate', jsonb_build_object('id', v_id, 'role', p_role, 'name', p_name));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_list_activities(p_candidate_id uuid, p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, candidate_id uuid, activity_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.candidate_id, a.activity_type, a.taken_at, a.by_email, a.notes_md
      FROM public.founder_hiring_activity_log_r1930 a
      WHERE a.candidate_id = p_candidate_id
      ORDER BY a.taken_at DESC
      LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_log_activity(p_candidate_id uuid, p_activity_type text, p_by_email text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_hiring_activity_log_r1930(candidate_id, activity_type, by_email, notes_md)
    VALUES (p_candidate_id, p_activity_type, p_by_email, p_notes)
    RETURNING id INTO v_id;
  UPDATE public.founder_hiring_pipeline_r1930
    SET last_activity_at = now(), updated_at = now()
    WHERE id = p_candidate_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'fhp_r1930_log_activity', jsonb_build_object('id', v_id, 'candidate_id', p_candidate_id, 'type', p_activity_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_mark_stage(p_candidate_id uuid, p_stage text, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_hiring_pipeline_r1930
    SET stage = p_stage, status = p_status, last_activity_at = now(), updated_at = now()
    WHERE id = p_candidate_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'fhp_r1930_mark_stage', jsonb_build_object('id', p_candidate_id, 'stage', p_stage, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_top_roles()
RETURNS TABLE(role_label text, active_count bigint, joined_count bigint, dropped_count bigint, avg_fit numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.role_label,
           count(*) FILTER (WHERE c.status = 'active') AS active_count,
           count(*) FILTER (WHERE c.status = 'joined') AS joined_count,
           count(*) FILTER (WHERE c.status = 'dropped' OR c.status = 'declined') AS dropped_count,
           round(avg(c.fit_score)::numeric, 1) AS avg_fit
      FROM public.founder_hiring_pipeline_r1930 c
      GROUP BY c.role_label
      ORDER BY active_count DESC
      LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.fhp_r1930_recent_activities(p_limit int DEFAULT 30)
RETURNS TABLE(id uuid, candidate_id uuid, candidate_name text, role_label text, activity_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.candidate_id, c.candidate_name, c.role_label, a.activity_type, a.taken_at, a.by_email, a.notes_md
      FROM public.founder_hiring_activity_log_r1930 a
      JOIN public.founder_hiring_pipeline_r1930 c ON c.id = a.candidate_id
      ORDER BY a.taken_at DESC
      LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fhp_r1930_list_candidates(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_log_candidate(text, text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_list_activities(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_log_activity(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_mark_stage(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_top_roles() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fhp_r1930_recent_activities(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fhp_r1930_list_candidates(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_log_candidate(text, text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_list_activities(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_log_activity(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_mark_stage(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_top_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fhp_r1930_recent_activities(int) TO authenticated;

COMMIT;
