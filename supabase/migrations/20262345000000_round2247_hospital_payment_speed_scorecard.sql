BEGIN;

-- =====================================================================
-- Round 2247: Hospital Payment Speed Scorecard
-- Track invoice -> payment days per hospital, surface late-payers, trend
-- =====================================================================

-- Table 1: per-hospital scorecard snapshot rows
CREATE TABLE IF NOT EXISTS public.hospital_payment_scorecard_r2247 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name   text NOT NULL,
  hospital_city   text,
  invoices_count  int  NOT NULL DEFAULT 0,
  paid_count      int  NOT NULL DEFAULT 0,
  overdue_count   int  NOT NULL DEFAULT 0,
  avg_days_to_pay numeric(8,2) NOT NULL DEFAULT 0,
  median_days     numeric(8,2) NOT NULL DEFAULT 0,
  worst_days      int  NOT NULL DEFAULT 0,
  outstanding_rupees bigint NOT NULL DEFAULT 0,
  speed_grade     text NOT NULL DEFAULT 'unrated'
    CHECK (speed_grade IN ('fast','ontime','slow','laggard','unrated')),
  last_invoice_at timestamptz,
  last_payment_at timestamptz,
  snapshot_at     timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES public.profiles(id),
  notes           text
);

CREATE INDEX IF NOT EXISTS idx_hps_r2247_grade
  ON public.hospital_payment_scorecard_r2247 (speed_grade);
CREATE INDEX IF NOT EXISTS idx_hps_r2247_org
  ON public.hospital_payment_scorecard_r2247 (hospital_org_id);

ALTER TABLE public.hospital_payment_scorecard_r2247 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hps_r2247_founder_all
  ON public.hospital_payment_scorecard_r2247;
CREATE POLICY hps_r2247_founder_all
  ON public.hospital_payment_scorecard_r2247
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: weekly payment-behavior trend per hospital
CREATE TABLE IF NOT EXISTS public.hospital_payment_trend_r2247 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name   text NOT NULL,
  week_start      date NOT NULL,
  invoices_issued int  NOT NULL DEFAULT 0,
  invoices_paid   int  NOT NULL DEFAULT 0,
  avg_days_to_pay numeric(8,2) NOT NULL DEFAULT 0,
  on_time_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  trend_direction text NOT NULL DEFAULT 'flat'
    CHECK (trend_direction IN ('improving','flat','degrading')),
  amount_billed_rupees bigint NOT NULL DEFAULT 0,
  amount_paid_rupees   bigint NOT NULL DEFAULT 0,
  recorded_at     timestamptz NOT NULL DEFAULT now(),
  recorded_by     uuid REFERENCES public.profiles(id),
  founder_note    text
);

CREATE INDEX IF NOT EXISTS idx_hpt_r2247_week
  ON public.hospital_payment_trend_r2247 (week_start DESC);
CREATE INDEX IF NOT EXISTS idx_hpt_r2247_org
  ON public.hospital_payment_trend_r2247 (hospital_org_id);

ALTER TABLE public.hospital_payment_trend_r2247 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpt_r2247_founder_all
  ON public.hospital_payment_trend_r2247;
CREATE POLICY hpt_r2247_founder_all
  ON public.hospital_payment_trend_r2247
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- Seed rows
-- =====================================================================
INSERT INTO public.hospital_payment_scorecard_r2247
  (hospital_org_id, hospital_name, hospital_city, invoices_count, paid_count,
   overdue_count, avg_days_to_pay, median_days, worst_days, outstanding_rupees,
   speed_grade, last_invoice_at, last_payment_at, notes)
VALUES
  (gen_random_uuid(), 'Apollo Hyderabad', 'Hyderabad', 48, 46, 2, 8.50, 7.00, 22, 184000, 'fast', now() - interval '3 days', now() - interval '5 days', 'consistently fast settlement'),
  (gen_random_uuid(), 'KIMS Secunderabad', 'Hyderabad', 35, 31, 4, 18.30, 16.00, 41, 612000, 'ontime', now() - interval '6 days', now() - interval '9 days', 'reliable, occasional delay'),
  (gen_random_uuid(), 'Yashoda Somajiguda', 'Hyderabad', 27, 21, 6, 32.40, 30.00, 58, 1240000, 'slow', now() - interval '11 days', now() - interval '15 days', 'finance team slow approvals'),
  (gen_random_uuid(), 'Care Banjara Hills', 'Hyderabad', 22, 14, 8, 47.80, 45.00, 91, 2180000, 'laggard', now() - interval '2 days', now() - interval '21 days', 'escalate to founder direct')
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_payment_trend_r2247
  (hospital_org_id, hospital_name, week_start, invoices_issued, invoices_paid,
   avg_days_to_pay, on_time_rate_pct, trend_direction, amount_billed_rupees,
   amount_paid_rupees, founder_note)
VALUES
  (gen_random_uuid(), 'Apollo Hyderabad', current_date - interval '7 days', 4, 4, 7.50, 100.00, 'improving', 320000, 320000, 'gold standard'),
  (gen_random_uuid(), 'KIMS Secunderabad', current_date - interval '7 days', 3, 2, 19.00, 66.67, 'flat', 240000, 160000, 'monitor'),
  (gen_random_uuid(), 'Yashoda Somajiguda', current_date - interval '7 days', 2, 1, 34.00, 50.00, 'degrading', 180000, 80000, 'send polite reminder'),
  (gen_random_uuid(), 'Care Banjara Hills', current_date - interval '14 days', 3, 1, 52.00, 33.33, 'degrading', 450000, 120000, 'pause new credit')
ON CONFLICT DO NOTHING;

-- =====================================================================
-- RPCs (7) — all founder-gated, plpgsql, SECURITY DEFINER
-- =====================================================================

-- 1. Summary metrics
CREATE OR REPLACE FUNCTION public.hps_r2247_summary()
RETURNS TABLE (
  total_hospitals       int,
  laggard_count         int,
  fast_count            int,
  total_outstanding     bigint,
  avg_days_to_pay_all   numeric,
  worst_offender        text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE speed_grade = 'laggard'))::int,
    (COUNT(*) FILTER (WHERE speed_grade = 'fast'))::int,
    COALESCE(SUM(outstanding_rupees), 0)::bigint,
    COALESCE(AVG(avg_days_to_pay), 0)::numeric,
    (SELECT hospital_name
       FROM public.hospital_payment_scorecard_r2247
       ORDER BY avg_days_to_pay DESC NULLS LAST
       LIMIT 1)
  FROM public.hospital_payment_scorecard_r2247;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_summary() TO authenticated;

-- 2. Scorecard list
CREATE OR REPLACE FUNCTION public.hps_r2247_scorecards()
RETURNS SETOF public.hospital_payment_scorecard_r2247
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT * FROM public.hospital_payment_scorecard_r2247
  ORDER BY avg_days_to_pay DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_scorecards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_scorecards() TO authenticated;

-- 3. Top late-payers
CREATE OR REPLACE FUNCTION public.hps_r2247_top_late()
RETURNS TABLE (
  hospital_name      text,
  hospital_city      text,
  avg_days_to_pay    numeric,
  worst_days         int,
  outstanding_rupees bigint,
  overdue_count      int,
  speed_grade        text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.hospital_name, s.hospital_city, s.avg_days_to_pay,
         s.worst_days, s.outstanding_rupees, s.overdue_count, s.speed_grade
  FROM public.hospital_payment_scorecard_r2247 s
  WHERE s.speed_grade IN ('slow','laggard')
  ORDER BY s.avg_days_to_pay DESC NULLS LAST
  LIMIT 10;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_top_late() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_top_late() TO authenticated;

-- 4. Trend rows
CREATE OR REPLACE FUNCTION public.hps_r2247_trends()
RETURNS SETOF public.hospital_payment_trend_r2247
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT * FROM public.hospital_payment_trend_r2247
  ORDER BY week_start DESC, hospital_name ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_trends() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_trends() TO authenticated;

-- 5. Grade distribution
CREATE OR REPLACE FUNCTION public.hps_r2247_grade_dist()
RETURNS TABLE (
  speed_grade text,
  hospital_count int,
  total_outstanding bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.speed_grade,
         (COUNT(*))::int,
         COALESCE(SUM(s.outstanding_rupees), 0)::bigint
  FROM public.hospital_payment_scorecard_r2247 s
  GROUP BY s.speed_grade
  ORDER BY s.speed_grade;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_grade_dist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_grade_dist() TO authenticated;

-- 6. Degrading trend hospitals
CREATE OR REPLACE FUNCTION public.hps_r2247_degrading()
RETURNS TABLE (
  hospital_name text,
  week_start    date,
  avg_days_to_pay numeric,
  on_time_rate_pct numeric,
  founder_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT t.hospital_name, t.week_start, t.avg_days_to_pay,
         t.on_time_rate_pct, t.founder_note
  FROM public.hospital_payment_trend_r2247 t
  WHERE t.trend_direction = 'degrading'
  ORDER BY t.week_start DESC, t.avg_days_to_pay DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_degrading() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_degrading() TO authenticated;

-- 7. Outstanding leaderboard
CREATE OR REPLACE FUNCTION public.hps_r2247_outstanding_top()
RETURNS TABLE (
  hospital_name text,
  hospital_city text,
  outstanding_rupees bigint,
  overdue_count int,
  speed_grade text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.hospital_name, s.hospital_city, s.outstanding_rupees,
         s.overdue_count, s.speed_grade
  FROM public.hospital_payment_scorecard_r2247 s
  WHERE s.outstanding_rupees > 0
  ORDER BY s.outstanding_rupees DESC
  LIMIT 10;
END;
$$;

REVOKE ALL ON FUNCTION public.hps_r2247_outstanding_top() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hps_r2247_outstanding_top() TO authenticated;

COMMIT;
