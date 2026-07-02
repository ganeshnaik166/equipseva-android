BEGIN;

-- ============================================================================
-- Round 2708: Customer Quarterly Clinical Outcome Attribution
-- Equipment × clinical outcome × measured × our contribution × evidence × follow-up
-- ============================================================================

-- Table 1: Clinical outcome attribution records
CREATE TABLE IF NOT EXISTS customer_quarterly_clinical_outcome_attribution_r2708 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_name text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier1','tier2','tier3','metro','rural')),
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','surgical','life_support','diagnostics','dialysis','cardiac','neonatal')),
  equipment_model text NOT NULL,
  clinical_outcome text NOT NULL,
  outcome_metric_name text NOT NULL,
  baseline_value numeric(10,2) NOT NULL,
  measured_value numeric(10,2) NOT NULL,
  delta_pct numeric(6,2) NOT NULL,
  uptime_contribution_pct numeric(5,2) NOT NULL CHECK (uptime_contribution_pct BETWEEN 0 AND 100),
  attribution_strength text NOT NULL CHECK (attribution_strength IN ('strong','moderate','weak','indirect')),
  evidence_doc_url text,
  evidence_type text NOT NULL CHECK (evidence_type IN ('chart_audit','registry_data','peer_review','self_report','third_party')),
  follow_up_action text NOT NULL,
  follow_up_owner text NOT NULL,
  follow_up_due_date date NOT NULL,
  follow_up_status text NOT NULL DEFAULT 'open' CHECK (follow_up_status IN ('open','in_progress','closed','blocked')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_quarterly_clinical_outcome_attribution_r2708 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_quarterly_clinical_outcome_attribution_r2708;
CREATE POLICY founder_all ON customer_quarterly_clinical_outcome_attribution_r2708 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_quarterly_clinical_outcome_attribution_r2708 (hospital_name, hospital_tier, quarter, equipment_category, equipment_model, clinical_outcome, outcome_metric_name, baseline_value, measured_value, delta_pct, uptime_contribution_pct, attribution_strength, evidence_doc_url, evidence_type, follow_up_action, follow_up_owner, follow_up_due_date, follow_up_status) VALUES
('Apollo Jubilee Hills','metro','Q2-2026','imaging','Siemens Magnetom Sola 1.5T','reduced_scan_cancellations','scan_cancellation_rate_pct',8.40,2.10,-75.00,98.50,'strong','https://docs.equipseva.com/evidence/r2708/apollo-mri-q2.pdf','chart_audit','quarterly_business_review_with_radiology_chief','priya.sharma@equipseva.com','2026-07-15','in_progress'),
('KIMS Secunderabad','tier1','Q2-2026','cardiac','GE Vivid E95 Echo','faster_door_to_balloon','door_to_balloon_minutes',92.00,68.00,-26.09,94.20,'strong','https://docs.equipseva.com/evidence/r2708/kims-cath-q2.pdf','registry_data','present_outcome_to_cardio_team_executive_committee','rohan.iyer@equipseva.com','2026-07-22','open'),
('Yashoda Somajiguda','metro','Q1-2026','life_support','Drager Evita V800 Ventilator','lower_vap_rate','ventilator_associated_pneumonia_per_1000_days',6.80,3.10,-54.41,89.40,'moderate','https://docs.equipseva.com/evidence/r2708/yashoda-icu-q1.pdf','peer_review','co_author_case_study_with_critical_care_head','aisha.khan@equipseva.com','2026-08-30','open'),
('Continental Gachibowli','tier1','Q2-2026','dialysis','Fresenius 5008S CorDiax','fewer_session_aborts','session_abort_rate_pct',4.20,1.30,-69.05,96.10,'strong','https://docs.equipseva.com/evidence/r2708/continental-nephro-q2.pdf','chart_audit','publish_internal_case_brief_for_marketing','varun.menon@equipseva.com','2026-07-30','in_progress'),
('Rainbow Banjara Hills','tier1','Q2-2026','neonatal','GE Giraffe OmniBed','improved_thermoregulation','nicu_thermoregulation_compliance_pct',82.00,96.50,17.68,99.20,'strong','https://docs.equipseva.com/evidence/r2708/rainbow-nicu-q2.pdf','chart_audit','request_nicu_director_reference_letter','sneha.rao@equipseva.com','2026-08-05','open'),
('AIG Hospitals Gachibowli','metro','Q2-2026','surgical','Karl Storz Image1 S 4K','reduced_lap_chole_conversion','open_conversion_rate_pct',3.50,1.10,-68.57,97.80,'moderate','https://docs.equipseva.com/evidence/r2708/aig-gi-q2.pdf','registry_data','build_4k_endo_uptime_one_pager_for_sales','kabir.singh@equipseva.com','2026-07-18','closed'),
('Care Hospitals Banjara','tier1','Q2-2026','diagnostics','Roche Cobas 6000','faster_critical_result_tat','critical_lab_tat_minutes',55.00,32.00,-41.82,92.70,'strong','https://docs.equipseva.com/evidence/r2708/care-lab-q2.pdf','chart_audit','co_present_at_lab_directors_summit_august','meera.joshi@equipseva.com','2026-08-12','open'),
('Sunshine Paradise','tier2','Q1-2026','imaging','Philips Ingenuity CT 128','lower_repeat_scan_rate','repeat_scan_rate_pct',6.20,2.40,-61.29,91.50,'moderate','https://docs.equipseva.com/evidence/r2708/sunshine-ct-q1.pdf','self_report','validate_with_external_audit_q3','rajeev.nair@equipseva.com','2026-09-15','blocked');

-- Table 2: Per-quarter rollup with attribution scoring
CREATE TABLE IF NOT EXISTS customer_quarterly_outcome_rollup_r2708 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_name text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  outcomes_measured integer NOT NULL CHECK (outcomes_measured BETWEEN 0 AND 200),
  outcomes_improved integer NOT NULL CHECK (outcomes_improved BETWEEN 0 AND 200),
  outcomes_attributed_strong integer NOT NULL CHECK (outcomes_attributed_strong BETWEEN 0 AND 200),
  weighted_attribution_score numeric(6,2) NOT NULL CHECK (weighted_attribution_score BETWEEN 0 AND 100),
  evidence_completeness_pct numeric(5,2) NOT NULL CHECK (evidence_completeness_pct BETWEEN 0 AND 100),
  reference_willingness text NOT NULL CHECK (reference_willingness IN ('public_logo','named_quote','blind_quote','internal_only','declined')),
  renewal_signal text NOT NULL CHECK (renewal_signal IN ('strong_yes','likely','at_risk','churning')),
  next_qbr_date date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_quarterly_outcome_rollup_r2708 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_quarterly_outcome_rollup_r2708;
CREATE POLICY founder_all ON customer_quarterly_outcome_rollup_r2708 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_quarterly_outcome_rollup_r2708 (hospital_name, quarter, outcomes_measured, outcomes_improved, outcomes_attributed_strong, weighted_attribution_score, evidence_completeness_pct, reference_willingness, renewal_signal, next_qbr_date, notes) VALUES
('Apollo Jubilee Hills','Q2-2026',12,11,8,87.40,94.50,'public_logo','strong_yes','2026-07-15','MRI uptime story is the lead reference; CMO is co-authoring whitepaper.'),
('KIMS Secunderabad','Q2-2026',9,7,6,79.20,88.00,'named_quote','strong_yes','2026-07-22','Door-to-balloon delta is the standout; cath lab director is willing to be quoted.'),
('Yashoda Somajiguda','Q1-2026',14,10,5,68.50,72.40,'blind_quote','likely','2026-07-30','VAP reduction is real but attribution is partly bundled care; need third party.'),
('Continental Gachibowli','Q2-2026',8,8,7,91.80,96.20,'public_logo','strong_yes','2026-08-05','All 8 nephro outcomes moved; cleanest attribution case in the portfolio.'),
('Rainbow Banjara Hills','Q2-2026',6,6,6,93.50,98.00,'public_logo','strong_yes','2026-08-12','NICU thermoregulation is best-in-class; ask for director reference letter.'),
('AIG Hospitals Gachibowli','Q2-2026',10,9,7,84.60,90.10,'named_quote','strong_yes','2026-07-18','Endo conversion rate halved; GI chief is presenting at AIG academic day.'),
('Sunshine Paradise','Q1-2026',7,5,2,54.20,61.30,'internal_only','at_risk','2026-09-15','Repeat scan rate improved but evidence is self-reported; needs external audit.');

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2708_kpi_summary()
RETURNS TABLE (
  total_outcomes integer,
  strong_attributions integer,
  public_logo_refs integer,
  avg_delta_pct numeric,
  avg_uptime_contribution_pct numeric,
  open_followups integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM customer_quarterly_clinical_outcome_attribution_r2708),
    (SELECT COUNT(*)::int FROM customer_quarterly_clinical_outcome_attribution_r2708 WHERE attribution_strength = 'strong'),
    (SELECT COUNT(*)::int FROM customer_quarterly_outcome_rollup_r2708 WHERE reference_willingness = 'public_logo'),
    (SELECT COALESCE(ROUND(AVG(ABS(delta_pct))::numeric, 2), 0) FROM customer_quarterly_clinical_outcome_attribution_r2708),
    (SELECT COALESCE(ROUND(AVG(uptime_contribution_pct)::numeric, 2), 0) FROM customer_quarterly_clinical_outcome_attribution_r2708),
    (SELECT COUNT(*)::int FROM customer_quarterly_clinical_outcome_attribution_r2708 WHERE follow_up_status IN ('open','in_progress'));
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_kpi_summary() TO authenticated;

-- ============================================================================
-- RPC 2: Outcome rows
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_outcomes();
CREATE OR REPLACE FUNCTION founder_r2708_outcomes()
RETURNS SETOF customer_quarterly_clinical_outcome_attribution_r2708
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_quarterly_clinical_outcome_attribution_r2708 ORDER BY ABS(delta_pct) DESC, hospital_name;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_outcomes() TO authenticated;

-- ============================================================================
-- RPC 3: Rollup rows
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_rollup();
CREATE OR REPLACE FUNCTION founder_r2708_rollup()
RETURNS SETOF customer_quarterly_outcome_rollup_r2708
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_quarterly_outcome_rollup_r2708 ORDER BY weighted_attribution_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_rollup() TO authenticated;

-- ============================================================================
-- RPC 4: By equipment category
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_by_category();
CREATE OR REPLACE FUNCTION founder_r2708_by_category()
RETURNS TABLE (
  equipment_category text,
  outcomes_count integer,
  strong_count integer,
  avg_delta_pct numeric,
  avg_uptime_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.equipment_category,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE o.attribution_strength = 'strong')::int,
    ROUND(AVG(ABS(o.delta_pct))::numeric, 2),
    ROUND(AVG(o.uptime_contribution_pct)::numeric, 2)
  FROM customer_quarterly_clinical_outcome_attribution_r2708 o
  GROUP BY o.equipment_category
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_by_category() TO authenticated;

-- ============================================================================
-- RPC 5: By quarter
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_by_quarter();
CREATE OR REPLACE FUNCTION founder_r2708_by_quarter()
RETURNS TABLE (
  quarter text,
  outcomes_count integer,
  strong_attribution_count integer,
  avg_delta_pct numeric,
  hospitals_covered integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.quarter,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE o.attribution_strength = 'strong')::int,
    ROUND(AVG(ABS(o.delta_pct))::numeric, 2),
    COUNT(DISTINCT o.hospital_name)::int
  FROM customer_quarterly_clinical_outcome_attribution_r2708 o
  GROUP BY o.quarter
  ORDER BY o.quarter;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_by_quarter() TO authenticated;

-- ============================================================================
-- RPC 6: Reference readiness
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_reference_readiness();
CREATE OR REPLACE FUNCTION founder_r2708_reference_readiness()
RETURNS TABLE (
  reference_willingness text,
  hospital_count integer,
  avg_score numeric,
  avg_evidence_completeness numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.reference_willingness,
    COUNT(*)::int,
    ROUND(AVG(r.weighted_attribution_score)::numeric, 2),
    ROUND(AVG(r.evidence_completeness_pct)::numeric, 2)
  FROM customer_quarterly_outcome_rollup_r2708 r
  GROUP BY r.reference_willingness
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_reference_readiness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_reference_readiness() TO authenticated;

-- ============================================================================
-- RPC 7: Follow-up queue
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_followup_queue();
CREATE OR REPLACE FUNCTION founder_r2708_followup_queue()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  follow_up_action text,
  follow_up_owner text,
  follow_up_due_date date,
  follow_up_status text,
  days_until_due integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.hospital_name,
    o.follow_up_action,
    o.follow_up_owner,
    o.follow_up_due_date,
    o.follow_up_status,
    (o.follow_up_due_date - CURRENT_DATE)::int
  FROM customer_quarterly_clinical_outcome_attribution_r2708 o
  WHERE o.follow_up_status IN ('open','in_progress','blocked')
  ORDER BY o.follow_up_due_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_followup_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_followup_queue() TO authenticated;

-- ============================================================================
-- RPC 8: Renewal risk view
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2708_renewal_signals();
CREATE OR REPLACE FUNCTION founder_r2708_renewal_signals()
RETURNS TABLE (
  renewal_signal text,
  hospital_count integer,
  avg_attribution_score numeric,
  hospitals text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.renewal_signal,
    COUNT(*)::int,
    ROUND(AVG(r.weighted_attribution_score)::numeric, 2),
    string_agg(r.hospital_name, ', ' ORDER BY r.weighted_attribution_score DESC)
  FROM customer_quarterly_outcome_rollup_r2708 r
  GROUP BY r.renewal_signal
  ORDER BY
    CASE r.renewal_signal
      WHEN 'churning' THEN 1
      WHEN 'at_risk' THEN 2
      WHEN 'likely' THEN 3
      WHEN 'strong_yes' THEN 4
    END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2708_renewal_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2708_renewal_signals() TO authenticated;

COMMIT;
