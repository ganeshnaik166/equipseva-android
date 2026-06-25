BEGIN;

-- ============================================================================
-- Round 2692 — Customer Monthly Equipment Deprecation Warning (HEAVY ★★★★)
-- Equipment × age × spares risk × replacement window × decision × action
-- ============================================================================

-- ---------- Table 1: equipment deprecation warnings ----------
DROP TABLE IF EXISTS deprecation_warnings_r2692 CASCADE;
CREATE TABLE deprecation_warnings_r2692 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warning_month date NOT NULL,
  hospital_name text NOT NULL,
  equipment_model text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('ventilator','xray','ultrasound','ecg','dental_chair','autoclave','dialysis')),
  install_age_years numeric(4,2) NOT NULL,
  manufacturer_eol_status text NOT NULL CHECK (manufacturer_eol_status IN ('supported','last_orders','eol_announced','eol_active','obsolete')),
  spares_availability_pct numeric(5,2) NOT NULL,
  spares_lead_time_days int NOT NULL,
  failure_rate_per_month numeric(5,2) NOT NULL,
  replacement_window_months int NOT NULL,
  replacement_capex_lakhs numeric(8,2) NOT NULL,
  current_amc_lakhs_per_year numeric(8,2) NOT NULL,
  risk_band text NOT NULL CHECK (risk_band IN ('low','medium','high','critical')),
  decision text NOT NULL CHECK (decision IN ('monitor','plan_replacement','quote_now','stock_critical_spares','escalate_clinical')),
  warning_sent_at timestamptz,
  customer_acknowledged boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE deprecation_warnings_r2692 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON deprecation_warnings_r2692;
CREATE POLICY founder_all ON deprecation_warnings_r2692 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO deprecation_warnings_r2692
  (warning_month, hospital_name, equipment_model, equipment_category, install_age_years, manufacturer_eol_status, spares_availability_pct, spares_lead_time_days, failure_rate_per_month, replacement_window_months, replacement_capex_lakhs, current_amc_lakhs_per_year, risk_band, decision, warning_sent_at, customer_acknowledged)
VALUES
  ('2026-06-01','Apollo Hyderabad','Drager Evita V300','ventilator',9.50,'eol_announced',42.00,45,1.20,12,28.00,2.40,'high','plan_replacement', now() - interval '6 days', true),
  ('2026-06-01','Yashoda Secunderabad','Siemens Multix Fusion','xray',12.00,'eol_active',18.00,90,1.80,9,42.00,3.10,'critical','quote_now', now() - interval '4 days', false),
  ('2026-06-01','KIMS Kondapur','GE Vivid E9','ultrasound',7.20,'last_orders',61.00,28,0.40,18,35.00,2.80,'medium','stock_critical_spares', now() - interval '8 days', true),
  ('2026-06-01','CARE Banjara','Philips PageWriter TC30','ecg',5.80,'supported',88.00,7,0.10,36,4.50,0.55,'low','monitor', now() - interval '2 days', false),
  ('2026-06-01','Continental Gachibowli','A-dec 300 Dental Chair','dental_chair',11.40,'obsolete',9.00,120,2.30,6,8.20,0.95,'critical','escalate_clinical', now() - interval '1 day', false),
  ('2026-06-01','Sunshine Begumpet','Tuttnauer 3870EA','autoclave',8.10,'last_orders',54.00,21,0.60,15,3.80,0.42,'medium','plan_replacement', now() - interval '3 days', true),
  ('2026-06-01','Olive Hospital','Fresenius 4008S','dialysis',10.30,'eol_announced',31.00,60,1.05,10,18.50,2.10,'high','quote_now', now() - interval '5 days', false);

-- ---------- Table 2: monthly action log ----------
DROP TABLE IF EXISTS deprecation_actions_r2692 CASCADE;
CREATE TABLE deprecation_actions_r2692 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warning_id uuid NOT NULL REFERENCES deprecation_warnings_r2692(id) ON DELETE CASCADE,
  action_taken text NOT NULL CHECK (action_taken IN ('warning_sent','customer_meeting','quote_drafted','spares_stocked','escalation_filed','replacement_ordered')),
  owner text NOT NULL,
  due_date date NOT NULL,
  completed_at timestamptz,
  outcome text NOT NULL CHECK (outcome IN ('pending','in_progress','completed','blocked','customer_declined')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE deprecation_actions_r2692 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON deprecation_actions_r2692;
CREATE POLICY founder_all ON deprecation_actions_r2692 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'warning_sent','customer_success_lead', current_date + 2, now() - interval '6 days','completed','Email + WhatsApp delivered' FROM deprecation_warnings_r2692 WHERE hospital_name='Apollo Hyderabad' LIMIT 1;

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'quote_drafted','sales_engineer', current_date + 7, NULL,'in_progress','Drafting Siemens Mobilett quote' FROM deprecation_warnings_r2692 WHERE hospital_name='Yashoda Secunderabad' LIMIT 1;

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'spares_stocked','parts_lead', current_date + 14, NULL,'pending','3x probe heads + 1x board' FROM deprecation_warnings_r2692 WHERE hospital_name='KIMS Kondapur' LIMIT 1;

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'escalation_filed','clinical_lead', current_date + 1, now() - interval '12 hours','completed','Patient safety risk flagged' FROM deprecation_warnings_r2692 WHERE hospital_name='Continental Gachibowli' LIMIT 1;

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'customer_meeting','founder', current_date + 4, NULL,'pending','Onsite walkthrough scheduled' FROM deprecation_warnings_r2692 WHERE hospital_name='Sunshine Begumpet' LIMIT 1;

INSERT INTO deprecation_actions_r2692
  (warning_id, action_taken, owner, due_date, completed_at, outcome, notes)
SELECT id, 'replacement_ordered','sales_engineer', current_date + 30, NULL,'in_progress','Fresenius 5008S PO drafted' FROM deprecation_warnings_r2692 WHERE hospital_name='Olive Hospital' LIMIT 1;

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS r2692_kpi_summary();
CREATE OR REPLACE FUNCTION r2692_kpi_summary()
RETURNS TABLE(total_warnings int, critical_count int, high_count int, ack_rate_pct numeric, replacement_capex_lakhs numeric, avg_age_years numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE risk_band='critical')::int,
    COUNT(*) FILTER (WHERE risk_band='high')::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE customer_acknowledged) / NULLIF(COUNT(*),0), 1),
    ROUND(SUM(replacement_capex_lakhs)::numeric, 2),
    ROUND(AVG(install_age_years)::numeric, 2)
  FROM deprecation_warnings_r2692;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2692_critical_warnings();
CREATE OR REPLACE FUNCTION r2692_critical_warnings()
RETURNS TABLE(id uuid, hospital_name text, equipment_model text, install_age_years numeric, spares_availability_pct numeric, replacement_capex_lakhs numeric, decision text, customer_acknowledged boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_name, w.equipment_model, w.install_age_years, w.spares_availability_pct, w.replacement_capex_lakhs, w.decision, w.customer_acknowledged
  FROM deprecation_warnings_r2692 w
  WHERE w.risk_band IN ('critical','high')
  ORDER BY w.risk_band DESC, w.install_age_years DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_critical_warnings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_critical_warnings() TO authenticated;

DROP FUNCTION IF EXISTS r2692_by_category();
CREATE OR REPLACE FUNCTION r2692_by_category()
RETURNS TABLE(equipment_category text, units int, avg_age numeric, avg_spares_pct numeric, total_capex_lakhs numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.equipment_category, COUNT(*)::int, ROUND(AVG(w.install_age_years)::numeric,2), ROUND(AVG(w.spares_availability_pct)::numeric,1), ROUND(SUM(w.replacement_capex_lakhs)::numeric,2)
  FROM deprecation_warnings_r2692 w
  GROUP BY w.equipment_category
  ORDER BY SUM(w.replacement_capex_lakhs) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_by_category() TO authenticated;

DROP FUNCTION IF EXISTS r2692_eol_status_breakdown();
CREATE OR REPLACE FUNCTION r2692_eol_status_breakdown()
RETURNS TABLE(manufacturer_eol_status text, units int, avg_failure_rate numeric, avg_lead_time_days numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.manufacturer_eol_status, COUNT(*)::int, ROUND(AVG(w.failure_rate_per_month)::numeric,2), ROUND(AVG(w.spares_lead_time_days)::numeric,1)
  FROM deprecation_warnings_r2692 w
  GROUP BY w.manufacturer_eol_status
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_eol_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_eol_status_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2692_decision_funnel();
CREATE OR REPLACE FUNCTION r2692_decision_funnel()
RETURNS TABLE(decision text, units int, capex_lakhs numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.decision, COUNT(*)::int, ROUND(SUM(w.replacement_capex_lakhs)::numeric,2)
  FROM deprecation_warnings_r2692 w
  GROUP BY w.decision
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_decision_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_decision_funnel() TO authenticated;

DROP FUNCTION IF EXISTS r2692_action_pipeline();
CREATE OR REPLACE FUNCTION r2692_action_pipeline()
RETURNS TABLE(id uuid, hospital_name text, equipment_model text, action_taken text, owner text, due_date date, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, w.hospital_name, w.equipment_model, a.action_taken, a.owner, a.due_date, a.outcome
  FROM deprecation_actions_r2692 a
  JOIN deprecation_warnings_r2692 w ON w.id = a.warning_id
  ORDER BY a.due_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_action_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_action_pipeline() TO authenticated;

DROP FUNCTION IF EXISTS r2692_replacement_window();
CREATE OR REPLACE FUNCTION r2692_replacement_window()
RETURNS TABLE(window_bucket text, units int, capex_lakhs numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN w.replacement_window_months <= 6 THEN 'within_6_months'
      WHEN w.replacement_window_months <= 12 THEN '6_to_12_months'
      WHEN w.replacement_window_months <= 24 THEN '12_to_24_months'
      ELSE 'beyond_24_months'
    END,
    COUNT(*)::int,
    ROUND(SUM(w.replacement_capex_lakhs)::numeric,2)
  FROM deprecation_warnings_r2692 w
  GROUP BY 1
  ORDER BY MIN(w.replacement_window_months);
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_replacement_window() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_replacement_window() TO authenticated;

DROP FUNCTION IF EXISTS r2692_unacknowledged_warnings();
CREATE OR REPLACE FUNCTION r2692_unacknowledged_warnings()
RETURNS TABLE(id uuid, hospital_name text, equipment_model text, risk_band text, warning_sent_at timestamptz, days_since_sent int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_name, w.equipment_model, w.risk_band, w.warning_sent_at,
    EXTRACT(DAY FROM (now() - w.warning_sent_at))::int
  FROM deprecation_warnings_r2692 w
  WHERE NOT w.customer_acknowledged AND w.warning_sent_at IS NOT NULL
  ORDER BY w.warning_sent_at ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2692_unacknowledged_warnings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2692_unacknowledged_warnings() TO authenticated;

COMMIT;
