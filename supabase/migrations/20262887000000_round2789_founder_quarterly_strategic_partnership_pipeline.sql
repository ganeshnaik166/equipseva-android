BEGIN;

-- ============================================================================
-- Round 2789 — Founder Quarterly Strategic Partnership Pipeline
-- partner x stage x strategic value x terms x commit x success x business impact
-- ============================================================================

-- ---------- Table 1: partnership pipeline ------------------------------------
CREATE TABLE IF NOT EXISTS founder_strategic_partnership_pipeline_r2789 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_name text NOT NULL,
  partner_category text NOT NULL CHECK (partner_category IN ('oem','distributor','hospital_chain','insurer','government','platform','academic','logistics')),
  region text NOT NULL,
  stage text NOT NULL CHECK (stage IN ('prospect','intro','discovery','term_sheet','contract','signed','live','stalled','lost')),
  strategic_value text NOT NULL CHECK (strategic_value IN ('low','medium','high','critical')),
  strategic_theme text NOT NULL,
  commit_arr_rupees bigint NOT NULL DEFAULT 0,
  commit_units_per_quarter int NOT NULL DEFAULT 0,
  exclusivity boolean NOT NULL DEFAULT false,
  expected_close_date date,
  champion_name text,
  next_step text,
  next_step_due_date date,
  probability_pct int NOT NULL DEFAULT 0 CHECK (probability_pct BETWEEN 0 AND 100),
  business_impact_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_strategic_partnership_pipeline_r2789 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_strategic_partnership_pipeline_r2789;
CREATE POLICY founder_all ON founder_strategic_partnership_pipeline_r2789
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_strategic_partnership_pipeline_r2789
  (partner_name, partner_category, region, stage, strategic_value, strategic_theme, commit_arr_rupees, commit_units_per_quarter, exclusivity, expected_close_date, champion_name, next_step, next_step_due_date, probability_pct, business_impact_rupees, notes)
VALUES
  ('Siemens Healthineers India','oem','South India','term_sheet','critical','Authorized service partner for CT/MRI in Telangana + AP', 22000000, 40, true, '2026-07-31'::date, 'Anant Rao','Counter on exclusivity radius', '2026-06-28'::date, 65, 38000000, 'Pushing 50km radius vs their 100km ask'),
  ('Apollo Hospitals Chain','hospital_chain','Pan-India','discovery','critical','Enterprise AMC across 71 hospitals',  68000000, 0, false, '2026-09-15'::date, 'Dr. Preetha Reddy office','Vendor onboarding form + ISO27001 dossier', '2026-07-05'::date, 45, 92000000, 'Procurement says decision in Q3'),
  ('Star Health Insurance','insurer','Pan-India','signed','high','Cashless biomed insurance attach', 9500000, 0, false, '2026-06-10'::date, 'Anand Roy','Kickoff with claims team', '2026-06-25'::date, 100, 14000000, 'Signed June 10, live July 1'),
  ('Telangana Med-Tech Park','government','South India','contract','high','Anchor service tenant + state subsidy', 5500000, 0, false, '2026-07-20'::date, 'Shanta Thoutam IAS','Lease + subsidy MoU signature', '2026-07-15'::date, 80, 9000000, 'TS-iPASS clearance pending'),
  ('Delhivery Healthcare','logistics','Pan-India','intro','medium','Cold-chain spare part SLA 24h', 0, 600, false, '2026-08-30'::date, 'Sahil Barua office','Pricing RFQ workshop', '2026-07-10'::date, 30, 3500000, 'Replaces existing 3PL'),
  ('IIT Hyderabad CfHE','academic','South India','prospect','medium','Joint biomed AI research + talent pipe', 0, 0, false, '2026-10-01'::date, 'Prof Renu John','Faculty intro deck', '2026-07-18'::date, 20, 2000000, 'PhD intern pipeline'),
  ('Practo Health Platform','platform','Pan-India','stalled','low','Engineer marketplace cross-list', 1200000, 0, false, NULL, 'Shashank ND team','Reactivate after Q3 board', '2026-09-01'::date, 10, 1500000, 'Paused — their priority shifted to OPD'),
  ('GE Healthcare South Asia','oem','Pan-India','discovery','critical','OEM authorized partner — ultrasound + cath lab', 31000000, 80, false, '2026-08-25'::date, 'Chaitanya Sarawate','Technical capability audit', '2026-07-22'::date, 50, 54000000, 'Competing with Trivitron'),
  ('Manipal Hospitals','hospital_chain','Pan-India','term_sheet','high','AMC across 28 hospitals', 18000000, 0, false, '2026-07-30'::date, 'Dilip Jose','Pricing revision', '2026-07-02'::date, 55, 26000000, NULL);

-- ---------- Table 2: milestones ---------------------------------------------
CREATE TABLE IF NOT EXISTS founder_partnership_milestones_r2789 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES founder_strategic_partnership_pipeline_r2789(id) ON DELETE CASCADE,
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('intro_call','demo','site_visit','nda','term_sheet','legal_review','signature','kickoff','first_invoice','renewal')),
  milestone_title text NOT NULL,
  scheduled_date date NOT NULL,
  completed_date date,
  status text NOT NULL CHECK (status IN ('scheduled','done','slipped','blocked')) DEFAULT 'scheduled',
  blocker text,
  owner_name text,
  success_metric text,
  success_metric_target text,
  success_metric_actual text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_partnership_milestones_r2789 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_partnership_milestones_r2789;
CREATE POLICY founder_all ON founder_partnership_milestones_r2789
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_partnership_milestones_r2789
  (pipeline_id, milestone_kind, milestone_title, scheduled_date, completed_date, status, blocker, owner_name, success_metric, success_metric_target, success_metric_actual, notes)
SELECT p.id, 'term_sheet', 'Siemens term sheet exchange', '2026-06-20'::date, '2026-06-22'::date, 'done', NULL, 'Ganesh', 'Term sheet executed', 'signed', 'signed', 'Exclusivity radius negotiated to 75km' FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='Siemens Healthineers India'
UNION ALL
SELECT p.id, 'site_visit', 'Apollo Chennai HQ site visit', '2026-06-30'::date, NULL, 'scheduled', NULL, 'Ganesh', 'Procurement scorecard pass', 'top-3', NULL, 'Demo in their biomed lab' FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='Apollo Hospitals Chain'
UNION ALL
SELECT p.id, 'kickoff', 'Star Health claims integration kickoff', '2026-06-25'::date, NULL, 'scheduled', NULL, 'Ganesh', 'API contract finalized', 'v1.0', NULL, 'Cashless flow' FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='Star Health Insurance'
UNION ALL
SELECT p.id, 'legal_review', 'TS-MedTechPark lease legal', '2026-07-12'::date, NULL, 'blocked', 'TS-iPASS approval awaited', 'Legal Counsel', 'Lease executed', 'executed', NULL, 'Government queue' FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='Telangana Med-Tech Park'
UNION ALL
SELECT p.id, 'demo', 'Delhivery cold-chain workshop', '2026-07-10'::date, NULL, 'scheduled', NULL, 'Ganesh', 'Pricing RFQ', '< Rs 180/kg', NULL, 'Benchmark vs Bluedart' FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='Delhivery Healthcare'
UNION ALL
SELECT p.id, 'intro_call', 'IIT Hyderabad CfHE intro', '2026-07-18'::date, NULL, 'scheduled', NULL, 'Ganesh', 'MoU draft', 'circulated', NULL, NULL FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='IIT Hyderabad CfHE'
UNION ALL
SELECT p.id, 'nda', 'GE Healthcare NDA', '2026-06-18'::date, '2026-06-19'::date, 'done', NULL, 'Ganesh', 'NDA executed', 'signed', 'signed', NULL FROM founder_strategic_partnership_pipeline_r2789 p WHERE partner_name='GE Healthcare South Asia';

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1) pipeline summary KPIs
DROP FUNCTION IF EXISTS founder_psp_summary_r2789();
CREATE OR REPLACE FUNCTION founder_psp_summary_r2789()
RETURNS TABLE(
  total_partners int,
  active_partners int,
  signed_partners int,
  stalled_partners int,
  total_commit_arr_rupees bigint,
  weighted_pipeline_rupees bigint,
  business_impact_rupees bigint,
  critical_count int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE stage NOT IN ('lost','stalled'))::int,
    COUNT(*) FILTER (WHERE stage IN ('signed','live'))::int,
    COUNT(*) FILTER (WHERE stage='stalled')::int,
    COALESCE(SUM(commit_arr_rupees),0)::bigint,
    COALESCE(SUM(commit_arr_rupees * probability_pct / 100),0)::bigint,
    COALESCE(SUM(business_impact_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE strategic_value='critical')::int
  FROM founder_strategic_partnership_pipeline_r2789;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_summary_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_summary_r2789() TO authenticated;

-- 2) pipeline by stage
DROP FUNCTION IF EXISTS founder_psp_by_stage_r2789();
CREATE OR REPLACE FUNCTION founder_psp_by_stage_r2789()
RETURNS TABLE(
  stage text,
  partners int,
  commit_arr_rupees bigint,
  weighted_arr_rupees bigint,
  avg_probability_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.stage,
    COUNT(*)::int,
    COALESCE(SUM(p.commit_arr_rupees),0)::bigint,
    COALESCE(SUM(p.commit_arr_rupees * p.probability_pct / 100),0)::bigint,
    ROUND(AVG(p.probability_pct)::numeric, 1)
  FROM founder_strategic_partnership_pipeline_r2789 p
  GROUP BY p.stage
  ORDER BY 3 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_by_stage_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_by_stage_r2789() TO authenticated;

-- 3) pipeline by category
DROP FUNCTION IF EXISTS founder_psp_by_category_r2789();
CREATE OR REPLACE FUNCTION founder_psp_by_category_r2789()
RETURNS TABLE(
  partner_category text,
  partners int,
  weighted_arr_rupees bigint,
  business_impact_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.partner_category,
    COUNT(*)::int,
    COALESCE(SUM(p.commit_arr_rupees * p.probability_pct / 100),0)::bigint,
    COALESCE(SUM(p.business_impact_rupees),0)::bigint
  FROM founder_strategic_partnership_pipeline_r2789 p
  GROUP BY p.partner_category
  ORDER BY 3 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_by_category_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_by_category_r2789() TO authenticated;

-- 4) top critical pipeline
DROP FUNCTION IF EXISTS founder_psp_critical_r2789();
CREATE OR REPLACE FUNCTION founder_psp_critical_r2789()
RETURNS TABLE(
  partner_name text,
  partner_category text,
  stage text,
  commit_arr_rupees bigint,
  probability_pct int,
  expected_close_date date,
  next_step text,
  next_step_due_date date,
  business_impact_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.partner_name, p.partner_category, p.stage, p.commit_arr_rupees, p.probability_pct, p.expected_close_date, p.next_step, p.next_step_due_date, p.business_impact_rupees
  FROM founder_strategic_partnership_pipeline_r2789 p
  WHERE p.strategic_value IN ('critical','high')
  ORDER BY p.commit_arr_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_critical_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_critical_r2789() TO authenticated;

-- 5) upcoming milestones
DROP FUNCTION IF EXISTS founder_psp_upcoming_milestones_r2789();
CREATE OR REPLACE FUNCTION founder_psp_upcoming_milestones_r2789()
RETURNS TABLE(
  partner_name text,
  milestone_kind text,
  milestone_title text,
  scheduled_date date,
  status text,
  blocker text,
  owner_name text,
  days_until int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.partner_name, m.milestone_kind, m.milestone_title, m.scheduled_date, m.status, m.blocker, m.owner_name,
         (m.scheduled_date - CURRENT_DATE)::int
  FROM founder_partnership_milestones_r2789 m
  JOIN founder_strategic_partnership_pipeline_r2789 p ON p.id = m.pipeline_id
  WHERE m.status IN ('scheduled','blocked')
  ORDER BY m.scheduled_date ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_upcoming_milestones_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_upcoming_milestones_r2789() TO authenticated;

-- 6) blocked partners
DROP FUNCTION IF EXISTS founder_psp_blocked_r2789();
CREATE OR REPLACE FUNCTION founder_psp_blocked_r2789()
RETURNS TABLE(
  partner_name text,
  stage text,
  blocker text,
  milestone_title text,
  scheduled_date date,
  business_impact_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.partner_name, p.stage, m.blocker, m.milestone_title, m.scheduled_date, p.business_impact_rupees
  FROM founder_partnership_milestones_r2789 m
  JOIN founder_strategic_partnership_pipeline_r2789 p ON p.id = m.pipeline_id
  WHERE m.status='blocked' OR p.stage='stalled'
  ORDER BY p.business_impact_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_blocked_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_blocked_r2789() TO authenticated;

-- 7) win-rate by category
DROP FUNCTION IF EXISTS founder_psp_winrate_r2789();
CREATE OR REPLACE FUNCTION founder_psp_winrate_r2789()
RETURNS TABLE(
  partner_category text,
  total int,
  signed int,
  lost int,
  win_rate_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.partner_category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.stage IN ('signed','live'))::int,
         COUNT(*) FILTER (WHERE p.stage='lost')::int,
         CASE WHEN COUNT(*) FILTER (WHERE p.stage IN ('signed','live','lost')) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE p.stage IN ('signed','live')) / COUNT(*) FILTER (WHERE p.stage IN ('signed','live','lost')), 1)
         END
  FROM founder_strategic_partnership_pipeline_r2789 p
  GROUP BY p.partner_category
  ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_winrate_r2789() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_winrate_r2789() TO authenticated;

-- 8) advance stage RPC
DROP FUNCTION IF EXISTS founder_psp_advance_stage_r2789(uuid, text);
CREATE OR REPLACE FUNCTION founder_psp_advance_stage_r2789(p_id uuid, p_new_stage text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_strategic_partnership_pipeline_r2789
     SET stage = p_new_stage, updated_at = now()
   WHERE id = p_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_psp_advance_stage_r2789(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_psp_advance_stage_r2789(uuid, text) TO authenticated;

COMMIT;
