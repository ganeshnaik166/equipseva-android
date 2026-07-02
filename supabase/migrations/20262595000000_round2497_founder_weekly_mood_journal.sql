BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_mood_r2497 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  dominant_emotion text NOT NULL CHECK (dominant_emotion IN ('joy','optimism','calm','focus','frustration','anxiety','overwhelm','anger','sadness')),
  what_worked_md text NOT NULL DEFAULT '',
  what_didnt_md text NOT NULL DEFAULT '',
  decisions_made_count int NOT NULL DEFAULT 0 CHECK (decisions_made_count >= 0),
  decisions_regret_count int NOT NULL DEFAULT 0 CHECK (decisions_regret_count >= 0),
  red_flag_patterns_md text NOT NULL DEFAULT '',
  mood_score int NOT NULL DEFAULT 5 CHECK (mood_score >= 0 AND mood_score <= 10),
  energy_score int NOT NULL DEFAULT 5 CHECK (energy_score >= 0 AND energy_score <= 10),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.emotion_decision_correlations_r2497 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  correlation_kind text NOT NULL CHECK (correlation_kind IN ('joy_better_decisions','frustration_worse_decisions','anxiety_avoidance','calm_clarity','overwhelm_postponed')),
  correlation_strength int NOT NULL DEFAULT 50 CHECK (correlation_strength >= 0 AND correlation_strength <= 100),
  observation_md text NOT NULL DEFAULT '',
  action_to_amplify_or_kill text NOT NULL DEFAULT '',
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_mood_r2497 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emotion_decision_correlations_r2497 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_mood_r2497 ON public.founder_weekly_mood_r2497;
CREATE POLICY founder_all_mood_r2497 ON public.founder_weekly_mood_r2497
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_corr_r2497 ON public.emotion_decision_correlations_r2497;
CREATE POLICY founder_all_corr_r2497 ON public.emotion_decision_correlations_r2497
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed mood entries (5 weeks)
INSERT INTO public.founder_weekly_mood_r2497 (week_start, dominant_emotion, what_worked_md, what_didnt_md, decisions_made_count, decisions_regret_count, red_flag_patterns_md, mood_score, energy_score, notes) VALUES
('2026-05-25'::date, 'overwhelm', '- Shipped Cashfree payouts\n- Closed audit 5', '- Tried to ship 4 features in one day\n- Skipped sleep twice', 12, 4, '- Pattern: I make worse decisions after 10pm\n- Pattern: Skipping standup correlates with scope creep', 4, 3, 'rough week, recovery needed'),
('2026-06-01'::date, 'optimism', '- Audit 6 caught Razorpay CRITICAL pre-prod\n- Founder digest auto-email landed', '- Procrastinated on Udyam paperwork', 9, 1, '- Pattern: paperwork avoidance under anxiety', 7, 7, 'momentum building'),
('2026-06-08'::date, 'focus', '- 4 audits closed in one week\n- v0.4 Phase 1 shipped', '- Said yes to a vendor call that wasted 2hrs', 18, 2, '- Pattern: yes-to-vendors during high-energy weeks costs focus', 8, 8, 'best week of quarter'),
('2026-06-15'::date, 'frustration', '- Day 5 ultracode batch hit 500 ships milestone', '- Audit-fix sweep r1322 caught 14 bugs I should have specced better', 22, 6, '- Pattern: frustration spikes when design agents emit wrong schema\n- Pattern: I rage-spec when audit-fix volume climbs', 5, 6, 'productive but bitter'),
('2026-06-22'::date, 'calm', '- Workflow normalizer scrubs 6 failure modes auto\n- 3 consecutive clean audits', '- Lost a day to a Cashfree KYC waitloop I cannot control', 14, 1, '- Pattern: calm + structured = best decision quality', 8, 7, 'sustainable pace')
ON CONFLICT DO NOTHING;

INSERT INTO public.emotion_decision_correlations_r2497 (week_start, correlation_kind, correlation_strength, observation_md, action_to_amplify_or_kill, owner_email, status, notes) VALUES
('2026-05-25'::date, 'overwhelm_postponed', 85, 'When overwhelmed I postpone the hardest decision (Udyam paperwork, audit response)', 'KILL: stop batching > 3 hard decisions per day. Schedule one hard call before noon.', 'marketingtools@getphyllo.com', 'in_progress', 'tracking week over week'),
('2026-06-01'::date, 'calm_clarity', 78, 'Calm + structured weeks ship more high-quality features per founder-hour', 'AMPLIFY: protect Tue/Wed mornings as deep-work blocks, no calls', 'marketingtools@getphyllo.com', 'open', 'try for 4 weeks'),
('2026-06-08'::date, 'joy_better_decisions', 72, 'Joy-week saw faster yes/no calls and less regret per decision', 'AMPLIFY: weekly Friday review with 1 win celebrated explicitly', 'marketingtools@getphyllo.com', 'open', 'add to runbook'),
('2026-06-15'::date, 'frustration_worse_decisions', 90, 'Frustration drove 6 regretted calls — most around scope and rude replies in PR comments', 'KILL: when frustrated, do NOT comment on PRs for 30min. Walk first.', 'marketingtools@getphyllo.com', 'in_progress', 'highest correlation strength logged'),
('2026-06-22'::date, 'anxiety_avoidance', 68, 'Anxiety about KYC delays caused 1 day of busywork avoidance', 'KILL: when blocked by external party, switch to a queued internal ship within 1hr', 'marketingtools@getphyllo.com', 'open', 'test next blocker')
ON CONFLICT DO NOTHING;

-- RPC 1: list_mood
CREATE OR REPLACE FUNCTION public.list_mood_r2497()
RETURNS TABLE (
  id uuid,
  week_start date,
  dominant_emotion text,
  what_worked_md text,
  what_didnt_md text,
  decisions_made_count int,
  decisions_regret_count int,
  red_flag_patterns_md text,
  mood_score int,
  energy_score int,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.week_start, m.dominant_emotion, m.what_worked_md, m.what_didnt_md,
    m.decisions_made_count, m.decisions_regret_count, m.red_flag_patterns_md,
    m.mood_score, m.energy_score, m.notes, m.created_at
  FROM public.founder_weekly_mood_r2497 m
  ORDER BY m.week_start DESC;
END;
$$;

-- RPC 2: list_correlations
CREATE OR REPLACE FUNCTION public.list_correlations_r2497()
RETURNS TABLE (
  id uuid,
  week_start date,
  correlation_kind text,
  correlation_strength int,
  observation_md text,
  action_to_amplify_or_kill text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.week_start, c.correlation_kind, c.correlation_strength,
    c.observation_md, c.action_to_amplify_or_kill, c.owner_email,
    c.status, c.notes, c.created_at
  FROM public.emotion_decision_correlations_r2497 c
  ORDER BY c.week_start DESC, c.correlation_strength DESC;
END;
$$;

-- RPC 3: weekly_mood_trend
CREATE OR REPLACE FUNCTION public.weekly_mood_trend_r2497()
RETURNS TABLE (
  week_start date,
  dominant_emotion text,
  mood_score int,
  energy_score int,
  mood_avg_4wk numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.week_start, m.dominant_emotion, m.mood_score, m.energy_score,
    ROUND(AVG(m.mood_score) OVER (ORDER BY m.week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS mood_avg_4wk
  FROM public.founder_weekly_mood_r2497 m
  ORDER BY m.week_start DESC;
END;
$$;

-- RPC 4: decisions_vs_emotion
CREATE OR REPLACE FUNCTION public.decisions_vs_emotion_r2497()
RETURNS TABLE (
  dominant_emotion text,
  weeks_logged int,
  total_decisions int,
  total_regretted int,
  regret_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.dominant_emotion,
    (COUNT(*))::int AS weeks_logged,
    (COALESCE(SUM(m.decisions_made_count),0))::int AS total_decisions,
    (COALESCE(SUM(m.decisions_regret_count),0))::int AS total_regretted,
    CASE WHEN COALESCE(SUM(m.decisions_made_count),0) = 0 THEN 0
      ELSE ROUND((SUM(m.decisions_regret_count)::numeric / SUM(m.decisions_made_count)::numeric) * 100, 2)
    END AS regret_rate_pct
  FROM public.founder_weekly_mood_r2497 m
  GROUP BY m.dominant_emotion
  ORDER BY regret_rate_pct DESC;
END;
$$;

-- RPC 5: top_red_flag_patterns
CREATE OR REPLACE FUNCTION public.top_red_flag_patterns_r2497()
RETURNS TABLE (
  week_start date,
  dominant_emotion text,
  red_flag_patterns_md text,
  mood_score int,
  decisions_regret_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.week_start, m.dominant_emotion, m.red_flag_patterns_md, m.mood_score, m.decisions_regret_count
  FROM public.founder_weekly_mood_r2497 m
  WHERE m.red_flag_patterns_md IS NOT NULL
    AND length(trim(m.red_flag_patterns_md)) > 0
  ORDER BY m.decisions_regret_count DESC, m.mood_score ASC
  LIMIT 20;
END;
$$;

-- RPC 6: dominant_emotion_distribution
CREATE OR REPLACE FUNCTION public.dominant_emotion_distribution_r2497()
RETURNS TABLE (
  dominant_emotion text,
  weeks_logged int,
  share_pct numeric,
  avg_mood numeric,
  avg_energy numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.founder_weekly_mood_r2497;
  RETURN QUERY
  SELECT m.dominant_emotion,
    (COUNT(*))::int AS weeks_logged,
    CASE WHEN v_total = 0 THEN 0
      ELSE ROUND((COUNT(*)::numeric / v_total::numeric) * 100, 2)
    END AS share_pct,
    ROUND(AVG(m.mood_score), 2) AS avg_mood,
    ROUND(AVG(m.energy_score), 2) AS avg_energy
  FROM public.founder_weekly_mood_r2497 m
  GROUP BY m.dominant_emotion
  ORDER BY weeks_logged DESC;
END;
$$;

-- RPC 7: monthly_pulse_summary
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2497()
RETURNS TABLE (
  month_start date,
  weeks_logged int,
  avg_mood numeric,
  avg_energy numeric,
  total_decisions int,
  total_regretted int,
  regret_rate_pct numeric,
  open_correlations int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', m.week_start)::date AS month_start,
    (COUNT(*))::int AS weeks_logged,
    ROUND(AVG(m.mood_score), 2) AS avg_mood,
    ROUND(AVG(m.energy_score), 2) AS avg_energy,
    (COALESCE(SUM(m.decisions_made_count),0))::int AS total_decisions,
    (COALESCE(SUM(m.decisions_regret_count),0))::int AS total_regretted,
    CASE WHEN COALESCE(SUM(m.decisions_made_count),0) = 0 THEN 0
      ELSE ROUND((SUM(m.decisions_regret_count)::numeric / SUM(m.decisions_made_count)::numeric) * 100, 2)
    END AS regret_rate_pct,
    (SELECT (COUNT(*))::int FROM public.emotion_decision_correlations_r2497 c
      WHERE date_trunc('month', c.week_start)::date = date_trunc('month', m.week_start)::date
        AND c.status IN ('open','in_progress')) AS open_correlations
  FROM public.founder_weekly_mood_r2497 m
  GROUP BY date_trunc('month', m.week_start)
  ORDER BY month_start DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_mood_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_correlations_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.weekly_mood_trend_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decisions_vs_emotion_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_red_flag_patterns_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dominant_emotion_distribution_r2497() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_summary_r2497() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mood_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_correlations_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_mood_trend_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.decisions_vs_emotion_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_red_flag_patterns_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dominant_emotion_distribution_r2497() TO authenticated;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_summary_r2497() TO authenticated;

