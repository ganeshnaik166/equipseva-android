BEGIN;

-- ============================================================================
-- Round 2751 — Hospital Chain Quarterly Clinical Leader Relationship
-- chain × leader × tenure × touchpoint × ask × commitment × outcome
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: clinical leader profiles per chain
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_chain_clinical_leaders_r2751 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  leader_name text NOT NULL,
  leader_role text NOT NULL CHECK (leader_role IN ('chief_medical_officer','head_of_biomed','director_clinical_ops','chief_nursing_officer','dean_clinical','head_radiology','head_cardiology','head_anaesthesia')),
  tenure_months int NOT NULL CHECK (tenure_months >= 0),
  influence_tier text NOT NULL CHECK (influence_tier IN ('decider','influencer','champion','gatekeeper','blocker')),
  warmth_score numeric(3,1) NOT NULL CHECK (warmth_score >= 0 AND warmth_score <= 10),
  last_touchpoint_at timestamptz,
  next_touchpoint_due_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_clinical_leaders_r2751 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_clinical_leaders_r2751;
CREATE POLICY founder_all ON hospital_chain_clinical_leaders_r2751
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_clinical_leaders_r2751
  (chain_name, leader_name, leader_role, tenure_months, influence_tier, warmth_score, last_touchpoint_at, next_touchpoint_due_at, notes)
VALUES
  ('Apollo Hospitals', 'Dr Anita Reddy', 'chief_medical_officer', 84, 'decider', 8.5, '2026-06-05'::date, '2026-07-12'::date, 'Approved AMC tier upgrade in Q2; wants uptime dashboard'),
  ('Yashoda Hospitals', 'Mr Suresh Iyer', 'head_of_biomed', 36, 'champion', 9.2, '2026-06-15'::date, '2026-07-05'::date, 'Internal advocate; pushes our SLA to other chains'),
  ('KIMS Hospitals', 'Dr Rohan Mehta', 'director_clinical_ops', 18, 'influencer', 6.4, '2026-05-28'::date, '2026-07-08'::date, 'New hire; building trust; mixed signals on pricing'),
  ('Care Hospitals', 'Ms Priya Nair', 'chief_nursing_officer', 60, 'gatekeeper', 5.1, '2026-05-10'::date, '2026-06-30'::date, 'Controls floor escalations; needs faster on-site response'),
  ('Continental Hospitals', 'Dr Vikram Joshi', 'head_radiology', 24, 'influencer', 7.0, '2026-06-08'::date, '2026-07-15'::date, 'Owns CT/MRI budget; evaluating us vs incumbent OEM'),
  ('Sunshine Hospitals', 'Dr Lakshmi Rao', 'dean_clinical', 96, 'decider', 7.8, '2026-06-12'::date, '2026-07-20'::date, 'Quarterly clinical council chair; influences 4 sister units'),
  ('AIG Hospitals', 'Dr Naveen Kumar', 'head_anaesthesia', 48, 'blocker', 3.2, '2026-04-22'::date, '2026-07-02'::date, 'Burned by last vendor; cold on switching; needs 1:1 dinner');

-- ----------------------------------------------------------------------------
-- Table 2: quarterly touchpoint log with ask, commitment, and outcome
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_chain_leader_touchpoints_r2751 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  leader_id uuid NOT NULL REFERENCES hospital_chain_clinical_leaders_r2751(id) ON DELETE CASCADE,
  quarter text NOT NULL CHECK (quarter ~ '^FY[0-9]{2}Q[1-4]$'),
  touchpoint_type text NOT NULL CHECK (touchpoint_type IN ('1_1_meeting','site_visit','dinner','call','email','clinical_council','quarterly_review')),
  touchpoint_at date NOT NULL,
  ask_summary text NOT NULL,
  commitment_summary text,
  commitment_status text NOT NULL DEFAULT 'open' CHECK (commitment_status IN ('open','in_progress','delivered','slipped','withdrawn')),
  outcome text CHECK (outcome IN ('expansion','renewal','referral','blocker_removed','status_quo','escalation','lost')),
  revenue_impact_rupees bigint NOT NULL DEFAULT 0,
  follow_up_due_at date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_leader_touchpoints_r2751 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_leader_touchpoints_r2751;
CREATE POLICY founder_all ON hospital_chain_leader_touchpoints_r2751
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_leader_touchpoints_r2751
  (leader_id, quarter, touchpoint_type, touchpoint_at, ask_summary, commitment_summary, commitment_status, outcome, revenue_impact_rupees, follow_up_due_at)
SELECT id, 'FY27Q1', 'quarterly_review', '2026-06-05'::date,
  'Roll out AMC Tier-A across 6 Apollo units in Hyderabad',
  'Approve pilot at 2 units; review uptime in 60 days',
  'in_progress', 'expansion', 1850000, '2026-08-05'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Dr Anita Reddy'
UNION ALL
SELECT id, 'FY27Q1', '1_1_meeting', '2026-06-15'::date,
  'Refer us to Yashoda Somajiguda biomed lead',
  'Intro email sent same day; demo booked',
  'delivered', 'referral', 420000, '2026-07-05'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Mr Suresh Iyer'
UNION ALL
SELECT id, 'FY27Q1', 'site_visit', '2026-05-28'::date,
  'Discount on 12-month bundled AMC for KIMS Secunderabad',
  'Will present to procurement; needs CFO sign-off',
  'open', 'status_quo', 0, '2026-07-08'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Dr Rohan Mehta'
UNION ALL
SELECT id, 'FY27Q1', 'call', '2026-05-10'::date,
  'Cut on-site response from 6h to 2h for Care Banjara Hills',
  'Agreed if SLA penalty clause added to contract',
  'in_progress', 'blocker_removed', 0, '2026-06-30'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Ms Priya Nair'
UNION ALL
SELECT id, 'FY27Q1', 'dinner', '2026-06-08'::date,
  'Switch CT tube replacements to us from incumbent OEM',
  'Send sample SoW for 2 machines',
  'in_progress', 'expansion', 2400000, '2026-07-15'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Dr Vikram Joshi'
UNION ALL
SELECT id, 'FY27Q1', 'clinical_council', '2026-06-12'::date,
  'Standardize AMC across all 4 Sunshine sister units',
  'Will recommend at next clinical council on 20 Jul',
  'open', 'expansion', 3600000, '2026-07-20'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Dr Lakshmi Rao'
UNION ALL
SELECT id, 'FY26Q4', 'email', '2026-04-22'::date,
  'Reconsider us after last vendor outage incident',
  'Declined; not switching this fiscal',
  'withdrawn', 'lost', 0, '2026-10-01'::date
FROM hospital_chain_clinical_leaders_r2751 WHERE leader_name = 'Dr Naveen Kumar';

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_leader_kpi_r2751();
CREATE OR REPLACE FUNCTION founder_chain_leader_kpi_r2751()
RETURNS TABLE (
  total_leaders bigint,
  deciders bigint,
  champions bigint,
  blockers bigint,
  avg_warmth numeric,
  touchpoints_this_q bigint,
  open_commitments bigint,
  pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'decider'),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'champion'),
    (SELECT count(*) FROM hospital_chain_clinical_leaders_r2751 WHERE influence_tier = 'blocker'),
    (SELECT round(avg(warmth_score)::numeric, 2) FROM hospital_chain_clinical_leaders_r2751),
    (SELECT count(*) FROM hospital_chain_leader_touchpoints_r2751 WHERE quarter = 'FY27Q1'),
    (SELECT count(*) FROM hospital_chain_leader_touchpoints_r2751 WHERE commitment_status IN ('open','in_progress')),
    (SELECT coalesce(sum(revenue_impact_rupees),0) FROM hospital_chain_leader_touchpoints_r2751 WHERE commitment_status IN ('open','in_progress'));
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_leader_kpi_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_leader_kpi_r2751() TO authenticated;

-- ============================================================================
-- RPC 2: leaders ordered by influence and warmth
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_leaders_list_r2751();
CREATE OR REPLACE FUNCTION founder_chain_leaders_list_r2751()
RETURNS TABLE (
  id uuid,
  chain_name text,
  leader_name text,
  leader_role text,
  tenure_months int,
  influence_tier text,
  warmth_score numeric,
  last_touchpoint_at timestamptz,
  next_touchpoint_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.leader_name, l.leader_role, l.tenure_months,
         l.influence_tier, l.warmth_score, l.last_touchpoint_at, l.next_touchpoint_due_at
  FROM hospital_chain_clinical_leaders_r2751 l
  ORDER BY
    CASE l.influence_tier
      WHEN 'decider' THEN 1
      WHEN 'champion' THEN 2
      WHEN 'influencer' THEN 3
      WHEN 'gatekeeper' THEN 4
      WHEN 'blocker' THEN 5
    END,
    l.warmth_score DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_leaders_list_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_leaders_list_r2751() TO authenticated;

-- ============================================================================
-- RPC 3: touchpoint log with leader name
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_touchpoints_log_r2751();
CREATE OR REPLACE FUNCTION founder_chain_touchpoints_log_r2751()
RETURNS TABLE (
  id uuid,
  chain_name text,
  leader_name text,
  quarter text,
  touchpoint_type text,
  touchpoint_at date,
  ask_summary text,
  commitment_summary text,
  commitment_status text,
  outcome text,
  revenue_impact_rupees bigint,
  follow_up_due_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, l.chain_name, l.leader_name, t.quarter, t.touchpoint_type, t.touchpoint_at,
         t.ask_summary, t.commitment_summary, t.commitment_status, t.outcome,
         t.revenue_impact_rupees, t.follow_up_due_at
  FROM hospital_chain_leader_touchpoints_r2751 t
  JOIN hospital_chain_clinical_leaders_r2751 l ON l.id = t.leader_id
  ORDER BY t.touchpoint_at DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_touchpoints_log_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_touchpoints_log_r2751() TO authenticated;

-- ============================================================================
-- RPC 4: outcome funnel by quarter
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_outcome_funnel_r2751();
CREATE OR REPLACE FUNCTION founder_chain_outcome_funnel_r2751()
RETURNS TABLE (
  outcome text,
  touchpoints bigint,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(t.outcome, 'unknown'), count(*)::bigint, coalesce(sum(t.revenue_impact_rupees),0)::bigint
  FROM hospital_chain_leader_touchpoints_r2751 t
  GROUP BY t.outcome
  ORDER BY coalesce(sum(t.revenue_impact_rupees),0) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_outcome_funnel_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_outcome_funnel_r2751() TO authenticated;

-- ============================================================================
-- RPC 5: overdue follow-ups
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_overdue_followups_r2751();
CREATE OR REPLACE FUNCTION founder_chain_overdue_followups_r2751()
RETURNS TABLE (
  chain_name text,
  leader_name text,
  ask_summary text,
  follow_up_due_at date,
  days_overdue int,
  commitment_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.chain_name, l.leader_name, t.ask_summary, t.follow_up_due_at,
         (CURRENT_DATE - t.follow_up_due_at)::int AS days_overdue,
         t.commitment_status
  FROM hospital_chain_leader_touchpoints_r2751 t
  JOIN hospital_chain_clinical_leaders_r2751 l ON l.id = t.leader_id
  WHERE t.follow_up_due_at IS NOT NULL
    AND t.commitment_status IN ('open','in_progress')
  ORDER BY t.follow_up_due_at ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_overdue_followups_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_overdue_followups_r2751() TO authenticated;

-- ============================================================================
-- RPC 6: warmth by chain
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_warmth_by_chain_r2751();
CREATE OR REPLACE FUNCTION founder_chain_warmth_by_chain_r2751()
RETURNS TABLE (
  chain_name text,
  leaders bigint,
  avg_warmth numeric,
  top_role text,
  pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.chain_name,
         count(DISTINCT l.id)::bigint,
         round(avg(l.warmth_score)::numeric, 2),
         (SELECT ll.leader_role FROM hospital_chain_clinical_leaders_r2751 ll
            WHERE ll.chain_name = l.chain_name ORDER BY ll.warmth_score DESC LIMIT 1),
         coalesce(sum(t.revenue_impact_rupees) FILTER (WHERE t.commitment_status IN ('open','in_progress')), 0)::bigint
  FROM hospital_chain_clinical_leaders_r2751 l
  LEFT JOIN hospital_chain_leader_touchpoints_r2751 t ON t.leader_id = l.id
  GROUP BY l.chain_name
  ORDER BY avg(l.warmth_score) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_warmth_by_chain_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_warmth_by_chain_r2751() TO authenticated;

-- ============================================================================
-- RPC 7: tenure cohort warmth
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_tenure_cohort_r2751();
CREATE OR REPLACE FUNCTION founder_chain_tenure_cohort_r2751()
RETURNS TABLE (
  cohort text,
  leaders bigint,
  avg_warmth numeric,
  deciders bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c AS (
    SELECT
      CASE
        WHEN tenure_months < 24 THEN '0_to_2y'
        WHEN tenure_months < 60 THEN '2_to_5y'
        ELSE '5y_plus'
      END AS cohort,
      warmth_score,
      influence_tier
    FROM hospital_chain_clinical_leaders_r2751
  )
  SELECT c.cohort,
         count(*)::bigint,
         round(avg(c.warmth_score)::numeric, 2),
         count(*) FILTER (WHERE c.influence_tier = 'decider')::bigint
  FROM c
  GROUP BY c.cohort
  ORDER BY c.cohort;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_tenure_cohort_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_tenure_cohort_r2751() TO authenticated;

-- ============================================================================
-- RPC 8: touchpoint type effectiveness
-- ============================================================================
DROP FUNCTION IF EXISTS founder_chain_touchpoint_effectiveness_r2751();
CREATE OR REPLACE FUNCTION founder_chain_touchpoint_effectiveness_r2751()
RETURNS TABLE (
  touchpoint_type text,
  events bigint,
  delivered bigint,
  delivered_pct numeric,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.touchpoint_type,
         count(*)::bigint,
         count(*) FILTER (WHERE t.commitment_status = 'delivered')::bigint,
         round(100.0 * count(*) FILTER (WHERE t.commitment_status = 'delivered') / NULLIF(count(*),0), 1),
         coalesce(sum(t.revenue_impact_rupees),0)::bigint
  FROM hospital_chain_leader_touchpoints_r2751 t
  GROUP BY t.touchpoint_type
  ORDER BY count(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_chain_touchpoint_effectiveness_r2751() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_touchpoint_effectiveness_r2751() TO authenticated;

COMMIT;
