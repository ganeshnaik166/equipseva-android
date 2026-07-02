-- Round 2508: customer equipment acceptance + handover runbook
-- Equipment × delivery × installation × UAT × signoff × revenue release
-- Surfaces signoff checklist completion and overdue handovers

BEGIN;

CREATE TABLE IF NOT EXISTS public.equipment_handover_runs_r2508 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_model text NOT NULL,
  delivery_at timestamptz,
  installation_at timestamptz,
  uat_started_at timestamptz,
  uat_completed_at timestamptz,
  signoff_at timestamptz,
  signoff_owner_email text,
  revenue_release_at timestamptz,
  revenue_amount_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('scheduled','delivered','installing','uat','signed_off','escalated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.acceptance_signoff_checklist_r2508 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handover_id uuid NOT NULL REFERENCES public.equipment_handover_runs_r2508(id) ON DELETE CASCADE,
  checklist_item text NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  completed_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.equipment_handover_runs_r2508 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acceptance_signoff_checklist_r2508 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_handover_runs_r2508;
CREATE POLICY founder_all ON public.equipment_handover_runs_r2508
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.acceptance_signoff_checklist_r2508;
CREATE POLICY founder_all ON public.acceptance_signoff_checklist_r2508
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed handover runs
INSERT INTO public.equipment_handover_runs_r2508
  (equipment_label, equipment_model, delivery_at, installation_at, uat_started_at, uat_completed_at, signoff_at, signoff_owner_email, revenue_release_at, revenue_amount_rupees, status, notes)
VALUES
  ('Apollo Hyd - CT Scanner #14', 'GE Revolution CT-128', '2026-06-10 10:00:00+05:30'::timestamptz, '2026-06-12 11:00:00+05:30'::timestamptz, '2026-06-13 09:00:00+05:30'::timestamptz, '2026-06-16 17:00:00+05:30'::timestamptz, '2026-06-17 12:00:00+05:30'::timestamptz, 'biomed.apollo@example.com', '2026-06-18 10:00:00+05:30'::timestamptz, 4500000, 'signed_off', 'clean signoff, payment milestone released'),
  ('KIMS Sec - Ventilator Bay-A', 'Drager Evita V300', '2026-06-15 09:00:00+05:30'::timestamptz, '2026-06-16 14:00:00+05:30'::timestamptz, '2026-06-17 10:00:00+05:30'::timestamptz, NULL, NULL, 'biomed.kims@example.com', NULL, 1800000, 'uat', 'UAT day 6, calibration pending'),
  ('Yashoda Sgd - Dialysis Cluster', 'Fresenius 5008S x4', '2026-06-18 11:00:00+05:30'::timestamptz, '2026-06-20 16:00:00+05:30'::timestamptz, NULL, NULL, NULL, 'biomed.yashoda@example.com', NULL, 3200000, 'installing', 'installation in progress, water-treatment line being plumbed'),
  ('Care Banj - X-Ray Mobile', 'Siemens Mobilett Elara Max', '2026-06-21 13:00:00+05:30'::timestamptz, NULL, NULL, NULL, NULL, 'biomed.care@example.com', NULL, 950000, 'delivered', 'delivered, awaiting installation crew'),
  ('Continental Gch - MRI 1.5T', 'Philips Ingenia 1.5T', NULL, NULL, NULL, NULL, NULL, 'biomed.continental@example.com', NULL, 8500000, 'escalated', 'civil works delayed by hospital, escalated to PMO');

-- Seed checklist items
WITH h AS (
  SELECT id, equipment_label FROM public.equipment_handover_runs_r2508
)
INSERT INTO public.acceptance_signoff_checklist_r2508
  (handover_id, checklist_item, completed, completed_at, completed_by_email, notes)
SELECT h.id, ci.item, ci.done, ci.done_at, ci.who, ci.notes
FROM h
JOIN LATERAL (
  VALUES
    ('Physical inspection & damage report', true, '2026-06-12 11:30:00+05:30'::timestamptz, 'biomed@example.com', 'no transit damage'),
    ('Power & UPS commissioning', true, '2026-06-12 14:00:00+05:30'::timestamptz, 'biomed@example.com', 'UPS rated 3kVA installed'),
    ('Calibration test pass', CASE WHEN h.equipment_label LIKE 'Apollo%' THEN true ELSE false END, NULL, 'qa@example.com', 'awaiting QA visit')
) AS ci(item, done, done_at, who, notes) ON true;

-- RPC 1: list handover runs
CREATE OR REPLACE FUNCTION public.list_handover_runs_r2508()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_model text,
  delivery_at timestamptz,
  installation_at timestamptz,
  uat_started_at timestamptz,
  uat_completed_at timestamptz,
  signoff_at timestamptz,
  signoff_owner_email text,
  revenue_release_at timestamptz,
  revenue_amount_rupees bigint,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.equipment_label, r.equipment_model, r.delivery_at, r.installation_at,
         r.uat_started_at, r.uat_completed_at, r.signoff_at, r.signoff_owner_email,
         r.revenue_release_at, r.revenue_amount_rupees, r.status, r.notes
  FROM public.equipment_handover_runs_r2508 r
  ORDER BY COALESCE(r.delivery_at, r.created_at) DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_handover_runs_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_handover_runs_r2508() TO authenticated;

-- RPC 2: list checklist items
CREATE OR REPLACE FUNCTION public.list_checklist_r2508()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  checklist_item text,
  completed boolean,
  completed_at timestamptz,
  completed_by_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, r.equipment_label, c.checklist_item, c.completed, c.completed_at,
         c.completed_by_email, c.notes
  FROM public.acceptance_signoff_checklist_r2508 c
  JOIN public.equipment_handover_runs_r2508 r ON r.id = c.handover_id
  ORDER BY r.equipment_label, c.created_at
  LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_checklist_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_checklist_r2508() TO authenticated;

-- RPC 3: top overdue handovers (escalated or stuck > 7 days w/o signoff)
CREATE OR REPLACE FUNCTION public.top_overdue_handovers_r2508()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  status text,
  delivery_at timestamptz,
  days_since_delivery integer,
  revenue_amount_rupees bigint,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.equipment_label, r.status, r.delivery_at,
         CASE WHEN r.delivery_at IS NULL THEN 0
              ELSE EXTRACT(DAY FROM (now() - r.delivery_at))::integer END,
         r.revenue_amount_rupees, r.notes
  FROM public.equipment_handover_runs_r2508 r
  WHERE r.signoff_at IS NULL
    AND (r.status = 'escalated' OR (r.delivery_at IS NOT NULL AND r.delivery_at < now() - interval '7 days'))
  ORDER BY r.delivery_at ASC NULLS FIRST, r.revenue_amount_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_overdue_handovers_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_overdue_handovers_r2508() TO authenticated;

-- RPC 4: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2508()
RETURNS TABLE (
  status text,
  run_count bigint,
  revenue_sum_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, COUNT(*)::bigint, COALESCE(SUM(r.revenue_amount_rupees),0)::bigint
  FROM public.equipment_handover_runs_r2508 r
  GROUP BY r.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2508() TO authenticated;

-- RPC 5: monthly revenue release trend
CREATE OR REPLACE FUNCTION public.monthly_revenue_release_trend_r2508()
RETURNS TABLE (
  month_label text,
  signed_off_count bigint,
  revenue_released_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', r.revenue_release_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COALESCE(SUM(r.revenue_amount_rupees),0)::bigint
  FROM public.equipment_handover_runs_r2508 r
  WHERE r.revenue_release_at IS NOT NULL
  GROUP BY date_trunc('month', r.revenue_release_at)
  ORDER BY date_trunc('month', r.revenue_release_at);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_revenue_release_trend_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_revenue_release_trend_r2508() TO authenticated;

-- RPC 6: equipment kind summary (group by model family)
CREATE OR REPLACE FUNCTION public.equipment_kind_summary_r2508()
RETURNS TABLE (
  equipment_model text,
  run_count bigint,
  signed_off_count bigint,
  avg_days_delivery_to_signoff numeric,
  revenue_sum_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.equipment_model,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE r.signoff_at IS NOT NULL)::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (r.signoff_at - r.delivery_at)) / 86400.0)::numeric, 2),
         COALESCE(SUM(r.revenue_amount_rupees),0)::bigint
  FROM public.equipment_handover_runs_r2508 r
  GROUP BY r.equipment_model
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2508() TO authenticated;

-- RPC 7: owner load (signoff owner workload)
CREATE OR REPLACE FUNCTION public.owner_load_r2508()
RETURNS TABLE (
  signoff_owner_email text,
  open_count bigint,
  signed_off_count bigint,
  pending_revenue_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.signoff_owner_email,
         COUNT(*) FILTER (WHERE r.signoff_at IS NULL)::bigint,
         COUNT(*) FILTER (WHERE r.signoff_at IS NOT NULL)::bigint,
         COALESCE(SUM(r.revenue_amount_rupees) FILTER (WHERE r.signoff_at IS NULL),0)::bigint
  FROM public.equipment_handover_runs_r2508 r
  WHERE r.signoff_owner_email IS NOT NULL
  GROUP BY r.signoff_owner_email
  ORDER BY COUNT(*) FILTER (WHERE r.signoff_at IS NULL) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2508() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2508() TO authenticated;

