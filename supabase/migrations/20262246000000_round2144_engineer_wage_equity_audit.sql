BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_wage_equity_audit_r2144 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  region_label text NOT NULL,
  tier_label text NOT NULL,
  avg_wage_rupees bigint NOT NULL DEFAULT 0,
  gender_wage_gap_pct numeric NOT NULL DEFAULT 0,
  tenure_wage_gap_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('equitable','concerning','critical','excellent')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_wage_action_log_r2144 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.engineer_wage_equity_audit_r2144(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('adjusted','escalated','closed','audited')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_wage_equity_audit_r2144 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_wage_action_log_r2144 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_wage_audit_r2144 ON public.engineer_wage_equity_audit_r2144;
CREATE POLICY founder_all_wage_audit_r2144 ON public.engineer_wage_equity_audit_r2144
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_wage_action_r2144 ON public.engineer_wage_action_log_r2144;
CREATE POLICY founder_all_wage_action_r2144 ON public.engineer_wage_action_log_r2144
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_audits_r2144()
RETURNS SETOF public.engineer_wage_equity_audit_r2144
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_wage_equity_audit_r2144 ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_audit_r2144(
  p_period_label text,
  p_region_label text,
  p_tier_label text,
  p_avg_wage_rupees bigint,
  p_gender_wage_gap_pct numeric,
  p_tenure_wage_gap_pct numeric,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_wage_equity_audit_r2144(period_label, region_label, tier_label, avg_wage_rupees, gender_wage_gap_pct, tenure_wage_gap_pct, status)
  VALUES (p_period_label, p_region_label, p_tier_label, p_avg_wage_rupees, p_gender_wage_gap_pct, p_tenure_wage_gap_pct, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_audit_r2144', jsonb_build_object('id', v_id, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2144(p_audit_id uuid)
RETURNS SETOF public.engineer_wage_action_log_r2144
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_wage_action_log_r2144 WHERE audit_id = p_audit_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2144(
  p_audit_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_wage_action_log_r2144(audit_id, action_type, by_email, notes_md)
  VALUES (p_audit_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2144', jsonb_build_object('id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2144(p_audit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_wage_equity_audit_r2144 SET status = p_status, updated_at = now() WHERE id = p_audit_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2144', jsonb_build_object('id', p_audit_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.concerning_gaps_r2144()
RETURNS SETOF public.engineer_wage_equity_audit_r2144
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_wage_equity_audit_r2144
    WHERE status IN ('concerning','critical')
    ORDER BY captured_at DESC LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2144()
RETURNS SETOF public.engineer_wage_action_log_r2144
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_wage_action_log_r2144 ORDER BY taken_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_audits_r2144() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r2144(text, text, text, bigint, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2144(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2144(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2144(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.concerning_gaps_r2144() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2144() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r2144() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r2144(text, text, text, bigint, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2144(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2144(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2144(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.concerning_gaps_r2144() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2144() TO authenticated;

COMMIT;
