BEGIN;

-- =============================================================
-- r1463 — Marketing Budget Tracker
-- Monthly marketing budget by channel; actual-vs-budget; CPL.
-- =============================================================

CREATE TABLE IF NOT EXISTS marketing_budget_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  channel text NOT NULL CHECK (channel IN ('linkedin_ads','content','webinars','events','google_ads','seo','referral','other')),
  budget_rupees bigint NOT NULL DEFAULT 0 CHECK (budget_rupees >= 0),
  owner text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (month_start, channel)
);

CREATE INDEX IF NOT EXISTS idx_mkt_budget_lines_month ON marketing_budget_lines(month_start DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_budget_lines_channel ON marketing_budget_lines(channel);

CREATE TABLE IF NOT EXISTS marketing_spend_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spent_on date NOT NULL,
  channel text NOT NULL CHECK (channel IN ('linkedin_ads','content','webinars','events','google_ads','seo','referral','other')),
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  leads_generated integer NOT NULL DEFAULT 0 CHECK (leads_generated >= 0),
  campaign text,
  vendor text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mkt_spend_spent_on ON marketing_spend_entries(spent_on DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_spend_channel ON marketing_spend_entries(channel);

ALTER TABLE marketing_budget_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketing_spend_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mkt_budget_lines_no_direct ON marketing_budget_lines;
CREATE POLICY mkt_budget_lines_no_direct ON marketing_budget_lines FOR ALL TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS mkt_spend_entries_no_direct ON marketing_spend_entries;
CREATE POLICY mkt_spend_entries_no_direct ON marketing_spend_entries FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- Audit log table (idempotent)
CREATE TABLE IF NOT EXISTS founder_action_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  payload jsonb,
  actor_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_action_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_action_log_no_direct ON founder_action_log;
CREATE POLICY founder_action_log_no_direct ON founder_action_log FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- =============================================================
-- log helpers
-- =============================================================

CREATE OR REPLACE FUNCTION log_founder_marketing_budget_set(p_month date, p_channel text, p_amount bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(action, payload, actor_id)
  VALUES ('marketing_budget_set', jsonb_build_object('month',p_month,'channel',p_channel,'amount',p_amount), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_marketing_budget_set(date,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_marketing_spend_added(p_entry_id uuid, p_channel text, p_amount bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(action, payload, actor_id)
  VALUES ('marketing_spend_added', jsonb_build_object('entry_id',p_entry_id,'channel',p_channel,'amount',p_amount), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_marketing_spend_added(uuid,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_marketing_overrun_flagged(p_month date, p_channel text, p_overrun bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(action, payload, actor_id)
  VALUES ('marketing_overrun_flagged', jsonb_build_object('month',p_month,'channel',p_channel,'overrun',p_overrun), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_marketing_overrun_flagged(date,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_marketing_cpl_review(p_month date)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(action, payload, actor_id)
  VALUES ('marketing_cpl_review', jsonb_build_object('month',p_month), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION log_founder_marketing_cpl_review(date) TO authenticated;

-- =============================================================
-- 7 SECDEF read RPCs
-- =============================================================

-- 1. KPI summary for current month
CREATE OR REPLACE FUNCTION founder_marketing_budget_kpis()
RETURNS TABLE (
  month_start date,
  total_budget_rupees bigint,
  total_spend_rupees bigint,
  total_leads bigint,
  utilization_pct numeric,
  overrun_rupees bigint,
  channels_over_budget bigint,
  channels_under_budget bigint,
  avg_cpl_rupees numeric,
  best_cpl_channel text,
  worst_cpl_channel text,
  spend_mtd_rupees bigint,
  spend_last_month_rupees bigint,
  mom_change_pct numeric,
  pacing_pct numeric,
  days_into_month integer,
  forecast_eom_spend_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_month date := date_trunc('month', now())::date;
  v_last  date := (date_trunc('month', now()) - interval '1 month')::date;
  v_days_in_month integer := EXTRACT(day FROM (date_trunc('month', now()) + interval '1 month - 1 day'))::int;
  v_days_into integer := EXTRACT(day FROM now())::int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH bud AS (
    SELECT channel, budget_rupees FROM marketing_budget_lines WHERE month_start = v_month
  ),
  spd AS (
    SELECT channel, SUM(amount_rupees)::bigint AS spend, SUM(leads_generated)::bigint AS leads
    FROM marketing_spend_entries
    WHERE spent_on >= v_month AND spent_on < (v_month + interval '1 month')::date
    GROUP BY channel
  ),
  joined AS (
    SELECT COALESCE(b.channel, s.channel) AS channel,
           COALESCE(b.budget_rupees,0)::bigint AS budget,
           COALESCE(s.spend,0)::bigint AS spend,
           COALESCE(s.leads,0)::bigint AS leads
    FROM bud b FULL OUTER JOIN spd s ON s.channel = b.channel
  ),
  last_month AS (
    SELECT COALESCE(SUM(amount_rupees),0)::bigint AS spend
    FROM marketing_spend_entries
    WHERE spent_on >= v_last AND spent_on < v_month
  ),
  totals AS (
    SELECT
      COALESCE(SUM(budget),0)::bigint AS tot_budget,
      COALESCE(SUM(spend),0)::bigint  AS tot_spend,
      COALESCE(SUM(leads),0)::bigint  AS tot_leads,
      COALESCE(SUM(GREATEST(spend - budget, 0)),0)::bigint AS overrun,
      COUNT(*) FILTER (WHERE spend > budget AND budget > 0)::bigint AS over_cnt,
      COUNT(*) FILTER (WHERE spend <= budget AND budget > 0)::bigint AS under_cnt
    FROM joined
  ),
  cpl AS (
    SELECT channel, CASE WHEN leads > 0 THEN (spend::numeric / leads) ELSE NULL END AS cpl
    FROM joined WHERE spend > 0
  )
  SELECT
    v_month,
    t.tot_budget,
    t.tot_spend,
    t.tot_leads,
    CASE WHEN t.tot_budget > 0 THEN ROUND(100.0 * t.tot_spend / t.tot_budget, 1) ELSE 0 END,
    t.overrun,
    t.over_cnt,
    t.under_cnt,
    (SELECT ROUND(AVG(cpl),0) FROM cpl WHERE cpl IS NOT NULL),
    (SELECT channel FROM cpl WHERE cpl IS NOT NULL ORDER BY cpl ASC LIMIT 1),
    (SELECT channel FROM cpl WHERE cpl IS NOT NULL ORDER BY cpl DESC LIMIT 1),
    t.tot_spend,
    (SELECT spend FROM last_month),
    CASE WHEN (SELECT spend FROM last_month) > 0
         THEN ROUND(100.0 * (t.tot_spend - (SELECT spend FROM last_month)) / (SELECT spend FROM last_month), 1)
         ELSE NULL END,
    CASE WHEN t.tot_budget > 0 AND v_days_in_month > 0
         THEN ROUND(100.0 * (t.tot_spend::numeric / NULLIF(t.tot_budget,0)) / (v_days_into::numeric / v_days_in_month), 1)
         ELSE NULL END,
    v_days_into,
    CASE WHEN v_days_into > 0
         THEN (t.tot_spend::numeric * v_days_in_month / v_days_into)::bigint
         ELSE 0 END
  FROM totals t;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_budget_kpis() TO authenticated;

-- 2. Budget vs actual by channel (current month)
CREATE OR REPLACE FUNCTION founder_marketing_channel_breakdown()
RETURNS TABLE (
  id text,
  channel text,
  budget_rupees bigint,
  spend_rupees bigint,
  leads bigint,
  utilization_pct numeric,
  overrun_rupees bigint,
  cpl_rupees numeric,
  status text,
  owner text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_month date := date_trunc('month', now())::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH bud AS (
    SELECT channel, budget_rupees, owner FROM marketing_budget_lines WHERE month_start = v_month
  ),
  spd AS (
    SELECT channel, SUM(amount_rupees)::bigint AS spend, SUM(leads_generated)::bigint AS leads
    FROM marketing_spend_entries
    WHERE spent_on >= v_month AND spent_on < (v_month + interval '1 month')::date
    GROUP BY channel
  )
  SELECT
    COALESCE(b.channel, s.channel) AS id,
    COALESCE(b.channel, s.channel) AS channel,
    COALESCE(b.budget_rupees,0)::bigint,
    COALESCE(s.spend,0)::bigint,
    COALESCE(s.leads,0)::bigint,
    CASE WHEN COALESCE(b.budget_rupees,0) > 0
         THEN ROUND(100.0 * COALESCE(s.spend,0) / b.budget_rupees, 1)
         ELSE NULL END,
    GREATEST(COALESCE(s.spend,0) - COALESCE(b.budget_rupees,0), 0)::bigint,
    CASE WHEN COALESCE(s.leads,0) > 0
         THEN ROUND(COALESCE(s.spend,0)::numeric / s.leads, 0)
         ELSE NULL END,
    CASE
      WHEN COALESCE(b.budget_rupees,0) = 0 THEN 'no_budget'
      WHEN COALESCE(s.spend,0) > b.budget_rupees THEN 'overrun'
      WHEN COALESCE(s.spend,0) >= (b.budget_rupees * 0.9) THEN 'near_cap'
      ELSE 'on_track'
    END,
    b.owner
  FROM bud b FULL OUTER JOIN spd s ON s.channel = b.channel
  ORDER BY COALESCE(s.spend,0) DESC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_channel_breakdown() TO authenticated;

-- 3. Monthly trend (last 6 months)
CREATE OR REPLACE FUNCTION founder_marketing_monthly_trend()
RETURNS TABLE (
  id text,
  month_label text,
  budget_rupees bigint,
  spend_rupees bigint,
  leads bigint,
  cpl_rupees numeric,
  utilization_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      (date_trunc('month', now()) - interval '5 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS m
  ),
  bud AS (
    SELECT m.m AS month_start, COALESCE(SUM(b.budget_rupees),0)::bigint AS budget
    FROM months m LEFT JOIN marketing_budget_lines b ON b.month_start = m.m
    GROUP BY m.m
  ),
  spd AS (
    SELECT m.m AS month_start,
           COALESCE(SUM(s.amount_rupees),0)::bigint AS spend,
           COALESCE(SUM(s.leads_generated),0)::bigint AS leads
    FROM months m
    LEFT JOIN marketing_spend_entries s
      ON s.spent_on >= m.m AND s.spent_on < (m.m + interval '1 month')::date
    GROUP BY m.m
  )
  SELECT
    to_char(b.month_start,'YYYY-MM') AS id,
    to_char(b.month_start,'Mon YYYY') AS month_label,
    b.budget,
    s.spend,
    s.leads,
    CASE WHEN s.leads > 0 THEN ROUND(s.spend::numeric / s.leads, 0) ELSE NULL END,
    CASE WHEN b.budget > 0 THEN ROUND(100.0 * s.spend / b.budget, 1) ELSE NULL END
  FROM bud b JOIN spd s USING (month_start)
  ORDER BY b.month_start ASC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_monthly_trend() TO authenticated;

-- 4. Overrun flags (current month)
CREATE OR REPLACE FUNCTION founder_marketing_overruns()
RETURNS TABLE (
  id text,
  channel text,
  budget_rupees bigint,
  spend_rupees bigint,
  overrun_rupees bigint,
  overrun_pct numeric,
  severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_month date := date_trunc('month', now())::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH bud AS (SELECT channel, budget_rupees FROM marketing_budget_lines WHERE month_start = v_month),
  spd AS (
    SELECT channel, SUM(amount_rupees)::bigint AS spend
    FROM marketing_spend_entries
    WHERE spent_on >= v_month AND spent_on < (v_month + interval '1 month')::date
    GROUP BY channel
  ),
  j AS (
    SELECT b.channel, b.budget_rupees, COALESCE(s.spend,0) AS spend
    FROM bud b LEFT JOIN spd s ON s.channel = b.channel
  )
  SELECT
    channel AS id,
    channel,
    budget_rupees,
    spend,
    (spend - budget_rupees)::bigint,
    CASE WHEN budget_rupees > 0 THEN ROUND(100.0 * (spend - budget_rupees) / budget_rupees, 1) ELSE NULL END,
    CASE
      WHEN spend > budget_rupees * 1.25 THEN 'severe'
      WHEN spend > budget_rupees * 1.10 THEN 'high'
      WHEN spend > budget_rupees THEN 'mild'
      ELSE 'ok'
    END
  FROM j
  WHERE spend > budget_rupees
  ORDER BY (spend - budget_rupees) DESC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_overruns() TO authenticated;

-- 5. CPL by channel current month
CREATE OR REPLACE FUNCTION founder_marketing_cpl_by_channel()
RETURNS TABLE (
  id text,
  channel text,
  spend_rupees bigint,
  leads bigint,
  cpl_rupees numeric,
  rank integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_month date := date_trunc('month', now())::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT channel,
           SUM(amount_rupees)::bigint AS spend,
           SUM(leads_generated)::bigint AS leads
    FROM marketing_spend_entries
    WHERE spent_on >= v_month AND spent_on < (v_month + interval '1 month')::date
    GROUP BY channel
  )
  SELECT
    channel,
    channel,
    spend,
    leads,
    CASE WHEN leads > 0 THEN ROUND(spend::numeric / leads, 0) ELSE NULL END,
    ROW_NUMBER() OVER (
      ORDER BY CASE WHEN leads > 0 THEN spend::numeric / leads ELSE 1e18 END ASC
    )::int
  FROM agg
  ORDER BY 6 ASC;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_cpl_by_channel() TO authenticated;

-- 6. Recent spend entries
CREATE OR REPLACE FUNCTION founder_marketing_recent_spend()
RETURNS TABLE (
  id uuid,
  spent_on date,
  channel text,
  amount_rupees bigint,
  leads_generated integer,
  campaign text,
  vendor text,
  cpl_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id, s.spent_on, s.channel, s.amount_rupees, s.leads_generated,
    s.campaign, s.vendor,
    CASE WHEN s.leads_generated > 0 THEN ROUND(s.amount_rupees::numeric / s.leads_generated, 0) ELSE NULL END
  FROM marketing_spend_entries s
  ORDER BY s.spent_on DESC, s.created_at DESC
  LIMIT 50;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_recent_spend() TO authenticated;

-- 7. Top campaigns by ROI (lowest CPL last 90d, min 5 leads)
CREATE OR REPLACE FUNCTION founder_marketing_top_campaigns()
RETURNS TABLE (
  id text,
  campaign text,
  channel text,
  spend_rupees bigint,
  leads bigint,
  cpl_rupees numeric,
  last_spent_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(campaign,'(untagged)') AS id,
    COALESCE(campaign,'(untagged)') AS campaign,
    channel,
    SUM(amount_rupees)::bigint,
    SUM(leads_generated)::bigint,
    CASE WHEN SUM(leads_generated) > 0
         THEN ROUND(SUM(amount_rupees)::numeric / SUM(leads_generated), 0)
         ELSE NULL END,
    MAX(spent_on)
  FROM marketing_spend_entries
  WHERE spent_on >= (now() - interval '90 days')::date
  GROUP BY 1, channel
  HAVING SUM(leads_generated) >= 5
  ORDER BY 6 ASC NULLS LAST
  LIMIT 25;
END; $$;
GRANT EXECUTE ON FUNCTION founder_marketing_top_campaigns() TO authenticated;

COMMIT;