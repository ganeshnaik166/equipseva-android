BEGIN;

-- ============================================================================
-- Round 2722 — Engineer Monthly Customer Trust Temperature
-- Spec: engineer × customer × trust score × signal × delta × intervention × outcome
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: engineer_customer_trust_temperature_r2722
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_customer_trust_temperature_r2722 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond')),
  customer_org text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','chain','dental')),
  trust_score numeric(5,2) NOT NULL CHECK (trust_score >= 0 AND trust_score <= 100),
  trust_band text NOT NULL CHECK (trust_band IN ('frozen','cold','cool','warm','hot','blazing')),
  prior_score numeric(5,2) NOT NULL,
  score_delta numeric(6,2) NOT NULL,
  signal_summary text NOT NULL,
  primary_signal text NOT NULL CHECK (primary_signal IN ('on_time','communication','workmanship','escalation','followup','attitude')),
  jobs_completed int NOT NULL CHECK (jobs_completed >= 0),
  nps_score int CHECK (nps_score IS NULL OR (nps_score >= -100 AND nps_score <= 100)),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_trust_temperature_r2722 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_trust_temperature_r2722;
CREATE POLICY founder_all ON engineer_customer_trust_temperature_r2722
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_customer_trust_temperature_r2722
  (month_label, engineer_name, engineer_tier, customer_org, customer_segment, trust_score, trust_band, prior_score, score_delta, signal_summary, primary_signal, jobs_completed, nps_score)
VALUES
  ('2026-06','Ravi Kumar','platinum','Apollo Hyderabad','hospital',92.50,'blazing',88.00,4.50,'On-time 100%, zero callbacks','on_time',14,82),
  ('2026-06','Suresh Babu','gold','Yashoda Clinics','clinic',78.40,'warm',82.10,-3.70,'2 late arrivals, polite comms','on_time',9,55),
  ('2026-06','Priya Reddy','silver','Vijaya Diagnostics','diagnostic',64.20,'cool',71.00,-6.80,'1 escalation on CT calibration','escalation',7,30),
  ('2026-06','Anil Verma','bronze','Care Hospitals','hospital',48.10,'cold',55.30,-7.20,'Weak followup, 3 reopened tickets','followup',6,5),
  ('2026-06','Lakshmi Iyer','diamond','KIMS Chain','chain',96.80,'blazing',94.50,2.30,'Perfect attendance, glowing NPS','workmanship',18,91),
  ('2026-06','Manoj Pillai','gold','Sterling Dental','dental',72.00,'warm',70.50,1.50,'Steady workmanship, slow updates','communication',8,48),
  ('2026-06','Deepika Rao','silver','Continental Diag','diagnostic',39.40,'frozen',52.80,-13.40,'Customer rage incident on June 12','attitude',5,-22);

-- ----------------------------------------------------------------------------
-- Table 2: trust_temperature_interventions_r2722
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trust_temperature_interventions_r2722 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trust_id uuid REFERENCES engineer_customer_trust_temperature_r2722(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('coaching','reassignment','apology_call','training','escalation','recognition','suspension')),
  intervention_status text NOT NULL CHECK (intervention_status IN ('planned','in_progress','completed','cancelled')),
  owner_role text NOT NULL CHECK (owner_role IN ('founder','ops_lead','field_manager','training_lead')),
  outcome_band text NOT NULL CHECK (outcome_band IN ('pending','recovered','improved','flat','worsened')),
  outcome_note text NOT NULL,
  trust_lift numeric(5,2) NOT NULL,
  scheduled_at timestamptz NOT NULL,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE trust_temperature_interventions_r2722 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON trust_temperature_interventions_r2722;
CREATE POLICY founder_all ON trust_temperature_interventions_r2722
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'coaching', 'completed', 'field_manager', 'improved', '1-on-1 SOP refresh, role-play comms', 6.20, '2026-06-18'::date, '2026-06-19'::date
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Suresh Babu' LIMIT 1;

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'apology_call', 'completed', 'founder', 'recovered', 'Founder called CMO, free service credit', 9.80, '2026-06-15'::date, '2026-06-15'::date
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Priya Reddy' LIMIT 1;

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'training', 'in_progress', 'training_lead', 'pending', 'Followup discipline bootcamp 3-day', 0.00, '2026-06-20'::date, NULL
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Anil Verma' LIMIT 1;

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'recognition', 'completed', 'founder', 'improved', 'Featured in monthly newsletter, bonus', 2.10, '2026-06-22'::date, '2026-06-22'::date
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Lakshmi Iyer' LIMIT 1;

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'suspension', 'completed', 'ops_lead', 'flat', 'Suspended pending HR review of rage incident', -3.00, '2026-06-13'::date, '2026-06-14'::date
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Deepika Rao' LIMIT 1;

INSERT INTO trust_temperature_interventions_r2722
  (trust_id, intervention_type, intervention_status, owner_role, outcome_band, outcome_note, trust_lift, scheduled_at, closed_at)
SELECT id, 'reassignment', 'planned', 'ops_lead', 'pending', 'Rotate engineer off this account next cycle', 0.00, '2026-07-01'::date, NULL
  FROM engineer_customer_trust_temperature_r2722 WHERE engineer_name='Manoj Pillai' LIMIT 1;

-- ----------------------------------------------------------------------------
-- RPC 1: KPI summary
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_kpis_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_kpis_r2722()
RETURNS TABLE (
  total_pairs int,
  blazing_pairs int,
  frozen_pairs int,
  avg_score numeric,
  avg_delta numeric,
  net_promoter_avg numeric
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
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE trust_band='blazing')::int,
    COUNT(*) FILTER (WHERE trust_band IN ('frozen','cold'))::int,
    ROUND(AVG(trust_score)::numeric, 2),
    ROUND(AVG(score_delta)::numeric, 2),
    ROUND(AVG(nps_score)::numeric, 1)
  FROM engineer_customer_trust_temperature_r2722;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_kpis_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_kpis_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 2: list pairs with trust scores
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_pairs_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_pairs_r2722()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_tier text,
  customer_org text,
  customer_segment text,
  trust_score numeric,
  trust_band text,
  score_delta numeric,
  primary_signal text,
  jobs_completed int,
  nps_score int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_name, t.engineer_tier, t.customer_org, t.customer_segment,
         t.trust_score, t.trust_band, t.score_delta, t.primary_signal, t.jobs_completed, t.nps_score
  FROM engineer_customer_trust_temperature_r2722 t
  ORDER BY t.trust_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_pairs_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_pairs_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 3: band distribution
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_band_dist_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_band_dist_r2722()
RETURNS TABLE (
  trust_band text,
  pair_count int,
  avg_score numeric,
  avg_delta numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trust_band,
         COUNT(*)::int,
         ROUND(AVG(t.trust_score)::numeric, 2),
         ROUND(AVG(t.score_delta)::numeric, 2)
  FROM engineer_customer_trust_temperature_r2722 t
  GROUP BY t.trust_band
  ORDER BY AVG(t.trust_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_band_dist_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_band_dist_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 4: signal breakdown
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_signals_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_signals_r2722()
RETURNS TABLE (
  primary_signal text,
  pair_count int,
  avg_delta numeric,
  worst_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.primary_signal,
         COUNT(*)::int,
         ROUND(AVG(t.score_delta)::numeric, 2),
         MIN(t.trust_score)
  FROM engineer_customer_trust_temperature_r2722 t
  GROUP BY t.primary_signal
  ORDER BY AVG(t.score_delta) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_signals_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_signals_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 5: interventions list
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_interventions_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_interventions_r2722()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  customer_org text,
  intervention_type text,
  intervention_status text,
  owner_role text,
  outcome_band text,
  outcome_note text,
  trust_lift numeric,
  scheduled_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, t.engineer_name, t.customer_org,
         i.intervention_type, i.intervention_status, i.owner_role,
         i.outcome_band, i.outcome_note, i.trust_lift, i.scheduled_at
  FROM trust_temperature_interventions_r2722 i
  JOIN engineer_customer_trust_temperature_r2722 t ON t.id = i.trust_id
  ORDER BY i.scheduled_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_interventions_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_interventions_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 6: top movers (largest absolute delta)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_top_movers_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_top_movers_r2722()
RETURNS TABLE (
  engineer_name text,
  customer_org text,
  prior_score numeric,
  trust_score numeric,
  score_delta numeric,
  direction text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_name, t.customer_org, t.prior_score, t.trust_score, t.score_delta,
         CASE WHEN t.score_delta > 0 THEN 'up'
              WHEN t.score_delta < 0 THEN 'down'
              ELSE 'flat' END
  FROM engineer_customer_trust_temperature_r2722 t
  ORDER BY ABS(t.score_delta) DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_top_movers_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_top_movers_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 7: segment heatmap
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_segment_heatmap_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_segment_heatmap_r2722()
RETURNS TABLE (
  customer_segment text,
  pair_count int,
  avg_score numeric,
  blazing_count int,
  frozen_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.customer_segment,
         COUNT(*)::int,
         ROUND(AVG(t.trust_score)::numeric, 2),
         COUNT(*) FILTER (WHERE t.trust_band='blazing')::int,
         COUNT(*) FILTER (WHERE t.trust_band IN ('frozen','cold'))::int
  FROM engineer_customer_trust_temperature_r2722 t
  GROUP BY t.customer_segment
  ORDER BY AVG(t.trust_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_segment_heatmap_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_segment_heatmap_r2722() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 8: intervention outcomes rollup
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_trust_temperature_outcomes_r2722();
CREATE OR REPLACE FUNCTION founder_trust_temperature_outcomes_r2722()
RETURNS TABLE (
  intervention_type text,
  total int,
  recovered int,
  improved int,
  flat int,
  worsened int,
  pending int,
  avg_lift numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intervention_type,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.outcome_band='recovered')::int,
         COUNT(*) FILTER (WHERE i.outcome_band='improved')::int,
         COUNT(*) FILTER (WHERE i.outcome_band='flat')::int,
         COUNT(*) FILTER (WHERE i.outcome_band='worsened')::int,
         COUNT(*) FILTER (WHERE i.outcome_band='pending')::int,
         ROUND(AVG(i.trust_lift)::numeric, 2)
  FROM trust_temperature_interventions_r2722 i
  GROUP BY i.intervention_type
  ORDER BY AVG(i.trust_lift) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_trust_temperature_outcomes_r2722() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_trust_temperature_outcomes_r2722() TO authenticated;

COMMIT;
