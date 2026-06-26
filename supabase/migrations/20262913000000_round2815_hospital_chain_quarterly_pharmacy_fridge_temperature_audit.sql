BEGIN;

-- =====================================================================
-- Round 2815 — Hospital Chain Quarterly Pharmacy Fridge Temperature Audit
-- Chains × pharmacy fridges × temperature deviations × duration × intervention × outcome
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: pharmacy fridge inventory per chain
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pharmacy_fridge_inventory_r2815 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  facility_name text NOT NULL,
  fridge_tag text NOT NULL,
  fridge_model text NOT NULL,
  target_low_celsius numeric(4,2) NOT NULL,
  target_high_celsius numeric(4,2) NOT NULL,
  installed_on date NOT NULL,
  last_calibration_on date NOT NULL,
  criticality text NOT NULL CHECK (criticality IN ('vaccine','insulin','biologic','general')),
  status text NOT NULL CHECK (status IN ('active','watch','quarantined','retired')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pharmacy_fridge_inventory_r2815 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON pharmacy_fridge_inventory_r2815;
CREATE POLICY founder_all ON pharmacy_fridge_inventory_r2815
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO pharmacy_fridge_inventory_r2815
  (chain_name, facility_name, fridge_tag, fridge_model, target_low_celsius, target_high_celsius, installed_on, last_calibration_on, criticality, status)
VALUES
  ('Apollo Group','Apollo Jubilee Hills','APL-JH-FRG-01','Vestfrost MK304',2.00,8.00,'2024-03-12'::date,'2026-04-02'::date,'vaccine','active'),
  ('Apollo Group','Apollo Hyderguda','APL-HG-FRG-02','Haier HBC-260',2.00,8.00,'2023-11-04'::date,'2026-03-18'::date,'insulin','watch'),
  ('Yashoda Hospitals','Yashoda Secunderabad','YSH-SC-FRG-03','Vestfrost MK304',2.00,8.00,'2024-07-21'::date,'2026-05-10'::date,'biologic','active'),
  ('KIMS Hospitals','KIMS Kondapur','KIM-KD-FRG-04','Blue Star CFR-300',2.00,8.00,'2023-08-30'::date,'2026-02-22'::date,'vaccine','quarantined'),
  ('CARE Hospitals','CARE Banjara Hills','CRE-BH-FRG-05','Haier HBC-260',2.00,8.00,'2024-01-09'::date,'2026-04-28'::date,'general','active'),
  ('Continental Hospitals','Continental Gachibowli','CNT-GB-FRG-06','Vestfrost MK500',2.00,8.00,'2023-05-17'::date,'2026-05-05'::date,'biologic','watch');

-- ---------------------------------------------------------------------
-- Table 2: quarterly audit events — deviations, duration, intervention, outcome
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fridge_temp_audit_events_r2815 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fridge_id uuid NOT NULL REFERENCES pharmacy_fridge_inventory_r2815(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  deviation_started_at timestamptz NOT NULL,
  deviation_ended_at timestamptz NOT NULL,
  peak_celsius numeric(4,2) NOT NULL,
  trough_celsius numeric(4,2) NOT NULL,
  duration_minutes integer NOT NULL,
  intervention text NOT NULL CHECK (intervention IN ('door_reseal','compressor_swap','transfer_stock','calibration','no_action')),
  intervention_lag_minutes integer NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('stock_saved','partial_loss','total_loss','no_impact','pending_review')),
  rupees_at_risk integer NOT NULL,
  rupees_lost integer NOT NULL,
  audited_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE fridge_temp_audit_events_r2815 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON fridge_temp_audit_events_r2815;
CREATE POLICY founder_all ON fridge_temp_audit_events_r2815
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO fridge_temp_audit_events_r2815
  (fridge_id, quarter_label, deviation_started_at, deviation_ended_at, peak_celsius, trough_celsius, duration_minutes, intervention, intervention_lag_minutes, outcome, rupees_at_risk, rupees_lost, audited_by)
SELECT id,'Q1-2026','2026-02-14 03:12:00+05:30'::timestamptz,'2026-02-14 04:48:00+05:30'::timestamptz,12.40,2.10,96,'door_reseal',22,'stock_saved',285000,0,'Audit Cell — Sruthi K.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'APL-JH-FRG-01'
UNION ALL
SELECT id,'Q1-2026','2026-03-02 22:40:00+05:30'::timestamptz,'2026-03-03 05:55:00+05:30'::timestamptz,14.10,1.80,435,'compressor_swap',74,'partial_loss',420000,118000,'Audit Cell — Praveen R.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'APL-HG-FRG-02'
UNION ALL
SELECT id,'Q2-2026','2026-04-19 11:05:00+05:30'::timestamptz,'2026-04-19 11:35:00+05:30'::timestamptz,9.30,2.40,30,'transfer_stock',8,'no_impact',95000,0,'Audit Cell — Meera B.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'YSH-SC-FRG-03'
UNION ALL
SELECT id,'Q2-2026','2026-05-08 16:20:00+05:30'::timestamptz,'2026-05-09 02:10:00+05:30'::timestamptz,15.80,1.60,590,'compressor_swap',155,'total_loss',680000,680000,'Audit Cell — Rohit S.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'KIM-KD-FRG-04'
UNION ALL
SELECT id,'Q2-2026','2026-06-01 08:45:00+05:30'::timestamptz,'2026-06-01 09:25:00+05:30'::timestamptz,10.20,2.30,40,'door_reseal',12,'stock_saved',140000,0,'Audit Cell — Sruthi K.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'CRE-BH-FRG-05'
UNION ALL
SELECT id,'Q2-2026','2026-06-12 14:10:00+05:30'::timestamptz,'2026-06-12 15:50:00+05:30'::timestamptz,11.50,2.00,100,'calibration',35,'partial_loss',310000,72000,'Audit Cell — Praveen R.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'CNT-GB-FRG-06'
UNION ALL
SELECT id,'Q2-2026','2026-06-15 19:00:00+05:30'::timestamptz,'2026-06-15 19:45:00+05:30'::timestamptz,8.90,2.50,45,'no_action',18,'pending_review',125000,0,'Audit Cell — Meera B.'
  FROM pharmacy_fridge_inventory_r2815 WHERE fridge_tag = 'APL-JH-FRG-01';

-- =====================================================================
-- RPCs
-- =====================================================================

-- RPC 1: chain rollup
DROP FUNCTION IF EXISTS r2815_chain_rollup();
CREATE OR REPLACE FUNCTION r2815_chain_rollup()
RETURNS TABLE (
  chain_name text,
  fridges integer,
  audited_events integer,
  total_deviation_minutes integer,
  rupees_at_risk bigint,
  rupees_lost bigint,
  loss_ratio_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    i.chain_name,
    COUNT(DISTINCT i.id)::int,
    COUNT(e.id)::int,
    COALESCE(SUM(e.duration_minutes),0)::int,
    COALESCE(SUM(e.rupees_at_risk),0)::bigint,
    COALESCE(SUM(e.rupees_lost),0)::bigint,
    CASE WHEN COALESCE(SUM(e.rupees_at_risk),0) = 0 THEN 0
         ELSE ROUND((SUM(e.rupees_lost)::numeric / SUM(e.rupees_at_risk)::numeric) * 100, 1)
    END
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.chain_name
  ORDER BY rupees_lost DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_chain_rollup() TO authenticated;

-- RPC 2: KPIs
DROP FUNCTION IF EXISTS r2815_kpis();
CREATE OR REPLACE FUNCTION r2815_kpis()
RETURNS TABLE (
  total_fridges integer,
  active_fridges integer,
  quarantined_fridges integer,
  total_events integer,
  total_minutes_out_of_range integer,
  total_rupees_at_risk bigint,
  total_rupees_lost bigint,
  total_loss_ratio_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM pharmacy_fridge_inventory_r2815),
    (SELECT COUNT(*)::int FROM pharmacy_fridge_inventory_r2815 WHERE status = 'active'),
    (SELECT COUNT(*)::int FROM pharmacy_fridge_inventory_r2815 WHERE status = 'quarantined'),
    (SELECT COUNT(*)::int FROM fridge_temp_audit_events_r2815),
    (SELECT COALESCE(SUM(duration_minutes),0)::int FROM fridge_temp_audit_events_r2815),
    (SELECT COALESCE(SUM(rupees_at_risk),0)::bigint FROM fridge_temp_audit_events_r2815),
    (SELECT COALESCE(SUM(rupees_lost),0)::bigint FROM fridge_temp_audit_events_r2815),
    (SELECT CASE WHEN COALESCE(SUM(rupees_at_risk),0) = 0 THEN 0
                 ELSE ROUND((SUM(rupees_lost)::numeric / SUM(rupees_at_risk)::numeric) * 100, 1)
            END FROM fridge_temp_audit_events_r2815);
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_kpis() TO authenticated;

-- RPC 3: deviation event list
DROP FUNCTION IF EXISTS r2815_deviation_events();
CREATE OR REPLACE FUNCTION r2815_deviation_events()
RETURNS TABLE (
  event_id uuid,
  chain_name text,
  facility_name text,
  fridge_tag text,
  quarter_label text,
  deviation_started_at timestamptz,
  duration_minutes integer,
  peak_celsius numeric,
  trough_celsius numeric,
  intervention text,
  intervention_lag_minutes integer,
  outcome text,
  rupees_at_risk integer,
  rupees_lost integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.id, i.chain_name, i.facility_name, i.fridge_tag, e.quarter_label,
         e.deviation_started_at, e.duration_minutes, e.peak_celsius, e.trough_celsius,
         e.intervention, e.intervention_lag_minutes, e.outcome, e.rupees_at_risk, e.rupees_lost
  FROM fridge_temp_audit_events_r2815 e
  JOIN pharmacy_fridge_inventory_r2815 i ON i.id = e.fridge_id
  ORDER BY e.deviation_started_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_deviation_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_deviation_events() TO authenticated;

-- RPC 4: intervention mix
DROP FUNCTION IF EXISTS r2815_intervention_mix();
CREATE OR REPLACE FUNCTION r2815_intervention_mix()
RETURNS TABLE (
  intervention text,
  events integer,
  avg_lag_minutes numeric,
  avg_duration_minutes numeric,
  rupees_lost bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.intervention,
         COUNT(*)::int,
         ROUND(AVG(e.intervention_lag_minutes)::numeric, 1),
         ROUND(AVG(e.duration_minutes)::numeric, 1),
         COALESCE(SUM(e.rupees_lost),0)::bigint
  FROM fridge_temp_audit_events_r2815 e
  GROUP BY e.intervention
  ORDER BY events DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_intervention_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_intervention_mix() TO authenticated;

-- RPC 5: outcome distribution
DROP FUNCTION IF EXISTS r2815_outcome_distribution();
CREATE OR REPLACE FUNCTION r2815_outcome_distribution()
RETURNS TABLE (
  outcome text,
  events integer,
  rupees_at_risk bigint,
  rupees_lost bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.outcome,
         COUNT(*)::int,
         COALESCE(SUM(e.rupees_at_risk),0)::bigint,
         COALESCE(SUM(e.rupees_lost),0)::bigint
  FROM fridge_temp_audit_events_r2815 e
  GROUP BY e.outcome
  ORDER BY rupees_lost DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_outcome_distribution() TO authenticated;

-- RPC 6: criticality risk view
DROP FUNCTION IF EXISTS r2815_criticality_risk();
CREATE OR REPLACE FUNCTION r2815_criticality_risk()
RETURNS TABLE (
  criticality text,
  fridges integer,
  events integer,
  rupees_lost bigint,
  pct_of_total_loss numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(SUM(rupees_lost),0)::bigint INTO v_total FROM fridge_temp_audit_events_r2815;
  RETURN QUERY
  SELECT i.criticality,
         COUNT(DISTINCT i.id)::int,
         COUNT(e.id)::int,
         COALESCE(SUM(e.rupees_lost),0)::bigint,
         CASE WHEN v_total = 0 THEN 0
              ELSE ROUND((COALESCE(SUM(e.rupees_lost),0)::numeric / v_total::numeric) * 100, 1)
         END
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.criticality
  ORDER BY rupees_lost DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_criticality_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_criticality_risk() TO authenticated;

-- RPC 7: long duration watchlist
DROP FUNCTION IF EXISTS r2815_long_duration_watchlist();
CREATE OR REPLACE FUNCTION r2815_long_duration_watchlist()
RETURNS TABLE (
  fridge_tag text,
  chain_name text,
  facility_name text,
  worst_duration_minutes integer,
  worst_peak_celsius numeric,
  rupees_lost bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.fridge_tag, i.chain_name, i.facility_name,
         COALESCE(MAX(e.duration_minutes),0)::int,
         COALESCE(MAX(e.peak_celsius),0)::numeric,
         COALESCE(SUM(e.rupees_lost),0)::bigint,
         i.status
  FROM pharmacy_fridge_inventory_r2815 i
  LEFT JOIN fridge_temp_audit_events_r2815 e ON e.fridge_id = i.id
  GROUP BY i.fridge_tag, i.chain_name, i.facility_name, i.status
  ORDER BY worst_duration_minutes DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_long_duration_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_long_duration_watchlist() TO authenticated;

-- RPC 8: schedule recalibration (VOLATILE)
DROP FUNCTION IF EXISTS r2815_schedule_recalibration(uuid);
CREATE OR REPLACE FUNCTION r2815_schedule_recalibration(p_fridge_id uuid)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE pharmacy_fridge_inventory_r2815
     SET status = 'watch',
         last_calibration_on = CURRENT_DATE
   WHERE id = p_fridge_id
   RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION r2815_schedule_recalibration(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2815_schedule_recalibration(uuid) TO authenticated;

COMMIT;
