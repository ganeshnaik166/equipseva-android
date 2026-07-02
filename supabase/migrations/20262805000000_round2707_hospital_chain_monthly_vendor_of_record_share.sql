BEGIN;

-- ============================================================================
-- Round 2707: Hospital Chain Monthly Vendor-of-Record Share
-- HEAVY founder console: chain x our share x other vendors x movement x cause
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: monthly vendor share snapshot per chain
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_chain_vendor_share_r2707 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('apollo','manipal','fortis','max','medanta','aster','kims','rainbow','narayana','yashoda')),
  month_label text NOT NULL,
  snapshot_date date NOT NULL,
  total_addressable_spend_inr bigint NOT NULL CHECK (total_addressable_spend_inr >= 0),
  our_share_inr bigint NOT NULL CHECK (our_share_inr >= 0),
  our_share_pct numeric(5,2) NOT NULL CHECK (our_share_pct >= 0 AND our_share_pct <= 100),
  top_competitor text NOT NULL,
  top_competitor_share_pct numeric(5,2) NOT NULL CHECK (top_competitor_share_pct >= 0 AND top_competitor_share_pct <= 100),
  share_movement_pct numeric(5,2) NOT NULL,
  movement_direction text NOT NULL CHECK (movement_direction IN ('up','down','flat')),
  primary_cause text NOT NULL CHECK (primary_cause IN ('won_amc_renewal','lost_amc_renewal','slow_response','price_war','spare_delay','new_unit_added','engineer_quality','vendor_consolidation')),
  vor_status text NOT NULL CHECK (vor_status IN ('vor','preferred','panel','observation','at_risk','lost')),
  active_units integer NOT NULL CHECK (active_units >= 0),
  monthly_jobs integer NOT NULL CHECK (monthly_jobs >= 0),
  csat_score numeric(3,1) CHECK (csat_score IS NULL OR (csat_score >= 0 AND csat_score <= 5)),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_vendor_share_r2707 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_vendor_share_r2707;
CREATE POLICY founder_all ON hospital_chain_vendor_share_r2707 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_vendor_share_r2707
(chain_name, chain_tier, month_label, snapshot_date, total_addressable_spend_inr, our_share_inr, our_share_pct, top_competitor, top_competitor_share_pct, share_movement_pct, movement_direction, primary_cause, vor_status, active_units, monthly_jobs, csat_score, notes)
VALUES
('Apollo Hospitals','apollo','2026-06','2026-06-30'::date,12500000,4250000,34.00,'Siemens Healthineers',28.50,4.20,'up','won_amc_renewal','preferred',18,142,4.6,'Won Hyderabad cluster AMC renewal worth 1.8Cr'),
('Manipal Hospitals','manipal','2026-06','2026-06-30'::date,8400000,5460000,65.00,'GE Healthcare',18.00,2.10,'up','engineer_quality','vor',12,98,4.8,'VOR status confirmed for 3rd consecutive quarter'),
('Fortis Healthcare','fortis','2026-06','2026-06-30'::date,9800000,2156000,22.00,'Philips Service',38.50,-5.80,'down','slow_response','at_risk','15',76,3.9,'TAT slipped to 14hrs from 8hrs in May - urgent fix needed'),
('Max Healthcare','max','2026-06','2026-06-30'::date,7200000,3960000,55.00,'Drager Service',22.00,8.50,'up','won_amc_renewal','preferred',10,84,4.5,'Captured ventilator AMC from Drager via faster TAT'),
('Medanta Medicity','medanta','2026-06','2026-06-30'::date,6500000,1300000,20.00,'Siemens Healthineers',45.00,-3.20,'down','price_war','panel',8,52,4.2,'Siemens undercut us by 18% on CT tube replacement'),
('Aster DM Healthcare','aster','2026-06','2026-06-30'::date,5800000,3132000,54.00,'BPL Service',16.00,1.50,'up','new_unit_added','vor',9,71,4.7,'Aster Kochi added - 3 new ICUs onboarded'),
('KIMS Hospitals','kims','2026-06','2026-06-30'::date,4200000,2856000,68.00,'Local vendors',12.00,0.00,'flat','vendor_consolidation','vor',11,89,4.8,'Stable VOR - consolidated 4 local vendors into us'),
('Rainbow Childrens','rainbow','2026-06','2026-06-30'::date,3100000,558000,18.00,'Mindray Service',42.00,-12.50,'down','lost_amc_renewal','at_risk',6,28,3.7,'Lost pediatric ventilator AMC to Mindray direct'),
('Narayana Health','narayana','2026-06','2026-06-30'::date,8900000,4005000,45.00,'Philips Service',25.00,3.80,'up','engineer_quality','preferred',14,118,4.6,'Cardiac cath lab service growing - +3 units'),
('Yashoda Hospitals','yashoda','2026-06','2026-06-30'::date,5400000,2916000,54.00,'GE Healthcare',24.00,-1.20,'down','spare_delay','preferred',8,67,4.3,'X-ray tube delivery delays hurting share');

-- ----------------------------------------------------------------------------
-- Table 2: action items to increase share per chain
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hospital_chain_share_actions_r2707 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  action_title text NOT NULL,
  action_category text NOT NULL CHECK (action_category IN ('pricing','tat','engineer_assign','spare_stock','contract_push','exec_meet','demo','escalation')),
  target_share_gain_pct numeric(5,2) NOT NULL CHECK (target_share_gain_pct >= 0),
  estimated_revenue_lift_inr bigint NOT NULL CHECK (estimated_revenue_lift_inr >= 0),
  owner_name text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','approved','in_progress','blocked','done','cancelled')),
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  blocker_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_share_actions_r2707 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_share_actions_r2707;
CREATE POLICY founder_all ON hospital_chain_share_actions_r2707 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_share_actions_r2707
(chain_name, action_title, action_category, target_share_gain_pct, estimated_revenue_lift_inr, owner_name, due_date, status, priority, blocker_note)
VALUES
('Fortis Healthcare','Recover TAT to under 6hrs across 15 units','tat',12.00,1800000,'Operations Head','2026-07-15'::date,'in_progress','p0','Need 3 more L2 engineers in Delhi NCR'),
('Medanta Medicity','Counter Siemens pricing on CT consumables','pricing',8.00,520000,'Founder','2026-07-10'::date,'approved','p0',NULL),
('Apollo Hospitals','Push pan-India AMC for 8 new units','contract_push',6.00,1500000,'KAM Apollo','2026-07-30'::date,'in_progress','p1',NULL),
('Rainbow Childrens','Win back pediatric ventilator AMC','contract_push',15.00,420000,'Sales Director','2026-08-15'::date,'proposed','p1','Need Mindray comparison demo first'),
('Yashoda Hospitals','Build X-ray tube buffer stock','spare_stock',5.00,180000,'Supply Chain','2026-07-20'::date,'blocked','p1','Vendor PO stuck in finance approval'),
('Max Healthcare','Quarterly business review with CMO','exec_meet',4.00,290000,'Founder','2026-07-05'::date,'approved','p2',NULL),
('Manipal Hospitals','Pilot AI-triage on Bangalore cluster','demo',3.00,160000,'CTO','2026-08-01'::date,'proposed','p2',NULL),
('Narayana Health','Dedicated cath-lab engineer hire','engineer_assign',7.00,620000,'HR Head','2026-07-25'::date,'in_progress','p1',NULL),
('Aster DM Healthcare','Kerala cluster onboarding ceremony','exec_meet',3.50,210000,'Regional Head','2026-07-12'::date,'approved','p2',NULL),
('KIMS Hospitals','Lock 3-year VOR contract renewal','contract_push',2.00,580000,'Founder','2026-09-01'::date,'proposed','p1','Awaiting board approval at KIMS');

-- ----------------------------------------------------------------------------
-- RPCs (all SECDEF + is_founder gate)
-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS f_r2707_chain_share_overview();
CREATE OR REPLACE FUNCTION f_r2707_chain_share_overview()
RETURNS TABLE(
  chains_tracked integer,
  total_addressable_inr bigint,
  total_our_share_inr bigint,
  weighted_share_pct numeric,
  vor_chains integer,
  at_risk_chains integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COALESCE(SUM(total_addressable_spend_inr),0)::bigint,
    COALESCE(SUM(our_share_inr),0)::bigint,
    CASE WHEN COALESCE(SUM(total_addressable_spend_inr),0) = 0 THEN 0::numeric
         ELSE ROUND(SUM(our_share_inr)::numeric / SUM(total_addressable_spend_inr)::numeric * 100, 2) END,
    COUNT(*) FILTER (WHERE vor_status = 'vor')::integer,
    COUNT(*) FILTER (WHERE vor_status = 'at_risk' OR vor_status = 'lost')::integer
  FROM hospital_chain_vendor_share_r2707;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_chain_share_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_chain_share_overview() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_chain_share_rows();
CREATE OR REPLACE FUNCTION f_r2707_chain_share_rows()
RETURNS TABLE(
  id uuid,
  chain_name text,
  chain_tier text,
  month_label text,
  total_addressable_spend_inr bigint,
  our_share_inr bigint,
  our_share_pct numeric,
  top_competitor text,
  top_competitor_share_pct numeric,
  share_movement_pct numeric,
  movement_direction text,
  primary_cause text,
  vor_status text,
  active_units integer,
  monthly_jobs integer,
  csat_score numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.chain_tier, s.month_label, s.total_addressable_spend_inr,
         s.our_share_inr, s.our_share_pct, s.top_competitor, s.top_competitor_share_pct,
         s.share_movement_pct, s.movement_direction, s.primary_cause, s.vor_status,
         s.active_units, s.monthly_jobs, s.csat_score, s.notes
  FROM hospital_chain_vendor_share_r2707 s
  ORDER BY s.our_share_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_chain_share_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_chain_share_rows() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_share_movement_breakdown();
CREATE OR REPLACE FUNCTION f_r2707_share_movement_breakdown()
RETURNS TABLE(
  movement_direction text,
  chain_count integer,
  total_movement_pct numeric,
  total_our_share_inr bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.movement_direction, COUNT(*)::integer,
         ROUND(SUM(s.share_movement_pct), 2),
         COALESCE(SUM(s.our_share_inr), 0)::bigint
  FROM hospital_chain_vendor_share_r2707 s
  GROUP BY s.movement_direction
  ORDER BY SUM(s.share_movement_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_share_movement_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_share_movement_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_cause_breakdown();
CREATE OR REPLACE FUNCTION f_r2707_cause_breakdown()
RETURNS TABLE(
  primary_cause text,
  chain_count integer,
  avg_movement_pct numeric,
  total_share_impact_inr bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.primary_cause, COUNT(*)::integer,
         ROUND(AVG(s.share_movement_pct), 2),
         COALESCE(SUM(s.our_share_inr), 0)::bigint
  FROM hospital_chain_vendor_share_r2707 s
  GROUP BY s.primary_cause
  ORDER BY SUM(s.our_share_inr) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_cause_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_top_competitors();
CREATE OR REPLACE FUNCTION f_r2707_top_competitors()
RETURNS TABLE(
  top_competitor text,
  chains_competing_in integer,
  avg_competitor_share_pct numeric,
  total_competitor_value_inr bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.top_competitor, COUNT(*)::integer,
         ROUND(AVG(s.top_competitor_share_pct), 2),
         COALESCE(SUM((s.total_addressable_spend_inr * s.top_competitor_share_pct / 100)::bigint), 0)::bigint
  FROM hospital_chain_vendor_share_r2707 s
  GROUP BY s.top_competitor
  ORDER BY SUM(s.total_addressable_spend_inr * s.top_competitor_share_pct / 100) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_top_competitors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_top_competitors() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_at_risk_chains();
CREATE OR REPLACE FUNCTION f_r2707_at_risk_chains()
RETURNS TABLE(
  chain_name text,
  vor_status text,
  our_share_pct numeric,
  share_movement_pct numeric,
  primary_cause text,
  top_competitor text,
  our_share_inr bigint,
  csat_score numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_name, s.vor_status, s.our_share_pct, s.share_movement_pct,
         s.primary_cause, s.top_competitor, s.our_share_inr, s.csat_score, s.notes
  FROM hospital_chain_vendor_share_r2707 s
  WHERE s.vor_status IN ('at_risk','lost','observation') OR s.share_movement_pct < 0
  ORDER BY s.share_movement_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_at_risk_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_at_risk_chains() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_increase_actions();
CREATE OR REPLACE FUNCTION f_r2707_increase_actions()
RETURNS TABLE(
  id uuid,
  chain_name text,
  action_title text,
  action_category text,
  target_share_gain_pct numeric,
  estimated_revenue_lift_inr bigint,
  owner_name text,
  due_date date,
  status text,
  priority text,
  blocker_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.action_title, a.action_category, a.target_share_gain_pct,
         a.estimated_revenue_lift_inr, a.owner_name, a.due_date, a.status, a.priority, a.blocker_note
  FROM hospital_chain_share_actions_r2707 a
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_increase_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_increase_actions() TO authenticated;

DROP FUNCTION IF EXISTS f_r2707_action_pipeline_summary();
CREATE OR REPLACE FUNCTION f_r2707_action_pipeline_summary()
RETURNS TABLE(
  status text,
  action_count integer,
  total_target_gain_pct numeric,
  total_revenue_lift_inr bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, COUNT(*)::integer,
         ROUND(SUM(a.target_share_gain_pct), 2),
         COALESCE(SUM(a.estimated_revenue_lift_inr), 0)::bigint
  FROM hospital_chain_share_actions_r2707 a
  GROUP BY a.status
  ORDER BY SUM(a.estimated_revenue_lift_inr) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION f_r2707_action_pipeline_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2707_action_pipeline_summary() TO authenticated;

COMMIT;
