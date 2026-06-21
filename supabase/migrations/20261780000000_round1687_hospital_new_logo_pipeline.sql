BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_new_logo_prospects_r1687 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_name text NOT NULL,
  city text,
  state text,
  intro_source text,
  expected_arr_rupees bigint NOT NULL DEFAULT 0,
  stage text NOT NULL DEFAULT 'intro' CHECK (stage IN ('intro','discovery','proposal','contract','won','lost')),
  owner_email text,
  last_activity_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_new_logo_activities_r1687 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid NOT NULL REFERENCES public.hospital_new_logo_prospects_r1687(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('email','call','visit','demo','proposal','follow_up')),
  activity_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hnlp_r1687_stage ON public.hospital_new_logo_prospects_r1687(stage);
CREATE INDEX IF NOT EXISTS idx_hnlp_r1687_last_activity ON public.hospital_new_logo_prospects_r1687(last_activity_at);
CREATE INDEX IF NOT EXISTS idx_hnla_r1687_prospect ON public.hospital_new_logo_activities_r1687(prospect_id);
CREATE INDEX IF NOT EXISTS idx_hnla_r1687_at ON public.hospital_new_logo_activities_r1687(activity_at);

-- RLS
ALTER TABLE public.hospital_new_logo_prospects_r1687 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_new_logo_activities_r1687 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hnlp_r1687_founder_all ON public.hospital_new_logo_prospects_r1687;
CREATE POLICY hnlp_r1687_founder_all ON public.hospital_new_logo_prospects_r1687
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hnla_r1687_founder_all ON public.hospital_new_logo_activities_r1687;
CREATE POLICY hnla_r1687_founder_all ON public.hospital_new_logo_activities_r1687
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_prospects
CREATE OR REPLACE FUNCTION public.list_prospects_r1687(p_stage text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  state text,
  intro_source text,
  expected_arr_rupees bigint,
  stage text,
  owner_email text,
  last_activity_at timestamptz,
  activity_count int,
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
    p.id,
    p.hospital_name,
    p.city,
    p.state,
    p.intro_source,
    p.expected_arr_rupees,
    p.stage,
    p.owner_email,
    p.last_activity_at,
    (SELECT (COUNT(*))::int FROM public.hospital_new_logo_activities_r1687 a WHERE a.prospect_id = p.id) AS activity_count,
    p.created_at
  FROM public.hospital_new_logo_prospects_r1687 p
  WHERE (p_stage IS NULL OR p.stage = p_stage)
  ORDER BY p.expected_arr_rupees DESC, p.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: add_prospect
CREATE OR REPLACE FUNCTION public.add_prospect_r1687(
  p_hospital_name text,
  p_city text DEFAULT NULL,
  p_state text DEFAULT NULL,
  p_intro_source text DEFAULT NULL,
  p_expected_arr_rupees bigint DEFAULT 0,
  p_owner_email text DEFAULT NULL
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
  INSERT INTO public.hospital_new_logo_prospects_r1687(
    hospital_name, city, state, intro_source, expected_arr_rupees, owner_email
  ) VALUES (
    p_hospital_name, p_city, p_state, p_intro_source, COALESCE(p_expected_arr_rupees,0), p_owner_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_prospect_r1687',
    jsonb_build_object('id', v_id, 'hospital_name', p_hospital_name, 'expected_arr_rupees', p_expected_arr_rupees));

  RETURN v_id;
END;
$$;

-- RPC 3: advance_stage
CREATE OR REPLACE FUNCTION public.advance_stage_r1687(
  p_prospect_id uuid,
  p_new_stage text
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
  IF p_new_stage NOT IN ('intro','discovery','proposal','contract','won','lost') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;
  UPDATE public.hospital_new_logo_prospects_r1687
     SET stage = p_new_stage, updated_at = now()
   WHERE id = p_prospect_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'advance_stage_r1687',
    jsonb_build_object('prospect_id', p_prospect_id, 'new_stage', p_new_stage));
END;
$$;

-- RPC 4: list_activities
CREATE OR REPLACE FUNCTION public.list_activities_r1687(p_prospect_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  prospect_id uuid,
  hospital_name text,
  activity_type text,
  activity_at timestamptz,
  by_email text,
  note text
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
    a.id,
    a.prospect_id,
    p.hospital_name,
    a.activity_type,
    a.activity_at,
    a.by_email,
    a.note
  FROM public.hospital_new_logo_activities_r1687 a
  JOIN public.hospital_new_logo_prospects_r1687 p ON p.id = a.prospect_id
  WHERE (p_prospect_id IS NULL OR a.prospect_id = p_prospect_id)
  ORDER BY a.activity_at DESC
  LIMIT 500;
END;
$$;

-- RPC 5: log_activity
CREATE OR REPLACE FUNCTION public.log_activity_r1687(
  p_prospect_id uuid,
  p_activity_type text,
  p_by_email text DEFAULT NULL,
  p_note text DEFAULT NULL
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
  IF p_activity_type NOT IN ('email','call','visit','demo','proposal','follow_up') THEN
    RAISE EXCEPTION 'invalid activity_type';
  END IF;
  INSERT INTO public.hospital_new_logo_activities_r1687(
    prospect_id, activity_type, by_email, note
  ) VALUES (
    p_prospect_id, p_activity_type, p_by_email, p_note
  ) RETURNING id INTO v_id;

  UPDATE public.hospital_new_logo_prospects_r1687
     SET last_activity_at = now(), updated_at = now()
   WHERE id = p_prospect_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_activity_r1687',
    jsonb_build_object('id', v_id, 'prospect_id', p_prospect_id, 'activity_type', p_activity_type));

  RETURN v_id;
END;
$$;

-- RPC 6: pipeline_summary_by_stage
CREATE OR REPLACE FUNCTION public.pipeline_summary_by_stage_r1687()
RETURNS TABLE (
  stage text,
  prospect_count int,
  total_arr_rupees bigint,
  avg_arr_rupees bigint
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
    p.stage,
    (COUNT(*))::int AS prospect_count,
    COALESCE(SUM(p.expected_arr_rupees),0)::bigint AS total_arr_rupees,
    COALESCE(AVG(p.expected_arr_rupees),0)::bigint AS avg_arr_rupees
  FROM public.hospital_new_logo_prospects_r1687 p
  GROUP BY p.stage
  ORDER BY p.stage;
END;
$$;

-- RPC 7: stale_prospects
CREATE OR REPLACE FUNCTION public.stale_prospects_r1687(p_days int DEFAULT 14)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  stage text,
  expected_arr_rupees bigint,
  owner_email text,
  last_activity_at timestamptz,
  days_stale int
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
    p.id,
    p.hospital_name,
    p.city,
    p.stage,
    p.expected_arr_rupees,
    p.owner_email,
    p.last_activity_at,
    (EXTRACT(EPOCH FROM (now() - COALESCE(p.last_activity_at, p.created_at)))/86400)::int AS days_stale
  FROM public.hospital_new_logo_prospects_r1687 p
  WHERE p.stage NOT IN ('won','lost')
    AND COALESCE(p.last_activity_at, p.created_at) < now() - make_interval(days => COALESCE(p_days,14))
  ORDER BY p.expected_arr_rupees DESC
  LIMIT 200;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_prospects_r1687(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_prospect_r1687(text, text, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.advance_stage_r1687(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_activities_r1687(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_activity_r1687(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pipeline_summary_by_stage_r1687() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stale_prospects_r1687(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_prospects_r1687(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_prospect_r1687(text, text, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage_r1687(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_activities_r1687(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_activity_r1687(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pipeline_summary_by_stage_r1687() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stale_prospects_r1687(int) TO authenticated;

COMMIT;