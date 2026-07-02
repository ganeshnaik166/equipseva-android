-- Round 2444: customer-spare-parts-just-in-time-watch
-- Hospital spare part JIT watch: consumption rate, stock days remaining, auto-reorder, supplier fulfillment.

BEGIN;

-- Table 1: spare_stock_levels_r2444
CREATE TABLE IF NOT EXISTS public.spare_stock_levels_r2444 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  part_sku text NOT NULL,
  part_name text NOT NULL,
  on_hand_count int NOT NULL DEFAULT 0 CHECK (on_hand_count >= 0),
  consumption_per_week int NOT NULL DEFAULT 0 CHECK (consumption_per_week >= 0),
  stock_days_remaining int NOT NULL DEFAULT 0 CHECK (stock_days_remaining >= 0),
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  reorder_threshold_count int NOT NULL DEFAULT 0 CHECK (reorder_threshold_count >= 0),
  auto_reorder_enabled boolean NOT NULL DEFAULT false,
  reorder_status text NOT NULL DEFAULT 'none' CHECK (reorder_status IN ('none','triggered','in_transit','delivered','cancelled')),
  last_reorder_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_spare_stock_r2444_hospital ON public.spare_stock_levels_r2444(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_spare_stock_r2444_supplier ON public.spare_stock_levels_r2444(supplier_org_id);
CREATE INDEX IF NOT EXISTS idx_spare_stock_r2444_status ON public.spare_stock_levels_r2444(reorder_status);

ALTER TABLE public.spare_stock_levels_r2444 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.spare_stock_levels_r2444;
CREATE POLICY founder_all ON public.spare_stock_levels_r2444 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Table 2: spare_reorder_history_r2444
CREATE TABLE IF NOT EXISTS public.spare_reorder_history_r2444 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_id uuid NOT NULL REFERENCES public.spare_stock_levels_r2444(id) ON DELETE CASCADE,
  ordered_at timestamptz NOT NULL DEFAULT now(),
  ordered_qty int NOT NULL CHECK (ordered_qty > 0),
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  fulfilled_at timestamptz,
  days_to_fulfill int CHECK (days_to_fulfill IS NULL OR days_to_fulfill >= 0),
  fulfillment_status text NOT NULL DEFAULT 'pending' CHECK (fulfillment_status IN ('pending','in_transit','delivered','cancelled')),
  cost_rupees int CHECK (cost_rupees IS NULL OR cost_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_spare_reorder_r2444_stock ON public.spare_reorder_history_r2444(stock_id);
CREATE INDEX IF NOT EXISTS idx_spare_reorder_r2444_supplier ON public.spare_reorder_history_r2444(supplier_org_id);
CREATE INDEX IF NOT EXISTS idx_spare_reorder_r2444_status ON public.spare_reorder_history_r2444(fulfillment_status);

ALTER TABLE public.spare_reorder_history_r2444 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.spare_reorder_history_r2444;
CREATE POLICY founder_all ON public.spare_reorder_history_r2444 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_supplier1 uuid;
  v_supplier2 uuid;
  v_stock1 uuid;
  v_stock2 uuid;
  v_stock3 uuid;
  v_stock4 uuid;
  v_stock5 uuid;
BEGIN
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_hosp1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_hosp1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_hosp2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  IF v_hosp1 IS NULL THEN
    SELECT id INTO v_hosp1 FROM public.profiles ORDER BY created_at LIMIT 1;
  END IF;
  IF v_hosp2 IS NULL THEN v_hosp2 := v_hosp1; END IF;
  IF v_hosp3 IS NULL THEN v_hosp3 := v_hosp1; END IF;

  SELECT id INTO v_supplier1 FROM public.organizations ORDER BY created_at LIMIT 1;
  SELECT id INTO v_supplier2 FROM public.organizations WHERE id <> COALESCE(v_supplier1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  IF v_supplier2 IS NULL THEN v_supplier2 := v_supplier1; END IF;

  IF v_hosp1 IS NULL OR v_supplier1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.spare_stock_levels_r2444(hospital_user_id, part_sku, part_name, on_hand_count, consumption_per_week, stock_days_remaining, supplier_org_id, reorder_threshold_count, auto_reorder_enabled, reorder_status, last_reorder_at, notes)
  VALUES (v_hosp1, 'SKU-XRAY-FILM-A4', 'X-Ray Film A4 200ct', 12, 30, 3, v_supplier1, 20, true, 'triggered', now() - interval '1 day', 'Below threshold; auto-reorder fired')
  RETURNING id INTO v_stock1;

  INSERT INTO public.spare_stock_levels_r2444(hospital_user_id, part_sku, part_name, on_hand_count, consumption_per_week, stock_days_remaining, supplier_org_id, reorder_threshold_count, auto_reorder_enabled, reorder_status, last_reorder_at, notes)
  VALUES (v_hosp2, 'SKU-ECG-PAPER', 'ECG Thermal Paper Roll', 45, 14, 22, v_supplier2, 25, true, 'none', NULL, 'Healthy stock')
  RETURNING id INTO v_stock2;

  INSERT INTO public.spare_stock_levels_r2444(hospital_user_id, part_sku, part_name, on_hand_count, consumption_per_week, stock_days_remaining, supplier_org_id, reorder_threshold_count, auto_reorder_enabled, reorder_status, last_reorder_at, notes)
  VALUES (v_hosp3, 'SKU-VENT-FILTER', 'Ventilator Bacterial Filter', 6, 21, 2, v_supplier1, 15, false, 'none', NULL, 'CRITICAL: manual reorder required')
  RETURNING id INTO v_stock3;

  INSERT INTO public.spare_stock_levels_r2444(hospital_user_id, part_sku, part_name, on_hand_count, consumption_per_week, stock_days_remaining, supplier_org_id, reorder_threshold_count, auto_reorder_enabled, reorder_status, last_reorder_at, notes)
  VALUES (v_hosp1, 'SKU-DIAL-TUBING', 'Dialysis Tubing Set', 80, 40, 14, v_supplier2, 50, true, 'in_transit', now() - interval '3 days', 'In transit; ETA 2 days')
  RETURNING id INTO v_stock4;

  INSERT INTO public.spare_stock_levels_r2444(hospital_user_id, part_sku, part_name, on_hand_count, consumption_per_week, stock_days_remaining, supplier_org_id, reorder_threshold_count, auto_reorder_enabled, reorder_status, last_reorder_at, notes)
  VALUES (v_hosp2, 'SKU-INFUSION-PUMP-CART', 'Infusion Pump Cartridge', 200, 50, 28, v_supplier1, 75, true, 'delivered', now() - interval '7 days', 'Restocked last week')
  RETURNING id INTO v_stock5;

  INSERT INTO public.spare_reorder_history_r2444(stock_id, ordered_at, ordered_qty, supplier_org_id, fulfilled_at, days_to_fulfill, fulfillment_status, cost_rupees, notes)
  VALUES
    (v_stock1, now() - interval '1 day', 100, v_supplier1, NULL, NULL, 'pending', 12000, 'Auto-reorder fired'),
    (v_stock4, now() - interval '3 days', 50, v_supplier2, NULL, NULL, 'in_transit', 18500, 'Tracking #LOG-44521'),
    (v_stock5, now() - interval '14 days', 150, v_supplier1, now() - interval '7 days', 7, 'delivered', 67500, 'On-time delivery'),
    (v_stock2, now() - interval '30 days', 60, v_supplier2, now() - interval '24 days', 6, 'delivered', 8400, 'Routine'),
    (v_stock3, now() - interval '60 days', 30, v_supplier1, NULL, NULL, 'cancelled', 0, 'Cancelled by hospital');
END $seed$;

-- RPC 1: list_stock_levels_r2444
CREATE OR REPLACE FUNCTION public.list_stock_levels_r2444()
RETURNS TABLE (
  id uuid,
  part_sku text,
  part_name text,
  on_hand_count int,
  consumption_per_week int,
  stock_days_remaining int,
  reorder_threshold_count int,
  auto_reorder_enabled boolean,
  reorder_status text,
  last_reorder_at timestamptz,
  hospital_email text,
  supplier_name text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.part_sku, s.part_name, s.on_hand_count, s.consumption_per_week,
         s.stock_days_remaining, s.reorder_threshold_count, s.auto_reorder_enabled,
         s.reorder_status, s.last_reorder_at,
         p.email AS hospital_email,
         o.name AS supplier_name,
         s.created_at
  FROM public.spare_stock_levels_r2444 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = s.supplier_org_id
  ORDER BY s.stock_days_remaining ASC, s.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_stock_levels_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stock_levels_r2444() TO authenticated;

-- RPC 2: list_reorder_history_r2444
CREATE OR REPLACE FUNCTION public.list_reorder_history_r2444()
RETURNS TABLE (
  id uuid,
  part_sku text,
  part_name text,
  ordered_at timestamptz,
  ordered_qty int,
  fulfilled_at timestamptz,
  days_to_fulfill int,
  fulfillment_status text,
  cost_rupees int,
  supplier_name text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, s.part_sku, s.part_name, h.ordered_at, h.ordered_qty,
         h.fulfilled_at, h.days_to_fulfill, h.fulfillment_status,
         h.cost_rupees,
         o.name AS supplier_name,
         h.created_at
  FROM public.spare_reorder_history_r2444 h
  JOIN public.spare_stock_levels_r2444 s ON s.id = h.stock_id
  LEFT JOIN public.organizations o ON o.id = h.supplier_org_id
  ORDER BY h.ordered_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_reorder_history_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reorder_history_r2444() TO authenticated;

-- RPC 3: urgent_reorders_r2444 (stock_days_remaining <= 7)
CREATE OR REPLACE FUNCTION public.urgent_reorders_r2444()
RETURNS TABLE (
  id uuid,
  part_sku text,
  part_name text,
  on_hand_count int,
  stock_days_remaining int,
  auto_reorder_enabled boolean,
  reorder_status text,
  hospital_email text,
  supplier_name text,
  urgency text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.part_sku, s.part_name, s.on_hand_count, s.stock_days_remaining,
         s.auto_reorder_enabled, s.reorder_status,
         p.email AS hospital_email,
         o.name AS supplier_name,
         CASE
           WHEN s.stock_days_remaining <= 3 THEN 'critical'
           WHEN s.stock_days_remaining <= 7 THEN 'high'
           ELSE 'medium'
         END AS urgency
  FROM public.spare_stock_levels_r2444 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = s.supplier_org_id
  WHERE s.stock_days_remaining <= 7
  ORDER BY s.stock_days_remaining ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.urgent_reorders_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.urgent_reorders_r2444() TO authenticated;

-- RPC 4: supplier_fulfillment_summary_r2444
CREATE OR REPLACE FUNCTION public.supplier_fulfillment_summary_r2444()
RETURNS TABLE (
  supplier_org_id uuid,
  supplier_name text,
  total_orders bigint,
  delivered_count bigint,
  pending_count bigint,
  in_transit_count bigint,
  cancelled_count bigint,
  avg_days_to_fulfill numeric,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.supplier_org_id,
         o.name AS supplier_name,
         COUNT(*)::bigint AS total_orders,
         COUNT(*) FILTER (WHERE h.fulfillment_status = 'delivered')::bigint AS delivered_count,
         COUNT(*) FILTER (WHERE h.fulfillment_status = 'pending')::bigint AS pending_count,
         COUNT(*) FILTER (WHERE h.fulfillment_status = 'in_transit')::bigint AS in_transit_count,
         COUNT(*) FILTER (WHERE h.fulfillment_status = 'cancelled')::bigint AS cancelled_count,
         ROUND(AVG(h.days_to_fulfill) FILTER (WHERE h.days_to_fulfill IS NOT NULL), 2) AS avg_days_to_fulfill,
         COALESCE(SUM(h.cost_rupees), 0)::bigint AS total_cost_rupees
  FROM public.spare_reorder_history_r2444 h
  LEFT JOIN public.organizations o ON o.id = h.supplier_org_id
  GROUP BY h.supplier_org_id, o.name
  ORDER BY total_orders DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.supplier_fulfillment_summary_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supplier_fulfillment_summary_r2444() TO authenticated;

-- RPC 5: top_consuming_hospitals_r2444
CREATE OR REPLACE FUNCTION public.top_consuming_hospitals_r2444()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  total_skus bigint,
  total_weekly_consumption bigint,
  urgent_skus bigint,
  auto_enabled_skus bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.hospital_user_id,
         p.email AS hospital_email,
         COUNT(*)::bigint AS total_skus,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption,
         COUNT(*) FILTER (WHERE s.stock_days_remaining <= 7)::bigint AS urgent_skus,
         COUNT(*) FILTER (WHERE s.auto_reorder_enabled = true)::bigint AS auto_enabled_skus
  FROM public.spare_stock_levels_r2444 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  GROUP BY s.hospital_user_id, p.email
  ORDER BY total_weekly_consumption DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_consuming_hospitals_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_consuming_hospitals_r2444() TO authenticated;

-- RPC 6: auto_reorder_summary_r2444
CREATE OR REPLACE FUNCTION public.auto_reorder_summary_r2444()
RETURNS TABLE (
  bucket text,
  sku_count bigint,
  total_on_hand bigint,
  total_weekly_consumption bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'auto_enabled'::text AS bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.on_hand_count), 0)::bigint AS total_on_hand,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption
  FROM public.spare_stock_levels_r2444 s
  WHERE s.auto_reorder_enabled = true
  UNION ALL
  SELECT 'manual_only'::text AS bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.on_hand_count), 0)::bigint AS total_on_hand,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption
  FROM public.spare_stock_levels_r2444 s
  WHERE s.auto_reorder_enabled = false
  UNION ALL
  SELECT 'triggered'::text AS bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.on_hand_count), 0)::bigint AS total_on_hand,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption
  FROM public.spare_stock_levels_r2444 s
  WHERE s.reorder_status = 'triggered'
  UNION ALL
  SELECT 'in_transit'::text AS bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.on_hand_count), 0)::bigint AS total_on_hand,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption
  FROM public.spare_stock_levels_r2444 s
  WHERE s.reorder_status = 'in_transit';
END $$;
REVOKE EXECUTE ON FUNCTION public.auto_reorder_summary_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_reorder_summary_r2444() TO authenticated;

-- RPC 7: weekly_stockout_risk_r2444
CREATE OR REPLACE FUNCTION public.weekly_stockout_risk_r2444()
RETURNS TABLE (
  risk_bucket text,
  sku_count bigint,
  total_weekly_consumption bigint,
  auto_enabled_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'critical_le_3_days'::text AS risk_bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption,
         COUNT(*) FILTER (WHERE s.auto_reorder_enabled = true)::bigint AS auto_enabled_count
  FROM public.spare_stock_levels_r2444 s
  WHERE s.stock_days_remaining <= 3
  UNION ALL
  SELECT 'high_4_to_7_days'::text AS risk_bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption,
         COUNT(*) FILTER (WHERE s.auto_reorder_enabled = true)::bigint AS auto_enabled_count
  FROM public.spare_stock_levels_r2444 s
  WHERE s.stock_days_remaining BETWEEN 4 AND 7
  UNION ALL
  SELECT 'medium_8_to_14_days'::text AS risk_bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption,
         COUNT(*) FILTER (WHERE s.auto_reorder_enabled = true)::bigint AS auto_enabled_count
  FROM public.spare_stock_levels_r2444 s
  WHERE s.stock_days_remaining BETWEEN 8 AND 14
  UNION ALL
  SELECT 'healthy_gt_14_days'::text AS risk_bucket,
         COUNT(*)::bigint AS sku_count,
         COALESCE(SUM(s.consumption_per_week), 0)::bigint AS total_weekly_consumption,
         COUNT(*) FILTER (WHERE s.auto_reorder_enabled = true)::bigint AS auto_enabled_count
  FROM public.spare_stock_levels_r2444 s
  WHERE s.stock_days_remaining > 14;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_stockout_risk_r2444() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_stockout_risk_r2444() TO authenticated;

