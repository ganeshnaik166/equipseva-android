-- Round 2629: Founder Monthly Emotional Resilience Pulse
-- Tracks monthly emotional resilience scores and recovery practice outcomes

BEGIN;

-- ============================================================
-- TABLE: founder_emotional_resilience_r2629
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_emotional_resilience_r2629 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  resilience_score int NOT NULL DEFAULT 0 CHECK (resilience_score BETWEEN 0 AND 100),
  stress_score int NOT NULL DEFAULT 0 CHECK (stress_score BETWEEN 0 AND 10),
  recovery_practices_md text,
  biggest_test_md text,
  lesson_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','done','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resilience_r2629_month ON public.founder_emotional_resilience_r2629(month_label);
CREATE INDEX IF NOT EXISTS idx_resilience_r2629_status ON public.founder_emotional_resilience_r2629(status);
CREATE INDEX IF NOT EXISTS idx_resilience_r2629_score ON public.founder_emotional_resilience_r2629(resilience_score);

ALTER TABLE public.founder_emotional_resilience_r2629 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_emotional_resilience_r2629;
CREATE POLICY founder_all ON public.founder_emotional_resilience_r2629
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE: resilience_practice_outcomes_r2629
-- ============================================================
CREATE TABLE IF NOT EXISTS public.resilience_practice_outcomes_r2629 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_id uuid NOT NULL REFERENCES public.founder_emotional_resilience_r2629(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  practice_kind text NOT NULL CHECK (practice_kind IN ('meditation','exercise','therapy','peer_support','journaling','sleep')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_practice_outcomes_r2629_pulse ON public.resilience_practice_outcomes_r2629(pulse_id);
CREATE INDEX IF NOT EXISTS idx_practice_outcomes_r2629_kind ON public.resilience_practice_outcomes_r2629(practice_kind);
CREATE INDEX IF NOT EXISTS idx_practice_outcomes_r2629_outcome ON public.resilience_practice_outcomes_r2629(outcome);
CREATE INDEX IF NOT EXISTS idx_practice_outcomes_r2629_status ON public.resilience_practice_outcomes_r2629(status);

ALTER TABLE public.resilience_practice_outcomes_r2629 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.resilience_practice_outcomes_r2629;
CREATE POLICY founder_all ON public.resilience_practice_outcomes_r2629
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.founder_emotional_resilience_r2629 (month_label, resilience_score, stress_score, recovery_practices_md, biggest_test_md, lesson_md, owner_email, status, notes) VALUES
  ('2026-02', 68, 7, 'Daily meditation 20min + weekly therapy', 'Cashfree KYC rejection — runway anxiety spike', 'Stress peaks need pre-planned recovery routines', 'founder@equipseva.com', 'done', 'Therapy session helped reframe'),
  ('2026-03', 74, 6, 'Morning runs + journaling', 'Co-founder dispute over equity split', 'Peer support beats lone problem-solving', 'founder@equipseva.com', 'done', 'YPO forum session pivotal'),
  ('2026-04', 82, 4, 'Sleep hygiene + meditation', 'Series A pitch rejection from top firm', 'Rest is a competitive advantage', 'founder@equipseva.com', 'done', 'Sleep 8h consistently'),
  ('2026-05', 78, 5, 'Therapy + peer support group', 'Lost a key engineer to competitor', 'Talent attrition needs systemic fix not panic', 'founder@equipseva.com', 'done', NULL),
  ('2026-06', 85, 3, 'Combination: meditation, exercise, therapy', 'Hospital chain pilot delayed by 6 weeks', 'Patience compounds when systems are right', 'founder@equipseva.com', 'draft', 'In progress');

INSERT INTO public.resilience_practice_outcomes_r2629 (pulse_id, observed_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-02-15'::timestamptz, 'meditation', 'positive', 'founder@equipseva.com', 'done', 'Reduced morning anxiety significantly'
FROM public.founder_emotional_resilience_r2629 WHERE month_label = '2026-02' LIMIT 1;

INSERT INTO public.resilience_practice_outcomes_r2629 (pulse_id, observed_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-03-10'::timestamptz, 'peer_support', 'positive', 'founder@equipseva.com', 'done', 'YPO forum gave perspective'
FROM public.founder_emotional_resilience_r2629 WHERE month_label = '2026-03' LIMIT 1;

INSERT INTO public.resilience_practice_outcomes_r2629 (pulse_id, observed_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-20'::timestamptz, 'sleep', 'positive', 'founder@equipseva.com', 'done', 'Better decision quality next day'
FROM public.founder_emotional_resilience_r2629 WHERE month_label = '2026-04' LIMIT 1;

INSERT INTO public.resilience_practice_outcomes_r2629 (pulse_id, observed_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-18'::timestamptz, 'therapy', 'neutral', 'founder@equipseva.com', 'open', 'Working through grief of attrition'
FROM public.founder_emotional_resilience_r2629 WHERE month_label = '2026-05' LIMIT 1;

INSERT INTO public.resilience_practice_outcomes_r2629 (pulse_id, observed_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-08'::timestamptz, 'exercise', 'pending', 'founder@equipseva.com', 'open', 'Daily 5km runs started'
FROM public.founder_emotional_resilience_r2629 WHERE month_label = '2026-06' LIMIT 1;

-- ============================================================
-- RPCs (7)
-- ============================================================

-- 1. list_resilience_r2629
CREATE OR REPLACE FUNCTION public.list_resilience_r2629()
RETURNS TABLE (
  id uuid,
  month_label text,
  resilience_score int,
  stress_score int,
  recovery_practices_md text,
  biggest_test_md text,
  lesson_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.month_label, r.resilience_score, r.stress_score,
         r.recovery_practices_md, r.biggest_test_md, r.lesson_md,
         r.owner_email, r.status, r.notes, r.created_at
  FROM public.founder_emotional_resilience_r2629 r
  ORDER BY r.month_label DESC, r.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_resilience_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_resilience_r2629() TO authenticated;

-- 2. list_practice_outcomes_r2629
CREATE OR REPLACE FUNCTION public.list_practice_outcomes_r2629()
RETURNS TABLE (
  id uuid,
  pulse_id uuid,
  month_label text,
  observed_at timestamptz,
  practice_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.pulse_id, r.month_label,
         o.observed_at, o.practice_kind, o.outcome, o.owner_email,
         o.status, o.notes
  FROM public.resilience_practice_outcomes_r2629 o
  LEFT JOIN public.founder_emotional_resilience_r2629 r ON r.id = o.pulse_id
  ORDER BY o.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_practice_outcomes_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_practice_outcomes_r2629() TO authenticated;

-- 3. top_practice_focus_r2629
CREATE OR REPLACE FUNCTION public.top_practice_focus_r2629()
RETURNS TABLE (
  practice_kind text,
  entry_count bigint,
  positive_count bigint,
  positive_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.practice_kind,
         COUNT(*)::bigint AS entry_count,
         COUNT(*) FILTER (WHERE o.outcome = 'positive')::bigint AS positive_count,
         (COUNT(*) FILTER (WHERE o.outcome = 'positive')::numeric
           / NULLIF(COUNT(*),0)::numeric * 100)::numeric AS positive_rate
  FROM public.resilience_practice_outcomes_r2629 o
  GROUP BY o.practice_kind
  ORDER BY positive_count DESC, entry_count DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_practice_focus_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_practice_focus_r2629() TO authenticated;

-- 4. monthly_score_trend_r2629
CREATE OR REPLACE FUNCTION public.monthly_score_trend_r2629()
RETURNS TABLE (
  month_label text,
  resilience_score int,
  stress_score int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.month_label, r.resilience_score, r.stress_score, r.status
  FROM public.founder_emotional_resilience_r2629 r
  ORDER BY r.month_label DESC
  LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_score_trend_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_score_trend_r2629() TO authenticated;

-- 5. status_funnel_r2629
CREATE OR REPLACE FUNCTION public.status_funnel_r2629()
RETURNS TABLE (
  status text,
  entry_count bigint,
  avg_resilience numeric,
  avg_stress numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status,
         COUNT(*)::bigint AS entry_count,
         COALESCE(AVG(r.resilience_score),0)::numeric AS avg_resilience,
         COALESCE(AVG(r.stress_score),0)::numeric AS avg_stress
  FROM public.founder_emotional_resilience_r2629 r
  GROUP BY r.status
  ORDER BY entry_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2629() TO authenticated;

-- 6. lesson_summary_r2629
CREATE OR REPLACE FUNCTION public.lesson_summary_r2629()
RETURNS TABLE (
  month_label text,
  resilience_score int,
  stress_score int,
  lesson_md text,
  biggest_test_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.month_label, r.resilience_score, r.stress_score, r.lesson_md, r.biggest_test_md
  FROM public.founder_emotional_resilience_r2629 r
  WHERE r.lesson_md IS NOT NULL
  ORDER BY r.month_label DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lesson_summary_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lesson_summary_r2629() TO authenticated;

-- 7. founder_pulse_summary_r2629
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2629()
RETURNS TABLE (
  total_pulses bigint,
  avg_resilience numeric,
  avg_stress numeric,
  done_count bigint,
  draft_count bigint,
  total_practice_logs bigint,
  positive_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_emotional_resilience_r2629) AS total_pulses,
    (SELECT COALESCE(AVG(resilience_score),0)::numeric FROM public.founder_emotional_resilience_r2629) AS avg_resilience,
    (SELECT COALESCE(AVG(stress_score),0)::numeric FROM public.founder_emotional_resilience_r2629) AS avg_stress,
    (SELECT COUNT(*)::bigint FROM public.founder_emotional_resilience_r2629 WHERE status = 'done') AS done_count,
    (SELECT COUNT(*)::bigint FROM public.founder_emotional_resilience_r2629 WHERE status = 'draft') AS draft_count,
    (SELECT COUNT(*)::bigint FROM public.resilience_practice_outcomes_r2629) AS total_practice_logs,
    (SELECT COUNT(*)::bigint FROM public.resilience_practice_outcomes_r2629 WHERE outcome = 'positive') AS positive_outcomes;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2629() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2629() TO authenticated;

COMMIT;
