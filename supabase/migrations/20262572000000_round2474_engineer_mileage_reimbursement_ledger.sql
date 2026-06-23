-- Round 2474: engineer-mileage-reimbursement-ledger
-- Per-trip km x rate x INR claimed x paid x discrepancy x monthly cap.

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_mileage_trips_r2474 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  trip_at timestamptz NOT NULL DEFAULT now(),
  from_label text NOT NULL,
  to_label text NOT NULL,
  km_driven int NOT NULL DEFAULT 0 CHECK (km_driven >= 0),
  rate_per_km_rupees int NOT NULL DEFAULT 0 CHECK (rate_per_km_rupees >= 0),
  claimed_rupees int NOT NULL DEFAULT 0 CHECK (claimed_rupees >= 0),
  paid_rupees int NOT NULL DEFAULT 0 CHECK (paid_rupees >= 0),
  discrepancy_rupees int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','rejected','disputed')),
  approver_email text,
  paid_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_mileage_trips_r2474_engineer ON public.engineer_mileage_trips_r2474(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_mileage_trips_r2474_status ON public.engineer_mileage_trips_r2474(status);
CREATE INDEX IF NOT EXISTS idx_engineer_mileage_trips_r2474_trip_at ON public.engineer_mileage_trips_r2474(trip_at);

CREATE TABLE IF NOT EXISTS public.engineer_mileage_monthly_caps_r2474 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  month_start date NOT NULL,
  total_km int NOT NULL DEFAULT 0 CHECK (total_km >= 0),
  total_claimed_rupees bigint NOT NULL DEFAULT 0 CHECK (total_claimed_rupees >= 0),
  total_paid_rupees bigint NOT NULL DEFAULT 0 CHECK (total_paid_rupees >= 0),
  monthly_cap_rupees bigint NOT NULL DEFAULT 0 CHECK (monthly_cap_rupees >= 0),
  cap_exceeded boolean NOT NULL DEFAULT false,
  cap_exceeded_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'under_cap' CHECK (status IN ('under_cap','at_cap','over_cap')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_mileage_monthly_caps_r2474_engineer ON public.engineer_mileage_monthly_caps_r2474(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_engineer_mileage_monthly_caps_r2474_month ON public.engineer_mileage_monthly_caps_r2474(month_start);
CREATE INDEX IF NOT EXISTS idx_engineer_mileage_monthly_caps_r2474_status ON public.engineer_mileage_monthly_caps_r2474(status);

ALTER TABLE public.engineer_mileage_trips_r2474 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mileage_monthly_caps_r2474 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_mileage_trips_r2474;
CREATE POLICY founder_all ON public.engineer_mileage_trips_r2474
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_mileage_monthly_caps_r2474;
CREATE POLICY founder_all ON public.engineer_mileage_monthly_caps_r2474
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at OFFSET 2 LIMIT 1;

  INSERT INTO public.engineer_mileage_trips_r2474(engineer_user_id, trip_at, from_label, to_label, km_driven, rate_per_km_rupees, claimed_rupees, paid_rupees, discrepancy_rupees, status, approver_email, paid_at, notes)
  VALUES
    (v_eng1, '2026-06-10 09:00:00'::timestamptz, 'Hyderabad HQ', 'Apollo Jubilee Hills', 18, 12, 216, 216, 0, 'paid', 'ops@equipseva.com', '2026-06-12 11:00:00'::timestamptz, 'Routine maintenance call'),
    (v_eng1, '2026-06-12 14:00:00'::timestamptz, 'Hyderabad HQ', 'KIMS Secunderabad', 22, 12, 264, 264, 0, 'paid', 'ops@equipseva.com', '2026-06-14 10:00:00'::timestamptz, 'Ventilator service'),
    (v_eng2, '2026-06-15 08:30:00'::timestamptz, 'Bangalore HQ', 'Manipal Whitefield', 35, 12, 420, 380, 40, 'disputed', 'ops@equipseva.com', NULL, 'Engineer claims toll road detour'),
    (v_eng3, '2026-06-18 10:00:00'::timestamptz, 'Chennai HQ', 'Fortis Vadapalani', 28, 12, 336, 0, 0, 'approved', 'ops@equipseva.com', NULL, 'Awaiting payout cycle'),
    (v_eng2, '2026-06-20 13:00:00'::timestamptz, 'Bangalore HQ', 'Aster CMI', 19, 12, 228, 0, 0, 'pending', NULL, NULL, 'Trip submitted, pending review');

  INSERT INTO public.engineer_mileage_monthly_caps_r2474(engineer_user_id, month_start, total_km, total_claimed_rupees, total_paid_rupees, monthly_cap_rupees, cap_exceeded, cap_exceeded_rupees, status, notes)
  VALUES
    (v_eng1, '2026-06-01'::date, 40, 480, 480, 6000, false, 0, 'under_cap', 'Well within cap'),
    (v_eng2, '2026-06-01'::date, 54, 648, 380, 6000, false, 0, 'under_cap', 'Pending dispute resolution'),
    (v_eng3, '2026-06-01'::date, 28, 336, 0, 4000, false, 0, 'under_cap', 'New engineer, low usage'),
    (v_eng1, '2026-05-01'::date, 520, 6240, 6000, 6000, true, 240, 'over_cap', 'Exceeded May cap by Rs 240'),
    (v_eng2, '2026-05-01'::date, 498, 5976, 5976, 6000, false, 0, 'at_cap', 'Right at cap line');
END $$;

-- RPC 1: list_trips_r2474
CREATE OR REPLACE FUNCTION public.list_trips_r2474()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  trip_at timestamptz,
  from_label text,
  to_label text,
  km_driven int,
  rate_per_km_rupees int,
  claimed_rupees int,
  paid_rupees int,
  discrepancy_rupees int,
  status text,
  approver_email text,
  paid_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.trip_at, t.from_label, t.to_label,
         t.km_driven, t.rate_per_km_rupees, t.claimed_rupees, t.paid_rupees,
         t.discrepancy_rupees, t.status, t.approver_email, t.paid_at, t.notes
  FROM public.engineer_mileage_trips_r2474 t
  ORDER BY t.trip_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_trips_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trips_r2474() TO authenticated;

-- RPC 2: list_monthly_caps_r2474
CREATE OR REPLACE FUNCTION public.list_monthly_caps_r2474()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  month_start date,
  total_km int,
  total_claimed_rupees bigint,
  total_paid_rupees bigint,
  monthly_cap_rupees bigint,
  cap_exceeded boolean,
  cap_exceeded_rupees bigint,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.month_start, c.total_km, c.total_claimed_rupees,
         c.total_paid_rupees, c.monthly_cap_rupees, c.cap_exceeded, c.cap_exceeded_rupees,
         c.status, c.notes
  FROM public.engineer_mileage_monthly_caps_r2474 c
  ORDER BY c.month_start DESC, c.total_claimed_rupees DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_monthly_caps_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_monthly_caps_r2474() TO authenticated;

-- RPC 3: top_claim_engineers_r2474
CREATE OR REPLACE FUNCTION public.top_claim_engineers_r2474()
RETURNS TABLE (
  engineer_user_id uuid,
  trip_count bigint,
  total_km bigint,
  total_claimed_rupees bigint,
  total_paid_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_user_id,
         COUNT(*)::bigint AS trip_count,
         COALESCE(SUM(t.km_driven), 0)::bigint AS total_km,
         COALESCE(SUM(t.claimed_rupees), 0)::bigint AS total_claimed_rupees,
         COALESCE(SUM(t.paid_rupees), 0)::bigint AS total_paid_rupees
  FROM public.engineer_mileage_trips_r2474 t
  WHERE t.engineer_user_id IS NOT NULL
  GROUP BY t.engineer_user_id
  ORDER BY total_claimed_rupees DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_claim_engineers_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_claim_engineers_r2474() TO authenticated;

-- RPC 4: discrepancy_focus_r2474
CREATE OR REPLACE FUNCTION public.discrepancy_focus_r2474()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  trip_at timestamptz,
  from_label text,
  to_label text,
  claimed_rupees int,
  paid_rupees int,
  discrepancy_rupees int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.trip_at, t.from_label, t.to_label,
         t.claimed_rupees, t.paid_rupees, t.discrepancy_rupees, t.status, t.notes
  FROM public.engineer_mileage_trips_r2474 t
  WHERE t.discrepancy_rupees <> 0 OR t.status = 'disputed'
  ORDER BY ABS(t.discrepancy_rupees) DESC, t.trip_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.discrepancy_focus_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.discrepancy_focus_r2474() TO authenticated;

-- RPC 5: monthly_total_trend_r2474
CREATE OR REPLACE FUNCTION public.monthly_total_trend_r2474()
RETURNS TABLE (
  month_start date,
  engineer_count bigint,
  total_km bigint,
  total_claimed_rupees bigint,
  total_paid_rupees bigint,
  over_cap_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.month_start,
         COUNT(DISTINCT c.engineer_user_id)::bigint AS engineer_count,
         COALESCE(SUM(c.total_km), 0)::bigint AS total_km,
         COALESCE(SUM(c.total_claimed_rupees), 0)::bigint AS total_claimed_rupees,
         COALESCE(SUM(c.total_paid_rupees), 0)::bigint AS total_paid_rupees,
         COUNT(*) FILTER (WHERE c.status = 'over_cap')::bigint AS over_cap_count
  FROM public.engineer_mileage_monthly_caps_r2474 c
  GROUP BY c.month_start
  ORDER BY c.month_start DESC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_total_trend_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_total_trend_r2474() TO authenticated;

-- RPC 6: cap_breach_focus_r2474
CREATE OR REPLACE FUNCTION public.cap_breach_focus_r2474()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  month_start date,
  total_claimed_rupees bigint,
  monthly_cap_rupees bigint,
  cap_exceeded_rupees bigint,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.month_start, c.total_claimed_rupees,
         c.monthly_cap_rupees, c.cap_exceeded_rupees, c.status, c.notes
  FROM public.engineer_mileage_monthly_caps_r2474 c
  WHERE c.status IN ('at_cap','over_cap') OR c.cap_exceeded = true
  ORDER BY c.cap_exceeded_rupees DESC, c.month_start DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.cap_breach_focus_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cap_breach_focus_r2474() TO authenticated;

-- RPC 7: status_breakdown_r2474
CREATE OR REPLACE FUNCTION public.status_breakdown_r2474()
RETURNS TABLE (
  status text,
  trip_count bigint,
  total_claimed_rupees bigint,
  total_paid_rupees bigint,
  total_discrepancy_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status,
         COUNT(*)::bigint AS trip_count,
         COALESCE(SUM(t.claimed_rupees), 0)::bigint AS total_claimed_rupees,
         COALESCE(SUM(t.paid_rupees), 0)::bigint AS total_paid_rupees,
         COALESCE(SUM(t.discrepancy_rupees), 0)::bigint AS total_discrepancy_rupees
  FROM public.engineer_mileage_trips_r2474 t
  GROUP BY t.status
  ORDER BY trip_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2474() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2474() TO authenticated;

