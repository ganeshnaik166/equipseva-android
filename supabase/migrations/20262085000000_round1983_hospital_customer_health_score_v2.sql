BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_health_v2_r1983 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  health_score int NOT NULL CHECK (health_score BETWEEN 0 AND 100),
  factors_md text,
  status text NOT NULL CHECK (status IN ('excellent','good','fair','poor','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hch_v2_r1983_hospital_idx ON public.hospital_customer_health_v2_r1983(hospital_id);
CREATE INDEX IF NOT EXISTS hch_v2_r1983_status_idx ON public.hospital_customer_health_v2_r1983(status);
CREATE INDEX IF NOT EXISTS hch_v2_r1983_captured_idx ON public.hospital_customer_health_v2_r1983(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_health_score_action_log_r1983 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  health_id uuid NOT NULL REFERENCES public.hospital_customer_health_v2_r1983(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('escalation_call','customer_review','save_offer','upsell_offer','account_recovery')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hhsal_r1983_health_idx ON public.hospital_health_score_action_log_r1983(health_id);
CREATE INDEX IF NOT EXISTS hhsal_r1983_taken_idx ON public.hospital_health_score_action_log_r1983(taken_at DESC);

ALTER TABLE public.hospital_customer_health_v2_r1983 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_health_score_action_log_r1983 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hch_v2_r1983_founder_all ON public.hospital_customer_health_v2_r1983;
CREATE POLICY hch_v2_r1983_founder_all ON public.hospital_customer_health_v2_r1983
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hhsal_r1983_founder_all ON public.hospital_health_score_action_log_r1983;
CREATE POLICY hhsal_r1983_founder_all ON public.hospital_health_score_action_log_r1983
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_healths_r1983()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, health_score int, factors_md text, status text, captured_at timestamptz, last_reviewed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.hospital_id, COALESCE(o.name, p.full_name, p.email) AS hospital_name,
           h.health_score, h.factors_md, h.status, h.captured_at, h.last_reviewed_at
    FROM public.hospital_customer_health_v2_r1983 h
    LEFT JOIN public.profiles p ON p.id = h.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY h.captured_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_health_r1983(
  p_hospital_id uuid,
  p_health_score int,
  p_factors_md text,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_health_v2_r1983(hospital_id, health_score, factors_md, status)
    VALUES (p_hospital_id, p_health_score, p_factors_md, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_health_r1983',
            jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'score', p_health_score, 'status', p_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1983(p_health_id uuid)
RETURNS TABLE(id uuid, health_id uuid, action_type text, taken_at timestamptz, by_email text, outcome_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.health_id, a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_health_score_action_log_r1983 a
    WHERE a.health_id = p_health_id
    ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r1983(
  p_health_id uuid,
  p_action_type text,
  p_outcome_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_health_score_action_log_r1983(health_id, action_type, by_email, outcome_md)
    VALUES (p_health_id, p_action_type, v_email, p_outcome_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_action_r1983',
            jsonb_build_object('id', v_id, 'health_id', p_health_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1983(
  p_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_health_v2_r1983
    SET status = p_status, last_reviewed_at = now(), updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1983',
            jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.critical_accounts_r1983()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, health_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.hospital_id, COALESCE(o.name, p.full_name, p.email) AS hospital_name,
           h.health_score, h.status, h.captured_at
    FROM public.hospital_customer_health_v2_r1983 h
    LEFT JOIN public.profiles p ON p.id = h.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE h.status IN ('critical','poor')
    ORDER BY h.health_score ASC, h.captured_at DESC
    LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1983()
RETURNS TABLE(id uuid, health_id uuid, hospital_name text, action_type text, taken_at timestamptz, by_email text, outcome_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.health_id, COALESCE(o.name, p.full_name, p.email) AS hospital_name,
           a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_health_score_action_log_r1983 a
    JOIN public.hospital_customer_health_v2_r1983 h ON h.id = a.health_id
    LEFT JOIN public.profiles p ON p.id = h.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_healths_r1983() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_health_r1983(uuid, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1983(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1983(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1983(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_accounts_r1983() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1983() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_healths_r1983() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_health_r1983(uuid, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1983(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1983(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1983(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_accounts_r1983() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1983() TO authenticated;

COMMIT;
