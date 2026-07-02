BEGIN;

-- ============================================================
-- Round 2683: Hospital Chain Quarterly Strategic Account Plan
-- chain x white space x wedge x stakeholder x action x milestone
-- ============================================================

-- ---- Table 1: strategic account plans ----
DROP TABLE IF EXISTS chain_account_plans_r2683 CASCADE;
CREATE TABLE chain_account_plans_r2683 (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter                 text NOT NULL,
  chain_name              text NOT NULL,
  tier                    text NOT NULL CHECK (tier IN ('strategic','growth','watch','dormant')),
  current_arr_rupees      numeric NOT NULL,
  target_arr_rupees       numeric NOT NULL,
  white_space_rupees      numeric NOT NULL,
  hospitals_active        integer NOT NULL,
  hospitals_total         integer NOT NULL,
  wedge_product           text NOT NULL,
  wedge_rationale         text NOT NULL,
  primary_stakeholder     text NOT NULL,
  stakeholder_role        text NOT NULL,
  relationship_health     text NOT NULL CHECK (relationship_health IN ('champion','neutral','at_risk','blocker')),
  plan_status             text NOT NULL CHECK (plan_status IN ('draft','approved','executing','at_risk','won','lost')),
  owner                   text NOT NULL,
  qbr_date                date NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_account_plans_r2683 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_account_plans_r2683;
CREATE POLICY founder_all ON chain_account_plans_r2683 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_account_plans_r2683 (quarter, chain_name, tier, current_arr_rupees, target_arr_rupees, white_space_rupees, hospitals_active, hospitals_total, wedge_product, wedge_rationale, primary_stakeholder, stakeholder_role, relationship_health, plan_status, owner, qbr_date) VALUES
('Q3-2026','Apollo Hospitals','strategic',4800000,8400000,3600000,12,28,'Bonded parts supply','Counterfeit-parts CFO concern after audit Q2; we have bonded chain','Dr Raghu Menon','VP BioMed','champion','executing','founder','2026-07-15'),
('Q3-2026','Fortis Healthcare','strategic',3200000,6500000,3300000,8,22,'AMC Tier-3 + GST auto-file','GST filing pain ate 3 person-days/month at HQ','Priya Sharma','Director Finance','champion','executing','growth','2026-07-22'),
('Q3-2026','Manipal Hospitals','growth',1800000,4200000,2400000,5,18,'Engineer SLA guarantee','Last vendor missed SLA 40%; we offer 2hr response with credit','Vinod Kapoor','GM Operations','neutral','approved','growth','2026-08-05'),
('Q3-2026','Max Healthcare','growth',1200000,3500000,2300000,4,14,'Tier-3 AMC bundle','Bundle 5+ hospitals for tier-3 pricing; 22% savings','Sneha Iyer','Procurement Head','at_risk','at_risk','growth','2026-07-30'),
('Q3-2026','Narayana Health','strategic',2900000,5800000,2900000,7,20,'Hospital portal v2','CTO wants single pane glass for biomed across 20 sites','Dr Anand Rao','CTO','champion','draft','founder','2026-08-12'),
('Q3-2026','KIMS Hospitals','watch',450000,1800000,1350000,2,12,'Pilot expansion','2 sites running 6mo with 4.7 CSAT; replicate to 10','Lakshmi Reddy','COO','neutral','draft','growth','2026-08-20'),
('Q3-2026','Yashoda Hospitals','growth',1100000,2400000,1300000,3,8,'Spot audit + engineer rotation','Hospital lost trust in last vendor on shadow billing','Rajesh Naidu','CFO','blocker','at_risk','founder','2026-07-28');

-- ---- Table 2: actions and milestones ----
DROP TABLE IF EXISTS account_plan_actions_r2683 CASCADE;
CREATE TABLE account_plan_actions_r2683 (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id                 uuid NOT NULL REFERENCES chain_account_plans_r2683(id) ON DELETE CASCADE,
  milestone_name          text NOT NULL,
  action_text             text NOT NULL,
  action_owner            text NOT NULL,
  due_date                date NOT NULL,
  completed_at            timestamptz,
  action_type             text NOT NULL CHECK (action_type IN ('discovery','demo','poc','negotiation','close','expansion','retention')),
  value_unlock_rupees     numeric NOT NULL,
  blocker_text            text,
  status                  text NOT NULL CHECK (status IN ('not_started','in_progress','done','blocked','skipped')),
  created_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE account_plan_actions_r2683 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON account_plan_actions_r2683;
CREATE POLICY founder_all ON account_plan_actions_r2683 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO account_plan_actions_r2683 (plan_id, milestone_name, action_text, action_owner, due_date, completed_at, action_type, value_unlock_rupees, blocker_text, status) VALUES
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Apollo Hospitals'),'Bonded parts MSA','Sign master service agreement covering all 28 hospitals','founder','2026-07-10', now() - interval '2 days','negotiation',3600000,NULL,'done'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Apollo Hospitals'),'16 hospital rollout','Onboard remaining 16 hospitals over 8 weeks','growth','2026-09-15',NULL,'expansion',2400000,NULL,'in_progress'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Fortis Healthcare'),'GST auto-file pilot','Enable GST filing on 4 pilot hospitals; measure time saved','finance','2026-07-25',NULL,'poc',800000,NULL,'in_progress'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Fortis Healthcare'),'Tier-3 AMC upgrade','Upgrade 8 active hospitals from Tier-1 to Tier-3','growth','2026-08-20',NULL,'expansion',1600000,'Procurement bandwidth limited Aug','blocked'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Manipal Hospitals'),'SLA POC','3-hospital POC of 2hr SLA with credit guarantee','ops','2026-08-01',NULL,'poc',900000,NULL,'in_progress'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Max Healthcare'),'CFO escalation','Re-engage CFO to unblock procurement freeze','founder','2026-07-26',NULL,'discovery',2300000,'Procurement freeze announced Q3','blocked'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Narayana Health'),'Hospital portal demo','Demo portal v2 to CTO and 3 site biomed heads','founder','2026-08-08',NULL,'demo',1500000,NULL,'not_started'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Narayana Health'),'Portal MSA','Sign MSA covering 20 hospitals on portal v2','founder','2026-09-30',NULL,'close',2900000,NULL,'not_started'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='KIMS Hospitals'),'Pilot success review','Review 6mo pilot data with COO; pitch 10-site expansion','growth','2026-08-15',NULL,'expansion',1350000,NULL,'not_started'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Yashoda Hospitals'),'CFO trust rebuild','In-person meeting with CFO; share spot audit reports','founder','2026-07-26',NULL,'retention',1100000,'CFO refused 2 prior meetings','blocked'),
((SELECT id FROM chain_account_plans_r2683 WHERE chain_name='Yashoda Hospitals'),'Engineer rotation guarantee','Document rotation policy in contract addendum','ops','2026-08-10',NULL,'negotiation',300000,NULL,'not_started');

-- ============================================================
-- RPCs (8)
-- ============================================================

-- RPC 1: list all account plans
DROP FUNCTION IF EXISTS founder_list_account_plans_r2683();
CREATE FUNCTION founder_list_account_plans_r2683()
RETURNS TABLE (
  id uuid, quarter text, chain_name text, tier text,
  current_arr_rupees numeric, target_arr_rupees numeric, white_space_rupees numeric,
  arr_growth_pct numeric, penetration_pct numeric,
  hospitals_active integer, hospitals_total integer,
  wedge_product text, wedge_rationale text,
  primary_stakeholder text, stakeholder_role text, relationship_health text,
  plan_status text, owner text, qbr_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.id, p.quarter, p.chain_name, p.tier,
           p.current_arr_rupees, p.target_arr_rupees, p.white_space_rupees,
           ROUND(((p.target_arr_rupees - p.current_arr_rupees) / NULLIF(p.current_arr_rupees,0) * 100)::numeric, 1) AS arr_growth_pct,
           ROUND((p.hospitals_active::numeric / NULLIF(p.hospitals_total,0) * 100)::numeric, 1) AS penetration_pct,
           p.hospitals_active, p.hospitals_total,
           p.wedge_product, p.wedge_rationale,
           p.primary_stakeholder, p.stakeholder_role, p.relationship_health,
           p.plan_status, p.owner, p.qbr_date
    FROM chain_account_plans_r2683 p
    ORDER BY p.white_space_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_list_account_plans_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_account_plans_r2683() TO authenticated;

-- RPC 2: portfolio summary
DROP FUNCTION IF EXISTS founder_account_plan_summary_r2683();
CREATE FUNCTION founder_account_plan_summary_r2683()
RETURNS TABLE (
  total_chains integer, strategic_chains integer, growth_chains integer,
  at_risk_chains integer, total_current_arr numeric, total_target_arr numeric,
  total_white_space numeric, avg_penetration_pct numeric, champion_chains integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::integer,
      COUNT(*) FILTER (WHERE tier = 'strategic')::integer,
      COUNT(*) FILTER (WHERE tier = 'growth')::integer,
      COUNT(*) FILTER (WHERE plan_status = 'at_risk')::integer,
      COALESCE(SUM(current_arr_rupees),0),
      COALESCE(SUM(target_arr_rupees),0),
      COALESCE(SUM(white_space_rupees),0),
      ROUND(AVG(hospitals_active::numeric / NULLIF(hospitals_total,0) * 100)::numeric, 1),
      COUNT(*) FILTER (WHERE relationship_health = 'champion')::integer
    FROM chain_account_plans_r2683;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_account_plan_summary_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_account_plan_summary_r2683() TO authenticated;

-- RPC 3: white space ranking
DROP FUNCTION IF EXISTS founder_white_space_ranking_r2683();
CREATE FUNCTION founder_white_space_ranking_r2683()
RETURNS TABLE (
  chain_name text, white_space_rupees numeric, wedge_product text,
  primary_stakeholder text, relationship_health text, plan_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.chain_name, p.white_space_rupees, p.wedge_product,
           p.primary_stakeholder, p.relationship_health, p.plan_status
    FROM chain_account_plans_r2683 p
    ORDER BY p.white_space_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_white_space_ranking_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_white_space_ranking_r2683() TO authenticated;

-- RPC 4: list actions with chain context
DROP FUNCTION IF EXISTS founder_list_actions_r2683();
CREATE FUNCTION founder_list_actions_r2683()
RETURNS TABLE (
  id uuid, chain_name text, milestone_name text, action_text text,
  action_owner text, due_date date, action_type text,
  value_unlock_rupees numeric, blocker_text text, status text,
  completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, p.chain_name, a.milestone_name, a.action_text,
           a.action_owner, a.due_date, a.action_type,
           a.value_unlock_rupees, a.blocker_text, a.status, a.completed_at
    FROM account_plan_actions_r2683 a
    JOIN chain_account_plans_r2683 p ON p.id = a.plan_id
    ORDER BY a.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_list_actions_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_actions_r2683() TO authenticated;

-- RPC 5: blocked actions needing escalation
DROP FUNCTION IF EXISTS founder_blocked_actions_r2683();
CREATE FUNCTION founder_blocked_actions_r2683()
RETURNS TABLE (
  chain_name text, milestone_name text, action_text text,
  blocker_text text, value_unlock_rupees numeric, due_date date,
  relationship_health text, primary_stakeholder text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.chain_name, a.milestone_name, a.action_text,
           a.blocker_text, a.value_unlock_rupees, a.due_date,
           p.relationship_health, p.primary_stakeholder
    FROM account_plan_actions_r2683 a
    JOIN chain_account_plans_r2683 p ON p.id = a.plan_id
    WHERE a.status = 'blocked'
    ORDER BY a.value_unlock_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_blocked_actions_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blocked_actions_r2683() TO authenticated;

-- RPC 6: stakeholder health roll-up
DROP FUNCTION IF EXISTS founder_stakeholder_health_r2683();
CREATE FUNCTION founder_stakeholder_health_r2683()
RETURNS TABLE (
  relationship_health text, chain_count integer,
  total_arr numeric, total_white_space numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.relationship_health,
           COUNT(*)::integer,
           COALESCE(SUM(p.current_arr_rupees),0),
           COALESCE(SUM(p.white_space_rupees),0)
    FROM chain_account_plans_r2683 p
    GROUP BY p.relationship_health
    ORDER BY SUM(p.white_space_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_stakeholder_health_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_stakeholder_health_r2683() TO authenticated;

-- RPC 7: upcoming QBRs (next 60 days)
DROP FUNCTION IF EXISTS founder_upcoming_qbrs_r2683();
CREATE FUNCTION founder_upcoming_qbrs_r2683()
RETURNS TABLE (
  chain_name text, qbr_date date, days_until integer,
  owner text, plan_status text, current_arr_rupees numeric,
  white_space_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT p.chain_name, p.qbr_date,
           (p.qbr_date - CURRENT_DATE)::integer AS days_until,
           p.owner, p.plan_status, p.current_arr_rupees, p.white_space_rupees
    FROM chain_account_plans_r2683 p
    WHERE p.qbr_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60
    ORDER BY p.qbr_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_upcoming_qbrs_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_upcoming_qbrs_r2683() TO authenticated;

-- RPC 8: action progress by type
DROP FUNCTION IF EXISTS founder_action_progress_r2683();
CREATE FUNCTION founder_action_progress_r2683()
RETURNS TABLE (
  action_type text, total_actions integer, done_count integer,
  blocked_count integer, total_value_unlock numeric, done_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.action_type,
           COUNT(*)::integer,
           COUNT(*) FILTER (WHERE a.status = 'done')::integer,
           COUNT(*) FILTER (WHERE a.status = 'blocked')::integer,
           COALESCE(SUM(a.value_unlock_rupees),0),
           ROUND((COUNT(*) FILTER (WHERE a.status = 'done')::numeric / NULLIF(COUNT(*),0) * 100)::numeric, 1)
    FROM account_plan_actions_r2683 a
    GROUP BY a.action_type
    ORDER BY SUM(a.value_unlock_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_action_progress_r2683() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_action_progress_r2683() TO authenticated;

COMMIT;