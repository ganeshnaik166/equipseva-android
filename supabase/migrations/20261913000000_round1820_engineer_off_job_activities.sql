BEGIN;

-- =============================================================================
-- Round 1820: Engineer Off-Job Activities
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.engineer_off_job_activities_r1820 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_date date NOT NULL DEFAULT CURRENT_DATE,
  activity_type text NOT NULL CHECK (activity_type IN ('admin','training','inventory','customer_relationship','team_meeting','personal_dev')),
  duration_minutes int NOT NULL CHECK (duration_minutes >= 0),
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','approved','disputed')),
  approved_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eoja_r1820_engineer ON public.engineer_off_job_activities_r1820(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eoja_r1820_activity_date ON public.engineer_off_job_activities_r1820(activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_eoja_r1820_status ON public.engineer_off_job_activities_r1820(status);
CREATE INDEX IF NOT EXISTS idx_eoja_r1820_type ON public.engineer_off_job_activities_r1820(activity_type);

CREATE TABLE IF NOT EXISTS public.engineer_off_job_summary_r1820 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_off_job_minutes int NOT NULL DEFAULT 0,
  total_job_minutes int NOT NULL DEFAULT 0,
  off_job_ratio_pct numeric NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eojs_r1820_engineer ON public.engineer_off_job_summary_r1820(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eojs_r1820_period ON public.engineer_off_job_summary_r1820(period_start DESC, period_end DESC);

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

ALTER TABLE public.engineer_off_job_activities_r1820 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_off_job_summary_r1820 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_eoja_r1820_founder ON public.engineer_off_job_activities_r1820;
CREATE POLICY p_eoja_r1820_founder ON public.engineer_off_job_activities_r1820
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_eojs_r1820_founder ON public.engineer_off_job_summary_r1820;
CREATE POLICY p_eojs_r1820_founder ON public.engineer_off_job_summary_r1820
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -----------------------------------------------------------------------------
-- RPCs
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_off_job_activities_r1820()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  activity_date date,
  activity_type text,
  duration_minutes int,
  status text,
  approved_by_email text,
  created_at timestamptz
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
  SELECT a.id, a.engineer_user_id, p.email, a.activity_date, a.activity_type,
         a.duration_minutes, a.status, a.approved_by_email, a.created_at
  FROM public.engineer_off_job_activities_r1820 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  ORDER BY a.activity_date DESC, a.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_off_job_activity_r1820(
  p_engineer_user_id uuid,
  p_activity_type text,
  p_duration_minutes int,
  p_activity_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_off_job_activities_r1820(
    engineer_user_id, activity_type, duration_minutes, activity_date
  ) VALUES (
    p_engineer_user_id, p_activity_type, p_duration_minutes, COALESCE(p_activity_date, CURRENT_DATE)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_off_job_activity_r1820',
          jsonb_build_object('activity_id', v_id, 'engineer_user_id', p_engineer_user_id, 'duration_minutes', p_duration_minutes, 'activity_type', p_activity_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_off_job_summaries_r1820()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  period_start date,
  period_end date,
  total_off_job_minutes int,
  total_job_minutes int,
  off_job_ratio_pct numeric,
  recorded_at timestamptz
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
  SELECT s.id, s.engineer_user_id, p.email, s.period_start, s.period_end,
         s.total_off_job_minutes, s.total_job_minutes, s.off_job_ratio_pct, s.recorded_at
  FROM public.engineer_off_job_summary_r1820 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.recorded_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_off_job_summary_r1820(
  p_engineer_user_id uuid,
  p_period_start date,
  p_period_end date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_off_min int;
  v_job_min int;
  v_ratio numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(duration_minutes),0)::int INTO v_off_min
  FROM public.engineer_off_job_activities_r1820
  WHERE engineer_user_id = p_engineer_user_id
    AND activity_date >= p_period_start
    AND activity_date <= p_period_end;

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (rj.completed_at - rj.created_at))/60),0)::int INTO v_job_min
  FROM public.repair_jobs rj
  JOIN public.engineers e ON e.id = rj.engineer_id
  WHERE e.user_id = p_engineer_user_id
    AND rj.completed_at IS NOT NULL
    AND rj.completed_at::date >= p_period_start
    AND rj.completed_at::date <= p_period_end;

  v_ratio := CASE WHEN (v_off_min + v_job_min) > 0
                  THEN ROUND((v_off_min::numeric / (v_off_min + v_job_min)::numeric) * 100, 2)
                  ELSE 0 END;

  INSERT INTO public.engineer_off_job_summary_r1820(
    engineer_user_id, period_start, period_end, total_off_job_minutes, total_job_minutes, off_job_ratio_pct
  ) VALUES (
    p_engineer_user_id, p_period_start, p_period_end, v_off_min, v_job_min, v_ratio
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_off_job_summary_r1820',
          jsonb_build_object('summary_id', v_id, 'engineer_user_id', p_engineer_user_id, 'off_job_ratio_pct', v_ratio));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_off_job_activity_r1820(p_activity_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := COALESCE(auth.jwt()->>'email','unknown');

  UPDATE public.engineer_off_job_activities_r1820
  SET status = 'approved',
      approved_by_email = v_email,
      updated_at = now()
  WHERE id = p_activity_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'approve_off_job_activity_r1820',
          jsonb_build_object('activity_id', p_activity_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_off_job_engineers_r1820()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  activity_count int,
  total_minutes bigint,
  approved_count int
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
  SELECT a.engineer_user_id,
         p.email,
         COUNT(*)::int AS activity_count,
         COALESCE(SUM(a.duration_minutes),0)::bigint AS total_minutes,
         (COUNT(*) FILTER (WHERE a.status = 'approved'))::int AS approved_count
  FROM public.engineer_off_job_activities_r1820 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  GROUP BY a.engineer_user_id, p.email
  ORDER BY total_minutes DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.off_job_activity_distribution_r1820()
RETURNS TABLE(
  activity_type text,
  activity_count int,
  total_minutes bigint,
  approved_count int,
  disputed_count int
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
  SELECT a.activity_type,
         COUNT(*)::int AS activity_count,
         COALESCE(SUM(a.duration_minutes),0)::bigint AS total_minutes,
         (COUNT(*) FILTER (WHERE a.status = 'approved'))::int AS approved_count,
         (COUNT(*) FILTER (WHERE a.status = 'disputed'))::int AS disputed_count
  FROM public.engineer_off_job_activities_r1820 a
  GROUP BY a.activity_type
  ORDER BY total_minutes DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_off_job_activities_r1820() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_off_job_activities_r1820() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_off_job_activity_r1820(uuid, text, int, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_off_job_activity_r1820(uuid, text, int, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_off_job_summaries_r1820() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_off_job_summaries_r1820() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.refresh_off_job_summary_r1820(uuid, date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.refresh_off_job_summary_r1820(uuid, date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.approve_off_job_activity_r1820(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.approve_off_job_activity_r1820(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_off_job_engineers_r1820() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_off_job_engineers_r1820() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.off_job_activity_distribution_r1820() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.off_job_activity_distribution_r1820() TO authenticated;

COMMIT;