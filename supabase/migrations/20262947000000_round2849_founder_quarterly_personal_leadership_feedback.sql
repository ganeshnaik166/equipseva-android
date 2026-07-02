BEGIN;

-- ============================================================
-- Round 2849: Founder Quarterly Personal Leadership Feedback
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_leadership_feedback_entries_r2849 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  feedback_giver text NOT NULL,
  giver_role text NOT NULL CHECK (giver_role IN ('investor','advisor','engineer','customer','cofounder_peer','board_member','team_lead')),
  feedback_theme text NOT NULL CHECK (feedback_theme IN ('decisiveness','communication','focus','delegation','listening','urgency','calmness','vision','execution','people')),
  raw_quote text NOT NULL,
  stake_for_founder text NOT NULL CHECK (stake_for_founder IN ('low','medium','high','critical')),
  candor_score int NOT NULL CHECK (candor_score BETWEEN 1 AND 10),
  pattern_recurrence int NOT NULL DEFAULT 1,
  received_at date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_leadership_feedback_entries_r2849 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_leadership_feedback_entries_r2849;
CREATE POLICY founder_all ON founder_leadership_feedback_entries_r2849 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_leadership_adjustments_r2849 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid REFERENCES founder_leadership_feedback_entries_r2849(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  adjustment_title text NOT NULL,
  commit_action text NOT NULL,
  commit_owner text NOT NULL DEFAULT 'founder',
  commit_due date NOT NULL,
  outcome_observed text,
  measurable_delta text,
  verdict text NOT NULL CHECK (verdict IN ('pending','in_progress','adopted','rejected','partial','reverted')),
  difficulty int NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
  reviewed_at date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_leadership_adjustments_r2849 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_leadership_adjustments_r2849;
CREATE POLICY founder_all ON founder_leadership_adjustments_r2849 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed feedback entries
INSERT INTO founder_leadership_feedback_entries_r2849 (quarter_label, feedback_giver, giver_role, feedback_theme, raw_quote, stake_for_founder, candor_score, pattern_recurrence, received_at, notes) VALUES
('Q1-2026','Priya Mehta (Lead Investor)','investor','decisiveness','You take 3 weeks to kill a feature that everyone in the room knew was dead in week 1.','critical',9,3,'2026-03-12'::date,'Repeated for 3 quarters'),
('Q1-2026','Dr. Anand Rao (Medical Advisor)','advisor','listening','You answer before the customer finishes the sentence — you are pattern-matching too fast.','high',8,2,'2026-03-18'::date,'Hospital chain meetings'),
('Q1-2026','Ramesh K. (Senior Engineer)','engineer','delegation','You rewrite my code at 1am instead of telling me what is wrong.','high',10,4,'2026-03-22'::date,'Trust + scale blocker'),
('Q1-2026','Apollo Hyderabad CTO','customer','communication','Your roadmap emails are 2000 words — I read the first paragraph.','medium',7,1,'2026-04-02'::date,'Customer comms'),
('Q1-2026','Board Member (Nidhi S.)','board_member','focus','You shipped 1700 features. Which 5 made revenue?','critical',10,2,'2026-04-08'::date,'Board pack pushback'),
('Q1-2026','Kavya R. (Team Lead)','team_lead','urgency','Everything is P0. When everything is urgent, nothing is.','high',8,3,'2026-04-15'::date,'Triage discipline'),
('Q1-2026','Sameer Joshi (Advisor)','advisor','calmness','You sound panicked on Slack at 11pm. Team mirrors your nervous system.','high',9,2,'2026-04-20'::date,'Emotional contagion');

-- Seed adjustments
INSERT INTO founder_leadership_adjustments_r2849 (quarter_label, adjustment_title, commit_action, commit_due, outcome_observed, measurable_delta, verdict, difficulty, reviewed_at) VALUES
('Q1-2026','48-hour kill rule','Any feature with no traction in 48h gets killed in standup','2026-04-30'::date,'Killed 12 dead features in Q1 vs avg 3','-9 dead features','adopted',3,'2026-05-15'::date),
('Q1-2026','Listen 30 seconds','Set silent 30s timer before responding in customer calls','2026-04-15'::date,'Customer call NPS rose from 7.1 to 8.4','+1.3 NPS','adopted',4,'2026-05-10'::date),
('Q1-2026','No 1am code rewrites','Hand back to engineer with written review by EOD','2026-05-01'::date,'2 rewrites in Q1, was 14','-12 rewrites','partial',5,'2026-05-20'::date),
('Q1-2026','TL;DR top of every email','Force 3-line summary at top of every customer email','2026-04-10'::date,'Customer reply rate 41% to 73%','+32pp reply','adopted',2,'2026-05-05'::date),
('Q1-2026','5-feature revenue map','Maintain live map of top-5 revenue-driving features','2026-05-15'::date,'Identified 3 features driving 67% revenue','67% rev concentration','adopted',3,'2026-05-25'::date),
('Q1-2026','P0/P1/P2 weekly cap','Max 2 P0s per week, hard cap','2026-04-22'::date,'Team reports less burnout, focus rising','3.2 P0/wk to 1.8','in_progress',4,'2026-05-18'::date),
('Q1-2026','No Slack after 9pm','Drafts only, send at 8am next day','2026-04-25'::date,NULL,NULL,'pending',5,NULL);

-- ============================================================
-- RPCs (7+)
-- ============================================================

DROP FUNCTION IF EXISTS founder_leadership_feedback_summary_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_feedback_summary_r2849()
RETURNS TABLE (
  total_entries bigint,
  critical_stake bigint,
  avg_candor numeric,
  recurring_patterns bigint,
  themes_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE stake_for_founder = 'critical')::bigint,
    ROUND(AVG(candor_score)::numeric, 2),
    COUNT(*) FILTER (WHERE pattern_recurrence >= 2)::bigint,
    COUNT(DISTINCT feedback_theme)::bigint
  FROM founder_leadership_feedback_entries_r2849;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_feedback_summary_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_feedback_summary_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_feedback_list_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_feedback_list_r2849()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  feedback_giver text,
  giver_role text,
  feedback_theme text,
  raw_quote text,
  stake_for_founder text,
  candor_score int,
  pattern_recurrence int,
  received_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.quarter_label, e.feedback_giver, e.giver_role, e.feedback_theme,
         e.raw_quote, e.stake_for_founder, e.candor_score, e.pattern_recurrence, e.received_at
  FROM founder_leadership_feedback_entries_r2849 e
  ORDER BY
    CASE e.stake_for_founder WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    e.candor_score DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_feedback_list_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_feedback_list_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_adjustments_list_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_adjustments_list_r2849()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  adjustment_title text,
  commit_action text,
  commit_owner text,
  commit_due date,
  outcome_observed text,
  measurable_delta text,
  verdict text,
  difficulty int,
  reviewed_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.quarter_label, a.adjustment_title, a.commit_action, a.commit_owner,
         a.commit_due, a.outcome_observed, a.measurable_delta, a.verdict, a.difficulty, a.reviewed_at
  FROM founder_leadership_adjustments_r2849 a
  ORDER BY a.commit_due DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_adjustments_list_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_adjustments_list_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_theme_rollup_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_theme_rollup_r2849()
RETURNS TABLE (
  feedback_theme text,
  entry_count bigint,
  avg_candor numeric,
  max_recurrence int,
  critical_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.feedback_theme,
         COUNT(*)::bigint,
         ROUND(AVG(e.candor_score)::numeric, 2),
         MAX(e.pattern_recurrence),
         COUNT(*) FILTER (WHERE e.stake_for_founder = 'critical')::bigint
  FROM founder_leadership_feedback_entries_r2849 e
  GROUP BY e.feedback_theme
  ORDER BY COUNT(*) DESC, MAX(e.pattern_recurrence) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_theme_rollup_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_theme_rollup_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_verdict_rollup_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_verdict_rollup_r2849()
RETURNS TABLE (
  verdict text,
  count bigint,
  avg_difficulty numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.verdict, COUNT(*)::bigint, ROUND(AVG(a.difficulty)::numeric, 2)
  FROM founder_leadership_adjustments_r2849 a
  GROUP BY a.verdict
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_verdict_rollup_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_verdict_rollup_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_giver_rollup_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_giver_rollup_r2849()
RETURNS TABLE (
  giver_role text,
  entry_count bigint,
  avg_candor numeric,
  high_stake_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.giver_role,
         COUNT(*)::bigint,
         ROUND(AVG(e.candor_score)::numeric, 2),
         COUNT(*) FILTER (WHERE e.stake_for_founder IN ('high','critical'))::bigint
  FROM founder_leadership_feedback_entries_r2849 e
  GROUP BY e.giver_role
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_giver_rollup_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_giver_rollup_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_adoption_rate_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_adoption_rate_r2849()
RETURNS TABLE (
  quarter_label text,
  total_adjustments bigint,
  adopted_count bigint,
  partial_count bigint,
  rejected_count bigint,
  pending_count bigint,
  adoption_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.quarter_label,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.verdict = 'adopted')::bigint,
         COUNT(*) FILTER (WHERE a.verdict = 'partial')::bigint,
         COUNT(*) FILTER (WHERE a.verdict IN ('rejected','reverted'))::bigint,
         COUNT(*) FILTER (WHERE a.verdict IN ('pending','in_progress'))::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE a.verdict = 'adopted') / NULLIF(COUNT(*),0), 1)
  FROM founder_leadership_adjustments_r2849 a
  GROUP BY a.quarter_label
  ORDER BY a.quarter_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_adoption_rate_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_adoption_rate_r2849() TO authenticated;

DROP FUNCTION IF EXISTS founder_leadership_critical_open_r2849();
CREATE OR REPLACE FUNCTION founder_leadership_critical_open_r2849()
RETURNS TABLE (
  id uuid,
  feedback_giver text,
  feedback_theme text,
  raw_quote text,
  candor_score int,
  pattern_recurrence int,
  received_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.feedback_giver, e.feedback_theme, e.raw_quote, e.candor_score, e.pattern_recurrence, e.received_at
  FROM founder_leadership_feedback_entries_r2849 e
  WHERE e.stake_for_founder IN ('critical','high')
  ORDER BY e.pattern_recurrence DESC, e.candor_score DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_leadership_critical_open_r2849() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_leadership_critical_open_r2849() TO authenticated;

COMMIT;
