BEGIN;

-- ============================================================================
-- Round 2263: Hospital Chain DSO (Days-Sales-Outstanding) Tracker
-- Receivables aging by hospital chain, top dragging chains, collection priority
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_receivables_r2263 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL,
  chain_name text NOT NULL,
  hospital_count int NOT NULL DEFAULT 1,
  invoice_number text NOT NULL,
  invoice_amount_rupees int NOT NULL CHECK (invoice_amount_rupees > 0),
  invoiced_at timestamptz NOT NULL DEFAULT now(),
  due_at timestamptz NOT NULL,
  paid_at timestamptz,
  amount_paid_rupees int NOT NULL DEFAULT 0,
  aging_bucket text NOT NULL CHECK (aging_bucket IN ('current','1_30','31_60','61_90','90_plus')),
  collection_status text NOT NULL DEFAULT 'open' CHECK (collection_status IN ('open','partial','paid','disputed','written_off')),
  contact_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_collection_actions_r2263 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receivable_id uuid NOT NULL REFERENCES public.hospital_chain_receivables_r2263(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reminder_email','phone_call','escalation','legal_notice','settlement_offer','payment_received')),
  action_notes text NOT NULL,
  amount_promised_rupees int DEFAULT 0,
  promised_by_date timestamptz,
  action_taken_at timestamptz NOT NULL DEFAULT now(),
  action_taken_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_hcr_r2263_chain ON public.hospital_chain_receivables_r2263(chain_id);
CREATE INDEX IF NOT EXISTS idx_hcr_r2263_bucket ON public.hospital_chain_receivables_r2263(aging_bucket);
CREATE INDEX IF NOT EXISTS idx_hcr_r2263_status ON public.hospital_chain_receivables_r2263(collection_status);
CREATE INDEX IF NOT EXISTS idx_hca_r2263_recv ON public.hospital_chain_collection_actions_r2263(receivable_id);

ALTER TABLE public.hospital_chain_receivables_r2263 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_collection_actions_r2263 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcr_r2263 ON public.hospital_chain_receivables_r2263;
CREATE POLICY founder_all_hcr_r2263 ON public.hospital_chain_receivables_r2263
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hca_r2263 ON public.hospital_chain_collection_actions_r2263;
CREATE POLICY founder_all_hca_r2263 ON public.hospital_chain_collection_actions_r2263
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: Overview KPIs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_dso_overview()
RETURNS TABLE (
  total_outstanding_rupees bigint,
  total_invoices int,
  weighted_dso_days numeric,
  overdue_90_plus_rupees bigint,
  chains_with_dues int,
  collection_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(r.invoice_amount_rupees - r.amount_paid_rupees), 0)::bigint,
    (COUNT(*) FILTER (WHERE r.collection_status IN ('open','partial')))::int,
    COALESCE(AVG(EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0)
      FILTER (WHERE r.collection_status IN ('open','partial')), 0)::numeric(10,1),
    COALESCE(SUM(r.invoice_amount_rupees - r.amount_paid_rupees)
      FILTER (WHERE r.aging_bucket = '90_plus'), 0)::bigint,
    (COUNT(DISTINCT r.chain_id) FILTER (WHERE r.collection_status IN ('open','partial')))::int,
    CASE WHEN SUM(r.invoice_amount_rupees) > 0
      THEN (SUM(r.amount_paid_rupees)::numeric * 100.0 / SUM(r.invoice_amount_rupees))
      ELSE 0 END::numeric(5,2)
  FROM public.hospital_chain_receivables_r2263 r;
END;
$$;

-- ============================================================================
-- RPC 2: Aging bucket breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_aging_buckets()
RETURNS TABLE (
  bucket text,
  invoice_count int,
  total_amount_rupees bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_grand_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(invoice_amount_rupees - amount_paid_rupees), 0)
    INTO v_grand_total
    FROM public.hospital_chain_receivables_r2263
    WHERE collection_status IN ('open','partial');
  RETURN QUERY
  SELECT
    r.aging_bucket,
    COUNT(*)::int,
    COALESCE(SUM(r.invoice_amount_rupees - r.amount_paid_rupees), 0)::bigint,
    CASE WHEN v_grand_total > 0
      THEN (SUM(r.invoice_amount_rupees - r.amount_paid_rupees)::numeric * 100.0 / v_grand_total)
      ELSE 0 END::numeric(5,2)
  FROM public.hospital_chain_receivables_r2263 r
  WHERE r.collection_status IN ('open','partial')
  GROUP BY r.aging_bucket
  ORDER BY r.aging_bucket;
END;
$$;

-- ============================================================================
-- RPC 3: Top dragging chains
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_top_dragging_chains()
RETURNS TABLE (
  chain_id uuid,
  chain_name text,
  hospital_count int,
  open_invoices int,
  total_outstanding_rupees bigint,
  oldest_invoice_age_days int,
  chain_dso_days numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.chain_id,
    MAX(r.chain_name),
    MAX(r.hospital_count)::int,
    (COUNT(*) FILTER (WHERE r.collection_status IN ('open','partial')))::int,
    COALESCE(SUM(r.invoice_amount_rupees - r.amount_paid_rupees), 0)::bigint,
    COALESCE(MAX(EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0)
      FILTER (WHERE r.collection_status IN ('open','partial')), 0)::int,
    COALESCE(AVG(EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0)
      FILTER (WHERE r.collection_status IN ('open','partial')), 0)::numeric(10,1)
  FROM public.hospital_chain_receivables_r2263 r
  WHERE r.collection_status IN ('open','partial')
  GROUP BY r.chain_id
  ORDER BY SUM(r.invoice_amount_rupees - r.amount_paid_rupees) DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- ============================================================================
-- RPC 4: Collection priority queue
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_collection_priority()
RETURNS TABLE (
  receivable_id uuid,
  chain_name text,
  invoice_number text,
  outstanding_rupees bigint,
  aging_days int,
  aging_bucket text,
  priority_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.invoice_number,
    (r.invoice_amount_rupees - r.amount_paid_rupees)::bigint,
    (EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0)::int,
    r.aging_bucket,
    ((r.invoice_amount_rupees - r.amount_paid_rupees)::numeric *
      (EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0) / 1000.0)::numeric(12,2)
  FROM public.hospital_chain_receivables_r2263 r
  WHERE r.collection_status IN ('open','partial')
  ORDER BY ((r.invoice_amount_rupees - r.amount_paid_rupees)::numeric *
    (EXTRACT(EPOCH FROM (now() - r.invoiced_at)) / 86400.0)) DESC
  LIMIT 30;
END;
$$;

-- ============================================================================
-- RPC 5: Recent collection actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_recent_actions()
RETURNS TABLE (
  action_id uuid,
  chain_name text,
  invoice_number text,
  action_type text,
  action_notes text,
  amount_promised_rupees int,
  action_taken_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    r.chain_name,
    r.invoice_number,
    a.action_type,
    a.action_notes,
    a.amount_promised_rupees,
    a.action_taken_at
  FROM public.hospital_chain_collection_actions_r2263 a
  JOIN public.hospital_chain_receivables_r2263 r ON r.id = a.receivable_id
  ORDER BY a.action_taken_at DESC
  LIMIT 30;
END;
$$;

-- ============================================================================
-- RPC 6: Dispute and write-off summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_dispute_summary()
RETURNS TABLE (
  status text,
  invoice_count int,
  amount_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.collection_status,
    COUNT(*)::int,
    COALESCE(SUM(r.invoice_amount_rupees - r.amount_paid_rupees), 0)::bigint
  FROM public.hospital_chain_receivables_r2263 r
  WHERE r.collection_status IN ('disputed','written_off','paid')
  GROUP BY r.collection_status
  ORDER BY SUM(r.invoice_amount_rupees - r.amount_paid_rupees) DESC NULLS LAST;
END;
$$;

-- ============================================================================
-- RPC 7: Log a collection action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2263_log_action(
  p_receivable_id uuid,
  p_action_type text,
  p_action_notes text,
  p_amount_promised_rupees int DEFAULT 0,
  p_promised_by_date timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_user_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_user_id FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.hospital_chain_collection_actions_r2263 (
    receivable_id, action_type, action_notes, amount_promised_rupees, promised_by_date, action_taken_by
  ) VALUES (
    p_receivable_id, p_action_type, p_action_notes, COALESCE(p_amount_promised_rupees, 0), p_promised_by_date, v_user_id
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.r2263_dso_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_aging_buckets() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_top_dragging_chains() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_collection_priority() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_recent_actions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_dispute_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2263_log_action(uuid, text, text, int, timestamptz) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2263_dso_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_aging_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_top_dragging_chains() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_collection_priority() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_recent_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_dispute_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2263_log_action(uuid, text, text, int, timestamptz) TO authenticated;

-- ============================================================================
-- Seed data
-- ============================================================================
INSERT INTO public.hospital_chain_receivables_r2263 (
  chain_id, chain_name, hospital_count, invoice_number, invoice_amount_rupees,
  invoiced_at, due_at, paid_at, amount_paid_rupees, aging_bucket, collection_status, contact_email
) VALUES
  (gen_random_uuid(), 'Apollo Hospitals Group', 71, 'INV-AP-2026-0418', 1850000, now() - interval '95 days', now() - interval '65 days', NULL, 0, '90_plus', 'open', 'ap@apollo.in'),
  (gen_random_uuid(), 'Apollo Hospitals Group', 71, 'INV-AP-2026-0512', 920000, now() - interval '72 days', now() - interval '42 days', NULL, 0, '61_90', 'open', 'ap@apollo.in'),
  (gen_random_uuid(), 'Fortis Healthcare', 28, 'INV-FT-2026-0301', 1240000, now() - interval '110 days', now() - interval '80 days', NULL, 250000, '90_plus', 'partial', 'ar@fortis.in'),
  (gen_random_uuid(), 'Manipal Hospitals', 31, 'INV-MN-2026-0277', 680000, now() - interval '48 days', now() - interval '18 days', NULL, 0, '31_60', 'open', 'finance@manipal.in'),
  (gen_random_uuid(), 'Max Healthcare', 17, 'INV-MX-2026-0189', 1450000, now() - interval '38 days', now() - interval '8 days', NULL, 0, '31_60', 'open', 'ap@maxhealthcare.in'),
  (gen_random_uuid(), 'Narayana Health', 23, 'INV-NH-2026-0444', 540000, now() - interval '22 days', now() - interval '0 days', NULL, 0, '1_30', 'open', 'ar@narayanahealth.org'),
  (gen_random_uuid(), 'Medanta Hospitals', 5, 'INV-MD-2026-0166', 880000, now() - interval '67 days', now() - interval '37 days', NULL, 0, '61_90', 'disputed', 'finance@medanta.org'),
  (gen_random_uuid(), 'KIMS Hospitals', 12, 'INV-KM-2026-0218', 320000, now() - interval '12 days', now() + interval '18 days', NULL, 0, 'current', 'open', 'ap@kimshospitals.com'),
  (gen_random_uuid(), 'Aster DM Healthcare', 14, 'INV-AS-2026-0322', 720000, now() - interval '125 days', now() - interval '95 days', NULL, 100000, '90_plus', 'partial', 'ar@asterdmhealthcare.com'),
  (gen_random_uuid(), 'Yashoda Hospitals', 4, 'INV-YS-2026-0142', 290000, now() - interval '180 days', now() - interval '150 days', NULL, 0, '90_plus', 'written_off', 'ap@yashodahospitals.com');

WITH r AS (SELECT id, chain_name FROM public.hospital_chain_receivables_r2263 ORDER BY created_at DESC LIMIT 4)
INSERT INTO public.hospital_chain_collection_actions_r2263 (receivable_id, action_type, action_notes, amount_promised_rupees, promised_by_date)
SELECT id, 'reminder_email', 'Sent 3rd reminder for outstanding invoice', 0, NULL FROM r LIMIT 1;

WITH r AS (SELECT id, chain_name FROM public.hospital_chain_receivables_r2263 WHERE chain_name = 'Apollo Hospitals Group' LIMIT 1)
INSERT INTO public.hospital_chain_collection_actions_r2263 (receivable_id, action_type, action_notes, amount_promised_rupees, promised_by_date)
SELECT id, 'escalation', 'Escalated to CFO office; meeting scheduled', 1850000, now() + interval '14 days' FROM r;

WITH r AS (SELECT id FROM public.hospital_chain_receivables_r2263 WHERE chain_name = 'Fortis Healthcare' LIMIT 1)
INSERT INTO public.hospital_chain_collection_actions_r2263 (receivable_id, action_type, action_notes, amount_promised_rupees, promised_by_date)
SELECT id, 'settlement_offer', 'Proposed 10% discount for immediate clearance', 990000, now() + interval '7 days' FROM r;

COMMIT;
