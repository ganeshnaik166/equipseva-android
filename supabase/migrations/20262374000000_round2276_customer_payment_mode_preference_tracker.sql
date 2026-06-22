BEGIN;

-- Table 1: customer payment mode preferences (current state per hospital)
CREATE TABLE IF NOT EXISTS public.customer_payment_mode_preferences_r2276 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  primary_mode text NOT NULL CHECK (primary_mode IN ('upi','neft','card','cash','cheque','wallet')),
  secondary_mode text CHECK (secondary_mode IN ('upi','neft','card','cash','cheque','wallet')),
  monthly_volume_rupees bigint NOT NULL DEFAULT 0,
  txn_count_30d int NOT NULL DEFAULT 0,
  avg_settlement_hours numeric(6,2) NOT NULL DEFAULT 0,
  cost_to_serve_rupees bigint NOT NULL DEFAULT 0,
  failure_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  preferred_since date NOT NULL DEFAULT CURRENT_DATE,
  last_used_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpmp_r2276_hospital ON public.customer_payment_mode_preferences_r2276(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cpmp_r2276_mode ON public.customer_payment_mode_preferences_r2276(primary_mode);

ALTER TABLE public.customer_payment_mode_preferences_r2276 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cpmp_r2276_founder_all ON public.customer_payment_mode_preferences_r2276;
CREATE POLICY cpmp_r2276_founder_all ON public.customer_payment_mode_preferences_r2276
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: switching events log
CREATE TABLE IF NOT EXISTS public.customer_payment_mode_switches_r2276 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  from_mode text NOT NULL CHECK (from_mode IN ('upi','neft','card','cash','cheque','wallet','none')),
  to_mode text NOT NULL CHECK (to_mode IN ('upi','neft','card','cash','cheque','wallet')),
  switch_reason text NOT NULL CHECK (switch_reason IN ('faster_settlement','lower_cost','reliability','vendor_request','convenience','failure_event','other')),
  cost_delta_rupees bigint NOT NULL DEFAULT 0,
  settlement_delta_hours numeric(6,2) NOT NULL DEFAULT 0,
  switched_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpms_r2276_hospital ON public.customer_payment_mode_switches_r2276(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cpms_r2276_switched_at ON public.customer_payment_mode_switches_r2276(switched_at DESC);

ALTER TABLE public.customer_payment_mode_switches_r2276 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cpms_r2276_founder_all ON public.customer_payment_mode_switches_r2276;
CREATE POLICY cpms_r2276_founder_all ON public.customer_payment_mode_switches_r2276
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_h4 uuid;
  v_h5 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h4 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h3, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h5 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h3, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h4, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;

  IF v_h1 IS NOT NULL THEN
    INSERT INTO public.customer_payment_mode_preferences_r2276 (hospital_user_id, hospital_name, primary_mode, secondary_mode, monthly_volume_rupees, txn_count_30d, avg_settlement_hours, cost_to_serve_rupees, failure_rate_pct, preferred_since, last_used_at, notes)
    VALUES (v_h1, 'Apollo Jubilee Hills', 'upi', 'neft', 4250000, 38, 2.5, 4250, 0.50, '2026-01-15', now() - interval '2 hours', 'Top UPI user; clean rails');

    INSERT INTO public.customer_payment_mode_switches_r2276 (hospital_user_id, hospital_name, from_mode, to_mode, switch_reason, cost_delta_rupees, settlement_delta_hours, switched_at, notes)
    VALUES (v_h1, 'Apollo Jubilee Hills', 'neft', 'upi', 'faster_settlement', -3500, -22.0, now() - interval '60 days', 'Moved bulk AMC fees to UPI rails');
  END IF;

  IF v_h2 IS NOT NULL THEN
    INSERT INTO public.customer_payment_mode_preferences_r2276 (hospital_user_id, hospital_name, primary_mode, secondary_mode, monthly_volume_rupees, txn_count_30d, avg_settlement_hours, cost_to_serve_rupees, failure_rate_pct, preferred_since, last_used_at, notes)
    VALUES (v_h2, 'KIMS Secunderabad', 'neft', 'cheque', 8800000, 12, 28.5, 18200, 1.20, '2025-09-01', now() - interval '1 day', 'Heavy NEFT — finance dept policy');

    INSERT INTO public.customer_payment_mode_switches_r2276 (hospital_user_id, hospital_name, from_mode, to_mode, switch_reason, cost_delta_rupees, settlement_delta_hours, switched_at, notes)
    VALUES (v_h2, 'KIMS Secunderabad', 'cheque', 'neft', 'reliability', -5000, -48.0, now() - interval '120 days', 'Cheque bounce in Aug forced switch');
  END IF;

  IF v_h3 IS NOT NULL THEN
    INSERT INTO public.customer_payment_mode_preferences_r2276 (hospital_user_id, hospital_name, primary_mode, secondary_mode, monthly_volume_rupees, txn_count_30d, avg_settlement_hours, cost_to_serve_rupees, failure_rate_pct, preferred_since, last_used_at, notes)
    VALUES (v_h3, 'Yashoda Somajiguda', 'card', 'upi', 1850000, 22, 18.0, 33800, 3.20, '2026-02-10', now() - interval '6 hours', 'Card MDR eats margin; nudge to UPI');

    INSERT INTO public.customer_payment_mode_switches_r2276 (hospital_user_id, hospital_name, from_mode, to_mode, switch_reason, cost_delta_rupees, settlement_delta_hours, switched_at, notes)
    VALUES (v_h3, 'Yashoda Somajiguda', 'upi', 'card', 'vendor_request', 14500, 16.5, now() - interval '40 days', 'CFO wants reward points on corporate cards');
  END IF;

  IF v_h4 IS NOT NULL THEN
    INSERT INTO public.customer_payment_mode_preferences_r2276 (hospital_user_id, hospital_name, primary_mode, secondary_mode, monthly_volume_rupees, txn_count_30d, avg_settlement_hours, cost_to_serve_rupees, failure_rate_pct, preferred_since, last_used_at, notes)
    VALUES (v_h4, 'Continental Gachibowli', 'cash', 'upi', 320000, 8, 0.5, 1600, 0.0, '2025-11-20', now() - interval '4 days', 'Small clinic — cash for low-ticket repairs');
  END IF;

  IF v_h5 IS NOT NULL THEN
    INSERT INTO public.customer_payment_mode_preferences_r2276 (hospital_user_id, hospital_name, primary_mode, secondary_mode, monthly_volume_rupees, txn_count_30d, avg_settlement_hours, cost_to_serve_rupees, failure_rate_pct, preferred_since, last_used_at, notes)
    VALUES (v_h5, 'Care Banjara Hills', 'wallet', 'upi', 680000, 14, 4.0, 6800, 1.10, '2026-03-05', now() - interval '12 hours', 'Paytm wallet for routine AMC slots');

    INSERT INTO public.customer_payment_mode_switches_r2276 (hospital_user_id, hospital_name, from_mode, to_mode, switch_reason, cost_delta_rupees, settlement_delta_hours, switched_at, notes)
    VALUES (v_h5, 'Care Banjara Hills', 'cash', 'wallet', 'convenience', 800, 3.5, now() - interval '25 days', 'Front-desk hates handling cash');
  END IF;
END;
$seed$;

-- RPC 1: list preferences
CREATE OR REPLACE FUNCTION public.r2276_list_preferences()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  primary_mode text,
  secondary_mode text,
  monthly_volume_rupees bigint,
  txn_count_30d int,
  avg_settlement_hours numeric,
  cost_to_serve_rupees bigint,
  failure_rate_pct numeric,
  preferred_since date,
  last_used_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_name, p.primary_mode, p.secondary_mode, p.monthly_volume_rupees,
         p.txn_count_30d, p.avg_settlement_hours, p.cost_to_serve_rupees, p.failure_rate_pct,
         p.preferred_since, p.last_used_at
  FROM public.customer_payment_mode_preferences_r2276 p
  ORDER BY p.monthly_volume_rupees DESC;
END;
$$;

-- RPC 2: list switches
CREATE OR REPLACE FUNCTION public.r2276_list_switches()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  from_mode text,
  to_mode text,
  switch_reason text,
  cost_delta_rupees bigint,
  settlement_delta_hours numeric,
  switched_at timestamptz,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_name, s.from_mode, s.to_mode, s.switch_reason,
         s.cost_delta_rupees, s.settlement_delta_hours, s.switched_at, s.notes
  FROM public.customer_payment_mode_switches_r2276 s
  ORDER BY s.switched_at DESC;
END;
$$;

-- RPC 3: mode mix summary
CREATE OR REPLACE FUNCTION public.r2276_mode_mix()
RETURNS TABLE (
  mode text,
  hospital_count int,
  total_monthly_volume_rupees bigint,
  total_cost_to_serve_rupees bigint,
  avg_settlement_hours numeric,
  avg_failure_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.primary_mode AS mode,
         (COUNT(*))::int AS hospital_count,
         COALESCE(SUM(p.monthly_volume_rupees), 0)::bigint AS total_monthly_volume_rupees,
         COALESCE(SUM(p.cost_to_serve_rupees), 0)::bigint AS total_cost_to_serve_rupees,
         COALESCE(AVG(p.avg_settlement_hours), 0)::numeric AS avg_settlement_hours,
         COALESCE(AVG(p.failure_rate_pct), 0)::numeric AS avg_failure_rate_pct
  FROM public.customer_payment_mode_preferences_r2276 p
  GROUP BY p.primary_mode
  ORDER BY total_monthly_volume_rupees DESC;
END;
$$;

-- RPC 4: cost-to-serve ranking
CREATE OR REPLACE FUNCTION public.r2276_cost_ranking()
RETURNS TABLE (
  hospital_name text,
  primary_mode text,
  monthly_volume_rupees bigint,
  cost_to_serve_rupees bigint,
  cost_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT p.hospital_name, p.primary_mode, p.monthly_volume_rupees, p.cost_to_serve_rupees,
         CASE WHEN p.monthly_volume_rupees > 0
              THEN ROUND((p.cost_to_serve_rupees::numeric / p.monthly_volume_rupees::numeric) * 100, 2)
              ELSE 0 END AS cost_pct
  FROM public.customer_payment_mode_preferences_r2276 p
  ORDER BY cost_pct DESC NULLS LAST;
END;
$$;

-- RPC 5: switch reasons rollup
CREATE OR REPLACE FUNCTION public.r2276_switch_reasons()
RETURNS TABLE (
  switch_reason text,
  switch_count int,
  total_cost_delta_rupees bigint,
  avg_settlement_delta_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.switch_reason,
         (COUNT(*))::int AS switch_count,
         COALESCE(SUM(s.cost_delta_rupees), 0)::bigint AS total_cost_delta_rupees,
         COALESCE(AVG(s.settlement_delta_hours), 0)::numeric AS avg_settlement_delta_hours
  FROM public.customer_payment_mode_switches_r2276 s
  GROUP BY s.switch_reason
  ORDER BY switch_count DESC;
END;
$$;

-- RPC 6: KPIs
CREATE OR REPLACE FUNCTION public.r2276_kpis()
RETURNS TABLE (
  total_hospitals int,
  total_monthly_volume_rupees bigint,
  total_cost_to_serve_rupees bigint,
  upi_share_pct numeric,
  switches_last_90d int,
  avg_settlement_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_vol bigint;
  v_upi_vol bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(SUM(monthly_volume_rupees), 0) INTO v_total_vol FROM public.customer_payment_mode_preferences_r2276;
  SELECT COALESCE(SUM(monthly_volume_rupees), 0) INTO v_upi_vol FROM public.customer_payment_mode_preferences_r2276 WHERE primary_mode = 'upi';
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.customer_payment_mode_preferences_r2276),
    v_total_vol,
    (SELECT COALESCE(SUM(cost_to_serve_rupees), 0)::bigint FROM public.customer_payment_mode_preferences_r2276),
    CASE WHEN v_total_vol > 0 THEN ROUND((v_upi_vol::numeric / v_total_vol::numeric) * 100, 2) ELSE 0 END,
    (SELECT COUNT(*) FILTER (WHERE switched_at > now() - interval '90 days'))::int FROM public.customer_payment_mode_switches_r2276,
    (SELECT COALESCE(AVG(avg_settlement_hours), 0)::numeric FROM public.customer_payment_mode_preferences_r2276);
END;
$$;

-- RPC 7: recent switches feed
CREATE OR REPLACE FUNCTION public.r2276_recent_switches()
RETURNS TABLE (
  hospital_name text,
  from_mode text,
  to_mode text,
  switch_reason text,
  cost_delta_rupees bigint,
  switched_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.hospital_name, s.from_mode, s.to_mode, s.switch_reason, s.cost_delta_rupees, s.switched_at
  FROM public.customer_payment_mode_switches_r2276 s
  WHERE s.switched_at > now() - interval '180 days'
  ORDER BY s.switched_at DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.r2276_list_preferences() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_list_switches() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_mode_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_cost_ranking() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_switch_reasons() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2276_recent_switches() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2276_list_preferences() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_list_switches() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_mode_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_cost_ranking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_switch_reasons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2276_recent_switches() TO authenticated;

COMMIT;
