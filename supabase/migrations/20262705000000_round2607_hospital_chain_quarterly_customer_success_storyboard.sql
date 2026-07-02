-- Round 2607: Hospital Chain Quarterly Customer Success Storyboard
-- Tables: chain_customer_success_stories_r2607, success_story_distribution_log_r2607
-- 7 RPCs founder-gated

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_customer_success_stories_r2607 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  story_title text NOT NULL,
  outcome_md text,
  proof_md text,
  shareability_kind text NOT NULL CHECK (shareability_kind IN ('public','case_study','conference','sales_deck','internal_only')),
  distribution_channels_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','approved','published','archived')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.success_story_distribution_log_r2607 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  story_id uuid NOT NULL REFERENCES public.chain_customer_success_stories_r2607(id) ON DELETE CASCADE,
  distributed_at timestamptz NOT NULL DEFAULT now(),
  channel_kind text NOT NULL CHECK (channel_kind IN ('linkedin','conference','blog','press','email_campaign','podcast')),
  reach int NOT NULL DEFAULT 0,
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text
);

ALTER TABLE public.chain_customer_success_stories_r2607 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.success_story_distribution_log_r2607 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_customer_success_stories_r2607;
CREATE POLICY founder_all ON public.chain_customer_success_stories_r2607
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.success_story_distribution_log_r2607;
CREATE POLICY founder_all ON public.success_story_distribution_log_r2607
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_customer_success_stories_r2607 (chain_name, quarter_label, story_title, outcome_md, proof_md, shareability_kind, distribution_channels_md, owner_email, status, notes)
VALUES
  ('Apollo Multispeciality', 'Q1-2026', 'Zero downtime on CT scanner for 90 days', 'Uptime jumped from 87 pct to 99.4 pct across 4 sites', 'Internal dashboard screenshots plus signed letter from biomed head', 'case_study', 'LinkedIn carousel plus sales deck slide 12', 'success@example.com', 'published', 'Hero story for board pack'),
  ('Yashoda Group', 'Q1-2026', 'AMC saved 14 lakh in repair costs', 'Switched 6 hospitals to Tier-2 AMC and avoided 9 emergency calls', 'Cashfree payout ledger plus invoice comparison', 'sales_deck', 'Quarterly review deck plus blog post', 'success@example.com', 'approved', 'Pending hospital legal review for proof PDF'),
  ('KIMS Sunshine', 'Q4-2025', 'Engineer rotation cut response time by 38 pct', 'Average response dropped from 11 hours to 6.8 hours', 'Repair-job analytics export', 'conference', 'Medtech India 2026 plenary slot', 'cse@example.com', 'in_review', 'Conference abstract drafted'),
  ('Manipal Hospitals', 'Q4-2025', 'NABH audit cleared first attempt', 'Bonded-parts provenance proved during NABH ZIP', 'NABH audit letter plus our generated ZIP manifest', 'public', 'Press release plus founder LinkedIn', 'founder@example.com', 'draft', 'Working with PR agency on copy'),
  ('Care Hospitals', 'Q3-2025', 'Dental vertical pilot reached 12 sites in 60 days', 'Onboarded 12 dental clinics under chain umbrella deal', 'Onboarding tracker plus signed master MSA', 'internal_only', 'Internal Slack only', 'sales@example.com', 'archived', 'Insights folded into v0.5 chain bulk module');

INSERT INTO public.success_story_distribution_log_r2607 (story_id, distributed_at, channel_kind, reach, engagement_score, owner_email, status, notes)
SELECT id, '2026-03-15T10:00:00Z'::timestamptz, 'linkedin', 8400, 72, 'founder@example.com', 'done', 'Carousel went viral in biomed circle'
FROM public.chain_customer_success_stories_r2607 WHERE story_title LIKE 'Zero downtime%' LIMIT 1;

INSERT INTO public.success_story_distribution_log_r2607 (story_id, distributed_at, channel_kind, reach, engagement_score, owner_email, status, notes)
SELECT id, '2026-04-02T09:00:00Z'::timestamptz, 'email_campaign', 1200, 55, 'sales@example.com', 'done', 'Sent to 1200 hospital procurement contacts'
FROM public.chain_customer_success_stories_r2607 WHERE story_title LIKE 'AMC saved%' LIMIT 1;

INSERT INTO public.success_story_distribution_log_r2607 (story_id, distributed_at, channel_kind, reach, engagement_score, owner_email, status, notes)
SELECT id, '2026-05-10T14:30:00Z'::timestamptz, 'conference', 350, 88, 'cse@example.com', 'planned', 'Plenary slot confirmed Medtech India'
FROM public.chain_customer_success_stories_r2607 WHERE story_title LIKE 'Engineer rotation%' LIMIT 1;

INSERT INTO public.success_story_distribution_log_r2607 (story_id, distributed_at, channel_kind, reach, engagement_score, owner_email, status, notes)
SELECT id, '2026-06-01T08:00:00Z'::timestamptz, 'press', 22000, 64, 'founder@example.com', 'planned', 'Press release drafted with PR agency'
FROM public.chain_customer_success_stories_r2607 WHERE story_title LIKE 'NABH audit%' LIMIT 1;

INSERT INTO public.success_story_distribution_log_r2607 (story_id, distributed_at, channel_kind, reach, engagement_score, owner_email, status, notes)
SELECT id, '2026-02-20T11:00:00Z'::timestamptz, 'podcast', 5600, 41, 'success@example.com', 'cancelled', 'Podcast host pulled out last minute'
FROM public.chain_customer_success_stories_r2607 WHERE story_title LIKE 'AMC saved%' LIMIT 1;

-- RPC 1: list stories
CREATE OR REPLACE FUNCTION public.list_stories_r2607()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  chain_name text,
  quarter_label text,
  story_title text,
  shareability_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.created_at, s.chain_name, s.quarter_label, s.story_title,
         s.shareability_kind, s.owner_email, s.status, s.notes
  FROM public.chain_customer_success_stories_r2607 s
  ORDER BY s.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_stories_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stories_r2607() TO authenticated;

-- RPC 2: list distribution log
CREATE OR REPLACE FUNCTION public.list_distribution_log_r2607()
RETURNS TABLE (
  id uuid,
  story_id uuid,
  story_title text,
  distributed_at timestamptz,
  channel_kind text,
  reach int,
  engagement_score int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.story_id, s.story_title, d.distributed_at, d.channel_kind,
         d.reach, d.engagement_score, d.owner_email, d.status, d.notes
  FROM public.success_story_distribution_log_r2607 d
  LEFT JOIN public.chain_customer_success_stories_r2607 s ON s.id = d.story_id
  ORDER BY d.distributed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_distribution_log_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_distribution_log_r2607() TO authenticated;

-- RPC 3: top reach stories
CREATE OR REPLACE FUNCTION public.top_reach_stories_r2607()
RETURNS TABLE (
  story_id uuid,
  story_title text,
  chain_name text,
  total_reach bigint,
  avg_engagement numeric,
  distribution_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.story_title, s.chain_name,
         COALESCE(SUM(d.reach), 0)::bigint,
         COALESCE(ROUND(AVG(d.engagement_score)::numeric, 1), 0),
         COUNT(d.id)::bigint
  FROM public.chain_customer_success_stories_r2607 s
  LEFT JOIN public.success_story_distribution_log_r2607 d ON d.story_id = s.id
  GROUP BY s.id, s.story_title, s.chain_name
  ORDER BY COALESCE(SUM(d.reach), 0) DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reach_stories_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reach_stories_r2607() TO authenticated;

-- RPC 4: shareability distribution
CREATE OR REPLACE FUNCTION public.shareability_distribution_r2607()
RETURNS TABLE (
  shareability_kind text,
  story_count bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.chain_customer_success_stories_r2607;
  RETURN QUERY
  SELECT s.shareability_kind, COUNT(*)::bigint,
         CASE WHEN total > 0 THEN ROUND((COUNT(*)::numeric / total) * 100, 1) ELSE 0 END
  FROM public.chain_customer_success_stories_r2607 s
  GROUP BY s.shareability_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.shareability_distribution_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shareability_distribution_r2607() TO authenticated;

-- RPC 5: channel kind breakdown
CREATE OR REPLACE FUNCTION public.channel_kind_breakdown_r2607()
RETURNS TABLE (
  channel_kind text,
  log_count bigint,
  total_reach bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.channel_kind, COUNT(*)::bigint,
         COALESCE(SUM(d.reach), 0)::bigint,
         COALESCE(ROUND(AVG(d.engagement_score)::numeric, 1), 0)
  FROM public.success_story_distribution_log_r2607 d
  GROUP BY d.channel_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.channel_kind_breakdown_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_kind_breakdown_r2607() TO authenticated;

-- RPC 6: quarterly story trend
CREATE OR REPLACE FUNCTION public.quarterly_story_trend_r2607()
RETURNS TABLE (
  quarter_label text,
  story_count bigint,
  published_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label, COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE s.status = 'published')::bigint
  FROM public.chain_customer_success_stories_r2607 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_story_trend_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_story_trend_r2607() TO authenticated;

-- RPC 7: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2607()
RETURNS TABLE (
  status text,
  story_count bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.chain_customer_success_stories_r2607;
  RETURN QUERY
  SELECT s.status, COUNT(*)::bigint,
         CASE WHEN total > 0 THEN ROUND((COUNT(*)::numeric / total) * 100, 1) ELSE 0 END
  FROM public.chain_customer_success_stories_r2607 s
  GROUP BY s.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2607() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2607() TO authenticated;

