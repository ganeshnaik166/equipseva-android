BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_lifetime_value_tracker_r2140 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  total_revenue_attributed_rupees bigint NOT NULL DEFAULT 0,
  total_jobs_completed int NOT NULL DEFAULT 0,
  retention_months int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('rising','stable','declining','exceptional')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_ltv_action_log_r2140 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ltv_id uuid NOT NULL REFERENCES public.engineer_lifetime_value_tracker_r2140(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','coached','escalated','retention_intervention','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_lifetime_value_tracker_r2140 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_ltv_action_log_r2140 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ltv_r2140 ON public.engineer_lifetime_value_tracker_r2140;
CREATE POLICY founder_all_ltv_r2140 ON public.engineer_lifetime_value_tracker_r2140
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ltv_action_r2140 ON public.engineer_ltv_action_log_r2140;
CREATE POLICY founder_all_ltv_action_r2140 ON public.engineer_ltv_action_log_r2140
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_ltvs_r2140()
RETURNS SETOF public.engineer_lifetime_value_tracker_r2140
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_lifetime_value_tracker_r2140 ORDER BY captured_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_ltv_r2140(
  p_engineer_user_id uuid,
  p_period_label text,
  p_total_revenue_attributed_rupees bigint,
  p_total_jobs_completed int,
  p_retention_months int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_lifetime_value_tracker_r2140(engineer_user_id, period_label, total_revenue_attributed_rupees, total_jobs_completed, retention_months, status)
  VALUES (p_engineer_user_id, p_period_label, p_total_revenue_attributed_rupees, p_total_jobs_completed, p_retention_months, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_ltv_r2140', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_ltv_actions_r2140(p_ltv_id uuid)
RETURNS SETOF public.engineer_ltv_action_log_r2140
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_ltv_action_log_r2140 WHERE ltv_id = p_ltv_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_ltv_action_r2140(
  p_ltv_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_ltv_action_log_r2140(ltv_id, action_type, by_email, notes_md)
  VALUES (p_ltv_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_ltv_action_r2140', jsonb_build_object('id', v_id, 'ltv_id', p_ltv_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_ltv_status_r2140(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_lifetime_value_tracker_r2140 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_ltv_status_r2140', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_ltv_r2140()
RETURNS SETOF public.engineer_lifetime_value_tracker_r2140
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_lifetime_value_tracker_r2140 ORDER BY total_revenue_attributed_rupees DESC LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_ltv_actions_r2140()
RETURNS SETOF public.engineer_ltv_action_log_r2140
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_ltv_action_log_r2140 ORDER BY taken_at DESC LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_ltvs_r2140() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_ltv_r2140(uuid, text, bigint, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_ltv_actions_r2140(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_ltv_action_r2140(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_ltv_status_r2140(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_ltv_r2140() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_ltv_actions_r2140() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_ltvs_r2140() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_ltv_r2140(uuid, text, bigint, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_ltv_actions_r2140(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_ltv_action_r2140(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_ltv_status_r2140(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_ltv_r2140() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_ltv_actions_r2140() TO authenticated;

COMMIT;
