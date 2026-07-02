BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_field_earned_hours_r2096 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  field_hours numeric NOT NULL DEFAULT 0,
  billed_hours numeric NOT NULL DEFAULT 0,
  gap_hours numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_target' CHECK (status IN ('on_target','under_recording','over_billing','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_hours_action_log_r2096 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hours_id uuid NOT NULL REFERENCES public.engineer_field_earned_hours_r2096(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('audited','corrected','coached','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_field_earned_hours_r2096 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_hours_action_log_r2096 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hours_r2096 ON public.engineer_field_earned_hours_r2096;
CREATE POLICY founder_all_hours_r2096 ON public.engineer_field_earned_hours_r2096
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2096 ON public.engineer_hours_action_log_r2096;
CREATE POLICY founder_all_actions_r2096 ON public.engineer_hours_action_log_r2096
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_hours_r2096()
RETURNS SETOF public.engineer_field_earned_hours_r2096
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_field_earned_hours_r2096 ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_hours_r2096(
  p_engineer_user_id uuid,
  p_period_label text,
  p_field_hours numeric,
  p_billed_hours numeric,
  p_status text DEFAULT 'on_target'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_gap numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_gap := COALESCE(p_billed_hours,0) - COALESCE(p_field_hours,0);
  INSERT INTO public.engineer_field_earned_hours_r2096(engineer_user_id, period_label, field_hours, billed_hours, gap_hours, status)
  VALUES (p_engineer_user_id, p_period_label, COALESCE(p_field_hours,0), COALESCE(p_billed_hours,0), v_gap, COALESCE(p_status,'on_target'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_hours_r2096', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'gap', v_gap));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2096(p_hours_id uuid)
RETURNS SETOF public.engineer_hours_action_log_r2096
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_hours_action_log_r2096 WHERE hours_id = p_hours_id ORDER BY taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2096(
  p_hours_id uuid,
  p_action_type text,
  p_notes_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_hours_action_log_r2096(hours_id, action_type, by_email, notes_md)
  VALUES (p_hours_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2096', jsonb_build_object('id', v_id, 'hours_id', p_hours_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2096(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_field_earned_hours_r2096 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2096', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.gaps_r2096()
RETURNS TABLE(status text, rows_count bigint, total_gap numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT h.status, COUNT(*)::bigint, COALESCE(SUM(h.gap_hours),0)
  FROM public.engineer_field_earned_hours_r2096 h GROUP BY h.status ORDER BY h.status;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2096()
RETURNS SETOF public.engineer_hours_action_log_r2096
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_hours_action_log_r2096 ORDER BY taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_hours_r2096() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hours_r2096(uuid, text, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2096(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2096(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2096(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.gaps_r2096() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2096() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hours_r2096() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hours_r2096(uuid, text, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2096(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2096(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2096(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gaps_r2096() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2096() TO authenticated;

COMMIT;
