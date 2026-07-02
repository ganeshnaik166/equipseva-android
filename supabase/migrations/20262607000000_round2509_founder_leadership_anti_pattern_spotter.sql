-- Round 2509: founder-leadership-anti-pattern-spotter
-- Anti-pattern x frequency x cost x correction x root cause x kill plan

CREATE TABLE IF NOT EXISTS public.founder_anti_patterns_r2509 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_kind text NOT NULL CHECK (pattern_kind IN ('micromanage','avoid_conflict','decide_too_late','decide_too_fast','skip_culture','over_invest_in_low_roi','people_pleasing','firefighter_mode','strategic_drift','no_followups')),
  frequency_score int NOT NULL CHECK (frequency_score >= 0 AND frequency_score <= 100),
  cost_impact_rupees bigint NOT NULL DEFAULT 0,
  observed_at timestamptz NOT NULL DEFAULT now(),
  observation_md text,
  correction_md text,
  root_cause_md text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','killed','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.anti_pattern_kill_actions_r2509 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_id uuid NOT NULL REFERENCES public.founder_anti_patterns_r2509(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('commitment_device','peer_review','sop_change','coaching','calendar_block')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_anti_patterns_r2509 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anti_pattern_kill_actions_r2509 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_anti_patterns_r2509;
CREATE POLICY founder_all ON public.founder_anti_patterns_r2509
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.anti_pattern_kill_actions_r2509;
CREATE POLICY founder_all ON public.anti_pattern_kill_actions_r2509
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.founder_anti_patterns_r2509 (id, pattern_kind, frequency_score, cost_impact_rupees, observed_at, observation_md, correction_md, root_cause_md, status, owner_email, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101', 'micromanage', 78, 450000, now() - interval '14 days', 'Reviewed every line of engineer payout code', 'Delegate to senior engineer + spot-check', 'Lack of trust calibration after r1083 incident', 'in_progress', 'founder@equipseva.in', 'Tracked via calendar audit'),
  ('11111111-1111-1111-1111-111111111102', 'decide_too_late', 65, 1200000, now() - interval '21 days', 'Sat on Cashfree KYC docs for 3 weeks', 'Same-day decision rule for ops blockers', 'Perfection bias on partner choice', 'killed', 'founder@equipseva.in', 'Cashfree activated now'),
  ('11111111-1111-1111-1111-111111111103', 'firefighter_mode', 88, 780000, now() - interval '7 days', 'Spent entire week on hospital escalation', 'Build L1 escalation team + SOP', 'No deputy ownership', 'open', 'founder@equipseva.in', 'Recurring P0 firefighting'),
  ('11111111-1111-1111-1111-111111111104', 'no_followups', 55, 230000, now() - interval '30 days', 'Action items from board call slipped 4x', 'Automated follow-up cron + Slack reminders', 'No accountability infra', 'in_progress', 'founder@equipseva.in', 'Wired to r1306 priority actions'),
  ('11111111-1111-1111-1111-111111111105', 'strategic_drift', 42, 1800000, now() - interval '45 days', 'Pivoted 3 times in 6 weeks on AMC tiering', 'Quarterly strategy lock + change gate', 'Investor noise overload', 'open', 'founder@equipseva.in', 'High cost item')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.anti_pattern_kill_actions_r2509 (pattern_id, action_at, action_kind, outcome, follow_up_at, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101', now() - interval '10 days', 'calendar_block', 'positive', now() + interval '7 days', 'Blocked Mon mornings for delegation'),
  ('11111111-1111-1111-1111-111111111102', now() - interval '14 days', 'commitment_device', 'positive', now() + interval '14 days', 'Public commitment to ship by EOD'),
  ('11111111-1111-1111-1111-111111111103', now() - interval '5 days', 'sop_change', 'pending', now() + interval '3 days', 'L1 SOP drafted, awaiting review'),
  ('11111111-1111-1111-1111-111111111104', now() - interval '20 days', 'peer_review', 'neutral', now() + interval '14 days', 'Bi-weekly peer review with co-founder'),
  ('11111111-1111-1111-1111-111111111105', now() - interval '40 days', 'coaching', 'negative', now() + interval '7 days', 'Coach session did not help, need new approach');

-- RPC 1: list_anti_patterns_r2509
CREATE OR REPLACE FUNCTION public.list_anti_patterns_r2509()
RETURNS TABLE (
  id uuid,
  pattern_kind text,
  frequency_score int,
  cost_impact_rupees bigint,
  observed_at timestamptz,
  status text,
  owner_email text,
  observation_md text,
  correction_md text,
  root_cause_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pattern_kind, a.frequency_score, a.cost_impact_rupees, a.observed_at,
         a.status, a.owner_email, a.observation_md, a.correction_md, a.root_cause_md, a.notes
  FROM public.founder_anti_patterns_r2509 a
  ORDER BY a.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_anti_patterns_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_anti_patterns_r2509() TO authenticated;

-- RPC 2: list_kill_actions_r2509
CREATE OR REPLACE FUNCTION public.list_kill_actions_r2509()
RETURNS TABLE (
  id uuid,
  pattern_id uuid,
  pattern_kind text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  follow_up_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.pattern_id, a.pattern_kind, k.action_at, k.action_kind, k.outcome, k.follow_up_at, k.notes
  FROM public.anti_pattern_kill_actions_r2509 k
  JOIN public.founder_anti_patterns_r2509 a ON a.id = k.pattern_id
  ORDER BY k.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_kill_actions_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_kill_actions_r2509() TO authenticated;

-- RPC 3: top_cost_patterns_r2509
CREATE OR REPLACE FUNCTION public.top_cost_patterns_r2509()
RETURNS TABLE (
  pattern_kind text,
  total_cost_rupees bigint,
  occurrences bigint,
  avg_frequency numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.pattern_kind,
         COALESCE(SUM(a.cost_impact_rupees), 0)::bigint AS total_cost_rupees,
         COUNT(*)::bigint AS occurrences,
         ROUND(AVG(a.frequency_score)::numeric, 1) AS avg_frequency
  FROM public.founder_anti_patterns_r2509 a
  GROUP BY a.pattern_kind
  ORDER BY total_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_cost_patterns_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cost_patterns_r2509() TO authenticated;

-- RPC 4: frequency_distribution_r2509
CREATE OR REPLACE FUNCTION public.frequency_distribution_r2509()
RETURNS TABLE (
  bucket text,
  pattern_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN a.frequency_score >= 75 THEN 'high (75-100)'
      WHEN a.frequency_score >= 50 THEN 'medium (50-74)'
      WHEN a.frequency_score >= 25 THEN 'low (25-49)'
      ELSE 'rare (0-24)'
    END AS bucket,
    COUNT(*)::bigint AS pattern_count
  FROM public.founder_anti_patterns_r2509 a
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.frequency_distribution_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.frequency_distribution_r2509() TO authenticated;

-- RPC 5: kill_outcome_summary_r2509
CREATE OR REPLACE FUNCTION public.kill_outcome_summary_r2509()
RETURNS TABLE (
  outcome text,
  action_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.anti_pattern_kill_actions_r2509;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT k.outcome,
         COUNT(*)::bigint AS action_count,
         ROUND((COUNT(*)::numeric * 100.0 / total), 1) AS pct_of_total
  FROM public.anti_pattern_kill_actions_r2509 k
  GROUP BY k.outcome
  ORDER BY action_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kill_outcome_summary_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kill_outcome_summary_r2509() TO authenticated;

-- RPC 6: monthly_anti_pattern_trend_r2509
CREATE OR REPLACE FUNCTION public.monthly_anti_pattern_trend_r2509()
RETURNS TABLE (
  month_label text,
  pattern_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.observed_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS pattern_count,
         COALESCE(SUM(a.cost_impact_rupees), 0)::bigint AS total_cost_rupees
  FROM public.founder_anti_patterns_r2509 a
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_anti_pattern_trend_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_anti_pattern_trend_r2509() TO authenticated;

-- RPC 7: status_funnel_r2509
CREATE OR REPLACE FUNCTION public.status_funnel_r2509()
RETURNS TABLE (
  status text,
  pattern_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status,
         COUNT(*)::bigint AS pattern_count,
         COALESCE(SUM(a.cost_impact_rupees), 0)::bigint AS total_cost_rupees
  FROM public.founder_anti_patterns_r2509 a
  GROUP BY a.status
  ORDER BY pattern_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2509() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2509() TO authenticated;
