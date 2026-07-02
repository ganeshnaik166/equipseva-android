BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_leave_balances_r2266 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  city text NOT NULL,
  annual_pto_days_allocated numeric(5,1) NOT NULL DEFAULT 24.0,
  pto_days_used numeric(5,1) NOT NULL DEFAULT 0.0,
  pto_days_pending numeric(5,1) NOT NULL DEFAULT 0.0,
  sick_days_allocated numeric(5,1) NOT NULL DEFAULT 12.0,
  sick_days_used numeric(5,1) NOT NULL DEFAULT 0.0,
  carryover_from_prior_year numeric(5,1) NOT NULL DEFAULT 0.0,
  fiscal_year int NOT NULL DEFAULT 2026,
  last_leave_taken_at timestamptz,
  burnout_risk_score numeric(4,2) NOT NULL DEFAULT 0.0 CHECK (burnout_risk_score >= 0 AND burnout_risk_score <= 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_leave_bal_r2266_eng ON public.engineer_leave_balances_r2266(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_leave_bal_r2266_city ON public.engineer_leave_balances_r2266(city);

CREATE TABLE IF NOT EXISTS public.engineer_leave_requests_r2266 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  balance_id uuid NOT NULL REFERENCES public.engineer_leave_balances_r2266(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  city text NOT NULL,
  leave_type text NOT NULL CHECK (leave_type IN ('pto','sick','unpaid','bereavement','training')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  days_requested numeric(4,1) NOT NULL,
  reason text NOT NULL,
  conflicts_with_peak_week boolean NOT NULL DEFAULT false,
  peak_week_label text,
  open_jobs_in_window int NOT NULL DEFAULT 0,
  coverage_engineer_assigned text,
  approval_status text NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected','cancelled')),
  approval_notes text,
  approved_by_founder_email text,
  approved_at timestamptz,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_leave_req_r2266_status ON public.engineer_leave_requests_r2266(approval_status);
CREATE INDEX IF NOT EXISTS idx_eng_leave_req_r2266_eng ON public.engineer_leave_requests_r2266(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_leave_req_r2266_peak ON public.engineer_leave_requests_r2266(conflicts_with_peak_week) WHERE conflicts_with_peak_week = true;

ALTER TABLE public.engineer_leave_balances_r2266 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_leave_requests_r2266 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_leave_balances_r2266;
CREATE POLICY founder_all ON public.engineer_leave_balances_r2266
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_leave_requests_r2266;
CREATE POLICY founder_all ON public.engineer_leave_requests_r2266
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed balances
INSERT INTO public.engineer_leave_balances_r2266 (engineer_user_id, engineer_name, city, annual_pto_days_allocated, pto_days_used, pto_days_pending, sick_days_used, carryover_from_prior_year, last_leave_taken_at, burnout_risk_score)
SELECT id, COALESCE(full_name, email, 'Engineer'), 'Hyderabad', 24.0, 14.5, 2.0, 4.0, 3.0, now() - interval '45 days', 78.5
FROM public.profiles WHERE role = 'engineer' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.engineer_leave_balances_r2266 (engineer_user_id, engineer_name, city, annual_pto_days_allocated, pto_days_used, pto_days_pending, sick_days_used, carryover_from_prior_year, last_leave_taken_at, burnout_risk_score)
SELECT id, COALESCE(full_name, email, 'Engineer'), 'Mumbai', 24.0, 6.0, 5.0, 1.0, 0.0, now() - interval '90 days', 42.0
FROM public.profiles WHERE role = 'engineer' OFFSET 1 LIMIT 1
ON CONFLICT DO NOTHING;

-- Seed requests
INSERT INTO public.engineer_leave_requests_r2266 (balance_id, engineer_user_id, engineer_name, city, leave_type, start_date, end_date, days_requested, reason, conflicts_with_peak_week, peak_week_label, open_jobs_in_window, coverage_engineer_assigned, approval_status, submitted_at)
SELECT b.id, b.engineer_user_id, b.engineer_name, b.city, 'pto', current_date + 5, current_date + 9, 5.0,
  'Family wedding in hometown', true, 'Q3 peak week 3 (AMC renewals + chain rollout)', 8, 'Backup engineer TBD', 'pending', now() - interval '2 days'
FROM public.engineer_leave_balances_r2266 b LIMIT 1;

INSERT INTO public.engineer_leave_requests_r2266 (balance_id, engineer_user_id, engineer_name, city, leave_type, start_date, end_date, days_requested, reason, conflicts_with_peak_week, peak_week_label, open_jobs_in_window, coverage_engineer_assigned, approval_status, approved_by_founder_email, approved_at, submitted_at)
SELECT b.id, b.engineer_user_id, b.engineer_name, b.city, 'sick', current_date - 3, current_date - 1, 3.0,
  'Viral fever with medical note', false, NULL, 2, 'Auto-reassigned to peer pool', 'approved', 'founder@equipseva.in', now() - interval '4 days', now() - interval '5 days'
FROM public.engineer_leave_balances_r2266 b OFFSET 1 LIMIT 1;

-- RPC: top-line KPIs
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_kpis_r2266()
RETURNS TABLE(
  total_engineers int,
  total_pto_allocated numeric,
  total_pto_used numeric,
  pending_requests int,
  peak_week_conflicts int,
  high_burnout_count int,
  avg_burnout_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.engineer_leave_balances_r2266)::int,
    COALESCE((SELECT SUM(annual_pto_days_allocated) FROM public.engineer_leave_balances_r2266), 0)::numeric,
    COALESCE((SELECT SUM(pto_days_used) FROM public.engineer_leave_balances_r2266), 0)::numeric,
    (SELECT COUNT(*) FILTER (WHERE approval_status = 'pending') FROM public.engineer_leave_requests_r2266)::int,
    (SELECT COUNT(*) FILTER (WHERE conflicts_with_peak_week = true AND approval_status = 'pending') FROM public.engineer_leave_requests_r2266)::int,
    (SELECT COUNT(*) FILTER (WHERE burnout_risk_score >= 70) FROM public.engineer_leave_balances_r2266)::int,
    COALESCE((SELECT AVG(burnout_risk_score) FROM public.engineer_leave_balances_r2266), 0)::numeric;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_kpis_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_kpis_r2266() TO authenticated;

-- RPC: balance list
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_balances_r2266()
RETURNS SETOF public.engineer_leave_balances_r2266
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_leave_balances_r2266 ORDER BY burnout_risk_score DESC, pto_days_used DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_balances_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_balances_r2266() TO authenticated;

-- RPC: pending requests
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_pending_r2266()
RETURNS SETOF public.engineer_leave_requests_r2266
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_leave_requests_r2266 WHERE approval_status = 'pending' ORDER BY conflicts_with_peak_week DESC, submitted_at ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_pending_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_pending_r2266() TO authenticated;

-- RPC: peak-week conflicts
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_conflicts_r2266()
RETURNS SETOF public.engineer_leave_requests_r2266
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_leave_requests_r2266 WHERE conflicts_with_peak_week = true ORDER BY start_date ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_conflicts_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_conflicts_r2266() TO authenticated;

-- RPC: city rollup
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_by_city_r2266()
RETURNS TABLE(
  city text,
  engineers int,
  total_pending_days numeric,
  total_used_days numeric,
  pending_requests int,
  avg_burnout numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.city,
    COUNT(*)::int,
    COALESCE(SUM(b.pto_days_pending), 0)::numeric,
    COALESCE(SUM(b.pto_days_used), 0)::numeric,
    (SELECT COUNT(*) FILTER (WHERE r.approval_status = 'pending') FROM public.engineer_leave_requests_r2266 r WHERE r.city = b.city)::int,
    COALESCE(AVG(b.burnout_risk_score), 0)::numeric
  FROM public.engineer_leave_balances_r2266 b
  GROUP BY b.city
  ORDER BY b.city;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_by_city_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_by_city_r2266() TO authenticated;

-- RPC: high burnout watchlist
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_burnout_r2266()
RETURNS SETOF public.engineer_leave_balances_r2266
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_leave_balances_r2266 WHERE burnout_risk_score >= 60 ORDER BY burnout_risk_score DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_burnout_r2266() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_burnout_r2266() TO authenticated;

-- RPC: approval action
CREATE OR REPLACE FUNCTION public.rpc_eng_leave_approve_r2266(p_request_id uuid, p_action text, p_notes text DEFAULT NULL)
RETURNS public.engineer_leave_requests_r2266
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.engineer_leave_requests_r2266;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_action NOT IN ('approve','reject') THEN RAISE EXCEPTION 'invalid action'; END IF;
  v_email := auth.jwt()->>'email';
  UPDATE public.engineer_leave_requests_r2266
  SET approval_status = CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END,
      approval_notes = p_notes,
      approved_by_founder_email = v_email,
      approved_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_eng_leave_approve_r2266(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eng_leave_approve_r2266(uuid, text, text) TO authenticated;

COMMIT;
