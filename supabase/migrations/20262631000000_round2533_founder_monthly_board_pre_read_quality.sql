-- Round 2533: founder-monthly-board-pre-read-quality
-- Tables: founder_board_pre_reads_r2533, pre_read_section_quality_r2533
-- RPCs: list_pre_reads_r2533, list_section_quality_r2533, top_omission_sections_r2533,
--       monthly_quality_trend_r2533, section_kind_breakdown_r2533, iteration_velocity_r2533,
--       founder_pulse_summary_r2533

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_board_pre_reads_r2533 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  sections_count int NOT NULL DEFAULT 0,
  clarity_score int NOT NULL DEFAULT 0 CHECK (clarity_score BETWEEN 0 AND 100),
  completeness_score int NOT NULL DEFAULT 0 CHECK (completeness_score BETWEEN 0 AND 100),
  founder_self_grade text NOT NULL DEFAULT 'C' CHECK (founder_self_grade IN ('A','B','C','D','F')),
  iteration_count int NOT NULL DEFAULT 1,
  sent_at timestamptz,
  board_feedback_md text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','final','closed')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pre_read_section_quality_r2533 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pre_read_id uuid NOT NULL REFERENCES public.founder_board_pre_reads_r2533(id) ON DELETE CASCADE,
  section_kind text NOT NULL CHECK (section_kind IN ('business_metrics','financials','customers','team','risks','asks','strategy','competition')),
  clarity_score int NOT NULL DEFAULT 0 CHECK (clarity_score BETWEEN 0 AND 100),
  completeness_score int NOT NULL DEFAULT 0 CHECK (completeness_score BETWEEN 0 AND 100),
  top_omission text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_board_pre_reads_r2533 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_read_section_quality_r2533 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_board_pre_reads_r2533;
CREATE POLICY founder_all ON public.founder_board_pre_reads_r2533
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.pre_read_section_quality_r2533;
CREATE POLICY founder_all ON public.pre_read_section_quality_r2533
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed pre-reads
WITH p1 AS (
  INSERT INTO public.founder_board_pre_reads_r2533
    (month_label, sections_count, clarity_score, completeness_score, founder_self_grade, iteration_count,
     sent_at, board_feedback_md, status, owner_email, notes)
  VALUES
    ('2026-03', 8, 72, 78, 'B', 3, '2026-03-28T18:00:00Z'::timestamptz,
     '## Feedback\n- More detail on competition\n- Financial bridge missing', 'closed', 'founder@equipseva.in', 'Q4-FY26 review')
  RETURNING id
), p2 AS (
  INSERT INTO public.founder_board_pre_reads_r2533
    (month_label, sections_count, clarity_score, completeness_score, founder_self_grade, iteration_count,
     sent_at, board_feedback_md, status, owner_email, notes)
  VALUES
    ('2026-04', 8, 80, 82, 'B', 2, '2026-04-26T18:00:00Z'::timestamptz,
     '## Feedback\n- Better than last month\n- Need clearer asks', 'closed', 'founder@equipseva.in', 'monthly review')
  RETURNING id
), p3 AS (
  INSERT INTO public.founder_board_pre_reads_r2533
    (month_label, sections_count, clarity_score, completeness_score, founder_self_grade, iteration_count,
     sent_at, board_feedback_md, status, owner_email, notes)
  VALUES
    ('2026-05', 8, 85, 88, 'A', 2, '2026-05-29T18:00:00Z'::timestamptz,
     '## Feedback\n- Strong pack\n- Risks section best yet', 'final', 'founder@equipseva.in', 'May pack')
  RETURNING id
), p4 AS (
  INSERT INTO public.founder_board_pre_reads_r2533
    (month_label, sections_count, clarity_score, completeness_score, founder_self_grade, iteration_count,
     sent_at, board_feedback_md, status, owner_email, notes)
  VALUES
    ('2026-06', 8, 76, 80, 'B', 4, NULL,
     '## Pending\n- Still iterating', 'draft', 'founder@equipseva.in', 'June draft')
  RETURNING id
)
INSERT INTO public.pre_read_section_quality_r2533
  (pre_read_id, section_kind, clarity_score, completeness_score, top_omission, owner_email, status, notes)
SELECT id, 'business_metrics', 78, 82, 'churn cohort detail', 'founder@equipseva.in', 'final', 'mar metrics' FROM p1
UNION ALL
SELECT id, 'financials', 70, 72, 'cash bridge', 'founder@equipseva.in', 'final', 'mar fin' FROM p1
UNION ALL
SELECT id, 'competition', 60, 65, 'no competitive matrix', 'founder@equipseva.in', 'final', 'mar comp' FROM p1
UNION ALL
SELECT id, 'business_metrics', 82, 85, 'cohort retention', 'founder@equipseva.in', 'final', 'apr metrics' FROM p2
UNION ALL
SELECT id, 'asks', 75, 70, 'specific dollar amounts', 'founder@equipseva.in', 'final', 'apr asks' FROM p2
UNION ALL
SELECT id, 'risks', 90, 92, 'none', 'founder@equipseva.in', 'final', 'may risks strong' FROM p3
UNION ALL
SELECT id, 'strategy', 88, 90, 'minor gaps', 'founder@equipseva.in', 'final', 'may strategy' FROM p3
UNION ALL
SELECT id, 'team', 72, 78, 'attrition data', 'founder@equipseva.in', 'draft', 'jun team' FROM p4
UNION ALL
SELECT id, 'customers', 78, 82, 'NPS breakdown', 'founder@equipseva.in', 'draft', 'jun cust' FROM p4
UNION ALL
SELECT id, 'competition', 65, 70, 'win/loss analysis', 'founder@equipseva.in', 'draft', 'jun comp' FROM p4;

CREATE OR REPLACE FUNCTION public.list_pre_reads_r2533()
RETURNS TABLE (id uuid, month_label text, sections_count int, clarity_score int,
               completeness_score int, founder_self_grade text, iteration_count int,
               sent_at timestamptz, status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.month_label, p.sections_count, p.clarity_score, p.completeness_score,
           p.founder_self_grade, p.iteration_count, p.sent_at, p.status, p.owner_email
    FROM public.founder_board_pre_reads_r2533 p
    ORDER BY p.month_label DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_pre_reads_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pre_reads_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_section_quality_r2533()
RETURNS TABLE (id uuid, pre_read_id uuid, section_kind text, clarity_score int,
               completeness_score int, top_omission text, status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.pre_read_id, s.section_kind, s.clarity_score, s.completeness_score,
           s.top_omission, s.status, s.owner_email
    FROM public.pre_read_section_quality_r2533 s
    ORDER BY s.created_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_section_quality_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_section_quality_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_omission_sections_r2533()
RETURNS TABLE (section_kind text, top_omission text, clarity_score int, completeness_score int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_kind, s.top_omission, s.clarity_score, s.completeness_score, s.status
    FROM public.pre_read_section_quality_r2533 s
    WHERE s.top_omission IS NOT NULL AND s.top_omission <> 'none'
    ORDER BY s.completeness_score ASC, s.clarity_score ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_omission_sections_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_omission_sections_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_quality_trend_r2533()
RETURNS TABLE (month_label text, clarity_score int, completeness_score int, founder_self_grade text, iteration_count int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.month_label, p.clarity_score, p.completeness_score, p.founder_self_grade,
           p.iteration_count, p.status
    FROM public.founder_board_pre_reads_r2533 p
    ORDER BY p.month_label ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_quality_trend_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_quality_trend_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.section_kind_breakdown_r2533()
RETURNS TABLE (section_kind text, sections_count bigint, avg_clarity numeric, avg_completeness numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_kind, count(*)::bigint,
           round(avg(s.clarity_score)::numeric, 2),
           round(avg(s.completeness_score)::numeric, 2)
    FROM public.pre_read_section_quality_r2533 s
    GROUP BY s.section_kind
    ORDER BY round(avg(s.completeness_score)::numeric, 2) ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.section_kind_breakdown_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.section_kind_breakdown_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.iteration_velocity_r2533()
RETURNS TABLE (month_label text, iteration_count int, status text, sent_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.month_label, p.iteration_count, p.status, p.sent_at
    FROM public.founder_board_pre_reads_r2533 p
    ORDER BY p.iteration_count DESC, p.month_label DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.iteration_velocity_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.iteration_velocity_r2533() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2533()
RETURNS TABLE (total_pre_reads bigint, sent_count bigint, draft_count bigint,
               avg_clarity numeric, avg_completeness numeric, avg_iterations numeric, total_sections bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::bigint FROM public.founder_board_pre_reads_r2533),
      (SELECT count(*)::bigint FROM public.founder_board_pre_reads_r2533 WHERE status IN ('sent','final','closed')),
      (SELECT count(*)::bigint FROM public.founder_board_pre_reads_r2533 WHERE status = 'draft'),
      (SELECT round(avg(clarity_score)::numeric, 2) FROM public.founder_board_pre_reads_r2533),
      (SELECT round(avg(completeness_score)::numeric, 2) FROM public.founder_board_pre_reads_r2533),
      (SELECT round(avg(iteration_count)::numeric, 2) FROM public.founder_board_pre_reads_r2533),
      (SELECT count(*)::bigint FROM public.pre_read_section_quality_r2533);
END;$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2533() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2533() TO authenticated;

