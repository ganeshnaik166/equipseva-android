BEGIN;

-- Grant ledger
DROP TABLE IF EXISTS equity_grants_r2741 CASCADE;
CREATE TABLE equity_grants_r2741 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grantee_name text NOT NULL,
  grantee_role text NOT NULL CHECK (grantee_role IN ('founder','engineer','exec','advisor','operator','board')),
  tier text NOT NULL CHECK (tier IN ('platinum','gold','silver','bronze')),
  grant_quarter text NOT NULL CHECK (grant_quarter IN ('Q1_2026','Q2_2026','Q3_2026','Q4_2026')),
  shares_granted integer NOT NULL CHECK (shares_granted >= 0),
  strike_price_rupees numeric(12,2) NOT NULL CHECK (strike_price_rupees >= 0),
  vesting_months integer NOT NULL CHECK (vesting_months >= 12),
  cliff_months integer NOT NULL CHECK (cliff_months >= 0),
  milestone_tag text NOT NULL,
  strategic_value_rupees numeric(14,2) NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equity_grants_r2741 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON equity_grants_r2741 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO equity_grants_r2741 (grantee_name, grantee_role, tier, grant_quarter, shares_granted, strike_price_rupees, vesting_months, cliff_months, milestone_tag, strategic_value_rupees) VALUES
('Priya Sharma','engineer','platinum','Q2_2026',12000,10.00,48,12,'500-job-milestone',1800000.00),
('Rahul Verma','exec','gold','Q2_2026',8000,15.00,48,12,'series-a-close',1200000.00),
('Anita Desai','advisor','silver','Q2_2026',4000,20.00,36,6,'hospital-pilot-launch',600000.00),
('Vikram Singh','engineer','gold','Q2_2026',6000,12.00,48,12,'amc-tier-platinum',900000.00),
('Sunita Rao','operator','bronze','Q2_2026',2000,8.00,36,12,'ops-90day-anniversary',300000.00),
('Karthik Reddy','board','platinum','Q2_2026',15000,5.00,48,0,'board-seat-acceptance',2250000.00);

-- Vesting schedule
DROP TABLE IF EXISTS vesting_events_r2741 CASCADE;
CREATE TABLE vesting_events_r2741 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grant_id uuid NOT NULL REFERENCES equity_grants_r2741(id) ON DELETE CASCADE,
  vesting_date date NOT NULL,
  shares_vested integer NOT NULL CHECK (shares_vested >= 0),
  event_type text NOT NULL CHECK (event_type IN ('cliff','monthly','accelerated','milestone')),
  value_at_vesting_rupees numeric(14,2) NOT NULL,
  status text NOT NULL CHECK (status IN ('scheduled','vested','exercised','forfeited')),
  notes text
);

ALTER TABLE vesting_events_r2741 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON vesting_events_r2741 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO vesting_events_r2741 (grant_id, vesting_date, shares_vested, event_type, value_at_vesting_rupees, status, notes)
SELECT id, '2027-06-25'::date, 3000, 'cliff', 450000.00, 'scheduled', 'Year-1 cliff vest' FROM equity_grants_r2741 WHERE grantee_name='Priya Sharma'
UNION ALL
SELECT id, '2027-06-25'::date, 2000, 'cliff', 300000.00, 'scheduled', 'Year-1 cliff vest' FROM equity_grants_r2741 WHERE grantee_name='Rahul Verma'
UNION ALL
SELECT id, '2026-12-25'::date, 1000, 'cliff', 150000.00, 'scheduled', '6-month cliff advisor' FROM equity_grants_r2741 WHERE grantee_name='Anita Desai'
UNION ALL
SELECT id, '2027-06-25'::date, 1500, 'cliff', 225000.00, 'scheduled', 'Year-1 cliff vest' FROM equity_grants_r2741 WHERE grantee_name='Vikram Singh'
UNION ALL
SELECT id, '2027-06-25'::date, 500, 'cliff', 75000.00, 'scheduled', 'Year-1 cliff vest' FROM equity_grants_r2741 WHERE grantee_name='Sunita Rao'
UNION ALL
SELECT id, '2026-07-25'::date, 3000, 'milestone', 450000.00, 'vested', 'Board acceptance trigger' FROM equity_grants_r2741 WHERE grantee_name='Karthik Reddy';

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_equity_grant_kpis_r2741();
CREATE FUNCTION founder_equity_grant_kpis_r2741()
RETURNS TABLE(total_grants bigint, total_shares bigint, total_strategic_value numeric, avg_vesting_months numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT COUNT(*)::bigint, COALESCE(SUM(shares_granted),0)::bigint,
    COALESCE(SUM(strategic_value_rupees),0)::numeric, COALESCE(AVG(vesting_months),0)::numeric
  FROM equity_grants_r2741;
END $$;
REVOKE EXECUTE ON FUNCTION founder_equity_grant_kpis_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_equity_grant_kpis_r2741() TO authenticated;

-- RPC 2: by role
DROP FUNCTION IF EXISTS founder_equity_grants_by_role_r2741();
CREATE FUNCTION founder_equity_grants_by_role_r2741()
RETURNS TABLE(grantee_role text, grant_count bigint, total_shares bigint, total_value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.grantee_role, COUNT(*)::bigint, SUM(g.shares_granted)::bigint, SUM(g.strategic_value_rupees)::numeric
  FROM equity_grants_r2741 g GROUP BY g.grantee_role ORDER BY SUM(g.shares_granted) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_equity_grants_by_role_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_equity_grants_by_role_r2741() TO authenticated;

-- RPC 3: by tier
DROP FUNCTION IF EXISTS founder_equity_grants_by_tier_r2741();
CREATE FUNCTION founder_equity_grants_by_tier_r2741()
RETURNS TABLE(tier text, grant_count bigint, total_shares bigint, avg_strike numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.tier, COUNT(*)::bigint, SUM(g.shares_granted)::bigint, AVG(g.strike_price_rupees)::numeric
  FROM equity_grants_r2741 g GROUP BY g.tier ORDER BY g.tier;
END $$;
REVOKE EXECUTE ON FUNCTION founder_equity_grants_by_tier_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_equity_grants_by_tier_r2741() TO authenticated;

-- RPC 4: list grants
DROP FUNCTION IF EXISTS founder_equity_grants_list_r2741();
CREATE FUNCTION founder_equity_grants_list_r2741()
RETURNS TABLE(id uuid, grantee_name text, grantee_role text, tier text, grant_quarter text, shares_granted integer, strike_price_rupees numeric, vesting_months integer, cliff_months integer, milestone_tag text, strategic_value_rupees numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.id, g.grantee_name, g.grantee_role, g.tier, g.grant_quarter, g.shares_granted,
    g.strike_price_rupees, g.vesting_months, g.cliff_months, g.milestone_tag, g.strategic_value_rupees
  FROM equity_grants_r2741 g ORDER BY g.strategic_value_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_equity_grants_list_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_equity_grants_list_r2741() TO authenticated;

-- RPC 5: vesting schedule
DROP FUNCTION IF EXISTS founder_vesting_schedule_r2741();
CREATE FUNCTION founder_vesting_schedule_r2741()
RETURNS TABLE(grantee_name text, vesting_date date, shares_vested integer, event_type text, value_at_vesting_rupees numeric, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.grantee_name, v.vesting_date, v.shares_vested, v.event_type, v.value_at_vesting_rupees, v.status
  FROM vesting_events_r2741 v JOIN equity_grants_r2741 g ON g.id = v.grant_id ORDER BY v.vesting_date;
END $$;
REVOKE EXECUTE ON FUNCTION founder_vesting_schedule_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vesting_schedule_r2741() TO authenticated;

-- RPC 6: milestone breakdown
DROP FUNCTION IF EXISTS founder_grants_by_milestone_r2741();
CREATE FUNCTION founder_grants_by_milestone_r2741()
RETURNS TABLE(milestone_tag text, grant_count bigint, total_shares bigint, total_value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.milestone_tag, COUNT(*)::bigint, SUM(g.shares_granted)::bigint, SUM(g.strategic_value_rupees)::numeric
  FROM equity_grants_r2741 g GROUP BY g.milestone_tag ORDER BY SUM(g.strategic_value_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_grants_by_milestone_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_grants_by_milestone_r2741() TO authenticated;

-- RPC 7: vesting status summary
DROP FUNCTION IF EXISTS founder_vesting_status_summary_r2741();
CREATE FUNCTION founder_vesting_status_summary_r2741()
RETURNS TABLE(status text, event_count bigint, total_shares bigint, total_value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT v.status, COUNT(*)::bigint, SUM(v.shares_vested)::bigint, SUM(v.value_at_vesting_rupees)::numeric
  FROM vesting_events_r2741 v GROUP BY v.status ORDER BY v.status;
END $$;
REVOKE EXECUTE ON FUNCTION founder_vesting_status_summary_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vesting_status_summary_r2741() TO authenticated;

-- RPC 8: top strategic grants
DROP FUNCTION IF EXISTS founder_top_strategic_grants_r2741();
CREATE FUNCTION founder_top_strategic_grants_r2741()
RETURNS TABLE(grantee_name text, grantee_role text, tier text, strategic_value_rupees numeric, milestone_tag text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT g.grantee_name, g.grantee_role, g.tier, g.strategic_value_rupees, g.milestone_tag
  FROM equity_grants_r2741 g ORDER BY g.strategic_value_rupees DESC LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_top_strategic_grants_r2741() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_top_strategic_grants_r2741() TO authenticated;

COMMIT;
