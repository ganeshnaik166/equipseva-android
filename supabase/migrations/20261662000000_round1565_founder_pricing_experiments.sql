BEGIN;

-- =========================================================================
-- r1565 — Founder Pricing Experiments
-- A/B price experiments across customer segments with conversion + revenue
-- impact tracking, and founder approve/promote winning variant workflow.
-- =========================================================================

-- Experiments registry
CREATE TABLE IF NOT EXISTS founder_pricing_experiments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  hypothesis text,
  customer_segment text NOT NULL CHECK (customer_segment IN ('class_a','class_b','class_c','dental','super_specialty','chain','all')),
  product_scope text NOT NULL CHECK (product_scope IN ('amc','repair','spare_parts','marketplace')),
  control_price_rupees integer NOT NULL CHECK (control_price_rupees >= 0),
  variant_price_rupees integer NOT NULL CHECK (variant_price_rupees >= 0),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','running','paused','promoted','rejected','completed')),
  promoted_variant text CHECK (promoted_variant IN ('control','variant')),
  started_at timestamptz,
  ended_at timestamptz,
  promoted_at timestamptz,
  promoted_by uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id) DEFAULT auth.uid()
);

CREATE INDEX IF NOT EXISTS idx_fpe_status ON founder_pricing_experiments(status);
CREATE INDEX IF NOT EXISTS idx_fpe_segment ON founder_pricing_experiments(customer_segment);
CREATE INDEX IF NOT EXISTS idx_fpe_started_at ON founder_pricing_experiments(started_at DESC);

ALTER TABLE founder_pricing_experiments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fpe ON founder_pricing_experiments;
CREATE POLICY founder_only_fpe ON founder_pricing_experiments
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- Experiment exposures: one row per user assignment / observed event
CREATE TABLE IF NOT EXISTS founder_pricing_experiment_exposures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id uuid NOT NULL REFERENCES founder_pricing_experiments(id) ON DELETE CASCADE,
  bucket text NOT NULL CHECK (bucket IN ('control','variant')),
  subject_user_id uuid REFERENCES auth.users(id),
  subject_org_id uuid REFERENCES organizations(id),
  exposed_at timestamptz NOT NULL DEFAULT now(),
  converted boolean NOT NULL DEFAULT false,
  converted_at timestamptz,
  realized_revenue_rupees integer DEFAULT 0 CHECK (realized_revenue_rupees >= 0),
  metadata jsonb
);

CREATE INDEX IF NOT EXISTS idx_fpee_exp ON founder_pricing_experiment_exposures(experiment_id);
CREATE INDEX IF NOT EXISTS idx_fpee_bucket ON founder_pricing_experiment_exposures(experiment_id, bucket);
CREATE INDEX IF NOT EXISTS idx_fpee_converted ON founder_pricing_experiment_exposures(experiment_id, converted);

ALTER TABLE founder_pricing_experiment_exposures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fpee ON founder_pricing_experiment_exposures;
CREATE POLICY founder_only_fpee ON founder_pricing_experiment_exposures
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_pricing_experiment_create(p_experiment_id uuid, p_name text, p_segment text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pricing_experiment_create',
    jsonb_build_object('experiment_id', p_experiment_id, 'name', p_name, 'segment', p_segment));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pricing_experiment_create(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pricing_experiment_create(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pricing_experiment_status_change(p_experiment_id uuid, p_from text, p_to text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pricing_experiment_status_change',
    jsonb_build_object('experiment_id', p_experiment_id, 'from', p_from, 'to', p_to));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pricing_experiment_status_change(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pricing_experiment_status_change(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pricing_experiment_promote(p_experiment_id uuid, p_winning_variant text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pricing_experiment_promote',
    jsonb_build_object('experiment_id', p_experiment_id, 'winning_variant', p_winning_variant));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pricing_experiment_promote(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pricing_experiment_promote(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pricing_experiment_reject(p_experiment_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pricing_experiment_reject',
    jsonb_build_object('experiment_id', p_experiment_id, 'reason', p_reason));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pricing_experiment_reject(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pricing_experiment_reject(uuid, text) TO authenticated;

-- =========================================================================
-- READ RPCs (STABLE SECDEF)
-- =========================================================================

DROP FUNCTION IF EXISTS founder_pricing_experiments_summary();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_summary()
RETURNS TABLE(
  total_experiments bigint,
  running_experiments bigint,
  draft_experiments bigint,
  promoted_experiments bigint,
  rejected_experiments bigint,
  completed_experiments bigint,
  total_exposures bigint,
  total_conversions bigint,
  overall_conversion_pct numeric,
  total_realized_revenue_rupees bigint,
  avg_control_price_rupees numeric,
  avg_variant_price_rupees numeric,
  segments_covered bigint,
  longest_running_days numeric,
  experiments_last_7d bigint,
  experiments_last_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_pricing_experiments),
    (SELECT count(*) FROM founder_pricing_experiments WHERE status = 'running'),
    (SELECT count(*) FROM founder_pricing_experiments WHERE status = 'draft'),
    (SELECT count(*) FROM founder_pricing_experiments WHERE status = 'promoted'),
    (SELECT count(*) FROM founder_pricing_experiments WHERE status = 'rejected'),
    (SELECT count(*) FROM founder_pricing_experiments WHERE status = 'completed'),
    (SELECT count(*) FROM founder_pricing_experiment_exposures),
    (SELECT count(*) FROM founder_pricing_experiment_exposures WHERE converted),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE converted) / NULLIF(count(*), 0), 2) FROM founder_pricing_experiment_exposures), 0),
    COALESCE((SELECT sum(realized_revenue_rupees) FROM founder_pricing_experiment_exposures), 0)::bigint,
    COALESCE((SELECT round(avg(control_price_rupees), 2) FROM founder_pricing_experiments), 0),
    COALESCE((SELECT round(avg(variant_price_rupees), 2) FROM founder_pricing_experiments), 0),
    (SELECT count(DISTINCT customer_segment) FROM founder_pricing_experiments),
    COALESCE((SELECT round(EXTRACT(EPOCH FROM max(COALESCE(ended_at, now()) - started_at))/86400.0, 1) FROM founder_pricing_experiments WHERE started_at IS NOT NULL), 0),
    (SELECT count(*) FROM founder_pricing_experiments WHERE created_at > now() - interval '7 days'),
    (SELECT count(*) FROM founder_pricing_experiments WHERE created_at > now() - interval '30 days');
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_list();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_list()
RETURNS TABLE(
  id uuid,
  name text,
  customer_segment text,
  product_scope text,
  control_price_rupees integer,
  variant_price_rupees integer,
  status text,
  promoted_variant text,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.name, e.customer_segment, e.product_scope, e.control_price_rupees,
         e.variant_price_rupees, e.status, e.promoted_variant, e.started_at, e.ended_at, e.created_at
  FROM founder_pricing_experiments e
  ORDER BY e.created_at DESC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_results();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_results()
RETURNS TABLE(
  experiment_id uuid,
  name text,
  customer_segment text,
  control_exposures bigint,
  control_conversions bigint,
  control_conversion_pct numeric,
  control_revenue_rupees bigint,
  variant_exposures bigint,
  variant_conversions bigint,
  variant_conversion_pct numeric,
  variant_revenue_rupees bigint,
  lift_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.name,
    e.customer_segment,
    COALESCE((SELECT count(*) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'control'), 0),
    COALESCE((SELECT count(*) FILTER (WHERE x.converted) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'control'), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE x.converted) / NULLIF(count(*), 0), 2) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'control'), 0),
    COALESCE((SELECT sum(x.realized_revenue_rupees) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'control'), 0)::bigint,
    COALESCE((SELECT count(*) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'variant'), 0),
    COALESCE((SELECT count(*) FILTER (WHERE x.converted) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'variant'), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE x.converted) / NULLIF(count(*), 0), 2) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'variant'), 0),
    COALESCE((SELECT sum(x.realized_revenue_rupees) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id AND x.bucket = 'variant'), 0)::bigint,
    COALESCE((
      SELECT round(
        100.0 * (
          (count(*) FILTER (WHERE x.converted AND x.bucket = 'variant')::numeric / NULLIF(count(*) FILTER (WHERE x.bucket = 'variant'), 0))
          -
          (count(*) FILTER (WHERE x.converted AND x.bucket = 'control')::numeric / NULLIF(count(*) FILTER (WHERE x.bucket = 'control'), 0))
        ) / NULLIF((count(*) FILTER (WHERE x.converted AND x.bucket = 'control')::numeric / NULLIF(count(*) FILTER (WHERE x.bucket = 'control'), 0)), 0),
        2)
      FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id
    ), 0),
    e.status
  FROM founder_pricing_experiments e
  ORDER BY e.created_at DESC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_results() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_results() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_by_segment();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_by_segment()
RETURNS TABLE(
  customer_segment text,
  experiment_count bigint,
  running_count bigint,
  promoted_count bigint,
  avg_control_price_rupees numeric,
  avg_variant_price_rupees numeric,
  total_exposures bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.customer_segment,
    count(*),
    count(*) FILTER (WHERE e.status = 'running'),
    count(*) FILTER (WHERE e.status = 'promoted'),
    COALESCE(round(avg(e.control_price_rupees), 2), 0),
    COALESCE(round(avg(e.variant_price_rupees), 2), 0),
    COALESCE((SELECT count(*) FROM founder_pricing_experiment_exposures x JOIN founder_pricing_experiments e2 ON e2.id = x.experiment_id WHERE e2.customer_segment = e.customer_segment), 0),
    COALESCE((SELECT sum(x.realized_revenue_rupees) FROM founder_pricing_experiment_exposures x JOIN founder_pricing_experiments e2 ON e2.id = x.experiment_id WHERE e2.customer_segment = e.customer_segment), 0)::bigint
  FROM founder_pricing_experiments e
  GROUP BY e.customer_segment
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_by_segment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_by_segment() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_by_scope();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_by_scope()
RETURNS TABLE(
  product_scope text,
  experiment_count bigint,
  running_count bigint,
  promoted_count bigint,
  total_exposures bigint,
  total_conversions bigint,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.product_scope,
    count(*),
    count(*) FILTER (WHERE e.status = 'running'),
    count(*) FILTER (WHERE e.status = 'promoted'),
    COALESCE((SELECT count(*) FROM founder_pricing_experiment_exposures x JOIN founder_pricing_experiments e2 ON e2.id = x.experiment_id WHERE e2.product_scope = e.product_scope), 0),
    COALESCE((SELECT count(*) FILTER (WHERE x.converted) FROM founder_pricing_experiment_exposures x JOIN founder_pricing_experiments e2 ON e2.id = x.experiment_id WHERE e2.product_scope = e.product_scope), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE x.converted) / NULLIF(count(*), 0), 2) FROM founder_pricing_experiment_exposures x JOIN founder_pricing_experiments e2 ON e2.id = x.experiment_id WHERE e2.product_scope = e.product_scope), 0)
  FROM founder_pricing_experiments e
  GROUP BY e.product_scope
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_by_scope() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_by_scope() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_top_winners();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_top_winners()
RETURNS TABLE(
  experiment_id uuid,
  name text,
  customer_segment text,
  product_scope text,
  promoted_variant text,
  promoted_at timestamptz,
  total_revenue_rupees bigint,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.name,
    e.customer_segment,
    e.product_scope,
    e.promoted_variant,
    e.promoted_at,
    COALESCE((SELECT sum(x.realized_revenue_rupees) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id), 0)::bigint,
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE x.converted) / NULLIF(count(*), 0), 2) FROM founder_pricing_experiment_exposures x WHERE x.experiment_id = e.id), 0)
  FROM founder_pricing_experiments e
  WHERE e.status = 'promoted'
  ORDER BY e.promoted_at DESC NULLS LAST
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_top_winners() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_top_winners() TO authenticated;

DROP FUNCTION IF EXISTS founder_pricing_experiments_recent_exposures();
CREATE OR REPLACE FUNCTION founder_pricing_experiments_recent_exposures()
RETURNS TABLE(
  id uuid,
  experiment_id uuid,
  experiment_name text,
  bucket text,
  exposed_at timestamptz,
  converted boolean,
  realized_revenue_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.experiment_id, e.name, x.bucket, x.exposed_at, x.converted, x.realized_revenue_rupees
  FROM founder_pricing_experiment_exposures x
  JOIN founder_pricing_experiments e ON e.id = x.experiment_id
  ORDER BY x.exposed_at DESC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiments_recent_exposures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiments_recent_exposures() TO authenticated;

-- =========================================================================
-- WRITE RPC (VOLATILE SECDEF) — promote winning variant
-- =========================================================================

DROP FUNCTION IF EXISTS founder_pricing_experiment_promote(uuid, text);
CREATE OR REPLACE FUNCTION founder_pricing_experiment_promote(p_experiment_id uuid, p_winning_variant text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_winning_variant NOT IN ('control','variant') THEN RAISE EXCEPTION 'invalid_variant'; END IF;
  UPDATE founder_pricing_experiments
     SET status = 'promoted',
         promoted_variant = p_winning_variant,
         promoted_at = now(),
         promoted_by = auth.uid(),
         ended_at = COALESCE(ended_at, now())
   WHERE id = p_experiment_id;
  PERFORM log_founder_pricing_experiment_promote(p_experiment_id, p_winning_variant);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_pricing_experiment_promote(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_pricing_experiment_promote(uuid, text) TO authenticated;

COMMIT;