BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_newsletter_drafts_r1950 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  edition_label text NOT NULL,
  headline text NOT NULL,
  sections_md text,
  send_status text NOT NULL DEFAULT 'draft' CHECK (send_status IN ('draft','reviewing','scheduled','sent','cancelled')),
  sent_at timestamptz,
  scheduled_for timestamptz,
  audience_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_newsletter_engagement_log_r1950 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES public.founder_newsletter_drafts_r1950(id) ON DELETE CASCADE,
  engagement_type text NOT NULL CHECK (engagement_type IN ('open_rate_reported','reply_received','link_click','unsubscribe','share_received')),
  reported_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  value_metric numeric,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fnd_r1950_status ON public.founder_newsletter_drafts_r1950(send_status);
CREATE INDEX IF NOT EXISTS idx_fnd_r1950_sched ON public.founder_newsletter_drafts_r1950(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_fnel_r1950_draft ON public.founder_newsletter_engagement_log_r1950(draft_id);
CREATE INDEX IF NOT EXISTS idx_fnel_r1950_type ON public.founder_newsletter_engagement_log_r1950(engagement_type);

ALTER TABLE public.founder_newsletter_drafts_r1950 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_newsletter_engagement_log_r1950 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fnd_r1950_founder_all ON public.founder_newsletter_drafts_r1950;
CREATE POLICY fnd_r1950_founder_all ON public.founder_newsletter_drafts_r1950
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fnel_r1950_founder_all ON public.founder_newsletter_engagement_log_r1950;
CREATE POLICY fnel_r1950_founder_all ON public.founder_newsletter_engagement_log_r1950
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_drafts_r1950()
RETURNS TABLE (
  id uuid,
  edition_label text,
  headline text,
  send_status text,
  sent_at timestamptz,
  scheduled_for timestamptz,
  audience_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.edition_label, d.headline, d.send_status, d.sent_at, d.scheduled_for, d.audience_count, d.created_at
  FROM public.founder_newsletter_drafts_r1950 d
  ORDER BY d.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_draft_r1950(
  p_edition_label text,
  p_headline text,
  p_sections_md text,
  p_send_status text,
  p_scheduled_for timestamptz,
  p_audience_count int
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
  INSERT INTO public.founder_newsletter_drafts_r1950(edition_label, headline, sections_md, send_status, scheduled_for, audience_count)
  VALUES (p_edition_label, p_headline, p_sections_md, COALESCE(p_send_status,'draft'), p_scheduled_for, COALESCE(p_audience_count,0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_draft_r1950', jsonb_build_object('id', v_id, 'edition', p_edition_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_engagement_r1950(p_draft_id uuid)
RETURNS TABLE (
  id uuid,
  draft_id uuid,
  engagement_type text,
  reported_at timestamptz,
  by_email text,
  value_metric numeric,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.draft_id, e.engagement_type, e.reported_at, e.by_email, e.value_metric, e.notes_md
  FROM public.founder_newsletter_engagement_log_r1950 e
  WHERE (p_draft_id IS NULL OR e.draft_id = p_draft_id)
  ORDER BY e.reported_at DESC
  LIMIT 300;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_engagement_r1950(
  p_draft_id uuid,
  p_engagement_type text,
  p_by_email text,
  p_value_metric numeric,
  p_notes_md text
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
  INSERT INTO public.founder_newsletter_engagement_log_r1950(draft_id, engagement_type, by_email, value_metric, notes_md)
  VALUES (p_draft_id, p_engagement_type, p_by_email, p_value_metric, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engagement_r1950', jsonb_build_object('id', v_id, 'draft_id', p_draft_id, 'type', p_engagement_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1950(
  p_draft_id uuid,
  p_send_status text,
  p_sent_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_send_status NOT IN ('draft','reviewing','scheduled','sent','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.founder_newsletter_drafts_r1950
  SET send_status = p_send_status,
      sent_at = COALESCE(p_sent_at, CASE WHEN p_send_status='sent' THEN now() ELSE sent_at END),
      updated_at = now()
  WHERE id = p_draft_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1950', jsonb_build_object('draft_id', p_draft_id, 'status', p_send_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.scheduled_or_sending_r1950()
RETURNS TABLE (
  id uuid,
  edition_label text,
  headline text,
  send_status text,
  scheduled_for timestamptz,
  audience_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.edition_label, d.headline, d.send_status, d.scheduled_for, d.audience_count
  FROM public.founder_newsletter_drafts_r1950 d
  WHERE d.send_status IN ('scheduled','reviewing')
  ORDER BY COALESCE(d.scheduled_for, d.created_at) ASC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_engagement_r1950(p_days int)
RETURNS TABLE (
  engagement_type text,
  event_count bigint,
  avg_metric numeric,
  last_reported timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engagement_type,
         COUNT(*)::bigint AS event_count,
         AVG(e.value_metric)::numeric AS avg_metric,
         MAX(e.reported_at) AS last_reported
  FROM public.founder_newsletter_engagement_log_r1950 e
  WHERE e.reported_at >= now() - (COALESCE(p_days,30) || ' days')::interval
  GROUP BY e.engagement_type
  ORDER BY event_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_drafts_r1950() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_draft_r1950(text, text, text, text, timestamptz, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_engagement_r1950(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1950(uuid, text, text, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1950(uuid, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.scheduled_or_sending_r1950() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_engagement_r1950(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_drafts_r1950() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_draft_r1950(text, text, text, text, timestamptz, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_engagement_r1950(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1950(uuid, text, text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1950(uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.scheduled_or_sending_r1950() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_engagement_r1950(int) TO authenticated;

COMMIT;
