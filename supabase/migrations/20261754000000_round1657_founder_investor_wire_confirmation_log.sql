BEGIN;

-- =====================================================================
-- r1657 — Founder Investor Wire Confirmation Log (HEAVY)
-- Log incoming investor wires, reconcile vs commitments, founder ack +
-- thank-you note per wire.
-- =====================================================================

-- Wire receipts: one row per inbound investor wire
CREATE TABLE IF NOT EXISTS public.founder_investor_wire_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  commitment_rupees bigint NOT NULL DEFAULT 0 CHECK (commitment_rupees >= 0),
  wire_amount_rupees bigint NOT NULL CHECK (wire_amount_rupees > 0),
  bank_reference text,
  wired_at timestamptz NOT NULL DEFAULT now(),
  currency text NOT NULL DEFAULT 'INR',
  reconciled boolean NOT NULL DEFAULT false,
  reconciliation_variance_rupees bigint NOT NULL DEFAULT 0,
  reconciled_at timestamptz,
  reconciled_by uuid REFERENCES public.profiles(id),
  acknowledged boolean NOT NULL DEFAULT false,
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES public.profiles(id),
  thank_you_note text,
  thank_you_sent_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_investor_wire_receipts_wired_at
  ON public.founder_investor_wire_receipts (wired_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_investor_wire_receipts_investor
  ON public.founder_investor_wire_receipts (investor_name);
CREATE INDEX IF NOT EXISTS idx_founder_investor_wire_receipts_recon
  ON public.founder_investor_wire_receipts (reconciled, acknowledged);

ALTER TABLE public.founder_investor_wire_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_wire_receipts_founder_only
  ON public.founder_investor_wire_receipts;
CREATE POLICY founder_wire_receipts_founder_only
  ON public.founder_investor_wire_receipts
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_investor_wire_receipts FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.founder_investor_wire_receipts TO authenticated;

-- Per-wire acknowledgement / thank-you events (audit trail)
CREATE TABLE IF NOT EXISTS public.founder_investor_wire_ack_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL
    REFERENCES public.founder_investor_wire_receipts(id) ON DELETE CASCADE,
  event_kind text NOT NULL
    CHECK (event_kind IN ('reconciled','acknowledged','thank_you_sent','note_updated')),
  message text,
  actor_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_wire_ack_events_receipt
  ON public.founder_investor_wire_ack_events (receipt_id, created_at DESC);

ALTER TABLE public.founder_investor_wire_ack_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_wire_ack_events_founder_only
  ON public.founder_investor_wire_ack_events;
CREATE POLICY founder_wire_ack_events_founder_only
  ON public.founder_investor_wire_ack_events
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_investor_wire_ack_events FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.founder_investor_wire_ack_events TO authenticated;

-- =====================================================================
-- RPCs
-- =====================================================================

-- 1) List wire receipts (READ)
DROP FUNCTION IF EXISTS public.founder_wire_receipts_list(int);
CREATE OR REPLACE FUNCTION public.founder_wire_receipts_list(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  commitment_rupees bigint,
  wire_amount_rupees bigint,
  bank_reference text,
  wired_at timestamptz,
  reconciled boolean,
  reconciliation_variance_rupees bigint,
  acknowledged boolean,
  thank_you_sent_at timestamptz,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id, r.investor_name, r.investor_email, r.commitment_rupees,
    r.wire_amount_rupees, r.bank_reference, r.wired_at,
    r.reconciled, r.reconciliation_variance_rupees,
    r.acknowledged, r.thank_you_sent_at, r.notes
  FROM public.founder_investor_wire_receipts r
  ORDER BY r.wired_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_receipts_list(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_receipts_list(int) TO authenticated;

-- 2) Aggregate summary (READ)
DROP FUNCTION IF EXISTS public.founder_wire_receipts_summary();
CREATE OR REPLACE FUNCTION public.founder_wire_receipts_summary()
RETURNS TABLE (
  total_wires int,
  total_received_rupees bigint,
  total_commitment_rupees bigint,
  reconciled_count int,
  unreconciled_count int,
  acknowledged_count int,
  pending_ack_count int,
  thank_you_sent_count int,
  variance_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_wires,
    COALESCE(SUM(r.wire_amount_rupees), 0)::bigint AS total_received_rupees,
    COALESCE(SUM(r.commitment_rupees), 0)::bigint AS total_commitment_rupees,
    (COUNT(*) FILTER (WHERE r.reconciled))::int AS reconciled_count,
    (COUNT(*) FILTER (WHERE NOT r.reconciled))::int AS unreconciled_count,
    (COUNT(*) FILTER (WHERE r.acknowledged))::int AS acknowledged_count,
    (COUNT(*) FILTER (WHERE NOT r.acknowledged))::int AS pending_ack_count,
    (COUNT(*) FILTER (WHERE r.thank_you_sent_at IS NOT NULL))::int AS thank_you_sent_count,
    COALESCE(SUM(r.wire_amount_rupees - r.commitment_rupees), 0)::bigint AS variance_rupees
  FROM public.founder_investor_wire_receipts r;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_receipts_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_receipts_summary() TO authenticated;

-- 3) Per-investor rollup (READ)
DROP FUNCTION IF EXISTS public.founder_wire_receipts_by_investor();
CREATE OR REPLACE FUNCTION public.founder_wire_receipts_by_investor()
RETURNS TABLE (
  investor_name text,
  wire_count int,
  total_wired_rupees bigint,
  total_commitment_rupees bigint,
  outstanding_rupees bigint,
  last_wired_at timestamptz,
  pending_ack_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.investor_name,
    (COUNT(*))::int AS wire_count,
    COALESCE(SUM(r.wire_amount_rupees), 0)::bigint AS total_wired_rupees,
    COALESCE(MAX(r.commitment_rupees), 0)::bigint AS total_commitment_rupees,
    GREATEST(COALESCE(MAX(r.commitment_rupees), 0) - COALESCE(SUM(r.wire_amount_rupees), 0), 0)::bigint AS outstanding_rupees,
    MAX(r.wired_at) AS last_wired_at,
    (COUNT(*) FILTER (WHERE NOT r.acknowledged))::int AS pending_ack_count
  FROM public.founder_investor_wire_receipts r
  GROUP BY r.investor_name
  ORDER BY total_wired_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_receipts_by_investor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_receipts_by_investor() TO authenticated;

-- 4) Recent ack events (READ)
DROP FUNCTION IF EXISTS public.founder_wire_ack_events_recent(int);
CREATE OR REPLACE FUNCTION public.founder_wire_ack_events_recent(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  receipt_id uuid,
  investor_name text,
  event_kind text,
  message text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id, e.receipt_id, r.investor_name,
    e.event_kind, e.message, e.created_at
  FROM public.founder_investor_wire_ack_events e
  JOIN public.founder_investor_wire_receipts r ON r.id = e.receipt_id
  ORDER BY e.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_ack_events_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_ack_events_recent(int) TO authenticated;

-- 5) Log a wire (WRITE, VOLATILE)
DROP FUNCTION IF EXISTS public.founder_wire_log(text, text, bigint, bigint, text, timestamptz, text);
CREATE OR REPLACE FUNCTION public.founder_wire_log(
  p_investor_name text,
  p_investor_email text,
  p_commitment_rupees bigint,
  p_wire_amount_rupees bigint,
  p_bank_reference text,
  p_wired_at timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_investor_name IS NULL OR length(trim(p_investor_name)) = 0 THEN
    RAISE EXCEPTION 'investor_name required';
  END IF;
  IF p_wire_amount_rupees IS NULL OR p_wire_amount_rupees <= 0 THEN
    RAISE EXCEPTION 'wire_amount_rupees must be positive';
  END IF;

  INSERT INTO public.founder_investor_wire_receipts (
    investor_name, investor_email, commitment_rupees, wire_amount_rupees,
    bank_reference, wired_at, notes
  ) VALUES (
    trim(p_investor_name), p_investor_email, COALESCE(p_commitment_rupees, 0),
    p_wire_amount_rupees, p_bank_reference, COALESCE(p_wired_at, now()), p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_wire_log',
    jsonb_build_object('receipt_id', v_id, 'investor_name', p_investor_name, 'amount_rupees', p_wire_amount_rupees),
    now()
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_log(text, text, bigint, bigint, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_log(text, text, bigint, bigint, text, timestamptz, text) TO authenticated;

-- 6) Reconcile a wire (WRITE, VOLATILE)
DROP FUNCTION IF EXISTS public.founder_wire_reconcile(uuid, text);
CREATE OR REPLACE FUNCTION public.founder_wire_reconcile(
  p_receipt_id uuid,
  p_message text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_variance bigint;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_uid := auth.uid();

  UPDATE public.founder_investor_wire_receipts
     SET reconciled = true,
         reconciled_at = now(),
         reconciled_by = v_uid,
         reconciliation_variance_rupees = (wire_amount_rupees - commitment_rupees),
         updated_at = now()
   WHERE id = p_receipt_id
   RETURNING reconciliation_variance_rupees INTO v_variance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'receipt not found';
  END IF;

  INSERT INTO public.founder_investor_wire_ack_events (receipt_id, event_kind, message, actor_user_id)
  VALUES (p_receipt_id, 'reconciled', p_message, v_uid);

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    v_uid,
    (auth.jwt()->>'email'),
    'founder_wire_reconcile',
    jsonb_build_object('receipt_id', p_receipt_id, 'variance_rupees', v_variance),
    now()
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_reconcile(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_reconcile(uuid, text) TO authenticated;

-- 7) Acknowledge + thank-you (WRITE, VOLATILE)
DROP FUNCTION IF EXISTS public.founder_wire_acknowledge(uuid, text);
CREATE OR REPLACE FUNCTION public.founder_wire_acknowledge(
  p_receipt_id uuid,
  p_thank_you_note text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_uid := auth.uid();

  UPDATE public.founder_investor_wire_receipts
     SET acknowledged = true,
         acknowledged_at = now(),
         acknowledged_by = v_uid,
         thank_you_note = COALESCE(p_thank_you_note, thank_you_note),
         thank_you_sent_at = CASE WHEN p_thank_you_note IS NOT NULL AND length(trim(p_thank_you_note)) > 0 THEN now() ELSE thank_you_sent_at END,
         updated_at = now()
   WHERE id = p_receipt_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'receipt not found';
  END IF;

  INSERT INTO public.founder_investor_wire_ack_events (receipt_id, event_kind, message, actor_user_id)
  VALUES (p_receipt_id, 'acknowledged', p_thank_you_note, v_uid);

  IF p_thank_you_note IS NOT NULL AND length(trim(p_thank_you_note)) > 0 THEN
    INSERT INTO public.founder_investor_wire_ack_events (receipt_id, event_kind, message, actor_user_id)
    VALUES (p_receipt_id, 'thank_you_sent', p_thank_you_note, v_uid);
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    v_uid,
    (auth.jwt()->>'email'),
    'founder_wire_acknowledge',
    jsonb_build_object('receipt_id', p_receipt_id, 'has_note', (p_thank_you_note IS NOT NULL)),
    now()
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_wire_acknowledge(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_wire_acknowledge(uuid, text) TO authenticated;

COMMIT;