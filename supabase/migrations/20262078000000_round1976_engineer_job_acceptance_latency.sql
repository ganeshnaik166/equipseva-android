BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_job_acceptance_latency_r1976 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id),
  repair_job_id uuid,
  offered_at timestamptz,
  accepted_at timestamptz,
  latency_minutes int,
  status text CHECK (status IN ('pending','accepted','declined','timed_out','withdrawn')),
  response_type text CHECK (response_type IN ('immediate','quick','delayed','very_delayed','no_response')),
  captured_at timestamptz DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_acceptance_action_log_r1976 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  latency_id uuid REFERENCES public.engineer_job_acceptance_latency_r1976(id) ON DELETE CASCADE,
  action_type text CHECK (action_type IN ('assigned','accepted','declined','reminder_sent','escalated')),
  taken_at timestamptz DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_job_acceptance_latency_r1976 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_acceptance_action_log_r1976 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_latency_r1976 ON public.engineer_job_acceptance_latency_r1976;
CREATE POLICY founder_all_latency_r1976 ON public.engineer_job_acceptance_latency_r1976
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1976 ON public.engineer_acceptance_action_log_r1976;
CREATE POLICY founder_all_actions_r1976 ON public.engineer_acceptance_action_log_r1976
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_latencies_r1976()
RETURNS TABLE (id uuid, engineer_user_id uuid, repair_job_id uuid, offered_at timestamptz, accepted_at timestamptz, latency_minutes int, status text, response_type text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.engineer_user_id, l.repair_job_id, l.offered_at, l.accepted_at, l.latency_minutes, l.status, l.response_type, l.captured_at
    FROM public.engineer_job_acceptance_latency_r1976 l
    ORDER BY l.captured_at DESC NULLS LAST LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_latency_r1976(p_engineer uuid, p_job uuid, p_offered timestamptz, p_accepted timestamptz, p_latency int, p_status text, p_response_type text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_job_acceptance_latency_r1976(engineer_user_id, repair_job_id, offered_at, accepted_at, latency_minutes, status, response_type)
    VALUES (p_engineer, p_job, p_offered, p_accepted, p_latency, p_status, p_response_type) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_latency_r1976', jsonb_build_object('id', v_id, 'engineer', p_engineer, 'latency_minutes', p_latency));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1976(p_latency uuid)
RETURNS TABLE (id uuid, latency_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.latency_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_acceptance_action_log_r1976 a WHERE a.latency_id = p_latency
    ORDER BY a.taken_at DESC NULLS LAST LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r1976(p_latency uuid, p_action_type text, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_acceptance_action_log_r1976(latency_id, action_type, by_email, notes_md)
    VALUES (p_latency, p_action_type, v_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_action_r1976', jsonb_build_object('id', v_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1976(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_job_acceptance_latency_r1976 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1976', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.slow_engineers_r1976()
RETURNS TABLE (engineer_user_id uuid, avg_latency numeric, total_offers bigint, slow_offers bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.engineer_user_id, AVG(l.latency_minutes)::numeric, COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE l.response_type IN ('delayed','very_delayed','no_response'))::bigint
    FROM public.engineer_job_acceptance_latency_r1976 l
    WHERE l.engineer_user_id IS NOT NULL
    GROUP BY l.engineer_user_id ORDER BY AVG(l.latency_minutes) DESC NULLS LAST LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1976()
RETURNS TABLE (id uuid, latency_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.latency_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_acceptance_action_log_r1976 a
    ORDER BY a.taken_at DESC NULLS LAST LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_latencies_r1976() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_latency_r1976(uuid, uuid, timestamptz, timestamptz, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1976(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1976(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1976(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.slow_engineers_r1976() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1976() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_latencies_r1976() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_latency_r1976(uuid, uuid, timestamptz, timestamptz, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1976(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1976(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1976(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.slow_engineers_r1976() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1976() TO authenticated;

COMMIT;
