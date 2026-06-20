BEGIN;
-- r1425 founder_hospital_maintenance_calendar_generator
-- 1 table + 7 RPCs. Auto-generates maintenance schedule rows from active AMCs.



-- ============================================================================
-- TABLE: founder_hospital_maintenance_schedule
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_maintenance_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  equipment_label text NOT NULL DEFAULT 'AMC equipment',
  scheduled_date date NOT NULL,
  visit_kind text NOT NULL DEFAULT 'preventive'
    CHECK (visit_kind IN ('preventive','calibration','firmware','annual_pm','warranty_check','followup')),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','assigned','in_progress','completed','rescheduled','cancelled')),
  assigned_engineer_id uuid REFERENCES public.engineers(id),
  completed_repair_job_id uuid,
  expected_minutes int NOT NULL DEFAULT 60,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (amc_contract_id, scheduled_date, equipment_label)
);

CREATE INDEX IF NOT EXISTS idx_fhms_scheduled_date
  ON public.founder_hospital_maintenance_schedule(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_fhms_status
  ON public.founder_hospital_maintenance_schedule(status);
CREATE INDEX IF NOT EXISTS idx_fhms_amc_contract
  ON public.founder_hospital_maintenance_schedule(amc_contract_id);
CREATE INDEX IF NOT EXISTS idx_fhms_engineer
  ON public.founder_hospital_maintenance_schedule(assigned_engineer_id)
  WHERE assigned_engineer_id IS NOT NULL;

ALTER TABLE public.founder_hospital_maintenance_schedule ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhms_founder_all ON public.founder_hospital_maintenance_schedule;
CREATE POLICY fhms_founder_all ON public.founder_hospital_maintenance_schedule
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

GRANT SELECT ON public.founder_hospital_maintenance_schedule TO authenticated;

-- ============================================================================
-- RPC 1: founder_hospital_maintenance_calendar_summary (16 KPIs)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_maintenance_calendar_summary();
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_summary()
RETURNS TABLE (
  total_rows bigint,
  scheduled_count bigint,
  assigned_count bigint,
  in_progress_count bigint,
  completed_count bigint,
  rescheduled_count bigint,
  cancelled_count bigint,
  overdue_count bigint,
  due_next_7d bigint,
  due_next_30d bigint,
  due_next_90d bigint,
  preventive_count bigint,
  calibration_count bigint,
  active_amcs_covered bigint,
  avg_expected_minutes numeric,
  total_expected_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    count(*)::bigint AS total_rows,
    count(*) FILTER (WHERE s.status = 'scheduled')::bigint,
    count(*) FILTER (WHERE s.status = 'assigned')::bigint,
    count(*) FILTER (WHERE s.status = 'in_progress')::bigint,
    count(*) FILTER (WHERE s.status = 'completed')::bigint,
    count(*) FILTER (WHERE s.status = 'rescheduled')::bigint,
    count(*) FILTER (WHERE s.status = 'cancelled')::bigint,
    count(*) FILTER (WHERE s.scheduled_date < current_date
                     AND s.status IN ('scheduled','assigned'))::bigint,
    count(*) FILTER (WHERE s.scheduled_date BETWEEN current_date AND current_date + 7
                     AND s.status IN ('scheduled','assigned'))::bigint,
    count(*) FILTER (WHERE s.scheduled_date BETWEEN current_date AND current_date + 30
                     AND s.status IN ('scheduled','assigned'))::bigint,
    count(*) FILTER (WHERE s.scheduled_date BETWEEN current_date AND current_date + 90
                     AND s.status IN ('scheduled','assigned'))::bigint,
    count(*) FILTER (WHERE s.visit_kind = 'preventive')::bigint,
    count(*) FILTER (WHERE s.visit_kind = 'calibration')::bigint,
    count(DISTINCT s.amc_contract_id)::bigint,
    coalesce(avg(s.expected_minutes), 0)::numeric AS avg_expected_minutes,
    coalesce(sum(s.expected_minutes) / 60.0, 0)::numeric AS total_expected_hours
  FROM public.founder_hospital_maintenance_schedule s;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_maintenance_calendar_summary() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_maintenance_calendar_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_hospital_maintenance_calendar_recent (100 rows)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_maintenance_calendar_recent();
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_recent()
RETURNS TABLE (
  id uuid,
  amc_contract_id uuid,
  equipment_label text,
  scheduled_date date,
  visit_kind text,
  status text,
  expected_minutes int,
  assigned_engineer_id uuid,
  amc_tier text,
  hospital_name text,
  days_until int,
  is_overdue boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.amc_contract_id,
    s.equipment_label,
    s.scheduled_date,
    s.visit_kind,
    s.status,
    s.expected_minutes,
    s.assigned_engineer_id,
    a.amc_tier::text,
    coalesce(o.name, p.full_name, 'Unknown') AS hospital_name,
    (s.scheduled_date - current_date)::int AS days_until,
    (s.scheduled_date < current_date AND s.status IN ('scheduled','assigned')) AS is_overdue,
    s.created_at
  FROM public.founder_hospital_maintenance_schedule s
  LEFT JOIN public.amc_contracts a ON a.id = s.amc_contract_id
  LEFT JOIN public.profiles p ON p.user_id = a.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.scheduled_date ASC, s.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_maintenance_calendar_recent() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_maintenance_calendar_recent() TO authenticated;

-- ============================================================================
-- RPC 3: founder_hospital_maintenance_calendar_due_30d
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_maintenance_calendar_due_30d();
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_due_30d()
RETURNS TABLE (
  scheduled_date date,
  total bigint,
  preventive bigint,
  calibration bigint,
  assigned bigint,
  unassigned bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.scheduled_date,
    count(*)::bigint AS total,
    count(*) FILTER (WHERE s.visit_kind = 'preventive')::bigint AS preventive,
    count(*) FILTER (WHERE s.visit_kind = 'calibration')::bigint AS calibration,
    count(*) FILTER (WHERE s.status = 'assigned')::bigint AS assigned,
    count(*) FILTER (WHERE s.status = 'scheduled' AND s.assigned_engineer_id IS NULL)::bigint AS unassigned
  FROM public.founder_hospital_maintenance_schedule s
  WHERE s.scheduled_date BETWEEN current_date AND current_date + 30
    AND s.status IN ('scheduled','assigned')
  GROUP BY s.scheduled_date
  ORDER BY s.scheduled_date ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_maintenance_calendar_due_30d() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_maintenance_calendar_due_30d() TO authenticated;

-- ============================================================================
-- RPC 4: founder_hospital_maintenance_calendar_overdue
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_maintenance_calendar_overdue();
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_overdue()
RETURNS TABLE (
  id uuid,
  amc_contract_id uuid,
  equipment_label text,
  scheduled_date date,
  visit_kind text,
  status text,
  days_overdue int,
  hospital_name text,
  amc_tier text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.amc_contract_id,
    s.equipment_label,
    s.scheduled_date,
    s.visit_kind,
    s.status,
    (current_date - s.scheduled_date)::int AS days_overdue,
    coalesce(o.name, p.full_name, 'Unknown') AS hospital_name,
    a.amc_tier::text
  FROM public.founder_hospital_maintenance_schedule s
  LEFT JOIN public.amc_contracts a ON a.id = s.amc_contract_id
  LEFT JOIN public.profiles p ON p.user_id = a.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE s.scheduled_date < current_date
    AND s.status IN ('scheduled','assigned')
  ORDER BY s.scheduled_date ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_maintenance_calendar_overdue() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_maintenance_calendar_overdue() TO authenticated;

-- ============================================================================
-- RPC 5: founder_hospital_maintenance_calendar_generate_quarter
-- Cron-callable. Generates schedule rows for next 90d from active AMCs.
-- Visit frequency proxy = 1 per month per active AMC.
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_maintenance_calendar_generate_quarter();
CREATE OR REPLACE FUNCTION public.founder_hospital_maintenance_calendar_generate_quarter()
RETURNS TABLE (
  rows_inserted bigint,
  amcs_processed bigint,
  window_start date,
  window_end date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted bigint := 0;
  v_amcs bigint := 0;
  v_start date := current_date;
  v_end date := current_date + 90;
  v_contract record;
  v_month_offset int;
  v_target_date date;
BEGIN
  -- Allow founder OR pg_cron (no JWT). Inline check; do NOT call is_founder via cron.
  IF current_setting('request.jwt.claims', true) IS NOT NULL THEN
    IF NOT public.is_founder() THEN
      RAISE EXCEPTION 'forbidden';
    END IF;
  END IF;

  FOR v_contract IN
    SELECT id, start_date
    FROM public.amc_contracts
    WHERE status = 'active'
  LOOP
    v_amcs := v_amcs + 1;
    -- 3 visits across next 90d = 1 per month proxy
    FOR v_month_offset IN 0..2 LOOP
      v_target_date := v_start + (v_month_offset * 30);
      IF v_target_date <= v_end THEN
        INSERT INTO public.founder_hospital_maintenance_schedule (
          amc_contract_id, equipment_label, scheduled_date, visit_kind, status, expected_minutes
        ) VALUES (
          v_contract.id,
          'AMC equipment',
          v_target_date,
          'preventive',
          'scheduled',
          60
        )
        ON CONFLICT (amc_contract_id, scheduled_date, equipment_label) DO NOTHING;
        IF FOUND THEN
          v_inserted := v_inserted + 1;
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  RETURN QUERY SELECT v_inserted, v_amcs, v_start, v_end;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hospital_maintenance_calendar_generate_quarter() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_maintenance_calendar_generate_quarter() TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_maintenance_schedule_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_maintenance_schedule_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_maintenance_schedule_status(
  p_schedule_id uuid,
  p_new_status text,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_new_status NOT IN ('scheduled','assigned','in_progress','completed','rescheduled','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.founder_hospital_maintenance_schedule
  SET status = p_new_status,
      notes = coalesce(p_notes, notes),
      updated_at = now()
  WHERE id = p_schedule_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'schedule row not found';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_maintenance_schedule_status(uuid, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_maintenance_schedule_status(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_maintenance_assign_engineer
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_maintenance_assign_engineer(uuid, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_maintenance_assign_engineer(
  p_schedule_id uuid,
  p_engineer_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.engineers WHERE id = p_engineer_id) THEN
    RAISE EXCEPTION 'engineer not found';
  END IF;

  UPDATE public.founder_hospital_maintenance_schedule
  SET assigned_engineer_id = p_engineer_id,
      status = CASE WHEN status = 'scheduled' THEN 'assigned' ELSE status END,
      updated_at = now()
  WHERE id = p_schedule_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'schedule row not found';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_maintenance_assign_engineer(uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_maintenance_assign_engineer(uuid, uuid) TO authenticated;

COMMIT;