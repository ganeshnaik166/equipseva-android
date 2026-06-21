BEGIN;

-- =========================================================================
-- Round 1867 — Hospital Emergency Response Playbook
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_emergency_response_playbooks_r1867 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  playbook_label text NOT NULL,
  scenario_text text,
  primary_contact_email text,
  escalation_chain text[] NOT NULL DEFAULT ARRAY[]::text[],
  response_minutes int NOT NULL DEFAULT 30,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','archived')),
  last_drilled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_herp_r1867_hospital ON public.hospital_emergency_response_playbooks_r1867(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_herp_r1867_status ON public.hospital_emergency_response_playbooks_r1867(status);
CREATE INDEX IF NOT EXISTS idx_herp_r1867_last_drilled ON public.hospital_emergency_response_playbooks_r1867(last_drilled_at);

ALTER TABLE public.hospital_emergency_response_playbooks_r1867 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_herp_r1867 ON public.hospital_emergency_response_playbooks_r1867;
CREATE POLICY p_founder_all_herp_r1867
  ON public.hospital_emergency_response_playbooks_r1867
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_emergency_response_drills_r1867 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playbook_id uuid NOT NULL REFERENCES public.hospital_emergency_response_playbooks_r1867(id) ON DELETE CASCADE,
  drilled_at timestamptz NOT NULL DEFAULT now(),
  drilled_by_email text,
  scenario_run text,
  response_time_actual_min int,
  gaps_md text,
  status text NOT NULL DEFAULT 'passed' CHECK (status IN ('passed','needs_improvement','failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_herd_r1867_playbook ON public.hospital_emergency_response_drills_r1867(playbook_id);
CREATE INDEX IF NOT EXISTS idx_herd_r1867_status ON public.hospital_emergency_response_drills_r1867(status);
CREATE INDEX IF NOT EXISTS idx_herd_r1867_drilled_at ON public.hospital_emergency_response_drills_r1867(drilled_at);

ALTER TABLE public.hospital_emergency_response_drills_r1867 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_herd_r1867 ON public.hospital_emergency_response_drills_r1867;
CREATE POLICY p_founder_all_herd_r1867
  ON public.hospital_emergency_response_drills_r1867
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_playbooks
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_list_playbooks(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  playbook_label text,
  scenario_text text,
  primary_contact_email text,
  escalation_chain text[],
  response_minutes int,
  status text,
  last_drilled_at timestamptz,
  drill_count int,
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
    pb.id,
    pb.hospital_user_id,
    pr.email AS hospital_email,
    pb.playbook_label,
    pb.scenario_text,
    pb.primary_contact_email,
    pb.escalation_chain,
    pb.response_minutes,
    pb.status,
    pb.last_drilled_at,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867 d WHERE d.playbook_id = pb.id)::int AS drill_count,
    pb.created_at
  FROM public.hospital_emergency_response_playbooks_r1867 pb
  LEFT JOIN public.profiles pr ON pr.id = pb.hospital_user_id
  WHERE p_status IS NULL OR pb.status = p_status
  ORDER BY pb.updated_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_list_playbooks(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_list_playbooks(text) TO authenticated;

-- =========================================================================
-- RPC 2: set_playbook
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_set_playbook(
  p_hospital_user_id uuid,
  p_playbook_label text,
  p_scenario_text text,
  p_primary_contact_email text,
  p_escalation_chain text[],
  p_response_minutes int,
  p_status text DEFAULT 'active'
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

  INSERT INTO public.hospital_emergency_response_playbooks_r1867(
    hospital_user_id, playbook_label, scenario_text, primary_contact_email,
    escalation_chain, response_minutes, status
  )
  VALUES (
    p_hospital_user_id, p_playbook_label, p_scenario_text, p_primary_contact_email,
    COALESCE(p_escalation_chain, ARRAY[]::text[]),
    COALESCE(p_response_minutes, 30),
    COALESCE(p_status, 'active')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1867_set_playbook',
    jsonb_build_object(
      'id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'playbook_label', p_playbook_label,
      'response_minutes', p_response_minutes,
      'status', p_status
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_set_playbook(uuid, text, text, text, text[], int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_set_playbook(uuid, text, text, text, text[], int, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_drills
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_list_drills(p_playbook_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  playbook_id uuid,
  playbook_label text,
  hospital_email text,
  drilled_at timestamptz,
  drilled_by_email text,
  scenario_run text,
  response_time_actual_min int,
  target_response_minutes int,
  gaps_md text,
  status text
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
    d.id,
    d.playbook_id,
    pb.playbook_label,
    pr.email AS hospital_email,
    d.drilled_at,
    d.drilled_by_email,
    d.scenario_run,
    d.response_time_actual_min,
    pb.response_minutes AS target_response_minutes,
    d.gaps_md,
    d.status
  FROM public.hospital_emergency_response_drills_r1867 d
  JOIN public.hospital_emergency_response_playbooks_r1867 pb ON pb.id = d.playbook_id
  LEFT JOIN public.profiles pr ON pr.id = pb.hospital_user_id
  WHERE p_playbook_id IS NULL OR d.playbook_id = p_playbook_id
  ORDER BY d.drilled_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_list_drills(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_list_drills(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_drill
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_log_drill(
  p_playbook_id uuid,
  p_drilled_by_email text,
  p_scenario_run text,
  p_response_time_actual_min int,
  p_gaps_md text,
  p_status text DEFAULT 'passed'
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

  IF p_status NOT IN ('passed','needs_improvement','failed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  INSERT INTO public.hospital_emergency_response_drills_r1867(
    playbook_id, drilled_by_email, scenario_run, response_time_actual_min, gaps_md, status
  )
  VALUES (
    p_playbook_id, p_drilled_by_email, p_scenario_run,
    p_response_time_actual_min, p_gaps_md, COALESCE(p_status, 'passed')
  )
  RETURNING id INTO v_id;

  UPDATE public.hospital_emergency_response_playbooks_r1867
  SET last_drilled_at = now(),
      updated_at = now()
  WHERE id = p_playbook_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1867_log_drill',
    jsonb_build_object(
      'id', v_id,
      'playbook_id', p_playbook_id,
      'response_time_actual_min', p_response_time_actual_min,
      'status', p_status
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_log_drill(uuid, text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_log_drill(uuid, text, text, int, text, text) TO authenticated;

-- =========================================================================
-- RPC 5: mark_response_time
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_mark_response_time(
  p_playbook_id uuid,
  p_response_minutes int
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

  IF p_response_minutes IS NULL OR p_response_minutes < 0 THEN
    RAISE EXCEPTION 'invalid_minutes';
  END IF;

  UPDATE public.hospital_emergency_response_playbooks_r1867
  SET response_minutes = p_response_minutes,
      updated_at = now()
  WHERE id = p_playbook_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1867_mark_response_time',
    jsonb_build_object(
      'playbook_id', p_playbook_id,
      'response_minutes', p_response_minutes
    ));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_mark_response_time(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_mark_response_time(uuid, int) TO authenticated;

-- =========================================================================
-- RPC 6: drill_pass_rate
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_drill_pass_rate()
RETURNS TABLE (
  total_drills int,
  passed_count int,
  needs_improvement_count int,
  failed_count int,
  pass_rate_pct numeric,
  avg_response_time_min numeric,
  total_playbooks int,
  active_playbooks int,
  under_review_playbooks int,
  archived_playbooks int
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
    (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867)::int AS total_drills,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867 WHERE status = 'passed')::int AS passed_count,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867 WHERE status = 'needs_improvement')::int AS needs_improvement_count,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867 WHERE status = 'failed')::int AS failed_count,
    CASE
      WHEN (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867) = 0 THEN 0::numeric
      ELSE ROUND(
        100.0 * (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867 WHERE status = 'passed')::numeric
              / (SELECT COUNT(*) FROM public.hospital_emergency_response_drills_r1867)::numeric,
        2)
    END AS pass_rate_pct,
    COALESCE(
      (SELECT ROUND(AVG(response_time_actual_min)::numeric, 2)
       FROM public.hospital_emergency_response_drills_r1867
       WHERE response_time_actual_min IS NOT NULL),
      0::numeric
    ) AS avg_response_time_min,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_playbooks_r1867)::int AS total_playbooks,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_playbooks_r1867 WHERE status = 'active')::int AS active_playbooks,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_playbooks_r1867 WHERE status = 'under_review')::int AS under_review_playbooks,
    (SELECT COUNT(*) FROM public.hospital_emergency_response_playbooks_r1867 WHERE status = 'archived')::int AS archived_playbooks;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_drill_pass_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_drill_pass_rate() TO authenticated;

-- =========================================================================
-- RPC 7: stale_playbooks
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r1867_stale_playbooks(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  playbook_label text,
  status text,
  response_minutes int,
  last_drilled_at timestamptz,
  days_since_drill int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_threshold := COALESCE(p_days, 90);

  RETURN QUERY
  SELECT
    pb.id,
    pb.hospital_user_id,
    pr.email AS hospital_email,
    pb.playbook_label,
    pb.status,
    pb.response_minutes,
    pb.last_drilled_at,
    CASE
      WHEN pb.last_drilled_at IS NULL THEN NULL
      ELSE EXTRACT(DAY FROM (now() - pb.last_drilled_at))::int
    END AS days_since_drill,
    pb.created_at
  FROM public.hospital_emergency_response_playbooks_r1867 pb
  LEFT JOIN public.profiles pr ON pr.id = pb.hospital_user_id
  WHERE pb.status <> 'archived'
    AND (
      pb.last_drilled_at IS NULL
      OR pb.last_drilled_at < (now() - (v_threshold || ' days')::interval)
    )
  ORDER BY pb.last_drilled_at ASC NULLS FIRST, pb.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1867_stale_playbooks(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1867_stale_playbooks(int) TO authenticated;

COMMIT;