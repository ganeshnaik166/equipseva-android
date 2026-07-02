BEGIN;

-- ============================================================
-- r1525 — Founder engineer holiday + leave calendar
-- Pan-India engineer leave tracking with per-state availability
-- and redline alerts when <70% engineers available in any city.
-- ============================================================

-- Planned + actual leaves
CREATE TABLE IF NOT EXISTS engineer_leave_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  leave_type text NOT NULL CHECK (leave_type IN ('planned','sick','personal','festival','emergency','training','other')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  reason text,
  city text,
  state_code text,
  is_actual boolean NOT NULL DEFAULT false,
  approved boolean NOT NULL DEFAULT false,
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT engineer_leave_calendar_date_range_chk CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_eng_leave_cal_engineer ON engineer_leave_calendar(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eng_leave_cal_date ON engineer_leave_calendar(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_eng_leave_cal_state ON engineer_leave_calendar(state_code);
CREATE INDEX IF NOT EXISTS idx_eng_leave_cal_city ON engineer_leave_calendar(city);

ALTER TABLE engineer_leave_calendar ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_leave_calendar_founder_all ON engineer_leave_calendar;
CREATE POLICY engineer_leave_calendar_founder_all ON engineer_leave_calendar
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- City availability redline thresholds
CREATE TABLE IF NOT EXISTS engineer_city_availability_thresholds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city text NOT NULL,
  state_code text,
  redline_pct numeric(5,2) NOT NULL DEFAULT 70.00,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (city)
);

ALTER TABLE engineer_city_availability_thresholds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_city_avail_thr_founder_all ON engineer_city_availability_thresholds;
CREATE POLICY eng_city_avail_thr_founder_all ON engineer_city_availability_thresholds
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_overview()
RETURNS TABLE (
  total_engineers bigint,
  on_leave_today bigint,
  planned_next_7d bigint,
  planned_next_30d bigint,
  actual_last_30d bigint,
  approved_pending bigint,
  cities_redline bigint,
  states_with_leave bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH eng AS (
    SELECT id FROM engineers
  ),
  today_leave AS (
    SELECT DISTINCT engineer_id FROM engineer_leave_calendar
    WHERE current_date BETWEEN start_date AND end_date
  ),
  next7 AS (
    SELECT id FROM engineer_leave_calendar
    WHERE start_date BETWEEN current_date AND current_date + 7 AND NOT is_actual
  ),
  next30 AS (
    SELECT id FROM engineer_leave_calendar
    WHERE start_date BETWEEN current_date AND current_date + 30 AND NOT is_actual
  ),
  last30 AS (
    SELECT id FROM engineer_leave_calendar
    WHERE is_actual AND start_date >= current_date - 30
  ),
  pending AS (
    SELECT id FROM engineer_leave_calendar WHERE NOT approved
  ),
  city_red AS (
    SELECT 1 FROM (
      SELECT e.id, o.city
      FROM engineers e
      LEFT JOIN profiles p ON p.id = e.user_id
      LEFT JOIN organizations o ON o.id = p.organization_id
      WHERE o.city IS NOT NULL
    ) ec
    GROUP BY ec.city
    HAVING (
      (count(*) FILTER (WHERE ec.id NOT IN (SELECT engineer_id FROM today_leave))) * 100.0
      / NULLIF(count(*), 0)
    ) < 70
  ),
  states AS (
    SELECT DISTINCT state_code FROM engineer_leave_calendar WHERE state_code IS NOT NULL
  )
  SELECT
    (SELECT count(*) FROM eng)::bigint,
    (SELECT count(*) FROM today_leave)::bigint,
    (SELECT count(*) FROM next7)::bigint,
    (SELECT count(*) FROM next30)::bigint,
    (SELECT count(*) FROM last30)::bigint,
    (SELECT count(*) FROM pending)::bigint,
    (SELECT count(*) FROM city_red)::bigint,
    (SELECT count(*) FROM states)::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_list_upcoming()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  leave_type text,
  start_date date,
  end_date date,
  days_count numeric,
  city text,
  state_code text,
  approved boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    lc.id,
    lc.engineer_id,
    p.email,
    lc.leave_type,
    lc.start_date,
    lc.end_date,
    (lc.end_date - lc.start_date + 1)::numeric AS days_count,
    lc.city,
    lc.state_code,
    lc.approved
  FROM engineer_leave_calendar lc
  JOIN engineers e ON e.id = lc.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE lc.start_date >= current_date - 1
  ORDER BY lc.start_date ASC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_per_state()
RETURNS TABLE (
  state_code text,
  total_engineers bigint,
  on_leave_today bigint,
  available bigint,
  availability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT e.id AS engineer_id, COALESCE(o.state_code, lc.state_code) AS state_code,
           EXISTS (SELECT 1 FROM engineer_leave_calendar l2
                   WHERE l2.engineer_id = e.id
                     AND current_date BETWEEN l2.start_date AND l2.end_date) AS on_leave
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    LEFT JOIN LATERAL (
      SELECT state_code FROM engineer_leave_calendar
      WHERE engineer_id = e.id AND state_code IS NOT NULL
      ORDER BY start_date DESC LIMIT 1
    ) lc ON true
  )
  SELECT
    state_code,
    count(*)::bigint AS total_engineers,
    count(*) FILTER (WHERE on_leave)::bigint AS on_leave_today,
    count(*) FILTER (WHERE NOT on_leave)::bigint AS available,
    ROUND((count(*) FILTER (WHERE NOT on_leave) * 100.0) / NULLIF(count(*),0), 2) AS availability_pct
  FROM base
  WHERE state_code IS NOT NULL
  GROUP BY state_code
  ORDER BY availability_pct ASC NULLS LAST
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_redline_cities()
RETURNS TABLE (
  city text,
  total_engineers bigint,
  on_leave_today bigint,
  available bigint,
  availability_pct numeric,
  redline_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT e.id AS engineer_id, o.city,
           EXISTS (SELECT 1 FROM engineer_leave_calendar l2
                   WHERE l2.engineer_id = e.id
                     AND current_date BETWEEN l2.start_date AND l2.end_date) AS on_leave
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.user_id
    LEFT JOIN organizations o ON o.id = p.organization_id
    WHERE o.city IS NOT NULL
  ),
  agg AS (
    SELECT city,
           count(*) AS total_engineers,
           count(*) FILTER (WHERE on_leave) AS on_leave_today,
           count(*) FILTER (WHERE NOT on_leave) AS available,
           ROUND((count(*) FILTER (WHERE NOT on_leave) * 100.0) / NULLIF(count(*),0), 2) AS availability_pct
    FROM base
    GROUP BY city
  )
  SELECT a.city,
         a.total_engineers::bigint,
         a.on_leave_today::bigint,
         a.available::bigint,
         a.availability_pct,
         COALESCE(t.redline_pct, 70.00) AS redline_pct,
         CASE WHEN a.availability_pct < COALESCE(t.redline_pct, 70.00) THEN 'redline'
              WHEN a.availability_pct < COALESCE(t.redline_pct, 70.00) + 10 THEN 'warn'
              ELSE 'ok' END AS status
  FROM agg a
  LEFT JOIN engineer_city_availability_thresholds t ON t.city = a.city
  ORDER BY a.availability_pct ASC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_by_type()
RETURNS TABLE (
  leave_type text,
  cnt bigint,
  total_days numeric,
  avg_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT lc.leave_type,
         count(*)::bigint,
         SUM((lc.end_date - lc.start_date + 1))::numeric AS total_days,
         ROUND(AVG((lc.end_date - lc.start_date + 1))::numeric, 2) AS avg_days
  FROM engineer_leave_calendar lc
  WHERE lc.start_date >= current_date - 90
  GROUP BY lc.leave_type
  ORDER BY cnt DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_pending_approvals()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_email text,
  leave_type text,
  start_date date,
  end_date date,
  city text,
  reason text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT lc.id, lc.engineer_id, p.email, lc.leave_type, lc.start_date, lc.end_date,
         lc.city, lc.reason, lc.created_at
  FROM engineer_leave_calendar lc
  JOIN engineers e ON e.id = lc.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE NOT lc.approved
  ORDER BY lc.created_at ASC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_top_absentees()
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  total_leave_days numeric,
  leave_count bigint,
  last_leave_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT lc.engineer_id,
         p.email,
         SUM((lc.end_date - lc.start_date + 1))::numeric AS total_leave_days,
         count(*)::bigint AS leave_count,
         MAX(lc.end_date) AS last_leave_date
  FROM engineer_leave_calendar lc
  JOIN engineers e ON e.id = lc.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE lc.start_date >= current_date - 180
  GROUP BY lc.engineer_id, p.email
  ORDER BY total_leave_days DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- WRITE RPCs (VOLATILE) + log helpers
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_leave_create(p_id uuid, p_engineer uuid, p_type text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'leave_calendar.create',
          jsonb_build_object('id', p_id, 'engineer_id', p_engineer, 'leave_type', p_type));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_leave_approve(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'leave_calendar.approve',
          jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_leave_threshold_set(p_city text, p_pct numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'leave_calendar.threshold_set',
          jsonb_build_object('city', p_city, 'redline_pct', p_pct));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_leave_delete(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'leave_calendar.delete',
          jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_create(
  p_engineer_id uuid,
  p_leave_type text,
  p_start_date date,
  p_end_date date,
  p_reason text,
  p_city text,
  p_state_code text,
  p_is_actual boolean
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_leave_calendar (engineer_id, leave_type, start_date, end_date, reason, city, state_code, is_actual)
  VALUES (p_engineer_id, p_leave_type, p_start_date, p_end_date, p_reason, p_city, p_state_code, COALESCE(p_is_actual, false))
  RETURNING id INTO v_id;
  PERFORM log_founder_leave_create(v_id, p_engineer_id, p_leave_type);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_approve(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_leave_calendar
     SET approved = true, approved_by = auth.uid(), approved_at = now()
   WHERE id = p_id;
  PERFORM log_founder_leave_approve(p_id);
END;
$$;

CREATE OR REPLACE FUNCTION founder_engineer_leave_calendar_set_threshold(p_city text, p_state_code text, p_redline_pct numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_city_availability_thresholds (city, state_code, redline_pct)
  VALUES (p_city, p_state_code, p_redline_pct)
  ON CONFLICT (city) DO UPDATE SET redline_pct = EXCLUDED.redline_pct, state_code = EXCLUDED.state_code;
  PERFORM log_founder_leave_threshold_set(p_city, p_redline_pct);
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_overview() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_list_upcoming() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_list_upcoming() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_per_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_per_state() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_redline_cities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_redline_cities() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_by_type() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_pending_approvals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_pending_approvals() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_top_absentees() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_top_absentees() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_create(uuid, text, date, date, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_create(uuid, text, date, date, text, text, text, boolean) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_approve(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_engineer_leave_calendar_set_threshold(text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_leave_calendar_set_threshold(text, text, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_leave_create(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_leave_create(uuid, uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_leave_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_leave_approve(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_leave_threshold_set(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_leave_threshold_set(text, numeric) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_leave_delete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_leave_delete(uuid) TO authenticated;

COMMIT;