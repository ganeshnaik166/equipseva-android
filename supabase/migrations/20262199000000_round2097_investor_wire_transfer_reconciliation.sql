BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_wire_transfer_reconciliation_r2097 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id_referenced uuid,
  intent_label text NOT NULL,
  expected_amount_rupees bigint NOT NULL DEFAULT 0,
  received_amount_rupees bigint NOT NULL DEFAULT 0,
  variance_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'matched' CHECK (status IN ('matched','under_received','over_received','orphaned','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_wire_recon_action_log_r2097 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recon_id uuid NOT NULL REFERENCES public.investor_wire_transfer_reconciliation_r2097(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('matched','adjusted','disputed','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_wire_transfer_reconciliation_r2097 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_wire_recon_action_log_r2097 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_recon_r2097 ON public.investor_wire_transfer_reconciliation_r2097;
CREATE POLICY founder_all_recon_r2097 ON public.investor_wire_transfer_reconciliation_r2097
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2097 ON public.investor_wire_recon_action_log_r2097;
CREATE POLICY founder_all_action_r2097 ON public.investor_wire_recon_action_log_r2097
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1) list_recons
CREATE OR REPLACE FUNCTION public.list_recons_r2097()
RETURNS SETOF public.investor_wire_transfer_reconciliation_r2097
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_wire_transfer_reconciliation_r2097 ORDER BY captured_at DESC LIMIT 500;
END; $$;

-- 2) log_recon
CREATE OR REPLACE FUNCTION public.log_recon_r2097(
  p_intent_label text,
  p_expected_amount_rupees bigint,
  p_received_amount_rupees bigint,
  p_transfer_id_referenced uuid DEFAULT NULL,
  p_status text DEFAULT 'matched'
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_variance bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_variance := COALESCE(p_received_amount_rupees,0) - COALESCE(p_expected_amount_rupees,0);
  INSERT INTO public.investor_wire_transfer_reconciliation_r2097
    (transfer_id_referenced, intent_label, expected_amount_rupees, received_amount_rupees, variance_rupees, status)
  VALUES (p_transfer_id_referenced, p_intent_label, COALESCE(p_expected_amount_rupees,0), COALESCE(p_received_amount_rupees,0), v_variance, COALESCE(p_status,'matched'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_recon_r2097',
          jsonb_build_object('recon_id', v_id, 'intent_label', p_intent_label, 'variance', v_variance));
  RETURN v_id;
END; $$;

-- 3) list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2097(p_recon_id uuid)
RETURNS SETOF public.investor_wire_recon_action_log_r2097
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_wire_recon_action_log_r2097 WHERE recon_id = p_recon_id ORDER BY taken_at DESC;
END; $$;

-- 4) log_action
CREATE OR REPLACE FUNCTION public.log_action_r2097(
  p_recon_id uuid,
  p_action_type text,
  p_notes_md text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_wire_recon_action_log_r2097 (recon_id, action_type, by_email, notes_md)
  VALUES (p_recon_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2097',
          jsonb_build_object('action_id', v_id, 'recon_id', p_recon_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

-- 5) mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2097(p_recon_id uuid, p_status text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_wire_transfer_reconciliation_r2097 SET status = p_status, updated_at = now() WHERE id = p_recon_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2097',
          jsonb_build_object('recon_id', p_recon_id, 'status', p_status));
  RETURN true;
END; $$;

-- 6) orphaned
CREATE OR REPLACE FUNCTION public.orphaned_r2097()
RETURNS SETOF public.investor_wire_transfer_reconciliation_r2097
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_wire_transfer_reconciliation_r2097 WHERE status = 'orphaned' ORDER BY captured_at DESC LIMIT 200;
END; $$;

-- 7) recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2097()
RETURNS SETOF public.investor_wire_recon_action_log_r2097
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_wire_recon_action_log_r2097 ORDER BY taken_at DESC LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_recons_r2097() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_recon_r2097(text, bigint, bigint, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2097(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2097(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2097(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.orphaned_r2097() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2097() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_recons_r2097() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_recon_r2097(text, bigint, bigint, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2097(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2097(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2097(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.orphaned_r2097() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2097() TO authenticated;

COMMIT;
