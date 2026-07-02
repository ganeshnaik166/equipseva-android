BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_liquidation_preference_stack_r1937 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  round_label text NOT NULL,
  preference_multiplier numeric NOT NULL DEFAULT 1.0,
  preference_type text NOT NULL CHECK (preference_type IN ('non_participating','participating_capped','participating_uncapped')),
  seniority int NOT NULL DEFAULT 1,
  invested_amount_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','superseded')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_liquidation_stack_action_log_r1937 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stack_id uuid NOT NULL REFERENCES public.investor_liquidation_preference_stack_r1937(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('stack_modeled','scenario_run','exercise_logged','waived','notified')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_liquidation_preference_stack_r1937 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_liquidation_stack_action_log_r1937 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stack_r1937 ON public.investor_liquidation_preference_stack_r1937;
CREATE POLICY founder_all_stack_r1937 ON public.investor_liquidation_preference_stack_r1937
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_stack_log_r1937 ON public.investor_liquidation_stack_action_log_r1937;
CREATE POLICY founder_all_stack_log_r1937 ON public.investor_liquidation_stack_action_log_r1937
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_liquidation_stacks_r1937()
RETURNS SETOF public.investor_liquidation_preference_stack_r1937
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_liquidation_preference_stack_r1937 ORDER BY seniority ASC, recorded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_liquidation_stack_r1937(
  p_investor_id uuid,
  p_round_label text,
  p_preference_multiplier numeric,
  p_preference_type text,
  p_seniority int,
  p_invested_amount_rupees bigint
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
  INSERT INTO public.investor_liquidation_preference_stack_r1937(
    investor_id, round_label, preference_multiplier, preference_type, seniority, invested_amount_rupees
  ) VALUES (
    p_investor_id, p_round_label, p_preference_multiplier, p_preference_type, p_seniority, p_invested_amount_rupees
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_liquidation_stack_r1937', jsonb_build_object('stack_id', v_id, 'investor_id', p_investor_id, 'round_label', p_round_label));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_liquidation_stack_actions_r1937(p_stack_id uuid)
RETURNS SETOF public.investor_liquidation_stack_action_log_r1937
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_liquidation_stack_action_log_r1937 WHERE stack_id = p_stack_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_liquidation_stack_action_r1937(
  p_stack_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_liquidation_stack_action_log_r1937(stack_id, action_type, by_email, notes_md)
  VALUES (p_stack_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_liquidation_stack_action_r1937', jsonb_build_object('action_id', v_id, 'stack_id', p_stack_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_liquidation_stack_status_r1937(
  p_stack_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_liquidation_preference_stack_r1937 SET status = p_status, updated_at = now() WHERE id = p_stack_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_liquidation_stack_status_r1937', jsonb_build_object('stack_id', p_stack_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.liquidation_stack_by_seniority_r1937()
RETURNS TABLE(seniority int, stack_count bigint, total_invested_rupees bigint, avg_multiplier numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.seniority,
           COUNT(*)::bigint,
           COALESCE(SUM(s.invested_amount_rupees), 0)::bigint,
           ROUND(AVG(s.preference_multiplier)::numeric, 2)
    FROM public.investor_liquidation_preference_stack_r1937 s
    WHERE s.status = 'active'
    GROUP BY s.seniority
    ORDER BY s.seniority ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_liquidation_stack_actions_r1937(p_limit int DEFAULT 25)
RETURNS SETOF public.investor_liquidation_stack_action_log_r1937
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_liquidation_stack_action_log_r1937 ORDER BY taken_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_liquidation_stacks_r1937() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_liquidation_stack_r1937(uuid, text, numeric, text, int, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_liquidation_stack_actions_r1937(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_liquidation_stack_action_r1937(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_liquidation_stack_status_r1937(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.liquidation_stack_by_seniority_r1937() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_liquidation_stack_actions_r1937(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_liquidation_stacks_r1937() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_liquidation_stack_r1937(uuid, text, numeric, text, int, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_liquidation_stack_actions_r1937(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_liquidation_stack_action_r1937(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_liquidation_stack_status_r1937(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.liquidation_stack_by_seniority_r1937() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_liquidation_stack_actions_r1937(int) TO authenticated;

COMMIT;
