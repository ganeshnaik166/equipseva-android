-- r2459 hospital-chain-implementation-burndown
CREATE TABLE IF NOT EXISTS public.chain_implementation_milestones_r2459 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('kickoff','equipment_delivery','install','training','go_live','post_launch')),
  planned_at timestamptz NOT NULL,
  actual_at timestamptz,
  days_delta int,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','blocked','dropped')),
  at_risk boolean NOT NULL DEFAULT false,
  blocker_notes text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chain_implementation_burndown_snapshots_r2459 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  snapshot_date date NOT NULL,
  total_milestones int NOT NULL DEFAULT 0,
  completed_milestones int NOT NULL DEFAULT 0,
  completion_pct numeric(5,2) NOT NULL DEFAULT 0,
  at_risk_count int NOT NULL DEFAULT 0,
  days_to_go_live int,
  status text NOT NULL DEFAULT 'green' CHECK (status IN ('green','amber','red')),
  top_blocker text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_implementation_milestones_r2459 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_implementation_burndown_snapshots_r2459 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_implementation_milestones_r2459;
CREATE POLICY founder_all ON public.chain_implementation_milestones_r2459 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_implementation_burndown_snapshots_r2459;
CREATE POLICY founder_all ON public.chain_implementation_burndown_snapshots_r2459 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

INSERT INTO public.chain_implementation_milestones_r2459(chain_name, milestone_kind, planned_at, actual_at, days_delta, status, at_risk, blocker_notes, owner_email, notes)
VALUES
  ('Apollo South', 'kickoff', '2026-05-01 09:00'::timestamptz, '2026-05-02 09:00'::timestamptz, 1, 'done', false, null, 'pm1@equipseva.io', 'kickoff workshop done'),
  ('Apollo South', 'equipment_delivery', '2026-05-20 09:00'::timestamptz, '2026-05-25 09:00'::timestamptz, 5, 'done', true, 'logistics delay 5d', 'pm1@equipseva.io', 'truck breakdown'),
  ('Apollo South', 'install', '2026-06-05 09:00'::timestamptz, null, null, 'in_progress', true, 'pending civil work site B', 'pm1@equipseva.io', null),
  ('Yashoda North', 'kickoff', '2026-05-10 09:00'::timestamptz, '2026-05-10 09:00'::timestamptz, 0, 'done', false, null, 'pm2@equipseva.io', null),
  ('Yashoda North', 'training', '2026-06-15 09:00'::timestamptz, null, null, 'blocked', true, 'biomed team unavailable', 'pm2@equipseva.io', null),
  ('KIMS West', 'go_live', '2026-07-30 09:00'::timestamptz, null, null, 'open', false, null, 'pm3@equipseva.io', 'on track');

INSERT INTO public.chain_implementation_burndown_snapshots_r2459(chain_name, snapshot_date, total_milestones, completed_milestones, completion_pct, at_risk_count, days_to_go_live, status, top_blocker, notes)
VALUES
  ('Apollo South', '2026-06-15', 8, 3, 37.50, 2, 25, 'amber', 'install delays', 'civil work site B'),
  ('Apollo South', '2026-06-22', 8, 4, 50.00, 1, 18, 'amber', 'install delays', null),
  ('Yashoda North', '2026-06-22', 7, 2, 28.57, 2, 40, 'red', 'training blocker', 'biomed team unavailable'),
  ('KIMS West', '2026-06-22', 6, 4, 66.67, 0, 7, 'green', null, 'on track');

CREATE OR REPLACE FUNCTION public.list_milestones_r2459()
RETURNS TABLE(id uuid, chain_name text, milestone_kind text, planned_at timestamptz, actual_at timestamptz, days_delta int, status text, at_risk boolean, blocker_notes text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.chain_name, m.milestone_kind, m.planned_at, m.actual_at, m.days_delta, m.status, m.at_risk, m.blocker_notes, m.owner_email
  FROM public.chain_implementation_milestones_r2459 m
  ORDER BY m.planned_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_burndown_snapshots_r2459()
RETURNS TABLE(id uuid, chain_name text, snapshot_date date, total_milestones int, completed_milestones int, completion_pct numeric, at_risk_count int, days_to_go_live int, status text, top_blocker text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.snapshot_date, s.total_milestones, s.completed_milestones, s.completion_pct, s.at_risk_count, s.days_to_go_live, s.status, s.top_blocker
  FROM public.chain_implementation_burndown_snapshots_r2459 s
  ORDER BY s.snapshot_date DESC, s.chain_name ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_burndown_snapshots_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_burndown_snapshots_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.at_risk_focus_r2459()
RETURNS TABLE(chain_name text, milestone_kind text, planned_at timestamptz, status text, blocker_notes text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.chain_name, m.milestone_kind, m.planned_at, m.status, m.blocker_notes, m.owner_email
  FROM public.chain_implementation_milestones_r2459 m
  WHERE m.at_risk = true AND m.status NOT IN ('done','dropped')
  ORDER BY m.planned_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.at_risk_focus_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.at_risk_focus_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_chains_by_completion_r2459()
RETURNS TABLE(chain_name text, total_milestones bigint, done_count bigint, completion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.chain_name,
    COUNT(*)::bigint AS total_milestones,
    COUNT(*) FILTER (WHERE m.status = 'done')::bigint AS done_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE m.status = 'done') / NULLIF(COUNT(*),0), 2) AS completion_pct
  FROM public.chain_implementation_milestones_r2459 m
  GROUP BY m.chain_name
  ORDER BY completion_pct DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_completion_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_chains_by_completion_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.milestone_kind_summary_r2459()
RETURNS TABLE(milestone_kind text, total bigint, done bigint, blocked bigint, at_risk bigint, avg_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.milestone_kind,
    COUNT(*)::bigint AS total,
    COUNT(*) FILTER (WHERE m.status = 'done')::bigint AS done,
    COUNT(*) FILTER (WHERE m.status = 'blocked')::bigint AS blocked,
    COUNT(*) FILTER (WHERE m.at_risk = true)::bigint AS at_risk,
    ROUND(AVG(m.days_delta)::numeric, 2) AS avg_delta
  FROM public.chain_implementation_milestones_r2459 m
  GROUP BY m.milestone_kind
  ORDER BY total DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.milestone_kind_summary_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.milestone_kind_summary_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_burndown_trend_r2459()
RETURNS TABLE(week_bucket date, avg_completion_pct numeric, avg_at_risk numeric, snapshot_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', s.snapshot_date)::date AS week_bucket,
    ROUND(AVG(s.completion_pct)::numeric, 2) AS avg_completion_pct,
    ROUND(AVG(s.at_risk_count)::numeric, 2) AS avg_at_risk,
    COUNT(*)::bigint AS snapshot_count
  FROM public.chain_implementation_burndown_snapshots_r2459 s
  GROUP BY week_bucket
  ORDER BY week_bucket DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.weekly_burndown_trend_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_burndown_trend_r2459() TO authenticated;

CREATE OR REPLACE FUNCTION public.upcoming_milestones_r2459()
RETURNS TABLE(chain_name text, milestone_kind text, planned_at timestamptz, status text, owner_email text, days_out int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.chain_name, m.milestone_kind, m.planned_at, m.status, m.owner_email,
    EXTRACT(DAY FROM (m.planned_at - now()))::int AS days_out
  FROM public.chain_implementation_milestones_r2459 m
  WHERE m.planned_at >= now() AND m.status NOT IN ('done','dropped')
  ORDER BY m.planned_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.upcoming_milestones_r2459() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_milestones_r2459() TO authenticated;
