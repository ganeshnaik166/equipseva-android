BEGIN;

-- =============================================================================
-- Round 2885 — Founder Quarterly Strategic Team Onboarding 30/60/90
-- =============================================================================

-- Table 1: strategic_new_hires_r2885
CREATE TABLE IF NOT EXISTS strategic_new_hires_r2885 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_name text NOT NULL,
  role_title text NOT NULL,
  function_area text NOT NULL CHECK (function_area IN ('engineering','operations','sales','finance','customer_success','product')),
  level_band text NOT NULL CHECK (level_band IN ('ic','senior_ic','lead','manager','director','vp')),
  start_date date NOT NULL,
  hiring_manager text NOT NULL,
  base_ctc_lakhs numeric(10,2) NOT NULL,
  esop_grant_units integer NOT NULL DEFAULT 0,
  source_channel text NOT NULL CHECK (source_channel IN ('referral','linkedin','agency','inbound','founder_network')),
  strategic_priority text NOT NULL CHECK (strategic_priority IN ('p0','p1','p2')),
  status text NOT NULL CHECK (status IN ('pre_start','in_30_day','in_60_day','in_90_day','graduated','at_risk','attrited')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE strategic_new_hires_r2885 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON strategic_new_hires_r2885;
CREATE POLICY founder_all ON strategic_new_hires_r2885 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: onboarding_milestones_r2885
CREATE TABLE IF NOT EXISTS onboarding_milestones_r2885 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_id uuid NOT NULL REFERENCES strategic_new_hires_r2885(id) ON DELETE CASCADE,
  checkpoint_window text NOT NULL CHECK (checkpoint_window IN ('30_day','60_day','90_day')),
  milestone_title text NOT NULL,
  milestone_category text NOT NULL CHECK (milestone_category IN ('learning','delivery','relationship','impact','culture')),
  target_outcome text NOT NULL,
  actual_outcome text,
  rating text NOT NULL CHECK (rating IN ('exceeds','meets','below','missed','pending')),
  manager_verdict text NOT NULL CHECK (manager_verdict IN ('continue','accelerate','coach','pip','exit','too_early')),
  retention_probability_pct integer NOT NULL CHECK (retention_probability_pct BETWEEN 0 AND 100),
  evaluated_at date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE onboarding_milestones_r2885 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON onboarding_milestones_r2885;
CREATE POLICY founder_all ON onboarding_milestones_r2885 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =============================================================================
-- Seed data
-- =============================================================================

INSERT INTO strategic_new_hires_r2885 (id, hire_name, role_title, function_area, level_band, start_date, hiring_manager, base_ctc_lakhs, esop_grant_units, source_channel, strategic_priority, status) VALUES
  ('11111111-1111-1111-1111-111111111101', 'Anita Reddy', 'Head of Hospital Sales', 'sales', 'director', '2026-04-01'::date, 'Founder', 65.00, 8000, 'founder_network', 'p0', 'graduated'),
  ('11111111-1111-1111-1111-111111111102', 'Rohan Mehta', 'Staff Engineer — Triage AI', 'engineering', 'senior_ic', '2026-04-15'::date, 'CTO', 58.00, 6500, 'referral', 'p0', 'in_90_day'),
  ('11111111-1111-1111-1111-111111111103', 'Priya Nair', 'Customer Success Manager', 'customer_success', 'lead', '2026-05-01'::date, 'COO', 32.00, 2500, 'linkedin', 'p1', 'in_60_day'),
  ('11111111-1111-1111-1111-111111111104', 'Vikram Singh', 'Finance Controller', 'finance', 'manager', '2026-05-15'::date, 'Founder', 42.00, 3200, 'agency', 'p1', 'in_30_day'),
  ('11111111-1111-1111-1111-111111111105', 'Sneha Iyer', 'Product Manager — AMC', 'product', 'manager', '2026-05-20'::date, 'CPO', 48.00, 4500, 'inbound', 'p0', 'in_30_day'),
  ('11111111-1111-1111-1111-111111111106', 'Karthik Rao', 'Ops Lead — South India', 'operations', 'lead', '2026-04-10'::date, 'COO', 28.00, 1800, 'referral', 'p1', 'at_risk'),
  ('11111111-1111-1111-1111-111111111107', 'Meera Joshi', 'VP Engineering', 'engineering', 'vp', '2026-03-15'::date, 'Founder', 85.00, 15000, 'founder_network', 'p0', 'graduated');

INSERT INTO onboarding_milestones_r2885 (hire_id, checkpoint_window, milestone_title, milestone_category, target_outcome, actual_outcome, rating, manager_verdict, retention_probability_pct, evaluated_at, notes) VALUES
  ('11111111-1111-1111-1111-111111111101', '30_day', 'Meet top 20 hospital CXOs', 'relationship', 'Complete 20 intro calls', 'Completed 24 calls, 6 active pilots', 'exceeds', 'accelerate', 95, '2026-05-01'::date, 'Network already producing pipeline'),
  ('11111111-1111-1111-1111-111111111101', '60_day', 'Close 2 chain deals', 'delivery', '2 signed MSAs', '3 MSAs signed, INR 1.2Cr ARR', 'exceeds', 'accelerate', 96, '2026-06-01'::date, 'Promote to SVP track'),
  ('11111111-1111-1111-1111-111111111101', '90_day', 'Build sales playbook v2', 'impact', 'Playbook + 5 AE hires', 'Playbook shipped, 4 AEs hired', 'meets', 'continue', 94, '2026-07-01'::date, 'Strong leader'),
  ('11111111-1111-1111-1111-111111111102', '30_day', 'Land first triage model PR', 'delivery', 'Merged PR with measurable lift', 'Shipped 3 PRs, 11pp accuracy lift', 'exceeds', 'accelerate', 92, '2026-05-15'::date, 'Senior eng caliber'),
  ('11111111-1111-1111-1111-111111111102', '60_day', 'Own triage roadmap', 'impact', 'Q3 roadmap doc', 'Roadmap + RFC published', 'meets', 'continue', 90, '2026-06-15'::date, 'Tracking well'),
  ('11111111-1111-1111-1111-111111111103', '30_day', 'Take over top 15 accounts', 'relationship', 'Warm handoffs completed', '15 handoffs done, 2 escalations resolved', 'meets', 'continue', 82, '2026-06-01'::date, 'Solid first month'),
  ('11111111-1111-1111-1111-111111111104', '30_day', 'Close Q1 books', 'delivery', 'Books closed by D+25', 'Closed D+28, found 2 reconciliation gaps', 'below', 'coach', 65, '2026-06-15'::date, 'Slow but thorough'),
  ('11111111-1111-1111-1111-111111111105', '30_day', 'Ship AMC churn dashboard', 'delivery', 'Dashboard live in 30d', 'Pending — discovery extended', 'pending', 'too_early', 75, '2026-06-20'::date, 'Discovery phase'),
  ('11111111-1111-1111-1111-111111111106', '30_day', 'Hire 4 ops engineers South', 'delivery', '4 offers signed', '1 offer signed, 2 declined', 'missed', 'pip', 35, '2026-05-10'::date, 'Hiring funnel broken'),
  ('11111111-1111-1111-1111-111111111106', '60_day', 'Repair NPS in Bangalore region', 'impact', 'NPS +15', 'NPS flat', 'below', 'coach', 40, '2026-06-10'::date, 'At risk'),
  ('11111111-1111-1111-1111-111111111107', '30_day', 'Org diagnostic', 'learning', 'Diagnostic memo to founder', 'Memo delivered with 8 actions', 'exceeds', 'accelerate', 98, '2026-04-15'::date, 'Outstanding'),
  ('11111111-1111-1111-1111-111111111107', '60_day', 'Ship platform v2 plan', 'impact', 'Approved 3yr platform plan', 'Plan approved, hiring 5 staff eng', 'exceeds', 'accelerate', 97, '2026-05-15'::date, 'Foundational hire'),
  ('11111111-1111-1111-1111-111111111107', '90_day', 'Deliver Q2 OKRs', 'delivery', '4 of 5 OKRs green', '5 of 5 green', 'exceeds', 'continue', 97, '2026-06-15'::date, 'Top tier');

-- =============================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated, search_path locked)
-- =============================================================================

DROP FUNCTION IF EXISTS founder_r2885_onboarding_kpis();
CREATE OR REPLACE FUNCTION founder_r2885_onboarding_kpis()
RETURNS TABLE(
  total_hires bigint,
  in_window bigint,
  graduated bigint,
  at_risk bigint,
  avg_retention_pct numeric,
  exceeds_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM strategic_new_hires_r2885),
    (SELECT count(*) FROM strategic_new_hires_r2885 WHERE status IN ('in_30_day','in_60_day','in_90_day')),
    (SELECT count(*) FROM strategic_new_hires_r2885 WHERE status = 'graduated'),
    (SELECT count(*) FROM strategic_new_hires_r2885 WHERE status = 'at_risk'),
    COALESCE((SELECT round(avg(retention_probability_pct)::numeric, 1) FROM onboarding_milestones_r2885), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE rating = 'exceeds') / NULLIF(count(*),0), 1) FROM onboarding_milestones_r2885), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_onboarding_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_onboarding_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_hires_list();
CREATE OR REPLACE FUNCTION founder_r2885_hires_list()
RETURNS TABLE(
  id uuid,
  hire_name text,
  role_title text,
  function_area text,
  level_band text,
  start_date date,
  hiring_manager text,
  base_ctc_lakhs numeric,
  strategic_priority text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.hire_name, h.role_title, h.function_area, h.level_band,
         h.start_date, h.hiring_manager, h.base_ctc_lakhs, h.strategic_priority, h.status
  FROM strategic_new_hires_r2885 h
  ORDER BY h.start_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_hires_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_hires_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_milestones_list();
CREATE OR REPLACE FUNCTION founder_r2885_milestones_list()
RETURNS TABLE(
  milestone_id uuid,
  hire_name text,
  role_title text,
  checkpoint_window text,
  milestone_title text,
  milestone_category text,
  target_outcome text,
  actual_outcome text,
  rating text,
  manager_verdict text,
  retention_probability_pct integer,
  evaluated_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, h.hire_name, h.role_title, m.checkpoint_window, m.milestone_title,
         m.milestone_category, m.target_outcome, m.actual_outcome, m.rating,
         m.manager_verdict, m.retention_probability_pct, m.evaluated_at
  FROM onboarding_milestones_r2885 m
  JOIN strategic_new_hires_r2885 h ON h.id = m.hire_id
  ORDER BY m.evaluated_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_milestones_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_milestones_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_by_window();
CREATE OR REPLACE FUNCTION founder_r2885_by_window()
RETURNS TABLE(
  checkpoint_window text,
  total_milestones bigint,
  exceeds_count bigint,
  meets_count bigint,
  below_or_missed bigint,
  avg_retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.checkpoint_window,
         count(*)::bigint,
         count(*) FILTER (WHERE m.rating = 'exceeds')::bigint,
         count(*) FILTER (WHERE m.rating = 'meets')::bigint,
         count(*) FILTER (WHERE m.rating IN ('below','missed'))::bigint,
         round(avg(m.retention_probability_pct)::numeric, 1)
  FROM onboarding_milestones_r2885 m
  GROUP BY m.checkpoint_window
  ORDER BY m.checkpoint_window;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_by_window() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_by_window() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_by_function();
CREATE OR REPLACE FUNCTION founder_r2885_by_function()
RETURNS TABLE(
  function_area text,
  hires_count bigint,
  total_ctc_lakhs numeric,
  graduated_count bigint,
  at_risk_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.function_area,
         count(*)::bigint,
         round(sum(h.base_ctc_lakhs)::numeric, 2),
         count(*) FILTER (WHERE h.status = 'graduated')::bigint,
         count(*) FILTER (WHERE h.status = 'at_risk')::bigint
  FROM strategic_new_hires_r2885 h
  GROUP BY h.function_area
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_by_function() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_by_function() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_at_risk();
CREATE OR REPLACE FUNCTION founder_r2885_at_risk()
RETURNS TABLE(
  hire_name text,
  role_title text,
  hiring_manager text,
  status text,
  worst_rating text,
  min_retention_pct integer,
  latest_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.hire_name, h.role_title, h.hiring_manager, h.status,
         (SELECT m.rating FROM onboarding_milestones_r2885 m WHERE m.hire_id = h.id
           ORDER BY CASE m.rating WHEN 'missed' THEN 1 WHEN 'below' THEN 2 WHEN 'pending' THEN 3
                                  WHEN 'meets' THEN 4 WHEN 'exceeds' THEN 5 END LIMIT 1),
         (SELECT min(m.retention_probability_pct) FROM onboarding_milestones_r2885 m WHERE m.hire_id = h.id),
         (SELECT m.manager_verdict FROM onboarding_milestones_r2885 m WHERE m.hire_id = h.id ORDER BY m.evaluated_at DESC LIMIT 1)
  FROM strategic_new_hires_r2885 h
  WHERE h.status IN ('at_risk','attrited')
     OR EXISTS (SELECT 1 FROM onboarding_milestones_r2885 m
                 WHERE m.hire_id = h.id AND m.retention_probability_pct < 60)
  ORDER BY (SELECT min(m.retention_probability_pct) FROM onboarding_milestones_r2885 m WHERE m.hire_id = h.id) ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_at_risk() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2885_verdict_mix()
RETURNS TABLE(
  manager_verdict text,
  verdict_count bigint,
  avg_retention_pct numeric,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH total AS (SELECT count(*)::numeric AS t FROM onboarding_milestones_r2885)
  SELECT m.manager_verdict,
         count(*)::bigint,
         round(avg(m.retention_probability_pct)::numeric, 1),
         round(100.0 * count(*)::numeric / NULLIF((SELECT t FROM total), 0), 1)
  FROM onboarding_milestones_r2885 m
  GROUP BY m.manager_verdict
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_verdict_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2885_source_roi();
CREATE OR REPLACE FUNCTION founder_r2885_source_roi()
RETURNS TABLE(
  source_channel text,
  hires_count bigint,
  graduated_count bigint,
  at_risk_count bigint,
  avg_retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.source_channel,
         count(DISTINCT h.id)::bigint,
         count(DISTINCT h.id) FILTER (WHERE h.status = 'graduated')::bigint,
         count(DISTINCT h.id) FILTER (WHERE h.status = 'at_risk')::bigint,
         COALESCE(round(avg(m.retention_probability_pct)::numeric, 1), 0)
  FROM strategic_new_hires_r2885 h
  LEFT JOIN onboarding_milestones_r2885 m ON m.hire_id = h.id
  GROUP BY h.source_channel
  ORDER BY count(DISTINCT h.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2885_source_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2885_source_roi() TO authenticated;

COMMIT;
