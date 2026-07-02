BEGIN;

-- ============================================================================
-- Round 1757: Investor Wire Confirmation Tracker
-- Track wire transfer confirmations from investors + thank-you queue
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_wire_confirmations_r1757 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  commitment_amount_rupees bigint NOT NULL DEFAULT 0,
  wire_received_amount_rupees bigint NOT NULL DEFAULT 0,
  wire_received_at timestamptz,
  bank_reference text,
  mismatch_flag boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','reconciled','disputed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_wire_thanks_queue_r1757 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wire_id uuid NOT NULL REFERENCES public.investor_wire_confirmations_r1757(id) ON DELETE CASCADE,
  thank_you_method text NOT NULL
    CHECK (thank_you_method IN ('email','handwritten','call','in_person')),
  sent_at timestamptz,
  by_email text,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_wire_confirmations_r1757 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_wire_thanks_queue_r1757 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r1757_wires_founder_all ON public.investor_wire_confirmations_r1757;
CREATE POLICY r1757_wires_founder_all ON public.investor_wire_confirmations_r1757
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r1757_thanks_founder_all ON public.investor_wire_thanks_queue_r1757;
CREATE POLICY r1757_thanks_founder_all ON public.investor_wire_thanks_queue_r1757
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_wires_r1757()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  commitment_amount_rupees bigint,
  wire_received_amount_rupees bigint,
  wire_received_at timestamptz,
  bank_reference text,
  mismatch_flag boolean,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT w.id, w.investor_id, p.email::text, w.commitment_amount_rupees,
         w.wire_received_amount_rupees, w.wire_received_at, w.bank_reference,
         w.mismatch_flag, w.status, w.created_at
  FROM public.investor_wire_confirmations_r1757 w
  LEFT JOIN public.profiles p ON p.id = w.investor_id
  ORDER BY w.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_wire_r1757(
  p_investor_id uuid,
  p_commitment_rupees bigint,
  p_received_rupees bigint,
  p_received_at timestamptz,
  p_bank_reference text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_mismatch boolean;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_mismatch := (p_commitment_rupees IS DISTINCT FROM p_received_rupees);
  INSERT INTO public.investor_wire_confirmations_r1757(
    investor_id, commitment_amount_rupees, wire_received_amount_rupees,
    wire_received_at, bank_reference, mismatch_flag, status
  ) VALUES (
    p_investor_id, p_commitment_rupees, p_received_rupees,
    p_received_at, p_bank_reference, v_mismatch,
    CASE WHEN v_mismatch THEN 'disputed' ELSE 'confirmed' END
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1757_log_wire',
          jsonb_build_object('wire_id', v_id, 'mismatch', v_mismatch), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_thanks_r1757()
RETURNS TABLE (
  id uuid,
  wire_id uuid,
  investor_email text,
  thank_you_method text,
  sent_at timestamptz,
  by_email text,
  response text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT t.id, t.wire_id, p.email::text, t.thank_you_method,
         t.sent_at, t.by_email, t.response, t.created_at
  FROM public.investor_wire_thanks_queue_r1757 t
  LEFT JOIN public.investor_wire_confirmations_r1757 w ON w.id = t.wire_id
  LEFT JOIN public.profiles p ON p.id = w.investor_id
  ORDER BY t.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_thanks_r1757(
  p_wire_id uuid,
  p_method text,
  p_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_wire_thanks_queue_r1757(wire_id, thank_you_method, sent_at, by_email)
  VALUES (p_wire_id, p_method, now(), p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1757_send_thanks',
          jsonb_build_object('thanks_id', v_id, 'wire_id', p_wire_id, 'method', p_method), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_wire_r1757(
  p_wire_id uuid,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_wire_confirmations_r1757
     SET status = 'reconciled', notes = p_notes, updated_at = now()
   WHERE id = p_wire_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1757_reconcile_wire',
          jsonb_build_object('wire_id', p_wire_id), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.pending_thanks_queue_r1757()
RETURNS TABLE (
  wire_id uuid,
  investor_email text,
  wire_received_amount_rupees bigint,
  wire_received_at timestamptz,
  days_since_received int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT w.id, p.email::text, w.wire_received_amount_rupees, w.wire_received_at,
         EXTRACT(DAY FROM (now() - w.wire_received_at))::int
  FROM public.investor_wire_confirmations_r1757 w
  LEFT JOIN public.profiles p ON p.id = w.investor_id
  WHERE w.status IN ('confirmed','reconciled')
    AND NOT EXISTS (
      SELECT 1 FROM public.investor_wire_thanks_queue_r1757 t
      WHERE t.wire_id = w.id AND t.sent_at IS NOT NULL
    )
  ORDER BY w.wire_received_at ASC NULLS LAST
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_wires_summary_r1757()
RETURNS TABLE (
  total_wires int,
  total_received_rupees bigint,
  total_committed_rupees bigint,
  mismatches int,
  reconciled int,
  pending_thanks int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    COALESCE(SUM(w.wire_received_amount_rupees), 0)::bigint,
    COALESCE(SUM(w.commitment_amount_rupees), 0)::bigint,
    (COUNT(*) FILTER (WHERE w.mismatch_flag))::int,
    (COUNT(*) FILTER (WHERE w.status = 'reconciled'))::int,
    (
      SELECT COUNT(*)::int
      FROM public.investor_wire_confirmations_r1757 w2
      WHERE w2.status IN ('confirmed','reconciled')
        AND NOT EXISTS (
          SELECT 1 FROM public.investor_wire_thanks_queue_r1757 t
          WHERE t.wire_id = w2.id AND t.sent_at IS NOT NULL
        )
    )
  FROM public.investor_wire_confirmations_r1757 w
  WHERE w.created_at > now() - interval '90 days';
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_wires_r1757() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_wire_r1757(uuid, bigint, bigint, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_thanks_r1757() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.send_thanks_r1757(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reconcile_wire_r1757(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pending_thanks_queue_r1757() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_wires_summary_r1757() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_wires_r1757() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_wire_r1757(uuid, bigint, bigint, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thanks_r1757() TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_thanks_r1757(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_wire_r1757(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_thanks_queue_r1757() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_wires_summary_r1757() TO authenticated;

COMMIT;