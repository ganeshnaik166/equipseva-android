BEGIN;

-- ============================================================
-- r1578 Founder · Engineer Rural Deployment Tracker
-- Tracks engineers willing to serve rural/remote areas,
-- their stipend + travel allowance, per-trip outcomes,
-- and underserved district coverage.
-- ============================================================

-- Engineer-level rural deployment enrollment
CREATE TABLE IF NOT EXISTS founder_rural_engineer_enrollments_v4 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  willing boolean NOT NULL DEFAULT true,
  home_state text,
  preferred_states text[] NOT NULL DEFAULT '{}',
  preferred_districts text[] NOT NULL DEFAULT '{}',
  max_travel_km integer NOT NULL DEFAULT 250 CHECK (max_travel_km >= 0),
  monthly_stipend_rupees integer NOT NULL DEFAULT 0 CHECK (monthly_stipend_rupees >= 0),
  per_km_allowance_paise integer NOT NULL DEFAULT 800 CHECK (per_km_allowance_paise >= 0),
  per_diem_rupees integer NOT NULL DEFAULT 0 CHECK (per_diem_rupees >= 0),
  vehicle_type text CHECK (vehicle_type IN ('two_wheeler','four_wheeler','public_transport','none')),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  paused_at timestamptz,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_frenr_v4_engineer ON founder_rural_engineer_enrollments_v4(engineer_id);
CREATE INDEX IF NOT EXISTS idx_frenr_v4_willing ON founder_rural_engineer_enrollments_v4(willing) WHERE paused_at IS NULL;

ALTER TABLE founder_rural_engineer_enrollments_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_frenr_v4_founder_all ON founder_rural_engineer_enrollments_v4;
CREATE POLICY p_frenr_v4_founder_all ON founder_rural_engineer_enrollments_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Per-trip rural deployment log
CREATE TABLE IF NOT EXISTS founder_rural_trips_v4 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  trip_state text NOT NULL,
  trip_district text NOT NULL,
  trip_pincode text,
  distance_km numeric(8,2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
  departed_at timestamptz NOT NULL DEFAULT now(),
  returned_at timestamptz,
  jobs_completed integer NOT NULL DEFAULT 0 CHECK (jobs_completed >= 0),
  jobs_attempted integer NOT NULL DEFAULT 0 CHECK (jobs_attempted >= 0),
  hospitals_visited integer NOT NULL DEFAULT 0 CHECK (hospitals_visited >= 0),
  travel_cost_rupees integer NOT NULL DEFAULT 0 CHECK (travel_cost_rupees >= 0),
  per_diem_paid_rupees integer NOT NULL DEFAULT 0 CHECK (per_diem_paid_rupees >= 0),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','successful','partial','failed','cancelled')),
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_frt_v4_engineer ON founder_rural_trips_v4(engineer_id);
CREATE INDEX IF NOT EXISTS idx_frt_v4_district ON founder_rural_trips_v4(trip_state, trip_district);
CREATE INDEX IF NOT EXISTS idx_frt_v4_departed ON founder_rural_trips_v4(departed_at DESC);
CREATE INDEX IF NOT EXISTS idx_frt_v4_outcome ON founder_rural_trips_v4(outcome);

ALTER TABLE founder_rural_trips_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_frt_v4_founder_all ON founder_rural_trips_v4;
CREATE POLICY p_frt_v4_founder_all ON founder_rural_trips_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

DROP FUNCTION IF EXISTS founder_rural_overview_kpis_v4();
CREATE OR REPLACE FUNCTION founder_rural_overview_kpis_v4()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_enrolled integer;
  v_active_enrolled integer;
  v_total_trips integer;
  v_successful_trips integer;
  v_partial_trips integer;
  v_failed_trips integer;
  v_pending_trips integer;
  v_total_km numeric;
  v_total_travel_cost integer;
  v_total_per_diem integer;
  v_monthly_stipend_outflow integer;
  v_jobs_completed integer;
  v_jobs_attempted integer;
  v_distinct_districts integer;
  v_distinct_states integer;
  v_avg_km_per_trip numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*), count(*) FILTER (WHERE willing AND paused_at IS NULL)
    INTO v_total_enrolled, v_active_enrolled
    FROM founder_rural_engineer_enrollments_v4;

  SELECT coalesce(sum(monthly_stipend_rupees),0)
    INTO v_monthly_stipend_outflow
    FROM founder_rural_engineer_enrollments_v4
    WHERE willing AND paused_at IS NULL;

  SELECT
    count(*),
    count(*) FILTER (WHERE outcome='successful'),
    count(*) FILTER (WHERE outcome='partial'),
    count(*) FILTER (WHERE outcome='failed'),
    count(*) FILTER (WHERE outcome='pending'),
    coalesce(sum(distance_km),0),
    coalesce(sum(travel_cost_rupees),0),
    coalesce(sum(per_diem_paid_rupees),0),
    coalesce(sum(jobs_completed),0),
    coalesce(sum(jobs_attempted),0),
    coalesce(avg(distance_km),0)
    INTO v_total_trips, v_successful_trips, v_partial_trips, v_failed_trips, v_pending_trips,
         v_total_km, v_total_travel_cost, v_total_per_diem, v_jobs_completed, v_jobs_attempted, v_avg_km_per_trip
    FROM founder_rural_trips_v4;

  SELECT count(DISTINCT (trip_state || '|' || trip_district)),
         count(DISTINCT trip_state)
    INTO v_distinct_districts, v_distinct_states
    FROM founder_rural_trips_v4;

  RETURN jsonb_build_object(
    'total_enrolled', coalesce(v_total_enrolled,0),
    'active_enrolled', coalesce(v_active_enrolled,0),
    'total_trips', coalesce(v_total_trips,0),
    'successful_trips', coalesce(v_successful_trips,0),
    'partial_trips', coalesce(v_partial_trips,0),
    'failed_trips', coalesce(v_failed_trips,0),
    'pending_trips', coalesce(v_pending_trips,0),
    'total_km', coalesce(v_total_km,0),
    'total_travel_cost_rupees', coalesce(v_total_travel_cost,0),
    'total_per_diem_rupees', coalesce(v_total_per_diem,0),
    'monthly_stipend_outflow_rupees', coalesce(v_monthly_stipend_outflow,0),
    'jobs_completed', coalesce(v_jobs_completed,0),
    'jobs_attempted', coalesce(v_jobs_attempted,0),
    'distinct_districts', coalesce(v_distinct_districts,0),
    'distinct_states', coalesce(v_distinct_states,0),
    'avg_km_per_trip', coalesce(v_avg_km_per_trip,0)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_overview_kpis_v4() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_overview_kpis_v4() TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_enrollments_list_v4(integer);
CREATE OR REPLACE FUNCTION founder_rural_enrollments_list_v4(p_limit integer DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  cached_highest_tier text,
  willing boolean,
  home_state text,
  preferred_states_count integer,
  preferred_districts_count integer,
  max_travel_km integer,
  monthly_stipend_rupees integer,
  per_km_allowance_paise integer,
  per_diem_rupees integer,
  vehicle_type text,
  enrolled_at timestamptz,
  paused_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.engineer_id,
      coalesce(p.full_name,'(unknown)') AS engineer_name,
      eng.cached_highest_tier,
      e.willing,
      e.home_state,
      coalesce(array_length(e.preferred_states,1),0),
      coalesce(array_length(e.preferred_districts,1),0),
      e.max_travel_km,
      e.monthly_stipend_rupees,
      e.per_km_allowance_paise,
      e.per_diem_rupees,
      e.vehicle_type,
      e.enrolled_at,
      e.paused_at
    FROM founder_rural_engineer_enrollments_v4 e
    JOIN engineers eng ON eng.id = e.engineer_id
    LEFT JOIN profiles p ON p.id = eng.user_id
    ORDER BY e.enrolled_at DESC
    LIMIT greatest(coalesce(p_limit,100), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_enrollments_list_v4(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_enrollments_list_v4(integer) TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_trips_recent_v4(integer);
CREATE OR REPLACE FUNCTION founder_rural_trips_recent_v4(p_limit integer DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  trip_state text,
  trip_district text,
  trip_pincode text,
  distance_km numeric,
  departed_at timestamptz,
  returned_at timestamptz,
  duration_days numeric,
  jobs_completed integer,
  jobs_attempted integer,
  hospitals_visited integer,
  travel_cost_rupees integer,
  per_diem_paid_rupees integer,
  outcome text,
  outcome_notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.id,
      t.engineer_id,
      coalesce(p.full_name,'(unknown)') AS engineer_name,
      t.trip_state,
      t.trip_district,
      t.trip_pincode,
      t.distance_km,
      t.departed_at,
      t.returned_at,
      CASE WHEN t.returned_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.returned_at - t.departed_at))/86400.0
        ELSE NULL END,
      t.jobs_completed,
      t.jobs_attempted,
      t.hospitals_visited,
      t.travel_cost_rupees,
      t.per_diem_paid_rupees,
      t.outcome,
      t.outcome_notes
    FROM founder_rural_trips_v4 t
    JOIN engineers eng ON eng.id = t.engineer_id
    LEFT JOIN profiles p ON p.id = eng.user_id
    ORDER BY t.departed_at DESC
    LIMIT greatest(coalesce(p_limit,100), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_trips_recent_v4(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_trips_recent_v4(integer) TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_district_coverage_v4();
CREATE OR REPLACE FUNCTION founder_rural_district_coverage_v4()
RETURNS TABLE(
  trip_state text,
  trip_district text,
  trip_count integer,
  successful_count integer,
  unique_engineers integer,
  total_km numeric,
  total_travel_cost_rupees bigint,
  jobs_completed integer,
  last_visit_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.trip_state,
      t.trip_district,
      count(*)::integer,
      count(*) FILTER (WHERE t.outcome='successful')::integer,
      count(DISTINCT t.engineer_id)::integer,
      coalesce(sum(t.distance_km),0),
      coalesce(sum(t.travel_cost_rupees),0)::bigint,
      coalesce(sum(t.jobs_completed),0)::integer,
      max(t.departed_at)
    FROM founder_rural_trips_v4 t
    GROUP BY t.trip_state, t.trip_district
    ORDER BY count(*) DESC, max(t.departed_at) DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_district_coverage_v4() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_district_coverage_v4() TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_engineer_scoreboard_v4();
CREATE OR REPLACE FUNCTION founder_rural_engineer_scoreboard_v4()
RETURNS TABLE(
  engineer_id uuid,
  engineer_name text,
  trip_count integer,
  successful_count integer,
  total_km numeric,
  jobs_completed integer,
  travel_cost_rupees bigint,
  per_diem_rupees bigint,
  distinct_districts integer,
  last_trip_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.engineer_id,
      coalesce(p.full_name,'(unknown)') AS engineer_name,
      count(*)::integer,
      count(*) FILTER (WHERE t.outcome='successful')::integer,
      coalesce(sum(t.distance_km),0),
      coalesce(sum(t.jobs_completed),0)::integer,
      coalesce(sum(t.travel_cost_rupees),0)::bigint,
      coalesce(sum(t.per_diem_paid_rupees),0)::bigint,
      count(DISTINCT (t.trip_state || '|' || t.trip_district))::integer,
      max(t.departed_at)
    FROM founder_rural_trips_v4 t
    JOIN engineers eng ON eng.id = t.engineer_id
    LEFT JOIN profiles p ON p.id = eng.user_id
    GROUP BY t.engineer_id, p.full_name
    ORDER BY count(*) DESC
    LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_engineer_scoreboard_v4() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_engineer_scoreboard_v4() TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_underserved_districts_v4();
CREATE OR REPLACE FUNCTION founder_rural_underserved_districts_v4()
RETURNS TABLE(
  state_name text,
  district text,
  trips integer,
  successful integer,
  last_visit_at timestamptz,
  days_since_visit numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.trip_state,
      t.trip_district,
      count(*)::integer,
      count(*) FILTER (WHERE t.outcome='successful')::integer,
      max(t.departed_at),
      EXTRACT(EPOCH FROM (now() - max(t.departed_at)))/86400.0
    FROM founder_rural_trips_v4 t
    GROUP BY t.trip_state, t.trip_district
    HAVING count(*) FILTER (WHERE t.outcome='successful') = 0
       OR max(t.departed_at) < now() - interval '90 days'
    ORDER BY max(t.departed_at) ASC NULLS FIRST
    LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_underserved_districts_v4() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_underserved_districts_v4() TO authenticated;

DROP FUNCTION IF EXISTS founder_rural_monthly_spend_v4();
CREATE OR REPLACE FUNCTION founder_rural_monthly_spend_v4()
RETURNS TABLE(
  month_start date,
  trip_count integer,
  total_km numeric,
  travel_cost_rupees bigint,
  per_diem_rupees bigint,
  combined_cost_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      date_trunc('month', t.departed_at)::date,
      count(*)::integer,
      coalesce(sum(t.distance_km),0),
      coalesce(sum(t.travel_cost_rupees),0)::bigint,
      coalesce(sum(t.per_diem_paid_rupees),0)::bigint,
      (coalesce(sum(t.travel_cost_rupees),0) + coalesce(sum(t.per_diem_paid_rupees),0))::bigint
    FROM founder_rural_trips_v4 t
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_rural_monthly_spend_v4() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_rural_monthly_spend_v4() TO authenticated;

-- ============================================================
-- WRITE / LOG helpers (VOLATILE)
-- ============================================================

DROP FUNCTION IF EXISTS log_founder_rural_enroll_engineer_v4(uuid, integer, integer, integer, text, text, text[], text[], integer);
CREATE OR REPLACE FUNCTION log_founder_rural_enroll_engineer_v4(
  p_engineer_id uuid,
  p_monthly_stipend_rupees integer,
  p_per_km_allowance_paise integer,
  p_per_diem_rupees integer,
  p_vehicle_type text,
  p_home_state text,
  p_preferred_states text[],
  p_preferred_districts text[],
  p_max_travel_km integer
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
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_rural_engineer_enrollments_v4(
    engineer_id, monthly_stipend_rupees, per_km_allowance_paise, per_diem_rupees,
    vehicle_type, home_state, preferred_states, preferred_districts, max_travel_km
  )
  VALUES (
    p_engineer_id, coalesce(p_monthly_stipend_rupees,0), coalesce(p_per_km_allowance_paise,800),
    coalesce(p_per_diem_rupees,0), p_vehicle_type, p_home_state,
    coalesce(p_preferred_states,'{}'), coalesce(p_preferred_districts,'{}'),
    coalesce(p_max_travel_km,250)
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'rural_enroll_engineer_v4',
    jsonb_build_object('enrollment_id', v_id, 'engineer_id', p_engineer_id, 'monthly_stipend_rupees', p_monthly_stipend_rupees)
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rural_enroll_engineer_v4(uuid, integer, integer, integer, text, text, text[], text[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rural_enroll_engineer_v4(uuid, integer, integer, integer, text, text, text[], text[], integer) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_rural_pause_enrollment_v4(uuid, boolean);
CREATE OR REPLACE FUNCTION log_founder_rural_pause_enrollment_v4(p_enrollment_id uuid, p_pause boolean)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_rural_engineer_enrollments_v4
    SET paused_at = CASE WHEN p_pause THEN now() ELSE NULL END,
        willing = NOT p_pause
    WHERE id = p_enrollment_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'rural_pause_enrollment_v4',
    jsonb_build_object('enrollment_id', p_enrollment_id, 'paused', p_pause)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rural_pause_enrollment_v4(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rural_pause_enrollment_v4(uuid, boolean) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_rural_log_trip_v4(uuid, text, text, text, numeric, integer, integer, integer, integer, integer, text, text);
CREATE OR REPLACE FUNCTION log_founder_rural_log_trip_v4(
  p_engineer_id uuid,
  p_trip_state text,
  p_trip_district text,
  p_trip_pincode text,
  p_distance_km numeric,
  p_jobs_completed integer,
  p_jobs_attempted integer,
  p_hospitals_visited integer,
  p_travel_cost_rupees integer,
  p_per_diem_paid_rupees integer,
  p_outcome text,
  p_outcome_notes text
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
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_rural_trips_v4(
    engineer_id, trip_state, trip_district, trip_pincode, distance_km,
    jobs_completed, jobs_attempted, hospitals_visited,
    travel_cost_rupees, per_diem_paid_rupees, outcome, outcome_notes
  )
  VALUES (
    p_engineer_id, p_trip_state, p_trip_district, p_trip_pincode, coalesce(p_distance_km,0),
    coalesce(p_jobs_completed,0), coalesce(p_jobs_attempted,0), coalesce(p_hospitals_visited,0),
    coalesce(p_travel_cost_rupees,0), coalesce(p_per_diem_paid_rupees,0),
    coalesce(p_outcome,'pending'), p_outcome_notes
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'rural_log_trip_v4',
    jsonb_build_object('trip_id', v_id, 'engineer_id', p_engineer_id, 'state', p_trip_state, 'district', p_trip_district, 'outcome', p_outcome)
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rural_log_trip_v4(uuid, text, text, text, numeric, integer, integer, integer, integer, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rural_log_trip_v4(uuid, text, text, text, numeric, integer, integer, integer, integer, integer, text, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_rural_close_trip_v4(uuid, text, text);
CREATE OR REPLACE FUNCTION log_founder_rural_close_trip_v4(p_trip_id uuid, p_outcome text, p_outcome_notes text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_rural_trips_v4
    SET outcome = coalesce(p_outcome, outcome),
        outcome_notes = coalesce(p_outcome_notes, outcome_notes),
        returned_at = coalesce(returned_at, now())
    WHERE id = p_trip_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'rural_close_trip_v4',
    jsonb_build_object('trip_id', p_trip_id, 'outcome', p_outcome)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_rural_close_trip_v4(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_rural_close_trip_v4(uuid, text, text) TO authenticated;

COMMIT;