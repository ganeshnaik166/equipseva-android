BEGIN;

-- ============================================================
-- Round 2850: Engineer Monthly Job Completion Narrative Story
-- engineer × job × narrative × highlight × public share × engagement × verdict
-- ============================================================

-- ---------- Table 1: narrative stories ----------
CREATE TABLE IF NOT EXISTS engineer_monthly_job_narrative_stories_r2850 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  story_month date NOT NULL,
  jobs_completed int NOT NULL CHECK (jobs_completed >= 0),
  jobs_perfect int NOT NULL CHECK (jobs_perfect >= 0),
  hospitals_served int NOT NULL CHECK (hospitals_served >= 0),
  hero_job_title text NOT NULL,
  hero_job_summary text NOT NULL,
  narrative_arc text NOT NULL,
  highlight_quote text NOT NULL,
  csat_avg numeric(3,2) NOT NULL CHECK (csat_avg >= 0 AND csat_avg <= 5),
  revenue_generated_rupees numeric(12,2) NOT NULL CHECK (revenue_generated_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('legendary','strong','solid','needs_boost','at_risk')),
  share_status text NOT NULL DEFAULT 'draft' CHECK (share_status IN ('draft','approved','published','retired')),
  public_share_token text UNIQUE,
  share_view_count int NOT NULL DEFAULT 0 CHECK (share_view_count >= 0),
  founder_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_job_narrative_stories_r2850 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_job_narrative_stories_r2850;
CREATE POLICY founder_all ON engineer_monthly_job_narrative_stories_r2850
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_job_narrative_stories_r2850
  (engineer_name, engineer_tier, story_month, jobs_completed, jobs_perfect, hospitals_served,
   hero_job_title, hero_job_summary, narrative_arc, highlight_quote,
   csat_avg, revenue_generated_rupees, verdict, share_status, public_share_token,
   share_view_count, founder_notes)
VALUES
  ('Ramesh Kumar','platinum','2026-05-01'::date,47,42,18,
   'Saved Apollo CT-scanner mid-surgery',
   'Diagnosed cooling-loop failure in 12 minutes; bypass repair held 6 hours till spare arrived.',
   'Started month behind on calls — closed with biggest single-job revenue ever recorded.',
   'I treat every machine like the patient depends on it. Because they do.',
   4.92,684500.00,'legendary','published','shr_ramesh_may26_x7k9q',1847,
   'Anchor of Hyderabad south zone. Promote to lead-engineer track.'),
  ('Priya Sharma','gold','2026-05-01'::date,38,34,14,
   'First-time-fix on Siemens MRI quench',
   'Cold-head replacement plus helium top-up in single visit. Hospital saved 3-day downtime.',
   'Tier upgrade in week 2 changed her confidence — repair velocity jumped 40 percent.',
   'When you trust your tools, the machine trusts you back.',
   4.81,512300.00,'strong','published','shr_priya_may26_b4m2n',1203,
   'Candidate for Bangalore expansion captain.'),
  ('Anand Reddy','silver','2026-05-01'::date,29,24,11,
   'KIMS dialysis bank — 6 units in 36 hours',
   'Sequential ultrafiltration calibration across 6 chairs; zero patient slot lost.',
   'Quiet month build — consistency beats heroics on dialysis routes.',
   'Routine done right is the highest form of repair.',
   4.66,318900.00,'solid','approved',NULL,0,
   'Steady performer. Watch for fatigue — 11 hospitals is high for silver.'),
  ('Vikram Iyer','bronze','2026-05-01'::date,18,12,8,
   'Stumbled on Yashoda ventilator board swap',
   'Took 3 visits to close — wrong board pulled twice. Customer escalated.',
   'Tough first month post-onboarding. Mentor pairing applied week 3.',
   'I am learning every machine has its own language.',
   3.94,142700.00,'needs_boost','draft',NULL,0,
   'Pair with Ramesh for June. Block bronze from ventilator routes till re-cert.'),
  ('Saritha Devi','gold','2026-05-01'::date,41,38,16,
   'Rainbow paediatric incubator humidity crisis',
   '14 incubators recalibrated overnight before NABH audit. Zero non-conformance found.',
   'Crisis-mode performer — best deployed on audit-week rescue ops.',
   'Babies do not wait for tomorrow. Neither do I.',
   4.88,597800.00,'legendary','published','shr_saritha_may26_p2v8r',2104,
   'Highest viewership share so far. Use story in investor deck.'),
  ('Mohammed Faiz','silver','2026-05-01'::date,33,28,12,
   'Continental hospital OT-light retrofit',
   'LED conversion of 8 OT lamps; finished one day early; CSAT 5.0 from OT-head.',
   'Steady climber — silver-to-gold promotion threshold this month.',
   'Light in the OT is light in our craft.',
   4.74,401200.00,'strong','approved',NULL,0,
   'Promote to gold July 1. Hindi-Telugu bilingual asset.'),
  ('Lakshmi Nair','platinum','2026-05-01'::date,52,49,22,
   'Citizens hospital biomedical wing turnaround',
   '52 jobs across 22 hospitals — new single-engineer record. Zero rework.',
   'Defended the platinum benchmark — bar nobody has touched since.',
   'Records exist to remind the next engineer what is possible.',
   4.95,798400.00,'legendary','published','shr_lakshmi_may26_z9w3t',3210,
   'Highest-grossing engineer in EquipSeva history. Profile her for Forbes pitch.'),
  ('Suresh Babu','bronze','2026-05-01'::date,12,6,5,
   'Missed SLA on Continental autoclave',
   'Two jobs reopened for same fault. Hospital threatened to switch vendor.',
   'Worst month for the cohort. Risk of churn — needs immediate intervention.',
   'I do not want to be the engineer who lost us a hospital.',
   3.41,68300.00,'at_risk','draft',NULL,0,
   'PIP triggered. Re-shadow with Lakshmi 2 weeks before final call.');

-- ---------- Table 2: engagement events ----------
CREATE TABLE IF NOT EXISTS engineer_monthly_job_narrative_engagement_r2850 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES engineer_monthly_job_narrative_stories_r2850(id) ON DELETE CASCADE,
  event_kind text NOT NULL CHECK (event_kind IN ('view','share','reaction','comment','bookmark','quote_pull')),
  audience text NOT NULL CHECK (audience IN ('hospital_lead','investor','press','team_internal','engineer_self','partner')),
  audience_label text NOT NULL,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','critical','rave')),
  remark text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_job_narrative_engagement_r2850 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_job_narrative_engagement_r2850;
CREATE POLICY founder_all ON engineer_monthly_job_narrative_engagement_r2850
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_job_narrative_engagement_r2850
  (story_id, event_kind, audience, audience_label, sentiment, remark, occurred_at)
SELECT id,'view','hospital_lead','Apollo Biomed Head','rave',
       'Forwarded to procurement team — wants Ramesh on annual contract.',
       now() - interval '3 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Ramesh Kumar'
UNION ALL
SELECT id,'share','investor','Sequoia India partner','positive',
       'Shared in monthly LP letter — example of unit economics holding under stress.',
       now() - interval '5 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Lakshmi Nair'
UNION ALL
SELECT id,'reaction','press','YourStory writer','rave',
       'Pinged for full interview. Wants the helium-quench story for feature piece.',
       now() - interval '2 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Priya Sharma'
UNION ALL
SELECT id,'comment','team_internal','Ops Lead Hyderabad','positive',
       'Saritha pulled the audit save — we owe her the platinum dinner.',
       now() - interval '7 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Saritha Devi'
UNION ALL
SELECT id,'bookmark','partner','Cashfree partner manager','neutral',
       'Bookmarked for reference — using as case study in their hospital vertical pitch.',
       now() - interval '4 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Lakshmi Nair'
UNION ALL
SELECT id,'quote_pull','press','The Ken reporter','rave',
       'Quoted line about routine being highest form of repair in their long-read.',
       now() - interval '6 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Anand Reddy'
UNION ALL
SELECT id,'view','engineer_self','Vikram Iyer login','critical',
       'Engineer opened own story 11 times — taking the feedback to heart, watch wellbeing.',
       now() - interval '1 day'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Vikram Iyer'
UNION ALL
SELECT id,'comment','hospital_lead','KIMS biomedical','positive',
       'Anand consistently underbilled honest hours. Bonus from us to him.',
       now() - interval '8 days'
FROM engineer_monthly_job_narrative_stories_r2850 WHERE engineer_name='Anand Reddy';

-- ============================================================
-- RPCs (7+)
-- ============================================================

DROP FUNCTION IF EXISTS rpc_r2850_summary();
CREATE OR REPLACE FUNCTION rpc_r2850_summary()
RETURNS TABLE(
  total_stories int,
  legendary_count int,
  at_risk_count int,
  published_count int,
  total_views int,
  total_revenue_rupees numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE verdict='legendary')::int,
    COUNT(*) FILTER (WHERE verdict='at_risk')::int,
    COUNT(*) FILTER (WHERE share_status='published')::int,
    COALESCE(SUM(share_view_count),0)::int,
    COALESCE(SUM(revenue_generated_rupees),0)::numeric,
    COALESCE(ROUND(AVG(csat_avg)::numeric,2),0)
  FROM engineer_monthly_job_narrative_stories_r2850;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_summary() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_stories();
CREATE OR REPLACE FUNCTION rpc_r2850_stories()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  engineer_tier text,
  story_month date,
  jobs_completed int,
  jobs_perfect int,
  csat_avg numeric,
  revenue_generated_rupees numeric,
  verdict text,
  share_status text,
  share_view_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_name, s.engineer_tier, s.story_month,
         s.jobs_completed, s.jobs_perfect, s.csat_avg, s.revenue_generated_rupees,
         s.verdict, s.share_status, s.share_view_count
  FROM engineer_monthly_job_narrative_stories_r2850 s
  ORDER BY s.revenue_generated_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_stories() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_stories() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_hero_jobs();
CREATE OR REPLACE FUNCTION rpc_r2850_hero_jobs()
RETURNS TABLE(
  engineer_name text,
  engineer_tier text,
  hero_job_title text,
  hero_job_summary text,
  highlight_quote text,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.engineer_tier, s.hero_job_title, s.hero_job_summary,
         s.highlight_quote, s.verdict
  FROM engineer_monthly_job_narrative_stories_r2850 s
  WHERE s.verdict IN ('legendary','strong')
  ORDER BY s.csat_avg DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_hero_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_hero_jobs() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_tier_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2850_tier_breakdown()
RETURNS TABLE(
  engineer_tier text,
  engineer_count int,
  total_jobs int,
  perfect_pct numeric,
  total_revenue_rupees numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_tier,
    COUNT(*)::int,
    COALESCE(SUM(s.jobs_completed),0)::int,
    CASE WHEN SUM(s.jobs_completed) > 0
         THEN ROUND((SUM(s.jobs_perfect)::numeric / SUM(s.jobs_completed)::numeric) * 100, 1)
         ELSE 0 END,
    COALESCE(SUM(s.revenue_generated_rupees),0)::numeric,
    COALESCE(ROUND(AVG(s.csat_avg)::numeric,2),0)
  FROM engineer_monthly_job_narrative_stories_r2850 s
  GROUP BY s.engineer_tier
  ORDER BY total_revenue_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_tier_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_engagement_feed();
CREATE OR REPLACE FUNCTION rpc_r2850_engagement_feed()
RETURNS TABLE(
  engineer_name text,
  event_kind text,
  audience text,
  audience_label text,
  sentiment text,
  remark text,
  occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, e.event_kind, e.audience, e.audience_label,
         e.sentiment, e.remark, e.occurred_at
  FROM engineer_monthly_job_narrative_engagement_r2850 e
  JOIN engineer_monthly_job_narrative_stories_r2850 s ON s.id = e.story_id
  ORDER BY e.occurred_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_engagement_feed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_engagement_feed() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_public_share_health();
CREATE OR REPLACE FUNCTION rpc_r2850_public_share_health()
RETURNS TABLE(
  engineer_name text,
  share_status text,
  public_share_token text,
  share_view_count int,
  engagement_events int,
  rave_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_name,
    s.share_status,
    s.public_share_token,
    s.share_view_count,
    COUNT(e.id)::int,
    COUNT(e.id) FILTER (WHERE e.sentiment='rave')::int
  FROM engineer_monthly_job_narrative_stories_r2850 s
  LEFT JOIN engineer_monthly_job_narrative_engagement_r2850 e ON e.story_id = s.id
  GROUP BY s.id, s.engineer_name, s.share_status, s.public_share_token, s.share_view_count
  ORDER BY s.share_view_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_public_share_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_public_share_health() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_verdict_distribution();
CREATE OR REPLACE FUNCTION rpc_r2850_verdict_distribution()
RETURNS TABLE(
  verdict text,
  engineer_count int,
  share_of_revenue_pct numeric,
  avg_jobs numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total_rev numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(revenue_generated_rupees),0)
    INTO total_rev
    FROM engineer_monthly_job_narrative_stories_r2850;
  IF total_rev = 0 THEN total_rev := 1; END IF;
  RETURN QUERY
  SELECT
    s.verdict,
    COUNT(*)::int,
    ROUND((SUM(s.revenue_generated_rupees) / total_rev) * 100, 1),
    ROUND(AVG(s.jobs_completed)::numeric,1),
    ROUND(AVG(s.csat_avg)::numeric,2)
  FROM engineer_monthly_job_narrative_stories_r2850 s
  GROUP BY s.verdict
  ORDER BY engineer_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_verdict_distribution() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2850_at_risk_watchlist();
CREATE OR REPLACE FUNCTION rpc_r2850_at_risk_watchlist()
RETURNS TABLE(
  engineer_name text,
  engineer_tier text,
  jobs_completed int,
  csat_avg numeric,
  verdict text,
  founder_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.engineer_tier, s.jobs_completed, s.csat_avg,
         s.verdict, s.founder_notes
  FROM engineer_monthly_job_narrative_stories_r2850 s
  WHERE s.verdict IN ('at_risk','needs_boost')
  ORDER BY s.csat_avg ASC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_r2850_at_risk_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2850_at_risk_watchlist() TO authenticated;

COMMIT;
