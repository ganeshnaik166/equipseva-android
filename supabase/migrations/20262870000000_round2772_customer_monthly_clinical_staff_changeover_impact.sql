BEGIN;

-- ============================================================
-- Round 2772 — Customer Monthly Clinical Staff Changeover Impact
-- ============================================================

-- Table 1: changeover events
CREATE TABLE IF NOT EXISTS customer_clinical_staff_changeovers_r2772 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  customer_tier text NOT NULL CHECK (customer_tier IN ('platinum','gold','silver','bronze')),
  outgoing_clinician_name text NOT NULL,
  outgoing_role text NOT NULL CHECK (outgoing_role IN ('biomed_engineer','head_nurse','radiology_lead','lab_lead','icu_lead')),
  incoming_clinician_name text NOT NULL,
  incoming_role text NOT NULL CHECK (incoming_role IN ('biomed_engineer','head_nurse','radiology_lead','lab_lead','icu_lead')),
  changeover_date date NOT NULL,
  handoff_days_planned int NOT NULL CHECK (handoff_days_planned >= 0),
  handoff_days_actual int NOT NULL CHECK (handoff_days_actual >= 0),
  handoff_quality text NOT NULL CHECK (handoff_quality IN ('excellent','good','partial','missing')),
  knowledge_transfer_pct int NOT NULL CHECK (knowledge_transfer_pct BETWEEN 0 AND 100),
  adoption_score_pre int NOT NULL CHECK (adoption_score_pre BETWEEN 0 AND 100),
  adoption_score_post int NOT NULL CHECK (adoption_score_post BETWEEN 0 AND 100),
  support_tickets_30d int NOT NULL DEFAULT 0,
  support_tickets_pre_30d int NOT NULL DEFAULT 0,
  risk_level text NOT NULL CHECK (risk_level IN ('low','medium','high','critical')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_clinical_staff_changeovers_r2772 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_clinical_staff_changeovers_r2772;
CREATE POLICY founder_all ON customer_clinical_staff_changeovers_r2772
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_clinical_staff_changeovers_r2772
(customer_org_name, customer_tier, outgoing_clinician_name, outgoing_role, incoming_clinician_name, incoming_role, changeover_date, handoff_days_planned, handoff_days_actual, handoff_quality, knowledge_transfer_pct, adoption_score_pre, adoption_score_post, support_tickets_30d, support_tickets_pre_30d, risk_level)
VALUES
('Apollo Hyderabad','platinum','Dr Anu Reddy','biomed_engineer','Dr Karthik V','biomed_engineer','2026-06-01'::date,14,12,'good',78,88,72,11,3,'medium'),
('Yashoda Secunderabad','gold','Sr Priya','head_nurse','Sr Latha','head_nurse','2026-05-18'::date,10,4,'partial',55,84,61,18,4,'high'),
('Kims Kondapur','gold','Mr Suresh K','radiology_lead','Mr Vinod J','radiology_lead','2026-05-25'::date,21,21,'excellent',92,90,89,2,2,'low'),
('Sunshine Begumpet','silver','Ms Rekha','lab_lead','Ms Anitha','lab_lead','2026-06-03'::date,7,0,'missing',12,75,38,29,5,'critical'),
('Continental Gachibowli','platinum','Dr Mohan','icu_lead','Dr Sanjay','icu_lead','2026-06-08'::date,14,11,'good',74,86,70,9,3,'medium'),
('Care Banjara','silver','Mr Ravi','biomed_engineer','Mr Naresh','biomed_engineer','2026-05-30'::date,7,3,'partial',48,80,55,16,4,'high');

-- Table 2: monthly impact rollup
CREATE TABLE IF NOT EXISTS changeover_monthly_impact_r2772 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  customer_org_name text NOT NULL,
  changeovers_count int NOT NULL DEFAULT 0,
  high_risk_count int NOT NULL DEFAULT 0,
  avg_adoption_drop_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_support_uplift int NOT NULL DEFAULT 0,
  mrr_at_risk_rupees bigint NOT NULL DEFAULT 0,
  intervention_status text NOT NULL CHECK (intervention_status IN ('none','training_scheduled','onsite_dispatched','escalated','resolved')),
  csm_owner text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE changeover_monthly_impact_r2772 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON changeover_monthly_impact_r2772;
CREATE POLICY founder_all ON changeover_monthly_impact_r2772
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO changeover_monthly_impact_r2772
(month_start, customer_org_name, changeovers_count, high_risk_count, avg_adoption_drop_pct, avg_support_uplift, mrr_at_risk_rupees, intervention_status, csm_owner, notes)
VALUES
('2026-06-01'::date,'Apollo Hyderabad',1,0,16.00,8,0,'training_scheduled','Anjali M','re-cert booked Jun 22'),
('2026-05-01'::date,'Yashoda Secunderabad',1,1,23.00,14,180000,'onsite_dispatched','Rohit B','onsite handover Jun 14-16'),
('2026-05-01'::date,'Kims Kondapur',1,0,1.00,0,0,'none','Anjali M','clean transition'),
('2026-06-01'::date,'Sunshine Begumpet',1,1,37.00,24,240000,'escalated','Founder','no-handover risk; AMC review'),
('2026-06-01'::date,'Continental Gachibowli',1,0,16.00,6,0,'training_scheduled','Rohit B','playbook refresh'),
('2026-05-01'::date,'Care Banjara',1,1,25.00,12,90000,'onsite_dispatched','Anjali M','field engg dispatched');

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2772_summary();
CREATE OR REPLACE FUNCTION founder_r2772_summary()
RETURNS TABLE(total_changeovers int, critical_count int, high_count int, avg_adoption_drop numeric, avg_support_uplift numeric, total_mrr_at_risk bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM customer_clinical_staff_changeovers_r2772),
    (SELECT COUNT(*)::int FROM customer_clinical_staff_changeovers_r2772 WHERE risk_level = 'critical'),
    (SELECT COUNT(*)::int FROM customer_clinical_staff_changeovers_r2772 WHERE risk_level = 'high'),
    (SELECT ROUND(AVG(adoption_score_pre - adoption_score_post)::numeric, 2) FROM customer_clinical_staff_changeovers_r2772),
    (SELECT ROUND(AVG(support_tickets_30d - support_tickets_pre_30d)::numeric, 2) FROM customer_clinical_staff_changeovers_r2772),
    (SELECT COALESCE(SUM(mrr_at_risk_rupees),0)::bigint FROM changeover_monthly_impact_r2772);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_changeovers();
CREATE OR REPLACE FUNCTION founder_r2772_changeovers()
RETURNS SETOF customer_clinical_staff_changeovers_r2772
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_clinical_staff_changeovers_r2772 ORDER BY changeover_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_changeovers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_changeovers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_high_risk();
CREATE OR REPLACE FUNCTION founder_r2772_high_risk()
RETURNS TABLE(customer_org_name text, outgoing_clinician_name text, incoming_clinician_name text, risk_level text, adoption_drop int, support_uplift int, handoff_quality text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_org_name, c.outgoing_clinician_name, c.incoming_clinician_name, c.risk_level,
         (c.adoption_score_pre - c.adoption_score_post), (c.support_tickets_30d - c.support_tickets_pre_30d), c.handoff_quality
  FROM customer_clinical_staff_changeovers_r2772 c
  WHERE c.risk_level IN ('high','critical')
  ORDER BY (c.adoption_score_pre - c.adoption_score_post) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_high_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_high_risk() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_monthly_impact();
CREATE OR REPLACE FUNCTION founder_r2772_monthly_impact()
RETURNS SETOF changeover_monthly_impact_r2772
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM changeover_monthly_impact_r2772 ORDER BY month_start DESC, mrr_at_risk_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_monthly_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_monthly_impact() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_handoff_quality_breakdown();
CREATE OR REPLACE FUNCTION founder_r2772_handoff_quality_breakdown()
RETURNS TABLE(handoff_quality text, n int, avg_adoption_drop numeric, avg_support_uplift numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.handoff_quality, COUNT(*)::int,
         ROUND(AVG(c.adoption_score_pre - c.adoption_score_post)::numeric, 2),
         ROUND(AVG(c.support_tickets_30d - c.support_tickets_pre_30d)::numeric, 2)
  FROM customer_clinical_staff_changeovers_r2772 c
  GROUP BY c.handoff_quality
  ORDER BY 3 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_handoff_quality_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_handoff_quality_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_role_pattern();
CREATE OR REPLACE FUNCTION founder_r2772_role_pattern()
RETURNS TABLE(outgoing_role text, n int, avg_knowledge_transfer numeric, critical_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.outgoing_role, COUNT(*)::int,
         ROUND(AVG(c.knowledge_transfer_pct)::numeric, 1),
         COUNT(*) FILTER (WHERE c.risk_level = 'critical')::int
  FROM customer_clinical_staff_changeovers_r2772 c
  GROUP BY c.outgoing_role
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_role_pattern() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_role_pattern() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_intervention_queue();
CREATE OR REPLACE FUNCTION founder_r2772_intervention_queue()
RETURNS TABLE(customer_org_name text, csm_owner text, intervention_status text, mrr_at_risk_rupees bigint, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.customer_org_name, m.csm_owner, m.intervention_status, m.mrr_at_risk_rupees, m.notes
  FROM changeover_monthly_impact_r2772 m
  WHERE m.intervention_status IN ('training_scheduled','onsite_dispatched','escalated')
  ORDER BY m.mrr_at_risk_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_intervention_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_intervention_queue() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2772_tier_impact();
CREATE OR REPLACE FUNCTION founder_r2772_tier_impact()
RETURNS TABLE(customer_tier text, n int, avg_adoption_drop numeric, avg_handoff_days_actual numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_tier, COUNT(*)::int,
         ROUND(AVG(c.adoption_score_pre - c.adoption_score_post)::numeric, 2),
         ROUND(AVG(c.handoff_days_actual)::numeric, 1)
  FROM customer_clinical_staff_changeovers_r2772 c
  GROUP BY c.customer_tier
  ORDER BY 3 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2772_tier_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2772_tier_impact() TO authenticated;

COMMIT;
