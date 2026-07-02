BEGIN;

-- =========================================================================
-- Round 2695: Hospital Chain Monthly Clinical Team Relationship
-- chain x clinical role x relationship strength x touchpoint x ask x action
-- =========================================================================

-- ---- Table 1: clinical team relationship snapshots ---------------------
CREATE TABLE IF NOT EXISTS hospital_chain_clinical_relationships_r2695 (
  id bigserial PRIMARY KEY,
  snapshot_month date NOT NULL,
  chain_name text NOT NULL,
  hospital_unit text NOT NULL,
  clinical_role text NOT NULL CHECK (clinical_role IN ('chief_biomed','head_radiology','head_dialysis','head_icu','head_surgery','head_lab','head_cssd','head_cathlab','head_nursing','head_procurement')),
  contact_name text NOT NULL,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('champion','warm','neutral','cool','at_risk')),
  relationship_score int NOT NULL CHECK (relationship_score BETWEEN 0 AND 100),
  last_touchpoint text NOT NULL CHECK (last_touchpoint IN ('site_visit','quarterly_review','tea_meet','whatsapp_check','dinner','training_session','escalation_call','none')),
  last_touchpoint_at date NOT NULL,
  next_touchpoint_due date NOT NULL,
  open_ask text NOT NULL,
  ask_urgency text NOT NULL CHECK (ask_urgency IN ('blocker','urgent','normal','low')),
  next_action text NOT NULL,
  owner_name text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_clinical_relationships_r2695 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_clinical_relationships_r2695;
CREATE POLICY founder_all ON hospital_chain_clinical_relationships_r2695
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_clinical_relationships_r2695
  (snapshot_month, chain_name, hospital_unit, clinical_role, contact_name, relationship_strength, relationship_score, last_touchpoint, last_touchpoint_at, next_touchpoint_due, open_ask, ask_urgency, next_action, owner_name, notes)
VALUES
  ('2026-06-01'::date, 'Apollo Hospitals', 'Apollo Jubilee Hills', 'chief_biomed', 'Dr Rakesh Menon', 'champion', 92, 'quarterly_review', '2026-06-10'::date, '2026-07-10'::date, 'Bundle 12-month AMC for 3 new cath-labs', 'urgent', 'Send AMC quote with chain discount', 'Ganesh', 'Refers us to peers; signed 4 contracts'),
  ('2026-06-01'::date, 'Apollo Hospitals', 'Apollo Hyderguda', 'head_dialysis', 'Sr Nurse Mgr Lakshmi', 'warm', 78, 'site_visit', '2026-06-12'::date, '2026-07-05'::date, 'RO plant uptime SLA 99.5%', 'urgent', 'Share Q2 uptime audit + corrective plan', 'Priya', 'Wants weekly uptime email'),
  ('2026-06-01'::date, 'Yashoda Hospitals', 'Yashoda Secunderabad', 'head_radiology', 'Dr Anil Kapoor', 'neutral', 58, 'whatsapp_check', '2026-06-05'::date, '2026-06-25'::date, 'CT tube replacement timeline', 'blocker', 'Confirm tube ETA + loaner unit', 'Ganesh', 'Considering OEM direct'),
  ('2026-06-01'::date, 'KIMS Hospitals', 'KIMS Kondapur', 'head_icu', 'Dr Suresh Reddy', 'champion', 95, 'tea_meet', '2026-06-15'::date, '2026-07-15'::date, 'Vent fleet preventive cycle Q3', 'normal', 'Schedule July PM batch + share calendar', 'Priya', 'Strong advocate inside KIMS group'),
  ('2026-06-01'::date, 'Care Hospitals', 'Care Banjara', 'head_cathlab', 'Dr Meera Iyer', 'cool', 42, 'escalation_call', '2026-06-03'::date, '2026-06-22'::date, 'Cath-lab downtime last week', 'blocker', 'In-person apology visit + RCA doc', 'Ganesh', 'Lost faith after 14-hr downtime'),
  ('2026-06-01'::date, 'Continental Hospitals', 'Continental Gachibowli', 'head_surgery', 'Dr Vivek Sharma', 'warm', 72, 'training_session', '2026-06-08'::date, '2026-07-08'::date, 'OT integration upgrade plan', 'normal', 'Demo new OT-IT module', 'Karthik', 'Open to pilot if pricing OK'),
  ('2026-06-01'::date, 'Sunshine Hospitals', 'Sunshine Paradise', 'head_lab', 'Dr Anjali Rao', 'at_risk', 28, 'none', '2026-04-20'::date, '2026-06-22'::date, '60-day silence; expired AMC', 'blocker', 'CEO-to-CEO escalation call', 'Ganesh', 'Likely lost; salvage attempt'),
  ('2026-06-01'::date, 'AIG Hospitals', 'AIG Gachibowli', 'head_cssd', 'Sr Mgr Kavitha', 'warm', 75, 'site_visit', '2026-06-14'::date, '2026-07-14'::date, 'Autoclave validation paperwork', 'urgent', 'Send NABH-grade validation pack', 'Priya', 'Auditor visit in 2 weeks'),
  ('2026-06-01'::date, 'Yashoda Hospitals', 'Yashoda Somajiguda', 'head_procurement', 'Mr Ramesh Gupta', 'neutral', 55, 'quarterly_review', '2026-06-09'::date, '2026-07-09'::date, 'Renegotiate AMC bundle pricing', 'normal', 'Prepare chain-tier proposal', 'Ganesh', 'Procurement-led, not clinical'),
  ('2026-06-01'::date, 'Apollo Hospitals', 'Apollo Health City', 'head_nursing', 'CNO Mrs Sujatha', 'champion', 88, 'dinner', '2026-06-11'::date, '2026-08-11'::date, 'Nursing training on infusion pumps', 'low', 'Schedule Q3 onsite training', 'Priya', 'Internal champion for biomed dept');

CREATE INDEX IF NOT EXISTS idx_hcr_r2695_month ON hospital_chain_clinical_relationships_r2695 (snapshot_month);
CREATE INDEX IF NOT EXISTS idx_hcr_r2695_chain ON hospital_chain_clinical_relationships_r2695 (chain_name);
CREATE INDEX IF NOT EXISTS idx_hcr_r2695_strength ON hospital_chain_clinical_relationships_r2695 (relationship_strength);

-- ---- Table 2: touchpoint actions log ----------------------------------
CREATE TABLE IF NOT EXISTS hospital_chain_relationship_actions_r2695 (
  id bigserial PRIMARY KEY,
  relationship_id bigint NOT NULL REFERENCES hospital_chain_clinical_relationships_r2695(id) ON DELETE CASCADE,
  action_date date NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('email_sent','quote_sent','site_visit_done','call_done','escalation_done','training_done','dinner_done','followup_due','closed_won','closed_lost')),
  action_summary text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  arr_impact_rupees bigint NOT NULL DEFAULT 0,
  owner_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_relationship_actions_r2695 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_relationship_actions_r2695;
CREATE POLICY founder_all ON hospital_chain_relationship_actions_r2695
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_relationship_actions_r2695
  (relationship_id, action_date, action_type, action_summary, outcome, arr_impact_rupees, owner_name)
VALUES
  (1, '2026-06-16'::date, 'quote_sent', 'AMC bundle quote for 3 cath-labs Apollo Jubilee', 'pending', 4800000, 'Ganesh'),
  (2, '2026-06-13'::date, 'email_sent', 'Q2 RO uptime audit report sent', 'positive', 0, 'Priya'),
  (3, '2026-06-18'::date, 'call_done', 'CT tube ETA confirmed Aug 2; loaner offered', 'neutral', 0, 'Ganesh'),
  (4, '2026-06-16'::date, 'site_visit_done', 'KIMS Kondapur Q3 PM batch finalized', 'positive', 1200000, 'Priya'),
  (5, '2026-06-04'::date, 'escalation_done', 'Care Banjara CEO apology + RCA delivered', 'neutral', 0, 'Ganesh'),
  (6, '2026-06-10'::date, 'training_done', 'Continental OT-IT pilot demo completed', 'positive', 2400000, 'Karthik'),
  (7, '2026-06-20'::date, 'followup_due', 'Sunshine Paradise CEO call scheduled', 'pending', 0, 'Ganesh'),
  (8, '2026-06-15'::date, 'email_sent', 'AIG CSSD NABH validation pack delivered', 'positive', 0, 'Priya'),
  (9, '2026-06-12'::date, 'quote_sent', 'Yashoda chain-tier AMC proposal sent', 'pending', 3600000, 'Ganesh'),
  (10, '2026-06-12'::date, 'dinner_done', 'Apollo Health City CNO dinner; champion strengthened', 'positive', 0, 'Priya');

CREATE INDEX IF NOT EXISTS idx_hra_r2695_rel ON hospital_chain_relationship_actions_r2695 (relationship_id);
CREATE INDEX IF NOT EXISTS idx_hra_r2695_date ON hospital_chain_relationship_actions_r2695 (action_date);

-- =========================================================================
-- RPCs
-- =========================================================================

-- RPC 1: KPIs summary
DROP FUNCTION IF EXISTS founder_hcr_r2695_kpis();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_kpis()
RETURNS TABLE (
  total_relationships int,
  champions int,
  at_risk int,
  avg_score numeric,
  overdue_touchpoints int,
  blocker_asks int,
  pipeline_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM hospital_chain_clinical_relationships_r2695),
    (SELECT count(*)::int FROM hospital_chain_clinical_relationships_r2695 WHERE relationship_strength = 'champion'),
    (SELECT count(*)::int FROM hospital_chain_clinical_relationships_r2695 WHERE relationship_strength = 'at_risk'),
    (SELECT round(avg(relationship_score)::numeric, 1) FROM hospital_chain_clinical_relationships_r2695),
    (SELECT count(*)::int FROM hospital_chain_clinical_relationships_r2695 WHERE next_touchpoint_due < current_date),
    (SELECT count(*)::int FROM hospital_chain_clinical_relationships_r2695 WHERE ask_urgency = 'blocker'),
    (SELECT coalesce(sum(arr_impact_rupees), 0)::bigint FROM hospital_chain_relationship_actions_r2695 WHERE outcome IN ('pending','positive'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_kpis() TO authenticated;

-- RPC 2: relationships by chain
DROP FUNCTION IF EXISTS founder_hcr_r2695_by_chain();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_by_chain()
RETURNS TABLE (
  chain_name text,
  contacts int,
  champions int,
  at_risk int,
  avg_score numeric,
  pipeline_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.chain_name,
    count(*)::int,
    count(*) FILTER (WHERE r.relationship_strength = 'champion')::int,
    count(*) FILTER (WHERE r.relationship_strength = 'at_risk')::int,
    round(avg(r.relationship_score)::numeric, 1),
    coalesce(sum(a.arr_impact_rupees), 0)::bigint
  FROM hospital_chain_clinical_relationships_r2695 r
  LEFT JOIN hospital_chain_relationship_actions_r2695 a ON a.relationship_id = r.id
  GROUP BY r.chain_name
  ORDER BY avg(r.relationship_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_by_chain() TO authenticated;

-- RPC 3: relationships by clinical role
DROP FUNCTION IF EXISTS founder_hcr_r2695_by_role();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_by_role()
RETURNS TABLE (
  clinical_role text,
  contacts int,
  avg_score numeric,
  blockers int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.clinical_role,
    count(*)::int,
    round(avg(r.relationship_score)::numeric, 1),
    count(*) FILTER (WHERE r.ask_urgency = 'blocker')::int
  FROM hospital_chain_clinical_relationships_r2695 r
  GROUP BY r.clinical_role
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_by_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_by_role() TO authenticated;

-- RPC 4: overdue touchpoints
DROP FUNCTION IF EXISTS founder_hcr_r2695_overdue();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_overdue()
RETURNS TABLE (
  id bigint,
  chain_name text,
  hospital_unit text,
  contact_name text,
  clinical_role text,
  relationship_strength text,
  days_overdue int,
  open_ask text,
  next_action text,
  owner_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.hospital_unit,
    r.contact_name,
    r.clinical_role,
    r.relationship_strength,
    (current_date - r.next_touchpoint_due)::int AS days_overdue,
    r.open_ask,
    r.next_action,
    r.owner_name
  FROM hospital_chain_clinical_relationships_r2695 r
  WHERE r.next_touchpoint_due < current_date
  ORDER BY r.next_touchpoint_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_overdue() TO authenticated;

-- RPC 5: blocker asks
DROP FUNCTION IF EXISTS founder_hcr_r2695_blockers();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_blockers()
RETURNS TABLE (
  id bigint,
  chain_name text,
  hospital_unit text,
  contact_name text,
  relationship_strength text,
  relationship_score int,
  open_ask text,
  next_action text,
  owner_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.chain_name,
    r.hospital_unit,
    r.contact_name,
    r.relationship_strength,
    r.relationship_score,
    r.open_ask,
    r.next_action,
    r.owner_name
  FROM hospital_chain_clinical_relationships_r2695 r
  WHERE r.ask_urgency = 'blocker'
  ORDER BY r.relationship_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_blockers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_blockers() TO authenticated;

-- RPC 6: champions list
DROP FUNCTION IF EXISTS founder_hcr_r2695_champions();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_champions()
RETURNS TABLE (
  chain_name text,
  hospital_unit text,
  contact_name text,
  clinical_role text,
  relationship_score int,
  open_ask text,
  last_touchpoint text,
  last_touchpoint_at date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.chain_name,
    r.hospital_unit,
    r.contact_name,
    r.clinical_role,
    r.relationship_score,
    r.open_ask,
    r.last_touchpoint,
    r.last_touchpoint_at
  FROM hospital_chain_clinical_relationships_r2695 r
  WHERE r.relationship_strength = 'champion'
  ORDER BY r.relationship_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_champions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_champions() TO authenticated;

-- RPC 7: recent actions
DROP FUNCTION IF EXISTS founder_hcr_r2695_recent_actions();
CREATE OR REPLACE FUNCTION founder_hcr_r2695_recent_actions()
RETURNS TABLE (
  action_date date,
  chain_name text,
  contact_name text,
  action_type text,
  action_summary text,
  outcome text,
  arr_impact_rupees bigint,
  owner_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.action_date,
    r.chain_name,
    r.contact_name,
    a.action_type,
    a.action_summary,
    a.outcome,
    a.arr_impact_rupees,
    a.owner_name
  FROM hospital_chain_relationship_actions_r2695 a
  JOIN hospital_chain_clinical_relationships_r2695 r ON r.id = a.relationship_id
  ORDER BY a.action_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_recent_actions() TO authenticated;

-- RPC 8: log a new action
DROP FUNCTION IF EXISTS founder_hcr_r2695_log_action(bigint, date, text, text, text, bigint, text);
CREATE OR REPLACE FUNCTION founder_hcr_r2695_log_action(
  p_relationship_id bigint,
  p_action_date date,
  p_action_type text,
  p_action_summary text,
  p_outcome text,
  p_arr_impact_rupees bigint,
  p_owner_name text
)
RETURNS bigint
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO hospital_chain_relationship_actions_r2695
    (relationship_id, action_date, action_type, action_summary, outcome, arr_impact_rupees, owner_name)
  VALUES
    (p_relationship_id, p_action_date, p_action_type, p_action_summary, p_outcome, p_arr_impact_rupees, p_owner_name)
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hcr_r2695_log_action(bigint, date, text, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hcr_r2695_log_action(bigint, date, text, text, text, bigint, text) TO authenticated;

COMMIT;