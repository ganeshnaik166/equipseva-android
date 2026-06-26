BEGIN;

-- =========================================================
-- Round 2817 — Founder Quarterly India Policy Watch
-- =========================================================

CREATE TABLE IF NOT EXISTS policy_items_r2817 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  policy_code text NOT NULL,
  policy_title text NOT NULL,
  ministry text NOT NULL CHECK (ministry IN ('mohfw','meity','dpiit','cdsco','niti_aayog','finance','commerce','labour','environment')),
  stage text NOT NULL CHECK (stage IN ('draft','consultation','cabinet','enacted','gazetted','implemented','paused','withdrawn')),
  impact text NOT NULL CHECK (impact IN ('existential','major','moderate','minor','watch_only')),
  stance text NOT NULL CHECK (stance IN ('supportive','neutral','concerned','opposed','watching')),
  engagement_mode text NOT NULL CHECK (engagement_mode IN ('public_comment','industry_body','direct_meeting','press_op_ed','none')),
  business_move text NOT NULL,
  est_revenue_impact_lakhs numeric(12,2) NOT NULL DEFAULT 0,
  owner text NOT NULL,
  reviewed_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE policy_items_r2817 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON policy_items_r2817;
CREATE POLICY founder_all ON policy_items_r2817 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO policy_items_r2817 (quarter, policy_code, policy_title, ministry, stage, impact, stance, engagement_mode, business_move, est_revenue_impact_lakhs, owner, reviewed_on) VALUES
  ('Q2-FY27','MDR-2026-AMD','Medical Devices Rules amendment Class B reclass','cdsco','consultation','major','concerned','public_comment','File public comment via AIMED; prepare Class B QMS roadmap',-42.50,'founder','2026-06-10'::date),
  ('Q2-FY27','PLI-MD-Phase3','PLI Phase-3 medical devices manufacturing','dpiit','enacted','major','supportive','industry_body','Apply for Phase-3 quota; partner with TS MedTech Park',180.00,'cofounder','2026-06-12'::date),
  ('Q2-FY27','DPDP-RULES','DPDP Act implementation rules notified','meity','gazetted','existential','neutral','direct_meeting','Appoint DPO; ship grievance officer portal; complete DPIA',-25.00,'founder','2026-06-15'::date),
  ('Q2-FY27','GST-HSN-9018','GST rate cut on HSN 9018 medical devices 12 to 5','finance','cabinet','major','supportive','press_op_ed','Pass-through to hospitals; refresh quotes; reprice AMC',95.00,'cfo','2026-06-18'::date),
  ('Q2-FY27','NABH-V2','NABH digital accreditation v2 small hospital pathway','mohfw','implemented','moderate','supportive','industry_body','Bundle NABH ZIP into AMC tier-3; ₹15k uplift per contract',62.50,'product','2026-06-20'::date),
  ('Q2-FY27','LABOUR-FE','Field engineer gig classification update','labour','draft','moderate','concerned','direct_meeting','Convert top engineers to W-2; document training hours',-18.00,'people_ops','2026-06-22'::date),
  ('Q2-FY27','EWASTE-2026','E-waste rules biomedical electronics inclusion','environment','consultation','moderate','watching','public_comment','Tie up with authorized recycler; charge ₹500/asset disposal',12.00,'ops','2026-06-24'::date);

-- =========================================================

CREATE TABLE IF NOT EXISTS policy_engagement_log_r2817 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES policy_items_r2817(id) ON DELETE CASCADE,
  engaged_on date NOT NULL,
  channel text NOT NULL CHECK (channel IN ('email','meeting','submission','press','social','call')),
  counterparty text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('acknowledged','no_response','meeting_set','escalated','resolved','closed')),
  notes text NOT NULL,
  hours_spent numeric(5,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE policy_engagement_log_r2817 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON policy_engagement_log_r2817;
CREATE POLICY founder_all ON policy_engagement_log_r2817 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO policy_engagement_log_r2817 (policy_id, engaged_on, channel, counterparty, outcome, notes, hours_spent)
SELECT id, '2026-06-11'::date, 'submission', 'AIMED-CDSCO joint committee', 'acknowledged', 'Filed 8-page public comment on Class B reclass timeline', 6.00 FROM policy_items_r2817 WHERE policy_code = 'MDR-2026-AMD'
UNION ALL
SELECT id, '2026-06-13'::date, 'meeting', 'DPIIT Phase-3 desk officer', 'meeting_set', 'PLI quota application pre-check scheduled 2026-07-02', 2.50 FROM policy_items_r2817 WHERE policy_code = 'PLI-MD-Phase3'
UNION ALL
SELECT id, '2026-06-16'::date, 'meeting', 'MeitY DPDP rules cell', 'resolved', 'Got clarification on DPO threshold for SDF MSME exemption', 3.00 FROM policy_items_r2817 WHERE policy_code = 'DPDP-RULES'
UNION ALL
SELECT id, '2026-06-19'::date, 'press', 'ET HealthWorld op-ed', 'acknowledged', 'Op-ed on GST cut pass-through to small hospitals filed', 4.00 FROM policy_items_r2817 WHERE policy_code = 'GST-HSN-9018'
UNION ALL
SELECT id, '2026-06-21'::date, 'email', 'NABH digital accreditation desk', 'no_response', 'Asked for bulk small-hospital onboarding rate card', 0.50 FROM policy_items_r2817 WHERE policy_code = 'NABH-V2'
UNION ALL
SELECT id, '2026-06-23'::date, 'call', 'Labour ministry gig cell', 'escalated', 'Escalated to joint secretary on training-hours definition', 1.50 FROM policy_items_r2817 WHERE policy_code = 'LABOUR-FE';

-- =========================================================
-- RPCs
-- =========================================================

DROP FUNCTION IF EXISTS f_policy_kpis_r2817();
CREATE OR REPLACE FUNCTION f_policy_kpis_r2817()
RETURNS TABLE (
  total_items int,
  existential_items int,
  major_items int,
  net_revenue_impact_lakhs numeric,
  concerned_items int,
  engagements_logged int,
  hours_spent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM policy_items_r2817),
    (SELECT count(*)::int FROM policy_items_r2817 WHERE impact = 'existential'),
    (SELECT count(*)::int FROM policy_items_r2817 WHERE impact = 'major'),
    (SELECT coalesce(sum(est_revenue_impact_lakhs),0) FROM policy_items_r2817),
    (SELECT count(*)::int FROM policy_items_r2817 WHERE stance = 'concerned'),
    (SELECT count(*)::int FROM policy_engagement_log_r2817),
    (SELECT coalesce(sum(hours_spent),0) FROM policy_engagement_log_r2817);
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_kpis_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_kpis_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_by_ministry_r2817();
CREATE OR REPLACE FUNCTION f_policy_by_ministry_r2817()
RETURNS TABLE (ministry text, items int, net_impact_lakhs numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.ministry, count(*)::int, coalesce(sum(p.est_revenue_impact_lakhs),0)
  FROM policy_items_r2817 p
  GROUP BY p.ministry
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_by_ministry_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_by_ministry_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_by_stage_r2817();
CREATE OR REPLACE FUNCTION f_policy_by_stage_r2817()
RETURNS TABLE (stage text, items int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.stage, count(*)::int
  FROM policy_items_r2817 p
  GROUP BY p.stage
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_by_stage_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_by_stage_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_top_impact_r2817();
CREATE OR REPLACE FUNCTION f_policy_top_impact_r2817()
RETURNS TABLE (policy_code text, policy_title text, impact text, stance text, est_revenue_impact_lakhs numeric, business_move text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.policy_code, p.policy_title, p.impact, p.stance, p.est_revenue_impact_lakhs, p.business_move
  FROM policy_items_r2817 p
  ORDER BY abs(p.est_revenue_impact_lakhs) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_top_impact_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_top_impact_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_engagement_log_r2817();
CREATE OR REPLACE FUNCTION f_policy_engagement_log_r2817()
RETURNS TABLE (policy_code text, engaged_on date, channel text, counterparty text, outcome text, hours_spent numeric, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.policy_code, e.engaged_on, e.channel, e.counterparty, e.outcome, e.hours_spent, e.notes
  FROM policy_engagement_log_r2817 e
  JOIN policy_items_r2817 p ON p.id = e.policy_id
  ORDER BY e.engaged_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_engagement_log_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_engagement_log_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_concerned_items_r2817();
CREATE OR REPLACE FUNCTION f_policy_concerned_items_r2817()
RETURNS TABLE (policy_code text, policy_title text, ministry text, stage text, owner text, business_move text, reviewed_on date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.policy_code, p.policy_title, p.ministry, p.stage, p.owner, p.business_move, p.reviewed_on
  FROM policy_items_r2817 p
  WHERE p.stance IN ('concerned','opposed')
  ORDER BY p.reviewed_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_concerned_items_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_concerned_items_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_engagement_summary_r2817();
CREATE OR REPLACE FUNCTION f_policy_engagement_summary_r2817()
RETURNS TABLE (channel text, engagements int, total_hours numeric, resolved_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.channel,
         count(*)::int,
         coalesce(sum(e.hours_spent),0),
         sum(CASE WHEN e.outcome = 'resolved' THEN 1 ELSE 0 END)::int
  FROM policy_engagement_log_r2817 e
  GROUP BY e.channel
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_engagement_summary_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_engagement_summary_r2817() TO authenticated;

DROP FUNCTION IF EXISTS f_policy_all_items_r2817();
CREATE OR REPLACE FUNCTION f_policy_all_items_r2817()
RETURNS TABLE (policy_code text, policy_title text, ministry text, stage text, impact text, stance text, engagement_mode text, est_revenue_impact_lakhs numeric, owner text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.policy_code, p.policy_title, p.ministry, p.stage, p.impact, p.stance, p.engagement_mode, p.est_revenue_impact_lakhs, p.owner
  FROM policy_items_r2817 p
  ORDER BY p.reviewed_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_policy_all_items_r2817() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_policy_all_items_r2817() TO authenticated;

COMMIT;
