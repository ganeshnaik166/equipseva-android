-- Round 2553: founder-quarterly-content-publishing-cadence
-- Quarter x LinkedIn x blog x podcast x press x planned vs actual x reach

CREATE TABLE IF NOT EXISTS public.founder_quarterly_content_plans_r2553 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  quarter_label text NOT NULL,
  linkedin_planned int NOT NULL DEFAULT 0,
  linkedin_actual int NOT NULL DEFAULT 0,
  blog_planned int NOT NULL DEFAULT 0,
  blog_actual int NOT NULL DEFAULT 0,
  podcast_planned int NOT NULL DEFAULT 0,
  podcast_actual int NOT NULL DEFAULT 0,
  press_planned int NOT NULL DEFAULT 0,
  press_actual int NOT NULL DEFAULT 0,
  total_reach int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','closed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.content_publishing_log_r2553 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  plan_id uuid NOT NULL REFERENCES public.founder_quarterly_content_plans_r2553(id) ON DELETE CASCADE,
  published_at timestamptz NOT NULL DEFAULT now(),
  channel_kind text NOT NULL CHECK (channel_kind IN ('linkedin','blog','podcast','press','event','youtube')),
  title text NOT NULL,
  reach int NOT NULL DEFAULT 0,
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  top_takeaway text,
  notes text
);

ALTER TABLE public.founder_quarterly_content_plans_r2553 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_publishing_log_r2553 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quarterly_content_plans_r2553;
CREATE POLICY founder_all ON public.founder_quarterly_content_plans_r2553
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.content_publishing_log_r2553;
CREATE POLICY founder_all ON public.content_publishing_log_r2553
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed plans
INSERT INTO public.founder_quarterly_content_plans_r2553
  (quarter_label, linkedin_planned, linkedin_actual, blog_planned, blog_actual, podcast_planned, podcast_actual, press_planned, press_actual, total_reach, owner_email, status, notes)
VALUES
  ('Q1-2026', 24, 22, 6, 5, 4, 3, 2, 2, 145000, 'ganesh@equipseva.in', 'closed', 'Strong LinkedIn cadence, podcast under-delivered'),
  ('Q2-2026', 30, 18, 8, 4, 4, 2, 3, 1, 92000, 'ganesh@equipseva.in', 'in_progress', 'Behind on blog and press; founder bandwidth crunch'),
  ('Q3-2026', 30, 0, 8, 0, 4, 0, 3, 0, 0, 'ganesh@equipseva.in', 'planned', 'Series-A narrative quarter'),
  ('Q4-2026', 36, 0, 10, 0, 6, 0, 4, 0, 0, 'ganesh@equipseva.in', 'planned', 'Year-end review + investor day push');

-- Seed publishing log
INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-02-14 10:00:00'::timestamptz, 'linkedin', 'Why repair-uptime is the new ICU KPI', 18500, 78, 'Hospital CFOs care more about uptime than CAPEX', 'Top post Q1' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q1-2026';

INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-03-04 12:00:00'::timestamptz, 'blog', 'Counterfeit parts in Tier-2 India: a field report', 9200, 64, 'CDSCO rep letter unlocks hospital trust', 'Drove 12 inbound demos' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q1-2026';

INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-03-20 09:00:00'::timestamptz, 'podcast', 'Repair-as-a-Service with Dr. Mehta', 6400, 71, 'Class-A hospitals will pay AMC premium for SLAs', 'Cross-posted to YouTube' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q1-2026';

INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-05-09 11:00:00'::timestamptz, 'press', 'YourStory feature: EquipSeva crosses 1000 hospitals', 14200, 58, 'Press boosts hospital-chain RFP response rate', 'Inbound from 2 chain CXOs' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q2-2026';

INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-06-02 14:00:00'::timestamptz, 'linkedin', 'Engineer Tier ladder explained', 11200, 82, 'Tier framework resonates with HRs', 'Recruiter inbound spike' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q2-2026';

INSERT INTO public.content_publishing_log_r2553
  (plan_id, published_at, channel_kind, title, reach, engagement_score, top_takeaway, notes)
SELECT id, '2026-06-15 16:00:00'::timestamptz, 'event', 'Healthcare CIO Summit Hyderabad keynote', 3400, 88, 'Live demo beats slides for hospital buyers', '4 RFPs from attendees' FROM public.founder_quarterly_content_plans_r2553 WHERE quarter_label='Q2-2026';

-- RPC 1: list_plans_r2553
CREATE OR REPLACE FUNCTION public.list_plans_r2553()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  linkedin_planned int,
  linkedin_actual int,
  blog_planned int,
  blog_actual int,
  podcast_planned int,
  podcast_actual int,
  press_planned int,
  press_actual int,
  total_reach int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.quarter_label, p.linkedin_planned, p.linkedin_actual,
         p.blog_planned, p.blog_actual, p.podcast_planned, p.podcast_actual,
         p.press_planned, p.press_actual, p.total_reach, p.owner_email,
         p.status, p.notes, p.created_at
  FROM public.founder_quarterly_content_plans_r2553 p
  ORDER BY p.quarter_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_plans_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_plans_r2553() TO authenticated;

-- RPC 2: list_publishing_log_r2553
CREATE OR REPLACE FUNCTION public.list_publishing_log_r2553()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  published_at timestamptz,
  channel_kind text,
  title text,
  reach int,
  engagement_score int,
  top_takeaway text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, p.quarter_label, l.published_at, l.channel_kind, l.title,
         l.reach, l.engagement_score, l.top_takeaway, l.notes
  FROM public.content_publishing_log_r2553 l
  JOIN public.founder_quarterly_content_plans_r2553 p ON p.id = l.plan_id
  ORDER BY l.published_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_publishing_log_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_publishing_log_r2553() TO authenticated;

-- RPC 3: top_reach_posts_r2553
CREATE OR REPLACE FUNCTION public.top_reach_posts_r2553()
RETURNS TABLE (
  title text,
  channel_kind text,
  quarter_label text,
  reach int,
  engagement_score int,
  published_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.title, l.channel_kind, p.quarter_label, l.reach, l.engagement_score, l.published_at
  FROM public.content_publishing_log_r2553 l
  JOIN public.founder_quarterly_content_plans_r2553 p ON p.id = l.plan_id
  ORDER BY l.reach DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reach_posts_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reach_posts_r2553() TO authenticated;

-- RPC 4: channel_breakdown_r2553
CREATE OR REPLACE FUNCTION public.channel_breakdown_r2553()
RETURNS TABLE (
  channel_kind text,
  post_count bigint,
  total_reach bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.channel_kind,
         COUNT(*)::bigint AS post_count,
         COALESCE(SUM(l.reach),0)::bigint AS total_reach,
         ROUND(AVG(l.engagement_score)::numeric, 1) AS avg_engagement
  FROM public.content_publishing_log_r2553 l
  GROUP BY l.channel_kind
  ORDER BY total_reach DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.channel_breakdown_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_breakdown_r2553() TO authenticated;

-- RPC 5: quarterly_actual_vs_planned_r2553
CREATE OR REPLACE FUNCTION public.quarterly_actual_vs_planned_r2553()
RETURNS TABLE (
  quarter_label text,
  channel_kind text,
  planned int,
  actual int,
  delta int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.quarter_label, 'linkedin'::text, p.linkedin_planned, p.linkedin_actual, (p.linkedin_actual - p.linkedin_planned)
    FROM public.founder_quarterly_content_plans_r2553 p
  UNION ALL
  SELECT p.quarter_label, 'blog'::text, p.blog_planned, p.blog_actual, (p.blog_actual - p.blog_planned)
    FROM public.founder_quarterly_content_plans_r2553 p
  UNION ALL
  SELECT p.quarter_label, 'podcast'::text, p.podcast_planned, p.podcast_actual, (p.podcast_actual - p.podcast_planned)
    FROM public.founder_quarterly_content_plans_r2553 p
  UNION ALL
  SELECT p.quarter_label, 'press'::text, p.press_planned, p.press_actual, (p.press_actual - p.press_planned)
    FROM public.founder_quarterly_content_plans_r2553 p
  ORDER BY 1 DESC NULLS LAST, 2 ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_actual_vs_planned_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_actual_vs_planned_r2553() TO authenticated;

-- RPC 6: monthly_publish_trend_r2553
CREATE OR REPLACE FUNCTION public.monthly_publish_trend_r2553()
RETURNS TABLE (
  month_label text,
  post_count bigint,
  total_reach bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.published_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS post_count,
         COALESCE(SUM(l.reach),0)::bigint AS total_reach,
         ROUND(AVG(l.engagement_score)::numeric, 1) AS avg_engagement
  FROM public.content_publishing_log_r2553 l
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_publish_trend_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_publish_trend_r2553() TO authenticated;

-- RPC 7: owner_load_r2553
CREATE OR REPLACE FUNCTION public.owner_load_r2553()
RETURNS TABLE (
  owner_email text,
  plan_count bigint,
  linkedin_actual_total bigint,
  blog_actual_total bigint,
  podcast_actual_total bigint,
  press_actual_total bigint,
  reach_total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint AS plan_count,
         COALESCE(SUM(p.linkedin_actual),0)::bigint AS linkedin_actual_total,
         COALESCE(SUM(p.blog_actual),0)::bigint AS blog_actual_total,
         COALESCE(SUM(p.podcast_actual),0)::bigint AS podcast_actual_total,
         COALESCE(SUM(p.press_actual),0)::bigint AS press_actual_total,
         COALESCE(SUM(p.total_reach),0)::bigint AS reach_total
  FROM public.founder_quarterly_content_plans_r2553 p
  GROUP BY 1
  ORDER BY reach_total DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2553() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2553() TO authenticated;
