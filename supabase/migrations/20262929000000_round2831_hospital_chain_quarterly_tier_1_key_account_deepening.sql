BEGIN;

-- =====================================================================
-- Round 2831: Hospital Chain Quarterly Tier-1 Key Account Deepening
-- =====================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_tier1_deepening_plays_r2831 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  tier1_sub_account text NOT NULL,
  quarter text NOT NULL,
  deepen_play text NOT NULL,
  exec_commit_amount_rupees bigint NOT NULL,
  outcome_status text NOT NULL CHECK (outcome_status IN ('committed','in_motion','landed','slipped','at_risk')),
  outcome_value_rupees bigint NOT NULL DEFAULT 0,
  renewal_probability_pct int NOT NULL CHECK (renewal_probability_pct BETWEEN 0 AND 100),
  account_owner text NOT NULL,
  next_review_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS hospital_chain_tier1_deepening_signals_r2831 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  tier1_sub_account text NOT NULL,
  signal_kind text NOT NULL CHECK (signal_kind IN ('expansion','satisfaction','churn_risk','price_pressure','exec_change')),
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','medium','strong')),
  detail text NOT NULL,
  observed_on date NOT NULL,
  action_taken text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tier1_deepening_plays_r2831 ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_chain_tier1_deepening_signals_r2831 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON hospital_chain_tier1_deepening_plays_r2831;
CREATE POLICY founder_all ON hospital_chain_tier1_deepening_plays_r2831
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON hospital_chain_tier1_deepening_signals_r2831;
CREATE POLICY founder_all ON hospital_chain_tier1_deepening_signals_r2831
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ----- Seeds: plays -----
INSERT INTO hospital_chain_tier1_deepening_plays_r2831
  (chain_name, tier1_sub_account, quarter, deepen_play, exec_commit_amount_rupees, outcome_status, outcome_value_rupees, renewal_probability_pct, account_owner, next_review_on)
VALUES
  ('Apollo Hospitals','Apollo Jubilee Hills HYD','2026-Q3','AMC tier upgrade plus ventilator pool',4800000,'committed',0,82,'Ganesh','2026-07-15'::date),
  ('Yashoda Group','Yashoda Somajiguda HYD','2026-Q3','Cath lab uptime SLA bundle',3600000,'in_motion',1200000,74,'Ganesh','2026-07-22'::date),
  ('Manipal Health','Manipal Vijayawada','2026-Q3','MRI preventive contract expansion',5200000,'landed',5200000,91,'Senior CSM','2026-08-05'::date),
  ('KIMS Group','KIMS Secunderabad','2026-Q3','Endoscopy fleet replacement plan',2900000,'at_risk',0,48,'Ganesh','2026-07-10'::date),
  ('Care Hospitals','Care Banjara Hills HYD','2026-Q3','Bio-medical staff augmentation',1800000,'slipped',0,55,'Senior CSM','2026-07-18'::date),
  ('Fortis Healthcare','Fortis Bengaluru','2026-Q3','Spare parts buffer stock SLA',2400000,'committed',0,68,'Ganesh','2026-07-25'::date);

-- ----- Seeds: signals -----
INSERT INTO hospital_chain_tier1_deepening_signals_r2831
  (chain_name, tier1_sub_account, signal_kind, signal_strength, detail, observed_on, action_taken)
VALUES
  ('Apollo Hospitals','Apollo Jubilee Hills HYD','expansion','strong','Discussed adding 12 new ICU pumps under AMC','2026-06-10'::date,'Sent proposal'),
  ('Yashoda Group','Yashoda Somajiguda HYD','satisfaction','medium','CSAT 4.2 on cath lab response time','2026-06-12'::date,'CSM follow-up scheduled'),
  ('KIMS Group','KIMS Secunderabad','churn_risk','strong','RFQ floated to two competitors','2026-06-15'::date,'Founder visit booked'),
  ('Care Hospitals','Care Banjara Hills HYD','price_pressure','medium','Asked for 8 percent discount on renewal','2026-06-08'::date,'Counter with bundled SLA'),
  ('Manipal Health','Manipal Vijayawada','exec_change','weak','New biomedical head joined','2026-06-05'::date,'Intro meeting completed'),
  ('Fortis Healthcare','Fortis Bengaluru','expansion','medium','Inquiry on radiology preventive add-on','2026-06-14'::date,'Quote in draft');

-- =====================================================================
-- RPCs
-- =====================================================================

DROP FUNCTION IF EXISTS rpc_r2831_play_summary();
CREATE FUNCTION rpc_r2831_play_summary()
RETURNS TABLE (
  total_plays bigint,
  total_commit_rupees bigint,
  total_landed_rupees bigint,
  avg_renewal_pct numeric,
  at_risk_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(exec_commit_amount_rupees),0)::bigint,
    coalesce(sum(outcome_value_rupees) FILTER (WHERE outcome_status='landed'),0)::bigint,
    coalesce(round(avg(renewal_probability_pct)::numeric,1),0),
    count(*) FILTER (WHERE outcome_status='at_risk')::bigint
  FROM hospital_chain_tier1_deepening_plays_r2831;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_play_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_play_summary() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_plays_by_chain();
CREATE FUNCTION rpc_r2831_plays_by_chain()
RETURNS TABLE (
  chain_name text,
  play_count bigint,
  commit_rupees bigint,
  landed_rupees bigint,
  avg_renewal_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    count(*)::bigint,
    coalesce(sum(p.exec_commit_amount_rupees),0)::bigint,
    coalesce(sum(p.outcome_value_rupees) FILTER (WHERE p.outcome_status='landed'),0)::bigint,
    coalesce(round(avg(p.renewal_probability_pct)::numeric,1),0)
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  GROUP BY p.chain_name
  ORDER BY commit_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_plays_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_plays_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_plays_by_outcome();
CREATE FUNCTION rpc_r2831_plays_by_outcome()
RETURNS TABLE (
  outcome_status text,
  cnt bigint,
  commit_rupees bigint,
  outcome_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.outcome_status,
    count(*)::bigint,
    coalesce(sum(p.exec_commit_amount_rupees),0)::bigint,
    coalesce(sum(p.outcome_value_rupees),0)::bigint
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  GROUP BY p.outcome_status
  ORDER BY commit_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_plays_by_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_plays_by_outcome() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_plays_full();
CREATE FUNCTION rpc_r2831_plays_full()
RETURNS TABLE (
  id uuid,
  chain_name text,
  tier1_sub_account text,
  quarter text,
  deepen_play text,
  exec_commit_amount_rupees bigint,
  outcome_status text,
  outcome_value_rupees bigint,
  renewal_probability_pct int,
  account_owner text,
  next_review_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.chain_name, p.tier1_sub_account, p.quarter, p.deepen_play,
         p.exec_commit_amount_rupees, p.outcome_status, p.outcome_value_rupees,
         p.renewal_probability_pct, p.account_owner, p.next_review_on
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  ORDER BY p.exec_commit_amount_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_plays_full() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_plays_full() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_signals_by_kind();
CREATE FUNCTION rpc_r2831_signals_by_kind()
RETURNS TABLE (
  signal_kind text,
  cnt bigint,
  strong_cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.signal_kind,
    count(*)::bigint,
    count(*) FILTER (WHERE s.signal_strength='strong')::bigint
  FROM hospital_chain_tier1_deepening_signals_r2831 s
  GROUP BY s.signal_kind
  ORDER BY cnt DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_signals_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_signals_by_kind() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_signals_full();
CREATE FUNCTION rpc_r2831_signals_full()
RETURNS TABLE (
  id uuid,
  chain_name text,
  tier1_sub_account text,
  signal_kind text,
  signal_strength text,
  detail text,
  observed_on date,
  action_taken text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.tier1_sub_account, s.signal_kind, s.signal_strength,
         s.detail, s.observed_on, s.action_taken
  FROM hospital_chain_tier1_deepening_signals_r2831 s
  ORDER BY s.observed_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_signals_full() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_signals_full() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_top_renewal_risks();
CREATE FUNCTION rpc_r2831_top_renewal_risks()
RETURNS TABLE (
  chain_name text,
  tier1_sub_account text,
  deepen_play text,
  outcome_status text,
  renewal_probability_pct int,
  account_owner text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.tier1_sub_account, p.deepen_play, p.outcome_status,
         p.renewal_probability_pct, p.account_owner
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  WHERE p.renewal_probability_pct <= 70
  ORDER BY p.renewal_probability_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_top_renewal_risks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_top_renewal_risks() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2831_upcoming_reviews();
CREATE FUNCTION rpc_r2831_upcoming_reviews()
RETURNS TABLE (
  chain_name text,
  tier1_sub_account text,
  next_review_on date,
  account_owner text,
  outcome_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.tier1_sub_account, p.next_review_on, p.account_owner, p.outcome_status
  FROM hospital_chain_tier1_deepening_plays_r2831 p
  ORDER BY p.next_review_on ASC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2831_upcoming_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2831_upcoming_reviews() TO authenticated;

COMMIT;
