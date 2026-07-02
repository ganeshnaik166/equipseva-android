-- Round 2564: customer equipment data quality air-gap bridge
-- Tracks per-equipment data export feasibility, bridge mechanism, frequency, and revenue from data.

BEGIN;

-- Main bridge table
CREATE TABLE IF NOT EXISTS public.equipment_data_bridge_r2564 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  data_export_feasibility text NOT NULL CHECK (data_export_feasibility IN ('yes','partial','no')),
  bridge_kind text NOT NULL CHECK (bridge_kind IN ('usb_dump','network_one_way','api_proxy','manual_csv','no_bridge')),
  frequency_kind text NOT NULL CHECK (frequency_kind IN ('real_time','hourly','daily','weekly','monthly','none')),
  revenue_from_data_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('scoping','in_setup','live','broken','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Revenue event log table
CREATE TABLE IF NOT EXISTS public.data_bridge_revenue_log_r2564 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bridge_id uuid NOT NULL REFERENCES public.equipment_data_bridge_r2564(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  revenue_event_kind text NOT NULL CHECK (revenue_event_kind IN ('report_subscription','api_seat','analytics_pack','training_credit')),
  revenue_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.equipment_data_bridge_r2564 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_bridge_revenue_log_r2564 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_data_bridge_r2564;
CREATE POLICY founder_all ON public.equipment_data_bridge_r2564
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.data_bridge_revenue_log_r2564;
CREATE POLICY founder_all ON public.data_bridge_revenue_log_r2564
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed: pick a few real hospital profiles
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_b1 uuid;
  v_b2 uuid;
  v_b3 uuid;
  v_b4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, gen_random_uuid()) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, gen_random_uuid()), COALESCE(v_h2, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;

  IF v_h1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.equipment_data_bridge_r2564
    (hospital_user_id, equipment_label, equipment_kind, data_export_feasibility, bridge_kind, frequency_kind, revenue_from_data_rupees, owner_email, status, notes)
  VALUES
    (v_h1, 'Philips Cath Lab Allura Xper FD20', 'cath_lab', 'yes', 'api_proxy', 'daily', 480000, 'founder@equipseva.in', 'live', 'API proxy live — daily uptime + utilization stream feeds analytics pack')
  RETURNING id INTO v_b1;

  INSERT INTO public.equipment_data_bridge_r2564
    (hospital_user_id, equipment_label, equipment_kind, data_export_feasibility, bridge_kind, frequency_kind, revenue_from_data_rupees, owner_email, status, notes)
  VALUES
    (COALESCE(v_h2, v_h1), 'GE Logiq E10 Ultrasound', 'ultrasound', 'partial', 'usb_dump', 'weekly', 120000, 'founder@equipseva.in', 'in_setup', 'Weekly USB dump SOP; biomed eng trained, awaiting sign-off')
  RETURNING id INTO v_b2;

  INSERT INTO public.equipment_data_bridge_r2564
    (hospital_user_id, equipment_label, equipment_kind, data_export_feasibility, bridge_kind, frequency_kind, revenue_from_data_rupees, owner_email, status, notes)
  VALUES
    (COALESCE(v_h3, v_h1), 'Siemens Magnetom MRI 1.5T', 'mri', 'no', 'no_bridge', 'none', 0, 'founder@equipseva.in', 'scoping', 'Vendor air-gap policy blocks export; scoping manual CSV alternative')
  RETURNING id INTO v_b3;

  INSERT INTO public.equipment_data_bridge_r2564
    (hospital_user_id, equipment_label, equipment_kind, data_export_feasibility, bridge_kind, frequency_kind, revenue_from_data_rupees, owner_email, status, notes)
  VALUES
    (v_h1, 'Roche Cobas 8000 Lab Analyzer', 'lab_analyzer', 'yes', 'network_one_way', 'hourly', 360000, 'founder@equipseva.in', 'broken', 'One-way LIS feed broken since firmware patch; tech revisit Mon')
  RETURNING id INTO v_b4;

  -- Revenue log
  IF v_b1 IS NOT NULL THEN
    INSERT INTO public.data_bridge_revenue_log_r2564
      (bridge_id, observed_at, revenue_event_kind, revenue_rupees, owner_email, status, notes)
    VALUES
      (v_b1, now() - interval '20 days', 'analytics_pack', 240000, 'founder@equipseva.in', 'done', 'Q2 cath lab utilization analytics pack invoiced');
    INSERT INTO public.data_bridge_revenue_log_r2564
      (bridge_id, observed_at, revenue_event_kind, revenue_rupees, owner_email, status, notes)
    VALUES
      (v_b1, now() - interval '5 days', 'api_seat', 60000, 'founder@equipseva.in', 'done', 'Added 2 cardiologist API seats');
  END IF;

  IF v_b2 IS NOT NULL THEN
    INSERT INTO public.data_bridge_revenue_log_r2564
      (bridge_id, observed_at, revenue_event_kind, revenue_rupees, owner_email, status, notes)
    VALUES
      (v_b2, now() - interval '12 days', 'report_subscription', 30000, 'founder@equipseva.in', 'open', 'Pilot subscription for monthly ultrasound utilization report');
  END IF;

  IF v_b4 IS NOT NULL THEN
    INSERT INTO public.data_bridge_revenue_log_r2564
      (bridge_id, observed_at, revenue_event_kind, revenue_rupees, owner_email, status, notes)
    VALUES
      (v_b4, now() - interval '40 days', 'training_credit', 50000, 'founder@equipseva.in', 'dropped', 'Training credit consumed; bridge break paused renewal');
  END IF;
END
$seed$;

-- RPCs ----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_bridges_r2564()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_label text,
  equipment_kind text,
  data_export_feasibility text,
  bridge_kind text,
  frequency_kind text,
  revenue_from_data_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id,
           b.hospital_user_id,
           p.email,
           b.equipment_label,
           b.equipment_kind,
           b.data_export_feasibility,
           b.bridge_kind,
           b.frequency_kind,
           b.revenue_from_data_rupees,
           b.owner_email,
           b.status,
           b.notes,
           b.created_at
      FROM public.equipment_data_bridge_r2564 b
      LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
     ORDER BY b.revenue_from_data_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bridges_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bridges_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_revenue_log_r2564()
RETURNS TABLE (
  id uuid,
  bridge_id uuid,
  equipment_label text,
  hospital_email text,
  observed_at timestamptz,
  revenue_event_kind text,
  revenue_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id,
           r.bridge_id,
           b.equipment_label,
           p.email,
           r.observed_at,
           r.revenue_event_kind,
           r.revenue_rupees,
           r.owner_email,
           r.status,
           r.notes,
           r.created_at
      FROM public.data_bridge_revenue_log_r2564 r
      LEFT JOIN public.equipment_data_bridge_r2564 b ON b.id = r.bridge_id
      LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
     ORDER BY r.observed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_revenue_log_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_revenue_log_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_revenue_bridges_r2564()
RETURNS TABLE (
  bridge_id uuid,
  equipment_label text,
  equipment_kind text,
  hospital_email text,
  bridge_kind text,
  frequency_kind text,
  total_revenue_rupees bigint,
  events_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id AS bridge_id,
           b.equipment_label,
           b.equipment_kind,
           p.email,
           b.bridge_kind,
           b.frequency_kind,
           (b.revenue_from_data_rupees + COALESCE(SUM(r.revenue_rupees), 0))::bigint AS total_revenue_rupees,
           COUNT(r.id) AS events_count
      FROM public.equipment_data_bridge_r2564 b
      LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
      LEFT JOIN public.data_bridge_revenue_log_r2564 r ON r.bridge_id = b.id
     GROUP BY b.id, b.equipment_label, b.equipment_kind, p.email, b.bridge_kind, b.frequency_kind, b.revenue_from_data_rupees
     ORDER BY total_revenue_rupees DESC NULLS LAST
     LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_bridges_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_bridges_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.feasibility_breakdown_r2564()
RETURNS TABLE (
  data_export_feasibility text,
  equipment_count bigint,
  total_revenue_rupees bigint,
  live_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.data_export_feasibility,
           COUNT(*) AS equipment_count,
           COALESCE(SUM(b.revenue_from_data_rupees), 0)::bigint AS total_revenue_rupees,
           COUNT(*) FILTER (WHERE b.status = 'live') AS live_count
      FROM public.equipment_data_bridge_r2564 b
     GROUP BY b.data_export_feasibility
     ORDER BY total_revenue_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.feasibility_breakdown_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feasibility_breakdown_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.bridge_kind_distribution_r2564()
RETURNS TABLE (
  bridge_kind text,
  equipment_count bigint,
  total_revenue_rupees bigint,
  pct_live numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bridge_kind,
           COUNT(*) AS equipment_count,
           COALESCE(SUM(b.revenue_from_data_rupees), 0)::bigint AS total_revenue_rupees,
           CASE WHEN COUNT(*) = 0 THEN 0::numeric
                ELSE ROUND((COUNT(*) FILTER (WHERE b.status = 'live'))::numeric * 100.0 / COUNT(*), 1)
           END AS pct_live
      FROM public.equipment_data_bridge_r2564 b
     GROUP BY b.bridge_kind
     ORDER BY total_revenue_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bridge_kind_distribution_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bridge_kind_distribution_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_revenue_trend_r2564()
RETURNS TABLE (
  month_start timestamptz,
  events_count bigint,
  total_revenue_rupees bigint,
  done_count bigint,
  open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', r.observed_at) AS month_start,
           COUNT(*) AS events_count,
           COALESCE(SUM(r.revenue_rupees), 0)::bigint AS total_revenue_rupees,
           COUNT(*) FILTER (WHERE r.status = 'done') AS done_count,
           COUNT(*) FILTER (WHERE r.status = 'open') AS open_count
      FROM public.data_bridge_revenue_log_r2564 r
     GROUP BY date_trunc('month', r.observed_at)
     ORDER BY month_start DESC NULLS LAST
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_revenue_trend_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_revenue_trend_r2564() TO authenticated;

CREATE OR REPLACE FUNCTION public.broken_focus_r2564()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_label text,
  equipment_kind text,
  bridge_kind text,
  frequency_kind text,
  revenue_from_data_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id,
           b.hospital_user_id,
           p.email,
           b.equipment_label,
           b.equipment_kind,
           b.bridge_kind,
           b.frequency_kind,
           b.revenue_from_data_rupees,
           b.owner_email,
           b.status,
           b.notes
      FROM public.equipment_data_bridge_r2564 b
      LEFT JOIN public.profiles p ON p.id = b.hospital_user_id
     WHERE b.status = 'broken' OR b.data_export_feasibility = 'no'
     ORDER BY b.revenue_from_data_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.broken_focus_r2564() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.broken_focus_r2564() TO authenticated;

