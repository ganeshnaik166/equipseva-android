BEGIN;

-- ============================================================
-- Round 2016 — Engineer Hospital Visit Logger
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_hospital_visit_logger_r2016 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  visit_date date NOT NULL DEFAULT CURRENT_DATE,
  visit_purpose text NOT NULL CHECK (visit_purpose IN ('repair','diagnostic','installation','training','consultation','social_call')),
  visit_duration_minutes integer NOT NULL DEFAULT 0 CHECK (visit_duration_minutes >= 0),
  outcome_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled','no_show')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_visit_action_log_r2016 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL REFERENCES public.engineer_hospital_visit_logger_r2016(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('rescheduled','extended','cancelled','follow_up_required','no_show')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehvl_r2016_engineer ON public.engineer_hospital_visit_logger_r2016(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ehvl_r2016_hospital ON public.engineer_hospital_visit_logger_r2016(hospital_id);
CREATE INDEX IF NOT EXISTS idx_ehvl_r2016_visit_date ON public.engineer_hospital_visit_logger_r2016(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_eval_r2016_visit ON public.engineer_visit_action_log_r2016(visit_id);
CREATE INDEX IF NOT EXISTS idx_eval_r2016_taken_at ON public.engineer_visit_action_log_r2016(taken_at DESC);

ALTER TABLE public.engineer_hospital_visit_logger_r2016 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_visit_action_log_r2016 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ehvl_r2016_founder ON public.engineer_hospital_visit_logger_r2016;
CREATE POLICY p_ehvl_r2016_founder ON public.engineer_hospital_visit_logger_r2016
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_eval_r2016_founder ON public.engineer_visit_action_log_r2016;
CREATE POLICY p_eval_r2016_founder ON public.engineer_visit_action_log_r2016
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.list_visits_r2016(integer);
CREATE OR REPLACE FUNCTION public.list_visits_r2016(p_limit integer DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  visit_date date,
  visit_purpose text,
  visit_duration_minutes integer,
  outcome_md text,
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
  SELECT v.id, v.engineer_user_id, p.email::text, v.hospital_id, o.name::text,
         v.visit_date, v.visit_purpose, v.visit_duration_minutes, v.outcome_md,
         v.status, v.captured_at
  FROM public.engineer_hospital_visit_logger_r2016 v
  LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = v.hospital_id
  ORDER BY v.visit_date DESC, v.captured_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

DROP FUNCTION IF EXISTS public.log_visit_r2016(uuid, uuid, date, text, integer, text, text);
CREATE OR REPLACE FUNCTION public.log_visit_r2016(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_visit_date date,
  p_visit_purpose text,
  p_visit_duration_minutes integer,
  p_outcome_md text,
  p_status text
) RETURNS uuid
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
  INSERT INTO public.engineer_hospital_visit_logger_r2016(
    engineer_user_id, hospital_id, visit_date, visit_purpose,
    visit_duration_minutes, outcome_md, status
  ) VALUES (
    p_engineer_user_id, p_hospital_id, p_visit_date, p_visit_purpose,
    COALESCE(p_visit_duration_minutes, 0), p_outcome_md, COALESCE(p_status, 'planned')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_visit_r2016',
          jsonb_build_object('visit_id', v_id, 'engineer_user_id', p_engineer_user_id, 'hospital_id', p_hospital_id));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r2016(uuid, integer);
CREATE OR REPLACE FUNCTION public.list_actions_r2016(p_visit_id uuid DEFAULT NULL, p_limit integer DEFAULT 200)
RETURNS TABLE (
  id uuid,
  visit_id uuid,
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
  SELECT a.id, a.visit_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_visit_action_log_r2016 a
  WHERE (p_visit_id IS NULL OR a.visit_id = p_visit_id)
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r2016(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2016(
  p_visit_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
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
  INSERT INTO public.engineer_visit_action_log_r2016(visit_id, action_type, by_email, notes_md)
  VALUES (p_visit_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2016',
          jsonb_build_object('action_id', v_id, 'visit_id', p_visit_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r2016(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2016(p_visit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_hospital_visit_logger_r2016
  SET status = p_status, updated_at = now()
  WHERE id = p_visit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2016',
          jsonb_build_object('visit_id', p_visit_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.top_visited_hospitals_r2016(integer);
CREATE OR REPLACE FUNCTION public.top_visited_hospitals_r2016(p_limit integer DEFAULT 20)
RETURNS TABLE (
  hospital_id uuid,
  hospital_name text,
  visit_count bigint,
  total_minutes bigint,
  last_visit_date date
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
  SELECT v.hospital_id, o.name::text, COUNT(*)::bigint,
         COALESCE(SUM(v.visit_duration_minutes),0)::bigint,
         MAX(v.visit_date)
  FROM public.engineer_hospital_visit_logger_r2016 v
  LEFT JOIN public.organizations o ON o.id = v.hospital_id
  GROUP BY v.hospital_id, o.name
  ORDER BY COUNT(*) DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r2016(integer);
CREATE OR REPLACE FUNCTION public.recent_actions_r2016(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  visit_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text,
  hospital_name text
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
  SELECT a.id, a.visit_id, a.action_type, a.taken_at, a.by_email, a.notes_md, o.name::text
  FROM public.engineer_visit_action_log_r2016 a
  LEFT JOIN public.engineer_hospital_visit_logger_r2016 v ON v.id = a.visit_id
  LEFT JOIN public.organizations o ON o.id = v.hospital_id
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_visits_r2016(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_visits_r2016(integer) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.log_visit_r2016(uuid, uuid, date, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_visit_r2016(uuid, uuid, date, text, integer, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2016(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2016(uuid, integer) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.log_action_r2016(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2016(uuid, text, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2016(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2016(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.top_visited_hospitals_r2016(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_visited_hospitals_r2016(integer) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2016(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2016(integer) TO authenticated;

COMMIT;
