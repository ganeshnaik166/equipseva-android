BEGIN;

CREATE TABLE IF NOT EXISTS chain_protocol_recommendations_r2739 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3')),
  protocol_area text NOT NULL,
  our_recommendation text NOT NULL,
  rationale text NOT NULL,
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A','B','C','D')),
  adoption_status text NOT NULL CHECK (adoption_status IN ('proposed','piloting','adopted','rejected','revising')),
  adoption_percent numeric(5,2) NOT NULL DEFAULT 0,
  clinical_outcome_delta_percent numeric(6,2),
  proposed_at date NOT NULL,
  decision_due_at date NOT NULL,
  champion_clinician text,
  story text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_protocol_recommendations_r2739 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_protocol_recommendations_r2739;
CREATE POLICY founder_all ON chain_protocol_recommendations_r2739 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS chain_protocol_outcome_logs_r2739 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id uuid NOT NULL REFERENCES chain_protocol_recommendations_r2739(id) ON DELETE CASCADE,
  recorded_on date NOT NULL,
  hospitals_adopted int NOT NULL DEFAULT 0,
  hospitals_total int NOT NULL DEFAULT 0,
  outcome_metric text NOT NULL,
  baseline_value numeric(10,2) NOT NULL,
  current_value numeric(10,2) NOT NULL,
  delta_percent numeric(6,2) NOT NULL,
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('improved','flat','regressed')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_protocol_outcome_logs_r2739 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_protocol_outcome_logs_r2739;
CREATE POLICY founder_all ON chain_protocol_outcome_logs_r2739 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_protocol_recommendations_r2739 (chain_name, chain_tier, protocol_area, our_recommendation, rationale, evidence_grade, adoption_status, adoption_percent, clinical_outcome_delta_percent, proposed_at, decision_due_at, champion_clinician, story) VALUES
('Apollo South India','tier1','Ventilator PM cycle','Quarterly 90-day PM with O2 sensor swap','Sensor drift causes 38% of vent recalls; 90d cycle eliminates','A','adopted',92.50,18.40,'2026-04-15'::date,'2026-05-30'::date,'Dr. Reddy (CMO)','Apollo CMO signed off after Hyderabad ICU saw 18% fewer vent reintubations'),
('Manipal Hospitals','tier1','OT laminar flow QC','Monthly particle count + HEPA log','SSI rate correlates strongly with airflow drift','A','piloting','45.00',9.20,'2026-05-01'::date,'2026-06-30'::date,'Dr. Pai (Infection control)','Manipal Bangalore pilot 3 OTs showed SSI drop from 2.1% to 1.9%'),
('Fortis Healthcare','tier2','Dialysis water RO','Bi-monthly endotoxin test + RO membrane log','BIS IS-13428 compliance + reduces pyrogen reactions','B','proposed','0.00',NULL,'2026-06-10'::date,'2026-07-15'::date,'Dr. Mehta (Nephro head)','Proposed after Fortis Mohali pyrogen incident Q1 2026'),
('Aster DM Healthcare','tier1','MRI cold-head service','Quarterly helium top-off + cold-head check','He boil-off prevents quench events (₹40L recovery)','A','adopted','78.00',12.50,'2026-03-20'::date,'2026-05-15'::date,'Dr. Iqbal (Radiology)','Aster Kochi avoided 1 quench event in Q2 — paid back contract 4x'),
('Yashoda Hospitals','tier2','Endoscope reprocessing','Per-cycle MEC validation + leak test log','CRE outbreak risk; AERs miss 11% leaks','B','revising','25.00',NULL,'2026-04-25'::date,'2026-07-10'::date,'Dr. Rao (GI)','Yashoda revising after staff push-back on per-cycle leak test time'),
('Narayana Health','tier1','Cath lab radiation','Quarterly dosimeter calibration + shield audit','Operator cumulative dose creeping above AERB limit','A','adopted','88.00',22.10,'2026-02-10'::date,'2026-04-20'::date,'Dr. Shetty (Cardiac)','Narayana Bangalore staff dose down 22% — surgeons celebrated win'),
('KIMS Hospitals','tier2','Neonatal incubator humidity','Weekly humidity sensor verify + chamber clean','NICU sepsis cluster traced to biofilm in humidifier','B','piloting','60.00',7.80,'2026-05-15'::date,'2026-07-05'::date,'Dr. Devi (Neonatology)','KIMS Hyderabad NICU sepsis rate down 8% in pilot 2 units');

INSERT INTO chain_protocol_outcome_logs_r2739 (recommendation_id, recorded_on, hospitals_adopted, hospitals_total, outcome_metric, baseline_value, current_value, delta_percent, outcome_grade, note)
SELECT id, '2026-06-20'::date, 11, 12, 'vent reintubation rate %', 4.80, 3.92, 18.40, 'improved', 'Q2 outcome ahead of model' FROM chain_protocol_recommendations_r2739 WHERE chain_name='Apollo South India'
UNION ALL
SELECT id, '2026-06-18'::date, 3, 6, 'SSI rate %', 2.10, 1.90, 9.20, 'improved', 'Pilot OTs only' FROM chain_protocol_recommendations_r2739 WHERE chain_name='Manipal Hospitals'
UNION ALL
SELECT id, '2026-06-15'::date, 7, 9, 'cryostat helium boil-off L/quarter', 12.00, 10.50, 12.50, 'improved', 'No quench events Q2' FROM chain_protocol_recommendations_r2739 WHERE chain_name='Aster DM Healthcare'
UNION ALL
SELECT id, '2026-06-22'::date, 14, 16, 'operator cumulative dose mSv', 18.50, 14.40, 22.10, 'improved', 'AERB report cleaner' FROM chain_protocol_recommendations_r2739 WHERE chain_name='Narayana Health'
UNION ALL
SELECT id, '2026-06-19'::date, 3, 5, 'NICU sepsis incidents/month', 4.20, 3.87, 7.80, 'improved', 'Two units; biofilm cleared' FROM chain_protocol_recommendations_r2739 WHERE chain_name='KIMS Hospitals'
UNION ALL
SELECT id, '2026-06-23'::date, 1, 4, 'AER leak miss rate %', 11.00, 11.00, 0.00, 'flat', 'Staff push-back; no measurable change yet' FROM chain_protocol_recommendations_r2739 WHERE chain_name='Yashoda Hospitals';

DROP FUNCTION IF EXISTS founder_chain_protocol_overview_r2739();
CREATE FUNCTION founder_chain_protocol_overview_r2739()
RETURNS TABLE(total_chains int, total_recommendations int, adopted_count int, piloting_count int, proposed_count int, revising_count int, avg_adoption_percent numeric, avg_outcome_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_name)::int,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE adoption_status='adopted')::int,
    COUNT(*) FILTER (WHERE adoption_status='piloting')::int,
    COUNT(*) FILTER (WHERE adoption_status='proposed')::int,
    COUNT(*) FILTER (WHERE adoption_status='revising')::int,
    ROUND(AVG(adoption_percent)::numeric, 2),
    ROUND(AVG(clinical_outcome_delta_percent)::numeric, 2)
  FROM chain_protocol_recommendations_r2739;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_overview_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_overview_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_list_r2739();
CREATE FUNCTION founder_chain_protocol_list_r2739()
RETURNS TABLE(id uuid, chain_name text, chain_tier text, protocol_area text, our_recommendation text, evidence_grade text, adoption_status text, adoption_percent numeric, clinical_outcome_delta_percent numeric, champion_clinician text, decision_due_at date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.chain_tier, r.protocol_area, r.our_recommendation, r.evidence_grade, r.adoption_status, r.adoption_percent, r.clinical_outcome_delta_percent, r.champion_clinician, r.decision_due_at
  FROM chain_protocol_recommendations_r2739 r
  ORDER BY r.adoption_percent DESC, r.proposed_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_list_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_list_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_by_status_r2739();
CREATE FUNCTION founder_chain_protocol_by_status_r2739()
RETURNS TABLE(adoption_status text, recommendation_count int, avg_adoption numeric, avg_outcome_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.adoption_status, COUNT(*)::int, ROUND(AVG(r.adoption_percent)::numeric, 2), ROUND(AVG(r.clinical_outcome_delta_percent)::numeric, 2)
  FROM chain_protocol_recommendations_r2739 r
  GROUP BY r.adoption_status
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_by_status_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_by_status_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_by_tier_r2739();
CREATE FUNCTION founder_chain_protocol_by_tier_r2739()
RETURNS TABLE(chain_tier text, chain_count int, adopted_count int, avg_outcome_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_tier, COUNT(DISTINCT r.chain_name)::int, COUNT(*) FILTER (WHERE r.adoption_status='adopted')::int, ROUND(AVG(r.clinical_outcome_delta_percent)::numeric, 2)
  FROM chain_protocol_recommendations_r2739 r
  GROUP BY r.chain_tier
  ORDER BY r.chain_tier;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_by_tier_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_by_tier_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_outcome_logs_r2739();
CREATE FUNCTION founder_chain_protocol_outcome_logs_r2739()
RETURNS TABLE(id uuid, chain_name text, protocol_area text, recorded_on date, outcome_metric text, baseline_value numeric, current_value numeric, delta_percent numeric, outcome_grade text, hospitals_adopted int, hospitals_total int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, r.chain_name, r.protocol_area, l.recorded_on, l.outcome_metric, l.baseline_value, l.current_value, l.delta_percent, l.outcome_grade, l.hospitals_adopted, l.hospitals_total
  FROM chain_protocol_outcome_logs_r2739 l
  JOIN chain_protocol_recommendations_r2739 r ON r.id=l.recommendation_id
  ORDER BY l.recorded_on DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_outcome_logs_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_outcome_logs_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_top_wins_r2739();
CREATE FUNCTION founder_chain_protocol_top_wins_r2739()
RETURNS TABLE(chain_name text, protocol_area text, our_recommendation text, clinical_outcome_delta_percent numeric, story text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.protocol_area, r.our_recommendation, r.clinical_outcome_delta_percent, r.story
  FROM chain_protocol_recommendations_r2739 r
  WHERE r.adoption_status='adopted' AND r.clinical_outcome_delta_percent IS NOT NULL
  ORDER BY r.clinical_outcome_delta_percent DESC NULLS LAST
  LIMIT 5;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_top_wins_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_top_wins_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_pending_decisions_r2739();
CREATE FUNCTION founder_chain_protocol_pending_decisions_r2739()
RETURNS TABLE(chain_name text, protocol_area text, our_recommendation text, adoption_status text, decision_due_at date, days_until_due int, champion_clinician text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.protocol_area, r.our_recommendation, r.adoption_status, r.decision_due_at, (r.decision_due_at - CURRENT_DATE)::int, r.champion_clinician
  FROM chain_protocol_recommendations_r2739 r
  WHERE r.adoption_status IN ('proposed','piloting','revising')
  ORDER BY r.decision_due_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_pending_decisions_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_pending_decisions_r2739() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_protocol_evidence_grade_mix_r2739();
CREATE FUNCTION founder_chain_protocol_evidence_grade_mix_r2739()
RETURNS TABLE(evidence_grade text, recommendation_count int, adoption_percent_avg numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.evidence_grade, COUNT(*)::int, ROUND(AVG(r.adoption_percent)::numeric, 2)
  FROM chain_protocol_recommendations_r2739 r
  GROUP BY r.evidence_grade
  ORDER BY r.evidence_grade;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_chain_protocol_evidence_grade_mix_r2739() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_protocol_evidence_grade_mix_r2739() TO authenticated;

COMMIT;