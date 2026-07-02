BEGIN;

-- ============================================================
-- r1593 — Founder Weekly Digest Sent Log
-- Log every weekly digest sent to investors/team.
-- Track recipient list, open/click rates, A/B subject test,
-- per-recipient engagement.
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_weekly_digest_sends_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_at timestamptz NOT NULL DEFAULT now(),
  digest_week_start date NOT NULL,
  audience text NOT NULL CHECK (audience IN ('investors','team','board','advisors','all')),
  subject_variant text NOT NULL CHECK (subject_variant IN ('A','B')),
  subject_line text NOT NULL,
  body_preview text,
  recipient_count int NOT NULL DEFAULT 0,
  opens_count int NOT NULL DEFAULT 0,
  clicks_count int NOT NULL DEFAULT 0,
  bounces_count int NOT NULL DEFAULT 0,
  unsubscribes_count int NOT NULL DEFAULT 0,
  sender_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwds_v2_sent_at ON founder_weekly_digest_sends_v2 (sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_fwds_v2_audience ON founder_weekly_digest_sends_v2 (audience);
CREATE INDEX IF NOT EXISTS idx_fwds_v2_variant ON founder_weekly_digest_sends_v2 (subject_variant);
CREATE INDEX IF NOT EXISTS idx_fwds_v2_week ON founder_weekly_digest_sends_v2 (digest_week_start DESC);

ALTER TABLE founder_weekly_digest_sends_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwds_v2_founder_all ON founder_weekly_digest_sends_v2;
CREATE POLICY fwds_v2_founder_all ON founder_weekly_digest_sends_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_weekly_digest_recipients_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  digest_send_id uuid NOT NULL REFERENCES founder_weekly_digest_sends_v2(id) ON DELETE CASCADE,
  recipient_email text NOT NULL,
  recipient_name text,
  recipient_role text CHECK (recipient_role IN ('investor','team','board','advisor','other')),
  delivered boolean NOT NULL DEFAULT true,
  opened_at timestamptz,
  first_click_at timestamptz,
  click_count int NOT NULL DEFAULT 0,
  bounced boolean NOT NULL DEFAULT false,
  unsubscribed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwdr_v2_send_id ON founder_weekly_digest_recipients_v2 (digest_send_id);
CREATE INDEX IF NOT EXISTS idx_fwdr_v2_email ON founder_weekly_digest_recipients_v2 (recipient_email);
CREATE INDEX IF NOT EXISTS idx_fwdr_v2_role ON founder_weekly_digest_recipients_v2 (recipient_role);
CREATE INDEX IF NOT EXISTS idx_fwdr_v2_opened ON founder_weekly_digest_recipients_v2 (opened_at) WHERE opened_at IS NOT NULL;

ALTER TABLE founder_weekly_digest_recipients_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwdr_v2_founder_all ON founder_weekly_digest_recipients_v2;
CREATE POLICY fwdr_v2_founder_all ON founder_weekly_digest_recipients_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_weekly_digest_kpis_v2()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT jsonb_build_object(
    'total_sends', COUNT(*),
    'sends_last_30d', COUNT(*) FILTER (WHERE sent_at > now() - interval '30 days'),
    'sends_last_90d', COUNT(*) FILTER (WHERE sent_at > now() - interval '90 days'),
    'investor_sends', COUNT(*) FILTER (WHERE audience='investors'),
    'team_sends', COUNT(*) FILTER (WHERE audience='team'),
    'board_sends', COUNT(*) FILTER (WHERE audience='board'),
    'total_recipients', COALESCE(SUM(recipient_count),0),
    'total_opens', COALESCE(SUM(opens_count),0),
    'total_clicks', COALESCE(SUM(clicks_count),0),
    'total_bounces', COALESCE(SUM(bounces_count),0),
    'total_unsubscribes', COALESCE(SUM(unsubscribes_count),0),
    'avg_open_rate_pct', CASE WHEN COALESCE(SUM(recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(opens_count)::numeric / SUM(recipient_count),2) END,
    'avg_click_rate_pct', CASE WHEN COALESCE(SUM(recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(clicks_count)::numeric / SUM(recipient_count),2) END,
    'variant_a_sends', COUNT(*) FILTER (WHERE subject_variant='A'),
    'variant_b_sends', COUNT(*) FILTER (WHERE subject_variant='B'),
    'last_send_at', MAX(sent_at),
    'first_send_at', MIN(sent_at)
  ) INTO result
  FROM founder_weekly_digest_sends_v2;

  RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_kpis_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_kpis_v2() TO authenticated;


CREATE OR REPLACE FUNCTION founder_weekly_digest_recent_sends_v2(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  sent_at timestamptz,
  digest_week_start date,
  audience text,
  subject_variant text,
  subject_line text,
  recipient_count int,
  opens_count int,
  clicks_count int,
  open_rate_pct numeric,
  click_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT s.id, s.sent_at, s.digest_week_start, s.audience, s.subject_variant, s.subject_line,
    s.recipient_count, s.opens_count, s.clicks_count,
    CASE WHEN s.recipient_count=0 THEN 0 ELSE ROUND(100.0 * s.opens_count::numeric / s.recipient_count,2) END,
    CASE WHEN s.recipient_count=0 THEN 0 ELSE ROUND(100.0 * s.clicks_count::numeric / s.recipient_count,2) END
  FROM founder_weekly_digest_sends_v2 s
  ORDER BY s.sent_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_recent_sends_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_recent_sends_v2(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_weekly_digest_ab_test_v2()
RETURNS TABLE (
  subject_variant text,
  sends int,
  total_recipients bigint,
  total_opens bigint,
  total_clicks bigint,
  open_rate_pct numeric,
  click_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT s.subject_variant,
    COUNT(*)::int,
    COALESCE(SUM(s.recipient_count),0),
    COALESCE(SUM(s.opens_count),0),
    COALESCE(SUM(s.clicks_count),0),
    CASE WHEN COALESCE(SUM(s.recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(s.opens_count)::numeric / SUM(s.recipient_count),2) END,
    CASE WHEN COALESCE(SUM(s.recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(s.clicks_count)::numeric / SUM(s.recipient_count),2) END
  FROM founder_weekly_digest_sends_v2 s
  GROUP BY s.subject_variant
  ORDER BY s.subject_variant;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_ab_test_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_ab_test_v2() TO authenticated;


CREATE OR REPLACE FUNCTION founder_weekly_digest_top_recipients_v2(p_limit int DEFAULT 25)
RETURNS TABLE (
  recipient_email text,
  recipient_name text,
  recipient_role text,
  sends_received bigint,
  opens bigint,
  clicks bigint,
  last_open_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT r.recipient_email,
    MAX(r.recipient_name),
    MAX(r.recipient_role),
    COUNT(*),
    COUNT(*) FILTER (WHERE r.opened_at IS NOT NULL),
    COALESCE(SUM(r.click_count),0),
    MAX(r.opened_at)
  FROM founder_weekly_digest_recipients_v2 r
  GROUP BY r.recipient_email
  ORDER BY COUNT(*) FILTER (WHERE r.opened_at IS NOT NULL) DESC, COUNT(*) DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_top_recipients_v2(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_top_recipients_v2(int) TO authenticated;


CREATE OR REPLACE FUNCTION founder_weekly_digest_by_audience_v2()
RETURNS TABLE (
  audience text,
  sends bigint,
  total_recipients bigint,
  open_rate_pct numeric,
  click_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT s.audience,
    COUNT(*),
    COALESCE(SUM(s.recipient_count),0),
    CASE WHEN COALESCE(SUM(s.recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(s.opens_count)::numeric / SUM(s.recipient_count),2) END,
    CASE WHEN COALESCE(SUM(s.recipient_count),0)=0 THEN 0 ELSE ROUND(100.0 * SUM(s.clicks_count)::numeric / SUM(s.recipient_count),2) END
  FROM founder_weekly_digest_sends_v2 s
  GROUP BY s.audience
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_by_audience_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_by_audience_v2() TO authenticated;


-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_weekly_digest_log_send_v2(
  p_week_start date,
  p_audience text,
  p_variant text,
  p_subject text,
  p_body_preview text,
  p_sender_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_weekly_digest_sends_v2 (
    digest_week_start, audience, subject_variant, subject_line, body_preview, sender_email, notes
  ) VALUES (
    p_week_start, p_audience, p_variant, p_subject, p_body_preview, p_sender_email, p_notes
  ) RETURNING id INTO v_id;

  PERFORM log_founder_weekly_digest_send(v_id, p_audience, p_variant, p_subject);

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_log_send_v2(date,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_log_send_v2(date,text,text,text,text,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION founder_weekly_digest_update_engagement_v2(
  p_send_id uuid,
  p_opens int,
  p_clicks int,
  p_bounces int,
  p_unsubs int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_weekly_digest_sends_v2
  SET opens_count = COALESCE(p_opens, opens_count),
      clicks_count = COALESCE(p_clicks, clicks_count),
      bounces_count = COALESCE(p_bounces, bounces_count),
      unsubscribes_count = COALESCE(p_unsubs, unsubscribes_count),
      updated_at = now()
  WHERE id = p_send_id;

  PERFORM log_founder_weekly_digest_update(p_send_id, p_opens, p_clicks);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_weekly_digest_update_engagement_v2(uuid,int,int,int,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_weekly_digest_update_engagement_v2(uuid,int,int,int,int) TO authenticated;


-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_weekly_digest_send(
  p_send_id uuid, p_audience text, p_variant text, p_subject text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_weekly_digest_log_send_v2',
    jsonb_build_object('send_id', p_send_id, 'audience', p_audience, 'variant', p_variant, 'subject', p_subject)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_weekly_digest_send(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_weekly_digest_send(uuid,text,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_weekly_digest_update(
  p_send_id uuid, p_opens int, p_clicks int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_weekly_digest_update_engagement_v2',
    jsonb_build_object('send_id', p_send_id, 'opens', p_opens, 'clicks', p_clicks)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_weekly_digest_update(uuid,int,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_weekly_digest_update(uuid,int,int) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_weekly_digest_recipient_event(
  p_send_id uuid, p_email text, p_event text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'weekly_digest_recipient_event',
    jsonb_build_object('send_id', p_send_id, 'email', p_email, 'event', p_event)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_weekly_digest_recipient_event(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_weekly_digest_recipient_event(uuid,text,text) TO authenticated;

COMMIT;