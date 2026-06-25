BEGIN;

-- =====================================================================
-- Round 2744 — Customer Quarterly Equipment Warranty Extension Pitch
-- Equipment × warranty expiry × extension price × close × upsell × outcome
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: warranty extension pitches per equipment
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warranty_extension_pitches_r2744 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_code text UNIQUE NOT NULL,
  quarter_label text NOT NULL,
  customer_name text NOT NULL,
  customer_segment text NOT NULL CHECK (customer_segment IN ('hospital','clinic','diagnostic','dental','vet')),
  equipment_model text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','dental','lab','surgical','monitoring')),
  warranty_expiry_date date NOT NULL,
  extension_months int NOT NULL CHECK (extension_months > 0),
  extension_price_rupees int NOT NULL CHECK (extension_price_rupees > 0),
  pitched_at timestamptz NOT NULL DEFAULT now(),
  close_status text NOT NULL CHECK (close_status IN ('pitched','negotiating','won','lost','expired')),
  upsell_amc_offered boolean NOT NULL DEFAULT false,
  outcome_notes text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.warranty_extension_pitches_r2744 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_extension_pitches_r2744;
CREATE POLICY founder_all ON public.warranty_extension_pitches_r2744
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- Table 2: outcome log per pitch
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warranty_extension_outcomes_r2744 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_code text NOT NULL REFERENCES public.warranty_extension_pitches_r2744(pitch_code) ON DELETE CASCADE,
  outcome_stage text NOT NULL CHECK (outcome_stage IN ('intro','demo','quote','negotiation','close')),
  outcome_result text NOT NULL CHECK (outcome_result IN ('progressed','stalled','won','lost')),
  realized_revenue_rupees int NOT NULL DEFAULT 0,
  upsell_amc_value_rupees int NOT NULL DEFAULT 0,
  next_step text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.warranty_extension_outcomes_r2744 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_extension_outcomes_r2744;
CREATE POLICY founder_all ON public.warranty_extension_outcomes_r2744
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- Seeds — pitches (6 rows)
-- ---------------------------------------------------------------------
INSERT INTO public.warranty_extension_pitches_r2744
  (pitch_code, quarter_label, customer_name, customer_segment, equipment_model, equipment_category,
   warranty_expiry_date, extension_months, extension_price_rupees, close_status, upsell_amc_offered, outcome_notes)
VALUES
  ('PITCH-2744-001','Q3-FY26','Apollo Hyderabad','hospital','GE Optima CT 660','imaging',
   '2026-09-30'::date, 12, 285000, 'won', true, 'Closed with bundled AMC 18-mo'),
  ('PITCH-2744-002','Q3-FY26','Smile Dental Banjara','dental','Planmeca PlanScan','dental',
   '2026-08-15'::date, 24, 145000, 'negotiating', true, 'Pricing pushback - quote v2 sent'),
  ('PITCH-2744-003','Q3-FY26','Vijaya Diagnostic Lab','diagnostic','Roche Cobas e411','lab',
   '2026-10-05'::date, 12, 198000, 'pitched', false, 'Awaiting lab head review'),
  ('PITCH-2744-004','Q3-FY26','KIMS Surgical Wing','hospital','Karl Storz Endoscopy Tower','surgical',
   '2026-07-22'::date, 18, 412000, 'won', true, 'Top-tier deal with AMC upsell 22L'),
  ('PITCH-2744-005','Q3-FY26','Hyd Pet Hospital','vet','Mindray Vet Monitor','monitoring',
   '2026-11-12'::date, 12, 78000, 'lost', false, 'Lost to OEM direct extension'),
  ('PITCH-2744-006','Q3-FY26','Yashoda Clinic Secunderabad','clinic','Philips DigitalDiagnost','imaging',
   '2026-09-01'::date, 12, 165000, 'expired', false, 'Warranty lapsed before close');

-- ---------------------------------------------------------------------
-- Seeds — outcomes (6 rows)
-- ---------------------------------------------------------------------
INSERT INTO public.warranty_extension_outcomes_r2744
  (pitch_code, outcome_stage, outcome_result, realized_revenue_rupees, upsell_amc_value_rupees, next_step)
VALUES
  ('PITCH-2744-001','close','won', 285000, 1800000, 'Issue contract + send AMC invoice'),
  ('PITCH-2744-002','negotiation','stalled', 0, 0, 'Founder follow-up call this Friday'),
  ('PITCH-2744-003','quote','progressed', 0, 0, 'Lab head meeting next Tuesday'),
  ('PITCH-2744-004','close','won', 412000, 2200000, 'Onboard to AMC tier Platinum'),
  ('PITCH-2744-005','close','lost', 0, 0, 'Mark closed-lost; revisit at next renewal'),
  ('PITCH-2744-006','quote','lost', 0, 0, 'Warranty expired - pitch new AMC cold');

-- ---------------------------------------------------------------------
-- RPCs (8) — all SECURITY DEFINER, is_founder() gated
-- ---------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.r2744_pitch_summary();
CREATE OR REPLACE FUNCTION public.r2744_pitch_summary()
RETURNS TABLE (
  total_pitches int,
  won_pitches int,
  lost_pitches int,
  open_pitches int,
  pipeline_rupees bigint,
  realized_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE close_status = 'won')::int,
    COUNT(*) FILTER (WHERE close_status = 'lost')::int,
    COUNT(*) FILTER (WHERE close_status IN ('pitched','negotiating'))::int,
    COALESCE(SUM(extension_price_rupees) FILTER (WHERE close_status IN ('pitched','negotiating')), 0)::bigint,
    COALESCE(SUM(extension_price_rupees) FILTER (WHERE close_status = 'won'), 0)::bigint
  FROM public.warranty_extension_pitches_r2744;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_pitch_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_pitch_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_pitches_list();
CREATE OR REPLACE FUNCTION public.r2744_pitches_list()
RETURNS TABLE (
  pitch_code text,
  customer_name text,
  customer_segment text,
  equipment_model text,
  warranty_expiry_date date,
  extension_months int,
  extension_price_rupees int,
  close_status text,
  upsell_amc_offered boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pitch_code, p.customer_name, p.customer_segment, p.equipment_model,
         p.warranty_expiry_date, p.extension_months, p.extension_price_rupees,
         p.close_status, p.upsell_amc_offered
  FROM public.warranty_extension_pitches_r2744 p
  ORDER BY p.warranty_expiry_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_pitches_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_pitches_list() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_by_segment();
CREATE OR REPLACE FUNCTION public.r2744_by_segment()
RETURNS TABLE (
  customer_segment text,
  pitch_count int,
  won_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.customer_segment,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.close_status = 'won')::int,
         COALESCE(SUM(p.extension_price_rupees), 0)::bigint
  FROM public.warranty_extension_pitches_r2744 p
  GROUP BY p.customer_segment
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_by_segment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_by_segment() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_outcomes_list();
CREATE OR REPLACE FUNCTION public.r2744_outcomes_list()
RETURNS TABLE (
  pitch_code text,
  outcome_stage text,
  outcome_result text,
  realized_revenue_rupees int,
  upsell_amc_value_rupees int,
  next_step text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.pitch_code, o.outcome_stage, o.outcome_result,
         o.realized_revenue_rupees, o.upsell_amc_value_rupees, o.next_step
  FROM public.warranty_extension_outcomes_r2744 o
  ORDER BY o.recorded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_outcomes_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_outcomes_list() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_upsell_summary();
CREATE OR REPLACE FUNCTION public.r2744_upsell_summary()
RETURNS TABLE (
  upsell_offered_count int,
  amc_realized_rupees bigint,
  attach_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.warranty_extension_pitches_r2744;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.warranty_extension_pitches_r2744 WHERE upsell_amc_offered),
    COALESCE((SELECT SUM(upsell_amc_value_rupees) FROM public.warranty_extension_outcomes_r2744), 0)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(
           (SELECT COUNT(*)::numeric FROM public.warranty_extension_pitches_r2744 WHERE upsell_amc_offered)
           * 100.0 / v_total, 1)
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_upsell_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_upsell_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_expiring_soon();
CREATE OR REPLACE FUNCTION public.r2744_expiring_soon()
RETURNS TABLE (
  pitch_code text,
  customer_name text,
  equipment_model text,
  warranty_expiry_date date,
  days_until_expiry int,
  close_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pitch_code, p.customer_name, p.equipment_model, p.warranty_expiry_date,
         (p.warranty_expiry_date - CURRENT_DATE)::int,
         p.close_status
  FROM public.warranty_extension_pitches_r2744 p
  WHERE p.close_status NOT IN ('won','lost')
  ORDER BY p.warranty_expiry_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_expiring_soon() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_expiring_soon() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_close_funnel();
CREATE OR REPLACE FUNCTION public.r2744_close_funnel()
RETURNS TABLE (
  outcome_stage text,
  stage_count int,
  won_count int,
  lost_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outcome_stage,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE o.outcome_result = 'won')::int,
         COUNT(*) FILTER (WHERE o.outcome_result = 'lost')::int
  FROM public.warranty_extension_outcomes_r2744 o
  GROUP BY o.outcome_stage
  ORDER BY o.outcome_stage;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_close_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_close_funnel() TO authenticated;

DROP FUNCTION IF EXISTS public.r2744_category_revenue();
CREATE OR REPLACE FUNCTION public.r2744_category_revenue()
RETURNS TABLE (
  equipment_category text,
  pitch_count int,
  realized_rupees bigint,
  pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.equipment_category,
         COUNT(*)::int,
         COALESCE(SUM(p.extension_price_rupees) FILTER (WHERE p.close_status = 'won'), 0)::bigint,
         COALESCE(SUM(p.extension_price_rupees) FILTER (WHERE p.close_status IN ('pitched','negotiating')), 0)::bigint
  FROM public.warranty_extension_pitches_r2744 p
  GROUP BY p.equipment_category
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2744_category_revenue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2744_category_revenue() TO authenticated;

COMMIT;
