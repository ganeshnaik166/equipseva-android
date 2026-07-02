BEGIN;

CREATE TABLE IF NOT EXISTS engineer_monthly_customer_handover_final_mile_checklist_r2834 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  customer_org text NOT NULL,
  handover_month date NOT NULL,
  handover_step text NOT NULL CHECK (handover_step IN ('arrival_briefing','equipment_walkthrough','spares_inventory','manual_handover','training_session','warranty_explainer','signoff_capture')),
  final_mile_action text NOT NULL CHECK (final_mile_action IN ('photo_evidence','customer_sign','manager_call','followup_scheduled','digital_invoice','feedback_collected','none')),
  signoff_state text NOT NULL CHECK (signoff_state IN ('pending','partial','signed','rejected','expired')),
  customer_thanked boolean NOT NULL DEFAULT false,
  verdict text NOT NULL CHECK (verdict IN ('green','amber','red','blocker')),
  duration_minutes integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_customer_handover_final_mile_checklist_r2834 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_customer_handover_final_mile_checklist_r2834;
CREATE POLICY founder_all ON engineer_monthly_customer_handover_final_mile_checklist_r2834 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_handover_verdict_rollup_r2834 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  rollup_month date NOT NULL,
  total_handovers integer NOT NULL DEFAULT 0,
  signed_count integer NOT NULL DEFAULT 0,
  thanked_count integer NOT NULL DEFAULT 0,
  green_count integer NOT NULL DEFAULT 0,
  amber_count integer NOT NULL DEFAULT 0,
  red_count integer NOT NULL DEFAULT 0,
  blocker_count integer NOT NULL DEFAULT 0,
  avg_duration_minutes numeric(8,2) NOT NULL DEFAULT 0,
  coach_bucket text NOT NULL CHECK (coach_bucket IN ('star','keep','watch','escalate','off_grid')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_verdict_rollup_r2834 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_verdict_rollup_r2834;
CREATE POLICY founder_all ON engineer_handover_verdict_rollup_r2834 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_customer_handover_final_mile_checklist_r2834 (engineer_code, engineer_name, customer_org, handover_month, handover_step, final_mile_action, signoff_state, customer_thanked, verdict, duration_minutes, notes) VALUES
  ('ENG-HYD-014','Ravi Kumar','Apollo Jubilee Hills','2026-06-01'::date,'arrival_briefing','photo_evidence','signed',true,'green',22,'Briefing in OPD waiting bay clean.'),
  ('ENG-BLR-027','Sneha Iyer','Manipal Whitefield','2026-06-01'::date,'equipment_walkthrough','customer_sign','signed',true,'green',35,'Biomed team walked through ventilator stack.'),
  ('ENG-MUM-008','Arjun Mehta','Lilavati ICU-3','2026-06-01'::date,'spares_inventory','followup_scheduled','partial',false,'amber',18,'2 spares missing — followup booked.'),
  ('ENG-DEL-019','Priya Nair','Max Saket NABH','2026-06-01'::date,'manual_handover','digital_invoice','signed',true,'green',12,'Manuals dropped to biomed shared drive.'),
  ('ENG-CHE-031','Sundar Raj','Apollo Greams Road','2026-06-01'::date,'training_session','feedback_collected','rejected',false,'red',55,'Nurse training rejected — repeat next visit.'),
  ('ENG-KOL-045','Devika Sen','AMRI Salt Lake','2026-06-01'::date,'warranty_explainer','manager_call','signed',true,'green',20,'Warranty card explained to admin.'),
  ('ENG-PNQ-052','Kunal Patil','Ruby Hall Clinic','2026-06-01'::date,'signoff_capture','none','expired',false,'blocker',8,'Signoff window expired — escalate.');

INSERT INTO engineer_handover_verdict_rollup_r2834 (engineer_code, rollup_month, total_handovers, signed_count, thanked_count, green_count, amber_count, red_count, blocker_count, avg_duration_minutes, coach_bucket) VALUES
  ('ENG-HYD-014','2026-06-01'::date,18,16,15,14,3,1,0,21.5,'star'),
  ('ENG-BLR-027','2026-06-01'::date,22,20,19,18,3,1,0,27.8,'star'),
  ('ENG-MUM-008','2026-06-01'::date,14,9,7,6,5,2,1,19.2,'watch'),
  ('ENG-DEL-019','2026-06-01'::date,20,18,17,16,3,1,0,15.4,'keep'),
  ('ENG-CHE-031','2026-06-01'::date,11,5,4,3,3,4,1,42.1,'escalate'),
  ('ENG-KOL-045','2026-06-01'::date,16,14,13,12,3,1,0,22.7,'keep'),
  ('ENG-PNQ-052','2026-06-01'::date,9,3,2,2,2,3,2,11.5,'off_grid');

DROP FUNCTION IF EXISTS founder_r2834_overview();
CREATE OR REPLACE FUNCTION founder_r2834_overview()
RETURNS TABLE (label text, value text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'Total handovers'::text, COUNT(*)::text FROM engineer_monthly_customer_handover_final_mile_checklist_r2834
    UNION ALL SELECT 'Signed handovers', COUNT(*)::text FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 WHERE signoff_state = 'signed'
    UNION ALL SELECT 'Customers thanked', COUNT(*)::text FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 WHERE customer_thanked = true
    UNION ALL SELECT 'Blocker verdicts', COUNT(*)::text FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 WHERE verdict = 'blocker'
    UNION ALL SELECT 'Avg duration mins', COALESCE(ROUND(AVG(duration_minutes)::numeric, 1)::text, '0') FROM engineer_monthly_customer_handover_final_mile_checklist_r2834;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_by_step();
CREATE OR REPLACE FUNCTION founder_r2834_by_step()
RETURNS TABLE (handover_step text, total bigint, signed_count bigint, blocker_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.handover_step, COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE c.signoff_state = 'signed')::bigint,
           COUNT(*) FILTER (WHERE c.verdict = 'blocker')::bigint
    FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 c
    GROUP BY c.handover_step
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_by_step() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_by_step() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_by_final_mile();
CREATE OR REPLACE FUNCTION founder_r2834_by_final_mile()
RETURNS TABLE (final_mile_action text, total bigint, thanked bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.final_mile_action, COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE c.customer_thanked = true)::bigint
    FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 c
    GROUP BY c.final_mile_action
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_by_final_mile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_by_final_mile() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_by_signoff();
CREATE OR REPLACE FUNCTION founder_r2834_by_signoff()
RETURNS TABLE (signoff_state text, total bigint, green_count bigint, red_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.signoff_state, COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE c.verdict = 'green')::bigint,
           COUNT(*) FILTER (WHERE c.verdict = 'red')::bigint
    FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 c
    GROUP BY c.signoff_state
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_by_signoff() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_by_signoff() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_recent_checklist();
CREATE OR REPLACE FUNCTION founder_r2834_recent_checklist()
RETURNS TABLE (engineer_code text, engineer_name text, customer_org text, handover_step text, signoff_state text, verdict text, customer_thanked boolean, duration_minutes integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.engineer_code, c.engineer_name, c.customer_org, c.handover_step, c.signoff_state, c.verdict, c.customer_thanked, c.duration_minutes
    FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 c
    ORDER BY c.created_at DESC
    LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_recent_checklist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_recent_checklist() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2834_engineer_rollup()
RETURNS TABLE (engineer_code text, total_handovers integer, signed_count integer, thanked_count integer, blocker_count integer, coach_bucket text, avg_duration_minutes numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.engineer_code, r.total_handovers, r.signed_count, r.thanked_count, r.blocker_count, r.coach_bucket, r.avg_duration_minutes
    FROM engineer_handover_verdict_rollup_r2834 r
    ORDER BY r.total_handovers DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_engineer_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_coach_buckets();
CREATE OR REPLACE FUNCTION founder_r2834_coach_buckets()
RETURNS TABLE (coach_bucket text, engineers bigint, total_signed bigint, total_blocker bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.coach_bucket, COUNT(*)::bigint, SUM(r.signed_count)::bigint, SUM(r.blocker_count)::bigint
    FROM engineer_handover_verdict_rollup_r2834 r
    GROUP BY r.coach_bucket
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_coach_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_coach_buckets() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2834_blocker_alerts();
CREATE OR REPLACE FUNCTION founder_r2834_blocker_alerts()
RETURNS TABLE (engineer_code text, engineer_name text, customer_org text, handover_step text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.engineer_code, c.engineer_name, c.customer_org, c.handover_step, c.notes
    FROM engineer_monthly_customer_handover_final_mile_checklist_r2834 c
    WHERE c.verdict IN ('red','blocker')
    ORDER BY c.created_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2834_blocker_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2834_blocker_alerts() TO authenticated;

COMMIT;