BEGIN;

-- =========================================================================
-- Round 2773 — Founder Monthly Press Relationship Tracker
-- Reporters x outlets x beats x asks x coverage x strength x deepen actions
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: press_reporter_relationships_r2773
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.press_reporter_relationships_r2773 (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_name         text NOT NULL,
  outlet                text NOT NULL,
  beat                  text NOT NULL,
  outlet_tier           text NOT NULL CHECK (outlet_tier IN ('tier_1_national','tier_2_regional','tier_3_trade','tier_4_blog')),
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('cold','warm','engaged','strong','advocate')),
  last_touch_date       date NOT NULL,
  last_ask_summary      text NOT NULL,
  coverage_count_ytd    int  NOT NULL DEFAULT 0 CHECK (coverage_count_ytd >= 0),
  reach_estimate_k      int  NOT NULL DEFAULT 0 CHECK (reach_estimate_k >= 0),
  founder_priority      text NOT NULL CHECK (founder_priority IN ('p0','p1','p2','p3')),
  next_deepen_action    text NOT NULL,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.press_reporter_relationships_r2773 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.press_reporter_relationships_r2773;
CREATE POLICY founder_all ON public.press_reporter_relationships_r2773
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.press_reporter_relationships_r2773
  (reporter_name, outlet, beat, outlet_tier, relationship_strength, last_touch_date, last_ask_summary, coverage_count_ytd, reach_estimate_k, founder_priority, next_deepen_action, notes)
VALUES
  ('Priya Ranjan',   'Economic Times',      'healthtech',       'tier_1_national', 'advocate', '2026-06-15'::date, 'AMC milestone exclusive — 1000 hospitals',  4, 2400, 'p0', 'Offer 2027 Q1 deep-dive on rural reach', 'Quoted founder in 4 stories — strongest tier-1 ally'),
  ('Rahul Sahu',     'Mint',                'startups',         'tier_1_national', 'strong',   '2026-06-10'::date, 'Series A fundraise embargoed brief',         3, 1900, 'p0', 'Lunch in BLR next visit — pitch BLR HQ angle','Wants exclusive on next funding round'),
  ('Anjali Mehta',   'YourStory',           'social_impact',    'tier_2_regional', 'engaged',  '2026-06-08'::date, 'Engineer livelihoods feature pitch',         2,  450, 'p1', 'Send 5 engineer case studies + ride-along offer','Loves human-interest angle on tier-2/3 cities'),
  ('Vikram Iyer',    'Inc42',               'fundraising',      'tier_2_regional', 'engaged',  '2026-06-12'::date, 'Cap table + investor list off-record',       2,  680, 'p1', 'Brief on AMC unit economics for industry report','Building healthtech market map — get cited'),
  ('Sneha Kulkarni', 'Medical Buyer',       'medical_devices',  'tier_3_trade',    'warm',     '2026-06-02'::date, 'OEM partnership ladder commentary',          1,  120, 'p2', 'Submit guest column on Class B service market',  'Trade publication — high biomed-engineer reach'),
  ('Arjun Pillai',   'The Ken',             'business_deep',    'tier_1_national', 'warm',     '2026-05-28'::date, 'Long-form on hospital procurement broken',   0,  900, 'p0', 'Pitch 4-part series — 60 min founder interview', 'Premium readership — board + LPs read religiously'),
  ('Meera Joshi',    'Times of India BLR',  'city_health',      'tier_2_regional', 'cold',     '2026-04-20'::date, 'Pitched but no reply — BLR hospital crunch', 0,  850, 'p2', 'Re-engage via mutual at NABH event July 12',     'Bounce — need warm intro');

-- -------------------------------------------------------------------------
-- Table 2: press_monthly_outreach_log_r2773
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.press_monthly_outreach_log_r2773 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id         uuid NOT NULL REFERENCES public.press_reporter_relationships_r2773(id) ON DELETE CASCADE,
  outreach_month      date NOT NULL,
  outreach_type       text NOT NULL CHECK (outreach_type IN ('cold_pitch','warm_followup','exclusive_offer','press_release','event_invite','off_record_brief','social_engagement')),
  ask_category        text NOT NULL CHECK (ask_category IN ('coverage','quote','feature','interview','data_share','intro','event_attend')),
  ask_summary         text NOT NULL,
  response_status     text NOT NULL CHECK (response_status IN ('no_reply','acknowledged','meeting_set','published','declined','pending')),
  coverage_published  boolean NOT NULL DEFAULT false,
  coverage_url        text,
  founder_satisfaction int CHECK (founder_satisfaction BETWEEN 1 AND 5),
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.press_monthly_outreach_log_r2773 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.press_monthly_outreach_log_r2773;
CREATE POLICY founder_all ON public.press_monthly_outreach_log_r2773
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.press_monthly_outreach_log_r2773
  (reporter_id, outreach_month, outreach_type, ask_category, ask_summary, response_status, coverage_published, coverage_url, founder_satisfaction)
SELECT id, '2026-06-01'::date, 'exclusive_offer',  'feature',    '1000-hospital AMC milestone exclusive',          'published',   true,  'https://economictimes.com/equipseva-1k', 5 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Priya Ranjan'
UNION ALL
SELECT id, '2026-06-01'::date, 'off_record_brief', 'interview',  'Series A intent + cap table walkthrough',        'meeting_set', false, NULL,                                     4 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Rahul Sahu'
UNION ALL
SELECT id, '2026-06-01'::date, 'warm_followup',   'feature',    'Engineer livelihoods — 50 stories',              'acknowledged',false, NULL,                                     3 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Anjali Mehta'
UNION ALL
SELECT id, '2026-06-01'::date, 'press_release',   'coverage',   'AMC tier 3 rural launch announcement',           'published',   true,  'https://inc42.com/equipseva-rural',      4 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Vikram Iyer'
UNION ALL
SELECT id, '2026-06-01'::date, 'cold_pitch',      'quote',      'Quote on OEM service-market structure',          'pending',     false, NULL,                                     2 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Sneha Kulkarni'
UNION ALL
SELECT id, '2026-06-01'::date, 'exclusive_offer', 'interview',  'Long-form series on hospital procurement',       'no_reply',    false, NULL,                                     2 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Arjun Pillai'
UNION ALL
SELECT id, '2026-06-01'::date, 'cold_pitch',      'coverage',   'BLR hospital crunch + EquipSeva fix story',      'no_reply',    false, NULL,                                     1 FROM public.press_reporter_relationships_r2773 WHERE reporter_name = 'Meera Joshi';

-- =========================================================================
-- RPCs
-- =========================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS public.fn_press_relationship_kpis_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_relationship_kpis_r2773()
RETURNS TABLE (
  total_reporters int,
  advocates_strong int,
  engaged_warm int,
  cold int,
  total_coverage_ytd int,
  total_reach_k int,
  p0_priorities int,
  june_outreach_count int,
  june_published_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM press_reporter_relationships_r2773),
    (SELECT count(*)::int FROM press_reporter_relationships_r2773 WHERE relationship_strength IN ('advocate','strong')),
    (SELECT count(*)::int FROM press_reporter_relationships_r2773 WHERE relationship_strength IN ('engaged','warm')),
    (SELECT count(*)::int FROM press_reporter_relationships_r2773 WHERE relationship_strength = 'cold'),
    (SELECT COALESCE(sum(coverage_count_ytd),0)::int FROM press_reporter_relationships_r2773),
    (SELECT COALESCE(sum(reach_estimate_k),0)::int FROM press_reporter_relationships_r2773),
    (SELECT count(*)::int FROM press_reporter_relationships_r2773 WHERE founder_priority = 'p0'),
    (SELECT count(*)::int FROM press_monthly_outreach_log_r2773 WHERE outreach_month = '2026-06-01'::date),
    (SELECT count(*)::int FROM press_monthly_outreach_log_r2773 WHERE outreach_month = '2026-06-01'::date AND coverage_published);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_relationship_kpis_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_relationship_kpis_r2773() TO authenticated;

-- RPC 2: roster ordered by priority + strength
DROP FUNCTION IF EXISTS public.fn_press_roster_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_roster_r2773()
RETURNS TABLE (
  reporter_name text,
  outlet text,
  beat text,
  outlet_tier text,
  relationship_strength text,
  founder_priority text,
  coverage_count_ytd int,
  reach_estimate_k int,
  last_touch_date date,
  next_deepen_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reporter_name, r.outlet, r.beat, r.outlet_tier, r.relationship_strength,
         r.founder_priority, r.coverage_count_ytd, r.reach_estimate_k, r.last_touch_date, r.next_deepen_action
  FROM press_reporter_relationships_r2773 r
  ORDER BY
    CASE r.founder_priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    CASE r.relationship_strength WHEN 'advocate' THEN 0 WHEN 'strong' THEN 1 WHEN 'engaged' THEN 2 WHEN 'warm' THEN 3 ELSE 4 END,
    r.reach_estimate_k DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_roster_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_roster_r2773() TO authenticated;

-- RPC 3: outreach log joined with reporter
DROP FUNCTION IF EXISTS public.fn_press_outreach_log_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_outreach_log_r2773()
RETURNS TABLE (
  outreach_month date,
  reporter_name text,
  outlet text,
  outreach_type text,
  ask_category text,
  ask_summary text,
  response_status text,
  coverage_published boolean,
  founder_satisfaction int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outreach_month, r.reporter_name, r.outlet, o.outreach_type, o.ask_category,
         o.ask_summary, o.response_status, o.coverage_published, o.founder_satisfaction
  FROM press_monthly_outreach_log_r2773 o
  JOIN press_reporter_relationships_r2773 r ON r.id = o.reporter_id
  ORDER BY o.outreach_month DESC,
           CASE o.response_status WHEN 'published' THEN 0 WHEN 'meeting_set' THEN 1 WHEN 'acknowledged' THEN 2 WHEN 'pending' THEN 3 WHEN 'no_reply' THEN 4 ELSE 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_outreach_log_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_outreach_log_r2773() TO authenticated;

-- RPC 4: rollup by beat
DROP FUNCTION IF EXISTS public.fn_press_beat_rollup_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_beat_rollup_r2773()
RETURNS TABLE (
  beat text,
  reporter_count int,
  coverage_ytd int,
  reach_k int,
  avg_strength_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.beat,
         count(*)::int,
         COALESCE(sum(r.coverage_count_ytd),0)::int,
         COALESCE(sum(r.reach_estimate_k),0)::int,
         ROUND(AVG(CASE r.relationship_strength WHEN 'advocate' THEN 5 WHEN 'strong' THEN 4 WHEN 'engaged' THEN 3 WHEN 'warm' THEN 2 ELSE 1 END)::numeric, 2)
  FROM press_reporter_relationships_r2773 r
  GROUP BY r.beat
  ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_beat_rollup_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_beat_rollup_r2773() TO authenticated;

-- RPC 5: rollup by outlet tier
DROP FUNCTION IF EXISTS public.fn_press_tier_rollup_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_tier_rollup_r2773()
RETURNS TABLE (
  outlet_tier text,
  reporter_count int,
  coverage_ytd int,
  reach_k int,
  published_june int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.outlet_tier,
         count(*)::int,
         COALESCE(sum(r.coverage_count_ytd),0)::int,
         COALESCE(sum(r.reach_estimate_k),0)::int,
         (SELECT count(*)::int FROM press_monthly_outreach_log_r2773 o
          JOIN press_reporter_relationships_r2773 r2 ON r2.id = o.reporter_id
          WHERE r2.outlet_tier = r.outlet_tier AND o.outreach_month = '2026-06-01'::date AND o.coverage_published)
  FROM press_reporter_relationships_r2773 r
  GROUP BY r.outlet_tier
  ORDER BY 4 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_tier_rollup_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_tier_rollup_r2773() TO authenticated;

-- RPC 6: stale outreach (no touch > 30d)
DROP FUNCTION IF EXISTS public.fn_press_stale_relationships_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_stale_relationships_r2773()
RETURNS TABLE (
  reporter_name text,
  outlet text,
  founder_priority text,
  relationship_strength text,
  last_touch_date date,
  days_since_touch int,
  next_deepen_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reporter_name, r.outlet, r.founder_priority, r.relationship_strength,
         r.last_touch_date,
         (CURRENT_DATE - r.last_touch_date)::int AS days_since_touch,
         r.next_deepen_action
  FROM press_reporter_relationships_r2773 r
  WHERE (CURRENT_DATE - r.last_touch_date) >= 30
  ORDER BY (CURRENT_DATE - r.last_touch_date) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_stale_relationships_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_stale_relationships_r2773() TO authenticated;

-- RPC 7: deepen action queue (priority p0/p1 with concrete next steps)
DROP FUNCTION IF EXISTS public.fn_press_deepen_queue_r2773();
CREATE OR REPLACE FUNCTION public.fn_press_deepen_queue_r2773()
RETURNS TABLE (
  reporter_name text,
  outlet text,
  founder_priority text,
  relationship_strength text,
  next_deepen_action text,
  reach_estimate_k int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reporter_name, r.outlet, r.founder_priority, r.relationship_strength,
         r.next_deepen_action, r.reach_estimate_k
  FROM press_reporter_relationships_r2773 r
  WHERE r.founder_priority IN ('p0','p1')
  ORDER BY r.founder_priority, r.reach_estimate_k DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_deepen_queue_r2773() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_deepen_queue_r2773() TO authenticated;

-- RPC 8: log new outreach (VOLATILE)
DROP FUNCTION IF EXISTS public.fn_press_log_outreach_r2773(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.fn_press_log_outreach_r2773(
  p_reporter_id uuid,
  p_outreach_type text,
  p_ask_category text,
  p_ask_summary text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO press_monthly_outreach_log_r2773
    (reporter_id, outreach_month, outreach_type, ask_category, ask_summary, response_status, coverage_published)
  VALUES
    (p_reporter_id, date_trunc('month', CURRENT_DATE)::date, p_outreach_type, p_ask_category, p_ask_summary, 'pending', false)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_press_log_outreach_r2773(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_press_log_outreach_r2773(uuid, text, text, text) TO authenticated;

COMMIT;
