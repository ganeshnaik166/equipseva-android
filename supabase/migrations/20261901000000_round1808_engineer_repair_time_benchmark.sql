BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_repair_time_benchmarks_r1808 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  avg_repair_minutes int NOT NULL DEFAULT 0,
  peer_median_minutes int NOT NULL DEFAULT 0,
  deviation_pct numeric(8,2) NOT NULL DEFAULT 0,
  sample_size int NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'at_peer' CHECK (status IN ('faster','at_peer','slower','critically_slow')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_repair_time_coaching_r1808 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  benchmark_id uuid NOT NULL REFERENCES public.engineer_repair_time_benchmarks_r1808(id) ON DELETE CASCADE,
  coaching_action text NOT NULL CHECK (coaching_action IN ('shadowing','training','tooling','mentor_assignment','pip')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  follow_up_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ertb_r1808_engineer ON public.engineer_repair_time_benchmarks_r1808(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ertb_r1808_category ON public.engineer_repair_time_benchmarks_r1808(equipment_category);
CREATE INDEX IF NOT EXISTS idx_ertb_r1808_status ON public.engineer_repair_time_benchmarks_r1808(status);
CREATE INDEX IF NOT EXISTS idx_ertc_r1808_bench ON public.engineer_repair_time_coaching_r1808(benchmark_id);

ALTER TABLE public.engineer_repair_time_benchmarks_r1808 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_repair_time_coaching_r1808 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ertb_r1808 ON public.engineer_repair_time_benchmarks_r1808;
CREATE POLICY founder_all_ertb_r1808 ON public.engineer_repair_time_benchmarks_r1808
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ertc_r1808 ON public.engineer_repair_time_coaching_r1808;
CREATE POLICY founder_all_ertc_r1808 ON public.engineer_repair_time_coaching_r1808
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_benchmarks
CREATE OR REPLACE FUNCTION public.list_benchmarks_r1808(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_category text,
  avg_repair_minutes int,
  peer_median_minutes int,
  deviation_pct numeric,
  sample_size int,
  status text,
  recorded_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, p.email,
         b.equipment_category, b.avg_repair_minutes, b.peer_median_minutes,
         b.deviation_pct, b.sample_size, b.status, b.recorded_at
  FROM public.engineer_repair_time_benchmarks_r1808 b
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  ORDER BY b.recorded_at DESC
  LIMIT COALESCE(p_limit, 200);
END; $$;

-- 2. refresh_benchmark
CREATE OR REPLACE FUNCTION public.refresh_benchmark_r1808(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_avg_minutes int,
  p_peer_median int,
  p_sample int
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_dev numeric;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_peer_median > 0 THEN
    v_dev := ROUND(((p_avg_minutes - p_peer_median)::numeric / p_peer_median) * 100, 2);
  ELSE
    v_dev := 0;
  END IF;
  v_status := CASE
    WHEN v_dev <= -10 THEN 'faster'
    WHEN v_dev < 10 THEN 'at_peer'
    WHEN v_dev < 50 THEN 'slower'
    ELSE 'critically_slow'
  END;
  INSERT INTO public.engineer_repair_time_benchmarks_r1808(
    engineer_user_id, equipment_category, avg_repair_minutes,
    peer_median_minutes, deviation_pct, sample_size, status
  ) VALUES (
    p_engineer_user_id, p_equipment_category, p_avg_minutes,
    p_peer_median, v_dev, p_sample, v_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_benchmark_r1808',
    jsonb_build_object('benchmark_id', v_id, 'engineer', p_engineer_user_id, 'status', v_status));
  RETURN v_id;
END; $$;

-- 3. list_coaching
CREATE OR REPLACE FUNCTION public.list_coaching_r1808(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  benchmark_id uuid,
  engineer_email text,
  equipment_category text,
  coaching_action text,
  taken_at timestamptz,
  by_email text,
  follow_up_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.benchmark_id, p.email, b.equipment_category,
         c.coaching_action, c.taken_at, c.by_email, c.follow_up_date
  FROM public.engineer_repair_time_coaching_r1808 c
  LEFT JOIN public.engineer_repair_time_benchmarks_r1808 b ON b.id = c.benchmark_id
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  ORDER BY c.taken_at DESC
  LIMIT COALESCE(p_limit, 200);
END; $$;

-- 4. log_coaching
CREATE OR REPLACE FUNCTION public.log_coaching_r1808(
  p_benchmark_id uuid,
  p_action text,
  p_follow_up date DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_repair_time_coaching_r1808(
    benchmark_id, coaching_action, by_email, follow_up_date, notes
  ) VALUES (
    p_benchmark_id, p_action, v_email, p_follow_up, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_coaching_r1808',
    jsonb_build_object('coaching_id', v_id, 'benchmark_id', p_benchmark_id, 'action', p_action));
  RETURN v_id;
END; $$;

-- 5. slowest_engineers
CREATE OR REPLACE FUNCTION public.slowest_engineers_r1808(p_limit int DEFAULT 20)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  avg_deviation_pct numeric,
  benchmark_count int,
  critical_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.engineer_user_id, p.email,
         ROUND(AVG(b.deviation_pct), 2) AS avg_deviation_pct,
         COUNT(*)::int AS benchmark_count,
         (COUNT(*) FILTER (WHERE b.status = 'critically_slow'))::int AS critical_count
  FROM public.engineer_repair_time_benchmarks_r1808 b
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, p.email
  ORDER BY avg_deviation_pct DESC NULLS LAST
  LIMIT COALESCE(p_limit, 20);
END; $$;

-- 6. fastest_engineers
CREATE OR REPLACE FUNCTION public.fastest_engineers_r1808(p_limit int DEFAULT 20)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  avg_deviation_pct numeric,
  benchmark_count int,
  faster_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.engineer_user_id, p.email,
         ROUND(AVG(b.deviation_pct), 2) AS avg_deviation_pct,
         COUNT(*)::int AS benchmark_count,
         (COUNT(*) FILTER (WHERE b.status = 'faster'))::int AS faster_count
  FROM public.engineer_repair_time_benchmarks_r1808 b
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  GROUP BY b.engineer_user_id, p.email
  ORDER BY avg_deviation_pct ASC NULLS LAST
  LIMIT COALESCE(p_limit, 20);
END; $$;

-- 7. category_average_speed
CREATE OR REPLACE FUNCTION public.category_average_speed_r1808()
RETURNS TABLE(
  equipment_category text,
  category_avg_minutes numeric,
  category_median_minutes numeric,
  engineer_count int,
  total_samples int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.equipment_category,
         ROUND(AVG(b.avg_repair_minutes)::numeric, 2) AS category_avg_minutes,
         ROUND(AVG(b.peer_median_minutes)::numeric, 2) AS category_median_minutes,
         COUNT(DISTINCT b.engineer_user_id)::int AS engineer_count,
         COALESCE(SUM(b.sample_size), 0)::int AS total_samples
  FROM public.engineer_repair_time_benchmarks_r1808 b
  GROUP BY b.equipment_category
  ORDER BY category_avg_minutes DESC NULLS LAST;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_benchmarks_r1808(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_benchmark_r1808(uuid, text, int, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_coaching_r1808(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_coaching_r1808(uuid, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.slowest_engineers_r1808(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fastest_engineers_r1808(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.category_average_speed_r1808() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_benchmarks_r1808(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_benchmark_r1808(uuid, text, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_coaching_r1808(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_coaching_r1808(uuid, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.slowest_engineers_r1808(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fastest_engineers_r1808(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.category_average_speed_r1808() TO authenticated;

COMMIT;