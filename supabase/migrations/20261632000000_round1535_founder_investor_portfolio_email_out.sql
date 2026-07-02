BEGIN;

-- ============================================================================
-- r1535 — Founder Investor Portfolio Email-Out
-- Monthly investor update composer + send log + open/click tracking + replies
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_investor_email_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject text NOT NULL,
  body_markdown text NOT NULL,
  period_month date NOT NULL,
  kpi_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','queued','sent','archived')),
  recipients_count integer NOT NULL DEFAULT 0,
  sent_count integer NOT NULL DEFAULT 0,
  opens_count integer NOT NULL DEFAULT 0,
  clicks_count integer NOT NULL DEFAULT 0,
  replies_count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

CREATE TABLE IF NOT EXISTS founder_investor_email_sends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES founder_investor_email_campaigns(id) ON DELETE CASCADE,
  investor_email text NOT NULL,
  investor_name text,
  investor_firm text,
  sent_at timestamptz NOT NULL DEFAULT now(),
  opened_at timestamptz,
  open_count integer NOT NULL DEFAULT 0,
  first_clicked_at timestamptz,
  click_count integer NOT NULL DEFAULT 0,
  replied_at timestamptz,
  reply_category text CHECK (reply_category IN ('positive','question','intro_request','pass','noise','none')),
  reply_snippet text,
  bounce boolean NOT NULL DEFAULT false,
  unsubscribed boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_invemail_camp_status ON founder_investor_email_campaigns(status, period_month DESC);
CREATE INDEX IF NOT EXISTS idx_invemail_sends_camp ON founder_investor_email_sends(campaign_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_invemail_sends_reply ON founder_investor_email_sends(reply_category) WHERE replied_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invemail_sends_email ON founder_investor_email_sends(investor_email);

ALTER TABLE founder_investor_email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_email_sends ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_invemail_camp_founder ON founder_investor_email_campaigns;
CREATE POLICY p_invemail_camp_founder ON founder_investor_email_campaigns FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS p_invemail_sends_founder ON founder_investor_email_sends;
CREATE POLICY p_invemail_sends_founder ON founder_investor_email_sends FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_invemail_recent_campaigns();
CREATE OR REPLACE FUNCTION founder_invemail_recent_campaigns()
RETURNS TABLE (
  id uuid,
  subject text,
  period_month date,
  status text,
  recipients_count integer,
  sent_count integer,
  opens_count integer,
  clicks_count integer,
  replies_count integer,
  sent_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.subject, c.period_month, c.status, c.recipients_count, c.sent_count,
         c.opens_count, c.clicks_count, c.replies_count, c.sent_at, c.created_at
  FROM founder_investor_email_campaigns c
  ORDER BY c.created_at DESC
  LIMIT 50;
END $$;

DROP FUNCTION IF EXISTS founder_invemail_kpi_autofill();
CREATE OR REPLACE FUNCTION founder_invemail_kpi_autofill()
RETURNS TABLE (
  metric text,
  value_text text,
  value_num numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'jobs_30d'::text, (SELECT count(*)::text FROM repair_jobs WHERE created_at >= now() - interval '30 days'), (SELECT count(*)::numeric FROM repair_jobs WHERE created_at >= now() - interval '30 days')
  UNION ALL
  SELECT 'gmv_30d_rupees', coalesce((SELECT sum(contracted_amount_rupees)::text FROM repair_jobs WHERE created_at >= now() - interval '30 days'),'0'), coalesce((SELECT sum(contracted_amount_rupees)::numeric FROM repair_jobs WHERE created_at >= now() - interval '30 days'),0)
  UNION ALL
  SELECT 'amc_active', (SELECT count(*)::text FROM amc_contracts WHERE status='active'), (SELECT count(*)::numeric FROM amc_contracts WHERE status='active')
  UNION ALL
  SELECT 'engineers_total', (SELECT count(*)::text FROM engineers), (SELECT count(*)::numeric FROM engineers);
END $$;

DROP FUNCTION IF EXISTS founder_invemail_campaign_sends(uuid);
CREATE OR REPLACE FUNCTION founder_invemail_campaign_sends(p_campaign_id uuid)
RETURNS TABLE (
  id uuid,
  investor_email text,
  investor_name text,
  investor_firm text,
  sent_at timestamptz,
  opened_at timestamptz,
  open_count integer,
  click_count integer,
  replied_at timestamptz,
  reply_category text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_email, s.investor_name, s.investor_firm, s.sent_at, s.opened_at,
         s.open_count, s.click_count, s.replied_at, s.reply_category
  FROM founder_investor_email_sends s
  WHERE s.campaign_id = p_campaign_id
  ORDER BY s.sent_at DESC
  LIMIT 500;
END $$;

DROP FUNCTION IF EXISTS founder_invemail_recent_replies();
CREATE OR REPLACE FUNCTION founder_invemail_recent_replies()
RETURNS TABLE (
  id uuid,
  campaign_subject text,
  investor_email text,
  investor_name text,
  investor_firm text,
  reply_category text,
  reply_snippet text,
  replied_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, c.subject, s.investor_email, s.investor_name, s.investor_firm,
         s.reply_category, s.reply_snippet, s.replied_at
  FROM founder_investor_email_sends s
  JOIN founder_investor_email_campaigns c ON c.id = s.campaign_id
  WHERE s.replied_at IS NOT NULL
  ORDER BY s.replied_at DESC
  LIMIT 100;
END $$;

DROP FUNCTION IF EXISTS founder_invemail_engagement_summary();
CREATE OR REPLACE FUNCTION founder_invemail_engagement_summary()
RETURNS TABLE (
  campaigns_total bigint,
  campaigns_sent bigint,
  total_sends bigint,
  unique_opens bigint,
  total_clicks bigint,
  total_replies bigint,
  open_rate_pct numeric,
  reply_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_investor_email_campaigns),
    (SELECT count(*) FROM founder_investor_email_campaigns WHERE status='sent'),
    (SELECT count(*) FROM founder_investor_email_sends),
    (SELECT count(*) FROM founder_investor_email_sends WHERE opened_at IS NOT NULL),
    (SELECT coalesce(sum(click_count),0) FROM founder_investor_email_sends),
    (SELECT count(*) FROM founder_investor_email_sends WHERE replied_at IS NOT NULL),
    CASE WHEN (SELECT count(*) FROM founder_investor_email_sends) = 0 THEN 0::numeric
         ELSE round(100.0 * (SELECT count(*) FROM founder_investor_email_sends WHERE opened_at IS NOT NULL)::numeric / (SELECT count(*) FROM founder_investor_email_sends), 1) END,
    CASE WHEN (SELECT count(*) FROM founder_investor_email_sends) = 0 THEN 0::numeric
         ELSE round(100.0 * (SELECT count(*) FROM founder_investor_email_sends WHERE replied_at IS NOT NULL)::numeric / (SELECT count(*) FROM founder_investor_email_sends), 1) END;
END $$;

DROP FUNCTION IF EXISTS founder_invemail_top_engaged_investors();
CREATE OR REPLACE FUNCTION founder_invemail_top_engaged_investors()
RETURNS TABLE (
  investor_email text,
  investor_name text,
  investor_firm text,
  sends_n bigint,
  opens_n bigint,
  clicks_n bigint,
  replies_n bigint,
  last_seen_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.investor_email,
         max(s.investor_name),
         max(s.investor_firm),
         count(*),
         count(*) FILTER (WHERE s.opened_at IS NOT NULL),
         sum(s.click_count),
         count(*) FILTER (WHERE s.replied_at IS NOT NULL),
         max(coalesce(s.replied_at, s.first_clicked_at, s.opened_at, s.sent_at))
  FROM founder_investor_email_sends s
  GROUP BY s.investor_email
  ORDER BY count(*) FILTER (WHERE s.opened_at IS NOT NULL) DESC NULLS LAST,
           count(*) FILTER (WHERE s.replied_at IS NOT NULL) DESC NULLS LAST
  LIMIT 50;
END $$;

DROP FUNCTION IF EXISTS founder_invemail_monthly_trend();
CREATE OR REPLACE FUNCTION founder_invemail_monthly_trend()
RETURNS TABLE (
  month_label text,
  campaigns_n bigint,
  sends_n bigint,
  opens_n bigint,
  replies_n bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', c.created_at), 'YYYY-MM'),
         count(DISTINCT c.id),
         count(s.id),
         count(s.id) FILTER (WHERE s.opened_at IS NOT NULL),
         count(s.id) FILTER (WHERE s.replied_at IS NOT NULL)
  FROM founder_investor_email_campaigns c
  LEFT JOIN founder_investor_email_sends s ON s.campaign_id = c.id
  WHERE c.created_at >= now() - interval '12 months'
  GROUP BY date_trunc('month', c.created_at)
  ORDER BY date_trunc('month', c.created_at) DESC;
END $$;

-- ============================================================================
-- WRITE RPCs (VOLATILE) — log_founder_* helpers
-- ============================================================================

DROP FUNCTION IF EXISTS log_founder_invemail_create_campaign(text, text, date);
CREATE OR REPLACE FUNCTION log_founder_invemail_create_campaign(p_subject text, p_body_markdown text, p_period_month date)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_email_campaigns (subject, body_markdown, period_month, created_by)
  VALUES (p_subject, p_body_markdown, p_period_month, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invemail_create_campaign',
          jsonb_build_object('id', v_id, 'subject', p_subject, 'period_month', p_period_month));
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS log_founder_invemail_mark_sent(uuid, integer);
CREATE OR REPLACE FUNCTION log_founder_invemail_mark_sent(p_campaign_id uuid, p_recipients_count integer)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_email_campaigns
     SET status = 'sent', sent_at = now(), recipients_count = p_recipients_count, sent_count = p_recipients_count
   WHERE id = p_campaign_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invemail_mark_sent',
          jsonb_build_object('campaign_id', p_campaign_id, 'recipients', p_recipients_count));
END $$;

DROP FUNCTION IF EXISTS log_founder_invemail_categorize_reply(uuid, text, text);
CREATE OR REPLACE FUNCTION log_founder_invemail_categorize_reply(p_send_id uuid, p_category text, p_snippet text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_category NOT IN ('positive','question','intro_request','pass','noise','none') THEN
    RAISE EXCEPTION 'invalid category';
  END IF;
  UPDATE founder_investor_email_sends
     SET reply_category = p_category, reply_snippet = p_snippet, replied_at = coalesce(replied_at, now())
   WHERE id = p_send_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invemail_categorize_reply',
          jsonb_build_object('send_id', p_send_id, 'category', p_category));
END $$;

DROP FUNCTION IF EXISTS log_founder_invemail_archive_campaign(uuid);
CREATE OR REPLACE FUNCTION log_founder_invemail_archive_campaign(p_campaign_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_email_campaigns SET status = 'archived' WHERE id = p_campaign_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'invemail_archive_campaign',
          jsonb_build_object('campaign_id', p_campaign_id));
END $$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION founder_invemail_recent_campaigns() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_kpi_autofill() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_campaign_sends(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_recent_replies() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_engagement_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_top_engaged_investors() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_invemail_monthly_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invemail_create_campaign(text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invemail_mark_sent(uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invemail_categorize_reply(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_invemail_archive_campaign(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_invemail_recent_campaigns() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_kpi_autofill() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_campaign_sends(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_recent_replies() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_engagement_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_top_engaged_investors() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_invemail_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invemail_create_campaign(text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invemail_mark_sent(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invemail_categorize_reply(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_invemail_archive_campaign(uuid) TO authenticated;

COMMIT;