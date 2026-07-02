BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_spotlights_r1706 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  headline text NOT NULL,
  story_md text,
  metric_summary text,
  photo_url text,
  video_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  published_at timestamptz,
  used_in_deck boolean NOT NULL DEFAULT false,
  used_in_blog boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_spotlight_engagement_log_r1706 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spotlight_id uuid NOT NULL REFERENCES public.founder_customer_spotlights_r1706(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('deck','blog','website','social','email')),
  used_at timestamptz NOT NULL DEFAULT now(),
  audience_count int,
  engagement_count int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_spotlights_r1706 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_spotlight_engagement_log_r1706 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_spotlights_r1706 ON public.founder_customer_spotlights_r1706;
CREATE POLICY founder_all_spotlights_r1706 ON public.founder_customer_spotlights_r1706
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_engagement_r1706 ON public.founder_spotlight_engagement_log_r1706;
CREATE POLICY founder_all_engagement_r1706 ON public.founder_spotlight_engagement_log_r1706
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_spotlights_r1706_status ON public.founder_customer_spotlights_r1706(status);
CREATE INDEX IF NOT EXISTS idx_spotlights_r1706_hospital ON public.founder_customer_spotlights_r1706(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_spotlight_eng_r1706_spotlight ON public.founder_spotlight_engagement_log_r1706(spotlight_id);
CREATE INDEX IF NOT EXISTS idx_spotlight_eng_r1706_channel ON public.founder_spotlight_engagement_log_r1706(channel);

DROP FUNCTION IF EXISTS public.list_spotlights_r1706();
CREATE OR REPLACE FUNCTION public.list_spotlights_r1706()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  headline text,
  story_md text,
  metric_summary text,
  photo_url text,
  video_url text,
  status text,
  published_at timestamptz,
  used_in_deck boolean,
  used_in_blog boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, s.headline, s.story_md, s.metric_summary,
         s.photo_url, s.video_url, s.status, s.published_at,
         s.used_in_deck, s.used_in_blog, s.created_at
  FROM public.founder_customer_spotlights_r1706 s
  ORDER BY s.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.draft_spotlight_r1706(uuid, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.draft_spotlight_r1706(
  p_hospital_user_id uuid,
  p_headline text,
  p_story_md text,
  p_metric_summary text,
  p_photo_url text,
  p_video_url text
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
  INSERT INTO public.founder_customer_spotlights_r1706(
    hospital_user_id, headline, story_md, metric_summary, photo_url, video_url, status
  ) VALUES (
    p_hospital_user_id, p_headline, p_story_md, p_metric_summary, p_photo_url, p_video_url, 'draft'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_spotlight_r1706',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'headline', p_headline));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.publish_spotlight_r1706(uuid);
CREATE OR REPLACE FUNCTION public.publish_spotlight_r1706(p_spotlight_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_customer_spotlights_r1706
     SET status = 'published',
         published_at = COALESCE(published_at, now()),
         updated_at = now()
   WHERE id = p_spotlight_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'publish_spotlight_r1706',
    jsonb_build_object('id', p_spotlight_id));

  RETURN p_spotlight_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_engagement_r1706(uuid);
CREATE OR REPLACE FUNCTION public.list_engagement_r1706(p_spotlight_id uuid)
RETURNS TABLE (
  id uuid,
  spotlight_id uuid,
  channel text,
  used_at timestamptz,
  audience_count int,
  engagement_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.spotlight_id, e.channel, e.used_at, e.audience_count, e.engagement_count
  FROM public.founder_spotlight_engagement_log_r1706 e
  WHERE e.spotlight_id = p_spotlight_id
  ORDER BY e.used_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_engagement_r1706(uuid, text, int, int);
CREATE OR REPLACE FUNCTION public.log_engagement_r1706(
  p_spotlight_id uuid,
  p_channel text,
  p_audience_count int,
  p_engagement_count int
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
  INSERT INTO public.founder_spotlight_engagement_log_r1706(
    spotlight_id, channel, audience_count, engagement_count
  ) VALUES (
    p_spotlight_id, p_channel, p_audience_count, p_engagement_count
  )
  RETURNING id INTO v_id;

  IF p_channel = 'deck' THEN
    UPDATE public.founder_customer_spotlights_r1706
       SET used_in_deck = true, updated_at = now()
     WHERE id = p_spotlight_id;
  ELSIF p_channel = 'blog' THEN
    UPDATE public.founder_customer_spotlights_r1706
       SET used_in_blog = true, updated_at = now()
     WHERE id = p_spotlight_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engagement_r1706',
    jsonb_build_object('id', v_id, 'spotlight_id', p_spotlight_id, 'channel', p_channel));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.top_used_spotlights_r1706();
CREATE OR REPLACE FUNCTION public.top_used_spotlights_r1706()
RETURNS TABLE (
  spotlight_id uuid,
  headline text,
  status text,
  usage_count int,
  total_audience bigint,
  total_engagement bigint,
  last_used_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id AS spotlight_id,
         s.headline,
         s.status,
         (COUNT(e.id))::int AS usage_count,
         COALESCE(SUM(e.audience_count), 0)::bigint AS total_audience,
         COALESCE(SUM(e.engagement_count), 0)::bigint AS total_engagement,
         MAX(e.used_at) AS last_used_at
  FROM public.founder_customer_spotlights_r1706 s
  LEFT JOIN public.founder_spotlight_engagement_log_r1706 e ON e.spotlight_id = s.id
  GROUP BY s.id, s.headline, s.status
  ORDER BY usage_count DESC, total_engagement DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.hospital_spotlight_lookup_r1706(uuid);
CREATE OR REPLACE FUNCTION public.hospital_spotlight_lookup_r1706(p_hospital_user_id uuid)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  headline text,
  status text,
  published_at timestamptz,
  used_in_deck boolean,
  used_in_blog boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, s.headline, s.status, s.published_at,
         s.used_in_deck, s.used_in_blog, s.created_at
  FROM public.founder_customer_spotlights_r1706 s
  WHERE s.hospital_user_id = p_hospital_user_id
  ORDER BY s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_spotlights_r1706() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_spotlight_r1706(uuid, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_spotlight_r1706(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_engagement_r1706(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1706(uuid, text, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_used_spotlights_r1706() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hospital_spotlight_lookup_r1706(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_spotlights_r1706() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_spotlight_r1706(uuid, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_spotlight_r1706(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_engagement_r1706(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1706(uuid, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_used_spotlights_r1706() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hospital_spotlight_lookup_r1706(uuid) TO authenticated;

COMMIT;