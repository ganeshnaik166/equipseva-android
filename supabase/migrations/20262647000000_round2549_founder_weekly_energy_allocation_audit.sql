-- Round r2549: founder-weekly-energy-allocation-audit
-- Tables: founder_weekly_energy_allocation_r2549, energy_allocation_corrections_r2549
-- RPCs: 7

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_energy_allocation_r2549 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  strategic_hours numeric NOT NULL DEFAULT 0,
  tactical_hours numeric NOT NULL DEFAULT 0,
  firefighting_hours numeric NOT NULL DEFAULT 0,
  learning_hours numeric NOT NULL DEFAULT 0,
  total_hours numeric NOT NULL DEFAULT 0,
  alignment_kind text NOT NULL CHECK (alignment_kind IN ('highly_aligned','aligned','misaligned','highly_misaligned')),
  leverage_score int NOT NULL CHECK (leverage_score BETWEEN 0 AND 100),
  top_drain_md text,
  top_high_leverage_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.energy_allocation_corrections_r2549 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  allocation_id uuid NOT NULL REFERENCES public.founder_weekly_energy_allocation_r2549(id) ON DELETE CASCADE,
  correction_kind text NOT NULL CHECK (correction_kind IN ('delegate','automate','eliminate','restructure_calendar')),
  action_md text,
  expected_impact_md text,
  status text NOT NULL CHECK (status IN ('planned','in_progress','done','dropped')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_energy_allocation_r2549 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.energy_allocation_corrections_r2549 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_weekly_energy_allocation_r2549;
CREATE POLICY founder_all ON public.founder_weekly_energy_allocation_r2549 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.energy_allocation_corrections_r2549;
CREATE POLICY founder_all ON public.energy_allocation_corrections_r2549 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed weekly allocations
INSERT INTO public.founder_weekly_energy_allocation_r2549
  (week_start, strategic_hours, tactical_hours, firefighting_hours, learning_hours, total_hours, alignment_kind, leverage_score, top_drain_md, top_high_leverage_md, owner_email, notes)
VALUES
  ('2026-05-25', 18, 22, 14, 6, 60, 'misaligned', 52, 'Firefighting Cashfree KYC escalations ate 14h', 'Drafted v0.6 roadmap (3h) yielded 10-phase plan', 'marketingtools@getphyllo.com', 'Too much reactive support'),
  ('2026-06-01', 24, 20, 8, 8, 60, 'aligned', 68, 'Manual GST invoice review (6h) — automate', 'Hospital chain pilot pitch deck (5h) — 3 LOIs', 'marketingtools@getphyllo.com', 'Strategic time recovered'),
  ('2026-06-08', 28, 18, 6, 10, 62, 'highly_aligned', 82, 'Engineer payout reconciliation (4h)', 'Board pack narrative arc + investor call prep', 'marketingtools@getphyllo.com', 'Best week — leverage trending up'),
  ('2026-06-15', 20, 24, 12, 4, 60, 'misaligned', 58, 'AMC churn investigation took 10h', 'Founder dashboard v2 spec (4h)', 'marketingtools@getphyllo.com', 'Churn fire pulled focus'),
  ('2026-06-22', 26, 20, 8, 8, 62, 'aligned', 74, 'Manual founder digest review (3h)', 'v0.5 launch readiness sweep + audit batch', 'marketingtools@getphyllo.com', 'Back on track')
ON CONFLICT DO NOTHING;

INSERT INTO public.energy_allocation_corrections_r2549
  (allocation_id, correction_kind, action_md, expected_impact_md, status, outcome, owner_email, notes)
SELECT a.id, 'delegate', 'Hand Cashfree KYC escalation flow to ops contractor', 'Recover 10h/week strategic time', 'in_progress', 'pending', 'marketingtools@getphyllo.com', 'Interviewing 3 candidates'
FROM public.founder_weekly_energy_allocation_r2549 a WHERE a.week_start = '2026-05-25' LIMIT 1;

INSERT INTO public.energy_allocation_corrections_r2549
  (allocation_id, correction_kind, action_md, expected_impact_md, status, outcome, owner_email, notes)
SELECT a.id, 'automate', 'Auto-generate GST invoice review batch via cron', 'Save 6h/week tactical', 'done', 'positive', 'marketingtools@getphyllo.com', 'Shipped r1349'
FROM public.founder_weekly_energy_allocation_r2549 a WHERE a.week_start = '2026-06-01' LIMIT 1;

INSERT INTO public.energy_allocation_corrections_r2549
  (allocation_id, correction_kind, action_md, expected_impact_md, status, outcome, owner_email, notes)
SELECT a.id, 'restructure_calendar', 'Block Tue/Thu mornings 8-12 for deep strategic work — no meetings', 'Protect 8h/week high-leverage time', 'done', 'positive', 'marketingtools@getphyllo.com', 'Calendar updated 06-09'
FROM public.founder_weekly_energy_allocation_r2549 a WHERE a.week_start = '2026-06-08' LIMIT 1;

INSERT INTO public.energy_allocation_corrections_r2549
  (allocation_id, correction_kind, action_md, expected_impact_md, status, outcome, owner_email, notes)
SELECT a.id, 'eliminate', 'Drop weekly all-hands sync — replace with async Loom', 'Save 2h/week + better focus', 'planned', 'pending', 'marketingtools@getphyllo.com', 'Team buy-in needed'
FROM public.founder_weekly_energy_allocation_r2549 a WHERE a.week_start = '2026-06-15' LIMIT 1;

INSERT INTO public.energy_allocation_corrections_r2549
  (allocation_id, correction_kind, action_md, expected_impact_md, status, outcome, owner_email, notes)
SELECT a.id, 'automate', 'Auto-summarize founder digest via LLM cron', 'Save 3h/week', 'in_progress', 'pending', 'marketingtools@getphyllo.com', 'Prototype building'
FROM public.founder_weekly_energy_allocation_r2549 a WHERE a.week_start = '2026-06-22' LIMIT 1;

-- RPC 1: list_allocation_r2549
CREATE OR REPLACE FUNCTION public.list_allocation_r2549()
RETURNS TABLE (
  id uuid,
  week_start date,
  strategic_hours numeric,
  tactical_hours numeric,
  firefighting_hours numeric,
  learning_hours numeric,
  total_hours numeric,
  alignment_kind text,
  leverage_score int,
  top_drain_md text,
  top_high_leverage_md text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.week_start, a.strategic_hours, a.tactical_hours, a.firefighting_hours,
         a.learning_hours, a.total_hours, a.alignment_kind, a.leverage_score,
         a.top_drain_md, a.top_high_leverage_md, a.owner_email, a.notes
  FROM public.founder_weekly_energy_allocation_r2549 a
  ORDER BY a.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_allocation_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_allocation_r2549() TO authenticated;

-- RPC 2: list_corrections_r2549
CREATE OR REPLACE FUNCTION public.list_corrections_r2549()
RETURNS TABLE (
  id uuid,
  allocation_id uuid,
  week_start date,
  correction_kind text,
  action_md text,
  expected_impact_md text,
  status text,
  outcome text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.allocation_id, a.week_start, c.correction_kind, c.action_md,
         c.expected_impact_md, c.status, c.outcome, c.owner_email, c.notes
  FROM public.energy_allocation_corrections_r2549 c
  JOIN public.founder_weekly_energy_allocation_r2549 a ON a.id = c.allocation_id
  ORDER BY a.week_start DESC, c.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_corrections_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_corrections_r2549() TO authenticated;

-- RPC 3: weekly_leverage_trend_r2549
CREATE OR REPLACE FUNCTION public.weekly_leverage_trend_r2549()
RETURNS TABLE (
  week_start date,
  leverage_score int,
  strategic_hours numeric,
  firefighting_hours numeric,
  alignment_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.week_start, a.leverage_score, a.strategic_hours, a.firefighting_hours, a.alignment_kind
  FROM public.founder_weekly_energy_allocation_r2549 a
  ORDER BY a.week_start ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_leverage_trend_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_leverage_trend_r2549() TO authenticated;

-- RPC 4: alignment_kind_distribution_r2549
CREATE OR REPLACE FUNCTION public.alignment_kind_distribution_r2549()
RETURNS TABLE (
  alignment_kind text,
  week_count bigint,
  avg_leverage numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.alignment_kind, COUNT(*)::bigint AS week_count,
         ROUND(AVG(a.leverage_score)::numeric, 1) AS avg_leverage
  FROM public.founder_weekly_energy_allocation_r2549 a
  GROUP BY a.alignment_kind
  ORDER BY week_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.alignment_kind_distribution_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.alignment_kind_distribution_r2549() TO authenticated;

-- RPC 5: top_drain_focus_r2549
CREATE OR REPLACE FUNCTION public.top_drain_focus_r2549()
RETURNS TABLE (
  week_start date,
  firefighting_hours numeric,
  top_drain_md text,
  leverage_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.week_start, a.firefighting_hours, a.top_drain_md, a.leverage_score
  FROM public.founder_weekly_energy_allocation_r2549 a
  WHERE a.top_drain_md IS NOT NULL
  ORDER BY a.firefighting_hours DESC, a.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_drain_focus_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drain_focus_r2549() TO authenticated;

-- RPC 6: correction_status_funnel_r2549
CREATE OR REPLACE FUNCTION public.correction_status_funnel_r2549()
RETURNS TABLE (
  status text,
  correction_count bigint,
  positive_outcomes bigint,
  pending_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
         COUNT(*)::bigint AS correction_count,
         COUNT(*) FILTER (WHERE c.outcome = 'positive')::bigint AS positive_outcomes,
         COUNT(*) FILTER (WHERE c.outcome = 'pending')::bigint AS pending_outcomes
  FROM public.energy_allocation_corrections_r2549 c
  GROUP BY c.status
  ORDER BY correction_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.correction_status_funnel_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correction_status_funnel_r2549() TO authenticated;

-- RPC 7: monthly_pulse_summary_r2549
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2549()
RETURNS TABLE (
  month_start date,
  weeks_logged bigint,
  avg_strategic_hours numeric,
  avg_firefighting_hours numeric,
  avg_leverage numeric,
  corrections_done bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.week_start)::date AS month_start,
         COUNT(*)::bigint AS weeks_logged,
         ROUND(AVG(a.strategic_hours)::numeric, 1) AS avg_strategic_hours,
         ROUND(AVG(a.firefighting_hours)::numeric, 1) AS avg_firefighting_hours,
         ROUND(AVG(a.leverage_score)::numeric, 1) AS avg_leverage,
         (SELECT COUNT(*) FROM public.energy_allocation_corrections_r2549 cc
          JOIN public.founder_weekly_energy_allocation_r2549 aa ON aa.id = cc.allocation_id
          WHERE date_trunc('month', aa.week_start) = date_trunc('month', a.week_start)
            AND cc.status = 'done')::bigint AS corrections_done
  FROM public.founder_weekly_energy_allocation_r2549 a
  GROUP BY date_trunc('month', a.week_start)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_summary_r2549() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_summary_r2549() TO authenticated;

