BEGIN;

CREATE TABLE IF NOT EXISTS customer_engineer_transfer_log_r2796 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  customer_name text NOT NULL,
  engineer_name text NOT NULL,
  source_region text NOT NULL,
  target_region text NOT NULL,
  insight_category text NOT NULL CHECK (insight_category IN ('repair_pattern','spare_sourcing','client_handling','compliance_trick','tooling_hack')),
  insight_summary text NOT NULL,
  adoption_score numeric(5,2) NOT NULL CHECK (adoption_score BETWEEN 0 AND 100),
  cost_saving_rupees integer NOT NULL CHECK (cost_saving_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('scale','iterate','park','kill')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_engineer_transfer_log_r2796 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_engineer_transfer_log_r2796;
CREATE POLICY founder_all ON customer_engineer_transfer_log_r2796 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS customer_engineer_transfer_region_stats_r2796 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  region_name text NOT NULL,
  inbound_transfers integer NOT NULL CHECK (inbound_transfers >= 0),
  outbound_transfers integer NOT NULL CHECK (outbound_transfers >= 0),
  avg_adoption numeric(5,2) NOT NULL CHECK (avg_adoption BETWEEN 0 AND 100),
  total_savings_rupees integer NOT NULL CHECK (total_savings_rupees >= 0),
  net_verdict text NOT NULL CHECK (net_verdict IN ('expand','hold','contract')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_engineer_transfer_region_stats_r2796 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_engineer_transfer_region_stats_r2796;
CREATE POLICY founder_all ON customer_engineer_transfer_region_stats_r2796 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_engineer_transfer_log_r2796 (month_label, customer_name, engineer_name, source_region, target_region, insight_category, insight_summary, adoption_score, cost_saving_rupees, verdict) VALUES
  ('2026-06', 'Apollo Hyderabad', 'Ravi Kumar', 'South', 'West', 'repair_pattern', 'CT tube calibration shortcut saves 40 min', 88.50, 145000, 'scale'),
  ('2026-06', 'Fortis Mumbai', 'Anitha Reddy', 'South', 'North', 'spare_sourcing', 'Local Pune supplier matches OEM at 30% off', 76.20, 92000, 'scale'),
  ('2026-06', 'Manipal Bengaluru', 'Suresh Iyer', 'South', 'East', 'client_handling', 'Pre-visit WhatsApp brief cuts rework calls', 64.80, 38000, 'iterate'),
  ('2026-06', 'AIIMS Delhi', 'Pooja Sharma', 'North', 'South', 'compliance_trick', 'NABH doc bundle template auto-fill', 91.40, 210000, 'scale'),
  ('2026-06', 'KIMS Hyderabad', 'Vikram Singh', 'South', 'West', 'tooling_hack', 'Custom Allen-key set for Siemens MRIs', 52.10, 27000, 'iterate'),
  ('2026-06', 'Yashoda Hyderabad', 'Meera Patel', 'South', 'North', 'repair_pattern', 'Ultrasound probe re-seating SOP', 33.60, 12000, 'park');

INSERT INTO customer_engineer_transfer_region_stats_r2796 (month_label, region_name, inbound_transfers, outbound_transfers, avg_adoption, total_savings_rupees, net_verdict) VALUES
  ('2026-06', 'South', 1, 4, 71.30, 524000, 'expand'),
  ('2026-06', 'West', 2, 0, 70.30, 172000, 'expand'),
  ('2026-06', 'North', 2, 1, 83.80, 302000, 'expand'),
  ('2026-06', 'East', 1, 0, 64.80, 38000, 'hold'),
  ('2026-06', 'Central', 0, 0, 0.00, 0, 'contract');

DROP FUNCTION IF EXISTS founder_transfer_summary_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_summary_r2796()
RETURNS TABLE(total_transfers bigint, avg_adoption numeric, total_savings bigint, scale_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT count(*)::bigint, round(avg(adoption_score),2)::numeric, sum(cost_saving_rupees)::bigint,
    count(*) FILTER (WHERE verdict='scale')::bigint
  FROM customer_engineer_transfer_log_r2796;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_summary_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_summary_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_log_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_log_r2796()
RETURNS SETOF customer_engineer_transfer_log_r2796
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_engineer_transfer_log_r2796 ORDER BY adoption_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_log_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_log_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_region_stats_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_region_stats_r2796()
RETURNS SETOF customer_engineer_transfer_region_stats_r2796
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_engineer_transfer_region_stats_r2796 ORDER BY total_savings_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_region_stats_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_region_stats_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_by_category_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_by_category_r2796()
RETURNS TABLE(category text, cnt bigint, avg_adoption numeric, total_savings bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT insight_category, count(*)::bigint, round(avg(adoption_score),2)::numeric, sum(cost_saving_rupees)::bigint
  FROM customer_engineer_transfer_log_r2796 GROUP BY insight_category ORDER BY sum(cost_saving_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_by_category_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_by_category_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_top_engineers_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_top_engineers_r2796()
RETURNS TABLE(engineer_name text, transfers bigint, total_savings bigint, avg_adoption numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.engineer_name, count(*)::bigint, sum(l.cost_saving_rupees)::bigint, round(avg(l.adoption_score),2)::numeric
  FROM customer_engineer_transfer_log_r2796 l GROUP BY l.engineer_name ORDER BY sum(l.cost_saving_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_top_engineers_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_top_engineers_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_verdicts_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_verdicts_r2796()
RETURNS TABLE(verdict text, cnt bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM customer_engineer_transfer_log_r2796;
  RETURN QUERY SELECT l.verdict, count(*)::bigint, round(count(*)::numeric * 100 / NULLIF(total,0),2)
  FROM customer_engineer_transfer_log_r2796 l GROUP BY l.verdict ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_verdicts_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_verdicts_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_high_adoption_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_high_adoption_r2796()
RETURNS SETOF customer_engineer_transfer_log_r2796
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_engineer_transfer_log_r2796 WHERE adoption_score >= 70 ORDER BY adoption_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_high_adoption_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_high_adoption_r2796() TO authenticated;

DROP FUNCTION IF EXISTS founder_transfer_corridor_pairs_r2796();
CREATE OR REPLACE FUNCTION founder_transfer_corridor_pairs_r2796()
RETURNS TABLE(corridor text, transfers bigint, total_savings bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT (source_region || ' to ' || target_region)::text, count(*)::bigint, sum(cost_saving_rupees)::bigint
  FROM customer_engineer_transfer_log_r2796 GROUP BY source_region, target_region ORDER BY sum(cost_saving_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_transfer_corridor_pairs_r2796() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_transfer_corridor_pairs_r2796() TO authenticated;

COMMIT;