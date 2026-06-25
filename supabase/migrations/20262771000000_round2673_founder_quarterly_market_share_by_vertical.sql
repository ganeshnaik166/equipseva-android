BEGIN;

-- ============================================================================
-- Round 2673 — Founder Quarterly Market Share by Vertical
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: quarterly market share snapshots per vertical
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS market_share_snapshots_r2673 CASCADE;
CREATE TABLE market_share_snapshots_r2673 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label            text NOT NULL,
  quarter_start            date NOT NULL,
  vertical                 text NOT NULL,
  our_share_pct            numeric(6,2) NOT NULL,
  top_competitor_name      text NOT NULL,
  top_competitor_share_pct numeric(6,2) NOT NULL,
  other_share_pct          numeric(6,2) NOT NULL,
  tam_rupees               bigint NOT NULL,
  our_revenue_rupees       bigint NOT NULL,
  growth_qoq_pct           numeric(6,2) NOT NULL,
  growth_yoy_pct           numeric(6,2) NOT NULL,
  wins_count               int NOT NULL DEFAULT 0,
  losses_count             int NOT NULL DEFAULT 0,
  pipeline_count           int NOT NULL DEFAULT 0,
  status                   text NOT NULL DEFAULT 'tracking',
  recommended_action       text,
  owner_email              text,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE market_share_snapshots_r2673 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON market_share_snapshots_r2673;
CREATE POLICY founder_all ON market_share_snapshots_r2673
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO market_share_snapshots_r2673
  (quarter_label, quarter_start, vertical, our_share_pct, top_competitor_name,
   top_competitor_share_pct, other_share_pct, tam_rupees, our_revenue_rupees,
   growth_qoq_pct, growth_yoy_pct, wins_count, losses_count, pipeline_count,
   status, recommended_action, owner_email, notes)
VALUES
  ('Q2-2026','2026-04-01','Dental Class A',18.50,'DentaCare Services',
   32.10,49.40,42000000,7770000,12.30,48.20,14,5,22,
   'gaining','double down on Hyderabad + Pune',
   'ops@getphyllo.com','strong NPS in Tier-1 cities'),
  ('Q2-2026','2026-04-01','Ophthalmology',9.80,'OptiServ India',
   41.20,49.00,28000000,2744000,4.10,18.50,7,8,12,
   'flat','rebuild ophthal SOPs + hire vertical lead',
   'ops@getphyllo.com','competitor undercut on AMC pricing'),
  ('Q2-2026','2026-04-01','Diagnostics Lab',24.40,'LabMech',
   29.60,46.00,55000000,13420000,18.70,62.40,21,4,30,
   'gaining','expand chain partnerships',
   'ops@getphyllo.com','BMC chain + Apollo pilot live'),
  ('Q2-2026','2026-04-01','Hospital ICU',6.20,'MedTech AMC',
   55.10,38.70,80000000,4960000,-3.20,7.10,3,9,8,
   'losing','pause direct sales; pursue OEM tie-up',
   'ops@getphyllo.com','OEMs lock channel; need partnership'),
  ('Q2-2026','2026-04-01','Veterinary',31.80,'VetGear Repair',
   22.40,45.80,12000000,3816000,22.50,71.30,11,2,9,
   'gaining','launch SaaS for chain vets',
   'ops@getphyllo.com','only Tier-1 player with cert ladder'),
  ('Q2-2026','2026-04-01','Imaging Centers',12.10,'ImageFix Bharat',
   38.40,49.50,38000000,4598000,7.80,29.40,9,6,15,
   'tracking','attend RSNA + radiologist webinars',
   'ops@getphyllo.com','need radiologist-network deal');

-- ---------------------------------------------------------------------------
-- Table 2: win/loss event log per vertical
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS market_share_events_r2673 CASCADE;
CREATE TABLE market_share_events_r2673 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id         uuid REFERENCES market_share_snapshots_r2673(id) ON DELETE CASCADE,
  vertical            text NOT NULL,
  event_type          text NOT NULL, -- win | loss | churn | renewal
  account_name        text NOT NULL,
  account_size_rupees bigint NOT NULL DEFAULT 0,
  competitor_name     text,
  reason              text,
  occurred_on         date NOT NULL DEFAULT CURRENT_DATE,
  owner_email         text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE market_share_events_r2673 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON market_share_events_r2673;
CREATE POLICY founder_all ON market_share_events_r2673
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO market_share_events_r2673
  (vertical, event_type, account_name, account_size_rupees, competitor_name,
   reason, occurred_on, owner_email)
VALUES
  ('Dental Class A','win','Smile Studio Hyderabad',480000,'DentaCare Services',
   'faster SLA + cert engineer','2026-05-12','ops@getphyllo.com'),
  ('Ophthalmology','loss','VisionPlus Bangalore',620000,'OptiServ India',
   'undercut on AMC by 18%','2026-04-21','ops@getphyllo.com'),
  ('Diagnostics Lab','win','BMC Lab Chain Pune',2200000,'LabMech',
   'chain bulk deal + uptime guarantee','2026-05-03','ops@getphyllo.com'),
  ('Hospital ICU','loss','Apollo ICU Mumbai',3100000,'MedTech AMC',
   'OEM exclusivity locked','2026-06-01','ops@getphyllo.com'),
  ('Veterinary','win','PawCare Chennai',180000,'VetGear Repair',
   'only certified vet-equipment engineer','2026-05-29','ops@getphyllo.com'),
  ('Imaging Centers','renewal','RadioScan Pune',950000,NULL,
   'NPS 9.2 + on-time SLA','2026-06-09','ops@getphyllo.com'),
  ('Diagnostics Lab','churn','MetroDx Delhi',420000,'LabMech',
   'price; service quality acceptable','2026-04-18','ops@getphyllo.com');

-- ===========================================================================
-- RPCs
-- ===========================================================================

-- 1) list snapshots
DROP FUNCTION IF EXISTS list_market_share_snapshots_r2673();
CREATE OR REPLACE FUNCTION list_market_share_snapshots_r2673()
RETURNS TABLE (
  id uuid, quarter_label text, vertical text, our_share_pct numeric,
  top_competitor_name text, top_competitor_share_pct numeric,
  other_share_pct numeric, tam_rupees bigint, our_revenue_rupees bigint,
  growth_qoq_pct numeric, growth_yoy_pct numeric,
  wins_count int, losses_count int, pipeline_count int,
  status text, recommended_action text, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.vertical, s.our_share_pct,
         s.top_competitor_name, s.top_competitor_share_pct,
         s.other_share_pct, s.tam_rupees, s.our_revenue_rupees,
         s.growth_qoq_pct, s.growth_yoy_pct,
         s.wins_count, s.losses_count, s.pipeline_count,
         s.status, s.recommended_action, s.owner_email
  FROM market_share_snapshots_r2673 s
  ORDER BY s.our_share_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_market_share_snapshots_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_market_share_snapshots_r2673() TO authenticated;

-- 2) top vertical focus (gaining + biggest growth)
DROP FUNCTION IF EXISTS top_market_share_focus_r2673();
CREATE OR REPLACE FUNCTION top_market_share_focus_r2673()
RETURNS TABLE (
  vertical text, our_share_pct numeric, growth_yoy_pct numeric,
  status text, recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.vertical, s.our_share_pct, s.growth_yoy_pct,
         s.status, s.recommended_action
  FROM market_share_snapshots_r2673 s
  WHERE s.status IN ('gaining','tracking')
  ORDER BY s.growth_yoy_pct DESC
  LIMIT 5;
END;
$$;
REVOKE EXECUTE ON FUNCTION top_market_share_focus_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION top_market_share_focus_r2673() TO authenticated;

-- 3) status funnel
DROP FUNCTION IF EXISTS market_share_status_funnel_r2673();
CREATE OR REPLACE FUNCTION market_share_status_funnel_r2673()
RETURNS TABLE (status text, vertical_count int, total_revenue_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status,
         COUNT(*)::int,
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint
  FROM market_share_snapshots_r2673 s
  GROUP BY s.status
  ORDER BY total_revenue_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION market_share_status_funnel_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION market_share_status_funnel_r2673() TO authenticated;

-- 4) monthly trend (events per month)
DROP FUNCTION IF EXISTS monthly_market_share_trend_r2673();
CREATE OR REPLACE FUNCTION monthly_market_share_trend_r2673()
RETURNS TABLE (month_start date, wins int, losses int,
               net_revenue_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', e.occurred_on)::date AS month_start,
         COUNT(*) FILTER (WHERE e.event_type = 'win')::int,
         COUNT(*) FILTER (WHERE e.event_type IN ('loss','churn'))::int,
         (COALESCE(SUM(e.account_size_rupees) FILTER (WHERE e.event_type='win'),0)
          - COALESCE(SUM(e.account_size_rupees) FILTER (WHERE e.event_type IN ('loss','churn')),0))::bigint
  FROM market_share_events_r2673 e
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION monthly_market_share_trend_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION monthly_market_share_trend_r2673() TO authenticated;

-- 5) quarterly trend (per quarter aggregate of snapshots)
DROP FUNCTION IF EXISTS quarterly_market_share_trend_r2673();
CREATE OR REPLACE FUNCTION quarterly_market_share_trend_r2673()
RETURNS TABLE (quarter_label text, avg_our_share_pct numeric,
               total_revenue_rupees bigint, avg_growth_yoy_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         ROUND(AVG(s.our_share_pct), 2),
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint,
         ROUND(AVG(s.growth_yoy_pct), 2)
  FROM market_share_snapshots_r2673 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION quarterly_market_share_trend_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION quarterly_market_share_trend_r2673() TO authenticated;

-- 6) summary KPIs
DROP FUNCTION IF EXISTS market_share_summary_r2673();
CREATE OR REPLACE FUNCTION market_share_summary_r2673()
RETURNS TABLE (
  total_verticals int,
  avg_our_share_pct numeric,
  total_tam_rupees bigint,
  total_our_revenue_rupees bigint,
  total_wins int,
  total_losses int,
  gaining_count int,
  losing_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         ROUND(AVG(s.our_share_pct), 2),
         COALESCE(SUM(s.tam_rupees),0)::bigint,
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint,
         COALESCE(SUM(s.wins_count),0)::int,
         COALESCE(SUM(s.losses_count),0)::int,
         COUNT(*) FILTER (WHERE s.status = 'gaining')::int,
         COUNT(*) FILTER (WHERE s.status = 'losing')::int
  FROM market_share_snapshots_r2673 s;
END;
$$;
REVOKE EXECUTE ON FUNCTION market_share_summary_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION market_share_summary_r2673() TO authenticated;

-- 7) owner load (per owner)
DROP FUNCTION IF EXISTS market_share_owner_load_r2673();
CREATE OR REPLACE FUNCTION market_share_owner_load_r2673()
RETURNS TABLE (owner_email text, vertical_count int,
               total_revenue_rupees bigint, losing_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(s.owner_email,'(unassigned)') AS owner_email,
         COUNT(*)::int,
         COALESCE(SUM(s.our_revenue_rupees),0)::bigint,
         COUNT(*) FILTER (WHERE s.status='losing')::int
  FROM market_share_snapshots_r2673 s
  GROUP BY COALESCE(s.owner_email,'(unassigned)')
  ORDER BY total_revenue_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION market_share_owner_load_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION market_share_owner_load_r2673() TO authenticated;

-- 8) recent win/loss events
DROP FUNCTION IF EXISTS recent_market_share_events_r2673();
CREATE OR REPLACE FUNCTION recent_market_share_events_r2673()
RETURNS TABLE (
  vertical text, event_type text, account_name text,
  account_size_rupees bigint, competitor_name text,
  reason text, occurred_on date, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.vertical, e.event_type, e.account_name,
         e.account_size_rupees, e.competitor_name,
         e.reason, e.occurred_on, e.owner_email
  FROM market_share_events_r2673 e
  ORDER BY e.occurred_on DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION recent_market_share_events_r2673() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION recent_market_share_events_r2673() TO authenticated;

COMMIT;
