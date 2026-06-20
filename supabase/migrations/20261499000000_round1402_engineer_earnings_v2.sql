BEGIN;
-- r1402 — Engineer earnings v2 with cashout history + tax filing assistance
-- 2 tables + 8 RPCs



-- ============================================================================
-- TABLE 1: engineer_tax_filing_assists
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_tax_filing_assists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assessment_year text NOT NULL,
  total_income_rupees numeric NOT NULL DEFAULT 0,
  total_tds_deducted_rupees numeric NOT NULL DEFAULT 0,
  gst_filed boolean NOT NULL DEFAULT false,
  it_filed boolean NOT NULL DEFAULT false,
  form_16a_url text,
  form_26as_url text,
  itr_v_url text,
  generated_at timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, assessment_year)
);

CREATE INDEX IF NOT EXISTS idx_etfa_engineer ON public.engineer_tax_filing_assists(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_etfa_ay ON public.engineer_tax_filing_assists(assessment_year);

ALTER TABLE public.engineer_tax_filing_assists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etfa_engineer_self_read ON public.engineer_tax_filing_assists;
CREATE POLICY etfa_engineer_self_read ON public.engineer_tax_filing_assists
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS etfa_founder_write ON public.engineer_tax_filing_assists;
CREATE POLICY etfa_founder_write ON public.engineer_tax_filing_assists
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: engineer_cashout_requests
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_cashout_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount_rupees numeric NOT NULL CHECK (amount_rupees >= 0),
  request_status text NOT NULL DEFAULT 'requested'
    CHECK (request_status IN ('requested','approved','queued_for_payout','sent','rejected','cancelled')),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  payout_id uuid REFERENCES public.engineer_payouts(id) ON DELETE SET NULL,
  rejection_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecr_engineer ON public.engineer_cashout_requests(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecr_status ON public.engineer_cashout_requests(request_status);
CREATE INDEX IF NOT EXISTS idx_ecr_requested_at ON public.engineer_cashout_requests(requested_at DESC);

ALTER TABLE public.engineer_cashout_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ecr_engineer_self_read ON public.engineer_cashout_requests;
CREATE POLICY ecr_engineer_self_read ON public.engineer_cashout_requests
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS ecr_founder_all ON public.engineer_cashout_requests;
CREATE POLICY ecr_founder_all ON public.engineer_cashout_requests
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_engineer_earnings_v2_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_earnings_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_earnings_v2_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
  v_ay_start date;
  v_ay_end date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  -- AY April 1 -> March 31
  IF extract(month FROM now()) >= 4 THEN
    v_ay_start := make_date(extract(year FROM now())::int, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int + 1, 3, 31);
  ELSE
    v_ay_start := make_date(extract(year FROM now())::int - 1, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int, 3, 31);
  END IF;

  SELECT jsonb_build_object(
    'total_earnings_lifetime_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE status = 'processed'), 0),
    'total_earnings_this_ay_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE status = 'processed' AND processed_at::date BETWEEN v_ay_start AND v_ay_end), 0),
    'total_tds_deducted_rupees', COALESCE((SELECT SUM(total_tds_deducted_rupees) FROM engineer_tax_filing_assists), 0),
    'top_earner_user_id', (SELECT engineer_user_id FROM engineer_payouts WHERE status='processed' GROUP BY engineer_user_id ORDER BY SUM(amount_rupees) DESC LIMIT 1),
    'top_earner_total_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE status='processed' GROUP BY engineer_user_id ORDER BY SUM(amount_rupees) DESC LIMIT 1), 0),
    'cashout_requests_pending', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE request_status = 'requested'),
    'cashout_requests_approved', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE request_status = 'approved'),
    'cashout_requests_queued', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE request_status = 'queued_for_payout'),
    'cashout_requests_sent', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE request_status = 'sent'),
    'cashout_requests_rejected', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE request_status = 'rejected'),
    'cashout_requests_total_30d', (SELECT COUNT(*) FROM engineer_cashout_requests WHERE requested_at >= now() - interval '30 days'),
    'cashout_amount_sent_lifetime', COALESCE((SELECT SUM(amount_rupees) FROM engineer_cashout_requests WHERE request_status = 'sent'), 0),
    'cashout_amount_pending_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_cashout_requests WHERE request_status IN ('requested','approved','queued_for_payout')), 0),
    'avg_days_request_to_sent', COALESCE((SELECT ROUND(AVG(EXTRACT(EPOCH FROM (sent_at - requested_at)) / 86400)::numeric, 2) FROM engineer_cashout_requests WHERE request_status = 'sent' AND sent_at IS NOT NULL), 0),
    'engineers_with_tax_assist', (SELECT COUNT(DISTINCT engineer_user_id) FROM engineer_tax_filing_assists),
    'engineers_gst_filed_this_ay', (SELECT COUNT(*) FROM engineer_tax_filing_assists WHERE gst_filed = true AND assessment_year = 'AY-' || to_char(v_ay_start, 'YY') || '-' || to_char(v_ay_end, 'YY')),
    'engineers_it_filed_this_ay', (SELECT COUNT(*) FROM engineer_tax_filing_assists WHERE it_filed = true AND assessment_year = 'AY-' || to_char(v_ay_start, 'YY') || '-' || to_char(v_ay_end, 'YY')),
    'current_ay_label', 'AY-' || to_char(v_ay_start, 'YY') || '-' || to_char(v_ay_end, 'YY')
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_engineer_earnings_v2_cashout_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_earnings_v2_cashout_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_engineer_earnings_v2_cashout_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  amount_rupees numeric,
  request_status text,
  approved_at timestamptz,
  payout_id uuid,
  rejection_reason text,
  requested_at timestamptz,
  sent_at timestamptz,
  days_open numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    ecr.id,
    ecr.engineer_user_id,
    ecr.amount_rupees,
    ecr.request_status,
    ecr.approved_at,
    ecr.payout_id,
    ecr.rejection_reason,
    ecr.requested_at,
    ecr.sent_at,
    ROUND(EXTRACT(EPOCH FROM (COALESCE(ecr.sent_at, now()) - ecr.requested_at)) / 86400, 2) AS days_open
  FROM engineer_cashout_requests ecr
  WHERE (p_status IS NULL OR ecr.request_status = p_status)
  ORDER BY ecr.requested_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_cashout_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_cashout_recent(text, int) TO authenticated;

-- ============================================================================
-- RPC 3: founder_engineer_earnings_v2_tax_filing_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_earnings_v2_tax_filing_status();
CREATE OR REPLACE FUNCTION public.founder_engineer_earnings_v2_tax_filing_status()
RETURNS TABLE (
  engineer_user_id uuid,
  assessment_year text,
  total_income_rupees numeric,
  total_tds_deducted_rupees numeric,
  gst_filed boolean,
  it_filed boolean,
  form_16a_url text,
  form_26as_url text,
  itr_v_url text,
  last_updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ay_start date;
  v_ay_end date;
  v_ay_label text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF extract(month FROM now()) >= 4 THEN
    v_ay_start := make_date(extract(year FROM now())::int, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int + 1, 3, 31);
  ELSE
    v_ay_start := make_date(extract(year FROM now())::int - 1, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int, 3, 31);
  END IF;
  v_ay_label := 'AY-' || to_char(v_ay_start, 'YY') || '-' || to_char(v_ay_end, 'YY');

  RETURN QUERY
  SELECT
    etfa.engineer_user_id,
    etfa.assessment_year,
    etfa.total_income_rupees,
    etfa.total_tds_deducted_rupees,
    etfa.gst_filed,
    etfa.it_filed,
    etfa.form_16a_url,
    etfa.form_26as_url,
    etfa.itr_v_url,
    etfa.last_updated_at
  FROM engineer_tax_filing_assists etfa
  WHERE etfa.assessment_year = v_ay_label
  ORDER BY etfa.total_income_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_tax_filing_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_earnings_v2_tax_filing_status() TO authenticated;

-- ============================================================================
-- RPC 4: engineer_earnings_v2_my_summary (engineer self)
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_earnings_v2_my_summary();
CREATE OR REPLACE FUNCTION public.engineer_earnings_v2_my_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_ay_start date;
  v_ay_end date;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  IF extract(month FROM now()) >= 4 THEN
    v_ay_start := make_date(extract(year FROM now())::int, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int + 1, 3, 31);
  ELSE
    v_ay_start := make_date(extract(year FROM now())::int - 1, 4, 1);
    v_ay_end := make_date(extract(year FROM now())::int, 3, 31);
  END IF;

  SELECT jsonb_build_object(
    'lifetime_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE engineer_user_id = v_uid AND status = 'processed'), 0),
    'this_ay_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE engineer_user_id = v_uid AND status = 'processed' AND processed_at::date BETWEEN v_ay_start AND v_ay_end), 0),
    'last_12m_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE engineer_user_id = v_uid AND status = 'processed' AND processed_at >= now() - interval '12 months'), 0),
    'pending_cashout_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_cashout_requests WHERE engineer_user_id = v_uid AND request_status IN ('requested','approved','queued_for_payout')), 0),
    'lifetime_cashout_sent_rupees', COALESCE((SELECT SUM(amount_rupees) FROM engineer_cashout_requests WHERE engineer_user_id = v_uid AND request_status = 'sent'), 0)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_earnings_v2_my_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_earnings_v2_my_summary() TO authenticated;

-- ============================================================================
-- RPC 5: engineer_earnings_v2_request_cashout (engineer self)
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_earnings_v2_request_cashout(numeric);
CREATE OR REPLACE FUNCTION public.engineer_earnings_v2_request_cashout(p_amount_rupees numeric)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_request_id uuid;
  v_available numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  IF p_amount_rupees IS NULL OR p_amount_rupees <= 0 THEN
    RAISE EXCEPTION 'amount must be positive' USING ERRCODE='22023';
  END IF;

  SELECT
    COALESCE((SELECT SUM(amount_rupees) FROM engineer_payouts WHERE engineer_user_id = v_uid AND status = 'processed'), 0)
    - COALESCE((SELECT SUM(amount_rupees) FROM engineer_cashout_requests WHERE engineer_user_id = v_uid AND request_status IN ('requested','approved','queued_for_payout','sent')), 0)
  INTO v_available;

  IF p_amount_rupees > v_available THEN
    RAISE EXCEPTION 'insufficient balance: % requested, % available', p_amount_rupees, v_available USING ERRCODE='22023';
  END IF;

  INSERT INTO engineer_cashout_requests (engineer_user_id, amount_rupees, request_status)
  VALUES (v_uid, p_amount_rupees, 'requested')
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_earnings_v2_request_cashout(numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_earnings_v2_request_cashout(numeric) TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_engineer_earnings_v2_approve_cashout
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_earnings_v2_approve_cashout(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_earnings_v2_approve_cashout(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE engineer_cashout_requests
  SET request_status = 'approved',
      approved_by = auth.uid(),
      approved_at = now(),
      updated_at = now()
  WHERE id = p_request_id AND request_status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'request not found or not in requested state' USING ERRCODE='P0002';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_approve_cashout(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_approve_cashout(uuid) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_engineer_earnings_v2_reject_cashout
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_earnings_v2_reject_cashout(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_earnings_v2_reject_cashout(p_request_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE engineer_cashout_requests
  SET request_status = 'rejected',
      rejection_reason = p_reason,
      approved_by = auth.uid(),
      approved_at = now(),
      updated_at = now()
  WHERE id = p_request_id AND request_status IN ('requested','approved');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'request not found or already finalized' USING ERRCODE='P0002';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_reject_cashout(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_reject_cashout(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 8: log_founder_engineer_earnings_v2_link_payout
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_earnings_v2_link_payout(uuid, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_earnings_v2_link_payout(p_request_id uuid, p_payout_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payout_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT status INTO v_payout_status FROM engineer_payouts WHERE id = p_payout_id;
  IF v_payout_status IS NULL THEN
    RAISE EXCEPTION 'payout not found' USING ERRCODE='P0002';
  END IF;

  UPDATE engineer_cashout_requests
  SET payout_id = p_payout_id,
      request_status = CASE WHEN v_payout_status = 'processed' THEN 'sent' ELSE 'queued_for_payout' END,
      sent_at = CASE WHEN v_payout_status = 'processed' THEN now() ELSE sent_at END,
      updated_at = now()
  WHERE id = p_request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'request not found' USING ERRCODE='P0002';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_link_payout(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_earnings_v2_link_payout(uuid, uuid) TO authenticated;

COMMIT;