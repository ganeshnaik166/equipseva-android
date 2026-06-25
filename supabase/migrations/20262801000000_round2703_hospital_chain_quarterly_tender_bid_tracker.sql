BEGIN;

-- Round r2703: Hospital Chain Quarterly Tender Bid Tracker
-- Tracks chain x tender x bid value x win probability x competitor x outcome x learning

-- ============================================================
-- Table 1: hospital_chain_tender_bids_r2703
-- ============================================================
DROP TABLE IF EXISTS hospital_chain_tender_bids_r2703 CASCADE;

CREATE TABLE hospital_chain_tender_bids_r2703 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3','government','trust')),
  tender_code text NOT NULL,
  tender_title text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1','Q2','Q3','Q4')),
  fiscal_year text NOT NULL,
  tender_value_rupees bigint NOT NULL CHECK (tender_value_rupees >= 0),
  our_bid_rupees bigint NOT NULL CHECK (our_bid_rupees >= 0),
  win_probability_pct integer NOT NULL CHECK (win_probability_pct BETWEEN 0 AND 100),
  competitor_count integer NOT NULL CHECK (competitor_count >= 0),
  lead_competitor text,
  competitor_bid_rupees bigint,
  outcome text NOT NULL CHECK (outcome IN ('pending','submitted','shortlisted','won','lost','withdrawn','cancelled')),
  submitted_at date,
  decision_at date,
  margin_pct numeric(5,2),
  region text NOT NULL,
  decision_maker text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tender_bids_r2703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_tender_bids_r2703;
CREATE POLICY founder_all ON hospital_chain_tender_bids_r2703
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_tender_bids_r2703
  (chain_name, chain_tier, tender_code, tender_title, quarter, fiscal_year,
   tender_value_rupees, our_bid_rupees, win_probability_pct, competitor_count,
   lead_competitor, competitor_bid_rupees, outcome, submitted_at, decision_at,
   margin_pct, region, decision_maker, notes)
VALUES
  ('Apollo Hospitals','tier1','APL-Q1-2027-001','AMC Bundle 142 Devices','Q1','FY27',
   18500000, 17400000, 72, 4, 'TruMed Services', 18200000, 'shortlisted',
   '2026-06-12'::date, '2026-07-05'::date, 14.20, 'South', 'Dr. Krishna (CTO)', 'Strong incumbent pricing pressure'),
  ('Fortis Healthcare','tier1','FRT-Q1-2027-014','OR Equipment Calibration','Q1','FY27',
   9800000, 9200000, 64, 3, 'BioMed Allied', 9450000, 'submitted',
   '2026-06-15'::date, NULL, 11.80, 'North', 'Mr. Anand Bhatia', 'Demo scheduled June 28'),
  ('Manipal Hospitals','tier1','MNP-Q4-2026-088','Critical Care Suite SLA','Q4','FY26',
   24500000, 23100000, 81, 5, 'Siemens Healthineers', 23800000, 'won',
   '2026-04-22'::date, '2026-05-30'::date, 16.50, 'South', 'Dr. Rao (Procurement)', 'Won on response-time SLA'),
  ('Max Healthcare','tier1','MAX-Q1-2027-022','Dental Chair Network AMC','Q1','FY27',
   6700000, 6450000, 38, 6, 'Planmeca Direct', 6100000, 'lost',
   '2026-06-02'::date, '2026-06-18'::date, 9.40, 'North', 'Mr. Sharma (Sourcing)', 'Lost on price by 5.4%'),
  ('Yashoda Hospitals','tier2','YSH-Q2-2027-005','Endoscopy Repair Annual','Q2','FY27',
   4200000, 3950000, 68, 2, 'Olympus Service India', 4050000, 'pending',
   NULL, NULL, 12.10, 'South', 'Dr. Naidu', 'Site walk-through July 8'),
  ('AIIMS Delhi','government','AIIMS-Q1-2027-101','Imaging Block AMC','Q1','FY27',
   31200000, 29800000, 55, 7, 'Wipro GE Healthcare', 30100000, 'submitted',
   '2026-06-10'::date, NULL, 8.70, 'North', 'DGM Procurement', 'GeM portal e-tender'),
  ('Narayana Health','tier2','NRY-Q4-2026-067','Cath Lab Rotation AMC','Q4','FY26',
   12800000, 12100000, 74, 4, 'Philips Healthcare', 12400000, 'won',
   '2026-03-18'::date, '2026-04-22'::date, 13.60, 'South', 'Mr. Mahadevan', 'Multi-site rotation play won'),
  ('Tata Memorial','trust','TMC-Q2-2027-009','Oncology Equipment SLA','Q2','FY27',
   15600000, 14900000, 49, 5, 'Varian Service', 14750000, 'pending',
   NULL, NULL, 10.20, 'West', 'Dr. Mehta', 'Awaiting RFP clarification'),
  ('KIMS Hyderabad','tier2','KIMS-Q1-2027-033','Multi-modality Imaging','Q1','FY27',
   8400000, 7900000, 62, 3, 'GE Healthcare Direct', 8050000, 'shortlisted',
   '2026-06-08'::date, '2026-07-12'::date, 12.80, 'South', 'Mr. Bhaskar Rao', 'Reference site visit pending');

-- ============================================================
-- Table 2: hospital_chain_tender_learnings_r2703
-- ============================================================
DROP TABLE IF EXISTS hospital_chain_tender_learnings_r2703 CASCADE;

CREATE TABLE hospital_chain_tender_learnings_r2703 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bid_id uuid REFERENCES hospital_chain_tender_bids_r2703(id) ON DELETE SET NULL,
  chain_name text NOT NULL,
  learning_category text NOT NULL CHECK (learning_category IN ('pricing','technical','relationship','timing','competitor_intel','process')),
  learning_title text NOT NULL,
  learning_detail text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('insight','action','warning','critical')),
  action_owner text NOT NULL,
  action_status text NOT NULL CHECK (action_status IN ('open','in_progress','closed','deferred')),
  captured_at date NOT NULL,
  closed_at date,
  impact_estimate_rupees bigint,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tender_learnings_r2703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_tender_learnings_r2703;
CREATE POLICY founder_all ON hospital_chain_tender_learnings_r2703
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_tender_learnings_r2703
  (chain_name, learning_category, learning_title, learning_detail, severity,
   action_owner, action_status, captured_at, closed_at, impact_estimate_rupees)
VALUES
  ('Max Healthcare','pricing','Sub-5% gap loses to Planmeca','Lost MAX-Q1-2027-022 by 5.4% on price; Planmeca bundled training for free.',
   'critical','Founder','open','2026-06-18'::date, NULL, 6700000),
  ('Apollo Hospitals','competitor_intel','TruMed offering 4hr SLA','TruMed undercut SLA on incumbent renewals; we must match or beat.',
   'warning','VP Sales','in_progress','2026-06-13'::date, NULL, 18500000),
  ('Manipal Hospitals','technical','Response-time SLA wins it','Manipal weighted response-time 35% in scoring; bundle this in all bids.',
   'insight','Sales Ops','closed','2026-06-01'::date, '2026-06-10'::date, 24500000),
  ('AIIMS Delhi','process','GeM e-tender quirks','GeM portal requires DSC class-3; near-miss on submission deadline.',
   'action','Operations','in_progress','2026-06-11'::date, NULL, 31200000),
  ('Narayana Health','relationship','Multi-site rotation play resonates','Mahadevan values single-vendor accountability; replicate with KIMS.',
   'action','Founder','open','2026-04-25'::date, NULL, 12800000),
  ('Yashoda Hospitals','timing','Site walk before quote','Yashoda procurement insists on site walk-through before bid; add as default.',
   'insight','Field Ops','open','2026-06-17'::date, NULL, 4200000),
  ('Tata Memorial','technical','Oncology SLA needs RT cert','TMC requires certified RT-trained engineers; capacity gap.',
   'critical','HR','open','2026-06-14'::date, NULL, 15600000);

CREATE INDEX IF NOT EXISTS idx_bids_outcome_r2703 ON hospital_chain_tender_bids_r2703 (outcome);
CREATE INDEX IF NOT EXISTS idx_bids_quarter_r2703 ON hospital_chain_tender_bids_r2703 (fiscal_year, quarter);
CREATE INDEX IF NOT EXISTS idx_learnings_severity_r2703 ON hospital_chain_tender_learnings_r2703 (severity);

-- ============================================================
-- RPC 1: list_open_tender_bids_r2703
-- ============================================================
DROP FUNCTION IF EXISTS list_open_tender_bids_r2703();
CREATE OR REPLACE FUNCTION list_open_tender_bids_r2703()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  tender_code text,
  tender_title text,
  quarter text,
  fiscal_year text,
  tender_value_rupees bigint,
  our_bid_rupees bigint,
  win_probability_pct integer,
  outcome text,
  submitted_at date,
  decision_at date,
  region text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.chain_name, b.chain_tier, b.tender_code, b.tender_title,
         b.quarter, b.fiscal_year, b.tender_value_rupees, b.our_bid_rupees,
         b.win_probability_pct, b.outcome, b.submitted_at, b.decision_at, b.region
  FROM hospital_chain_tender_bids_r2703 b
  WHERE b.outcome IN ('pending','submitted','shortlisted')
  ORDER BY b.win_probability_pct DESC, b.tender_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_open_tender_bids_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_open_tender_bids_r2703() TO authenticated;

-- ============================================================
-- RPC 2: tender_pipeline_kpis_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_pipeline_kpis_r2703();
CREATE OR REPLACE FUNCTION tender_pipeline_kpis_r2703()
RETURNS TABLE (
  total_bids integer,
  open_bids integer,
  total_pipeline_value_rupees bigint,
  weighted_pipeline_rupees bigint,
  won_value_rupees bigint,
  lost_value_rupees bigint,
  win_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
  v_open integer;
  v_pipe bigint;
  v_weighted bigint;
  v_won bigint;
  v_lost bigint;
  v_decided integer;
  v_won_count integer;
  v_rate numeric;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*) INTO v_total FROM hospital_chain_tender_bids_r2703;
  SELECT COUNT(*) INTO v_open FROM hospital_chain_tender_bids_r2703
    WHERE outcome IN ('pending','submitted','shortlisted');
  SELECT COALESCE(SUM(our_bid_rupees),0) INTO v_pipe FROM hospital_chain_tender_bids_r2703
    WHERE outcome IN ('pending','submitted','shortlisted');
  SELECT COALESCE(SUM(our_bid_rupees * win_probability_pct / 100),0) INTO v_weighted
    FROM hospital_chain_tender_bids_r2703
    WHERE outcome IN ('pending','submitted','shortlisted');
  SELECT COALESCE(SUM(our_bid_rupees),0) INTO v_won FROM hospital_chain_tender_bids_r2703
    WHERE outcome = 'won';
  SELECT COALESCE(SUM(our_bid_rupees),0) INTO v_lost FROM hospital_chain_tender_bids_r2703
    WHERE outcome = 'lost';
  SELECT COUNT(*) INTO v_decided FROM hospital_chain_tender_bids_r2703
    WHERE outcome IN ('won','lost');
  SELECT COUNT(*) INTO v_won_count FROM hospital_chain_tender_bids_r2703
    WHERE outcome = 'won';
  v_rate := CASE WHEN v_decided = 0 THEN 0 ELSE round(v_won_count::numeric * 100.0 / v_decided, 2) END;

  RETURN QUERY SELECT v_total, v_open, v_pipe, v_weighted, v_won, v_lost, v_rate;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_pipeline_kpis_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_pipeline_kpis_r2703() TO authenticated;

-- ============================================================
-- RPC 3: tender_bids_by_chain_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_bids_by_chain_r2703();
CREATE OR REPLACE FUNCTION tender_bids_by_chain_r2703()
RETURNS TABLE (
  chain_name text,
  chain_tier text,
  bids_count integer,
  open_count integer,
  won_count integer,
  lost_count integer,
  pipeline_rupees bigint,
  won_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.chain_name,
         MAX(b.chain_tier) AS chain_tier,
         COUNT(*)::integer AS bids_count,
         COUNT(*) FILTER (WHERE b.outcome IN ('pending','submitted','shortlisted'))::integer AS open_count,
         COUNT(*) FILTER (WHERE b.outcome = 'won')::integer AS won_count,
         COUNT(*) FILTER (WHERE b.outcome = 'lost')::integer AS lost_count,
         COALESCE(SUM(b.our_bid_rupees) FILTER (WHERE b.outcome IN ('pending','submitted','shortlisted')),0)::bigint AS pipeline_rupees,
         COALESCE(SUM(b.our_bid_rupees) FILTER (WHERE b.outcome = 'won'),0)::bigint AS won_rupees
  FROM hospital_chain_tender_bids_r2703 b
  GROUP BY b.chain_name
  ORDER BY pipeline_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_bids_by_chain_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_bids_by_chain_r2703() TO authenticated;

-- ============================================================
-- RPC 4: tender_competitor_threat_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_competitor_threat_r2703();
CREATE OR REPLACE FUNCTION tender_competitor_threat_r2703()
RETURNS TABLE (
  lead_competitor text,
  encounters integer,
  wins_against integer,
  losses_against integer,
  total_competing_value_rupees bigint,
  avg_competitor_bid_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.lead_competitor,
         COUNT(*)::integer AS encounters,
         COUNT(*) FILTER (WHERE b.outcome = 'won')::integer AS wins_against,
         COUNT(*) FILTER (WHERE b.outcome = 'lost')::integer AS losses_against,
         COALESCE(SUM(b.tender_value_rupees),0)::bigint AS total_competing_value_rupees,
         COALESCE(AVG(b.competitor_bid_rupees),0)::bigint AS avg_competitor_bid_rupees
  FROM hospital_chain_tender_bids_r2703 b
  WHERE b.lead_competitor IS NOT NULL
  GROUP BY b.lead_competitor
  ORDER BY encounters DESC, total_competing_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_competitor_threat_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_competitor_threat_r2703() TO authenticated;

-- ============================================================
-- RPC 5: tender_quarterly_breakdown_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_quarterly_breakdown_r2703();
CREATE OR REPLACE FUNCTION tender_quarterly_breakdown_r2703()
RETURNS TABLE (
  fiscal_year text,
  quarter text,
  bids integer,
  pipeline_rupees bigint,
  weighted_rupees bigint,
  won_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.fiscal_year, b.quarter,
         COUNT(*)::integer AS bids,
         COALESCE(SUM(b.our_bid_rupees),0)::bigint AS pipeline_rupees,
         COALESCE(SUM(b.our_bid_rupees * b.win_probability_pct / 100),0)::bigint AS weighted_rupees,
         COALESCE(SUM(b.our_bid_rupees) FILTER (WHERE b.outcome = 'won'),0)::bigint AS won_rupees
  FROM hospital_chain_tender_bids_r2703 b
  GROUP BY b.fiscal_year, b.quarter
  ORDER BY b.fiscal_year DESC, b.quarter DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_quarterly_breakdown_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_quarterly_breakdown_r2703() TO authenticated;

-- ============================================================
-- RPC 6: list_open_tender_learnings_r2703
-- ============================================================
DROP FUNCTION IF EXISTS list_open_tender_learnings_r2703();
CREATE OR REPLACE FUNCTION list_open_tender_learnings_r2703()
RETURNS TABLE (
  id uuid,
  chain_name text,
  learning_category text,
  learning_title text,
  severity text,
  action_owner text,
  action_status text,
  captured_at date,
  impact_estimate_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.learning_category, l.learning_title,
         l.severity, l.action_owner, l.action_status, l.captured_at, l.impact_estimate_rupees
  FROM hospital_chain_tender_learnings_r2703 l
  WHERE l.action_status IN ('open','in_progress')
  ORDER BY
    CASE l.severity WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 WHEN 'action' THEN 3 ELSE 4 END,
    l.captured_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_open_tender_learnings_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_open_tender_learnings_r2703() TO authenticated;

-- ============================================================
-- RPC 7: tender_decided_outcomes_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_decided_outcomes_r2703();
CREATE OR REPLACE FUNCTION tender_decided_outcomes_r2703()
RETURNS TABLE (
  id uuid,
  chain_name text,
  tender_code text,
  tender_title text,
  outcome text,
  our_bid_rupees bigint,
  competitor_bid_rupees bigint,
  lead_competitor text,
  margin_pct numeric,
  decision_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.chain_name, b.tender_code, b.tender_title, b.outcome,
         b.our_bid_rupees, b.competitor_bid_rupees, b.lead_competitor,
         b.margin_pct, b.decision_at
  FROM hospital_chain_tender_bids_r2703 b
  WHERE b.outcome IN ('won','lost','withdrawn','cancelled')
  ORDER BY b.decision_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_decided_outcomes_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_decided_outcomes_r2703() TO authenticated;

-- ============================================================
-- RPC 8: tender_learnings_by_category_r2703
-- ============================================================
DROP FUNCTION IF EXISTS tender_learnings_by_category_r2703();
CREATE OR REPLACE FUNCTION tender_learnings_by_category_r2703()
RETURNS TABLE (
  learning_category text,
  total_count integer,
  open_count integer,
  critical_count integer,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT l.learning_category,
         COUNT(*)::integer AS total_count,
         COUNT(*) FILTER (WHERE l.action_status IN ('open','in_progress'))::integer AS open_count,
         COUNT(*) FILTER (WHERE l.severity = 'critical')::integer AS critical_count,
         COALESCE(SUM(l.impact_estimate_rupees),0)::bigint AS total_impact_rupees
  FROM hospital_chain_tender_learnings_r2703 l
  GROUP BY l.learning_category
  ORDER BY total_impact_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION tender_learnings_by_category_r2703() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tender_learnings_by_category_r2703() TO authenticated;

COMMIT;
