BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_success_stories_r2328 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  story_md text,
  hero_metric text,
  metric_uptime_pct numeric(5,2),
  metric_jobs_completed int,
  metric_cost_savings_rupees bigint,
  is_hero_story boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','review','published','archived')),
  published_at timestamptz,
  used_in_sales_count int NOT NULL DEFAULT 0,
  last_refreshed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_story_refresh_log_r2328 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES public.founder_success_stories_r2328(id) ON DELETE CASCADE,
  refresh_kind text NOT NULL CHECK (refresh_kind IN ('metrics_update','story_edit','quote_added','photo_swap','hero_promote','sales_use')),
  notes text,
  refreshed_by_email text,
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_success_stories_r2328 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_story_refresh_log_r2328 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stories_r2328 ON public.founder_success_stories_r2328;
CREATE POLICY founder_all_stories_r2328 ON public.founder_success_stories_r2328
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_refresh_r2328 ON public.founder_story_refresh_log_r2328;
CREATE POLICY founder_all_refresh_r2328 ON public.founder_story_refresh_log_r2328
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_stories_r2328_status ON public.founder_success_stories_r2328(status);
CREATE INDEX IF NOT EXISTS idx_stories_r2328_hospital ON public.founder_success_stories_r2328(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_stories_r2328_hero ON public.founder_success_stories_r2328(is_hero_story);
CREATE INDEX IF NOT EXISTS idx_story_refresh_r2328_story ON public.founder_story_refresh_log_r2328(story_id);
CREATE INDEX IF NOT EXISTS idx_story_refresh_r2328_kind ON public.founder_story_refresh_log_r2328(refresh_kind);

DROP FUNCTION IF EXISTS public.list_success_stories_r2328();
CREATE OR REPLACE FUNCTION public.list_success_stories_r2328()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  title text,
  hero_metric text,
  metric_uptime_pct numeric,
  metric_jobs_completed int,
  metric_cost_savings_rupees bigint,
  is_hero_story boolean,
  status text,
  published_at timestamptz,
  used_in_sales_count int,
  last_refreshed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, s.title, s.hero_metric,
         s.metric_uptime_pct, s.metric_jobs_completed, s.metric_cost_savings_rupees,
         s.is_hero_story, s.status, s.published_at,
         s.used_in_sales_count, s.last_refreshed_at, s.created_at
  FROM public.founder_success_stories_r2328 s
  ORDER BY s.is_hero_story DESC, s.used_in_sales_count DESC, s.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.draft_success_story_r2328(uuid, text, text, text, numeric, int, bigint);
CREATE OR REPLACE FUNCTION public.draft_success_story_r2328(
  p_hospital_user_id uuid,
  p_title text,
  p_story_md text,
  p_hero_metric text,
  p_metric_uptime_pct numeric,
  p_metric_jobs_completed int,
  p_metric_cost_savings_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_success_stories_r2328(
    hospital_user_id, title, story_md, hero_metric,
    metric_uptime_pct, metric_jobs_completed, metric_cost_savings_rupees,
    status, last_refreshed_at
  ) VALUES (
    p_hospital_user_id, p_title, p_story_md, p_hero_metric,
    p_metric_uptime_pct, p_metric_jobs_completed, p_metric_cost_savings_rupees,
    'draft', now()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_success_story_r2328',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'title', p_title));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.publish_success_story_r2328(uuid);
CREATE OR REPLACE FUNCTION public.publish_success_story_r2328(p_story_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_success_stories_r2328
     SET status = 'published',
         published_at = COALESCE(published_at, now()),
         updated_at = now()
   WHERE id = p_story_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'publish_success_story_r2328',
    jsonb_build_object('id', p_story_id));

  RETURN p_story_id;
END;
$$;

DROP FUNCTION IF EXISTS public.promote_hero_story_r2328(uuid);
CREATE OR REPLACE FUNCTION public.promote_hero_story_r2328(p_story_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_success_stories_r2328 SET is_hero_story = false, updated_at = now() WHERE is_hero_story = true;
  UPDATE public.founder_success_stories_r2328
     SET is_hero_story = true, updated_at = now()
   WHERE id = p_story_id;

  INSERT INTO public.founder_story_refresh_log_r2328(story_id, refresh_kind, notes, refreshed_by_email)
  VALUES (p_story_id, 'hero_promote', 'promoted to hero', (auth.jwt()->>'email'));

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'promote_hero_story_r2328',
    jsonb_build_object('id', p_story_id));

  RETURN p_story_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_story_refresh_r2328(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_story_refresh_r2328(
  p_story_id uuid,
  p_refresh_kind text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_story_refresh_log_r2328(story_id, refresh_kind, notes, refreshed_by_email)
  VALUES (p_story_id, p_refresh_kind, p_notes, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  UPDATE public.founder_success_stories_r2328
     SET last_refreshed_at = now(),
         used_in_sales_count = CASE WHEN p_refresh_kind = 'sales_use' THEN used_in_sales_count + 1 ELSE used_in_sales_count END,
         updated_at = now()
   WHERE id = p_story_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_story_refresh_r2328',
    jsonb_build_object('id', v_id, 'story_id', p_story_id, 'refresh_kind', p_refresh_kind));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_story_refresh_log_r2328(uuid);
CREATE OR REPLACE FUNCTION public.list_story_refresh_log_r2328(p_story_id uuid)
RETURNS TABLE (
  id uuid,
  story_id uuid,
  refresh_kind text,
  notes text,
  refreshed_by_email text,
  refreshed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.story_id, r.refresh_kind, r.notes, r.refreshed_by_email, r.refreshed_at
  FROM public.founder_story_refresh_log_r2328 r
  WHERE r.story_id = p_story_id
  ORDER BY r.refreshed_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.top_sales_stories_r2328();
CREATE OR REPLACE FUNCTION public.top_sales_stories_r2328()
RETURNS TABLE (
  story_id uuid,
  title text,
  status text,
  is_hero_story boolean,
  used_in_sales_count int,
  refresh_count bigint,
  last_refreshed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id AS story_id,
         s.title,
         s.status,
         s.is_hero_story,
         s.used_in_sales_count,
         (COUNT(r.id))::bigint AS refresh_count,
         MAX(r.refreshed_at) AS last_refreshed_at
  FROM public.founder_success_stories_r2328 s
  LEFT JOIN public.founder_story_refresh_log_r2328 r ON r.story_id = s.id
  GROUP BY s.id, s.title, s.status, s.is_hero_story, s.used_in_sales_count
  ORDER BY s.is_hero_story DESC, s.used_in_sales_count DESC, refresh_count DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.story_library_summary_r2328();
CREATE OR REPLACE FUNCTION public.story_library_summary_r2328()
RETURNS TABLE (
  total_stories bigint,
  published_stories bigint,
  draft_stories bigint,
  hero_count bigint,
  total_sales_uses bigint,
  total_refreshes bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.founder_success_stories_r2328)::bigint,
    (SELECT COUNT(*) FROM public.founder_success_stories_r2328 WHERE status = 'published')::bigint,
    (SELECT COUNT(*) FROM public.founder_success_stories_r2328 WHERE status = 'draft')::bigint,
    (SELECT COUNT(*) FROM public.founder_success_stories_r2328 WHERE is_hero_story = true)::bigint,
    (SELECT COALESCE(SUM(used_in_sales_count), 0) FROM public.founder_success_stories_r2328)::bigint,
    (SELECT COUNT(*) FROM public.founder_story_refresh_log_r2328)::bigint;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_success_stories_r2328() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_success_story_r2328(uuid, text, text, text, numeric, int, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_success_story_r2328(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.promote_hero_story_r2328(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_story_refresh_r2328(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_story_refresh_log_r2328(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_sales_stories_r2328() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.story_library_summary_r2328() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_success_stories_r2328() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_success_story_r2328(uuid, text, text, text, numeric, int, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_success_story_r2328(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.promote_hero_story_r2328(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_story_refresh_r2328(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_story_refresh_log_r2328(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_sales_stories_r2328() TO authenticated;
GRANT EXECUTE ON FUNCTION public.story_library_summary_r2328() TO authenticated;

COMMIT;