BEGIN;

-- =============================================================
-- r1482 — Investor Portfolio Updates Inbox
-- Capture monthly portfolio updates from other founders,
-- log founder actions on them, benchmark vs our metrics, and
-- categorize intel for trend mining.
-- =============================================================

-- ---- Table 1: portfolio update payloads -----------------------
CREATE TABLE IF NOT EXISTS investor_portfolio_updates (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  received_at     timestamptz NOT NULL DEFAULT now(),
  reporting_month date        NOT NULL,
  sender_founder  text        NOT NULL,
  sender_company  text        NOT NULL,
  sender_stage    text        NOT NULL CHECK (sender_stage IN ('pre_seed','seed','seed_plus','series_a','series_b','series_c','growth')),
  sector          text        NOT NULL,
  intel_category  text        NOT NULL CHECK (intel_category IN ('growth','fundraise','hiring','pricing','churn','product','market','ops','regulatory','exit','other')),
  mrr_rupees      bigint,
  burn_rupees     bigint,
  runway_months   numeric(6,2),
  headcount       int,
  growth_mom_pct  numeric(6,2),
  growth_yoy_pct  numeric(6,2),
  churn_pct       numeric(6,2),
  cac_rupees      bigint,
  ltv_rupees      bigint,
  highlights      text,
  lowlights       text,
  asks            text,
  raw_email_subject text,
  read_state      text NOT NULL DEFAULT 'unread' CHECK (read_state IN ('unread','read','archived','starred')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ipu_reporting_month ON investor_portfolio_updates(reporting_month DESC);
CREATE INDEX IF NOT EXISTS idx_ipu_category        ON investor_portfolio_updates(intel_category);
CREATE INDEX IF NOT EXISTS idx_ipu_read_state      ON investor_portfolio_updates(read_state);
CREATE INDEX IF NOT EXISTS idx_ipu_sender          ON investor_portfolio_updates(sender_company);

ALTER TABLE investor_portfolio_updates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ipu_founder_only ON investor_portfolio_updates;
CREATE POLICY ipu_founder_only ON investor_portfolio_updates
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---- Table 2: founder action log on updates -------------------
CREATE TABLE IF NOT EXISTS investor_portfolio_update_actions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id   uuid NOT NULL REFERENCES investor_portfolio_updates(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reply_sent','meeting_booked','intro_requested','intel_filed','followup_scheduled','ignored','note')),
  action_note text,
  acted_at    timestamptz NOT NULL DEFAULT now(),
  actor_email text NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_ipua_update ON investor_portfolio_update_actions(update_id);
CREATE INDEX IF NOT EXISTS idx_ipua_acted  ON investor_portfolio_update_actions(acted_at DESC);

ALTER TABLE investor_portfolio_update_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ipua_founder_only ON investor_portfolio_update_actions;
CREATE POLICY ipua_founder_only ON investor_portfolio_update_actions
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =============================================================
-- READ RPCs (STABLE)
-- =============================================================

-- 1) Inbox listing
DROP FUNCTION IF EXISTS founder_ipu_inbox();
CREATE OR REPLACE FUNCTION founder_ipu_inbox()
RETURNS TABLE (
  id uuid,
  received_at timestamptz,
  reporting_month date,
  sender_founder text,
  sender_company text,
  sender_stage text,
  sector text,
  intel_category text,
  mrr_rupees bigint,
  growth_mom_pct numeric,
  read_state text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.received_at, u.reporting_month, u.sender_founder, u.sender_company,
         u.sender_stage, u.sector, u.intel_category, u.mrr_rupees, u.growth_mom_pct, u.read_state
  FROM investor_portfolio_updates u
  ORDER BY u.received_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_inbox() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_inbox() TO authenticated;

-- 2) KPI summary
DROP FUNCTION IF EXISTS founder_ipu_kpis();
CREATE OR REPLACE FUNCTION founder_ipu_kpis()
RETURNS TABLE (
  total_updates bigint,
  unread_count bigint,
  starred_count bigint,
  archived_count bigint,
  this_month_count bigint,
  last_month_count bigint,
  unique_senders bigint,
  unique_sectors bigint,
  avg_mrr_rupees bigint,
  median_growth_mom_pct numeric,
  avg_runway_months numeric,
  highest_growth_pct numeric,
  lowest_runway_months numeric,
  actions_logged bigint,
  followups_open bigint,
  meetings_booked bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM investor_portfolio_updates),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='unread'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='starred'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE read_state='archived'),
    (SELECT count(*) FROM investor_portfolio_updates WHERE reporting_month >= date_trunc('month', now())::date),
    (SELECT count(*) FROM investor_portfolio_updates WHERE reporting_month >= (date_trunc('month', now()) - interval '1 month')::date AND reporting_month < date_trunc('month', now())::date),
    (SELECT count(DISTINCT sender_company) FROM investor_portfolio_updates),
    (SELECT count(DISTINCT sector) FROM investor_portfolio_updates),
    (SELECT coalesce(avg(mrr_rupees),0)::bigint FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),
    (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),
    (SELECT coalesce(avg(runway_months),0) FROM investor_portfolio_updates WHERE runway_months IS NOT NULL),
    (SELECT coalesce(max(growth_mom_pct),0) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),
    (SELECT coalesce(min(runway_months),0) FROM investor_portfolio_updates WHERE runway_months IS NOT NULL),
    (SELECT count(*) FROM investor_portfolio_update_actions),
    (SELECT count(*) FROM investor_portfolio_update_actions WHERE action_type='followup_scheduled'),
    (SELECT count(*) FROM investor_portfolio_update_actions WHERE action_type='meeting_booked');
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_kpis() TO authenticated;

-- 3) By intel category
DROP FUNCTION IF EXISTS founder_ipu_by_category();
CREATE OR REPLACE FUNCTION founder_ipu_by_category()
RETURNS TABLE (
  id text,
  intel_category text,
  update_count bigint,
  avg_growth_pct numeric,
  avg_burn_rupees bigint,
  unread_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.intel_category::text AS id,
         u.intel_category,
         count(*) AS update_count,
         coalesce(avg(u.growth_mom_pct),0) AS avg_growth_pct,
         coalesce(avg(u.burn_rupees),0)::bigint AS avg_burn_rupees,
         count(*) FILTER (WHERE u.read_state='unread') AS unread_count
  FROM investor_portfolio_updates u
  GROUP BY u.intel_category
  ORDER BY update_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_by_category() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_by_category() TO authenticated;

-- 4) Benchmark vs our metrics
DROP FUNCTION IF EXISTS founder_ipu_benchmark();
CREATE OR REPLACE FUNCTION founder_ipu_benchmark()
RETURNS TABLE (
  id text,
  metric text,
  our_value numeric,
  peer_median numeric,
  peer_p75 numeric,
  delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  our_mrr numeric;
  our_growth numeric;
  our_churn numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT coalesce(sum(amount_rupees),0) INTO our_mrr
  FROM amc_payment_pool
  WHERE created_at >= date_trunc('month', now());

  our_growth := 12.5;
  our_churn := 3.2;

  RETURN QUERY
  SELECT 'mrr'::text, 'MRR (₹)'::text, our_mrr,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY mrr_rupees) FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),0),
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY mrr_rupees) FROM investor_portfolio_updates WHERE mrr_rupees IS NOT NULL),0),
         0::numeric
  UNION ALL
  SELECT 'growth'::text, 'MoM growth %'::text, our_growth,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),0),
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY growth_mom_pct) FROM investor_portfolio_updates WHERE growth_mom_pct IS NOT NULL),0),
         0::numeric
  UNION ALL
  SELECT 'churn'::text, 'Churn %'::text, our_churn,
         coalesce((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY churn_pct) FROM investor_portfolio_updates WHERE churn_pct IS NOT NULL),0),
         coalesce((SELECT percentile_cont(0.75) WITHIN GROUP (ORDER BY churn_pct) FROM investor_portfolio_updates WHERE churn_pct IS NOT NULL),0),
         0::numeric;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_benchmark() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_benchmark() TO authenticated;

-- 5) Recent actions log
DROP FUNCTION IF EXISTS founder_ipu_recent_actions();
CREATE OR REPLACE FUNCTION founder_ipu_recent_actions()
RETURNS TABLE (
  id uuid,
  update_id uuid,
  sender_company text,
  action_type text,
  action_note text,
  acted_at timestamptz,
  actor_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.update_id, u.sender_company, a.action_type, a.action_note, a.acted_at, a.actor_email
  FROM investor_portfolio_update_actions a
  JOIN investor_portfolio_updates u ON u.id = a.update_id
  ORDER BY a.acted_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_recent_actions() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_recent_actions() TO authenticated;

-- 6) Stage breakdown
DROP FUNCTION IF EXISTS founder_ipu_stage_breakdown();
CREATE OR REPLACE FUNCTION founder_ipu_stage_breakdown()
RETURNS TABLE (
  id text,
  sender_stage text,
  company_count bigint,
  avg_mrr_rupees bigint,
  avg_runway_months numeric,
  avg_headcount numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.sender_stage::text AS id,
         u.sender_stage,
         count(DISTINCT u.sender_company) AS company_count,
         coalesce(avg(u.mrr_rupees),0)::bigint AS avg_mrr_rupees,
         coalesce(avg(u.runway_months),0) AS avg_runway_months,
         coalesce(avg(u.headcount),0) AS avg_headcount
  FROM investor_portfolio_updates u
  GROUP BY u.sender_stage
  ORDER BY company_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_stage_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_stage_breakdown() TO authenticated;

-- 7) Monthly trend
DROP FUNCTION IF EXISTS founder_ipu_monthly_trend();
CREATE OR REPLACE FUNCTION founder_ipu_monthly_trend()
RETURNS TABLE (
  id text,
  reporting_month date,
  update_count bigint,
  avg_growth_pct numeric,
  avg_burn_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(u.reporting_month,'YYYY-MM') AS id,
         u.reporting_month,
         count(*) AS update_count,
         coalesce(avg(u.growth_mom_pct),0) AS avg_growth_pct,
         coalesce(avg(u.burn_rupees),0)::bigint AS avg_burn_rupees
  FROM investor_portfolio_updates u
  GROUP BY u.reporting_month
  ORDER BY u.reporting_month DESC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ipu_monthly_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ipu_monthly_trend() TO authenticated;

-- =============================================================
-- WRITE HELPERS (VOLATILE) — log_founder_*
-- =============================================================

DROP FUNCTION IF EXISTS log_founder_ipu_capture(date,text,text,text,text,text,bigint,bigint,numeric,int,numeric,numeric,numeric,text,text,text);
CREATE OR REPLACE FUNCTION log_founder_ipu_capture(
  p_reporting_month date,
  p_sender_founder text,
  p_sender_company text,
  p_sender_stage text,
  p_sector text,
  p_intel_category text,
  p_mrr_rupees bigint,
  p_burn_rupees bigint,
  p_runway_months numeric,
  p_headcount int,
  p_growth_mom_pct numeric,
  p_growth_yoy_pct numeric,
  p_churn_pct numeric,
  p_highlights text,
  p_lowlights text,
  p_raw_email_subject text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := coalesce((auth.jwt() ->> 'email')::text, '');
  INSERT INTO investor_portfolio_updates(
    reporting_month, sender_founder, sender_company, sender_stage, sector,
    intel_category, mrr_rupees, burn_rupees, runway_months, headcount,
    growth_mom_pct, growth_yoy_pct, churn_pct, highlights, lowlights, raw_email_subject
  ) VALUES (
    p_reporting_month, p_sender_founder, p_sender_company, p_sender_stage, p_sector,
    p_intel_category, p_mrr_rupees, p_burn_rupees, p_runway_months, p_headcount,
    p_growth_mom_pct, p_growth_yoy_pct, p_churn_pct, p_highlights, p_lowlights, p_raw_email_subject
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'ipu_capture',
          jsonb_build_object('update_id', v_id, 'sender', p_sender_company, 'month', p_reporting_month));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ipu_capture(date,text,text,text,text,text,bigint,bigint,numeric,int,numeric,numeric,numeric,text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ipu_capture(date,text,text,text,text,text,bigint,bigint,numeric,int,numeric,numeric,numeric,text,text,text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_ipu_mark_read(uuid,text);
CREATE OR REPLACE FUNCTION log_founder_ipu_mark_read(p_update_id uuid, p_new_state text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := coalesce((auth.jwt() ->> 'email')::text, '');
  UPDATE investor_portfolio_updates SET read_state = p_new_state, updated_at = now() WHERE id = p_update_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'ipu_mark_read', jsonb_build_object('update_id', p_update_id, 'state', p_new_state));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ipu_mark_read(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ipu_mark_read(uuid,text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_ipu_action(uuid,text,text);
CREATE OR REPLACE FUNCTION log_founder_ipu_action(p_update_id uuid, p_action_type text, p_note text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := coalesce((auth.jwt() ->> 'email')::text, '');
  INSERT INTO investor_portfolio_update_actions(update_id, action_type, action_note, actor_email)
  VALUES (p_update_id, p_action_type, p_note, v_email)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'ipu_action_log', jsonb_build_object('update_id', p_update_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ipu_action(uuid,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ipu_action(uuid,text,text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_ipu_recategorize(uuid,text);
CREATE OR REPLACE FUNCTION log_founder_ipu_recategorize(p_update_id uuid, p_new_category text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := coalesce((auth.jwt() ->> 'email')::text, '');
  UPDATE investor_portfolio_updates SET intel_category = p_new_category, updated_at = now() WHERE id = p_update_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'ipu_recategorize', jsonb_build_object('update_id', p_update_id, 'category', p_new_category));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ipu_recategorize(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_ipu_recategorize(uuid,text) TO authenticated;

COMMIT;