BEGIN;

-- ============================================================================
-- Round 2792 — Customer Monthly Engineer Handover Customer Confidence Score
-- Spec: job x customer x confidence pre x post x delta x cause x winback action
-- ============================================================================

-- Table 1: handover confidence events
CREATE TABLE IF NOT EXISTS customer_handover_confidence_r2792 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code        text NOT NULL,
  customer_name   text NOT NULL,
  hospital_city   text NOT NULL,
  prior_engineer  text NOT NULL,
  new_engineer    text NOT NULL,
  handover_date   date NOT NULL,
  confidence_pre  numeric(4,2) NOT NULL CHECK (confidence_pre  BETWEEN 0 AND 10),
  confidence_post numeric(4,2) NOT NULL CHECK (confidence_post BETWEEN 0 AND 10),
  delta_score     numeric(5,2) NOT NULL,
  primary_cause   text NOT NULL CHECK (primary_cause IN ('skill_gap','tone','punctuality','escalation_speed','rapport','documentation','first_visit_friction')),
  severity        text NOT NULL CHECK (severity IN ('green','amber','red','critical')),
  winback_action  text NOT NULL CHECK (winback_action IN ('founder_call','senior_swap','goodwill_credit','onsite_visit','training_audit','no_action')),
  action_owner    text NOT NULL,
  due_at          timestamptz NOT NULL DEFAULT now() + interval '3 days',
  resolved        boolean NOT NULL DEFAULT false,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_handover_confidence_r2792 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_handover_confidence_r2792;
CREATE POLICY founder_all ON customer_handover_confidence_r2792
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_handover_confidence_r2792
  (job_code, customer_name, hospital_city, prior_engineer, new_engineer, handover_date, confidence_pre, confidence_post, delta_score, primary_cause, severity, winback_action, action_owner, resolved, notes)
VALUES
  ('JOB-7711','Apollo Jubilee Hills','Hyderabad','Ravi K.','Suresh M.','2026-06-15'::date,9.20,6.40,-2.80,'rapport','red','founder_call','founder',false,'Long-term engineer rotated out; biomed head upset'),
  ('JOB-7712','Yashoda Secunderabad','Hyderabad','Mahesh P.','Anil R.','2026-06-16'::date,8.10,7.90,-0.20,'documentation','green','no_action','ops_lead',true,'Minor handover note gap; closed same day'),
  ('JOB-7713','KIMS Kondapur','Hyderabad','Lokesh T.','Bharath V.','2026-06-17'::date,8.50,5.10,-3.40,'skill_gap','critical','senior_swap','founder',false,'New engineer fumbled CT troubleshoot'),
  ('JOB-7714','Continental Gachibowli','Hyderabad','Vinay S.','Karthik N.','2026-06-18'::date,7.60,7.10,-0.50,'punctuality','amber','goodwill_credit','ops_lead',false,'Arrived 90min late on first visit'),
  ('JOB-7715','AIG Hospitals','Hyderabad','Rohit B.','Manoj G.','2026-06-19'::date,9.00,8.40,-0.60,'tone','amber','training_audit','training_lead',false,'Curt response to biomed query'),
  ('JOB-7716','Star Banjara','Hyderabad','Praveen D.','Sai L.','2026-06-20'::date,7.80,4.20,-3.60,'escalation_speed','critical','onsite_visit','founder',false,'OT downtime, delayed escalation'),
  ('JOB-7717','Care Outpatient','Hyderabad','Naveen A.','Deepak C.','2026-06-20'::date,8.30,8.10,-0.20,'first_visit_friction','green','no_action','ops_lead',true,'Smooth-ish handover');

-- Table 2: winback playbook actions log
CREATE TABLE IF NOT EXISTS handover_winback_actions_r2792 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  confidence_id    uuid REFERENCES customer_handover_confidence_r2792(id) ON DELETE CASCADE,
  customer_name    text NOT NULL,
  action_type      text NOT NULL CHECK (action_type IN ('founder_call','senior_swap','goodwill_credit','onsite_visit','training_audit','escalation_call','apology_letter')),
  taken_by         text NOT NULL,
  taken_at         timestamptz NOT NULL DEFAULT now(),
  outcome          text NOT NULL CHECK (outcome IN ('recovered','partial','no_recovery','pending','escalated')),
  recovery_score   numeric(4,2) NOT NULL CHECK (recovery_score BETWEEN 0 AND 10),
  cost_inr         numeric(10,2) NOT NULL DEFAULT 0,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE handover_winback_actions_r2792 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON handover_winback_actions_r2792;
CREATE POLICY founder_all ON handover_winback_actions_r2792
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO handover_winback_actions_r2792
  (customer_name, action_type, taken_by, outcome, recovery_score, cost_inr, notes)
VALUES
  ('Apollo Jubilee Hills','founder_call','founder','recovered',8.80,0,'30min call + sweets to biomed team'),
  ('KIMS Kondapur','senior_swap','founder','partial',7.20,4500,'Swapped to senior engineer Ravi K. (deputed)'),
  ('Continental Gachibowli','goodwill_credit','ops_lead','recovered',7.90,2000,'Issued ₹2000 service credit'),
  ('AIG Hospitals','training_audit','training_lead','pending',0.00,1200,'Tone training session scheduled'),
  ('Star Banjara','onsite_visit','founder','partial',6.10,8500,'Founder onsite + replacement engineer'),
  ('Yashoda Secunderabad','apology_letter','ops_lead','recovered',8.00,0,'Email apology + signed by founder');

-- ============================================================================
-- RPCs (7+) — all SECURITY DEFINER + is_founder() gated
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2792_handover_kpis();
CREATE OR REPLACE FUNCTION founder_r2792_handover_kpis()
RETURNS TABLE(
  total_handovers     int,
  avg_delta           numeric,
  critical_count      int,
  red_count           int,
  unresolved_count    int,
  total_winback_cost  numeric,
  recovered_count     int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM customer_handover_confidence_r2792),
    (SELECT round(avg(delta_score)::numeric,2) FROM customer_handover_confidence_r2792),
    (SELECT count(*)::int FROM customer_handover_confidence_r2792 WHERE severity='critical'),
    (SELECT count(*)::int FROM customer_handover_confidence_r2792 WHERE severity='red'),
    (SELECT count(*)::int FROM customer_handover_confidence_r2792 WHERE NOT resolved),
    (SELECT coalesce(sum(cost_inr),0) FROM handover_winback_actions_r2792),
    (SELECT count(*)::int FROM handover_winback_actions_r2792 WHERE outcome='recovered');
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_handover_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_handover_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_handover_list();
CREATE OR REPLACE FUNCTION founder_r2792_handover_list()
RETURNS TABLE(
  id              uuid,
  job_code        text,
  customer_name   text,
  hospital_city   text,
  prior_engineer  text,
  new_engineer    text,
  handover_date   date,
  confidence_pre  numeric,
  confidence_post numeric,
  delta_score     numeric,
  primary_cause   text,
  severity        text,
  winback_action  text,
  resolved        boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id,h.job_code,h.customer_name,h.hospital_city,h.prior_engineer,h.new_engineer,h.handover_date,
         h.confidence_pre,h.confidence_post,h.delta_score,h.primary_cause,h.severity,h.winback_action,h.resolved
  FROM customer_handover_confidence_r2792 h
  ORDER BY h.delta_score ASC, h.handover_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_handover_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_handover_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_cause_breakdown();
CREATE OR REPLACE FUNCTION founder_r2792_cause_breakdown()
RETURNS TABLE(
  primary_cause text,
  event_count   int,
  avg_delta     numeric,
  worst_delta   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.primary_cause, count(*)::int, round(avg(h.delta_score)::numeric,2), min(h.delta_score)
  FROM customer_handover_confidence_r2792 h
  GROUP BY h.primary_cause
  ORDER BY avg(h.delta_score) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_cause_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_cause_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_severity_breakdown();
CREATE OR REPLACE FUNCTION founder_r2792_severity_breakdown()
RETURNS TABLE(
  severity      text,
  event_count   int,
  avg_pre       numeric,
  avg_post      numeric,
  avg_delta     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.severity, count(*)::int,
         round(avg(h.confidence_pre)::numeric,2),
         round(avg(h.confidence_post)::numeric,2),
         round(avg(h.delta_score)::numeric,2)
  FROM customer_handover_confidence_r2792 h
  GROUP BY h.severity
  ORDER BY avg(h.delta_score) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_severity_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_severity_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_winback_actions();
CREATE OR REPLACE FUNCTION founder_r2792_winback_actions()
RETURNS TABLE(
  id             uuid,
  customer_name  text,
  action_type    text,
  taken_by       text,
  taken_at       timestamptz,
  outcome        text,
  recovery_score numeric,
  cost_inr       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id,w.customer_name,w.action_type,w.taken_by,w.taken_at,w.outcome,w.recovery_score,w.cost_inr
  FROM handover_winback_actions_r2792 w
  ORDER BY w.taken_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_winback_actions() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_winback_actions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_at_risk_customers();
CREATE OR REPLACE FUNCTION founder_r2792_at_risk_customers()
RETURNS TABLE(
  customer_name    text,
  hospital_city    text,
  worst_delta      numeric,
  events           int,
  unresolved_count int,
  last_handover    date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.customer_name, h.hospital_city,
         min(h.delta_score),
         count(*)::int,
         count(*) FILTER (WHERE NOT h.resolved)::int,
         max(h.handover_date)
  FROM customer_handover_confidence_r2792 h
  GROUP BY h.customer_name, h.hospital_city
  HAVING min(h.delta_score) <= -1.0
  ORDER BY min(h.delta_score) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_at_risk_customers() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_at_risk_customers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_engineer_handover_quality();
CREATE OR REPLACE FUNCTION founder_r2792_engineer_handover_quality()
RETURNS TABLE(
  engineer_name text,
  handovers_received int,
  avg_post_score numeric,
  avg_delta     numeric,
  worst_delta   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.new_engineer, count(*)::int,
         round(avg(h.confidence_post)::numeric,2),
         round(avg(h.delta_score)::numeric,2),
         min(h.delta_score)
  FROM customer_handover_confidence_r2792 h
  GROUP BY h.new_engineer
  ORDER BY avg(h.delta_score) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_engineer_handover_quality() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_engineer_handover_quality() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2792_mark_resolved(uuid);
CREATE OR REPLACE FUNCTION founder_r2792_mark_resolved(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE customer_handover_confidence_r2792 SET resolved = true WHERE id = p_id;
  RETURN FOUND;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2792_mark_resolved(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2792_mark_resolved(uuid) TO authenticated;

COMMIT;
