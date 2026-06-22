BEGIN;

-- Table 1: rotation roster — current weeks of duty per engineer per region/shift
CREATE TABLE IF NOT EXISTS public.engineer_rotation_roster_r2274 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  region text NOT NULL,
  shift_type text NOT NULL CHECK (shift_type IN ('night','weekend','holiday','weekday')),
  week_start_date date NOT NULL,
  week_end_date date NOT NULL,
  on_duty boolean NOT NULL DEFAULT true,
  jobs_assigned_count int NOT NULL DEFAULT 0,
  hours_logged numeric(8,2) NOT NULL DEFAULT 0,
  fairness_score numeric(6,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, region, shift_type, week_start_date)
);

CREATE INDEX IF NOT EXISTS idx_err_roster_r2274_region_week
  ON public.engineer_rotation_roster_r2274 (region, week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_err_roster_r2274_engineer
  ON public.engineer_rotation_roster_r2274 (engineer_user_id, week_start_date DESC);

ALTER TABLE public.engineer_rotation_roster_r2274 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS err_roster_r2274_founder_all ON public.engineer_rotation_roster_r2274;
CREATE POLICY err_roster_r2274_founder_all
  ON public.engineer_rotation_roster_r2274
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: balance log — running rotation balance entries for audit + fairness math
CREATE TABLE IF NOT EXISTS public.engineer_rotation_balance_log_r2274 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  region text NOT NULL,
  shift_type text NOT NULL CHECK (shift_type IN ('night','weekend','holiday','weekday')),
  event_date date NOT NULL,
  delta_points numeric(6,2) NOT NULL DEFAULT 0,
  running_balance numeric(8,2) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_err_balance_r2274_engineer_date
  ON public.engineer_rotation_balance_log_r2274 (engineer_user_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_err_balance_r2274_region_date
  ON public.engineer_rotation_balance_log_r2274 (region, event_date DESC);

ALTER TABLE public.engineer_rotation_balance_log_r2274 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS err_balance_r2274_founder_all ON public.engineer_rotation_balance_log_r2274;
CREATE POLICY err_balance_r2274_founder_all
  ON public.engineer_rotation_balance_log_r2274
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data: pick 6 existing engineers; bail out if there are fewer
DO $seed$
DECLARE
  ids uuid[];
  v_eng_a uuid;
  v_eng_b uuid;
  v_eng_c uuid;
  v_eng_d uuid;
  v_eng_e uuid;
  v_eng_f uuid;
BEGIN
  SELECT ARRAY(SELECT id FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 6) INTO ids;
  IF array_length(ids, 1) < 6 THEN RETURN; END IF;
  v_eng_a := ids[1]; v_eng_b := ids[2]; v_eng_c := ids[3];
  v_eng_d := ids[4]; v_eng_e := ids[5]; v_eng_f := ids[6];

  INSERT INTO public.engineer_rotation_roster_r2274
    (engineer_user_id, region, shift_type, week_start_date, week_end_date, on_duty, jobs_assigned_count, hours_logged, fairness_score, notes)
  VALUES
    (v_eng_a, 'Hyderabad', 'night', current_date - 7, current_date - 1, true, 12, 48.5, 78.2, 'covered 2 ICU calls'),
    (v_eng_b, 'Hyderabad', 'weekend', current_date - 7, current_date - 1, true, 8, 32.0, 65.4, 'standard weekend block'),
    (v_eng_c, 'Bangalore', 'night', current_date - 7, current_date - 1, true, 10, 41.0, 71.8, 'paired with C-shift lead'),
    (v_eng_d, 'Bangalore', 'holiday', current_date - 7, current_date - 1, false, 4, 16.0, 42.5, 'half-week on duty'),
    (v_eng_e, 'Chennai', 'weekend', current_date - 7, current_date - 1, true, 9, 36.0, 68.1, 'covered for sick leave'),
    (v_eng_f, 'Chennai', 'weekday', current_date - 7, current_date - 1, true, 14, 52.0, 81.3, 'high jobcount week'),
    (v_eng_a, 'Hyderabad', 'weekend', current_date, current_date + 6, true, 0, 0, 70.0, 'upcoming weekend duty'),
    (v_eng_c, 'Bangalore', 'holiday', current_date, current_date + 6, true, 0, 0, 70.0, 'public holiday block')
  ON CONFLICT (engineer_user_id, region, shift_type, week_start_date) DO NOTHING;

  INSERT INTO public.engineer_rotation_balance_log_r2274
    (engineer_user_id, region, shift_type, event_date, delta_points, running_balance, reason)
  VALUES
    (v_eng_a, 'Hyderabad', 'night',    current_date - 5, 8.5,  8.5,  'night ICU run'),
    (v_eng_a, 'Hyderabad', 'night',    current_date - 3, 6.0,  14.5, 'night call'),
    (v_eng_b, 'Hyderabad', 'weekend',  current_date - 4, 7.0,  7.0,  'weekend block'),
    (v_eng_c, 'Bangalore', 'night',    current_date - 6, 5.5,  5.5,  'night block start'),
    (v_eng_c, 'Bangalore', 'night',    current_date - 2, 6.5,  12.0, 'night extended'),
    (v_eng_d, 'Bangalore', 'holiday',  current_date - 3, -3.0, -3.0, 'declined half-block'),
    (v_eng_e, 'Chennai',   'weekend',  current_date - 4, 6.0,  6.0,  'weekend covered'),
    (v_eng_f, 'Chennai',   'weekday',  current_date - 5, 9.0,  9.0,  'high jobcount'),
    (v_eng_f, 'Chennai',   'weekday',  current_date - 1, 4.5,  13.5, 'after-hours extension');
END
$seed$;

-- RPC 1: KPIs
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_kpis_r2274()
RETURNS TABLE (
  active_engineers int,
  on_duty_this_week int,
  total_hours_last_week numeric,
  avg_fairness_score numeric,
  night_shift_count int,
  weekend_shift_count int,
  holiday_shift_count int
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
    (COUNT(DISTINCT engineer_user_id))::int,
    (COUNT(DISTINCT engineer_user_id) FILTER (WHERE on_duty AND week_start_date <= current_date AND week_end_date >= current_date))::int,
    COALESCE(SUM(hours_logged) FILTER (WHERE week_end_date < current_date AND week_end_date >= current_date - 7), 0)::numeric,
    COALESCE(AVG(fairness_score), 0)::numeric,
    (COUNT(*) FILTER (WHERE shift_type = 'night'))::int,
    (COUNT(*) FILTER (WHERE shift_type = 'weekend'))::int,
    (COUNT(*) FILTER (WHERE shift_type = 'holiday'))::int
  FROM public.engineer_rotation_roster_r2274;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_kpis_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_kpis_r2274() TO authenticated;

-- RPC 2: by region
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_by_region_r2274()
RETURNS TABLE (
  region text,
  engineers int,
  total_jobs int,
  total_hours numeric,
  avg_fairness numeric
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
    r.region,
    (COUNT(DISTINCT r.engineer_user_id))::int,
    COALESCE(SUM(r.jobs_assigned_count), 0)::int,
    COALESCE(SUM(r.hours_logged), 0)::numeric,
    COALESCE(AVG(r.fairness_score), 0)::numeric
  FROM public.engineer_rotation_roster_r2274 r
  GROUP BY r.region
  ORDER BY r.region;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_by_region_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_by_region_r2274() TO authenticated;

-- RPC 3: by shift type
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_by_shift_r2274()
RETURNS TABLE (
  shift_type text,
  rows_count int,
  on_duty_count int,
  total_hours numeric,
  total_jobs int
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
    r.shift_type,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE r.on_duty))::int,
    COALESCE(SUM(r.hours_logged), 0)::numeric,
    COALESCE(SUM(r.jobs_assigned_count), 0)::int
  FROM public.engineer_rotation_roster_r2274 r
  GROUP BY r.shift_type
  ORDER BY r.shift_type;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_by_shift_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_by_shift_r2274() TO authenticated;

-- RPC 4: current week duty
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_current_week_r2274()
RETURNS TABLE (
  engineer_email text,
  region text,
  shift_type text,
  week_start_date date,
  week_end_date date,
  jobs_assigned_count int,
  hours_logged numeric,
  fairness_score numeric
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
    p.email,
    r.region,
    r.shift_type,
    r.week_start_date,
    r.week_end_date,
    r.jobs_assigned_count,
    r.hours_logged,
    r.fairness_score
  FROM public.engineer_rotation_roster_r2274 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.week_start_date <= current_date
    AND r.week_end_date >= current_date
    AND r.on_duty
  ORDER BY r.region, r.shift_type, p.email;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_current_week_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_current_week_r2274() TO authenticated;

-- RPC 5: fairness ranking
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_fairness_rank_r2274()
RETURNS TABLE (
  engineer_email text,
  region text,
  total_jobs int,
  total_hours numeric,
  avg_fairness_score numeric,
  balance_total numeric
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
    p.email,
    MAX(r.region),
    COALESCE(SUM(r.jobs_assigned_count), 0)::int,
    COALESCE(SUM(r.hours_logged), 0)::numeric,
    COALESCE(AVG(r.fairness_score), 0)::numeric,
    COALESCE((SELECT SUM(delta_points) FROM public.engineer_rotation_balance_log_r2274 b WHERE b.engineer_user_id = p.id), 0)::numeric
  FROM public.engineer_rotation_roster_r2274 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  GROUP BY p.id, p.email
  ORDER BY COALESCE(AVG(r.fairness_score), 0) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_fairness_rank_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_fairness_rank_r2274() TO authenticated;

-- RPC 6: balance log recent
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_balance_log_r2274()
RETURNS TABLE (
  engineer_email text,
  region text,
  shift_type text,
  event_date date,
  delta_points numeric,
  running_balance numeric,
  reason text
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
    p.email,
    b.region,
    b.shift_type,
    b.event_date,
    b.delta_points,
    b.running_balance,
    b.reason
  FROM public.engineer_rotation_balance_log_r2274 b
  JOIN public.profiles p ON p.id = b.engineer_user_id
  ORDER BY b.event_date DESC, b.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_balance_log_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_balance_log_r2274() TO authenticated;

-- RPC 7: weekly trend (hours per week)
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_weekly_trend_r2274()
RETURNS TABLE (
  week_start_date date,
  rows_count int,
  on_duty_count int,
  total_hours numeric,
  total_jobs int
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
    r.week_start_date,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE r.on_duty))::int,
    COALESCE(SUM(r.hours_logged), 0)::numeric,
    COALESCE(SUM(r.jobs_assigned_count), 0)::int
  FROM public.engineer_rotation_roster_r2274 r
  GROUP BY r.week_start_date
  ORDER BY r.week_start_date DESC
  LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_engineer_rotation_weekly_trend_r2274() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_rotation_weekly_trend_r2274() TO authenticated;

COMMIT;
