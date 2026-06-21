BEGIN;

-- Round 1668: Engineer Travel Heatmap
-- Per-engineer travel: km/week, cost/km, productivity/km + optimization tickets

CREATE TABLE engineer_travel_weeks_r1668 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  engineer_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  total_km int NOT NULL DEFAULT 0 CHECK (total_km >= 0),
  total_cost_rupees int NOT NULL DEFAULT 0 CHECK (total_cost_rupees >= 0),
  jobs_completed int NOT NULL DEFAULT 0 CHECK (jobs_completed >= 0),
  productivity_per_km numeric(10,4) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (engineer_user_id, week_start)
);

CREATE INDEX idx_travel_weeks_r1668_eng ON engineer_travel_weeks_r1668(engineer_user_id);
CREATE INDEX idx_travel_weeks_r1668_week ON engineer_travel_weeks_r1668(week_start DESC);

CREATE TABLE engineer_travel_optimization_tickets_r1668 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  week_id uuid NOT NULL REFERENCES engineer_travel_weeks_r1668(id) ON DELETE CASCADE,
  suggestion_text text NOT NULL,
  expected_saving_rupees int NOT NULL DEFAULT 0 CHECK (expected_saving_rupees >= 0),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','applied','dismissed')),
  decided_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_travel_tickets_r1668_week ON engineer_travel_optimization_tickets_r1668(week_id);
CREATE INDEX idx_travel_tickets_r1668_status ON engineer_travel_optimization_tickets_r1668(status);

ALTER TABLE engineer_travel_weeks_r1668 ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_travel_optimization_tickets_r1668 ENABLE ROW LEVEL SECURITY;

CREATE POLICY travel_weeks_r1668_founder_all ON engineer_travel_weeks_r1668
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE POLICY travel_tickets_r1668_founder_all ON engineer_travel_optimization_tickets_r1668
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_travel_weeks
CREATE OR REPLACE FUNCTION public.list_travel_weeks_r1668()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  week_start date,
  total_km int,
  total_cost_rupees int,
  jobs_completed int,
  productivity_per_km numeric,
  cost_per_km numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    w.id,
    w.engineer_user_id,
    p.email,
    w.week_start,
    w.total_km,
    w.total_cost_rupees,
    w.jobs_completed,
    w.productivity_per_km,
    CASE WHEN w.total_km > 0 THEN (w.total_cost_rupees::numeric / w.total_km::numeric) ELSE 0 END AS cost_per_km,
    w.created_at
  FROM engineer_travel_weeks_r1668 w
  LEFT JOIN profiles p ON p.id = w.engineer_user_id
  ORDER BY w.week_start DESC, w.total_km DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_travel_weeks_r1668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_travel_weeks_r1668() TO authenticated;

-- RPC 2: record_week
CREATE OR REPLACE FUNCTION public.record_week_r1668(
  p_engineer_user_id uuid,
  p_week_start date,
  p_total_km int,
  p_total_cost_rupees int,
  p_jobs_completed int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_productivity numeric(10,4);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_productivity := CASE WHEN p_total_km > 0 THEN (p_jobs_completed::numeric / p_total_km::numeric) ELSE 0 END;

  INSERT INTO engineer_travel_weeks_r1668(
    engineer_user_id, week_start, total_km, total_cost_rupees, jobs_completed, productivity_per_km
  )
  VALUES (p_engineer_user_id, p_week_start, p_total_km, p_total_cost_rupees, p_jobs_completed, v_productivity)
  ON CONFLICT (engineer_user_id, week_start) DO UPDATE
    SET total_km = EXCLUDED.total_km,
        total_cost_rupees = EXCLUDED.total_cost_rupees,
        jobs_completed = EXCLUDED.jobs_completed,
        productivity_per_km = EXCLUDED.productivity_per_km,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1668_record_week',
    jsonb_build_object(
      'week_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'week_start', p_week_start,
      'total_km', p_total_km,
      'total_cost_rupees', p_total_cost_rupees,
      'jobs_completed', p_jobs_completed
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_week_r1668(uuid, date, int, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_week_r1668(uuid, date, int, int, int) TO authenticated;

-- RPC 3: top_km_engineers
CREATE OR REPLACE FUNCTION public.top_km_engineers_r1668()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_km_4w int,
  total_cost_4w int,
  jobs_4w int,
  avg_cost_per_km numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    w.engineer_user_id,
    p.email,
    COALESCE(SUM(w.total_km), 0)::int AS total_km_4w,
    COALESCE(SUM(w.total_cost_rupees), 0)::int AS total_cost_4w,
    COALESCE(SUM(w.jobs_completed), 0)::int AS jobs_4w,
    CASE WHEN COALESCE(SUM(w.total_km), 0) > 0
      THEN (COALESCE(SUM(w.total_cost_rupees), 0)::numeric / COALESCE(SUM(w.total_km), 0)::numeric)
      ELSE 0 END AS avg_cost_per_km
  FROM engineer_travel_weeks_r1668 w
  LEFT JOIN profiles p ON p.id = w.engineer_user_id
  WHERE w.week_start >= (current_date - interval '28 days')
  GROUP BY w.engineer_user_id, p.email
  ORDER BY total_km_4w DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_km_engineers_r1668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_km_engineers_r1668() TO authenticated;

-- RPC 4: list_tickets
CREATE OR REPLACE FUNCTION public.list_tickets_r1668()
RETURNS TABLE (
  id uuid,
  week_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  week_start date,
  suggestion_text text,
  expected_saving_rupees int,
  status text,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.week_id,
    w.engineer_user_id,
    p.email,
    w.week_start,
    t.suggestion_text,
    t.expected_saving_rupees,
    t.status,
    t.decided_at,
    t.created_at
  FROM engineer_travel_optimization_tickets_r1668 t
  JOIN engineer_travel_weeks_r1668 w ON w.id = t.week_id
  LEFT JOIN profiles p ON p.id = w.engineer_user_id
  ORDER BY
    CASE t.status WHEN 'open' THEN 0 WHEN 'applied' THEN 1 ELSE 2 END,
    t.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tickets_r1668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_tickets_r1668() TO authenticated;

-- RPC 5: add_ticket
CREATE OR REPLACE FUNCTION public.add_ticket_r1668(
  p_week_id uuid,
  p_suggestion_text text,
  p_expected_saving_rupees int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO engineer_travel_optimization_tickets_r1668(
    week_id, suggestion_text, expected_saving_rupees, status
  )
  VALUES (p_week_id, p_suggestion_text, p_expected_saving_rupees, 'open')
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1668_add_ticket',
    jsonb_build_object(
      'ticket_id', v_id,
      'week_id', p_week_id,
      'expected_saving_rupees', p_expected_saving_rupees
    ));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_ticket_r1668(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_ticket_r1668(uuid, text, int) TO authenticated;

-- RPC 6: decide_ticket
CREATE OR REPLACE FUNCTION public.decide_ticket_r1668(
  p_ticket_id uuid,
  p_decision text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_decision NOT IN ('applied','dismissed') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;

  UPDATE engineer_travel_optimization_tickets_r1668
  SET status = p_decision,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_ticket_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1668_decide_ticket',
    jsonb_build_object(
      'ticket_id', p_ticket_id,
      'decision', p_decision
    ));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.decide_ticket_r1668(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decide_ticket_r1668(uuid, text) TO authenticated;

-- RPC 7: travel_summary
CREATE OR REPLACE FUNCTION public.travel_summary_r1668()
RETURNS TABLE (
  total_weeks int,
  total_km_4w int,
  total_cost_4w int,
  avg_cost_per_km numeric,
  avg_productivity_per_km numeric,
  open_tickets int,
  applied_tickets int,
  expected_savings_open_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_travel_weeks_r1668),
    COALESCE((SELECT SUM(total_km)::int FROM engineer_travel_weeks_r1668
      WHERE week_start >= (current_date - interval '28 days')), 0),
    COALESCE((SELECT SUM(total_cost_rupees)::int FROM engineer_travel_weeks_r1668
      WHERE week_start >= (current_date - interval '28 days')), 0),
    COALESCE((SELECT
      CASE WHEN SUM(total_km) > 0
        THEN (SUM(total_cost_rupees)::numeric / SUM(total_km)::numeric)
        ELSE 0 END
      FROM engineer_travel_weeks_r1668
      WHERE week_start >= (current_date - interval '28 days')), 0),
    COALESCE((SELECT AVG(productivity_per_km)
      FROM engineer_travel_weeks_r1668
      WHERE week_start >= (current_date - interval '28 days')), 0),
    (COUNT(*) FILTER (WHERE t.status = 'open'))::int,
    (COUNT(*) FILTER (WHERE t.status = 'applied'))::int,
    COALESCE(SUM(t.expected_saving_rupees) FILTER (WHERE t.status = 'open'), 0)::int
  FROM engineer_travel_optimization_tickets_r1668 t;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.travel_summary_r1668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.travel_summary_r1668() TO authenticated;

COMMIT;