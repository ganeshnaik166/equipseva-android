-- Round 2528: Customer Equipment Loaner Fleet Utilization
-- Loaner unit × hospital × deployed days × utilization × wait queue × idle

CREATE TABLE IF NOT EXISTS public.equipment_loaner_deployments_r2528 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loaner_unit_label text NOT NULL,
  equipment_kind text NOT NULL CHECK (equipment_kind IN ('ventilator','ultrasound','ecg','monitor','anesthesia','dental')),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  deployed_at timestamptz,
  returned_at timestamptz,
  days_deployed int NOT NULL DEFAULT 0,
  utilization_pct numeric(6,2) NOT NULL DEFAULT 0,
  idle_days int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('pending','deployed','returned','lost','in_repair')),
  revenue_substituted_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loaner_wait_queue_r2528 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_kind text NOT NULL CHECK (equipment_kind IN ('ventilator','ultrasound','ecg','monitor','anesthesia','dental')),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  requested_at timestamptz NOT NULL,
  expected_deploy_at timestamptz,
  status text NOT NULL CHECK (status IN ('queued','assigned','cancelled','fulfilled')),
  priority text NOT NULL CHECK (priority IN ('low','medium','high','critical')),
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.equipment_loaner_deployments_r2528 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loaner_wait_queue_r2528 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_loaner_deployments_r2528;
CREATE POLICY founder_all ON public.equipment_loaner_deployments_r2528
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.loaner_wait_queue_r2528;
CREATE POLICY founder_all ON public.loaner_wait_queue_r2528
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed deployments
INSERT INTO public.equipment_loaner_deployments_r2528
  (loaner_unit_label, equipment_kind, deployed_at, returned_at, days_deployed, utilization_pct, idle_days, status, revenue_substituted_rupees, owner_email, notes)
VALUES
  ('VENT-L01', 'ventilator', (now() - interval '40 days')::timestamptz, (now() - interval '10 days')::timestamptz, 30, 88.50, 4, 'returned', 180000, 'ops@equipseva.com', 'Apollo ICU loaner — high utilization'),
  ('USG-L02', 'ultrasound', (now() - interval '20 days')::timestamptz, NULL, 20, 72.00, 6, 'deployed', 120000, 'ops@equipseva.com', 'KIMS radiology — extended use'),
  ('ECG-L03', 'ecg', (now() - interval '60 days')::timestamptz, (now() - interval '5 days')::timestamptz, 55, 45.00, 22, 'returned', 45000, 'ops@equipseva.com', 'Tier-2 hospital — partial utilization'),
  ('MON-L04', 'monitor', NULL, NULL, 0, 0.00, 14, 'in_repair', 0, 'ops@equipseva.com', 'Sensor calibration pending'),
  ('DENT-L05', 'dental', (now() - interval '8 days')::timestamptz, NULL, 8, 91.00, 1, 'deployed', 56000, 'ops@equipseva.com', 'Dental chain — high utilization');

-- Seed wait queue
INSERT INTO public.loaner_wait_queue_r2528
  (equipment_kind, requested_at, expected_deploy_at, status, priority, owner_email, notes)
VALUES
  ('ventilator', (now() - interval '3 days')::timestamptz, (now() + interval '2 days')::timestamptz, 'queued', 'critical', 'ops@equipseva.com', 'ICU surge — need within 48h'),
  ('ultrasound', (now() - interval '1 days')::timestamptz, (now() + interval '5 days')::timestamptz, 'queued', 'high', 'ops@equipseva.com', 'Radiology backup'),
  ('anesthesia', (now() - interval '7 days')::timestamptz, (now() + interval '10 days')::timestamptz, 'assigned', 'medium', 'ops@equipseva.com', 'OT schedule alignment'),
  ('monitor', (now() - interval '14 days')::timestamptz, NULL, 'cancelled', 'low', 'ops@equipseva.com', 'Hospital procured own unit'),
  ('dental', (now() - interval '2 days')::timestamptz, (now() + interval '1 days')::timestamptz, 'fulfilled', 'high', 'ops@equipseva.com', 'Dental chain rapid swap');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_deployments_r2528()
RETURNS TABLE(
  id uuid,
  loaner_unit_label text,
  equipment_kind text,
  hospital_user_id uuid,
  deployed_at timestamptz,
  returned_at timestamptz,
  days_deployed int,
  utilization_pct numeric,
  idle_days int,
  status text,
  revenue_substituted_rupees bigint,
  owner_email text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.loaner_unit_label, d.equipment_kind, d.hospital_user_id,
           d.deployed_at, d.returned_at, d.days_deployed, d.utilization_pct,
           d.idle_days, d.status, d.revenue_substituted_rupees, d.owner_email, d.notes
    FROM public.equipment_loaner_deployments_r2528 d
    ORDER BY d.deployed_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_deployments_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deployments_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_wait_queue_r2528()
RETURNS TABLE(
  id uuid,
  equipment_kind text,
  hospital_user_id uuid,
  requested_at timestamptz,
  expected_deploy_at timestamptz,
  status text,
  priority text,
  owner_email text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.id, q.equipment_kind, q.hospital_user_id, q.requested_at, q.expected_deploy_at,
           q.status, q.priority, q.owner_email, q.notes
    FROM public.loaner_wait_queue_r2528 q
    ORDER BY q.requested_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_wait_queue_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_wait_queue_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_utilized_loaners_r2528()
RETURNS TABLE(
  loaner_unit_label text,
  equipment_kind text,
  utilization_pct numeric,
  days_deployed int,
  revenue_substituted_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.loaner_unit_label, d.equipment_kind, d.utilization_pct, d.days_deployed, d.revenue_substituted_rupees
    FROM public.equipment_loaner_deployments_r2528 d
    ORDER BY d.utilization_pct DESC NULLS LAST
    LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_utilized_loaners_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_utilized_loaners_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.equipment_kind_summary_r2528()
RETURNS TABLE(
  equipment_kind text,
  unit_count bigint,
  avg_utilization numeric,
  total_idle_days bigint,
  total_revenue_substituted bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.equipment_kind,
           COUNT(*)::bigint AS unit_count,
           ROUND(AVG(d.utilization_pct), 2) AS avg_utilization,
           SUM(d.idle_days)::bigint AS total_idle_days,
           SUM(d.revenue_substituted_rupees)::bigint AS total_revenue_substituted
    FROM public.equipment_loaner_deployments_r2528 d
    GROUP BY d.equipment_kind
    ORDER BY unit_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_utilization_trend_r2528()
RETURNS TABLE(
  month_start timestamptz,
  deployments_count bigint,
  avg_utilization numeric,
  total_revenue_substituted bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', d.deployed_at) AS month_start,
           COUNT(*)::bigint AS deployments_count,
           ROUND(AVG(d.utilization_pct), 2) AS avg_utilization,
           SUM(d.revenue_substituted_rupees)::bigint AS total_revenue_substituted
    FROM public.equipment_loaner_deployments_r2528 d
    WHERE d.deployed_at IS NOT NULL
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_utilization_trend_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_utilization_trend_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.idle_loaners_focus_r2528()
RETURNS TABLE(
  id uuid,
  loaner_unit_label text,
  equipment_kind text,
  idle_days int,
  status text,
  utilization_pct numeric,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.loaner_unit_label, d.equipment_kind, d.idle_days, d.status, d.utilization_pct, d.notes
    FROM public.equipment_loaner_deployments_r2528 d
    WHERE d.idle_days > 5 OR d.status IN ('in_repair','pending','lost')
    ORDER BY d.idle_days DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.idle_loaners_focus_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.idle_loaners_focus_r2528() TO authenticated;

CREATE OR REPLACE FUNCTION public.queue_priority_distribution_r2528()
RETURNS TABLE(
  priority text,
  queue_count bigint,
  queued_count bigint,
  assigned_count bigint,
  fulfilled_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.priority,
           COUNT(*)::bigint AS queue_count,
           COUNT(*) FILTER (WHERE q.status = 'queued')::bigint AS queued_count,
           COUNT(*) FILTER (WHERE q.status = 'assigned')::bigint AS assigned_count,
           COUNT(*) FILTER (WHERE q.status = 'fulfilled')::bigint AS fulfilled_count
    FROM public.loaner_wait_queue_r2528 q
    GROUP BY q.priority
    ORDER BY queue_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.queue_priority_distribution_r2528() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.queue_priority_distribution_r2528() TO authenticated;
