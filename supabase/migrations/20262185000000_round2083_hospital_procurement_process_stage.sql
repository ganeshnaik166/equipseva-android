BEGIN;

-- Table 1: hospital_procurement_process_stages_r2083
CREATE TABLE IF NOT EXISTS public.hospital_procurement_process_stages_r2083 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_stage text NOT NULL CHECK (current_stage IN ('needs_assessment','rfp_drafting','vendor_evaluation','negotiation','award','legal_review','contract_signed')),
  stage_entered_at timestamptz NOT NULL DEFAULT now(),
  expected_completion_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','stalled','escalated','completed','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hppss_r2083_hospital ON public.hospital_procurement_process_stages_r2083(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hppss_r2083_status ON public.hospital_procurement_process_stages_r2083(status);
CREATE INDEX IF NOT EXISTS idx_hppss_r2083_captured ON public.hospital_procurement_process_stages_r2083(captured_at DESC);

ALTER TABLE public.hospital_procurement_process_stages_r2083 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hppss_r2083 ON public.hospital_procurement_process_stages_r2083;
CREATE POLICY founder_all_hppss_r2083 ON public.hospital_procurement_process_stages_r2083
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: hospital_procurement_progress_log_r2083
CREATE TABLE IF NOT EXISTS public.hospital_procurement_progress_log_r2083 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id uuid NOT NULL REFERENCES public.hospital_procurement_process_stages_r2083(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('advanced','stalled','escalated','completed','abandoned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hppl_r2083_stage ON public.hospital_procurement_progress_log_r2083(stage_id);
CREATE INDEX IF NOT EXISTS idx_hppl_r2083_taken ON public.hospital_procurement_progress_log_r2083(taken_at DESC);

ALTER TABLE public.hospital_procurement_progress_log_r2083 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hppl_r2083 ON public.hospital_procurement_progress_log_r2083;
CREATE POLICY founder_all_hppl_r2083 ON public.hospital_procurement_progress_log_r2083
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_processes
CREATE OR REPLACE FUNCTION public.list_procurement_processes_r2083()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  current_stage text,
  stage_entered_at timestamptz,
  expected_completion_date date,
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
  SELECT s.id, s.hospital_id, p.email, s.current_stage, s.stage_entered_at, s.expected_completion_date, s.status, s.captured_at
  FROM public.hospital_procurement_process_stages_r2083 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  ORDER BY s.captured_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log_process
CREATE OR REPLACE FUNCTION public.log_procurement_process_r2083(
  p_hospital_id uuid,
  p_current_stage text,
  p_expected_completion_date date,
  p_status text
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
  INSERT INTO public.hospital_procurement_process_stages_r2083(hospital_id, current_stage, expected_completion_date, status)
  VALUES (p_hospital_id, p_current_stage, p_expected_completion_date, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_procurement_process_r2083', jsonb_build_object('stage_id', v_id, 'hospital_id', p_hospital_id, 'current_stage', p_current_stage));
  RETURN v_id;
END;
$$;

-- RPC 3: list_progress
CREATE OR REPLACE FUNCTION public.list_procurement_progress_r2083(p_stage_id uuid)
RETURNS TABLE (
  id uuid,
  stage_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.stage_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_procurement_progress_log_r2083 l
  WHERE l.stage_id = p_stage_id
  ORDER BY l.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_progress
CREATE OR REPLACE FUNCTION public.log_procurement_progress_r2083(
  p_stage_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_procurement_progress_log_r2083(stage_id, action_type, by_email, notes_md)
  VALUES (p_stage_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_procurement_progress_r2083', jsonb_build_object('log_id', v_id, 'stage_id', p_stage_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_procurement_status_r2083(
  p_stage_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_procurement_process_stages_r2083
  SET status = p_status, updated_at = now()
  WHERE id = p_stage_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_procurement_status_r2083', jsonb_build_object('stage_id', p_stage_id, 'status', p_status));
END;
$$;

-- RPC 6: stalled_processes
CREATE OR REPLACE FUNCTION public.stalled_procurement_processes_r2083()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  current_stage text,
  stage_entered_at timestamptz,
  expected_completion_date date,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, p.email, s.current_stage, s.stage_entered_at, s.expected_completion_date, s.status
  FROM public.hospital_procurement_process_stages_r2083 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  WHERE s.status IN ('stalled','escalated')
  ORDER BY s.stage_entered_at ASC
  LIMIT 200;
END;
$$;

-- RPC 7: recent_progress
CREATE OR REPLACE FUNCTION public.recent_procurement_progress_r2083()
RETURNS TABLE (
  id uuid,
  stage_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.stage_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_procurement_progress_log_r2083 l
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_procurement_processes_r2083() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_procurement_process_r2083(uuid, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_procurement_progress_r2083(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_procurement_progress_r2083(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_procurement_status_r2083(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stalled_procurement_processes_r2083() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_procurement_progress_r2083() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_procurement_processes_r2083() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_procurement_process_r2083(uuid, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_procurement_progress_r2083(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_procurement_progress_r2083(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_procurement_status_r2083(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stalled_procurement_processes_r2083() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_procurement_progress_r2083() TO authenticated;

COMMIT;
