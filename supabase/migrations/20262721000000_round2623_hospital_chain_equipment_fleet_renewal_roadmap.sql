-- Round 2623: Hospital Chain Equipment Fleet Renewal Roadmap
-- Tracks multi-year fleet refresh roadmaps for hospital chains plus milestone events.

CREATE TABLE IF NOT EXISTS public.chain_fleet_renewal_roadmap_r2623 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_kind text NOT NULL,
  current_count int NOT NULL DEFAULT 0,
  refresh_in_12mo_count int NOT NULL DEFAULT 0,
  refresh_in_24mo_count int NOT NULL DEFAULT 0,
  refresh_in_36mo_count int NOT NULL DEFAULT 0,
  total_value_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','active','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fleet_renewal_milestones_r2623 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id uuid NOT NULL REFERENCES public.chain_fleet_renewal_roadmap_r2623(id) ON DELETE CASCADE,
  milestone_at timestamptz NOT NULL DEFAULT now(),
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('quote','approval','po','delivery','install')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_fleet_renewal_roadmap_r2623_status ON public.chain_fleet_renewal_roadmap_r2623(status);
CREATE INDEX IF NOT EXISTS idx_chain_fleet_renewal_roadmap_r2623_kind ON public.chain_fleet_renewal_roadmap_r2623(equipment_kind);
CREATE INDEX IF NOT EXISTS idx_fleet_renewal_milestones_r2623_roadmap ON public.fleet_renewal_milestones_r2623(roadmap_id);
CREATE INDEX IF NOT EXISTS idx_fleet_renewal_milestones_r2623_at ON public.fleet_renewal_milestones_r2623(milestone_at);

ALTER TABLE public.chain_fleet_renewal_roadmap_r2623 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fleet_renewal_milestones_r2623 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_fleet_renewal_roadmap_r2623;
CREATE POLICY founder_all ON public.chain_fleet_renewal_roadmap_r2623
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.fleet_renewal_milestones_r2623;
CREATE POLICY founder_all ON public.fleet_renewal_milestones_r2623
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.chain_fleet_renewal_roadmap_r2623 (chain_name, equipment_kind, current_count, refresh_in_12mo_count, refresh_in_24mo_count, refresh_in_36mo_count, total_value_rupees, owner_email, status, notes) VALUES
  ('Apollo Hospitals', 'CT Scanner', 12, 3, 4, 5, 18000000000, 'fleet@apollo.example', 'in_progress', 'Multi-city refresh wave planned'),
  ('Manipal Health', 'MRI', 8, 2, 3, 3, 14000000000, 'cap@manipal.example', 'planned', 'Awaiting board sign-off Q3'),
  ('Fortis Healthcare', 'Ultrasound', 40, 12, 14, 14, 4000000000, 'biomed@fortis.example', 'active', 'Hub-and-spoke rollout active'),
  ('Narayana Health', 'Ventilator', 60, 20, 20, 20, 1200000000, 'ops@narayana.example', 'in_progress', 'Pediatric units prioritized'),
  ('Max Healthcare', 'C-Arm', 18, 5, 6, 7, 2700000000, 'capex@max.example', 'closed', 'Cycle complete; next refresh 2030');

INSERT INTO public.fleet_renewal_milestones_r2623 (roadmap_id, milestone_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '14 days')::timestamptz, 'quote', 'positive', 'quote@equipseva.example', 'done', 'Initial quote accepted'
FROM public.chain_fleet_renewal_roadmap_r2623 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.fleet_renewal_milestones_r2623 (roadmap_id, milestone_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '7 days')::timestamptz, 'approval', 'pending', 'capex@manipal.example', 'open', 'Board review next week'
FROM public.chain_fleet_renewal_roadmap_r2623 WHERE chain_name = 'Manipal Health' LIMIT 1;

INSERT INTO public.fleet_renewal_milestones_r2623 (roadmap_id, milestone_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '21 days')::timestamptz, 'po', 'positive', 'ops@fortis.example', 'done', 'PO issued for first batch'
FROM public.chain_fleet_renewal_roadmap_r2623 WHERE chain_name = 'Fortis Healthcare' LIMIT 1;

INSERT INTO public.fleet_renewal_milestones_r2623 (roadmap_id, milestone_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '3 days')::timestamptz, 'delivery', 'neutral', 'ops@narayana.example', 'open', 'Logistics in transit'
FROM public.chain_fleet_renewal_roadmap_r2623 WHERE chain_name = 'Narayana Health' LIMIT 1;

INSERT INTO public.fleet_renewal_milestones_r2623 (roadmap_id, milestone_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '40 days')::timestamptz, 'install', 'positive', 'biomed@max.example', 'done', 'Final installs validated'
FROM public.chain_fleet_renewal_roadmap_r2623 WHERE chain_name = 'Max Healthcare' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_roadmaps_r2623()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_kind text,
  current_count int,
  refresh_in_12mo_count int,
  refresh_in_24mo_count int,
  refresh_in_36mo_count int,
  total_value_rupees bigint,
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
  SELECT r.id, r.chain_name, r.equipment_kind, r.current_count,
         r.refresh_in_12mo_count, r.refresh_in_24mo_count, r.refresh_in_36mo_count,
         r.total_value_rupees, r.owner_email, r.status, r.notes, r.created_at
  FROM public.chain_fleet_renewal_roadmap_r2623 r
  ORDER BY r.total_value_rupees DESC, r.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_roadmaps_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_roadmaps_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_milestones_r2623()
RETURNS TABLE (
  id uuid,
  roadmap_id uuid,
  chain_name text,
  milestone_at timestamptz,
  milestone_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.roadmap_id, r.chain_name, m.milestone_at,
         m.milestone_kind, m.outcome, m.owner_email, m.status, m.notes
  FROM public.fleet_renewal_milestones_r2623 m
  LEFT JOIN public.chain_fleet_renewal_roadmap_r2623 r ON r.id = m.roadmap_id
  ORDER BY m.milestone_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_total_value_focus_r2623()
RETURNS TABLE (
  chain_name text,
  equipment_kind text,
  total_value_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.equipment_kind, r.total_value_rupees, r.status
  FROM public.chain_fleet_renewal_roadmap_r2623 r
  ORDER BY r.total_value_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_total_value_focus_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_total_value_focus_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.equipment_kind_distribution_r2623()
RETURNS TABLE (
  equipment_kind text,
  roadmap_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_kind, COUNT(*)::bigint AS roadmap_count, COALESCE(SUM(r.total_value_rupees),0)::bigint
  FROM public.chain_fleet_renewal_roadmap_r2623 r
  GROUP BY r.equipment_kind
  ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_distribution_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_distribution_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2623()
RETURNS TABLE (
  status text,
  roadmap_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, COUNT(*)::bigint, COALESCE(SUM(r.total_value_rupees),0)::bigint
  FROM public.chain_fleet_renewal_roadmap_r2623 r
  GROUP BY r.status
  ORDER BY r.status;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_milestone_trend_r2623()
RETURNS TABLE (
  month_start timestamptz,
  milestone_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', m.milestone_at)::timestamptz AS month_start,
         COUNT(*)::bigint AS milestone_count,
         COUNT(*) FILTER (WHERE m.outcome = 'positive')::bigint AS positive_count
  FROM public.fleet_renewal_milestones_r2623 m
  WHERE m.milestone_at >= (now() - interval '12 months')
  GROUP BY date_trunc('month', m.milestone_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_milestone_trend_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_milestone_trend_r2623() TO authenticated;

CREATE OR REPLACE FUNCTION public.refresh_in_12mo_summary_r2623()
RETURNS TABLE (
  total_units_12mo bigint,
  total_units_24mo bigint,
  total_units_36mo bigint,
  total_value_rupees bigint,
  chain_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(SUM(r.refresh_in_12mo_count),0)::bigint,
         COALESCE(SUM(r.refresh_in_24mo_count),0)::bigint,
         COALESCE(SUM(r.refresh_in_36mo_count),0)::bigint,
         COALESCE(SUM(r.total_value_rupees),0)::bigint,
         COUNT(DISTINCT r.chain_name)::bigint
  FROM public.chain_fleet_renewal_roadmap_r2623 r;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refresh_in_12mo_summary_r2623() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_in_12mo_summary_r2623() TO authenticated;
