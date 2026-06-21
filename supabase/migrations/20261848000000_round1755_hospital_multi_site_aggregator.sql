BEGIN;

-- Round 1755: Hospital Multi-Site Aggregator
-- Aggregate metrics across all sites of a hospital chain.

CREATE TABLE IF NOT EXISTS public.hospital_chain_aggregates_r1755 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  site_count int NOT NULL DEFAULT 0,
  total_active_amc int NOT NULL DEFAULT 0,
  total_monthly_revenue_rupees bigint NOT NULL DEFAULT 0,
  avg_satisfaction_score numeric(4,2),
  aggregated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hca_r1755_chain ON public.hospital_chain_aggregates_r1755 (chain_org_id);
CREATE INDEX IF NOT EXISTS idx_hca_r1755_aggregated_at ON public.hospital_chain_aggregates_r1755 (aggregated_at DESC);
CREATE INDEX IF NOT EXISTS idx_hca_r1755_revenue ON public.hospital_chain_aggregates_r1755 (total_monthly_revenue_rupees DESC);

CREATE TABLE IF NOT EXISTS public.hospital_chain_site_breakdown_r1755 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_id uuid NOT NULL REFERENCES public.hospital_chain_aggregates_r1755(id) ON DELETE CASCADE,
  site_hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amc_count int NOT NULL DEFAULT 0,
  monthly_revenue_rupees bigint NOT NULL DEFAULT 0,
  satisfaction_score numeric(4,2),
  status text NOT NULL CHECK (status IN ('active','at_risk','churned')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcsb_r1755_agg ON public.hospital_chain_site_breakdown_r1755 (aggregate_id);
CREATE INDEX IF NOT EXISTS idx_hcsb_r1755_site ON public.hospital_chain_site_breakdown_r1755 (site_hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hcsb_r1755_status ON public.hospital_chain_site_breakdown_r1755 (status);

ALTER TABLE public.hospital_chain_aggregates_r1755 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_site_breakdown_r1755 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hca_r1755_founder ON public.hospital_chain_aggregates_r1755;
CREATE POLICY hca_r1755_founder ON public.hospital_chain_aggregates_r1755
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hcsb_r1755_founder ON public.hospital_chain_site_breakdown_r1755;
CREATE POLICY hcsb_r1755_founder ON public.hospital_chain_site_breakdown_r1755
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_chains
CREATE OR REPLACE FUNCTION public.list_chains_r1755()
RETURNS TABLE (
  id uuid,
  chain_org_id uuid,
  chain_name text,
  site_count int,
  total_active_amc int,
  total_monthly_revenue_rupees bigint,
  avg_satisfaction_score numeric,
  aggregated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.chain_org_id, o.name AS chain_name, a.site_count,
         a.total_active_amc, a.total_monthly_revenue_rupees,
         a.avg_satisfaction_score, a.aggregated_at
  FROM public.hospital_chain_aggregates_r1755 a
  JOIN public.organizations o ON o.id = a.chain_org_id
  ORDER BY a.aggregated_at DESC
  LIMIT 200;
END;
$$;

-- 2. aggregate_chain (write)
CREATE OR REPLACE FUNCTION public.aggregate_chain_r1755(
  p_chain_org_id uuid,
  p_site_count int,
  p_total_active_amc int,
  p_total_monthly_revenue_rupees bigint,
  p_avg_satisfaction_score numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_chain_aggregates_r1755 (
    chain_org_id, site_count, total_active_amc,
    total_monthly_revenue_rupees, avg_satisfaction_score
  )
  VALUES (
    p_chain_org_id, p_site_count, p_total_active_amc,
    p_total_monthly_revenue_rupees, p_avg_satisfaction_score
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'aggregate_chain_r1755',
    jsonb_build_object(
      'aggregate_id', v_id,
      'chain_org_id', p_chain_org_id,
      'site_count', p_site_count,
      'total_monthly_revenue_rupees', p_total_monthly_revenue_rupees
    )
  );
  RETURN v_id;
END;
$$;

-- 3. list_breakdown
CREATE OR REPLACE FUNCTION public.list_breakdown_r1755(p_aggregate_id uuid)
RETURNS TABLE (
  id uuid,
  aggregate_id uuid,
  site_hospital_user_id uuid,
  site_name text,
  amc_count int,
  monthly_revenue_rupees bigint,
  satisfaction_score numeric,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.aggregate_id, b.site_hospital_user_id,
         COALESCE(p.full_name, p.email, 'site') AS site_name,
         b.amc_count, b.monthly_revenue_rupees,
         b.satisfaction_score, b.status
  FROM public.hospital_chain_site_breakdown_r1755 b
  LEFT JOIN public.profiles p ON p.id = b.site_hospital_user_id
  WHERE b.aggregate_id = p_aggregate_id
  ORDER BY b.monthly_revenue_rupees DESC
  LIMIT 500;
END;
$$;

-- 4. refresh_breakdown (write)
CREATE OR REPLACE FUNCTION public.refresh_breakdown_r1755(
  p_aggregate_id uuid,
  p_site_hospital_user_id uuid,
  p_amc_count int,
  p_monthly_revenue_rupees bigint,
  p_satisfaction_score numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('active','at_risk','churned') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  INSERT INTO public.hospital_chain_site_breakdown_r1755 (
    aggregate_id, site_hospital_user_id, amc_count,
    monthly_revenue_rupees, satisfaction_score, status
  )
  VALUES (
    p_aggregate_id, p_site_hospital_user_id, p_amc_count,
    p_monthly_revenue_rupees, p_satisfaction_score, p_status
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'refresh_breakdown_r1755',
    jsonb_build_object(
      'breakdown_id', v_id,
      'aggregate_id', p_aggregate_id,
      'site_hospital_user_id', p_site_hospital_user_id,
      'status', p_status
    )
  );
  RETURN v_id;
END;
$$;

-- 5. top_chains_by_revenue
CREATE OR REPLACE FUNCTION public.top_chains_by_revenue_r1755()
RETURNS TABLE (
  chain_org_id uuid,
  chain_name text,
  site_count int,
  total_monthly_revenue_rupees bigint,
  total_active_amc int,
  aggregated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT DISTINCT ON (a.chain_org_id)
         a.chain_org_id, o.name AS chain_name, a.site_count,
         a.total_monthly_revenue_rupees, a.total_active_amc, a.aggregated_at
  FROM public.hospital_chain_aggregates_r1755 a
  JOIN public.organizations o ON o.id = a.chain_org_id
  ORDER BY a.chain_org_id, a.aggregated_at DESC;
END;
$$;

-- 6. at_risk_chains
CREATE OR REPLACE FUNCTION public.at_risk_chains_r1755()
RETURNS TABLE (
  chain_org_id uuid,
  chain_name text,
  at_risk_sites int,
  churned_sites int,
  total_sites int,
  avg_satisfaction_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.chain_org_id,
         o.name AS chain_name,
         (COUNT(*) FILTER (WHERE b.status = 'at_risk'))::int AS at_risk_sites,
         (COUNT(*) FILTER (WHERE b.status = 'churned'))::int AS churned_sites,
         (COUNT(*))::int AS total_sites,
         AVG(b.satisfaction_score) AS avg_satisfaction_score
  FROM public.hospital_chain_aggregates_r1755 a
  JOIN public.organizations o ON o.id = a.chain_org_id
  JOIN public.hospital_chain_site_breakdown_r1755 b ON b.aggregate_id = a.id
  GROUP BY a.chain_org_id, o.name
  HAVING (COUNT(*) FILTER (WHERE b.status IN ('at_risk','churned'))) > 0
  ORDER BY at_risk_sites DESC, churned_sites DESC
  LIMIT 100;
END;
$$;

-- 7. recent_aggregations
CREATE OR REPLACE FUNCTION public.recent_aggregations_r1755()
RETURNS TABLE (
  id uuid,
  chain_org_id uuid,
  chain_name text,
  site_count int,
  total_monthly_revenue_rupees bigint,
  aggregated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.chain_org_id, o.name AS chain_name,
         a.site_count, a.total_monthly_revenue_rupees, a.aggregated_at
  FROM public.hospital_chain_aggregates_r1755 a
  JOIN public.organizations o ON o.id = a.chain_org_id
  ORDER BY a.aggregated_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chains_r1755() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.aggregate_chain_r1755(uuid, int, int, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_breakdown_r1755(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_breakdown_r1755(uuid, uuid, int, bigint, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_revenue_r1755() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_chains_r1755() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_aggregations_r1755() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chains_r1755() TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_chain_r1755(uuid, int, int, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_breakdown_r1755(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_breakdown_r1755(uuid, uuid, int, bigint, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_chains_by_revenue_r1755() TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_chains_r1755() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_aggregations_r1755() TO authenticated;

COMMIT;