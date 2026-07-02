BEGIN;

-- =====================================================================
-- Round 2769: Founder Quarterly Investor Update — Narrative Test
-- Audience x Narrative x Pull Quote x Reaction x Refine x Send Decision
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: Narrative drafts under test
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS investor_update_narratives_r2769 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  audience_segment text NOT NULL CHECK (audience_segment IN ('lead_vc','follow_vc','angel','strategic','board')),
  narrative_angle text NOT NULL CHECK (narrative_angle IN ('growth','efficiency','moat','market','team','vision')),
  headline text NOT NULL,
  pull_quote text NOT NULL,
  body_md text NOT NULL,
  word_count integer NOT NULL CHECK (word_count >= 50),
  status text NOT NULL CHECK (status IN ('draft','testing','refined','approved','sent','killed')),
  drafted_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  sent_at timestamptz
);

ALTER TABLE investor_update_narratives_r2769 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON investor_update_narratives_r2769;
CREATE POLICY founder_all ON investor_update_narratives_r2769
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO investor_update_narratives_r2769
  (quarter, audience_segment, narrative_angle, headline, pull_quote, body_md, word_count, status, drafted_at, approved_at, sent_at)
VALUES
  ('Q2-2026','lead_vc','growth','GMV doubled in 90 days','We crossed 12 Cr GMV with 38 percent gross margin — no paid acquisition.',
   'Q2 closed at 12.4 Cr GMV vs 6.1 Cr in Q1. Organic referral mix held at 71 percent. Margin expansion came from spare-parts pool savings, not price hikes.',
   62,'sent','2026-06-15 09:00+05:30'::timestamptz,'2026-06-17 11:00+05:30'::timestamptz,'2026-06-18 08:00+05:30'::timestamptz),
  ('Q2-2026','follow_vc','efficiency','Burn down 40 percent quarter on quarter','We are now default-alive at current MRR; 22 months runway with no new raise.',
   'Burn dropped from 78L per month to 47L. Engineer payout automation and AMC pool collateralization removed the working-capital drag.',
   55,'approved','2026-06-15 09:10+05:30'::timestamptz,'2026-06-17 11:05+05:30'::timestamptz,NULL),
  ('Q2-2026','angel','moat','Hospital chains lock in 3-year AMCs','Apollo and Yashoda renewed early — the only vendor with NABH-compliant audit trail.',
   'Five Tier-1 hospital chains signed multi-year AMCs this quarter. Lock-in driven by our NABH-grade audit ZIP and same-day MTBF reporting.',
   58,'refined','2026-06-15 09:20+05:30'::timestamptz,NULL,NULL),
  ('Q2-2026','strategic','market','Class A and B medical equipment is a 4200 Cr TAM','We service 14 of the top 20 device categories — the long-tail no OEM wants to touch.',
   'India Class A and B installed base sits at 4200 Cr in annual service spend. We hold 0.3 percent share — meaningful room before any direct competitor.',
   60,'testing','2026-06-15 09:30+05:30'::timestamptz,NULL,NULL),
  ('Q2-2026','board','vision','Path to 100 Cr ARR by FY27','Three verticals, one platform, zero ad spend.',
   'Roadmap covers super-specialty (oncology, cardiac, dental), franchise expansion across 12 metros, and international pilots in Sri Lanka and Bangladesh.',
   54,'draft','2026-06-15 09:40+05:30'::timestamptz,NULL,NULL),
  ('Q2-2026','lead_vc','team','Engineer headcount doubled, churn stayed at 4 percent','Tier-1 engineers earn 1.4x market median — none have left in 6 months.',
   'We grew from 42 to 88 certified engineers. Supervised-training ladder and tier-based payouts created retention even competitors notice.',
   57,'killed','2026-06-15 09:50+05:30'::timestamptz,NULL,NULL);

-- ---------------------------------------------------------------------
-- Table 2: Reactions + refinement log per narrative
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS investor_narrative_reactions_r2769 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  narrative_id uuid NOT NULL REFERENCES investor_update_narratives_r2769(id) ON DELETE CASCADE,
  reviewer_name text NOT NULL,
  reviewer_role text NOT NULL CHECK (reviewer_role IN ('founder','board','existing_lp','prospect','advisor')),
  reaction text NOT NULL CHECK (reaction IN ('strong_yes','soft_yes','neutral','soft_no','strong_no')),
  reaction_score integer NOT NULL CHECK (reaction_score BETWEEN 1 AND 10),
  qualitative_note text NOT NULL,
  refinement_suggestion text,
  applied boolean NOT NULL DEFAULT false,
  send_decision text NOT NULL CHECK (send_decision IN ('send_as_is','refine_send','hold','kill')),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE investor_narrative_reactions_r2769 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON investor_narrative_reactions_r2769;
CREATE POLICY founder_all ON investor_narrative_reactions_r2769
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Ravi K (Peak XV)','existing_lp','strong_yes',9,
       'Headline lands. The "no paid acquisition" line is the differentiator.',
       'Add CAC payback months alongside organic mix.',true,'refine_send','2026-06-16 10:00+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE audience_segment='lead_vc' AND narrative_angle='growth';

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Priya M (Blume)','prospect','soft_yes',7,
       'Efficiency story is rare in healthtech — credible.',
       'Show the trailing burn chart, not just the percent.',false,'refine_send','2026-06-16 10:15+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE audience_segment='follow_vc';

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Dr Anand (Angel)','existing_lp','strong_yes',10,
       'NABH lock-in is the actual moat. Lead with this.',
       'Move pull quote up; cut the body to 40 words.',true,'refine_send','2026-06-16 10:30+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE audience_segment='angel';

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Strategic — Siemens India','prospect','neutral',5,
       'TAM number needs primary source citation.',
       'Add footnote with MoHFW + KPMG study reference.',false,'hold','2026-06-16 10:45+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE audience_segment='strategic';

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Board chair','board','soft_yes',7,
       'Vision is right but international pilot reads premature.',
       'Drop SL/BD line for now, keep super-specialty + franchise.',false,'refine_send','2026-06-16 11:00+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE audience_segment='board';

INSERT INTO investor_narrative_reactions_r2769
  (narrative_id, reviewer_name, reviewer_role, reaction, reaction_score, qualitative_note, refinement_suggestion, applied, send_decision, reviewed_at)
SELECT id,'Internal — Ganesh','founder','strong_no',3,
       'Team headcount as a lead is weak. Investors do not buy people stories.',
       'Kill this narrative entirely.',true,'kill','2026-06-16 11:15+05:30'::timestamptz
FROM investor_update_narratives_r2769 WHERE narrative_angle='team';

-- ---------------------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS narrative_test_kpi_r2769();
CREATE OR REPLACE FUNCTION narrative_test_kpi_r2769()
RETURNS TABLE (
  total_narratives bigint,
  sent_count bigint,
  approved_count bigint,
  killed_count bigint,
  avg_reaction_score numeric,
  refine_send_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM investor_update_narratives_r2769),
    (SELECT count(*) FROM investor_update_narratives_r2769 WHERE status='sent'),
    (SELECT count(*) FROM investor_update_narratives_r2769 WHERE status='approved'),
    (SELECT count(*) FROM investor_update_narratives_r2769 WHERE status='killed'),
    (SELECT round(avg(reaction_score)::numeric,2) FROM investor_narrative_reactions_r2769),
    (SELECT round(100.0 * count(*) FILTER (WHERE send_decision='refine_send') / NULLIF(count(*),0)::numeric, 1)
       FROM investor_narrative_reactions_r2769);
END $$;
REVOKE EXECUTE ON FUNCTION narrative_test_kpi_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION narrative_test_kpi_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: Narratives by audience segment
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS narratives_by_audience_r2769();
CREATE OR REPLACE FUNCTION narratives_by_audience_r2769()
RETURNS TABLE (audience_segment text, narrative_count bigint, avg_word_count numeric, sent_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.audience_segment,
         count(*)::bigint,
         round(avg(n.word_count)::numeric,1),
         count(*) FILTER (WHERE n.status='sent')::bigint
  FROM investor_update_narratives_r2769 n
  GROUP BY n.audience_segment
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION narratives_by_audience_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION narratives_by_audience_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: Reactions by angle
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS reactions_by_angle_r2769();
CREATE OR REPLACE FUNCTION reactions_by_angle_r2769()
RETURNS TABLE (narrative_angle text, avg_score numeric, strong_yes_count bigint, strong_no_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.narrative_angle,
         round(avg(r.reaction_score)::numeric,2),
         count(*) FILTER (WHERE r.reaction='strong_yes')::bigint,
         count(*) FILTER (WHERE r.reaction='strong_no')::bigint
  FROM investor_update_narratives_r2769 n
  JOIN investor_narrative_reactions_r2769 r ON r.narrative_id = n.id
  GROUP BY n.narrative_angle
  ORDER BY avg(r.reaction_score) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION reactions_by_angle_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION reactions_by_angle_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: Pull quote leaderboard
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS pull_quote_leaderboard_r2769();
CREATE OR REPLACE FUNCTION pull_quote_leaderboard_r2769()
RETURNS TABLE (headline text, pull_quote text, audience_segment text, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.headline, n.pull_quote, n.audience_segment,
         round(coalesce(avg(r.reaction_score),0)::numeric,2)
  FROM investor_update_narratives_r2769 n
  LEFT JOIN investor_narrative_reactions_r2769 r ON r.narrative_id = n.id
  GROUP BY n.id, n.headline, n.pull_quote, n.audience_segment
  ORDER BY coalesce(avg(r.reaction_score),0) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION pull_quote_leaderboard_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION pull_quote_leaderboard_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: Send decision distribution
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS send_decision_distribution_r2769();
CREATE OR REPLACE FUNCTION send_decision_distribution_r2769()
RETURNS TABLE (send_decision text, decision_count bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM investor_narrative_reactions_r2769;
  RETURN QUERY
  SELECT r.send_decision,
         count(*)::bigint,
         round(100.0 * count(*) / NULLIF(total,0)::numeric, 1)
  FROM investor_narrative_reactions_r2769 r
  GROUP BY r.send_decision
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION send_decision_distribution_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION send_decision_distribution_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: Refinements pending
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS refinements_pending_r2769();
CREATE OR REPLACE FUNCTION refinements_pending_r2769()
RETURNS TABLE (headline text, reviewer_name text, refinement_suggestion text, send_decision text, reviewed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.headline, r.reviewer_name, r.refinement_suggestion, r.send_decision, r.reviewed_at
  FROM investor_narrative_reactions_r2769 r
  JOIN investor_update_narratives_r2769 n ON n.id = r.narrative_id
  WHERE r.applied = false AND r.refinement_suggestion IS NOT NULL
  ORDER BY r.reviewed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION refinements_pending_r2769() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION refinements_pending_r2769() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: Mark refinement applied
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS mark_refinement_applied_r2769(uuid);
CREATE OR REPLACE FUNCTION mark_refinement_applied_r2769(p_reaction_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_narrative_reactions_r2769 SET applied = true WHERE id = p_reaction_id;
  RETURN FOUND;
END $$;
REVOKE EXECUTE ON FUNCTION mark_refinement_applied_r2769(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION mark_refinement_applied_r2769(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 8: Approve narrative for send
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS approve_narrative_r2769(uuid);
CREATE OR REPLACE FUNCTION approve_narrative_r2769(p_narrative_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_update_narratives_r2769
     SET status='approved', approved_at=now()
   WHERE id=p_narrative_id AND status IN ('draft','testing','refined');
  RETURN FOUND;
END $$;
REVOKE EXECUTE ON FUNCTION approve_narrative_r2769(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION approve_narrative_r2769(uuid) TO authenticated;

COMMIT;
