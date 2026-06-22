BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_retention_score_r2040 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  retained_customers_count int NOT NULL DEFAULT 0,
  lost_customers_count int NOT NULL DEFAULT 0,
  retention_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('high_retention','normal','declining','at_risk')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_retention_action_log_r2040 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retention_id uuid NOT NULL REFERENCES public.engineer_customer_retention_score_r2040(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','recognition','escalation','retraining','bonus')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_retention_score_r2040 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_retention_action_log_r2040 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_retention_r2040 ON public.engineer_customer_retention_score_r2040;
CREATE POLICY founder_all_retention_r2040 ON public.engineer_customer_retention_score_r2040
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_retention_actions_r2040 ON public.engineer_retention_action_log_r2040;
CREATE POLICY founder_all_retention_actions_r2040 ON public.engineer_retention_action_log_r2040
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_retentions_r2040()
RETURNS SETOF public.engineer_customer_retention_score_r2040
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_customer_retention_score_r2040 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_retention_r2040(
  p_engineer_user_id uuid,
  p_period_label text,
  p_retained int,
  p_lost int,
  p_status text DEFAULT 'normal'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_pct numeric(6,2);
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_total := COALESCE(p_retained,0) + COALESCE(p_lost,0);
  IF v_total = 0 THEN
    v_pct := 0;
  ELSE
    v_pct := ROUND( (COALESCE(p_retained,0)::numeric / v_total::numeric) * 100, 2);
  END IF;
  INSERT INTO public.engineer_customer_retention_score_r2040(engineer_user_id, period_label, retained_customers_count, lost_customers_count, retention_pct, status)
  VALUES (p_engineer_user_id, p_period_label, COALESCE(p_retained,0), COALESCE(p_lost,0), v_pct, COALESCE(p_status,'normal'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_retention_r2040', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'period_label', p_period_label, 'retention_pct', v_pct));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2040(p_retention_id uuid)
RETURNS SETOF public.engineer_retention_action_log_r2040
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_retention_action_log_r2040 WHERE retention_id = p_retention_id ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2040(
  p_retention_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_retention_action_log_r2040(retention_id, action_type, by_email, notes_md)
  VALUES (p_retention_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2040', jsonb_build_object('id', v_id, 'retention_id', p_retention_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2040(
  p_retention_id uuid,
  p_status text
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
  UPDATE public.engineer_customer_retention_score_r2040
     SET status = p_status, updated_at = now()
   WHERE id = p_retention_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2040', jsonb_build_object('id', p_retention_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.at_risk_r2040()
RETURNS SETOF public.engineer_customer_retention_score_r2040
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_customer_retention_score_r2040 WHERE status IN ('declining','at_risk') ORDER BY retention_pct ASC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2040()
RETURNS SETOF public.engineer_retention_action_log_r2040
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.engineer_retention_action_log_r2040 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_retentions_r2040() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_retention_r2040(uuid, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2040(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2040(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2040(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_r2040() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2040() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_retentions_r2040() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_retention_r2040(uuid, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2040(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2040(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2040(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_r2040() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2040() TO authenticated;

COMMIT;
