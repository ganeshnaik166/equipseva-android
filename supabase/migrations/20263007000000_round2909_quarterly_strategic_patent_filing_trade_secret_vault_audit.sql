-- Round 2909: Founder Quarterly Strategic Patent-Filing & Trade-Secret Vault Audit
-- Heavy founder ops: track patent filings + trade-secret vault entries with quarterly audit cadence.

-- ============================================================
-- TABLE 1: patent_filings_r2909
-- ============================================================
CREATE TABLE IF NOT EXISTS patent_filings_r2909 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  filing_code text NOT NULL,
  title text NOT NULL,
  inventor_name text NOT NULL,
  jurisdiction text NOT NULL, -- 'IN','US','EP','WO','JP'
  application_no text,
  filing_status text NOT NULL, -- 'draft','filed','published','examined','granted','abandoned'
  filing_date date,
  priority_date date,
  examination_due_date date,
  estimated_grant_date date,
  legal_spend_rupees bigint NOT NULL DEFAULT 0,
  strategic_priority text NOT NULL, -- 'p0','p1','p2','p3'
  blocking_competitor text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE patent_filings_r2909 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: trade_secret_vault_r2909
-- ============================================================
CREATE TABLE IF NOT EXISTS trade_secret_vault_r2909 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  secret_code text NOT NULL,
  secret_name text NOT NULL,
  category text NOT NULL, -- 'algorithm','dataset','vendor_terms','pricing_model','process','formula'
  access_tier text NOT NULL, -- 'founder_only','exec','core_team','operational'
  custodian_name text NOT NULL,
  vault_location text NOT NULL, -- 'kms_aws','1password','sealed_envelope','offline_drive'
  last_rotation_date date,
  next_rotation_due date,
  ndas_in_place_count int NOT NULL DEFAULT 0,
  leak_risk_score int NOT NULL DEFAULT 0, -- 0-100
  audit_status text NOT NULL, -- 'green','amber','red'
  est_business_value_rupees bigint NOT NULL DEFAULT 0,
  last_audited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE trade_secret_vault_r2909 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED: patent_filings_r2909 (18 rows)
-- ============================================================
INSERT INTO patent_filings_r2909 (filing_code, title, inventor_name, jurisdiction, application_no, filing_status, filing_date, priority_date, examination_due_date, estimated_grant_date, legal_spend_rupees, strategic_priority, blocking_competitor, notes) VALUES
('PF-IN-001','Predictive AMC Tier Pricing Engine','G. Dhanavath','IN','202641034001','granted','2026-01-12'::date,'2025-11-04'::date,'2026-07-12'::date,'2027-09-12'::date,485000,'p0','Equipo Health','Core moat — covers tier rollover logic'),
('PF-US-002','Bonded Spare Parts Provenance Chain','G. Dhanavath','US','17/884,221','examined','2026-02-08'::date,'2026-01-10'::date,'2026-08-08'::date,'2027-12-08'::date,1240000,'p0','MedRepair Inc','PCT route — high blocking value'),
('PF-EP-003','Engineer Skill Ladder Auto-Promotion','G. Dhanavath','EP','EP3892145','filed','2026-03-15'::date,'2026-01-10'::date,'2026-09-15'::date,'2028-03-15'::date,890000,'p1','Siemens Healthineers','EPO search report awaited'),
('PF-WO-004','Hospital Chain Volume Discount Algorithm','G. Dhanavath','WO','PCT/IN2026/050022','filed','2026-04-02'::date,'2026-04-02'::date,'2026-10-02'::date,'2028-04-02'::date,675000,'p1',NULL,'PCT national phase Q3-2026'),
('PF-IN-005','Counterfeit Part QR Provenance','G. Dhanavath','IN','202641034002','published','2026-02-20'::date,'2026-02-20'::date,'2026-08-20'::date,'2027-08-20'::date,320000,'p0','SpareKart','First-to-file in India'),
('PF-US-006','Dynamic Engineer Routing Heuristic','G. Dhanavath','US','17/901,335','filed','2026-05-10'::date,'2026-05-10'::date,'2026-11-10'::date,'2028-05-10'::date,920000,'p2','UrbanCompany',NULL),
('PF-IN-007','NABH-Compliant Service Ledger','G. Dhanavath','IN','202641034003','draft',NULL,'2026-06-01'::date,'2026-12-01'::date,'2028-06-01'::date,45000,'p2',NULL,'Draft in counsel review'),
('PF-JP-008','Hospital Chain Bulk Audit System','G. Dhanavath','JP','2026-118445','filed','2026-04-22'::date,'2026-04-22'::date,'2026-10-22'::date,'2028-10-22'::date,1450000,'p2',NULL,'JP counsel: Yuasa & Hara'),
('PF-IN-009','GST Invoice Auto-Dispatch Pipeline','G. Dhanavath','IN','202641034004','granted','2025-12-05'::date,'2025-09-12'::date,'2026-06-05'::date,'2027-06-05'::date,210000,'p3',NULL,'Defensive filing'),
('PF-US-010','AMC Pool Ledger Reconciliation','G. Dhanavath','US','17/912,008','published','2026-03-30'::date,'2026-03-30'::date,'2026-09-30'::date,'2028-03-30'::date,780000,'p1','PMS Global',NULL),
('PF-EP-011','Engineer Liveness Multi-Factor Check','G. Dhanavath','EP','EP3899221','examined','2026-01-25'::date,'2025-10-18'::date,'2026-07-25'::date,'2027-07-25'::date,1120000,'p0','Wesco Anixter','EPO grant likely'),
('PF-WO-012','Code-Red Cross-Vendor Escalation','G. Dhanavath','WO','PCT/IN2026/050088','draft',NULL,'2026-05-30'::date,'2026-11-30'::date,'2028-05-30'::date,55000,'p2',NULL,'PCT route — moat against incumbents'),
('PF-IN-013','Engineer Payout Tier Calculator','G. Dhanavath','IN','202641034005','abandoned','2025-08-14'::date,'2025-05-20'::date,'2026-02-14'::date,NULL,180000,'p3',NULL,'Abandoned — prior-art found'),
('PF-US-014','Spot-Audit Engineer Rotation','G. Dhanavath','US','17/925,118','filed','2026-05-22'::date,'2026-05-22'::date,'2026-11-22'::date,'2028-05-22'::date,640000,'p1',NULL,NULL),
('PF-IN-015','AI Triage of Repair Job Disputes','G. Dhanavath','IN','202641034006','filed','2026-06-10'::date,'2026-06-10'::date,'2026-12-10'::date,'2028-06-10'::date,290000,'p1',NULL,'AI-claim — careful drafting'),
('PF-EP-016','Investor Data-Room Access Ledger','G. Dhanavath','EP','EP3905110','draft',NULL,'2026-06-15'::date,'2026-12-15'::date,'2028-12-15'::date,75000,'p3',NULL,'Defensive — low priority'),
('PF-JP-017','Hospital Discount Approval Queue','G. Dhanavath','JP','2026-122900','filed','2026-05-30'::date,'2026-05-30'::date,'2026-11-30'::date,'2028-11-30'::date,980000,'p2',NULL,NULL),
('PF-IN-018','Cashfree Payout Reaper Algorithm','G. Dhanavath','IN','202641034007','published','2026-04-18'::date,'2026-04-18'::date,'2026-10-18'::date,'2027-10-18'::date,235000,'p1','RazorpayX','Aggressive blocking play');

-- ============================================================
-- SEED: trade_secret_vault_r2909 (18 rows)
-- ============================================================
INSERT INTO trade_secret_vault_r2909 (secret_code, secret_name, category, access_tier, custodian_name, vault_location, last_rotation_date, next_rotation_due, ndas_in_place_count, leak_risk_score, audit_status, est_business_value_rupees, last_audited_at) VALUES
('TS-001','AMC tier rollover coefficients','algorithm','founder_only','G. Dhanavath','kms_aws','2026-04-01'::date,'2026-10-01'::date,1,12,'green',85000000,'2026-06-01 09:00:00+05:30'::timestamptz),
('TS-002','Engineer payout split table','pricing_model','exec','G. Dhanavath','1password','2026-03-15'::date,'2026-09-15'::date,4,28,'amber',42000000,'2026-05-28 10:00:00+05:30'::timestamptz),
('TS-003','Hospital chain master discount grid','pricing_model','exec','G. Dhanavath','kms_aws','2026-02-10'::date,'2026-08-10'::date,6,22,'green',68000000,'2026-06-05 11:00:00+05:30'::timestamptz),
('TS-004','Spare parts supplier cost basis','vendor_terms','founder_only','G. Dhanavath','sealed_envelope','2025-12-20'::date,'2026-06-20'::date,2,45,'red',55000000,'2026-04-15 09:00:00+05:30'::timestamptz),
('TS-005','Cashfree payout flow fingerprint','process','core_team','G. Dhanavath','kms_aws','2026-05-01'::date,'2026-11-01'::date,8,18,'green',12000000,'2026-06-10 12:00:00+05:30'::timestamptz),
('TS-006','Predictive churn model weights','algorithm','founder_only','G. Dhanavath','kms_aws','2026-04-22'::date,'2026-10-22'::date,1,8,'green',95000000,'2026-06-08 09:30:00+05:30'::timestamptz),
('TS-007','Bonded parts blockchain seed','algorithm','founder_only','G. Dhanavath','offline_drive','2026-01-05'::date,'2026-07-05'::date,1,15,'green',75000000,'2026-06-12 10:00:00+05:30'::timestamptz),
('TS-008','Engineer rotation entropy table','dataset','core_team','G. Dhanavath','1password','2026-03-28'::date,'2026-09-28'::date,5,32,'amber',18000000,'2026-05-30 11:30:00+05:30'::timestamptz),
('TS-009','Investor data-room watermark scheme','process','exec','G. Dhanavath','kms_aws','2026-05-15'::date,'2026-11-15'::date,3,20,'green',8000000,'2026-06-15 09:00:00+05:30'::timestamptz),
('TS-010','GST invoice auto-batching SQL','process','operational','G. Dhanavath','1password','2026-02-01'::date,'2026-08-01'::date,12,35,'amber',5000000,'2026-05-20 14:00:00+05:30'::timestamptz),
('TS-011','Code-Red escalation contact graph','dataset','exec','G. Dhanavath','kms_aws','2026-04-10'::date,'2026-10-10'::date,4,25,'green',22000000,'2026-06-02 10:30:00+05:30'::timestamptz),
('TS-012','Engineer tier promotion thresholds','formula','founder_only','G. Dhanavath','sealed_envelope','2025-11-15'::date,'2026-05-15'::date,1,55,'red',38000000,'2026-03-12 09:00:00+05:30'::timestamptz),
('TS-013','AMC pool reconciliation snapshot','process','exec','G. Dhanavath','kms_aws','2026-04-20'::date,'2026-10-20'::date,3,14,'green',28000000,'2026-06-09 11:00:00+05:30'::timestamptz),
('TS-014','Spot-audit invitation entropy','algorithm','founder_only','G. Dhanavath','offline_drive','2026-05-08'::date,'2026-11-08'::date,1,10,'green',15000000,'2026-06-14 09:30:00+05:30'::timestamptz),
('TS-015','Hospital chain LOI template clauses','vendor_terms','exec','G. Dhanavath','1password','2026-03-10'::date,'2026-09-10'::date,7,30,'amber',12000000,'2026-05-25 10:00:00+05:30'::timestamptz),
('TS-016','Counterfeit-part QR cryptokey','formula','founder_only','G. Dhanavath','kms_aws','2026-04-25'::date,'2026-10-25'::date,1,7,'green',62000000,'2026-06-11 09:00:00+05:30'::timestamptz),
('TS-017','Founder daily digest aggregation','process','core_team','G. Dhanavath','1password','2026-02-20'::date,'2026-08-20'::date,9,40,'amber',3500000,'2026-05-18 12:00:00+05:30'::timestamptz),
('TS-018','International pilot pricing model','pricing_model','founder_only','G. Dhanavath','sealed_envelope','2025-10-30'::date,'2026-04-30'::date,2,68,'red',45000000,'2026-02-28 09:00:00+05:30'::timestamptz);

-- ============================================================
-- is_founder fallback (no-op if exists)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='is_founder') THEN
    CREATE FUNCTION is_founder() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
    BEGIN
      RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'founder');
    END;
    $f$;
  END IF;
END $$;

-- ============================================================
-- RPC 1: patent_portfolio_overview_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION patent_portfolio_overview_r2909()
RETURNS TABLE (
  jurisdiction text,
  total_filings bigint,
  granted_count bigint,
  filed_count bigint,
  draft_count bigint,
  abandoned_count bigint,
  total_legal_spend_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT p.jurisdiction,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.filing_status='granted')::bigint,
         COUNT(*) FILTER (WHERE p.filing_status='filed')::bigint,
         COUNT(*) FILTER (WHERE p.filing_status='draft')::bigint,
         COUNT(*) FILTER (WHERE p.filing_status='abandoned')::bigint,
         COALESCE(SUM(p.legal_spend_rupees),0)::bigint
  FROM patent_filings_r2909 p
  GROUP BY p.jurisdiction
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION patent_portfolio_overview_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION patent_portfolio_overview_r2909() TO authenticated;

-- ============================================================
-- RPC 2: upcoming_patent_deadlines_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION upcoming_patent_deadlines_r2909()
RETURNS TABLE (
  id uuid,
  filing_code text,
  title text,
  jurisdiction text,
  filing_status text,
  examination_due_date date,
  days_until_due int,
  strategic_priority text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT p.id, p.filing_code, p.title, p.jurisdiction, p.filing_status,
         p.examination_due_date,
         (p.examination_due_date - CURRENT_DATE)::int,
         p.strategic_priority
  FROM patent_filings_r2909 p
  WHERE p.examination_due_date IS NOT NULL
    AND p.examination_due_date >= CURRENT_DATE
    AND p.filing_status NOT IN ('abandoned','granted')
  ORDER BY p.examination_due_date ASC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION upcoming_patent_deadlines_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION upcoming_patent_deadlines_r2909() TO authenticated;

-- ============================================================
-- RPC 3: high_priority_filings_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION high_priority_filings_r2909()
RETURNS TABLE (
  id uuid,
  filing_code text,
  title text,
  strategic_priority text,
  blocking_competitor text,
  filing_status text,
  legal_spend_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT p.id, p.filing_code, p.title, p.strategic_priority,
         p.blocking_competitor, p.filing_status, p.legal_spend_rupees
  FROM patent_filings_r2909 p
  WHERE p.strategic_priority IN ('p0','p1')
  ORDER BY p.strategic_priority ASC, p.legal_spend_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION high_priority_filings_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION high_priority_filings_r2909() TO authenticated;

-- ============================================================
-- RPC 4: vault_audit_summary_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION vault_audit_summary_r2909()
RETURNS TABLE (
  audit_status text,
  secret_count bigint,
  avg_leak_risk numeric,
  total_business_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT v.audit_status,
         COUNT(*)::bigint,
         ROUND(AVG(v.leak_risk_score)::numeric, 1),
         COALESCE(SUM(v.est_business_value_rupees),0)::bigint
  FROM trade_secret_vault_r2909 v
  GROUP BY v.audit_status
  ORDER BY CASE v.audit_status WHEN 'red' THEN 1 WHEN 'amber' THEN 2 ELSE 3 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION vault_audit_summary_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION vault_audit_summary_r2909() TO authenticated;

-- ============================================================
-- RPC 5: red_secrets_needing_rotation_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION red_secrets_needing_rotation_r2909()
RETURNS TABLE (
  id uuid,
  secret_code text,
  secret_name text,
  access_tier text,
  next_rotation_due date,
  days_overdue int,
  leak_risk_score int,
  audit_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT v.id, v.secret_code, v.secret_name, v.access_tier,
         v.next_rotation_due,
         GREATEST(0, (CURRENT_DATE - v.next_rotation_due))::int,
         v.leak_risk_score, v.audit_status
  FROM trade_secret_vault_r2909 v
  WHERE v.audit_status IN ('red','amber') OR v.next_rotation_due <= CURRENT_DATE
  ORDER BY v.leak_risk_score DESC, v.next_rotation_due ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION red_secrets_needing_rotation_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION red_secrets_needing_rotation_r2909() TO authenticated;

-- ============================================================
-- RPC 6: vault_by_category_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION vault_by_category_r2909()
RETURNS TABLE (
  category text,
  secret_count bigint,
  founder_only_count bigint,
  avg_ndas numeric,
  total_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT v.category,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE v.access_tier='founder_only')::bigint,
         ROUND(AVG(v.ndas_in_place_count)::numeric, 1),
         COALESCE(SUM(v.est_business_value_rupees),0)::bigint
  FROM trade_secret_vault_r2909 v
  GROUP BY v.category
  ORDER BY SUM(v.est_business_value_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION vault_by_category_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION vault_by_category_r2909() TO authenticated;

-- ============================================================
-- RPC 7: quarterly_audit_kpis_r2909
-- ============================================================
CREATE OR REPLACE FUNCTION quarterly_audit_kpis_r2909()
RETURNS TABLE (
  total_filings bigint,
  granted_count bigint,
  p0_p1_count bigint,
  total_legal_spend_rupees bigint,
  total_secrets bigint,
  red_secrets bigint,
  founder_only_secrets bigint,
  total_secret_value_rupees bigint,
  avg_leak_risk numeric,
  filings_due_90d bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM patent_filings_r2909),
    (SELECT COUNT(*)::bigint FROM patent_filings_r2909 WHERE filing_status='granted'),
    (SELECT COUNT(*)::bigint FROM patent_filings_r2909 WHERE strategic_priority IN ('p0','p1')),
    (SELECT COALESCE(SUM(legal_spend_rupees),0)::bigint FROM patent_filings_r2909),
    (SELECT COUNT(*)::bigint FROM trade_secret_vault_r2909),
    (SELECT COUNT(*)::bigint FROM trade_secret_vault_r2909 WHERE audit_status='red'),
    (SELECT COUNT(*)::bigint FROM trade_secret_vault_r2909 WHERE access_tier='founder_only'),
    (SELECT COALESCE(SUM(est_business_value_rupees),0)::bigint FROM trade_secret_vault_r2909),
    (SELECT ROUND(AVG(leak_risk_score)::numeric, 1) FROM trade_secret_vault_r2909),
    (SELECT COUNT(*)::bigint FROM patent_filings_r2909
       WHERE examination_due_date IS NOT NULL
         AND examination_due_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + 90));
END;
$$;

REVOKE EXECUTE ON FUNCTION quarterly_audit_kpis_r2909() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION quarterly_audit_kpis_r2909() TO authenticated;
