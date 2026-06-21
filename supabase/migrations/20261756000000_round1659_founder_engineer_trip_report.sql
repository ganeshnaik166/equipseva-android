BEGIN;

-- Engineer trip reports — logged after each site visit
CREATE TABLE IF NOT EXISTS public.engineer_trip_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  visit_date date NOT NULL DEFAULT CURRENT_DATE,
  distance_km numeric(8,2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
  time_on_site_minutes int NOT NULL DEFAULT 0 CHECK (time_on_site_minutes >= 0),
  travel_minutes int NOT NULL DEFAULT 0 CHECK (travel_minutes >= 0),
  hospital_interaction_notes text,
  interaction_rating int CHECK (interaction_rating BETWEEN 1 AND 5),
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_due_date date,
  follow_up_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etr_engineer_date ON public.engineer_trip_reports(engineer_user_id, visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_etr_hospital ON public.engineer_trip_reports(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_etr_follow_up ON public.engineer_trip_reports(follow_up_due_date) WHERE follow_up_required = true;

ALTER TABLE public.engineer_trip_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS etr_founder_all ON public.engineer_trip_reports;
CREATE POLICY etr_founder_all ON public.engineer_trip_reports
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Helper: log founder action
DROP FUNCTION IF EXISTS public.log_founder_trip_report_action(text, jsonb);
CREATE OR REPLACE FUNCTION public.log_founder_trip_report_action(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_trip_report_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_trip_report_action(text, jsonb) TO authenticated;

-- RPC 1: recent trip reports
DROP FUNCTION IF EXISTS public.founder_engineer_trip_report_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_report_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  visit_date date,
  engineer_user_id uuid,
  engineer_name text,
  hospital_org_id uuid,
  hospital_name text,
  distance_km numeric,
  time_on_site_minutes int,
  travel_minutes int,
  interaction_rating int,
  follow_up_required boolean,
  follow_up_due_date date,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT etr.id,
         etr.visit_date,
         etr.engineer_user_id,
         p.full_name,
         etr.hospital_org_id,
         o.name,
         etr.distance_km,
         etr.time_on_site_minutes,
         etr.travel_minutes,
         etr.interaction_rating,
         etr.follow_up_required,
         etr.follow_up_due_date,
         etr.created_at
  FROM public.engineer_trip_reports etr
  LEFT JOIN public.profiles p ON p.id = etr.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = etr.hospital_org_id
  ORDER BY etr.visit_date DESC, etr.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_report_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_report_recent(int) TO authenticated;

-- RPC 2: per-engineer trip-frequency rollup (90 day window)
DROP FUNCTION IF EXISTS public.founder_engineer_trip_frequency_rollup(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_frequency_rollup(p_days int DEFAULT 90)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_name text,
  tier text,
  total_trips int,
  trips_last_7d int,
  trips_last_30d int,
  total_distance_km numeric,
  avg_distance_km numeric,
  total_on_site_hours numeric,
  avg_on_site_minutes numeric,
  follow_ups_open int,
  avg_interaction_rating numeric,
  last_visit_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT etr.engineer_user_id,
         p.full_name,
         e.cached_highest_tier,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 7))::int,
         (COUNT(*) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30))::int,
         COALESCE(SUM(etr.distance_km), 0)::numeric,
         COALESCE(AVG(etr.distance_km), 0)::numeric,
         ROUND((COALESCE(SUM(etr.time_on_site_minutes), 0) / 60.0)::numeric, 2),
         COALESCE(AVG(etr.time_on_site_minutes), 0)::numeric,
         (COUNT(*) FILTER (WHERE etr.follow_up_required AND (etr.follow_up_due_date IS NULL OR etr.follow_up_due_date >= CURRENT_DATE)))::int,
         AVG(etr.interaction_rating)::numeric,
         MAX(etr.visit_date)
  FROM public.engineer_trip_reports etr
  LEFT JOIN public.profiles p ON p.id = etr.engineer_user_id
  LEFT JOIN public.engineers e ON e.user_id = etr.engineer_user_id
  WHERE etr.visit_date >= CURRENT_DATE - GREATEST(p_days, 1)
  GROUP BY etr.engineer_user_id, p.full_name, e.cached_highest_tier
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_frequency_rollup(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_frequency_rollup(int) TO authenticated;

-- RPC 3: pending follow-ups
DROP FUNCTION IF EXISTS public.founder_engineer_trip_followups_pending();
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_followups_pending()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  hospital_name text,
  visit_date date,
  follow_up_due_date date,
  days_until_due int,
  follow_up_notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT etr.id,
         etr.engineer_user_id,
         p.full_name,
         o.name,
         etr.visit_date,
         etr.follow_up_due_date,
         CASE WHEN etr.follow_up_due_date IS NULL THEN NULL
              ELSE (etr.follow_up_due_date - CURRENT_DATE)::int END,
         etr.follow_up_notes
  FROM public.engineer_trip_reports etr
  LEFT JOIN public.profiles p ON p.id = etr.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = etr.hospital_org_id
  WHERE etr.follow_up_required = true
  ORDER BY COALESCE(etr.follow_up_due_date, etr.visit_date) ASC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_followups_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_followups_pending() TO authenticated;

-- RPC 4: hospital-level interaction rollup
DROP FUNCTION IF EXISTS public.founder_engineer_trip_by_hospital(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_by_hospital(p_days int DEFAULT 90)
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  state text,
  total_visits int,
  distinct_engineers int,
  total_on_site_hours numeric,
  avg_interaction_rating numeric,
  last_visit_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT etr.hospital_org_id,
         o.name,
         o.state,
         COUNT(*)::int,
         COUNT(DISTINCT etr.engineer_user_id)::int,
         ROUND((COALESCE(SUM(etr.time_on_site_minutes), 0) / 60.0)::numeric, 2),
         AVG(etr.interaction_rating)::numeric,
         MAX(etr.visit_date)
  FROM public.engineer_trip_reports etr
  LEFT JOIN public.organizations o ON o.id = etr.hospital_org_id
  WHERE etr.visit_date >= CURRENT_DATE - GREATEST(p_days, 1)
    AND etr.hospital_org_id IS NOT NULL
  GROUP BY etr.hospital_org_id, o.name, o.state
  ORDER BY COUNT(*) DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_by_hospital(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_by_hospital(int) TO authenticated;

-- RPC 5: dashboard KPIs
DROP FUNCTION IF EXISTS public.founder_engineer_trip_kpis();
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_kpis()
RETURNS TABLE (
  trips_7d int,
  trips_30d int,
  trips_90d int,
  active_engineers_30d int,
  total_distance_km_30d numeric,
  total_on_site_hours_30d numeric,
  open_follow_ups int,
  overdue_follow_ups int,
  avg_rating_30d numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 7))::int,
    (COUNT(*) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30))::int,
    (COUNT(*) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 90))::int,
    COUNT(DISTINCT etr.engineer_user_id) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30)::int,
    COALESCE(SUM(etr.distance_km) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30), 0)::numeric,
    ROUND((COALESCE(SUM(etr.time_on_site_minutes) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30), 0) / 60.0)::numeric, 2),
    (COUNT(*) FILTER (WHERE etr.follow_up_required AND (etr.follow_up_due_date IS NULL OR etr.follow_up_due_date >= CURRENT_DATE)))::int,
    (COUNT(*) FILTER (WHERE etr.follow_up_required AND etr.follow_up_due_date IS NOT NULL AND etr.follow_up_due_date < CURRENT_DATE))::int,
    AVG(etr.interaction_rating) FILTER (WHERE etr.visit_date >= CURRENT_DATE - 30)::numeric
  FROM public.engineer_trip_reports etr;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_kpis() TO authenticated;

-- RPC 6: daily volume sparkline (last 30 days)
DROP FUNCTION IF EXISTS public.founder_engineer_trip_daily_series(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_daily_series(p_days int DEFAULT 30)
RETURNS TABLE (
  day date,
  trips int,
  distance_km numeric,
  on_site_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT etr.visit_date,
         COUNT(*)::int,
         COALESCE(SUM(etr.distance_km), 0)::numeric,
         ROUND((COALESCE(SUM(etr.time_on_site_minutes), 0) / 60.0)::numeric, 2)
  FROM public.engineer_trip_reports etr
  WHERE etr.visit_date >= CURRENT_DATE - GREATEST(p_days, 1)
  GROUP BY etr.visit_date
  ORDER BY etr.visit_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_daily_series(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_daily_series(int) TO authenticated;

-- RPC 7: write — log a trip report (founder-side seeding / corrections)
DROP FUNCTION IF EXISTS public.founder_engineer_trip_report_log(uuid, uuid, uuid, date, numeric, int, int, text, int, boolean, date, text);
CREATE OR REPLACE FUNCTION public.founder_engineer_trip_report_log(
  p_engineer_user_id uuid,
  p_hospital_org_id uuid,
  p_repair_job_id uuid,
  p_visit_date date,
  p_distance_km numeric,
  p_time_on_site_minutes int,
  p_travel_minutes int,
  p_interaction_notes text,
  p_interaction_rating int,
  p_follow_up_required boolean,
  p_follow_up_due_date date,
  p_follow_up_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_trip_reports(
    engineer_user_id, hospital_org_id, repair_job_id, visit_date,
    distance_km, time_on_site_minutes, travel_minutes,
    hospital_interaction_notes, interaction_rating,
    follow_up_required, follow_up_due_date, follow_up_notes
  ) VALUES (
    p_engineer_user_id, p_hospital_org_id, p_repair_job_id, COALESCE(p_visit_date, CURRENT_DATE),
    COALESCE(p_distance_km, 0), COALESCE(p_time_on_site_minutes, 0), COALESCE(p_travel_minutes, 0),
    p_interaction_notes, p_interaction_rating,
    COALESCE(p_follow_up_required, false), p_follow_up_due_date, p_follow_up_notes
  )
  RETURNING id INTO v_id;

  PERFORM public.log_founder_trip_report_action(
    'engineer_trip_report_log',
    jsonb_build_object(
      'id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'hospital_org_id', p_hospital_org_id,
      'visit_date', p_visit_date,
      'distance_km', p_distance_km,
      'time_on_site_minutes', p_time_on_site_minutes
    )
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_trip_report_log(uuid, uuid, uuid, date, numeric, int, int, text, int, boolean, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_trip_report_log(uuid, uuid, uuid, date, numeric, int, int, text, int, boolean, date, text) TO authenticated;

COMMIT;