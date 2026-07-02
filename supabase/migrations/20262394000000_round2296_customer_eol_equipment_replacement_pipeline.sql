BEGIN;

-- Round 2296: Customer end-of-life equipment replacement pipeline
-- Tracks aging equipment past supportable life + replacement quote/decision flow

CREATE TABLE IF NOT EXISTS public.eol_equipment_candidates_r2296 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','dental','sterilization','monitoring','surgical','lab','other')),
  manufacturer text,
  model_number text,
  install_year int NOT NULL CHECK (install_year BETWEEN 1980 AND 2100),
  supportable_life_years int NOT NULL DEFAULT 10 CHECK (supportable_life_years BETWEEN 1 AND 40),
  past_eol_years numeric(5,2) NOT NULL DEFAULT 0 CHECK (past_eol_years >= 0),
  spare_parts_available boolean NOT NULL DEFAULT true,
  service_calls_last_12mo int NOT NULL DEFAULT 0 CHECK (service_calls_last_12mo >= 0),
  cumulative_repair_cost_rupees int NOT NULL DEFAULT 0 CHECK (cumulative_repair_cost_rupees >= 0),
  estimated_replacement_cost_rupees int CHECK (estimated_replacement_cost_rupees IS NULL OR estimated_replacement_cost_rupees >= 0),
  risk_score int NOT NULL DEFAULT 50 CHECK (risk_score BETWEEN 0 AND 100),
  pipeline_stage text NOT NULL DEFAULT 'identified' CHECK (pipeline_stage IN ('identified','assessed','quoted','negotiating','approved','ordered','installed','declined')),
  notes text,
  flagged_at timestamptz NOT NULL DEFAULT now(),
  last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eol_candidates_r2296_stage ON public.eol_equipment_candidates_r2296(pipeline_stage);
CREATE INDEX IF NOT EXISTS idx_eol_candidates_r2296_customer ON public.eol_equipment_candidates_r2296(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_eol_candidates_r2296_risk ON public.eol_equipment_candidates_r2296(risk_score DESC);

ALTER TABLE public.eol_equipment_candidates_r2296 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eol_candidates_r2296 ON public.eol_equipment_candidates_r2296;
CREATE POLICY founder_all_eol_candidates_r2296 ON public.eol_equipment_candidates_r2296
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.eol_replacement_quotes_r2296 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.eol_equipment_candidates_r2296(id) ON DELETE CASCADE,
  supplier_org_name text NOT NULL,
  supplier_contact_email text,
  proposed_model text NOT NULL,
  quoted_price_rupees int NOT NULL CHECK (quoted_price_rupees >= 0),
  trade_in_credit_rupees int NOT NULL DEFAULT 0 CHECK (trade_in_credit_rupees >= 0),
  warranty_months int NOT NULL DEFAULT 12 CHECK (warranty_months BETWEEN 0 AND 120),
  delivery_days int NOT NULL DEFAULT 30 CHECK (delivery_days BETWEEN 0 AND 365),
  quote_status text NOT NULL DEFAULT 'open' CHECK (quote_status IN ('open','shortlisted','rejected','accepted','expired')),
  quoted_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_eol_quotes_r2296_candidate ON public.eol_replacement_quotes_r2296(candidate_id);
CREATE INDEX IF NOT EXISTS idx_eol_quotes_r2296_status ON public.eol_replacement_quotes_r2296(quote_status);

ALTER TABLE public.eol_replacement_quotes_r2296 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eol_quotes_r2296 ON public.eol_replacement_quotes_r2296;
CREATE POLICY founder_all_eol_quotes_r2296 ON public.eol_replacement_quotes_r2296
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: pipeline summary
CREATE OR REPLACE FUNCTION public.eol_pipeline_summary_r2296()
RETURNS TABLE(
  pipeline_stage text,
  candidate_count int,
  total_replacement_value_rupees bigint,
  avg_past_eol_years numeric,
  avg_risk_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.pipeline_stage,
    (COUNT(*))::int AS candidate_count,
    COALESCE(SUM(c.estimated_replacement_cost_rupees), 0)::bigint AS total_replacement_value_rupees,
    ROUND(AVG(c.past_eol_years)::numeric, 2) AS avg_past_eol_years,
    ROUND(AVG(c.risk_score)::numeric, 1) AS avg_risk_score
  FROM public.eol_equipment_candidates_r2296 c
  GROUP BY c.pipeline_stage
  ORDER BY c.pipeline_stage;
END $$;

REVOKE ALL ON FUNCTION public.eol_pipeline_summary_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_pipeline_summary_r2296() TO authenticated;

-- RPC 2: top at-risk candidates
CREATE OR REPLACE FUNCTION public.eol_top_at_risk_r2296(p_limit int DEFAULT 25)
RETURNS TABLE(
  id uuid,
  customer_email text,
  equipment_label text,
  equipment_category text,
  past_eol_years numeric,
  risk_score int,
  pipeline_stage text,
  estimated_replacement_cost_rupees int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    (SELECT p.email FROM public.profiles p WHERE p.id = c.customer_user_id),
    c.equipment_label,
    c.equipment_category,
    c.past_eol_years,
    c.risk_score,
    c.pipeline_stage,
    c.estimated_replacement_cost_rupees
  FROM public.eol_equipment_candidates_r2296 c
  WHERE c.pipeline_stage NOT IN ('installed','declined')
  ORDER BY c.risk_score DESC, c.past_eol_years DESC
  LIMIT p_limit;
END $$;

REVOKE ALL ON FUNCTION public.eol_top_at_risk_r2296(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_top_at_risk_r2296(int) TO authenticated;

-- RPC 3: category breakdown
CREATE OR REPLACE FUNCTION public.eol_category_breakdown_r2296()
RETURNS TABLE(
  equipment_category text,
  candidate_count int,
  spare_parts_unavailable_count int,
  avg_service_calls_12mo numeric,
  total_repair_cost_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.equipment_category,
    (COUNT(*))::int AS candidate_count,
    (COUNT(*) FILTER (WHERE NOT c.spare_parts_available))::int AS spare_parts_unavailable_count,
    ROUND(AVG(c.service_calls_last_12mo)::numeric, 2) AS avg_service_calls_12mo,
    COALESCE(SUM(c.cumulative_repair_cost_rupees), 0)::bigint AS total_repair_cost_rupees
  FROM public.eol_equipment_candidates_r2296 c
  GROUP BY c.equipment_category
  ORDER BY candidate_count DESC;
END $$;

REVOKE ALL ON FUNCTION public.eol_category_breakdown_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_category_breakdown_r2296() TO authenticated;

-- RPC 4: quote summary per candidate
CREATE OR REPLACE FUNCTION public.eol_quote_summary_r2296()
RETURNS TABLE(
  candidate_id uuid,
  equipment_label text,
  customer_email text,
  quote_count int,
  min_quote_rupees int,
  max_quote_rupees int,
  accepted_quote_rupees int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id AS candidate_id,
    c.equipment_label,
    (SELECT p.email FROM public.profiles p WHERE p.id = c.customer_user_id),
    (COUNT(q.*))::int AS quote_count,
    (MIN(q.quoted_price_rupees))::int AS min_quote_rupees,
    (MAX(q.quoted_price_rupees))::int AS max_quote_rupees,
    (MAX(q.quoted_price_rupees) FILTER (WHERE q.quote_status = 'accepted'))::int AS accepted_quote_rupees
  FROM public.eol_equipment_candidates_r2296 c
  LEFT JOIN public.eol_replacement_quotes_r2296 q ON q.candidate_id = c.id
  GROUP BY c.id, c.equipment_label, c.customer_user_id
  ORDER BY quote_count DESC NULLS LAST, c.equipment_label;
END $$;

REVOKE ALL ON FUNCTION public.eol_quote_summary_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_quote_summary_r2296() TO authenticated;

-- RPC 5: stale-pipeline alerts (stuck > 30 days)
CREATE OR REPLACE FUNCTION public.eol_stale_alerts_r2296()
RETURNS TABLE(
  id uuid,
  equipment_label text,
  pipeline_stage text,
  days_stuck int,
  past_eol_years numeric,
  customer_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.equipment_label,
    c.pipeline_stage,
    (EXTRACT(EPOCH FROM (now() - c.last_updated_at)) / 86400)::int AS days_stuck,
    c.past_eol_years,
    (SELECT p.email FROM public.profiles p WHERE p.id = c.customer_user_id)
  FROM public.eol_equipment_candidates_r2296 c
  WHERE c.pipeline_stage NOT IN ('installed','declined')
    AND c.last_updated_at < now() - INTERVAL '30 days'
  ORDER BY c.last_updated_at ASC;
END $$;

REVOKE ALL ON FUNCTION public.eol_stale_alerts_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_stale_alerts_r2296() TO authenticated;

-- RPC 6: spare-parts shortage flags
CREATE OR REPLACE FUNCTION public.eol_spare_shortage_r2296()
RETURNS TABLE(
  id uuid,
  equipment_label text,
  manufacturer text,
  model_number text,
  past_eol_years numeric,
  service_calls_last_12mo int,
  customer_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.equipment_label,
    c.manufacturer,
    c.model_number,
    c.past_eol_years,
    c.service_calls_last_12mo,
    (SELECT p.email FROM public.profiles p WHERE p.id = c.customer_user_id)
  FROM public.eol_equipment_candidates_r2296 c
  WHERE NOT c.spare_parts_available
    AND c.pipeline_stage NOT IN ('installed','declined')
  ORDER BY c.past_eol_years DESC;
END $$;

REVOKE ALL ON FUNCTION public.eol_spare_shortage_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_spare_shortage_r2296() TO authenticated;

-- RPC 7: KPI snapshot
CREATE OR REPLACE FUNCTION public.eol_kpi_snapshot_r2296()
RETURNS TABLE(
  total_candidates int,
  active_candidates int,
  installed_count int,
  declined_count int,
  total_pipeline_value_rupees bigint,
  total_accepted_quotes_rupees bigint,
  avg_past_eol_years numeric,
  high_risk_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.eol_equipment_candidates_r2296)::int AS total_candidates,
    (SELECT COUNT(*) FROM public.eol_equipment_candidates_r2296 WHERE pipeline_stage NOT IN ('installed','declined'))::int AS active_candidates,
    (SELECT COUNT(*) FROM public.eol_equipment_candidates_r2296 WHERE pipeline_stage = 'installed')::int AS installed_count,
    (SELECT COUNT(*) FROM public.eol_equipment_candidates_r2296 WHERE pipeline_stage = 'declined')::int AS declined_count,
    (SELECT COALESCE(SUM(estimated_replacement_cost_rupees), 0) FROM public.eol_equipment_candidates_r2296 WHERE pipeline_stage NOT IN ('installed','declined'))::bigint AS total_pipeline_value_rupees,
    (SELECT COALESCE(SUM(quoted_price_rupees), 0) FROM public.eol_replacement_quotes_r2296 WHERE quote_status = 'accepted')::bigint AS total_accepted_quotes_rupees,
    (SELECT ROUND(COALESCE(AVG(past_eol_years), 0)::numeric, 2) FROM public.eol_equipment_candidates_r2296)::numeric AS avg_past_eol_years,
    (SELECT COUNT(*) FROM public.eol_equipment_candidates_r2296 WHERE risk_score >= 75 AND pipeline_stage NOT IN ('installed','declined'))::int AS high_risk_count;
END $$;

REVOKE ALL ON FUNCTION public.eol_kpi_snapshot_r2296() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eol_kpi_snapshot_r2296() TO authenticated;

COMMIT;
