-- Round r2573: Founder quarterly spend vs revenue attribution
-- Tables: founder_quarterly_spend_revenue_r2573, spend_attribution_changes_r2573
-- 7 RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.founder_quarterly_spend_revenue_r2573 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  team_kind text NOT NULL CHECK (team_kind IN ('engineering','sales','marketing','operations','founder_office','customer_success')),
  spend_rupees bigint NOT NULL DEFAULT 0,
  revenue_attributed_rupees bigint NOT NULL DEFAULT 0,
  cac_rupees bigint NOT NULL DEFAULT 0,
  ltv_rupees bigint NOT NULL DEFAULT 0,
  payback_months numeric NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','published')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.spend_attribution_changes_r2573 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  allocation_id uuid NOT NULL REFERENCES public.founder_quarterly_spend_revenue_r2573(id) ON DELETE CASCADE,
  changed_at timestamptz NOT NULL DEFAULT now(),
  change_kind text NOT NULL CHECK (change_kind IN ('reallocation','expansion','cut','reclassification')),
  prior_spend_rupees bigint NOT NULL DEFAULT 0,
  new_spend_rupees bigint NOT NULL DEFAULT 0,
  rationale_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_spend_revenue_r2573 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spend_attribution_changes_r2573 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quarterly_spend_revenue_r2573;
CREATE POLICY founder_all ON public.founder_quarterly_spend_revenue_r2573
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.spend_attribution_changes_r2573;
CREATE POLICY founder_all ON public.spend_attribution_changes_r2573
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed allocations
INSERT INTO public.founder_quarterly_spend_revenue_r2573
  (id, quarter_label, team_kind, spend_rupees, revenue_attributed_rupees, cac_rupees, ltv_rupees, payback_months, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101', 'Q1-2026', 'sales', 4500000, 18000000, 12000, 96000, 4.2, 'cfo@equipseva.in', 'published', 'Hospital chain expansion sales push'),
  ('11111111-1111-1111-1111-111111111102', 'Q1-2026', 'marketing', 2200000, 7800000, 9500, 72000, 5.8, 'cmo@equipseva.in', 'final', 'NABH+CAHO conference marketing'),
  ('11111111-1111-1111-1111-111111111103', 'Q1-2026', 'engineering', 6800000, 12000000, 0, 0, 0, 'cto@equipseva.in', 'published', 'Engineer marketplace platform build'),
  ('11111111-1111-1111-1111-111111111104', 'Q1-2026', 'customer_success', 1800000, 9200000, 4500, 110000, 2.3, 'csm@equipseva.in', 'final', 'AMC renewals + upsell'),
  ('11111111-1111-1111-1111-111111111105', 'Q1-2026', 'operations', 1500000, 3200000, 0, 0, 0, 'coo@equipseva.in', 'draft', 'Spare part logistics ops')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.spend_attribution_changes_r2573
  (allocation_id, change_kind, prior_spend_rupees, new_spend_rupees, rationale_md, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101', 'expansion', 3500000, 4500000, 'Added 2 enterprise AEs for chain accounts', 'cfo@equipseva.in', 'done', 'Approved by board'),
  ('11111111-1111-1111-1111-111111111102', 'reallocation', 2800000, 2200000, 'Cut paid LinkedIn, doubled down on conferences', 'cmo@equipseva.in', 'done', 'Better CAC signal'),
  ('11111111-1111-1111-1111-111111111103', 'expansion', 5200000, 6800000, 'Hired 3 senior engineers for marketplace v2', 'cto@equipseva.in', 'done', 'Q2 ship target'),
  ('11111111-1111-1111-1111-111111111105', 'cut', 2100000, 1500000, 'Outsourced last-mile to 3PL partner', 'coo@equipseva.in', 'open', 'Pending vendor SLA review')
ON CONFLICT (id) DO NOTHING;

-- RPC 1: list spend revenue
CREATE OR REPLACE FUNCTION public.list_spend_revenue_r2573()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  team_kind text,
  spend_rupees bigint,
  revenue_attributed_rupees bigint,
  cac_rupees bigint,
  ltv_rupees bigint,
  payback_months numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.team_kind, s.spend_rupees, s.revenue_attributed_rupees,
         s.cac_rupees, s.ltv_rupees, s.payback_months, s.owner_email, s.status, s.notes, s.created_at
  FROM public.founder_quarterly_spend_revenue_r2573 s
  ORDER BY s.created_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_spend_revenue_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_spend_revenue_r2573() TO authenticated;

-- RPC 2: list attribution changes
CREATE OR REPLACE FUNCTION public.list_attribution_changes_r2573()
RETURNS TABLE (
  id uuid,
  allocation_id uuid,
  quarter_label text,
  team_kind text,
  change_kind text,
  prior_spend_rupees bigint,
  new_spend_rupees bigint,
  delta_rupees bigint,
  rationale_md text,
  owner_email text,
  status text,
  changed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.allocation_id, s.quarter_label, s.team_kind, c.change_kind,
         c.prior_spend_rupees, c.new_spend_rupees,
         (c.new_spend_rupees - c.prior_spend_rupees)::bigint AS delta_rupees,
         c.rationale_md, c.owner_email, c.status, c.changed_at
  FROM public.spend_attribution_changes_r2573 c
  JOIN public.founder_quarterly_spend_revenue_r2573 s ON s.id = c.allocation_id
  ORDER BY c.changed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attribution_changes_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attribution_changes_r2573() TO authenticated;

-- RPC 3: top payback teams
CREATE OR REPLACE FUNCTION public.top_payback_teams_r2573()
RETURNS TABLE (
  team_kind text,
  payback_months numeric,
  spend_rupees bigint,
  revenue_attributed_rupees bigint,
  quarter_label text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_kind, s.payback_months, s.spend_rupees, s.revenue_attributed_rupees, s.quarter_label
  FROM public.founder_quarterly_spend_revenue_r2573 s
  WHERE s.payback_months > 0
  ORDER BY s.payback_months ASC NULLS LAST
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_payback_teams_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_payback_teams_r2573() TO authenticated;

-- RPC 4: team kind distribution
CREATE OR REPLACE FUNCTION public.team_kind_distribution_r2573()
RETURNS TABLE (
  team_kind text,
  allocation_count bigint,
  total_spend_rupees bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_kind,
         COUNT(*)::bigint AS allocation_count,
         COALESCE(SUM(s.spend_rupees),0)::bigint AS total_spend_rupees,
         COALESCE(SUM(s.revenue_attributed_rupees),0)::bigint AS total_revenue_rupees
  FROM public.founder_quarterly_spend_revenue_r2573 s
  GROUP BY s.team_kind
  ORDER BY total_spend_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.team_kind_distribution_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.team_kind_distribution_r2573() TO authenticated;

-- RPC 5: ltv cac ratio summary
CREATE OR REPLACE FUNCTION public.ltv_cac_ratio_summary_r2573()
RETURNS TABLE (
  team_kind text,
  avg_cac_rupees numeric,
  avg_ltv_rupees numeric,
  ltv_cac_ratio numeric,
  sample_size bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_kind,
         AVG(NULLIF(s.cac_rupees,0))::numeric AS avg_cac_rupees,
         AVG(NULLIF(s.ltv_rupees,0))::numeric AS avg_ltv_rupees,
         CASE WHEN AVG(NULLIF(s.cac_rupees,0)) > 0
              THEN (AVG(NULLIF(s.ltv_rupees,0)) / AVG(NULLIF(s.cac_rupees,0)))::numeric
              ELSE 0::numeric END AS ltv_cac_ratio,
         COUNT(*)::bigint AS sample_size
  FROM public.founder_quarterly_spend_revenue_r2573 s
  WHERE s.cac_rupees > 0
  GROUP BY s.team_kind
  ORDER BY ltv_cac_ratio DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.ltv_cac_ratio_summary_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ltv_cac_ratio_summary_r2573() TO authenticated;

-- RPC 6: monthly spend trend (by created_at month)
CREATE OR REPLACE FUNCTION public.monthly_spend_trend_r2573()
RETURNS TABLE (
  month_label text,
  allocation_count bigint,
  total_spend_rupees bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', s.created_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS allocation_count,
         COALESCE(SUM(s.spend_rupees),0)::bigint AS total_spend_rupees,
         COALESCE(SUM(s.revenue_attributed_rupees),0)::bigint AS total_revenue_rupees
  FROM public.founder_quarterly_spend_revenue_r2573 s
  GROUP BY date_trunc('month', s.created_at)
  ORDER BY date_trunc('month', s.created_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_spend_trend_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_spend_trend_r2573() TO authenticated;

-- RPC 7: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2573()
RETURNS TABLE (
  status text,
  allocation_count bigint,
  total_spend_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status,
         COUNT(*)::bigint AS allocation_count,
         COALESCE(SUM(s.spend_rupees),0)::bigint AS total_spend_rupees
  FROM public.founder_quarterly_spend_revenue_r2573 s
  GROUP BY s.status
  ORDER BY allocation_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2573() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2573() TO authenticated;
