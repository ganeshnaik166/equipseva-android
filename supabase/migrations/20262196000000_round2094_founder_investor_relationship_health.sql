BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_investor_relationship_health_r2094 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id_label text NOT NULL,
  relationship_score int NOT NULL CHECK (relationship_score >= 0 AND relationship_score <= 100),
  last_signal_md text,
  signal_type text NOT NULL CHECK (signal_type IN ('positive','neutral','concern','critical')),
  status text NOT NULL DEFAULT 'healthy' CHECK (status IN ('thriving','healthy','at_risk','critical','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_relationship_action_log_r2094 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  health_id uuid NOT NULL REFERENCES public.founder_investor_relationship_health_r2094(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signal_received','engagement','escalation','win_back','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_investor_relationship_health_r2094 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_relationship_action_log_r2094 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_health_founder_r2094 ON public.founder_investor_relationship_health_r2094;
CREATE POLICY p_health_founder_r2094 ON public.founder_investor_relationship_health_r2094
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_action_founder_r2094 ON public.founder_relationship_action_log_r2094;
CREATE POLICY p_action_founder_r2094 ON public.founder_relationship_action_log_r2094
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_healths_r2094()
RETURNS SETOF public.founder_investor_relationship_health_r2094
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_investor_relationship_health_r2094 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_health_r2094(
  p_investor_id_label text,
  p_relationship_score int,
  p_signal_type text,
  p_last_signal_md text DEFAULT NULL,
  p_status text DEFAULT 'healthy'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_investor_relationship_health_r2094(investor_id_label, relationship_score, signal_type, last_signal_md, status)
  VALUES (p_investor_id_label, p_relationship_score, p_signal_type, p_last_signal_md, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_health_r2094',
          jsonb_build_object('id', v_id, 'investor', p_investor_id_label, 'score', p_relationship_score, 'signal', p_signal_type, 'status', p_status),
          now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2094(p_health_id uuid)
RETURNS SETOF public.founder_relationship_action_log_r2094
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_relationship_action_log_r2094 WHERE health_id = p_health_id ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2094(
  p_health_id uuid,
  p_action_type text,
  p_by_email text DEFAULT NULL,
  p_notes_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_relationship_action_log_r2094(health_id, action_type, by_email, notes_md)
  VALUES (p_health_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2094',
          jsonb_build_object('id', v_id, 'health_id', p_health_id, 'action_type', p_action_type),
          now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2094(p_health_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_investor_relationship_health_r2094
     SET status = p_status, updated_at = now()
   WHERE id = p_health_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2094',
          jsonb_build_object('id', p_health_id, 'status', p_status),
          now());
END;
$$;

CREATE OR REPLACE FUNCTION public.at_risk_r2094()
RETURNS SETOF public.founder_investor_relationship_health_r2094
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_investor_relationship_health_r2094
    WHERE status IN ('at_risk','critical','lost') OR relationship_score < 50
    ORDER BY relationship_score ASC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2094()
RETURNS SETOF public.founder_relationship_action_log_r2094
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_relationship_action_log_r2094 ORDER BY taken_at DESC LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_healths_r2094() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_health_r2094(text,int,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2094(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2094(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2094(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_r2094() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2094() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_healths_r2094() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_health_r2094(text,int,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2094(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2094(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2094(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_r2094() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2094() TO authenticated;

COMMIT;
