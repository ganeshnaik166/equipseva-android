BEGIN;

-- =========================================================================
-- Round 2740 — Customer Monthly Pre-Visit Checklist Completion
-- HEAVY ★★★★ founder console
-- Spec: job × checklist × items completed × missed × prep impact × refine action
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: pre-visit checklist completion records
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_pre_visit_checklists_r2740 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL,
  customer_name text NOT NULL,
  hospital_segment text NOT NULL CHECK (hospital_segment IN ('tier1','tier2','tier3','chain','government')),
  visit_date date NOT NULL,
  engineer_name text NOT NULL,
  checklist_template text NOT NULL,
  items_total int NOT NULL CHECK (items_total >= 0),
  items_completed int NOT NULL CHECK (items_completed >= 0),
  items_missed int NOT NULL CHECK (items_missed >= 0),
  completion_pct numeric(5,2) NOT NULL CHECK (completion_pct >= 0 AND completion_pct <= 100),
  prep_score numeric(5,2) NOT NULL CHECK (prep_score >= 0 AND prep_score <= 100),
  prep_impact_minutes_saved int NOT NULL DEFAULT 0,
  visit_outcome text NOT NULL CHECK (visit_outcome IN ('completed_on_time','delayed','escalated','aborted','rescheduled')),
  refine_status text NOT NULL CHECK (refine_status IN ('pending','in_review','refined','rejected','archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_pre_visit_checklists_r2740 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_pre_visit_checklists_r2740;
CREATE POLICY founder_all ON customer_pre_visit_checklists_r2740
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO customer_pre_visit_checklists_r2740
  (job_code, customer_name, hospital_segment, visit_date, engineer_name, checklist_template,
   items_total, items_completed, items_missed, completion_pct, prep_score,
   prep_impact_minutes_saved, visit_outcome, refine_status, notes)
VALUES
  ('JOB-2740-A01','Apollo Jubilee Hills','tier1','2026-06-03'::date,'Rohit S.',
   'Ventilator-PM-v3', 24, 23, 1, 95.83, 92.00, 38, 'completed_on_time','refined','breathing-circuit swap pre-staged'),
  ('JOB-2740-A02','Yashoda Secunderabad','chain','2026-06-05'::date,'Imran K.',
   'CathLab-Quarterly-v2', 30, 26, 4, 86.67, 81.50, 22, 'delayed','in_review','dye flush kit missed'),
  ('JOB-2740-A03','KIMS Kondapur','tier1','2026-06-08'::date,'Sneha P.',
   'MRI-Coil-Check-v4', 18, 18, 0, 100.00, 98.00, 47, 'completed_on_time','refined','best run this month'),
  ('JOB-2740-A04','Suraksha Diagnostics','tier3','2026-06-11'::date,'Manoj T.',
   'XRay-Basic-v1', 12, 7, 5, 58.33, 54.00, 0, 'escalated','pending','customer not ready, calibration tools missing'),
  ('JOB-2740-A05','Sunshine Hospitals','tier2','2026-06-13'::date,'Divya R.',
   'USG-Probe-PM-v2', 16, 15, 1, 93.75, 89.00, 19, 'completed_on_time','refined','probe disinfectant low - flagged'),
  ('JOB-2740-A06','Aarogyasri Govt Hub','government','2026-06-15'::date,'Karthik V.',
   'Defib-Battery-v3', 14, 10, 4, 71.43, 66.00, 8, 'rescheduled','in_review','battery pack DOA - reordered'),
  ('JOB-2740-A07','Care Hospitals Banjara','tier1','2026-06-18'::date,'Anita M.',
   'Anesthesia-PM-v2', 22, 21, 1, 95.45, 91.00, 31, 'completed_on_time','refined','vapor canister pre-checked');

-- -------------------------------------------------------------------------
-- Table 2: refinement actions taken on checklists
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_checklist_refine_actions_r2740 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id uuid REFERENCES customer_pre_visit_checklists_r2740(id) ON DELETE CASCADE,
  action_code text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('add_item','remove_item','reorder','split_template','merge_template','reword','escalate')),
  proposed_by text NOT NULL,
  proposed_at timestamptz NOT NULL DEFAULT now(),
  rationale text NOT NULL,
  expected_minutes_saved int NOT NULL DEFAULT 0,
  approval_status text NOT NULL CHECK (approval_status IN ('proposed','approved','applied','rejected','rolled_back')),
  applied_at timestamptz,
  measured_lift_pct numeric(5,2) DEFAULT 0
);

ALTER TABLE customer_checklist_refine_actions_r2740 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_checklist_refine_actions_r2740;
CREATE POLICY founder_all ON customer_checklist_refine_actions_r2740
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-001','add_item','Rohit S.',
       'Add breathing-circuit O-ring inspection before swap', 6, 'applied',
       '2026-06-04 09:30:00+05:30'::timestamptz, 4.20
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A01';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-002','split_template','Imran K.',
       'Split CathLab-Quarterly into dye-prep and electrical halves', 15, 'approved',
       NULL, 0
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A02';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-003','reorder','Sneha P.',
       'Move coil-temp check to top so cooldown overlaps prep', 10, 'applied',
       '2026-06-09 11:00:00+05:30'::timestamptz, 7.10
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A03';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-004','escalate','Manoj T.',
       'Escalate Suraksha to senior - calibration training gap', 0, 'proposed',
       NULL, 0
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A04';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-005','add_item','Divya R.',
       'Add disinfectant fluid-level row to USG template', 5, 'applied',
       '2026-06-14 10:15:00+05:30'::timestamptz, 3.40
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A05';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-006','reword','Karthik V.',
       'Reword battery check to spell out load-test wattage', 4, 'applied',
       '2026-06-16 08:50:00+05:30'::timestamptz, 2.10
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A06';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-007','remove_item','Anita M.',
       'Remove redundant vapor visual now that canister pre-check exists', 3, 'applied',
       '2026-06-19 09:00:00+05:30'::timestamptz, 2.80
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A07';

INSERT INTO customer_checklist_refine_actions_r2740
  (checklist_id, action_code, action_type, proposed_by, rationale,
   expected_minutes_saved, approval_status, applied_at, measured_lift_pct)
SELECT id, 'RA-008','merge_template','Sneha P.',
       'Merge MRI coil + magnet checks into single chain template', 12, 'rejected',
       NULL, 0
  FROM customer_pre_visit_checklists_r2740 WHERE job_code='JOB-2740-A03';

-- =========================================================================
-- RPCs (7+) — all SECURITY DEFINER + is_founder gated
-- =========================================================================

-- RPC 1: overview KPIs
DROP FUNCTION IF EXISTS founder_r2740_overview();
CREATE OR REPLACE FUNCTION founder_r2740_overview()
RETURNS TABLE (
  total_checklists bigint,
  avg_completion_pct numeric,
  avg_prep_score numeric,
  total_minutes_saved bigint,
  refined_count bigint,
  pending_refine bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(round(avg(completion_pct)::numeric, 2), 0),
    coalesce(round(avg(prep_score)::numeric, 2), 0),
    coalesce(sum(prep_impact_minutes_saved), 0)::bigint,
    count(*) FILTER (WHERE refine_status = 'refined')::bigint,
    count(*) FILTER (WHERE refine_status = 'pending')::bigint
  FROM customer_pre_visit_checklists_r2740;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_overview() TO authenticated;

-- RPC 2: checklist rows
DROP FUNCTION IF EXISTS founder_r2740_checklists();
CREATE OR REPLACE FUNCTION founder_r2740_checklists()
RETURNS TABLE (
  id uuid,
  job_code text,
  customer_name text,
  hospital_segment text,
  visit_date date,
  engineer_name text,
  checklist_template text,
  items_total int,
  items_completed int,
  items_missed int,
  completion_pct numeric,
  prep_score numeric,
  prep_impact_minutes_saved int,
  visit_outcome text,
  refine_status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.job_code, c.customer_name, c.hospital_segment, c.visit_date,
         c.engineer_name, c.checklist_template, c.items_total, c.items_completed,
         c.items_missed, c.completion_pct, c.prep_score,
         c.prep_impact_minutes_saved, c.visit_outcome, c.refine_status, c.notes
  FROM customer_pre_visit_checklists_r2740 c
  ORDER BY c.visit_date DESC, c.job_code;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_checklists() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_checklists() TO authenticated;

-- RPC 3: segment summary
DROP FUNCTION IF EXISTS founder_r2740_by_segment();
CREATE OR REPLACE FUNCTION founder_r2740_by_segment()
RETURNS TABLE (
  hospital_segment text,
  visits bigint,
  avg_completion numeric,
  avg_prep numeric,
  minutes_saved bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.hospital_segment,
         count(*)::bigint,
         round(avg(c.completion_pct)::numeric, 2),
         round(avg(c.prep_score)::numeric, 2),
         coalesce(sum(c.prep_impact_minutes_saved),0)::bigint
  FROM customer_pre_visit_checklists_r2740 c
  GROUP BY c.hospital_segment
  ORDER BY avg(c.completion_pct) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_by_segment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_by_segment() TO authenticated;

-- RPC 4: missed items leaderboard
DROP FUNCTION IF EXISTS founder_r2740_missed_leaders();
CREATE OR REPLACE FUNCTION founder_r2740_missed_leaders()
RETURNS TABLE (
  job_code text,
  customer_name text,
  engineer_name text,
  items_missed int,
  completion_pct numeric,
  visit_outcome text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.job_code, c.customer_name, c.engineer_name,
         c.items_missed, c.completion_pct, c.visit_outcome
  FROM customer_pre_visit_checklists_r2740 c
  WHERE c.items_missed > 0
  ORDER BY c.items_missed DESC, c.completion_pct ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_missed_leaders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_missed_leaders() TO authenticated;

-- RPC 5: refine actions
DROP FUNCTION IF EXISTS founder_r2740_refine_actions();
CREATE OR REPLACE FUNCTION founder_r2740_refine_actions()
RETURNS TABLE (
  action_code text,
  job_code text,
  action_type text,
  proposed_by text,
  rationale text,
  expected_minutes_saved int,
  approval_status text,
  measured_lift_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_code, c.job_code, a.action_type, a.proposed_by, a.rationale,
         a.expected_minutes_saved, a.approval_status, a.measured_lift_pct
  FROM customer_checklist_refine_actions_r2740 a
  JOIN customer_pre_visit_checklists_r2740 c ON c.id = a.checklist_id
  ORDER BY a.proposed_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_refine_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_refine_actions() TO authenticated;

-- RPC 6: prep impact rollup by template
DROP FUNCTION IF EXISTS founder_r2740_template_impact();
CREATE OR REPLACE FUNCTION founder_r2740_template_impact()
RETURNS TABLE (
  checklist_template text,
  runs bigint,
  avg_completion numeric,
  total_minutes_saved bigint,
  avg_missed numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.checklist_template,
         count(*)::bigint,
         round(avg(c.completion_pct)::numeric, 2),
         coalesce(sum(c.prep_impact_minutes_saved),0)::bigint,
         round(avg(c.items_missed)::numeric, 2)
  FROM customer_pre_visit_checklists_r2740 c
  GROUP BY c.checklist_template
  ORDER BY sum(c.prep_impact_minutes_saved) DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_template_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_template_impact() TO authenticated;

-- RPC 7: outcome breakdown
DROP FUNCTION IF EXISTS founder_r2740_outcome_mix();
CREATE OR REPLACE FUNCTION founder_r2740_outcome_mix()
RETURNS TABLE (
  visit_outcome text,
  visits bigint,
  share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM customer_pre_visit_checklists_r2740;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT c.visit_outcome,
         count(*)::bigint,
         round((count(*)::numeric * 100.0 / total)::numeric, 2)
  FROM customer_pre_visit_checklists_r2740 c
  GROUP BY c.visit_outcome
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_outcome_mix() TO authenticated;

-- RPC 8: engineer prep score leaderboard
DROP FUNCTION IF EXISTS founder_r2740_engineer_prep();
CREATE OR REPLACE FUNCTION founder_r2740_engineer_prep()
RETURNS TABLE (
  engineer_name text,
  visits bigint,
  avg_prep numeric,
  avg_completion numeric,
  missed_total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_name,
         count(*)::bigint,
         round(avg(c.prep_score)::numeric, 2),
         round(avg(c.completion_pct)::numeric, 2),
         coalesce(sum(c.items_missed),0)::bigint
  FROM customer_pre_visit_checklists_r2740 c
  GROUP BY c.engineer_name
  ORDER BY avg(c.prep_score) DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2740_engineer_prep() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2740_engineer_prep() TO authenticated;

COMMIT;
