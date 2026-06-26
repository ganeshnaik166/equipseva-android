BEGIN;

-- =====================================================================
-- Round 2874: Engineer Monthly Customer Job Recovery Narrative
-- HEAVY ★★★★ founder console
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: engineer_monthly_recovery_narratives_r2874
-- One row per (engineer, month, customer, failed_job) recovery story
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_recovery_narratives_r2874 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  narrative_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond')),
  customer_code text NOT NULL,
  customer_name text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','veterinary','homecare')),
  failed_job_code text NOT NULL,
  failed_job_kind text NOT NULL CHECK (failed_job_kind IN ('repair','maintenance','installation','calibration','amc_visit')),
  failure_root_cause text NOT NULL CHECK (failure_root_cause IN ('part_unavailable','engineer_skill_gap','escalation_delay','customer_cancel','sla_breach','quality_reject','wrong_diagnosis')),
  failure_severity text NOT NULL CHECK (failure_severity IN ('p0','p1','p2','p3')),
  failed_at timestamptz NOT NULL,
  recovery_action text NOT NULL CHECK (recovery_action IN ('rework_visit','senior_engineer_pair','refund_partial','refund_full','goodwill_credit','tier_upgrade_discount','escalated_to_founder')),
  recovery_owner_engineer text NOT NULL,
  recovery_completed_at timestamptz,
  recovery_outcome text NOT NULL CHECK (recovery_outcome IN ('won_back','at_risk','churned','partial_recovery','pending')),
  winback_revenue_rupees integer NOT NULL DEFAULT 0,
  refund_paid_rupees integer NOT NULL DEFAULT 0,
  goodwill_credit_rupees integer NOT NULL DEFAULT 0,
  csat_before integer CHECK (csat_before BETWEEN 1 AND 5),
  csat_after integer CHECK (csat_after BETWEEN 1 AND 5),
  pulse_score integer NOT NULL CHECK (pulse_score BETWEEN 0 AND 100),
  founder_verdict text NOT NULL CHECK (founder_verdict IN ('exemplary','acceptable','watchlist','intervene','terminate_engagement')),
  narrative_summary text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_recovery_narratives_r2874 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_recovery_narratives_r2874;
CREATE POLICY founder_all ON engineer_monthly_recovery_narratives_r2874
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_recovery_narratives_r2874
  (narrative_month, engineer_code, engineer_name, engineer_tier, customer_code, customer_name, customer_segment,
   failed_job_code, failed_job_kind, failure_root_cause, failure_severity, failed_at,
   recovery_action, recovery_owner_engineer, recovery_completed_at, recovery_outcome,
   winback_revenue_rupees, refund_paid_rupees, goodwill_credit_rupees,
   csat_before, csat_after, pulse_score, founder_verdict, narrative_summary)
VALUES
  ('2026-06-01'::date, 'ENG-1101', 'Ravi Kumar', 'gold', 'CUST-5501', 'Apollo Hyderabad', 'hospital',
   'JOB-90021', 'repair', 'part_unavailable', 'p1', '2026-06-03 09:12:00+05:30',
   'senior_engineer_pair', 'ENG-1199', '2026-06-05 18:00:00+05:30', 'won_back',
   42000, 0, 2500, 2, 5, 88, 'exemplary',
   'Apollo ventilator down 36h; senior pair flew bonded part same-day; CSAT 2 to 5; renewed AMC.'),
  ('2026-06-01'::date, 'ENG-1102', 'Sunita Reddy', 'silver', 'CUST-5502', 'CARE Banjara Diagnostic', 'diagnostic',
   'JOB-90034', 'calibration', 'engineer_skill_gap', 'p2', '2026-06-07 11:00:00+05:30',
   'rework_visit', 'ENG-1102', '2026-06-09 14:30:00+05:30', 'partial_recovery',
   8500, 1500, 1000, 3, 4, 64, 'acceptable',
   'CT calibration drifted; rework closed but customer flagged delay; renewed for 3 months only.'),
  ('2026-06-01'::date, 'ENG-1103', 'Imran Shaikh', 'bronze', 'CUST-5503', 'Smile Dental Whitefield', 'dental',
   'JOB-90045', 'maintenance', 'sla_breach', 'p2', '2026-06-10 10:30:00+05:30',
   'refund_partial', 'ENG-1199', '2026-06-12 17:00:00+05:30', 'at_risk',
   0, 4500, 2000, 4, 3, 42, 'watchlist',
   'Dental chair PM 48h late; partial refund issued; customer paused AMC pending June review.'),
  ('2026-06-01'::date, 'ENG-1104', 'Pooja Mehta', 'platinum', 'CUST-5504', 'Manipal Vijayawada', 'hospital',
   'JOB-90067', 'installation', 'wrong_diagnosis', 'p1', '2026-06-12 08:00:00+05:30',
   'escalated_to_founder', 'FOUNDER', '2026-06-14 21:00:00+05:30', 'won_back',
   75000, 0, 5000, 1, 5, 92, 'exemplary',
   'Anesthesia install mis-spec; founder escalation, swap unit shipped; expanded to 4 ORs contract.'),
  ('2026-06-01'::date, 'ENG-1105', 'Karthik Nair', 'silver', 'CUST-5505', 'Vasan Eye Coimbatore', 'clinic',
   'JOB-90089', 'repair', 'quality_reject', 'p2', '2026-06-15 13:45:00+05:30',
   'goodwill_credit', 'ENG-1105', '2026-06-17 11:00:00+05:30', 'won_back',
   18000, 0, 3500, 3, 4, 71, 'acceptable',
   'Phaco machine post-repair noise; goodwill credit + free PM next month; relationship stabilized.'),
  ('2026-06-01'::date, 'ENG-1106', 'Deepika Iyer', 'gold', 'CUST-5506', 'PetCare Pune Vet Hospital', 'veterinary',
   'JOB-90102', 'amc_visit', 'escalation_delay', 'p1', '2026-06-18 09:00:00+05:30',
   'tier_upgrade_discount', 'ENG-1106', '2026-06-20 16:00:00+05:30', 'won_back',
   28000, 0, 1500, 2, 5, 81, 'exemplary',
   'Vet X-ray AMC visit delayed 5d; tier upgrade discount converted to platinum AMC.'),
  ('2026-06-01'::date, 'ENG-1107', 'Anand Joshi', 'bronze', 'CUST-5507', 'HomeOxy Chennai', 'homecare',
   'JOB-90115', 'repair', 'customer_cancel', 'p3', '2026-06-20 14:00:00+05:30',
   'refund_full', 'ENG-1199', '2026-06-21 10:00:00+05:30', 'churned',
   0, 6500, 0, 4, 2, 18, 'intervene',
   'Homecare concentrator job aborted; customer churned to local vendor; engineer counseling triggered.'),
  ('2026-06-01'::date, 'ENG-1108', 'Reema Banerjee', 'diamond', 'CUST-5508', 'Tata Memorial Mumbai', 'hospital',
   'JOB-90133', 'maintenance', 'part_unavailable', 'p0', '2026-06-22 06:30:00+05:30',
   'senior_engineer_pair', 'ENG-1108', '2026-06-22 18:00:00+05:30', 'won_back',
   95000, 0, 8000, 2, 5, 96, 'exemplary',
   'Linac PM critical; 12h heroic recovery same-day; flagship reference customer retained.');

-- ---------------------------------------------------------------------
-- Table 2: engineer_monthly_recovery_pulse_r2874
-- Pulse + verdict roll-up per engineer per month
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_recovery_pulse_r2874 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond')),
  failed_jobs_count integer NOT NULL DEFAULT 0,
  recovery_attempts integer NOT NULL DEFAULT 0,
  won_back_count integer NOT NULL DEFAULT 0,
  churned_count integer NOT NULL DEFAULT 0,
  total_winback_revenue_rupees integer NOT NULL DEFAULT 0,
  total_refund_paid_rupees integer NOT NULL DEFAULT 0,
  avg_csat_lift numeric(3,2) NOT NULL DEFAULT 0,
  median_recovery_hours integer NOT NULL DEFAULT 0,
  pulse_score integer NOT NULL CHECK (pulse_score BETWEEN 0 AND 100),
  trend_vs_prev_month text NOT NULL CHECK (trend_vs_prev_month IN ('improving','steady','degrading','volatile')),
  founder_verdict text NOT NULL CHECK (founder_verdict IN ('exemplary','acceptable','watchlist','intervene','terminate_engagement')),
  founder_note text NOT NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_recovery_pulse_r2874 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_recovery_pulse_r2874;
CREATE POLICY founder_all ON engineer_monthly_recovery_pulse_r2874
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_recovery_pulse_r2874
  (pulse_month, engineer_code, engineer_name, engineer_tier, failed_jobs_count, recovery_attempts,
   won_back_count, churned_count, total_winback_revenue_rupees, total_refund_paid_rupees,
   avg_csat_lift, median_recovery_hours, pulse_score, trend_vs_prev_month, founder_verdict, founder_note)
VALUES
  ('2026-06-01'::date, 'ENG-1101', 'Ravi Kumar', 'gold', 3, 3, 3, 0, 142000, 0, 2.30, 28, 88, 'improving', 'exemplary', 'Three recoveries, zero churn; promote to platinum candidate.'),
  ('2026-06-01'::date, 'ENG-1102', 'Sunita Reddy', 'silver', 5, 5, 3, 1, 38000, 4500, 1.10, 36, 64, 'steady', 'acceptable', 'Mixed; pair with senior for next two calibration jobs.'),
  ('2026-06-01'::date, 'ENG-1103', 'Imran Shaikh', 'bronze', 4, 3, 1, 2, 6000, 9500, 0.40, 52, 42, 'degrading', 'watchlist', 'SLA breaches recurring; mandatory training week-of 06-29.'),
  ('2026-06-01'::date, 'ENG-1104', 'Pooja Mehta', 'platinum', 2, 2, 2, 0, 175000, 0, 3.50, 22, 92, 'improving', 'exemplary', 'High-value saves; nominate for diamond Q3.'),
  ('2026-06-01'::date, 'ENG-1105', 'Karthik Nair', 'silver', 4, 4, 3, 0, 52000, 0, 1.40, 30, 71, 'steady', 'acceptable', 'Steady; encourage tier promotion through cert exam.'),
  ('2026-06-01'::date, 'ENG-1106', 'Deepika Iyer', 'gold', 3, 3, 3, 0, 68000, 0, 2.00, 24, 81, 'improving', 'exemplary', 'Vet vertical strong; explore solo lead role.'),
  ('2026-06-01'::date, 'ENG-1107', 'Anand Joshi', 'bronze', 6, 4, 1, 3, 12000, 18500, -0.50, 60, 18, 'degrading', 'intervene', 'Three churns this month; founder 1:1 + PIP this week.'),
  ('2026-06-01'::date, 'ENG-1108', 'Reema Banerjee', 'diamond', 2, 2, 2, 0, 215000, 0, 2.80, 14, 96, 'steady', 'exemplary', 'Flagship retainer; co-author playbook for new diamonds.');

-- =====================================================================
-- SECDEF RPCs (all founder-gated)
-- =====================================================================

-- RPC 1: KPI totals for the month
DROP FUNCTION IF EXISTS founder_r2874_recovery_kpis(date);
CREATE OR REPLACE FUNCTION founder_r2874_recovery_kpis(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  total_failed_jobs integer,
  total_won_back integer,
  total_churned integer,
  total_winback_revenue integer,
  total_refunds_paid integer,
  avg_pulse_score numeric,
  exemplary_engineers integer,
  intervene_engineers integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(failed_jobs_count),0)::int,
    COALESCE(SUM(won_back_count),0)::int,
    COALESCE(SUM(churned_count),0)::int,
    COALESCE(SUM(total_winback_revenue_rupees),0)::int,
    COALESCE(SUM(total_refund_paid_rupees),0)::int,
    COALESCE(ROUND(AVG(pulse_score)::numeric,2),0),
    COUNT(*) FILTER (WHERE founder_verdict='exemplary')::int,
    COUNT(*) FILTER (WHERE founder_verdict='intervene')::int
  FROM engineer_monthly_recovery_pulse_r2874
  WHERE pulse_month = p_month;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_recovery_kpis(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_recovery_kpis(date) TO authenticated;

-- RPC 2: Engineer pulse table
DROP FUNCTION IF EXISTS founder_r2874_engineer_pulse(date);
CREATE OR REPLACE FUNCTION founder_r2874_engineer_pulse(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  failed_jobs_count integer,
  won_back_count integer,
  churned_count integer,
  total_winback_revenue_rupees integer,
  pulse_score integer,
  trend_vs_prev_month text,
  founder_verdict text,
  founder_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.engineer_code, p.engineer_name, p.engineer_tier, p.failed_jobs_count,
         p.won_back_count, p.churned_count, p.total_winback_revenue_rupees,
         p.pulse_score, p.trend_vs_prev_month, p.founder_verdict, p.founder_note
  FROM engineer_monthly_recovery_pulse_r2874 p
  WHERE p.pulse_month = p_month
  ORDER BY p.pulse_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_engineer_pulse(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_engineer_pulse(date) TO authenticated;

-- RPC 3: Recovery narratives stream
DROP FUNCTION IF EXISTS founder_r2874_recovery_narratives(date);
CREATE OR REPLACE FUNCTION founder_r2874_recovery_narratives(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  failed_job_code text,
  engineer_code text,
  engineer_name text,
  customer_name text,
  customer_segment text,
  failure_root_cause text,
  failure_severity text,
  recovery_action text,
  recovery_outcome text,
  winback_revenue_rupees integer,
  pulse_score integer,
  founder_verdict text,
  narrative_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.failed_job_code, n.engineer_code, n.engineer_name, n.customer_name, n.customer_segment,
         n.failure_root_cause, n.failure_severity, n.recovery_action, n.recovery_outcome,
         n.winback_revenue_rupees, n.pulse_score, n.founder_verdict, n.narrative_summary
  FROM engineer_monthly_recovery_narratives_r2874 n
  WHERE n.narrative_month = p_month
  ORDER BY n.pulse_score DESC, n.winback_revenue_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_recovery_narratives(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_recovery_narratives(date) TO authenticated;

-- RPC 4: Root-cause breakdown
DROP FUNCTION IF EXISTS founder_r2874_root_cause_mix(date);
CREATE OR REPLACE FUNCTION founder_r2874_root_cause_mix(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  failure_root_cause text,
  failures integer,
  won_back integer,
  churned integer,
  winback_revenue_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.failure_root_cause,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE n.recovery_outcome='won_back')::int,
         COUNT(*) FILTER (WHERE n.recovery_outcome='churned')::int,
         COALESCE(SUM(n.winback_revenue_rupees),0)::int
  FROM engineer_monthly_recovery_narratives_r2874 n
  WHERE n.narrative_month = p_month
  GROUP BY n.failure_root_cause
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_root_cause_mix(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_root_cause_mix(date) TO authenticated;

-- RPC 5: Customer segment outcomes
DROP FUNCTION IF EXISTS founder_r2874_segment_outcomes(date);
CREATE OR REPLACE FUNCTION founder_r2874_segment_outcomes(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  customer_segment text,
  failures integer,
  won_back integer,
  at_risk integer,
  churned integer,
  winback_revenue_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.customer_segment,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE n.recovery_outcome='won_back')::int,
         COUNT(*) FILTER (WHERE n.recovery_outcome='at_risk')::int,
         COUNT(*) FILTER (WHERE n.recovery_outcome='churned')::int,
         COALESCE(SUM(n.winback_revenue_rupees),0)::int
  FROM engineer_monthly_recovery_narratives_r2874 n
  WHERE n.narrative_month = p_month
  GROUP BY n.customer_segment
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_segment_outcomes(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_segment_outcomes(date) TO authenticated;

-- RPC 6: Watchlist + intervene engineers
DROP FUNCTION IF EXISTS founder_r2874_watchlist(date);
CREATE OR REPLACE FUNCTION founder_r2874_watchlist(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  pulse_score integer,
  failed_jobs_count integer,
  churned_count integer,
  founder_verdict text,
  founder_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.engineer_code, p.engineer_name, p.engineer_tier, p.pulse_score,
         p.failed_jobs_count, p.churned_count, p.founder_verdict, p.founder_note
  FROM engineer_monthly_recovery_pulse_r2874 p
  WHERE p.pulse_month = p_month
    AND p.founder_verdict IN ('watchlist','intervene','terminate_engagement')
  ORDER BY p.pulse_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_watchlist(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_watchlist(date) TO authenticated;

-- RPC 7: Top winback stories (exemplary)
DROP FUNCTION IF EXISTS founder_r2874_top_winbacks(date, integer);
CREATE OR REPLACE FUNCTION founder_r2874_top_winbacks(p_month date DEFAULT '2026-06-01'::date, p_limit integer DEFAULT 5)
RETURNS TABLE(
  failed_job_code text,
  engineer_name text,
  customer_name text,
  recovery_action text,
  winback_revenue_rupees integer,
  pulse_score integer,
  narrative_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.failed_job_code, n.engineer_name, n.customer_name, n.recovery_action,
         n.winback_revenue_rupees, n.pulse_score, n.narrative_summary
  FROM engineer_monthly_recovery_narratives_r2874 n
  WHERE n.narrative_month = p_month
    AND n.recovery_outcome = 'won_back'
  ORDER BY n.winback_revenue_rupees DESC, n.pulse_score DESC
  LIMIT GREATEST(p_limit,1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_top_winbacks(date, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_top_winbacks(date, integer) TO authenticated;

-- RPC 8: Founder verdict mix
DROP FUNCTION IF EXISTS founder_r2874_verdict_mix(date);
CREATE OR REPLACE FUNCTION founder_r2874_verdict_mix(p_month date DEFAULT '2026-06-01'::date)
RETURNS TABLE(
  founder_verdict text,
  engineers integer,
  avg_pulse numeric,
  total_winback_revenue integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.founder_verdict,
         COUNT(*)::int,
         COALESCE(ROUND(AVG(p.pulse_score)::numeric,2),0),
         COALESCE(SUM(p.total_winback_revenue_rupees),0)::int
  FROM engineer_monthly_recovery_pulse_r2874 p
  WHERE p.pulse_month = p_month
  GROUP BY p.founder_verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2874_verdict_mix(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2874_verdict_mix(date) TO authenticated;

COMMIT;
