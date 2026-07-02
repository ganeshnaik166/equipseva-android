BEGIN;

-- ============================================================
-- Round 2839 — Hospital Chain Quarterly Equipment Fleet Rejuvenation
-- chain x asset cohort x refurb x retire x replace x revenue x verdict
-- ============================================================

CREATE TABLE IF NOT EXISTS chain_fleet_cohorts_r2839 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code      text NOT NULL,
  chain_name      text NOT NULL,
  cohort_label    text NOT NULL,
  asset_category  text NOT NULL CHECK (asset_category IN ('imaging','monitoring','surgical','laboratory','life_support','dental')),
  units_total     integer NOT NULL CHECK (units_total >= 0),
  units_refurb    integer NOT NULL CHECK (units_refurb >= 0),
  units_retire    integer NOT NULL CHECK (units_retire >= 0),
  units_replace   integer NOT NULL CHECK (units_replace >= 0),
  avg_age_years   numeric(5,2) NOT NULL CHECK (avg_age_years >= 0),
  refurb_cost_lakhs   numeric(12,2) NOT NULL CHECK (refurb_cost_lakhs >= 0),
  replace_cost_lakhs  numeric(12,2) NOT NULL CHECK (replace_cost_lakhs >= 0),
  expected_revenue_lakhs numeric(12,2) NOT NULL CHECK (expected_revenue_lakhs >= 0),
  verdict         text NOT NULL CHECK (verdict IN ('refurbish_now','replace_now','retire_only','defer_next_quarter','escalate_review')),
  quarter_tag     text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_fleet_cohorts_r2839 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_fleet_cohorts_r2839;
CREATE POLICY founder_all ON chain_fleet_cohorts_r2839 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS chain_rejuvenation_runs_r2839 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code      text NOT NULL,
  run_quarter     text NOT NULL,
  run_date        date NOT NULL,
  units_actioned  integer NOT NULL CHECK (units_actioned >= 0),
  cost_committed_lakhs numeric(12,2) NOT NULL CHECK (cost_committed_lakhs >= 0),
  revenue_actual_lakhs numeric(12,2) NOT NULL CHECK (revenue_actual_lakhs >= 0),
  refurb_success_pct  numeric(5,2) NOT NULL CHECK (refurb_success_pct BETWEEN 0 AND 100),
  retire_compliance_pct numeric(5,2) NOT NULL CHECK (retire_compliance_pct BETWEEN 0 AND 100),
  status          text NOT NULL CHECK (status IN ('planned','in_progress','completed','blocked','rolled_back')),
  notes           text NOT NULL DEFAULT '',
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_rejuvenation_runs_r2839 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_rejuvenation_runs_r2839;
CREATE POLICY founder_all ON chain_rejuvenation_runs_r2839 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO chain_fleet_cohorts_r2839
  (chain_code, chain_name, cohort_label, asset_category, units_total, units_refurb, units_retire, units_replace, avg_age_years, refurb_cost_lakhs, replace_cost_lakhs, expected_revenue_lakhs, verdict, quarter_tag)
VALUES
  ('apollo-south','Apollo Southern','Imaging-MRI-2018','imaging',12,4,2,3,6.50,42.00,180.00,265.00,'replace_now','2026-Q3'),
  ('fortis-north','Fortis Northern','Monitoring-ICU-2019','monitoring',48,18,6,8,5.20,28.50,96.00,142.00,'refurbish_now','2026-Q3'),
  ('manipal-west','Manipal Western','Surgical-OT-2017','surgical',22,6,4,5,7.10,55.00,210.00,318.00,'replace_now','2026-Q3'),
  ('kims-east','KIMS Eastern','Laboratory-Bench-2020','laboratory',35,10,3,2,4.40,18.20,72.00,88.00,'refurbish_now','2026-Q3'),
  ('aster-central','Aster Central','LifeSupport-Vent-2016','life_support',15,3,7,4,8.30,32.00,148.00,162.00,'retire_only','2026-Q3'),
  ('clove-metro','Clove Metro Dental','Dental-Chair-2019','dental',60,22,4,6,5.50,16.40,58.00,94.50,'refurbish_now','2026-Q3'),
  ('apollo-south','Apollo Southern','Imaging-CT-2015','imaging',8,1,5,2,9.20,38.00,205.00,228.00,'escalate_review','2026-Q3'),
  ('fortis-north','Fortis Northern','Surgical-Endo-2021','surgical',14,4,1,1,3.80,22.00,84.00,72.00,'defer_next_quarter','2026-Q3');

INSERT INTO chain_rejuvenation_runs_r2839
  (chain_code, run_quarter, run_date, units_actioned, cost_committed_lakhs, revenue_actual_lakhs, refurb_success_pct, retire_compliance_pct, status, notes)
VALUES
  ('apollo-south','2026-Q2','2026-04-18'::date,9,212.50,248.00,88.50,100.00,'completed','MRI replacement closed two weeks early'),
  ('fortis-north','2026-Q2','2026-04-22'::date,32,124.00,138.50,91.20,95.50,'completed','ICU monitor refurb wave green'),
  ('manipal-west','2026-Q2','2026-05-02'::date,15,265.00,295.00,84.00,100.00,'completed','OT replacement on plan'),
  ('kims-east','2026-Q3','2026-06-01'::date,15,86.20,42.00,82.50,90.00,'in_progress','Lab bench refurb mid-quarter'),
  ('aster-central','2026-Q3','2026-06-05'::date,7,148.00,0.00,0.00,100.00,'planned','Vent retire awaits biomedical sign-off'),
  ('clove-metro','2026-Q2','2026-05-19'::date,28,82.40,98.20,89.80,100.00,'completed','Dental chair refurb solid ROI'),
  ('apollo-south','2026-Q1','2026-01-15'::date,11,118.00,0.00,42.00,60.00,'rolled_back','CT vendor delivery slipped; rolled back');

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS rpc_r2839_cohort_overview();
CREATE OR REPLACE FUNCTION rpc_r2839_cohort_overview()
RETURNS TABLE (
  chain_code text, chain_name text, cohort_label text, asset_category text,
  units_total integer, avg_age_years numeric, verdict text, expected_revenue_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, c.chain_name, c.cohort_label, c.asset_category,
           c.units_total, c.avg_age_years, c.verdict, c.expected_revenue_lakhs
    FROM chain_fleet_cohorts_r2839 c
    ORDER BY c.expected_revenue_lakhs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_cohort_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_cohort_overview() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_kpis();
CREATE OR REPLACE FUNCTION rpc_r2839_kpis()
RETURNS TABLE (
  total_units bigint, total_refurb bigint, total_retire bigint, total_replace bigint,
  total_refurb_cost numeric, total_replace_cost numeric, total_expected_revenue numeric, escalate_cohorts bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(SUM(units_total),0)::bigint,
           COALESCE(SUM(units_refurb),0)::bigint,
           COALESCE(SUM(units_retire),0)::bigint,
           COALESCE(SUM(units_replace),0)::bigint,
           COALESCE(SUM(refurb_cost_lakhs),0)::numeric,
           COALESCE(SUM(replace_cost_lakhs),0)::numeric,
           COALESCE(SUM(expected_revenue_lakhs),0)::numeric,
           COALESCE(SUM(CASE WHEN verdict = 'escalate_review' THEN 1 ELSE 0 END),0)::bigint
    FROM chain_fleet_cohorts_r2839;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_kpis() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_verdict_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2839_verdict_breakdown()
RETURNS TABLE (verdict text, cohort_count bigint, units_sum bigint, cost_sum numeric, revenue_sum numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.verdict,
           COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           COALESCE(SUM(c.refurb_cost_lakhs + c.replace_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.verdict
    ORDER BY revenue_sum DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_verdict_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_chain_rollup();
CREATE OR REPLACE FUNCTION rpc_r2839_chain_rollup()
RETURNS TABLE (chain_code text, chain_name text, cohorts bigint, units_total bigint, refurb_cost numeric, replace_cost numeric, expected_revenue numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, MAX(c.chain_name), COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           COALESCE(SUM(c.refurb_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.replace_cost_lakhs),0)::numeric,
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.chain_code
    ORDER BY expected_revenue DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_chain_rollup() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_recent_runs();
CREATE OR REPLACE FUNCTION rpc_r2839_recent_runs()
RETURNS TABLE (chain_code text, run_quarter text, run_date date, units_actioned integer, cost_committed_lakhs numeric, revenue_actual_lakhs numeric, refurb_success_pct numeric, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_code, r.run_quarter, r.run_date, r.units_actioned,
           r.cost_committed_lakhs, r.revenue_actual_lakhs, r.refurb_success_pct, r.status, r.notes
    FROM chain_rejuvenation_runs_r2839 r
    ORDER BY r.run_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_recent_runs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_recent_runs() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_roi_ranking();
CREATE OR REPLACE FUNCTION rpc_r2839_roi_ranking()
RETURNS TABLE (chain_code text, cohort_label text, total_cost numeric, expected_revenue numeric, roi_multiple numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.chain_code, c.cohort_label,
           (c.refurb_cost_lakhs + c.replace_cost_lakhs)::numeric AS total_cost,
           c.expected_revenue_lakhs,
           CASE WHEN (c.refurb_cost_lakhs + c.replace_cost_lakhs) = 0 THEN 0
                ELSE ROUND(c.expected_revenue_lakhs / (c.refurb_cost_lakhs + c.replace_cost_lakhs), 2) END AS roi_multiple,
           c.verdict
    FROM chain_fleet_cohorts_r2839 c
    ORDER BY roi_multiple DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_roi_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_roi_ranking() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_category_mix();
CREATE OR REPLACE FUNCTION rpc_r2839_category_mix()
RETURNS TABLE (asset_category text, cohorts bigint, units_total bigint, avg_age numeric, expected_revenue numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.asset_category, COUNT(*)::bigint,
           COALESCE(SUM(c.units_total),0)::bigint,
           ROUND(AVG(c.avg_age_years)::numeric, 2),
           COALESCE(SUM(c.expected_revenue_lakhs),0)::numeric
    FROM chain_fleet_cohorts_r2839 c
    GROUP BY c.asset_category
    ORDER BY expected_revenue DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_category_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_category_mix() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2839_run_health();
CREATE OR REPLACE FUNCTION rpc_r2839_run_health()
RETURNS TABLE (status text, run_count bigint, units_sum bigint, cost_sum numeric, revenue_sum numeric, avg_success numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.status, COUNT(*)::bigint,
           COALESCE(SUM(r.units_actioned),0)::bigint,
           COALESCE(SUM(r.cost_committed_lakhs),0)::numeric,
           COALESCE(SUM(r.revenue_actual_lakhs),0)::numeric,
           ROUND(AVG(r.refurb_success_pct)::numeric, 2)
    FROM chain_rejuvenation_runs_r2839 r
    GROUP BY r.status
    ORDER BY run_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2839_run_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2839_run_health() TO authenticated;

COMMIT;
