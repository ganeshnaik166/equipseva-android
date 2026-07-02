BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_compliments_r1928 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  compliment_text_md text NOT NULL,
  compliment_source text NOT NULL CHECK (compliment_source IN ('survey','voicemail','email','in_person','text_message')),
  severity_of_praise text NOT NULL CHECK (severity_of_praise IN ('standard','exceptional','heroic')),
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','celebrated','promoted_to_marketing')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_compliment_response_log_r1928 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliment_id uuid NOT NULL REFERENCES public.engineer_customer_compliments_r1928(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_you_sent','team_share','bonus_consideration','marketing_use')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_compliments_r1928 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_compliment_response_log_r1928 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_compliments_r1928 ON public.engineer_customer_compliments_r1928;
CREATE POLICY founder_all_compliments_r1928 ON public.engineer_customer_compliments_r1928
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_responses_r1928 ON public.engineer_compliment_response_log_r1928;
CREATE POLICY founder_all_responses_r1928 ON public.engineer_compliment_response_log_r1928
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_compliments_r1928()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  repair_job_id uuid,
  compliment_text_md text,
  compliment_source text,
  severity_of_praise text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, p.email, c.hospital_id, o.name,
         c.repair_job_id, c.compliment_text_md, c.compliment_source,
         c.severity_of_praise, c.status, c.captured_at
  FROM public.engineer_customer_compliments_r1928 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = c.hospital_id
  ORDER BY c.captured_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_compliment_r1928(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_repair_job_id uuid,
  p_text_md text,
  p_source text,
  p_severity text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_compliments_r1928 (engineer_user_id, hospital_id, repair_job_id, compliment_text_md, compliment_source, severity_of_praise)
  VALUES (p_engineer_user_id, p_hospital_id, p_repair_job_id, p_text_md, p_source, p_severity)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_compliment_r1928',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'severity', p_severity));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_responses_r1928(p_compliment_id uuid)
RETURNS TABLE (
  id uuid,
  compliment_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.compliment_id, r.action_type, r.taken_at, r.by_email
  FROM public.engineer_compliment_response_log_r1928 r
  WHERE r.compliment_id = p_compliment_id
  ORDER BY r.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_response_r1928(
  p_compliment_id uuid,
  p_action_type text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := COALESCE((auth.jwt()->>'email'), 'unknown');
  INSERT INTO public.engineer_compliment_response_log_r1928 (compliment_id, action_type, by_email)
  VALUES (p_compliment_id, p_action_type, v_email)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_response_r1928',
          jsonb_build_object('id', v_id, 'compliment_id', p_compliment_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1928(
  p_compliment_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_compliments_r1928
  SET status = p_status, updated_at = now()
  WHERE id = p_compliment_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1928',
          jsonb_build_object('id', p_compliment_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_engineers_complimented_r1928()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_compliments bigint,
  heroic_count bigint,
  exceptional_count bigint,
  standard_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         p.email,
         COUNT(*)::bigint AS total_compliments,
         COUNT(*) FILTER (WHERE c.severity_of_praise = 'heroic')::bigint,
         COUNT(*) FILTER (WHERE c.severity_of_praise = 'exceptional')::bigint,
         COUNT(*) FILTER (WHERE c.severity_of_praise = 'standard')::bigint
  FROM public.engineer_customer_compliments_r1928 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  GROUP BY c.engineer_user_id, p.email
  ORDER BY total_compliments DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_responses_r1928()
RETURNS TABLE (
  id uuid,
  compliment_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  engineer_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.compliment_id, r.action_type, r.taken_at, r.by_email, p.email
  FROM public.engineer_compliment_response_log_r1928 r
  LEFT JOIN public.engineer_customer_compliments_r1928 c ON c.id = r.compliment_id
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY r.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_compliments_r1928() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_compliment_r1928(uuid, uuid, uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_responses_r1928(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_response_r1928(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1928(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engineers_complimented_r1928() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_responses_r1928() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_compliments_r1928() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_compliment_r1928(uuid, uuid, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_responses_r1928(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_response_r1928(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1928(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineers_complimented_r1928() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_responses_r1928() TO authenticated;

COMMIT;
