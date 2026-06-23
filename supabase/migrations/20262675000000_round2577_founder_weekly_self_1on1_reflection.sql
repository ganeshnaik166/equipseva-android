-- Round r2577: Founder weekly self 1-on-1 reflection
-- Tables: founder_self_reflections_r2577, reflection_commitment_outcomes_r2577
-- 7 RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.founder_self_reflections_r2577 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  wins_md text,
  misses_md text,
  lessons_md text,
  dominant_emotion text NOT NULL CHECK (dominant_emotion IN ('joy','focus','calm','frustration','anxiety','overwhelm','excitement','sadness')),
  calibration_score int NOT NULL DEFAULT 5 CHECK (calibration_score BETWEEN 0 AND 10),
  next_week_commitment_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','done','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reflection_commitment_outcomes_r2577 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_id uuid NOT NULL REFERENCES public.founder_self_reflections_r2577(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  commitment_kind text NOT NULL CHECK (commitment_kind IN ('strategic','tactical','relationship','health','family')),
  outcome text NOT NULL CHECK (outcome IN ('achieved','missed','dropped','partial')),
  lessons_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_self_reflections_r2577 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reflection_commitment_outcomes_r2577 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_self_reflections_r2577;
CREATE POLICY founder_all ON public.founder_self_reflections_r2577
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.reflection_commitment_outcomes_r2577;
CREATE POLICY founder_all ON public.reflection_commitment_outcomes_r2577
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed reflections
INSERT INTO public.founder_self_reflections_r2577
  (id, week_start, wins_md, misses_md, lessons_md, dominant_emotion, calibration_score, next_week_commitment_md, owner_email, status, notes)
VALUES
  ('22222222-2222-2222-2222-222222222201', '2026-06-01', '- Closed Apollo chain MSA\n- Shipped engineer marketplace v2\n- Hired senior backend eng', '- Missed CFO 1:1\n- Skipped 2 workouts\n- Investor follow-up slipped 3 days', '- Block calendar harder for deep work\n- Protect Sunday family time\n- Pre-write investor updates Sunday night', 'focus', 7, 'Ship hospital chain bulk-import flow & call 5 investors', 'founder@equipseva.in', 'closed', 'Strong week, energy high'),
  ('22222222-2222-2222-2222-222222222202', '2026-06-08', '- Hospital chain bulk-import shipped\n- 3 investor calls booked\n- Team morale post-allhands lift', '- Burned out mid-week\n- Snapped at engineering lead\n- Skipped therapy session', '- Cap deep-work to 4 hrs continuous\n- Schedule walks between meetings\n- Therapy is non-negotiable', 'overwhelm', 4, 'Recover energy + ship AMC churn report', 'founder@equipseva.in', 'closed', 'Energy crash week'),
  ('22222222-2222-2222-2222-222222222203', '2026-06-15', '- AMC churn report shipped\n- Recovered energy via 2 long walks daily\n- Therapy back on track', '- Marketing campaign delayed\n- 1 spare-part SLA breach not investigated', '- Marketing needs dedicated owner not founder time\n- SLA breaches need same-day RCA cron', 'calm', 8, 'Hire marketing lead candidate shortlist & wire SLA RCA cron', 'founder@equipseva.in', 'done', 'Clear-headed week'),
  ('22222222-2222-2222-2222-222222222204', '2026-06-22', '- Marketing lead shortlist ready\n- SLA RCA cron wired\n- Customer pulse NPS up 4 points', '- Investor data room outdated\n- Co-founder 1:1 cancelled twice', '- Data room is 30-min weekly chore not big batch\n- Co-founder time IS the leverage', 'joy', 9, 'Refresh data room weekly & 2 protected co-founder slots', 'founder@equipseva.in', 'draft', 'Best week this month')
ON CONFLICT (id) DO NOTHING;

-- Seed commitment outcomes
INSERT INTO public.reflection_commitment_outcomes_r2577
  (reflection_id, observed_at, commitment_kind, outcome, lessons_md, notes)
VALUES
  ('22222222-2222-2222-2222-222222222201', '2026-06-08 09:00:00+05:30', 'strategic', 'achieved', 'Bulk import shipped on time when scoped narrow', 'Apollo onboarded'),
  ('22222222-2222-2222-2222-222222222201', '2026-06-08 09:30:00+05:30', 'health', 'missed', 'Workout target slipped under deadline pressure', 'Need calendar block'),
  ('22222222-2222-2222-2222-222222222202', '2026-06-15 09:00:00+05:30', 'strategic', 'achieved', 'AMC churn shipped despite low energy', 'Useful to other CSMs'),
  ('22222222-2222-2222-2222-222222222202', '2026-06-15 09:30:00+05:30', 'relationship', 'partial', 'Made up with eng lead via 1:1 apology', 'Trust restored'),
  ('22222222-2222-2222-2222-222222222203', '2026-06-22 09:00:00+05:30', 'tactical', 'achieved', 'SLA RCA cron live in 2 days', 'Wired pg_cron 6 AM IST'),
  ('22222222-2222-2222-2222-222222222203', '2026-06-22 09:30:00+05:30', 'family', 'dropped', 'Family dinner skipped twice; reschedule next week', 'Reset Sunday')
ON CONFLICT (id) DO NOTHING;

-- RPC 1: list reflections
CREATE OR REPLACE FUNCTION public.list_reflections_r2577()
RETURNS TABLE (
  id uuid,
  week_start date,
  wins_md text,
  misses_md text,
  lessons_md text,
  dominant_emotion text,
  calibration_score int,
  next_week_commitment_md text,
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
  SELECT r.id, r.week_start, r.wins_md, r.misses_md, r.lessons_md, r.dominant_emotion,
         r.calibration_score, r.next_week_commitment_md, r.owner_email, r.status, r.notes, r.created_at
  FROM public.founder_self_reflections_r2577 r
  ORDER BY r.week_start DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reflections_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reflections_r2577() TO authenticated;

-- RPC 2: list commitment outcomes
CREATE OR REPLACE FUNCTION public.list_commitment_outcomes_r2577()
RETURNS TABLE (
  id uuid,
  reflection_id uuid,
  week_start date,
  observed_at timestamptz,
  commitment_kind text,
  outcome text,
  lessons_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.reflection_id, r.week_start, c.observed_at, c.commitment_kind, c.outcome, c.lessons_md, c.notes
  FROM public.reflection_commitment_outcomes_r2577 c
  JOIN public.founder_self_reflections_r2577 r ON r.id = c.reflection_id
  ORDER BY c.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_commitment_outcomes_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_commitment_outcomes_r2577() TO authenticated;

-- RPC 3: weekly emotion trend
CREATE OR REPLACE FUNCTION public.weekly_emotion_trend_r2577()
RETURNS TABLE (
  week_start date,
  dominant_emotion text,
  calibration_score int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.week_start, r.dominant_emotion, r.calibration_score, r.status
  FROM public.founder_self_reflections_r2577 r
  ORDER BY r.week_start ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_emotion_trend_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_emotion_trend_r2577() TO authenticated;

-- RPC 4: calibration trend
CREATE OR REPLACE FUNCTION public.calibration_trend_r2577()
RETURNS TABLE (
  week_start date,
  calibration_score int,
  rolling_4w_avg numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.week_start,
         r.calibration_score,
         AVG(r.calibration_score) OVER (ORDER BY r.week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)::numeric AS rolling_4w_avg
  FROM public.founder_self_reflections_r2577 r
  ORDER BY r.week_start ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.calibration_trend_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calibration_trend_r2577() TO authenticated;

-- RPC 5: commitment achievement rate
CREATE OR REPLACE FUNCTION public.commitment_achievement_rate_r2577()
RETURNS TABLE (
  commitment_kind text,
  total_count bigint,
  achieved_count bigint,
  partial_count bigint,
  missed_count bigint,
  dropped_count bigint,
  achievement_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.commitment_kind,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE c.outcome = 'achieved')::bigint AS achieved_count,
         COUNT(*) FILTER (WHERE c.outcome = 'partial')::bigint AS partial_count,
         COUNT(*) FILTER (WHERE c.outcome = 'missed')::bigint AS missed_count,
         COUNT(*) FILTER (WHERE c.outcome = 'dropped')::bigint AS dropped_count,
         CASE WHEN COUNT(*) > 0
              THEN (COUNT(*) FILTER (WHERE c.outcome = 'achieved')::numeric / COUNT(*)::numeric)
              ELSE 0::numeric END AS achievement_rate
  FROM public.reflection_commitment_outcomes_r2577 c
  GROUP BY c.commitment_kind
  ORDER BY achievement_rate DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.commitment_achievement_rate_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commitment_achievement_rate_r2577() TO authenticated;

-- RPC 6: top lessons (lessons_md preview)
CREATE OR REPLACE FUNCTION public.top_lessons_r2577()
RETURNS TABLE (
  week_start date,
  dominant_emotion text,
  calibration_score int,
  lessons_md text,
  source text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.week_start, r.dominant_emotion, r.calibration_score, r.lessons_md, 'reflection'::text AS source
  FROM public.founder_self_reflections_r2577 r
  WHERE r.lessons_md IS NOT NULL AND length(r.lessons_md) > 0
  UNION ALL
  SELECT r.week_start, r.dominant_emotion, r.calibration_score, c.lessons_md, ('outcome:' || c.commitment_kind)::text AS source
  FROM public.reflection_commitment_outcomes_r2577 c
  JOIN public.founder_self_reflections_r2577 r ON r.id = c.reflection_id
  WHERE c.lessons_md IS NOT NULL AND length(c.lessons_md) > 0
  ORDER BY week_start DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lessons_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lessons_r2577() TO authenticated;

-- RPC 7: monthly pulse summary
CREATE OR REPLACE FUNCTION public.monthly_pulse_summary_r2577()
RETURNS TABLE (
  month_label text,
  reflection_count bigint,
  avg_calibration numeric,
  most_common_emotion text,
  closed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT to_char(date_trunc('month', r.week_start), 'YYYY-MM') AS month_label,
           r.calibration_score,
           r.dominant_emotion,
           r.status
    FROM public.founder_self_reflections_r2577 r
  ),
  emo AS (
    SELECT month_label, dominant_emotion, COUNT(*) AS emo_count,
           ROW_NUMBER() OVER (PARTITION BY month_label ORDER BY COUNT(*) DESC) AS rn
    FROM base
    GROUP BY month_label, dominant_emotion
  )
  SELECT b.month_label,
         COUNT(*)::bigint AS reflection_count,
         AVG(b.calibration_score)::numeric AS avg_calibration,
         (SELECT e.dominant_emotion FROM emo e WHERE e.month_label = b.month_label AND e.rn = 1 LIMIT 1) AS most_common_emotion,
         COUNT(*) FILTER (WHERE b.status = 'closed')::bigint AS closed_count
  FROM base b
  GROUP BY b.month_label
  ORDER BY b.month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_summary_r2577() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_summary_r2577() TO authenticated;
