BEGIN;

-- =====================================================================
-- Round 2760 — Customer Monthly Engineer Arrival × Customer Rating
-- Founder-only console: job × engineer × arrival rating × verbatim ×
-- pattern × incentive action
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: per-arrival rating record (one row per visit)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_monthly_arrival_ratings_r2760 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  arrival_date date NOT NULL,
  job_code text NOT NULL,
  customer_org text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  arrival_punctuality_minutes int NOT NULL,
  arrival_rating numeric(3,2) NOT NULL CHECK (arrival_rating BETWEEN 0 AND 5),
  service_rating numeric(3,2) NOT NULL CHECK (service_rating BETWEEN 0 AND 5),
  overall_rating numeric(3,2) NOT NULL CHECK (overall_rating BETWEEN 0 AND 5),
  verbatim_quote text NOT NULL,
  sentiment text NOT NULL CHECK (sentiment IN ('promoter','passive','detractor')),
  pattern_tag text NOT NULL,
  incentive_action text NOT NULL CHECK (incentive_action IN ('bonus','coach','warn','flag','none')),
  incentive_amount_rupees int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_arrival_ratings_r2760 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_monthly_arrival_ratings_r2760;
CREATE POLICY founder_all ON customer_monthly_arrival_ratings_r2760
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_arrival_ratings_r2760
  (month_label, arrival_date, job_code, customer_org, engineer_name, engineer_tier,
   arrival_punctuality_minutes, arrival_rating, service_rating, overall_rating,
   verbatim_quote, sentiment, pattern_tag, incentive_action, incentive_amount_rupees)
VALUES
  ('2026-06','2026-06-03'::date,'JOB-7841','Apollo Cradle Jubilee','Ramesh Kumar','gold',
    -8, 5.00, 4.80, 4.90,
    'Engineer reached 8 minutes early and finished autoclave PM ahead of OT slot.',
    'promoter','early-arrival-OT-saver','bonus', 1500),
  ('2026-06','2026-06-05'::date,'JOB-7855','KIMS Secunderabad','Priya Sharma','platinum',
    -2, 4.80, 5.00, 4.90,
    'Calibration done before first case. Biomed signed off without a single rework.',
    'promoter','platinum-first-time-right','bonus', 2000),
  ('2026-06','2026-06-07'::date,'JOB-7862','Yashoda Somajiguda','Anil Reddy','silver',
    22, 3.20, 3.80, 3.50,
    'Came 22 minutes late, parking excuse. Service was okay but disrupted ICU round.',
    'passive','late-parking-excuse','coach', 0),
  ('2026-06','2026-06-09'::date,'JOB-7870','Rainbow Banjara Hills','Sunita Rao','gold',
    -4, 4.60, 4.40, 4.50,
    'Arrived 4 min early, fixed monitor BP module fast. Nurse station happy.',
    'promoter','fast-icu-monitor-fix','bonus', 800),
  ('2026-06','2026-06-12'::date,'JOB-7888','Continental Gachibowli','Mahesh Goud','bronze',
    47, 2.10, 2.40, 2.20,
    'Engineer 47 minutes late, told nurse traffic. Diagnostic incomplete, second visit needed.',
    'detractor','severe-late-rework','warn', 0),
  ('2026-06','2026-06-15'::date,'JOB-7901','Care Hospital Banjara','Lakshmi Devi','platinum',
    0, 5.00, 4.90, 4.95,
    'On the dot 9:00am. Defibrillator PM perfect, cath lab head wants her back monthly.',
    'promoter','on-the-dot-cath-lab','bonus', 2500),
  ('2026-06','2026-06-18'::date,'JOB-7920','MaxCure Madhapur','Vikram Singh','silver',
    35, 2.80, 3.10, 2.90,
    'Late again. Same engineer, third complaint this month from Madhapur node.',
    'detractor','repeat-late-same-node','flag', 0),
  ('2026-06','2026-06-21'::date,'JOB-7935','AIG Gachibowli','Deepa Iyer','gold',
    -6, 4.90, 4.70, 4.80,
    'Came early with spare ECG leads in hand. Pre-empted the failure. Quoted us to AIG board.',
    'promoter','pre-empt-spare-carry','bonus', 1800);

-- ---------------------------------------------------------------------
-- Table 2: monthly pattern rollup with incentive policy decision
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_pattern_rollup_r2760 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  total_arrivals int NOT NULL,
  on_time_arrivals int NOT NULL,
  late_arrivals int NOT NULL,
  avg_arrival_rating numeric(3,2) NOT NULL,
  avg_overall_rating numeric(3,2) NOT NULL,
  promoter_count int NOT NULL,
  detractor_count int NOT NULL,
  dominant_pattern text NOT NULL,
  policy_decision text NOT NULL CHECK (policy_decision IN ('promote','retain','coach','probation','exit')),
  monthly_bonus_rupees int NOT NULL DEFAULT 0,
  founder_note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_pattern_rollup_r2760 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_monthly_pattern_rollup_r2760;
CREATE POLICY founder_all ON engineer_monthly_pattern_rollup_r2760
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_pattern_rollup_r2760
  (month_label, engineer_name, engineer_tier, total_arrivals, on_time_arrivals, late_arrivals,
   avg_arrival_rating, avg_overall_rating, promoter_count, detractor_count,
   dominant_pattern, policy_decision, monthly_bonus_rupees, founder_note)
VALUES
  ('2026-06','Ramesh Kumar','gold', 14, 13, 1, 4.80, 4.85, 12, 0,
    'early-arrival-OT-saver','promote', 6000,
    'Promote to platinum next month. OT slot saves quoted by Apollo billing twice.'),
  ('2026-06','Priya Sharma','platinum', 12, 12, 0, 4.85, 4.88, 11, 0,
    'platinum-first-time-right','retain', 8000,
    'Anchor engineer. Pair with new joiners for shadow visits.'),
  ('2026-06','Anil Reddy','silver', 11, 7, 4, 3.40, 3.55, 4, 2,
    'late-parking-excuse','coach', 0,
    'Coaching plan: route planning + 30 min buffer rule. Re-rate in 30 days.'),
  ('2026-06','Sunita Rao','gold', 13, 12, 1, 4.60, 4.55, 10, 0,
    'fast-icu-monitor-fix','retain', 3500,
    'Solid gold. Push toward platinum at Q3 review.'),
  ('2026-06','Mahesh Goud','bronze', 9, 4, 5, 2.30, 2.40, 1, 4,
    'severe-late-rework','probation', 0,
    'Probation 30 days. Two more late detractors = exit conversation.'),
  ('2026-06','Lakshmi Devi','platinum', 15, 15, 0, 4.95, 4.93, 14, 0,
    'on-the-dot-cath-lab','promote', 10000,
    'Top performer of month. Quoted by Care Hospital board. Public spotlight worthy.'),
  ('2026-06','Vikram Singh','silver', 10, 5, 5, 2.70, 2.85, 2, 3,
    'repeat-late-same-node','exit', 0,
    'Exit conversation this week. Same node complained 3x. Reputation risk.'),
  ('2026-06','Deepa Iyer','gold', 13, 12, 1, 4.70, 4.75, 11, 0,
    'pre-empt-spare-carry','promote', 5500,
    'AIG board called out by name. Promote to platinum next month.');

-- =====================================================================
-- RPCs — all founder-gated, SECDEF, plpgsql, search_path pinned
-- =====================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2760_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2760_kpi_summary()
RETURNS TABLE (
  total_arrivals bigint,
  on_time_pct numeric,
  avg_arrival_rating numeric,
  avg_overall_rating numeric,
  promoter_pct numeric,
  detractor_pct numeric,
  total_bonus_paid_rupees bigint,
  engineers_on_probation bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    ROUND(100.0 * SUM(CASE WHEN arrival_punctuality_minutes <= 0 THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(arrival_rating)::numeric, 2),
    ROUND(AVG(overall_rating)::numeric, 2),
    ROUND(100.0 * SUM(CASE WHEN sentiment = 'promoter' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * SUM(CASE WHEN sentiment = 'detractor' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(incentive_amount_rupees),0)::bigint,
    (SELECT COUNT(*)::bigint FROM engineer_monthly_pattern_rollup_r2760 WHERE policy_decision IN ('probation','exit'))
  FROM customer_monthly_arrival_ratings_r2760;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_kpi_summary() TO authenticated;

-- RPC 2: arrival rating feed
DROP FUNCTION IF EXISTS founder_r2760_arrival_feed();
CREATE OR REPLACE FUNCTION founder_r2760_arrival_feed()
RETURNS SETOF customer_monthly_arrival_ratings_r2760
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM customer_monthly_arrival_ratings_r2760
  ORDER BY arrival_date DESC, overall_rating DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_arrival_feed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_arrival_feed() TO authenticated;

-- RPC 3: engineer rollup feed
DROP FUNCTION IF EXISTS founder_r2760_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2760_engineer_rollup()
RETURNS SETOF engineer_monthly_pattern_rollup_r2760
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_monthly_pattern_rollup_r2760
  ORDER BY avg_overall_rating DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_engineer_rollup() TO authenticated;

-- RPC 4: pattern frequency
DROP FUNCTION IF EXISTS founder_r2760_pattern_frequency();
CREATE OR REPLACE FUNCTION founder_r2760_pattern_frequency()
RETURNS TABLE (
  pattern_tag text,
  occurrences bigint,
  avg_overall_rating numeric,
  sentiment_skew text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.pattern_tag,
    COUNT(*)::bigint,
    ROUND(AVG(a.overall_rating)::numeric, 2),
    CASE
      WHEN AVG(a.overall_rating) >= 4.5 THEN 'promoter-dominant'
      WHEN AVG(a.overall_rating) >= 3.5 THEN 'mixed'
      ELSE 'detractor-dominant'
    END
  FROM customer_monthly_arrival_ratings_r2760 a
  GROUP BY a.pattern_tag
  ORDER BY COUNT(*) DESC, AVG(a.overall_rating) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_pattern_frequency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_pattern_frequency() TO authenticated;

-- RPC 5: tier mix
DROP FUNCTION IF EXISTS founder_r2760_tier_mix();
CREATE OR REPLACE FUNCTION founder_r2760_tier_mix()
RETURNS TABLE (
  engineer_tier text,
  engineers bigint,
  avg_rating numeric,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.engineer_tier,
    COUNT(*)::bigint,
    ROUND(AVG(r.avg_overall_rating)::numeric, 2),
    COALESCE(SUM(r.monthly_bonus_rupees),0)::bigint
  FROM engineer_monthly_pattern_rollup_r2760 r
  GROUP BY r.engineer_tier
  ORDER BY AVG(r.avg_overall_rating) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_tier_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_tier_mix() TO authenticated;

-- RPC 6: incentive action mix
DROP FUNCTION IF EXISTS founder_r2760_action_mix();
CREATE OR REPLACE FUNCTION founder_r2760_action_mix()
RETURNS TABLE (
  incentive_action text,
  arrivals bigint,
  total_payout_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.incentive_action,
    COUNT(*)::bigint,
    COALESCE(SUM(a.incentive_amount_rupees),0)::bigint
  FROM customer_monthly_arrival_ratings_r2760 a
  GROUP BY a.incentive_action
  ORDER BY SUM(a.incentive_amount_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_action_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_action_mix() TO authenticated;

-- RPC 7: top promoter quotes
DROP FUNCTION IF EXISTS founder_r2760_top_promoter_quotes();
CREATE OR REPLACE FUNCTION founder_r2760_top_promoter_quotes()
RETURNS TABLE (
  engineer_name text,
  customer_org text,
  overall_rating numeric,
  verbatim_quote text,
  pattern_tag text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_name, a.customer_org, a.overall_rating, a.verbatim_quote, a.pattern_tag
  FROM customer_monthly_arrival_ratings_r2760 a
  WHERE a.sentiment = 'promoter'
  ORDER BY a.overall_rating DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_top_promoter_quotes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_top_promoter_quotes() TO authenticated;

-- RPC 8: detractor watchlist
DROP FUNCTION IF EXISTS founder_r2760_detractor_watchlist();
CREATE OR REPLACE FUNCTION founder_r2760_detractor_watchlist()
RETURNS TABLE (
  engineer_name text,
  customer_org text,
  arrival_punctuality_minutes int,
  overall_rating numeric,
  verbatim_quote text,
  incentive_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_name, a.customer_org, a.arrival_punctuality_minutes,
         a.overall_rating, a.verbatim_quote, a.incentive_action
  FROM customer_monthly_arrival_ratings_r2760 a
  WHERE a.sentiment = 'detractor'
  ORDER BY a.overall_rating ASC, a.arrival_punctuality_minutes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2760_detractor_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2760_detractor_watchlist() TO authenticated;

COMMIT;
