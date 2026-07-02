BEGIN;

-- ============================================================================
-- r1453 — Service Region Heatmap Data Layer
-- Aggregate repair_jobs by city/state into per-region revenue + engineer
-- density + AMC penetration density; surface white-space + over-served regions.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- TABLE 1: service_region_snapshots
-- Daily snapshot of per-region rollups (city,state) for heatmap rendering.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_region_snapshots (
  id bigserial PRIMARY KEY,
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  city text NOT NULL,
  state text NOT NULL,
  jobs_90d integer NOT NULL DEFAULT 0,
  revenue_rupees_90d bigint NOT NULL DEFAULT 0,
  active_engineer_count integer NOT NULL DEFAULT 0,
  active_org_count integer NOT NULL DEFAULT 0,
  amc_active_count integer NOT NULL DEFAULT 0,
  amc_penetration_pct numeric(6,2) NOT NULL DEFAULT 0,
  jobs_per_engineer numeric(8,2) NOT NULL DEFAULT 0,
  revenue_per_engineer_rupees bigint NOT NULL DEFAULT 0,
  heat_score numeric(8,2) NOT NULL DEFAULT 0,
  classification text NOT NULL DEFAULT 'unknown' CHECK (classification IN ('white_space','under_served','balanced','over_served','saturated','unknown')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (snapshot_date, city, state)
);

ALTER TABLE public.service_region_snapshots ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_srs_date ON public.service_region_snapshots(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_srs_state_city ON public.service_region_snapshots(state, city);
CREATE INDEX IF NOT EXISTS idx_srs_classification ON public.service_region_snapshots(classification);

-- ---------------------------------------------------------------------------
-- TABLE 2: service_region_heatmap_audit
-- Append-only audit log of every founder view + recompute action.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_region_heatmap_audit (
  id bigserial PRIMARY KEY,
  actor_user_id uuid NOT NULL,
  action text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.service_region_heatmap_audit ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_srha_actor ON public.service_region_heatmap_audit(actor_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_srha_action ON public.service_region_heatmap_audit(action, created_at DESC);

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF, is_founder gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_founder_region_view()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_region_heatmap_audit(actor_user_id, action, payload)
  VALUES (auth.uid(), 'view_heatmap', jsonb_build_object('at', now()));
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_region_view() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_region_view() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_region_recompute(p_rows int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_region_heatmap_audit(actor_user_id, action, payload)
  VALUES (auth.uid(), 'recompute_snapshot', jsonb_build_object('rows', p_rows, 'at', now()));
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_region_recompute(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_region_recompute(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_region_drilldown(p_city text, p_state text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_region_heatmap_audit(actor_user_id, action, payload)
  VALUES (auth.uid(), 'drilldown', jsonb_build_object('city', p_city, 'state', p_state));
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_region_drilldown(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_region_drilldown(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_region_export()
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.service_region_heatmap_audit(actor_user_id, action, payload)
  VALUES (auth.uid(), 'export', jsonb_build_object('at', now()));
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_region_export() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_region_export() TO authenticated;

-- ============================================================================
-- RPC 1: founder_region_heatmap_kpis
-- Top-level scoreboard numbers.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_kpis()
RETURNS TABLE (
  total_regions int,
  white_space_regions int,
  under_served_regions int,
  balanced_regions int,
  over_served_regions int,
  saturated_regions int,
  total_revenue_rupees_90d bigint,
  total_jobs_90d bigint,
  total_active_engineers int,
  total_active_orgs int,
  total_amc_active int,
  median_amc_penetration_pct numeric,
  median_jobs_per_engineer numeric,
  top_state_by_revenue text,
  top_city_by_revenue text,
  snapshot_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  WITH s AS (
    SELECT * FROM public.service_region_snapshots WHERE snapshot_date = v_snap
  ),
  top_st AS (
    SELECT state, sum(revenue_rupees_90d) r FROM s GROUP BY state ORDER BY r DESC NULLS LAST LIMIT 1
  ),
  top_ct AS (
    SELECT city, revenue_rupees_90d FROM s ORDER BY revenue_rupees_90d DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT count(*)::int FROM s),
    (SELECT count(*)::int FROM s WHERE classification = 'white_space'),
    (SELECT count(*)::int FROM s WHERE classification = 'under_served'),
    (SELECT count(*)::int FROM s WHERE classification = 'balanced'),
    (SELECT count(*)::int FROM s WHERE classification = 'over_served'),
    (SELECT count(*)::int FROM s WHERE classification = 'saturated'),
    COALESCE((SELECT sum(revenue_rupees_90d) FROM s), 0)::bigint,
    COALESCE((SELECT sum(jobs_90d) FROM s), 0)::bigint,
    COALESCE((SELECT sum(active_engineer_count) FROM s), 0)::int,
    COALESCE((SELECT sum(active_org_count) FROM s), 0)::int,
    COALESCE((SELECT sum(amc_active_count) FROM s), 0)::int,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY amc_penetration_pct) FROM s), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY jobs_per_engineer) FROM s), 0)::numeric,
    COALESCE((SELECT state FROM top_st), '—'),
    COALESCE((SELECT city FROM top_ct), '—'),
    v_snap;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: founder_region_heatmap_by_state
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_by_state()
RETURNS TABLE (
  id text,
  state text,
  city_count int,
  jobs_90d bigint,
  revenue_rupees_90d bigint,
  active_engineers bigint,
  active_orgs bigint,
  amc_active bigint,
  amc_penetration_pct numeric,
  classification_mix text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  SELECT
    s.state AS id,
    s.state,
    count(*)::int AS city_count,
    sum(s.jobs_90d)::bigint,
    sum(s.revenue_rupees_90d)::bigint,
    sum(s.active_engineer_count)::bigint,
    sum(s.active_org_count)::bigint,
    sum(s.amc_active_count)::bigint,
    CASE WHEN sum(s.active_org_count) > 0
         THEN round((sum(s.amc_active_count)::numeric / sum(s.active_org_count)::numeric) * 100, 2)
         ELSE 0 END,
    string_agg(DISTINCT s.classification, ', ' ORDER BY s.classification)
  FROM public.service_region_snapshots s
  WHERE s.snapshot_date = v_snap
  GROUP BY s.state
  ORDER BY sum(s.revenue_rupees_90d) DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_by_state() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_by_state() TO authenticated;

-- ============================================================================
-- RPC 3: founder_region_heatmap_top_cities
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_top_cities()
RETURNS TABLE (
  id text,
  city text,
  state text,
  jobs_90d int,
  revenue_rupees_90d bigint,
  active_engineers int,
  amc_active int,
  amc_penetration_pct numeric,
  jobs_per_engineer numeric,
  heat_score numeric,
  classification text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  SELECT
    (s.city || '|' || s.state) AS id,
    s.city, s.state,
    s.jobs_90d, s.revenue_rupees_90d,
    s.active_engineer_count, s.amc_active_count,
    s.amc_penetration_pct, s.jobs_per_engineer,
    s.heat_score, s.classification
  FROM public.service_region_snapshots s
  WHERE s.snapshot_date = v_snap
  ORDER BY s.revenue_rupees_90d DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_top_cities() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_top_cities() TO authenticated;

-- ============================================================================
-- RPC 4: founder_region_heatmap_white_space
-- High org density but low engineer density = expansion candidate.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_white_space()
RETURNS TABLE (
  id text,
  city text,
  state text,
  active_orgs int,
  active_engineers int,
  orgs_per_engineer numeric,
  jobs_90d int,
  amc_penetration_pct numeric,
  opportunity_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  SELECT
    (s.city || '|' || s.state) AS id,
    s.city, s.state,
    s.active_org_count, s.active_engineer_count,
    CASE WHEN s.active_engineer_count > 0
         THEN round(s.active_org_count::numeric / s.active_engineer_count::numeric, 2)
         ELSE s.active_org_count::numeric END,
    s.jobs_90d, s.amc_penetration_pct,
    CASE
      WHEN s.active_engineer_count = 0 AND s.active_org_count >= 3 THEN 'no engineer coverage'
      WHEN s.active_engineer_count > 0 AND (s.active_org_count::numeric / s.active_engineer_count) >= 5 THEN 'engineer under-supply'
      ELSE 'expansion candidate'
    END
  FROM public.service_region_snapshots s
  WHERE s.snapshot_date = v_snap
    AND s.classification IN ('white_space','under_served')
  ORDER BY s.active_org_count DESC NULLS LAST, s.active_engineer_count ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_white_space() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_white_space() TO authenticated;

-- ============================================================================
-- RPC 5: founder_region_heatmap_over_served
-- Too many engineers chasing too few jobs = consolidation candidates.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_over_served()
RETURNS TABLE (
  id text,
  city text,
  state text,
  active_engineers int,
  jobs_90d int,
  jobs_per_engineer numeric,
  revenue_per_engineer_rupees bigint,
  classification text,
  risk_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  SELECT
    (s.city || '|' || s.state) AS id,
    s.city, s.state,
    s.active_engineer_count, s.jobs_90d,
    s.jobs_per_engineer, s.revenue_per_engineer_rupees,
    s.classification,
    CASE
      WHEN s.jobs_per_engineer < 2 THEN 'engineer idle risk'
      WHEN s.revenue_per_engineer_rupees < 500000 THEN 'low earnings risk'
      ELSE 'rebalance candidate'
    END
  FROM public.service_region_snapshots s
  WHERE s.snapshot_date = v_snap
    AND s.classification IN ('over_served','saturated')
  ORDER BY s.jobs_per_engineer ASC NULLS FIRST
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_over_served() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_over_served() TO authenticated;

-- ============================================================================
-- RPC 6: founder_region_heatmap_amc_penetration
-- AMC density per region — sorted lowest first (penetration opportunities).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_amc_penetration()
RETURNS TABLE (
  id text,
  city text,
  state text,
  active_orgs int,
  amc_active int,
  amc_penetration_pct numeric,
  jobs_90d int,
  revenue_rupees_90d bigint,
  classification text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_snap date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(snapshot_date) INTO v_snap FROM public.service_region_snapshots;

  RETURN QUERY
  SELECT
    (s.city || '|' || s.state) AS id,
    s.city, s.state,
    s.active_org_count, s.amc_active_count,
    s.amc_penetration_pct, s.jobs_90d, s.revenue_rupees_90d,
    s.classification
  FROM public.service_region_snapshots s
  WHERE s.snapshot_date = v_snap
    AND s.active_org_count >= 3
  ORDER BY s.amc_penetration_pct ASC NULLS FIRST, s.active_org_count DESC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_amc_penetration() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_amc_penetration() TO authenticated;

-- ============================================================================
-- RPC 7: founder_region_heatmap_recompute
-- Rebuild snapshot for today from repair_jobs + organizations + engineers + amc_contracts.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_region_heatmap_recompute()
RETURNS TABLE (
  rows_written int,
  snapshot_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_rows int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH org_geo AS (
    SELECT o.id AS org_id,
           COALESCE(NULLIF(trim(o.city), ''), 'Unknown') AS city,
           COALESCE(NULLIF(trim(o.state), ''), 'Unknown') AS state
    FROM public.organizations o
  ),
  jobs_agg AS (
    SELECT g.city, g.state,
           count(*) AS jobs_90d,
           COALESCE(sum(rj.total_amount_rupees), 0) AS revenue_rupees_90d
    FROM public.repair_jobs rj
    JOIN org_geo g ON g.org_id = rj.organization_id
    WHERE rj.created_at >= now() - interval '90 days'
    GROUP BY g.city, g.state
  ),
  eng_agg AS (
    SELECT COALESCE(NULLIF(trim(o.city), ''), 'Unknown') AS city,
           COALESCE(NULLIF(trim(o.state), ''), 'Unknown') AS state,
           count(DISTINCT e.id) AS active_engineer_count
    FROM public.engineers e
    LEFT JOIN public.organizations o ON o.id = e.organization_id
    WHERE e.is_active = true
    GROUP BY 1, 2
  ),
  org_agg AS (
    SELECT g.city, g.state, count(DISTINCT g.org_id) AS active_org_count
    FROM org_geo g
    GROUP BY g.city, g.state
  ),
  amc_agg AS (
    SELECT g.city, g.state, count(*) AS amc_active_count
    FROM public.amc_contracts c
    JOIN org_geo g ON g.org_id = c.organization_id
    WHERE c.status = 'active'
    GROUP BY g.city, g.state
  ),
  combined AS (
    SELECT
      COALESCE(j.city, e.city, o.city, a.city) AS city,
      COALESCE(j.state, e.state, o.state, a.state) AS state,
      COALESCE(j.jobs_90d, 0)::int AS jobs_90d,
      COALESCE(j.revenue_rupees_90d, 0)::bigint AS revenue_rupees_90d,
      COALESCE(e.active_engineer_count, 0)::int AS active_engineer_count,
      COALESCE(o.active_org_count, 0)::int AS active_org_count,
      COALESCE(a.amc_active_count, 0)::int AS amc_active_count
    FROM jobs_agg j
    FULL OUTER JOIN eng_agg e ON e.city = j.city AND e.state = j.state
    FULL OUTER JOIN org_agg o ON o.city = COALESCE(j.city, e.city) AND o.state = COALESCE(j.state, e.state)
    FULL OUTER JOIN amc_agg a ON a.city = COALESCE(j.city, e.city, o.city) AND a.state = COALESCE(j.state, e.state, o.state)
  ),
  scored AS (
    SELECT c.*,
      CASE WHEN c.active_org_count > 0
           THEN round((c.amc_active_count::numeric / c.active_org_count::numeric) * 100, 2)
           ELSE 0 END AS amc_penetration_pct,
      CASE WHEN c.active_engineer_count > 0
           THEN round(c.jobs_90d::numeric / c.active_engineer_count::numeric, 2)
           ELSE 0 END AS jobs_per_engineer,
      CASE WHEN c.active_engineer_count > 0
           THEN (c.revenue_rupees_90d / c.active_engineer_count)::bigint
           ELSE 0::bigint END AS revenue_per_engineer_rupees
    FROM combined c
    WHERE c.city IS NOT NULL AND c.state IS NOT NULL
  ),
  final AS (
    SELECT s.*,
      round(
        (least(s.jobs_90d, 200)::numeric * 0.4)
        + (least(s.revenue_rupees_90d / 100000.0, 200)::numeric * 0.3)
        + (s.amc_penetration_pct * 0.3)
      , 2) AS heat_score,
      CASE
        WHEN s.active_org_count = 0 AND s.active_engineer_count = 0 THEN 'unknown'
        WHEN s.active_org_count >= 3 AND s.active_engineer_count = 0 THEN 'white_space'
        WHEN s.active_engineer_count > 0 AND (s.active_org_count::numeric / NULLIF(s.active_engineer_count,0)) >= 5 THEN 'under_served'
        WHEN s.active_engineer_count > 0 AND s.jobs_per_engineer < 2 THEN 'over_served'
        WHEN s.active_engineer_count > 0 AND s.jobs_per_engineer < 1 AND s.active_engineer_count >= 5 THEN 'saturated'
        ELSE 'balanced'
      END AS classification
    FROM scored s
  )
  INSERT INTO public.service_region_snapshots
    (snapshot_date, city, state, jobs_90d, revenue_rupees_90d, active_engineer_count,
     active_org_count, amc_active_count, amc_penetration_pct, jobs_per_engineer,
     revenue_per_engineer_rupees, heat_score, classification)
  SELECT v_today, f.city, f.state, f.jobs_90d, f.revenue_rupees_90d, f.active_engineer_count,
         f.active_org_count, f.amc_active_count, f.amc_penetration_pct, f.jobs_per_engineer,
         f.revenue_per_engineer_rupees, f.heat_score, f.classification
  FROM final f
  ON CONFLICT (snapshot_date, city, state) DO UPDATE SET
    jobs_90d = EXCLUDED.jobs_90d,
    revenue_rupees_90d = EXCLUDED.revenue_rupees_90d,
    active_engineer_count = EXCLUDED.active_engineer_count,
    active_org_count = EXCLUDED.active_org_count,
    amc_active_count = EXCLUDED.amc_active_count,
    amc_penetration_pct = EXCLUDED.amc_penetration_pct,
    jobs_per_engineer = EXCLUDED.jobs_per_engineer,
    revenue_per_engineer_rupees = EXCLUDED.revenue_per_engineer_rupees,
    heat_score = EXCLUDED.heat_score,
    classification = EXCLUDED.classification;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  RETURN QUERY SELECT v_rows, v_today;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_region_heatmap_recompute() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_region_heatmap_recompute() TO authenticated;

COMMIT;