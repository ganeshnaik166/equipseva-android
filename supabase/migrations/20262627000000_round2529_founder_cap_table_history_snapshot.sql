-- Round 2529: founder-cap-table-history-snapshot
-- Tables: founder_cap_table_snapshots_r2529, cap_table_dilution_events_r2529
-- RPCs: list_snapshots_r2529, list_dilution_events_r2529, founder_ownership_trajectory_r2529,
--       snapshot_kind_summary_r2529, latest_locked_snapshot_r2529, monthly_event_trend_r2529,
--       esop_pool_evolution_r2529

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_cap_table_snapshots_r2529 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL,
  snapshot_kind text NOT NULL CHECK (snapshot_kind IN ('routine','round_close','esop_grant','secondary','exit')),
  founder_ownership_pct numeric(6,3) NOT NULL DEFAULT 0,
  esop_pool_pct numeric(6,3) NOT NULL DEFAULT 0,
  total_investors_count int NOT NULL DEFAULT 0,
  total_shares_outstanding bigint NOT NULL DEFAULT 0,
  valuation_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cap_table_dilution_events_r2529 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid NOT NULL REFERENCES public.founder_cap_table_snapshots_r2529(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('round','esop_grant','secondary','repurchase','option_exercise','fractional_split')),
  founder_delta_pct numeric(6,3) NOT NULL DEFAULT 0,
  esop_delta_pct numeric(6,3) NOT NULL DEFAULT 0,
  employee_impact_summary text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','executed','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_cap_table_snapshots_r2529 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cap_table_dilution_events_r2529 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_cap_table_snapshots_r2529;
CREATE POLICY founder_all ON public.founder_cap_table_snapshots_r2529
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.cap_table_dilution_events_r2529;
CREATE POLICY founder_all ON public.cap_table_dilution_events_r2529
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed snapshots
WITH s1 AS (
  INSERT INTO public.founder_cap_table_snapshots_r2529
    (snapshot_date, snapshot_kind, founder_ownership_pct, esop_pool_pct, total_investors_count,
     total_shares_outstanding, valuation_rupees, notes_md, owner_email, status, notes)
  VALUES
    ('2026-01-15','routine',68.500,10.000,3,1000000,250000000,'Q1 routine snapshot','founder@equipseva.in','final','baseline')
  RETURNING id
), s2 AS (
  INSERT INTO public.founder_cap_table_snapshots_r2529
    (snapshot_date, snapshot_kind, founder_ownership_pct, esop_pool_pct, total_investors_count,
     total_shares_outstanding, valuation_rupees, notes_md, owner_email, status, notes)
  VALUES
    ('2026-03-20','round_close',58.250,12.500,7,1200000,500000000,'Seed round close','founder@equipseva.in','final','seed-A')
  RETURNING id
), s3 AS (
  INSERT INTO public.founder_cap_table_snapshots_r2529
    (snapshot_date, snapshot_kind, founder_ownership_pct, esop_pool_pct, total_investors_count,
     total_shares_outstanding, valuation_rupees, notes_md, owner_email, status, notes)
  VALUES
    ('2026-05-10','esop_grant',57.000,15.000,7,1230000,520000000,'ESOP top-up','founder@equipseva.in','final','esop+2.5')
  RETURNING id
), s4 AS (
  INSERT INTO public.founder_cap_table_snapshots_r2529
    (snapshot_date, snapshot_kind, founder_ownership_pct, esop_pool_pct, total_investors_count,
     total_shares_outstanding, valuation_rupees, notes_md, owner_email, status, notes)
  VALUES
    ('2026-06-15','routine',56.800,15.000,7,1230000,540000000,'Q2 routine snapshot','founder@equipseva.in','draft','draft-Q2')
  RETURNING id
)
INSERT INTO public.cap_table_dilution_events_r2529
  (snapshot_id, event_at, event_kind, founder_delta_pct, esop_delta_pct, employee_impact_summary, owner_email, status, notes)
SELECT id, '2026-03-20T10:00:00Z'::timestamptz,'round',-10.250,2.500,'7 employees re-grant','founder@equipseva.in','executed','seed close' FROM s2
UNION ALL
SELECT id, '2026-05-10T10:00:00Z'::timestamptz,'esop_grant',-1.250,2.500,'12 grants','founder@equipseva.in','executed','esop top-up' FROM s3
UNION ALL
SELECT id, '2026-06-01T10:00:00Z'::timestamptz,'option_exercise',-0.200,0.000,'3 exercises','founder@equipseva.in','executed','vest exercise' FROM s4;

CREATE OR REPLACE FUNCTION public.list_snapshots_r2529()
RETURNS TABLE (id uuid, snapshot_date date, snapshot_kind text, founder_ownership_pct numeric,
               esop_pool_pct numeric, total_investors_count int, valuation_rupees bigint,
               status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.snapshot_date, s.snapshot_kind, s.founder_ownership_pct, s.esop_pool_pct,
           s.total_investors_count, s.valuation_rupees, s.status, s.owner_email
    FROM public.founder_cap_table_snapshots_r2529 s
    ORDER BY s.snapshot_date DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_snapshots_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_snapshots_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_dilution_events_r2529()
RETURNS TABLE (id uuid, snapshot_id uuid, event_at timestamptz, event_kind text,
               founder_delta_pct numeric, esop_delta_pct numeric, employee_impact_summary text,
               status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.snapshot_id, e.event_at, e.event_kind, e.founder_delta_pct, e.esop_delta_pct,
           e.employee_impact_summary, e.status, e.owner_email
    FROM public.cap_table_dilution_events_r2529 e
    ORDER BY e.event_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_dilution_events_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dilution_events_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_ownership_trajectory_r2529()
RETURNS TABLE (snapshot_date date, founder_ownership_pct numeric, valuation_rupees bigint, snapshot_kind text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.snapshot_date, s.founder_ownership_pct, s.valuation_rupees, s.snapshot_kind
    FROM public.founder_cap_table_snapshots_r2529 s
    ORDER BY s.snapshot_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.founder_ownership_trajectory_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ownership_trajectory_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.snapshot_kind_summary_r2529()
RETURNS TABLE (snapshot_kind text, snapshots_count bigint, avg_founder_pct numeric, avg_esop_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.snapshot_kind, count(*)::bigint, round(avg(s.founder_ownership_pct),3),
           round(avg(s.esop_pool_pct),3)
    FROM public.founder_cap_table_snapshots_r2529 s
    GROUP BY s.snapshot_kind
    ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.snapshot_kind_summary_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.snapshot_kind_summary_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.latest_locked_snapshot_r2529()
RETURNS TABLE (id uuid, snapshot_date date, snapshot_kind text, founder_ownership_pct numeric,
               esop_pool_pct numeric, total_investors_count int, valuation_rupees bigint, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.snapshot_date, s.snapshot_kind, s.founder_ownership_pct, s.esop_pool_pct,
           s.total_investors_count, s.valuation_rupees, s.status
    FROM public.founder_cap_table_snapshots_r2529 s
    WHERE s.status = 'final'
    ORDER BY s.snapshot_date DESC
    LIMIT 1;
END;$$;
REVOKE EXECUTE ON FUNCTION public.latest_locked_snapshot_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.latest_locked_snapshot_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_event_trend_r2529()
RETURNS TABLE (month_start date, events_count bigint, total_founder_delta numeric, total_esop_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', e.event_at)::date, count(*)::bigint,
           round(sum(e.founder_delta_pct),3), round(sum(e.esop_delta_pct),3)
    FROM public.cap_table_dilution_events_r2529 e
    GROUP BY date_trunc('month', e.event_at)
    ORDER BY date_trunc('month', e.event_at) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_event_trend_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_event_trend_r2529() TO authenticated;

CREATE OR REPLACE FUNCTION public.esop_pool_evolution_r2529()
RETURNS TABLE (snapshot_date date, esop_pool_pct numeric, snapshot_kind text, total_investors_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.snapshot_date, s.esop_pool_pct, s.snapshot_kind, s.total_investors_count
    FROM public.founder_cap_table_snapshots_r2529 s
    ORDER BY s.snapshot_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.esop_pool_evolution_r2529() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.esop_pool_evolution_r2529() TO authenticated;

