-- Round r2493: founder-energy-management-tracker
-- Daily energy x sleep x exercise x nutrition x creative blocks x peak hours x low hours

CREATE TABLE IF NOT EXISTS public.founder_daily_energy_r2493 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day date NOT NULL,
  sleep_hours numeric(4,2) NOT NULL CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
  exercise_minutes int NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0 AND exercise_minutes <= 600),
  nutrition_score int NOT NULL CHECK (nutrition_score >= 0 AND nutrition_score <= 10),
  creative_block_minutes int NOT NULL DEFAULT 0 CHECK (creative_block_minutes >= 0 AND creative_block_minutes <= 1440),
  peak_hours_md text,
  low_hours_md text,
  energy_score int NOT NULL CHECK (energy_score >= 0 AND energy_score <= 10),
  stress_score int NOT NULL CHECK (stress_score >= 0 AND stress_score <= 10),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.energy_pattern_insights_r2493 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_kind text NOT NULL CHECK (pattern_kind IN ('peak_morning','peak_afternoon','peak_evening','crash_after_lunch','late_night_creative','exercise_correlation')),
  observed_count int NOT NULL DEFAULT 0 CHECK (observed_count >= 0),
  action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_daily_energy_r2493 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.energy_pattern_insights_r2493 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_daily_energy_r2493;
CREATE POLICY founder_all ON public.founder_daily_energy_r2493
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.energy_pattern_insights_r2493;
CREATE POLICY founder_all ON public.energy_pattern_insights_r2493
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed daily energy (last few days)
INSERT INTO public.founder_daily_energy_r2493 (day, sleep_hours, exercise_minutes, nutrition_score, creative_block_minutes, peak_hours_md, low_hours_md, energy_score, stress_score, notes) VALUES
  ('2026-06-18'::date, 6.5, 30, 7, 90, '**09:00 - 12:00** deep code', '**14:00 - 15:30** post-lunch dip', 7, 5, 'Solid morning, lunch killed flow'),
  ('2026-06-19'::date, 7.5, 45, 8, 120, '**08:30 - 11:30** strategy work', '**16:00 - 17:00** decision fatigue', 8, 4, 'Best day this week'),
  ('2026-06-20'::date, 5.0, 0, 5, 30, '**10:00 - 11:00** brief peak', '**13:00 - 18:00** sluggish all afternoon', 4, 7, 'Bad sleep tanked the day'),
  ('2026-06-21'::date, 8.0, 60, 9, 180, '**07:30 - 11:00** & **20:00 - 22:00**', '**15:00 - 16:00** mild dip', 9, 3, 'Sunday recovery + late-night creative burst'),
  ('2026-06-22'::date, 7.0, 40, 7, 60, '**09:00 - 12:30** founder review', '**14:30 - 15:30** crash after lunch', 7, 5, 'Pattern: lunch crash is reliable');

-- Seed pattern insights
INSERT INTO public.energy_pattern_insights_r2493 (pattern_kind, observed_count, action_md, owner_email, status, notes) VALUES
  ('peak_morning', 14, 'Block **09:00 - 12:00** for deep code + strategy. No meetings.', 'marketingtools@getphyllo.com', 'in_progress', 'Strongest pattern; calendar protected'),
  ('crash_after_lunch', 11, 'Move heavy meetings to 15:30+. Use 14:00 - 15:30 for shallow work or walk.', 'marketingtools@getphyllo.com', 'open', 'Reliable dip after lunch regardless of meal'),
  ('late_night_creative', 6, 'Allow **20:00 - 22:00** creative bursts on weekends; protect weekday wind-down.', 'marketingtools@getphyllo.com', 'open', 'Weekend pattern only'),
  ('exercise_correlation', 9, '40+ min exercise correlates with +2 energy score next day. Schedule daily.', 'marketingtools@getphyllo.com', 'done', 'Confirmed across 9 sample pairs'),
  ('peak_evening', 4, 'Reserve evening peaks for personal projects, not work calls.', 'marketingtools@getphyllo.com', 'open', 'Less common but useful');

-- RPC 1: list daily energy
CREATE OR REPLACE FUNCTION public.list_daily_energy_r2493()
RETURNS SETOF public.founder_daily_energy_r2493
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_daily_energy_r2493 ORDER BY day DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_daily_energy_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_daily_energy_r2493() TO authenticated;

-- RPC 2: list pattern insights
CREATE OR REPLACE FUNCTION public.list_pattern_insights_r2493()
RETURNS SETOF public.energy_pattern_insights_r2493
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.energy_pattern_insights_r2493 ORDER BY observed_count DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pattern_insights_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pattern_insights_r2493() TO authenticated;

-- RPC 3: weekly energy trend
CREATE OR REPLACE FUNCTION public.weekly_energy_trend_r2493()
RETURNS TABLE(week_start date, avg_energy numeric, avg_stress numeric, avg_sleep numeric, days_logged int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('week', day)::date AS week_start,
           round(avg(energy_score)::numeric, 2) AS avg_energy,
           round(avg(stress_score)::numeric, 2) AS avg_stress,
           round(avg(sleep_hours)::numeric, 2) AS avg_sleep,
           count(*)::int AS days_logged
    FROM public.founder_daily_energy_r2493
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_energy_trend_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_energy_trend_r2493() TO authenticated;

-- RPC 4: peak hours breakdown
CREATE OR REPLACE FUNCTION public.peak_hours_breakdown_r2493()
RETURNS TABLE(pattern_kind text, observed_count int, status text, action_md text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.pattern_kind, p.observed_count, p.status, p.action_md
    FROM public.energy_pattern_insights_r2493 p
    ORDER BY p.observed_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.peak_hours_breakdown_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.peak_hours_breakdown_r2493() TO authenticated;

-- RPC 5: exercise vs energy
CREATE OR REPLACE FUNCTION public.exercise_vs_energy_r2493()
RETURNS TABLE(exercise_bucket text, days_count int, avg_energy numeric, avg_stress numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN exercise_minutes = 0 THEN 'none (0)'
        WHEN exercise_minutes < 30 THEN 'light (1-29)'
        WHEN exercise_minutes < 60 THEN 'moderate (30-59)'
        ELSE 'heavy (60+)'
      END AS exercise_bucket,
      count(*)::int AS days_count,
      round(avg(energy_score)::numeric, 2) AS avg_energy,
      round(avg(stress_score)::numeric, 2) AS avg_stress
    FROM public.founder_daily_energy_r2493
    GROUP BY 1
    ORDER BY days_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.exercise_vs_energy_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.exercise_vs_energy_r2493() TO authenticated;

-- RPC 6: sleep vs energy
CREATE OR REPLACE FUNCTION public.sleep_vs_energy_r2493()
RETURNS TABLE(sleep_bucket text, days_count int, avg_energy numeric, avg_stress numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN sleep_hours < 6 THEN 'short (<6h)'
        WHEN sleep_hours < 7 THEN 'low (6-7h)'
        WHEN sleep_hours < 8 THEN 'good (7-8h)'
        ELSE 'long (8h+)'
      END AS sleep_bucket,
      count(*)::int AS days_count,
      round(avg(energy_score)::numeric, 2) AS avg_energy,
      round(avg(stress_score)::numeric, 2) AS avg_stress
    FROM public.founder_daily_energy_r2493
    GROUP BY 1
    ORDER BY days_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.sleep_vs_energy_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sleep_vs_energy_r2493() TO authenticated;

-- RPC 7: monthly pulse summary
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2493()
RETURNS TABLE(metric text, value numeric, detail text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int;
  v_avg_energy numeric;
  v_avg_stress numeric;
  v_avg_sleep numeric;
  v_avg_exercise numeric;
  v_avg_creative numeric;
  v_open_patterns int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*)::int,
         round(avg(energy_score)::numeric, 2),
         round(avg(stress_score)::numeric, 2),
         round(avg(sleep_hours)::numeric, 2),
         round(avg(exercise_minutes)::numeric, 1),
         round(avg(creative_block_minutes)::numeric, 1)
    INTO v_days, v_avg_energy, v_avg_stress, v_avg_sleep, v_avg_exercise, v_avg_creative
    FROM public.founder_daily_energy_r2493
   WHERE day >= (current_date - interval '30 days');

  SELECT count(*)::int INTO v_open_patterns
    FROM public.energy_pattern_insights_r2493
   WHERE status IN ('open','in_progress');

  RETURN QUERY
    SELECT 'days_logged_30d'::text, COALESCE(v_days,0)::numeric, 'days with an energy log in last 30 days'::text
    UNION ALL SELECT 'avg_energy_30d'::text, COALESCE(v_avg_energy,0), 'mean energy_score 0-10'::text
    UNION ALL SELECT 'avg_stress_30d'::text, COALESCE(v_avg_stress,0), 'mean stress_score 0-10'::text
    UNION ALL SELECT 'avg_sleep_hours_30d'::text, COALESCE(v_avg_sleep,0), 'mean sleep_hours'::text
    UNION ALL SELECT 'avg_exercise_min_30d'::text, COALESCE(v_avg_exercise,0), 'mean exercise minutes'::text
    UNION ALL SELECT 'avg_creative_min_30d'::text, COALESCE(v_avg_creative,0), 'mean deep creative block minutes'::text
    UNION ALL SELECT 'open_patterns'::text, COALESCE(v_open_patterns,0)::numeric, 'pattern insights still open or in_progress'::text;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_summary_r2493() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_summary_r2493() TO authenticated;
