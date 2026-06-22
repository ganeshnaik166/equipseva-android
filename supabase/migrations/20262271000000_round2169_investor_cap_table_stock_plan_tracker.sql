BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_stock_plan_tracker_r2169 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_label text NOT NULL,
  total_authorized_shares bigint NOT NULL DEFAULT 0,
  total_issued_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exhausted','superseded','amended')),
  last_amended_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_stock_plan_action_log_r2169 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.investor_cap_table_stock_plan_tracker_r2169(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('created','amended','exhausted','superseded','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_change bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_stock_plan_tracker_r2169 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_stock_plan_action_log_r2169 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_plan_tracker_r2169 ON public.investor_cap_table_stock_plan_tracker_r2169;
CREATE POLICY founder_all_plan_tracker_r2169 ON public.investor_cap_table_stock_plan_tracker_r2169
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_plan_action_log_r2169 ON public.investor_stock_plan_action_log_r2169;
CREATE POLICY founder_all_plan_action_log_r2169 ON public.investor_stock_plan_action_log_r2169
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_plans_r2169()
RETURNS SETOF public.investor_cap_table_stock_plan_tracker_r2169
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_stock_plan_tracker_r2169 ORDER BY captured_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_plans_r2169() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_plans_r2169() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_plan_r2169(p_label text, p_authorized bigint, p_issued bigint, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_stock_plan_tracker_r2169(plan_label, total_authorized_shares, total_issued_shares, status)
  VALUES (p_label, p_authorized, p_issued, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_plan_r2169', jsonb_build_object('id', v_id, 'label', p_label), now());
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION public.log_plan_r2169(text, bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_plan_r2169(text, bigint, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2169(p_plan_id uuid)
RETURNS SETOF public.investor_stock_plan_action_log_r2169
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_stock_plan_action_log_r2169 WHERE plan_id = p_plan_id ORDER BY taken_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2169(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2169(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2169(p_plan_id uuid, p_action text, p_email text, p_shares_change bigint, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_stock_plan_action_log_r2169(plan_id, action_type, by_email, shares_change, notes_md)
  VALUES (p_plan_id, p_action, p_email, p_shares_change, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2169', jsonb_build_object('id', v_id, 'plan_id', p_plan_id, 'action', p_action), now());
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2169(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2169(uuid, text, text, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2169(p_plan_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_stock_plan_tracker_r2169
     SET status = p_status, last_amended_at = now(), updated_at = now()
   WHERE id = p_plan_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2169', jsonb_build_object('plan_id', p_plan_id, 'status', p_status), now());
END;$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2169(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2169(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.active_plans_r2169()
RETURNS SETOF public.investor_cap_table_stock_plan_tracker_r2169
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_stock_plan_tracker_r2169 WHERE status = 'active' ORDER BY captured_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.active_plans_r2169() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_plans_r2169() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2169(p_limit int)
RETURNS SETOF public.investor_stock_plan_action_log_r2169
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_stock_plan_action_log_r2169 ORDER BY taken_at DESC LIMIT COALESCE(p_limit, 50);
END;$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2169(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2169(int) TO authenticated;

COMMIT;
