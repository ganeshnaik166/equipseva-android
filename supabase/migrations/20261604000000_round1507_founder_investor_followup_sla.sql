BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS founder_investor_interactions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  channel text NOT NULL CHECK (channel IN ('email','call','meeting','whatsapp','intro')),
  topic text,
  contacted_at timestamptz NOT NULL DEFAULT now(),
  sla_hours int NOT NULL DEFAULT 48,
  followup_due_at timestamptz NOT NULL,
  cleared_at timestamptz,
  cleared_note text,
  founder_user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fii_v2_due ON founder_investor_interactions_v2(followup_due_at) WHERE cleared_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fii_v2_investor ON founder_investor_interactions_v2(investor_name);

CREATE TABLE IF NOT EXISTS founder_investor_weekly_clearance_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  cleared_count int NOT NULL DEFAULT 0,
  opened_count int NOT NULL DEFAULT 0,
  overdue_carry int NOT NULL DEFAULT 0,
  median_hours numeric,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_start)
);

ALTER TABLE founder_investor_interactions_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_weekly_clearance_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fii_v2_founder ON founder_investor_interactions_v2;
CREATE POLICY p_fii_v2_founder ON founder_investor_interactions_v2 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS p_fiwc_v2_founder ON founder_investor_weekly_clearance_v2;
CREATE POLICY p_fiwc_v2_founder ON founder_investor_weekly_clearance_v2 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- log helpers
CREATE OR REPLACE FUNCTION log_founder_investor_interaction_open(p_id uuid, p_investor text, p_channel text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id=auth.uid()), 'investor_interaction_open',
          jsonb_build_object('id', p_id, 'investor', p_investor, 'channel', p_channel));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_interaction_open(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_interaction_open(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_interaction_clear(p_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id=auth.uid()), 'investor_interaction_clear',
          jsonb_build_object('id', p_id, 'note', p_note));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_interaction_clear(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_interaction_clear(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_weekly_snapshot(p_week date, p_cleared int, p_opened int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id=auth.uid()), 'investor_weekly_snapshot',
          jsonb_build_object('week_start', p_week, 'cleared', p_cleared, 'opened', p_opened));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_weekly_snapshot(date,int,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_weekly_snapshot(date,int,int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_sla_override(p_id uuid, p_hours int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id=auth.uid()), 'investor_sla_override',
          jsonb_build_object('id', p_id, 'sla_hours', p_hours));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_sla_override(uuid,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_sla_override(uuid,int) TO authenticated;

-- 7 SECDEF RPCs
CREATE OR REPLACE FUNCTION founder_investor_sla_summary()
RETURNS TABLE(total_open int, overdue_count int, due_24h int, cleared_7d int, median_clear_hours numeric, oldest_overdue_hours numeric, unique_investors int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE cleared_at IS NULL)::int,
    COUNT(*) FILTER (WHERE cleared_at IS NULL AND followup_due_at < now())::int,
    COUNT(*) FILTER (WHERE cleared_at IS NULL AND followup_due_at BETWEEN now() AND now() + interval '24 hours')::int,
    COUNT(*) FILTER (WHERE cleared_at >= now() - interval '7 days')::int,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (cleared_at - contacted_at))/3600.0) FILTER (WHERE cleared_at IS NOT NULL),
    MAX(EXTRACT(EPOCH FROM (now() - followup_due_at))/3600.0) FILTER (WHERE cleared_at IS NULL AND followup_due_at < now()),
    COUNT(DISTINCT investor_name)::int
  FROM founder_investor_interactions_v2;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_sla_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_sla_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_overdue_list()
RETURNS TABLE(id uuid, investor_name text, investor_firm text, channel text, topic text, contacted_at timestamptz, followup_due_at timestamptz, hours_overdue numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.investor_firm, i.channel, i.topic, i.contacted_at, i.followup_due_at,
         EXTRACT(EPOCH FROM (now() - i.followup_due_at))/3600.0
  FROM founder_investor_interactions_v2 i
  WHERE i.cleared_at IS NULL AND i.followup_due_at < now()
  ORDER BY i.followup_due_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_overdue_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_overdue_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_debt_per_investor()
RETURNS TABLE(investor_name text, investor_firm text, open_count int, overdue_count int, oldest_open_hours numeric, last_contact timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.investor_name, MAX(i.investor_firm),
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL)::int,
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL AND i.followup_due_at < now())::int,
         MAX(EXTRACT(EPOCH FROM (now() - i.contacted_at))/3600.0) FILTER (WHERE i.cleared_at IS NULL),
         MAX(i.contacted_at)
  FROM founder_investor_interactions_v2 i
  GROUP BY i.investor_name
  HAVING COUNT(*) FILTER (WHERE i.cleared_at IS NULL) > 0
  ORDER BY COUNT(*) FILTER (WHERE i.cleared_at IS NULL AND i.followup_due_at < now()) DESC,
           COUNT(*) FILTER (WHERE i.cleared_at IS NULL) DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_debt_per_investor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_debt_per_investor() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_due_soon()
RETURNS TABLE(id uuid, investor_name text, channel text, topic text, followup_due_at timestamptz, hours_until_due numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.channel, i.topic, i.followup_due_at,
         EXTRACT(EPOCH FROM (i.followup_due_at - now()))/3600.0
  FROM founder_investor_interactions_v2 i
  WHERE i.cleared_at IS NULL AND i.followup_due_at BETWEEN now() AND now() + interval '48 hours'
  ORDER BY i.followup_due_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_due_soon() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_due_soon() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_weekly_clearance_log()
RETURNS TABLE(week_start date, cleared_count int, opened_count int, overdue_carry int, median_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.week_start, w.cleared_count, w.opened_count, w.overdue_carry, w.median_hours
  FROM founder_investor_weekly_clearance_v2 w
  ORDER BY w.week_start DESC
  LIMIT 26;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_weekly_clearance_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_weekly_clearance_log() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_channel_mix()
RETURNS TABLE(channel text, total_count int, open_count int, overdue_count int, median_clear_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.channel,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL)::int,
         COUNT(*) FILTER (WHERE i.cleared_at IS NULL AND i.followup_due_at < now())::int,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (i.cleared_at - i.contacted_at))/3600.0) FILTER (WHERE i.cleared_at IS NOT NULL)
  FROM founder_investor_interactions_v2 i
  GROUP BY i.channel
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_channel_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_channel_mix() TO authenticated;

CREATE OR REPLACE FUNCTION founder_investor_open_interactions()
RETURNS TABLE(id uuid, investor_name text, investor_firm text, channel text, topic text, contacted_at timestamptz, followup_due_at timestamptz, sla_hours int, age_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.investor_firm, i.channel, i.topic, i.contacted_at, i.followup_due_at, i.sla_hours,
         EXTRACT(EPOCH FROM (now() - i.contacted_at))/3600.0
  FROM founder_investor_interactions_v2 i
  WHERE i.cleared_at IS NULL
  ORDER BY i.followup_due_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_investor_open_interactions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_open_interactions() TO authenticated;

COMMIT;