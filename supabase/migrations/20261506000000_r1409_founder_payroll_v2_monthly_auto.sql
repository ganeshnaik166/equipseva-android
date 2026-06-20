BEGIN;
-- r1409 — Founder Payroll v2: Monthly Auto-Disburse Scheduler
-- Extends r1325 (founder_payroll_batches) with cron-driven schedules,
-- per-engineer cadence (weekly/biweekly/monthly/quarterly/custom),
-- next-run forecasting, and a cron-callable kickoff RPC.



-- ============================================================================
-- TABLE: founder_payroll_v2_schedules
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_payroll_v2_schedules (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_label           text NOT NULL UNIQUE,
  frequency                text NOT NULL CHECK (frequency IN ('weekly','biweekly','monthly','quarterly','custom')),
  day_of_period            int  NOT NULL CHECK (day_of_period BETWEEN 1 AND 28),
  next_run_at              timestamptz NOT NULL,
  last_run_at              timestamptz,
  last_run_outcome         text CHECK (last_run_outcome IN ('pending','running','success','partial','failed','skipped')),
  last_run_batch_count     int,
  last_run_amount_rupees   numeric,
  is_active                boolean NOT NULL DEFAULT true,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pv2_sched_next_run
  ON public.founder_payroll_v2_schedules (next_run_at)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_pv2_sched_active
  ON public.founder_payroll_v2_schedules (is_active, frequency);

ALTER TABLE public.founder_payroll_v2_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pv2_sched_founder_all ON public.founder_payroll_v2_schedules;
CREATE POLICY pv2_sched_founder_all
  ON public.founder_payroll_v2_schedules
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_payroll_v2_monthly_summary — 14 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payroll_v2_monthly_summary();
CREATE OR REPLACE FUNCTION public.founder_payroll_v2_monthly_summary()
RETURNS TABLE (
  active_schedules            bigint,
  paused_schedules            bigint,
  monthly_schedules           bigint,
  weekly_schedules            bigint,
  biweekly_schedules          bigint,
  quarterly_schedules         bigint,
  custom_schedules            bigint,
  next_run_within_24h         bigint,
  next_run_within_7d          bigint,
  last_30d_success_runs       bigint,
  last_30d_failed_runs        bigint,
  last_30d_partial_runs       bigint,
  last_30d_total_disbursed    numeric,
  last_30d_total_batches      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE NOT is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE frequency='monthly' AND is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE frequency='weekly' AND is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE frequency='biweekly' AND is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE frequency='quarterly' AND is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE frequency='custom' AND is_active),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE is_active AND next_run_at <= now() + interval '24 hours'),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE is_active AND next_run_at <= now() + interval '7 days'),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE last_run_outcome='success' AND last_run_at >= now() - interval '30 days'),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE last_run_outcome='failed'  AND last_run_at >= now() - interval '30 days'),
    (SELECT count(*) FROM public.founder_payroll_v2_schedules WHERE last_run_outcome='partial' AND last_run_at >= now() - interval '30 days'),
    COALESCE((SELECT sum(last_run_amount_rupees) FROM public.founder_payroll_v2_schedules WHERE last_run_at >= now() - interval '30 days'), 0)::numeric,
    COALESCE((SELECT sum(last_run_batch_count)    FROM public.founder_payroll_v2_schedules WHERE last_run_at >= now() - interval '30 days'), 0)::bigint;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_payroll_v2_monthly_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_payroll_v2_monthly_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_payroll_v2_schedules_recent — last 20 schedule rows
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payroll_v2_schedules_recent();
CREATE OR REPLACE FUNCTION public.founder_payroll_v2_schedules_recent()
RETURNS TABLE (
  id                       uuid,
  schedule_label           text,
  frequency                text,
  day_of_period            int,
  next_run_at              timestamptz,
  last_run_at              timestamptz,
  last_run_outcome         text,
  last_run_batch_count     int,
  last_run_amount_rupees   numeric,
  is_active                boolean,
  notes                    text,
  created_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT s.id, s.schedule_label, s.frequency, s.day_of_period, s.next_run_at,
         s.last_run_at, s.last_run_outcome, s.last_run_batch_count,
         s.last_run_amount_rupees, s.is_active, s.notes, s.created_at
  FROM public.founder_payroll_v2_schedules s
  ORDER BY s.next_run_at ASC NULLS LAST, s.created_at DESC
  LIMIT 20;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_payroll_v2_schedules_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_payroll_v2_schedules_recent() TO authenticated;

-- ============================================================================
-- RPC 3: founder_payroll_v2_next_runs — upcoming N runs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payroll_v2_next_runs();
CREATE OR REPLACE FUNCTION public.founder_payroll_v2_next_runs()
RETURNS TABLE (
  schedule_label   text,
  frequency        text,
  next_run_at      timestamptz,
  hours_until_run  numeric,
  is_active        boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT s.schedule_label,
         s.frequency,
         s.next_run_at,
         ROUND(EXTRACT(EPOCH FROM (s.next_run_at - now()))::numeric / 3600.0, 1) AS hours_until_run,
         s.is_active
  FROM public.founder_payroll_v2_schedules s
  WHERE s.is_active = true AND s.next_run_at >= now()
  ORDER BY s.next_run_at ASC
  LIMIT 10;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_payroll_v2_next_runs() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_payroll_v2_next_runs() TO authenticated;

-- ============================================================================
-- RPC 4: payroll_v2_kickoff_scheduled_run — CRON-CALLABLE (no is_founder gate)
-- ============================================================================
DROP FUNCTION IF EXISTS public.payroll_v2_kickoff_scheduled_run();
CREATE OR REPLACE FUNCTION public.payroll_v2_kickoff_scheduled_run()
RETURNS TABLE (
  schedule_id      uuid,
  schedule_label   text,
  outcome          text,
  next_run_at      timestamptz
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  s record;
  v_next timestamptz;
BEGIN
  -- Cron-callable. No is_founder gate (pg_cron has no JWT).
  FOR s IN
    SELECT * FROM public.founder_payroll_v2_schedules
    WHERE is_active = true AND next_run_at <= now()
    ORDER BY next_run_at ASC
  LOOP
    -- Forecast next_run_at by frequency
    v_next := CASE s.frequency
                WHEN 'weekly'    THEN s.next_run_at + interval '7 days'
                WHEN 'biweekly'  THEN s.next_run_at + interval '14 days'
                WHEN 'monthly'   THEN s.next_run_at + interval '1 month'
                WHEN 'quarterly' THEN s.next_run_at + interval '3 months'
                ELSE s.next_run_at + interval '30 days'
              END;

    UPDATE public.founder_payroll_v2_schedules
       SET last_run_at      = now(),
           last_run_outcome = 'pending',
           next_run_at      = v_next,
           updated_at       = now()
     WHERE id = s.id;

    RETURN QUERY SELECT s.id, s.schedule_label, 'pending'::text, v_next;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.payroll_v2_kickoff_scheduled_run() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.payroll_v2_kickoff_scheduled_run() TO authenticated;

-- ============================================================================
-- RPC 5: log_founder_payroll_v2_register_schedule
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_payroll_v2_register_schedule(text, text, int, timestamptz, text);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_v2_register_schedule(
  p_label text,
  p_freq  text,
  p_day   int,
  p_next  timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_payroll_v2_schedules
    (schedule_label, frequency, day_of_period, next_run_at, notes)
  VALUES (p_label, p_freq, p_day, p_next, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_payroll_v2_register_schedule(text, text, int, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_payroll_v2_register_schedule(text, text, int, timestamptz, text) TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_payroll_v2_pause_schedule
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_payroll_v2_pause_schedule(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_v2_pause_schedule(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_payroll_v2_schedules
     SET is_active = false, updated_at = now()
   WHERE id = p_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_payroll_v2_pause_schedule(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_payroll_v2_pause_schedule(uuid) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_payroll_v2_run_history — record outcome after kickoff
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_payroll_v2_run_history(uuid, text, int, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_v2_run_history(
  p_id      uuid,
  p_outcome text,
  p_count   int,
  p_amount  numeric
)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_payroll_v2_schedules
     SET last_run_outcome       = p_outcome,
         last_run_batch_count   = p_count,
         last_run_amount_rupees = p_amount,
         updated_at             = now()
   WHERE id = p_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_payroll_v2_run_history(uuid, text, int, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_payroll_v2_run_history(uuid, text, int, numeric) TO authenticated;

COMMIT;