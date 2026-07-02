BEGIN;

-- =========================================================================
-- Round 2766 — Engineer Monthly Cross-Vertical Skill Matrix
-- =========================================================================
-- Two round-suffixed tables capturing per-engineer competency across verticals
-- (dental, ophthalmology, dialysis, anesthesia, imaging, etc.) plus the
-- per-month upskill action queue that founder reviews to balance the bench.
-- =========================================================================

-- ---------- TABLE 1: skill matrix snapshot ------------------------------
CREATE TABLE IF NOT EXISTS engineer_skill_matrix_r2766 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_month  date NOT NULL,
  engineer_id     uuid NOT NULL,
  engineer_name   text NOT NULL,
  vertical        text NOT NULL CHECK (vertical IN ('dental','ophthalmology','dialysis','anesthesia','imaging','endoscopy','icu_ventilator','ortho_power_tools')),
  competency      text NOT NULL CHECK (competency IN ('novice','apprentice','journeyman','expert','master')),
  competency_score numeric(4,2) NOT NULL CHECK (competency_score BETWEEN 0 AND 5),
  cert_status     text NOT NULL CHECK (cert_status IN ('none','training','certified','expired','revoked')),
  cert_expires_on date,
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct BETWEEN 0 AND 100),
  jobs_completed  int NOT NULL DEFAULT 0 CHECK (jobs_completed >= 0),
  csat_avg        numeric(3,2) NOT NULL DEFAULT 0 CHECK (csat_avg BETWEEN 0 AND 5),
  bench_gap_flag  boolean NOT NULL DEFAULT false,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_skill_matrix_r2766 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_skill_matrix_r2766;
CREATE POLICY founder_all ON engineer_skill_matrix_r2766
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_esm_r2766_month ON engineer_skill_matrix_r2766(snapshot_month);
CREATE INDEX IF NOT EXISTS idx_esm_r2766_eng ON engineer_skill_matrix_r2766(engineer_id);
CREATE INDEX IF NOT EXISTS idx_esm_r2766_vert ON engineer_skill_matrix_r2766(vertical);

-- ---------- TABLE 2: upskill action queue -------------------------------
CREATE TABLE IF NOT EXISTS engineer_upskill_actions_r2766 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_month  date NOT NULL,
  engineer_id     uuid NOT NULL,
  engineer_name   text NOT NULL,
  vertical        text NOT NULL CHECK (vertical IN ('dental','ophthalmology','dialysis','anesthesia','imaging','endoscopy','icu_ventilator','ortho_power_tools')),
  action_kind     text NOT NULL CHECK (action_kind IN ('training','shadow','cert_renewal','oem_workshop','field_audit','self_study')),
  priority        text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  status          text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','assigned','in_progress','completed','cancelled')),
  due_on          date NOT NULL,
  estimated_hours numeric(5,2) NOT NULL DEFAULT 0 CHECK (estimated_hours >= 0),
  expected_score_lift numeric(3,2) NOT NULL DEFAULT 0 CHECK (expected_score_lift BETWEEN 0 AND 5),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_upskill_actions_r2766 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_upskill_actions_r2766;
CREATE POLICY founder_all ON engineer_upskill_actions_r2766
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_eua_r2766_month ON engineer_upskill_actions_r2766(snapshot_month);
CREATE INDEX IF NOT EXISTS idx_eua_r2766_status ON engineer_upskill_actions_r2766(status);

-- ---------- SEEDS: skill matrix (10 rows) -------------------------------
INSERT INTO engineer_skill_matrix_r2766
  (snapshot_month, engineer_id, engineer_name, vertical, competency, competency_score, cert_status, cert_expires_on, utilization_pct, jobs_completed, csat_avg, bench_gap_flag, notes)
VALUES
  ('2026-06-01'::date, '11111111-1111-1111-1111-111111111111'::uuid, 'Ravi Kumar', 'dental', 'expert', 4.40, 'certified', '2027-04-30'::date, 78.50, 42, 4.60, false, 'Lead bench for dental chairs HYD'),
  ('2026-06-01'::date, '11111111-1111-1111-1111-111111111111'::uuid, 'Ravi Kumar', 'ophthalmology', 'apprentice', 2.10, 'training', NULL, 12.00, 4, 3.80, true, 'Cross-train pilot — phaco machines'),
  ('2026-06-01'::date, '22222222-2222-2222-2222-222222222222'::uuid, 'Sneha Reddy', 'dialysis', 'journeyman', 3.50, 'certified', '2026-09-15'::date, 82.00, 38, 4.40, false, 'Cert renewal due Q3'),
  ('2026-06-01'::date, '22222222-2222-2222-2222-222222222222'::uuid, 'Sneha Reddy', 'icu_ventilator', 'novice', 1.20, 'none', NULL, 5.00, 1, 3.50, true, 'Gap — only one vent-certified eng in region'),
  ('2026-06-01'::date, '33333333-3333-3333-3333-333333333333'::uuid, 'Mohammed Iqbal', 'imaging', 'master', 4.80, 'certified', '2028-02-20'::date, 88.00, 51, 4.75, false, 'OEM-certified Siemens + GE'),
  ('2026-06-01'::date, '33333333-3333-3333-3333-333333333333'::uuid, 'Mohammed Iqbal', 'endoscopy', 'journeyman', 3.20, 'certified', '2026-07-10'::date, 25.00, 9, 4.20, false, 'Renewal urgent — 30 days out'),
  ('2026-06-01'::date, '44444444-4444-4444-4444-444444444444'::uuid, 'Priya Nair', 'anesthesia', 'expert', 4.30, 'certified', '2027-11-05'::date, 70.00, 33, 4.55, false, 'Stable bench Bangalore'),
  ('2026-06-01'::date, '44444444-4444-4444-4444-444444444444'::uuid, 'Priya Nair', 'ortho_power_tools', 'apprentice', 2.40, 'training', NULL, 8.00, 3, 4.00, true, 'Shadow shift with Stryker rep planned'),
  ('2026-06-01'::date, '55555555-5555-5555-5555-555555555555'::uuid, 'Anil Verma', 'dental', 'journeyman', 3.10, 'certified', '2026-06-30'::date, 65.00, 27, 4.25, false, 'Cert expiring this month — renewal queued'),
  ('2026-06-01'::date, '55555555-5555-5555-5555-555555555555'::uuid, 'Anil Verma', 'dialysis', 'apprentice', 2.00, 'training', NULL, 10.00, 4, 3.90, true, 'Backup bench for SR Reddy');

-- ---------- SEEDS: upskill actions (8 rows) -----------------------------
INSERT INTO engineer_upskill_actions_r2766
  (snapshot_month, engineer_id, engineer_name, vertical, action_kind, priority, status, due_on, estimated_hours, expected_score_lift, notes)
VALUES
  ('2026-06-01'::date, '11111111-1111-1111-1111-111111111111'::uuid, 'Ravi Kumar', 'ophthalmology', 'shadow', 'p1', 'in_progress', '2026-07-15'::date, 24.00, 1.20, 'Ride along with Iqbal — 3 phaco jobs'),
  ('2026-06-01'::date, '22222222-2222-2222-2222-222222222222'::uuid, 'Sneha Reddy', 'dialysis', 'cert_renewal', 'p1', 'queued', '2026-09-01'::date, 8.00, 0.30, 'NABH renewal cycle'),
  ('2026-06-01'::date, '22222222-2222-2222-2222-222222222222'::uuid, 'Sneha Reddy', 'icu_ventilator', 'training', 'p0', 'assigned', '2026-07-30'::date, 40.00, 1.80, 'CRITICAL — second vent eng needed'),
  ('2026-06-01'::date, '33333333-3333-3333-3333-333333333333'::uuid, 'Mohammed Iqbal', 'endoscopy', 'cert_renewal', 'p0', 'in_progress', '2026-07-10'::date, 6.00, 0.20, 'Expires in 30 days — block schedule'),
  ('2026-06-01'::date, '44444444-4444-4444-4444-444444444444'::uuid, 'Priya Nair', 'ortho_power_tools', 'oem_workshop', 'p2', 'queued', '2026-08-20'::date, 16.00, 1.40, 'Stryker workshop Bangalore'),
  ('2026-06-01'::date, '55555555-5555-5555-5555-555555555555'::uuid, 'Anil Verma', 'dental', 'cert_renewal', 'p0', 'assigned', '2026-06-30'::date, 4.00, 0.10, 'Expires this month — urgent'),
  ('2026-06-01'::date, '55555555-5555-5555-5555-555555555555'::uuid, 'Anil Verma', 'dialysis', 'shadow', 'p1', 'queued', '2026-08-01'::date, 20.00, 1.00, 'Shadow Sneha 5 jobs'),
  ('2026-06-01'::date, '11111111-1111-1111-1111-111111111111'::uuid, 'Ravi Kumar', 'dental', 'field_audit', 'p3', 'completed', '2026-05-25'::date, 3.00, 0.05, 'Quarterly QA check — passed');

-- =========================================================================
-- RPCs (7) — all SECDEF, founder-gated, plpgsql
-- =========================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_skill_matrix_kpis_r2766();
CREATE OR REPLACE FUNCTION founder_skill_matrix_kpis_r2766()
RETURNS TABLE (
  total_engineers     int,
  total_skill_rows    int,
  bench_gaps          int,
  avg_competency      numeric,
  avg_utilization     numeric,
  expiring_certs_30d  int,
  open_actions        int,
  p0_actions          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT engineer_id)::int FROM engineer_skill_matrix_r2766),
    (SELECT count(*)::int FROM engineer_skill_matrix_r2766),
    (SELECT count(*)::int FROM engineer_skill_matrix_r2766 WHERE bench_gap_flag),
    (SELECT round(avg(competency_score)::numeric, 2) FROM engineer_skill_matrix_r2766),
    (SELECT round(avg(utilization_pct)::numeric, 2) FROM engineer_skill_matrix_r2766),
    (SELECT count(*)::int FROM engineer_skill_matrix_r2766 WHERE cert_expires_on IS NOT NULL AND cert_expires_on <= current_date + interval '30 days'),
    (SELECT count(*)::int FROM engineer_upskill_actions_r2766 WHERE status IN ('queued','assigned','in_progress')),
    (SELECT count(*)::int FROM engineer_upskill_actions_r2766 WHERE priority = 'p0' AND status != 'completed');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_skill_matrix_kpis_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_matrix_kpis_r2766() TO authenticated;

-- RPC 2: full skill matrix
DROP FUNCTION IF EXISTS founder_skill_matrix_rows_r2766();
CREATE OR REPLACE FUNCTION founder_skill_matrix_rows_r2766()
RETURNS SETOF engineer_skill_matrix_r2766
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_skill_matrix_r2766
  ORDER BY engineer_name, vertical;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_skill_matrix_rows_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_skill_matrix_rows_r2766() TO authenticated;

-- RPC 3: vertical coverage rollup
DROP FUNCTION IF EXISTS founder_vertical_coverage_r2766();
CREATE OR REPLACE FUNCTION founder_vertical_coverage_r2766()
RETURNS TABLE (
  vertical           text,
  engineers_count    int,
  experts_count      int,
  avg_score          numeric,
  avg_utilization    numeric,
  gap_count          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.vertical,
    count(DISTINCT s.engineer_id)::int,
    count(*) FILTER (WHERE s.competency IN ('expert','master'))::int,
    round(avg(s.competency_score)::numeric, 2),
    round(avg(s.utilization_pct)::numeric, 2),
    count(*) FILTER (WHERE s.bench_gap_flag)::int
  FROM engineer_skill_matrix_r2766 s
  GROUP BY s.vertical
  ORDER BY s.vertical;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vertical_coverage_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vertical_coverage_r2766() TO authenticated;

-- RPC 4: engineer rollup
DROP FUNCTION IF EXISTS founder_engineer_rollup_r2766();
CREATE OR REPLACE FUNCTION founder_engineer_rollup_r2766()
RETURNS TABLE (
  engineer_id        uuid,
  engineer_name      text,
  verticals_covered  int,
  avg_score          numeric,
  total_jobs         int,
  avg_csat           numeric,
  open_actions       int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_id,
    max(s.engineer_name),
    count(DISTINCT s.vertical)::int,
    round(avg(s.competency_score)::numeric, 2),
    sum(s.jobs_completed)::int,
    round(avg(s.csat_avg)::numeric, 2),
    COALESCE((SELECT count(*)::int FROM engineer_upskill_actions_r2766 a
      WHERE a.engineer_id = s.engineer_id AND a.status != 'completed'), 0)
  FROM engineer_skill_matrix_r2766 s
  GROUP BY s.engineer_id
  ORDER BY avg_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_rollup_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_rollup_r2766() TO authenticated;

-- RPC 5: bench gaps list
DROP FUNCTION IF EXISTS founder_bench_gaps_r2766();
CREATE OR REPLACE FUNCTION founder_bench_gaps_r2766()
RETURNS SETOF engineer_skill_matrix_r2766
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_skill_matrix_r2766
  WHERE bench_gap_flag = true
  ORDER BY competency_score ASC, engineer_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_gaps_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_gaps_r2766() TO authenticated;

-- RPC 6: expiring certs
DROP FUNCTION IF EXISTS founder_expiring_certs_r2766();
CREATE OR REPLACE FUNCTION founder_expiring_certs_r2766()
RETURNS TABLE (
  engineer_name   text,
  vertical        text,
  cert_status     text,
  cert_expires_on date,
  days_to_expiry  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_name,
    s.vertical,
    s.cert_status,
    s.cert_expires_on,
    (s.cert_expires_on - current_date)::int
  FROM engineer_skill_matrix_r2766 s
  WHERE s.cert_expires_on IS NOT NULL
    AND s.cert_expires_on <= current_date + interval '90 days'
  ORDER BY s.cert_expires_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_expiring_certs_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expiring_certs_r2766() TO authenticated;

-- RPC 7: upskill actions queue
DROP FUNCTION IF EXISTS founder_upskill_actions_r2766();
CREATE OR REPLACE FUNCTION founder_upskill_actions_r2766()
RETURNS SETOF engineer_upskill_actions_r2766
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_upskill_actions_r2766
  ORDER BY
    CASE priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_upskill_actions_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_upskill_actions_r2766() TO authenticated;

-- RPC 8: action mix by kind
DROP FUNCTION IF EXISTS founder_action_mix_r2766();
CREATE OR REPLACE FUNCTION founder_action_mix_r2766()
RETURNS TABLE (
  action_kind       text,
  total_actions     int,
  open_actions      int,
  total_hours       numeric,
  expected_lift_sum numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.action_kind,
    count(*)::int,
    count(*) FILTER (WHERE a.status != 'completed')::int,
    round(sum(a.estimated_hours)::numeric, 2),
    round(sum(a.expected_score_lift)::numeric, 2)
  FROM engineer_upskill_actions_r2766 a
  GROUP BY a.action_kind
  ORDER BY total_actions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_action_mix_r2766() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_action_mix_r2766() TO authenticated;

COMMIT;
