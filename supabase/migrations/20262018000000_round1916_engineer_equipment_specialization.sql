BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_equipment_specialization_r1916 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','ventilator','anesthesia','monitor','lab','other')),
  certification_level text NOT NULL CHECK (certification_level IN ('trainee','competent','proficient','expert','master')),
  jobs_completed_in_category int NOT NULL DEFAULT 0,
  last_job_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_specialization_milestone_log_r1916 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spec_id uuid NOT NULL REFERENCES public.engineer_equipment_specialization_r1916(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('first_job','cert_passed','expert_review','master_review')),
  milestone_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_equipment_specialization_r1916 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_specialization_milestone_log_r1916 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_spec_r1916 ON public.engineer_equipment_specialization_r1916;
CREATE POLICY founder_all_spec_r1916 ON public.engineer_equipment_specialization_r1916
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_milestone_r1916 ON public.engineer_specialization_milestone_log_r1916;
CREATE POLICY founder_all_milestone_r1916 ON public.engineer_specialization_milestone_log_r1916
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1) list_specializations
CREATE OR REPLACE FUNCTION public.list_specializations_r1916()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  certification_level text,
  jobs_completed_in_category int,
  last_job_at timestamptz,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, p.email, s.equipment_category, s.certification_level,
         s.jobs_completed_in_category, s.last_job_at, s.status, s.created_at
  FROM public.engineer_equipment_specialization_r1916 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.created_at DESC
  LIMIT 200;
END;
$$;

-- 2) log_specialization
CREATE OR REPLACE FUNCTION public.log_specialization_r1916(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_certification_level text
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
  INSERT INTO public.engineer_equipment_specialization_r1916 (engineer_user_id, equipment_category, certification_level)
  VALUES (p_engineer_user_id, p_equipment_category, p_certification_level)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_specialization_r1916',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_equipment_category));
  RETURN v_id;
END;
$$;

-- 3) list_milestones
CREATE OR REPLACE FUNCTION public.list_milestones_r1916(p_spec_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  spec_id uuid,
  milestone_type text,
  milestone_at timestamptz,
  by_email text,
  score int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.spec_id, m.milestone_type, m.milestone_at, m.by_email, m.score, m.created_at
  FROM public.engineer_specialization_milestone_log_r1916 m
  WHERE (p_spec_id IS NULL OR m.spec_id = p_spec_id)
  ORDER BY m.milestone_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_milestone
CREATE OR REPLACE FUNCTION public.log_milestone_r1916(
  p_spec_id uuid,
  p_milestone_type text,
  p_by_email text,
  p_score int
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
  INSERT INTO public.engineer_specialization_milestone_log_r1916 (spec_id, milestone_type, by_email, score)
  VALUES (p_spec_id, p_milestone_type, p_by_email, p_score)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_milestone_r1916',
          jsonb_build_object('id', v_id, 'spec_id', p_spec_id, 'type', p_milestone_type));
  RETURN v_id;
END;
$$;

-- 5) mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1916(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_equipment_specialization_r1916
  SET status = p_status, updated_at = now()
  WHERE id = p_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1916',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- 6) top_specializations
CREATE OR REPLACE FUNCTION public.top_specializations_r1916()
RETURNS TABLE (
  equipment_category text,
  certification_level text,
  engineer_count int,
  total_jobs int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.equipment_category, s.certification_level,
         (COUNT(*) FILTER (WHERE s.status = 'active'))::int AS engineer_count,
         COALESCE(SUM(s.jobs_completed_in_category), 0)::int AS total_jobs
  FROM public.engineer_equipment_specialization_r1916 s
  GROUP BY s.equipment_category, s.certification_level
  ORDER BY engineer_count DESC, total_jobs DESC
  LIMIT 100;
END;
$$;

-- 7) recent_milestones
CREATE OR REPLACE FUNCTION public.recent_milestones_r1916()
RETURNS TABLE (
  id uuid,
  spec_id uuid,
  engineer_email text,
  equipment_category text,
  milestone_type text,
  milestone_at timestamptz,
  score int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.spec_id, p.email, s.equipment_category,
         m.milestone_type, m.milestone_at, m.score
  FROM public.engineer_specialization_milestone_log_r1916 m
  JOIN public.engineer_equipment_specialization_r1916 s ON s.id = m.spec_id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY m.milestone_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_specializations_r1916() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_specialization_r1916(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r1916(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r1916(uuid, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1916(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_specializations_r1916() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_milestones_r1916() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_specializations_r1916() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_specialization_r1916(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1916(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_milestone_r1916(uuid, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1916(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_specializations_r1916() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_milestones_r1916() TO authenticated;

COMMIT;
