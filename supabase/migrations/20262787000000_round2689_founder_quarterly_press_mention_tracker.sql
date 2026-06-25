BEGIN;

-- =====================================================================
-- Round 2689 — Founder Quarterly Press Mention Tracker
-- publication x topic x sentiment x reach x follow-up x business impact
-- =====================================================================

CREATE TABLE IF NOT EXISTS press_mentions_r2689 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL CHECK (quarter IN ('2026Q1','2026Q2','2026Q3','2026Q4','2027Q1')),
  publication text NOT NULL,
  publication_tier text NOT NULL CHECK (publication_tier IN ('tier1_national','tier1_business','tier2_trade','tier3_regional','online_only','podcast')),
  article_title text NOT NULL,
  article_url text NOT NULL,
  published_at timestamptz NOT NULL,
  reporter_name text NOT NULL,
  topic text NOT NULL CHECK (topic IN ('funding','product_launch','founder_profile','market_analysis','customer_story','regulatory','partnership','exit_milestone')),
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative','mixed')),
  prominence text NOT NULL CHECK (prominence IN ('hero_feature','quoted_extensively','quoted_briefly','mentioned','passing_reference')),
  est_reach integer NOT NULL CHECK (est_reach >= 0),
  est_uvm_rupees_value integer NOT NULL CHECK (est_uvm_rupees_value >= 0),
  word_count integer NOT NULL CHECK (word_count >= 0),
  syndicated_count integer NOT NULL DEFAULT 0 CHECK (syndicated_count >= 0),
  social_shares integer NOT NULL DEFAULT 0 CHECK (social_shares >= 0),
  status text NOT NULL CHECK (status IN ('live','syndicated','archived','retracted')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE press_mentions_r2689 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON press_mentions_r2689;
CREATE POLICY founder_all ON press_mentions_r2689 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS press_mention_followups_r2689 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mention_id uuid NOT NULL REFERENCES press_mentions_r2689(id) ON DELETE CASCADE,
  followup_type text NOT NULL CHECK (followup_type IN ('inbound_lead','customer_inquiry','investor_outreach','partnership_intro','recruiting_application','speaking_invite','followup_article','correction_filed')),
  source_party text NOT NULL,
  business_impact text NOT NULL CHECK (business_impact IN ('signed_deal','qualified_pipeline','exploratory','no_action','negative_outcome')),
  pipeline_rupees integer NOT NULL DEFAULT 0 CHECK (pipeline_rupees >= 0),
  closed_rupees integer NOT NULL DEFAULT 0 CHECK (closed_rupees >= 0),
  days_to_response integer NOT NULL CHECK (days_to_response >= 0),
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE press_mention_followups_r2689 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON press_mention_followups_r2689;
CREATE POLICY founder_all ON press_mention_followups_r2689 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: press mentions
INSERT INTO press_mentions_r2689 (quarter, publication, publication_tier, article_title, article_url, published_at, reporter_name, topic, sentiment, prominence, est_reach, est_uvm_rupees_value, word_count, syndicated_count, social_shares, status) VALUES
('2026Q2','Economic Times','tier1_business','How EquipSeva is fixing hospital equipment downtime','https://economictimes.com/equipseva-feature','2026-04-12 09:00:00+00','Priya Menon','founder_profile','positive','hero_feature',850000,1850000,1640,12,3400,'syndicated'),
('2026Q2','YourStory','tier2_trade','EquipSeva raises seed round to scale AMC marketplace','https://yourstory.com/equipseva-seed','2026-05-03 06:30:00+00','Rohan Kapoor','funding','positive','quoted_extensively',420000,680000,920,8,2100,'live'),
('2026Q1','Mint','tier1_business','India hospitals push for transparent equipment contracts','https://livemint.com/hospital-equipment','2026-02-22 11:15:00+00','Anjali Desai','market_analysis','neutral','quoted_briefly',610000,420000,1200,3,540,'live'),
('2026Q3','The Ken','tier2_trade','The repair economy behind Tier-2 hospitals','https://the-ken.com/repair-economy','2026-07-18 08:00:00+00','Vikram Shah','market_analysis','positive','quoted_extensively',180000,520000,2400,2,890,'live'),
('2026Q2','Inc42 Podcast','podcast','Founder candid: building deep ops with engineers','https://inc42.com/podcast-equipseva','2026-06-04 14:00:00+00','Suresh Iyer','founder_profile','positive','hero_feature',95000,210000,0,1,650,'live'),
('2026Q1','Times of India','tier1_national','Counterfeit medical parts crisis exposed','https://toi.com/counterfeit-parts','2026-03-08 07:45:00+00','Meera Rao','regulatory','mixed','mentioned',1200000,180000,780,15,1850,'syndicated'),
('2026Q3','Medical Buyer','tier2_trade','AMC tier-3 cities see growth uptick','https://medicalbuyer.com/tier3-growth','2026-08-21 10:00:00+00','Arjun Pillai','partnership','positive','quoted_briefly',45000,95000,650,1,210,'live');

-- Seeds: followups
INSERT INTO press_mention_followups_r2689 (mention_id, followup_type, source_party, business_impact, pipeline_rupees, closed_rupees, days_to_response, notes) VALUES
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'How EquipSeva is fixing%'),'inbound_lead','Apollo Hospitals Hyderabad','qualified_pipeline',4200000,0,3,'Procurement head reached out for AMC pitch'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'How EquipSeva is fixing%'),'investor_outreach','Sequoia India','signed_deal',0,15000000,7,'Led to seed extension conversation'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'EquipSeva raises seed%'),'recruiting_application','Senior PM ex-Razorpay','signed_deal',0,2400000,5,'Hired as Head of Product Q3'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'EquipSeva raises seed%'),'partnership_intro','Siemens Healthineers India','qualified_pipeline',6800000,0,9,'OEM parts partnership discussion ongoing'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'India hospitals push%'),'customer_inquiry','KIMS Secunderabad','exploratory',1200000,0,12,'Asked for AMC reference deck'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'The repair economy%'),'speaking_invite','NATHEALTH Summit','no_action',0,0,4,'Founder keynote slot confirmed'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'Founder candid:%'),'inbound_lead','Manipal Hospitals','qualified_pipeline',3800000,0,2,'Listened to podcast, want demo'),
((SELECT id FROM press_mentions_r2689 WHERE article_title LIKE 'Counterfeit medical parts%'),'correction_filed','TOI Editorial','negative_outcome',0,0,1,'Asked for clarification on EquipSeva quote scope');

-- =====================================================================
-- RPCs
-- =====================================================================

DROP FUNCTION IF EXISTS rpc_r2689_quarterly_kpis();
CREATE OR REPLACE FUNCTION rpc_r2689_quarterly_kpis()
RETURNS TABLE(metric text, value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'total_mentions'::text, count(*)::numeric FROM press_mentions_r2689 WHERE status != 'retracted'
  UNION ALL
  SELECT 'total_reach', COALESCE(sum(est_reach),0)::numeric FROM press_mentions_r2689 WHERE status != 'retracted'
  UNION ALL
  SELECT 'total_uvm_rupees_value', COALESCE(sum(est_uvm_rupees_value),0)::numeric FROM press_mentions_r2689
  UNION ALL
  SELECT 'positive_share_pct',
    CASE WHEN count(*) = 0 THEN 0
    ELSE round(100.0 * count(*) FILTER (WHERE sentiment = 'positive') / count(*), 1) END
    FROM press_mentions_r2689
  UNION ALL
  SELECT 'pipeline_rupees', COALESCE(sum(pipeline_rupees),0)::numeric FROM press_mention_followups_r2689
  UNION ALL
  SELECT 'closed_rupees', COALESCE(sum(closed_rupees),0)::numeric FROM press_mention_followups_r2689
  UNION ALL
  SELECT 'tier1_mentions', count(*)::numeric FROM press_mentions_r2689 WHERE publication_tier IN ('tier1_national','tier1_business');
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_quarterly_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_quarterly_kpis() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_mentions_by_quarter();
CREATE OR REPLACE FUNCTION rpc_r2689_mentions_by_quarter()
RETURNS TABLE(quarter text, mention_count bigint, total_reach bigint, positive_count bigint, uvm_value bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.quarter, count(*)::bigint, sum(m.est_reach)::bigint,
    count(*) FILTER (WHERE m.sentiment = 'positive')::bigint,
    sum(m.est_uvm_rupees_value)::bigint
  FROM press_mentions_r2689 m
  GROUP BY m.quarter
  ORDER BY m.quarter DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_mentions_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_mentions_by_quarter() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_topic_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2689_topic_breakdown()
RETURNS TABLE(topic text, mention_count bigint, avg_reach numeric, positive_pct numeric, total_pipeline bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.topic, count(*)::bigint, round(avg(m.est_reach)::numeric, 0),
    round(100.0 * count(*) FILTER (WHERE m.sentiment = 'positive') / NULLIF(count(*),0), 1),
    COALESCE(sum(f.pipeline_rupees),0)::bigint
  FROM press_mentions_r2689 m
  LEFT JOIN press_mention_followups_r2689 f ON f.mention_id = m.id
  GROUP BY m.topic
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_topic_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_topic_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_publication_leaderboard();
CREATE OR REPLACE FUNCTION rpc_r2689_publication_leaderboard()
RETURNS TABLE(publication text, publication_tier text, mention_count bigint, total_reach bigint, avg_word_count numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.publication, m.publication_tier, count(*)::bigint, sum(m.est_reach)::bigint, round(avg(m.word_count)::numeric, 0)
  FROM press_mentions_r2689 m
  GROUP BY m.publication, m.publication_tier
  ORDER BY sum(m.est_reach) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_publication_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_publication_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_sentiment_matrix();
CREATE OR REPLACE FUNCTION rpc_r2689_sentiment_matrix()
RETURNS TABLE(sentiment text, prominence text, mention_count bigint, total_reach bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.sentiment, m.prominence, count(*)::bigint, sum(m.est_reach)::bigint
  FROM press_mentions_r2689 m
  GROUP BY m.sentiment, m.prominence
  ORDER BY sum(m.est_reach) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_sentiment_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_sentiment_matrix() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_followup_impact();
CREATE OR REPLACE FUNCTION rpc_r2689_followup_impact()
RETURNS TABLE(followup_type text, business_impact text, followup_count bigint, pipeline_total bigint, closed_total bigint, avg_response_days numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.followup_type, f.business_impact, count(*)::bigint, sum(f.pipeline_rupees)::bigint, sum(f.closed_rupees)::bigint, round(avg(f.days_to_response)::numeric, 1)
  FROM press_mention_followups_r2689 f
  GROUP BY f.followup_type, f.business_impact
  ORDER BY sum(f.closed_rupees) DESC, sum(f.pipeline_rupees) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_followup_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_followup_impact() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_top_mentions();
CREATE OR REPLACE FUNCTION rpc_r2689_top_mentions()
RETURNS TABLE(quarter text, publication text, article_title text, topic text, sentiment text, prominence text, est_reach integer, est_uvm_rupees_value integer, published_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.quarter, m.publication, m.article_title, m.topic, m.sentiment, m.prominence, m.est_reach, m.est_uvm_rupees_value, m.published_at
  FROM press_mentions_r2689 m
  WHERE m.status != 'retracted'
  ORDER BY m.est_reach DESC
  LIMIT 25;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_top_mentions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_top_mentions() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2689_followup_list();
CREATE OR REPLACE FUNCTION rpc_r2689_followup_list()
RETURNS TABLE(publication text, article_title text, followup_type text, source_party text, business_impact text, pipeline_rupees integer, closed_rupees integer, days_to_response integer, recorded_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.publication, m.article_title, f.followup_type, f.source_party, f.business_impact, f.pipeline_rupees, f.closed_rupees, f.days_to_response, f.recorded_at
  FROM press_mention_followups_r2689 f
  JOIN press_mentions_r2689 m ON m.id = f.mention_id
  ORDER BY f.closed_rupees DESC, f.pipeline_rupees DESC
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION rpc_r2689_followup_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2689_followup_list() TO authenticated;

COMMIT;