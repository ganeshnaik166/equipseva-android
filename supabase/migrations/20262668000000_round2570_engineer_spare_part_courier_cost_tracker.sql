-- Round 2570: engineer-spare-part-courier-cost-tracker
-- Dispatch x courier x cost x distance x time-to-delivery x outlier flag x supplier

CREATE TABLE IF NOT EXISTS public.engineer_spare_courier_dispatches_r2570 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  dispatched_at timestamptz NOT NULL DEFAULT now(),
  part_sku text NOT NULL,
  part_name text NOT NULL,
  courier_kind text NOT NULL CHECK (courier_kind IN ('blue_dart','dtdc','india_post','in_house','uber_courier','local_runner')),
  cost_rupees int NOT NULL DEFAULT 0,
  distance_km int NOT NULL DEFAULT 0,
  time_to_delivery_hours numeric NOT NULL DEFAULT 0,
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  outlier_flag text NOT NULL DEFAULT 'none' CHECK (outlier_flag IN ('none','expensive','slow','missing','damaged')),
  owner_email text,
  status text NOT NULL DEFAULT 'in_transit' CHECK (status IN ('in_transit','delivered','missed','returned','disputed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.courier_outlier_actions_r2570 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  dispatch_id uuid NOT NULL REFERENCES public.engineer_spare_courier_dispatches_r2570(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('supplier_review','courier_switch','cost_audit','refund_chase','escalation')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.engineer_spare_courier_dispatches_r2570 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courier_outlier_actions_r2570 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_spare_courier_dispatches_r2570;
CREATE POLICY founder_all ON public.engineer_spare_courier_dispatches_r2570
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.courier_outlier_actions_r2570;
CREATE POLICY founder_all ON public.courier_outlier_actions_r2570
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.engineer_spare_courier_dispatches_r2570
  (dispatched_at, part_sku, part_name, courier_kind, cost_rupees, distance_km, time_to_delivery_hours, outlier_flag, owner_email, status, notes)
VALUES
  ('2026-06-01T09:30:00+05:30'::timestamptz, 'PROBE-CARDIO-7', 'Cardiac probe T7',     'blue_dart',    1850, 420, 18.5, 'none',      'ops@equipseva.in', 'delivered', 'Standard intercity'),
  ('2026-06-04T14:00:00+05:30'::timestamptz, 'BATT-VENT-12',  'Ventilator battery 12V','dtdc',         2100, 380, 36.0, 'slow',      'ops@equipseva.in', 'delivered', 'DTDC slipped on SLA'),
  ('2026-06-08T11:00:00+05:30'::timestamptz, 'BULB-XRAY-3',   'X-ray tube bulb',       'india_post',    320, 510, 96.0, 'slow',      'ops@equipseva.in', 'missed',    'IndiaPost lost route'),
  ('2026-06-12T08:45:00+05:30'::timestamptz, 'CABLE-USG-9',   'USG transducer cable',  'uber_courier', 4500,  18,  2.5, 'expensive', 'ops@equipseva.in', 'delivered', 'Same-city rush; price spike'),
  ('2026-06-18T19:00:00+05:30'::timestamptz, 'GASKET-OT-1',   'OT gasket set',         'in_house',      450,  62,  6.0, 'none',      'ops@equipseva.in', 'delivered', 'Engineer carried in van');

INSERT INTO public.courier_outlier_actions_r2570
  (dispatch_id, action_at, action_kind, outcome, owner_email, status, notes)
VALUES
  ((SELECT id FROM public.engineer_spare_courier_dispatches_r2570 WHERE part_sku='BATT-VENT-12' LIMIT 1),
   '2026-06-06T10:00:00+05:30'::timestamptz, 'courier_switch', 'positive', 'ops@equipseva.in', 'done',  'Moved Vent battery lane to Blue Dart'),
  ((SELECT id FROM public.engineer_spare_courier_dispatches_r2570 WHERE part_sku='BULB-XRAY-3' LIMIT 1),
   '2026-06-10T11:30:00+05:30'::timestamptz, 'refund_chase',   'pending',  'ops@equipseva.in', 'open',  'IndiaPost claim filed'),
  ((SELECT id FROM public.engineer_spare_courier_dispatches_r2570 WHERE part_sku='BULB-XRAY-3' LIMIT 1),
   '2026-06-11T09:00:00+05:30'::timestamptz, 'escalation',     'neutral',  'ops@equipseva.in', 'open',  'Escalated to postmaster general'),
  ((SELECT id FROM public.engineer_spare_courier_dispatches_r2570 WHERE part_sku='CABLE-USG-9' LIMIT 1),
   '2026-06-13T15:00:00+05:30'::timestamptz, 'cost_audit',     'positive', 'ops@equipseva.in', 'done',  'Negotiated Uber Courier flat rate'),
  ((SELECT id FROM public.engineer_spare_courier_dispatches_r2570 WHERE part_sku='PROBE-CARDIO-7' LIMIT 1),
   '2026-06-02T12:00:00+05:30'::timestamptz, 'supplier_review','neutral',  'ops@equipseva.in', 'done',  'Standard QA pass');

-- RPCs
CREATE OR REPLACE FUNCTION public.list_dispatches_r2570()
RETURNS TABLE (
  id uuid, engineer_user_id uuid, dispatched_at timestamptz,
  part_sku text, part_name text, courier_kind text,
  cost_rupees int, distance_km int, time_to_delivery_hours numeric,
  supplier_org_id uuid, outlier_flag text, owner_email text,
  status text, notes text, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, d.dispatched_at,
         d.part_sku, d.part_name, d.courier_kind,
         d.cost_rupees, d.distance_km, d.time_to_delivery_hours,
         d.supplier_org_id, d.outlier_flag, d.owner_email,
         d.status, d.notes, d.created_at
  FROM public.engineer_spare_courier_dispatches_r2570 d
  ORDER BY d.dispatched_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_dispatches_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dispatches_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outlier_actions_r2570()
RETURNS TABLE (
  id uuid, dispatch_id uuid, part_sku text, part_name text,
  action_at timestamptz, action_kind text, outcome text,
  owner_email text, status text, notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.dispatch_id, d.part_sku, d.part_name,
         a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.courier_outlier_actions_r2570 a
  JOIN public.engineer_spare_courier_dispatches_r2570 d ON d.id = a.dispatch_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outlier_actions_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outlier_actions_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_cost_couriers_r2570()
RETURNS TABLE (
  courier_kind text, dispatches bigint,
  total_cost_rupees bigint, avg_cost_rupees numeric,
  avg_distance_km numeric, avg_ttd_hours numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.courier_kind, COUNT(*)::bigint,
         SUM(d.cost_rupees)::bigint,
         ROUND(AVG(d.cost_rupees)::numeric, 2),
         ROUND(AVG(d.distance_km)::numeric, 2),
         ROUND(AVG(d.time_to_delivery_hours)::numeric, 2)
  FROM public.engineer_spare_courier_dispatches_r2570 d
  GROUP BY d.courier_kind
  ORDER BY SUM(d.cost_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_cost_couriers_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cost_couriers_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.courier_kind_summary_r2570()
RETURNS TABLE (
  courier_kind text, dispatches bigint,
  delivered_cnt bigint, missed_cnt bigint,
  disputed_cnt bigint, returned_cnt bigint,
  avg_ttd_hours numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.courier_kind, COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE d.status='delivered')::bigint,
         COUNT(*) FILTER (WHERE d.status='missed')::bigint,
         COUNT(*) FILTER (WHERE d.status='disputed')::bigint,
         COUNT(*) FILTER (WHERE d.status='returned')::bigint,
         ROUND(AVG(d.time_to_delivery_hours)::numeric, 2)
  FROM public.engineer_spare_courier_dispatches_r2570 d
  GROUP BY d.courier_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.courier_kind_summary_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.courier_kind_summary_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.outlier_flag_distribution_r2570()
RETURNS TABLE (
  outlier_flag text, cnt bigint,
  total_cost_rupees bigint, avg_ttd_hours numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.outlier_flag, COUNT(*)::bigint,
         SUM(d.cost_rupees)::bigint,
         ROUND(AVG(d.time_to_delivery_hours)::numeric, 2)
  FROM public.engineer_spare_courier_dispatches_r2570 d
  GROUP BY d.outlier_flag
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.outlier_flag_distribution_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outlier_flag_distribution_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_cost_trend_r2570()
RETURNS TABLE (
  month_label text, dispatches bigint,
  total_cost_rupees bigint, avg_cost_rupees numeric,
  avg_ttd_hours numeric, outlier_cnt bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(d.dispatched_at, 'YYYY-MM') AS month_label,
         COUNT(*)::bigint,
         SUM(d.cost_rupees)::bigint,
         ROUND(AVG(d.cost_rupees)::numeric, 2),
         ROUND(AVG(d.time_to_delivery_hours)::numeric, 2),
         COUNT(*) FILTER (WHERE d.outlier_flag <> 'none')::bigint
  FROM public.engineer_spare_courier_dispatches_r2570 d
  GROUP BY to_char(d.dispatched_at, 'YYYY-MM')
  ORDER BY to_char(d.dispatched_at, 'YYYY-MM') ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_cost_trend_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_cost_trend_r2570() TO authenticated;

CREATE OR REPLACE FUNCTION public.supplier_courier_breakdown_r2570()
RETURNS TABLE (
  supplier_org_id uuid, courier_kind text,
  dispatches bigint, total_cost_rupees bigint,
  avg_ttd_hours numeric, outlier_cnt bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.supplier_org_id, d.courier_kind,
         COUNT(*)::bigint,
         SUM(d.cost_rupees)::bigint,
         ROUND(AVG(d.time_to_delivery_hours)::numeric, 2),
         COUNT(*) FILTER (WHERE d.outlier_flag <> 'none')::bigint
  FROM public.engineer_spare_courier_dispatches_r2570 d
  GROUP BY d.supplier_org_id, d.courier_kind
  ORDER BY SUM(d.cost_rupees) DESC, COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.supplier_courier_breakdown_r2570() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supplier_courier_breakdown_r2570() TO authenticated;
