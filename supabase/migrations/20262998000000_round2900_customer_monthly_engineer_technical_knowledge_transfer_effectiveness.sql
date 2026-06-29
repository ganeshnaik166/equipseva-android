-- Round 2900: Customer Monthly Engineer Technical Knowledge Transfer Effectiveness
-- Tracks how well engineers transfer technical knowledge to hospital biomed staff during monthly visits

-- =========================================================================
-- TABLE 1: monthly knowledge transfer sessions (one per hospital per month)
-- =========================================================================
CREATE TABLE IF NOT EXISTS knowledge_transfer_sessions_r2900 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  session_month date NOT NULL,
  hospital_name text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3','super_specialty')),
  engineer_code text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  topic text NOT NULL,
  duration_minutes int NOT NULL CHECK (duration_minutes >= 0),
  biomed_attendees int NOT NULL CHECK (biomed_attendees >= 0),
  pre_test_score numeric(5,2) NOT NULL CHECK (pre_test_score BETWEEN 0 AND 100),
  post_test_score numeric(5,2) NOT NULL CHECK (post_test_score BETWEEN 0 AND 100),
  effectiveness_score numeric(5,2) NOT NULL CHECK (effectiveness_score BETWEEN 0 AND 100),
  status text NOT NULL CHECK (status IN ('scheduled','delivered','validated','disputed'))
);

ALTER TABLE knowledge_transfer_sessions_r2900 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: retention impact rollup per hospital
-- =========================================================================
CREATE TABLE IF NOT EXISTS knowledge_retention_outcomes_r2900 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_name text NOT NULL,
  hospital_tier text NOT NULL,
  cohort_month date NOT NULL,
  sessions_count int NOT NULL DEFAULT 0,
  avg_effectiveness numeric(5,2) NOT NULL DEFAULT 0,
  self_repair_attempts int NOT NULL DEFAULT 0,
  self_repair_success int NOT NULL DEFAULT 0,
  callbacks_avoided int NOT NULL DEFAULT 0,
  estimated_savings_rupees numeric(12,2) NOT NULL DEFAULT 0,
  amc_renewed boolean NOT NULL DEFAULT false,
  nps_change numeric(5,2) NOT NULL DEFAULT 0,
  retention_signal text NOT NULL CHECK (retention_signal IN ('strong','positive','neutral','at_risk','churn'))
);

ALTER TABLE knowledge_retention_outcomes_r2900 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED DATA
-- =========================================================================
INSERT INTO knowledge_transfer_sessions_r2900 (session_month, hospital_name, hospital_tier, engineer_code, engineer_tier, topic, duration_minutes, biomed_attendees, pre_test_score, post_test_score, effectiveness_score, status) VALUES
('2026-06-01','Apollo Jubilee Hills','super_specialty','ENG-A1','platinum','Ventilator self-calibration',90,6,42.0,88.5,92.5,'validated'),
('2026-06-01','Yashoda Secunderabad','tier_1','ENG-B2','gold','MRI quench drill',75,4,38.5,82.0,86.5,'validated'),
('2026-06-01','KIMS Kondapur','tier_1','ENG-C3','gold','Anaesthesia leak test',60,5,51.0,86.5,84.0,'validated'),
('2026-06-01','Continental Gachibowli','super_specialty','ENG-A1','platinum','Cath lab pressure transducer',120,8,45.0,91.0,94.0,'validated'),
('2026-06-01','Care Banjara','tier_1','ENG-D4','silver','Defibrillator self-test',45,3,48.0,72.5,68.0,'disputed'),
('2026-06-01','AIG Hospitals','super_specialty','ENG-E5','platinum','Endoscope reprocessing',90,7,40.0,89.5,93.0,'validated'),
('2026-06-01','Sunshine Paradise','tier_2','ENG-F6','silver','Patient monitor leads',50,3,55.0,78.0,72.5,'delivered'),
('2026-06-01','Olive Hospital','tier_2','ENG-G7','bronze','Suction pump cleaning',40,2,60.0,75.0,65.0,'disputed'),
('2026-06-01','Rainbow Childrens','tier_1','ENG-B2','gold','Neonatal incubator humidity',60,4,44.0,85.0,82.5,'validated'),
('2026-06-01','Star Hospitals','tier_1','ENG-C3','gold','Dialysis water quality',75,5,47.0,84.0,80.0,'validated'),
('2026-06-01','Medicover','tier_2','ENG-F6','silver','Surgical laser alignment',60,3,52.0,79.5,74.0,'delivered'),
('2026-06-01','Citizens Specialty','tier_2','ENG-D4','silver','Infusion pump occlusion',45,3,49.0,76.0,71.0,'delivered'),
('2026-06-01','Krishna Institute','tier_3','ENG-H8','bronze','Autoclave temperature drift',30,2,58.0,68.0,55.0,'disputed'),
('2026-06-01','Prathima Caduceus','tier_3','ENG-H8','bronze','ECG lead noise',35,2,55.0,70.0,58.0,'delivered'),
('2026-06-01','Asian Institute Gastro','super_specialty','ENG-E5','platinum','Endo-ultrasound probe care',105,6,41.0,90.0,91.5,'validated'),
('2026-06-01','Global Hospital','tier_1','ENG-A1','platinum','Bipap PEEP tuning',70,5,46.0,87.5,88.0,'validated'),
('2026-06-01','Virinchi','tier_2','ENG-G7','bronze','Centrifuge balance',40,3,53.0,72.0,64.0,'delivered'),
('2026-06-01','Renova Soumya','tier_3','ENG-H8','bronze','Pulse oximeter probe',25,2,60.0,69.0,52.0,'disputed'),
('2026-06-01','Maxcure','tier_2','ENG-F6','silver','Surgical drill sterility',55,3,50.0,77.5,73.0,'delivered'),
('2026-06-01','Aware Gleneagles','tier_1','ENG-C3','gold','CT contrast injector',80,5,45.5,84.5,81.5,'validated');

INSERT INTO knowledge_retention_outcomes_r2900 (hospital_name, hospital_tier, cohort_month, sessions_count, avg_effectiveness, self_repair_attempts, self_repair_success, callbacks_avoided, estimated_savings_rupees, amc_renewed, nps_change, retention_signal) VALUES
('Apollo Jubilee Hills','super_specialty','2026-06-01',4,92.5,18,16,12,148000,true,12.5,'strong'),
('Yashoda Secunderabad','tier_1','2026-06-01',3,86.5,14,11,8,92000,true,8.0,'positive'),
('KIMS Kondapur','tier_1','2026-06-01',3,84.0,12,10,7,78000,true,6.5,'positive'),
('Continental Gachibowli','super_specialty','2026-06-01',4,94.0,20,19,14,168000,true,14.0,'strong'),
('Care Banjara','tier_1','2026-06-01',2,68.0,6,3,2,18000,false,-3.5,'at_risk'),
('AIG Hospitals','super_specialty','2026-06-01',4,93.0,19,17,13,156000,true,13.0,'strong'),
('Sunshine Paradise','tier_2','2026-06-01',2,72.5,8,5,4,38000,true,2.5,'neutral'),
('Olive Hospital','tier_2','2026-06-01',2,65.0,5,2,1,12000,false,-5.0,'at_risk'),
('Rainbow Childrens','tier_1','2026-06-01',3,82.5,11,9,6,68000,true,5.5,'positive'),
('Star Hospitals','tier_1','2026-06-01',3,80.0,10,8,6,62000,true,4.0,'positive'),
('Medicover','tier_2','2026-06-01',2,74.0,9,6,4,42000,true,3.0,'neutral'),
('Citizens Specialty','tier_2','2026-06-01',2,71.0,7,5,3,32000,true,1.5,'neutral'),
('Krishna Institute','tier_3','2026-06-01',1,55.0,3,1,0,5000,false,-8.0,'churn'),
('Prathima Caduceus','tier_3','2026-06-01',1,58.0,4,1,1,8000,false,-6.5,'at_risk'),
('Asian Institute Gastro','super_specialty','2026-06-01',4,91.5,17,16,12,142000,true,11.5,'strong'),
('Global Hospital','tier_1','2026-06-01',3,88.0,15,13,9,98000,true,7.5,'positive'),
('Virinchi','tier_2','2026-06-01',2,64.0,6,3,2,22000,false,-4.0,'at_risk'),
('Renova Soumya','tier_3','2026-06-01',1,52.0,2,0,0,3000,false,-9.5,'churn'),
('Maxcure','tier_2','2026-06-01',2,73.0,8,6,4,40000,true,2.0,'neutral'),
('Aware Gleneagles','tier_1','2026-06-01',3,81.5,11,9,6,66000,true,5.0,'positive');

-- =========================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_r2900_program_kpis()
RETURNS TABLE (
  total_sessions bigint,
  validated_sessions bigint,
  disputed_sessions bigint,
  avg_effectiveness numeric,
  avg_score_lift numeric,
  total_savings_rupees numeric,
  hospitals_at_risk bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM knowledge_transfer_sessions_r2900),
    (SELECT count(*) FROM knowledge_transfer_sessions_r2900 WHERE status = 'validated'),
    (SELECT count(*) FROM knowledge_transfer_sessions_r2900 WHERE status = 'disputed'),
    (SELECT round(avg(effectiveness_score)::numeric, 2) FROM knowledge_transfer_sessions_r2900),
    (SELECT round(avg(post_test_score - pre_test_score)::numeric, 2) FROM knowledge_transfer_sessions_r2900),
    (SELECT coalesce(sum(estimated_savings_rupees),0) FROM knowledge_retention_outcomes_r2900),
    (SELECT count(*) FROM knowledge_retention_outcomes_r2900 WHERE retention_signal IN ('at_risk','churn'));
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_top_engineers()
RETURNS TABLE (
  engineer_code text,
  engineer_tier text,
  sessions bigint,
  avg_effectiveness numeric,
  avg_lift numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_tier, count(*),
         round(avg(s.effectiveness_score)::numeric, 2),
         round(avg(s.post_test_score - s.pre_test_score)::numeric, 2)
  FROM knowledge_transfer_sessions_r2900 s
  GROUP BY s.engineer_code, s.engineer_tier
  ORDER BY avg(s.effectiveness_score) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_hospital_outcomes()
RETURNS TABLE (
  hospital_name text,
  hospital_tier text,
  avg_effectiveness numeric,
  callbacks_avoided int,
  savings_rupees numeric,
  amc_renewed boolean,
  retention_signal text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT o.hospital_name, o.hospital_tier, o.avg_effectiveness,
         o.callbacks_avoided, o.estimated_savings_rupees,
         o.amc_renewed, o.retention_signal
  FROM knowledge_retention_outcomes_r2900 o
  ORDER BY o.estimated_savings_rupees DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_tier_breakdown()
RETURNS TABLE (
  hospital_tier text,
  hospitals bigint,
  avg_effectiveness numeric,
  total_savings numeric,
  renewal_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT o.hospital_tier,
         count(*),
         round(avg(o.avg_effectiveness)::numeric, 2),
         sum(o.estimated_savings_rupees),
         round((sum(CASE WHEN o.amc_renewed THEN 1 ELSE 0 END)::numeric * 100 / count(*))::numeric, 2)
  FROM knowledge_retention_outcomes_r2900 o
  GROUP BY o.hospital_tier
  ORDER BY sum(o.estimated_savings_rupees) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_disputed_sessions()
RETURNS TABLE (
  hospital_name text,
  engineer_code text,
  topic text,
  effectiveness_score numeric,
  post_test_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.hospital_name, s.engineer_code, s.topic,
         s.effectiveness_score, s.post_test_score
  FROM knowledge_transfer_sessions_r2900 s
  WHERE s.status = 'disputed'
  ORDER BY s.effectiveness_score ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_at_risk_accounts()
RETURNS TABLE (
  hospital_name text,
  hospital_tier text,
  avg_effectiveness numeric,
  nps_change numeric,
  retention_signal text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT o.hospital_name, o.hospital_tier, o.avg_effectiveness,
         o.nps_change, o.retention_signal
  FROM knowledge_retention_outcomes_r2900 o
  WHERE o.retention_signal IN ('at_risk','churn')
  ORDER BY o.nps_change ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2900_topic_efficacy()
RETURNS TABLE (
  topic text,
  sessions bigint,
  avg_effectiveness numeric,
  avg_lift numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT s.topic, count(*),
         round(avg(s.effectiveness_score)::numeric, 2),
         round(avg(s.post_test_score - s.pre_test_score)::numeric, 2)
  FROM knowledge_transfer_sessions_r2900 s
  GROUP BY s.topic
  ORDER BY avg(s.effectiveness_score) DESC;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION founder_r2900_program_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_top_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_hospital_outcomes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_tier_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_disputed_sessions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_at_risk_accounts() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2900_topic_efficacy() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2900_program_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_top_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_hospital_outcomes() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_tier_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_disputed_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_at_risk_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2900_topic_efficacy() TO authenticated;
