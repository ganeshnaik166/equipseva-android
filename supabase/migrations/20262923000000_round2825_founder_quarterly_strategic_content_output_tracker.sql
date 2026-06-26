BEGIN;

-- ============================================================
-- Round 2825: Founder Quarterly Strategic Content Output Tracker
-- piece x format x audience x performance x repurpose x strategic value
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_quarterly_strategic_content_pieces_r2825 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL CHECK (quarter IN ('q1_2026','q2_2026','q3_2026','q4_2026','q1_2027')),
  piece_title text NOT NULL,
  format text NOT NULL CHECK (format IN ('long_form_essay','case_study','data_report','video','podcast','linkedin_thread','keynote','press_release','whitepaper','newsletter')),
  primary_audience text NOT NULL CHECK (primary_audience IN ('hospital_buyers','engineers','investors','regulators','press','partners','talent')),
  strategic_pillar text NOT NULL CHECK (strategic_pillar IN ('category_creation','thought_leadership','recruiting','fundraising','sales_enablement','regulatory_positioning','brand')),
  published_on date NOT NULL,
  views integer NOT NULL DEFAULT 0,
  qualified_leads integer NOT NULL DEFAULT 0,
  pipeline_attributed_rupees bigint NOT NULL DEFAULT 0,
  effort_hours numeric(6,1) NOT NULL DEFAULT 0,
  strategic_value_score integer NOT NULL CHECK (strategic_value_score BETWEEN 1 AND 100),
  status text NOT NULL CHECK (status IN ('drafting','in_review','published','retired','evergreen')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_quarterly_strategic_content_pieces_r2825 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_quarterly_strategic_content_pieces_r2825;
CREATE POLICY founder_all ON founder_quarterly_strategic_content_pieces_r2825 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_quarterly_strategic_content_repurposes_r2825 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  piece_id uuid NOT NULL REFERENCES founder_quarterly_strategic_content_pieces_r2825(id) ON DELETE CASCADE,
  derivative_format text NOT NULL CHECK (derivative_format IN ('twitter_thread','linkedin_post','short_video','newsletter_blurb','sales_one_pager','investor_slide','podcast_clip','press_quote')),
  channel text NOT NULL CHECK (channel IN ('twitter','linkedin','youtube','email','sales','investor_update','podcast_feed','press_kit')),
  shipped_on date NOT NULL,
  incremental_views integer NOT NULL DEFAULT 0,
  incremental_leads integer NOT NULL DEFAULT 0,
  multiplier_score numeric(4,2) NOT NULL CHECK (multiplier_score BETWEEN 0 AND 10),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_quarterly_strategic_content_repurposes_r2825 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_quarterly_strategic_content_repurposes_r2825;
CREATE POLICY founder_all ON founder_quarterly_strategic_content_repurposes_r2825 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seed: pieces (6 rows)
-- ============================================================
INSERT INTO founder_quarterly_strategic_content_pieces_r2825
  (quarter, piece_title, format, primary_audience, strategic_pillar, published_on, views, qualified_leads, pipeline_attributed_rupees, effort_hours, strategic_value_score, status, notes)
VALUES
  ('q2_2026','Why Hospital Equipment Uptime Is The New ICU KPI','long_form_essay','hospital_buyers','category_creation','2026-04-12'::date, 48200, 41, 18500000, 22.5, 92, 'evergreen','Cited by 3 hospital procurement leads'),
  ('q2_2026','EquipSeva Engineer Tier Ladder Explained','case_study','engineers','recruiting','2026-04-28'::date, 12400, 86, 0, 14.0, 78, 'published','Drove 86 engineer applications in 2 weeks'),
  ('q2_2026','India Medtech Service: A $2.4B Hidden Market','data_report','investors','fundraising','2026-05-09'::date, 21800, 11, 0, 38.0, 95, 'published','Referenced in 4 VC memos'),
  ('q2_2026','DPDP Compliance For Medical Equipment Vendors','whitepaper','regulators','regulatory_positioning','2026-05-22'::date, 6700, 3, 0, 27.0, 71, 'published','Submitted to MeitY consultation'),
  ('q2_2026','Founder Q2 Letter — Crossing 1000 AMC Contracts','newsletter','investors','fundraising','2026-06-15'::date, 3200, 7, 0, 6.0, 84, 'published','Sent to 412 investor contacts'),
  ('q2_2026','Keynote: Service-First Medtech At HealthTech India','keynote','press','brand','2026-06-18'::date, 1800, 9, 4200000, 18.0, 80, 'published','3 press pickups, 1 large hospital intro');

-- ============================================================
-- Seed: repurposes (8 rows)
-- ============================================================
INSERT INTO founder_quarterly_strategic_content_repurposes_r2825
  (piece_id, derivative_format, channel, shipped_on, incremental_views, incremental_leads, multiplier_score, notes)
SELECT id, 'twitter_thread','twitter','2026-04-14'::date, 28000, 12, 4.20, 'Hit 1.2k retweets'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'Why Hospital Equipment Uptime Is The New ICU KPI'
UNION ALL
SELECT id, 'linkedin_post','linkedin','2026-04-15'::date, 41000, 18, 5.10, 'Top voice repost'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'Why Hospital Equipment Uptime Is The New ICU KPI'
UNION ALL
SELECT id, 'short_video','youtube','2026-05-02'::date, 9200, 31, 3.80, '90s explainer reel'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'EquipSeva Engineer Tier Ladder Explained'
UNION ALL
SELECT id, 'investor_slide','investor_update','2026-05-12'::date, 412, 4, 6.50, 'Slide 7 in pitch deck'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'India Medtech Service: A $2.4B Hidden Market'
UNION ALL
SELECT id, 'newsletter_blurb','email','2026-05-14'::date, 3100, 2, 2.10, 'Top-of-fold callout'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'India Medtech Service: A $2.4B Hidden Market'
UNION ALL
SELECT id, 'sales_one_pager','sales','2026-05-30'::date, 180, 0, 5.20, 'Used in 14 hospital sales calls'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'DPDP Compliance For Medical Equipment Vendors'
UNION ALL
SELECT id, 'podcast_clip','podcast_feed','2026-06-20'::date, 4400, 6, 3.40, 'Snippet on MedtechIndia pod'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'Keynote: Service-First Medtech At HealthTech India'
UNION ALL
SELECT id, 'press_quote','press_kit','2026-06-19'::date, 12000, 5, 4.80, 'Picked up by ET Healthworld'
FROM founder_quarterly_strategic_content_pieces_r2825 WHERE piece_title = 'Keynote: Service-First Medtech At HealthTech India';

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2825_pieces_overview();
CREATE OR REPLACE FUNCTION founder_r2825_pieces_overview()
RETURNS TABLE (
  quarter text,
  piece_title text,
  format text,
  primary_audience text,
  strategic_pillar text,
  published_on date,
  views integer,
  qualified_leads integer,
  pipeline_attributed_rupees bigint,
  effort_hours numeric,
  strategic_value_score integer,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.quarter, p.piece_title, p.format, p.primary_audience, p.strategic_pillar,
         p.published_on, p.views, p.qualified_leads, p.pipeline_attributed_rupees,
         p.effort_hours, p.strategic_value_score, p.status
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  ORDER BY p.published_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_pieces_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_pieces_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_kpis();
CREATE OR REPLACE FUNCTION founder_r2825_kpis()
RETURNS TABLE (
  total_pieces integer,
  total_views bigint,
  total_qualified_leads bigint,
  total_pipeline_rupees bigint,
  total_effort_hours numeric,
  avg_strategic_value numeric,
  evergreen_count integer,
  total_repurposes integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT coalesce(sum(views),0)::bigint FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT coalesce(sum(qualified_leads),0)::bigint FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT coalesce(sum(pipeline_attributed_rupees),0)::bigint FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT coalesce(sum(effort_hours),0) FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT coalesce(round(avg(strategic_value_score)::numeric, 1), 0) FROM founder_quarterly_strategic_content_pieces_r2825),
    (SELECT count(*)::int FROM founder_quarterly_strategic_content_pieces_r2825 WHERE status = 'evergreen'),
    (SELECT count(*)::int FROM founder_quarterly_strategic_content_repurposes_r2825);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_by_format();
CREATE OR REPLACE FUNCTION founder_r2825_by_format()
RETURNS TABLE (
  format text,
  pieces integer,
  total_views bigint,
  total_leads bigint,
  avg_strategic_value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.format,
         count(*)::int,
         coalesce(sum(p.views),0)::bigint,
         coalesce(sum(p.qualified_leads),0)::bigint,
         coalesce(round(avg(p.strategic_value_score)::numeric, 1), 0)
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  GROUP BY p.format
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_by_format() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_by_format() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_by_audience();
CREATE OR REPLACE FUNCTION founder_r2825_by_audience()
RETURNS TABLE (
  primary_audience text,
  pieces integer,
  total_views bigint,
  total_leads bigint,
  total_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.primary_audience,
         count(*)::int,
         coalesce(sum(p.views),0)::bigint,
         coalesce(sum(p.qualified_leads),0)::bigint,
         coalesce(sum(p.pipeline_attributed_rupees),0)::bigint
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  GROUP BY p.primary_audience
  ORDER BY sum(p.qualified_leads) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_by_audience() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_by_audience() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_by_pillar();
CREATE OR REPLACE FUNCTION founder_r2825_by_pillar()
RETURNS TABLE (
  strategic_pillar text,
  pieces integer,
  avg_strategic_value numeric,
  total_effort_hours numeric,
  total_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.strategic_pillar,
         count(*)::int,
         coalesce(round(avg(p.strategic_value_score)::numeric, 1), 0),
         coalesce(sum(p.effort_hours), 0),
         coalesce(sum(p.pipeline_attributed_rupees),0)::bigint
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  GROUP BY p.strategic_pillar
  ORDER BY avg(p.strategic_value_score) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_by_pillar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_by_pillar() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_top_repurposes();
CREATE OR REPLACE FUNCTION founder_r2825_top_repurposes()
RETURNS TABLE (
  piece_title text,
  derivative_format text,
  channel text,
  shipped_on date,
  incremental_views integer,
  incremental_leads integer,
  multiplier_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.piece_title, r.derivative_format, r.channel, r.shipped_on,
         r.incremental_views, r.incremental_leads, r.multiplier_score
  FROM founder_quarterly_strategic_content_repurposes_r2825 r
  JOIN founder_quarterly_strategic_content_pieces_r2825 p ON p.id = r.piece_id
  ORDER BY r.multiplier_score DESC, r.incremental_views DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_top_repurposes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_top_repurposes() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_efficiency_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2825_efficiency_leaderboard()
RETURNS TABLE (
  piece_title text,
  format text,
  strategic_value_score integer,
  effort_hours numeric,
  value_per_hour numeric,
  repurpose_count integer,
  total_amplified_views bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.piece_title, p.format, p.strategic_value_score, p.effort_hours,
         CASE WHEN p.effort_hours > 0 THEN round((p.strategic_value_score / p.effort_hours)::numeric, 2) ELSE 0 END,
         (SELECT count(*)::int FROM founder_quarterly_strategic_content_repurposes_r2825 r WHERE r.piece_id = p.id),
         p.views + coalesce((SELECT sum(r.incremental_views)::bigint FROM founder_quarterly_strategic_content_repurposes_r2825 r WHERE r.piece_id = p.id), 0)
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  ORDER BY CASE WHEN p.effort_hours > 0 THEN (p.strategic_value_score / p.effort_hours) ELSE 0 END DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_efficiency_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_efficiency_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2825_quarter_rollup();
CREATE OR REPLACE FUNCTION founder_r2825_quarter_rollup()
RETURNS TABLE (
  quarter text,
  pieces integer,
  total_views bigint,
  total_leads bigint,
  total_pipeline_rupees bigint,
  avg_strategic_value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.quarter,
         count(*)::int,
         coalesce(sum(p.views),0)::bigint,
         coalesce(sum(p.qualified_leads),0)::bigint,
         coalesce(sum(p.pipeline_attributed_rupees),0)::bigint,
         coalesce(round(avg(p.strategic_value_score)::numeric, 1), 0)
  FROM founder_quarterly_strategic_content_pieces_r2825 p
  GROUP BY p.quarter
  ORDER BY p.quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2825_quarter_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2825_quarter_rollup() TO authenticated;

COMMIT;
