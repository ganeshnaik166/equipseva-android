-- Round 2425: founder-mental-bandwidth-tracker
-- Weekly self-check on bandwidth, distraction, energy, and delegated decisions.

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_bandwidth_r2425 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  hours_deep_work int NOT NULL DEFAULT 0 CHECK (hours_deep_work >= 0 AND hours_deep_work <= 80),
  hours_meetings int NOT NULL DEFAULT 0 CHECK (hours_meetings >= 0 AND hours_meetings <= 80),
  hours_email_slack int NOT NULL DEFAULT 0 CHECK (hours_email_slack >= 0 AND hours_email_slack <= 80),
  hours_firefighting int NOT NULL DEFAULT 0 CHECK (hours_firefighting >= 0 AND hours_firefighting <= 80),
  hours_strategic_thinking int NOT NULL DEFAULT 0 CHECK (hours_strategic_thinking >= 0 AND hours_strategic_thinking <= 80),
  distraction_score int NOT NULL CHECK (distraction_score BETWEEN 1 AND 10),
  energy_score int NOT NULL CHECK (energy_score BETWEEN 1 AND 10),
  sleep_hours_avg numeric(4,2) NOT NULL DEFAULT 7.0 CHECK (sleep_hours_avg >= 0 AND sleep_hours_avg <= 16),
  mood text NOT NULL CHECK (mood IN ('great','good','neutral','low','burned_out')),
  top_distraction text,
  what_drained text,
  what_energized text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_delegated_decisions_r2425 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  decision_summary text NOT NULL,
  delegated_to_email text NOT NULL,
  decision_outcome text NOT NULL CHECK (decision_outcome IN ('good','neutral','bad','reversed')),
  came_back_to_founder boolean NOT NULL DEFAULT false,
  time_saved_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (time_saved_hours >= 0),
  founder_regret_score int NOT NULL DEFAULT 0 CHECK (founder_regret_score BETWEEN 0 AND 5),
  learnings_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_bandwidth_r2425 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_delegated_decisions_r2425 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_weekly_bandwidth_r2425;
CREATE POLICY founder_all ON public.founder_weekly_bandwidth_r2425
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_delegated_decisions_r2425;
CREATE POLICY founder_all ON public.founder_delegated_decisions_r2425
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed 4 weeks of bandwidth rows
INSERT INTO public.founder_weekly_bandwidth_r2425
  (week_start, hours_deep_work, hours_meetings, hours_email_slack, hours_firefighting, hours_strategic_thinking, distraction_score, energy_score, sleep_hours_avg, mood, top_distraction, what_drained, what_energized, notes)
VALUES
  ('2026-05-25', 22, 14, 9, 6, 4, 7, 5, 6.4, 'low', 'Slack DMs from ops', 'Cashfree KYC chase', 'Founder dinner with mentor', 'Heavy firefighting week'),
  ('2026-06-01', 28, 12, 8, 4, 6, 6, 6, 6.8, 'neutral', 'Investor cold emails', 'Compliance paperwork', 'Shipped 4 design batches', 'Better rhythm'),
  ('2026-06-08', 34, 10, 7, 3, 8, 5, 7, 7.1, 'good', 'Twitter rabbit hole', 'Hospital chain RFP edits', 'r1300 milestone hit', 'Deep work block held'),
  ('2026-06-15', 38, 9, 6, 2, 10, 3, 8, 7.5, 'great', 'None', 'Minor partner pings', 'Ultracode chain shipping 500+ rounds', 'Best bandwidth week so far');

INSERT INTO public.founder_delegated_decisions_r2425
  (week_start, decision_summary, delegated_to_email, decision_outcome, came_back_to_founder, time_saved_hours, founder_regret_score, learnings_md, notes)
VALUES
  ('2026-05-25', 'Approve refund for hospital BH-021', 'ops@equipseva.in', 'good', false, 2.5, 0, 'Ops can own < INR 25k refunds without escalation', 'Clean handoff'),
  ('2026-06-01', 'Pick logo vendor from 3 finalists', 'design@equipseva.in', 'neutral', true, 1.0, 2, 'Brand decisions need founder eye; do not redelegate', 'Came back for tiebreaker'),
  ('2026-06-08', 'Negotiate AMC tier discount with chain X', 'sales@equipseva.in', 'bad', true, 0.5, 4, 'Pricing authority not yet transferable; lost 8 percent margin', 'Reversed terms next week'),
  ('2026-06-15', 'Hire 2 field engineers in Hyderabad', 'hr@equipseva.in', 'good', false, 6.0, 0, 'Hiring rubric works; HR can run end-to-end', 'Both joined on time'),
  ('2026-06-15', 'Reply to investor Q from VC fund A', 'cofounder@equipseva.in', 'reversed', true, 0.0, 5, 'Investor comms must stay founder-led until Series A', 'Had to send corrective email');

CREATE OR REPLACE FUNCTION public.list_weekly_bandwidth_r2425()
RETURNS TABLE (
  id uuid,
  week_start date,
  hours_deep_work int,
  hours_meetings int,
  hours_email_slack int,
  hours_firefighting int,
  hours_strategic_thinking int,
  total_hours int,
  distraction_score int,
  energy_score int,
  sleep_hours_avg numeric,
  mood text,
  top_distraction text,
  what_drained text,
  what_energized text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.week_start, b.hours_deep_work, b.hours_meetings, b.hours_email_slack,
         b.hours_firefighting, b.hours_strategic_thinking,
         (b.hours_deep_work + b.hours_meetings + b.hours_email_slack + b.hours_firefighting + b.hours_strategic_thinking) AS total_hours,
         b.distraction_score, b.energy_score, b.sleep_hours_avg, b.mood,
         b.top_distraction, b.what_drained, b.what_energized, b.notes, b.created_at
  FROM public.founder_weekly_bandwidth_r2425 b
  ORDER BY b.week_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_weekly_bandwidth_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_weekly_bandwidth_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_delegated_decisions_r2425()
RETURNS TABLE (
  id uuid,
  week_start date,
  decision_summary text,
  delegated_to_email text,
  decision_outcome text,
  came_back_to_founder boolean,
  time_saved_hours numeric,
  founder_regret_score int,
  learnings_md text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.week_start, d.decision_summary, d.delegated_to_email, d.decision_outcome,
         d.came_back_to_founder, d.time_saved_hours, d.founder_regret_score,
         d.learnings_md, d.notes, d.created_at
  FROM public.founder_delegated_decisions_r2425 d
  ORDER BY d.week_start DESC, d.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_delegated_decisions_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_delegated_decisions_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.distraction_trend_r2425()
RETURNS TABLE (
  week_start date,
  distraction_score int,
  energy_score int,
  delta_distraction int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.week_start, b.distraction_score, b.energy_score,
         (b.distraction_score - LAG(b.distraction_score) OVER (ORDER BY b.week_start))::int AS delta_distraction
  FROM public.founder_weekly_bandwidth_r2425 b
  ORDER BY b.week_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.distraction_trend_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.distraction_trend_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.energy_vs_deep_work_r2425()
RETURNS TABLE (
  week_start date,
  energy_score int,
  hours_deep_work int,
  hours_firefighting int,
  ratio_deep_to_fire numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.week_start, b.energy_score, b.hours_deep_work, b.hours_firefighting,
         CASE WHEN b.hours_firefighting = 0 THEN b.hours_deep_work::numeric
              ELSE round(b.hours_deep_work::numeric / b.hours_firefighting::numeric, 2)
         END AS ratio_deep_to_fire
  FROM public.founder_weekly_bandwidth_r2425 b
  ORDER BY b.week_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.energy_vs_deep_work_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.energy_vs_deep_work_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.delegation_outcome_breakdown_r2425()
RETURNS TABLE (
  decision_outcome text,
  decisions int,
  total_time_saved numeric,
  avg_regret numeric,
  reversed_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_outcome,
         COUNT(*)::int AS decisions,
         COALESCE(SUM(d.time_saved_hours), 0)::numeric AS total_time_saved,
         COALESCE(round(AVG(d.founder_regret_score)::numeric, 2), 0)::numeric AS avg_regret,
         COALESCE(round((SUM(CASE WHEN d.came_back_to_founder THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0)::numeric) * 100, 1), 0)::numeric AS reversed_share
  FROM public.founder_delegated_decisions_r2425 d
  GROUP BY d.decision_outcome
  ORDER BY decisions DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.delegation_outcome_breakdown_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delegation_outcome_breakdown_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_drains_r2425()
RETURNS TABLE (
  drain text,
  occurrences int,
  avg_distraction numeric,
  avg_energy numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(b.what_drained, '(unspecified)')::text AS drain,
         COUNT(*)::int AS occurrences,
         COALESCE(round(AVG(b.distraction_score)::numeric, 2), 0)::numeric AS avg_distraction,
         COALESCE(round(AVG(b.energy_score)::numeric, 2), 0)::numeric AS avg_energy
  FROM public.founder_weekly_bandwidth_r2425 b
  GROUP BY COALESCE(b.what_drained, '(unspecified)')
  ORDER BY occurrences DESC, avg_distraction DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_drains_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drains_r2425() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_pulse_summary_r2425()
RETURNS TABLE (
  weeks_logged int,
  avg_deep_work numeric,
  avg_firefighting numeric,
  avg_distraction numeric,
  avg_energy numeric,
  avg_sleep numeric,
  delegated_count int,
  delegated_time_saved numeric,
  delegated_reversed int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT COUNT(*)::int FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COALESCE(round(AVG(hours_deep_work)::numeric, 2), 0) FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COALESCE(round(AVG(hours_firefighting)::numeric, 2), 0) FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COALESCE(round(AVG(distraction_score)::numeric, 2), 0) FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COALESCE(round(AVG(energy_score)::numeric, 2), 0) FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COALESCE(round(AVG(sleep_hours_avg)::numeric, 2), 0) FROM public.founder_weekly_bandwidth_r2425),
         (SELECT COUNT(*)::int FROM public.founder_delegated_decisions_r2425),
         (SELECT COALESCE(SUM(time_saved_hours), 0)::numeric FROM public.founder_delegated_decisions_r2425),
         (SELECT COUNT(*)::int FROM public.founder_delegated_decisions_r2425 WHERE decision_outcome = 'reversed');
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_pulse_summary_r2425() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_pulse_summary_r2425() TO authenticated;

