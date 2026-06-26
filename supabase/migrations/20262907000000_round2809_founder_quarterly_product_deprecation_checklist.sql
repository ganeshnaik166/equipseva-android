BEGIN;

-- =====================================================================
-- Round 2809 — Founder Quarterly Product Deprecation Checklist (HEAVY)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: deprecation candidates registry
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_deprecation_candidates_r2809 (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label         text NOT NULL,
  feature_name          text NOT NULL,
  surface               text NOT NULL CHECK (surface IN ('android_app','web_console','engineer_app','public_site','api','admin_only')),
  shipped_round         int NOT NULL,
  active_users_30d      int NOT NULL DEFAULT 0 CHECK (active_users_30d >= 0),
  monthly_revenue_inr   int NOT NULL DEFAULT 0 CHECK (monthly_revenue_inr >= 0),
  upstream_dependencies int NOT NULL DEFAULT 0 CHECK (upstream_dependencies >= 0),
  downstream_consumers  int NOT NULL DEFAULT 0 CHECK (downstream_consumers >= 0),
  maintenance_hours_q   int NOT NULL DEFAULT 0 CHECK (maintenance_hours_q >= 0),
  verdict               text NOT NULL CHECK (verdict IN ('keep','deprecate','sunset_q','sunset_year','rebuild','undecided')),
  notes                 text,
  reviewed_at           date NOT NULL DEFAULT current_date,
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE product_deprecation_candidates_r2809 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON product_deprecation_candidates_r2809;
CREATE POLICY founder_all ON product_deprecation_candidates_r2809
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO product_deprecation_candidates_r2809
  (quarter_label, feature_name, surface, shipped_round, active_users_30d, monthly_revenue_inr, upstream_dependencies, downstream_consumers, maintenance_hours_q, verdict, notes, reviewed_at)
VALUES
  ('2026-Q2','Legacy spare-parts catalog v1','web_console',412, 3, 0, 1, 7, 18, 'sunset_q','Replaced by bonded provenance v2 at r500','2026-06-21'::date),
  ('2026-Q2','SMS OTP fallback','android_app',289, 47, 0, 2, 4, 6, 'keep','Still 4% of logins; keep through 2026','2026-06-21'::date),
  ('2026-Q2','Old AMC tier picker','android_app',355, 0, 0, 0, 3, 2, 'sunset_q','Payment-first flow r477 made this dead','2026-06-21'::date),
  ('2026-Q2','Bulk CSV import (admin)','admin_only',201, 1, 0, 3, 2, 12, 'rebuild','Crashes on >500 rows; rebuild on workers','2026-06-21'::date),
  ('2026-Q2','Public referral landing v1','public_site',378, 12, 8500, 1, 3, 4, 'sunset_year','Low conv 0.4%; v2 in design r2700','2026-06-21'::date),
  ('2026-Q2','Engineer training quiz v1','engineer_app',420, 89, 0, 1, 5, 9, 'deprecate','Supervised training r585 supersedes','2026-06-21'::date);

-- ---------------------------------------------------------------------
-- Table 2: deprecation checklist steps
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_deprecation_steps_r2809 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id        uuid NOT NULL REFERENCES product_deprecation_candidates_r2809(id) ON DELETE CASCADE,
  step_order          int NOT NULL CHECK (step_order > 0),
  step_kind           text NOT NULL CHECK (step_kind IN ('communicate','migrate','remove_ui','remove_api','remove_db','archive','postmortem')),
  description         text NOT NULL,
  target_date         date NOT NULL,
  owner_role          text NOT NULL CHECK (owner_role IN ('founder','engineering','support','marketing','legal')),
  status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','blocked','skipped')),
  blocker_notes       text,
  completed_at        timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE product_deprecation_steps_r2809 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON product_deprecation_steps_r2809;
CREATE POLICY founder_all ON product_deprecation_steps_r2809
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO product_deprecation_steps_r2809
  (candidate_id, step_order, step_kind, description, target_date, owner_role, status, blocker_notes)
SELECT id, 1, 'communicate', 'Email 3 active users + post in-app banner', '2026-07-01'::date, 'support', 'done', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Legacy spare-parts catalog v1'
UNION ALL
SELECT id, 2, 'migrate', 'Backfill orders to v2 provenance table', '2026-07-10'::date, 'engineering', 'in_progress', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Legacy spare-parts catalog v1'
UNION ALL
SELECT id, 3, 'remove_ui', 'Pull catalog v1 routes from web console', '2026-07-25'::date, 'engineering', 'pending', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Legacy spare-parts catalog v1'
UNION ALL
SELECT id, 1, 'communicate', 'Notify training engineers about quiz v2', '2026-07-05'::date, 'support', 'pending', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Engineer training quiz v1'
UNION ALL
SELECT id, 2, 'archive', 'Archive quiz attempts to cold storage', '2026-08-15'::date, 'engineering', 'pending', 'Need S3 bucket sign-off'
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Engineer training quiz v1'
UNION ALL
SELECT id, 1, 'remove_ui', 'Hide old AMC picker behind flag', '2026-06-30'::date, 'engineering', 'done', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Old AMC tier picker'
UNION ALL
SELECT id, 1, 'communicate', 'Founder note to internal team about CSV import rebuild', '2026-07-12'::date, 'founder', 'pending', NULL
  FROM product_deprecation_candidates_r2809 WHERE feature_name = 'Bulk CSV import (admin)';

-- ---------------------------------------------------------------------
-- RPC 1: overview KPIs
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_overview();
CREATE OR REPLACE FUNCTION founder_r2809_overview()
RETURNS TABLE (
  total_candidates    int,
  sunset_this_quarter int,
  total_steps         int,
  steps_done          int,
  revenue_at_risk     int,
  users_to_migrate    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM product_deprecation_candidates_r2809),
    (SELECT COUNT(*)::int FROM product_deprecation_candidates_r2809 WHERE verdict = 'sunset_q'),
    (SELECT COUNT(*)::int FROM product_deprecation_steps_r2809),
    (SELECT COUNT(*)::int FROM product_deprecation_steps_r2809 WHERE status = 'done'),
    (SELECT COALESCE(SUM(monthly_revenue_inr),0)::int FROM product_deprecation_candidates_r2809 WHERE verdict IN ('sunset_q','sunset_year','deprecate')),
    (SELECT COALESCE(SUM(active_users_30d),0)::int FROM product_deprecation_candidates_r2809 WHERE verdict IN ('sunset_q','sunset_year','deprecate'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_overview() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: candidate list with derived risk
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_candidates();
CREATE OR REPLACE FUNCTION founder_r2809_candidates()
RETURNS TABLE (
  id                  uuid,
  feature_name        text,
  surface             text,
  active_users_30d    int,
  monthly_revenue_inr int,
  upstream_dependencies int,
  downstream_consumers  int,
  maintenance_hours_q int,
  verdict             text,
  risk_score          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.feature_name, c.surface, c.active_users_30d, c.monthly_revenue_inr,
         c.upstream_dependencies, c.downstream_consumers, c.maintenance_hours_q, c.verdict,
         (c.active_users_30d * 2 + c.downstream_consumers * 5 + c.monthly_revenue_inr / 1000)::int
  FROM product_deprecation_candidates_r2809 c
  ORDER BY c.maintenance_hours_q DESC, c.feature_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_candidates() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: verdict breakdown
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_verdict_breakdown();
CREATE OR REPLACE FUNCTION founder_r2809_verdict_breakdown()
RETURNS TABLE (verdict text, candidate_count int, total_users int, total_revenue int, total_hours int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.verdict,
         COUNT(*)::int,
         COALESCE(SUM(c.active_users_30d),0)::int,
         COALESCE(SUM(c.monthly_revenue_inr),0)::int,
         COALESCE(SUM(c.maintenance_hours_q),0)::int
  FROM product_deprecation_candidates_r2809 c
  GROUP BY c.verdict
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_verdict_breakdown() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: surface breakdown
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_surface_breakdown();
CREATE OR REPLACE FUNCTION founder_r2809_surface_breakdown()
RETURNS TABLE (surface text, candidate_count int, total_hours int, sunset_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.surface,
         COUNT(*)::int,
         COALESCE(SUM(c.maintenance_hours_q),0)::int,
         COUNT(*) FILTER (WHERE c.verdict IN ('sunset_q','sunset_year','deprecate'))::int
  FROM product_deprecation_candidates_r2809 c
  GROUP BY c.surface
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_surface_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_surface_breakdown() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: pending checklist steps
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_pending_steps();
CREATE OR REPLACE FUNCTION founder_r2809_pending_steps()
RETURNS TABLE (
  step_id        uuid,
  feature_name   text,
  step_order     int,
  step_kind      text,
  description    text,
  target_date    date,
  owner_role     text,
  status         text,
  days_to_target int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, c.feature_name, s.step_order, s.step_kind, s.description, s.target_date,
         s.owner_role, s.status, (s.target_date - current_date)::int
  FROM product_deprecation_steps_r2809 s
  JOIN product_deprecation_candidates_r2809 c ON c.id = s.candidate_id
  WHERE s.status IN ('pending','in_progress','blocked')
  ORDER BY s.target_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_pending_steps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_pending_steps() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: completion progress per candidate
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_completion_progress();
CREATE OR REPLACE FUNCTION founder_r2809_completion_progress()
RETURNS TABLE (feature_name text, verdict text, total_steps int, done_steps int, percent_done int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.feature_name, c.verdict,
         COUNT(s.id)::int,
         COUNT(s.id) FILTER (WHERE s.status = 'done')::int,
         CASE WHEN COUNT(s.id) = 0 THEN 0
              ELSE (COUNT(s.id) FILTER (WHERE s.status = 'done') * 100 / COUNT(s.id))::int
         END
  FROM product_deprecation_candidates_r2809 c
  LEFT JOIN product_deprecation_steps_r2809 s ON s.candidate_id = c.id
  GROUP BY c.feature_name, c.verdict
  ORDER BY c.feature_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_completion_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_completion_progress() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: blockers requiring founder attention
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_blockers();
CREATE OR REPLACE FUNCTION founder_r2809_blockers()
RETURNS TABLE (feature_name text, step_kind text, owner_role text, blocker_notes text, target_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.feature_name, s.step_kind, s.owner_role, s.blocker_notes, s.target_date
  FROM product_deprecation_steps_r2809 s
  JOIN product_deprecation_candidates_r2809 c ON c.id = s.candidate_id
  WHERE s.status = 'blocked' OR s.blocker_notes IS NOT NULL
  ORDER BY s.target_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_blockers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_blockers() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 8: mark a step done
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2809_mark_step_done(uuid);
CREATE OR REPLACE FUNCTION founder_r2809_mark_step_done(p_step_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE product_deprecation_steps_r2809
     SET status = 'done', completed_at = now()
   WHERE id = p_step_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2809_mark_step_done(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2809_mark_step_done(uuid) TO authenticated;

COMMIT;
