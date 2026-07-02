BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_earning_trajectory_r2036 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  base_payout_rupees bigint NOT NULL DEFAULT 0,
  bonus_payout_rupees bigint NOT NULL DEFAULT 0,
  total_earnings_rupees bigint NOT NULL DEFAULT 0,
  ytd_total_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'stable' CHECK (status IN ('rising','stable','declining','spike')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_earning_action_log_r2036 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  earning_id uuid NOT NULL REFERENCES public.engineer_earning_trajectory_r2036(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','coached','escalation','recognition_added','bonus_increased')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_earning_trajectory_r2036 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_earning_action_log_r2036 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_earn_traj_r2036 ON public.engineer_earning_trajectory_r2036;
CREATE POLICY founder_all_earn_traj_r2036 ON public.engineer_earning_trajectory_r2036
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_earn_action_r2036 ON public.engineer_earning_action_log_r2036;
CREATE POLICY founder_all_earn_action_r2036 ON public.engineer_earning_action_log_r2036
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_earnings_r2036()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_label text,
  base_payout_rupees bigint,
  bonus_payout_rupees bigint,
  total_earnings_rupees bigint,
  ytd_total_rupees bigint,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.engineer_user_id, e.period_label, e.base_payout_rupees, e.bonus_payout_rupees,
           e.total_earnings_rupees, e.ytd_total_rupees, e.status, e.captured_at
    FROM public.engineer_earning_trajectory_r2036 e
    ORDER BY e.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_earning_r2036(
  p_engineer_user_id uuid,
  p_period_label text,
  p_base_payout_rupees bigint,
  p_bonus_payout_rupees bigint,
  p_ytd_total_rupees bigint,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_total := COALESCE(p_base_payout_rupees,0) + COALESCE(p_bonus_payout_rupees,0);
  INSERT INTO public.engineer_earning_trajectory_r2036
    (engineer_user_id, period_label, base_payout_rupees, bonus_payout_rupees, total_earnings_rupees, ytd_total_rupees, status)
    VALUES (p_engineer_user_id, p_period_label, p_base_payout_rupees, p_bonus_payout_rupees, v_total, p_ytd_total_rupees, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_earning_r2036',
            jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'period_label', p_period_label, 'total', v_total));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2036(p_earning_id uuid)
RETURNS TABLE (
  id uuid,
  earning_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.earning_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_earning_action_log_r2036 a
    WHERE a.earning_id = p_earning_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2036(
  p_earning_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_earning_action_log_r2036 (earning_id, action_type, by_email, notes_md)
    VALUES (p_earning_id, p_action_type, v_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_action_r2036',
            jsonb_build_object('id', v_id, 'earning_id', p_earning_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2036(
  p_earning_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_earning_trajectory_r2036
    SET status = p_status, updated_at = now()
    WHERE id = p_earning_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2036',
            jsonb_build_object('id', p_earning_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_earners_r2036()
RETURNS TABLE (
  engineer_user_id uuid,
  total_rupees bigint,
  ytd_rupees bigint,
  entries bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.engineer_user_id,
           SUM(e.total_earnings_rupees)::bigint AS total_rupees,
           MAX(e.ytd_total_rupees)::bigint AS ytd_rupees,
           COUNT(*)::bigint AS entries
    FROM public.engineer_earning_trajectory_r2036 e
    GROUP BY e.engineer_user_id
    ORDER BY total_rupees DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2036()
RETURNS TABLE (
  id uuid,
  earning_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.earning_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.engineer_earning_action_log_r2036 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_earnings_r2036() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_earning_r2036(uuid, text, bigint, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2036(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2036(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2036(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_earners_r2036() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2036() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_earnings_r2036() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_earning_r2036(uuid, text, bigint, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2036(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2036(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2036(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_earners_r2036() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2036() TO authenticated;

COMMIT;
