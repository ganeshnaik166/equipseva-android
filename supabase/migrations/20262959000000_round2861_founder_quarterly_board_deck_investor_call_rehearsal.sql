BEGIN;

-- =====================================================================
-- Round 2861 — Founder Quarterly Board Deck × Investor Call Rehearsal
-- rehearsal x audience x topic x score x refine x confidence x send
-- =====================================================================

-- ---------- Table 1: rehearsal sessions ----------
CREATE TABLE IF NOT EXISTS board_deck_rehearsal_sessions_r2861 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  audience_kind text NOT NULL CHECK (audience_kind IN ('board','seed_investors','growth_investors','strategic_lp','press_dry_run','internal_exec')),
  topic_slug text NOT NULL,
  topic_title text NOT NULL,
  rehearsal_round int NOT NULL DEFAULT 1,
  scheduled_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 45,
  delivery_score numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (delivery_score BETWEEN 0 AND 10),
  clarity_score numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (clarity_score BETWEEN 0 AND 10),
  numbers_recall_score numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (numbers_recall_score BETWEEN 0 AND 10),
  hard_question_score numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (hard_question_score BETWEEN 0 AND 10),
  founder_confidence numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (founder_confidence BETWEEN 0 AND 10),
  refine_notes text,
  refine_count int NOT NULL DEFAULT 0,
  send_decision text NOT NULL DEFAULT 'pending' CHECK (send_decision IN ('pending','hold','send_with_caveats','send','abort')),
  send_decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE board_deck_rehearsal_sessions_r2861 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON board_deck_rehearsal_sessions_r2861;
CREATE POLICY founder_all ON board_deck_rehearsal_sessions_r2861
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Table 2: rehearsal hard-question drills ----------
CREATE TABLE IF NOT EXISTS board_deck_hard_question_drills_r2861 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES board_deck_rehearsal_sessions_r2861(id) ON DELETE CASCADE,
  question_text text NOT NULL,
  question_category text NOT NULL CHECK (question_category IN ('burn','unit_economics','competition','moat','team','risk','exit','metrics_drilldown')),
  asked_by_persona text NOT NULL,
  answer_clarity numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (answer_clarity BETWEEN 0 AND 10),
  answer_confidence numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (answer_confidence BETWEEN 0 AND 10),
  needed_refine boolean NOT NULL DEFAULT false,
  refine_action text,
  resolved boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE board_deck_hard_question_drills_r2861 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON board_deck_hard_question_drills_r2861;
CREATE POLICY founder_all ON board_deck_hard_question_drills_r2861
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Seeds: sessions ----------
INSERT INTO board_deck_rehearsal_sessions_r2861
  (quarter_label, audience_kind, topic_slug, topic_title, rehearsal_round, scheduled_at, duration_minutes,
   delivery_score, clarity_score, numbers_recall_score, hard_question_score, founder_confidence,
   refine_notes, refine_count, send_decision, send_decided_at)
VALUES
  ('Q2-FY27','board','arr-bridge','ARR bridge and net retention',1,'2026-06-22 09:00:00+05:30'::timestamptz,45,
   7.4, 8.1, 6.2, 6.8, 7.0,'Tighten ARR walk — drop quarter-on-quarter table for waterfall chart',1,'send_with_caveats','2026-06-22 11:00:00+05:30'::timestamptz),
  ('Q2-FY27','growth_investors','unit-econ-deepdive','Per-engineer contribution margin',2,'2026-06-23 14:00:00+05:30'::timestamptz,60,
   8.2, 8.6, 8.0, 7.4, 8.1,'Pre-empt CAC payback question with cohort overlay',2,'send','2026-06-23 16:30:00+05:30'::timestamptz),
  ('Q2-FY27','seed_investors','amc-churn','AMC churn vs new chain wins',1,'2026-06-24 10:30:00+05:30'::timestamptz,30,
   6.1, 6.5, 5.8, 5.4, 5.9,'Founder kept defending churn instead of reframing — refine narrative',3,'hold',NULL),
  ('Q2-FY27','strategic_lp','market-expansion','Tier-1 to Tier-2 expansion math',1,'2026-06-25 11:00:00+05:30'::timestamptz,50,
   7.8, 7.6, 7.2, 7.0, 7.5,'Add bottoms-up TAM with hospital count by city',1,'send_with_caveats','2026-06-25 13:00:00+05:30'::timestamptz),
  ('Q2-FY27','press_dry_run','founder-story','Founder narrative and origin',1,'2026-06-26 16:00:00+05:30'::timestamptz,25,
   9.0, 8.8, 8.5, 8.2, 9.1,'Press dry-run polished — green to send',0,'send','2026-06-26 17:00:00+05:30'::timestamptz),
  ('Q2-FY27','internal_exec','rev-rec-policy','Revenue recognition policy walkthrough',2,'2026-06-27 09:30:00+05:30'::timestamptz,40,
   8.0, 7.9, 9.0, 8.4, 8.3,'CFO satisfied — clean for board',1,'send','2026-06-27 11:00:00+05:30'::timestamptz),
  ('Q2-FY27','board','cash-runway','Cash runway and burn glidepath',1,'2026-06-28 09:00:00+05:30'::timestamptz,45,
   5.2, 5.6, 6.0, 4.8, 5.0,'Numbers slipped twice — REHEARSE AGAIN before send',4,'abort',NULL),
  ('Q2-FY27','growth_investors','competitive-moat','Moat vs new entrants',1,'2026-06-29 15:00:00+05:30'::timestamptz,35,
   7.0, 7.3, 6.8, 6.5, 7.1,'Need crisper 30-second moat statement',2,'pending',NULL);

-- ---------- Seeds: drills ----------
INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'What is the QoQ ARR walk if we exclude the top-3 chain wins?','metrics_drilldown'::text,'board_chair',6.5,6.0,true,'Build slide showing organic ARR ex-top-3',false
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='arr-bridge' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'CAC payback months when you blend Tier-1 and Tier-2?','unit_economics','growth_partner',8.1,8.4,false,NULL,true
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='unit-econ-deepdive' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'Why is AMC gross churn 4 percent if the product is sticky?','metrics_drilldown','seed_lead',5.2,5.0,true,'Reframe as net retention not gross churn',false
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='amc-churn' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'How many hospitals per Tier-2 city and what penetration in 24 months?','metrics_drilldown','strategic_partner',7.4,7.2,true,'Insert hospital-count table by city tier',true
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='market-expansion' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'Why now? Why you?','team','tier1_journalist',9.0,9.2,false,NULL,true
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='founder-story' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'What is the exact runway at current burn and at 0.8x burn?','burn','board_chair',4.5,4.2,true,'Practice runway numbers cold every morning',false
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='cash-runway' LIMIT 1;

INSERT INTO board_deck_hard_question_drills_r2861
  (session_id, question_text, question_category, asked_by_persona, answer_clarity, answer_confidence, needed_refine, refine_action, resolved)
SELECT id,'How do you stop a well-funded entrant from copying you in 6 months?','moat','growth_partner',6.8,6.5,true,'30-sec moat statement: density + data + dispatch',false
  FROM board_deck_rehearsal_sessions_r2861 WHERE topic_slug='competitive-moat' LIMIT 1;

-- ---------- RPCs ----------

DROP FUNCTION IF EXISTS rpc_r2861_kpis();
CREATE OR REPLACE FUNCTION rpc_r2861_kpis()
RETURNS TABLE(
  total_sessions int,
  sessions_send int,
  sessions_hold int,
  sessions_abort int,
  avg_confidence numeric,
  avg_delivery numeric,
  total_drills int,
  drills_refine int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM board_deck_rehearsal_sessions_r2861),
    (SELECT count(*)::int FROM board_deck_rehearsal_sessions_r2861 WHERE send_decision IN ('send','send_with_caveats')),
    (SELECT count(*)::int FROM board_deck_rehearsal_sessions_r2861 WHERE send_decision='hold'),
    (SELECT count(*)::int FROM board_deck_rehearsal_sessions_r2861 WHERE send_decision='abort'),
    (SELECT round(avg(founder_confidence)::numeric, 2) FROM board_deck_rehearsal_sessions_r2861),
    (SELECT round(avg(delivery_score)::numeric, 2) FROM board_deck_rehearsal_sessions_r2861),
    (SELECT count(*)::int FROM board_deck_hard_question_drills_r2861),
    (SELECT count(*)::int FROM board_deck_hard_question_drills_r2861 WHERE needed_refine AND NOT resolved);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_kpis() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_sessions();
CREATE OR REPLACE FUNCTION rpc_r2861_sessions()
RETURNS TABLE(
  id uuid,
  quarter_label text,
  audience_kind text,
  topic_title text,
  rehearsal_round int,
  scheduled_at timestamptz,
  founder_confidence numeric,
  delivery_score numeric,
  send_decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.audience_kind, s.topic_title, s.rehearsal_round,
         s.scheduled_at, s.founder_confidence, s.delivery_score, s.send_decision
  FROM board_deck_rehearsal_sessions_r2861 s
  ORDER BY s.scheduled_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_sessions() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_drills();
CREATE OR REPLACE FUNCTION rpc_r2861_drills()
RETURNS TABLE(
  id uuid,
  topic_title text,
  question_text text,
  question_category text,
  asked_by_persona text,
  answer_clarity numeric,
  answer_confidence numeric,
  needed_refine boolean,
  resolved boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, s.topic_title, d.question_text, d.question_category, d.asked_by_persona,
         d.answer_clarity, d.answer_confidence, d.needed_refine, d.resolved
  FROM board_deck_hard_question_drills_r2861 d
  JOIN board_deck_rehearsal_sessions_r2861 s ON s.id = d.session_id
  ORDER BY d.needed_refine DESC, d.answer_confidence ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_drills() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_drills() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_audience_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2861_audience_breakdown()
RETURNS TABLE(
  audience_kind text,
  sessions int,
  avg_confidence numeric,
  send_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.audience_kind,
         count(*)::int,
         round(avg(s.founder_confidence)::numeric, 2),
         round(100.0 * sum(CASE WHEN s.send_decision IN ('send','send_with_caveats') THEN 1 ELSE 0 END) / NULLIF(count(*),0), 1)
  FROM board_deck_rehearsal_sessions_r2861 s
  GROUP BY s.audience_kind
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_audience_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_audience_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_refine_queue();
CREATE OR REPLACE FUNCTION rpc_r2861_refine_queue()
RETURNS TABLE(
  topic_title text,
  refine_count int,
  refine_notes text,
  founder_confidence numeric,
  send_decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.topic_title, s.refine_count, s.refine_notes, s.founder_confidence, s.send_decision
  FROM board_deck_rehearsal_sessions_r2861 s
  WHERE s.refine_count > 0
  ORDER BY s.refine_count DESC, s.founder_confidence ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_refine_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_refine_queue() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_low_confidence();
CREATE OR REPLACE FUNCTION rpc_r2861_low_confidence()
RETURNS TABLE(
  topic_title text,
  audience_kind text,
  founder_confidence numeric,
  hard_question_score numeric,
  send_decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.topic_title, s.audience_kind, s.founder_confidence, s.hard_question_score, s.send_decision
  FROM board_deck_rehearsal_sessions_r2861 s
  WHERE s.founder_confidence < 7.0
  ORDER BY s.founder_confidence ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_low_confidence() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_low_confidence() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_send_ready();
CREATE OR REPLACE FUNCTION rpc_r2861_send_ready()
RETURNS TABLE(
  topic_title text,
  audience_kind text,
  founder_confidence numeric,
  send_decision text,
  send_decided_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.topic_title, s.audience_kind, s.founder_confidence, s.send_decision, s.send_decided_at
  FROM board_deck_rehearsal_sessions_r2861 s
  WHERE s.send_decision IN ('send','send_with_caveats')
  ORDER BY s.send_decided_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_send_ready() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_send_ready() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2861_drill_categories();
CREATE OR REPLACE FUNCTION rpc_r2861_drill_categories()
RETURNS TABLE(
  question_category text,
  drills int,
  avg_clarity numeric,
  unresolved int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.question_category,
         count(*)::int,
         round(avg(d.answer_clarity)::numeric, 2),
         sum(CASE WHEN NOT d.resolved THEN 1 ELSE 0 END)::int
  FROM board_deck_hard_question_drills_r2861 d
  GROUP BY d.question_category
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2861_drill_categories() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2861_drill_categories() TO authenticated;

COMMIT;
