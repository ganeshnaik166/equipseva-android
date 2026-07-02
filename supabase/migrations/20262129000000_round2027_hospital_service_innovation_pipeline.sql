BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_innovation_pipeline_r2027 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  innovation_label text NOT NULL,
  innovation_md text,
  stage text NOT NULL CHECK (stage IN ('ideation','scoping','poc','pilot','rolled_out','abandoned')),
  estimated_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('active','paused','closed','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_innovation_stage_log_r2027 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  innovation_id uuid NOT NULL REFERENCES public.hospital_service_innovation_pipeline_r2027(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('moved_to_stage','blocker_resolved','pivoted','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_innovation_pipeline_r2027 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_innovation_stage_log_r2027 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_innov_r2027 ON public.hospital_service_innovation_pipeline_r2027;
CREATE POLICY founder_all_innov_r2027 ON public.hospital_service_innovation_pipeline_r2027
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_stage_r2027 ON public.hospital_innovation_stage_log_r2027;
CREATE POLICY founder_all_stage_r2027 ON public.hospital_innovation_stage_log_r2027
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_innovations_r2027()
RETURNS TABLE (id uuid, hospital_id uuid, hospital_name text, innovation_label text, stage text, status text, estimated_value_rupees bigint, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.hospital_id, COALESCE(o.name, p.email) AS hospital_name,
         i.innovation_label, i.stage, i.status, i.estimated_value_rupees, i.captured_at
  FROM public.hospital_service_innovation_pipeline_r2027 i
  LEFT JOIN public.profiles p ON p.id = i.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY i.captured_at DESC
  LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_innovation_r2027(
  p_hospital_id uuid, p_label text, p_md text, p_stage text, p_value bigint, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_innovation_pipeline_r2027(hospital_id, innovation_label, innovation_md, stage, estimated_value_rupees, status)
  VALUES (p_hospital_id, p_label, p_md, p_stage, COALESCE(p_value,0), p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_innovation_r2027', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'stage', p_stage));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_stages_r2027(p_innovation_id uuid)
RETURNS TABLE (id uuid, innovation_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.innovation_id, s.action_type, s.taken_at, s.by_email, s.notes_md
  FROM public.hospital_innovation_stage_log_r2027 s
  WHERE s.innovation_id = p_innovation_id
  ORDER BY s.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_stage_r2027(
  p_innovation_id uuid, p_action_type text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_innovation_stage_log_r2027(innovation_id, action_type, by_email, notes_md)
  VALUES (p_innovation_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stage_r2027', jsonb_build_object('id', v_id, 'innovation_id', p_innovation_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2027(p_innovation_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_innovation_pipeline_r2027
  SET status = p_status, updated_at = now()
  WHERE id = p_innovation_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2027', jsonb_build_object('id', p_innovation_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.by_stage_r2027()
RETURNS TABLE (stage text, n bigint, total_value_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.stage, COUNT(*)::bigint AS n, COALESCE(SUM(i.estimated_value_rupees),0)::bigint AS total_value_rupees
  FROM public.hospital_service_innovation_pipeline_r2027 i
  GROUP BY i.stage
  ORDER BY n DESC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_stages_r2027()
RETURNS TABLE (id uuid, innovation_id uuid, innovation_label text, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.innovation_id, i.innovation_label, s.action_type, s.taken_at, s.by_email
  FROM public.hospital_innovation_stage_log_r2027 s
  JOIN public.hospital_service_innovation_pipeline_r2027 i ON i.id = s.innovation_id
  ORDER BY s.taken_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_innovations_r2027() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_innovation_r2027(uuid,text,text,text,bigint,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_stages_r2027(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_stage_r2027(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2027(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.by_stage_r2027() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_stages_r2027() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_innovations_r2027() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_innovation_r2027(uuid,text,text,text,bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_stages_r2027(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_stage_r2027(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2027(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.by_stage_r2027() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_stages_r2027() TO authenticated;

COMMIT;
