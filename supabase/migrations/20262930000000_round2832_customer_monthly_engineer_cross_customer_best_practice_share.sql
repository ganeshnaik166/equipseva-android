BEGIN;

-- Round 2832: Customer Monthly Engineer Cross-Customer Best Practice Share
-- HEAVY founder console: engineer x insight x from customer x to customer x adoption x lift x verdict

CREATE TABLE IF NOT EXISTS cross_customer_practice_shares_r2832 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  insight_title text NOT NULL,
  insight_category text NOT NULL CHECK (insight_category IN ('uptime_routine','spare_kit','training_drill','workflow_tweak','sla_recovery')),
  from_customer text NOT NULL,
  to_customer text NOT NULL,
  adoption_status text NOT NULL CHECK (adoption_status IN ('adopted','piloting','rejected','queued')),
  lift_percent numeric(6,2) NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('replicate_fleetwide','keep_local','needs_more_data','kill')),
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cross_customer_practice_shares_r2832 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON cross_customer_practice_shares_r2832 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS cross_customer_practice_metrics_r2832 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  shares_attempted integer NOT NULL,
  shares_adopted integer NOT NULL,
  avg_lift_percent numeric(6,2) NOT NULL,
  fleetwide_replications integer NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cross_customer_practice_metrics_r2832 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON cross_customer_practice_metrics_r2832 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO cross_customer_practice_shares_r2832 (month_label, engineer_name, insight_title, insight_category, from_customer, to_customer, adoption_status, lift_percent, verdict, notes) VALUES
  ('2026-06','Ravi Kumar','Daily 5-min ventilator filter swab','uptime_routine','Apollo Jubilee','KIMS Secunderabad','adopted',18.40,'replicate_fleetwide','Reduced filter alarms 18% in 2 weeks'),
  ('2026-06','Sneha Reddy','Pre-stocked dental compressor belt kit','spare_kit','Clove Banjara','Sabka Dentist HYD','adopted',24.10,'replicate_fleetwide','Cut belt-change downtime from 4h to 45min'),
  ('2026-06','Arjun Nair','Sunday morning OT autoclave mock drill','training_drill','Yashoda Somajiguda','Continental Hospitals','piloting',9.80,'needs_more_data','Only 3 weeks of data so far'),
  ('2026-06','Pooja Sharma','Reverse-order PM checklist for X-ray','workflow_tweak','Care Banjara','Star Hospitals','rejected',-2.30,'kill','Nurses reported confusion, net negative'),
  ('2026-06','Vikram Joshi','SLA recovery: 2-engineer parallel triage','sla_recovery','AIG Hospitals','Rainbow Children','adopted',31.50,'replicate_fleetwide','SLA breach rate dropped from 12% to 3%'),
  ('2026-05','Ravi Kumar','Monsoon humidity ventilator gel sachet','uptime_routine','Apollo Jubilee','Yashoda Hitec','queued','12.00','needs_more_data','Awaiting monsoon onset to validate');

INSERT INTO cross_customer_practice_metrics_r2832 (month_label, engineer_name, shares_attempted, shares_adopted, avg_lift_percent, fleetwide_replications) VALUES
  ('2026-06','Ravi Kumar',4,3,15.20,2),
  ('2026-06','Sneha Reddy',3,3,22.40,2),
  ('2026-06','Arjun Nair',2,1,9.80,0),
  ('2026-06','Pooja Sharma',3,0,-1.10,0),
  ('2026-06','Vikram Joshi',5,4,28.30,3),
  ('2026-05','Ravi Kumar',3,2,14.60,1);

DROP FUNCTION IF EXISTS r2832_summary_kpis();
CREATE OR REPLACE FUNCTION r2832_summary_kpis()
RETURNS TABLE(total_shares bigint, adopted_shares bigint, fleetwide_count bigint, avg_lift numeric, top_engineer text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM cross_customer_practice_shares_r2832),
    (SELECT count(*) FROM cross_customer_practice_shares_r2832 WHERE adoption_status = 'adopted'),
    (SELECT count(*) FROM cross_customer_practice_shares_r2832 WHERE verdict = 'replicate_fleetwide'),
    (SELECT round(avg(lift_percent),2) FROM cross_customer_practice_shares_r2832 WHERE adoption_status = 'adopted'),
    (SELECT engineer_name FROM cross_customer_practice_metrics_r2832 ORDER BY fleetwide_replications DESC, avg_lift_percent DESC LIMIT 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_summary_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_summary_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2832_shares_list();
CREATE OR REPLACE FUNCTION r2832_shares_list()
RETURNS TABLE(month_label text, engineer_name text, insight_title text, insight_category text, from_customer text, to_customer text, adoption_status text, lift_percent numeric, verdict text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.month_label, s.engineer_name, s.insight_title, s.insight_category, s.from_customer, s.to_customer, s.adoption_status, s.lift_percent, s.verdict, s.notes
  FROM cross_customer_practice_shares_r2832 s
  ORDER BY s.recorded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_shares_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_shares_list() TO authenticated;

DROP FUNCTION IF EXISTS r2832_engineer_leaderboard();
CREATE OR REPLACE FUNCTION r2832_engineer_leaderboard()
RETURNS TABLE(engineer_name text, shares_attempted bigint, shares_adopted bigint, adoption_rate numeric, avg_lift numeric, fleetwide_replications bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.engineer_name,
    sum(m.shares_attempted)::bigint,
    sum(m.shares_adopted)::bigint,
    round(100.0 * sum(m.shares_adopted)::numeric / NULLIF(sum(m.shares_attempted),0), 2),
    round(avg(m.avg_lift_percent),2),
    sum(m.fleetwide_replications)::bigint
  FROM cross_customer_practice_metrics_r2832 m
  GROUP BY m.engineer_name
  ORDER BY sum(m.fleetwide_replications) DESC, sum(m.shares_adopted) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS r2832_category_breakdown();
CREATE OR REPLACE FUNCTION r2832_category_breakdown()
RETURNS TABLE(insight_category text, total bigint, adopted bigint, avg_lift numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.insight_category,
    count(*)::bigint,
    sum(CASE WHEN s.adoption_status = 'adopted' THEN 1 ELSE 0 END)::bigint,
    round(avg(s.lift_percent),2)
  FROM cross_customer_practice_shares_r2832 s
  GROUP BY s.insight_category
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_category_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2832_verdict_mix();
CREATE OR REPLACE FUNCTION r2832_verdict_mix()
RETURNS TABLE(verdict text, total bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM cross_customer_practice_shares_r2832;
  RETURN QUERY
  SELECT s.verdict, count(*)::bigint, round(100.0 * count(*)::numeric / NULLIF(v_total,0), 2)
  FROM cross_customer_practice_shares_r2832 s
  GROUP BY s.verdict
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_verdict_mix() TO authenticated;

DROP FUNCTION IF EXISTS r2832_top_lifts(integer);
CREATE OR REPLACE FUNCTION r2832_top_lifts(p_limit integer DEFAULT 5)
RETURNS TABLE(engineer_name text, insight_title text, from_customer text, to_customer text, lift_percent numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.insight_title, s.from_customer, s.to_customer, s.lift_percent, s.verdict
  FROM cross_customer_practice_shares_r2832 s
  WHERE s.adoption_status = 'adopted'
  ORDER BY s.lift_percent DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_top_lifts(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_top_lifts(integer) TO authenticated;

DROP FUNCTION IF EXISTS r2832_rejected_or_killed();
CREATE OR REPLACE FUNCTION r2832_rejected_or_killed()
RETURNS TABLE(engineer_name text, insight_title text, from_customer text, to_customer text, lift_percent numeric, verdict text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.insight_title, s.from_customer, s.to_customer, s.lift_percent, s.verdict, s.notes
  FROM cross_customer_practice_shares_r2832 s
  WHERE s.adoption_status = 'rejected' OR s.verdict = 'kill'
  ORDER BY s.lift_percent ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_rejected_or_killed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_rejected_or_killed() TO authenticated;

DROP FUNCTION IF EXISTS r2832_monthly_trend();
CREATE OR REPLACE FUNCTION r2832_monthly_trend()
RETURNS TABLE(month_label text, total_shares bigint, total_adopted bigint, avg_lift numeric, fleetwide bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.month_label,
    sum(m.shares_attempted)::bigint,
    sum(m.shares_adopted)::bigint,
    round(avg(m.avg_lift_percent),2),
    sum(m.fleetwide_replications)::bigint
  FROM cross_customer_practice_metrics_r2832 m
  GROUP BY m.month_label
  ORDER BY m.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2832_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2832_monthly_trend() TO authenticated;

COMMIT;
