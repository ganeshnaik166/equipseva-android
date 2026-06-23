-- Round r2477: founder-monthly-vacation-restorative-tracker
-- Tracks founder monthly restoration: days off, restorative practices, creative time,
-- stress vs energy scores, sleep, exercise, drains, restorers, mood + intentions.

CREATE TABLE IF NOT EXISTS public.founder_monthly_restoration_r2477 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  days_off_taken int NOT NULL DEFAULT 0 CHECK (days_off_taken >= 0 AND days_off_taken <= 31),
  restorative_practices_md text,
  creative_time_hours numeric NOT NULL DEFAULT 0 CHECK (creative_time_hours >= 0),
  stress_score int NOT NULL DEFAULT 5 CHECK (stress_score >= 0 AND stress_score <= 10),
  energy_score int NOT NULL DEFAULT 5 CHECK (energy_score >= 0 AND energy_score <= 10),
  sleep_avg_hours numeric NOT NULL DEFAULT 7 CHECK (sleep_avg_hours >= 0 AND sleep_avg_hours <= 24),
  exercise_hours numeric NOT NULL DEFAULT 0 CHECK (exercise_hours >= 0),
  top_drains_md text,
  top_restorers_md text,
  mood text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_restoration_intentions_r2477 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  intention_kind text NOT NULL CHECK (intention_kind IN ('weekend_off','long_break','no_meeting_friday','journaling','exercise','family_time')),
  planned boolean NOT NULL DEFAULT true,
  actual_hours numeric NOT NULL DEFAULT 0 CHECK (actual_hours >= 0),
  satisfaction int NOT NULL DEFAULT 5 CHECK (satisfaction >= 0 AND satisfaction <= 10),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','missed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_monthly_restoration_r2477 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_restoration_intentions_r2477 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_monthly_restoration_r2477;
CREATE POLICY founder_all ON public.founder_monthly_restoration_r2477
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_restoration_intentions_r2477;
CREATE POLICY founder_all ON public.founder_restoration_intentions_r2477
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed monthly restoration rows (last 5 months)
INSERT INTO public.founder_monthly_restoration_r2477
  (month_start, days_off_taken, restorative_practices_md, creative_time_hours, stress_score, energy_score, sleep_avg_hours, exercise_hours, top_drains_md, top_restorers_md, mood, notes)
VALUES
  ('2026-02-01', 4, '- Weekend hike\n- 2 long walks', 6.5, 7, 5, 6.2, 4.0, 'Cashfree KYC limbo, AMC churn', 'Hike + cooking', 'tense', 'Lots of context switching'),
  ('2026-03-01', 6, '- 3-day Goa trip\n- Daily 30-min journaling', 12.0, 6, 6, 6.8, 6.5, 'Investor pings, hospital escalations', 'Goa + journaling', 'recovering', 'Long break helped reset'),
  ('2026-04-01', 5, '- No-meeting Fridays\n- Family dinners 3x/week', 9.5, 6, 6, 7.0, 7.0, 'Founder ops, audit blitzes', 'No-meeting Fridays', 'steady', 'Friday block held 3 of 4 weeks'),
  ('2026-05-01', 7, '- Long weekend with parents\n- Yoga 4x/week', 14.0, 5, 7, 7.2, 9.0, 'Code red incidents', 'Yoga + parents visit', 'good', 'Stress trending down'),
  ('2026-06-01', 8, '- Mid-month 4-day off\n- Reading hour daily', 16.5, 4, 8, 7.5, 10.5, 'Investor cap-table reviews', 'Reading + 4-day off', 'energised', 'Best month so far');

-- Seed intention rows
INSERT INTO public.founder_restoration_intentions_r2477
  (month_start, intention_kind, planned, actual_hours, satisfaction, status, notes)
VALUES
  ('2026-06-01', 'weekend_off', true, 16, 8, 'done', 'Both weekends fully off'),
  ('2026-06-01', 'no_meeting_friday', true, 24, 9, 'done', 'Held all 4 Fridays'),
  ('2026-06-01', 'long_break', true, 32, 9, 'done', '4-day mid-month break'),
  ('2026-06-01', 'journaling', true, 6, 7, 'done', '15 min daily, missed 3 days'),
  ('2026-06-01', 'exercise', true, 10.5, 8, 'done', 'Yoga + walks'),
  ('2026-06-01', 'family_time', true, 18, 8, 'done', 'Daily dinner, 1 outing'),
  ('2026-05-01', 'weekend_off', true, 14, 7, 'done', 'Mostly held'),
  ('2026-05-01', 'no_meeting_friday', true, 18, 6, 'missed', 'Missed 1 Friday for code red'),
  ('2026-05-01', 'journaling', true, 4, 6, 'done', 'Sporadic'),
  ('2026-04-01', 'no_meeting_friday', true, 24, 7, 'done', 'All 4 Fridays'),
  ('2026-04-01', 'long_break', true, 0, 3, 'dropped', 'Could not plan'),
  ('2026-03-01', 'long_break', true, 72, 10, 'done', 'Goa 3-day trip'),
  ('2026-02-01', 'weekend_off', true, 8, 5, 'missed', 'Half weekends only');

-- RPC 1: list monthly restoration
CREATE OR REPLACE FUNCTION public.list_restoration_r2477()
RETURNS TABLE (
  id uuid,
  month_start date,
  days_off_taken int,
  restorative_practices_md text,
  creative_time_hours numeric,
  stress_score int,
  energy_score int,
  sleep_avg_hours numeric,
  exercise_hours numeric,
  top_drains_md text,
  top_restorers_md text,
  mood text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.month_start, r.days_off_taken, r.restorative_practices_md,
         r.creative_time_hours, r.stress_score, r.energy_score,
         r.sleep_avg_hours, r.exercise_hours, r.top_drains_md, r.top_restorers_md,
         r.mood, r.notes, r.created_at
  FROM public.founder_monthly_restoration_r2477 r
  ORDER BY r.month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_restoration_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_restoration_r2477() TO authenticated;

-- RPC 2: list intentions
CREATE OR REPLACE FUNCTION public.list_intentions_r2477()
RETURNS TABLE (
  id uuid,
  month_start date,
  intention_kind text,
  planned boolean,
  actual_hours numeric,
  satisfaction int,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.month_start, i.intention_kind, i.planned, i.actual_hours,
         i.satisfaction, i.status, i.notes, i.created_at
  FROM public.founder_restoration_intentions_r2477 i
  ORDER BY i.month_start DESC, i.intention_kind ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_intentions_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intentions_r2477() TO authenticated;

-- RPC 3: stress vs creative trend
CREATE OR REPLACE FUNCTION public.stress_vs_creative_trend_r2477()
RETURNS TABLE (
  month_start date,
  stress_score int,
  energy_score int,
  creative_time_hours numeric,
  days_off_taken int,
  sleep_avg_hours numeric,
  exercise_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.month_start, r.stress_score, r.energy_score, r.creative_time_hours,
         r.days_off_taken, r.sleep_avg_hours, r.exercise_hours
  FROM public.founder_monthly_restoration_r2477 r
  ORDER BY r.month_start ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.stress_vs_creative_trend_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stress_vs_creative_trend_r2477() TO authenticated;

-- RPC 4: intention completion summary
CREATE OR REPLACE FUNCTION public.intention_completion_summary_r2477()
RETURNS TABLE (
  intention_kind text,
  total int,
  done_count int,
  missed_count int,
  dropped_count int,
  planned_count int,
  avg_satisfaction numeric,
  total_actual_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intention_kind,
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE i.status = 'done')::int AS done_count,
         COUNT(*) FILTER (WHERE i.status = 'missed')::int AS missed_count,
         COUNT(*) FILTER (WHERE i.status = 'dropped')::int AS dropped_count,
         COUNT(*) FILTER (WHERE i.status = 'planned')::int AS planned_count,
         ROUND(AVG(i.satisfaction)::numeric, 2) AS avg_satisfaction,
         COALESCE(SUM(i.actual_hours), 0)::numeric AS total_actual_hours
  FROM public.founder_restoration_intentions_r2477 i
  GROUP BY i.intention_kind
  ORDER BY done_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.intention_completion_summary_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.intention_completion_summary_r2477() TO authenticated;

-- RPC 5: top restorers (most-recent month list)
CREATE OR REPLACE FUNCTION public.top_restorers_r2477()
RETURNS TABLE (
  month_start date,
  top_restorers_md text,
  energy_score int,
  creative_time_hours numeric,
  mood text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.month_start, r.top_restorers_md, r.energy_score, r.creative_time_hours, r.mood
  FROM public.founder_monthly_restoration_r2477 r
  WHERE r.top_restorers_md IS NOT NULL
  ORDER BY r.month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_restorers_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_restorers_r2477() TO authenticated;

-- RPC 6: top drains (most-recent month list)
CREATE OR REPLACE FUNCTION public.top_drains_r2477()
RETURNS TABLE (
  month_start date,
  top_drains_md text,
  stress_score int,
  days_off_taken int,
  mood text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.month_start, r.top_drains_md, r.stress_score, r.days_off_taken, r.mood
  FROM public.founder_monthly_restoration_r2477 r
  WHERE r.top_drains_md IS NOT NULL
  ORDER BY r.month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_drains_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drains_r2477() TO authenticated;

-- RPC 7: monthly pulse summary
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2477()
RETURNS TABLE (
  months_tracked int,
  avg_days_off numeric,
  avg_stress numeric,
  avg_energy numeric,
  avg_sleep numeric,
  avg_creative_hours numeric,
  avg_exercise_hours numeric,
  best_month date,
  worst_month date,
  trending text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_recent_stress numeric;
  v_older_stress numeric;
  v_trend text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT AVG(stress_score)::numeric INTO v_recent_stress
  FROM (SELECT stress_score FROM public.founder_monthly_restoration_r2477 ORDER BY month_start DESC LIMIT 2) recent;

  SELECT AVG(stress_score)::numeric INTO v_older_stress
  FROM (SELECT stress_score FROM public.founder_monthly_restoration_r2477 ORDER BY month_start ASC LIMIT 2) older;

  v_trend := CASE
    WHEN v_recent_stress IS NULL OR v_older_stress IS NULL THEN 'insufficient_data'
    WHEN v_recent_stress < v_older_stress - 0.5 THEN 'improving'
    WHEN v_recent_stress > v_older_stress + 0.5 THEN 'worsening'
    ELSE 'stable'
  END;

  RETURN QUERY
  SELECT
    COUNT(*)::int AS months_tracked,
    ROUND(AVG(r.days_off_taken)::numeric, 2) AS avg_days_off,
    ROUND(AVG(r.stress_score)::numeric, 2) AS avg_stress,
    ROUND(AVG(r.energy_score)::numeric, 2) AS avg_energy,
    ROUND(AVG(r.sleep_avg_hours)::numeric, 2) AS avg_sleep,
    ROUND(AVG(r.creative_time_hours)::numeric, 2) AS avg_creative_hours,
    ROUND(AVG(r.exercise_hours)::numeric, 2) AS avg_exercise_hours,
    (SELECT month_start FROM public.founder_monthly_restoration_r2477 ORDER BY energy_score DESC, stress_score ASC LIMIT 1) AS best_month,
    (SELECT month_start FROM public.founder_monthly_restoration_r2477 ORDER BY stress_score DESC, energy_score ASC LIMIT 1) AS worst_month,
    v_trend AS trending
  FROM public.founder_monthly_restoration_r2477 r;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_summary_r2477() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_summary_r2477() TO authenticated;
