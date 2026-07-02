BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_trust_score_r2072 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  trust_score int NOT NULL DEFAULT 50 CHECK (trust_score >= 0 AND trust_score <= 100),
  total_interactions int NOT NULL DEFAULT 0,
  positive_interactions int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('excellent','strong','normal','concerning','at_risk')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_trust_action_log_r2072 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trust_id uuid NOT NULL REFERENCES public.engineer_customer_trust_score_r2072(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','coached','escalated','recovered','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_trust_score_r2072 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_trust_action_log_r2072 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_trust_r2072 ON public.engineer_customer_trust_score_r2072;
CREATE POLICY founder_all_trust_r2072 ON public.engineer_customer_trust_score_r2072
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2072 ON public.engineer_trust_action_log_r2072;
CREATE POLICY founder_all_action_r2072 ON public.engineer_trust_action_log_r2072
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_trusts_r2072()
RETURNS TABLE (id uuid, engineer_user_id uuid, hospital_id uuid, trust_score int, total_interactions int, positive_interactions int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.hospital_id, t.trust_score, t.total_interactions, t.positive_interactions, t.status, t.captured_at
    FROM public.engineer_customer_trust_score_r2072 t ORDER BY t.captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_trust_r2072(p_engineer uuid, p_hospital uuid, p_score int, p_total int, p_positive int, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_trust_score_r2072(engineer_user_id, hospital_id, trust_score, total_interactions, positive_interactions, status)
    VALUES (p_engineer, p_hospital, p_score, p_total, p_positive, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trust_r2072', jsonb_build_object('id', v_id, 'score', p_score));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2072(p_trust uuid)
RETURNS TABLE (id uuid, trust_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.trust_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_trust_action_log_r2072 a WHERE a.trust_id = p_trust ORDER BY a.taken_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2072(p_trust uuid, p_action text, p_email text, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_trust_action_log_r2072(trust_id, action_type, by_email, notes_md)
    VALUES (p_trust, p_action, p_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2072', jsonb_build_object('id', v_id, 'action', p_action));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2072(p_trust uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_trust_score_r2072 SET status = p_status, updated_at = now() WHERE id = p_trust;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2072', jsonb_build_object('id', p_trust, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.at_risk_r2072()
RETURNS TABLE (id uuid, engineer_user_id uuid, hospital_id uuid, trust_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.engineer_user_id, t.hospital_id, t.trust_score, t.status, t.captured_at
    FROM public.engineer_customer_trust_score_r2072 t WHERE t.status IN ('concerning','at_risk') ORDER BY t.trust_score ASC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2072()
RETURNS TABLE (id uuid, trust_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.trust_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_trust_action_log_r2072 a ORDER BY a.taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_trusts_r2072() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_trust_r2072(uuid, uuid, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2072(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2072(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2072(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_r2072() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2072() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_trusts_r2072() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_trust_r2072(uuid, uuid, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2072(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2072(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2072(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_r2072() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2072() TO authenticated;

COMMIT;
