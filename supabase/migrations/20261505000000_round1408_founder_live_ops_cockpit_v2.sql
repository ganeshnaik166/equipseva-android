BEGIN;
-- r1404 — founder_live_ops_cockpit_v2_heartbeat composite aggregator
-- 18 KPIs spanning action center + incidents + cron + DPDP + payouts + billing + calendar + AMC + engineers
-- Pure read-only · no new tables · founder-gated · plpgsql STABLE SECURITY DEFINER



DROP FUNCTION IF EXISTS public.founder_live_ops_cockpit_v2_heartbeat();

CREATE OR REPLACE FUNCTION public.founder_live_ops_cockpit_v2_heartbeat()
RETURNS TABLE (
  open_priority_actions integer,
  open_incidents integer,
  code_red_open integer,
  cron_failure_rate_24h numeric,
  dpdp_grievances_open integer,
  payouts_queued integer,
  billing_invoiced_30d_rupees bigint,
  billing_outstanding_rupees bigint,
  calendar_overdue_count integer,
  calendar_due_30d integer,
  total_active_amcs integer,
  total_active_engineers integer,
  generated_at timestamptz,
  last_morning_pulse_at timestamptz,
  hospitals_at_risk_count integer,
  system_health_score integer,
  most_recent_critical_event_at timestamptz,
  alerts_red_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_open_priority integer := 0;
  v_open_incidents integer := 0;
  v_code_red integer := 0;
  v_cron_fail numeric := 0;
  v_dpdp integer := 0;
  v_payouts integer := 0;
  v_billed bigint := 0;
  v_outstanding bigint := 0;
  v_overdue integer := 0;
  v_due_30 integer := 0;
  v_amcs integer := 0;
  v_engineers integer := 0;
  v_pulse_at timestamptz;
  v_risk integer := 0;
  v_health integer := 100;
  v_critical_at timestamptz;
  v_alerts_red integer := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  -- 1. Open priority actions
  BEGIN
    SELECT COUNT(*) INTO v_open_priority
      FROM public.founder_priority_actions
      WHERE action_taken IS NULL;
  EXCEPTION WHEN OTHERS THEN v_open_priority := 0; END;

  -- 2. Open incidents (last 30d, not resolved)
  BEGIN
    SELECT COUNT(*) INTO v_open_incidents
      FROM public.founder_incidents
      WHERE resolved_at IS NULL
        AND created_at >= now() - interval '30 days';
  EXCEPTION WHEN OTHERS THEN v_open_incidents := 0; END;

  -- 3. Code red open
  BEGIN
    SELECT COUNT(*) INTO v_code_red
      FROM public.code_red_requests
      WHERE status IN ('open','escalated','dispatched');
  EXCEPTION WHEN OTHERS THEN v_code_red := 0; END;

  -- 4. Cron failure rate 24h
  BEGIN
    SELECT COALESCE(
      ROUND(
        100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)::numeric
             / NULLIF(COUNT(*),0)::numeric,
      2), 0)
    INTO v_cron_fail
    FROM cron.job_run_details
    WHERE start_time >= now() - interval '24 hours';
  EXCEPTION WHEN OTHERS THEN v_cron_fail := 0; END;

  -- 5. DPDP grievances open
  BEGIN
    SELECT COUNT(*) INTO v_dpdp
      FROM public.dpdp_grievances
      WHERE status IN ('open','assigned','in_progress');
  EXCEPTION WHEN OTHERS THEN v_dpdp := 0; END;

  -- 6. Payouts queued
  BEGIN
    SELECT COUNT(*) INTO v_payouts
      FROM public.engineer_payouts
      WHERE status IN ('queued','processing');
  EXCEPTION WHEN OTHERS THEN v_payouts := 0; END;

  -- 7. Billing invoiced 30d
  BEGIN
    SELECT COALESCE(SUM(amount_rupees),0)::bigint INTO v_billed
      FROM public.payments
      WHERE created_at >= now() - interval '30 days'
        AND status IN ('succeeded','captured','paid');
  EXCEPTION WHEN OTHERS THEN v_billed := 0; END;

  -- 8. Billing outstanding (pending/failed unsettled)
  BEGIN
    SELECT COALESCE(SUM(amount_rupees),0)::bigint INTO v_outstanding
      FROM public.payments
      WHERE created_at >= now() - interval '60 days'
        AND status IN ('pending','failed','requires_action');
  EXCEPTION WHEN OTHERS THEN v_outstanding := 0; END;

  -- 9. Calendar overdue (maintenance jobs past due, not completed)
  BEGIN
    SELECT COUNT(*) INTO v_overdue
      FROM public.repair_jobs
      WHERE kind = 'maintenance'
        AND completed_at IS NULL
        AND scheduled_at < now();
  EXCEPTION WHEN OTHERS THEN v_overdue := 0; END;

  -- 10. Calendar due in next 30d
  BEGIN
    SELECT COUNT(*) INTO v_due_30
      FROM public.repair_jobs
      WHERE kind = 'maintenance'
        AND completed_at IS NULL
        AND scheduled_at BETWEEN now() AND now() + interval '30 days';
  EXCEPTION WHEN OTHERS THEN v_due_30 := 0; END;

  -- 11. Total active AMCs
  BEGIN
    SELECT COUNT(*) INTO v_amcs
      FROM public.amc_contracts
      WHERE status = 'active';
  EXCEPTION WHEN OTHERS THEN v_amcs := 0; END;

  -- 12. Total active engineers
  BEGIN
    SELECT COUNT(*) INTO v_engineers
      FROM public.engineers
      WHERE is_active = true;
  EXCEPTION WHEN OTHERS THEN v_engineers := 0; END;

  -- 13. Last morning pulse run (cron timestamp)
  BEGIN
    SELECT MAX(start_time) INTO v_pulse_at
      FROM cron.job_run_details d
      JOIN cron.job j ON j.jobid = d.jobid
      WHERE j.jobname ILIKE '%morning%pulse%';
  EXCEPTION WHEN OTHERS THEN v_pulse_at := NULL; END;

  -- 14. Hospitals at risk proxy (open incidents + open disputes)
  BEGIN
    SELECT COALESCE(
      (SELECT COUNT(DISTINCT hospital_org_id)
         FROM public.founder_incidents
         WHERE resolved_at IS NULL),
      0
    ) + COALESCE(
      (SELECT COUNT(DISTINCT hospital_org_id)
         FROM public.disputes
         WHERE status IN ('open','escalated')),
      0
    ) INTO v_risk;
  EXCEPTION WHEN OTHERS THEN v_risk := 0; END;

  -- 15. Most recent critical event (incident severity = high)
  BEGIN
    SELECT MAX(created_at) INTO v_critical_at
      FROM public.founder_incidents
      WHERE severity IN ('high','critical')
        AND created_at >= now() - interval '7 days';
  EXCEPTION WHEN OTHERS THEN v_critical_at := NULL; END;

  -- 16. Red alerts: cron fail >10% OR code-red >5 OR payouts queued >20 OR overdue >10
  v_alerts_red := 0;
  IF v_cron_fail > 10 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_code_red > 5 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_payouts > 20 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_overdue > 10 THEN v_alerts_red := v_alerts_red + 1; END IF;
  IF v_dpdp > 3 THEN v_alerts_red := v_alerts_red + 1; END IF;

  -- 17. System health 0..100 (subtract per red flag class)
  v_health := 100
    - LEAST(40, (v_cron_fail * 2)::integer)
    - LEAST(15, v_code_red * 3)
    - LEAST(15, v_open_incidents)
    - LEAST(10, v_dpdp * 3)
    - LEAST(10, v_overdue)
    - LEAST(10, v_alerts_red * 5);
  IF v_health < 0 THEN v_health := 0; END IF;

  RETURN QUERY SELECT
    v_open_priority,
    v_open_incidents,
    v_code_red,
    v_cron_fail,
    v_dpdp,
    v_payouts,
    v_billed,
    v_outstanding,
    v_overdue,
    v_due_30,
    v_amcs,
    v_engineers,
    now() AS generated_at,
    v_pulse_at,
    v_risk,
    v_health,
    v_critical_at,
    v_alerts_red;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_live_ops_cockpit_v2_heartbeat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_live_ops_cockpit_v2_heartbeat() TO authenticated;

COMMIT;