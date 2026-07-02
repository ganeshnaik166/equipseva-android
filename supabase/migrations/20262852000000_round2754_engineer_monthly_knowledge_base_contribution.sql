BEGIN;

-- =========================================================================
-- Round 2754: Engineer Monthly Knowledge Base Contribution
-- Tracks engineer KB articles, topics, views, kudos, resolution saves, rewards
-- =========================================================================

-- ---- TABLE 1: KB Articles authored by engineers --------------------------
CREATE TABLE IF NOT EXISTS engineer_kb_articles_r2754 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id     uuid NOT NULL,
  engineer_name   text NOT NULL,
  article_title   text NOT NULL,
  topic           text NOT NULL CHECK (topic IN ('ventilator','dialysis','ct_scan','mri','ultrasound','ecg','autoclave','infusion_pump','patient_monitor','xray')),
  device_brand    text NOT NULL,
  difficulty      text NOT NULL CHECK (difficulty IN ('basic','intermediate','advanced','expert')),
  published_month date NOT NULL,
  view_count      integer NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  kudos_count     integer NOT NULL DEFAULT 0 CHECK (kudos_count >= 0),
  resolution_saves integer NOT NULL DEFAULT 0 CHECK (resolution_saves >= 0),
  reward_rupees   integer NOT NULL DEFAULT 0 CHECK (reward_rupees >= 0),
  status          text NOT NULL CHECK (status IN ('draft','under_review','published','featured','archived')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_kb_articles_r2754 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_kb_articles_r2754;
CREATE POLICY founder_all ON engineer_kb_articles_r2754
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_kb_articles_r2754 (engineer_id, engineer_name, article_title, topic, device_brand, difficulty, published_month, view_count, kudos_count, resolution_saves, reward_rupees, status) VALUES
  (gen_random_uuid(), 'Ravi Kumar',    'Ventilator PEEP calibration drift fix',     'ventilator',      'Drager Evita',        'advanced',     '2026-06-01'::date, 1842,  94, 38, 8500,  'featured'),
  (gen_random_uuid(), 'Priya Sharma',  'Dialysis machine conductivity alarm guide', 'dialysis',        'Fresenius 4008S',     'intermediate', '2026-06-01'::date, 1205,  67, 24, 5500,  'published'),
  (gen_random_uuid(), 'Anand Reddy',   'CT tube arc detection workflow',            'ct_scan',         'GE Revolution',       'expert',       '2026-06-01'::date, 2310, 128, 52, 12000, 'featured'),
  (gen_random_uuid(), 'Sneha Iyer',    'MRI gradient coil cold-start protocol',     'mri',             'Siemens Magnetom',    'expert',       '2026-06-01'::date, 1678,  82, 31, 9500,  'published'),
  (gen_random_uuid(), 'Vikram Singh',  'Ultrasound probe artefact triage',          'ultrasound',      'Philips Affiniti',    'intermediate', '2026-06-01'::date,  894,  41, 18, 4000,  'published'),
  (gen_random_uuid(), 'Meera Nair',    'ECG lead-fall noise root cause matrix',     'ecg',             'BPL Cardiart',        'basic',        '2026-06-01'::date,  612,  29, 12, 2500,  'published'),
  (gen_random_uuid(), 'Karthik Menon', 'Autoclave vacuum pump replacement',         'autoclave',       'Steris Amsco',        'advanced',     '2026-06-01'::date,  428,  22,  9, 3500,  'published'),
  (gen_random_uuid(), 'Deepa Pillai',  'Infusion pump occlusion sensitivity table', 'infusion_pump',   'BD Alaris',           'intermediate', '2026-06-01'::date,  756,  38, 16, 4500,  'published');

-- ---- TABLE 2: Topic-level engagement rollup -----------------------------
CREATE TABLE IF NOT EXISTS engineer_kb_topic_rollup_r2754 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic            text NOT NULL CHECK (topic IN ('ventilator','dialysis','ct_scan','mri','ultrasound','ecg','autoclave','infusion_pump','patient_monitor','xray')),
  rollup_month     date NOT NULL,
  total_articles   integer NOT NULL CHECK (total_articles >= 0),
  total_views      integer NOT NULL CHECK (total_views >= 0),
  total_kudos      integer NOT NULL CHECK (total_kudos >= 0),
  total_saves      integer NOT NULL CHECK (total_saves >= 0),
  reward_pool_rupees integer NOT NULL CHECK (reward_pool_rupees >= 0),
  demand_signal    text NOT NULL CHECK (demand_signal IN ('low','medium','high','very_high')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (topic, rollup_month)
);

ALTER TABLE engineer_kb_topic_rollup_r2754 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_kb_topic_rollup_r2754;
CREATE POLICY founder_all ON engineer_kb_topic_rollup_r2754
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_kb_topic_rollup_r2754 (topic, rollup_month, total_articles, total_views, total_kudos, total_saves, reward_pool_rupees, demand_signal) VALUES
  ('ventilator',    '2026-06-01'::date, 6, 8420,  412, 178, 28000, 'very_high'),
  ('dialysis',      '2026-06-01'::date, 4, 5210,  248, 102, 18500, 'high'),
  ('ct_scan',       '2026-06-01'::date, 3, 6890,  331, 142, 32000, 'very_high'),
  ('mri',           '2026-06-01'::date, 3, 4520,  219,  88, 24500, 'high'),
  ('ultrasound',    '2026-06-01'::date, 4, 3180,  152,  64, 12000, 'medium'),
  ('ecg',           '2026-06-01'::date, 5, 2410,  118,  48,  8500, 'medium'),
  ('autoclave',     '2026-06-01'::date, 2,  890,   44,  18,  6500, 'low'),
  ('infusion_pump', '2026-06-01'::date, 3, 1840,   89,  38,  9500, 'medium');

-- =========================================================================
-- RPCs
-- =========================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_engineer_kb_kpi_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_kpi_r2754()
RETURNS TABLE (
  total_articles bigint,
  total_views bigint,
  total_kudos bigint,
  total_saves bigint,
  total_reward_rupees bigint,
  featured_count bigint,
  active_engineers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(view_count),0)::bigint,
    COALESCE(SUM(kudos_count),0)::bigint,
    COALESCE(SUM(resolution_saves),0)::bigint,
    COALESCE(SUM(reward_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE status = 'featured')::bigint,
    COUNT(DISTINCT engineer_id)::bigint
  FROM engineer_kb_articles_r2754;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_kpi_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_kpi_r2754() TO authenticated;

-- RPC 2: Top articles
DROP FUNCTION IF EXISTS founder_engineer_kb_top_articles_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_top_articles_r2754()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  article_title text,
  topic text,
  device_brand text,
  difficulty text,
  view_count integer,
  kudos_count integer,
  resolution_saves integer,
  reward_rupees integer,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_name, a.article_title, a.topic, a.device_brand,
         a.difficulty, a.view_count, a.kudos_count, a.resolution_saves,
         a.reward_rupees, a.status
  FROM engineer_kb_articles_r2754 a
  ORDER BY a.view_count DESC, a.kudos_count DESC
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_top_articles_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_top_articles_r2754() TO authenticated;

-- RPC 3: Topic rollup
DROP FUNCTION IF EXISTS founder_engineer_kb_topic_rollup_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_topic_rollup_r2754()
RETURNS TABLE (
  topic text,
  rollup_month date,
  total_articles integer,
  total_views integer,
  total_kudos integer,
  total_saves integer,
  reward_pool_rupees integer,
  demand_signal text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic, t.rollup_month, t.total_articles, t.total_views,
         t.total_kudos, t.total_saves, t.reward_pool_rupees, t.demand_signal
  FROM engineer_kb_topic_rollup_r2754 t
  ORDER BY t.total_views DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_topic_rollup_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_topic_rollup_r2754() TO authenticated;

-- RPC 4: Engineer leaderboard
DROP FUNCTION IF EXISTS founder_engineer_kb_leaderboard_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_leaderboard_r2754()
RETURNS TABLE (
  engineer_name text,
  article_count bigint,
  total_views bigint,
  total_kudos bigint,
  total_saves bigint,
  total_reward_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_name,
         COUNT(*)::bigint,
         COALESCE(SUM(a.view_count),0)::bigint,
         COALESCE(SUM(a.kudos_count),0)::bigint,
         COALESCE(SUM(a.resolution_saves),0)::bigint,
         COALESCE(SUM(a.reward_rupees),0)::bigint
  FROM engineer_kb_articles_r2754 a
  GROUP BY a.engineer_name
  ORDER BY 6 DESC, 3 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_leaderboard_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_leaderboard_r2754() TO authenticated;

-- RPC 5: Difficulty mix
DROP FUNCTION IF EXISTS founder_engineer_kb_difficulty_mix_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_difficulty_mix_r2754()
RETURNS TABLE (
  difficulty text,
  article_count bigint,
  avg_views numeric,
  avg_kudos numeric,
  total_reward bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.difficulty,
         COUNT(*)::bigint,
         ROUND(AVG(a.view_count)::numeric, 1),
         ROUND(AVG(a.kudos_count)::numeric, 1),
         COALESCE(SUM(a.reward_rupees),0)::bigint
  FROM engineer_kb_articles_r2754 a
  GROUP BY a.difficulty
  ORDER BY 5 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_difficulty_mix_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_difficulty_mix_r2754() TO authenticated;

-- RPC 6: Status pipeline
DROP FUNCTION IF EXISTS founder_engineer_kb_status_pipeline_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_status_pipeline_r2754()
RETURNS TABLE (
  status text,
  article_count bigint,
  total_views bigint,
  total_reward bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status,
         COUNT(*)::bigint,
         COALESCE(SUM(a.view_count),0)::bigint,
         COALESCE(SUM(a.reward_rupees),0)::bigint
  FROM engineer_kb_articles_r2754 a
  GROUP BY a.status
  ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_status_pipeline_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_status_pipeline_r2754() TO authenticated;

-- RPC 7: Brand coverage
DROP FUNCTION IF EXISTS founder_engineer_kb_brand_coverage_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_brand_coverage_r2754()
RETURNS TABLE (
  device_brand text,
  article_count bigint,
  total_views bigint,
  total_saves bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.device_brand,
         COUNT(*)::bigint,
         COALESCE(SUM(a.view_count),0)::bigint,
         COALESCE(SUM(a.resolution_saves),0)::bigint
  FROM engineer_kb_articles_r2754 a
  GROUP BY a.device_brand
  ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_brand_coverage_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_brand_coverage_r2754() TO authenticated;

-- RPC 8: High demand gaps (topics with high demand signal but few articles)
DROP FUNCTION IF EXISTS founder_engineer_kb_demand_gaps_r2754();
CREATE OR REPLACE FUNCTION founder_engineer_kb_demand_gaps_r2754()
RETURNS TABLE (
  topic text,
  demand_signal text,
  total_articles integer,
  total_views integer,
  gap_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic, t.demand_signal, t.total_articles, t.total_views,
         ROUND((t.total_views::numeric / GREATEST(t.total_articles,1))::numeric, 1)
  FROM engineer_kb_topic_rollup_r2754 t
  WHERE t.demand_signal IN ('high','very_high')
  ORDER BY 5 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_kb_demand_gaps_r2754() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_kb_demand_gaps_r2754() TO authenticated;

COMMIT;
