BEGIN;

-- ============================================================
-- r1457 — Engineer Career Ladder Map (T0 → T6)
-- ============================================================

CREATE TABLE IF NOT EXISTS engineer_career_rungs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rung_code text NOT NULL UNIQUE CHECK (rung_code IN ('T0','T1','T2','T3','T4','T5','T6')),
  rung_name text NOT NULL,
  rung_order int NOT NULL UNIQUE,
  min_completed_jobs int NOT NULL DEFAULT 0,
  min_avg_rating numeric(3,2) NOT NULL DEFAULT 0,
  min_amc_attached int NOT NULL DEFAULT 0,
  min_certifications int NOT NULL DEFAULT 0,
  base_monthly_stipend_rupees int NOT NULL DEFAULT 0,
  per_job_bonus_rupees int NOT NULL DEFAULT 0,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_career_rungs ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS engineer_rung_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  current_rung_code text NOT NULL CHECK (current_rung_code IN ('T0','T1','T2','T3','T4','T5','T6')),
  target_rung_code text NOT NULL CHECK (target_rung_code IN ('T0','T1','T2','T3','T4','T5','T6')),
  readiness_pct numeric(5,2) NOT NULL DEFAULT 0,
  gap_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  assessed_at timestamptz NOT NULL DEFAULT now(),
  assessed_by uuid REFERENCES profiles(id),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_rung_assess_engineer ON engineer_rung_assessments(engineer_id, assessed_at DESC);
CREATE INDEX IF NOT EXISTS idx_rung_assess_target ON engineer_rung_assessments(target_rung_code, readiness_pct DESC);

ALTER TABLE engineer_rung_assessments ENABLE ROW LEVEL SECURITY;

-- seed rungs
INSERT INTO engineer_career_rungs (rung_code, rung_name, rung_order, min_completed_jobs, min_avg_rating, min_amc_attached, min_certifications, base_monthly_stipend_rupees, per_job_bonus_rupees, description)
VALUES
  ('T0','Trainee',0,0,0.00,0,0,0,0,'Onboarding — shadow visits only'),
  ('T1','Junior',1,10,3.50,0,1,5000,100,'Solo repair-only jobs under remote supervision'),
  ('T2','Field Engineer',2,40,4.00,2,2,9000,200,'Independent repair + basic maintenance'),
  ('T3','Senior Engineer',3,120,4.20,8,4,14000,350,'Maintenance contracts + spare-parts authority'),
  ('T4','Specialist',4,300,4.40,20,6,20000,500,'Multi-OEM coverage + AMC owner'),
  ('T5','Principal',5,600,4.55,50,8,28000,700,'City lead — supervises T1/T2'),
  ('T6','Master',6,1000,4.70,100,10,40000,1000,'National authority — trains all rungs')
ON CONFLICT (rung_code) DO NOTHING;

-- ============================================================
-- founder log table (if not exists)
-- ============================================================
CREATE TABLE IF NOT EXISTS founder_career_ladder_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_kind text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  logged_at timestamptz NOT NULL DEFAULT now(),
  logged_by uuid REFERENCES profiles(id)
);

ALTER TABLE founder_career_ladder_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- log helpers
-- ============================================================
CREATE OR REPLACE FUNCTION log_founder_rung_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_career_ladder_log(event_kind, payload, logged_by)
  VALUES ('ladder_view', '{}'::jsonb, auth.uid());
END $$;
GRANT EXECUTE ON FUNCTION log_founder_rung_view() TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rung_assessment(p_engineer_id uuid, p_target text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_career_ladder_log(event_kind, payload, logged_by)
  VALUES ('assessment_run', jsonb_build_object('engineer_id', p_engineer_id, 'target', p_target), auth.uid());
END $$;
GRANT EXECUTE ON FUNCTION log_founder_rung_assessment(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rung_export()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_career_ladder_log(event_kind, payload, logged_by)
  VALUES ('ladder_export', '{}'::jsonb, auth.uid());
END $$;
GRANT EXECUTE ON FUNCTION log_founder_rung_export() TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_rung_promotion(p_engineer_id uuid, p_from text, p_to text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_career_ladder_log(event_kind, payload, logged_by)
  VALUES ('rung_promotion', jsonb_build_object('engineer_id', p_engineer_id, 'from', p_from, 'to', p_to), auth.uid());
END $$;
GRANT EXECUTE ON FUNCTION log_founder_rung_promotion(uuid, text, text) TO authenticated;

-- ============================================================
-- RPC 1 — ladder definition
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_definition()
RETURNS TABLE (
  rung_code text,
  rung_name text,
  rung_order int,
  min_completed_jobs int,
  min_avg_rating numeric,
  min_amc_attached int,
  min_certifications int,
  base_monthly_stipend_rupees int,
  per_job_bonus_rupees int,
  description text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.rung_code, r.rung_name, r.rung_order, r.min_completed_jobs, r.min_avg_rating,
         r.min_amc_attached, r.min_certifications, r.base_monthly_stipend_rupees,
         r.per_job_bonus_rupees, r.description
  FROM engineer_career_rungs r
  ORDER BY r.rung_order;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_definition() TO authenticated;

-- ============================================================
-- RPC 2 — engineer current rung snapshot
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_engineer_current()
RETURNS TABLE (
  engineer_id uuid,
  display_name text,
  current_rung text,
  completed_jobs bigint,
  avg_rating numeric,
  amc_attached bigint,
  city text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, 'Engineer'),
    COALESCE(e.cached_highest_tier, 'T0')::text,
    COALESCE((SELECT COUNT(*) FROM repair_jobs rj WHERE rj.engineer_id = e.id AND rj.status = 'completed'), 0),
    COALESCE((SELECT AVG(rating)::numeric(3,2) FROM repair_job_ratings rjr JOIN repair_jobs rj ON rj.id = rjr.repair_job_id WHERE rj.engineer_id = e.id), 0)::numeric,
    COALESCE((SELECT COUNT(*) FROM amc_contracts a WHERE a.assigned_engineer_id = e.id AND a.status = 'active'), 0),
    COALESCE(o.city, '—')
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.profile_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  ORDER BY 4 DESC NULLS LAST
  LIMIT 500;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_engineer_current() TO authenticated;

-- ============================================================
-- RPC 3 — rung distribution
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_distribution()
RETURNS TABLE (
  rung_code text,
  rung_name text,
  engineer_count bigint,
  pct_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM engineers;
  RETURN QUERY
  SELECT
    r.rung_code,
    r.rung_name,
    COALESCE((SELECT COUNT(*) FROM engineers e WHERE COALESCE(e.cached_highest_tier, 'T0') = r.rung_code), 0),
    CASE WHEN v_total = 0 THEN 0
         ELSE ROUND(100.0 * COALESCE((SELECT COUNT(*) FROM engineers e WHERE COALESCE(e.cached_highest_tier, 'T0') = r.rung_code), 0) / v_total, 2)
    END::numeric
  FROM engineer_career_rungs r
  ORDER BY r.rung_order;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_distribution() TO authenticated;

-- ============================================================
-- RPC 4 — gap analysis (engineers near promotion)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_gap_analysis()
RETURNS TABLE (
  engineer_id uuid,
  display_name text,
  current_rung text,
  next_rung text,
  jobs_done bigint,
  jobs_required int,
  jobs_gap int,
  avg_rating numeric,
  rating_required numeric,
  readiness_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH eng AS (
    SELECT
      e.id,
      COALESCE(p.full_name, 'Engineer') AS dname,
      COALESCE(e.cached_highest_tier, 'T0') AS cur,
      COALESCE((SELECT COUNT(*) FROM repair_jobs rj WHERE rj.engineer_id = e.id AND rj.status = 'completed'), 0) AS jobs,
      COALESCE((SELECT AVG(rating)::numeric(3,2) FROM repair_job_ratings rjr JOIN repair_jobs rj ON rj.id = rjr.repair_job_id WHERE rj.engineer_id = e.id), 0)::numeric AS rating
    FROM engineers e
    LEFT JOIN profiles p ON p.id = e.profile_id
  ),
  next_rung AS (
    SELECT r1.rung_code AS cur_code, r2.rung_code AS nxt_code, r2.min_completed_jobs, r2.min_avg_rating
    FROM engineer_career_rungs r1
    JOIN engineer_career_rungs r2 ON r2.rung_order = r1.rung_order + 1
  )
  SELECT
    eng.id,
    eng.dname,
    eng.cur::text,
    COALESCE(nr.nxt_code, 'T6')::text,
    eng.jobs,
    COALESCE(nr.min_completed_jobs, 0),
    GREATEST(0, COALESCE(nr.min_completed_jobs, 0) - eng.jobs::int),
    eng.rating,
    COALESCE(nr.min_avg_rating, 0)::numeric,
    LEAST(100, ROUND(
      (CASE WHEN COALESCE(nr.min_completed_jobs,0) = 0 THEN 100 ELSE LEAST(100, 100.0 * eng.jobs / nr.min_completed_jobs) END +
       CASE WHEN COALESCE(nr.min_avg_rating,0) = 0 THEN 100 ELSE LEAST(100, 100.0 * eng.rating / nr.min_avg_rating) END) / 2.0
    , 2))::numeric
  FROM eng
  LEFT JOIN next_rung nr ON nr.cur_code = eng.cur
  ORDER BY 11 DESC NULLS LAST
  LIMIT 200;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_gap_analysis() TO authenticated;

-- ============================================================
-- RPC 5 — recent promotions
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_recent_promotions()
RETURNS TABLE (
  event_id uuid,
  engineer_id uuid,
  from_rung text,
  to_rung text,
  promoted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    (l.payload->>'engineer_id')::uuid,
    (l.payload->>'from')::text,
    (l.payload->>'to')::text,
    l.logged_at
  FROM founder_career_ladder_log l
  WHERE l.event_kind = 'rung_promotion'
  ORDER BY l.logged_at DESC
  LIMIT 50;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_recent_promotions() TO authenticated;

-- ============================================================
-- RPC 6 — KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_kpis()
RETURNS TABLE (
  total_engineers bigint,
  t0_count bigint,
  t1_count bigint,
  t2_count bigint,
  t3_count bigint,
  t4_count bigint,
  t5_count bigint,
  t6_count bigint,
  avg_readiness numeric,
  ready_for_promotion bigint,
  promotions_30d bigint,
  total_payroll_rupees bigint,
  pending_assessments bigint,
  certified_engineers bigint,
  avg_rating_all numeric,
  median_rung_order numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM engineers),
    (SELECT COUNT(*) FROM engineers WHERE COALESCE(cached_highest_tier,'T0')='T0'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T1'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T2'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T3'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T4'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T5'),
    (SELECT COUNT(*) FROM engineers WHERE cached_highest_tier='T6'),
    COALESCE((SELECT AVG(readiness_pct)::numeric(5,2) FROM engineer_rung_assessments), 0)::numeric,
    (SELECT COUNT(*) FROM engineer_rung_assessments WHERE readiness_pct >= 80),
    (SELECT COUNT(*) FROM founder_career_ladder_log WHERE event_kind='rung_promotion' AND logged_at > now() - interval '30 days'),
    COALESCE((SELECT SUM(r.base_monthly_stipend_rupees)::bigint FROM engineers e JOIN engineer_career_rungs r ON r.rung_code = COALESCE(e.cached_highest_tier,'T0')), 0),
    (SELECT COUNT(*) FROM engineers e WHERE NOT EXISTS (SELECT 1 FROM engineer_rung_assessments a WHERE a.engineer_id = e.id)),
    (SELECT COUNT(DISTINCT e.id) FROM engineers e WHERE COALESCE(e.cached_highest_tier,'T0') >= 'T2'),
    COALESCE((SELECT AVG(rating)::numeric(3,2) FROM repair_job_ratings), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY r.rung_order) FROM engineers e JOIN engineer_career_rungs r ON r.rung_code = COALESCE(e.cached_highest_tier,'T0')), 0)::numeric;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_kpis() TO authenticated;

-- ============================================================
-- RPC 7 — recent assessments
-- ============================================================
CREATE OR REPLACE FUNCTION founder_career_ladder_recent_assessments()
RETURNS TABLE (
  assessment_id uuid,
  engineer_id uuid,
  current_rung text,
  target_rung text,
  readiness_pct numeric,
  assessed_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_id, a.current_rung_code, a.target_rung_code,
         a.readiness_pct, a.assessed_at, a.notes
  FROM engineer_rung_assessments a
  ORDER BY a.assessed_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_career_ladder_recent_assessments() TO authenticated;

COMMIT;