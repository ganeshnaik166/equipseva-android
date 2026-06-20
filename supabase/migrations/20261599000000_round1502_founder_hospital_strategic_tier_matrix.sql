BEGIN;

-- ============================================================
-- r1502 — Founder Hospital Strategic-Tier Matrix
-- 2x2 matrix: revenue (high/low) × strategic-fit (high/low)
-- Per-quadrant action playbook + founder review cadence
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_hospital_strategic_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  revenue_score numeric(5,2) NOT NULL DEFAULT 0 CHECK (revenue_score >= 0 AND revenue_score <= 100),
  strategic_fit_score numeric(5,2) NOT NULL DEFAULT 0 CHECK (strategic_fit_score >= 0 AND strategic_fit_score <= 100),
  quadrant text NOT NULL CHECK (quadrant IN ('star','cash_cow','question_mark','dog')),
  trailing_90d_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  active_contracts int NOT NULL DEFAULT 0,
  review_cadence_days int NOT NULL DEFAULT 30,
  next_review_at timestamptz,
  last_reviewed_at timestamptz,
  founder_notes text,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id)
);

CREATE INDEX IF NOT EXISTS idx_fhsts_quadrant ON founder_hospital_strategic_scores(quadrant);
CREATE INDEX IF NOT EXISTS idx_fhsts_next_review ON founder_hospital_strategic_scores(next_review_at);

ALTER TABLE founder_hospital_strategic_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhsts_founder_only ON founder_hospital_strategic_scores;
CREATE POLICY fhsts_founder_only ON founder_hospital_strategic_scores
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_hospital_quadrant_playbook (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quadrant text NOT NULL CHECK (quadrant IN ('star','cash_cow','question_mark','dog')),
  step_order int NOT NULL,
  action_label text NOT NULL,
  owner_role text NOT NULL,
  cadence_days int NOT NULL DEFAULT 30,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quadrant, step_order)
);

CREATE INDEX IF NOT EXISTS idx_fhqp_quadrant ON founder_hospital_quadrant_playbook(quadrant, step_order);

ALTER TABLE founder_hospital_quadrant_playbook ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhqp_founder_only ON founder_hospital_quadrant_playbook;
CREATE POLICY fhqp_founder_only ON founder_hospital_quadrant_playbook
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Seed playbook (idempotent)
INSERT INTO founder_hospital_quadrant_playbook (quadrant, step_order, action_label, owner_role, cadence_days) VALUES
  ('star', 1, 'Founder quarterly business review on-site', 'founder', 14),
  ('star', 2, 'Lock 24-month AMC at premium tier', 'sales', 14),
  ('star', 3, 'Co-author case study + reference call', 'marketing', 30),
  ('cash_cow', 1, 'Auto-renew AMC + uptime SLA check', 'ops', 30),
  ('cash_cow', 2, 'Cross-sell spare-parts bundle', 'sales', 30),
  ('cash_cow', 3, 'Monthly NPS pulse', 'cs', 30),
  ('question_mark', 1, 'Discovery call — surface fit blockers', 'founder', 14),
  ('question_mark', 2, 'Pilot 3-month AMC with success metric', 'sales', 21),
  ('question_mark', 3, 'Decide: invest or downgrade in 90 days', 'founder', 90),
  ('dog', 1, 'Right-size SLA to ad-hoc only', 'ops', 60),
  ('dog', 2, 'Audit cost-to-serve quarterly', 'finance', 60),
  ('dog', 3, 'Sunset playbook if margin negative 2Q', 'founder', 90)
ON CONFLICT (quadrant, step_order) DO NOTHING;

-- ============================================================
-- Helpers (VOLATILE SECDEF) — log_founder_*
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_matrix_view()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'matrix_view', jsonb_build_object('at', now()));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_matrix_recompute(p_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'matrix_recompute', jsonb_build_object('count', p_count, 'at', now()));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_matrix_review_marked(p_hospital uuid, p_quadrant text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'matrix_review_marked', jsonb_build_object('hospital_org_id', p_hospital, 'quadrant', p_quadrant, 'at', now()));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_matrix_note_saved(p_hospital uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'matrix_note_saved', jsonb_build_object('hospital_org_id', p_hospital, 'at', now()));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_matrix_view() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_matrix_view() TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_matrix_recompute(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_matrix_recompute(int) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_matrix_review_marked(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_matrix_review_marked(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_matrix_note_saved(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_matrix_note_saved(uuid) TO authenticated;

-- ============================================================
-- 7 SECDEF RPCs
-- ============================================================

-- 1. Matrix overview (STABLE read)
CREATE OR REPLACE FUNCTION founder_hospital_matrix_overview()
RETURNS TABLE (
  total_hospitals int,
  stars int,
  cash_cows int,
  question_marks int,
  dogs int,
  stars_revenue numeric,
  cash_cows_revenue numeric,
  question_marks_revenue numeric,
  dogs_revenue numeric,
  total_trailing_revenue numeric,
  avg_revenue_score numeric,
  avg_fit_score numeric,
  overdue_reviews int,
  reviews_due_7d int,
  last_recompute_at timestamptz,
  unscored_hospitals int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH s AS (SELECT * FROM founder_hospital_strategic_scores),
  o AS (SELECT count(*)::int AS c FROM organizations WHERE org_type = 'hospital')
  SELECT
    (SELECT c FROM o),
    COUNT(*) FILTER (WHERE quadrant='star')::int,
    COUNT(*) FILTER (WHERE quadrant='cash_cow')::int,
    COUNT(*) FILTER (WHERE quadrant='question_mark')::int,
    COUNT(*) FILTER (WHERE quadrant='dog')::int,
    COALESCE(SUM(trailing_90d_revenue_rupees) FILTER (WHERE quadrant='star'),0),
    COALESCE(SUM(trailing_90d_revenue_rupees) FILTER (WHERE quadrant='cash_cow'),0),
    COALESCE(SUM(trailing_90d_revenue_rupees) FILTER (WHERE quadrant='question_mark'),0),
    COALESCE(SUM(trailing_90d_revenue_rupees) FILTER (WHERE quadrant='dog'),0),
    COALESCE(SUM(trailing_90d_revenue_rupees),0),
    COALESCE(AVG(revenue_score),0)::numeric,
    COALESCE(AVG(strategic_fit_score),0)::numeric,
    COUNT(*) FILTER (WHERE next_review_at < now())::int,
    COUNT(*) FILTER (WHERE next_review_at BETWEEN now() AND now() + interval '7 days')::int,
    MAX(computed_at),
    GREATEST(0, (SELECT c FROM o) - COUNT(*)::int)
  FROM s;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_overview() TO authenticated;

-- 2. List hospitals with quadrant
CREATE OR REPLACE FUNCTION founder_hospital_matrix_list()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quadrant text,
  revenue_score numeric,
  strategic_fit_score numeric,
  trailing_90d_revenue_rupees numeric,
  active_contracts int,
  next_review_at timestamptz,
  last_reviewed_at timestamptz,
  days_until_review numeric
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
    s.id,
    s.hospital_org_id,
    COALESCE(o.name,'Unknown'),
    s.quadrant,
    s.revenue_score,
    s.strategic_fit_score,
    s.trailing_90d_revenue_rupees,
    s.active_contracts,
    s.next_review_at,
    s.last_reviewed_at,
    CASE WHEN s.next_review_at IS NULL THEN NULL
         ELSE EXTRACT(EPOCH FROM (s.next_review_at - now()))/86400.0
    END
  FROM founder_hospital_strategic_scores s
  LEFT JOIN organizations o ON o.id = s.hospital_org_id
  ORDER BY s.trailing_90d_revenue_rupees DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_list() TO authenticated;

-- 3. Quadrant breakdown
CREATE OR REPLACE FUNCTION founder_hospital_matrix_quadrants()
RETURNS TABLE (
  id uuid,
  quadrant text,
  hospital_count int,
  total_revenue numeric,
  avg_revenue_score numeric,
  avg_fit_score numeric,
  avg_review_cadence_days numeric,
  overdue_count int
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
    gen_random_uuid(),
    s.quadrant,
    COUNT(*)::int,
    COALESCE(SUM(s.trailing_90d_revenue_rupees),0),
    COALESCE(AVG(s.revenue_score),0)::numeric,
    COALESCE(AVG(s.strategic_fit_score),0)::numeric,
    COALESCE(AVG(s.review_cadence_days),0)::numeric,
    COUNT(*) FILTER (WHERE s.next_review_at < now())::int
  FROM founder_hospital_strategic_scores s
  GROUP BY s.quadrant
  ORDER BY 4 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_quadrants() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_quadrants() TO authenticated;

-- 4. Playbook by quadrant
CREATE OR REPLACE FUNCTION founder_hospital_matrix_playbook()
RETURNS TABLE (
  id uuid,
  quadrant text,
  step_order int,
  action_label text,
  owner_role text,
  cadence_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.quadrant, p.step_order, p.action_label, p.owner_role, p.cadence_days
  FROM founder_hospital_quadrant_playbook p
  WHERE p.is_active = true
  ORDER BY p.quadrant, p.step_order;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_playbook() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_playbook() TO authenticated;

-- 5. Reviews due
CREATE OR REPLACE FUNCTION founder_hospital_matrix_reviews_due()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quadrant text,
  next_review_at timestamptz,
  days_overdue numeric,
  trailing_90d_revenue_rupees numeric
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
    s.id,
    s.hospital_org_id,
    COALESCE(o.name,'Unknown'),
    s.quadrant,
    s.next_review_at,
    EXTRACT(EPOCH FROM (now() - s.next_review_at))/86400.0,
    s.trailing_90d_revenue_rupees
  FROM founder_hospital_strategic_scores s
  LEFT JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.next_review_at IS NOT NULL AND s.next_review_at <= now() + interval '7 days'
  ORDER BY s.next_review_at ASC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_reviews_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_reviews_due() TO authenticated;

-- 6. Top movers (last computed vs now, simplified — top by revenue rank)
CREATE OR REPLACE FUNCTION founder_hospital_matrix_top_movers()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  quadrant text,
  revenue_score numeric,
  strategic_fit_score numeric,
  trailing_90d_revenue_rupees numeric
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
    s.id,
    s.hospital_org_id,
    COALESCE(o.name,'Unknown'),
    s.quadrant,
    s.revenue_score,
    s.strategic_fit_score,
    s.trailing_90d_revenue_rupees
  FROM founder_hospital_strategic_scores s
  LEFT JOIN organizations o ON o.id = s.hospital_org_id
  ORDER BY s.trailing_90d_revenue_rupees DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_top_movers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_top_movers() TO authenticated;

-- 7. Recompute scores (VOLATILE write)
CREATE OR REPLACE FUNCTION founder_hospital_matrix_recompute()
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_max_rev numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH rev AS (
    SELECT
      rj.hospital_org_id,
      SUM(COALESCE(rj.contracted_amount_rupees,0)) AS rev_90d,
      COUNT(DISTINCT ac.id) AS active_contracts
    FROM repair_jobs rj
    LEFT JOIN amc_contracts ac
      ON ac.hospital_user_id IN (
        SELECT p.id FROM profiles p WHERE p.organization_id = rj.hospital_org_id
      )
     AND ac.status = 'active'
    WHERE rj.created_at >= now() - interval '90 days'
    GROUP BY rj.hospital_org_id
  ),
  base AS (
    SELECT
      o.id AS hospital_org_id,
      COALESCE(r.rev_90d,0) AS rev_90d,
      COALESCE(r.active_contracts,0)::int AS active_contracts
    FROM organizations o
    LEFT JOIN rev r ON r.hospital_org_id = o.id
    WHERE o.org_type = 'hospital'
  ),
  scored AS (
    SELECT
      b.*,
      LEAST(100, GREATEST(0,
        CASE WHEN (SELECT MAX(rev_90d) FROM base) > 0
          THEN (b.rev_90d / NULLIF((SELECT MAX(rev_90d) FROM base),0)) * 100
          ELSE 0
        END
      ))::numeric(5,2) AS rev_score,
      LEAST(100, GREATEST(0,
        (b.active_contracts * 20)
        + LEAST(50, (b.rev_90d / 10000)::int)
      ))::numeric(5,2) AS fit_score
    FROM base b
  )
  INSERT INTO founder_hospital_strategic_scores (
    hospital_org_id, revenue_score, strategic_fit_score, quadrant,
    trailing_90d_revenue_rupees, active_contracts, review_cadence_days,
    next_review_at, computed_at, updated_at
  )
  SELECT
    s.hospital_org_id,
    s.rev_score,
    s.fit_score,
    CASE
      WHEN s.rev_score >= 50 AND s.fit_score >= 50 THEN 'star'
      WHEN s.rev_score >= 50 AND s.fit_score <  50 THEN 'cash_cow'
      WHEN s.rev_score <  50 AND s.fit_score >= 50 THEN 'question_mark'
      ELSE 'dog'
    END,
    s.rev_90d,
    s.active_contracts,
    CASE
      WHEN s.rev_score >= 50 AND s.fit_score >= 50 THEN 14
      WHEN s.rev_score >= 50 AND s.fit_score <  50 THEN 30
      WHEN s.rev_score <  50 AND s.fit_score >= 50 THEN 21
      ELSE 60
    END,
    now() + (CASE
      WHEN s.rev_score >= 50 AND s.fit_score >= 50 THEN interval '14 days'
      WHEN s.rev_score >= 50 AND s.fit_score <  50 THEN interval '30 days'
      WHEN s.rev_score <  50 AND s.fit_score >= 50 THEN interval '21 days'
      ELSE interval '60 days'
    END),
    now(),
    now()
  FROM scored s
  ON CONFLICT (hospital_org_id) DO UPDATE SET
    revenue_score = EXCLUDED.revenue_score,
    strategic_fit_score = EXCLUDED.strategic_fit_score,
    quadrant = EXCLUDED.quadrant,
    trailing_90d_revenue_rupees = EXCLUDED.trailing_90d_revenue_rupees,
    active_contracts = EXCLUDED.active_contracts,
    review_cadence_days = EXCLUDED.review_cadence_days,
    next_review_at = EXCLUDED.next_review_at,
    computed_at = now(),
    updated_at = now();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM log_founder_matrix_recompute(v_count);

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_hospital_matrix_recompute() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_matrix_recompute() TO authenticated;

COMMIT;