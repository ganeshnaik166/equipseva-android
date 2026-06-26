BEGIN;

-- ============================================================================
-- Round 2884 — Customer Monthly Engineer-Job Customer-Tea Acceptance
-- HEAVY ★★★★ founder console
-- Tracks: engineer × tea offered × accepted × dwell × bond × outcome × verdict
-- ============================================================================

-- ---------- Table 1: tea_offers_r2884 ---------------------------------------
CREATE TABLE IF NOT EXISTS tea_offers_r2884 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_month     date NOT NULL,
  engineer_name   text NOT NULL,
  customer_name   text NOT NULL,
  job_code        text NOT NULL,
  city            text NOT NULL,
  tea_offered     boolean NOT NULL DEFAULT false,
  tea_accepted    boolean NOT NULL DEFAULT false,
  dwell_minutes   integer NOT NULL CHECK (dwell_minutes >= 0),
  bond_score      integer NOT NULL CHECK (bond_score BETWEEN 0 AND 100),
  outcome         text NOT NULL CHECK (outcome IN ('renewed','upsold','neutral','churned','flagged')),
  verdict         text NOT NULL CHECK (verdict IN ('warm_bond','transactional','cold','escalate','exemplar')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tea_offers_r2884 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON tea_offers_r2884;
CREATE POLICY founder_all ON tea_offers_r2884
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO tea_offers_r2884
  (offer_month, engineer_name, customer_name, job_code, city, tea_offered, tea_accepted, dwell_minutes, bond_score, outcome, verdict, notes)
VALUES
  ('2026-06-01'::date,'Ravi Kumar','Apollo Hyderabad','JOB-7701','Hyderabad',true,true,38,92,'renewed','warm_bond','customer asked for Ravi again next AMC visit'),
  ('2026-06-01'::date,'Suresh Babu','Yashoda Secunderabad','JOB-7702','Hyderabad',true,false,12,54,'neutral','transactional','tea declined, polite'),
  ('2026-06-01'::date,'Vikram Reddy','KIMS Kondapur','JOB-7703','Hyderabad',false,false,9,38,'churned','cold','rushed exit, no rapport'),
  ('2026-06-01'::date,'Anil Naidu','Care Banjara','JOB-7704','Hyderabad',true,true,45,96,'upsold','exemplar','sold spare AMC add-on over chai'),
  ('2026-06-01'::date,'Mohan Rao','Continental Gachibowli','JOB-7705','Hyderabad',true,true,28,71,'renewed','warm_bond','steady regular'),
  ('2026-06-01'::date,'Kiran Goud','Rainbow Hyderguda','JOB-7706','Hyderabad',true,false,8,22,'flagged','escalate','customer complained engineer hostile'),
  ('2026-06-01'::date,'Pradeep Sharma','Sunshine Begumpet','JOB-7707','Hyderabad',true,true,32,84,'renewed','warm_bond','tea ritual every visit');

-- ---------- Table 2: tea_acceptance_audits_r2884 ----------------------------
CREATE TABLE IF NOT EXISTS tea_acceptance_audits_r2884 (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_month       date NOT NULL,
  engineer_name     text NOT NULL,
  offers_count      integer NOT NULL CHECK (offers_count >= 0),
  accepted_count    integer NOT NULL CHECK (accepted_count >= 0),
  acceptance_rate   numeric(5,2) NOT NULL CHECK (acceptance_rate BETWEEN 0 AND 100),
  avg_dwell_minutes numeric(6,2) NOT NULL CHECK (avg_dwell_minutes >= 0),
  avg_bond_score    numeric(5,2) NOT NULL CHECK (avg_bond_score BETWEEN 0 AND 100),
  band              text NOT NULL CHECK (band IN ('gold','silver','bronze','watch','red')),
  founder_note      text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tea_acceptance_audits_r2884 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON tea_acceptance_audits_r2884;
CREATE POLICY founder_all ON tea_acceptance_audits_r2884
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO tea_acceptance_audits_r2884
  (audit_month, engineer_name, offers_count, accepted_count, acceptance_rate, avg_dwell_minutes, avg_bond_score, band, founder_note)
VALUES
  ('2026-06-01'::date,'Anil Naidu',12,11,91.67,42.50,94.20,'gold','rockstar — pair junior eng with him'),
  ('2026-06-01'::date,'Ravi Kumar',10,8,80.00,36.40,89.10,'gold','reliable warm-bond performer'),
  ('2026-06-01'::date,'Pradeep Sharma',9,7,77.78,30.20,82.40,'silver','solid; coach upsell'),
  ('2026-06-01'::date,'Mohan Rao',8,5,62.50,27.10,72.30,'silver','consistent'),
  ('2026-06-01'::date,'Suresh Babu',11,4,36.36,14.80,55.10,'bronze','too quick — slow down'),
  ('2026-06-01'::date,'Vikram Reddy',9,2,22.22,10.50,40.20,'watch','call him this week'),
  ('2026-06-01'::date,'Kiran Goud',7,1,14.29,9.10,28.40,'red','suspend; investigate complaint');

-- ============================================================================
-- RPCs (7) — all gated by is_founder()
-- ============================================================================

-- RPC 1: kpi summary
DROP FUNCTION IF EXISTS founder_r2884_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2884_kpi_summary()
RETURNS TABLE (
  total_offers integer,
  total_accepted integer,
  acceptance_rate numeric,
  avg_dwell numeric,
  avg_bond numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE tea_accepted)::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE tea_accepted) / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(dwell_minutes)::numeric, 2),
    ROUND(AVG(bond_score)::numeric, 2)
  FROM tea_offers_r2884;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_kpi_summary() TO authenticated;

-- RPC 2: by engineer
DROP FUNCTION IF EXISTS founder_r2884_by_engineer();
CREATE OR REPLACE FUNCTION founder_r2884_by_engineer()
RETURNS TABLE (
  engineer_name text,
  offers integer,
  accepted integer,
  acceptance_rate numeric,
  avg_dwell numeric,
  avg_bond numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.engineer_name,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE t.tea_accepted)::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE t.tea_accepted) / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(t.dwell_minutes)::numeric, 2),
    ROUND(AVG(t.bond_score)::numeric, 2)
  FROM tea_offers_r2884 t
  GROUP BY t.engineer_name
  ORDER BY ROUND(AVG(t.bond_score)::numeric, 2) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_by_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_by_engineer() TO authenticated;

-- RPC 3: by verdict
DROP FUNCTION IF EXISTS founder_r2884_by_verdict();
CREATE OR REPLACE FUNCTION founder_r2884_by_verdict()
RETURNS TABLE (
  verdict text,
  visits integer,
  avg_bond numeric,
  avg_dwell numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.verdict,
    COUNT(*)::int,
    ROUND(AVG(t.bond_score)::numeric, 2),
    ROUND(AVG(t.dwell_minutes)::numeric, 2)
  FROM tea_offers_r2884 t
  GROUP BY t.verdict
  ORDER BY ROUND(AVG(t.bond_score)::numeric, 2) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_by_verdict() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_by_verdict() TO authenticated;

-- RPC 4: by outcome
DROP FUNCTION IF EXISTS founder_r2884_by_outcome();
CREATE OR REPLACE FUNCTION founder_r2884_by_outcome()
RETURNS TABLE (
  outcome text,
  visits integer,
  acceptance_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.outcome,
    COUNT(*)::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE t.tea_accepted) / NULLIF(COUNT(*),0), 2)
  FROM tea_offers_r2884 t
  GROUP BY t.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_by_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_by_outcome() TO authenticated;

-- RPC 5: audit bands
DROP FUNCTION IF EXISTS founder_r2884_audit_bands();
CREATE OR REPLACE FUNCTION founder_r2884_audit_bands()
RETURNS TABLE (
  band text,
  engineers integer,
  avg_acceptance numeric,
  avg_bond numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.band,
    COUNT(*)::int,
    ROUND(AVG(a.acceptance_rate)::numeric, 2),
    ROUND(AVG(a.avg_bond_score)::numeric, 2)
  FROM tea_acceptance_audits_r2884 a
  GROUP BY a.band
  ORDER BY ROUND(AVG(a.avg_bond_score)::numeric, 2) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_audit_bands() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_audit_bands() TO authenticated;

-- RPC 6: red & watch list
DROP FUNCTION IF EXISTS founder_r2884_red_watch();
CREATE OR REPLACE FUNCTION founder_r2884_red_watch()
RETURNS TABLE (
  engineer_name text,
  band text,
  acceptance_rate numeric,
  avg_bond_score numeric,
  founder_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_name,
    a.band,
    a.acceptance_rate,
    a.avg_bond_score,
    a.founder_note
  FROM tea_acceptance_audits_r2884 a
  WHERE a.band IN ('watch','red')
  ORDER BY a.acceptance_rate ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_red_watch() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_red_watch() TO authenticated;

-- RPC 7: recent offers feed
DROP FUNCTION IF EXISTS founder_r2884_recent_offers();
CREATE OR REPLACE FUNCTION founder_r2884_recent_offers()
RETURNS TABLE (
  offer_month date,
  engineer_name text,
  customer_name text,
  job_code text,
  tea_offered boolean,
  tea_accepted boolean,
  dwell_minutes integer,
  bond_score integer,
  outcome text,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.offer_month, t.engineer_name, t.customer_name, t.job_code,
    t.tea_offered, t.tea_accepted, t.dwell_minutes, t.bond_score,
    t.outcome, t.verdict
  FROM tea_offers_r2884 t
  ORDER BY t.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_recent_offers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_recent_offers() TO authenticated;

-- RPC 8: exemplar leaderboard
DROP FUNCTION IF EXISTS founder_r2884_exemplar_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2884_exemplar_leaderboard()
RETURNS TABLE (
  engineer_name text,
  exemplar_visits integer,
  warm_bond_visits integer,
  total_visits integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.engineer_name,
    COUNT(*) FILTER (WHERE t.verdict = 'exemplar')::int,
    COUNT(*) FILTER (WHERE t.verdict = 'warm_bond')::int,
    COUNT(*)::int
  FROM tea_offers_r2884 t
  GROUP BY t.engineer_name
  ORDER BY COUNT(*) FILTER (WHERE t.verdict = 'exemplar') DESC,
           COUNT(*) FILTER (WHERE t.verdict = 'warm_bond') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2884_exemplar_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2884_exemplar_leaderboard() TO authenticated;

COMMIT;
