BEGIN;

-- ============================================================
-- Round 2676: Customer Quarterly Equipment ROI Justification
-- ============================================================

-- Drop tables if exist (round-suffixed)
DROP TABLE IF EXISTS public.customer_equipment_roi_records_r2676 CASCADE;
DROP TABLE IF EXISTS public.customer_equipment_roi_decisions_r2676 CASCADE;

-- ----------------------------------------------------------
-- Table 1: equipment ROI per quarter per customer
-- ----------------------------------------------------------
CREATE TABLE public.customer_equipment_roi_records_r2676 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  equipment_label text NOT NULL,
  equipment_category text NOT NULL,
  fiscal_quarter text NOT NULL,
  purchase_cost_rupees bigint NOT NULL,
  amc_cost_rupees bigint NOT NULL DEFAULT 0,
  repair_cost_rupees bigint NOT NULL DEFAULT 0,
  utilization_hours int NOT NULL DEFAULT 0,
  utilization_target_hours int NOT NULL DEFAULT 1,
  revenue_generated_rupees bigint NOT NULL DEFAULT 0,
  procedures_count int NOT NULL DEFAULT 0,
  downtime_hours int NOT NULL DEFAULT 0,
  roi_percent numeric(8,2) NOT NULL DEFAULT 0,
  payback_months numeric(6,2),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_equipment_roi_records_r2676 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_equipment_roi_records_r2676;
CREATE POLICY founder_all ON public.customer_equipment_roi_records_r2676
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------
-- Table 2: keep / replace / divest decisions
-- ----------------------------------------------------------
CREATE TABLE public.customer_equipment_roi_decisions_r2676 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roi_record_id uuid NOT NULL REFERENCES public.customer_equipment_roi_records_r2676(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('keep','upgrade','replace','divest','review')),
  decided_by_role text NOT NULL,
  rationale text NOT NULL,
  estimated_savings_rupees bigint NOT NULL DEFAULT 0,
  effective_from date NOT NULL DEFAULT current_date,
  approval_status text NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected','implemented')),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_equipment_roi_decisions_r2676 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_equipment_roi_decisions_r2676;
CREATE POLICY founder_all ON public.customer_equipment_roi_decisions_r2676
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------
-- Seed data: ROI records
-- ----------------------------------------------------------
INSERT INTO public.customer_equipment_roi_records_r2676
  (customer_org_name, equipment_label, equipment_category, fiscal_quarter,
   purchase_cost_rupees, amc_cost_rupees, repair_cost_rupees,
   utilization_hours, utilization_target_hours, revenue_generated_rupees,
   procedures_count, downtime_hours, roi_percent, payback_months)
VALUES
  ('Apollo Hyderabad', 'Siemens MRI 1.5T', 'imaging', 'Q1-FY27', 35000000, 850000, 220000, 640, 720, 18500000, 412, 18, 51.5, 22.4),
  ('Yashoda Secunderabad', 'Philips CT 128-slice', 'imaging', 'Q1-FY27', 22000000, 620000, 180000, 580, 720, 11200000, 388, 32, 49.6, 24.1),
  ('KIMS Kondapur', 'Mindray Anesthesia Workstation', 'surgical', 'Q1-FY27', 1800000, 95000, 42000, 320, 480, 1450000, 156, 12, 75.8, 14.8),
  ('Continental Gachibowli', 'GE Cath Lab Innova', 'cardiac', 'Q1-FY27', 48000000, 1450000, 380000, 450, 720, 14800000, 142, 56, 29.5, 38.6),
  ('Sunshine Begumpet', 'Stryker Endoscopy Tower', 'surgical', 'Q1-FY27', 950000, 48000, 18000, 280, 480, 880000, 198, 8, 84.1, 13.0),
  ('Aware Gleneagles', 'Hologic Mammography Unit', 'imaging', 'Q1-FY27', 8500000, 220000, 95000, 220, 480, 2900000, 184, 24, 32.4, 35.2);

-- ----------------------------------------------------------
-- Seed data: ROI decisions
-- ----------------------------------------------------------
INSERT INTO public.customer_equipment_roi_decisions_r2676
  (roi_record_id, decision, decided_by_role, rationale, estimated_savings_rupees, effective_from, approval_status)
SELECT id, 'keep', 'biomedical-head', 'Strong utilization >85% of target; ROI above 50% threshold', 0, current_date, 'approved'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='Apollo Hyderabad'
UNION ALL
SELECT id, 'upgrade', 'cfo', 'Demand exceeds capacity; upgrade to 256-slice projected payback 18mo', 4800000, current_date, 'pending'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='Yashoda Secunderabad'
UNION ALL
SELECT id, 'keep', 'biomedical-head', 'High utilization, healthy ROI, low downtime', 0, current_date, 'approved'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='KIMS Kondapur'
UNION ALL
SELECT id, 'review', 'cfo', 'Low utilization (62%) high downtime; review service contract', 1200000, current_date, 'pending'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='Continental Gachibowli'
UNION ALL
SELECT id, 'keep', 'biomedical-head', 'Compact unit, top ROI, minimal downtime', 0, current_date, 'approved'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='Sunshine Begumpet'
UNION ALL
SELECT id, 'divest', 'cfo', 'Underutilized (46%); refer cases to partner radiology center', 2400000, current_date, 'pending'
  FROM public.customer_equipment_roi_records_r2676 WHERE customer_org_name='Aware Gleneagles';

-- ============================================================
-- RPC FUNCTIONS (7+)
-- ============================================================

-- RPC 1: Portfolio overview KPIs
DROP FUNCTION IF EXISTS public.roi_r2676_portfolio_kpis();
CREATE OR REPLACE FUNCTION public.roi_r2676_portfolio_kpis()
RETURNS TABLE(
  total_equipment int,
  total_invested_rupees bigint,
  total_revenue_rupees bigint,
  weighted_roi_percent numeric,
  avg_utilization_percent numeric,
  underperformers int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(purchase_cost_rupees),0)::bigint,
    COALESCE(SUM(revenue_generated_rupees),0)::bigint,
    ROUND(AVG(roi_percent),2),
    ROUND(AVG(utilization_hours::numeric*100/NULLIF(utilization_target_hours,0)),2),
    COUNT(*) FILTER (WHERE roi_percent < 40)::int
  FROM public.customer_equipment_roi_records_r2676;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_portfolio_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_portfolio_kpis() TO authenticated;

-- RPC 2: Equipment list by ROI desc
DROP FUNCTION IF EXISTS public.roi_r2676_list_by_roi();
CREATE OR REPLACE FUNCTION public.roi_r2676_list_by_roi()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  equipment_label text,
  equipment_category text,
  fiscal_quarter text,
  purchase_cost_rupees bigint,
  revenue_generated_rupees bigint,
  roi_percent numeric,
  utilization_percent numeric,
  payback_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_org_name, r.equipment_label, r.equipment_category,
         r.fiscal_quarter, r.purchase_cost_rupees, r.revenue_generated_rupees,
         r.roi_percent,
         ROUND(r.utilization_hours::numeric*100/NULLIF(r.utilization_target_hours,0),2),
         r.payback_months
  FROM public.customer_equipment_roi_records_r2676 r
  ORDER BY r.roi_percent DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_list_by_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_list_by_roi() TO authenticated;

-- RPC 3: Category ROI rollup
DROP FUNCTION IF EXISTS public.roi_r2676_category_rollup();
CREATE OR REPLACE FUNCTION public.roi_r2676_category_rollup()
RETURNS TABLE(
  equipment_category text,
  units int,
  invested_rupees bigint,
  revenue_rupees bigint,
  avg_roi_percent numeric,
  avg_downtime_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_category, COUNT(*)::int,
         SUM(r.purchase_cost_rupees)::bigint,
         SUM(r.revenue_generated_rupees)::bigint,
         ROUND(AVG(r.roi_percent),2),
         ROUND(AVG(r.downtime_hours),2)
  FROM public.customer_equipment_roi_records_r2676 r
  GROUP BY r.equipment_category
  ORDER BY AVG(r.roi_percent) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_category_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_category_rollup() TO authenticated;

-- RPC 4: Underperformers (ROI < 40%)
DROP FUNCTION IF EXISTS public.roi_r2676_underperformers();
CREATE OR REPLACE FUNCTION public.roi_r2676_underperformers()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  equipment_label text,
  roi_percent numeric,
  utilization_percent numeric,
  downtime_hours int,
  payback_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_org_name, r.equipment_label, r.roi_percent,
         ROUND(r.utilization_hours::numeric*100/NULLIF(r.utilization_target_hours,0),2),
         r.downtime_hours, r.payback_months
  FROM public.customer_equipment_roi_records_r2676 r
  WHERE r.roi_percent < 40
  ORDER BY r.roi_percent ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_underperformers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_underperformers() TO authenticated;

-- RPC 5: Customer ROI summary
DROP FUNCTION IF EXISTS public.roi_r2676_customer_summary();
CREATE OR REPLACE FUNCTION public.roi_r2676_customer_summary()
RETURNS TABLE(
  customer_org_name text,
  units int,
  total_invested_rupees bigint,
  total_revenue_rupees bigint,
  avg_roi_percent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.customer_org_name, COUNT(*)::int,
         SUM(r.purchase_cost_rupees)::bigint,
         SUM(r.revenue_generated_rupees)::bigint,
         ROUND(AVG(r.roi_percent),2)
  FROM public.customer_equipment_roi_records_r2676 r
  GROUP BY r.customer_org_name
  ORDER BY AVG(r.roi_percent) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_customer_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_customer_summary() TO authenticated;

-- RPC 6: Decisions list
DROP FUNCTION IF EXISTS public.roi_r2676_decisions_list();
CREATE OR REPLACE FUNCTION public.roi_r2676_decisions_list()
RETURNS TABLE(
  id uuid,
  customer_org_name text,
  equipment_label text,
  decision text,
  decided_by_role text,
  rationale text,
  estimated_savings_rupees bigint,
  approval_status text,
  effective_from date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, r.customer_org_name, r.equipment_label, d.decision,
         d.decided_by_role, d.rationale, d.estimated_savings_rupees,
         d.approval_status, d.effective_from
  FROM public.customer_equipment_roi_decisions_r2676 d
  JOIN public.customer_equipment_roi_records_r2676 r ON r.id = d.roi_record_id
  ORDER BY d.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_decisions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_decisions_list() TO authenticated;

-- RPC 7: Decision mix
DROP FUNCTION IF EXISTS public.roi_r2676_decision_mix();
CREATE OR REPLACE FUNCTION public.roi_r2676_decision_mix()
RETURNS TABLE(
  decision text,
  units int,
  estimated_savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision, COUNT(*)::int, COALESCE(SUM(d.estimated_savings_rupees),0)::bigint
  FROM public.customer_equipment_roi_decisions_r2676 d
  GROUP BY d.decision
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_decision_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_decision_mix() TO authenticated;

-- RPC 8: Approve / record a decision
DROP FUNCTION IF EXISTS public.roi_r2676_record_decision(uuid, text, text, text, bigint);
CREATE OR REPLACE FUNCTION public.roi_r2676_record_decision(
  p_roi_record_id uuid,
  p_decision text,
  p_decided_by_role text,
  p_rationale text,
  p_estimated_savings_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_equipment_roi_decisions_r2676
    (roi_record_id, decision, decided_by_role, rationale, estimated_savings_rupees, approval_status)
  VALUES (p_roi_record_id, p_decision, p_decided_by_role, p_rationale, p_estimated_savings_rupees, 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.roi_r2676_record_decision(uuid, text, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.roi_r2676_record_decision(uuid, text, text, text, bigint) TO authenticated;

COMMIT;
