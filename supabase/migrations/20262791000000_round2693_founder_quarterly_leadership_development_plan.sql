BEGIN;

DROP TABLE IF EXISTS leadership_dev_plans_r2693 CASCADE;
DROP TABLE IF EXISTS leadership_dev_milestones_r2693 CASCADE;

CREATE TABLE leadership_dev_plans_r2693 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_name text NOT NULL,
  role_title text NOT NULL,
  hire_date date NOT NULL,
  top_strength text NOT NULL,
  critical_gap text NOT NULL,
  development_plan text NOT NULL,
  strength_score int NOT NULL CHECK (strength_score BETWEEN 1 AND 10),
  gap_severity text NOT NULL CHECK (gap_severity IN ('low','medium','high','critical')),
  promotion_decision text NOT NULL CHECK (promotion_decision IN ('promote','retain','coach','exit','hold')),
  quarter text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE leadership_dev_milestones_r2693 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES leadership_dev_plans_r2693(id) ON DELETE CASCADE,
  milestone_title text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('not_started','in_progress','completed','blocked','at_risk')),
  completion_pct int NOT NULL CHECK (completion_pct BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE leadership_dev_plans_r2693 ENABLE ROW LEVEL SECURITY;
ALTER TABLE leadership_dev_milestones_r2693 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON leadership_dev_plans_r2693;
CREATE POLICY founder_all ON leadership_dev_plans_r2693 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON leadership_dev_milestones_r2693;
CREATE POLICY founder_all ON leadership_dev_milestones_r2693 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO leadership_dev_plans_r2693 (hire_name, role_title, hire_date, top_strength, critical_gap, development_plan, strength_score, gap_severity, promotion_decision, quarter) VALUES
('Priya Nair','VP Engineering','2025-09-01','System design depth','Cross-functional comms','Toastmasters + weekly 1:1 with CMO',9,'medium','promote','Q2-2026'),
('Rahul Iyer','Head of Sales','2025-11-15','Pipeline velocity','Forecasting accuracy','MEDDICC bootcamp + RevOps shadowing',8,'high','coach','Q2-2026'),
('Anjali Verma','Director Ops','2026-01-10','Process rigor','Strategic thinking','MBA exec module + scenario planning',7,'medium','retain','Q2-2026'),
('Karthik Rao','Lead Engineer','2025-07-22','Code velocity','People management','Manager onboarding + peer coach',8,'high','coach','Q2-2026'),
('Sneha Pillai','Product Lead','2026-02-05','Customer empathy','Technical depth','Pair with sr-eng + SQL bootcamp',7,'medium','retain','Q2-2026'),
('Vikram Shah','GM South','2025-10-30','Field execution','Data literacy','Looker training + KPI dashboards',6,'critical','hold','Q2-2026'),
('Meera Joshi','Head HR','2025-12-12','Culture building','Hiring funnel ops','ATS audit + Greenhouse cert',8,'low','promote','Q2-2026');

INSERT INTO leadership_dev_milestones_r2693 (plan_id, milestone_title, due_date, status, completion_pct, notes)
SELECT id, 'Complete Toastmasters L1','2026-07-15'::date,'in_progress',60,'Speech 3 of 5 done' FROM leadership_dev_plans_r2693 WHERE hire_name='Priya Nair' UNION ALL
SELECT id, 'Hit 90% forecast accuracy','2026-08-30'::date,'at_risk',40,'Q1 miss by 18%' FROM leadership_dev_plans_r2693 WHERE hire_name='Rahul Iyer' UNION ALL
SELECT id, 'Finish MBA exec module 2','2026-09-15'::date,'not_started',0,'Enrollment confirmed' FROM leadership_dev_plans_r2693 WHERE hire_name='Anjali Verma' UNION ALL
SELECT id, 'Manage team of 4 for 90d','2026-10-01'::date,'in_progress',55,'Direct reports onboarded' FROM leadership_dev_plans_r2693 WHERE hire_name='Karthik Rao' UNION ALL
SELECT id, 'Ship SQL bootcamp cert','2026-07-30'::date,'completed',100,'Cert hash xyz' FROM leadership_dev_plans_r2693 WHERE hire_name='Sneha Pillai' UNION ALL
SELECT id, 'Looker dash launched','2026-08-15'::date,'blocked',20,'Waiting on data eng' FROM leadership_dev_plans_r2693 WHERE hire_name='Vikram Shah' UNION ALL
SELECT id, 'Greenhouse rollout','2026-07-01'::date,'completed',100,'Live since June' FROM leadership_dev_plans_r2693 WHERE hire_name='Meera Joshi';

DROP FUNCTION IF EXISTS r2693_summary();
CREATE OR REPLACE FUNCTION r2693_summary()
RETURNS TABLE(total_plans int, promote_count int, coach_count int, exit_count int, avg_strength numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE promotion_decision='promote')::int,
    COUNT(*) FILTER (WHERE promotion_decision='coach')::int,
    COUNT(*) FILTER (WHERE promotion_decision='exit')::int,
    ROUND(AVG(strength_score)::numeric, 2)
  FROM leadership_dev_plans_r2693;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2693_list_plans();
CREATE OR REPLACE FUNCTION r2693_list_plans()
RETURNS SETOF leadership_dev_plans_r2693
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM leadership_dev_plans_r2693 ORDER BY strength_score DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_list_plans() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_list_plans() TO authenticated;

DROP FUNCTION IF EXISTS r2693_list_milestones();
CREATE OR REPLACE FUNCTION r2693_list_milestones()
RETURNS TABLE(hire_name text, milestone_title text, due_date date, status text, completion_pct int, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.hire_name, m.milestone_title, m.due_date, m.status, m.completion_pct, m.notes
  FROM leadership_dev_milestones_r2693 m JOIN leadership_dev_plans_r2693 p ON p.id = m.plan_id
  ORDER BY m.due_date ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_list_milestones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_list_milestones() TO authenticated;

DROP FUNCTION IF EXISTS r2693_gap_breakdown();
CREATE OR REPLACE FUNCTION r2693_gap_breakdown()
RETURNS TABLE(gap_severity text, plan_count int, avg_strength numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.gap_severity, COUNT(*)::int, ROUND(AVG(p.strength_score)::numeric, 2)
  FROM leadership_dev_plans_r2693 p GROUP BY p.gap_severity ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_gap_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_gap_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2693_at_risk_milestones();
CREATE OR REPLACE FUNCTION r2693_at_risk_milestones()
RETURNS TABLE(hire_name text, milestone_title text, status text, completion_pct int, due_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.hire_name, m.milestone_title, m.status, m.completion_pct, m.due_date
  FROM leadership_dev_milestones_r2693 m JOIN leadership_dev_plans_r2693 p ON p.id = m.plan_id
  WHERE m.status IN ('at_risk','blocked') ORDER BY m.due_date ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_at_risk_milestones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_at_risk_milestones() TO authenticated;

DROP FUNCTION IF EXISTS r2693_promotion_distribution();
CREATE OR REPLACE FUNCTION r2693_promotion_distribution()
RETURNS TABLE(promotion_decision text, hire_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.promotion_decision, COUNT(*)::int FROM leadership_dev_plans_r2693 p
  GROUP BY p.promotion_decision ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_promotion_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_promotion_distribution() TO authenticated;

DROP FUNCTION IF EXISTS r2693_milestone_completion_avg();
CREATE OR REPLACE FUNCTION r2693_milestone_completion_avg()
RETURNS TABLE(hire_name text, role_title text, avg_completion numeric, milestone_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.hire_name, p.role_title, ROUND(AVG(m.completion_pct)::numeric, 1), COUNT(m.id)::int
  FROM leadership_dev_plans_r2693 p LEFT JOIN leadership_dev_milestones_r2693 m ON m.plan_id = p.id
  GROUP BY p.hire_name, p.role_title ORDER BY AVG(m.completion_pct) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_milestone_completion_avg() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_milestone_completion_avg() TO authenticated;

DROP FUNCTION IF EXISTS r2693_top_strength_hires();
CREATE OR REPLACE FUNCTION r2693_top_strength_hires()
RETURNS TABLE(hire_name text, role_title text, top_strength text, strength_score int, promotion_decision text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.hire_name, p.role_title, p.top_strength, p.strength_score, p.promotion_decision
  FROM leadership_dev_plans_r2693 p WHERE p.strength_score >= 8 ORDER BY p.strength_score DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2693_top_strength_hires() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2693_top_strength_hires() TO authenticated;

COMMIT;