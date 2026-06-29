-- Round 2890 — Engineer Monthly Customer Repeat-Request Bonus Score
-- Founder ops: engineer accountability scorecard tracking how often
-- hospitals specifically request the same engineer back month-over-month.

BEGIN;

-- =====================================================================
-- TABLE 1: engineer_monthly_repeat_score_r2890
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_monthly_repeat_score_r2890 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_id uuid NOT NULL,
  month_key text NOT NULL,
  total_jobs int NOT NULL DEFAULT 0,
  unique_hospitals int NOT NULL DEFAULT 0,
  repeat_request_count int NOT NULL DEFAULT 0,
  repeat_ratio numeric(5,2) NOT NULL DEFAULT 0,
  avg_csat numeric(3,2) NOT NULL DEFAULT 0,
  bonus_score numeric(6,2) NOT NULL DEFAULT 0,
  bonus_payout_rupees int NOT NULL DEFAULT 0,
  tier_band text NOT NULL DEFAULT 'bronze',
  notes text
);

ALTER TABLE public.engineer_monthly_repeat_score_r2890 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- TABLE 2: engineer_repeat_request_events_r2890
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_repeat_request_events_r2890 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_id uuid NOT NULL,
  hospital_org_id uuid,
  hospital_name text NOT NULL,
  prior_job_id uuid,
  new_job_id uuid,
  days_since_last_visit int NOT NULL DEFAULT 0,
  requested_by_name text,
  request_channel text NOT NULL DEFAULT 'phone',
  csat_prior numeric(3,2),
  bonus_credited_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'verified'
);

ALTER TABLE public.engineer_repeat_request_events_r2890 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- SEED DATA: engineer_monthly_repeat_score_r2890 (15 rows)
-- =====================================================================
INSERT INTO public.engineer_monthly_repeat_score_r2890
  (engineer_id, month_key, total_jobs, unique_hospitals, repeat_request_count, repeat_ratio, avg_csat, bonus_score, bonus_payout_rupees, tier_band, notes)
VALUES
  (gen_random_uuid(), '2026-06', 28, 12, 16, 57.14, 4.78, 92.30, 8500, 'platinum', 'Top performer — Apollo + KIMS both re-booked twice'),
  (gen_random_uuid(), '2026-06', 24, 14, 10, 41.66, 4.62, 78.40, 5500, 'gold', 'Strong repeat from Yashoda + Continental'),
  (gen_random_uuid(), '2026-06', 31, 22, 9, 29.03, 4.51, 65.20, 3500, 'silver', 'High volume but mostly new hospitals'),
  (gen_random_uuid(), '2026-06', 19, 8, 11, 57.89, 4.81, 90.10, 8000, 'platinum', 'Dental specialty — Clove + Sabka Dentist loyal'),
  (gen_random_uuid(), '2026-06', 22, 15, 7, 31.81, 4.34, 58.90, 2500, 'silver', 'CSAT slipping in week 3'),
  (gen_random_uuid(), '2026-06', 14, 6, 8, 57.14, 4.72, 85.40, 6500, 'gold', 'Tier-2 city specialist — Vizag + Rajahmundry'),
  (gen_random_uuid(), '2026-06', 26, 18, 8, 30.76, 4.28, 56.10, 2000, 'silver', 'Lab equipment focus — new vertical'),
  (gen_random_uuid(), '2026-06', 17, 9, 9, 52.94, 4.65, 82.20, 6000, 'gold', 'Pediatric ICU specialist'),
  (gen_random_uuid(), '2026-06', 33, 25, 8, 24.24, 4.12, 48.30, 1500, 'bronze', 'Volume hire — repeats lagging'),
  (gen_random_uuid(), '2026-06', 21, 11, 10, 47.61, 4.55, 75.80, 5000, 'gold', 'Cath-lab niche — Care + KIMS rebooked'),
  (gen_random_uuid(), '2026-05', 25, 13, 14, 56.00, 4.71, 88.60, 7500, 'platinum', 'May benchmark — held platinum'),
  (gen_random_uuid(), '2026-05', 18, 12, 6, 33.33, 4.22, 55.40, 2000, 'silver', 'Lost 2 hospitals to competitor engineer'),
  (gen_random_uuid(), '2026-05', 29, 16, 13, 44.82, 4.59, 76.90, 5500, 'gold', 'Strong month, dipped slightly in June'),
  (gen_random_uuid(), '2026-05', 12, 5, 7, 58.33, 4.83, 91.20, 8200, 'platinum', 'Boutique book — high loyalty'),
  (gen_random_uuid(), '2026-05', 23, 19, 4, 17.39, 3.98, 38.20, 0, 'bronze', 'Warning band — no bonus, coaching scheduled');

-- =====================================================================
-- SEED DATA: engineer_repeat_request_events_r2890 (18 rows)
-- =====================================================================
INSERT INTO public.engineer_repeat_request_events_r2890
  (engineer_id, hospital_name, days_since_last_visit, requested_by_name, request_channel, csat_prior, bonus_credited_rupees, status)
VALUES
  (gen_random_uuid(), 'Apollo Hospitals Jubilee Hills', 18, 'Dr. Mehta (Bio-med head)', 'phone', 4.90, 500, 'verified'),
  (gen_random_uuid(), 'KIMS Secunderabad', 22, 'Sister Lakshmi (ICU)', 'whatsapp', 4.85, 500, 'verified'),
  (gen_random_uuid(), 'Yashoda Somajiguda', 14, 'Mr. Naidu (Procurement)', 'phone', 4.70, 500, 'verified'),
  (gen_random_uuid(), 'Continental Hospitals', 27, 'Dr. Reddy (Cardiology)', 'app', 4.75, 500, 'verified'),
  (gen_random_uuid(), 'Care Hospitals Banjara', 11, 'Bio-med Engineer Suresh', 'phone', 4.92, 500, 'verified'),
  (gen_random_uuid(), 'Clove Dental Madhapur', 9, 'Dr. Kapoor', 'app', 4.88, 500, 'verified'),
  (gen_random_uuid(), 'Sabka Dentist Kondapur', 16, 'Reception manager', 'whatsapp', 4.65, 500, 'verified'),
  (gen_random_uuid(), 'KIMS Vizag', 24, 'Dr. Patnaik', 'phone', 4.80, 500, 'verified'),
  (gen_random_uuid(), 'Sunshine Hospitals Gachibowli', 33, 'Sister Anitha', 'whatsapp', 4.55, 500, 'verified'),
  (gen_random_uuid(), 'Rainbow Children Banjara', 19, 'NICU head nurse', 'phone', 4.91, 500, 'verified'),
  (gen_random_uuid(), 'AIG Hospitals Gachibowli', 12, 'Dr. Nageshwar Rao office', 'phone', 4.86, 500, 'verified'),
  (gen_random_uuid(), 'Medicover Hitech City', 21, 'Procurement lead', 'app', 4.42, 500, 'verified'),
  (gen_random_uuid(), 'Star Hospitals Banjara', 8, 'Bio-med Ramesh', 'phone', 4.78, 500, 'verified'),
  (gen_random_uuid(), 'Olive Hospital Mehdipatnam', 28, 'Admin Iqbal', 'whatsapp', 4.31, 500, 'verified'),
  (gen_random_uuid(), 'Renova Hospitals Sanathnagar', 17, 'Dr. Patel', 'phone', 4.69, 500, 'verified'),
  (gen_random_uuid(), 'Maxcure Madhapur', 13, 'Bio-med supervisor', 'app', 4.83, 500, 'verified'),
  (gen_random_uuid(), 'Krishna Institute Vijayawada', 31, 'Owner Dr. Krishna', 'phone', 4.74, 500, 'verified'),
  (gen_random_uuid(), 'Manipal Tadepalli', 25, 'Procurement officer', 'app', 4.58, 500, 'pending');

-- =====================================================================
-- RPCS (7) — all is_founder gated
-- =====================================================================

CREATE OR REPLACE FUNCTION public.r2890_kpi_summary()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT 'total_engineers_scored'::text, COUNT(DISTINCT engineer_id)::text FROM public.engineer_monthly_repeat_score_r2890
  UNION ALL
  SELECT 'avg_repeat_ratio_pct', ROUND(AVG(repeat_ratio),2)::text FROM public.engineer_monthly_repeat_score_r2890
  UNION ALL
  SELECT 'total_bonus_paid_rupees', COALESCE(SUM(bonus_payout_rupees),0)::text FROM public.engineer_monthly_repeat_score_r2890
  UNION ALL
  SELECT 'platinum_count', COUNT(*)::text FROM public.engineer_monthly_repeat_score_r2890 WHERE tier_band='platinum'
  UNION ALL
  SELECT 'repeat_events_verified', COUNT(*)::text FROM public.engineer_repeat_request_events_r2890 WHERE status='verified';
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_top_engineers()
RETURNS SETOF public.engineer_monthly_repeat_score_r2890
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM public.engineer_monthly_repeat_score_r2890
  WHERE month_key = '2026-06'
  ORDER BY bonus_score DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_tier_distribution()
RETURNS TABLE(tier_band text, engineer_count bigint, total_bonus bigint, avg_csat numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.tier_band, COUNT(*)::bigint, COALESCE(SUM(s.bonus_payout_rupees),0)::bigint, ROUND(AVG(s.avg_csat),2)
  FROM public.engineer_monthly_repeat_score_r2890 s
  GROUP BY s.tier_band
  ORDER BY total_bonus DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_recent_repeat_events()
RETURNS SETOF public.engineer_repeat_request_events_r2890
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM public.engineer_repeat_request_events_r2890
  ORDER BY created_at DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_channel_breakdown()
RETURNS TABLE(request_channel text, event_count bigint, avg_days_since_last numeric, avg_prior_csat numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.request_channel, COUNT(*)::bigint, ROUND(AVG(e.days_since_last_visit),1), ROUND(AVG(e.csat_prior),2)
  FROM public.engineer_repeat_request_events_r2890 e
  GROUP BY e.request_channel
  ORDER BY event_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_month_over_month()
RETURNS TABLE(month_key text, engineer_count bigint, avg_repeat_ratio numeric, avg_bonus_score numeric, total_payout bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.month_key, COUNT(*)::bigint, ROUND(AVG(s.repeat_ratio),2), ROUND(AVG(s.bonus_score),2), COALESCE(SUM(s.bonus_payout_rupees),0)::bigint
  FROM public.engineer_monthly_repeat_score_r2890 s
  GROUP BY s.month_key
  ORDER BY s.month_key DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2890_coaching_watchlist()
RETURNS SETOF public.engineer_monthly_repeat_score_r2890
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM public.engineer_monthly_repeat_score_r2890
  WHERE tier_band='bronze' OR avg_csat < 4.30
  ORDER BY avg_csat ASC, bonus_score ASC
  LIMIT 20;
END;
$$;

-- =====================================================================
-- GRANTS — is_founder gate enforces inside; revoke broad EXECUTE
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.r2890_kpi_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_top_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_tier_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_recent_repeat_events() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_channel_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_month_over_month() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2890_coaching_watchlist() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2890_kpi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_top_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_tier_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_recent_repeat_events() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_channel_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_month_over_month() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2890_coaching_watchlist() TO authenticated;

COMMIT;
