BEGIN;

-- =========================================================================
-- Round 2783 — Hospital Chain Quarterly Equipment AI Integration Pulse
-- chain × equipment × AI module × adoption × outcome × scale decision
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_ai_integration_pulse_r2783 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_quarter   text NOT NULL,
  chain_name      text NOT NULL,
  city            text NOT NULL,
  equipment_class text NOT NULL CHECK (equipment_class IN ('mri','ct','ventilator','dialysis','infusion','ultrasound','c_arm')),
  ai_module       text NOT NULL CHECK (ai_module IN ('predictive_fault','autonomous_triage','spare_forecast','energy_optimizer','image_qc','workflow_router')),
  units_eligible  int  NOT NULL CHECK (units_eligible > 0),
  units_live      int  NOT NULL CHECK (units_live >= 0),
  adoption_pct    numeric(5,2) NOT NULL CHECK (adoption_pct >= 0 AND adoption_pct <= 100),
  downtime_delta_pct numeric(6,2) NOT NULL,
  ticket_volume_delta_pct numeric(6,2) NOT NULL,
  npv_inr         bigint NOT NULL,
  scale_decision  text NOT NULL CHECK (scale_decision IN ('scale_all','expand_pilot','hold','retire')),
  decision_owner  text NOT NULL,
  recorded_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_ai_integration_pulse_r2783 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_ai_integration_pulse_r2783;
CREATE POLICY founder_all ON hospital_chain_ai_integration_pulse_r2783
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_ai_outcome_signals_r2783 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_quarter   text NOT NULL,
  chain_name      text NOT NULL,
  ai_module       text NOT NULL CHECK (ai_module IN ('predictive_fault','autonomous_triage','spare_forecast','energy_optimizer','image_qc','workflow_router')),
  signal_type     text NOT NULL CHECK (signal_type IN ('mttr_drop','sla_breach_avoided','spare_stockout_avoided','energy_saved','false_alert','clinician_complaint')),
  signal_count    int  NOT NULL CHECK (signal_count >= 0),
  monetary_value_inr bigint NOT NULL DEFAULT 0,
  trend_qoq_pct   numeric(6,2) NOT NULL,
  health          text NOT NULL CHECK (health IN ('green','amber','red')),
  recorded_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_ai_outcome_signals_r2783 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_ai_outcome_signals_r2783;
CREATE POLICY founder_all ON hospital_chain_ai_outcome_signals_r2783
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ---------------- SEED: pulse ----------------
INSERT INTO hospital_chain_ai_integration_pulse_r2783
  (pulse_quarter, chain_name, city, equipment_class, ai_module, units_eligible, units_live, adoption_pct, downtime_delta_pct, ticket_volume_delta_pct, npv_inr, scale_decision, decision_owner)
VALUES
  ('2026-Q2','Apollo','Hyderabad','mri','predictive_fault',18,15,83.33,-22.40,-18.10,8400000,'scale_all','founder'),
  ('2026-Q2','Manipal','Bengaluru','ct','image_qc',24,12,50.00,-9.80,-6.20,3100000,'expand_pilot','vp_ops'),
  ('2026-Q2','Fortis','Mumbai','ventilator','autonomous_triage',60,42,70.00,-15.10,-12.80,5600000,'scale_all','founder'),
  ('2026-Q2','Narayana','Bengaluru','dialysis','spare_forecast',45,28,62.22,-11.30,-9.50,4200000,'expand_pilot','vp_supply'),
  ('2026-Q2','KIMS','Hyderabad','infusion','workflow_router',120,30,25.00,-3.40,-1.10,420000,'hold','vp_ops'),
  ('2026-Q2','Yashoda','Hyderabad','ultrasound','image_qc',32,4,12.50,-1.20,2.40,-180000,'retire','founder'),
  ('2026-Q1','Apollo','Hyderabad','mri','predictive_fault',18,9,50.00,-12.10,-8.40,3900000,'expand_pilot','founder');

-- ---------------- SEED: outcome signals ----------------
INSERT INTO hospital_chain_ai_outcome_signals_r2783
  (pulse_quarter, chain_name, ai_module, signal_type, signal_count, monetary_value_inr, trend_qoq_pct, health)
VALUES
  ('2026-Q2','Apollo','predictive_fault','mttr_drop',412,2800000,18.40,'green'),
  ('2026-Q2','Apollo','predictive_fault','sla_breach_avoided',38,1500000,21.00,'green'),
  ('2026-Q2','Manipal','image_qc','false_alert',74,0,-12.10,'amber'),
  ('2026-Q2','Fortis','autonomous_triage','clinician_complaint',9,0,-30.00,'amber'),
  ('2026-Q2','Narayana','spare_forecast','spare_stockout_avoided',55,1100000,14.20,'green'),
  ('2026-Q2','KIMS','workflow_router','mttr_drop',12,180000,2.10,'amber'),
  ('2026-Q2','Yashoda','image_qc','clinician_complaint',31,0,42.00,'red');

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS r2783_chain_ai_pulse_overview();
CREATE OR REPLACE FUNCTION r2783_chain_ai_pulse_overview()
RETURNS TABLE (
  chains_tracked        int,
  ai_modules_live       int,
  avg_adoption_pct      numeric,
  total_npv_inr         bigint,
  scale_all_count       int,
  retire_count          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_name)::int,
    COUNT(DISTINCT ai_module)::int,
    ROUND(AVG(adoption_pct)::numeric, 2),
    COALESCE(SUM(npv_inr),0)::bigint,
    COUNT(*) FILTER (WHERE scale_decision = 'scale_all')::int,
    COUNT(*) FILTER (WHERE scale_decision = 'retire')::int
  FROM hospital_chain_ai_integration_pulse_r2783
  WHERE pulse_quarter = '2026-Q2';
END $$;
REVOKE EXECUTE ON FUNCTION r2783_chain_ai_pulse_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_chain_ai_pulse_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2783_chain_pulse_rows();
CREATE OR REPLACE FUNCTION r2783_chain_pulse_rows()
RETURNS SETOF hospital_chain_ai_integration_pulse_r2783
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM hospital_chain_ai_integration_pulse_r2783
  WHERE pulse_quarter = '2026-Q2'
  ORDER BY npv_inr DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_chain_pulse_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_chain_pulse_rows() TO authenticated;

DROP FUNCTION IF EXISTS r2783_ai_module_leaderboard();
CREATE OR REPLACE FUNCTION r2783_ai_module_leaderboard()
RETURNS TABLE (
  ai_module           text,
  chains_using        int,
  avg_adoption_pct    numeric,
  avg_downtime_delta  numeric,
  total_npv_inr       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.ai_module,
    COUNT(DISTINCT p.chain_name)::int,
    ROUND(AVG(p.adoption_pct)::numeric, 2),
    ROUND(AVG(p.downtime_delta_pct)::numeric, 2),
    COALESCE(SUM(p.npv_inr),0)::bigint
  FROM hospital_chain_ai_integration_pulse_r2783 p
  WHERE p.pulse_quarter = '2026-Q2'
  GROUP BY p.ai_module
  ORDER BY total_npv_inr DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_ai_module_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_ai_module_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS r2783_outcome_signal_rows();
CREATE OR REPLACE FUNCTION r2783_outcome_signal_rows()
RETURNS SETOF hospital_chain_ai_outcome_signals_r2783
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM hospital_chain_ai_outcome_signals_r2783
  WHERE pulse_quarter = '2026-Q2'
  ORDER BY monetary_value_inr DESC, signal_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_outcome_signal_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_outcome_signal_rows() TO authenticated;

DROP FUNCTION IF EXISTS r2783_decision_breakdown();
CREATE OR REPLACE FUNCTION r2783_decision_breakdown()
RETURNS TABLE (
  scale_decision  text,
  pilot_count     int,
  total_npv_inr   bigint,
  avg_adoption    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.scale_decision,
    COUNT(*)::int,
    COALESCE(SUM(p.npv_inr),0)::bigint,
    ROUND(AVG(p.adoption_pct)::numeric, 2)
  FROM hospital_chain_ai_integration_pulse_r2783 p
  WHERE p.pulse_quarter = '2026-Q2'
  GROUP BY p.scale_decision
  ORDER BY total_npv_inr DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_decision_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_decision_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2783_red_signals();
CREATE OR REPLACE FUNCTION r2783_red_signals()
RETURNS SETOF hospital_chain_ai_outcome_signals_r2783
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM hospital_chain_ai_outcome_signals_r2783
  WHERE health IN ('amber','red')
    AND pulse_quarter = '2026-Q2'
  ORDER BY (CASE health WHEN 'red' THEN 0 ELSE 1 END), trend_qoq_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_red_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_red_signals() TO authenticated;

DROP FUNCTION IF EXISTS r2783_qoq_adoption_trend();
CREATE OR REPLACE FUNCTION r2783_qoq_adoption_trend()
RETURNS TABLE (
  chain_name       text,
  ai_module        text,
  q1_adoption_pct  numeric,
  q2_adoption_pct  numeric,
  delta_pct        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q2.chain_name,
    q2.ai_module,
    COALESCE(q1.adoption_pct, 0)::numeric,
    q2.adoption_pct::numeric,
    ROUND((q2.adoption_pct - COALESCE(q1.adoption_pct, 0))::numeric, 2)
  FROM hospital_chain_ai_integration_pulse_r2783 q2
  LEFT JOIN hospital_chain_ai_integration_pulse_r2783 q1
    ON q1.chain_name = q2.chain_name
   AND q1.ai_module  = q2.ai_module
   AND q1.pulse_quarter = '2026-Q1'
  WHERE q2.pulse_quarter = '2026-Q2'
  ORDER BY delta_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_qoq_adoption_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_qoq_adoption_trend() TO authenticated;

DROP FUNCTION IF EXISTS r2783_mark_decision(uuid, text, text);
CREATE OR REPLACE FUNCTION r2783_mark_decision(p_id uuid, p_decision text, p_owner text)
RETURNS hospital_chain_ai_integration_pulse_r2783
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_row hospital_chain_ai_integration_pulse_r2783;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('scale_all','expand_pilot','hold','retire') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  UPDATE hospital_chain_ai_integration_pulse_r2783
     SET scale_decision = p_decision,
         decision_owner = p_owner,
         recorded_at    = now()
   WHERE id = p_id
  RETURNING * INTO v_row;
  RETURN v_row;
END $$;
REVOKE EXECUTE ON FUNCTION r2783_mark_decision(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2783_mark_decision(uuid, text, text) TO authenticated;

COMMIT;
