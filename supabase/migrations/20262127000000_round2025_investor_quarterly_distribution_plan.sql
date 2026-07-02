BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_quarterly_distribution_plan_r2025 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  planned_total_rupees bigint NOT NULL DEFAULT 0,
  executed_total_rupees bigint NOT NULL DEFAULT 0,
  planned_date date,
  executed_date date,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','executed','cancelled','postponed','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_distribution_action_log_r2025 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.investor_quarterly_distribution_plan_r2025(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('planned','approved','executed','cancelled','clawback')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_quarterly_distribution_plan_r2025 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_distribution_action_log_r2025 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_plan_r2025 ON public.investor_quarterly_distribution_plan_r2025;
CREATE POLICY founder_all_plan_r2025 ON public.investor_quarterly_distribution_plan_r2025
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2025 ON public.investor_distribution_action_log_r2025;
CREATE POLICY founder_all_action_r2025 ON public.investor_distribution_action_log_r2025
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_plans_r2025()
RETURNS SETOF public.investor_quarterly_distribution_plan_r2025
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_quarterly_distribution_plan_r2025 ORDER BY captured_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_plan_r2025(
  p_quarter_label text,
  p_planned_total_rupees bigint,
  p_planned_date date,
  p_status text DEFAULT 'planned'
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_quarterly_distribution_plan_r2025(quarter_label, planned_total_rupees, planned_date, status)
    VALUES (p_quarter_label, COALESCE(p_planned_total_rupees,0), p_planned_date, COALESCE(p_status,'planned'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_plan_r2025',
            jsonb_build_object('id', v_id, 'quarter_label', p_quarter_label, 'planned_total_rupees', p_planned_total_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2025(p_plan_id uuid DEFAULT NULL)
RETURNS SETOF public.investor_distribution_action_log_r2025
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.investor_distribution_action_log_r2025
    WHERE p_plan_id IS NULL OR plan_id = p_plan_id
    ORDER BY taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2025(
  p_plan_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
  p_notes_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_distribution_action_log_r2025(plan_id, action_type, by_email, amount_rupees, notes_md)
    VALUES (p_plan_id, p_action_type, p_by_email, COALESCE(p_amount_rupees,0), p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2025',
            jsonb_build_object('id', v_id, 'plan_id', p_plan_id, 'action_type', p_action_type, 'amount_rupees', p_amount_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2025(
  p_plan_id uuid,
  p_status text,
  p_executed_total_rupees bigint DEFAULT NULL,
  p_executed_date date DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_quarterly_distribution_plan_r2025
     SET status = p_status,
         executed_total_rupees = COALESCE(p_executed_total_rupees, executed_total_rupees),
         executed_date = COALESCE(p_executed_date, executed_date),
         updated_at = now()
   WHERE id = p_plan_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2025',
            jsonb_build_object('plan_id', p_plan_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.upcoming_plans_r2025()
RETURNS SETOF public.investor_quarterly_distribution_plan_r2025
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.investor_quarterly_distribution_plan_r2025
    WHERE status IN ('planned','postponed') AND (planned_date IS NULL OR planned_date >= CURRENT_DATE)
    ORDER BY planned_date NULLS LAST LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2025()
RETURNS SETOF public.investor_distribution_action_log_r2025
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.investor_distribution_action_log_r2025
    ORDER BY taken_at DESC LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_plans_r2025() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_plan_r2025(text, bigint, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2025(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2025(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2025(uuid, text, bigint, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_plans_r2025() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2025() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_plans_r2025() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_plan_r2025(text, bigint, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2025(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2025(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2025(uuid, text, bigint, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_plans_r2025() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2025() TO authenticated;

COMMIT;
