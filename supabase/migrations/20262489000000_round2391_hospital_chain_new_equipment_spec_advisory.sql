BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_chain_spec_advisories_r2391 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_admin_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  equipment_category text NOT NULL,
  budget_rupees bigint,
  hospitals_count int NOT NULL DEFAULT 1,
  ask_summary text NOT NULL,
  our_recommendation text,
  recommended_brand text,
  recommended_model text,
  recommended_price_rupees bigint,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','recommended','installed','lost','withdrawn')),
  asked_at timestamptz NOT NULL DEFAULT now(),
  recommended_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_chain_spec_outcomes_r2391 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advisory_id uuid NOT NULL REFERENCES public.founder_chain_spec_advisories_r2391(id) ON DELETE CASCADE,
  outcome text NOT NULL CHECK (outcome IN ('followed_install','followed_other_vendor','rejected','pending')),
  units_installed int NOT NULL DEFAULT 0,
  final_brand text,
  final_model text,
  final_price_rupees bigint,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_chain_spec_advisories_r2391 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_chain_spec_outcomes_r2391 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_advisories_r2391 ON public.founder_chain_spec_advisories_r2391;
CREATE POLICY founder_all_advisories_r2391 ON public.founder_chain_spec_advisories_r2391
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_outcomes_r2391 ON public.founder_chain_spec_outcomes_r2391;
CREATE POLICY founder_all_outcomes_r2391 ON public.founder_chain_spec_outcomes_r2391
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_advisories_r2391_status ON public.founder_chain_spec_advisories_r2391(status);
CREATE INDEX IF NOT EXISTS idx_advisories_r2391_chain ON public.founder_chain_spec_advisories_r2391(chain_admin_user_id);
CREATE INDEX IF NOT EXISTS idx_advisories_r2391_category ON public.founder_chain_spec_advisories_r2391(equipment_category);
CREATE INDEX IF NOT EXISTS idx_advisories_r2391_asked ON public.founder_chain_spec_advisories_r2391(asked_at DESC);
CREATE INDEX IF NOT EXISTS idx_outcomes_r2391_advisory ON public.founder_chain_spec_outcomes_r2391(advisory_id);
CREATE INDEX IF NOT EXISTS idx_outcomes_r2391_outcome ON public.founder_chain_spec_outcomes_r2391(outcome);

DROP FUNCTION IF EXISTS public.list_chain_spec_advisories_r2391();
CREATE OR REPLACE FUNCTION public.list_chain_spec_advisories_r2391()
RETURNS TABLE (
  id uuid,
  chain_admin_user_id uuid,
  chain_name text,
  equipment_category text,
  budget_rupees bigint,
  hospitals_count int,
  ask_summary text,
  our_recommendation text,
  recommended_brand text,
  recommended_model text,
  recommended_price_rupees bigint,
  status text,
  asked_at timestamptz,
  recommended_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_admin_user_id, a.chain_name, a.equipment_category, a.budget_rupees,
         a.hospitals_count, a.ask_summary, a.our_recommendation, a.recommended_brand,
         a.recommended_model, a.recommended_price_rupees, a.status, a.asked_at,
         a.recommended_at, a.decided_at, a.created_at
  FROM public.founder_chain_spec_advisories_r2391 a
  ORDER BY a.asked_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.list_chain_spec_outcomes_r2391();
CREATE OR REPLACE FUNCTION public.list_chain_spec_outcomes_r2391()
RETURNS TABLE (
  id uuid,
  advisory_id uuid,
  outcome text,
  units_installed int,
  final_brand text,
  final_model text,
  final_price_rupees bigint,
  notes text,
  recorded_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.advisory_id, o.outcome, o.units_installed, o.final_brand,
         o.final_model, o.final_price_rupees, o.notes, o.recorded_at, o.created_at
  FROM public.founder_chain_spec_outcomes_r2391 o
  ORDER BY o.recorded_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.win_rate_by_category_r2391();
CREATE OR REPLACE FUNCTION public.win_rate_by_category_r2391()
RETURNS TABLE (
  equipment_category text,
  advisory_count bigint,
  installed_count bigint,
  lost_count bigint,
  win_rate_pct numeric,
  total_units_installed bigint,
  total_revenue_assist_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.equipment_category,
         COUNT(*)::bigint AS advisory_count,
         COUNT(*) FILTER (WHERE a.status = 'installed')::bigint AS installed_count,
         COUNT(*) FILTER (WHERE a.status = 'lost')::bigint AS lost_count,
         ROUND(
           CASE WHEN COUNT(*) FILTER (WHERE a.status IN ('installed','lost')) > 0
                THEN 100.0 * COUNT(*) FILTER (WHERE a.status = 'installed')::numeric
                     / COUNT(*) FILTER (WHERE a.status IN ('installed','lost'))::numeric
                ELSE 0 END, 1) AS win_rate_pct,
         COALESCE(SUM(o.units_installed) FILTER (WHERE o.outcome = 'followed_install'), 0)::bigint AS total_units_installed,
         COALESCE(SUM(o.final_price_rupees * o.units_installed) FILTER (WHERE o.outcome = 'followed_install'), 0)::bigint AS total_revenue_assist_rupees
  FROM public.founder_chain_spec_advisories_r2391 a
  LEFT JOIN public.founder_chain_spec_outcomes_r2391 o ON o.advisory_id = a.id
  GROUP BY a.equipment_category
  ORDER BY win_rate_pct DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.top_chains_by_advisory_r2391();
CREATE OR REPLACE FUNCTION public.top_chains_by_advisory_r2391()
RETURNS TABLE (
  chain_name text,
  advisory_count bigint,
  installed_count bigint,
  win_rate_pct numeric,
  last_asked_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
         COUNT(*)::bigint AS advisory_count,
         COUNT(*) FILTER (WHERE a.status = 'installed')::bigint AS installed_count,
         ROUND(
           CASE WHEN COUNT(*) FILTER (WHERE a.status IN ('installed','lost')) > 0
                THEN 100.0 * COUNT(*) FILTER (WHERE a.status = 'installed')::numeric
                     / COUNT(*) FILTER (WHERE a.status IN ('installed','lost'))::numeric
                ELSE 0 END, 1) AS win_rate_pct,
         MAX(a.asked_at) AS last_asked_at
  FROM public.founder_chain_spec_advisories_r2391 a
  GROUP BY a.chain_name
  ORDER BY advisory_count DESC, last_asked_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.pipeline_summary_r2391();
CREATE OR REPLACE FUNCTION public.pipeline_summary_r2391()
RETURNS TABLE (
  open_count bigint,
  recommended_count bigint,
  installed_count bigint,
  lost_count bigint,
  withdrawn_count bigint,
  total_pipeline_budget_rupees bigint,
  avg_decision_days numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*) FILTER (WHERE status = 'open')::bigint,
         COUNT(*) FILTER (WHERE status = 'recommended')::bigint,
         COUNT(*) FILTER (WHERE status = 'installed')::bigint,
         COUNT(*) FILTER (WHERE status = 'lost')::bigint,
         COUNT(*) FILTER (WHERE status = 'withdrawn')::bigint,
         COALESCE(SUM(budget_rupees) FILTER (WHERE status IN ('open','recommended')), 0)::bigint,
         COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (decided_at - asked_at)) / 86400.0) FILTER (WHERE decided_at IS NOT NULL), 1), 0)
  FROM public.founder_chain_spec_advisories_r2391;
END;
$$;

DROP FUNCTION IF EXISTS public.stalled_advisories_r2391();
CREATE OR REPLACE FUNCTION public.stalled_advisories_r2391()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_category text,
  status text,
  asked_at timestamptz,
  days_open numeric,
  budget_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.equipment_category, a.status, a.asked_at,
         ROUND(EXTRACT(EPOCH FROM (now() - a.asked_at)) / 86400.0, 1) AS days_open,
         a.budget_rupees
  FROM public.founder_chain_spec_advisories_r2391 a
  WHERE a.status IN ('open','recommended')
    AND a.asked_at < now() - interval '14 days'
  ORDER BY a.asked_at ASC;
END;
$$;

DROP FUNCTION IF EXISTS public.outcomes_for_advisory_r2391(uuid);
CREATE OR REPLACE FUNCTION public.outcomes_for_advisory_r2391(p_advisory_id uuid)
RETURNS TABLE (
  id uuid,
  outcome text,
  units_installed int,
  final_brand text,
  final_model text,
  final_price_rupees bigint,
  notes text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.outcome, o.units_installed, o.final_brand, o.final_model,
         o.final_price_rupees, o.notes, o.recorded_at
  FROM public.founder_chain_spec_outcomes_r2391 o
  WHERE o.advisory_id = p_advisory_id
  ORDER BY o.recorded_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_chain_spec_advisories_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_chain_spec_outcomes_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.win_rate_by_category_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_chains_by_advisory_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pipeline_summary_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.stalled_advisories_r2391() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.outcomes_for_advisory_r2391(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_spec_advisories_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_spec_outcomes_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.win_rate_by_category_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_chains_by_advisory_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pipeline_summary_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stalled_advisories_r2391() TO authenticated;
GRANT EXECUTE ON FUNCTION public.outcomes_for_advisory_r2391(uuid) TO authenticated;

COMMIT;
