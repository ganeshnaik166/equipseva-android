BEGIN;

-- =====================================================================
-- Round 2767 — Hospital Chain Quarterly M&A Impact
-- Tracks M&A events at hospital chains, our exposure, renegotiation
-- posture, outcomes, and strategy moves.
-- =====================================================================

CREATE TABLE IF NOT EXISTS chain_ma_events_r2767 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('acquisition','merger','divestiture','spinoff','jv','minority_stake')),
  event_quarter text NOT NULL,
  announced_on date NOT NULL,
  expected_close_on date,
  closed_on date,
  counterparty text NOT NULL,
  deal_value_crore numeric(12,2) NOT NULL CHECK (deal_value_crore >= 0),
  acquirer_country text NOT NULL DEFAULT 'IN',
  combined_beds int NOT NULL CHECK (combined_beds >= 0),
  combined_hospitals int NOT NULL CHECK (combined_hospitals >= 0),
  our_active_contracts int NOT NULL CHECK (our_active_contracts >= 0),
  our_active_engineers int NOT NULL CHECK (our_active_engineers >= 0),
  our_quarterly_revenue_lakh numeric(12,2) NOT NULL CHECK (our_quarterly_revenue_lakh >= 0),
  exposure_tier text NOT NULL CHECK (exposure_tier IN ('critical','high','medium','low')),
  renegotiation_status text NOT NULL CHECK (renegotiation_status IN ('not_started','requested','in_progress','signed','lost')),
  renegotiation_outcome text CHECK (renegotiation_outcome IN ('expanded','retained','reduced','terminated','pending')),
  contract_delta_pct numeric(6,2),
  strategy_play text NOT NULL CHECK (strategy_play IN ('lock_in','expand','defend','exit','observe')),
  owner_role text NOT NULL CHECK (owner_role IN ('founder','head_sales','head_ops','head_clinical')),
  next_review_on date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_ma_events_r2767 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_ma_events_r2767;
CREATE POLICY founder_all ON chain_ma_events_r2767
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_ma_events_r2767
  (chain_name,event_type,event_quarter,announced_on,expected_close_on,closed_on,counterparty,deal_value_crore,acquirer_country,combined_beds,combined_hospitals,our_active_contracts,our_active_engineers,our_quarterly_revenue_lakh,exposure_tier,renegotiation_status,renegotiation_outcome,contract_delta_pct,strategy_play,owner_role,next_review_on,notes)
VALUES
  ('Apollo Hospitals','acquisition','Q2-FY27','2026-04-12'::date,'2026-08-30'::date,NULL,'Care Hospitals (Blackstone exit)',6200.00,'IN',12800,74,38,46,182.50,'critical','in_progress','pending',NULL,'expand','founder','2026-07-05'::date,'Combined AMC RFP expected post close — push tier-1 SLA.'),
  ('Manipal Hospitals','merger','Q1-FY27','2026-02-08'::date,'2026-05-22'::date,'2026-05-22'::date,'AMRI Kolkata',2100.00,'IN',9400,33,21,28,98.40,'high','signed','expanded',18.50,'lock_in','head_sales','2026-07-15'::date,'Renegotiated master AMC +18.5% scope · 6 added sites.'),
  ('Fortis Healthcare','minority_stake','Q2-FY27','2026-04-30'::date,'2026-07-15'::date,NULL,'IHH Healthcare top-up',1450.00,'MY',6800,28,17,22,76.20,'high','requested','pending',NULL,'defend','head_sales','2026-06-30'::date,'IHH pushing global vendor list — counter with India service-density argument.'),
  ('Aster DM Healthcare','divestiture','Q1-FY27','2026-01-18'::date,'2026-04-09'::date,'2026-04-09'::date,'GCC business sold to Alpha GCC',8800.00,'AE',4200,17,9,12,42.10,'medium','signed','retained',-3.20,'defend','head_ops','2026-07-20'::date,'India entity retained AMC; -3.2% scope after GCC carveout.'),
  ('Max Healthcare','acquisition','Q2-FY27','2026-05-02'::date,'2026-09-10'::date,NULL,'Sahara Hospital Lucknow',940.00,'IN',5100,21,14,18,68.90,'high','in_progress','pending',NULL,'expand','founder','2026-07-08'::date,'Lucknow corridor — pitch combined AMC + engineer redeployment.'),
  ('KIMS Hospitals','jv','Q2-FY27','2026-04-25'::date,'2026-08-05'::date,NULL,'Sunshine Hospitals (Hyd)',780.00,'IN',3600,11,8,11,34.50,'medium','not_started','pending',NULL,'observe','head_clinical','2026-07-25'::date,'Wait for governance clarity before initiating renegotiation.'),
  ('Narayana Health','spinoff','Q1-FY27','2026-03-14'::date,'2026-06-30'::date,NULL,'NH Insurance arm spinoff',310.00,'IN',6700,24,15,19,71.80,'low','requested','pending',NULL,'observe','head_ops','2026-07-30'::date,'Insurance carveout — clinical AMC unaffected; keep watch.'),
  ('Medanta','acquisition','Q2-FY27','2026-05-18'::date,'2026-10-15'::date,NULL,'Global Health undisclosed target',2300.00,'IN',4900,7,5,8,28.30,'medium','not_started','pending',NULL,'expand','head_sales','2026-08-05'::date,'Small foothold — use M&A to plant flag at new sites.');

CREATE TABLE IF NOT EXISTS chain_ma_actions_r2767 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES chain_ma_events_r2767(id) ON DELETE CASCADE,
  action_date date NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('exec_meeting','rfp_response','site_visit','pricing_revision','sla_revision','legal_review','exit_notice','expansion_signed')),
  owner text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','blocked')),
  revenue_impact_lakh numeric(12,2) NOT NULL DEFAULT 0,
  followup_due_on date,
  summary text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_ma_actions_r2767 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_ma_actions_r2767;
CREATE POLICY founder_all ON chain_ma_actions_r2767
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_ma_actions_r2767
  (event_id,action_date,action_type,owner,outcome,revenue_impact_lakh,followup_due_on,summary)
SELECT id,'2026-05-04'::date,'exec_meeting','Ganesh D','positive',0,'2026-06-25'::date,'Apollo CFO confirmed AMC renegotiation post Care close — Aug window.'
FROM chain_ma_events_r2767 WHERE chain_name='Apollo Hospitals'
UNION ALL
SELECT id,'2026-05-22'::date,'expansion_signed','Head Sales','positive',32.40,'2026-08-15'::date,'Manipal+AMRI master AMC signed — +6 sites · +18.5% scope.'
FROM chain_ma_events_r2767 WHERE chain_name='Manipal Hospitals'
UNION ALL
SELECT id,'2026-05-10'::date,'rfp_response','Head Sales','neutral',0,'2026-06-28'::date,'Fortis sent IHH global RFP — submitted India-density rebuttal.'
FROM chain_ma_events_r2767 WHERE chain_name='Fortis Healthcare'
UNION ALL
SELECT id,'2026-04-15'::date,'sla_revision','Head Ops','positive',-1.30,'2026-07-15'::date,'Aster India SLA refreshed post-GCC carveout, -3.2% scope.'
FROM chain_ma_events_r2767 WHERE chain_name='Aster DM Healthcare'
UNION ALL
SELECT id,'2026-05-19'::date,'site_visit','Ganesh D','positive',0,'2026-06-30'::date,'Walked Max Lucknow corridor; pitched combined AMC + redeploy.'
FROM chain_ma_events_r2767 WHERE chain_name='Max Healthcare'
UNION ALL
SELECT id,'2026-04-28'::date,'legal_review','Legal','neutral',0,'2026-07-20'::date,'KIMS JV governance docs under review — hold renegotiation.'
FROM chain_ma_events_r2767 WHERE chain_name='KIMS Hospitals'
UNION ALL
SELECT id,'2026-05-12'::date,'pricing_revision','Head Sales','positive',4.80,'2026-08-01'::date,'Medanta expansion pricing locked at +12% premium tier.'
FROM chain_ma_events_r2767 WHERE chain_name='Medanta';

-- ============================ RPCs =====================================

DROP FUNCTION IF EXISTS chain_ma_overview_r2767();
CREATE OR REPLACE FUNCTION chain_ma_overview_r2767()
RETURNS TABLE (
  total_events int,
  closed_events int,
  pending_events int,
  total_deal_value_crore numeric,
  exposed_revenue_lakh numeric,
  active_contracts int,
  expanded_contracts int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE closed_on IS NOT NULL)::int,
    COUNT(*) FILTER (WHERE closed_on IS NULL)::int,
    COALESCE(SUM(deal_value_crore),0)::numeric,
    COALESCE(SUM(our_quarterly_revenue_lakh),0)::numeric,
    COALESCE(SUM(our_active_contracts),0)::int,
    COUNT(*) FILTER (WHERE renegotiation_outcome='expanded')::int
  FROM chain_ma_events_r2767;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_overview_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_overview_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_events_list_r2767();
CREATE OR REPLACE FUNCTION chain_ma_events_list_r2767()
RETURNS SETOF chain_ma_events_r2767
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM chain_ma_events_r2767
  ORDER BY
    CASE exposure_tier WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    announced_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_events_list_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_events_list_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_by_exposure_r2767();
CREATE OR REPLACE FUNCTION chain_ma_by_exposure_r2767()
RETURNS TABLE (
  exposure_tier text,
  events int,
  contracts int,
  engineers int,
  quarterly_revenue_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.exposure_tier::text,
    COUNT(*)::int,
    SUM(e.our_active_contracts)::int,
    SUM(e.our_active_engineers)::int,
    SUM(e.our_quarterly_revenue_lakh)::numeric
  FROM chain_ma_events_r2767 e
  GROUP BY e.exposure_tier
  ORDER BY
    CASE e.exposure_tier WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_by_exposure_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_by_exposure_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_renegotiation_status_r2767();
CREATE OR REPLACE FUNCTION chain_ma_renegotiation_status_r2767()
RETURNS TABLE (
  renegotiation_status text,
  events int,
  signed_share_pct numeric,
  revenue_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM chain_ma_events_r2767;
  RETURN QUERY
  SELECT
    e.renegotiation_status::text,
    COUNT(*)::int,
    CASE WHEN total = 0 THEN 0 ELSE ROUND((COUNT(*)::numeric / total::numeric) * 100, 2) END,
    SUM(e.our_quarterly_revenue_lakh)::numeric
  FROM chain_ma_events_r2767 e
  GROUP BY e.renegotiation_status
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_renegotiation_status_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_renegotiation_status_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_strategy_mix_r2767();
CREATE OR REPLACE FUNCTION chain_ma_strategy_mix_r2767()
RETURNS TABLE (
  strategy_play text,
  events int,
  avg_contract_delta_pct numeric,
  revenue_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.strategy_play::text,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(e.contract_delta_pct),2),0),
    SUM(e.our_quarterly_revenue_lakh)::numeric
  FROM chain_ma_events_r2767 e
  GROUP BY e.strategy_play
  ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_strategy_mix_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_strategy_mix_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_recent_actions_r2767();
CREATE OR REPLACE FUNCTION chain_ma_recent_actions_r2767()
RETURNS TABLE (
  chain_name text,
  action_date date,
  action_type text,
  owner text,
  outcome text,
  revenue_impact_lakh numeric,
  summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_name, a.action_date, a.action_type::text, a.owner, a.outcome::text,
         a.revenue_impact_lakh, a.summary
  FROM chain_ma_actions_r2767 a
  JOIN chain_ma_events_r2767 e ON e.id = a.event_id
  ORDER BY a.action_date DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_recent_actions_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_recent_actions_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_upcoming_reviews_r2767();
CREATE OR REPLACE FUNCTION chain_ma_upcoming_reviews_r2767()
RETURNS TABLE (
  chain_name text,
  next_review_on date,
  days_until int,
  exposure_tier text,
  renegotiation_status text,
  strategy_play text,
  owner_role text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_name, e.next_review_on,
         (e.next_review_on - CURRENT_DATE)::int,
         e.exposure_tier::text, e.renegotiation_status::text,
         e.strategy_play::text, e.owner_role::text
  FROM chain_ma_events_r2767 e
  ORDER BY e.next_review_on ASC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_upcoming_reviews_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_upcoming_reviews_r2767() TO authenticated;

DROP FUNCTION IF EXISTS chain_ma_outcome_summary_r2767();
CREATE OR REPLACE FUNCTION chain_ma_outcome_summary_r2767()
RETURNS TABLE (
  renegotiation_outcome text,
  events int,
  avg_delta_pct numeric,
  revenue_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(e.renegotiation_outcome,'pending')::text,
         COUNT(*)::int,
         COALESCE(ROUND(AVG(e.contract_delta_pct),2),0),
         SUM(e.our_quarterly_revenue_lakh)::numeric
  FROM chain_ma_events_r2767 e
  GROUP BY e.renegotiation_outcome
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION chain_ma_outcome_summary_r2767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION chain_ma_outcome_summary_r2767() TO authenticated;

COMMIT;
