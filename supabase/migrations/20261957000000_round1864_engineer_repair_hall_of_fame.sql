BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_repair_hall_of_fame_r1864 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  repair_complexity_score int NOT NULL CHECK (repair_complexity_score BETWEEN 1 AND 10),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  photo_url text,
  video_url text,
  story_md text,
  marketing_use boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'nominated' CHECK (status IN ('nominated','approved','featured','archived')),
  featured_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_repair_hof_nominations_r1864 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_id uuid NOT NULL REFERENCES public.engineer_repair_hall_of_fame_r1864(id) ON DELETE CASCADE,
  nominator_email text NOT NULL,
  nomination_reason text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_repair_hall_of_fame_r1864 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_repair_hof_nominations_r1864 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hof_founder_all ON public.engineer_repair_hall_of_fame_r1864;
CREATE POLICY hof_founder_all ON public.engineer_repair_hall_of_fame_r1864
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hof_nom_founder_all ON public.engineer_repair_hof_nominations_r1864;
CREATE POLICY hof_nom_founder_all ON public.engineer_repair_hof_nominations_r1864
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_repairs_r1864()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  repair_job_id uuid,
  repair_complexity_score int,
  hospital_user_id uuid,
  hospital_email text,
  story_md text,
  marketing_use boolean,
  status text,
  featured_at timestamptz,
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
  SELECT h.id, h.engineer_user_id, pe.email, h.repair_job_id, h.repair_complexity_score,
         h.hospital_user_id, ph.email, h.story_md, h.marketing_use, h.status, h.featured_at, h.created_at
  FROM public.engineer_repair_hall_of_fame_r1864 h
  LEFT JOIN public.profiles pe ON pe.id = h.engineer_user_id
  LEFT JOIN public.profiles ph ON ph.id = h.hospital_user_id
  ORDER BY h.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.nominate_r1864(
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_complexity int,
  p_hospital_user_id uuid,
  p_story_md text
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
  INSERT INTO public.engineer_repair_hall_of_fame_r1864
    (engineer_user_id, repair_job_id, repair_complexity_score, hospital_user_id, story_md, status)
  VALUES (p_engineer_user_id, p_repair_job_id, p_complexity, p_hospital_user_id, p_story_md, 'nominated')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1864_nominate',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'complexity', p_complexity));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_nominations_r1864()
RETURNS TABLE (
  id uuid,
  repair_id uuid,
  nominator_email text,
  nomination_reason text,
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
  SELECT n.id, n.repair_id, n.nominator_email, n.nomination_reason, n.recorded_at
  FROM public.engineer_repair_hof_nominations_r1864 n
  ORDER BY n.recorded_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_nomination_r1864(
  p_repair_id uuid,
  p_nominator_email text,
  p_reason text
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
  INSERT INTO public.engineer_repair_hof_nominations_r1864
    (repair_id, nominator_email, nomination_reason)
  VALUES (p_repair_id, p_nominator_email, p_reason)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1864_log_nomination',
    jsonb_build_object('id', v_id, 'repair_id', p_repair_id, 'nominator_email', p_nominator_email));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.feature_repair_r1864(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_repair_hall_of_fame_r1864
  SET status = 'featured', featured_at = now(), updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1864_feature_repair',
    jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_complexity_r1864()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  repair_complexity_score int,
  status text,
  story_md text,
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
  SELECT h.id, h.engineer_user_id, pe.email, h.repair_complexity_score, h.status, h.story_md, h.created_at
  FROM public.engineer_repair_hall_of_fame_r1864 h
  LEFT JOIN public.profiles pe ON pe.id = h.engineer_user_id
  ORDER BY h.repair_complexity_score DESC, h.created_at DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.recently_featured_r1864()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  repair_complexity_score int,
  story_md text,
  marketing_use boolean,
  featured_at timestamptz
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
  SELECT h.id, h.engineer_user_id, pe.email, h.repair_complexity_score, h.story_md, h.marketing_use, h.featured_at
  FROM public.engineer_repair_hall_of_fame_r1864 h
  LEFT JOIN public.profiles pe ON pe.id = h.engineer_user_id
  WHERE h.status = 'featured' AND h.featured_at IS NOT NULL
  ORDER BY h.featured_at DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_repairs_r1864() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.nominate_r1864(uuid, uuid, int, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_nominations_r1864() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_nomination_r1864(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.feature_repair_r1864(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_complexity_r1864() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recently_featured_r1864() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_repairs_r1864() TO authenticated;
GRANT EXECUTE ON FUNCTION public.nominate_r1864(uuid, uuid, int, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_nominations_r1864() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_nomination_r1864(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feature_repair_r1864(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_complexity_r1864() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recently_featured_r1864() TO authenticated;

COMMIT;