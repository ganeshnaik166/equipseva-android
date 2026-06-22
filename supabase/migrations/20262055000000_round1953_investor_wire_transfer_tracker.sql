BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_wire_transfers_r1953 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  transfer_date date NOT NULL,
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  purpose text NOT NULL CHECK (purpose IN ('capital_call','founder_payment','expense_reimbursement','refund','other')),
  currency text NOT NULL DEFAULT 'INR',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','received','reconciled','disputed','refunded')),
  reference_md text,
  reconciled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_wire_reconciliation_log_r1953 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL REFERENCES public.investor_wire_transfers_r1953(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('received_confirmed','reconciled_to_intent','missing_intent','dispute_opened','refunded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_wire_transfers_r1953 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_wire_reconciliation_log_r1953 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_wires_r1953 ON public.investor_wire_transfers_r1953;
CREATE POLICY founder_all_wires_r1953 ON public.investor_wire_transfers_r1953
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_recon_r1953 ON public.investor_wire_reconciliation_log_r1953;
CREATE POLICY founder_all_recon_r1953 ON public.investor_wire_reconciliation_log_r1953
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_investor_wire_transfers_r1953()
RETURNS TABLE(id uuid, investor_id uuid, investor_email text, transfer_date date, amount_rupees bigint, purpose text, currency text, status text, reference_md text, reconciled_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_id, p.email, t.transfer_date, t.amount_rupees, t.purpose, t.currency, t.status, t.reference_md, t.reconciled_at, t.created_at
    FROM public.investor_wire_transfers_r1953 t
    LEFT JOIN public.profiles p ON p.id = t.investor_id
    ORDER BY t.transfer_date DESC, t.created_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_wire_transfer_r1953(
  p_investor_id uuid,
  p_transfer_date date,
  p_amount_rupees bigint,
  p_purpose text,
  p_currency text,
  p_status text,
  p_reference_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_wire_transfers_r1953(investor_id, transfer_date, amount_rupees, purpose, currency, status, reference_md)
  VALUES (p_investor_id, p_transfer_date, p_amount_rupees, p_purpose, COALESCE(p_currency,'INR'), COALESCE(p_status,'pending'), p_reference_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1953.log_transfer', jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'amount_rupees', p_amount_rupees, 'purpose', p_purpose, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_investor_wire_reconciliations_r1953(p_transfer_id uuid)
RETURNS TABLE(id uuid, transfer_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.transfer_id, r.action_type, r.taken_at, r.by_email, r.notes_md
    FROM public.investor_wire_reconciliation_log_r1953 r
    WHERE r.transfer_id = p_transfer_id
    ORDER BY r.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_wire_reconciliation_r1953(
  p_transfer_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_wire_reconciliation_log_r1953(transfer_id, action_type, by_email, notes_md)
  VALUES (p_transfer_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1953.log_reconciliation', jsonb_build_object('id', v_id, 'transfer_id', p_transfer_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_investor_wire_status_r1953(
  p_transfer_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','received','reconciled','disputed','refunded') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.investor_wire_transfers_r1953
     SET status = p_status,
         reconciled_at = CASE WHEN p_status = 'reconciled' THEN now() ELSE reconciled_at END,
         updated_at = now()
   WHERE id = p_transfer_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1953.mark_status', jsonb_build_object('id', p_transfer_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.unreconciled_investor_wires_r1953()
RETURNS TABLE(id uuid, investor_email text, transfer_date date, amount_rupees bigint, purpose text, status text, age_days int)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, p.email, t.transfer_date, t.amount_rupees, t.purpose, t.status,
           GREATEST(0, (CURRENT_DATE - t.transfer_date))::int
    FROM public.investor_wire_transfers_r1953 t
    LEFT JOIN public.profiles p ON p.id = t.investor_id
    WHERE t.status IN ('pending','received','disputed')
    ORDER BY t.transfer_date ASC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_investor_wire_reconciliations_r1953()
RETURNS TABLE(id uuid, transfer_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.transfer_id, r.action_type, r.taken_at, r.by_email, r.notes_md
    FROM public.investor_wire_reconciliation_log_r1953 r
    ORDER BY r.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_wire_transfers_r1953() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_wire_transfer_r1953(uuid, date, bigint, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_wire_reconciliations_r1953(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_wire_reconciliation_r1953(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_wire_status_r1953(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.unreconciled_investor_wires_r1953() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_investor_wire_reconciliations_r1953() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_wire_transfers_r1953() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_wire_transfer_r1953(uuid, date, bigint, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_wire_reconciliations_r1953(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_wire_reconciliation_r1953(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_wire_status_r1953(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unreconciled_investor_wires_r1953() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_investor_wire_reconciliations_r1953() TO authenticated;

COMMIT;
