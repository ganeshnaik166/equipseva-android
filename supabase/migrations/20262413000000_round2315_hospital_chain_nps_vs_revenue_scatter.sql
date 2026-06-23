BEGIN;

-- =====================================================================
-- r2315 — Hospital chain NPS-vs-revenue scatter
-- Plots each chain on NPS (y) vs revenue (x). Identifies four quadrants:
--   * Expand   — high NPS, low rev   (delight, room to grow)
--   * Protect  — low  NPS, high rev  (at-risk whales)
--   * Star     — high NPS, high rev  (reference accounts)
--   * Fix      — low  NPS, low rev   (deprioritize or fix)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.chain_nps_revenue_snapshots_r2315 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_org_id     uuid NOT NULL,
  chain_name       text NOT NULL,
  region           text NOT NULL,
  hospital_count   int  NOT NULL DEFAULT 0,
  nps_score        numeric(6,2) NOT NULL,
  response_count   int  NOT NULL DEFAULT 0,
  revenue_rupees   numeric(14,2) NOT NULL DEFAULT 0,
  amc_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  job_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  quadrant         text NOT NULL CHECK (quadrant IN ('star','expand','protect','fix')),
  prior_nps_score  numeric(6,2),
  prior_revenue_rupees numeric(14,2),
  snapshot_date    date NOT NULL DEFAULT CURRENT_DATE,
  notes            text,
  created_by       uuid REFERENCES public.profiles(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_snap_r2315_chain ON public.chain_nps_revenue_snapshots_r2315(chain_org_id);
CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_snap_r2315_date  ON public.chain_nps_revenue_snapshots_r2315(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_snap_r2315_quad  ON public.chain_nps_revenue_snapshots_r2315(quadrant);

ALTER TABLE public.chain_nps_revenue_snapshots_r2315 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_nps_revenue_snapshots_r2315;
CREATE POLICY founder_all ON public.chain_nps_revenue_snapshots_r2315
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.chain_nps_revenue_actions_r2315 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_org_id        uuid NOT NULL,
  chain_name          text NOT NULL,
  quadrant            text NOT NULL CHECK (quadrant IN ('star','expand','protect','fix')),
  action_type         text NOT NULL CHECK (action_type IN ('expand_outreach','retention_save','reference_call','deprioritize','price_review','exec_visit')),
  action_owner_email  text,
  due_date            date,
  status              text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  notes               text,
  created_by          uuid REFERENCES public.profiles(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_act_r2315_chain  ON public.chain_nps_revenue_actions_r2315(chain_org_id);
CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_act_r2315_status ON public.chain_nps_revenue_actions_r2315(status);
CREATE INDEX IF NOT EXISTS idx_chain_nps_rev_act_r2315_due    ON public.chain_nps_revenue_actions_r2315(due_date);

ALTER TABLE public.chain_nps_revenue_actions_r2315 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_nps_revenue_actions_r2315;
CREATE POLICY founder_all ON public.chain_nps_revenue_actions_r2315
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: headline KPI
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_headline_kpi_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_headline_kpi_r2315()
RETURNS TABLE (
  chains_tracked      int,
  star_count          int,
  expand_count        int,
  protect_count       int,
  fix_count           int,
  total_revenue_rupees numeric,
  protect_revenue_rupees numeric,
  weighted_nps        numeric,
  open_actions        int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT
    COUNT(*)::int                                                AS chains_tracked,
    COUNT(*) FILTER (WHERE quadrant='star')::int                 AS star_count,
    COUNT(*) FILTER (WHERE quadrant='expand')::int               AS expand_count,
    COUNT(*) FILTER (WHERE quadrant='protect')::int              AS protect_count,
    COUNT(*) FILTER (WHERE quadrant='fix')::int                  AS fix_count,
    COALESCE(SUM(revenue_rupees),0)                              AS total_revenue_rupees,
    COALESCE(SUM(revenue_rupees) FILTER (WHERE quadrant='protect'),0) AS protect_revenue_rupees,
    CASE WHEN SUM(revenue_rupees) > 0
      THEN ROUND(SUM(nps_score * revenue_rupees) / SUM(revenue_rupees), 2)
      ELSE 0 END                                                 AS weighted_nps,
    (SELECT COUNT(*) FROM public.chain_nps_revenue_actions_r2315 WHERE status IN ('open','in_progress'))::int AS open_actions
  FROM latest;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_headline_kpi_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_headline_kpi_r2315() TO authenticated;

-- =====================================================================
-- RPC 2: scatter points (latest per chain)
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_scatter_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_scatter_r2315()
RETURNS TABLE (
  chain_name       text,
  region           text,
  hospital_count   int,
  nps_score        numeric,
  revenue_rupees   numeric,
  quadrant         text,
  snapshot_date    date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT chain_name, region, hospital_count, nps_score, revenue_rupees, quadrant, snapshot_date
  FROM latest
  ORDER BY revenue_rupees DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_scatter_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_scatter_r2315() TO authenticated;

-- =====================================================================
-- RPC 3: expand candidates (high NPS, low revenue)
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_expand_candidates_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_expand_candidates_r2315()
RETURNS TABLE (
  chain_name        text,
  region            text,
  hospital_count    int,
  nps_score         numeric,
  revenue_rupees    numeric,
  prior_revenue_rupees numeric,
  amc_revenue_rupees numeric,
  notes             text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT chain_name, region, hospital_count, nps_score, revenue_rupees, prior_revenue_rupees, amc_revenue_rupees, notes
  FROM latest
  WHERE quadrant='expand'
  ORDER BY nps_score DESC, revenue_rupees ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_expand_candidates_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_expand_candidates_r2315() TO authenticated;

-- =====================================================================
-- RPC 4: protect candidates (low NPS, high revenue — at-risk whales)
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_protect_candidates_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_protect_candidates_r2315()
RETURNS TABLE (
  chain_name        text,
  region            text,
  hospital_count    int,
  nps_score         numeric,
  prior_nps_score   numeric,
  revenue_rupees    numeric,
  amc_revenue_rupees numeric,
  job_revenue_rupees numeric,
  notes             text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT chain_name, region, hospital_count, nps_score, prior_nps_score, revenue_rupees, amc_revenue_rupees, job_revenue_rupees, notes
  FROM latest
  WHERE quadrant='protect'
  ORDER BY revenue_rupees DESC, nps_score ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_protect_candidates_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_protect_candidates_r2315() TO authenticated;

-- =====================================================================
-- RPC 5: quadrant roll-up
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_quadrant_rollup_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_quadrant_rollup_r2315()
RETURNS TABLE (
  quadrant          text,
  chain_count       int,
  total_revenue_rupees numeric,
  avg_nps_score     numeric,
  avg_revenue_rupees numeric,
  playbook          text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT
    l.quadrant,
    COUNT(*)::int,
    COALESCE(SUM(l.revenue_rupees),0),
    ROUND(AVG(l.nps_score)::numeric, 2),
    ROUND(AVG(l.revenue_rupees)::numeric, 2),
    CASE l.quadrant
      WHEN 'star'    THEN 'Reference call, case study, expand share-of-wallet'
      WHEN 'expand'  THEN 'AMC upsell, multi-site rollout, exec sponsor'
      WHEN 'protect' THEN 'Retention save, exec visit, root-cause review'
      WHEN 'fix'     THEN 'Triage or deprioritize — fix only if strategic'
    END
  FROM latest l
  GROUP BY l.quadrant
  ORDER BY SUM(l.revenue_rupees) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_quadrant_rollup_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_quadrant_rollup_r2315() TO authenticated;

-- =====================================================================
-- RPC 6: region roll-up
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_region_rollup_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_region_rollup_r2315()
RETURNS TABLE (
  region            text,
  chain_count       int,
  weighted_nps      numeric,
  total_revenue_rupees numeric,
  protect_count     int,
  expand_count      int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (chain_org_id) *
    FROM public.chain_nps_revenue_snapshots_r2315
    ORDER BY chain_org_id, snapshot_date DESC
  )
  SELECT
    l.region,
    COUNT(*)::int,
    CASE WHEN SUM(l.revenue_rupees) > 0
      THEN ROUND(SUM(l.nps_score * l.revenue_rupees) / SUM(l.revenue_rupees), 2)
      ELSE 0 END,
    COALESCE(SUM(l.revenue_rupees),0),
    COUNT(*) FILTER (WHERE l.quadrant='protect')::int,
    COUNT(*) FILTER (WHERE l.quadrant='expand')::int
  FROM latest l
  GROUP BY l.region
  ORDER BY SUM(l.revenue_rupees) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_region_rollup_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_region_rollup_r2315() TO authenticated;

-- =====================================================================
-- RPC 7: open actions queue
-- =====================================================================
DROP FUNCTION IF EXISTS public.chain_nps_rev_open_actions_r2315();
CREATE OR REPLACE FUNCTION public.chain_nps_rev_open_actions_r2315()
RETURNS TABLE (
  chain_name        text,
  quadrant          text,
  action_type       text,
  action_owner_email text,
  due_date          date,
  status            text,
  notes             text,
  created_at        timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT chain_name, quadrant, action_type, action_owner_email, due_date, status, notes, created_at
  FROM public.chain_nps_revenue_actions_r2315
  WHERE status IN ('open','in_progress')
  ORDER BY
    CASE quadrant WHEN 'protect' THEN 1 WHEN 'expand' THEN 2 WHEN 'fix' THEN 3 ELSE 4 END,
    due_date NULLS LAST,
    created_at DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.chain_nps_rev_open_actions_r2315() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_rev_open_actions_r2315() TO authenticated;

COMMIT;
