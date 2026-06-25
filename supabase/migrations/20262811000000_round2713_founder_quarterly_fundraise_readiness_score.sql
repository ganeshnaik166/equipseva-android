BEGIN;

-- ============================================================================
-- Round 2713 — Founder Quarterly Fundraise Readiness Score
-- pillar x score x evidence x gap x close action x target round x decision
-- ============================================================================

CREATE TABLE IF NOT EXISTS fundraise_readiness_pillars_r2713 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pillar_code text NOT NULL UNIQUE,
  pillar_name text NOT NULL,
  category text NOT NULL CHECK (category IN ('traction','financials','team','product','market','governance','compliance')),
  weight_pct integer NOT NULL CHECK (weight_pct BETWEEN 1 AND 100),
  current_score integer NOT NULL CHECK (current_score BETWEEN 0 AND 100),
  target_score integer NOT NULL CHECK (target_score BETWEEN 0 AND 100),
  evidence_summary text NOT NULL,
  gap_summary text NOT NULL,
  close_action text NOT NULL,
  owner text NOT NULL,
  target_round integer NOT NULL CHECK (target_round BETWEEN 1 AND 5000),
  decision text NOT NULL CHECK (decision IN ('ship_now','accelerate','watch','defer','blocker')),
  reviewed_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE fundraise_readiness_pillars_r2713 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON fundraise_readiness_pillars_r2713;
CREATE POLICY founder_all ON fundraise_readiness_pillars_r2713 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS fundraise_readiness_evidence_r2713 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pillar_code text NOT NULL REFERENCES fundraise_readiness_pillars_r2713(pillar_code) ON DELETE CASCADE,
  evidence_kind text NOT NULL CHECK (evidence_kind IN ('metric','contract','testimonial','filing','dashboard','letter','dataroom_doc')),
  evidence_title text NOT NULL,
  evidence_value text NOT NULL,
  source_url text,
  strength text NOT NULL CHECK (strength IN ('weak','moderate','strong','signature')),
  collected_at date NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE fundraise_readiness_evidence_r2713 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON fundraise_readiness_evidence_r2713;
CREATE POLICY founder_all ON fundraise_readiness_evidence_r2713 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed pillars
INSERT INTO fundraise_readiness_pillars_r2713 (pillar_code, pillar_name, category, weight_pct, current_score, target_score, evidence_summary, gap_summary, close_action, owner, target_round, decision, reviewed_at) VALUES
  ('REV_GROWTH','MRR growth 3x YoY','traction',20,82,90,'MRR 12.4L Q4, 4.1L Q4 prior — 3.02x','Need clean cohort retention chart','Build cohort heatmap dashboard','Founder',2720,'ship_now','2026-06-21'::date),
  ('UNIT_ECON','Contribution margin per AMC','financials',15,71,85,'Avg CM 38% across 412 active AMCs','High-tier mix only 22% — pull to 35%','Launch tier-upgrade push','Sales',2730,'accelerate','2026-06-21'::date),
  ('TEAM_DEPTH','Eng + Sales bench','team',10,55,80,'2 founders + 4 engineers + 2 sales','No VP Sales, no CFO','Hire VP Sales by Q2 close','Founder',2755,'blocker','2026-06-21'::date),
  ('PRODUCT_NPS','Engineer + Hospital NPS','product',10,88,90,'Engineer NPS 72, Hospital NPS 64','Need third-party verified survey','Commission Bain micro-survey','Ops',2740,'watch','2026-06-21'::date),
  ('MARKET_TAM','Class A/B + super-specialty TAM','market',15,78,85,'2.1k hospitals mapped, 412 paying','TAM letter from Frost or RedSeer','Commission TAM letter','Founder',2750,'accelerate','2026-06-21'::date),
  ('GOVERNANCE','Board + ESOP + auditor','governance',15,62,90,'2 board seats, no ind dir, auditor TBD','No independent director, no audited FY26','Onboard ind dir + Big4 auditor','Founder',2770,'blocker','2026-06-21'::date),
  ('COMPLIANCE','DPDP + CDSCO + GST current','compliance',15,90,95,'DPDP filing done, CDSCO rep letter live','Annual ROC pending','File ROC by 30-Sep','Compliance',2725,'ship_now','2026-06-21'::date);

-- Seed evidence
INSERT INTO fundraise_readiness_evidence_r2713 (pillar_code, evidence_kind, evidence_title, evidence_value, source_url, strength, collected_at, verified, notes) VALUES
  ('REV_GROWTH','metric','Q4 MRR live','12,40,000 INR','/founder-revenue-pulse','signature','2026-06-20'::date,true,'Stripe + Cashfree reconciled'),
  ('UNIT_ECON','dashboard','AMC unit economics','38% CM avg','/founder-unit-economics','strong','2026-06-19'::date,true,'412 contracts'),
  ('TEAM_DEPTH','contract','Hiring pipeline','3 VP Sales candidates','/founder-hiring-pipeline','moderate','2026-06-18'::date,false,'Round 2 offers pending'),
  ('PRODUCT_NPS','metric','Engineer NPS Q4','72','/founder-engineer-nps','strong','2026-06-17'::date,true,'n=148 engineers'),
  ('MARKET_TAM','dataroom_doc','TAM workbook v3','2.1k hospitals','/dataroom/tam.xlsx','moderate','2026-06-15'::date,false,'Needs third-party letter'),
  ('GOVERNANCE','filing','Articles of Association','AoA filed','/dataroom/aoa.pdf','strong','2026-06-10'::date,true,'MCA verified'),
  ('COMPLIANCE','letter','CDSCO representation letter','Active','/dataroom/cdsco.pdf','signature','2026-06-08'::date,true,'Valid till Mar 2027');

-- ============================================================================
-- RPCs (7+ SECURITY DEFINER functions)
-- ============================================================================

DROP FUNCTION IF EXISTS get_fundraise_pillars_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_pillars_r2713()
RETURNS SETOF fundraise_readiness_pillars_r2713
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM fundraise_readiness_pillars_r2713 ORDER BY weight_pct DESC, pillar_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_pillars_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_pillars_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_score_summary_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_score_summary_r2713()
RETURNS TABLE(total_pillars integer, weighted_current numeric, weighted_target numeric, gap_points numeric, blockers integer, ship_now integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    ROUND(SUM(current_score::numeric * weight_pct) / NULLIF(SUM(weight_pct),0), 1),
    ROUND(SUM(target_score::numeric * weight_pct) / NULLIF(SUM(weight_pct),0), 1),
    ROUND((SUM(target_score::numeric * weight_pct) - SUM(current_score::numeric * weight_pct)) / NULLIF(SUM(weight_pct),0), 1),
    COUNT(*) FILTER (WHERE decision = 'blocker')::integer,
    COUNT(*) FILTER (WHERE decision = 'ship_now')::integer
  FROM fundraise_readiness_pillars_r2713;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_score_summary_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_score_summary_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_blockers_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_blockers_r2713()
RETURNS SETOF fundraise_readiness_pillars_r2713
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM fundraise_readiness_pillars_r2713 WHERE decision IN ('blocker','accelerate') ORDER BY weight_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_blockers_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_blockers_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_evidence_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_evidence_r2713()
RETURNS SETOF fundraise_readiness_evidence_r2713
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM fundraise_readiness_evidence_r2713 ORDER BY collected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_evidence_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_evidence_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_by_category_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_by_category_r2713()
RETURNS TABLE(category text, pillars integer, avg_current numeric, avg_target numeric, avg_gap numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.category,
    COUNT(*)::integer,
    ROUND(AVG(p.current_score)::numeric, 1),
    ROUND(AVG(p.target_score)::numeric, 1),
    ROUND(AVG(p.target_score - p.current_score)::numeric, 1)
  FROM fundraise_readiness_pillars_r2713 p
  GROUP BY p.category
  ORDER BY p.category;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_by_category_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_by_category_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_evidence_strength_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_evidence_strength_r2713()
RETURNS TABLE(strength text, evidence_count integer, verified_count integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.strength,
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE e.verified)::integer
  FROM fundraise_readiness_evidence_r2713 e
  GROUP BY e.strength
  ORDER BY CASE e.strength WHEN 'signature' THEN 1 WHEN 'strong' THEN 2 WHEN 'moderate' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_evidence_strength_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_evidence_strength_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_target_rounds_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_target_rounds_r2713()
RETURNS TABLE(target_round integer, pillar_code text, pillar_name text, decision text, gap_points integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.target_round, p.pillar_code, p.pillar_name, p.decision, (p.target_score - p.current_score)
  FROM fundraise_readiness_pillars_r2713 p
  ORDER BY p.target_round ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_target_rounds_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_target_rounds_r2713() TO authenticated;

DROP FUNCTION IF EXISTS get_fundraise_unverified_evidence_r2713();
CREATE OR REPLACE FUNCTION get_fundraise_unverified_evidence_r2713()
RETURNS SETOF fundraise_readiness_evidence_r2713
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM fundraise_readiness_evidence_r2713 WHERE verified = false ORDER BY collected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_fundraise_unverified_evidence_r2713() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_fundraise_unverified_evidence_r2713() TO authenticated;

COMMIT;
