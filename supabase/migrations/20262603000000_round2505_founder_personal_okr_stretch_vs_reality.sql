-- Round 2505: founder personal OKR stretch vs reality tracker
-- Honest self-grading of personal OKRs: stretch target vs realistic target vs actual outcome
-- Lessons learned log to apply forward

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_personal_okrs_r2505 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  okr_name text NOT NULL,
  kr_text text NOT NULL,
  stretch_target numeric NOT NULL,
  realistic_target numeric NOT NULL,
  actual_value numeric NOT NULL DEFAULT 0,
  delta_to_stretch_pct numeric NOT NULL DEFAULT 0,
  delta_to_realistic_pct numeric NOT NULL DEFAULT 0,
  honest_grade text NOT NULL CHECK (honest_grade IN ('A','B','C','D','F')),
  lessons_md text,
  status text NOT NULL CHECK (status IN ('in_progress','done','missed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.personal_okr_lessons_log_r2505 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  lesson_kind text NOT NULL CHECK (lesson_kind IN ('overestimated','underestimated','poor_priority','external_blocker','great_execution')),
  lesson_md text NOT NULL,
  action_to_apply text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_okrs_r2505 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_okr_lessons_log_r2505 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_personal_okrs_r2505;
CREATE POLICY founder_all ON public.founder_personal_okrs_r2505
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.personal_okr_lessons_log_r2505;
CREATE POLICY founder_all ON public.personal_okr_lessons_log_r2505
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed personal OKRs
INSERT INTO public.founder_personal_okrs_r2505
  (quarter_label, okr_name, kr_text, stretch_target, realistic_target, actual_value, delta_to_stretch_pct, delta_to_realistic_pct, honest_grade, lessons_md, status, notes)
VALUES
  ('Q2-2026', 'Hit 100 paying hospitals', 'New paying hospitals signed by end of Q2', 100, 60, 47, -53.0, -21.7, 'C', 'Overestimated outbound sales velocity; chain deals took 3x longer than planned', 'in_progress', 'Stretch was a 10x; realistic was 5x. Actual 4.7x — solid C, lessons applied'),
  ('Q2-2026', 'Cashfree payouts at scale', 'Successful auto-payouts to engineers per month', 5000, 2000, 0, -100.0, -100.0, 'F', 'External blocker — Cashfree KYC stuck in activation; queue building safely but cant flush', 'missed', 'Not my failure to execute, but my failure to predict KYC delay'),
  ('Q2-2026', 'Engineer NPS above 60', 'Quarterly engineer NPS score', 70, 60, 64, -8.6, 6.7, 'B', 'Underestimated power of weekly office hours; small effort, big trust dividend', 'done', 'Beat realistic target; missed stretch by 9 percent — honest B'),
  ('Q2-2026', 'Ship Android v0.5', 'Production release with 10 new features', 10, 7, 8, -20.0, 14.3, 'B', 'Great execution on solo ship; one feature dropped due to scope creep', 'done', 'Beat realistic, missed stretch — but quality held up in audits'),
  ('Q2-2026', 'Hire 2 senior engineers', 'Senior FT hires onboarded', 2, 1, 0, -100.0, -100.0, 'F', 'Poor priority — spent zero time on recruiting; deferred hiring to Q3', 'dropped', 'Conscious deprioritization, not a miss — but should not have set the OKR if not committing time');

-- Seed lessons log
INSERT INTO public.personal_okr_lessons_log_r2505
  (quarter_label, lesson_kind, lesson_md, action_to_apply, owner_email, status, notes)
VALUES
  ('Q2-2026', 'overestimated', 'Hospital chain deal cycle is 90-120 days not 30-45. Stretch targets that assume short cycles will always miss.', 'For Q3 stretch targets on chain deals, use 90 day cycle baseline. Realistic = 1 chain/quarter, stretch = 2', 'marketingtools@getphyllo.com', 'open', 'Apply to Q3 planning doc'),
  ('Q2-2026', 'external_blocker', 'Regulatory/KYC blockers can sink an entire KR. Always have a non-blocked KR as backup.', 'Each OKR must have at least one KR with zero external dependencies', 'marketingtools@getphyllo.com', 'in_progress', 'Re-draft Q3 OKRs with this rule'),
  ('Q2-2026', 'underestimated', 'Weekly engineer office hours = low effort, high trust outcome. Underestimated this 5x.', 'Make office hours a standing KR not a side-effect activity', 'marketingtools@getphyllo.com', 'done', 'Added to Q3 OKR draft'),
  ('Q2-2026', 'poor_priority', 'Set a hiring OKR with zero allocated time. Either commit time or do not set the OKR.', 'Pre-flight check: does each OKR have a calendar block? If no, kill the OKR before quarter starts.', 'marketingtools@getphyllo.com', 'open', 'Build into Q3 OKR review template'),
  ('Q2-2026', 'great_execution', 'Solo Android v0.5 ship beat realistic target. Pattern: small daily commits, audit-fix sweeps, design batches.', 'Codify the design-batch + audit-fix pattern as the v0.6 default mode', 'marketingtools@getphyllo.com', 'done', 'Pattern documented in MEMORY.md');

-- RPC 1: list personal OKRs
CREATE OR REPLACE FUNCTION public.list_personal_okrs_r2505()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  okr_name text,
  kr_text text,
  stretch_target numeric,
  realistic_target numeric,
  actual_value numeric,
  delta_to_stretch_pct numeric,
  delta_to_realistic_pct numeric,
  honest_grade text,
  lessons_md text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.quarter_label, o.okr_name, o.kr_text, o.stretch_target, o.realistic_target,
         o.actual_value, o.delta_to_stretch_pct, o.delta_to_realistic_pct, o.honest_grade,
         o.lessons_md, o.status, o.notes, o.created_at
  FROM public.founder_personal_okrs_r2505 o
  ORDER BY o.quarter_label DESC, o.honest_grade ASC, o.okr_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_personal_okrs_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_personal_okrs_r2505() TO authenticated;

-- RPC 2: list lessons log
CREATE OR REPLACE FUNCTION public.list_lessons_log_r2505()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  lesson_kind text,
  lesson_md text,
  action_to_apply text,
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
  SELECT l.id, l.quarter_label, l.lesson_kind, l.lesson_md, l.action_to_apply, l.owner_email,
         l.status, l.notes, l.created_at
  FROM public.personal_okr_lessons_log_r2505 l
  ORDER BY l.quarter_label DESC, l.lesson_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_lessons_log_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_lessons_log_r2505() TO authenticated;

-- RPC 3: grade distribution
CREATE OR REPLACE FUNCTION public.grade_distribution_r2505()
RETURNS TABLE (
  honest_grade text,
  okr_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH total AS (SELECT count(*)::numeric AS t FROM public.founder_personal_okrs_r2505)
  SELECT o.honest_grade,
         count(*)::bigint,
         ROUND((count(*)::numeric / NULLIF((SELECT t FROM total),0)) * 100, 1)
  FROM public.founder_personal_okrs_r2505 o
  GROUP BY o.honest_grade
  ORDER BY o.honest_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.grade_distribution_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_distribution_r2505() TO authenticated;

-- RPC 4: stretch vs realistic summary
CREATE OR REPLACE FUNCTION public.stretch_vs_realistic_summary_r2505()
RETURNS TABLE (
  metric text,
  value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_okrs'::text, count(*)::numeric FROM public.founder_personal_okrs_r2505
  UNION ALL
  SELECT 'hit_stretch_count'::text, count(*)::numeric FROM public.founder_personal_okrs_r2505 WHERE actual_value >= stretch_target
  UNION ALL
  SELECT 'hit_realistic_count'::text, count(*)::numeric FROM public.founder_personal_okrs_r2505 WHERE actual_value >= realistic_target
  UNION ALL
  SELECT 'avg_delta_to_stretch_pct'::text, ROUND(AVG(delta_to_stretch_pct), 1) FROM public.founder_personal_okrs_r2505
  UNION ALL
  SELECT 'avg_delta_to_realistic_pct'::text, ROUND(AVG(delta_to_realistic_pct), 1) FROM public.founder_personal_okrs_r2505;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.stretch_vs_realistic_summary_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stretch_vs_realistic_summary_r2505() TO authenticated;

-- RPC 5: top lessons (most actionable, by status open + in_progress first)
CREATE OR REPLACE FUNCTION public.top_lessons_r2505()
RETURNS TABLE (
  lesson_kind text,
  lesson_count bigint,
  open_or_in_progress bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.lesson_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE l.status IN ('open','in_progress'))::bigint
  FROM public.personal_okr_lessons_log_r2505 l
  GROUP BY l.lesson_kind
  ORDER BY count(*) DESC, l.lesson_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lessons_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lessons_r2505() TO authenticated;

-- RPC 6: quarterly trend
CREATE OR REPLACE FUNCTION public.quarterly_trend_r2505()
RETURNS TABLE (
  quarter_label text,
  okr_count bigint,
  avg_delta_realistic_pct numeric,
  hit_realistic_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.quarter_label,
         count(*)::bigint,
         ROUND(AVG(o.delta_to_realistic_pct), 1),
         ROUND((count(*) FILTER (WHERE o.actual_value >= o.realistic_target)::numeric / NULLIF(count(*),0)) * 100, 1)
  FROM public.founder_personal_okrs_r2505 o
  GROUP BY o.quarter_label
  ORDER BY o.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_trend_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_trend_r2505() TO authenticated;

-- RPC 7: status breakdown
CREATE OR REPLACE FUNCTION public.status_breakdown_r2505()
RETURNS TABLE (
  status text,
  okr_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH total AS (SELECT count(*)::numeric AS t FROM public.founder_personal_okrs_r2505)
  SELECT o.status,
         count(*)::bigint,
         ROUND((count(*)::numeric / NULLIF((SELECT t FROM total),0)) * 100, 1)
  FROM public.founder_personal_okrs_r2505 o
  GROUP BY o.status
  ORDER BY count(*) DESC, o.status ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2505() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2505() TO authenticated;

