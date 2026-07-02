BEGIN;

-- ============================================================================
-- r1669 — Investor Pro-Rata Tracker
-- Track pro-rata rights + exercise queue per investor per round
-- ============================================================================

CREATE TABLE investor_pro_rata_rights_r1669 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  investor_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  round_name text NOT NULL,
  pct_pro_rata numeric(6,3) NOT NULL CHECK (pct_pro_rata >= 0 AND pct_pro_rata <= 100),
  max_invest_rupees bigint NOT NULL CHECK (max_invest_rupees >= 0),
  expires_on date NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','exercised','waived')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_pro_rata_rights_r1669_investor ON investor_pro_rata_rights_r1669(investor_id);
CREATE INDEX idx_pro_rata_rights_r1669_round ON investor_pro_rata_rights_r1669(round_name);
CREATE INDEX idx_pro_rata_rights_r1669_status ON investor_pro_rata_rights_r1669(status);
CREATE INDEX idx_pro_rata_rights_r1669_expires ON investor_pro_rata_rights_r1669(expires_on);

CREATE TABLE investor_pro_rata_exercises_r1669 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  right_id uuid NOT NULL REFERENCES investor_pro_rata_rights_r1669(id) ON DELETE CASCADE,
  decision_date date NOT NULL DEFAULT CURRENT_DATE,
  decision text NOT NULL CHECK (decision IN ('exercise','waive','partial')),
  amount_exercised_rupees bigint NOT NULL DEFAULT 0 CHECK (amount_exercised_rupees >= 0),
  note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_pro_rata_exercises_r1669_right ON investor_pro_rata_exercises_r1669(right_id);
CREATE INDEX idx_pro_rata_exercises_r1669_date ON investor_pro_rata_exercises_r1669(decision_date);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE investor_pro_rata_rights_r1669 ENABLE ROW LEVEL SECURITY;
ALTER TABLE investor_pro_rata_exercises_r1669 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all_rights_r1669
  ON investor_pro_rata_rights_r1669
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE POLICY founder_all_exercises_r1669
  ON investor_pro_rata_exercises_r1669
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1 — list_rights
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_list_rights()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  round_name text,
  pct_pro_rata numeric,
  max_invest_rupees bigint,
  expires_on date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.id, r.investor_id, p.email, r.round_name, r.pct_pro_rata,
         r.max_invest_rupees, r.expires_on, r.status, r.created_at
  FROM investor_pro_rata_rights_r1669 r
  LEFT JOIN profiles p ON p.id = r.investor_id
  ORDER BY r.expires_on ASC, r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_list_rights() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_list_rights() TO authenticated;

-- ============================================================================
-- RPC 2 — add_right
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_add_right(
  p_investor_id uuid,
  p_round_name text,
  p_pct_pro_rata numeric,
  p_max_invest_rupees bigint,
  p_expires_on date
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO investor_pro_rata_rights_r1669(investor_id, round_name, pct_pro_rata, max_invest_rupees, expires_on)
  VALUES (p_investor_id, p_round_name, p_pct_pro_rata, p_max_invest_rupees, p_expires_on)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1669_add_right',
    jsonb_build_object(
      'right_id', v_id,
      'investor_id', p_investor_id,
      'round_name', p_round_name,
      'pct_pro_rata', p_pct_pro_rata,
      'max_invest_rupees', p_max_invest_rupees,
      'expires_on', p_expires_on
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_add_right(uuid, text, numeric, bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_add_right(uuid, text, numeric, bigint, date) TO authenticated;

-- ============================================================================
-- RPC 3 — list_exercises
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_list_exercises()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  investor_email text,
  round_name text,
  decision_date date,
  decision text,
  amount_exercised_rupees bigint,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.id, e.right_id, p.email, r.round_name, e.decision_date,
         e.decision, e.amount_exercised_rupees, e.note, e.created_at
  FROM investor_pro_rata_exercises_r1669 e
  JOIN investor_pro_rata_rights_r1669 r ON r.id = e.right_id
  LEFT JOIN profiles p ON p.id = r.investor_id
  ORDER BY e.decision_date DESC, e.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_list_exercises() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_list_exercises() TO authenticated;

-- ============================================================================
-- RPC 4 — record_exercise
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_record_exercise(
  p_right_id uuid,
  p_decision text,
  p_amount_exercised_rupees bigint,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO investor_pro_rata_exercises_r1669(right_id, decision, amount_exercised_rupees, note)
  VALUES (p_right_id, p_decision, COALESCE(p_amount_exercised_rupees, 0), p_note)
  RETURNING id INTO v_id;

  v_new_status := CASE
    WHEN p_decision = 'exercise' THEN 'exercised'
    WHEN p_decision = 'waive' THEN 'waived'
    WHEN p_decision = 'partial' THEN 'exercised'
    ELSE 'active'
  END;

  UPDATE investor_pro_rata_rights_r1669
  SET status = v_new_status, updated_at = now()
  WHERE id = p_right_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1669_record_exercise',
    jsonb_build_object(
      'exercise_id', v_id,
      'right_id', p_right_id,
      'decision', p_decision,
      'amount_exercised_rupees', p_amount_exercised_rupees,
      'new_status', v_new_status
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_record_exercise(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_record_exercise(uuid, text, bigint, text) TO authenticated;

-- ============================================================================
-- RPC 5 — expiring_rights_window
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_expiring_rights_window(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  round_name text,
  pct_pro_rata numeric,
  max_invest_rupees bigint,
  expires_on date,
  days_left int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.id, r.investor_id, p.email, r.round_name, r.pct_pro_rata,
         r.max_invest_rupees, r.expires_on,
         (r.expires_on - CURRENT_DATE)::int AS days_left
  FROM investor_pro_rata_rights_r1669 r
  LEFT JOIN profiles p ON p.id = r.investor_id
  WHERE r.status = 'active'
    AND r.expires_on >= CURRENT_DATE
    AND r.expires_on <= CURRENT_DATE + (p_days || ' days')::interval
  ORDER BY r.expires_on ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_expiring_rights_window(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_expiring_rights_window(int) TO authenticated;

-- ============================================================================
-- RPC 6 — pro_rata_summary
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_pro_rata_summary()
RETURNS TABLE (
  total_rights int,
  active_rights int,
  expired_rights int,
  exercised_rights int,
  waived_rights int,
  total_max_invest_rupees bigint,
  total_exercised_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::int AS total_rights,
    (COUNT(*) FILTER (WHERE r.status = 'active'))::int AS active_rights,
    (COUNT(*) FILTER (WHERE r.status = 'expired'))::int AS expired_rights,
    (COUNT(*) FILTER (WHERE r.status = 'exercised'))::int AS exercised_rights,
    (COUNT(*) FILTER (WHERE r.status = 'waived'))::int AS waived_rights,
    COALESCE(SUM(r.max_invest_rupees), 0)::bigint AS total_max_invest_rupees,
    COALESCE((
      SELECT SUM(e.amount_exercised_rupees)
      FROM investor_pro_rata_exercises_r1669 e
    ), 0)::bigint AS total_exercised_rupees
  FROM investor_pro_rata_rights_r1669 r;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_pro_rata_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_pro_rata_summary() TO authenticated;

-- ============================================================================
-- RPC 7 — exercised_total
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1669_exercised_total()
RETURNS TABLE (
  round_name text,
  exercise_count int,
  total_exercised_rupees bigint,
  avg_exercised_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.round_name,
    COUNT(e.id)::int AS exercise_count,
    COALESCE(SUM(e.amount_exercised_rupees), 0)::bigint AS total_exercised_rupees,
    COALESCE(AVG(e.amount_exercised_rupees), 0)::bigint AS avg_exercised_rupees
  FROM investor_pro_rata_rights_r1669 r
  LEFT JOIN investor_pro_rata_exercises_r1669 e ON e.right_id = r.id
  GROUP BY r.round_name
  ORDER BY total_exercised_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1669_exercised_total() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1669_exercised_total() TO authenticated;

COMMIT;