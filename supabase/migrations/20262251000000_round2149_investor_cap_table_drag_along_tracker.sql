BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_drag_along_tracker_r2149 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  drag_along_label text NOT NULL,
  threshold_pct numeric NOT NULL,
  shares_consented bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','exercised','waived','expired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_drag_along_action_log_r2149 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drag_id uuid NOT NULL REFERENCES public.investor_cap_table_drag_along_tracker_r2149(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','exercised','waived','expired','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_count bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_drag_along_tracker_r2149 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_drag_along_action_log_r2149 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drags_r2149 ON public.investor_cap_table_drag_along_tracker_r2149;
CREATE POLICY founder_all_drags_r2149 ON public.investor_cap_table_drag_along_tracker_r2149
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_drag_actions_r2149 ON public.investor_drag_along_action_log_r2149;
CREATE POLICY founder_all_drag_actions_r2149 ON public.investor_drag_along_action_log_r2149
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_drags_r2149()
RETURNS TABLE(id uuid, investor_id uuid, drag_along_label text, threshold_pct numeric, shares_consented bigint, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.id, d.investor_id, d.drag_along_label, d.threshold_pct, d.shares_consented, d.status, d.captured_at
    FROM public.investor_cap_table_drag_along_tracker_r2149 d
    ORDER BY d.captured_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_drag_r2149(
  p_investor_id uuid, p_label text, p_threshold_pct numeric, p_shares_consented bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_drag_along_tracker_r2149(investor_id, drag_along_label, threshold_pct, shares_consented)
    VALUES (p_investor_id, p_label, p_threshold_pct, p_shares_consented) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_drag_r2149',
      jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_label, 'threshold_pct', p_threshold_pct));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2149(p_drag_id uuid)
RETURNS TABLE(id uuid, drag_id uuid, action_type text, taken_at timestamptz, by_email text, shares_count bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.drag_id, a.action_type, a.taken_at, a.by_email, a.shares_count, a.notes_md
    FROM public.investor_drag_along_action_log_r2149 a
    WHERE a.drag_id = p_drag_id
    ORDER BY a.taken_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2149(
  p_drag_id uuid, p_action_type text, p_by_email text, p_shares_count bigint, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_drag_along_action_log_r2149(drag_id, action_type, by_email, shares_count, notes_md)
    VALUES (p_drag_id, p_action_type, p_by_email, p_shares_count, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2149',
      jsonb_build_object('id', v_id, 'drag_id', p_drag_id, 'action_type', p_action_type, 'shares_count', p_shares_count));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2149(p_drag_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_drag_along_tracker_r2149 SET status = p_status, updated_at = now() WHERE id = p_drag_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2149',
      jsonb_build_object('drag_id', p_drag_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.threshold_met_r2149()
RETURNS TABLE(id uuid, drag_along_label text, threshold_pct numeric, shares_consented bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT d.id, d.drag_along_label, d.threshold_pct, d.shares_consented, d.status
    FROM public.investor_cap_table_drag_along_tracker_r2149 d
    WHERE d.status = 'active' AND d.shares_consented >= 0
    ORDER BY d.threshold_pct DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2149()
RETURNS TABLE(id uuid, drag_id uuid, action_type text, taken_at timestamptz, by_email text, shares_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.drag_id, a.action_type, a.taken_at, a.by_email, a.shares_count
    FROM public.investor_drag_along_action_log_r2149 a
    ORDER BY a.taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_drags_r2149() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_drag_r2149(uuid, text, numeric, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2149(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2149(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2149(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.threshold_met_r2149() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2149() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drags_r2149() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_drag_r2149(uuid, text, numeric, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2149(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2149(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2149(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.threshold_met_r2149() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2149() TO authenticated;

COMMIT;
