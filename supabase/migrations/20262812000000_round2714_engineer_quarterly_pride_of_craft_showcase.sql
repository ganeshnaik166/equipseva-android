BEGIN;

-- ============================================================
-- Round 2714: Engineer Quarterly Pride of Craft Showcase
-- ============================================================

CREATE TABLE IF NOT EXISTS craft_showcase_entries_r2714 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  craft_moment text NOT NULL,
  story text NOT NULL,
  hospital_name text NOT NULL,
  device_category text NOT NULL,
  award_category text NOT NULL CHECK (award_category IN ('innovation','grit','speed','craft','mentorship')),
  peer_votes integer NOT NULL DEFAULT 0 CHECK (peer_votes >= 0),
  judge_score numeric(4,2) NOT NULL DEFAULT 0 CHECK (judge_score >= 0 AND judge_score <= 10),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','shortlisted','finalist','winner','promoted')),
  quarter text NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  promoted_at timestamptz
);

CREATE TABLE IF NOT EXISTS craft_promote_actions_r2714 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid REFERENCES craft_showcase_entries_r2714(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('newsletter','linkedin','website','townhall','bonus','press')),
  reach_count integer NOT NULL DEFAULT 0 CHECK (reach_count >= 0),
  notes text NOT NULL,
  acted_by text NOT NULL,
  acted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE craft_showcase_entries_r2714 ENABLE ROW LEVEL SECURITY;
ALTER TABLE craft_promote_actions_r2714 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON craft_showcase_entries_r2714;
CREATE POLICY founder_all ON craft_showcase_entries_r2714 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON craft_promote_actions_r2714;
CREATE POLICY founder_all ON craft_promote_actions_r2714 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed entries
INSERT INTO craft_showcase_entries_r2714 (engineer_name, engineer_tier, craft_moment, story, hospital_name, device_category, award_category, peer_votes, judge_score, status, quarter, submitted_at) VALUES
('Rakesh Pillai','platinum','3am ventilator rescue','Diagnosed valve failure with stethoscope when scope unavailable; saved 2 ICU patients','Apollo Hyderabad','ventilator','grit',47,9.40,'finalist','Q2-2026','2026-06-10 02:30:00+05:30'::timestamptz),
('Anita Kumari','gold','Custom CT alignment jig','Built 3D-printed alignment jig that cut calibration time 60 percent across 14 sites','Yashoda Secunderabad','ct_scanner','innovation',39,9.10,'winner','Q2-2026','2026-06-12 14:15:00+05:30'::timestamptz),
('Vikram Naidu','gold','Sub-30 min defib turnaround','Closed 18 defib jobs in 28 min average across April surge','KIMS Kondapur','defibrillator','speed',31,8.70,'shortlisted','Q2-2026','2026-06-08 11:00:00+05:30'::timestamptz),
('Priya Reddy','silver','Mentored 6 bronze engineers','Walked 6 junior engineers through MRI cold-head replacement in one quarter','Continental Hospitals','mri','mentorship',28,8.40,'submitted','Q2-2026','2026-06-15 09:45:00+05:30'::timestamptz),
('Mohan Singh','platinum','OT light optical recalibration','Hand-figured optical bench restoring color rendering on 2018 OT lamp','Care Banjara','ot_light','craft',52,9.60,'promoted','Q2-2026','2026-06-05 16:20:00+05:30'::timestamptz),
('Lakshmi Devi','silver','Ultrasound probe rescue','Repaired 4 probes other vendors quoted as scrap; saved 8.2 lakh','Rainbow Hospitals','ultrasound','craft',24,8.20,'shortlisted','Q2-2026','2026-06-18 13:00:00+05:30'::timestamptz);

-- Seed promote actions
INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'newsletter', 4200, 'Featured in June engineer newsletter cover story', 'founder', '2026-06-20 10:00:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Mohan Singh';

INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'linkedin', 18500, 'LinkedIn post: hand-figured optical bench OT lamp restoration', 'founder', '2026-06-21 09:30:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Mohan Singh';

INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'townhall', 320, 'Showcased at all-hands; 5 min standing ovation', 'founder', '2026-06-22 18:00:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Anita Kumari';

INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'bonus', 1, 'Awarded 50k craft bonus + platinum fast-track', 'founder', '2026-06-23 12:00:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Anita Kumari';

INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'press', 12000, 'Pitched to YourStory engineer-of-quarter feature', 'founder', '2026-06-24 11:00:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Rakesh Pillai';

INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by, acted_at)
SELECT id, 'website', 8400, 'Hero card on careers page', 'founder', '2026-06-24 15:30:00+05:30'::timestamptz
FROM craft_showcase_entries_r2714 WHERE engineer_name = 'Mohan Singh';

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_craft_showcase_kpis_r2714();
CREATE OR REPLACE FUNCTION founder_craft_showcase_kpis_r2714()
RETURNS TABLE (
  total_entries integer,
  finalists integer,
  winners integer,
  promoted integer,
  total_peer_votes integer,
  avg_judge_score numeric,
  total_promote_actions integer,
  total_reach integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::integer FROM craft_showcase_entries_r2714),
    (SELECT count(*)::integer FROM craft_showcase_entries_r2714 WHERE status = 'finalist'),
    (SELECT count(*)::integer FROM craft_showcase_entries_r2714 WHERE status = 'winner'),
    (SELECT count(*)::integer FROM craft_showcase_entries_r2714 WHERE status = 'promoted'),
    (SELECT coalesce(sum(peer_votes),0)::integer FROM craft_showcase_entries_r2714),
    (SELECT round(avg(judge_score),2) FROM craft_showcase_entries_r2714),
    (SELECT count(*)::integer FROM craft_promote_actions_r2714),
    (SELECT coalesce(sum(reach_count),0)::integer FROM craft_promote_actions_r2714);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_showcase_kpis_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_showcase_kpis_r2714() TO authenticated;

-- RPC 2: All entries
DROP FUNCTION IF EXISTS founder_craft_showcase_entries_r2714();
CREATE OR REPLACE FUNCTION founder_craft_showcase_entries_r2714()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_tier text,
  craft_moment text,
  hospital_name text,
  device_category text,
  award_category text,
  peer_votes integer,
  judge_score numeric,
  status text,
  quarter text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_name, e.engineer_tier, e.craft_moment, e.hospital_name, e.device_category, e.award_category, e.peer_votes, e.judge_score, e.status, e.quarter
  FROM craft_showcase_entries_r2714 e
  ORDER BY e.judge_score DESC, e.peer_votes DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_showcase_entries_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_showcase_entries_r2714() TO authenticated;

-- RPC 3: Award category breakdown
DROP FUNCTION IF EXISTS founder_craft_award_breakdown_r2714();
CREATE OR REPLACE FUNCTION founder_craft_award_breakdown_r2714()
RETURNS TABLE (
  award_category text,
  entry_count integer,
  total_votes integer,
  avg_score numeric,
  top_engineer text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.award_category,
    count(*)::integer,
    sum(e.peer_votes)::integer,
    round(avg(e.judge_score),2),
    (SELECT e2.engineer_name FROM craft_showcase_entries_r2714 e2
       WHERE e2.award_category = e.award_category
       ORDER BY e2.judge_score DESC LIMIT 1)
  FROM craft_showcase_entries_r2714 e
  GROUP BY e.award_category
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_award_breakdown_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_award_breakdown_r2714() TO authenticated;

-- RPC 4: Tier leaderboard
DROP FUNCTION IF EXISTS founder_craft_tier_leaderboard_r2714();
CREATE OR REPLACE FUNCTION founder_craft_tier_leaderboard_r2714()
RETURNS TABLE (
  engineer_tier text,
  entries integer,
  votes integer,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_tier, count(*)::integer, sum(e.peer_votes)::integer, round(avg(e.judge_score),2)
  FROM craft_showcase_entries_r2714 e
  GROUP BY e.engineer_tier
  ORDER BY avg(e.judge_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_tier_leaderboard_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_tier_leaderboard_r2714() TO authenticated;

-- RPC 5: Promote actions feed
DROP FUNCTION IF EXISTS founder_craft_promote_actions_r2714();
CREATE OR REPLACE FUNCTION founder_craft_promote_actions_r2714()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  action_type text,
  reach_count integer,
  notes text,
  acted_by text,
  acted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, e.engineer_name, a.action_type, a.reach_count, a.notes, a.acted_by, a.acted_at
  FROM craft_promote_actions_r2714 a
  JOIN craft_showcase_entries_r2714 e ON e.id = a.entry_id
  ORDER BY a.acted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_promote_actions_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_promote_actions_r2714() TO authenticated;

-- RPC 6: Top stories
DROP FUNCTION IF EXISTS founder_craft_top_stories_r2714();
CREATE OR REPLACE FUNCTION founder_craft_top_stories_r2714()
RETURNS TABLE (
  engineer_name text,
  story text,
  hospital_name text,
  award_category text,
  judge_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.story, e.hospital_name, e.award_category, e.judge_score
  FROM craft_showcase_entries_r2714 e
  ORDER BY e.judge_score DESC
  LIMIT 5;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_top_stories_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_top_stories_r2714() TO authenticated;

-- RPC 7: Promote entry
DROP FUNCTION IF EXISTS founder_craft_promote_entry_r2714(uuid, text, integer, text);
CREATE OR REPLACE FUNCTION founder_craft_promote_entry_r2714(p_entry_id uuid, p_action_type text, p_reach integer, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO craft_promote_actions_r2714 (entry_id, action_type, reach_count, notes, acted_by)
  VALUES (p_entry_id, p_action_type, p_reach, p_notes, 'founder')
  RETURNING id INTO v_id;
  UPDATE craft_showcase_entries_r2714 SET status = 'promoted', promoted_at = now()
    WHERE id = p_entry_id AND status IN ('winner','finalist','shortlisted');
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_promote_entry_r2714(uuid, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_promote_entry_r2714(uuid, text, integer, text) TO authenticated;

-- RPC 8: Channel mix
DROP FUNCTION IF EXISTS founder_craft_channel_mix_r2714();
CREATE OR REPLACE FUNCTION founder_craft_channel_mix_r2714()
RETURNS TABLE (
  action_type text,
  action_count integer,
  total_reach integer,
  avg_reach numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_type, count(*)::integer, sum(a.reach_count)::integer, round(avg(a.reach_count),0)
  FROM craft_promote_actions_r2714 a
  GROUP BY a.action_type
  ORDER BY sum(a.reach_count) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_craft_channel_mix_r2714() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_craft_channel_mix_r2714() TO authenticated;

COMMIT;