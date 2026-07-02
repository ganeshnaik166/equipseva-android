BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_reference_pipeline_r1839 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reference_potential text NOT NULL CHECK (reference_potential IN ('tier_1','tier_2','probably','maybe','no')),
  willingness_to_speak boolean NOT NULL DEFAULT false,
  focus_areas text[] NOT NULL DEFAULT '{}',
  last_groomed_at timestamptz,
  status text NOT NULL DEFAULT 'warming' CHECK (status IN ('warm','warming','cool','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_reference_grooming_actions_r1839 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_id uuid NOT NULL REFERENCES public.hospital_reference_pipeline_r1839(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_you_visit','case_study','founder_call','co_marketing','handwritten_note')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_reference_pipeline_r1839 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_reference_grooming_actions_r1839 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pipeline_founder_all ON public.hospital_reference_pipeline_r1839;
CREATE POLICY pipeline_founder_all ON public.hospital_reference_pipeline_r1839
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS actions_founder_all ON public.hospital_reference_grooming_actions_r1839;
CREATE POLICY actions_founder_all ON public.hospital_reference_grooming_actions_r1839
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_ref_pipeline_potential_r1839 ON public.hospital_reference_pipeline_r1839(reference_potential);
CREATE INDEX IF NOT EXISTS idx_ref_pipeline_status_r1839 ON public.hospital_reference_pipeline_r1839(status);
CREATE INDEX IF NOT EXISTS idx_ref_actions_ref_r1839 ON public.hospital_reference_grooming_actions_r1839(reference_id);
CREATE INDEX IF NOT EXISTS idx_ref_actions_taken_r1839 ON public.hospital_reference_grooming_actions_r1839(taken_at DESC);

-- RPC 1: list_pipeline
CREATE OR REPLACE FUNCTION public.list_pipeline_r1839()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  reference_potential text,
  willingness_to_speak boolean,
  focus_areas text[],
  last_groomed_at timestamptz,
  status text,
  action_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_user_id, pr.email::text, p.reference_potential, p.willingness_to_speak,
         p.focus_areas, p.last_groomed_at, p.status,
         (SELECT COUNT(*) FROM public.hospital_reference_grooming_actions_r1839 a WHERE a.reference_id = p.id) AS action_count
  FROM public.hospital_reference_pipeline_r1839 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  ORDER BY
    CASE p.reference_potential
      WHEN 'tier_1' THEN 1
      WHEN 'tier_2' THEN 2
      WHEN 'probably' THEN 3
      WHEN 'maybe' THEN 4
      WHEN 'no' THEN 5
    END,
    p.last_groomed_at DESC NULLS LAST;
END;
$$;

-- RPC 2: log_pipeline
CREATE OR REPLACE FUNCTION public.log_pipeline_r1839(
  p_hospital_user_id uuid,
  p_reference_potential text,
  p_willingness boolean,
  p_focus_areas text[],
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_reference_pipeline_r1839
    (hospital_user_id, reference_potential, willingness_to_speak, focus_areas, status, last_groomed_at)
  VALUES (p_hospital_user_id, p_reference_potential, COALESCE(p_willingness, false), COALESCE(p_focus_areas, '{}'), COALESCE(p_status, 'warming'), now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pipeline_r1839',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'reference_potential', p_reference_potential));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1839(p_reference_id uuid)
RETURNS TABLE (
  id uuid,
  reference_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.reference_id, a.action_type, a.taken_at, a.by_email, a.outcome
  FROM public.hospital_reference_grooming_actions_r1839 a
  WHERE a.reference_id = p_reference_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r1839(
  p_reference_id uuid,
  p_action_type text,
  p_outcome text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');

  INSERT INTO public.hospital_reference_grooming_actions_r1839
    (reference_id, action_type, by_email, outcome)
  VALUES (p_reference_id, p_action_type, v_email, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.hospital_reference_pipeline_r1839
  SET last_groomed_at = now(), updated_at = now()
  WHERE id = p_reference_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r1839',
          jsonb_build_object('id', v_id, 'reference_id', p_reference_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: update_status
CREATE OR REPLACE FUNCTION public.update_status_r1839(p_reference_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_reference_pipeline_r1839
  SET status = p_status, updated_at = now()
  WHERE id = p_reference_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_status_r1839',
          jsonb_build_object('reference_id', p_reference_id, 'status', p_status));
END;
$$;

-- RPC 6: top_tier_1
CREATE OR REPLACE FUNCTION public.top_tier_1_r1839()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  willingness_to_speak boolean,
  focus_areas text[],
  last_groomed_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_user_id, pr.email::text, p.willingness_to_speak, p.focus_areas, p.last_groomed_at, p.status
  FROM public.hospital_reference_pipeline_r1839 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  WHERE p.reference_potential = 'tier_1' AND p.status IN ('warm','warming')
  ORDER BY p.last_groomed_at DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- RPC 7: recent_groomed
CREATE OR REPLACE FUNCTION public.recent_groomed_r1839()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  reference_potential text,
  status text,
  last_groomed_at timestamptz,
  recent_action_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_user_id, pr.email::text, p.reference_potential, p.status, p.last_groomed_at,
         (SELECT a.action_type FROM public.hospital_reference_grooming_actions_r1839 a
          WHERE a.reference_id = p.id ORDER BY a.taken_at DESC LIMIT 1) AS recent_action_type
  FROM public.hospital_reference_pipeline_r1839 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  WHERE p.last_groomed_at IS NOT NULL
  ORDER BY p.last_groomed_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pipeline_r1839() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pipeline_r1839(uuid, text, boolean, text[], text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1839(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1839(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_status_r1839(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_tier_1_r1839() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_groomed_r1839() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pipeline_r1839() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pipeline_r1839(uuid, text, boolean, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1839(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1839(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_status_r1839(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tier_1_r1839() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_groomed_r1839() TO authenticated;

COMMIT;