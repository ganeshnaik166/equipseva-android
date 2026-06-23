-- Round 2535: Hospital Chain CFO Budget Cycle Alignment
-- Track CFO budget calendars across hospital chains, plan pitch timing, log outcomes

CREATE TABLE IF NOT EXISTS public.chain_cfo_budget_cycles_r2535 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cfo_name text NOT NULL,
  cfo_email text NOT NULL,
  budget_cycle_kind text NOT NULL CHECK (budget_cycle_kind IN ('annual','semi_annual','quarterly')),
  cycle_start_month int NOT NULL CHECK (cycle_start_month BETWEEN 1 AND 12),
  planning_window_weeks int NOT NULL DEFAULT 8 CHECK (planning_window_weeks > 0),
  our_pitch_timing_optimal_at timestamptz,
  last_pitch_at timestamptz,
  last_pitch_outcome text CHECK (last_pitch_outcome IN ('won','lost','postponed','in_review')),
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cfo_pitch_pipeline_r2535 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.chain_cfo_budget_cycles_r2535(id) ON DELETE CASCADE,
  scheduled_pitch_at timestamptz NOT NULL,
  agenda_md text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled','rescheduled')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_cfo_budget_cycles_r2535 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cfo_pitch_pipeline_r2535 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_cfo_budget_cycles_r2535;
CREATE POLICY founder_all ON public.chain_cfo_budget_cycles_r2535
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.cfo_pitch_pipeline_r2535;
CREATE POLICY founder_all ON public.cfo_pitch_pipeline_r2535
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed cycles
INSERT INTO public.chain_cfo_budget_cycles_r2535
  (chain_name, cfo_name, cfo_email, budget_cycle_kind, cycle_start_month, planning_window_weeks, our_pitch_timing_optimal_at, last_pitch_at, last_pitch_outcome, owner_email, notes)
VALUES
  ('Apollo Network', 'Krishnan Iyer', 'cfo@apollo-net.example', 'annual', 4, 10, '2026-01-15T10:00:00+05:30'::timestamptz, '2026-01-20T11:00:00+05:30'::timestamptz, 'won', 'founder@equipseva.com', 'FY starts April; pitch in Jan-Feb optimal'),
  ('Manipal Chain', 'Rohini Shetty', 'cfo@manipal.example', 'semi_annual', 4, 6, '2026-02-10T09:30:00+05:30'::timestamptz, '2026-02-12T09:30:00+05:30'::timestamptz, 'in_review', 'founder@equipseva.com', 'Two windows: Apr + Oct'),
  ('Fortis Healthcare', 'Anand Bose', 'cfo@fortis.example', 'quarterly', 1, 4, '2026-03-05T14:00:00+05:30'::timestamptz, '2026-03-08T14:00:00+05:30'::timestamptz, 'postponed', 'founder@equipseva.com', 'Quarterly reviews; agile but harder to land big AMC'),
  ('Yashoda Hospitals', 'Padmaja Reddy', 'cfo@yashoda.example', 'annual', 4, 8, '2026-01-25T11:00:00+05:30'::timestamptz, '2026-01-28T11:00:00+05:30'::timestamptz, 'lost', 'founder@equipseva.com', 'Lost to incumbent; reattempt FY27');

-- Seed pipeline
WITH c AS (
  SELECT id, chain_name FROM public.chain_cfo_budget_cycles_r2535
)
INSERT INTO public.cfo_pitch_pipeline_r2535 (cycle_id, scheduled_pitch_at, agenda_md, owner_email, status, outcome, notes)
SELECT id, '2026-07-15T10:00:00+05:30'::timestamptz, '# Apollo Q2 AMC pitch\n- chain bulk discount\n- SLA dashboard', 'founder@equipseva.com', 'planned', 'pending', 'Pre-budget window' FROM c WHERE chain_name = 'Apollo Network'
UNION ALL
SELECT id, '2026-08-05T09:30:00+05:30'::timestamptz, '# Manipal H2 review\n- renewal terms\n- onboarding new sites', 'founder@equipseva.com', 'planned', 'pending', 'Aligned with Oct cycle' FROM c WHERE chain_name = 'Manipal Chain'
UNION ALL
SELECT id, '2026-06-28T14:00:00+05:30'::timestamptz, '# Fortis Q3\n- pilot expansion to 5 more sites', 'founder@equipseva.com', 'done', 'positive', 'Verbal LOI received' FROM c WHERE chain_name = 'Fortis Healthcare'
UNION ALL
SELECT id, '2026-09-10T11:00:00+05:30'::timestamptz, '# Yashoda reattempt\n- price match + analytics add-on', 'founder@equipseva.com', 'rescheduled', 'pending', 'CFO travel; pushed by 2 weeks' FROM c WHERE chain_name = 'Yashoda Hospitals';

-- RPC 1: list cycles
CREATE OR REPLACE FUNCTION public.list_budget_cycles_r2535()
RETURNS TABLE (
  id uuid, chain_name text, cfo_name text, cfo_email text,
  budget_cycle_kind text, cycle_start_month int, planning_window_weeks int,
  our_pitch_timing_optimal_at timestamptz, last_pitch_at timestamptz,
  last_pitch_outcome text, owner_email text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.cfo_name, c.cfo_email, c.budget_cycle_kind,
         c.cycle_start_month, c.planning_window_weeks, c.our_pitch_timing_optimal_at,
         c.last_pitch_at, c.last_pitch_outcome, c.owner_email, c.notes, c.created_at
  FROM public.chain_cfo_budget_cycles_r2535 c
  ORDER BY c.our_pitch_timing_optimal_at NULLS LAST, c.chain_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_budget_cycles_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_budget_cycles_r2535() TO authenticated;

-- RPC 2: list pipeline
CREATE OR REPLACE FUNCTION public.list_pitch_pipeline_r2535()
RETURNS TABLE (
  id uuid, cycle_id uuid, chain_name text, cfo_name text,
  scheduled_pitch_at timestamptz, agenda_md text, owner_email text,
  status text, outcome text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.cycle_id, c.chain_name, c.cfo_name,
         p.scheduled_pitch_at, p.agenda_md, p.owner_email,
         p.status, p.outcome, p.notes, p.created_at
  FROM public.cfo_pitch_pipeline_r2535 p
  JOIN public.chain_cfo_budget_cycles_r2535 c ON c.id = p.cycle_id
  ORDER BY p.scheduled_pitch_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pitch_pipeline_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pitch_pipeline_r2535() TO authenticated;

-- RPC 3: upcoming optimal windows (next 90 days)
CREATE OR REPLACE FUNCTION public.upcoming_optimal_windows_r2535()
RETURNS TABLE (
  id uuid, chain_name text, cfo_name text,
  our_pitch_timing_optimal_at timestamptz, days_until int,
  budget_cycle_kind text, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.cfo_name,
         c.our_pitch_timing_optimal_at,
         GREATEST(0, EXTRACT(DAY FROM (c.our_pitch_timing_optimal_at - now()))::int) AS days_until,
         c.budget_cycle_kind, c.owner_email
  FROM public.chain_cfo_budget_cycles_r2535 c
  WHERE c.our_pitch_timing_optimal_at IS NOT NULL
    AND c.our_pitch_timing_optimal_at >= (now() - interval '30 days')
    AND c.our_pitch_timing_optimal_at <= (now() + interval '90 days')
  ORDER BY c.our_pitch_timing_optimal_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_optimal_windows_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_optimal_windows_r2535() TO authenticated;

-- RPC 4: win rate summary
CREATE OR REPLACE FUNCTION public.win_rate_summary_r2535()
RETURNS TABLE (
  total_cycles bigint, won_count bigint, lost_count bigint,
  postponed_count bigint, in_review_count bigint, win_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_cycles,
    COUNT(*) FILTER (WHERE last_pitch_outcome = 'won')::bigint AS won_count,
    COUNT(*) FILTER (WHERE last_pitch_outcome = 'lost')::bigint AS lost_count,
    COUNT(*) FILTER (WHERE last_pitch_outcome = 'postponed')::bigint AS postponed_count,
    COUNT(*) FILTER (WHERE last_pitch_outcome = 'in_review')::bigint AS in_review_count,
    CASE WHEN COUNT(*) FILTER (WHERE last_pitch_outcome IN ('won','lost')) > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE last_pitch_outcome = 'won')
              / NULLIF(COUNT(*) FILTER (WHERE last_pitch_outcome IN ('won','lost')), 0), 2)
         ELSE 0 END AS win_rate_pct
  FROM public.chain_cfo_budget_cycles_r2535;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.win_rate_summary_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_rate_summary_r2535() TO authenticated;

-- RPC 5: budget cycle kind breakdown
CREATE OR REPLACE FUNCTION public.budget_cycle_kind_breakdown_r2535()
RETURNS TABLE (budget_cycle_kind text, chain_count bigint, avg_planning_weeks numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.budget_cycle_kind,
         COUNT(*)::bigint AS chain_count,
         ROUND(AVG(c.planning_window_weeks)::numeric, 2) AS avg_planning_weeks
  FROM public.chain_cfo_budget_cycles_r2535 c
  GROUP BY c.budget_cycle_kind
  ORDER BY chain_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.budget_cycle_kind_breakdown_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_cycle_kind_breakdown_r2535() TO authenticated;

-- RPC 6: top priority pitches (optimal window soonest + not yet won)
CREATE OR REPLACE FUNCTION public.top_priority_pitches_r2535()
RETURNS TABLE (
  id uuid, chain_name text, cfo_name text,
  our_pitch_timing_optimal_at timestamptz, last_pitch_outcome text,
  days_until int, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.cfo_name,
         c.our_pitch_timing_optimal_at,
         COALESCE(c.last_pitch_outcome, 'in_review'),
         GREATEST(0, EXTRACT(DAY FROM (c.our_pitch_timing_optimal_at - now()))::int) AS days_until,
         c.owner_email
  FROM public.chain_cfo_budget_cycles_r2535 c
  WHERE COALESCE(c.last_pitch_outcome, 'in_review') <> 'won'
    AND c.our_pitch_timing_optimal_at IS NOT NULL
  ORDER BY c.our_pitch_timing_optimal_at
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_priority_pitches_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_priority_pitches_r2535() TO authenticated;

-- RPC 7: monthly pitch trend (last 12 months scheduled pitches)
CREATE OR REPLACE FUNCTION public.monthly_pitch_trend_r2535()
RETURNS TABLE (month_start date, scheduled_count bigint, done_count bigint, positive_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', p.scheduled_pitch_at)::date AS month_start,
         COUNT(*)::bigint AS scheduled_count,
         COUNT(*) FILTER (WHERE p.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE p.outcome = 'positive')::bigint AS positive_count
  FROM public.cfo_pitch_pipeline_r2535 p
  WHERE p.scheduled_pitch_at >= (now() - interval '12 months')
  GROUP BY date_trunc('month', p.scheduled_pitch_at)
  ORDER BY month_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pitch_trend_r2535() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pitch_trend_r2535() TO authenticated;
