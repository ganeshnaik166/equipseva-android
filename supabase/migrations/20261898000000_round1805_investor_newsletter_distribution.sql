BEGIN;

-- ============================================================
-- Round 1805 — Investor Newsletter Distribution
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_newsletter_distributions_r1805 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  newsletter_id uuid NOT NULL,
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  opened_at timestamptz,
  click_count int NOT NULL DEFAULT 0,
  sentiment_inferred text CHECK (sentiment_inferred IN ('positive','neutral','negative','no_signal')) DEFAULT 'no_signal',
  replied boolean NOT NULL DEFAULT false,
  reply_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inld_r1805_newsletter
  ON public.investor_newsletter_distributions_r1805(newsletter_id);
CREATE INDEX IF NOT EXISTS idx_inld_r1805_investor
  ON public.investor_newsletter_distributions_r1805(investor_id);

CREATE TABLE IF NOT EXISTS public.investor_newsletter_recipient_segments_r1805 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  distribution_id uuid NOT NULL REFERENCES public.investor_newsletter_distributions_r1805(id) ON DELETE CASCADE,
  segment text NOT NULL CHECK (segment IN ('tier_1_lead','tier_2','observer','past_investor','declined')),
  custom_message_sent boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inrs_r1805_distribution
  ON public.investor_newsletter_recipient_segments_r1805(distribution_id);

ALTER TABLE public.investor_newsletter_distributions_r1805 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_newsletter_recipient_segments_r1805 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_inld_r1805_founder ON public.investor_newsletter_distributions_r1805;
CREATE POLICY p_inld_r1805_founder ON public.investor_newsletter_distributions_r1805
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_inrs_r1805_founder ON public.investor_newsletter_recipient_segments_r1805;
CREATE POLICY p_inrs_r1805_founder ON public.investor_newsletter_recipient_segments_r1805
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_distributions
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_distributions_r1805()
RETURNS TABLE (
  id uuid,
  newsletter_id uuid,
  investor_id uuid,
  investor_email text,
  sent_at timestamptz,
  opened_at timestamptz,
  click_count int,
  sentiment_inferred text,
  replied boolean,
  reply_summary text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.id, d.newsletter_id, d.investor_id, p.email::text, d.sent_at, d.opened_at,
         d.click_count, d.sentiment_inferred, d.replied, d.reply_summary
  FROM public.investor_newsletter_distributions_r1805 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY d.sent_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 2: log_distribution
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_distribution_r1805(
  p_newsletter_id uuid,
  p_investor_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_newsletter_distributions_r1805(newsletter_id, investor_id)
  VALUES (p_newsletter_id, p_investor_id)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_distribution_r1805',
          jsonb_build_object('distribution_id', v_id, 'newsletter_id', p_newsletter_id, 'investor_id', p_investor_id));
  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_segments
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_segments_r1805()
RETURNS TABLE (
  id uuid,
  distribution_id uuid,
  segment text,
  custom_message_sent boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.id, s.distribution_id, s.segment, s.custom_message_sent, s.created_at
  FROM public.investor_newsletter_recipient_segments_r1805 s
  ORDER BY s.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 4: set_segment
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_segment_r1805(
  p_distribution_id uuid,
  p_segment text,
  p_custom_message_sent boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_newsletter_recipient_segments_r1805(distribution_id, segment, custom_message_sent)
  VALUES (p_distribution_id, p_segment, p_custom_message_sent)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_segment_r1805',
          jsonb_build_object('segment_id', v_id, 'distribution_id', p_distribution_id, 'segment', p_segment));
  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: log_open
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_open_r1805(
  p_distribution_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_newsletter_distributions_r1805
  SET opened_at = COALESCE(opened_at, now()),
      click_count = click_count + 1,
      updated_at = now()
  WHERE id = p_distribution_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_open_r1805',
          jsonb_build_object('distribution_id', p_distribution_id));
END;
$$;

-- ============================================================
-- RPC 6: top_engaged_investors
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_engaged_investors_r1805()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  total_sends int,
  total_opens int,
  total_clicks int,
  replies int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.investor_id,
         p.email::text,
         (COUNT(*) )::int AS total_sends,
         (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::int AS total_opens,
         (COALESCE(SUM(d.click_count),0))::int AS total_clicks,
         (COUNT(*) FILTER (WHERE d.replied))::int AS replies
  FROM public.investor_newsletter_distributions_r1805 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  GROUP BY d.investor_id, p.email
  ORDER BY total_clicks DESC, total_opens DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- RPC 7: sentiment_summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.sentiment_summary_r1805()
RETURNS TABLE (
  sentiment text,
  cnt int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT COALESCE(d.sentiment_inferred,'no_signal') AS sentiment,
         (COUNT(*))::int AS cnt
  FROM public.investor_newsletter_distributions_r1805 d
  GROUP BY COALESCE(d.sentiment_inferred,'no_signal')
  ORDER BY cnt DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_distributions_r1805() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_distribution_r1805(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_segments_r1805() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_segment_r1805(uuid, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_open_r1805(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engaged_investors_r1805() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sentiment_summary_r1805() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_distributions_r1805() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_distribution_r1805(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_segments_r1805() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_segment_r1805(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_open_r1805(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engaged_investors_r1805() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sentiment_summary_r1805() TO authenticated;

COMMIT;