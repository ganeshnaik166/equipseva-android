-- Round 2941: Founder Monthly Strategic Quarterly LinkedIn Brand Voice Posting Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs

CREATE TABLE IF NOT EXISTS linkedin_brand_voice_posts_r2941 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  post_slug text NOT NULL UNIQUE,
  quarter text NOT NULL CHECK (quarter IN ('Q1','Q2','Q3','Q4')),
  fiscal_year int NOT NULL CHECK (fiscal_year BETWEEN 2024 AND 2030),
  month_label text NOT NULL,
  posted_at timestamptz NOT NULL,
  pillar text NOT NULL CHECK (pillar IN ('vision','customer_story','engineer_pride','market_intel','culture','product_update','founder_pov')),
  voice_tone text NOT NULL CHECK (voice_tone IN ('founder_first_person','data_driven','storytelling','contrarian','celebratory')),
  headline text NOT NULL,
  body_excerpt text NOT NULL,
  impressions int NOT NULL DEFAULT 0,
  reactions int NOT NULL DEFAULT 0,
  comments_count int NOT NULL DEFAULT 0,
  reposts int NOT NULL DEFAULT 0,
  on_brand_score numeric(4,2) NOT NULL CHECK (on_brand_score BETWEEN 0 AND 10),
  status text NOT NULL CHECK (status IN ('drafted','scheduled','posted','archived'))
);

CREATE TABLE IF NOT EXISTS linkedin_brand_voice_audits_r2941 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_slug text NOT NULL UNIQUE,
  audit_month text NOT NULL,
  audit_period_start date NOT NULL,
  audit_period_end date NOT NULL,
  posts_reviewed int NOT NULL DEFAULT 0,
  off_brand_count int NOT NULL DEFAULT 0,
  voice_drift_dimension text NOT NULL CHECK (voice_drift_dimension IN ('tone','jargon','pillar_mix','cadence','hook_quality','authenticity')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  drift_summary text NOT NULL,
  corrective_action text NOT NULL,
  audit_status text NOT NULL CHECK (audit_status IN ('open','in_review','resolved','accepted_drift'))
);

ALTER TABLE linkedin_brand_voice_posts_r2941 ENABLE ROW LEVEL SECURITY;
ALTER TABLE linkedin_brand_voice_audits_r2941 ENABLE ROW LEVEL SECURITY;

INSERT INTO linkedin_brand_voice_posts_r2941 (post_slug, quarter, fiscal_year, month_label, posted_at, pillar, voice_tone, headline, body_excerpt, impressions, reactions, comments_count, reposts, on_brand_score, status) VALUES
('post-apr-vision-01','Q1',2026,'Apr 2026','2026-04-03 09:30:00+00'::timestamptz,'vision','founder_first_person','Why medical equipment uptime is India''s silent emergency','Every hour an oxygen concentrator is down a hospital loses ₹4,000 and a patient loses dignity.',18420,612,84,47,9.20,'posted'),
('post-apr-engineer-02','Q1',2026,'Apr 2026','2026-04-09 11:00:00+00'::timestamptz,'engineer_pride','storytelling','Field engineer Ravi fixed 14 ventilators in one night','Tier-3 hospital, Hyderabad, midnight call. Ravi didn''t sleep until every bed was breathing.',24310,890,142,98,9.60,'posted'),
('post-apr-customer-03','Q1',2026,'Apr 2026','2026-04-16 08:15:00+00'::timestamptz,'customer_story','data_driven','Apollo Vizag cut MRI downtime 73% in 6 months','From 41 hours/month to 11 hours/month. Same machine. Same engineers. Better dispatch.',31200,1102,201,156,9.40,'posted'),
('post-apr-market-04','Q1',2026,'Apr 2026','2026-04-23 10:00:00+00'::timestamptz,'market_intel','contrarian','OEM AMC contracts are a tax on Indian hospitals','₹600cr/yr leaves the country for service contracts on machines made in India.',42100,1840,387,289,8.90,'posted'),
('post-may-pov-05','Q1',2026,'May 2026','2026-05-02 09:00:00+00'::timestamptz,'founder_pov','founder_first_person','I almost shut down EquipSeva in month 4','Three engineers quit the same week. Here''s what I learned about building field teams.',38900,2104,512,341,9.80,'posted'),
('post-may-product-06','Q1',2026,'May 2026','2026-05-08 11:30:00+00'::timestamptz,'product_update','data_driven','Bonded spare parts now scan-to-verify in 4 seconds','Counterfeit ventilator boards killed 11 patients in 2023. Provenance shouldn''t be optional.',27600,1041,178,134,9.10,'posted'),
('post-may-culture-07','Q1',2026,'May 2026','2026-05-15 14:00:00+00'::timestamptz,'culture','celebratory','EquipSeva engineers crossed 10,000 repairs this week','Every repair = a hospital open, a bed available, a family that didn''t hear "machine down".',22400,1490,89,67,9.50,'posted'),
('post-may-vision-08','Q1',2026,'May 2026','2026-05-22 09:45:00+00'::timestamptz,'vision','storytelling','Class B hospitals are India''s healthcare backbone','60-200 bed facilities serve 70% of districts. They deserve OEM-grade service.',19800,712,103,81,9.30,'posted'),
('post-jun-engineer-09','Q2',2026,'Jun 2026','2026-06-04 10:15:00+00'::timestamptz,'engineer_pride','founder_first_person','Our engineers are not "gig workers"','Tier-1 engineers earn ₹84,000/month + paid AMC training + ESOPs. This is the trade we''re rebuilding.',35200,1789,298,234,9.70,'posted'),
('post-jun-market-10','Q2',2026,'Jun 2026','2026-06-11 08:30:00+00'::timestamptz,'market_intel','contrarian','Stop calling biomedical engineers "technicians"','It''s electrical, mechanical, software, AND patient-safety. Doctors don''t fix the lights.',29400,1340,267,198,9.00,'posted'),
('post-jun-customer-11','Q2',2026,'Jun 2026','2026-06-18 11:00:00+00'::timestamptz,'customer_story','data_driven','Hyderabad chain saved ₹18 lakh in Q1 via predictive maintenance','12 hospitals, 340 machines, zero unplanned downtime in 90 days.',26800,981,156,127,9.30,'posted'),
('post-jun-pov-12','Q2',2026,'Jun 2026','2026-06-25 09:30:00+00'::timestamptz,'founder_pov','founder_first_person','I''m not building a marketplace. I''m building a guild.','Every engineer on EquipSeva is certified, ranked, bonded, and paid like a senior trade.',41200,2456,498,398,9.90,'posted'),
('post-jul-product-13','Q2',2026,'Jul 2026','2026-07-08 10:00:00+00'::timestamptz,'product_update','celebratory','EquipSeva Engineer App v0.5 ships AMC tier upgrades in-app','From paper certificate to tap-to-upgrade in 18 months. Engineers, this is yours.',18900,890,76,52,8.80,'scheduled'),
('post-jul-culture-14','Q2',2026,'Jul 2026','2026-07-15 14:30:00+00'::timestamptz,'culture','storytelling','How we hired our first 100 engineers without job boards','Word-of-mouth in trade colleges. Loyalty before scale.',16400,720,98,71,9.10,'scheduled'),
('post-jul-vision-15','Q2',2026,'Jul 2026','2026-07-22 09:15:00+00'::timestamptz,'vision','contrarian','India doesn''t need more healthtech apps. It needs reliable wrenches.','The next ₹10,000cr healthcare company will be unsexy, blue-collar, and essential.',0,0,0,0,9.40,'drafted'),
('post-may-archived-16','Q1',2026,'May 2026','2026-05-29 16:00:00+00'::timestamptz,'product_update','data_driven','Synergizing biomedical asset orchestration via cross-platform paradigms','Removed for off-brand jargon. Replaced by post #6.',4200,42,8,2,3.20,'archived');

INSERT INTO linkedin_brand_voice_posts_r2941 (post_slug, quarter, fiscal_year, month_label, posted_at, pillar, voice_tone, headline, body_excerpt, impressions, reactions, comments_count, reposts, on_brand_score, status) VALUES
('post-apr-celebratory-17','Q1',2026,'Apr 2026','2026-04-28 12:00:00+00'::timestamptz,'culture','celebratory','EquipSeva crossed 500 hospitals served','Two years ago, we had three engineers and one ventilator client.',19200,920,124,93,9.20,'posted'),
('post-jul-engineer-18','Q2',2026,'Jul 2026','2026-07-29 09:00:00+00'::timestamptz,'engineer_pride','data_driven','Tier-2 engineers earn 2.3× ITI average','Trade work pays. We''re proving it monthly.',0,0,0,0,9.30,'drafted');

INSERT INTO linkedin_brand_voice_audits_r2941 (audit_slug, audit_month, audit_period_start, audit_period_end, posts_reviewed, off_brand_count, voice_drift_dimension, severity, drift_summary, corrective_action, audit_status) VALUES
('audit-apr-2026','Apr 2026','2026-04-01'::date,'2026-04-30'::date,5,0,'tone','p3','All April posts held first-person founder voice. Engineer pillar slightly under-represented at 20%.','Increase engineer_pride pillar to 28% in May plan.','resolved'),
('audit-may-2026','May 2026','2026-05-01'::date,'2026-05-31'::date,5,1,'jargon','p1','One post (#16) shipped with corporate-jargon language inconsistent with founder voice. Archived within 6 hours.','Add jargon-screen RPC to pre-publish flow. Two-reviewer check on product_update pillar.','resolved'),
('audit-may-cadence','May 2026','2026-05-01'::date,'2026-05-31'::date,5,0,'cadence','p2','Posting cadence drifted to weekly average 8.4 days vs 7-day target.','Lock Tuesday 09:00 IST + Thursday 11:00 IST slots in calendar.','resolved'),
('audit-jun-2026','Jun 2026','2026-06-01'::date,'2026-06-30'::date,4,0,'pillar_mix','p2','Founder POV pillar over-indexed at 35% vs 20% target. Risk of personality-cult drift.','Cap founder_pov at 22% of monthly mix. Rotate to vision + market_intel.','in_review'),
('audit-jun-hook','Jun 2026','2026-06-01'::date,'2026-06-30'::date,4,0,'hook_quality','p3','Average first-line hook strength scored 8.7/10. On target.','Maintain hook-template library. Quarterly refresh.','resolved'),
('audit-jul-2026','Jul 2026','2026-07-01'::date,'2026-07-31'::date,4,0,'authenticity','p1','Two scheduled drafts read AI-polished. Re-edit needed for founder cadence.','Hand-edit drafts 13 and 18 before scheduling. Add em-dash + contraction pass.','open'),
('audit-q1-rollup','Q1 FY26','2026-04-01'::date,'2026-06-30'::date,14,1,'tone','p2','Q1 voice consistency 93.5%. One archived post. Founder-first-person held 65% of pillar slots.','Publish Q1 brand voice report internally. Refresh tone guide.','in_review'),
('audit-q2-prep','Q2 FY26','2026-07-01'::date,'2026-09-30'::date,2,0,'pillar_mix','p2','Q2 plan over-weights product_update pillar (40%) due to v0.5+v0.6 ship cadence. Risk of dry feed.','Add storytelling wrapper to every product_update post in Q2.','open'),
('audit-jargon-class','May 2026','2026-05-15'::date,'2026-05-31'::date,3,1,'jargon','p1','Pattern detected: "synergize", "paradigm", "ecosystem" appeared in 3 drafts after marketing-agency review.','Ban list added to pre-publish linter. Marketing-agency drafts go through founder voice-pass.','resolved'),
('audit-authenticity-q1','Q1 FY26','2026-04-01'::date,'2026-06-30'::date,14,2,'authenticity','p2','Two posts (#3, #11) read data-report-style without founder voice wrapper.','Mandate founder first-line + last-line on all data_driven posts.','accepted_drift'),
('audit-cadence-q1','Q1 FY26','2026-04-01'::date,'2026-06-30'::date,14,0,'cadence','p3','Q1 cadence 7.2 day average. On target.','None — maintain.','resolved'),
('audit-hook-q1','Q1 FY26','2026-04-01'::date,'2026-06-30'::date,14,0,'hook_quality','p3','Q1 hook quality avg 9.1/10. Top quartile vs LinkedIn benchmark.','Document top-5 hook templates for Q2.','resolved'),
('audit-p0-zero','Q1 FY26','2026-04-01'::date,'2026-06-30'::date,14,0,'tone','p0','Zero p0 brand-voice incidents in Q1. No public-facing reputational drift.','Quarterly p0 review continues.','resolved'),
('audit-quarterly-strategy','Q2 FY26','2026-07-01'::date,'2026-09-30'::date,0,0,'pillar_mix','p2','Strategic quarterly review: founder voice is differentiating moat. Lean further into contrarian + founder_pov.','Increase contrarian_tone share from 12% to 20% in Q2.','open');

CREATE OR REPLACE FUNCTION fn_r2941_posts_overview()
RETURNS TABLE (post_slug text, quarter text, month_label text, pillar text, voice_tone text, headline text, impressions int, reactions int, on_brand_score numeric, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.post_slug, p.quarter, p.month_label, p.pillar, p.voice_tone, p.headline, p.impressions, p.reactions, p.on_brand_score, p.status
    FROM linkedin_brand_voice_posts_r2941 p ORDER BY p.posted_at DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_monthly_engagement_rollup()
RETURNS TABLE (month_label text, posts_count int, total_impressions bigint, total_reactions bigint, avg_brand_score numeric, posted_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.month_label, count(*)::int AS posts_count,
    sum(p.impressions)::bigint, sum(p.reactions)::bigint,
    round(avg(p.on_brand_score),2),
    (count(*) filter (where p.status='posted'))::int
    FROM linkedin_brand_voice_posts_r2941 p
    GROUP BY p.month_label ORDER BY min(p.posted_at) DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_pillar_mix()
RETURNS TABLE (pillar text, post_count int, posted_count int, avg_brand_score numeric, total_impressions bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.pillar, count(*)::int,
    (count(*) filter (where p.status='posted'))::int,
    round(avg(p.on_brand_score),2),
    sum(p.impressions)::bigint
    FROM linkedin_brand_voice_posts_r2941 p
    GROUP BY p.pillar ORDER BY count(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_voice_tone_distribution()
RETURNS TABLE (voice_tone text, post_count int, avg_brand_score numeric, avg_impressions numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.voice_tone, count(*)::int,
    round(avg(p.on_brand_score),2),
    round(avg(p.impressions),0)
    FROM linkedin_brand_voice_posts_r2941 p
    GROUP BY p.voice_tone ORDER BY count(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_audit_queue()
RETURNS TABLE (audit_slug text, audit_month text, voice_drift_dimension text, severity text, posts_reviewed int, off_brand_count int, drift_summary text, audit_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.audit_slug, a.audit_month, a.voice_drift_dimension, a.severity, a.posts_reviewed, a.off_brand_count, a.drift_summary, a.audit_status
    FROM linkedin_brand_voice_audits_r2941 a
    ORDER BY CASE a.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
             a.audit_period_end DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_drift_by_dimension()
RETURNS TABLE (voice_drift_dimension text, audit_count int, open_count int, total_off_brand bigint, worst_severity text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.voice_drift_dimension, count(*)::int,
    (count(*) filter (where a.audit_status IN ('open','in_review')))::int,
    sum(a.off_brand_count)::bigint,
    min(a.severity)
    FROM linkedin_brand_voice_audits_r2941 a
    GROUP BY a.voice_drift_dimension ORDER BY count(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_quarterly_brand_health()
RETURNS TABLE (quarter text, fiscal_year int, posts_count int, posted_count int, avg_brand_score numeric, total_impressions bigint, off_brand_total bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.quarter, p.fiscal_year, count(*)::int,
    (count(*) filter (where p.status='posted'))::int,
    round(avg(p.on_brand_score),2),
    sum(p.impressions)::bigint,
    COALESCE((SELECT sum(a.off_brand_count) FROM linkedin_brand_voice_audits_r2941 a
              WHERE a.audit_period_start >= make_date(p.fiscal_year, CASE p.quarter WHEN 'Q1' THEN 4 WHEN 'Q2' THEN 7 WHEN 'Q3' THEN 10 ELSE 1 END, 1)),0)::bigint
    FROM linkedin_brand_voice_posts_r2941 p
    GROUP BY p.quarter, p.fiscal_year ORDER BY p.fiscal_year DESC, p.quarter DESC;
END $$;

CREATE OR REPLACE FUNCTION fn_r2941_top_posts_by_engagement()
RETURNS TABLE (post_slug text, headline text, pillar text, voice_tone text, impressions int, reactions int, reposts int, engagement_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.post_slug, p.headline, p.pillar, p.voice_tone, p.impressions, p.reactions, p.reposts,
    CASE WHEN p.impressions > 0 THEN round((p.reactions + p.comments_count + p.reposts)::numeric / p.impressions * 100, 2) ELSE 0 END
    FROM linkedin_brand_voice_posts_r2941 p
    WHERE p.status = 'posted'
    ORDER BY p.impressions DESC LIMIT 10;
END $$;

REVOKE EXECUTE ON FUNCTION fn_r2941_posts_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_monthly_engagement_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_pillar_mix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_voice_tone_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_audit_queue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_drift_by_dimension() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_quarterly_brand_health() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION fn_r2941_top_posts_by_engagement() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION fn_r2941_posts_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_monthly_engagement_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_pillar_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_voice_tone_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_audit_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_drift_by_dimension() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_quarterly_brand_health() TO authenticated;
GRANT EXECUTE ON FUNCTION fn_r2941_top_posts_by_engagement() TO authenticated;
