BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_escrow_holdbacks_r2224 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_label text NOT NULL,
  repair_job_ref text,
  escrow_amount_rupees integer NOT NULL DEFAULT 0,
  holdback_amount_rupees integer NOT NULL DEFAULT 0,
  released_amount_rupees integer NOT NULL DEFAULT 0,
  dispute_reason text NOT NULL,
  resolution_status text NOT NULL DEFAULT 'in_escrow' CHECK (resolution_status IN ('in_escrow','partial_release','resolved_customer','resolved_engineer','split_settlement','escalated')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  due_release_at timestamptz,
  resolved_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_escrow_release_events_r2224 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  holdback_id uuid NOT NULL REFERENCES public.customer_escrow_holdbacks_r2224(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('hold','partial_release','full_release','refund_customer','split_payout','escalation','note')),
  amount_rupees integer NOT NULL DEFAULT 0,
  actor_email text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  remark text
);

ALTER TABLE public.customer_escrow_holdbacks_r2224 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_escrow_release_events_r2224 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_escrow_holdbacks_r2224;
CREATE POLICY founder_all ON public.customer_escrow_holdbacks_r2224 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_escrow_release_events_r2224;
CREATE POLICY founder_all ON public.customer_escrow_release_events_r2224 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_customer_escrow_holdbacks_r2224()
RETURNS TABLE (
  id uuid,
  customer_label text,
  repair_job_ref text,
  escrow_amount_rupees integer,
  holdback_amount_rupees integer,
  released_amount_rupees integer,
  dispute_reason text,
  resolution_status text,
  opened_at timestamptz,
  due_release_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.customer_label, h.repair_job_ref, h.escrow_amount_rupees, h.holdback_amount_rupees,
           h.released_amount_rupees, h.dispute_reason, h.resolution_status, h.opened_at, h.due_release_at, h.resolved_at
    FROM public.customer_escrow_holdbacks_r2224 h
    ORDER BY h.opened_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_customer_escrow_holdback_r2224()
RETURNS TABLE (
  id uuid,
  holdback_id uuid,
  event_type text,
  amount_rupees integer,
  actor_email text,
  recorded_at timestamptz,
  remark text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.holdback_id, e.event_type, e.amount_rupees, e.actor_email, e.recorded_at, e.remark
    FROM public.customer_escrow_release_events_r2224 e
    ORDER BY e.recorded_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.top_customer_escrow_holdbacks_r2224()
RETURNS TABLE (
  id uuid,
  customer_label text,
  holdback_amount_rupees integer,
  resolution_status text,
  opened_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.customer_label, h.holdback_amount_rupees, h.resolution_status, h.opened_at
    FROM public.customer_escrow_holdbacks_r2224 h
    WHERE h.resolution_status IN ('in_escrow','partial_release','escalated')
    ORDER BY h.holdback_amount_rupees DESC
    LIMIT 20;
END; $$;

CREATE OR REPLACE FUNCTION public.log_customer_escrow_holdback_r2224(
  p_customer_label text,
  p_repair_job_ref text,
  p_escrow_amount_rupees integer,
  p_holdback_amount_rupees integer,
  p_dispute_reason text,
  p_due_release_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_escrow_holdbacks_r2224(customer_label, repair_job_ref, escrow_amount_rupees, holdback_amount_rupees, dispute_reason, due_release_at)
  VALUES (p_customer_label, p_repair_job_ref, COALESCE(p_escrow_amount_rupees,0), COALESCE(p_holdback_amount_rupees,0), p_dispute_reason, p_due_release_at)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2224_log_holdback', jsonb_build_object('id', v_id, 'customer', p_customer_label, 'holdback', p_holdback_amount_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_customer_escrow_holdback_r2224(
  p_holdback_id uuid,
  p_event_type text,
  p_amount_rupees integer,
  p_remark text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_escrow_release_events_r2224(holdback_id, event_type, amount_rupees, actor_email, remark)
  VALUES (p_holdback_id, p_event_type, COALESCE(p_amount_rupees,0), (auth.jwt()->>'email'), p_remark)
  RETURNING id INTO v_id;
  IF p_event_type IN ('partial_release','full_release','refund_customer','split_payout') THEN
    UPDATE public.customer_escrow_holdbacks_r2224
       SET released_amount_rupees = released_amount_rupees + COALESCE(p_amount_rupees,0)
     WHERE id = p_holdback_id;
  END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2224_log_event', jsonb_build_object('id', v_id, 'holdback', p_holdback_id, 'event', p_event_type, 'amount', p_amount_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_customer_escrow_holdback_r2224(
  p_holdback_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.customer_escrow_holdbacks_r2224
     SET resolution_status = p_status,
         resolved_at = CASE WHEN p_status IN ('resolved_customer','resolved_engineer','split_settlement') THEN now() ELSE resolved_at END
   WHERE id = p_holdback_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2224_mark_status', jsonb_build_object('id', p_holdback_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.aggregate_customer_escrow_holdback_r2224()
RETURNS TABLE (
  total_holdbacks int,
  in_escrow_count int,
  resolved_count int,
  escalated_count int,
  total_escrow_rupees bigint,
  total_holdback_rupees bigint,
  total_released_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (COUNT(*))::int AS total_holdbacks,
      (COUNT(*) FILTER (WHERE resolution_status = 'in_escrow'))::int AS in_escrow_count,
      (COUNT(*) FILTER (WHERE resolution_status IN ('resolved_customer','resolved_engineer','split_settlement')))::int AS resolved_count,
      (COUNT(*) FILTER (WHERE resolution_status = 'escalated'))::int AS escalated_count,
      COALESCE(SUM(escrow_amount_rupees),0)::bigint AS total_escrow_rupees,
      COALESCE(SUM(holdback_amount_rupees),0)::bigint AS total_holdback_rupees,
      COALESCE(SUM(released_amount_rupees),0)::bigint AS total_released_rupees
    FROM public.customer_escrow_holdbacks_r2224;
END; $$;

REVOKE ALL ON FUNCTION public.list_customer_escrow_holdbacks_r2224() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_customer_escrow_holdback_r2224() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_customer_escrow_holdbacks_r2224() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_customer_escrow_holdback_r2224(text, text, integer, integer, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_customer_escrow_holdback_r2224(uuid, text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_customer_escrow_holdback_r2224(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_customer_escrow_holdback_r2224() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_customer_escrow_holdbacks_r2224() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_customer_escrow_holdback_r2224() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_customer_escrow_holdbacks_r2224() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_customer_escrow_holdback_r2224(text, text, integer, integer, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_customer_escrow_holdback_r2224(uuid, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_customer_escrow_holdback_r2224(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_customer_escrow_holdback_r2224() TO authenticated;

COMMIT;
