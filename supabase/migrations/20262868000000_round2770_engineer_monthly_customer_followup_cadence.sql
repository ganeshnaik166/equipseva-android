BEGIN;

-- ============================================================================
-- Round 2770 — Engineer Monthly Customer Followup Cadence
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_followup_cadence_r2770 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  customer_name text NOT NULL,
  customer_org text NOT NULL,
  customer_city text NOT NULL,
  last_touch_at timestamptz NOT NULL,
  last_touch_channel text NOT NULL CHECK (last_touch_channel IN ('call','whatsapp','visit','email','sms')),
  cadence_target_days int NOT NULL CHECK (cadence_target_days BETWEEN 7 AND 120),
  next_followup_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('on_track','due_soon','overdue','snoozed','completed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_followup_cadence_r2770 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_followup_cadence_r2770;
CREATE POLICY founder_all ON engineer_followup_cadence_r2770 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_followup_outcome_r2770 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  customer_name text NOT NULL,
  followup_at timestamptz NOT NULL,
  channel text NOT NULL CHECK (channel IN ('call','whatsapp','visit','email','sms')),
  outcome text NOT NULL CHECK (outcome IN ('booked_job','renewed_amc','escalated','no_answer','satisfied','complaint','referral')),
  amc_lift_rupees int NOT NULL DEFAULT 0,
  job_lift_rupees int NOT NULL DEFAULT 0,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_followup_outcome_r2770 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_followup_outcome_r2770;
CREATE POLICY founder_all ON engineer_followup_outcome_r2770 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed cadence rows
INSERT INTO engineer_followup_cadence_r2770 (engineer_name, engineer_code, customer_name, customer_org, customer_city, last_touch_at, last_touch_channel, cadence_target_days, next_followup_at, status, notes) VALUES
  ('Ramesh K', 'ENG-001', 'Dr. Sharma', 'Apollo Banjara', 'Hyderabad', now() - interval '5 days', 'call', 30, now() + interval '25 days', 'on_track', 'AMC renewal Q3'),
  ('Priya N', 'ENG-002', 'Dr. Mehta', 'Yashoda Secunderabad', 'Hyderabad', now() - interval '28 days', 'visit', 30, now() + interval '2 days', 'due_soon', 'Quarterly check pending'),
  ('Suresh M', 'ENG-003', 'Dr. Iyer', 'Manipal Vijayawada', 'Vijayawada', now() - interval '45 days', 'whatsapp', 30, now() - interval '15 days', 'overdue', 'Missed July visit'),
  ('Lakshmi R', 'ENG-004', 'Dr. Reddy', 'KIMS Kondapur', 'Hyderabad', now() - interval '10 days', 'email', 60, now() + interval '50 days', 'on_track', 'Spare order followup'),
  ('Anil V', 'ENG-005', 'Dr. Kumar', 'Care Banjara', 'Hyderabad', now() - interval '90 days', 'call', 60, now() - interval '30 days', 'overdue', 'Customer complaint open'),
  ('Ramesh K', 'ENG-001', 'Dr. Rao', 'Sunshine Secunderabad', 'Hyderabad', now() - interval '15 days', 'visit', 45, now() + interval '30 days', 'on_track', 'AMC active');

-- Seed outcomes
INSERT INTO engineer_followup_outcome_r2770 (engineer_code, customer_name, followup_at, channel, outcome, amc_lift_rupees, job_lift_rupees, sentiment) VALUES
  ('ENG-001', 'Dr. Sharma', now() - interval '5 days', 'call', 'renewed_amc', 4500000, 0, 'positive'),
  ('ENG-002', 'Dr. Mehta', now() - interval '28 days', 'visit', 'booked_job', 0, 1200000, 'neutral'),
  ('ENG-003', 'Dr. Iyer', now() - interval '45 days', 'whatsapp', 'no_answer', 0, 0, 'neutral'),
  ('ENG-004', 'Dr. Reddy', now() - interval '10 days', 'email', 'satisfied', 0, 0, 'positive'),
  ('ENG-005', 'Dr. Kumar', now() - interval '90 days', 'call', 'complaint', 0, 0, 'negative'),
  ('ENG-001', 'Dr. Rao', now() - interval '15 days', 'visit', 'referral', 3000000, 800000, 'positive');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_followup_cadence_summary_r2770();
CREATE OR REPLACE FUNCTION founder_followup_cadence_summary_r2770()
RETURNS TABLE (
  total_cadences int,
  on_track int,
  due_soon int,
  overdue int,
  completed int,
  unique_engineers int,
  unique_customers int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'on_track')::int,
    COUNT(*) FILTER (WHERE status = 'due_soon')::int,
    COUNT(*) FILTER (WHERE status = 'overdue')::int,
    COUNT(*) FILTER (WHERE status = 'completed')::int,
    COUNT(DISTINCT engineer_code)::int,
    COUNT(DISTINCT customer_name)::int
  FROM engineer_followup_cadence_r2770;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_cadence_summary_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_cadence_summary_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_cadence_rows_r2770();
CREATE OR REPLACE FUNCTION founder_followup_cadence_rows_r2770()
RETURNS TABLE (
  engineer_name text,
  engineer_code text,
  customer_name text,
  customer_org text,
  customer_city text,
  last_touch_at timestamptz,
  last_touch_channel text,
  cadence_target_days int,
  next_followup_at timestamptz,
  status text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_name, c.engineer_code, c.customer_name, c.customer_org, c.customer_city,
         c.last_touch_at, c.last_touch_channel, c.cadence_target_days, c.next_followup_at, c.status, c.notes
  FROM engineer_followup_cadence_r2770 c
  ORDER BY c.next_followup_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_cadence_rows_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_cadence_rows_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_overdue_r2770();
CREATE OR REPLACE FUNCTION founder_followup_overdue_r2770()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  customer_name text,
  days_overdue int,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_code, c.engineer_name, c.customer_name,
         GREATEST(0, EXTRACT(DAY FROM (now() - c.next_followup_at))::int) AS days_overdue,
         c.notes
  FROM engineer_followup_cadence_r2770 c
  WHERE c.status = 'overdue'
  ORDER BY days_overdue DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_overdue_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_overdue_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_channel_mix_r2770();
CREATE OR REPLACE FUNCTION founder_followup_channel_mix_r2770()
RETURNS TABLE (
  channel text,
  touches int,
  pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_followup_cadence_r2770;
  RETURN QUERY
  SELECT c.last_touch_channel,
         COUNT(*)::int,
         CASE WHEN total = 0 THEN 0 ELSE ROUND(100.0 * COUNT(*) / total, 1) END
  FROM engineer_followup_cadence_r2770 c
  GROUP BY c.last_touch_channel
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_channel_mix_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_channel_mix_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_outcome_summary_r2770();
CREATE OR REPLACE FUNCTION founder_followup_outcome_summary_r2770()
RETURNS TABLE (
  outcome text,
  count_n int,
  amc_lift_rupees bigint,
  job_lift_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outcome, COUNT(*)::int, SUM(o.amc_lift_rupees)::bigint, SUM(o.job_lift_rupees)::bigint
  FROM engineer_followup_outcome_r2770 o
  GROUP BY o.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_outcome_summary_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_outcome_summary_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_engineer_leaderboard_r2770();
CREATE OR REPLACE FUNCTION founder_followup_engineer_leaderboard_r2770()
RETURNS TABLE (
  engineer_code text,
  touches int,
  amc_lift_rupees bigint,
  job_lift_rupees bigint,
  positive_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.engineer_code,
         COUNT(*)::int,
         SUM(o.amc_lift_rupees)::bigint,
         SUM(o.job_lift_rupees)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.sentiment = 'positive') / NULLIF(COUNT(*),0), 1)
  FROM engineer_followup_outcome_r2770 o
  GROUP BY o.engineer_code
  ORDER BY SUM(o.amc_lift_rupees + o.job_lift_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_engineer_leaderboard_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_engineer_leaderboard_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_sentiment_mix_r2770();
CREATE OR REPLACE FUNCTION founder_followup_sentiment_mix_r2770()
RETURNS TABLE (
  sentiment text,
  count_n int,
  pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_followup_outcome_r2770;
  RETURN QUERY
  SELECT o.sentiment,
         COUNT(*)::int,
         CASE WHEN total = 0 THEN 0 ELSE ROUND(100.0 * COUNT(*) / total, 1) END
  FROM engineer_followup_outcome_r2770 o
  GROUP BY o.sentiment
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_sentiment_mix_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_sentiment_mix_r2770() TO authenticated;

DROP FUNCTION IF EXISTS founder_followup_city_distribution_r2770();
CREATE OR REPLACE FUNCTION founder_followup_city_distribution_r2770()
RETURNS TABLE (
  city text,
  customers int,
  overdue_n int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_city,
         COUNT(DISTINCT c.customer_name)::int,
         COUNT(*) FILTER (WHERE c.status = 'overdue')::int
  FROM engineer_followup_cadence_r2770 c
  GROUP BY c.customer_city
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_followup_city_distribution_r2770() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_followup_city_distribution_r2770() TO authenticated;

COMMIT;
