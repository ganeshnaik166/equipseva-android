BEGIN;

-- =========================================================================
-- Round 2872 — Customer Monthly Engineer Quote Acceptance Velocity
-- HEAVY ★★★★ founder console
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: engineer monthly quote velocity snapshot
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_quote_velocity_r2872 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  quotes_sent int NOT NULL CHECK (quotes_sent >= 0),
  quotes_accepted int NOT NULL CHECK (quotes_accepted >= 0),
  quotes_declined int NOT NULL CHECK (quotes_declined >= 0),
  quotes_expired int NOT NULL CHECK (quotes_expired >= 0),
  avg_time_to_accept_hours numeric(8,2) NOT NULL CHECK (avg_time_to_accept_hours >= 0),
  median_discount_pct numeric(5,2) NOT NULL CHECK (median_discount_pct >= 0),
  total_quote_value_rupees bigint NOT NULL CHECK (total_quote_value_rupees >= 0),
  total_accepted_value_rupees bigint NOT NULL CHECK (total_accepted_value_rupees >= 0),
  refine_iterations_avg numeric(5,2) NOT NULL CHECK (refine_iterations_avg >= 0),
  velocity_band text NOT NULL CHECK (velocity_band IN ('fast','medium','slow','stalled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_quote_velocity_r2872 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_quote_velocity_r2872;
CREATE POLICY founder_all ON engineer_quote_velocity_r2872
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_quote_velocity_r2872
  (month_start, engineer_name, engineer_tier, quotes_sent, quotes_accepted, quotes_declined, quotes_expired,
   avg_time_to_accept_hours, median_discount_pct, total_quote_value_rupees, total_accepted_value_rupees,
   refine_iterations_avg, velocity_band)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 'platinum', 42, 31, 5, 6, 11.50, 4.20, 1850000, 1380000, 1.30, 'fast'),
  ('2026-06-01'::date, 'Anjali Sharma', 'gold', 38, 24, 7, 7, 18.40, 6.10, 1420000, 920000, 1.80, 'medium'),
  ('2026-06-01'::date, 'Mohammed Iqbal', 'gold', 35, 22, 6, 7, 21.20, 5.50, 1310000, 840000, 2.10, 'medium'),
  ('2026-06-01'::date, 'Priya Reddy', 'silver', 29, 14, 8, 7, 33.80, 8.70, 980000, 470000, 2.80, 'slow'),
  ('2026-06-01'::date, 'Vikram Singh', 'bronze', 22, 6, 9, 7, 48.20, 11.30, 720000, 210000, 3.40, 'stalled'),
  ('2026-05-01'::date, 'Ravi Kumar', 'platinum', 39, 28, 6, 5, 12.10, 4.80, 1720000, 1240000, 1.40, 'fast'),
  ('2026-05-01'::date, 'Anjali Sharma', 'gold', 36, 20, 8, 8, 22.50, 6.90, 1350000, 760000, 2.00, 'medium');

-- -------------------------------------------------------------------------
-- Table 2: per-quote refine + acceptance event log
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quote_acceptance_events_r2872 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_ref text NOT NULL,
  engineer_name text NOT NULL,
  customer_name text NOT NULL,
  sent_at timestamptz NOT NULL,
  responded_at timestamptz,
  outcome text NOT NULL CHECK (outcome IN ('accepted','declined','expired','refining','pending')),
  initial_amount_rupees bigint NOT NULL CHECK (initial_amount_rupees >= 0),
  final_amount_rupees bigint NOT NULL CHECK (final_amount_rupees >= 0),
  discount_pct numeric(5,2) NOT NULL CHECK (discount_pct >= 0),
  refine_count int NOT NULL CHECK (refine_count >= 0),
  time_to_respond_hours numeric(8,2) NOT NULL CHECK (time_to_respond_hours >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quote_acceptance_events_r2872 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON quote_acceptance_events_r2872;
CREATE POLICY founder_all ON quote_acceptance_events_r2872
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO quote_acceptance_events_r2872
  (quote_ref, engineer_name, customer_name, sent_at, responded_at, outcome,
   initial_amount_rupees, final_amount_rupees, discount_pct, refine_count, time_to_respond_hours, notes)
VALUES
  ('QT-26060001', 'Ravi Kumar',     'Apollo Jubilee Hills',  '2026-06-02 09:15+05:30', '2026-06-02 14:40+05:30', 'accepted',  85000, 81600, 4.00, 1, 5.42,  'Sterilizer service quote, single refine'),
  ('QT-26060002', 'Anjali Sharma',  'KIMS Secunderabad',     '2026-06-03 11:00+05:30', '2026-06-04 08:20+05:30', 'accepted', 142000, 132060, 7.00, 2, 21.33, 'Ventilator AMC refined twice'),
  ('QT-26060003', 'Mohammed Iqbal', 'Yashoda Somajiguda',    '2026-06-04 16:25+05:30', '2026-06-05 12:10+05:30', 'accepted',  62000,  58280, 6.00, 1, 19.75, 'Ultrasound repair'),
  ('QT-26060004', 'Priya Reddy',    'Care Banjara Hills',    '2026-06-05 10:30+05:30', '2026-06-07 09:50+05:30', 'declined',  98000,  88200, 10.00, 3, 47.33, 'Hospital chose competitor'),
  ('QT-26060005', 'Vikram Singh',   'Sunshine Paradise',     '2026-06-06 14:00+05:30', NULL,                     'expired',   45000,  45000, 0.00, 0, 72.00, 'Auto-expired after 72h SLA'),
  ('QT-26060006', 'Ravi Kumar',     'Continental Gachibowli','2026-06-08 09:00+05:30', '2026-06-08 11:45+05:30', 'accepted', 110000, 105600, 4.00, 1, 2.75,  'Fast turnaround, low discount'),
  ('QT-26060007', 'Anjali Sharma',  'Asian Institute',       '2026-06-09 13:30+05:30', NULL,                     'refining',  72000,  68040, 5.50, 2, 18.00, 'Customer requested third refine');

-- -------------------------------------------------------------------------
-- RPC 1: KPI summary for current month
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_quote_velocity_kpis();
CREATE OR REPLACE FUNCTION founder_r2872_quote_velocity_kpis()
RETURNS TABLE (
  total_quotes_sent bigint,
  total_quotes_accepted bigint,
  acceptance_rate_pct numeric,
  avg_time_to_accept_hours numeric,
  avg_discount_pct numeric,
  total_accepted_value_rupees bigint,
  avg_refine_iterations numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(quotes_sent),0)::bigint,
    COALESCE(SUM(quotes_accepted),0)::bigint,
    CASE WHEN COALESCE(SUM(quotes_sent),0) = 0 THEN 0
         ELSE ROUND((SUM(quotes_accepted)::numeric / SUM(quotes_sent)::numeric) * 100, 2) END,
    ROUND(AVG(avg_time_to_accept_hours), 2),
    ROUND(AVG(median_discount_pct), 2),
    COALESCE(SUM(total_accepted_value_rupees),0)::bigint,
    ROUND(AVG(refine_iterations_avg), 2)
  FROM engineer_quote_velocity_r2872
  WHERE month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_quote_velocity_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_quote_velocity_kpis() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 2: Engineer leaderboard for latest month
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2872_engineer_leaderboard()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  quotes_sent int,
  quotes_accepted int,
  acceptance_rate_pct numeric,
  avg_time_to_accept_hours numeric,
  total_accepted_value_rupees bigint,
  velocity_band text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.engineer_name, v.engineer_tier, v.quotes_sent, v.quotes_accepted,
    CASE WHEN v.quotes_sent = 0 THEN 0
         ELSE ROUND((v.quotes_accepted::numeric / v.quotes_sent::numeric) * 100, 2) END,
    v.avg_time_to_accept_hours, v.total_accepted_value_rupees, v.velocity_band
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
  ORDER BY v.quotes_accepted DESC, v.avg_time_to_accept_hours ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_engineer_leaderboard() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 3: Velocity band distribution
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_velocity_band_distribution();
CREATE OR REPLACE FUNCTION founder_r2872_velocity_band_distribution()
RETURNS TABLE (
  velocity_band text,
  engineer_count bigint,
  total_quotes_accepted bigint,
  share_of_accepted_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_accepted bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(quotes_accepted),0) INTO total_accepted
  FROM engineer_quote_velocity_r2872
  WHERE month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872);

  RETURN QUERY
  SELECT
    v.velocity_band,
    COUNT(*)::bigint,
    COALESCE(SUM(v.quotes_accepted),0)::bigint,
    CASE WHEN total_accepted = 0 THEN 0
         ELSE ROUND((SUM(v.quotes_accepted)::numeric / total_accepted::numeric) * 100, 2) END
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
  GROUP BY v.velocity_band
  ORDER BY total_quotes_accepted DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_velocity_band_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_velocity_band_distribution() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 4: Recent quote events
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_recent_quote_events();
CREATE OR REPLACE FUNCTION founder_r2872_recent_quote_events()
RETURNS TABLE (
  quote_ref text,
  engineer_name text,
  customer_name text,
  outcome text,
  initial_amount_rupees bigint,
  final_amount_rupees bigint,
  discount_pct numeric,
  refine_count int,
  time_to_respond_hours numeric,
  sent_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.quote_ref, e.engineer_name, e.customer_name, e.outcome,
    e.initial_amount_rupees, e.final_amount_rupees, e.discount_pct,
    e.refine_count, e.time_to_respond_hours, e.sent_at
  FROM quote_acceptance_events_r2872 e
  ORDER BY e.sent_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_recent_quote_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_recent_quote_events() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 5: Refine iteration impact analysis
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_refine_impact();
CREATE OR REPLACE FUNCTION founder_r2872_refine_impact()
RETURNS TABLE (
  refine_count int,
  quote_count bigint,
  accepted_count bigint,
  acceptance_rate_pct numeric,
  avg_discount_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.refine_count,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE e.outcome = 'accepted')::bigint,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND((COUNT(*) FILTER (WHERE e.outcome = 'accepted')::numeric / COUNT(*)::numeric) * 100, 2) END,
    ROUND(AVG(e.discount_pct), 2)
  FROM quote_acceptance_events_r2872 e
  GROUP BY e.refine_count
  ORDER BY e.refine_count ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_refine_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_refine_impact() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 6: Month-over-month trend
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_mom_trend();
CREATE OR REPLACE FUNCTION founder_r2872_mom_trend()
RETURNS TABLE (
  month_start date,
  total_sent bigint,
  total_accepted bigint,
  acceptance_rate_pct numeric,
  avg_time_to_accept_hours numeric,
  total_accepted_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.month_start,
    COALESCE(SUM(v.quotes_sent),0)::bigint,
    COALESCE(SUM(v.quotes_accepted),0)::bigint,
    CASE WHEN COALESCE(SUM(v.quotes_sent),0) = 0 THEN 0
         ELSE ROUND((SUM(v.quotes_accepted)::numeric / SUM(v.quotes_sent)::numeric) * 100, 2) END,
    ROUND(AVG(v.avg_time_to_accept_hours), 2),
    COALESCE(SUM(v.total_accepted_value_rupees),0)::bigint
  FROM engineer_quote_velocity_r2872 v
  GROUP BY v.month_start
  ORDER BY v.month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_mom_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_mom_trend() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 7: Tier-level rollup
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_tier_rollup();
CREATE OR REPLACE FUNCTION founder_r2872_tier_rollup()
RETURNS TABLE (
  engineer_tier text,
  engineer_count bigint,
  total_sent bigint,
  total_accepted bigint,
  acceptance_rate_pct numeric,
  avg_discount_pct numeric,
  total_accepted_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.engineer_tier,
    COUNT(*)::bigint,
    COALESCE(SUM(v.quotes_sent),0)::bigint,
    COALESCE(SUM(v.quotes_accepted),0)::bigint,
    CASE WHEN COALESCE(SUM(v.quotes_sent),0) = 0 THEN 0
         ELSE ROUND((SUM(v.quotes_accepted)::numeric / SUM(v.quotes_sent)::numeric) * 100, 2) END,
    ROUND(AVG(v.median_discount_pct), 2),
    COALESCE(SUM(v.total_accepted_value_rupees),0)::bigint
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
  GROUP BY v.engineer_tier
  ORDER BY total_accepted DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_tier_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_tier_rollup() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 8: Stalled engineers needing intervention
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2872_stalled_engineers();
CREATE OR REPLACE FUNCTION founder_r2872_stalled_engineers()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  quotes_sent int,
  quotes_accepted int,
  avg_time_to_accept_hours numeric,
  median_discount_pct numeric,
  refine_iterations_avg numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.engineer_name, v.engineer_tier, v.quotes_sent, v.quotes_accepted,
    v.avg_time_to_accept_hours, v.median_discount_pct, v.refine_iterations_avg
  FROM engineer_quote_velocity_r2872 v
  WHERE v.month_start = (SELECT MAX(month_start) FROM engineer_quote_velocity_r2872)
    AND v.velocity_band IN ('slow','stalled')
  ORDER BY v.velocity_band DESC, v.avg_time_to_accept_hours DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2872_stalled_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2872_stalled_engineers() TO authenticated;

COMMIT;
