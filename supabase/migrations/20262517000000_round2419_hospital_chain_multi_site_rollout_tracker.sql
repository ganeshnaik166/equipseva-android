-- Round r2419: Hospital chain multi-site rollout tracker
-- Tracks chain-level rollouts across sites, ARR realization, blockers, and go-live timeline.

BEGIN;

-- =====================================================================
-- Table 1: chain_rollout_sites_r2419
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_rollout_sites_r2419 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  site_label text NOT NULL,
  site_city text NOT NULL,
  deployment_status text NOT NULL CHECK (deployment_status IN ('planned','in_progress','deployed','delayed','cancelled')),
  planned_go_live_at timestamptz,
  actual_go_live_at timestamptz,
  days_delta integer,
  arr_per_site_rupees bigint NOT NULL DEFAULT 0 CHECK (arr_per_site_rupees >= 0),
  blocker_kind text NOT NULL DEFAULT 'none' CHECK (blocker_kind IN ('none','legal','integration','training','equipment','other')),
  blocker_notes text,
  owner_email text,
  notes text
);

ALTER TABLE public.chain_rollout_sites_r2419 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_rollout_sites_r2419;
CREATE POLICY founder_all ON public.chain_rollout_sites_r2419
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_chain_rollout_sites_r2419_chain ON public.chain_rollout_sites_r2419(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_rollout_sites_r2419_status ON public.chain_rollout_sites_r2419(deployment_status);
CREATE INDEX IF NOT EXISTS idx_chain_rollout_sites_r2419_planned ON public.chain_rollout_sites_r2419(planned_go_live_at);

-- =====================================================================
-- Table 2: chain_rollout_arr_snapshots_r2419
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_rollout_arr_snapshots_r2419 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  snapshot_date date NOT NULL DEFAULT current_date,
  total_sites integer NOT NULL DEFAULT 0 CHECK (total_sites >= 0),
  deployed_sites integer NOT NULL DEFAULT 0 CHECK (deployed_sites >= 0),
  in_progress_sites integer NOT NULL DEFAULT 0 CHECK (in_progress_sites >= 0),
  delayed_sites integer NOT NULL DEFAULT 0 CHECK (delayed_sites >= 0),
  total_arr_target_rupees bigint NOT NULL DEFAULT 0 CHECK (total_arr_target_rupees >= 0),
  total_arr_realized_rupees bigint NOT NULL DEFAULT 0 CHECK (total_arr_realized_rupees >= 0),
  realized_pct numeric(6,2) NOT NULL DEFAULT 0 CHECK (realized_pct >= 0 AND realized_pct <= 100)
);

ALTER TABLE public.chain_rollout_arr_snapshots_r2419 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_rollout_arr_snapshots_r2419;
CREATE POLICY founder_all ON public.chain_rollout_arr_snapshots_r2419
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_chain_rollout_arr_r2419_chain ON public.chain_rollout_arr_snapshots_r2419(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_rollout_arr_r2419_date ON public.chain_rollout_arr_snapshots_r2419(snapshot_date DESC);

-- =====================================================================
-- Seed data
-- =====================================================================
INSERT INTO public.chain_rollout_sites_r2419 (chain_name, site_label, site_city, deployment_status, planned_go_live_at, actual_go_live_at, days_delta, arr_per_site_rupees, blocker_kind, blocker_notes, owner_email, notes)
VALUES
  ('Apollo Chain', 'Apollo Hyderabad Jubilee Hills', 'Hyderabad', 'deployed', now() - interval '60 days', now() - interval '55 days', -5, 1800000, 'none', NULL, 'rollout@apollo.example', 'Pilot site, exceeded plan'),
  ('Apollo Chain', 'Apollo Bangalore Bannerghatta', 'Bangalore', 'in_progress', now() + interval '10 days', NULL, NULL, 1650000, 'integration', 'HIS integration with Apollo MIRACLE pending', 'rollout@apollo.example', 'Tech team review week of go-live'),
  ('Apollo Chain', 'Apollo Chennai Greams Road', 'Chennai', 'delayed', now() - interval '14 days', NULL, 14, 1500000, 'legal', 'MSA addendum stuck with legal', 'rollout@apollo.example', 'Escalate to CFO'),
  ('Manipal Chain', 'Manipal Whitefield', 'Bangalore', 'deployed', now() - interval '30 days', now() - interval '28 days', -2, 1400000, 'none', NULL, 'ops@manipal.example', 'Smooth go-live'),
  ('Manipal Chain', 'Manipal Mangaluru', 'Mangaluru', 'planned', now() + interval '45 days', NULL, NULL, 1200000, 'training', 'Biomed engineer training scheduled', 'ops@manipal.example', 'Training batch Q2'),
  ('Fortis Chain', 'Fortis Mulund', 'Mumbai', 'delayed', now() - interval '21 days', NULL, 21, 1900000, 'equipment', 'CT-scanner spare parts stuck at customs', 'rollout@fortis.example', 'Logistics escalation in flight');

INSERT INTO public.chain_rollout_arr_snapshots_r2419 (chain_name, snapshot_date, total_sites, deployed_sites, in_progress_sites, delayed_sites, total_arr_target_rupees, total_arr_realized_rupees, realized_pct)
VALUES
  ('Apollo Chain', current_date, 3, 1, 1, 1, 4950000, 1800000, 36.36),
  ('Manipal Chain', current_date, 2, 1, 0, 0, 2600000, 1400000, 53.85),
  ('Fortis Chain', current_date, 1, 0, 0, 1, 1900000, 0, 0.00),
  ('Apollo Chain', current_date - 30, 3, 0, 2, 1, 4950000, 0, 0.00);

-- =====================================================================
-- RPCs
-- =====================================================================

-- RPC 1: list rollout sites
CREATE OR REPLACE FUNCTION public.list_rollout_sites_r2419()
RETURNS TABLE (
  id uuid,
  chain_name text,
  site_label text,
  site_city text,
  deployment_status text,
  planned_go_live_at timestamptz,
  actual_go_live_at timestamptz,
  days_delta integer,
  arr_per_site_rupees bigint,
  blocker_kind text,
  blocker_notes text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.site_label, s.site_city, s.deployment_status,
         s.planned_go_live_at, s.actual_go_live_at, s.days_delta,
         s.arr_per_site_rupees, s.blocker_kind, s.blocker_notes,
         s.owner_email, s.notes, s.created_at
  FROM public.chain_rollout_sites_r2419 s
  ORDER BY s.chain_name ASC, s.planned_go_live_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_rollout_sites_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rollout_sites_r2419() TO authenticated;

-- RPC 2: list ARR snapshots
CREATE OR REPLACE FUNCTION public.list_arr_snapshots_r2419()
RETURNS TABLE (
  id uuid,
  chain_name text,
  snapshot_date date,
  total_sites integer,
  deployed_sites integer,
  in_progress_sites integer,
  delayed_sites integer,
  total_arr_target_rupees bigint,
  total_arr_realized_rupees bigint,
  realized_pct numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.snapshot_date, a.total_sites, a.deployed_sites,
         a.in_progress_sites, a.delayed_sites, a.total_arr_target_rupees,
         a.total_arr_realized_rupees, a.realized_pct, a.created_at
  FROM public.chain_rollout_arr_snapshots_r2419 a
  ORDER BY a.snapshot_date DESC, a.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_arr_snapshots_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_arr_snapshots_r2419() TO authenticated;

-- RPC 3: top delayed sites
CREATE OR REPLACE FUNCTION public.top_delayed_sites_r2419()
RETURNS TABLE (
  id uuid,
  chain_name text,
  site_label text,
  site_city text,
  days_delta integer,
  arr_per_site_rupees bigint,
  blocker_kind text,
  blocker_notes text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.site_label, s.site_city,
         COALESCE(s.days_delta, 0) AS days_delta,
         s.arr_per_site_rupees, s.blocker_kind, s.blocker_notes, s.owner_email
  FROM public.chain_rollout_sites_r2419 s
  WHERE s.deployment_status = 'delayed'
  ORDER BY COALESCE(s.days_delta, 0) DESC, s.arr_per_site_rupees DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_delayed_sites_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_delayed_sites_r2419() TO authenticated;

-- RPC 4: chain realization summary
CREATE OR REPLACE FUNCTION public.chain_realization_summary_r2419()
RETURNS TABLE (
  chain_name text,
  total_sites bigint,
  deployed_sites bigint,
  in_progress_sites bigint,
  delayed_sites bigint,
  planned_sites bigint,
  arr_target_rupees bigint,
  arr_realized_rupees bigint,
  realized_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_name,
         COUNT(*)::bigint AS total_sites,
         COUNT(*) FILTER (WHERE s.deployment_status = 'deployed')::bigint AS deployed_sites,
         COUNT(*) FILTER (WHERE s.deployment_status = 'in_progress')::bigint AS in_progress_sites,
         COUNT(*) FILTER (WHERE s.deployment_status = 'delayed')::bigint AS delayed_sites,
         COUNT(*) FILTER (WHERE s.deployment_status = 'planned')::bigint AS planned_sites,
         COALESCE(SUM(s.arr_per_site_rupees), 0)::bigint AS arr_target_rupees,
         COALESCE(SUM(s.arr_per_site_rupees) FILTER (WHERE s.deployment_status = 'deployed'), 0)::bigint AS arr_realized_rupees,
         CASE WHEN COALESCE(SUM(s.arr_per_site_rupees), 0) = 0 THEN 0
              ELSE ROUND(100.0 * COALESCE(SUM(s.arr_per_site_rupees) FILTER (WHERE s.deployment_status = 'deployed'), 0)
                              / NULLIF(SUM(s.arr_per_site_rupees), 0), 2)
         END AS realized_pct
  FROM public.chain_rollout_sites_r2419 s
  GROUP BY s.chain_name
  ORDER BY arr_target_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.chain_realization_summary_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_realization_summary_r2419() TO authenticated;

-- RPC 5: blocker breakdown
CREATE OR REPLACE FUNCTION public.blocker_breakdown_r2419()
RETURNS TABLE (
  blocker_kind text,
  blocked_sites bigint,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.blocker_kind,
         COUNT(*)::bigint AS blocked_sites,
         COALESCE(SUM(s.arr_per_site_rupees), 0)::bigint AS arr_at_risk_rupees
  FROM public.chain_rollout_sites_r2419 s
  WHERE s.blocker_kind <> 'none'
    AND s.deployment_status IN ('planned','in_progress','delayed')
  GROUP BY s.blocker_kind
  ORDER BY arr_at_risk_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.blocker_breakdown_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocker_breakdown_r2419() TO authenticated;

-- RPC 6: upcoming go-lives (next 60 days)
CREATE OR REPLACE FUNCTION public.upcoming_go_lives_r2419()
RETURNS TABLE (
  id uuid,
  chain_name text,
  site_label text,
  site_city text,
  deployment_status text,
  planned_go_live_at timestamptz,
  days_to_go integer,
  arr_per_site_rupees bigint,
  blocker_kind text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.site_label, s.site_city, s.deployment_status,
         s.planned_go_live_at,
         GREATEST(0, EXTRACT(DAY FROM (s.planned_go_live_at - now()))::integer) AS days_to_go,
         s.arr_per_site_rupees, s.blocker_kind, s.owner_email
  FROM public.chain_rollout_sites_r2419 s
  WHERE s.planned_go_live_at IS NOT NULL
    AND s.planned_go_live_at >= now()
    AND s.planned_go_live_at <= now() + interval '60 days'
    AND s.deployment_status IN ('planned','in_progress','delayed')
  ORDER BY s.planned_go_live_at ASC
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_go_lives_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_go_lives_r2419() TO authenticated;

-- RPC 7: top chains by realization (latest snapshot per chain)
CREATE OR REPLACE FUNCTION public.top_chains_by_realization_r2419()
RETURNS TABLE (
  chain_name text,
  snapshot_date date,
  total_sites integer,
  deployed_sites integer,
  total_arr_target_rupees bigint,
  total_arr_realized_rupees bigint,
  realized_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (a.chain_name)
         a.chain_name, a.snapshot_date, a.total_sites, a.deployed_sites,
         a.total_arr_target_rupees, a.total_arr_realized_rupees, a.realized_pct
  FROM public.chain_rollout_arr_snapshots_r2419 a
  ORDER BY a.chain_name, a.snapshot_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_realization_r2419() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_chains_by_realization_r2419() TO authenticated;

