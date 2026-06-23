BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_multi_site_rollouts_r2336 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  master_contract_ref text NOT NULL,
  total_sites_planned int NOT NULL CHECK (total_sites_planned > 0),
  sites_signed int NOT NULL DEFAULT 0 CHECK (sites_signed >= 0),
  sites_onboarded int NOT NULL DEFAULT 0 CHECK (sites_onboarded >= 0),
  sites_active int NOT NULL DEFAULT 0 CHECK (sites_active >= 0),
  sites_with_issues int NOT NULL DEFAULT 0 CHECK (sites_with_issues >= 0),
  contract_value_rupees bigint NOT NULL DEFAULT 0,
  rollout_started_at timestamptz NOT NULL DEFAULT now(),
  target_completion_at timestamptz,
  account_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_multi_site_status_r2336 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rollout_id uuid NOT NULL REFERENCES public.customer_multi_site_rollouts_r2336(id) ON DELETE CASCADE,
  site_name text NOT NULL,
  site_city text NOT NULL,
  site_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  status text NOT NULL CHECK (status IN ('signed','onboarded','active','issues')),
  signed_at timestamptz,
  onboarded_at timestamptz,
  activated_at timestamptz,
  last_issue_note text,
  last_issue_at timestamptz,
  equipment_count int NOT NULL DEFAULT 0,
  site_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cmsr_r2336_chain ON public.customer_multi_site_rollouts_r2336(chain_name);
CREATE INDEX IF NOT EXISTS idx_cmss_r2336_rollout ON public.customer_multi_site_status_r2336(rollout_id);
CREATE INDEX IF NOT EXISTS idx_cmss_r2336_status ON public.customer_multi_site_status_r2336(status);

ALTER TABLE public.customer_multi_site_rollouts_r2336 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_multi_site_status_r2336 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_multi_site_rollouts_r2336;
CREATE POLICY founder_all ON public.customer_multi_site_rollouts_r2336
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_multi_site_status_r2336;
CREATE POLICY founder_all ON public.customer_multi_site_status_r2336
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: rollout overview
CREATE OR REPLACE FUNCTION public.r2336_rollout_overview()
RETURNS TABLE (
  id uuid,
  chain_name text,
  master_contract_ref text,
  total_sites_planned int,
  sites_signed int,
  sites_onboarded int,
  sites_active int,
  sites_with_issues int,
  contract_value_rupees bigint,
  pct_active numeric,
  target_completion_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.master_contract_ref, r.total_sites_planned,
         r.sites_signed, r.sites_onboarded, r.sites_active, r.sites_with_issues,
         r.contract_value_rupees,
         ROUND((r.sites_active::numeric / NULLIF(r.total_sites_planned, 0)) * 100, 1) AS pct_active,
         r.target_completion_at
  FROM public.customer_multi_site_rollouts_r2336 r
  ORDER BY r.contract_value_rupees DESC, r.chain_name;
END;
$$;

-- RPC 2: site-level status by chain
CREATE OR REPLACE FUNCTION public.r2336_sites_by_chain(p_chain text)
RETURNS TABLE (
  id uuid,
  site_name text,
  site_city text,
  status text,
  signed_at timestamptz,
  onboarded_at timestamptz,
  activated_at timestamptz,
  equipment_count int,
  last_issue_note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.site_name, s.site_city, s.status,
         s.signed_at, s.onboarded_at, s.activated_at,
         s.equipment_count, s.last_issue_note
  FROM public.customer_multi_site_status_r2336 s
  JOIN public.customer_multi_site_rollouts_r2336 r ON r.id = s.rollout_id
  WHERE r.chain_name ILIKE p_chain
  ORDER BY s.site_city, s.site_name;
END;
$$;

-- RPC 3: stalled sites (signed but not onboarded > 30d)
CREATE OR REPLACE FUNCTION public.r2336_stalled_sites()
RETURNS TABLE (
  chain_name text,
  site_name text,
  site_city text,
  status text,
  signed_at timestamptz,
  days_stalled int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, s.site_name, s.site_city, s.status, s.signed_at,
         EXTRACT(day FROM (now() - s.signed_at))::int AS days_stalled
  FROM public.customer_multi_site_status_r2336 s
  JOIN public.customer_multi_site_rollouts_r2336 r ON r.id = s.rollout_id
  WHERE s.status = 'signed'
    AND s.signed_at IS NOT NULL
    AND s.signed_at < now() - INTERVAL '30 days'
  ORDER BY s.signed_at ASC;
END;
$$;

-- RPC 4: issue sites
CREATE OR REPLACE FUNCTION public.r2336_issue_sites()
RETURNS TABLE (
  chain_name text,
  site_name text,
  site_city text,
  last_issue_note text,
  last_issue_at timestamptz,
  equipment_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, s.site_name, s.site_city, s.last_issue_note, s.last_issue_at, s.equipment_count
  FROM public.customer_multi_site_status_r2336 s
  JOIN public.customer_multi_site_rollouts_r2336 r ON r.id = s.rollout_id
  WHERE s.status = 'issues'
  ORDER BY s.last_issue_at DESC NULLS LAST;
END;
$$;

-- RPC 5: rollout velocity (sites activated per chain in last 30d)
CREATE OR REPLACE FUNCTION public.r2336_rollout_velocity()
RETURNS TABLE (
  chain_name text,
  activated_30d int,
  activated_90d int,
  remaining_to_activate int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name,
         COUNT(*) FILTER (WHERE s.activated_at >= now() - INTERVAL '30 days')::int AS activated_30d,
         COUNT(*) FILTER (WHERE s.activated_at >= now() - INTERVAL '90 days')::int AS activated_90d,
         (r.total_sites_planned - r.sites_active)::int AS remaining_to_activate
  FROM public.customer_multi_site_rollouts_r2336 r
  LEFT JOIN public.customer_multi_site_status_r2336 s ON s.rollout_id = r.id
  GROUP BY r.id, r.chain_name, r.total_sites_planned, r.sites_active
  ORDER BY r.chain_name;
END;
$$;

-- RPC 6: city distribution
CREATE OR REPLACE FUNCTION public.r2336_city_distribution()
RETURNS TABLE (
  site_city text,
  total_sites int,
  active_sites int,
  issue_sites int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.site_city,
         COUNT(*)::int AS total_sites,
         COUNT(*) FILTER (WHERE s.status = 'active')::int AS active_sites,
         COUNT(*) FILTER (WHERE s.status = 'issues')::int AS issue_sites
  FROM public.customer_multi_site_status_r2336 s
  GROUP BY s.site_city
  ORDER BY total_sites DESC;
END;
$$;

-- RPC 7: top-level KPIs
CREATE OR REPLACE FUNCTION public.r2336_top_kpis()
RETURNS TABLE (
  total_chains int,
  total_sites_planned int,
  total_sites_active int,
  total_sites_with_issues int,
  total_contract_value_rupees bigint,
  pct_completion numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(DISTINCT r.id)::int AS total_chains,
         COALESCE(SUM(r.total_sites_planned), 0)::int AS total_sites_planned,
         COALESCE(SUM(r.sites_active), 0)::int AS total_sites_active,
         COALESCE(SUM(r.sites_with_issues), 0)::int AS total_sites_with_issues,
         COALESCE(SUM(r.contract_value_rupees), 0)::bigint AS total_contract_value_rupees,
         ROUND((COALESCE(SUM(r.sites_active), 0)::numeric / NULLIF(SUM(r.total_sites_planned), 0)) * 100, 1) AS pct_completion
  FROM public.customer_multi_site_rollouts_r2336 r;
END;
$$;

REVOKE ALL ON FUNCTION public.r2336_rollout_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_sites_by_chain(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_stalled_sites() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_issue_sites() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_rollout_velocity() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_city_distribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2336_top_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2336_rollout_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_sites_by_chain(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_stalled_sites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_issue_sites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_rollout_velocity() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_city_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2336_top_kpis() TO authenticated;

COMMIT;
