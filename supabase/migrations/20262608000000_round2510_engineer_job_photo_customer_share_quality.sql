-- Round 2510: engineer-job-photo-customer-share-quality
-- Photos shared with customer x channel x view count x feedback x privacy

CREATE TABLE IF NOT EXISTS public.engineer_photo_shares_r2510 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  shared_at timestamptz NOT NULL DEFAULT now(),
  share_channel text NOT NULL CHECK (share_channel IN ('whatsapp','email','in_app','portal','sms')),
  photo_count int NOT NULL DEFAULT 0 CHECK (photo_count >= 0),
  view_count int NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  customer_feedback text NOT NULL DEFAULT 'no_response' CHECK (customer_feedback IN ('positive','neutral','negative','no_response')),
  privacy_signoff_ok boolean NOT NULL DEFAULT false,
  customer_quote_text text,
  owner_email text,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','viewed','replied','no_response')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.photo_share_engagement_log_r2510 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id uuid NOT NULL REFERENCES public.engineer_photo_shares_r2510(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  viewer_email text,
  action_taken text NOT NULL DEFAULT 'none' CHECK (action_taken IN ('none','saved','forwarded','replied','booked_visit')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_photo_shares_r2510 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_share_engagement_log_r2510 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_photo_shares_r2510;
CREATE POLICY founder_all ON public.engineer_photo_shares_r2510
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.photo_share_engagement_log_r2510;
CREATE POLICY founder_all ON public.photo_share_engagement_log_r2510
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.engineer_photo_shares_r2510 (id, engineer_user_id, hospital_user_id, shared_at, share_channel, photo_count, view_count, customer_feedback, privacy_signoff_ok, customer_quote_text, owner_email, status, notes)
VALUES
  ('22222222-2222-2222-2222-222222222201', NULL, NULL, now() - interval '2 days', 'whatsapp', 8, 12, 'positive', true, 'Photos very clear, helped board approve', 'apollo-bio@apollohospitals.com', 'replied', 'High engagement'),
  ('22222222-2222-2222-2222-222222222202', NULL, NULL, now() - interval '5 days', 'email', 12, 4, 'neutral', true, 'Acknowledged receipt', 'kims-bio@kims.in', 'viewed', 'Lower view count'),
  ('22222222-2222-2222-2222-222222222203', NULL, NULL, now() - interval '7 days', 'in_app', 6, 9, 'positive', true, 'Loved the before/after format', 'yashoda-bio@yashoda.com', 'replied', 'Customer asked for similar follow-up'),
  ('22222222-2222-2222-2222-222222222204', NULL, NULL, now() - interval '10 days', 'portal', 4, 2, 'no_response', false, NULL, 'fortis-bio@fortis.in', 'sent', 'Privacy signoff missing - blocked future shares'),
  ('22222222-2222-2222-2222-222222222205', NULL, NULL, now() - interval '14 days', 'sms', 3, 1, 'negative', true, 'Resolution too low, hard to see', 'rainbow-bio@rainbow.in', 'no_response', 'Need to upgrade photo quality')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.photo_share_engagement_log_r2510 (share_id, viewed_at, viewer_email, action_taken, notes)
VALUES
  ('22222222-2222-2222-2222-222222222201', now() - interval '2 days', 'apollo-bio@apollohospitals.com', 'forwarded', 'Forwarded to board'),
  ('22222222-2222-2222-2222-222222222201', now() - interval '1 day', 'apollo-ceo@apollohospitals.com', 'replied', 'CEO acknowledged'),
  ('22222222-2222-2222-2222-222222222202', now() - interval '4 days', 'kims-bio@kims.in', 'saved', 'Saved for records'),
  ('22222222-2222-2222-2222-222222222203', now() - interval '6 days', 'yashoda-bio@yashoda.com', 'booked_visit', 'Booked PM visit'),
  ('22222222-2222-2222-2222-222222222204', now() - interval '9 days', 'fortis-bio@fortis.in', 'none', 'Opened, no action'),
  ('22222222-2222-2222-2222-222222222205', now() - interval '13 days', 'rainbow-bio@rainbow.in', 'none', 'Single view, no action');

-- RPC 1: list_shares_r2510
CREATE OR REPLACE FUNCTION public.list_shares_r2510()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  shared_at timestamptz,
  share_channel text,
  photo_count int,
  view_count int,
  customer_feedback text,
  privacy_signoff_ok boolean,
  customer_quote_text text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, s.hospital_user_id, s.shared_at, s.share_channel,
         s.photo_count, s.view_count, s.customer_feedback, s.privacy_signoff_ok,
         s.customer_quote_text, s.owner_email, s.status, s.notes
  FROM public.engineer_photo_shares_r2510 s
  ORDER BY s.shared_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_shares_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_shares_r2510() TO authenticated;

-- RPC 2: list_engagement_log_r2510
CREATE OR REPLACE FUNCTION public.list_engagement_log_r2510()
RETURNS TABLE (
  id uuid,
  share_id uuid,
  viewed_at timestamptz,
  viewer_email text,
  action_taken text,
  share_channel text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.share_id, l.viewed_at, l.viewer_email, l.action_taken,
         s.share_channel, s.owner_email, l.notes
  FROM public.photo_share_engagement_log_r2510 l
  JOIN public.engineer_photo_shares_r2510 s ON s.id = l.share_id
  ORDER BY l.viewed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_engagement_log_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagement_log_r2510() TO authenticated;

-- RPC 3: top_engaged_hospitals_r2510
CREATE OR REPLACE FUNCTION public.top_engaged_hospitals_r2510()
RETURNS TABLE (
  owner_email text,
  shares_count bigint,
  total_views bigint,
  total_actions bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.owner_email,
         COUNT(DISTINCT s.id)::bigint AS shares_count,
         COALESCE(SUM(s.view_count), 0)::bigint AS total_views,
         COUNT(l.id) FILTER (WHERE l.action_taken <> 'none')::bigint AS total_actions,
         COUNT(*) FILTER (WHERE s.customer_feedback = 'positive')::bigint AS positive_count
  FROM public.engineer_photo_shares_r2510 s
  LEFT JOIN public.photo_share_engagement_log_r2510 l ON l.share_id = s.id
  WHERE s.owner_email IS NOT NULL
  GROUP BY s.owner_email
  ORDER BY total_views DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_engaged_hospitals_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engaged_hospitals_r2510() TO authenticated;

-- RPC 4: channel_breakdown_r2510
CREATE OR REPLACE FUNCTION public.channel_breakdown_r2510()
RETURNS TABLE (
  share_channel text,
  shares_count bigint,
  total_photos bigint,
  total_views bigint,
  avg_views_per_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.share_channel,
         COUNT(*)::bigint AS shares_count,
         COALESCE(SUM(s.photo_count), 0)::bigint AS total_photos,
         COALESCE(SUM(s.view_count), 0)::bigint AS total_views,
         ROUND(AVG(s.view_count)::numeric, 1) AS avg_views_per_share
  FROM public.engineer_photo_shares_r2510 s
  GROUP BY s.share_channel
  ORDER BY total_views DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.channel_breakdown_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_breakdown_r2510() TO authenticated;

-- RPC 5: privacy_focus_r2510
CREATE OR REPLACE FUNCTION public.privacy_focus_r2510()
RETURNS TABLE (
  privacy_status text,
  shares_count bigint,
  total_photos bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.engineer_photo_shares_r2510;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT CASE WHEN s.privacy_signoff_ok THEN 'signoff_ok' ELSE 'signoff_missing' END AS privacy_status,
         COUNT(*)::bigint AS shares_count,
         COALESCE(SUM(s.photo_count), 0)::bigint AS total_photos,
         ROUND((COUNT(*)::numeric * 100.0 / total), 1) AS pct_of_total
  FROM public.engineer_photo_shares_r2510 s
  GROUP BY 1
  ORDER BY shares_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.privacy_focus_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.privacy_focus_r2510() TO authenticated;

-- RPC 6: top_positive_feedback_r2510
CREATE OR REPLACE FUNCTION public.top_positive_feedback_r2510()
RETURNS TABLE (
  id uuid,
  shared_at timestamptz,
  owner_email text,
  share_channel text,
  view_count int,
  customer_quote_text text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.shared_at, s.owner_email, s.share_channel, s.view_count,
         s.customer_quote_text, s.notes
  FROM public.engineer_photo_shares_r2510 s
  WHERE s.customer_feedback = 'positive'
  ORDER BY s.view_count DESC, s.shared_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_positive_feedback_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_positive_feedback_r2510() TO authenticated;

-- RPC 7: weekly_share_trend_r2510
CREATE OR REPLACE FUNCTION public.weekly_share_trend_r2510()
RETURNS TABLE (
  week_label text,
  shares_count bigint,
  total_photos bigint,
  total_views bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('week', s.shared_at), 'YYYY-MM-DD') AS week_label,
         COUNT(*)::bigint AS shares_count,
         COALESCE(SUM(s.photo_count), 0)::bigint AS total_photos,
         COALESCE(SUM(s.view_count), 0)::bigint AS total_views,
         COUNT(*) FILTER (WHERE s.customer_feedback = 'positive')::bigint AS positive_count
  FROM public.engineer_photo_shares_r2510 s
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_share_trend_r2510() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_share_trend_r2510() TO authenticated;
