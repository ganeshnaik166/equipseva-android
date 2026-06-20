BEGIN;

-- =====================================================================
-- r1451 — Marketing UTM Campaign Tracker
-- Log campaigns with UTM tags + spend + leads + attributed jobs; ROI per
-- campaign. Founder-only.
-- =====================================================================

-- ---------- Tables ---------------------------------------------------

CREATE TABLE IF NOT EXISTS marketing_utm_campaigns (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  channel         text NOT NULL CHECK (channel IN ('google_ads','meta_ads','linkedin','email','whatsapp','seo','event','partner','referral','other')),
  utm_source      text NOT NULL,
  utm_medium      text NOT NULL,
  utm_campaign    text NOT NULL,
  utm_term        text,
  utm_content     text,
  spend_rupees    integer NOT NULL DEFAULT 0 CHECK (spend_rupees >= 0),
  started_at      timestamptz NOT NULL DEFAULT now(),
  ended_at        timestamptz,
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','ended')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES auth.users(id),
  UNIQUE (utm_source, utm_medium, utm_campaign)
);

CREATE INDEX IF NOT EXISTS idx_mkt_utm_camp_status   ON marketing_utm_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_mkt_utm_camp_channel  ON marketing_utm_campaigns(channel);
CREATE INDEX IF NOT EXISTS idx_mkt_utm_camp_started  ON marketing_utm_campaigns(started_at DESC);

ALTER TABLE marketing_utm_campaigns ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS marketing_utm_touches (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id      uuid NOT NULL REFERENCES marketing_utm_campaigns(id) ON DELETE CASCADE,
  touched_at       timestamptz NOT NULL DEFAULT now(),
  touch_kind       text NOT NULL CHECK (touch_kind IN ('lead','signup','job_attributed','amc_attributed')),
  lead_email       text,
  lead_phone       text,
  organization_id  uuid REFERENCES organizations(id),
  repair_job_id    uuid REFERENCES repair_jobs(id),
  amc_contract_id  uuid REFERENCES amc_contracts(id),
  revenue_rupees   integer NOT NULL DEFAULT 0 CHECK (revenue_rupees >= 0),
  meta             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mkt_utm_touch_camp     ON marketing_utm_touches(campaign_id);
CREATE INDEX IF NOT EXISTS idx_mkt_utm_touch_kind     ON marketing_utm_touches(touch_kind);
CREATE INDEX IF NOT EXISTS idx_mkt_utm_touch_touched  ON marketing_utm_touches(touched_at DESC);

ALTER TABLE marketing_utm_touches ENABLE ROW LEVEL SECURITY;

-- ---------- SECDEF query RPCs (STABLE) -------------------------------

DROP FUNCTION IF EXISTS founder_utm_campaigns_overview();
CREATE OR REPLACE FUNCTION founder_utm_campaigns_overview()
RETURNS TABLE (
  id              uuid,
  name            text,
  channel         text,
  utm_source      text,
  utm_medium      text,
  utm_campaign    text,
  status          text,
  spend_rupees    integer,
  leads           bigint,
  signups         bigint,
  jobs_attributed bigint,
  amc_attributed  bigint,
  revenue_rupees  bigint,
  roi_pct         numeric,
  cpl_rupees      numeric,
  started_at      timestamptz,
  ended_at        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id, c.name, c.channel, c.utm_source, c.utm_medium, c.utm_campaign, c.status,
    c.spend_rupees,
    COALESCE(SUM(CASE WHEN t.touch_kind = 'lead' THEN 1 ELSE 0 END), 0)::bigint AS leads,
    COALESCE(SUM(CASE WHEN t.touch_kind = 'signup' THEN 1 ELSE 0 END), 0)::bigint AS signups,
    COALESCE(SUM(CASE WHEN t.touch_kind = 'job_attributed' THEN 1 ELSE 0 END), 0)::bigint AS jobs_attributed,
    COALESCE(SUM(CASE WHEN t.touch_kind = 'amc_attributed' THEN 1 ELSE 0 END), 0)::bigint AS amc_attributed,
    COALESCE(SUM(t.revenue_rupees), 0)::bigint AS revenue_rupees,
    CASE WHEN c.spend_rupees > 0
         THEN ROUND(((COALESCE(SUM(t.revenue_rupees),0)::numeric - c.spend_rupees) / c.spend_rupees) * 100.0, 1)
         ELSE NULL END AS roi_pct,
    CASE WHEN COALESCE(SUM(CASE WHEN t.touch_kind = 'lead' THEN 1 ELSE 0 END),0) > 0
         THEN ROUND(c.spend_rupees::numeric / SUM(CASE WHEN t.touch_kind = 'lead' THEN 1 ELSE 0 END), 1)
         ELSE NULL END AS cpl_rupees,
    c.started_at, c.ended_at
  FROM marketing_utm_campaigns c
  LEFT JOIN marketing_utm_touches t ON t.campaign_id = c.id
  GROUP BY c.id
  ORDER BY c.started_at DESC;
END $$;
REVOKE ALL ON FUNCTION founder_utm_campaigns_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_campaigns_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_kpis();
CREATE OR REPLACE FUNCTION founder_utm_kpis()
RETURNS TABLE (
  total_campaigns       bigint,
  active_campaigns      bigint,
  paused_campaigns      bigint,
  ended_campaigns       bigint,
  total_spend_rupees    bigint,
  spend_30d_rupees      bigint,
  total_leads           bigint,
  leads_30d             bigint,
  total_signups         bigint,
  total_jobs_attributed bigint,
  total_amc_attributed  bigint,
  total_revenue_rupees  bigint,
  revenue_30d_rupees    bigint,
  overall_roi_pct       numeric,
  avg_cpl_rupees        numeric,
  best_channel          text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_spend bigint;
  v_rev   bigint;
  v_leads bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(spend_rupees),0) INTO v_spend FROM marketing_utm_campaigns;
  SELECT COALESCE(SUM(revenue_rupees),0) INTO v_rev FROM marketing_utm_touches;
  SELECT COUNT(*) INTO v_leads FROM marketing_utm_touches WHERE touch_kind = 'lead';

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM marketing_utm_campaigns)::bigint,
    (SELECT COUNT(*) FROM marketing_utm_campaigns WHERE status='active')::bigint,
    (SELECT COUNT(*) FROM marketing_utm_campaigns WHERE status='paused')::bigint,
    (SELECT COUNT(*) FROM marketing_utm_campaigns WHERE status='ended')::bigint,
    v_spend,
    (SELECT COALESCE(SUM(spend_rupees),0)::bigint FROM marketing_utm_campaigns WHERE started_at >= now() - interval '30 days'),
    v_leads,
    (SELECT COUNT(*)::bigint FROM marketing_utm_touches WHERE touch_kind='lead' AND touched_at >= now() - interval '30 days'),
    (SELECT COUNT(*)::bigint FROM marketing_utm_touches WHERE touch_kind='signup'),
    (SELECT COUNT(*)::bigint FROM marketing_utm_touches WHERE touch_kind='job_attributed'),
    (SELECT COUNT(*)::bigint FROM marketing_utm_touches WHERE touch_kind='amc_attributed'),
    v_rev,
    (SELECT COALESCE(SUM(revenue_rupees),0)::bigint FROM marketing_utm_touches WHERE touched_at >= now() - interval '30 days'),
    CASE WHEN v_spend > 0 THEN ROUND(((v_rev::numeric - v_spend) / v_spend) * 100.0, 1) ELSE NULL END,
    CASE WHEN v_leads > 0 THEN ROUND(v_spend::numeric / v_leads, 1) ELSE NULL END,
    (SELECT c.channel
       FROM marketing_utm_campaigns c
       LEFT JOIN marketing_utm_touches t ON t.campaign_id = c.id
       GROUP BY c.channel
       ORDER BY COALESCE(SUM(t.revenue_rupees),0) DESC
       LIMIT 1);
END $$;
REVOKE ALL ON FUNCTION founder_utm_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_by_channel();
CREATE OR REPLACE FUNCTION founder_utm_by_channel()
RETURNS TABLE (
  id             text,
  channel        text,
  campaigns      bigint,
  spend_rupees   bigint,
  leads          bigint,
  jobs_attrib    bigint,
  revenue_rupees bigint,
  roi_pct        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.channel AS id,
    c.channel,
    COUNT(DISTINCT c.id)::bigint,
    COALESCE(SUM(c.spend_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE t.touch_kind='lead')::bigint,
    COUNT(*) FILTER (WHERE t.touch_kind='job_attributed')::bigint,
    COALESCE(SUM(t.revenue_rupees),0)::bigint,
    CASE WHEN COALESCE(SUM(c.spend_rupees),0) > 0
         THEN ROUND(((COALESCE(SUM(t.revenue_rupees),0)::numeric - SUM(c.spend_rupees)) / SUM(c.spend_rupees)) * 100.0, 1)
         ELSE NULL END
  FROM marketing_utm_campaigns c
  LEFT JOIN marketing_utm_touches t ON t.campaign_id = c.id
  GROUP BY c.channel
  ORDER BY COALESCE(SUM(t.revenue_rupees),0) DESC;
END $$;
REVOKE ALL ON FUNCTION founder_utm_by_channel() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_by_channel() TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_top_roi(integer);
CREATE OR REPLACE FUNCTION founder_utm_top_roi(p_limit integer DEFAULT 10)
RETURNS TABLE (
  id             uuid,
  name           text,
  channel        text,
  utm_campaign   text,
  spend_rupees   integer,
  revenue_rupees bigint,
  roi_pct        numeric,
  leads          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.name, c.channel, c.utm_campaign, c.spend_rupees,
         COALESCE(SUM(t.revenue_rupees),0)::bigint,
         CASE WHEN c.spend_rupees > 0
              THEN ROUND(((COALESCE(SUM(t.revenue_rupees),0)::numeric - c.spend_rupees) / c.spend_rupees) * 100.0, 1)
              ELSE NULL END,
         COUNT(*) FILTER (WHERE t.touch_kind='lead')::bigint
  FROM marketing_utm_campaigns c
  LEFT JOIN marketing_utm_touches t ON t.campaign_id = c.id
  WHERE c.spend_rupees > 0
  GROUP BY c.id
  ORDER BY (CASE WHEN c.spend_rupees > 0 THEN ((COALESCE(SUM(t.revenue_rupees),0)::numeric - c.spend_rupees) / c.spend_rupees) ELSE -1 END) DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION founder_utm_top_roi(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_top_roi(integer) TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_recent_touches(integer);
CREATE OR REPLACE FUNCTION founder_utm_recent_touches(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id              uuid,
  touched_at      timestamptz,
  touch_kind      text,
  campaign_name   text,
  channel         text,
  utm_campaign    text,
  lead_email      text,
  lead_phone      text,
  revenue_rupees  integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.touched_at, t.touch_kind, c.name, c.channel, c.utm_campaign,
         t.lead_email, t.lead_phone, t.revenue_rupees
  FROM marketing_utm_touches t
  JOIN marketing_utm_campaigns c ON c.id = t.campaign_id
  ORDER BY t.touched_at DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION founder_utm_recent_touches(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_recent_touches(integer) TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_spend_by_week();
CREATE OR REPLACE FUNCTION founder_utm_spend_by_week()
RETURNS TABLE (
  id               text,
  week_start       date,
  spend_rupees     bigint,
  revenue_rupees   bigint,
  leads            bigint,
  jobs_attributed  bigint,
  roi_pct          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH wk AS (
    SELECT generate_series(date_trunc('week', now() - interval '12 weeks')::date,
                           date_trunc('week', now())::date,
                           interval '1 week')::date AS week_start
  ),
  spend AS (
    SELECT date_trunc('week', started_at)::date AS week_start, SUM(spend_rupees)::bigint AS s
    FROM marketing_utm_campaigns
    GROUP BY 1
  ),
  rev AS (
    SELECT date_trunc('week', touched_at)::date AS week_start,
           SUM(revenue_rupees)::bigint AS r,
           COUNT(*) FILTER (WHERE touch_kind='lead')::bigint AS l,
           COUNT(*) FILTER (WHERE touch_kind='job_attributed')::bigint AS j
    FROM marketing_utm_touches
    GROUP BY 1
  )
  SELECT to_char(wk.week_start,'YYYY-MM-DD') AS id,
         wk.week_start,
         COALESCE(spend.s,0),
         COALESCE(rev.r,0),
         COALESCE(rev.l,0),
         COALESCE(rev.j,0),
         CASE WHEN COALESCE(spend.s,0) > 0
              THEN ROUND(((COALESCE(rev.r,0)::numeric - spend.s) / spend.s) * 100.0, 1)
              ELSE NULL END
  FROM wk
  LEFT JOIN spend ON spend.week_start = wk.week_start
  LEFT JOIN rev   ON rev.week_start   = wk.week_start
  ORDER BY wk.week_start DESC;
END $$;
REVOKE ALL ON FUNCTION founder_utm_spend_by_week() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_spend_by_week() TO authenticated;

DROP FUNCTION IF EXISTS founder_utm_underperformers();
CREATE OR REPLACE FUNCTION founder_utm_underperformers()
RETURNS TABLE (
  id             uuid,
  name           text,
  channel        text,
  utm_campaign   text,
  spend_rupees   integer,
  revenue_rupees bigint,
  roi_pct        numeric,
  leads          bigint,
  flag           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.name, c.channel, c.utm_campaign, c.spend_rupees,
         COALESCE(SUM(t.revenue_rupees),0)::bigint AS rev,
         CASE WHEN c.spend_rupees > 0
              THEN ROUND(((COALESCE(SUM(t.revenue_rupees),0)::numeric - c.spend_rupees) / c.spend_rupees) * 100.0, 1)
              ELSE NULL END AS roi,
         COUNT(*) FILTER (WHERE t.touch_kind='lead')::bigint AS leads,
         CASE
           WHEN c.spend_rupees > 0 AND COALESCE(SUM(t.revenue_rupees),0) = 0 THEN 'zero_revenue'
           WHEN c.spend_rupees > 0 AND COALESCE(SUM(t.revenue_rupees),0) < c.spend_rupees THEN 'negative_roi'
           WHEN c.spend_rupees > 0 AND COUNT(*) FILTER (WHERE t.touch_kind='lead') = 0 THEN 'no_leads'
           ELSE 'ok'
         END AS flag
  FROM marketing_utm_campaigns c
  LEFT JOIN marketing_utm_touches t ON t.campaign_id = c.id
  WHERE c.spend_rupees > 0
  GROUP BY c.id
  HAVING (COALESCE(SUM(t.revenue_rupees),0) < c.spend_rupees)
      OR COUNT(*) FILTER (WHERE t.touch_kind='lead') = 0
  ORDER BY (c.spend_rupees - COALESCE(SUM(t.revenue_rupees),0)) DESC;
END $$;
REVOKE ALL ON FUNCTION founder_utm_underperformers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_utm_underperformers() TO authenticated;

-- ---------- Write helpers (VOLATILE SECDEF) --------------------------

DROP FUNCTION IF EXISTS log_founder_utm_campaign_create(text, text, text, text, text, text, text, integer, text);
CREATE OR REPLACE FUNCTION log_founder_utm_campaign_create(
  p_name text,
  p_channel text,
  p_utm_source text,
  p_utm_medium text,
  p_utm_campaign text,
  p_utm_term text,
  p_utm_content text,
  p_spend_rupees integer,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO marketing_utm_campaigns (name, channel, utm_source, utm_medium, utm_campaign, utm_term, utm_content, spend_rupees, notes, created_by)
  VALUES (p_name, p_channel, p_utm_source, p_utm_medium, p_utm_campaign, p_utm_term, p_utm_content, COALESCE(p_spend_rupees,0), p_notes, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_utm_campaign_create(text, text, text, text, text, text, text, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_utm_campaign_create(text, text, text, text, text, text, text, integer, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_utm_campaign_update_spend(uuid, integer);
CREATE OR REPLACE FUNCTION log_founder_utm_campaign_update_spend(p_id uuid, p_spend_rupees integer)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE marketing_utm_campaigns SET spend_rupees = COALESCE(p_spend_rupees,0) WHERE id = p_id;
  RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION log_founder_utm_campaign_update_spend(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_utm_campaign_update_spend(uuid, integer) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_utm_campaign_set_status(uuid, text);
CREATE OR REPLACE FUNCTION log_founder_utm_campaign_set_status(p_id uuid, p_status text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','paused','ended') THEN RAISE EXCEPTION 'bad_status'; END IF;
  UPDATE marketing_utm_campaigns
     SET status = p_status,
         ended_at = CASE WHEN p_status = 'ended' THEN now() ELSE ended_at END
   WHERE id = p_id;
  RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION log_founder_utm_campaign_set_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_utm_campaign_set_status(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_utm_touch(uuid, text, text, text, integer);
CREATE OR REPLACE FUNCTION log_founder_utm_touch(
  p_campaign_id uuid,
  p_touch_kind text,
  p_lead_email text,
  p_lead_phone text,
  p_revenue_rupees integer
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_touch_kind NOT IN ('lead','signup','job_attributed','amc_attributed') THEN RAISE EXCEPTION 'bad_kind'; END IF;
  INSERT INTO marketing_utm_touches (campaign_id, touch_kind, lead_email, lead_phone, revenue_rupees)
  VALUES (p_campaign_id, p_touch_kind, p_lead_email, p_lead_phone, COALESCE(p_revenue_rupees,0))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION log_founder_utm_touch(uuid, text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_utm_touch(uuid, text, text, text, integer) TO authenticated;

COMMIT;