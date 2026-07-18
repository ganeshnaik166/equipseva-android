-- Round 3137 — Founder Quarterly Strategic Executive Coach + Peer-CEO Circle Feedback Tracker
-- Cadence x topic x commitments x NPS x peer feedback x blind spots x action closure

BEGIN;

CREATE TABLE IF NOT EXISTS founder_exec_coach_sessions_r3137 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  session_code text NOT NULL UNIQUE,
  session_date date NOT NULL,
  quarter_label text NOT NULL,
  coach_name text NOT NULL,
  coach_firm text NOT NULL,
  session_channel text NOT NULL CHECK (session_channel IN ('in_person_bengaluru','in_person_mumbai','zoom_video','phone_call','walking_session')),
  session_duration_minutes integer NOT NULL CHECK (session_duration_minutes BETWEEN 30 AND 240),
  primary_topic text NOT NULL CHECK (primary_topic IN ('scaling_founder_ceo','hiring_leadership_team','delegation_letting_go','board_management','fundraising_pitch_prep','cofounder_conflict','burnout_resilience','india_gtm_strategy','product_pmf_pivot','operations_at_scale','personal_finance_dilution','ipo_readiness_thinking')),
  founder_energy_score integer NOT NULL CHECK (founder_energy_score BETWEEN 1 AND 10),
  founder_stress_score integer NOT NULL CHECK (founder_stress_score BETWEEN 1 AND 10),
  key_insight text NOT NULL,
  commitment_count integer NOT NULL DEFAULT 0 CHECK (commitment_count BETWEEN 0 AND 10),
  commitments_closed integer NOT NULL DEFAULT 0 CHECK (commitments_closed BETWEEN 0 AND 10),
  session_nps integer NOT NULL CHECK (session_nps BETWEEN 0 AND 10),
  blind_spot_flagged text,
  next_session_date date,
  session_status text NOT NULL CHECK (session_status IN ('scheduled','completed','rescheduled','cancelled','no_show','commitments_open','commitments_closed')),
  session_fee_rupees integer NOT NULL CHECK (session_fee_rupees BETWEEN 0 AND 500000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_sessions_r3137_status ON founder_exec_coach_sessions_r3137(session_status, session_date DESC);
CREATE INDEX IF NOT EXISTS idx_coach_sessions_r3137_topic ON founder_exec_coach_sessions_r3137(primary_topic);

CREATE TABLE IF NOT EXISTS founder_peer_ceo_circle_feedback_r3137 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  session_ref uuid REFERENCES founder_exec_coach_sessions_r3137(id) ON DELETE SET NULL,
  feedback_code text NOT NULL UNIQUE,
  circle_name text NOT NULL CHECK (circle_name IN ('yc_india_founders_circle','nasscom_deeptech_ceo_group','iim_ahmedabad_saas_ceo','medtech_founders_bengaluru','iit_madras_alumni_ceo','tie_bangalore_charter','endeavor_india_high_impact')),
  peer_ceo_alias text NOT NULL,
  peer_ceo_stage text NOT NULL CHECK (peer_ceo_stage IN ('pre_seed','seed','series_a','series_b','series_c','pre_ipo')),
  feedback_date date NOT NULL,
  feedback_topic text NOT NULL CHECK (feedback_topic IN ('scaling_founder_ceo','hiring_leadership_team','delegation_letting_go','board_management','fundraising_pitch_prep','cofounder_conflict','burnout_resilience','india_gtm_strategy','product_pmf_pivot','operations_at_scale','personal_finance_dilution','ipo_readiness_thinking')),
  feedback_verdict text NOT NULL CHECK (feedback_verdict IN ('strong_agree','agree','neutral','disagree','strong_disagree','no_position')),
  candor_score integer NOT NULL CHECK (candor_score BETWEEN 1 AND 10),
  usefulness_score integer NOT NULL CHECK (usefulness_score BETWEEN 1 AND 10),
  blind_spot_called_out text,
  action_taken text NOT NULL CHECK (action_taken IN ('accepted_shipped','accepted_planned','partial_accept','rejected_with_reason','deferred_next_quarter','still_debating')),
  peer_would_recommend_ceo boolean NOT NULL DEFAULT false,
  peer_nps integer NOT NULL CHECK (peer_nps BETWEEN 0 AND 10),
  followup_needed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_peer_feedback_r3137_circle ON founder_peer_ceo_circle_feedback_r3137(circle_name, feedback_date DESC);
CREATE INDEX IF NOT EXISTS idx_peer_feedback_r3137_action ON founder_peer_ceo_circle_feedback_r3137(action_taken);

-- Seeds: coach sessions
INSERT INTO founder_exec_coach_sessions_r3137 (
  organization_id, session_code, session_date, quarter_label, coach_name, coach_firm, session_channel,
  session_duration_minutes, primary_topic, founder_energy_score, founder_stress_score, key_insight,
  commitment_count, commitments_closed, session_nps, blind_spot_flagged, next_session_date, session_status, session_fee_rupees
)
SELECT (SELECT id FROM organizations ORDER BY created_at LIMIT 1), q.code, q.dt::date, q.qtr, q.coach, q.firm, q.chan,
  q.dur, q.topic, q.energy, q.stress, q.insight, q.cc, q.cclosed, q.nps, q.blind, q.nextdt::date, q.status, q.fee
FROM (VALUES
  ('COACH-Q1-2026-01','2026-01-14','Q1_2026','Ravi Venkatesan','Global Founders Coaching','in_person_bengaluru',120,'scaling_founder_ceo',7,6,'Founder-CEO transition needs org design not more effort',3,3,9,'delegating engineer hiring to VP','2026-04-10','commitments_closed',150000),
  ('COACH-Q1-2026-02','2026-02-11','Q1_2026','Ravi Venkatesan','Global Founders Coaching','zoom_video',90,'hiring_leadership_team',6,7,'Hire VP Ops before Series A close or valuation drops',4,3,8,'no succession plan for CTO','2026-03-15','commitments_open',120000),
  ('COACH-Q1-2026-03','2026-03-18','Q1_2026','Sridhar Vembu Advisor Pool','Zoho Advisory','walking_session',75,'burnout_resilience',5,9,'Founder sleep deficit is killing product judgement',2,2,10,'no personal board of advisors','2026-04-22','commitments_closed',80000),
  ('COACH-Q2-2026-04','2026-04-22','Q2_2026','Manjula Rao','Endeavor India Coach','in_person_mumbai',105,'board_management',8,5,'Board deck needs Indian medtech benchmarks not SaaS',3,2,9,'over-preparing for board vs strategy','2026-05-20','commitments_open',180000),
  ('COACH-Q2-2026-05','2026-05-20','Q2_2026','Manjula Rao','Endeavor India Coach','zoom_video',60,'fundraising_pitch_prep',7,6,'Series A narrative missing hospital LTV proof',4,4,10,'founder telling not showing metrics','2026-06-18','commitments_closed',150000),
  ('COACH-Q2-2026-06','2026-06-18','Q2_2026','Manjula Rao','Endeavor India Coach','phone_call',45,'delegation_letting_go',7,7,'Weekly ops review should move from founder to COO',3,2,8,'founder still approving engineer payouts','2026-07-15','commitments_open',80000),
  ('COACH-Q3-2026-07','2026-07-15','Q3_2026','Kavitha Menon','MedTech Founders Coach','in_person_bengaluru',150,'india_gtm_strategy',8,4,'Tier-2 hospital chain sales cycle needs 3 field reps not founder',5,4,10,'founder still doing hospital demos','2026-08-12','commitments_closed',200000),
  ('COACH-Q3-2026-08','2026-08-12','Q3_2026','Kavitha Menon','MedTech Founders Coach','zoom_video',90,'operations_at_scale',7,6,'Ops SLA breach root cause is founder-in-the-loop not systems',3,3,9,'no ops runbook exists','2026-09-16','commitments_closed',150000),
  ('COACH-Q4-2026-09','2026-09-16','Q4_2026','Sridhar Vembu Advisor Pool','Zoho Advisory','walking_session',90,'personal_finance_dilution',6,8,'Founder equity dilution math not modelled past Series B',2,1,7,'no personal CA reviewing ESOP','2026-10-14','commitments_open',80000),
  ('COACH-Q4-2026-10','2026-10-14','Q4_2026','Ravi Venkatesan','Global Founders Coaching','in_person_bengaluru',135,'ipo_readiness_thinking',9,5,'IPO readiness thinking should start 24 months before not 12',4,3,10,'no CFO with listed-co experience','2026-11-11','commitments_closed',180000),
  ('COACH-Q4-2026-11','2026-11-11','Q4_2026','Kavitha Menon','MedTech Founders Coach','zoom_video',60,'product_pmf_pivot',8,4,'Multi-vertical PMF requires killing 2 verticals not doubling',3,3,10,'founder loves all verticals equally','2026-12-09','commitments_closed',120000),
  ('COACH-Q1-2027-12','2026-12-09','Q1_2027','Manjula Rao','Endeavor India Coach','in_person_mumbai',120,'cofounder_conflict',5,9,'Cofounder role reset needed before Series B pitch',4,2,8,'unspoken founder-cofounder role drift','2027-01-13','commitments_open',180000)
) AS q(code, dt, qtr, coach, firm, chan, dur, topic, energy, stress, insight, cc, cclosed, nps, blind, nextdt, status, fee);

-- Seeds: peer CEO circle feedback
INSERT INTO founder_peer_ceo_circle_feedback_r3137 (
  organization_id, session_ref, feedback_code, circle_name, peer_ceo_alias, peer_ceo_stage, feedback_date,
  feedback_topic, feedback_verdict, candor_score, usefulness_score, blind_spot_called_out, action_taken,
  peer_would_recommend_ceo, peer_nps, followup_needed
)
SELECT (SELECT id FROM organizations ORDER BY created_at LIMIT 1), NULL::uuid, q.code, q.circle, q.alias, q.stage, q.dt::date,
  q.topic, q.verdict, q.candor, q.useful, q.blind, q.action, q.rec, q.nps, q.follow
FROM (VALUES
  ('PEER-FB-2026-01','yc_india_founders_circle','Founder-A-YC22','series_a','2026-01-28','scaling_founder_ceo','strong_agree',9,9,'you are still the bottleneck on hiring','accepted_shipped',true,10,false),
  ('PEER-FB-2026-02','medtech_founders_bengaluru','Founder-M-Bengaluru','seed','2026-02-25','hiring_leadership_team','agree',8,8,'no VP Ops means Series A DD will flag it','accepted_planned',true,9,true),
  ('PEER-FB-2026-03','nasscom_deeptech_ceo_group','Founder-N-DeepTech','series_b','2026-03-25','burnout_resilience','strong_agree',10,10,'you look tired every dinner - fix it now','accepted_shipped',true,10,false),
  ('PEER-FB-2026-04','iim_ahmedabad_saas_ceo','Founder-I-IIM-A','series_a','2026-04-29','board_management','disagree',7,6,'over-indexing on board approval','partial_accept',true,7,true),
  ('PEER-FB-2026-05','endeavor_india_high_impact','Founder-E-EndeavorIN','series_b','2026-05-27','fundraising_pitch_prep','strong_agree',9,10,'your deck buries the hospital LTV in slide 18','accepted_shipped',true,10,false),
  ('PEER-FB-2026-06','yc_india_founders_circle','Founder-A-YC22','series_a','2026-06-24','delegation_letting_go','agree',8,7,'you review payouts every Friday - stop','accepted_planned',true,8,true),
  ('PEER-FB-2026-07','tie_bangalore_charter','Founder-T-TiEBLR','series_a','2026-07-22','india_gtm_strategy','strong_agree',9,9,'you are the sales team - hire reps yesterday','accepted_shipped',true,10,false),
  ('PEER-FB-2026-08','medtech_founders_bengaluru','Founder-M-Bengaluru','seed','2026-08-19','operations_at_scale','agree',8,8,'no ops runbook is a Series A red flag','accepted_shipped',true,9,false),
  ('PEER-FB-2026-09','iit_madras_alumni_ceo','Founder-M-IITM','pre_seed','2026-09-23','personal_finance_dilution','neutral',6,5,'you have not modelled your own dilution','deferred_next_quarter',false,6,true),
  ('PEER-FB-2026-10','endeavor_india_high_impact','Founder-E-EndeavorIN','series_b','2026-10-21','ipo_readiness_thinking','strong_agree',10,10,'no listed-co CFO = 2027 IPO is a fantasy','accepted_planned',true,10,true),
  ('PEER-FB-2026-11','iim_ahmedabad_saas_ceo','Founder-I-IIM-A','series_a','2026-11-18','product_pmf_pivot','strong_agree',9,10,'kill dental or kill imaging - pick one','accepted_shipped',true,10,false),
  ('PEER-FB-2026-12','nasscom_deeptech_ceo_group','Founder-N-DeepTech','series_b','2026-12-16','cofounder_conflict','agree',9,8,'your cofounder role drift is visible to everyone','partial_accept',true,8,true),
  ('PEER-FB-2027-13','yc_india_founders_circle','Founder-A-YC22','series_a','2027-01-06','scaling_founder_ceo','strong_agree',9,9,'stop taking every product call','accepted_planned',true,10,true),
  ('PEER-FB-2027-14','tie_bangalore_charter','Founder-T-TiEBLR','series_a','2027-01-20','delegation_letting_go','strong_disagree',8,4,'you rejected the COO shortlist - why','still_debating',false,5,true)
) AS q(code, circle, alias, stage, dt, topic, verdict, candor, useful, blind, action, rec, nps, follow);

-- Backfill session_ref where quarter matches
UPDATE founder_peer_ceo_circle_feedback_r3137 f
SET session_ref = s.id
FROM founder_exec_coach_sessions_r3137 s
WHERE f.feedback_topic = s.primary_topic
  AND date_trunc('quarter', f.feedback_date) = date_trunc('quarter', s.session_date)
  AND f.session_ref IS NULL;

-- RPC 1: quarterly session rollup
CREATE OR REPLACE FUNCTION founder_r3137_quarterly_session_rollup()
RETURNS TABLE (quarter_label text, session_count bigint, avg_energy numeric, avg_stress numeric, avg_nps numeric, total_fee_rupees bigint, closed_commitments bigint, total_commitments bigint, closure_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label, count(*)::bigint,
    round(avg(s.founder_energy_score)::numeric, 2),
    round(avg(s.founder_stress_score)::numeric, 2),
    round(avg(s.session_nps)::numeric, 2),
    sum(s.session_fee_rupees)::bigint,
    sum(s.commitments_closed)::bigint,
    sum(s.commitment_count)::bigint,
    round((sum(s.commitments_closed)::numeric * 100.0 / nullif(sum(s.commitment_count),0))::numeric, 2)
  FROM founder_exec_coach_sessions_r3137 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_quarterly_session_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_quarterly_session_rollup() TO authenticated;

-- RPC 2: topic mix
CREATE OR REPLACE FUNCTION founder_r3137_topic_mix()
RETURNS TABLE (primary_topic text, session_count bigint, avg_nps numeric, avg_energy numeric, avg_stress numeric, closure_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.primary_topic, count(*)::bigint,
    round(avg(s.session_nps)::numeric, 2),
    round(avg(s.founder_energy_score)::numeric, 2),
    round(avg(s.founder_stress_score)::numeric, 2),
    round((sum(s.commitments_closed)::numeric * 100.0 / nullif(sum(s.commitment_count),0))::numeric, 2)
  FROM founder_exec_coach_sessions_r3137 s
  GROUP BY s.primary_topic
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_topic_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_topic_mix() TO authenticated;

-- RPC 3: coach performance
CREATE OR REPLACE FUNCTION founder_r3137_coach_performance()
RETURNS TABLE (coach_name text, coach_firm text, sessions_held bigint, avg_nps numeric, total_fee_rupees bigint, avg_duration_minutes numeric, closure_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.coach_name, s.coach_firm, count(*)::bigint,
    round(avg(s.session_nps)::numeric, 2),
    sum(s.session_fee_rupees)::bigint,
    round(avg(s.session_duration_minutes)::numeric, 2),
    round((sum(s.commitments_closed)::numeric * 100.0 / nullif(sum(s.commitment_count),0))::numeric, 2)
  FROM founder_exec_coach_sessions_r3137 s
  GROUP BY s.coach_name, s.coach_firm
  ORDER BY avg(s.session_nps) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_coach_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_coach_performance() TO authenticated;

-- RPC 4: peer circle mix
CREATE OR REPLACE FUNCTION founder_r3137_peer_circle_mix()
RETURNS TABLE (circle_name text, feedback_count bigint, avg_candor numeric, avg_usefulness numeric, avg_peer_nps numeric, recommend_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.circle_name, count(*)::bigint,
    round(avg(f.candor_score)::numeric, 2),
    round(avg(f.usefulness_score)::numeric, 2),
    round(avg(f.peer_nps)::numeric, 2),
    round((sum(CASE WHEN f.peer_would_recommend_ceo THEN 1 ELSE 0 END)::numeric * 100.0 / count(*))::numeric, 2)
  FROM founder_peer_ceo_circle_feedback_r3137 f
  GROUP BY f.circle_name
  ORDER BY avg(f.usefulness_score) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_peer_circle_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_peer_circle_mix() TO authenticated;

-- RPC 5: action closure by verdict
CREATE OR REPLACE FUNCTION founder_r3137_action_closure_rollup()
RETURNS TABLE (action_taken text, count bigint, avg_candor numeric, avg_usefulness numeric, followup_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.action_taken, count(*)::bigint,
    round(avg(f.candor_score)::numeric, 2),
    round(avg(f.usefulness_score)::numeric, 2),
    round((sum(CASE WHEN f.followup_needed THEN 1 ELSE 0 END)::numeric * 100.0 / count(*))::numeric, 2)
  FROM founder_peer_ceo_circle_feedback_r3137 f
  GROUP BY f.action_taken
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_action_closure_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_action_closure_rollup() TO authenticated;

-- RPC 6: blind spots surfaced
CREATE OR REPLACE FUNCTION founder_r3137_blind_spots_open()
RETURNS TABLE (source text, session_or_feedback_code text, topic text, blind_spot text, action_taken_or_status text, dt date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'coach_session'::text, s.session_code, s.primary_topic, s.blind_spot_flagged, s.session_status, s.session_date
  FROM founder_exec_coach_sessions_r3137 s
  WHERE s.blind_spot_flagged IS NOT NULL
  UNION ALL
  SELECT 'peer_feedback'::text, f.feedback_code, f.feedback_topic, f.blind_spot_called_out, f.action_taken, f.feedback_date
  FROM founder_peer_ceo_circle_feedback_r3137 f
  WHERE f.blind_spot_called_out IS NOT NULL
  ORDER BY dt DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_blind_spots_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_blind_spots_open() TO authenticated;

-- RPC 7: peer stage impact
CREATE OR REPLACE FUNCTION founder_r3137_peer_stage_impact()
RETURNS TABLE (peer_ceo_stage text, feedback_count bigint, avg_usefulness numeric, accepted_shipped_count bigint, rejected_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.peer_ceo_stage, count(*)::bigint,
    round(avg(f.usefulness_score)::numeric, 2),
    sum(CASE WHEN f.action_taken = 'accepted_shipped' THEN 1 ELSE 0 END)::bigint,
    sum(CASE WHEN f.action_taken = 'rejected_with_reason' THEN 1 ELSE 0 END)::bigint
  FROM founder_peer_ceo_circle_feedback_r3137 f
  GROUP BY f.peer_ceo_stage
  ORDER BY avg(f.usefulness_score) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_peer_stage_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_peer_stage_impact() TO authenticated;

-- RPC 8: open commitments follow-up list
CREATE OR REPLACE FUNCTION founder_r3137_open_commitments_list()
RETURNS TABLE (session_code text, session_date date, coach_name text, primary_topic text, commitment_count integer, commitments_closed integer, open_commitments integer, next_session_date date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.session_code, s.session_date, s.coach_name, s.primary_topic,
    s.commitment_count, s.commitments_closed,
    (s.commitment_count - s.commitments_closed)::integer AS open_commitments,
    s.next_session_date
  FROM founder_exec_coach_sessions_r3137 s
  WHERE s.session_status IN ('commitments_open','scheduled','rescheduled')
     OR s.commitments_closed < s.commitment_count
  ORDER BY s.session_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3137_open_commitments_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3137_open_commitments_list() TO authenticated;

COMMIT;
