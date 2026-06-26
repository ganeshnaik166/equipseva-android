BEGIN;

-- Round 2813: Founder Quarterly Design System Evolution
-- Tracks design token churn, component adoption, override hotspots, refactor
-- backlog, and quarter-over-quarter design system stability for the founder.

CREATE TABLE IF NOT EXISTS design_system_quarter_tokens_r2813 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  token_name text NOT NULL,
  token_category text NOT NULL CHECK (token_category IN ('color','spacing','typography','radius','elevation','motion')),
  prior_value text,
  current_value text NOT NULL,
  change_kind text NOT NULL CHECK (change_kind IN ('introduced','renamed','retuned','deprecated','stable')),
  adoption_pct numeric(5,2) NOT NULL CHECK (adoption_pct BETWEEN 0 AND 100),
  override_count integer NOT NULL DEFAULT 0 CHECK (override_count >= 0),
  refactor_required boolean NOT NULL DEFAULT false,
  stability_score numeric(5,2) NOT NULL CHECK (stability_score BETWEEN 0 AND 100),
  verdict text NOT NULL CHECK (verdict IN ('keep','watch','retune','rollback','promote')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE design_system_quarter_tokens_r2813 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON design_system_quarter_tokens_r2813;
CREATE POLICY founder_all ON design_system_quarter_tokens_r2813
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS design_system_quarter_components_r2813 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  component_name text NOT NULL,
  surface_area text NOT NULL CHECK (surface_area IN ('founder','engineer','hospital','public','investor','shared')),
  adoption_count integer NOT NULL DEFAULT 0 CHECK (adoption_count >= 0),
  override_count integer NOT NULL DEFAULT 0 CHECK (override_count >= 0),
  refactor_backlog integer NOT NULL DEFAULT 0 CHECK (refactor_backlog >= 0),
  stability_score numeric(5,2) NOT NULL CHECK (stability_score BETWEEN 0 AND 100),
  a11y_score numeric(5,2) NOT NULL CHECK (a11y_score BETWEEN 0 AND 100),
  verdict text NOT NULL CHECK (verdict IN ('keep','watch','retune','rollback','promote')),
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE design_system_quarter_components_r2813 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON design_system_quarter_components_r2813;
CREATE POLICY founder_all ON design_system_quarter_components_r2813
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Seed tokens (6 rows)
INSERT INTO design_system_quarter_tokens_r2813
  (quarter, token_name, token_category, prior_value, current_value, change_kind, adoption_pct, override_count, refactor_required, stability_score, verdict)
VALUES
  ('2026Q2','color.brand.primary','color','#0F62FE','#0B5CD8','retuned',92.40,3,false,94.10,'keep'),
  ('2026Q2','space.scale.4','spacing','12px','12px','stable',98.70,0,false,99.00,'promote'),
  ('2026Q2','type.body.md','typography','15px/22px','16px/24px','retuned',74.20,11,true,71.80,'watch'),
  ('2026Q2','radius.card','radius','8px','10px','retuned',81.30,7,true,77.40,'retune'),
  ('2026Q2','elevation.popover','elevation','0 6px 18px','0 8px 24px','introduced',55.90,2,false,68.20,'watch'),
  ('2026Q2','motion.fast','motion','120ms','100ms','retuned',64.10,5,true,62.50,'retune');

-- Seed components (6 rows)
INSERT INTO design_system_quarter_components_r2813
  (quarter, component_name, surface_area, adoption_count, override_count, refactor_backlog, stability_score, a11y_score, verdict, notes)
VALUES
  ('2026Q2','DataTable','founder',147,4,2,96.20,93.10,'promote','high adoption, low overrides'),
  ('2026Q2','KpiCard','founder',92,3,1,94.80,91.40,'keep','primary surface for KPIs'),
  ('2026Q2','BannerAlert','shared',61,12,4,72.30,85.60,'retune','colour overrides leaking from legacy'),
  ('2026Q2','Modal','shared',58,9,3,77.40,82.20,'watch','focus-trap a11y gaps'),
  ('2026Q2','EngineerJobCard','engineer',74,2,0,93.40,88.90,'keep','low churn since r2400'),
  ('2026Q2','InvestorShareCard','investor',23,6,2,68.10,79.40,'retune','public surface needs polish');

-- ============================================================================
-- RPCs (7 minimum). All plpgsql, SECURITY DEFINER, is_founder() gated.
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2813_token_overview();
CREATE OR REPLACE FUNCTION founder_r2813_token_overview()
RETURNS TABLE (
  total_tokens integer,
  retuned_count integer,
  introduced_count integer,
  deprecated_count integer,
  avg_adoption numeric,
  avg_stability numeric,
  override_total integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE change_kind = 'retuned')::int,
    COUNT(*) FILTER (WHERE change_kind = 'introduced')::int,
    COUNT(*) FILTER (WHERE change_kind = 'deprecated')::int,
    ROUND(AVG(adoption_pct)::numeric, 2),
    ROUND(AVG(stability_score)::numeric, 2),
    COALESCE(SUM(override_count), 0)::int
  FROM design_system_quarter_tokens_r2813;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_token_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_token_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_token_rows();
CREATE OR REPLACE FUNCTION founder_r2813_token_rows()
RETURNS TABLE (
  id uuid,
  quarter text,
  token_name text,
  token_category text,
  change_kind text,
  prior_value text,
  current_value text,
  adoption_pct numeric,
  override_count integer,
  refactor_required boolean,
  stability_score numeric,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.quarter, t.token_name, t.token_category, t.change_kind,
         t.prior_value, t.current_value, t.adoption_pct, t.override_count,
         t.refactor_required, t.stability_score, t.verdict
  FROM design_system_quarter_tokens_r2813 t
  ORDER BY t.stability_score ASC, t.token_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_token_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_token_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_component_overview();
CREATE OR REPLACE FUNCTION founder_r2813_component_overview()
RETURNS TABLE (
  total_components integer,
  adoption_total integer,
  override_total integer,
  refactor_backlog_total integer,
  avg_stability numeric,
  avg_a11y numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(adoption_count),0)::int,
    COALESCE(SUM(override_count),0)::int,
    COALESCE(SUM(refactor_backlog),0)::int,
    ROUND(AVG(stability_score)::numeric, 2),
    ROUND(AVG(a11y_score)::numeric, 2)
  FROM design_system_quarter_components_r2813;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_component_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_component_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_component_rows();
CREATE OR REPLACE FUNCTION founder_r2813_component_rows()
RETURNS TABLE (
  id uuid,
  quarter text,
  component_name text,
  surface_area text,
  adoption_count integer,
  override_count integer,
  refactor_backlog integer,
  stability_score numeric,
  a11y_score numeric,
  verdict text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.quarter, c.component_name, c.surface_area, c.adoption_count,
         c.override_count, c.refactor_backlog, c.stability_score, c.a11y_score,
         c.verdict, c.notes
  FROM design_system_quarter_components_r2813 c
  ORDER BY c.stability_score ASC, c.component_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_component_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_component_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_override_hotspots();
CREATE OR REPLACE FUNCTION founder_r2813_override_hotspots()
RETURNS TABLE (
  source text,
  name text,
  category_or_surface text,
  override_count integer,
  stability_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'token'::text, t.token_name, t.token_category, t.override_count, t.stability_score
  FROM design_system_quarter_tokens_r2813 t
  WHERE t.override_count > 0
  UNION ALL
  SELECT 'component'::text, c.component_name, c.surface_area, c.override_count, c.stability_score
  FROM design_system_quarter_components_r2813 c
  WHERE c.override_count > 0
  ORDER BY override_count DESC, stability_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_override_hotspots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_override_hotspots() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_refactor_queue();
CREATE OR REPLACE FUNCTION founder_r2813_refactor_queue()
RETURNS TABLE (
  source text,
  name text,
  bucket text,
  workload integer,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'token'::text, t.token_name, t.token_category, t.override_count, t.verdict
  FROM design_system_quarter_tokens_r2813 t
  WHERE t.refactor_required
  UNION ALL
  SELECT 'component'::text, c.component_name, c.surface_area, c.refactor_backlog, c.verdict
  FROM design_system_quarter_components_r2813 c
  WHERE c.refactor_backlog > 0
  ORDER BY workload DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_refactor_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_refactor_queue() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2813_verdict_mix()
RETURNS TABLE (
  source text,
  verdict text,
  cnt integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'token'::text, t.verdict, COUNT(*)::int
  FROM design_system_quarter_tokens_r2813 t
  GROUP BY t.verdict
  UNION ALL
  SELECT 'component'::text, c.verdict, COUNT(*)::int
  FROM design_system_quarter_components_r2813 c
  GROUP BY c.verdict
  ORDER BY source, cnt DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_verdict_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2813_surface_stability();
CREATE OR REPLACE FUNCTION founder_r2813_surface_stability()
RETURNS TABLE (
  surface_area text,
  components integer,
  avg_stability numeric,
  avg_a11y numeric,
  overrides integer,
  backlog integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.surface_area,
    COUNT(*)::int,
    ROUND(AVG(c.stability_score)::numeric, 2),
    ROUND(AVG(c.a11y_score)::numeric, 2),
    COALESCE(SUM(c.override_count),0)::int,
    COALESCE(SUM(c.refactor_backlog),0)::int
  FROM design_system_quarter_components_r2813 c
  GROUP BY c.surface_area
  ORDER BY avg_stability ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2813_surface_stability() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2813_surface_stability() TO authenticated;

COMMIT;
