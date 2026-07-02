BEGIN;

-- ============================================================================
-- Round 2776 — Customer Monthly Engineer Handoff & Customer Presence
-- Tracks job-level engineer handoffs with customer presence verification,
-- handoff completeness scoring, signoff capture, and follow-up scheduling.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: handoff events per repair job
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_handoff_events_r2776 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL,
  engineer_name text NOT NULL,
  customer_name text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  handoff_month date NOT NULL,
  handoff_at timestamptz NOT NULL DEFAULT now(),
  customer_present boolean NOT NULL DEFAULT false,
  presence_mode text NOT NULL CHECK (presence_mode IN ('in_person','video_call','phone_only','absent')),
  checklist_total int NOT NULL CHECK (checklist_total > 0),
  checklist_passed int NOT NULL CHECK (checklist_passed >= 0),
  signoff_status text NOT NULL CHECK (signoff_status IN ('signed','verbal','deferred','missing')),
  signoff_method text NOT NULL CHECK (signoff_method IN ('digital','paper','photo','none')),
  followup_required boolean NOT NULL DEFAULT false,
  followup_due_date date,
  followup_reason text,
  job_value_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handoff_events_r2776 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_handoff_events_r2776;
CREATE POLICY founder_all ON engineer_handoff_events_r2776
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handoff_events_r2776
  (job_code, engineer_name, customer_name, hospital_name, city, handoff_month, handoff_at,
   customer_present, presence_mode, checklist_total, checklist_passed,
   signoff_status, signoff_method, followup_required, followup_due_date, followup_reason,
   job_value_rupees, notes)
VALUES
  ('JOB-7701','Ravi K','Dr. Suresh','Apollo Cradle','Hyderabad','2026-06-01'::date,'2026-06-03 11:00:00+05:30'::timestamptz,
   true,'in_person',12,12,'signed','digital',false,NULL,NULL,
   28000,'Full handoff, OT staff trained'),
  ('JOB-7702','Anita S','Nurse Lakshmi','Yashoda Group','Hyderabad','2026-06-01'::date,'2026-06-05 14:30:00+05:30'::timestamptz,
   true,'video_call',10,9,'verbal','photo',true,'2026-06-15'::date,'Pending vendor calibration cert',
   18500,'Customer on video, photo signoff'),
  ('JOB-7703','Mohan T','Dr. Patel','KIMS Secunderabad','Secunderabad','2026-06-01'::date,'2026-06-08 10:15:00+05:30'::timestamptz,
   false,'absent',8,5,'missing','none',true,'2026-06-12'::date,'No customer presence — repeat visit',
   12000,'Customer not available, partial test only'),
  ('JOB-7704','Suresh M','Dr. Reddy','Continental','Hyderabad','2026-06-01'::date,'2026-06-11 16:00:00+05:30'::timestamptz,
   true,'in_person',15,15,'signed','digital',false,NULL,NULL,
   45000,'Premium AMC handover, all protocols green'),
  ('JOB-7705','Priya N','Admin Kavita','Care Hospitals','Hyderabad','2026-06-01'::date,'2026-06-14 09:30:00+05:30'::timestamptz,
   true,'phone_only',10,8,'deferred','none',true,'2026-06-20'::date,'Need OT head signoff',
   22000,'Phone confirm, signoff pending OT head'),
  ('JOB-7706','Karthik R','Dr. Mehta','Sunshine Hospital','Hyderabad','2026-06-01'::date,'2026-06-17 13:45:00+05:30'::timestamptz,
   true,'in_person',14,13,'signed','paper',false,NULL,NULL,
   31000,'Paper signoff, photo backup uploaded'),
  ('JOB-7707','Deepa V','Dr. Iyer','Rainbow Childrens','Hyderabad','2026-06-01'::date,'2026-06-19 11:20:00+05:30'::timestamptz,
   false,'absent',10,4,'missing','none',true,'2026-06-22'::date,'Customer absent both visits',
   9500,'Second absence — escalate to CSM');

-- ---------------------------------------------------------------------------
-- Table 2: monthly engineer × customer presence rollup
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_presence_monthly_r2776 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  month_start date NOT NULL,
  total_handoffs int NOT NULL DEFAULT 0,
  customer_present_count int NOT NULL DEFAULT 0,
  full_signoff_count int NOT NULL DEFAULT 0,
  followups_open int NOT NULL DEFAULT 0,
  avg_checklist_pct numeric(5,2) NOT NULL DEFAULT 0,
  presence_pct numeric(5,2) NOT NULL DEFAULT 0,
  signoff_pct numeric(5,2) NOT NULL DEFAULT 0,
  grade text NOT NULL CHECK (grade IN ('A','B','C','D','F')),
  coaching_required boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_presence_monthly_r2776 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_presence_monthly_r2776;
CREATE POLICY founder_all ON engineer_presence_monthly_r2776
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_presence_monthly_r2776
  (engineer_name, month_start, total_handoffs, customer_present_count, full_signoff_count,
   followups_open, avg_checklist_pct, presence_pct, signoff_pct, grade, coaching_required, notes)
VALUES
  ('Ravi K','2026-06-01'::date,8,8,7,0,98.50,100.00,87.50,'A',false,'Top engineer this month'),
  ('Anita S','2026-06-01'::date,6,5,3,2,86.00,83.33,50.00,'B',false,'Strong presence, signoff slip'),
  ('Mohan T','2026-06-01'::date,5,2,1,3,62.50,40.00,20.00,'D',true,'Coaching scheduled — presence + signoff failing'),
  ('Suresh M','2026-06-01'::date,7,7,7,0,99.00,100.00,100.00,'A',false,'Perfect month, premium AMC focus'),
  ('Priya N','2026-06-01'::date,6,5,2,2,80.00,83.33,33.33,'C',true,'Phone-only handoffs flagged'),
  ('Karthik R','2026-06-01'::date,7,6,5,1,91.50,85.71,71.43,'B',false,'Solid — paper signoff dependency'),
  ('Deepa V','2026-06-01'::date,4,1,0,3,55.00,25.00,0.00,'F',true,'Escalate to ops head — repeat absences');

-- ---------------------------------------------------------------------------
-- RPC 1: KPI summary for current month
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_kpi();
CREATE OR REPLACE FUNCTION founder_r2776_kpi()
RETURNS TABLE (
  total_handoffs bigint,
  customer_present_pct numeric,
  full_signoff_pct numeric,
  followups_open bigint,
  total_job_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    ROUND(100.0 * SUM(CASE WHEN customer_present THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * SUM(CASE WHEN signoff_status = 'signed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2),
    SUM(CASE WHEN followup_required THEN 1 ELSE 0 END)::bigint,
    COALESCE(SUM(job_value_rupees),0)::bigint
  FROM engineer_handoff_events_r2776
  WHERE handoff_month = date_trunc('month', CURRENT_DATE)::date;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_kpi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_kpi() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: per-engineer monthly rollup
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2776_engineer_rollup()
RETURNS TABLE (
  engineer_name text,
  total_handoffs int,
  presence_pct numeric,
  signoff_pct numeric,
  avg_checklist_pct numeric,
  followups_open int,
  grade text,
  coaching_required boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT m.engineer_name, m.total_handoffs, m.presence_pct, m.signoff_pct,
         m.avg_checklist_pct, m.followups_open, m.grade, m.coaching_required
  FROM engineer_presence_monthly_r2776 m
  WHERE m.month_start = date_trunc('month', CURRENT_DATE)::date
  ORDER BY m.presence_pct DESC, m.signoff_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_engineer_rollup() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: handoff events list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_events();
CREATE OR REPLACE FUNCTION founder_r2776_events()
RETURNS TABLE (
  job_code text,
  engineer_name text,
  customer_name text,
  hospital_name text,
  presence_mode text,
  checklist_passed int,
  checklist_total int,
  signoff_status text,
  followup_required boolean,
  followup_due_date date,
  job_value_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.job_code, e.engineer_name, e.customer_name, e.hospital_name, e.presence_mode,
         e.checklist_passed, e.checklist_total, e.signoff_status, e.followup_required,
         e.followup_due_date, e.job_value_rupees
  FROM engineer_handoff_events_r2776 e
  WHERE e.handoff_month = date_trunc('month', CURRENT_DATE)::date
  ORDER BY e.handoff_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_events() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: presence mode breakdown
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_presence_breakdown();
CREATE OR REPLACE FUNCTION founder_r2776_presence_breakdown()
RETURNS TABLE (
  presence_mode text,
  event_count bigint,
  share_pct numeric,
  avg_checklist_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*) INTO total FROM engineer_handoff_events_r2776
   WHERE handoff_month = date_trunc('month', CURRENT_DATE)::date;
  RETURN QUERY
  SELECT e.presence_mode,
         COUNT(*)::bigint,
         ROUND(100.0 * COUNT(*) / NULLIF(total,0), 2),
         ROUND(AVG(100.0 * e.checklist_passed::numeric / NULLIF(e.checklist_total,0)), 2)
  FROM engineer_handoff_events_r2776 e
  WHERE e.handoff_month = date_trunc('month', CURRENT_DATE)::date
  GROUP BY e.presence_mode
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_presence_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_presence_breakdown() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: open follow-ups
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_open_followups();
CREATE OR REPLACE FUNCTION founder_r2776_open_followups()
RETURNS TABLE (
  job_code text,
  engineer_name text,
  customer_name text,
  hospital_name text,
  followup_due_date date,
  followup_reason text,
  days_to_due int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.job_code, e.engineer_name, e.customer_name, e.hospital_name,
         e.followup_due_date, e.followup_reason,
         (e.followup_due_date - CURRENT_DATE)::int
  FROM engineer_handoff_events_r2776 e
  WHERE e.followup_required = true
  ORDER BY e.followup_due_date ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_open_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_open_followups() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: signoff method mix
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_signoff_mix();
CREATE OR REPLACE FUNCTION founder_r2776_signoff_mix()
RETURNS TABLE (
  signoff_method text,
  signoff_status text,
  event_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.signoff_method, e.signoff_status,
         COUNT(*)::bigint,
         COALESCE(SUM(e.job_value_rupees),0)::bigint
  FROM engineer_handoff_events_r2776 e
  WHERE e.handoff_month = date_trunc('month', CURRENT_DATE)::date
  GROUP BY e.signoff_method, e.signoff_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_signoff_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_signoff_mix() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: coaching watchlist
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_coaching_watchlist();
CREATE OR REPLACE FUNCTION founder_r2776_coaching_watchlist()
RETURNS TABLE (
  engineer_name text,
  grade text,
  presence_pct numeric,
  signoff_pct numeric,
  followups_open int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT m.engineer_name, m.grade, m.presence_pct, m.signoff_pct, m.followups_open, m.notes
  FROM engineer_presence_monthly_r2776 m
  WHERE m.coaching_required = true
    AND m.month_start = date_trunc('month', CURRENT_DATE)::date
  ORDER BY
    CASE m.grade WHEN 'F' THEN 0 WHEN 'D' THEN 1 WHEN 'C' THEN 2 ELSE 3 END,
    m.presence_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_coaching_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_coaching_watchlist() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: city-level presence health
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2776_city_health();
CREATE OR REPLACE FUNCTION founder_r2776_city_health()
RETURNS TABLE (
  city text,
  events bigint,
  presence_pct numeric,
  signoff_pct numeric,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.city,
         COUNT(*)::bigint,
         ROUND(100.0 * SUM(CASE WHEN e.customer_present THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2),
         ROUND(100.0 * SUM(CASE WHEN e.signoff_status = 'signed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 2),
         COALESCE(SUM(e.job_value_rupees),0)::bigint
  FROM engineer_handoff_events_r2776 e
  WHERE e.handoff_month = date_trunc('month', CURRENT_DATE)::date
  GROUP BY e.city
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2776_city_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2776_city_health() TO authenticated;

COMMIT;
