BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_treasury_yield_tracker_r2161 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  treasury_balance_rupees bigint NOT NULL DEFAULT 0,
  yield_pct numeric NOT NULL DEFAULT 0,
  yield_amount_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('earning','declining','stable','concerning')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_yield_action_log_r2161 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  yield_id uuid NOT NULL REFERENCES public.investor_treasury_yield_tracker_r2161(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reinvested','withdrawn','escalated','closed','reviewed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_treasury_yield_tracker_r2161 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_yield_action_log_r2161 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_yields_r2161 ON public.investor_treasury_yield_tracker_r2161;
CREATE POLICY founder_all_yields_r2161 ON public.investor_treasury_yield_tracker_r2161
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2161 ON public.investor_yield_action_log_r2161;
CREATE POLICY founder_all_actions_r2161 ON public.investor_yield_action_log_r2161
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_yields_r2161()
RETURNS SETOF public.investor_treasury_yield_tracker_r2161
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_treasury_yield_tracker_r2161 ORDER BY captured_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_yields_r2161() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_yields_r2161() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_yield_r2161(
  p_period_label text,
  p_treasury_balance_rupees bigint,
  p_yield_pct numeric,
  p_yield_amount_rupees bigint,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_treasury_yield_tracker_r2161 (period_label, treasury_balance_rupees, yield_pct, yield_amount_rupees, status)
  VALUES (p_period_label, p_treasury_balance_rupees, p_yield_pct, p_yield_amount_rupees, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_yield_r2161', jsonb_build_object('id', v_id, 'period_label', p_period_label, 'status', p_status));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_yield_r2161(text, bigint, numeric, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_yield_r2161(text, bigint, numeric, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2161(p_yield_id uuid)
RETURNS SETOF public.investor_yield_action_log_r2161
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_yield_action_log_r2161 WHERE yield_id = p_yield_id ORDER BY taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2161(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2161(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2161(
  p_yield_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_yield_action_log_r2161 (yield_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_yield_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2161', jsonb_build_object('id', v_id, 'yield_id', p_yield_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2161(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2161(uuid, text, text, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2161(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_treasury_yield_tracker_r2161 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2161', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2161(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2161(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_yields_r2161(p_limit int)
RETURNS SETOF public.investor_treasury_yield_tracker_r2161
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_treasury_yield_tracker_r2161 ORDER BY captured_at DESC LIMIT COALESCE(p_limit, 25);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_yields_r2161(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_yields_r2161(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2161(p_limit int)
RETURNS SETOF public.investor_yield_action_log_r2161
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_yield_action_log_r2161 ORDER BY taken_at DESC LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2161(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2161(int) TO authenticated;

COMMIT;
