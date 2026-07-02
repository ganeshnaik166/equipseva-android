BEGIN;

-- =====================================================================
-- Round 1499 — Founder investor inbound-interest log
-- Capture every investor reaching out (cold email, Twitter, referral),
-- founder triage, meeting-conversion ladder, per-source channel rank.
-- =====================================================================

-- Source channels enum-ish table (small lookup, founder-only)
CREATE TABLE IF NOT EXISTS founder_investor_inbound_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key text NOT NULL UNIQUE,
  display_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_investor_inbound_sources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_sources_select ON founder_investor_inbound_sources;
CREATE POLICY founder_only_investor_sources_select ON founder_investor_inbound_sources
  FOR SELECT TO authenticated USING (is_founder());

DROP POLICY IF EXISTS founder_only_investor_sources_all ON founder_investor_inbound_sources;
CREATE POLICY founder_only_investor_sources_all ON founder_investor_inbound_sources
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_investor_inbound_sources(source_key, display_name) VALUES
  ('cold_email','Cold Email'),
  ('twitter','Twitter / X'),
  ('linkedin','LinkedIn'),
  ('referral','Warm Referral'),
  ('press','Press / Article'),
  ('event','Event / Conference'),
  ('angel_network','Angel Network'),
  ('accelerator','Accelerator'),
  ('other','Other')
ON CONFLICT (source_key) DO NOTHING;

-- Main inbound-interest log
CREATE TABLE IF NOT EXISTS founder_investor_inbound_interest (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm_name text,
  contact_email text,
  contact_handle text,
  source_key text NOT NULL DEFAULT 'other',
  check_size_min_rupees numeric(18,2),
  check_size_max_rupees numeric(18,2),
  stage_focus text,
  geo_focus text,
  thesis_snippet text,
  reached_out_at timestamptz NOT NULL DEFAULT now(),
  triage_status text NOT NULL DEFAULT 'new' CHECK (triage_status IN ('new','reviewing','warm','cold','pass','ghosted')),
  triage_score int CHECK (triage_score IS NULL OR (triage_score >= 0 AND triage_score <= 100)),
  triage_notes text,
  ladder_stage text NOT NULL DEFAULT 'inbound' CHECK (ladder_stage IN ('inbound','triaged','intro_meeting','partner_meeting','dd','term_sheet','closed','dead')),
  intro_meeting_at timestamptz,
  partner_meeting_at timestamptz,
  dd_started_at timestamptz,
  term_sheet_at timestamptz,
  closed_at timestamptz,
  dead_at timestamptz,
  dead_reason text,
  founder_priority int NOT NULL DEFAULT 3 CHECK (founder_priority BETWEEN 1 AND 5),
  last_touch_at timestamptz,
  next_action text,
  next_action_due timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fiii_triage_status ON founder_investor_inbound_interest(triage_status);
CREATE INDEX IF NOT EXISTS idx_fiii_ladder_stage ON founder_investor_inbound_interest(ladder_stage);
CREATE INDEX IF NOT EXISTS idx_fiii_source_key ON founder_investor_inbound_interest(source_key);
CREATE INDEX IF NOT EXISTS idx_fiii_reached_out_at ON founder_investor_inbound_interest(reached_out_at DESC);
CREATE INDEX IF NOT EXISTS idx_fiii_next_action_due ON founder_investor_inbound_interest(next_action_due);

ALTER TABLE founder_investor_inbound_interest ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fiii_select ON founder_investor_inbound_interest;
CREATE POLICY founder_only_fiii_select ON founder_investor_inbound_interest
  FOR SELECT TO authenticated USING (is_founder());

DROP POLICY IF EXISTS founder_only_fiii_all ON founder_investor_inbound_interest;
CREATE POLICY founder_only_fiii_all ON founder_investor_inbound_interest
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================================
-- Helpers: log_founder_* (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_investor_inbound_logged(p_id uuid, p_investor text, p_source text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM profiles WHERE id = auth.uid()), 'investor_inbound_logged',
          jsonb_build_object('id', p_id, 'investor', p_investor, 'source', p_source));
END;
$fn$;

CREATE OR REPLACE FUNCTION log_founder_investor_triaged(p_id uuid, p_status text, p_score int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM profiles WHERE id = auth.uid()), 'investor_triaged',
          jsonb_build_object('id', p_id, 'status', p_status, 'score', p_score));
END;
$fn$;

CREATE OR REPLACE FUNCTION log_founder_investor_ladder_advanced(p_id uuid, p_from text, p_to text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM profiles WHERE id = auth.uid()), 'investor_ladder_advanced',
          jsonb_build_object('id', p_id, 'from', p_from, 'to', p_to));
END;
$fn$;

CREATE OR REPLACE FUNCTION log_founder_investor_marked_dead(p_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM profiles WHERE id = auth.uid()), 'investor_marked_dead',
          jsonb_build_object('id', p_id, 'reason', p_reason));
END;
$fn$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_inbound_logged(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_inbound_logged(uuid, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_investor_triaged(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_triaged(uuid, text, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_investor_ladder_advanced(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_ladder_advanced(uuid, text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_investor_marked_dead(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_marked_dead(uuid, text) TO authenticated;

-- =====================================================================
-- Read RPCs (STABLE SECDEF)
-- =====================================================================

-- 1. KPI summary
CREATE OR REPLACE FUNCTION founder_investor_inbound_kpis()
RETURNS TABLE(
  total_inbound int,
  new_unreviewed int,
  reviewing int,
  warm_count int,
  cold_count int,
  pass_count int,
  ghosted_count int,
  intro_meetings int,
  partner_meetings int,
  dd_count int,
  term_sheet_count int,
  closed_count int,
  dead_count int,
  inbound_last_7d int,
  inbound_last_30d int,
  avg_triage_score numeric,
  median_days_to_intro numeric,
  conversion_rate_pct numeric,
  overdue_next_actions int,
  top_source text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM founder_investor_inbound_interest
  ),
  src AS (
    SELECT source_key, COUNT(*) c FROM base GROUP BY source_key ORDER BY 2 DESC LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::int FROM base),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='new'),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='reviewing'),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='warm'),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='cold'),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='pass'),
    (SELECT COUNT(*)::int FROM base WHERE triage_status='ghosted'),
    (SELECT COUNT(*)::int FROM base WHERE intro_meeting_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE partner_meeting_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE dd_started_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE term_sheet_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE closed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE dead_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM base WHERE reached_out_at >= now() - interval '7 days'),
    (SELECT COUNT(*)::int FROM base WHERE reached_out_at >= now() - interval '30 days'),
    (SELECT ROUND(AVG(triage_score)::numeric, 1) FROM base WHERE triage_score IS NOT NULL),
    (SELECT ROUND((percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (intro_meeting_at - reached_out_at))/86400.0))::numeric, 2)
       FROM base WHERE intro_meeting_at IS NOT NULL),
    (SELECT CASE WHEN COUNT(*) FILTER (WHERE intro_meeting_at IS NOT NULL) = 0 THEN 0
                 ELSE ROUND((COUNT(*) FILTER (WHERE partner_meeting_at IS NOT NULL)::numeric / COUNT(*) FILTER (WHERE intro_meeting_at IS NOT NULL)) * 100, 1) END
       FROM base),
    (SELECT COUNT(*)::int FROM base WHERE next_action_due IS NOT NULL AND next_action_due < now() AND ladder_stage NOT IN ('closed','dead')),
    (SELECT display_name FROM founder_investor_inbound_sources s JOIN src ON s.source_key = src.source_key LIMIT 1);
END;
$fn$;

-- 2. Inbound queue (newest first)
CREATE OR REPLACE FUNCTION founder_investor_inbound_queue(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm_name text,
  source_display text,
  reached_out_at timestamptz,
  triage_status text,
  triage_score int,
  ladder_stage text,
  founder_priority int,
  days_since_inbound numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.firm_name,
         COALESCE(s.display_name, i.source_key),
         i.reached_out_at, i.triage_status, i.triage_score, i.ladder_stage, i.founder_priority,
         ROUND((EXTRACT(EPOCH FROM (now() - i.reached_out_at))/86400.0)::numeric, 1)
  FROM founder_investor_inbound_interest i
  LEFT JOIN founder_investor_inbound_sources s ON s.source_key = i.source_key
  ORDER BY i.reached_out_at DESC
  LIMIT p_limit;
END;
$fn$;

-- 3. Triage backlog
CREATE OR REPLACE FUNCTION founder_investor_triage_backlog()
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm_name text,
  source_display text,
  days_waiting numeric,
  founder_priority int,
  contact_email text,
  contact_handle text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.firm_name,
         COALESCE(s.display_name, i.source_key),
         ROUND((EXTRACT(EPOCH FROM (now() - i.reached_out_at))/86400.0)::numeric, 1),
         i.founder_priority, i.contact_email, i.contact_handle
  FROM founder_investor_inbound_interest i
  LEFT JOIN founder_investor_inbound_sources s ON s.source_key = i.source_key
  WHERE i.triage_status IN ('new','reviewing')
  ORDER BY i.founder_priority ASC, i.reached_out_at ASC;
END;
$fn$;

-- 4. Meeting-conversion ladder breakdown
CREATE OR REPLACE FUNCTION founder_investor_ladder_breakdown()
RETURNS TABLE(
  stage text,
  stage_count int,
  pct_of_total numeric,
  avg_days_in_stage numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  total_count int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_count FROM founder_investor_inbound_interest;
  IF total_count = 0 THEN total_count := 1; END IF;
  RETURN QUERY
  SELECT stg.stage_name,
         COUNT(i.id)::int,
         ROUND((COUNT(i.id)::numeric / total_count) * 100, 1),
         ROUND(AVG(EXTRACT(EPOCH FROM (now() - i.reached_out_at))/86400.0)::numeric, 1)
  FROM (VALUES ('inbound'),('triaged'),('intro_meeting'),('partner_meeting'),('dd'),('term_sheet'),('closed'),('dead')) stg(stage_name)
  LEFT JOIN founder_investor_inbound_interest i ON i.ladder_stage = stg.stage_name
  GROUP BY stg.stage_name
  ORDER BY CASE stg.stage_name
    WHEN 'inbound' THEN 1 WHEN 'triaged' THEN 2 WHEN 'intro_meeting' THEN 3
    WHEN 'partner_meeting' THEN 4 WHEN 'dd' THEN 5 WHEN 'term_sheet' THEN 6
    WHEN 'closed' THEN 7 WHEN 'dead' THEN 8 END;
END;
$fn$;

-- 5. Per-source channel rank
CREATE OR REPLACE FUNCTION founder_investor_channel_rank()
RETURNS TABLE(
  source_display text,
  inbound_count int,
  warm_count int,
  intro_count int,
  partner_count int,
  term_sheet_count int,
  warm_pct numeric,
  intro_pct numeric,
  avg_triage_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(s.display_name, i.source_key),
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.triage_status='warm')::int,
         COUNT(*) FILTER (WHERE i.intro_meeting_at IS NOT NULL)::int,
         COUNT(*) FILTER (WHERE i.partner_meeting_at IS NOT NULL)::int,
         COUNT(*) FILTER (WHERE i.term_sheet_at IS NOT NULL)::int,
         ROUND((COUNT(*) FILTER (WHERE i.triage_status='warm')::numeric / GREATEST(COUNT(*),1)) * 100, 1),
         ROUND((COUNT(*) FILTER (WHERE i.intro_meeting_at IS NOT NULL)::numeric / GREATEST(COUNT(*),1)) * 100, 1),
         ROUND(AVG(i.triage_score)::numeric, 1)
  FROM founder_investor_inbound_interest i
  LEFT JOIN founder_investor_inbound_sources s ON s.source_key = i.source_key
  GROUP BY COALESCE(s.display_name, i.source_key)
  ORDER BY 7 DESC NULLS LAST, 2 DESC;
END;
$fn$;

-- 6. Overdue next-actions
CREATE OR REPLACE FUNCTION founder_investor_overdue_actions()
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm_name text,
  next_action text,
  next_action_due timestamptz,
  days_overdue numeric,
  ladder_stage text,
  founder_priority int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.firm_name, i.next_action, i.next_action_due,
         ROUND((EXTRACT(EPOCH FROM (now() - i.next_action_due))/86400.0)::numeric, 1),
         i.ladder_stage, i.founder_priority
  FROM founder_investor_inbound_interest i
  WHERE i.next_action_due IS NOT NULL
    AND i.next_action_due < now()
    AND i.ladder_stage NOT IN ('closed','dead')
  ORDER BY i.next_action_due ASC;
END;
$fn$;

-- 7. Top warm leads (highest score, not dead/closed)
CREATE OR REPLACE FUNCTION founder_investor_top_warm_leads(p_limit int DEFAULT 25)
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm_name text,
  source_display text,
  triage_score int,
  ladder_stage text,
  check_size_max_rupees numeric,
  thesis_snippet text,
  last_touch_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.investor_name, i.firm_name,
         COALESCE(s.display_name, i.source_key),
         i.triage_score, i.ladder_stage, i.check_size_max_rupees,
         i.thesis_snippet, i.last_touch_at
  FROM founder_investor_inbound_interest i
  LEFT JOIN founder_investor_inbound_sources s ON s.source_key = i.source_key
  WHERE i.triage_status = 'warm'
    AND i.ladder_stage NOT IN ('closed','dead')
  ORDER BY i.triage_score DESC NULLS LAST, i.reached_out_at DESC
  LIMIT p_limit;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION founder_investor_inbound_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_inbound_kpis() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_inbound_queue(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_inbound_queue(int) TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_triage_backlog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_triage_backlog() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_ladder_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_ladder_breakdown() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_channel_rank() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_channel_rank() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_overdue_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_overdue_actions() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_investor_top_warm_leads(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_top_warm_leads(int) TO authenticated;

COMMIT;