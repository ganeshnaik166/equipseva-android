BEGIN;

-- ============================================================================
-- Round 1747 — Hospital Cash Collection Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_invoices_outstanding_r1747 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_number text NOT NULL,
  invoice_date date NOT NULL,
  due_date date NOT NULL,
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  paid_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (paid_amount_rupees >= 0),
  days_overdue int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','overdue_30','overdue_60','overdue_90_plus','written_off')),
  write_off_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hio_r1747_hospital ON public.hospital_invoices_outstanding_r1747(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hio_r1747_status ON public.hospital_invoices_outstanding_r1747(status);
CREATE INDEX IF NOT EXISTS idx_hio_r1747_due ON public.hospital_invoices_outstanding_r1747(due_date);

CREATE TABLE IF NOT EXISTS public.hospital_collection_actions_r1747 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public.hospital_invoices_outstanding_r1747(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reminder','call','visit','legal_notice','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hca_r1747_invoice ON public.hospital_collection_actions_r1747(invoice_id);
CREATE INDEX IF NOT EXISTS idx_hca_r1747_taken ON public.hospital_collection_actions_r1747(taken_at DESC);

ALTER TABLE public.hospital_invoices_outstanding_r1747 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_collection_actions_r1747 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hio_r1747 ON public.hospital_invoices_outstanding_r1747;
CREATE POLICY founder_all_hio_r1747 ON public.hospital_invoices_outstanding_r1747
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hca_r1747 ON public.hospital_collection_actions_r1747;
CREATE POLICY founder_all_hca_r1747 ON public.hospital_collection_actions_r1747
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_outstanding
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_outstanding_r1747(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  hospital_org text,
  invoice_number text,
  invoice_date date,
  due_date date,
  amount_rupees bigint,
  paid_amount_rupees bigint,
  outstanding_rupees bigint,
  days_overdue int,
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
  SELECT
    h.id,
    h.hospital_user_id,
    p.email,
    o.name,
    h.invoice_number,
    h.invoice_date,
    h.due_date,
    h.amount_rupees,
    h.paid_amount_rupees,
    (h.amount_rupees - h.paid_amount_rupees)::bigint,
    GREATEST(0, (CURRENT_DATE - h.due_date))::int,
    h.status,
    h.created_at
  FROM public.hospital_invoices_outstanding_r1747 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE (p_status IS NULL OR h.status = p_status)
  ORDER BY h.due_date ASC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_invoice
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_invoice_r1747(
  p_hospital_user_id uuid,
  p_invoice_number text,
  p_invoice_date date,
  p_due_date date,
  p_amount_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_status text;
  v_overdue int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_overdue := GREATEST(0, (CURRENT_DATE - p_due_date));
  v_status := CASE
    WHEN v_overdue = 0 THEN 'current'
    WHEN v_overdue <= 30 THEN 'overdue_30'
    WHEN v_overdue <= 60 THEN 'overdue_60'
    ELSE 'overdue_90_plus'
  END;

  INSERT INTO public.hospital_invoices_outstanding_r1747
    (hospital_user_id, invoice_number, invoice_date, due_date, amount_rupees, days_overdue, status)
  VALUES
    (p_hospital_user_id, p_invoice_number, p_invoice_date, p_due_date, p_amount_rupees, v_overdue, v_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_invoice_r1747',
    jsonb_build_object(
      'invoice_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'invoice_number', p_invoice_number,
      'amount_rupees', p_amount_rupees
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_collection_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_collection_actions_r1747(p_invoice_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  invoice_id uuid,
  invoice_number text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
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
    a.id,
    a.invoice_id,
    h.invoice_number,
    a.action_type,
    a.taken_at,
    a.by_email,
    a.outcome
  FROM public.hospital_collection_actions_r1747 a
  LEFT JOIN public.hospital_invoices_outstanding_r1747 h ON h.id = a.invoice_id
  WHERE (p_invoice_id IS NULL OR a.invoice_id = p_invoice_id)
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1747(
  p_invoice_id uuid,
  p_action_type text,
  p_outcome text DEFAULT NULL
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

  INSERT INTO public.hospital_collection_actions_r1747
    (invoice_id, action_type, by_email, outcome)
  VALUES
    (p_invoice_id, p_action_type, (auth.jwt() ->> 'email'), p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_action_r1747',
    jsonb_build_object(
      'action_id', v_id,
      'invoice_id', p_invoice_id,
      'action_type', p_action_type,
      'outcome', p_outcome
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_paid
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_paid_r1747(
  p_invoice_id uuid,
  p_paid_amount_rupees bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amount bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT amount_rupees INTO v_amount
  FROM public.hospital_invoices_outstanding_r1747
  WHERE id = p_invoice_id;

  IF v_amount IS NULL THEN
    RAISE EXCEPTION 'invoice not found';
  END IF;

  UPDATE public.hospital_invoices_outstanding_r1747
  SET
    paid_amount_rupees = p_paid_amount_rupees,
    status = CASE WHEN p_paid_amount_rupees >= v_amount THEN 'current' ELSE status END,
    updated_at = now()
  WHERE id = p_invoice_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'mark_paid_r1747',
    jsonb_build_object(
      'invoice_id', p_invoice_id,
      'paid_amount_rupees', p_paid_amount_rupees
    )
  );
END;
$$;

-- ============================================================================
-- RPC 6: ageing_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ageing_summary_r1747()
RETURNS TABLE (
  bucket text,
  invoice_count int,
  total_outstanding_rupees bigint
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
    h.status::text,
    (COUNT(*))::int,
    COALESCE(SUM(h.amount_rupees - h.paid_amount_rupees), 0)::bigint
  FROM public.hospital_invoices_outstanding_r1747 h
  WHERE h.status <> 'written_off'
  GROUP BY h.status
  ORDER BY h.status;
END;
$$;

-- ============================================================================
-- RPC 7: top_overdue_hospitals
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_overdue_hospitals_r1747()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  hospital_org text,
  invoice_count int,
  total_outstanding_rupees bigint,
  max_days_overdue int
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
    h.hospital_user_id,
    p.email,
    o.name,
    (COUNT(*))::int,
    COALESCE(SUM(h.amount_rupees - h.paid_amount_rupees), 0)::bigint,
    COALESCE(MAX(GREATEST(0, (CURRENT_DATE - h.due_date))), 0)::int
  FROM public.hospital_invoices_outstanding_r1747 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE h.status IN ('overdue_30','overdue_60','overdue_90_plus')
  GROUP BY h.hospital_user_id, p.email, o.name
  ORDER BY total_outstanding_rupees DESC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_outstanding_r1747(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_invoice_r1747(uuid, text, date, date, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_collection_actions_r1747(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1747(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_paid_r1747(uuid, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ageing_summary_r1747() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_overdue_hospitals_r1747() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_outstanding_r1747(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_invoice_r1747(uuid, text, date, date, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_collection_actions_r1747(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1747(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_paid_r1747(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ageing_summary_r1747() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_overdue_hospitals_r1747() TO authenticated;

COMMIT;