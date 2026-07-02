BEGIN;
-- r1438 ★★★★ — Hospital equipment procurement pipeline.
--
-- Founder-visible board for tracking hospital-side equipment purchase deals
-- from initial need-identified through RFQ → vendor quotes → negotiation →
-- PO → part-payment → delivery → install → commissioned. Lets founder see
-- where each procurement is stuck, which are overdue, and what milestones
-- happened recently. Hospital is the BUYER here (org with hospital_user_id);
-- vendor is the SELLER (organization that wins the PO).
--
-- 2 tables:
--   founder_hospital_equipment_procurement_pipeline
--   founder_hospital_equipment_procurement_milestones
--
-- 7 RPCs:
--   founder_equipment_procurement_summary           — 16 KPIs
--   founder_equipment_procurement_recent            — pipeline rows (40)
--   founder_equipment_procurement_milestones_recent — milestone feed (60)
--   founder_equipment_procurement_overdue           — overdue banner data
--   log_founder_equipment_procurement_register      — create pipeline row
--   log_founder_equipment_procurement_stage_change  — move stage forward
--   log_founder_equipment_procurement_milestone     — append milestone

-- ============================================================================
-- 1. TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_equipment_procurement_pipeline (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  equipment_label       text NOT NULL,
  equipment_category    text,
  expected_value_rupees numeric NOT NULL DEFAULT 0 CHECK (expected_value_rupees >= 0),
  vendor_org_id         uuid,
  preferred_specs       jsonb NOT NULL DEFAULT '{}'::jsonb,
  procurement_stage     text NOT NULL DEFAULT 'need_identified' CHECK (procurement_stage IN (
    'need_identified','rfq_sent','quotes_received','negotiation','po_issued',
    'delivery_pending','delivered','installed','commissioned','cancelled'
  )),
  expected_delivery_date date,
  actual_delivery_date   date,
  signed_contract_url    text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_heq_procure_pipeline_stage
  ON public.founder_hospital_equipment_procurement_pipeline (procurement_stage, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_heq_procure_pipeline_hospital
  ON public.founder_hospital_equipment_procurement_pipeline (hospital_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_heq_procure_pipeline_expected_delivery
  ON public.founder_hospital_equipment_procurement_pipeline (expected_delivery_date)
  WHERE procurement_stage NOT IN ('delivered','installed','commissioned','cancelled');

ALTER TABLE public.founder_hospital_equipment_procurement_pipeline ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_heq_procure_pipeline
  ON public.founder_hospital_equipment_procurement_pipeline;
CREATE POLICY founder_only_heq_procure_pipeline
  ON public.founder_hospital_equipment_procurement_pipeline
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_hospital_equipment_procurement_milestones (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  procurement_id  uuid NOT NULL REFERENCES public.founder_hospital_equipment_procurement_pipeline(id) ON DELETE CASCADE,
  milestone_kind  text NOT NULL CHECK (milestone_kind IN (
    'rfq_sent','quotes_received','negotiation_start','po_issued','part_payment',
    'delivery_arrived','installation_started','commissioned','escalation','cancelled'
  )),
  description     text,
  happened_at     timestamptz NOT NULL DEFAULT now(),
  value_rupees    numeric NOT NULL DEFAULT 0 CHECK (value_rupees >= 0),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_heq_procure_milestones_procurement
  ON public.founder_hospital_equipment_procurement_milestones (procurement_id, happened_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_heq_procure_milestones_happened
  ON public.founder_hospital_equipment_procurement_milestones (happened_at DESC);

ALTER TABLE public.founder_hospital_equipment_procurement_milestones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_heq_procure_milestones
  ON public.founder_hospital_equipment_procurement_milestones;
CREATE POLICY founder_only_heq_procure_milestones
  ON public.founder_hospital_equipment_procurement_milestones
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. SUMMARY — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_equipment_procurement_summary();
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_summary()
RETURNS TABLE (
  total_pipeline_count       int,
  active_count               int,
  need_identified_count      int,
  rfq_sent_count             int,
  quotes_received_count      int,
  negotiation_count          int,
  po_issued_count            int,
  delivery_pending_count     int,
  delivered_count            int,
  commissioned_count         int,
  cancelled_count            int,
  overdue_count              int,
  total_pipeline_value_rupees numeric,
  active_pipeline_value_rupees numeric,
  commissioned_value_rupees  numeric,
  avg_days_to_commission     numeric,
  generated_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_active int;
  v_need int;
  v_rfq int;
  v_quotes int;
  v_neg int;
  v_po int;
  v_delpend int;
  v_del int;
  v_comm int;
  v_canc int;
  v_overdue int;
  v_total_val numeric;
  v_active_val numeric;
  v_comm_val numeric;
  v_avg_days numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*)::int,
         count(*) FILTER (WHERE procurement_stage NOT IN ('delivered','installed','commissioned','cancelled'))::int,
         count(*) FILTER (WHERE procurement_stage = 'need_identified')::int,
         count(*) FILTER (WHERE procurement_stage = 'rfq_sent')::int,
         count(*) FILTER (WHERE procurement_stage = 'quotes_received')::int,
         count(*) FILTER (WHERE procurement_stage = 'negotiation')::int,
         count(*) FILTER (WHERE procurement_stage = 'po_issued')::int,
         count(*) FILTER (WHERE procurement_stage = 'delivery_pending')::int,
         count(*) FILTER (WHERE procurement_stage IN ('delivered','installed'))::int,
         count(*) FILTER (WHERE procurement_stage = 'commissioned')::int,
         count(*) FILTER (WHERE procurement_stage = 'cancelled')::int,
         count(*) FILTER (
           WHERE expected_delivery_date IS NOT NULL
             AND expected_delivery_date < current_date
             AND procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')
         )::int,
         coalesce(sum(expected_value_rupees), 0),
         coalesce(sum(expected_value_rupees) FILTER (
           WHERE procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')
         ), 0),
         coalesce(sum(expected_value_rupees) FILTER (
           WHERE procurement_stage = 'commissioned'
         ), 0)
    INTO v_total, v_active, v_need, v_rfq, v_quotes, v_neg, v_po, v_delpend,
         v_del, v_comm, v_canc, v_overdue, v_total_val, v_active_val, v_comm_val
    FROM public.founder_hospital_equipment_procurement_pipeline;

  SELECT round(avg(extract(epoch FROM (updated_at - created_at)) / 86400.0)::numeric, 1)
    INTO v_avg_days
    FROM public.founder_hospital_equipment_procurement_pipeline
   WHERE procurement_stage = 'commissioned';

  RETURN QUERY SELECT
    coalesce(v_total, 0),
    coalesce(v_active, 0),
    coalesce(v_need, 0),
    coalesce(v_rfq, 0),
    coalesce(v_quotes, 0),
    coalesce(v_neg, 0),
    coalesce(v_po, 0),
    coalesce(v_delpend, 0),
    coalesce(v_del, 0),
    coalesce(v_comm, 0),
    coalesce(v_canc, 0),
    coalesce(v_overdue, 0),
    coalesce(v_total_val, 0),
    coalesce(v_active_val, 0),
    coalesce(v_comm_val, 0),
    coalesce(v_avg_days, 0),
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_procurement_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_procurement_summary() TO authenticated;

-- ============================================================================
-- 3. RECENT PIPELINE ROWS
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_equipment_procurement_recent();
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_recent()
RETURNS TABLE (
  id                    uuid,
  equipment_label       text,
  equipment_category    text,
  procurement_stage     text,
  expected_value_rupees numeric,
  vendor_org_id         uuid,
  hospital_label        text,
  expected_delivery_date date,
  actual_delivery_date   date,
  days_in_stage         int,
  is_overdue            boolean,
  created_at            timestamptz,
  updated_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         p.equipment_label,
         p.equipment_category,
         p.procurement_stage,
         p.expected_value_rupees,
         p.vendor_org_id,
         coalesce(o.name, prof.full_name, 'hospital'::text) AS hospital_label,
         p.expected_delivery_date,
         p.actual_delivery_date,
         extract(day FROM (now() - p.updated_at))::int AS days_in_stage,
         (p.expected_delivery_date IS NOT NULL
          AND p.expected_delivery_date < current_date
          AND p.procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')) AS is_overdue,
         p.created_at,
         p.updated_at
    FROM public.founder_hospital_equipment_procurement_pipeline p
    LEFT JOIN public.profiles prof ON prof.user_id = p.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = prof.organization_id
   ORDER BY
     CASE p.procurement_stage
       WHEN 'commissioned' THEN 9 WHEN 'cancelled' THEN 10
       WHEN 'installed' THEN 8 WHEN 'delivered' THEN 7
       ELSE 0 END,
     p.updated_at DESC
   LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_procurement_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_procurement_recent() TO authenticated;

-- ============================================================================
-- 4. RECENT MILESTONES — combined feed
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_equipment_procurement_milestones_recent();
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_milestones_recent()
RETURNS TABLE (
  id              uuid,
  procurement_id  uuid,
  equipment_label text,
  milestone_kind  text,
  description     text,
  value_rupees    numeric,
  happened_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT m.id, m.procurement_id,
         p.equipment_label,
         m.milestone_kind,
         m.description,
         m.value_rupees,
         m.happened_at
    FROM public.founder_hospital_equipment_procurement_milestones m
    JOIN public.founder_hospital_equipment_procurement_pipeline p ON p.id = m.procurement_id
   ORDER BY m.happened_at DESC
   LIMIT 60;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_procurement_milestones_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_procurement_milestones_recent() TO authenticated;

-- ============================================================================
-- 5. OVERDUE — banner data
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_equipment_procurement_overdue();
CREATE OR REPLACE FUNCTION public.founder_equipment_procurement_overdue()
RETURNS TABLE (
  id                    uuid,
  equipment_label       text,
  procurement_stage     text,
  expected_value_rupees numeric,
  expected_delivery_date date,
  days_overdue          int,
  hospital_label        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id, p.equipment_label, p.procurement_stage, p.expected_value_rupees,
         p.expected_delivery_date,
         (current_date - p.expected_delivery_date)::int AS days_overdue,
         coalesce(o.name, prof.full_name, 'hospital'::text) AS hospital_label
    FROM public.founder_hospital_equipment_procurement_pipeline p
    LEFT JOIN public.profiles prof ON prof.user_id = p.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = prof.organization_id
   WHERE p.expected_delivery_date IS NOT NULL
     AND p.expected_delivery_date < current_date
     AND p.procurement_stage NOT IN ('delivered','installed','commissioned','cancelled')
   ORDER BY (current_date - p.expected_delivery_date) DESC
   LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_procurement_overdue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_procurement_overdue() TO authenticated;

-- ============================================================================
-- 6. WRITE — register new procurement
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_equipment_procurement_register(uuid, text, text, numeric, uuid, jsonb, date);
CREATE OR REPLACE FUNCTION public.log_founder_equipment_procurement_register(
  p_hospital_user_id     uuid,
  p_equipment_label      text,
  p_equipment_category   text,
  p_expected_value_rupees numeric,
  p_vendor_org_id        uuid,
  p_preferred_specs      jsonb,
  p_expected_delivery_date date
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_hospital_user_id IS NULL THEN
    RAISE EXCEPTION 'hospital_user_id required' USING ERRCODE='22023';
  END IF;
  IF p_equipment_label IS NULL OR length(trim(p_equipment_label)) < 2 THEN
    RAISE EXCEPTION 'equipment_label required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_hospital_equipment_procurement_pipeline (
    hospital_user_id, equipment_label, equipment_category,
    expected_value_rupees, vendor_org_id, preferred_specs, expected_delivery_date
  ) VALUES (
    p_hospital_user_id,
    trim(p_equipment_label),
    nullif(trim(coalesce(p_equipment_category, '')), ''),
    coalesce(p_expected_value_rupees, 0),
    p_vendor_org_id,
    coalesce(p_preferred_specs, '{}'::jsonb),
    p_expected_delivery_date
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_equipment_procurement_register(uuid, text, text, numeric, uuid, jsonb, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_equipment_procurement_register(uuid, text, text, numeric, uuid, jsonb, date) TO authenticated;

-- ============================================================================
-- 7. WRITE — stage change
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_equipment_procurement_stage_change(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_equipment_procurement_stage_change(
  p_procurement_id uuid,
  p_new_stage      text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_procurement_id IS NULL THEN
    RAISE EXCEPTION 'procurement_id required' USING ERRCODE='22023';
  END IF;
  IF p_new_stage NOT IN ('need_identified','rfq_sent','quotes_received','negotiation','po_issued',
                         'delivery_pending','delivered','installed','commissioned','cancelled') THEN
    RAISE EXCEPTION 'invalid stage %', p_new_stage USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_hospital_equipment_procurement_pipeline
     SET procurement_stage = p_new_stage,
         actual_delivery_date = CASE
           WHEN p_new_stage = 'delivered' AND actual_delivery_date IS NULL THEN current_date
           ELSE actual_delivery_date END,
         updated_at = now()
   WHERE id = p_procurement_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'procurement not found' USING ERRCODE='02000';
  END IF;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_equipment_procurement_stage_change(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_equipment_procurement_stage_change(uuid, text) TO authenticated;

-- ============================================================================
-- 8. WRITE — append milestone
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_equipment_procurement_milestone(uuid, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_equipment_procurement_milestone(
  p_procurement_id uuid,
  p_milestone_kind text,
  p_description    text,
  p_value_rupees   numeric
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_procurement_id IS NULL THEN
    RAISE EXCEPTION 'procurement_id required' USING ERRCODE='22023';
  END IF;
  IF p_milestone_kind NOT IN ('rfq_sent','quotes_received','negotiation_start','po_issued','part_payment',
                              'delivery_arrived','installation_started','commissioned','escalation','cancelled') THEN
    RAISE EXCEPTION 'invalid milestone_kind %', p_milestone_kind USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.founder_hospital_equipment_procurement_pipeline WHERE id = p_procurement_id) THEN
    RAISE EXCEPTION 'procurement not found' USING ERRCODE='02000';
  END IF;

  INSERT INTO public.founder_hospital_equipment_procurement_milestones (
    procurement_id, milestone_kind, description, value_rupees
  ) VALUES (
    p_procurement_id, p_milestone_kind,
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(p_value_rupees, 0)
  )
  RETURNING id INTO v_id;

  UPDATE public.founder_hospital_equipment_procurement_pipeline
     SET updated_at = now()
   WHERE id = p_procurement_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_equipment_procurement_milestone(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_equipment_procurement_milestone(uuid, text, text, numeric) TO authenticated;

COMMIT;