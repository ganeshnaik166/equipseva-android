BEGIN;
-- r1428 founder_engineer_leave_tracker

CREATE TABLE IF NOT EXISTS public.engineer_leave_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  casual_leave_total_days int NOT NULL DEFAULT 12,
  casual_leave_used_days int NOT NULL DEFAULT 0,
  sick_leave_total_days int NOT NULL DEFAULT 10,
  sick_leave_used_days int NOT NULL DEFAULT 0,
  paid_leave_total_days int NOT NULL DEFAULT 0,
  paid_leave_used_days int NOT NULL DEFAULT 0,
  period_year int NOT NULL DEFAULT (extract(year from now())::int),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_elb_engineer ON public.engineer_leave_balances(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_elb_period ON public.engineer_leave_balances(period_year DESC);

CREATE TABLE IF NOT EXISTS public.engineer_leave_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  leave_kind text NOT NULL CHECK (leave_kind IN ('casual','sick','paid','unpaid','maternity','paternity','bereavement','emergency')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  total_days numeric NOT NULL DEFAULT 0,
  reason text,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','approved','rejected','cancelled','expired')),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  founder_response text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_elr_engineer ON public.engineer_leave_requests(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_elr_status ON public.engineer_leave_requests(status);
CREATE INDEX IF NOT EXISTS idx_elr_submitted ON public.engineer_leave_requests(submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_elr_kind ON public.engineer_leave_requests(leave_kind);

ALTER TABLE public.engineer_leave_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_leave_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS elb_engineer_self ON public.engineer_leave_balances;
CREATE POLICY elb_engineer_self ON public.engineer_leave_balances
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS elb_founder_all ON public.engineer_leave_balances;
CREATE POLICY elb_founder_all ON public.engineer_leave_balances
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS elr_engineer_self ON public.engineer_leave_requests;
CREATE POLICY elr_engineer_self ON public.engineer_leave_requests
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS elr_engineer_insert ON public.engineer_leave_requests;
CREATE POLICY elr_engineer_insert ON public.engineer_leave_requests
  FOR INSERT TO authenticated
  WITH CHECK (engineer_user_id = auth.uid());

DROP POLICY IF EXISTS elr_founder_all ON public.engineer_leave_requests;
CREATE POLICY elr_founder_all ON public.engineer_leave_requests
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_engineer_leave_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_leave_summary()
RETURNS TABLE (
  total_requests bigint,
  submitted_requests bigint,
  approved_requests bigint,
  rejected_requests bigint,
  cancelled_requests bigint,
  expired_requests bigint,
  pending_review bigint,
  total_days_approved numeric,
  total_days_pending numeric,
  unique_engineers_with_requests bigint,
  engineers_currently_on_leave bigint,
  casual_kind_count bigint,
  sick_kind_count bigint,
  paid_kind_count bigint,
  unpaid_kind_count bigint,
  requests_last_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'submitted')::bigint,
    COUNT(*) FILTER (WHERE status = 'approved')::bigint,
    COUNT(*) FILTER (WHERE status = 'rejected')::bigint,
    COUNT(*) FILTER (WHERE status = 'cancelled')::bigint,
    COUNT(*) FILTER (WHERE status = 'expired')::bigint,
    COUNT(*) FILTER (WHERE status = 'submitted')::bigint,
    COALESCE(SUM(total_days) FILTER (WHERE status = 'approved'), 0)::numeric,
    COALESCE(SUM(total_days) FILTER (WHERE status = 'submitted'), 0)::numeric,
    COUNT(DISTINCT engineer_user_id)::bigint,
    COUNT(DISTINCT engineer_user_id) FILTER (
      WHERE status = 'approved' AND CURRENT_DATE BETWEEN start_date AND end_date
    )::bigint,
    COUNT(*) FILTER (WHERE leave_kind = 'casual')::bigint,
    COUNT(*) FILTER (WHERE leave_kind = 'sick')::bigint,
    COUNT(*) FILTER (WHERE leave_kind = 'paid')::bigint,
    COUNT(*) FILTER (WHERE leave_kind = 'unpaid')::bigint,
    COUNT(*) FILTER (WHERE submitted_at >= now() - interval '30 days')::bigint
  FROM public.engineer_leave_requests;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_leave_balances_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_leave_balances_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  casual_leave_total_days int,
  casual_leave_used_days int,
  sick_leave_total_days int,
  sick_leave_used_days int,
  paid_leave_total_days int,
  paid_leave_used_days int,
  period_year int,
  notes text,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, b.casual_leave_total_days, b.casual_leave_used_days,
    b.sick_leave_total_days, b.sick_leave_used_days, b.paid_leave_total_days, b.paid_leave_used_days,
    b.period_year, b.notes, b.updated_at
  FROM public.engineer_leave_balances b
  ORDER BY b.updated_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_balances_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_leave_requests_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_leave_requests_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  leave_kind text,
  start_date date,
  end_date date,
  total_days numeric,
  reason text,
  status text,
  approved_by uuid,
  approved_at timestamptz,
  founder_response text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.leave_kind, r.start_date, r.end_date,
    r.total_days, r.reason, r.status, r.approved_by, r.approved_at,
    r.founder_response, r.submitted_at
  FROM public.engineer_leave_requests r
  ORDER BY r.submitted_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_requests_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_leave_requests_pending();
CREATE OR REPLACE FUNCTION public.founder_engineer_leave_requests_pending()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  leave_kind text,
  start_date date,
  end_date date,
  total_days numeric,
  reason text,
  submitted_at timestamptz,
  days_waiting numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.leave_kind, r.start_date, r.end_date,
    r.total_days, r.reason, r.submitted_at,
    EXTRACT(EPOCH FROM (now() - r.submitted_at)) / 86400.0
  FROM public.engineer_leave_requests r
  WHERE r.status = 'submitted'
  ORDER BY r.submitted_at ASC
  LIMIT 100;
END;
$$;
GRANT EXECUTE ON FUNCTION public.founder_engineer_leave_requests_pending() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_leave_my_requests();
CREATE OR REPLACE FUNCTION public.engineer_leave_my_requests()
RETURNS TABLE (
  id uuid,
  leave_kind text,
  start_date date,
  end_date date,
  total_days numeric,
  status text,
  reason text,
  founder_response text,
  submitted_at timestamptz,
  approved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  RETURN QUERY
  SELECT r.id, r.leave_kind, r.start_date, r.end_date, r.total_days,
    r.status, r.reason, r.founder_response, r.submitted_at, r.approved_at
  FROM public.engineer_leave_requests r
  WHERE r.engineer_user_id = v_uid
  ORDER BY r.submitted_at DESC
  LIMIT 100;
END;
$$;
GRANT EXECUTE ON FUNCTION public.engineer_leave_my_requests() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_leave_submit_request(text, date, date, text);
CREATE OR REPLACE FUNCTION public.engineer_leave_submit_request(
  p_leave_kind text,
  p_start_date date,
  p_end_date date,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
  v_days numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF p_leave_kind NOT IN ('casual','sick','paid','unpaid','maternity','paternity','bereavement','emergency') THEN
    RAISE EXCEPTION 'invalid_leave_kind';
  END IF;
  IF p_end_date < p_start_date THEN
    RAISE EXCEPTION 'end_before_start';
  END IF;
  v_days := (p_end_date - p_start_date) + 1;
  INSERT INTO public.engineer_leave_requests (
    engineer_user_id, leave_kind, start_date, end_date, total_days, reason, status
  ) VALUES (
    v_uid, p_leave_kind, p_start_date, p_end_date, v_days, p_reason, 'submitted'
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.engineer_leave_submit_request(text, date, date, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_engineer_leave_approve_request(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_leave_approve_request(
  p_request_id uuid,
  p_decision text,
  p_response text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  UPDATE public.engineer_leave_requests
  SET status = p_decision,
      approved_by = auth.uid(),
      approved_at = now(),
      founder_response = p_response
  WHERE id = p_request_id AND status = 'submitted';
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_leave_approve_request(uuid, text, text) TO authenticated;

COMMIT;