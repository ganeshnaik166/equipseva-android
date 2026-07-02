-- Round 2922: Engineer Monthly Customer-Site Tool-Box Calibration Sticker Audit
-- HEAVY founder ops console — 2 tables + 7 RPCs gated by is_founder()

-- =========================================================================
-- TABLE 1: tool_box_calibration_sticker_audits_r2922
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.tool_box_calibration_sticker_audits_r2922 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  engineer_code text NOT NULL,
  customer_site_code text NOT NULL,
  city text NOT NULL,
  tools_total int NOT NULL,
  stickers_valid int NOT NULL,
  stickers_expired int NOT NULL,
  stickers_missing int NOT NULL,
  compliance_pct numeric(5,2) NOT NULL,
  audit_status text NOT NULL CHECK (audit_status IN ('passed','warn','failed','pending')),
  next_calibration_due date,
  notes text
);

ALTER TABLE public.tool_box_calibration_sticker_audits_r2922 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.tool_box_calibration_sticker_audits_r2922
  (audit_month, engineer_code, customer_site_code, city, tools_total, stickers_valid, stickers_expired, stickers_missing, compliance_pct, audit_status, next_calibration_due, notes)
VALUES
  ('2026-06-01'::date,'ENG-101','APOLLO-HYD-01','Hyderabad',24,22,1,1,91.67,'warn','2026-07-15'::date,'Torque wrench sticker expired'),
  ('2026-06-01'::date,'ENG-102','FORTIS-BLR-02','Bengaluru',30,30,0,0,100.00,'passed','2026-09-01'::date,'Clean'),
  ('2026-06-01'::date,'ENG-103','MAX-DEL-03','Delhi',18,12,4,2,66.67,'failed','2026-06-25'::date,'Multiple expired'),
  ('2026-06-01'::date,'ENG-104','MANI-CHE-04','Chennai',22,21,1,0,95.45,'passed','2026-08-10'::date,'Multimeter due soon'),
  ('2026-06-01'::date,'ENG-105','KIMS-HYD-05','Hyderabad',26,24,1,1,92.31,'warn','2026-07-20'::date,'Pressure gauge missing'),
  ('2026-06-01'::date,'ENG-106','AIIMS-DEL-06','Delhi',32,32,0,0,100.00,'passed','2026-09-15'::date,'Reference site'),
  ('2026-06-01'::date,'ENG-107','NAR-BLR-07','Bengaluru',20,15,3,2,75.00,'failed','2026-06-30'::date,'Replace calibration kit'),
  ('2026-06-01'::date,'ENG-108','RAINBOW-HYD-08','Hyderabad',16,16,0,0,100.00,'passed','2026-10-01'::date,'New tools issued'),
  ('2026-06-01'::date,'ENG-109','MEDANTA-GUR-09','Gurugram',28,25,2,1,89.29,'warn','2026-07-05'::date,'Oscilloscope expired'),
  ('2026-06-01'::date,'ENG-110','GLENEAGLES-MUM-10','Mumbai',24,23,1,0,95.83,'passed','2026-08-20'::date,'Minor'),
  ('2026-06-01'::date,'ENG-111','CARE-HYD-11','Hyderabad',19,14,3,2,73.68,'failed','2026-06-28'::date,'Escalate to ops'),
  ('2026-06-01'::date,'ENG-112','HCG-BLR-12','Bengaluru',22,22,0,0,100.00,'passed','2026-09-10'::date,'Clean'),
  ('2026-05-01'::date,'ENG-101','APOLLO-HYD-01','Hyderabad',24,23,1,0,95.83,'passed','2026-06-15'::date,'Prior month'),
  ('2026-05-01'::date,'ENG-103','MAX-DEL-03','Delhi',18,16,2,0,88.89,'warn','2026-06-25'::date,'Trend down'),
  ('2026-05-01'::date,'ENG-107','NAR-BLR-07','Bengaluru',20,18,1,1,90.00,'warn','2026-06-30'::date,'Trend down'),
  ('2026-06-01'::date,'ENG-113','YASHODA-HYD-13','Hyderabad',21,20,1,0,95.24,'passed','2026-08-05'::date,'Good'),
  ('2026-06-01'::date,'ENG-114','SAKRA-BLR-14','Bengaluru',17,12,3,2,70.59,'failed','2026-06-27'::date,'Critical'),
  ('2026-06-01'::date,'ENG-115','LILAVATI-MUM-15','Mumbai',25,24,1,0,96.00,'passed','2026-08-25'::date,'OK');

-- =========================================================================
-- TABLE 2: tool_box_sticker_remediation_actions_r2922
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.tool_box_sticker_remediation_actions_r2922 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_code text NOT NULL,
  customer_site_code text NOT NULL,
  tool_name text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('recalibrate','replace_sticker','retire_tool','reorder')),
  cost_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('queued','in_progress','done','cancelled')),
  due_date date,
  closed_at timestamptz
);

ALTER TABLE public.tool_box_sticker_remediation_actions_r2922 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.tool_box_sticker_remediation_actions_r2922
  (engineer_code, customer_site_code, tool_name, action_type, cost_rupees, status, due_date, closed_at)
VALUES
  ('ENG-101','APOLLO-HYD-01','Torque Wrench','recalibrate',1200,'in_progress','2026-06-30'::date,NULL),
  ('ENG-103','MAX-DEL-03','Multimeter Fluke 87V','recalibrate',2400,'queued','2026-07-05'::date,NULL),
  ('ENG-103','MAX-DEL-03','Pressure Gauge','replace_sticker',150,'done','2026-06-18'::date,'2026-06-18 11:00:00+05:30'::timestamptz),
  ('ENG-103','MAX-DEL-03','Oscilloscope','retire_tool',0,'done','2026-06-19'::date,'2026-06-19 14:00:00+05:30'::timestamptz),
  ('ENG-105','KIMS-HYD-05','Pressure Gauge','reorder',3500,'queued','2026-07-10'::date,NULL),
  ('ENG-107','NAR-BLR-07','IR Thermometer','recalibrate',1800,'in_progress','2026-06-29'::date,NULL),
  ('ENG-107','NAR-BLR-07','Calibration Kit','reorder',12500,'queued','2026-07-12'::date,NULL),
  ('ENG-109','MEDANTA-GUR-09','Oscilloscope','recalibrate',4200,'queued','2026-07-08'::date,NULL),
  ('ENG-110','GLENEAGLES-MUM-10','Tachometer','replace_sticker',150,'done','2026-06-17'::date,'2026-06-17 09:30:00+05:30'::timestamptz),
  ('ENG-111','CARE-HYD-11','Multimeter','recalibrate',2400,'in_progress','2026-06-28'::date,NULL),
  ('ENG-111','CARE-HYD-11','Torque Wrench','retire_tool',0,'queued','2026-07-01'::date,NULL),
  ('ENG-111','CARE-HYD-11','Pressure Gauge','reorder',3500,'queued','2026-07-03'::date,NULL),
  ('ENG-114','SAKRA-BLR-14','Calibration Kit','reorder',12500,'queued','2026-07-15'::date,NULL),
  ('ENG-114','SAKRA-BLR-14','Multimeter','recalibrate',2400,'in_progress','2026-06-30'::date,NULL),
  ('ENG-114','SAKRA-BLR-14','IR Thermometer','retire_tool',0,'queued','2026-07-02'::date,NULL),
  ('ENG-101','APOLLO-HYD-01','Sticker Refresh Kit','reorder',800,'done','2026-06-15'::date,'2026-06-15 10:00:00+05:30'::timestamptz),
  ('ENG-104','MANI-CHE-04','Multimeter','replace_sticker',150,'queued','2026-07-04'::date,NULL),
  ('ENG-112','HCG-BLR-12','Pressure Gauge','replace_sticker',150,'done','2026-06-16'::date,'2026-06-16 16:00:00+05:30'::timestamptz);

-- =========================================================================
-- RPC 1: compliance summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_compliance_summary()
RETURNS TABLE(
  total_audits bigint,
  passed bigint,
  warn bigint,
  failed bigint,
  avg_compliance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE audit_status='passed')::bigint,
           COUNT(*) FILTER (WHERE audit_status='warn')::bigint,
           COUNT(*) FILTER (WHERE audit_status='failed')::bigint,
           ROUND(AVG(compliance_pct)::numeric, 2)
    FROM public.tool_box_calibration_sticker_audits_r2922
    WHERE audit_month = (SELECT MAX(audit_month) FROM public.tool_box_calibration_sticker_audits_r2922);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_compliance_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_compliance_summary() TO authenticated;

-- =========================================================================
-- RPC 2: failed audits this month
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_failed_audits()
RETURNS TABLE(
  id uuid,
  engineer_code text,
  customer_site_code text,
  city text,
  compliance_pct numeric,
  stickers_expired int,
  stickers_missing int,
  next_calibration_due date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.engineer_code, a.customer_site_code, a.city,
           a.compliance_pct, a.stickers_expired, a.stickers_missing, a.next_calibration_due
    FROM public.tool_box_calibration_sticker_audits_r2922 a
    WHERE a.audit_status='failed'
      AND a.audit_month = (SELECT MAX(audit_month) FROM public.tool_box_calibration_sticker_audits_r2922)
    ORDER BY a.compliance_pct ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_failed_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_failed_audits() TO authenticated;

-- =========================================================================
-- RPC 3: engineer leaderboard
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_engineer_leaderboard()
RETURNS TABLE(
  engineer_code text,
  audits_done bigint,
  avg_compliance numeric,
  failed_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.engineer_code,
           COUNT(*)::bigint,
           ROUND(AVG(a.compliance_pct)::numeric, 2),
           COUNT(*) FILTER (WHERE a.audit_status='failed')::bigint
    FROM public.tool_box_calibration_sticker_audits_r2922 a
    GROUP BY a.engineer_code
    ORDER BY ROUND(AVG(a.compliance_pct)::numeric, 2) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_engineer_leaderboard() TO authenticated;

-- =========================================================================
-- RPC 4: city rollup
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_city_rollup()
RETURNS TABLE(
  city text,
  sites_audited bigint,
  avg_compliance numeric,
  failed_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.city,
           COUNT(*)::bigint,
           ROUND(AVG(a.compliance_pct)::numeric, 2),
           COUNT(*) FILTER (WHERE a.audit_status='failed')::bigint
    FROM public.tool_box_calibration_sticker_audits_r2922 a
    WHERE a.audit_month = (SELECT MAX(audit_month) FROM public.tool_box_calibration_sticker_audits_r2922)
    GROUP BY a.city
    ORDER BY ROUND(AVG(a.compliance_pct)::numeric, 2) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_city_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_city_rollup() TO authenticated;

-- =========================================================================
-- RPC 5: open remediation actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_open_remediation()
RETURNS TABLE(
  id uuid,
  engineer_code text,
  customer_site_code text,
  tool_name text,
  action_type text,
  cost_rupees int,
  status text,
  due_date date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.engineer_code, r.customer_site_code, r.tool_name,
           r.action_type, r.cost_rupees, r.status, r.due_date
    FROM public.tool_box_sticker_remediation_actions_r2922 r
    WHERE r.status IN ('queued','in_progress')
    ORDER BY r.due_date ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_open_remediation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_open_remediation() TO authenticated;

-- =========================================================================
-- RPC 6: remediation cost by type
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_remediation_cost_by_type()
RETURNS TABLE(
  action_type text,
  open_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.action_type,
           COUNT(*) FILTER (WHERE r.status IN ('queued','in_progress'))::bigint,
           COALESCE(SUM(r.cost_rupees) FILTER (WHERE r.status IN ('queued','in_progress')), 0)::bigint
    FROM public.tool_box_sticker_remediation_actions_r2922 r
    GROUP BY r.action_type
    ORDER BY 3 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_remediation_cost_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_remediation_cost_by_type() TO authenticated;

-- =========================================================================
-- RPC 7: upcoming due (next 30 days)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2922_upcoming_due()
RETURNS TABLE(
  engineer_code text,
  customer_site_code text,
  city text,
  next_calibration_due date,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.engineer_code, a.customer_site_code, a.city,
           a.next_calibration_due,
           (a.next_calibration_due - CURRENT_DATE)::int AS days_until
    FROM public.tool_box_calibration_sticker_audits_r2922 a
    WHERE a.next_calibration_due IS NOT NULL
      AND a.next_calibration_due BETWEEN CURRENT_DATE AND (CURRENT_DATE + 30)
      AND a.audit_month = (SELECT MAX(audit_month) FROM public.tool_box_calibration_sticker_audits_r2922)
    ORDER BY a.next_calibration_due ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2922_upcoming_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2922_upcoming_due() TO authenticated;
