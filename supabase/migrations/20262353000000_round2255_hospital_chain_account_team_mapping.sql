BEGIN;

-- ============================================================================
-- r2255: Hospital chain account-team mapping
-- Each hospital chain -> account lead + CSM + engineer team + escalation path
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_chain_account_teams_r2255 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_code text NOT NULL UNIQUE,
  hospital_count int NOT NULL DEFAULT 1 CHECK (hospital_count >= 1),
  tier text NOT NULL CHECK (tier IN ('platinum','gold','silver','bronze')),
  account_lead_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  account_lead_name text NOT NULL,
  csm_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  csm_name text NOT NULL,
  primary_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  primary_engineer_name text NOT NULL,
  backup_engineer_name text,
  escalation_path text NOT NULL,
  contract_value_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (contract_value_rupees >= 0),
  active_amc_count int NOT NULL DEFAULT 0 CHECK (active_amc_count >= 0),
  health_score int NOT NULL DEFAULT 75 CHECK (health_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','at_risk','churned','onboarding')),
  last_qbr_date date,
  next_qbr_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hc_team_r2255_tier ON public.hospital_chain_account_teams_r2255(tier);
CREATE INDEX IF NOT EXISTS idx_hc_team_r2255_status ON public.hospital_chain_account_teams_r2255(status);
CREATE INDEX IF NOT EXISTS idx_hc_team_r2255_health ON public.hospital_chain_account_teams_r2255(health_score);

CREATE TABLE IF NOT EXISTS public.hospital_chain_escalations_r2255 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES public.hospital_chain_account_teams_r2255(id) ON DELETE CASCADE,
  escalation_level int NOT NULL CHECK (escalation_level BETWEEN 1 AND 5),
  contact_name text NOT NULL,
  contact_role text NOT NULL,
  contact_email text NOT NULL,
  response_sla_minutes int NOT NULL CHECK (response_sla_minutes > 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hc_esc_r2255_chain ON public.hospital_chain_escalations_r2255(chain_id);
CREATE INDEX IF NOT EXISTS idx_hc_esc_r2255_level ON public.hospital_chain_escalations_r2255(escalation_level);

ALTER TABLE public.hospital_chain_account_teams_r2255 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_escalations_r2255 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hc_team_r2255 ON public.hospital_chain_account_teams_r2255;
CREATE POLICY founder_all_hc_team_r2255 ON public.hospital_chain_account_teams_r2255
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hc_esc_r2255 ON public.hospital_chain_escalations_r2255;
CREATE POLICY founder_all_hc_esc_r2255 ON public.hospital_chain_escalations_r2255
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.hospital_chain_account_teams_r2255 (chain_name, chain_code, hospital_count, tier, account_lead_name, csm_name, primary_engineer_name, backup_engineer_name, escalation_path, contract_value_rupees, active_amc_count, health_score, status, last_qbr_date, next_qbr_date, notes) VALUES
('Apollo Hospitals South','APOLLO-S',14,'platinum','Vikram Reddy','Priya Iyer','Rajesh Kumar','Suresh Babu','L1 CSM -> L2 Account Lead -> L3 VP Ops -> L4 Founder',8400000.00,42,92,'active','2026-04-15','2026-07-15','Largest chain. QBR went well last quarter.'),
('Manipal Hospitals','MANIPAL',9,'platinum','Vikram Reddy','Anita Sharma','Mohammed Faisal','Rajesh Kumar','L1 CSM -> L2 Account Lead -> L3 VP Ops -> L4 Founder',5600000.00,28,88,'active','2026-05-01','2026-08-01','Expanding to Bangalore east cluster.'),
('Fortis Healthcare TN','FORTIS-TN',6,'gold','Sundar Krishnan','Anita Sharma','Karthik Subramanian',NULL,'L1 CSM -> L2 Account Lead -> L3 VP Ops',3200000.00,18,71,'at_risk','2026-03-20','2026-06-25','Health score dropped after 2 SLA misses. Need recovery plan.'),
('KIMS Hospitals','KIMS',7,'gold','Sundar Krishnan','Priya Iyer','Mohammed Faisal','Karthik Subramanian','L1 CSM -> L2 Account Lead -> L3 VP Ops',3800000.00,22,84,'active','2026-04-28','2026-07-28','Stable. Renewal due Sep 2026.'),
('Yashoda Hospitals','YASHODA',4,'gold','Sundar Krishnan','Anita Sharma','Rajesh Kumar',NULL,'L1 CSM -> L2 Account Lead -> L3 VP Ops',2100000.00,14,79,'active','2026-05-10','2026-08-10','Hyderabad concentration. Strong relationship.'),
('Continental Hospitals','CONTI',2,'silver','Meera Pillai','Anita Sharma','Suresh Babu',NULL,'L1 CSM -> L2 Account Lead',900000.00,6,68,'at_risk','2026-02-15','2026-06-30','Late on payments. Health declining.'),
('Care Hospitals AP','CARE-AP',5,'silver','Meera Pillai','Priya Iyer','Karthik Subramanian','Mohammed Faisal','L1 CSM -> L2 Account Lead',1600000.00,11,77,'active','2026-04-05','2026-07-05','Vizag + Vijayawada cluster.'),
('Rainbow Childrens','RAINBOW',3,'silver','Meera Pillai','Anita Sharma','Rajesh Kumar',NULL,'L1 CSM -> L2 Account Lead',1200000.00,8,82,'active','2026-05-18','2026-08-18','Pediatric specialty. Loyal customer.'),
('Sunshine Hospitals','SUN',2,'bronze','Meera Pillai','Priya Iyer','Suresh Babu',NULL,'L1 CSM -> L2 Account Lead',420000.00,4,65,'onboarding','2026-06-01','2026-09-01','Just onboarded. Needs hand-holding.'),
('AIG Hospitals','AIG',1,'bronze','Meera Pillai','Anita Sharma','Mohammed Faisal',NULL,'L1 CSM -> L2 Account Lead',280000.00,3,58,'churned','2026-01-20',NULL,'Churned in May 2026. Won-back attempt pending.')
ON CONFLICT (chain_code) DO NOTHING;

INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 1, 'Priya Iyer', 'CSM', 'priya@equipseva.in', 30, 'First responder' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'APOLLO-S'
ON CONFLICT DO NOTHING;
INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 2, 'Vikram Reddy', 'Account Lead', 'vikram@equipseva.in', 60, 'Account-level escalation' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'APOLLO-S'
ON CONFLICT DO NOTHING;
INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 3, 'VP Operations', 'VP Ops', 'vp-ops@equipseva.in', 120, 'Ops-level escalation' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'APOLLO-S'
ON CONFLICT DO NOTHING;
INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 4, 'Ganesh Dhanavath', 'Founder', 'founder@equipseva.in', 240, 'Founder-level escalation' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'APOLLO-S'
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 1, 'Anita Sharma', 'CSM', 'anita@equipseva.in', 30, 'First responder' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'FORTIS-TN'
ON CONFLICT DO NOTHING;
INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 2, 'Sundar Krishnan', 'Account Lead', 'sundar@equipseva.in', 45, 'At-risk account; tighter SLA' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'FORTIS-TN'
ON CONFLICT DO NOTHING;
INSERT INTO public.hospital_chain_escalations_r2255 (chain_id, escalation_level, contact_name, contact_role, contact_email, response_sla_minutes, notes)
SELECT id, 3, 'VP Operations', 'VP Ops', 'vp-ops@equipseva.in', 90, 'Recovery oversight' FROM public.hospital_chain_account_teams_r2255 WHERE chain_code = 'FORTIS-TN'
ON CONFLICT DO NOTHING;

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r2255_chain_team_overview()
RETURNS TABLE (chain_name text, chain_code text, tier text, hospital_count int, account_lead_name text, csm_name text, primary_engineer_name text, health_score int, status text, contract_value_rupees numeric, active_amc_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.chain_code, t.tier, t.hospital_count, t.account_lead_name, t.csm_name, t.primary_engineer_name, t.health_score, t.status, t.contract_value_rupees, t.active_amc_count
  FROM public.hospital_chain_account_teams_r2255 t
  ORDER BY t.contract_value_rupees DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_tier_summary()
RETURNS TABLE (tier text, chain_count bigint, total_contract_rupees numeric, avg_health numeric, at_risk_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tier, COUNT(*)::bigint, COALESCE(SUM(t.contract_value_rupees),0)::numeric, COALESCE(AVG(t.health_score),0)::numeric, (COUNT(*) FILTER (WHERE t.status = 'at_risk'))::int
  FROM public.hospital_chain_account_teams_r2255 t
  GROUP BY t.tier
  ORDER BY CASE t.tier WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 ELSE 4 END;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_at_risk_chains()
RETURNS TABLE (chain_name text, chain_code text, tier text, account_lead_name text, csm_name text, health_score int, contract_value_rupees numeric, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.chain_code, t.tier, t.account_lead_name, t.csm_name, t.health_score, t.contract_value_rupees, t.notes
  FROM public.hospital_chain_account_teams_r2255 t
  WHERE t.status IN ('at_risk','churned')
  ORDER BY t.contract_value_rupees DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_account_lead_load()
RETURNS TABLE (account_lead_name text, chains_assigned bigint, total_hospitals bigint, total_contract_rupees numeric, avg_health numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.account_lead_name, COUNT(*)::bigint, COALESCE(SUM(t.hospital_count),0)::bigint, COALESCE(SUM(t.contract_value_rupees),0)::numeric, COALESCE(AVG(t.health_score),0)::numeric
  FROM public.hospital_chain_account_teams_r2255 t
  GROUP BY t.account_lead_name
  ORDER BY total_contract_rupees DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_csm_load()
RETURNS TABLE (csm_name text, chains_assigned bigint, total_amcs bigint, avg_health numeric, at_risk_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.csm_name, COUNT(*)::bigint, COALESCE(SUM(t.active_amc_count),0)::bigint, COALESCE(AVG(t.health_score),0)::numeric, (COUNT(*) FILTER (WHERE t.status = 'at_risk'))::int
  FROM public.hospital_chain_account_teams_r2255 t
  GROUP BY t.csm_name
  ORDER BY total_amcs DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_escalation_paths()
RETURNS TABLE (chain_name text, chain_code text, escalation_level int, contact_name text, contact_role text, contact_email text, response_sla_minutes int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.chain_code, e.escalation_level, e.contact_name, e.contact_role, e.contact_email, e.response_sla_minutes
  FROM public.hospital_chain_escalations_r2255 e
  JOIN public.hospital_chain_account_teams_r2255 t ON t.id = e.chain_id
  ORDER BY t.chain_name, e.escalation_level;
END;$$;

CREATE OR REPLACE FUNCTION public.r2255_upcoming_qbrs()
RETURNS TABLE (chain_name text, tier text, account_lead_name text, csm_name text, next_qbr_date date, days_until int, health_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.tier, t.account_lead_name, t.csm_name, t.next_qbr_date, (t.next_qbr_date - CURRENT_DATE)::int, t.health_score
  FROM public.hospital_chain_account_teams_r2255 t
  WHERE t.next_qbr_date IS NOT NULL AND t.next_qbr_date >= CURRENT_DATE
  ORDER BY t.next_qbr_date ASC;
END;$$;

REVOKE ALL ON FUNCTION public.r2255_chain_team_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_tier_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_at_risk_chains() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_account_lead_load() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_csm_load() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_escalation_paths() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2255_upcoming_qbrs() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2255_chain_team_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_tier_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_at_risk_chains() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_account_lead_load() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_csm_load() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_escalation_paths() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2255_upcoming_qbrs() TO authenticated;

COMMIT;
