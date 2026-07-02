BEGIN;

-- ============================================================================
-- Round 2677 — Founder Monthly Customer Discovery Call Log
-- call x persona x pain x ask x insight x follow-up action
-- ============================================================================

DROP TABLE IF EXISTS discovery_call_followups_r2677 CASCADE;
DROP TABLE IF EXISTS discovery_calls_r2677 CASCADE;

CREATE TABLE discovery_calls_r2677 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_month text NOT NULL,
  call_date date NOT NULL,
  customer_name text NOT NULL,
  customer_org text NOT NULL,
  persona text NOT NULL,
  pain_point text NOT NULL,
  customer_ask text NOT NULL,
  insight text NOT NULL,
  insight_score int NOT NULL DEFAULT 3,
  duration_minutes int NOT NULL DEFAULT 30,
  recording_url text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE discovery_call_followups_r2677 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id uuid NOT NULL REFERENCES discovery_calls_r2677(id) ON DELETE CASCADE,
  action_title text NOT NULL,
  owner text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'p2',
  outcome_note text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE discovery_calls_r2677 ENABLE ROW LEVEL SECURITY;
ALTER TABLE discovery_call_followups_r2677 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON discovery_calls_r2677;
CREATE POLICY founder_all ON discovery_calls_r2677 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON discovery_call_followups_r2677;
CREATE POLICY founder_all ON discovery_call_followups_r2677 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed discovery calls
INSERT INTO discovery_calls_r2677 (call_month, call_date, customer_name, customer_org, persona, pain_point, customer_ask, insight, insight_score, duration_minutes, status) VALUES
('2026-06','2026-06-03','Dr Anita Rao','Sunrise Multi-Speciality Hospital','Biomed Head','OT ventilator downtime kills 2 surgeries per week','Need 4-hr SLA with loaner unit','Loaner pool is the deciding feature, not price',5,42,'completed'),
('2026-06','2026-06-07','Suresh Iyer','MediCare Diagnostics Chain','Procurement Director','12 invoice mismatches per month between AMC and actual repairs','Single PDF with line-item reconciliation','Reconciliation pain > AMC price; ready to pay 18% premium',5,38,'completed'),
('2026-06','2026-06-10','Dr Farah Khan','Apollo Spec Hyd','Chief of Cardiology','Cath-lab calibration drift undetected for 11 days','Auto-alerts via WhatsApp to her phone directly','Clinicians want direct alerts, not biomed-routed alerts',4,28,'completed'),
('2026-06','2026-06-14','Ramesh Patil','Pune Govt Medical College','Stores Officer','GeM tender requires OEM-authorized service letter','OEM letter bundle + Udyam cert + GST','Govt buyers value documentation bundle over discount',4,35,'completed'),
('2026-06','2026-06-18','Nisha Menon','Kerala Dental Group (14 clinics)','Operations Manager','Chair-side compressor failures cascade — 1 dead = 3 chairs idle','Predictive replacement schedule by usage hours','Multi-clinic groups need rollup dashboard not per-site view',5,45,'completed'),
('2026-06','2026-06-21','Dr Vikram Singh','Fortis Bangalore','Anaesthesia HOD','Anaesthesia workstation re-cal logs missing for NABH audit','Digital logbook with auto-sign by engineer','NABH-compliance feature unlocks anaesthesia HOD as champion',5,32,'completed');

-- Seed follow-ups
INSERT INTO discovery_call_followups_r2677 (call_id, action_title, owner, due_date, status, priority, outcome_note) VALUES
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Dr Anita Rao'),'Ship loaner pool MVP with 3 ventilators','Founder','2026-07-15','in_progress','p0','3 loaners sourced; SOP draft v2'),
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Suresh Iyer'),'Build single-page AMC reconciliation PDF','Eng','2026-07-05','open','p0',NULL),
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Dr Farah Khan'),'WhatsApp clinician-direct alert channel','Eng','2026-07-12','open','p1',NULL),
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Ramesh Patil'),'Generate OEM auth letter bundle template','Founder','2026-07-08','done','p1','Bundle delivered; tender won 2026-06-20'),
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Nisha Menon'),'Roll out usage-hour predictive schedule for dental','Eng','2026-07-25','open','p1',NULL),
((SELECT id FROM discovery_calls_r2677 WHERE customer_name='Dr Vikram Singh'),'Digital re-cal logbook with engineer e-sign','Eng','2026-07-20','in_progress','p0','UI wireframe ready');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS r2677_kpi_summary();
CREATE OR REPLACE FUNCTION r2677_kpi_summary()
RETURNS TABLE(total_calls int, total_followups int, open_followups int, p0_open int, avg_insight numeric, avg_duration numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM discovery_calls_r2677),
    (SELECT count(*)::int FROM discovery_call_followups_r2677),
    (SELECT count(*)::int FROM discovery_call_followups_r2677 WHERE status IN ('open','in_progress')),
    (SELECT count(*)::int FROM discovery_call_followups_r2677 WHERE priority='p0' AND status IN ('open','in_progress')),
    (SELECT round(avg(insight_score)::numeric,2) FROM discovery_calls_r2677),
    (SELECT round(avg(duration_minutes)::numeric,1) FROM discovery_calls_r2677);
END $$;
REVOKE EXECUTE ON FUNCTION r2677_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2677_list_calls();
CREATE OR REPLACE FUNCTION r2677_list_calls()
RETURNS TABLE(id uuid, call_date date, customer_name text, customer_org text, persona text, pain_point text, customer_ask text, insight text, insight_score int, duration_minutes int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.call_date, c.customer_name, c.customer_org, c.persona, c.pain_point, c.customer_ask, c.insight, c.insight_score, c.duration_minutes, c.status
  FROM discovery_calls_r2677 c
  ORDER BY c.call_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_list_calls() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_list_calls() TO authenticated;

DROP FUNCTION IF EXISTS r2677_list_followups();
CREATE OR REPLACE FUNCTION r2677_list_followups()
RETURNS TABLE(id uuid, customer_name text, action_title text, owner text, due_date date, status text, priority text, outcome_note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, c.customer_name, f.action_title, f.owner, f.due_date, f.status, f.priority, f.outcome_note
  FROM discovery_call_followups_r2677 f
  JOIN discovery_calls_r2677 c ON c.id = f.call_id
  ORDER BY f.due_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_list_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_list_followups() TO authenticated;

DROP FUNCTION IF EXISTS r2677_persona_breakdown();
CREATE OR REPLACE FUNCTION r2677_persona_breakdown()
RETURNS TABLE(persona text, calls int, avg_insight numeric, open_actions int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.persona,
         count(*)::int AS calls,
         round(avg(c.insight_score)::numeric,2) AS avg_insight,
         (SELECT count(*)::int FROM discovery_call_followups_r2677 f
            JOIN discovery_calls_r2677 c2 ON c2.id=f.call_id
           WHERE c2.persona=c.persona AND f.status IN ('open','in_progress')) AS open_actions
  FROM discovery_calls_r2677 c
  GROUP BY c.persona
  ORDER BY calls DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_persona_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_persona_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2677_top_insights();
CREATE OR REPLACE FUNCTION r2677_top_insights()
RETURNS TABLE(customer_name text, persona text, insight text, insight_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.customer_name, c.persona, c.insight, c.insight_score
  FROM discovery_calls_r2677 c
  WHERE c.insight_score >= 4
  ORDER BY c.insight_score DESC, c.call_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_top_insights() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_top_insights() TO authenticated;

DROP FUNCTION IF EXISTS r2677_pain_themes();
CREATE OR REPLACE FUNCTION r2677_pain_themes()
RETURNS TABLE(pain_point text, mentions int, p0_actions int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.pain_point,
         count(*)::int AS mentions,
         (SELECT count(*)::int FROM discovery_call_followups_r2677 f
            JOIN discovery_calls_r2677 c2 ON c2.id=f.call_id
           WHERE c2.pain_point=c.pain_point AND f.priority='p0') AS p0_actions
  FROM discovery_calls_r2677 c
  GROUP BY c.pain_point
  ORDER BY mentions DESC, p0_actions DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_pain_themes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_pain_themes() TO authenticated;

DROP FUNCTION IF EXISTS r2677_followup_health();
CREATE OR REPLACE FUNCTION r2677_followup_health()
RETURNS TABLE(status text, priority text, count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.status, f.priority, count(*)::int
  FROM discovery_call_followups_r2677 f
  GROUP BY f.status, f.priority
  ORDER BY f.priority ASC, f.status ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_followup_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_followup_health() TO authenticated;

DROP FUNCTION IF EXISTS r2677_close_followup(uuid, text);
CREATE OR REPLACE FUNCTION r2677_close_followup(p_id uuid, p_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE discovery_call_followups_r2677
     SET status='done', outcome_note=p_outcome, closed_at=now()
   WHERE id=p_id;
END $$;
REVOKE EXECUTE ON FUNCTION r2677_close_followup(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2677_close_followup(uuid, text) TO authenticated;

COMMIT;
