-- Round 2530: Engineer Quarterly 360 Review
-- Tables: engineer_360_reviews_r2530, review_360_action_items_r2530
-- Engineer × peers × hospital × self × manager scores × composite × growth track × actionable feedback

CREATE TABLE IF NOT EXISTS public.engineer_360_reviews_r2530 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  peer_score numeric,
  hospital_score numeric,
  self_score numeric,
  manager_score numeric,
  composite_score numeric,
  growth_track text NOT NULL DEFAULT 'senior'
    CHECK (growth_track IN ('senior','team_lead','specialist','manager','founder_track')),
  actionable_feedback_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','in_review','final','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.review_360_action_items_r2530 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES public.engineer_360_reviews_r2530(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_360_reviews_r2530 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_360_action_items_r2530 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_360_reviews_r2530;
CREATE POLICY founder_all ON public.engineer_360_reviews_r2530
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.review_360_action_items_r2530;
CREATE POLICY founder_all ON public.review_360_action_items_r2530
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed: 4 reviews
INSERT INTO public.engineer_360_reviews_r2530
  (quarter_label, peer_score, hospital_score, self_score, manager_score, composite_score, growth_track, actionable_feedback_md, owner_email, status, notes)
VALUES
  ('Q1-2026', 4.6, 4.7, 4.2, 4.5, 4.55, 'team_lead', '## Strengths\n- Strong hospital rapport\n- Mentors juniors well\n## Growth\n- Tighten documentation discipline', 'people@equipseva.in', 'final', 'Promotion candidate'),
  ('Q1-2026', 4.1, 4.3, 4.4, 4.0, 4.18, 'senior', '## Strengths\n- Reliable on repairs\n## Growth\n- Improve escalation timing', 'people@equipseva.in', 'in_review', NULL),
  ('Q1-2026', 4.8, 4.9, 4.5, 4.8, 4.78, 'specialist', '## Strengths\n- CT/MRI specialty depth\n## Growth\n- Take on training role', 'people@equipseva.in', 'final', 'Subject-matter expert track'),
  ('Q1-2026', 3.8, 3.9, 4.2, 3.7, 3.85, 'senior', '## Growth\n- Punctuality + parts inventory hygiene', 'people@equipseva.in', 'draft', 'Needs PIP if Q2 flat');

-- Seed action items linked to first 3 reviews
INSERT INTO public.review_360_action_items_r2530 (review_id, action_text, owner_email, due_at, status, priority, notes)
SELECT id, 'Shadow founder on 2 hospital chain pitches', 'people@equipseva.in', now() + interval '30 days', 'in_progress', 'high', NULL
FROM public.engineer_360_reviews_r2530 WHERE quarter_label = 'Q1-2026' AND growth_track = 'team_lead' LIMIT 1;

INSERT INTO public.review_360_action_items_r2530 (review_id, action_text, owner_email, due_at, status, priority, notes)
SELECT id, 'Run weekly internal CT troubleshooting workshop', 'people@equipseva.in', now() + interval '14 days', 'open', 'medium', NULL
FROM public.engineer_360_reviews_r2530 WHERE quarter_label = 'Q1-2026' AND growth_track = 'specialist' LIMIT 1;

INSERT INTO public.review_360_action_items_r2530 (review_id, action_text, owner_email, due_at, status, priority, notes)
SELECT id, 'Close 5 long-pending repair tickets within 7 days', 'people@equipseva.in', now() + interval '7 days', 'open', 'urgent', NULL
FROM public.engineer_360_reviews_r2530 WHERE quarter_label = 'Q1-2026' AND status = 'draft' LIMIT 1;

INSERT INTO public.review_360_action_items_r2530 (review_id, action_text, owner_email, due_at, status, priority, notes)
SELECT id, 'Submit weekly hospital escalation log', 'people@equipseva.in', now() + interval '21 days', 'done', 'low', 'Completed early'
FROM public.engineer_360_reviews_r2530 WHERE quarter_label = 'Q1-2026' AND growth_track = 'senior' AND status = 'in_review' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_reviews_r2530()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  growth_track text,
  composite_score numeric,
  peer_score numeric,
  hospital_score numeric,
  self_score numeric,
  manager_score numeric,
  status text,
  owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.quarter_label, r.growth_track, r.composite_score,
         r.peer_score, r.hospital_score, r.self_score, r.manager_score,
         r.status, r.owner_email, r.created_at
  FROM public.engineer_360_reviews_r2530 r
  ORDER BY r.composite_score DESC NULLS LAST, r.created_at DESC
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_action_items_r2530()
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_text text,
  priority text,
  status text,
  owner_email text,
  due_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, a.action_text, a.priority, a.status,
         a.owner_email, a.due_at, a.closed_at, a.created_at
  FROM public.review_360_action_items_r2530 a
  ORDER BY
    CASE a.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    a.due_at NULLS LAST
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_action_items_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_items_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_composite_engineers_r2530()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  growth_track text,
  composite_score numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.quarter_label, r.growth_track, r.composite_score, r.status
  FROM public.engineer_360_reviews_r2530 r
  WHERE r.composite_score IS NOT NULL
  ORDER BY r.composite_score DESC
  LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_composite_engineers_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_composite_engineers_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.growth_track_distribution_r2530()
RETURNS TABLE (
  growth_track text,
  review_count bigint,
  avg_composite numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.growth_track,
         count(*)::bigint AS review_count,
         round(avg(r.composite_score)::numeric, 2) AS avg_composite
  FROM public.engineer_360_reviews_r2530 r
  GROUP BY r.growth_track
  ORDER BY review_count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.growth_track_distribution_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.growth_track_distribution_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_completion_rate_r2530()
RETURNS TABLE (
  total_actions bigint,
  done_actions bigint,
  open_actions bigint,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint AS total_actions,
         count(*) FILTER (WHERE status = 'done')::bigint AS done_actions,
         count(*) FILTER (WHERE status IN ('open','in_progress'))::bigint AS open_actions,
         CASE WHEN count(*) = 0 THEN 0
              ELSE round(100.0 * count(*) FILTER (WHERE status = 'done') / count(*), 1)
         END AS completion_pct
  FROM public.review_360_action_items_r2530;
END;$$;
REVOKE EXECUTE ON FUNCTION public.action_completion_rate_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_completion_rate_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_score_trend_r2530()
RETURNS TABLE (
  quarter_label text,
  review_count bigint,
  avg_composite numeric,
  avg_peer numeric,
  avg_hospital numeric,
  avg_self numeric,
  avg_manager numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.quarter_label,
         count(*)::bigint AS review_count,
         round(avg(r.composite_score)::numeric, 2) AS avg_composite,
         round(avg(r.peer_score)::numeric, 2) AS avg_peer,
         round(avg(r.hospital_score)::numeric, 2) AS avg_hospital,
         round(avg(r.self_score)::numeric, 2) AS avg_self,
         round(avg(r.manager_score)::numeric, 2) AS avg_manager
  FROM public.engineer_360_reviews_r2530 r
  GROUP BY r.quarter_label
  ORDER BY r.quarter_label DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_score_trend_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_score_trend_r2530() TO authenticated;

CREATE OR REPLACE FUNCTION public.manager_load_r2530()
RETURNS TABLE (
  owner_email text,
  review_count bigint,
  open_actions bigint,
  avg_composite numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.owner_email,
         count(DISTINCT r.id)::bigint AS review_count,
         count(a.id) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_actions,
         round(avg(r.composite_score)::numeric, 2) AS avg_composite
  FROM public.engineer_360_reviews_r2530 r
  LEFT JOIN public.review_360_action_items_r2530 a ON a.review_id = r.id
  WHERE r.owner_email IS NOT NULL
  GROUP BY r.owner_email
  ORDER BY review_count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.manager_load_r2530() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manager_load_r2530() TO authenticated;
