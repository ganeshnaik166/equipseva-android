BEGIN;

-- ============================================================================
-- Round 2837 — Founder Quarterly Strategic Personal Branding Builds
-- Tracks channel x content x reach x follower delta x commercial signal x verdict
-- ============================================================================

-- Table 1: branding builds (one row per channel/content build)
CREATE TABLE IF NOT EXISTS founder_branding_builds_r2837 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  channel text NOT NULL CHECK (channel IN ('linkedin','twitter','youtube','podcast','newsletter','medium','press','conference')),
  content_type text NOT NULL CHECK (content_type IN ('thought_leadership','product_demo','customer_story','technical_deep_dive','founder_journey','industry_analysis','launch_announcement','interview')),
  title text NOT NULL,
  reach_count int NOT NULL DEFAULT 0,
  follower_delta int NOT NULL DEFAULT 0,
  engagement_rate numeric(6,3) NOT NULL DEFAULT 0,
  commercial_signal text NOT NULL CHECK (commercial_signal IN ('inbound_lead','demo_request','investor_dm','press_pickup','partner_intro','hire_apply','none')),
  signal_count int NOT NULL DEFAULT 0,
  verdict text NOT NULL CHECK (verdict IN ('keep_double_down','keep_iterate','kill','test_again')),
  effort_hours numeric(6,2) NOT NULL DEFAULT 0,
  published_at date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_branding_builds_r2837 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_branding_builds_r2837;
CREATE POLICY founder_all ON founder_branding_builds_r2837
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO founder_branding_builds_r2837 (quarter, channel, content_type, title, reach_count, follower_delta, engagement_rate, commercial_signal, signal_count, verdict, effort_hours, published_at, notes) VALUES
  ('Q2-2026','linkedin','founder_journey','Why I bet medical equipment uptime in tier-2 India',48200,1240,7.420,'inbound_lead',14,'keep_double_down',6.50,'2026-04-08'::date,'top post of quarter; 14 hospital inbound'),
  ('Q2-2026','twitter','technical_deep_dive','How we route 412 engineers across 8 cities with one SQL view',12400,180,3.110,'hire_apply',7,'keep_iterate',3.00,'2026-04-22'::date,'engineering hires followed'),
  ('Q2-2026','youtube','product_demo','Live AMC bulk enrollment for 40-bed hospital chain',8900,92,5.840,'demo_request',6,'keep_iterate',12.00,'2026-05-04'::date,'two chain demos booked off this'),
  ('Q2-2026','podcast','industry_analysis','Guest: Indian medtech post-PLI scheme reality check',22100,640,4.510,'investor_dm',9,'keep_double_down',4.50,'2026-05-19'::date,'three sub-angel intros'),
  ('Q2-2026','newsletter','customer_story','Apollo Hyderabad: 92 percent first-visit fix rate at six months',5400,310,11.200,'partner_intro',4,'keep_iterate',5.00,'2026-06-02'::date,'partner intros from chains'),
  ('Q2-2026','medium','industry_analysis','The unit economics of 24-hour MRI uptime in India',3100,42,2.100,'none',0,'kill',8.00,'2026-04-15'::date,'low signal; long form did not work here'),
  ('Q2-2026','press','launch_announcement','EquipSeva closes seed for hospital equipment uptime',180000,2100,0.480,'press_pickup',12,'keep_double_down',2.00,'2026-05-28'::date,'inc42 yourstory pickup'),
  ('Q2-2026','conference','thought_leadership','NABH summit keynote: equipment downtime is patient safety',1200,88,18.400,'inbound_lead',11,'keep_double_down',16.00,'2026-06-14'::date,'highest signal per reach');

-- Table 2: quarterly channel rollup
CREATE TABLE IF NOT EXISTS founder_branding_channel_rollup_r2837 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  channel text NOT NULL,
  total_reach int NOT NULL DEFAULT 0,
  total_follower_delta int NOT NULL DEFAULT 0,
  total_signals int NOT NULL DEFAULT 0,
  total_effort_hours numeric(8,2) NOT NULL DEFAULT 0,
  signals_per_hour numeric(8,3) NOT NULL DEFAULT 0,
  channel_verdict text NOT NULL CHECK (channel_verdict IN ('scale','maintain','kill','retest')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quarter, channel)
);

ALTER TABLE founder_branding_channel_rollup_r2837 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_branding_channel_rollup_r2837;
CREATE POLICY founder_all ON founder_branding_channel_rollup_r2837
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO founder_branding_channel_rollup_r2837 (quarter, channel, total_reach, total_follower_delta, total_signals, total_effort_hours, signals_per_hour, channel_verdict) VALUES
  ('Q2-2026','linkedin',48200,1240,14,6.50,2.154,'scale'),
  ('Q2-2026','twitter',12400,180,7,3.00,2.333,'maintain'),
  ('Q2-2026','youtube',8900,92,6,12.00,0.500,'maintain'),
  ('Q2-2026','podcast',22100,640,9,4.50,2.000,'scale'),
  ('Q2-2026','newsletter',5400,310,4,5.00,0.800,'maintain'),
  ('Q2-2026','medium',3100,42,0,8.00,0.000,'kill'),
  ('Q2-2026','press',180000,2100,12,2.00,6.000,'scale'),
  ('Q2-2026','conference',1200,88,11,16.00,0.688,'scale');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS rpc_r2837_kpis();
CREATE OR REPLACE FUNCTION rpc_r2837_kpis()
RETURNS TABLE (
  total_builds int,
  total_reach bigint,
  total_follower_delta bigint,
  total_signals bigint,
  total_effort_hours numeric,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::int,
         COALESCE(sum(reach_count),0)::bigint,
         COALESCE(sum(follower_delta),0)::bigint,
         COALESCE(sum(signal_count),0)::bigint,
         COALESCE(sum(effort_hours),0)::numeric,
         COALESCE(avg(engagement_rate),0)::numeric
  FROM founder_branding_builds_r2837;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_kpis() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_builds();
CREATE OR REPLACE FUNCTION rpc_r2837_builds()
RETURNS SETOF founder_branding_builds_r2837
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM founder_branding_builds_r2837 ORDER BY published_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_builds() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_builds() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_channel_rollup();
CREATE OR REPLACE FUNCTION rpc_r2837_channel_rollup()
RETURNS SETOF founder_branding_channel_rollup_r2837
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM founder_branding_channel_rollup_r2837 ORDER BY signals_per_hour DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_channel_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_channel_rollup() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_top_builds();
CREATE OR REPLACE FUNCTION rpc_r2837_top_builds()
RETURNS TABLE (
  title text,
  channel text,
  reach_count int,
  signal_count int,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.title, b.channel, b.reach_count, b.signal_count, b.verdict
  FROM founder_branding_builds_r2837 b
  ORDER BY b.signal_count DESC, b.reach_count DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_top_builds() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_top_builds() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_verdict_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2837_verdict_breakdown()
RETURNS TABLE (
  verdict text,
  build_count int,
  total_reach bigint,
  total_signals bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.verdict,
         count(*)::int,
         COALESCE(sum(b.reach_count),0)::bigint,
         COALESCE(sum(b.signal_count),0)::bigint
  FROM founder_branding_builds_r2837 b
  GROUP BY b.verdict
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_verdict_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_signal_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2837_signal_breakdown()
RETURNS TABLE (
  commercial_signal text,
  build_count int,
  total_signal_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.commercial_signal,
         count(*)::int,
         COALESCE(sum(b.signal_count),0)::bigint
  FROM founder_branding_builds_r2837 b
  GROUP BY b.commercial_signal
  ORDER BY sum(b.signal_count) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_signal_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_signal_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_efficiency();
CREATE OR REPLACE FUNCTION rpc_r2837_efficiency()
RETURNS TABLE (
  channel text,
  signals_per_hour numeric,
  channel_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.channel, r.signals_per_hour, r.channel_verdict
  FROM founder_branding_channel_rollup_r2837 r
  ORDER BY r.signals_per_hour DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_efficiency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_efficiency() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2837_content_type_mix();
CREATE OR REPLACE FUNCTION rpc_r2837_content_type_mix()
RETURNS TABLE (
  content_type text,
  build_count int,
  total_reach bigint,
  total_signals bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.content_type,
         count(*)::int,
         COALESCE(sum(b.reach_count),0)::bigint,
         COALESCE(sum(b.signal_count),0)::bigint
  FROM founder_branding_builds_r2837 b
  GROUP BY b.content_type
  ORDER BY sum(b.signal_count) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2837_content_type_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2837_content_type_mix() TO authenticated;

COMMIT;
