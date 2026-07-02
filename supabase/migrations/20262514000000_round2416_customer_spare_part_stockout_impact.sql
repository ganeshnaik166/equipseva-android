-- Round 2416 — Customer Spare Part Stockout Impact
-- Track stockouts, downtime, SLO breaches, customer escalations, supplier accountability.

BEGIN;

-- ============================================================================
-- TABLE: spare_stockouts_r2416
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.spare_stockouts_r2416 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  part_name text NOT NULL,
  part_sku text NOT NULL,
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  stockout_started_at timestamptz NOT NULL DEFAULT now(),
  stockout_resolved_at timestamptz,
  downtime_minutes integer NOT NULL DEFAULT 0 CHECK (downtime_minutes >= 0),
  slo_breached boolean NOT NULL DEFAULT false,
  customer_escalation_kind text NOT NULL DEFAULT 'none' CHECK (customer_escalation_kind IN ('none','email','call','portal','exec')),
  refund_required_rupees integer NOT NULL DEFAULT 0 CHECK (refund_required_rupees >= 0),
  refund_paid_rupees integer NOT NULL DEFAULT 0 CHECK (refund_paid_rupees >= 0),
  notes text
);

ALTER TABLE public.spare_stockouts_r2416 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.spare_stockouts_r2416
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: stockout_supplier_scorecard_r2416
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.stockout_supplier_scorecard_r2416 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  supplier_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  supplier_name text NOT NULL,
  stockouts_30d integer NOT NULL DEFAULT 0 CHECK (stockouts_30d >= 0),
  total_downtime_minutes_30d integer NOT NULL DEFAULT 0 CHECK (total_downtime_minutes_30d >= 0),
  slo_breaches_30d integer NOT NULL DEFAULT 0 CHECK (slo_breaches_30d >= 0),
  avg_resolution_hours numeric(8,2) NOT NULL DEFAULT 0 CHECK (avg_resolution_hours >= 0),
  refund_owed_rupees integer NOT NULL DEFAULT 0 CHECK (refund_owed_rupees >= 0),
  refund_paid_rupees integer NOT NULL DEFAULT 0 CHECK (refund_paid_rupees >= 0),
  last_stockout_at timestamptz,
  action_taken text
);

ALTER TABLE public.stockout_supplier_scorecard_r2416 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.stockout_supplier_scorecard_r2416
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_stockouts_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_stockouts_r2416()
RETURNS TABLE (
  id uuid,
  part_name text,
  part_sku text,
  supplier_org_id uuid,
  hospital_user_id uuid,
  equipment_label text,
  stockout_started_at timestamptz,
  stockout_resolved_at timestamptz,
  downtime_minutes integer,
  slo_breached boolean,
  customer_escalation_kind text,
  refund_required_rupees integer,
  refund_paid_rupees integer,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.part_name, s.part_sku, s.supplier_org_id, s.hospital_user_id,
           s.equipment_label, s.stockout_started_at, s.stockout_resolved_at,
           s.downtime_minutes, s.slo_breached, s.customer_escalation_kind,
           s.refund_required_rupees, s.refund_paid_rupees, s.notes
      FROM public.spare_stockouts_r2416 s
      ORDER BY s.stockout_started_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_stockouts_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stockouts_r2416() TO authenticated;

-- ============================================================================
-- RPC: supplier_scorecard_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.supplier_scorecard_r2416()
RETURNS TABLE (
  id uuid,
  supplier_org_id uuid,
  supplier_name text,
  stockouts_30d integer,
  total_downtime_minutes_30d integer,
  slo_breaches_30d integer,
  avg_resolution_hours numeric,
  refund_owed_rupees integer,
  refund_paid_rupees integer,
  last_stockout_at timestamptz,
  action_taken text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.supplier_org_id, c.supplier_name, c.stockouts_30d,
           c.total_downtime_minutes_30d, c.slo_breaches_30d, c.avg_resolution_hours,
           c.refund_owed_rupees, c.refund_paid_rupees, c.last_stockout_at, c.action_taken
      FROM public.stockout_supplier_scorecard_r2416 c
      ORDER BY c.total_downtime_minutes_30d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.supplier_scorecard_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supplier_scorecard_r2416() TO authenticated;

-- ============================================================================
-- RPC: top_offending_suppliers_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_offending_suppliers_r2416()
RETURNS TABLE (
  supplier_name text,
  stockout_count bigint,
  total_downtime_minutes bigint,
  slo_breach_count bigint,
  refund_required_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(c.supplier_name, 'Unknown') AS supplier_name,
           COUNT(*)::bigint AS stockout_count,
           COALESCE(SUM(s.downtime_minutes),0)::bigint AS total_downtime_minutes,
           COALESCE(SUM(CASE WHEN s.slo_breached THEN 1 ELSE 0 END),0)::bigint AS slo_breach_count,
           COALESCE(SUM(s.refund_required_rupees),0)::bigint AS refund_required_rupees
      FROM public.spare_stockouts_r2416 s
      LEFT JOIN public.stockout_supplier_scorecard_r2416 c
        ON c.supplier_org_id = s.supplier_org_id
     GROUP BY COALESCE(c.supplier_name, 'Unknown')
     ORDER BY total_downtime_minutes DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_offending_suppliers_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_offending_suppliers_r2416() TO authenticated;

-- ============================================================================
-- RPC: top_impacted_hospitals_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_impacted_hospitals_r2416()
RETURNS TABLE (
  hospital_user_id uuid,
  stockout_count bigint,
  total_downtime_minutes bigint,
  slo_breach_count bigint,
  exec_escalations bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.hospital_user_id,
           COUNT(*)::bigint AS stockout_count,
           COALESCE(SUM(s.downtime_minutes),0)::bigint AS total_downtime_minutes,
           COALESCE(SUM(CASE WHEN s.slo_breached THEN 1 ELSE 0 END),0)::bigint AS slo_breach_count,
           COALESCE(SUM(CASE WHEN s.customer_escalation_kind = 'exec' THEN 1 ELSE 0 END),0)::bigint AS exec_escalations
      FROM public.spare_stockouts_r2416 s
     WHERE s.hospital_user_id IS NOT NULL
     GROUP BY s.hospital_user_id
     ORDER BY total_downtime_minutes DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_impacted_hospitals_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_impacted_hospitals_r2416() TO authenticated;

-- ============================================================================
-- RPC: refund_balance_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.refund_balance_r2416()
RETURNS TABLE (
  total_refund_required_rupees bigint,
  total_refund_paid_rupees bigint,
  total_refund_outstanding_rupees bigint,
  stockouts_with_refund bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(SUM(s.refund_required_rupees),0)::bigint AS total_refund_required_rupees,
           COALESCE(SUM(s.refund_paid_rupees),0)::bigint AS total_refund_paid_rupees,
           COALESCE(SUM(s.refund_required_rupees - s.refund_paid_rupees),0)::bigint AS total_refund_outstanding_rupees,
           COUNT(*) FILTER (WHERE s.refund_required_rupees > 0)::bigint AS stockouts_with_refund
      FROM public.spare_stockouts_r2416 s;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refund_balance_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refund_balance_r2416() TO authenticated;

-- ============================================================================
-- RPC: monthly_downtime_trend_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_downtime_trend_r2416()
RETURNS TABLE (
  month_start date,
  stockout_count bigint,
  total_downtime_minutes bigint,
  slo_breach_count bigint,
  refund_required_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', s.stockout_started_at)::date AS month_start,
           COUNT(*)::bigint AS stockout_count,
           COALESCE(SUM(s.downtime_minutes),0)::bigint AS total_downtime_minutes,
           COALESCE(SUM(CASE WHEN s.slo_breached THEN 1 ELSE 0 END),0)::bigint AS slo_breach_count,
           COALESCE(SUM(s.refund_required_rupees),0)::bigint AS refund_required_rupees
      FROM public.spare_stockouts_r2416 s
     GROUP BY date_trunc('month', s.stockout_started_at)::date
     ORDER BY month_start DESC
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_downtime_trend_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_downtime_trend_r2416() TO authenticated;

-- ============================================================================
-- RPC: escalation_breakdown_r2416
-- ============================================================================
CREATE OR REPLACE FUNCTION public.escalation_breakdown_r2416()
RETURNS TABLE (
  customer_escalation_kind text,
  stockout_count bigint,
  total_downtime_minutes bigint,
  total_refund_required_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.customer_escalation_kind,
           COUNT(*)::bigint AS stockout_count,
           COALESCE(SUM(s.downtime_minutes),0)::bigint AS total_downtime_minutes,
           COALESCE(SUM(s.refund_required_rupees),0)::bigint AS total_refund_required_rupees
      FROM public.spare_stockouts_r2416 s
     GROUP BY s.customer_escalation_kind
     ORDER BY stockout_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.escalation_breakdown_r2416() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escalation_breakdown_r2416() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.spare_stockouts_r2416 (part_name, part_sku, equipment_label, stockout_started_at, stockout_resolved_at, downtime_minutes, slo_breached, customer_escalation_kind, refund_required_rupees, refund_paid_rupees, notes)
VALUES
  ('Ultrasound probe cable','USC-7L4','Philips Affiniti 50', now() - interval '20 days', now() - interval '18 days', 2880, true, 'exec', 25000, 25000, 'Apollo Hyd; exec escalation; refund paid in full'),
  ('X-ray tube head','XRT-525','Siemens Multix Fusion', now() - interval '15 days', now() - interval '13 days', 2160, true, 'call', 15000, 0, 'KIMS Sec; refund pending'),
  ('CT cooling fan','CT-FAN-128','GE Revolution EVO', now() - interval '8 days', now() - interval '7 days', 720, false, 'email', 0, 0, 'Within SLO; goodwill credit only'),
  ('MRI helium sensor','MRI-HE-3T','Siemens Magnetom Vida', now() - interval '5 days', NULL, 6000, true, 'portal', 40000, 10000, 'Open; partial refund issued'),
  ('Dialysis dialyzer','DLZ-F8','Fresenius 4008S', now() - interval '2 days', now() - interval '1 day', 1200, false, 'none', 0, 0, 'Resolved next-day; no escalation');

INSERT INTO public.stockout_supplier_scorecard_r2416 (supplier_name, stockouts_30d, total_downtime_minutes_30d, slo_breaches_30d, avg_resolution_hours, refund_owed_rupees, refund_paid_rupees, last_stockout_at, action_taken)
VALUES
  ('Philips Healthcare India', 3, 4320, 2, 36.5, 25000, 25000, now() - interval '20 days', 'AVL review; backup supplier added'),
  ('Siemens Healthineers', 4, 8160, 3, 42.0, 55000, 10000, now() - interval '5 days', 'Penalty clause invoked; refund schedule agreed'),
  ('GE HealthCare', 1, 720, 0, 12.0, 0, 0, now() - interval '8 days', 'Goodwill credit; no further action'),
  ('Fresenius Medical Care', 2, 1980, 0, 16.5, 0, 0, now() - interval '2 days', 'On watchlist; quarterly review scheduled');

