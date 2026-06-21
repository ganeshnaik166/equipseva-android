BEGIN;

-- =============================================================================
-- r1623 — Founder Engineer Night-Shift Roster
-- Engineers willing to take emergency night-shift Code Red calls.
-- Rotation schedule, per-shift premium pay, coverage gaps.
-- =============================================================================

-- Table 1: engineer night-shift opt-ins (which engineers willing + premium rate)
CREATE TABLE IF NOT EXISTS engineer_night_shift_optins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  willing boolean NOT NULL DEFAULT true,
  premium_pay_per_shift_rupees integer NOT NULL DEFAULT 1500 CHECK (premium_pay_per_shift_rupees >= 0),
  max_shifts_per_week integer NOT NULL DEFAULT 3 CHECK (max_shifts_per_week BETWEEN 0 AND 7),
  preferred_start_hour smallint NOT NULL DEFAULT 22 CHECK (preferred_start_hour BETWEEN 0 AND 23),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_eng_night_optin_willing ON engineer_night_shift_optins(willing) WHERE willing = true;

ALTER TABLE engineer_night_shift_optins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_eng_night_optin_founder ON engineer_night_shift_optins;
CREATE POLICY p_eng_night_optin_founder ON engineer_night_shift_optins
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: scheduled night-shift roster (one row per engineer per night)
CREATE TABLE IF NOT EXISTS engineer_night_shift_roster (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_date date NOT NULL,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  region_state text,
  shift_start_at timestamptz NOT NULL,
  shift_end_at timestamptz NOT NULL,
  premium_pay_rupees integer NOT NULL DEFAULT 1500 CHECK (premium_pay_rupees >= 0),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','active','completed','cancelled','no_show')),
  code_red_calls_taken integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shift_date, engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_eng_night_roster_date ON engineer_night_shift_roster(shift_date DESC);
CREATE INDEX IF NOT EXISTS idx_eng_night_roster_engineer ON engineer_night_shift_roster(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eng_night_roster_state ON engineer_night_shift_roster(region_state);

ALTER TABLE engineer_night_shift_roster ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_eng_night_roster_founder ON engineer_night_shift_roster;
CREATE POLICY p_eng_night_roster_founder ON engineer_night_shift_roster
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =============================================================================
-- LOGGING HELPERS (VOLATILE SECDEF)
-- =============================================================================

CREATE OR REPLACE FUNCTION log_founder_night_shift_optin_set(p_engineer_id uuid, p_willing boolean, p_premium integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'night_shift_optin_set',
          jsonb_build_object('engineer_id', p_engineer_id, 'willing', p_willing, 'premium', p_premium), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_night_shift_optin_set(uuid, boolean, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_night_shift_optin_set(uuid, boolean, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_night_shift_scheduled(p_engineer_id uuid, p_shift_date date, p_state text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'night_shift_scheduled',
          jsonb_build_object('engineer_id', p_engineer_id, 'shift_date', p_shift_date, 'state', p_state), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_night_shift_scheduled(uuid, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_night_shift_scheduled(uuid, date, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_night_shift_cancelled(p_roster_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'night_shift_cancelled',
          jsonb_build_object('roster_id', p_roster_id, 'reason', p_reason), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_night_shift_cancelled(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_night_shift_cancelled(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_night_shift_gap_filled(p_shift_date date, p_state text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'night_shift_gap_filled',
          jsonb_build_object('shift_date', p_shift_date, 'state', p_state), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_night_shift_gap_filled(date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_night_shift_gap_filled(date, text) TO authenticated;

-- =============================================================================
-- READ RPCs (STABLE SECDEF)
-- =============================================================================

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION founder_night_shift_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_optins_total int;
  v_optins_willing int;
  v_avg_premium numeric;
  v_max_premium int;
  v_avg_max_shifts numeric;
  v_shifts_total int;
  v_shifts_tonight int;
  v_shifts_this_week int;
  v_shifts_completed int;
  v_shifts_cancelled int;
  v_shifts_no_show int;
  v_code_red_taken int;
  v_total_premium_paid bigint;
  v_states_covered int;
  v_avg_shifts_per_engineer numeric;
  v_top_engineer_shifts int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE willing), COALESCE(AVG(premium_pay_per_shift_rupees),0),
         COALESCE(MAX(premium_pay_per_shift_rupees),0), COALESCE(AVG(max_shifts_per_week),0)
    INTO v_optins_total, v_optins_willing, v_avg_premium, v_max_premium, v_avg_max_shifts
    FROM engineer_night_shift_optins;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE shift_date = CURRENT_DATE),
         COUNT(*) FILTER (WHERE shift_date >= CURRENT_DATE - 7),
         COUNT(*) FILTER (WHERE status = 'completed'),
         COUNT(*) FILTER (WHERE status = 'cancelled'),
         COUNT(*) FILTER (WHERE status = 'no_show'),
         COALESCE(SUM(code_red_calls_taken),0),
         COALESCE(SUM(premium_pay_rupees) FILTER (WHERE status = 'completed'),0)
    INTO v_shifts_total, v_shifts_tonight, v_shifts_this_week, v_shifts_completed,
         v_shifts_cancelled, v_shifts_no_show, v_code_red_taken, v_total_premium_paid
    FROM engineer_night_shift_roster;

  SELECT COUNT(DISTINCT region_state) INTO v_states_covered
    FROM engineer_night_shift_roster WHERE region_state IS NOT NULL;

  WITH per_eng AS (
    SELECT engineer_id, COUNT(*) AS c
      FROM engineer_night_shift_roster
      GROUP BY engineer_id
  )
  SELECT COALESCE(AVG(c),0), COALESCE(MAX(c),0)
    INTO v_avg_shifts_per_engineer, v_top_engineer_shifts
    FROM per_eng;

  v_result := jsonb_build_object(
    'optins_total', v_optins_total,
    'optins_willing', v_optins_willing,
    'avg_premium_rupees', ROUND(v_avg_premium, 0),
    'max_premium_rupees', v_max_premium,
    'avg_max_shifts_per_week', ROUND(v_avg_max_shifts, 1),
    'shifts_total', v_shifts_total,
    'shifts_tonight', v_shifts_tonight,
    'shifts_this_week', v_shifts_this_week,
    'shifts_completed', v_shifts_completed,
    'shifts_cancelled', v_shifts_cancelled,
    'shifts_no_show', v_shifts_no_show,
    'code_red_calls_taken', v_code_red_taken,
    'total_premium_paid_rupees', v_total_premium_paid,
    'states_covered', v_states_covered,
    'avg_shifts_per_engineer', ROUND(v_avg_shifts_per_engineer, 1),
    'top_engineer_shifts', v_top_engineer_shifts
  );
  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_kpis() TO authenticated;

-- RPC 2: opt-in roster (engineers willing + premium)
CREATE OR REPLACE FUNCTION founder_night_shift_optins_list()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  cached_highest_tier text,
  willing boolean,
  premium_pay_per_shift_rupees integer,
  max_shifts_per_week integer,
  preferred_start_hour smallint,
  notes text,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.engineer_id, p.email, e.cached_highest_tier,
           o.willing, o.premium_pay_per_shift_rupees, o.max_shifts_per_week,
           o.preferred_start_hour, o.notes, o.updated_at
      FROM engineer_night_shift_optins o
      JOIN engineers e ON e.id = o.engineer_id
      LEFT JOIN profiles p ON p.id = e.user_id
      ORDER BY o.willing DESC, o.premium_pay_per_shift_rupees ASC, o.updated_at DESC
      LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_optins_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_optins_list() TO authenticated;

-- RPC 3: upcoming roster (next 14 nights)
CREATE OR REPLACE FUNCTION founder_night_shift_upcoming()
RETURNS TABLE (
  id uuid,
  shift_date date,
  engineer_id uuid,
  engineer_email text,
  region_state text,
  shift_start_at timestamptz,
  shift_end_at timestamptz,
  premium_pay_rupees integer,
  status text,
  code_red_calls_taken integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.shift_date, r.engineer_id, p.email, r.region_state,
           r.shift_start_at, r.shift_end_at, r.premium_pay_rupees, r.status, r.code_red_calls_taken
      FROM engineer_night_shift_roster r
      JOIN engineers e ON e.id = r.engineer_id
      LEFT JOIN profiles p ON p.id = e.user_id
      WHERE r.shift_date >= CURRENT_DATE AND r.shift_date < CURRENT_DATE + 14
      ORDER BY r.shift_date ASC, r.region_state NULLS LAST
      LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_upcoming() TO authenticated;

-- RPC 4: recent history (last 30 nights)
CREATE OR REPLACE FUNCTION founder_night_shift_history()
RETURNS TABLE (
  id uuid,
  shift_date date,
  engineer_id uuid,
  engineer_email text,
  region_state text,
  premium_pay_rupees integer,
  status text,
  code_red_calls_taken integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.shift_date, r.engineer_id, p.email, r.region_state,
           r.premium_pay_rupees, r.status, r.code_red_calls_taken
      FROM engineer_night_shift_roster r
      JOIN engineers e ON e.id = r.engineer_id
      LEFT JOIN profiles p ON p.id = e.user_id
      WHERE r.shift_date < CURRENT_DATE AND r.shift_date >= CURRENT_DATE - 30
      ORDER BY r.shift_date DESC
      LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_history() TO authenticated;

-- RPC 5: coverage gaps (nights with 0 engineers scheduled by state, next 14 nights)
CREATE OR REPLACE FUNCTION founder_night_shift_coverage_gaps()
RETURNS TABLE (
  shift_date date,
  state text,
  engineers_scheduled int,
  is_gap boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH dates AS (
      SELECT generate_series(CURRENT_DATE, CURRENT_DATE + 13, INTERVAL '1 day')::date AS d
    ),
    states AS (
      SELECT DISTINCT region_state AS s FROM engineer_night_shift_roster WHERE region_state IS NOT NULL
      UNION
      SELECT 'TS' UNION SELECT 'AP' UNION SELECT 'KA' UNION SELECT 'TN' UNION SELECT 'MH'
    ),
    grid AS (
      SELECT d.d AS shift_date, s.s AS state FROM dates d CROSS JOIN states s
    ),
    scheduled AS (
      SELECT shift_date, region_state, COUNT(*)::int AS c
        FROM engineer_night_shift_roster
        WHERE shift_date >= CURRENT_DATE AND shift_date < CURRENT_DATE + 14
          AND status IN ('scheduled','active')
        GROUP BY shift_date, region_state
    )
    SELECT g.shift_date, g.state, COALESCE(s.c, 0) AS engineers_scheduled,
           (COALESCE(s.c, 0) = 0) AS is_gap
      FROM grid g
      LEFT JOIN scheduled s ON s.shift_date = g.shift_date AND s.region_state = g.state
      ORDER BY g.shift_date ASC, g.state ASC
      LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_coverage_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_coverage_gaps() TO authenticated;

-- RPC 6 (WRITE / VOLATILE): set/update an engineer opt-in
CREATE OR REPLACE FUNCTION founder_night_shift_optin_upsert(
  p_engineer_id uuid,
  p_willing boolean,
  p_premium_pay_rupees integer,
  p_max_shifts_per_week integer,
  p_preferred_start_hour smallint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_night_shift_optins
    (engineer_id, willing, premium_pay_per_shift_rupees, max_shifts_per_week, preferred_start_hour, notes)
  VALUES (p_engineer_id, p_willing, p_premium_pay_rupees, p_max_shifts_per_week, p_preferred_start_hour, p_notes)
  ON CONFLICT (engineer_id) DO UPDATE
    SET willing = EXCLUDED.willing,
        premium_pay_per_shift_rupees = EXCLUDED.premium_pay_per_shift_rupees,
        max_shifts_per_week = EXCLUDED.max_shifts_per_week,
        preferred_start_hour = EXCLUDED.preferred_start_hour,
        notes = EXCLUDED.notes,
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_night_shift_optin_set(p_engineer_id, p_willing, p_premium_pay_rupees);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_optin_upsert(uuid, boolean, integer, integer, smallint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_optin_upsert(uuid, boolean, integer, integer, smallint, text) TO authenticated;

-- RPC 7 (WRITE / VOLATILE): schedule a night shift
CREATE OR REPLACE FUNCTION founder_night_shift_schedule(
  p_engineer_id uuid,
  p_shift_date date,
  p_state text,
  p_premium_pay_rupees integer
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_start := (p_shift_date::timestamptz + INTERVAL '22 hours');
  v_end := (p_shift_date::timestamptz + INTERVAL '30 hours'); -- next day 06:00
  INSERT INTO engineer_night_shift_roster
    (shift_date, engineer_id, region_state, shift_start_at, shift_end_at, premium_pay_rupees, status)
  VALUES (p_shift_date, p_engineer_id, p_state, v_start, v_end, p_premium_pay_rupees, 'scheduled')
  ON CONFLICT (shift_date, engineer_id) DO UPDATE
    SET region_state = EXCLUDED.region_state,
        premium_pay_rupees = EXCLUDED.premium_pay_rupees,
        status = 'scheduled',
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_night_shift_scheduled(p_engineer_id, p_shift_date, p_state);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_night_shift_schedule(uuid, date, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_night_shift_schedule(uuid, date, text, integer) TO authenticated;

COMMIT;