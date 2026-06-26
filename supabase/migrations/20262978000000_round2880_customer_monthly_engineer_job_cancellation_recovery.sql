BEGIN;

-- Round 2880: Customer Monthly Engineer Job Cancellation Recovery
-- Track engineer-level job cancellation causes, recovery actions, refunds, win-back, and verdict.

-- =====================================================================
-- Table 1: cancellation events
-- =====================================================================
CREATE TABLE IF NOT EXISTS engineer_job_cancellation_recovery_r2880 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  job_code text NOT NULL,
  job_kind text NOT NULL CHECK (job_kind IN ('repair','maintenance','amc_visit','installation')),
  customer_code text NOT NULL,
  customer_name text NOT NULL,
  cancellation_cause text NOT NULL CHECK (cancellation_cause IN ('engineer_no_show','part_unavailable','customer_dissatisfied','reschedule_failed','price_dispute','duplicate_visit','out_of_scope')),
  cancelled_at timestamptz NOT NULL,
  job_value_rupees numeric(12,2) NOT NULL,
  refund_rupees numeric(12,2) NOT NULL,
  recovery_action text NOT NULL CHECK (recovery_action IN ('refund_full','refund_partial','reassign_engineer','founder_call','credit_voucher','no_action')),
  recovery_owner text NOT NULL,
  win_back_state text NOT NULL CHECK (win_back_state IN ('lost','at_risk','recovered','escalated','pending')),
  win_back_value_rupees numeric(12,2) NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('coachable','systemic','one_off','blocker','win')),
  notes text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_job_cancellation_recovery_r2880 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_job_cancellation_recovery_r2880;
CREATE POLICY founder_all ON engineer_job_cancellation_recovery_r2880
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_job_cancellation_recovery_r2880
  (month_start, engineer_code, engineer_name, job_code, job_kind, customer_code, customer_name,
   cancellation_cause, cancelled_at, job_value_rupees, refund_rupees, recovery_action, recovery_owner,
   win_back_state, win_back_value_rupees, verdict, notes)
VALUES
  ('2026-06-01'::date, 'ENG-021', 'Ravi K', 'JOB-88201', 'repair', 'CUST-5101', 'Apollo Spectra Hyd',
   'engineer_no_show', '2026-06-04 11:20+05:30', 8400.00, 8400.00, 'refund_full', 'ops@equipseva',
   'recovered', 12500.00, 'coachable', 'engineer overslept; verbal warning + reassigned next day'),
  ('2026-06-01'::date, 'ENG-007', 'Sunil B', 'JOB-88455', 'amc_visit', 'CUST-5044', 'Yashoda KPHB',
   'part_unavailable', '2026-06-09 15:05+05:30', 4200.00, 0.00, 'reassign_engineer', 'inventory@equipseva',
   'pending', 4200.00, 'systemic', 'bonded-parts buffer empty for HF probes; reorder triggered'),
  ('2026-06-01'::date, 'ENG-014', 'Meena R', 'JOB-88512', 'repair', 'CUST-5198', 'KIMS Secunderabad',
   'customer_dissatisfied', '2026-06-12 09:40+05:30', 15600.00, 7800.00, 'refund_partial', 'founder@equipseva',
   'at_risk', 18000.00, 'coachable', 'rude on call; refresher training + founder courtesy call booked'),
  ('2026-06-01'::date, 'ENG-029', 'Arif H', 'JOB-88673', 'installation', 'CUST-5311', 'Care Banjara',
   'price_dispute', '2026-06-15 17:55+05:30', 22000.00, 22000.00, 'founder_call', 'founder@equipseva',
   'recovered', 25000.00, 'win', 'quote mismatch — founder rebuilt SoW, customer re-booked at higher value'),
  ('2026-06-01'::date, 'ENG-033', 'Pooja S', 'JOB-88701', 'maintenance', 'CUST-5407', 'Continental Gachibowli',
   'reschedule_failed', '2026-06-18 14:10+05:30', 6800.00, 6800.00, 'credit_voucher', 'ops@equipseva',
   'lost', 0.00, 'systemic', 'three reschedules in a row; route-planner needs Gachibowli slot fix'),
  ('2026-06-01'::date, 'ENG-021', 'Ravi K', 'JOB-88808', 'repair', 'CUST-5512', 'Aster Kukatpally',
   'duplicate_visit', '2026-06-21 10:30+05:30', 3200.00, 3200.00, 'refund_full', 'ops@equipseva',
   'recovered', 9800.00, 'one_off', 'duplicate ticket; merged into parent + apology voucher');

-- =====================================================================
-- Table 2: monthly engineer roll-up
-- =====================================================================
CREATE TABLE IF NOT EXISTS engineer_monthly_cancel_summary_r2880 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  total_jobs int NOT NULL,
  cancelled_jobs int NOT NULL,
  cancellation_rate_pct numeric(5,2) NOT NULL,
  refund_rupees numeric(12,2) NOT NULL,
  recovered_value_rupees numeric(12,2) NOT NULL,
  lost_value_rupees numeric(12,2) NOT NULL,
  top_cause text NOT NULL CHECK (top_cause IN ('engineer_no_show','part_unavailable','customer_dissatisfied','reschedule_failed','price_dispute','duplicate_visit','out_of_scope')),
  verdict text NOT NULL CHECK (verdict IN ('green','amber','red','watch')),
  action_owner text NOT NULL,
  next_step text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_cancel_summary_r2880 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_cancel_summary_r2880;
CREATE POLICY founder_all ON engineer_monthly_cancel_summary_r2880
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_cancel_summary_r2880
  (month_start, engineer_code, engineer_name, total_jobs, cancelled_jobs, cancellation_rate_pct,
   refund_rupees, recovered_value_rupees, lost_value_rupees, top_cause, verdict, action_owner, next_step)
VALUES
  ('2026-06-01'::date, 'ENG-021', 'Ravi K', 42, 2, 4.76, 11600.00, 22300.00, 0.00,
   'engineer_no_show', 'amber', 'ops@equipseva', 'weekly 1:1 + alarm-clock SOP'),
  ('2026-06-01'::date, 'ENG-007', 'Sunil B', 36, 1, 2.78, 0.00, 0.00, 4200.00,
   'part_unavailable', 'watch', 'inventory@equipseva', 'lift bonded-parts buffer 1.5x for HF probes'),
  ('2026-06-01'::date, 'ENG-014', 'Meena R', 31, 1, 3.23, 7800.00, 0.00, 18000.00,
   'customer_dissatisfied', 'red', 'founder@equipseva', 'soft-skills refresher + 30-day probation'),
  ('2026-06-01'::date, 'ENG-029', 'Arif H', 28, 1, 3.57, 22000.00, 25000.00, 0.00,
   'price_dispute', 'green', 'sales@equipseva', 'codify rebuilt SoW into quote template'),
  ('2026-06-01'::date, 'ENG-033', 'Pooja S', 25, 1, 4.00, 6800.00, 0.00, 0.00,
   'reschedule_failed', 'amber', 'ops@equipseva', 'fix Gachibowli slot in route planner'),
  ('2026-06-01'::date, 'ENG-040', 'Karthik V', 30, 0, 0.00, 0.00, 0.00, 0.00,
   'engineer_no_show', 'green', 'ops@equipseva', 'maintain; nominate for spotlight');

-- =====================================================================
-- RPCs (all SECDEF, founder-gated)
-- =====================================================================

-- 1. KPI overview
DROP FUNCTION IF EXISTS founder_r2880_kpi_overview();
CREATE FUNCTION founder_r2880_kpi_overview()
RETURNS TABLE (
  total_cancellations int,
  total_refund_rupees numeric,
  recovered_value_rupees numeric,
  lost_value_rupees numeric,
  recovery_rate_pct numeric,
  red_engineers int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_job_cancellation_recovery_r2880),
    COALESCE((SELECT SUM(refund_rupees) FROM engineer_job_cancellation_recovery_r2880), 0)::numeric,
    COALESCE((SELECT SUM(win_back_value_rupees) FROM engineer_job_cancellation_recovery_r2880 WHERE win_back_state = 'recovered'), 0)::numeric,
    COALESCE((SELECT SUM(job_value_rupees) FROM engineer_job_cancellation_recovery_r2880 WHERE win_back_state = 'lost'), 0)::numeric,
    CASE WHEN (SELECT COUNT(*) FROM engineer_job_cancellation_recovery_r2880) = 0 THEN 0
         ELSE ROUND(100.0 *
              (SELECT COUNT(*) FROM engineer_job_cancellation_recovery_r2880 WHERE win_back_state = 'recovered')::numeric
              / (SELECT COUNT(*) FROM engineer_job_cancellation_recovery_r2880)::numeric, 2)
    END,
    (SELECT COUNT(*)::int FROM engineer_monthly_cancel_summary_r2880 WHERE verdict = 'red');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_kpi_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_kpi_overview() TO authenticated;

-- 2. List cancellations
DROP FUNCTION IF EXISTS founder_r2880_list_cancellations();
CREATE FUNCTION founder_r2880_list_cancellations()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  job_code text,
  job_kind text,
  customer_name text,
  cancellation_cause text,
  cancelled_at timestamptz,
  job_value_rupees numeric,
  refund_rupees numeric,
  recovery_action text,
  win_back_state text,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_name, e.job_code, e.job_kind, e.customer_name,
         e.cancellation_cause, e.cancelled_at, e.job_value_rupees, e.refund_rupees,
         e.recovery_action, e.win_back_state, e.verdict
  FROM engineer_job_cancellation_recovery_r2880 e
  ORDER BY e.cancelled_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_list_cancellations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_list_cancellations() TO authenticated;

-- 3. Engineer monthly summary
DROP FUNCTION IF EXISTS founder_r2880_engineer_summary();
CREATE FUNCTION founder_r2880_engineer_summary()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  engineer_name text,
  total_jobs int,
  cancelled_jobs int,
  cancellation_rate_pct numeric,
  refund_rupees numeric,
  recovered_value_rupees numeric,
  lost_value_rupees numeric,
  top_cause text,
  verdict text,
  next_step text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_code, s.engineer_name, s.total_jobs, s.cancelled_jobs,
         s.cancellation_rate_pct, s.refund_rupees, s.recovered_value_rupees,
         s.lost_value_rupees, s.top_cause, s.verdict, s.next_step
  FROM engineer_monthly_cancel_summary_r2880 s
  ORDER BY s.cancellation_rate_pct DESC, s.engineer_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_engineer_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_engineer_summary() TO authenticated;

-- 4. Cause breakdown
DROP FUNCTION IF EXISTS founder_r2880_cause_breakdown();
CREATE FUNCTION founder_r2880_cause_breakdown()
RETURNS TABLE (
  cause text,
  event_count int,
  refund_rupees numeric,
  lost_value_rupees numeric,
  recovered_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.cancellation_cause,
         COUNT(*)::int,
         COALESCE(SUM(e.refund_rupees), 0)::numeric,
         COALESCE(SUM(CASE WHEN e.win_back_state = 'lost' THEN e.job_value_rupees ELSE 0 END), 0)::numeric,
         COALESCE(SUM(CASE WHEN e.win_back_state = 'recovered' THEN e.win_back_value_rupees ELSE 0 END), 0)::numeric
  FROM engineer_job_cancellation_recovery_r2880 e
  GROUP BY e.cancellation_cause
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_cause_breakdown() TO authenticated;

-- 5. Recovery action mix
DROP FUNCTION IF EXISTS founder_r2880_recovery_mix();
CREATE FUNCTION founder_r2880_recovery_mix()
RETURNS TABLE (
  recovery_action text,
  event_count int,
  refund_rupees numeric,
  recovered_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.recovery_action,
         COUNT(*)::int,
         COALESCE(SUM(e.refund_rupees), 0)::numeric,
         COALESCE(SUM(CASE WHEN e.win_back_state = 'recovered' THEN e.win_back_value_rupees ELSE 0 END), 0)::numeric
  FROM engineer_job_cancellation_recovery_r2880 e
  GROUP BY e.recovery_action
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_recovery_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_recovery_mix() TO authenticated;

-- 6. Win-back funnel
DROP FUNCTION IF EXISTS founder_r2880_winback_funnel();
CREATE FUNCTION founder_r2880_winback_funnel()
RETURNS TABLE (
  win_back_state text,
  event_count int,
  job_value_rupees numeric,
  win_back_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.win_back_state,
         COUNT(*)::int,
         COALESCE(SUM(e.job_value_rupees), 0)::numeric,
         COALESCE(SUM(e.win_back_value_rupees), 0)::numeric
  FROM engineer_job_cancellation_recovery_r2880 e
  GROUP BY e.win_back_state
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_winback_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_winback_funnel() TO authenticated;

-- 7. Verdict distribution
DROP FUNCTION IF EXISTS founder_r2880_verdict_distribution();
CREATE FUNCTION founder_r2880_verdict_distribution()
RETURNS TABLE (
  verdict text,
  event_count int,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total_n int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_n FROM engineer_job_cancellation_recovery_r2880;
  IF total_n = 0 THEN total_n := 1; END IF;
  RETURN QUERY
  SELECT e.verdict,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*)::numeric / total_n::numeric, 2)
  FROM engineer_job_cancellation_recovery_r2880 e
  GROUP BY e.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_verdict_distribution() TO authenticated;

-- 8. Red engineers (focus list)
DROP FUNCTION IF EXISTS founder_r2880_red_engineers();
CREATE FUNCTION founder_r2880_red_engineers()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  cancellation_rate_pct numeric,
  top_cause text,
  next_step text,
  action_owner text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.cancellation_rate_pct,
         s.top_cause, s.next_step, s.action_owner
  FROM engineer_monthly_cancel_summary_r2880 s
  WHERE s.verdict IN ('red','amber')
  ORDER BY CASE s.verdict WHEN 'red' THEN 0 ELSE 1 END, s.cancellation_rate_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2880_red_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2880_red_engineers() TO authenticated;

COMMIT;
