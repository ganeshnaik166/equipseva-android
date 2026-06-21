BEGIN;

-- ============================================================================
-- Round 1711 — Hospital Replacement Equipment Loaners
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_loaner_dispatches_r1711 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  dispatched_at timestamptz NOT NULL DEFAULT now(),
  returned_at timestamptz,
  return_condition text CHECK (return_condition IN ('pristine','minor_wear','damaged','lost')),
  billable_per_day_rupees int NOT NULL DEFAULT 0,
  total_billed_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','returned','billed','written_off')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loaner_dispatch_r1711_hospital ON public.hospital_loaner_dispatches_r1711(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_loaner_dispatch_r1711_status ON public.hospital_loaner_dispatches_r1711(status);
CREATE INDEX IF NOT EXISTS idx_loaner_dispatch_r1711_dispatched ON public.hospital_loaner_dispatches_r1711(dispatched_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_loaner_billing_actions_r1711 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispatch_id uuid NOT NULL REFERENCES public.hospital_loaner_dispatches_r1711(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('generate_invoice','waive','escalate','recover')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loaner_billing_r1711_dispatch ON public.hospital_loaner_billing_actions_r1711(dispatch_id);
CREATE INDEX IF NOT EXISTS idx_loaner_billing_r1711_taken ON public.hospital_loaner_billing_actions_r1711(taken_at DESC);

ALTER TABLE public.hospital_loaner_dispatches_r1711 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_loaner_billing_actions_r1711 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_loaner_dispatch_r1711 ON public.hospital_loaner_dispatches_r1711;
CREATE POLICY founder_all_loaner_dispatch_r1711 ON public.hospital_loaner_dispatches_r1711
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_loaner_billing_r1711 ON public.hospital_loaner_billing_actions_r1711;
CREATE POLICY founder_all_loaner_billing_r1711 ON public.hospital_loaner_billing_actions_r1711
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_dispatches
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_loaner_dispatches_r1711();
CREATE OR REPLACE FUNCTION public.list_loaner_dispatches_r1711()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  dispatched_at timestamptz,
  returned_at timestamptz,
  return_condition text,
  billable_per_day_rupees int,
  total_billed_rupees int,
  status text,
  days_out int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.hospital_user_id,
    p.email::text,
    d.equipment_name,
    d.dispatched_at,
    d.returned_at,
    d.return_condition,
    d.billable_per_day_rupees,
    d.total_billed_rupees,
    d.status,
    GREATEST(0, EXTRACT(DAY FROM (COALESCE(d.returned_at, now()) - d.dispatched_at))::int) AS days_out
  FROM public.hospital_loaner_dispatches_r1711 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY d.dispatched_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loaner_dispatches_r1711() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loaner_dispatches_r1711() TO authenticated;

-- ============================================================================
-- RPC 2: dispatch_loaner
-- ============================================================================
DROP FUNCTION IF EXISTS public.dispatch_loaner_r1711(uuid, text, int);
CREATE OR REPLACE FUNCTION public.dispatch_loaner_r1711(
  p_hospital_user_id uuid,
  p_equipment_name text,
  p_billable_per_day_rupees int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_loaner_dispatches_r1711(
    hospital_user_id, equipment_name, billable_per_day_rupees, status
  ) VALUES (
    p_hospital_user_id, p_equipment_name, COALESCE(p_billable_per_day_rupees, 0), 'active'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'dispatch_loaner_r1711',
    jsonb_build_object(
      'dispatch_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'equipment_name', p_equipment_name,
      'billable_per_day_rupees', p_billable_per_day_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dispatch_loaner_r1711(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_loaner_r1711(uuid, text, int) TO authenticated;

-- ============================================================================
-- RPC 3: return_loaner
-- ============================================================================
DROP FUNCTION IF EXISTS public.return_loaner_r1711(uuid, text);
CREATE OR REPLACE FUNCTION public.return_loaner_r1711(
  p_dispatch_id uuid,
  p_return_condition text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int;
  v_rate int;
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_return_condition NOT IN ('pristine','minor_wear','damaged','lost') THEN
    RAISE EXCEPTION 'invalid_condition';
  END IF;

  SELECT
    GREATEST(0, EXTRACT(DAY FROM (now() - dispatched_at))::int),
    billable_per_day_rupees
  INTO v_days, v_rate
  FROM public.hospital_loaner_dispatches_r1711
  WHERE id = p_dispatch_id;

  v_total := COALESCE(v_days, 0) * COALESCE(v_rate, 0);

  UPDATE public.hospital_loaner_dispatches_r1711
  SET
    returned_at = now(),
    return_condition = p_return_condition,
    total_billed_rupees = v_total,
    status = 'returned',
    updated_at = now()
  WHERE id = p_dispatch_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'return_loaner_r1711',
    jsonb_build_object(
      'dispatch_id', p_dispatch_id,
      'return_condition', p_return_condition,
      'total_billed_rupees', v_total
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.return_loaner_r1711(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.return_loaner_r1711(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 4: list_billing
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_loaner_billing_r1711();
CREATE OR REPLACE FUNCTION public.list_loaner_billing_r1711()
RETURNS TABLE(
  id uuid,
  dispatch_id uuid,
  equipment_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.id,
    b.dispatch_id,
    d.equipment_name,
    b.action_type,
    b.taken_at,
    b.by_email,
    b.note
  FROM public.hospital_loaner_billing_actions_r1711 b
  LEFT JOIN public.hospital_loaner_dispatches_r1711 d ON d.id = b.dispatch_id
  ORDER BY b.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loaner_billing_r1711() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loaner_billing_r1711() TO authenticated;

-- ============================================================================
-- RPC 5: log_billing
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_loaner_billing_r1711(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_loaner_billing_r1711(
  p_dispatch_id uuid,
  p_action_type text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_action_type NOT IN ('generate_invoice','waive','escalate','recover') THEN
    RAISE EXCEPTION 'invalid_action_type';
  END IF;

  v_email := (auth.jwt() ->> 'email');

  INSERT INTO public.hospital_loaner_billing_actions_r1711(
    dispatch_id, action_type, by_email, note
  ) VALUES (
    p_dispatch_id, p_action_type, v_email, p_note
  )
  RETURNING id INTO v_id;

  IF p_action_type = 'generate_invoice' THEN
    UPDATE public.hospital_loaner_dispatches_r1711
    SET status = 'billed', updated_at = now()
    WHERE id = p_dispatch_id AND status IN ('active','returned');
  ELSIF p_action_type = 'waive' THEN
    UPDATE public.hospital_loaner_dispatches_r1711
    SET status = 'written_off', updated_at = now()
    WHERE id = p_dispatch_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_loaner_billing_r1711',
    jsonb_build_object(
      'billing_id', v_id,
      'dispatch_id', p_dispatch_id,
      'action_type', p_action_type,
      'note', p_note
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_loaner_billing_r1711(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_loaner_billing_r1711(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 6: active_loaners_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.active_loaners_summary_r1711();
CREATE OR REPLACE FUNCTION public.active_loaners_summary_r1711()
RETURNS TABLE(
  total_active int,
  total_returned int,
  total_billed int,
  total_written_off int,
  total_billed_rupees_sum bigint,
  active_potential_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'active'))::int,
    (COUNT(*) FILTER (WHERE status = 'returned'))::int,
    (COUNT(*) FILTER (WHERE status = 'billed'))::int,
    (COUNT(*) FILTER (WHERE status = 'written_off'))::int,
    COALESCE(SUM(total_billed_rupees) FILTER (WHERE status IN ('billed','returned')), 0)::bigint,
    COALESCE(SUM(
      billable_per_day_rupees *
      GREATEST(0, EXTRACT(DAY FROM (now() - dispatched_at))::int)
    ) FILTER (WHERE status = 'active'), 0)::bigint
  FROM public.hospital_loaner_dispatches_r1711;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.active_loaners_summary_r1711() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_loaners_summary_r1711() TO authenticated;

-- ============================================================================
-- RPC 7: overdue_loaners (active > 14 days)
-- ============================================================================
DROP FUNCTION IF EXISTS public.overdue_loaners_r1711();
CREATE OR REPLACE FUNCTION public.overdue_loaners_r1711()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  dispatched_at timestamptz,
  days_out int,
  billable_per_day_rupees int,
  accrued_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.hospital_user_id,
    p.email::text,
    d.equipment_name,
    d.dispatched_at,
    EXTRACT(DAY FROM (now() - d.dispatched_at))::int AS days_out,
    d.billable_per_day_rupees,
    (d.billable_per_day_rupees * EXTRACT(DAY FROM (now() - d.dispatched_at))::int)::int AS accrued_rupees
  FROM public.hospital_loaner_dispatches_r1711 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  WHERE d.status = 'active'
    AND d.dispatched_at < now() - interval '14 days'
  ORDER BY d.dispatched_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.overdue_loaners_r1711() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_loaners_r1711() TO authenticated;

COMMIT;