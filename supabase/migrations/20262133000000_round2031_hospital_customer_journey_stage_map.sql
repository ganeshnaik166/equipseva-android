BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_journey_stages_r2031 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  journey_stage text NOT NULL CHECK (journey_stage IN ('awareness','consideration','trial','active_user','expansion','at_risk','churned')),
  stage_entered_at timestamptz NOT NULL DEFAULT now(),
  time_in_stage_days int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('progressing','stalled','regressed','exited')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_journey_action_log_r2031 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id uuid NOT NULL REFERENCES public.hospital_customer_journey_stages_r2031(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('nurture_call','training_offered','upsell_attempt','retention_call','win_back','exit_interview')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_journey_stages_r2031 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_journey_action_log_r2031 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stages_r2031 ON public.hospital_customer_journey_stages_r2031;
CREATE POLICY founder_all_stages_r2031 ON public.hospital_customer_journey_stages_r2031
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2031 ON public.hospital_journey_action_log_r2031;
CREATE POLICY founder_all_actions_r2031 ON public.hospital_journey_action_log_r2031
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_journey_stages_r2031()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  journey_stage text,
  stage_entered_at timestamptz,
  time_in_stage_days int,
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
    SELECT s.id, s.hospital_id, o.name AS hospital_name, s.journey_stage,
           s.stage_entered_at, s.time_in_stage_days, s.status, s.captured_at
      FROM public.hospital_customer_journey_stages_r2031 s
      LEFT JOIN public.profiles p ON p.id = s.hospital_id
      LEFT JOIN public.organizations o ON o.id = p.organization_id
     ORDER BY s.captured_at DESC
     LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_journey_stage_r2031(
  p_hospital_id uuid,
  p_journey_stage text,
  p_time_in_stage_days int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_journey_stages_r2031(
    hospital_id, journey_stage, time_in_stage_days, status
  ) VALUES (p_hospital_id, p_journey_stage, COALESCE(p_time_in_stage_days,0), p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_journey_stage_r2031',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'stage', p_journey_stage, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_journey_actions_r2031()
RETURNS TABLE (
  id uuid,
  stage_id uuid,
  hospital_name text,
  journey_stage text,
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
    SELECT a.id, a.stage_id, o.name AS hospital_name, s.journey_stage,
           a.action_type, a.taken_at, a.by_email, a.notes_md
      FROM public.hospital_journey_action_log_r2031 a
      JOIN public.hospital_customer_journey_stages_r2031 s ON s.id = a.stage_id
      LEFT JOIN public.profiles p ON p.id = s.hospital_id
      LEFT JOIN public.organizations o ON o.id = p.organization_id
     ORDER BY a.taken_at DESC
     LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_journey_action_r2031(
  p_stage_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_journey_action_log_r2031(
    stage_id, action_type, by_email, notes_md
  ) VALUES (p_stage_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_journey_action_r2031',
          jsonb_build_object('id', v_id, 'stage_id', p_stage_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_journey_status_r2031(
  p_stage_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_journey_stages_r2031
     SET status = p_status, updated_at = now()
   WHERE id = p_stage_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_journey_status_r2031',
          jsonb_build_object('stage_id', p_stage_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.stalled_journeys_r2031()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  journey_stage text,
  time_in_stage_days int,
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
    SELECT s.id, o.name AS hospital_name, s.journey_stage,
           s.time_in_stage_days, s.status, s.captured_at
      FROM public.hospital_customer_journey_stages_r2031 s
      LEFT JOIN public.profiles p ON p.id = s.hospital_id
      LEFT JOIN public.organizations o ON o.id = p.organization_id
     WHERE s.status IN ('stalled','regressed')
     ORDER BY s.time_in_stage_days DESC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_journey_actions_r2031()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  journey_stage text,
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
    SELECT a.id, o.name AS hospital_name, s.journey_stage,
           a.action_type, a.taken_at, a.by_email
      FROM public.hospital_journey_action_log_r2031 a
      JOIN public.hospital_customer_journey_stages_r2031 s ON s.id = a.stage_id
      LEFT JOIN public.profiles p ON p.id = s.hospital_id
      LEFT JOIN public.organizations o ON o.id = p.organization_id
     WHERE a.taken_at >= now() - interval '30 days'
     ORDER BY a.taken_at DESC
     LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_journey_stages_r2031() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_journey_stage_r2031(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_journey_actions_r2031() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_journey_action_r2031(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_journey_status_r2031(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stalled_journeys_r2031() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_journey_actions_r2031() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_journey_stages_r2031() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_journey_stage_r2031(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_journey_actions_r2031() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_journey_action_r2031(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_journey_status_r2031(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stalled_journeys_r2031() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_journey_actions_r2031() TO authenticated;

COMMIT;
