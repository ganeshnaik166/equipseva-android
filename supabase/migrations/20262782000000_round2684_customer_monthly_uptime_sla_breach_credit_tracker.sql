BEGIN;

-- ============================================================
-- Round r2684: Customer Monthly Uptime SLA Breach Credit Tracker
-- Tracks per-equipment monthly uptime vs SLA target, computes
-- breaches, issues service credits, and tracks remediation actions.
-- ============================================================

-- ---------- TABLE 1: uptime_sla_records_r2684 ----------
CREATE TABLE IF NOT EXISTS public.uptime_sla_records_r2684 (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name        text NOT NULL,
  equipment_label      text NOT NULL,
  equipment_category   text NOT NULL CHECK (equipment_category IN ('imaging','life_support','diagnostics','surgical','dental')),
  measurement_month    date NOT NULL,
  uptime_pct           numeric(5,2) NOT NULL CHECK (uptime_pct >= 0 AND uptime_pct <= 100),
  sla_target_pct       numeric(5,2) NOT NULL CHECK (sla_target_pct >= 0 AND sla_target_pct <= 100),
  breach_severity      text NOT NULL CHECK (breach_severity IN ('none','minor','major','critical')),
  downtime_minutes     integer NOT NULL CHECK (downtime_minutes >= 0),
  monthly_fee_rupees   integer NOT NULL CHECK (monthly_fee_rupees >= 0),
  credit_issued_rupees integer NOT NULL DEFAULT 0 CHECK (credit_issued_rupees >= 0),
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.uptime_sla_records_r2684 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.uptime_sla_records_r2684;
CREATE POLICY founder_all ON public.uptime_sla_records_r2684
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.uptime_sla_records_r2684
  (customer_name, equipment_label, equipment_category, measurement_month, uptime_pct, sla_target_pct, breach_severity, downtime_minutes, monthly_fee_rupees, credit_issued_rupees)
VALUES
  ('Apollo Hyderabad','MRI Siemens 1.5T','imaging','2026-05-01',97.20,99.50,'major',1209,180000,18000),
  ('Yashoda Hospitals','CT Scanner GE 64-slice','imaging','2026-05-01',99.80,99.50,'none',86,150000,0),
  ('Continental Multi-Specialty','Ventilator Hamilton C6','life_support','2026-05-01',95.40,99.90,'critical',2050,60000,12000),
  ('Sunrise Dental Chain','Dental Chair A-dec 511','dental','2026-05-01',99.10,98.00,'none',402,18000,0),
  ('Care Hospitals','Anaesthesia Workstation','surgical','2026-05-01',98.20,99.00,'minor',803,72000,3600),
  ('KIMS Secunderabad','Ultrasound Philips EPIQ','diagnostics','2026-05-01',96.70,99.00,'major',1466,45000,4500);

-- ---------- TABLE 2: sla_credit_actions_r2684 ----------
CREATE TABLE IF NOT EXISTS public.sla_credit_actions_r2684 (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id            uuid NOT NULL REFERENCES public.uptime_sla_records_r2684(id) ON DELETE CASCADE,
  action_type          text NOT NULL CHECK (action_type IN ('credit_note','rca_required','engineer_dispatch','contract_review','escalate_founder')),
  action_status        text NOT NULL CHECK (action_status IN ('pending','in_progress','completed','cancelled')),
  owner_name           text NOT NULL,
  due_date             date NOT NULL,
  notes                text NOT NULL DEFAULT '',
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sla_credit_actions_r2684 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.sla_credit_actions_r2684;
CREATE POLICY founder_all ON public.sla_credit_actions_r2684
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'credit_note','completed','Finance Ops','2026-06-05','Credit note CN-2684-001 issued for May breach' FROM public.uptime_sla_records_r2684 WHERE customer_name='Apollo Hyderabad' LIMIT 1;

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'rca_required','in_progress','Service Lead','2026-06-12','RCA pending on ventilator critical breach' FROM public.uptime_sla_records_r2684 WHERE customer_name='Continental Multi-Specialty' LIMIT 1;

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'engineer_dispatch','pending','Field Ops','2026-06-08','Senior engineer scheduled for ultrasound recalibration' FROM public.uptime_sla_records_r2684 WHERE customer_name='KIMS Secunderabad' LIMIT 1;

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'contract_review','pending','Sales Ops','2026-06-15','Apollo asking for revised SLA tier after 2 consecutive months' FROM public.uptime_sla_records_r2684 WHERE customer_name='Apollo Hyderabad' LIMIT 1;

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'escalate_founder','in_progress','Founder','2026-06-10','Critical ventilator breach — patient safety risk' FROM public.uptime_sla_records_r2684 WHERE customer_name='Continental Multi-Specialty' LIMIT 1;

INSERT INTO public.sla_credit_actions_r2684
  (record_id, action_type, action_status, owner_name, due_date, notes)
SELECT id, 'credit_note','pending','Finance Ops','2026-06-14','Care Hospitals minor breach credit awaiting CFO approval' FROM public.uptime_sla_records_r2684 WHERE customer_name='Care Hospitals' LIMIT 1;


-- ============================================================
-- RPC 1: founder_r2684_kpis — overall KPIs
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_kpis();
CREATE OR REPLACE FUNCTION public.founder_r2684_kpis()
RETURNS TABLE (
  total_records      bigint,
  total_breaches     bigint,
  critical_breaches  bigint,
  avg_uptime_pct     numeric,
  total_credits_inr  bigint,
  credits_at_risk    bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE breach_severity <> 'none')::bigint,
    COUNT(*) FILTER (WHERE breach_severity = 'critical')::bigint,
    COALESCE(ROUND(AVG(uptime_pct)::numeric, 2), 0)::numeric,
    COALESCE(SUM(credit_issued_rupees), 0)::bigint,
    COALESCE(SUM(monthly_fee_rupees) FILTER (WHERE breach_severity IN ('major','critical') AND credit_issued_rupees = 0), 0)::bigint
  FROM public.uptime_sla_records_r2684;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_kpis() TO authenticated;


-- ============================================================
-- RPC 2: founder_r2684_breach_records — all SLA records
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_breach_records();
CREATE OR REPLACE FUNCTION public.founder_r2684_breach_records()
RETURNS TABLE (
  id                    uuid,
  customer_name         text,
  equipment_label       text,
  equipment_category    text,
  measurement_month     date,
  uptime_pct            numeric,
  sla_target_pct        numeric,
  breach_severity       text,
  downtime_minutes      integer,
  monthly_fee_rupees    integer,
  credit_issued_rupees  integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_name, r.equipment_label, r.equipment_category, r.measurement_month,
         r.uptime_pct, r.sla_target_pct, r.breach_severity, r.downtime_minutes,
         r.monthly_fee_rupees, r.credit_issued_rupees
  FROM public.uptime_sla_records_r2684 r
  ORDER BY r.breach_severity DESC, r.uptime_pct ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_breach_records() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_breach_records() TO authenticated;


-- ============================================================
-- RPC 3: founder_r2684_category_summary — by equipment category
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_category_summary();
CREATE OR REPLACE FUNCTION public.founder_r2684_category_summary()
RETURNS TABLE (
  equipment_category text,
  record_count       bigint,
  avg_uptime         numeric,
  breach_count       bigint,
  total_credit       bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_category,
         COUNT(*)::bigint,
         ROUND(AVG(r.uptime_pct)::numeric, 2)::numeric,
         COUNT(*) FILTER (WHERE r.breach_severity <> 'none')::bigint,
         COALESCE(SUM(r.credit_issued_rupees), 0)::bigint
  FROM public.uptime_sla_records_r2684 r
  GROUP BY r.equipment_category
  ORDER BY breach_count DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_category_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_category_summary() TO authenticated;


-- ============================================================
-- RPC 4: founder_r2684_pending_actions — open actions
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_pending_actions();
CREATE OR REPLACE FUNCTION public.founder_r2684_pending_actions()
RETURNS TABLE (
  id              uuid,
  customer_name   text,
  equipment_label text,
  action_type     text,
  action_status   text,
  owner_name      text,
  due_date        date,
  notes           text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, r.customer_name, r.equipment_label, a.action_type, a.action_status,
         a.owner_name, a.due_date, a.notes
  FROM public.sla_credit_actions_r2684 a
  JOIN public.uptime_sla_records_r2684 r ON r.id = a.record_id
  WHERE a.action_status IN ('pending','in_progress')
  ORDER BY a.due_date ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_pending_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_pending_actions() TO authenticated;


-- ============================================================
-- RPC 5: founder_r2684_top_offenders — worst customers by uptime
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_top_offenders();
CREATE OR REPLACE FUNCTION public.founder_r2684_top_offenders()
RETURNS TABLE (
  customer_name     text,
  equipment_label   text,
  uptime_pct        numeric,
  sla_target_pct    numeric,
  gap_pct           numeric,
  breach_severity   text,
  credit_issued_inr integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.customer_name, r.equipment_label, r.uptime_pct, r.sla_target_pct,
         ROUND((r.sla_target_pct - r.uptime_pct)::numeric, 2)::numeric,
         r.breach_severity, r.credit_issued_rupees
  FROM public.uptime_sla_records_r2684 r
  WHERE r.uptime_pct < r.sla_target_pct
  ORDER BY (r.sla_target_pct - r.uptime_pct) DESC
  LIMIT 10;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_top_offenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_top_offenders() TO authenticated;


-- ============================================================
-- RPC 6: founder_r2684_severity_distribution
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_severity_distribution();
CREATE OR REPLACE FUNCTION public.founder_r2684_severity_distribution()
RETURNS TABLE (
  breach_severity text,
  record_count    bigint,
  total_downtime  bigint,
  total_credit    bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.breach_severity,
         COUNT(*)::bigint,
         COALESCE(SUM(r.downtime_minutes), 0)::bigint,
         COALESCE(SUM(r.credit_issued_rupees), 0)::bigint
  FROM public.uptime_sla_records_r2684 r
  GROUP BY r.breach_severity
  ORDER BY CASE r.breach_severity
    WHEN 'critical' THEN 1
    WHEN 'major' THEN 2
    WHEN 'minor' THEN 3
    WHEN 'none' THEN 4
  END;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_severity_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_severity_distribution() TO authenticated;


-- ============================================================
-- RPC 7: founder_r2684_credit_exposure — financial exposure
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_credit_exposure();
CREATE OR REPLACE FUNCTION public.founder_r2684_credit_exposure()
RETURNS TABLE (
  customer_name      text,
  monthly_fee_inr    integer,
  credit_issued_inr  integer,
  effective_pct      numeric,
  status_flag        text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.customer_name,
         r.monthly_fee_rupees,
         r.credit_issued_rupees,
         CASE WHEN r.monthly_fee_rupees > 0
              THEN ROUND((r.credit_issued_rupees::numeric / r.monthly_fee_rupees::numeric) * 100, 2)
              ELSE 0::numeric END,
         CASE
           WHEN r.breach_severity = 'critical' AND r.credit_issued_rupees = 0 THEN 'unresolved_critical'
           WHEN r.breach_severity = 'major' AND r.credit_issued_rupees = 0 THEN 'unresolved_major'
           WHEN r.credit_issued_rupees > 0 THEN 'credited'
           ELSE 'no_breach'
         END
  FROM public.uptime_sla_records_r2684 r
  ORDER BY r.credit_issued_rupees DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_credit_exposure() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_credit_exposure() TO authenticated;


-- ============================================================
-- RPC 8: founder_r2684_action_status_summary
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_r2684_action_status_summary();
CREATE OR REPLACE FUNCTION public.founder_r2684_action_status_summary()
RETURNS TABLE (
  action_type    text,
  action_status  text,
  count_rows     bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_type, a.action_status, COUNT(*)::bigint
  FROM public.sla_credit_actions_r2684 a
  GROUP BY a.action_type, a.action_status
  ORDER BY a.action_type, a.action_status;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.founder_r2684_action_status_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2684_action_status_summary() TO authenticated;

COMMIT;
