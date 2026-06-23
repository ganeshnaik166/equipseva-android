-- Round 2589: founder monthly leadership self assessment
-- Tracks founder's monthly self-rated leadership scores plus growth actions.

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_monthly_leadership_self_r2589 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  clarity_score int NOT NULL CHECK (clarity_score BETWEEN 0 AND 100),
  delegation_score int NOT NULL CHECK (delegation_score BETWEEN 0 AND 100),
  velocity_score int NOT NULL CHECK (velocity_score BETWEEN 0 AND 100),
  empathy_score int NOT NULL CHECK (empathy_score BETWEEN 0 AND 100),
  focus_score int NOT NULL CHECK (focus_score BETWEEN 0 AND 100),
  decision_quality_score int NOT NULL CHECK (decision_quality_score BETWEEN 0 AND 100),
  overall_score int NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  top_strength_md text,
  top_growth_area_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','done','closed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.leadership_growth_actions_r2589 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  assessment_id uuid NOT NULL REFERENCES public.founder_monthly_leadership_self_r2589(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('coaching','reading','peer_feedback','calendar_restructure','delegate_more','say_no')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.founder_monthly_leadership_self_r2589 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leadership_growth_actions_r2589 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_monthly_leadership_self_r2589;
CREATE POLICY founder_all ON public.founder_monthly_leadership_self_r2589
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.leadership_growth_actions_r2589;
CREATE POLICY founder_all ON public.leadership_growth_actions_r2589
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.founder_monthly_leadership_self_r2589
  (id, month_label, clarity_score, delegation_score, velocity_score, empathy_score, focus_score, decision_quality_score, overall_score, top_strength_md, top_growth_area_md, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111', '2026-02', 70, 55, 78, 72, 65, 74, 69, 'Strong product vision', 'Delegate more ops work', 'founder@equipseva.com', 'closed', 'first formal self check'),
  ('22222222-2222-2222-2222-222222222222', '2026-03', 74, 60, 80, 75, 68, 76, 72, 'Faster decisions', 'Calendar discipline', 'founder@equipseva.com', 'closed', 'small lift across board'),
  ('33333333-3333-3333-3333-333333333333', '2026-04', 78, 64, 82, 76, 72, 78, 75, 'Tight roadmap', 'Empathy in tough calls', 'founder@equipseva.com', 'closed', 'after coaching session'),
  ('44444444-4444-4444-4444-444444444444', '2026-05', 80, 70, 84, 78, 74, 80, 78, 'Shipping velocity', 'Saying no more often', 'founder@equipseva.com', 'done', 'best month yet'),
  ('55555555-5555-5555-5555-555555555555', '2026-06', 82, 72, 85, 80, 76, 82, 80, 'Clarity in OKRs', 'Focus blocks on calendar', 'founder@equipseva.com', 'draft', 'mid month check')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.leadership_growth_actions_r2589
  (assessment_id, action_at, action_kind, outcome, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111', now() - interval '120 days', 'coaching', 'positive', 'founder@equipseva.com', 'done', 'weekly exec coach'),
  ('22222222-2222-2222-2222-222222222222', now() - interval '95 days', 'reading', 'positive', 'founder@equipseva.com', 'done', 'Output Management book'),
  ('33333333-3333-3333-3333-333333333333', now() - interval '70 days', 'peer_feedback', 'neutral', 'founder@equipseva.com', 'done', 'CTO 1:1 retro'),
  ('44444444-4444-4444-4444-444444444444', now() - interval '40 days', 'calendar_restructure', 'positive', 'founder@equipseva.com', 'done', 'no-meeting Wednesdays'),
  ('44444444-4444-4444-4444-444444444444', now() - interval '30 days', 'delegate_more', 'pending', 'founder@equipseva.com', 'open', 'hand ops to COO'),
  ('55555555-5555-5555-5555-555555555555', now() - interval '10 days', 'say_no', 'pending', 'founder@equipseva.com', 'open', 'cut 2 side projects');

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_assessments_r2589()
RETURNS TABLE (
  id uuid,
  month_label text,
  clarity_score int,
  delegation_score int,
  velocity_score int,
  empathy_score int,
  focus_score int,
  decision_quality_score int,
  overall_score int,
  top_strength_md text,
  top_growth_area_md text,
  owner_email text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.month_label, a.clarity_score, a.delegation_score, a.velocity_score,
         a.empathy_score, a.focus_score, a.decision_quality_score, a.overall_score,
         a.top_strength_md, a.top_growth_area_md, a.owner_email, a.status, a.created_at
  FROM public.founder_monthly_leadership_self_r2589 a
  ORDER BY a.month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_assessments_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_assessments_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_growth_actions_r2589()
RETURNS TABLE (
  id uuid,
  assessment_id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.assessment_id, a.month_label, g.action_at, g.action_kind, g.outcome,
         g.owner_email, g.status, g.notes
  FROM public.leadership_growth_actions_r2589 g
  LEFT JOIN public.founder_monthly_leadership_self_r2589 a ON a.id = g.assessment_id
  ORDER BY g.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_growth_actions_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_growth_actions_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.monthly_score_trend_r2589()
RETURNS TABLE (
  month_label text,
  clarity_score int,
  delegation_score int,
  velocity_score int,
  empathy_score int,
  focus_score int,
  decision_quality_score int,
  overall_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.month_label, a.clarity_score, a.delegation_score, a.velocity_score,
         a.empathy_score, a.focus_score, a.decision_quality_score, a.overall_score
  FROM public.founder_monthly_leadership_self_r2589 a
  ORDER BY a.month_label ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_score_trend_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_score_trend_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_growth_areas_r2589()
RETURNS TABLE (
  growth_area text,
  mentions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.top_growth_area_md AS growth_area, count(*)::bigint AS mentions
  FROM public.founder_monthly_leadership_self_r2589 a
  WHERE a.top_growth_area_md IS NOT NULL
  GROUP BY a.top_growth_area_md
  ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_growth_areas_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_growth_areas_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.score_distribution_r2589()
RETURNS TABLE (
  dimension text,
  avg_score numeric,
  min_score int,
  max_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'clarity'::text, round(avg(clarity_score)::numeric, 1), min(clarity_score), max(clarity_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'delegation'::text, round(avg(delegation_score)::numeric, 1), min(delegation_score), max(delegation_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'velocity'::text, round(avg(velocity_score)::numeric, 1), min(velocity_score), max(velocity_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'empathy'::text, round(avg(empathy_score)::numeric, 1), min(empathy_score), max(empathy_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'focus'::text, round(avg(focus_score)::numeric, 1), min(focus_score), max(focus_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'decision_quality'::text, round(avg(decision_quality_score)::numeric, 1), min(decision_quality_score), max(decision_quality_score) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'overall'::text, round(avg(overall_score)::numeric, 1), min(overall_score), max(overall_score) FROM public.founder_monthly_leadership_self_r2589
  ORDER BY 1 ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.score_distribution_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.score_distribution_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.action_status_funnel_r2589()
RETURNS TABLE (
  status text,
  count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.status, count(*)::bigint
  FROM public.leadership_growth_actions_r2589 g
  GROUP BY g.status
  ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_status_funnel_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_status_funnel_r2589() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2589()
RETURNS TABLE (
  metric text,
  value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'assessments_total'::text, count(*)::numeric FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'avg_overall'::text, COALESCE(round(avg(overall_score)::numeric, 1), 0) FROM public.founder_monthly_leadership_self_r2589
  UNION ALL
  SELECT 'latest_overall'::text, COALESCE((SELECT overall_score FROM public.founder_monthly_leadership_self_r2589 ORDER BY month_label DESC NULLS LAST LIMIT 1), 0)::numeric
  UNION ALL
  SELECT 'actions_open'::text, count(*)::numeric FROM public.leadership_growth_actions_r2589 WHERE status = 'open'
  UNION ALL
  SELECT 'actions_done'::text, count(*)::numeric FROM public.leadership_growth_actions_r2589 WHERE status = 'done'
  ORDER BY 1 ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2589() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2589() TO authenticated;

