BEGIN;

-- Round 2843: Hospital Chain Quarterly Equipment Fleet Uptime by Modality
-- Tables: chain_modality_uptime_r2843, chain_modality_interventions_r2843

CREATE TABLE IF NOT EXISTS chain_modality_uptime_r2843 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_count integer NOT NULL,
  modality text NOT NULL CHECK (modality IN ('mri','ct','xray','ultrasound','cathlab','ventilator','dialysis','endoscopy')),
  asset_cohort text NOT NULL CHECK (asset_cohort IN ('new','mid_life','aging','end_of_life')),
  quarter text NOT NULL CHECK (quarter IN ('q1_2026','q2_2026','q3_2026','q4_2026')),
  fleet_size integer NOT NULL,
  uptime_pct numeric(5,2) NOT NULL,
  sla_target_pct numeric(5,2) NOT NULL,
  sla_breach_count integer NOT NULL DEFAULT 0,
  mttr_hours numeric(6,2) NOT NULL,
  mtbf_hours numeric(8,2) NOT NULL,
  revenue_lost_rupees bigint NOT NULL DEFAULT 0,
  risk_level text NOT NULL CHECK (risk_level IN ('green','yellow','orange','red')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_modality_uptime_r2843 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_modality_uptime_r2843;
CREATE POLICY founder_all ON chain_modality_uptime_r2843 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_modality_uptime_r2843 (chain_name, hospital_count, modality, asset_cohort, quarter, fleet_size, uptime_pct, sla_target_pct, sla_breach_count, mttr_hours, mtbf_hours, revenue_lost_rupees, risk_level) VALUES
('Apollo Group', 71, 'mri', 'mid_life', 'q2_2026', 48, 97.40, 98.00, 3, 6.20, 1450.00, 1850000, 'yellow'),
('Apollo Group', 71, 'ct', 'new', 'q2_2026', 62, 98.90, 98.00, 1, 4.10, 2100.00, 420000, 'green'),
('Manipal Hospitals', 30, 'cathlab', 'aging', 'q2_2026', 22, 94.10, 97.00, 7, 11.40, 720.00, 6200000, 'orange'),
('Fortis Healthcare', 36, 'ventilator', 'mid_life', 'q2_2026', 540, 99.20, 99.00, 4, 2.80, 4200.00, 380000, 'green'),
('Max Healthcare', 17, 'mri', 'end_of_life', 'q2_2026', 14, 88.40, 98.00, 14, 18.60, 380.00, 9800000, 'red'),
('Narayana Health', 23, 'dialysis', 'aging', 'q2_2026', 168, 95.20, 97.00, 8, 8.40, 920.00, 2100000, 'yellow'),
('Aster DM Healthcare', 14, 'endoscopy', 'mid_life', 'q2_2026', 38, 96.80, 97.00, 2, 5.10, 1820.00, 540000, 'green');

CREATE TABLE IF NOT EXISTS chain_modality_interventions_r2843 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  modality text NOT NULL,
  quarter text NOT NULL,
  intervention_type text NOT NULL CHECK (intervention_type IN ('preventive_maint','emergency_repair','replacement','training','vendor_switch','sla_renegotiation')),
  initiated_at date NOT NULL,
  cost_rupees bigint NOT NULL,
  uptime_delta_pct numeric(5,2) NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('successful','partial','failed','pending')),
  followup_required boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_modality_interventions_r2843 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_modality_interventions_r2843;
CREATE POLICY founder_all ON chain_modality_interventions_r2843 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_modality_interventions_r2843 (chain_name, modality, quarter, intervention_type, initiated_at, cost_rupees, uptime_delta_pct, outcome, followup_required, notes) VALUES
('Apollo Group', 'mri', 'q2_2026', 'preventive_maint', '2026-04-12'::date, 480000, 1.80, 'successful', false, 'Coil replacement on 4 MRIs cleared backlog'),
('Manipal Hospitals', 'cathlab', 'q2_2026', 'replacement', '2026-05-03'::date, 28000000, 4.20, 'partial', true, 'Bangalore HSR replaced; Mysore still aging'),
('Fortis Healthcare', 'ventilator', 'q2_2026', 'training', '2026-04-22'::date, 180000, 0.40, 'successful', false, 'Biomedical refresh across 7 ICUs'),
('Max Healthcare', 'mri', 'q2_2026', 'vendor_switch', '2026-05-18'::date, 1200000, 0.00, 'pending', true, 'Moved from incumbent OEM to multi-vendor pool'),
('Narayana Health', 'dialysis', 'q2_2026', 'sla_renegotiation', '2026-04-30'::date, 0, 2.10, 'successful', false, 'Tighter MTTR clause with primary AMC partner'),
('Aster DM Healthcare', 'endoscopy', 'q2_2026', 'emergency_repair', '2026-05-09'::date, 320000, 1.20, 'successful', false, 'CCD module replacement on 2 scopes');

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS f_r2843_kpi_summary();
CREATE FUNCTION f_r2843_kpi_summary()
RETURNS TABLE(total_chains integer, total_fleet integer, avg_uptime numeric, total_breaches integer, total_revenue_lost bigint, red_cohorts integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT (SELECT count(DISTINCT chain_name)::integer FROM chain_modality_uptime_r2843),
           COALESCE(SUM(fleet_size),0)::integer,
           ROUND(AVG(uptime_pct)::numeric, 2),
           COALESCE(SUM(sla_breach_count),0)::integer,
           COALESCE(SUM(revenue_lost_rupees),0)::bigint,
           SUM(CASE WHEN risk_level = 'red' THEN 1 ELSE 0 END)::integer
    FROM chain_modality_uptime_r2843;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_kpi_summary() TO authenticated;

-- RPC 2: Uptime rows
DROP FUNCTION IF EXISTS f_r2843_uptime_rows();
CREATE FUNCTION f_r2843_uptime_rows()
RETURNS SETOF chain_modality_uptime_r2843
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM chain_modality_uptime_r2843 ORDER BY uptime_pct ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_uptime_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_uptime_rows() TO authenticated;

-- RPC 3: By modality
DROP FUNCTION IF EXISTS f_r2843_by_modality();
CREATE FUNCTION f_r2843_by_modality()
RETURNS TABLE(modality text, fleet_size bigint, avg_uptime numeric, total_breaches bigint, revenue_lost_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.modality,
           SUM(u.fleet_size)::bigint,
           ROUND(AVG(u.uptime_pct)::numeric, 2),
           SUM(u.sla_breach_count)::bigint,
           SUM(u.revenue_lost_rupees)::bigint
    FROM chain_modality_uptime_r2843 u
    GROUP BY u.modality
    ORDER BY 5 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_by_modality() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_by_modality() TO authenticated;

-- RPC 4: By chain
DROP FUNCTION IF EXISTS f_r2843_by_chain();
CREATE FUNCTION f_r2843_by_chain()
RETURNS TABLE(chain_name text, hospital_count integer, avg_uptime numeric, total_breaches bigint, red_cohorts bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.chain_name,
           MAX(u.hospital_count)::integer,
           ROUND(AVG(u.uptime_pct)::numeric, 2),
           SUM(u.sla_breach_count)::bigint,
           SUM(CASE WHEN u.risk_level = 'red' THEN 1 ELSE 0 END)::bigint
    FROM chain_modality_uptime_r2843 u
    GROUP BY u.chain_name
    ORDER BY 3 ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_by_chain() TO authenticated;

-- RPC 5: Cohort risk
DROP FUNCTION IF EXISTS f_r2843_cohort_risk();
CREATE FUNCTION f_r2843_cohort_risk()
RETURNS TABLE(asset_cohort text, fleet_size bigint, avg_uptime numeric, avg_mttr numeric, red_cohorts bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.asset_cohort,
           SUM(u.fleet_size)::bigint,
           ROUND(AVG(u.uptime_pct)::numeric, 2),
           ROUND(AVG(u.mttr_hours)::numeric, 2),
           SUM(CASE WHEN u.risk_level = 'red' THEN 1 ELSE 0 END)::bigint
    FROM chain_modality_uptime_r2843 u
    GROUP BY u.asset_cohort
    ORDER BY 3 ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_cohort_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_cohort_risk() TO authenticated;

-- RPC 6: Interventions
DROP FUNCTION IF EXISTS f_r2843_interventions();
CREATE FUNCTION f_r2843_interventions()
RETURNS SETOF chain_modality_interventions_r2843
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM chain_modality_interventions_r2843 ORDER BY initiated_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_interventions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_interventions() TO authenticated;

-- RPC 7: Intervention ROI
DROP FUNCTION IF EXISTS f_r2843_intervention_roi();
CREATE FUNCTION f_r2843_intervention_roi()
RETURNS TABLE(intervention_type text, total_cost bigint, avg_uptime_delta numeric, successful_count bigint, pending_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.intervention_type,
           SUM(i.cost_rupees)::bigint,
           ROUND(AVG(i.uptime_delta_pct)::numeric, 2),
           SUM(CASE WHEN i.outcome = 'successful' THEN 1 ELSE 0 END)::bigint,
           SUM(CASE WHEN i.outcome = 'pending' THEN 1 ELSE 0 END)::bigint
    FROM chain_modality_interventions_r2843 i
    GROUP BY i.intervention_type
    ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_intervention_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_intervention_roi() TO authenticated;

-- RPC 8: Outcome mix
DROP FUNCTION IF EXISTS f_r2843_outcome_mix();
CREATE FUNCTION f_r2843_outcome_mix()
RETURNS TABLE(outcome text, count bigint, total_cost bigint, avg_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.outcome,
           COUNT(*)::bigint,
           SUM(i.cost_rupees)::bigint,
           ROUND(AVG(i.uptime_delta_pct)::numeric, 2)
    FROM chain_modality_interventions_r2843 i
    GROUP BY i.outcome
    ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION f_r2843_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2843_outcome_mix() TO authenticated;

COMMIT;
