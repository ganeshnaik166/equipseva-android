BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_night_shift_logs_r2222 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  job_ref text NOT NULL,
  shift_started_at timestamptz NOT NULL,
  shift_ended_at timestamptz,
  shift_kind text NOT NULL CHECK (shift_kind IN ('night','weekend','holiday','double')),
  base_pay_rupees integer NOT NULL DEFAULT 0,
  premium_multiplier numeric(4,2) NOT NULL DEFAULT 1.50,
  premium_pay_rupees integer NOT NULL DEFAULT 0,
  hours_worked numeric(6,2) NOT NULL DEFAULT 0,
  location_city text,
  approval_status text NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected','paid')),
  approval_notes text,
  approved_by uuid REFERENCES public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_night_shift_reconciliation_r2222 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reconciliation_month date NOT NULL,
  total_shifts integer NOT NULL DEFAULT 0,
  total_premium_pay_rupees integer NOT NULL DEFAULT 0,
  total_hours numeric(8,2) NOT NULL DEFAULT 0,
  payout_status text NOT NULL DEFAULT 'draft' CHECK (payout_status IN ('draft','locked','disbursed','disputed')),
  locked_at timestamptz,
  disbursed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_night_shift_logs_r2222 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_night_shift_reconciliation_r2222 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_night_shift_logs_r2222;
CREATE POLICY founder_all ON public.engineer_night_shift_logs_r2222 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_night_shift_reconciliation_r2222;
CREATE POLICY founder_all ON public.engineer_night_shift_reconciliation_r2222 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_night_shift_logs_r2222(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  job_ref text,
  shift_started_at timestamptz,
  shift_ended_at timestamptz,
  shift_kind text,
  base_pay_rupees integer,
  premium_multiplier numeric,
  premium_pay_rupees integer,
  hours_worked numeric,
  location_city text,
  approval_status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.engineer_user_id, l.job_ref, l.shift_started_at, l.shift_ended_at,
         l.shift_kind, l.base_pay_rupees, l.premium_multiplier, l.premium_pay_rupees,
         l.hours_worked, l.location_city, l.approval_status, l.created_at
  FROM public.engineer_night_shift_logs_r2222 l
  ORDER BY l.shift_started_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_night_shift_r2222(p_limit int DEFAULT 50)
RETURNS TABLE (
  id bigint,
  actor_email text,
  op_name text,
  after_value jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.actor_email, a.op_name, a.after_value, a.created_at
  FROM public.founder_action_log a
  WHERE a.op_name LIKE 'op_r2222%'
  ORDER BY a.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;

CREATE OR REPLACE FUNCTION public.top_night_shift_earners_r2222(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  total_premium_pay_rupees bigint,
  shift_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.engineer_user_id,
         SUM(l.premium_pay_rupees)::bigint AS total_premium_pay_rupees,
         COUNT(*)::bigint AS shift_count
  FROM public.engineer_night_shift_logs_r2222 l
  WHERE l.approval_status IN ('approved','paid')
  GROUP BY l.engineer_user_id
  ORDER BY total_premium_pay_rupees DESC
  LIMIT COALESCE(p_limit, 20);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_night_shift_r2222(
  p_engineer_user_id uuid,
  p_job_ref text,
  p_shift_started_at timestamptz,
  p_shift_kind text,
  p_base_pay_rupees integer,
  p_premium_multiplier numeric,
  p_hours_worked numeric,
  p_location_city text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_premium integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_premium := ROUND(p_base_pay_rupees * (p_premium_multiplier - 1));
  INSERT INTO public.engineer_night_shift_logs_r2222(
    engineer_user_id, job_ref, shift_started_at, shift_kind,
    base_pay_rupees, premium_multiplier, premium_pay_rupees, hours_worked, location_city
  ) VALUES (
    p_engineer_user_id, p_job_ref, p_shift_started_at, p_shift_kind,
    p_base_pay_rupees, p_premium_multiplier, v_premium, p_hours_worked, p_location_city
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2222_log_shift',
    jsonb_build_object('shift_id', v_id, 'engineer', p_engineer_user_id, 'premium', v_premium));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_night_shift_r2222(
  p_op_name text,
  p_payload jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op_name, p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_night_shift_r2222(
  p_id uuid,
  p_status text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','approved','rejected','paid') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.engineer_night_shift_logs_r2222
  SET approval_status = p_status,
      approval_notes = COALESCE(p_notes, approval_notes),
      approved_by = auth.uid(),
      approved_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2222_mark_status',
    jsonb_build_object('shift_id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_night_shift_r2222()
RETURNS TABLE (
  total_shifts integer,
  pending_shifts integer,
  approved_shifts integer,
  paid_shifts integer,
  total_premium_pay_rupees bigint,
  total_hours numeric,
  weekend_shifts integer,
  night_shifts integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_shifts,
    (COUNT(*) FILTER (WHERE approval_status = 'pending'))::int AS pending_shifts,
    (COUNT(*) FILTER (WHERE approval_status = 'approved'))::int AS approved_shifts,
    (COUNT(*) FILTER (WHERE approval_status = 'paid'))::int AS paid_shifts,
    COALESCE(SUM(premium_pay_rupees), 0)::bigint AS total_premium_pay_rupees,
    COALESCE(SUM(hours_worked), 0)::numeric AS total_hours,
    (COUNT(*) FILTER (WHERE shift_kind = 'weekend'))::int AS weekend_shifts,
    (COUNT(*) FILTER (WHERE shift_kind = 'night'))::int AS night_shifts
  FROM public.engineer_night_shift_logs_r2222;
END;
$$;

REVOKE ALL ON FUNCTION public.list_night_shift_logs_r2222(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_night_shift_r2222(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_night_shift_earners_r2222(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_night_shift_r2222(uuid, text, timestamptz, text, integer, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_night_shift_r2222(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_night_shift_r2222(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_night_shift_r2222() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_night_shift_logs_r2222(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_night_shift_r2222(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_night_shift_earners_r2222(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_night_shift_r2222(uuid, text, timestamptz, text, integer, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_night_shift_r2222(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_night_shift_r2222(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_night_shift_r2222() TO authenticated;

COMMIT;
