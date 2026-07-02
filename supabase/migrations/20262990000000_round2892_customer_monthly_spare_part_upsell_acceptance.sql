-- Round 2892 — Customer Monthly Engineer-Recommended Spare-Part Upsell Acceptance
-- Founder ops: track monthly engineer upsell recommendations to hospitals and acceptance funnel

BEGIN;

-- =========================================================
-- Table 1: monthly upsell recommendations by engineers
-- =========================================================
CREATE TABLE IF NOT EXISTS customer_monthly_spare_upsell_recos_r2892 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  hospital_name text NOT NULL,
  hospital_city text NOT NULL,
  engineer_code text NOT NULL,
  engineer_tier text NOT NULL,
  spare_part_name text NOT NULL,
  recommended_qty int NOT NULL,
  unit_price_rupees int NOT NULL,
  bundle_total_rupees int NOT NULL,
  reco_basis text NOT NULL,
  urgency text NOT NULL,
  accepted boolean NOT NULL,
  decision_hours numeric(8,2),
  rejection_reason text
);

ALTER TABLE customer_monthly_spare_upsell_recos_r2892 ENABLE ROW LEVEL SECURITY;

INSERT INTO customer_monthly_spare_upsell_recos_r2892
(month_label, hospital_name, hospital_city, engineer_code, engineer_tier, spare_part_name, recommended_qty, unit_price_rupees, bundle_total_rupees, reco_basis, urgency, accepted, decision_hours, rejection_reason) VALUES
('2026-06','Apollo Jubilee','Hyderabad','ENG-014','platinum','Defib battery pack',2,18500,37000,'cycle-count nearing EOL','high',true,4.50,NULL),
('2026-06','Yashoda Secunderabad','Hyderabad','ENG-022','gold','ECG lead set',6,1200,7200,'visible cable wear','medium',true,12.20,NULL),
('2026-06','KIMS Kondapur','Hyderabad','ENG-007','platinum','Infusion pump tubing kit',24,450,10800,'monthly consumable','low',true,2.10,NULL),
('2026-06','Rainbow Banjara','Hyderabad','ENG-031','silver','Pulse oximeter probe',8,2200,17600,'failed self-test','high',false,28.40,'budget cycle wait'),
('2026-06','Care Banjara Hills','Hyderabad','ENG-014','platinum','Suction unit filter',12,320,3840,'preventive','low',true,1.80,NULL),
('2026-06','Continental Gachibowli','Hyderabad','ENG-018','gold','Anesthesia vaporizer seal',4,4200,16800,'leak detected','high',true,6.70,NULL),
('2026-06','Sunshine Paradise','Hyderabad','ENG-022','gold','BP cuff adult',10,650,6500,'velcro fatigue','medium',false,48.10,'will source locally'),
('2026-06','Aware Gachibowli','Hyderabad','ENG-031','silver','Nebulizer mask pediatric',30,180,5400,'stockout warning','medium',true,8.30,NULL),
('2026-06','Krishna Institute','Secunderabad','ENG-007','platinum','Patient monitor module',1,42000,42000,'CO2 module fault','high',true,18.50,NULL),
('2026-06','Star Hospitals','Hyderabad','ENG-014','platinum','Surgical light bulb',6,1800,10800,'dimming observed','medium',true,9.20,NULL),
('2026-06','MaxCure','Madhapur','ENG-018','gold','Ventilator flow sensor',3,8500,25500,'calibration drift','high',false,72.00,'awaiting tender'),
('2026-06','Asian Institute','Banjara','ENG-022','gold','Centrifuge rotor lid',1,6800,6800,'crack visible','high',true,3.40,NULL),
('2026-06','Olive Hospital','Mehdipatnam','ENG-031','silver','Autoclave gasket',2,1100,2200,'steam leak','medium',true,5.60,NULL),
('2026-06','Renova Soft','Hyderabad','ENG-007','platinum','X-ray collimator lamp',2,3400,6800,'EOL alert','low',true,11.10,NULL),
('2026-06','Citizens Specialty','Nallagandla','ENG-014','platinum','Dialysis tubing pack',40,280,11200,'monthly volume','low',true,1.20,NULL),
('2026-06','Pranaam Hospitals','Hyderabad','ENG-018','gold','Suction canister',8,950,7600,'preventive','low',false,36.00,'preferred vendor'),
('2026-06','Image Hospitals','Ameerpet','ENG-022','gold','Surgical drill bits',12,1500,18000,'wear inspection','medium',true,14.50,NULL),
('2026-06','Virinchi Hospitals','Banjara','ENG-031','silver','Pulse rate sensor pad',20,420,8400,'consumable','low',true,7.80,NULL),
('2026-06','Citizens HiTech','Madhapur','ENG-007','platinum','MRI coil cable',1,28000,28000,'micro-fracture imaged','high',true,22.30,NULL),
('2026-06','Sai Sanjeevani','Secunderabad','ENG-014','platinum','Phototherapy LED bank',2,9200,18400,'lumens fading','medium',false,60.00,'finance review');

-- =========================================================
-- Table 2: hospital-level monthly acceptance scorecard
-- =========================================================
CREATE TABLE IF NOT EXISTS customer_monthly_upsell_scorecard_r2892 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  hospital_name text NOT NULL,
  amc_tier text NOT NULL,
  recos_offered int NOT NULL,
  recos_accepted int NOT NULL,
  acceptance_pct numeric(5,2) NOT NULL,
  monthly_upsell_gmv_rupees int NOT NULL,
  trailing3_acceptance_pct numeric(5,2) NOT NULL,
  uptime_pct numeric(5,2) NOT NULL,
  retention_risk text NOT NULL,
  nps_score int NOT NULL
);

ALTER TABLE customer_monthly_upsell_scorecard_r2892 ENABLE ROW LEVEL SECURITY;

INSERT INTO customer_monthly_upsell_scorecard_r2892
(month_label, hospital_name, amc_tier, recos_offered, recos_accepted, acceptance_pct, monthly_upsell_gmv_rupees, trailing3_acceptance_pct, uptime_pct, retention_risk, nps_score) VALUES
('2026-06','Apollo Jubilee','platinum',12,11,91.67,182000,88.40,99.20,'low',72),
('2026-06','Yashoda Secunderabad','platinum',9,8,88.89,142500,84.10,98.40,'low',68),
('2026-06','KIMS Kondapur','platinum',14,13,92.86,165000,90.20,99.50,'low',75),
('2026-06','Rainbow Banjara','gold',7,4,57.14,52000,54.80,96.10,'medium',54),
('2026-06','Care Banjara Hills','platinum',10,9,90.00,138000,87.50,99.10,'low',70),
('2026-06','Continental Gachibowli','gold',8,6,75.00,98000,72.30,97.40,'medium',61),
('2026-06','Sunshine Paradise','gold',6,3,50.00,41000,47.20,95.60,'high',42),
('2026-06','Aware Gachibowli','silver',5,4,80.00,38000,76.40,96.80,'medium',58),
('2026-06','Krishna Institute','platinum',11,10,90.91,201000,89.10,99.30,'low',74),
('2026-06','Star Hospitals','platinum',9,8,88.89,128000,86.50,98.90,'low',69),
('2026-06','MaxCure','gold',7,4,57.14,72000,55.10,96.20,'high',48),
('2026-06','Asian Institute','gold',8,7,87.50,84000,83.40,98.10,'low',65),
('2026-06','Olive Hospital','silver',4,3,75.00,28000,71.20,96.50,'medium',56),
('2026-06','Renova Soft','platinum',10,9,90.00,118000,88.20,99.00,'low',71),
('2026-06','Citizens Specialty','platinum',13,12,92.31,156000,91.40,99.40,'low',73),
('2026-06','Pranaam Hospitals','gold',6,4,66.67,58000,62.30,96.70,'medium',55),
('2026-06','Image Hospitals','gold',8,7,87.50,96000,84.60,98.20,'low',66),
('2026-06','Virinchi Hospitals','silver',5,4,80.00,42000,77.10,96.90,'medium',59),
('2026-06','Citizens HiTech','platinum',9,8,88.89,148000,87.40,99.10,'low',70),
('2026-06','Sai Sanjeevani','platinum',7,5,71.43,84000,68.90,97.80,'medium',57);

-- =========================================================
-- RPCs (founder gated)
-- =========================================================

CREATE OR REPLACE FUNCTION founder_r2892_kpis()
RETURNS TABLE(total_recos bigint, total_accepted bigint, acceptance_pct numeric, upsell_gmv_rupees bigint, avg_decision_hours numeric, hospitals_at_risk bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM customer_monthly_spare_upsell_recos_r2892),
    (SELECT count(*) FROM customer_monthly_spare_upsell_recos_r2892 WHERE accepted),
    ROUND(100.0 * (SELECT count(*) FROM customer_monthly_spare_upsell_recos_r2892 WHERE accepted)
      / NULLIF((SELECT count(*) FROM customer_monthly_spare_upsell_recos_r2892),0), 2),
    (SELECT COALESCE(SUM(bundle_total_rupees),0)::bigint FROM customer_monthly_spare_upsell_recos_r2892 WHERE accepted),
    (SELECT ROUND(AVG(decision_hours)::numeric, 2) FROM customer_monthly_spare_upsell_recos_r2892 WHERE decision_hours IS NOT NULL),
    (SELECT count(*) FROM customer_monthly_upsell_scorecard_r2892 WHERE retention_risk IN ('medium','high'));
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_top_hospitals()
RETURNS TABLE(id uuid, hospital_name text, amc_tier text, acceptance_pct numeric, monthly_upsell_gmv_rupees int, uptime_pct numeric, nps_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_name, s.amc_tier, s.acceptance_pct, s.monthly_upsell_gmv_rupees, s.uptime_pct, s.nps_score
  FROM customer_monthly_upsell_scorecard_r2892 s
  ORDER BY s.monthly_upsell_gmv_rupees DESC
  LIMIT 12;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_at_risk_hospitals()
RETURNS TABLE(id uuid, hospital_name text, amc_tier text, acceptance_pct numeric, trailing3_acceptance_pct numeric, retention_risk text, nps_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_name, s.amc_tier, s.acceptance_pct, s.trailing3_acceptance_pct, s.retention_risk, s.nps_score
  FROM customer_monthly_upsell_scorecard_r2892 s
  WHERE s.retention_risk IN ('medium','high')
  ORDER BY s.acceptance_pct ASC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_engineer_leaderboard()
RETURNS TABLE(engineer_code text, engineer_tier text, recos bigint, accepted bigint, acceptance_pct numeric, gmv_won_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_tier,
    count(*),
    count(*) FILTER (WHERE r.accepted),
    ROUND(100.0 * count(*) FILTER (WHERE r.accepted) / NULLIF(count(*),0), 2),
    COALESCE(SUM(r.bundle_total_rupees) FILTER (WHERE r.accepted), 0)::bigint
  FROM customer_monthly_spare_upsell_recos_r2892 r
  GROUP BY r.engineer_code, r.engineer_tier
  ORDER BY 6 DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_rejection_reasons()
RETURNS TABLE(rejection_reason text, rejections bigint, lost_gmv_rupees bigint, avg_decision_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.rejection_reason,
    count(*),
    COALESCE(SUM(r.bundle_total_rupees),0)::bigint,
    ROUND(AVG(r.decision_hours)::numeric, 2)
  FROM customer_monthly_spare_upsell_recos_r2892 r
  WHERE r.accepted = false AND r.rejection_reason IS NOT NULL
  GROUP BY r.rejection_reason
  ORDER BY 3 DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_urgency_mix()
RETURNS TABLE(urgency text, recos bigint, accepted bigint, acceptance_pct numeric, gmv_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.urgency,
    count(*),
    count(*) FILTER (WHERE r.accepted),
    ROUND(100.0 * count(*) FILTER (WHERE r.accepted) / NULLIF(count(*),0), 2),
    COALESCE(SUM(r.bundle_total_rupees) FILTER (WHERE r.accepted),0)::bigint
  FROM customer_monthly_spare_upsell_recos_r2892 r
  GROUP BY r.urgency
  ORDER BY 5 DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_high_ticket_recos()
RETURNS TABLE(id uuid, hospital_name text, spare_part_name text, bundle_total_rupees int, urgency text, accepted boolean, decision_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_name, r.spare_part_name, r.bundle_total_rupees, r.urgency, r.accepted, r.decision_hours
  FROM customer_monthly_spare_upsell_recos_r2892 r
  WHERE r.bundle_total_rupees >= 15000
  ORDER BY r.bundle_total_rupees DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2892_tier_acceptance()
RETURNS TABLE(amc_tier text, hospitals bigint, avg_acceptance_pct numeric, total_gmv_rupees bigint, avg_nps numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.amc_tier,
    count(*),
    ROUND(AVG(s.acceptance_pct)::numeric, 2),
    COALESCE(SUM(s.monthly_upsell_gmv_rupees),0)::bigint,
    ROUND(AVG(s.nps_score)::numeric, 2)
  FROM customer_monthly_upsell_scorecard_r2892 s
  GROUP BY s.amc_tier
  ORDER BY 4 DESC;
END;$$;

-- =========================================================
-- Grants
-- =========================================================
REVOKE EXECUTE ON FUNCTION founder_r2892_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_top_hospitals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_at_risk_hospitals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_engineer_leaderboard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_rejection_reasons() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_urgency_mix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_high_ticket_recos() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2892_tier_acceptance() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2892_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_top_hospitals() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_at_risk_hospitals() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_engineer_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_rejection_reasons() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_urgency_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_high_ticket_recos() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2892_tier_acceptance() TO authenticated;

COMMIT;
