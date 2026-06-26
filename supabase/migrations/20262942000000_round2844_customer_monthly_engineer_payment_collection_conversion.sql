BEGIN;

-- ============================================================================
-- Round 2844: Customer Monthly Engineer Payment Collection Conversion
-- Tracks engineer-led monthly payment collection from customers, conversion
-- of collection attempts into cleared payments, dispute outcomes, and tenure.
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_collection_invoices_r2844 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  customer_org text NOT NULL,
  invoice_number text NOT NULL UNIQUE,
  invoice_amount_rupees integer NOT NULL CHECK (invoice_amount_rupees > 0),
  payment_method text NOT NULL CHECK (payment_method IN ('upi','bank_transfer','cash','cheque','card')),
  collection_days integer NOT NULL CHECK (collection_days >= 0),
  dispute_flag boolean NOT NULL DEFAULT false,
  outcome text NOT NULL CHECK (outcome IN ('cleared','partial','disputed','written_off','pending')),
  cleared_amount_rupees integer NOT NULL DEFAULT 0 CHECK (cleared_amount_rupees >= 0),
  issued_at date NOT NULL,
  closed_at date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_collection_invoices_r2844 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_collection_invoices_r2844;
CREATE POLICY founder_all ON engineer_collection_invoices_r2844
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_collection_invoices_r2844
  (engineer_code, engineer_name, customer_org, invoice_number, invoice_amount_rupees, payment_method, collection_days, dispute_flag, outcome, cleared_amount_rupees, issued_at, closed_at, notes)
VALUES
  ('ENG-301','Ramesh Patel','Apollo Spectra Hyderabad','INV-R2844-1001',48500,'upi',3,false,'cleared',48500,'2026-06-01'::date,'2026-06-04'::date,'Same-week UPI clearance'),
  ('ENG-302','Suresh Kumar','KIMS Secunderabad','INV-R2844-1002',125000,'bank_transfer',14,false,'cleared',125000,'2026-06-03'::date,'2026-06-17'::date,'NEFT batch clearance'),
  ('ENG-303','Anjali Reddy','Yashoda Somajiguda','INV-R2844-1003',76200,'cheque',21,true,'partial',50000,'2026-06-05'::date,'2026-06-26'::date,'GST line item disputed'),
  ('ENG-304','Vikram Singh','Continental Hospitals','INV-R2844-1004',32000,'cash',1,false,'cleared',32000,'2026-06-08'::date,'2026-06-09'::date,'Field cash collection'),
  ('ENG-305','Priya Iyer','Care Banjara','INV-R2844-1005',91000,'card',7,false,'cleared',91000,'2026-06-10'::date,'2026-06-17'::date,'Corporate card swipe'),
  ('ENG-301','Ramesh Patel','Sunshine Begumpet','INV-R2844-1006',58000,'upi',32,true,'disputed',0,'2026-05-15'::date,NULL,'Service quality dispute'),
  ('ENG-306','Naveen Goud','Star Hospital','INV-R2844-1007',104500,'bank_transfer',9,false,'cleared',104500,'2026-06-02'::date,'2026-06-11'::date,'Routine NEFT');

CREATE TABLE IF NOT EXISTS engineer_collection_conversion_r2844 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL UNIQUE,
  engineer_name text NOT NULL,
  invoices_issued integer NOT NULL CHECK (invoices_issued >= 0),
  invoices_cleared integer NOT NULL CHECK (invoices_cleared >= 0),
  invoices_disputed integer NOT NULL CHECK (invoices_disputed >= 0),
  total_invoiced_rupees integer NOT NULL CHECK (total_invoiced_rupees >= 0),
  total_cleared_rupees integer NOT NULL CHECK (total_cleared_rupees >= 0),
  avg_collection_days numeric(6,2) NOT NULL CHECK (avg_collection_days >= 0),
  tenure_months integer NOT NULL CHECK (tenure_months >= 0),
  tier text NOT NULL CHECK (tier IN ('bronze','silver','gold','platinum')),
  last_collection_at date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_collection_conversion_r2844 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_collection_conversion_r2844;
CREATE POLICY founder_all ON engineer_collection_conversion_r2844
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_collection_conversion_r2844
  (engineer_code, engineer_name, invoices_issued, invoices_cleared, invoices_disputed, total_invoiced_rupees, total_cleared_rupees, avg_collection_days, tenure_months, tier, last_collection_at)
VALUES
  ('ENG-301','Ramesh Patel',24,21,2,1245000,1102000,8.40,38,'gold','2026-06-04'::date),
  ('ENG-302','Suresh Kumar',18,17,1,2340000,2210000,12.10,52,'platinum','2026-06-17'::date),
  ('ENG-303','Anjali Reddy',15,11,3,985000,712000,18.60,22,'silver','2026-06-26'::date),
  ('ENG-304','Vikram Singh',31,29,1,820000,790000,5.20,14,'gold','2026-06-09'::date),
  ('ENG-305','Priya Iyer',12,12,0,1080000,1080000,6.80,9,'gold','2026-06-17'::date),
  ('ENG-306','Naveen Goud',9,8,1,640000,580000,11.40,6,'bronze','2026-06-11'::date);

-- ============================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated)
-- ============================================================================

DROP FUNCTION IF EXISTS r2844_collection_summary();
CREATE OR REPLACE FUNCTION r2844_collection_summary()
RETURNS TABLE(
  total_invoices integer,
  total_invoiced_rupees bigint,
  total_cleared_rupees bigint,
  clearance_rate numeric,
  disputed_count integer,
  avg_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COALESCE(SUM(invoice_amount_rupees),0)::bigint,
    COALESCE(SUM(cleared_amount_rupees),0)::bigint,
    ROUND(100.0 * COALESCE(SUM(cleared_amount_rupees),0) / NULLIF(SUM(invoice_amount_rupees),0), 2),
    COUNT(*) FILTER (WHERE dispute_flag = true)::integer,
    ROUND(AVG(collection_days)::numeric, 2)
  FROM engineer_collection_invoices_r2844;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_collection_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_collection_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2844_by_payment_method();
CREATE OR REPLACE FUNCTION r2844_by_payment_method()
RETURNS TABLE(
  payment_method text,
  invoice_count integer,
  total_rupees bigint,
  avg_days numeric,
  clearance_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.payment_method,
    COUNT(*)::integer,
    COALESCE(SUM(i.invoice_amount_rupees),0)::bigint,
    ROUND(AVG(i.collection_days)::numeric, 2),
    ROUND(100.0 * SUM(i.cleared_amount_rupees) / NULLIF(SUM(i.invoice_amount_rupees),0), 2)
  FROM engineer_collection_invoices_r2844 i
  GROUP BY i.payment_method
  ORDER BY SUM(i.invoice_amount_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_by_payment_method() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_by_payment_method() TO authenticated;

DROP FUNCTION IF EXISTS r2844_engineer_leaderboard();
CREATE OR REPLACE FUNCTION r2844_engineer_leaderboard()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  tier text,
  invoices_issued integer,
  total_cleared_rupees integer,
  conversion_pct numeric,
  avg_collection_days numeric,
  tenure_months integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.engineer_code,
    c.engineer_name,
    c.tier,
    c.invoices_issued,
    c.total_cleared_rupees,
    ROUND(100.0 * c.invoices_cleared / NULLIF(c.invoices_issued,0), 2),
    c.avg_collection_days,
    c.tenure_months
  FROM engineer_collection_conversion_r2844 c
  ORDER BY c.total_cleared_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS r2844_dispute_outcomes();
CREATE OR REPLACE FUNCTION r2844_dispute_outcomes()
RETURNS TABLE(
  outcome text,
  invoice_count integer,
  rupees_at_stake bigint,
  rupees_recovered bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.outcome,
    COUNT(*)::integer,
    COALESCE(SUM(i.invoice_amount_rupees),0)::bigint,
    COALESCE(SUM(i.cleared_amount_rupees),0)::bigint
  FROM engineer_collection_invoices_r2844 i
  GROUP BY i.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_dispute_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_dispute_outcomes() TO authenticated;

DROP FUNCTION IF EXISTS r2844_collection_days_buckets();
CREATE OR REPLACE FUNCTION r2844_collection_days_buckets()
RETURNS TABLE(
  bucket text,
  invoice_count integer,
  total_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN i.collection_days <= 7 THEN '0-7 days'
      WHEN i.collection_days <= 14 THEN '8-14 days'
      WHEN i.collection_days <= 30 THEN '15-30 days'
      ELSE '30+ days'
    END AS bucket,
    COUNT(*)::integer,
    COALESCE(SUM(i.invoice_amount_rupees),0)::bigint
  FROM engineer_collection_invoices_r2844 i
  GROUP BY bucket
  ORDER BY MIN(i.collection_days);
END $$;
REVOKE EXECUTE ON FUNCTION r2844_collection_days_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_collection_days_buckets() TO authenticated;

DROP FUNCTION IF EXISTS r2844_open_disputes();
CREATE OR REPLACE FUNCTION r2844_open_disputes()
RETURNS TABLE(
  invoice_number text,
  engineer_name text,
  customer_org text,
  invoice_amount_rupees integer,
  collection_days integer,
  outcome text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.invoice_number, i.engineer_name, i.customer_org, i.invoice_amount_rupees, i.collection_days, i.outcome, i.notes
  FROM engineer_collection_invoices_r2844 i
  WHERE i.dispute_flag = true
  ORDER BY i.invoice_amount_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_open_disputes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_open_disputes() TO authenticated;

DROP FUNCTION IF EXISTS r2844_tier_breakdown();
CREATE OR REPLACE FUNCTION r2844_tier_breakdown()
RETURNS TABLE(
  tier text,
  engineer_count integer,
  total_cleared_rupees bigint,
  avg_tenure_months numeric,
  avg_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.tier,
    COUNT(*)::integer,
    COALESCE(SUM(c.total_cleared_rupees),0)::bigint,
    ROUND(AVG(c.tenure_months)::numeric, 2),
    ROUND(AVG(c.avg_collection_days)::numeric, 2)
  FROM engineer_collection_conversion_r2844 c
  GROUP BY c.tier
  ORDER BY SUM(c.total_cleared_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_tier_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2844_recent_invoices();
CREATE OR REPLACE FUNCTION r2844_recent_invoices()
RETURNS TABLE(
  invoice_number text,
  engineer_name text,
  customer_org text,
  invoice_amount_rupees integer,
  cleared_amount_rupees integer,
  payment_method text,
  collection_days integer,
  outcome text,
  issued_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.invoice_number, i.engineer_name, i.customer_org, i.invoice_amount_rupees, i.cleared_amount_rupees, i.payment_method, i.collection_days, i.outcome, i.issued_at
  FROM engineer_collection_invoices_r2844 i
  ORDER BY i.issued_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION r2844_recent_invoices() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2844_recent_invoices() TO authenticated;

COMMIT;
