BEGIN;

-- =========================================================================
-- Round 1689: Investor Newsletter Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.investor_newsletters_r1689 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_at timestamptz NOT NULL DEFAULT now(),
  subject text NOT NULL,
  body_md text NOT NULL DEFAULT '',
  recipients_count int NOT NULL DEFAULT 0,
  opens_count int NOT NULL DEFAULT 0,
  clicks_count int NOT NULL DEFAULT 0,
  replies_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_newsletter_reactions_r1689 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  newsletter_id uuid NOT NULL REFERENCES public.investor_newsletters_r1689(id) ON DELETE CASCADE,
  investor_id uuid NOT NULL,
  reaction_at timestamptz NOT NULL DEFAULT now(),
  reaction_type text NOT NULL CHECK (reaction_type IN ('open','click','reply','unsubscribe')),
  click_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_newsletters_r1689_sent_at ON public.investor_newsletters_r1689(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_newsletter_reactions_r1689_newsletter ON public.investor_newsletter_reactions_r1689(newsletter_id);
CREATE INDEX IF NOT EXISTS idx_newsletter_reactions_r1689_investor ON public.investor_newsletter_reactions_r1689(investor_id);
CREATE INDEX IF NOT EXISTS idx_newsletter_reactions_r1689_type ON public.investor_newsletter_reactions_r1689(reaction_type);

ALTER TABLE public.investor_newsletters_r1689 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_newsletter_reactions_r1689 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_newsletters_r1689 ON public.investor_newsletters_r1689;
CREATE POLICY founder_all_newsletters_r1689 ON public.investor_newsletters_r1689
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_newsletter_reactions_r1689 ON public.investor_newsletter_reactions_r1689;
CREATE POLICY founder_all_newsletter_reactions_r1689 ON public.investor_newsletter_reactions_r1689
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_newsletters
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_newsletters_r1689()
RETURNS TABLE (
  id uuid,
  sent_at timestamptz,
  subject text,
  recipients_count int,
  opens_count int,
  clicks_count int,
  replies_count int,
  open_rate_pct numeric,
  click_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    n.id,
    n.sent_at,
    n.subject,
    n.recipients_count,
    n.opens_count,
    n.clicks_count,
    n.replies_count,
    CASE WHEN n.recipients_count > 0 THEN ROUND((n.opens_count::numeric / n.recipients_count) * 100, 1) ELSE 0 END AS open_rate_pct,
    CASE WHEN n.recipients_count > 0 THEN ROUND((n.clicks_count::numeric / n.recipients_count) * 100, 1) ELSE 0 END AS click_rate_pct
  FROM public.investor_newsletters_r1689 n
  ORDER BY n.sent_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_newsletters_r1689() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_newsletters_r1689() TO authenticated;

-- =========================================================================
-- RPC 2: log_newsletter
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_newsletter_r1689(
  p_subject text,
  p_body_md text,
  p_recipients_count int
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
  INSERT INTO public.investor_newsletters_r1689(subject, body_md, recipients_count)
  VALUES (p_subject, COALESCE(p_body_md, ''), COALESCE(p_recipients_count, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_newsletter_r1689',
          jsonb_build_object('newsletter_id', v_id, 'subject', p_subject, 'recipients_count', p_recipients_count));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_newsletter_r1689(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_newsletter_r1689(text, text, int) TO authenticated;

-- =========================================================================
-- RPC 3: list_reactions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_reactions_r1689(p_newsletter_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  newsletter_id uuid,
  investor_id uuid,
  reaction_at timestamptz,
  reaction_type text,
  click_url text,
  newsletter_subject text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.newsletter_id,
    r.investor_id,
    r.reaction_at,
    r.reaction_type,
    r.click_url,
    n.subject AS newsletter_subject
  FROM public.investor_newsletter_reactions_r1689 r
  JOIN public.investor_newsletters_r1689 n ON n.id = r.newsletter_id
  WHERE p_newsletter_id IS NULL OR r.newsletter_id = p_newsletter_id
  ORDER BY r.reaction_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reactions_r1689(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reactions_r1689(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_reaction
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_reaction_r1689(
  p_newsletter_id uuid,
  p_investor_id uuid,
  p_reaction_type text,
  p_click_url text DEFAULT NULL
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
  IF p_reaction_type NOT IN ('open','click','reply','unsubscribe') THEN
    RAISE EXCEPTION 'invalid reaction_type';
  END IF;

  INSERT INTO public.investor_newsletter_reactions_r1689(newsletter_id, investor_id, reaction_type, click_url)
  VALUES (p_newsletter_id, p_investor_id, p_reaction_type, p_click_url)
  RETURNING id INTO v_id;

  -- update aggregate counters
  IF p_reaction_type = 'open' THEN
    UPDATE public.investor_newsletters_r1689 SET opens_count = opens_count + 1, updated_at = now() WHERE id = p_newsletter_id;
  ELSIF p_reaction_type = 'click' THEN
    UPDATE public.investor_newsletters_r1689 SET clicks_count = clicks_count + 1, updated_at = now() WHERE id = p_newsletter_id;
  ELSIF p_reaction_type = 'reply' THEN
    UPDATE public.investor_newsletters_r1689 SET replies_count = replies_count + 1, updated_at = now() WHERE id = p_newsletter_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r1689',
          jsonb_build_object('newsletter_id', p_newsletter_id, 'investor_id', p_investor_id, 'reaction_type', p_reaction_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_reaction_r1689(uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reaction_r1689(uuid, uuid, text, text) TO authenticated;

-- =========================================================================
-- RPC 5: open_rate_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.open_rate_summary_r1689()
RETURNS TABLE (
  total_newsletters int,
  total_recipients int,
  total_opens int,
  total_clicks int,
  total_replies int,
  avg_open_rate_pct numeric,
  avg_click_rate_pct numeric,
  avg_reply_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_newsletters,
    COALESCE(SUM(recipients_count), 0)::int AS total_recipients,
    COALESCE(SUM(opens_count), 0)::int AS total_opens,
    COALESCE(SUM(clicks_count), 0)::int AS total_clicks,
    COALESCE(SUM(replies_count), 0)::int AS total_replies,
    CASE WHEN COALESCE(SUM(recipients_count), 0) > 0
         THEN ROUND((SUM(opens_count)::numeric / SUM(recipients_count)) * 100, 1)
         ELSE 0 END AS avg_open_rate_pct,
    CASE WHEN COALESCE(SUM(recipients_count), 0) > 0
         THEN ROUND((SUM(clicks_count)::numeric / SUM(recipients_count)) * 100, 1)
         ELSE 0 END AS avg_click_rate_pct,
    CASE WHEN COALESCE(SUM(recipients_count), 0) > 0
         THEN ROUND((SUM(replies_count)::numeric / SUM(recipients_count)) * 100, 1)
         ELSE 0 END AS avg_reply_rate_pct
  FROM public.investor_newsletters_r1689;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.open_rate_summary_r1689() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_rate_summary_r1689() TO authenticated;

-- =========================================================================
-- RPC 6: top_engaged_investors
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_engaged_investors_r1689()
RETURNS TABLE (
  investor_id uuid,
  total_reactions int,
  opens int,
  clicks int,
  replies int,
  last_reaction_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.investor_id,
    (COUNT(*))::int AS total_reactions,
    (COUNT(*) FILTER (WHERE r.reaction_type = 'open'))::int AS opens,
    (COUNT(*) FILTER (WHERE r.reaction_type = 'click'))::int AS clicks,
    (COUNT(*) FILTER (WHERE r.reaction_type = 'reply'))::int AS replies,
    MAX(r.reaction_at) AS last_reaction_at
  FROM public.investor_newsletter_reactions_r1689 r
  GROUP BY r.investor_id
  ORDER BY total_reactions DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_engaged_investors_r1689() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engaged_investors_r1689() TO authenticated;

-- =========================================================================
-- RPC 7: newsletter_trend
-- =========================================================================
CREATE OR REPLACE FUNCTION public.newsletter_trend_r1689()
RETURNS TABLE (
  week_start date,
  newsletters_sent int,
  recipients int,
  opens int,
  clicks int,
  replies int,
  open_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', n.sent_at)::date AS week_start,
    (COUNT(*))::int AS newsletters_sent,
    COALESCE(SUM(n.recipients_count), 0)::int AS recipients,
    COALESCE(SUM(n.opens_count), 0)::int AS opens,
    COALESCE(SUM(n.clicks_count), 0)::int AS clicks,
    COALESCE(SUM(n.replies_count), 0)::int AS replies,
    CASE WHEN COALESCE(SUM(n.recipients_count), 0) > 0
         THEN ROUND((SUM(n.opens_count)::numeric / SUM(n.recipients_count)) * 100, 1)
         ELSE 0 END AS open_rate_pct
  FROM public.investor_newsletters_r1689 n
  WHERE n.sent_at >= now() - interval '180 days'
  GROUP BY date_trunc('week', n.sent_at)
  ORDER BY week_start DESC
  LIMIT 26;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.newsletter_trend_r1689() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.newsletter_trend_r1689() TO authenticated;

COMMIT;