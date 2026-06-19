BEGIN;
-- r1363 — Founder Supplier Onboarding Funnel
-- Tracks supplier-side recruiting pipeline from identified → onboarded_active
-- with 15-KPI summary + 80-row ledger + register/advance/reject helpers.



CREATE TABLE IF NOT EXISTS public.founder_supplier_onboarding_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_company_name text NOT NULL UNIQUE,
  supplier_contact_name text,
  supplier_contact_phone text,
  supplier_contact_email text,
  supplier_category text CHECK (supplier_category IN (
    'oem_parts','third_party_parts','consumables','tools',
    'calibration_services','training_partner','logistics','other'
  )),
  funnel_stage text NOT NULL DEFAULT 'identified' CHECK (funnel_stage IN (
    'identified','first_call','sample_request','quote_review',
    'bond_negotiation','onboarded_active','rejected','churned'
  )),
  expected_bond_amount_rupees numeric,
  expected_categories text[],
  identified_at timestamptz NOT NULL DEFAULT now(),
  first_call_at timestamptz,
  sample_received_at timestamptz,
  bond_signed_at timestamptz,
  onboarded_at timestamptz,
  churned_at timestamptz,
  rejection_reason text,
  recruiter_user_id uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supplier_onboarding_stage
  ON public.founder_supplier_onboarding_candidates (funnel_stage);
CREATE INDEX IF NOT EXISTS idx_supplier_onboarding_identified_at
  ON public.founder_supplier_onboarding_candidates (identified_at DESC);

ALTER TABLE public.founder_supplier_onboarding_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_supplier_onboarding_select ON public.founder_supplier_onboarding_candidates;
CREATE POLICY founder_supplier_onboarding_select
  ON public.founder_supplier_onboarding_candidates
  FOR SELECT TO authenticated
  USING (public.is_founder());

DROP FUNCTION IF EXISTS public.founder_supplier_onboarding_funnel_summary();
CREATE OR REPLACE FUNCTION public.founder_supplier_onboarding_funnel_summary()
RETURNS TABLE (
  total_candidates bigint,
  identified_count bigint,
  first_call_count bigint,
  sample_request_count bigint,
  quote_review_count bigint,
  bond_negotiation_count bigint,
  onboarded_count bigint,
  rejected_count bigint,
  churned_count bigint,
  conversion_pct numeric,
  total_bond_value_rupees numeric,
  top_category text,
  top_category_count bigint,
  median_days_identified_to_onboarded numeric,
  churn_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_supplier_onboarding_candidates
  ),
  agg AS (
    SELECT
      COUNT(*)::bigint AS total_candidates,
      COUNT(*) FILTER (WHERE funnel_stage='identified')::bigint AS identified_count,
      COUNT(*) FILTER (WHERE funnel_stage='first_call')::bigint AS first_call_count,
      COUNT(*) FILTER (WHERE funnel_stage='sample_request')::bigint AS sample_request_count,
      COUNT(*) FILTER (WHERE funnel_stage='quote_review')::bigint AS quote_review_count,
      COUNT(*) FILTER (WHERE funnel_stage='bond_negotiation')::bigint AS bond_negotiation_count,
      COUNT(*) FILTER (WHERE funnel_stage='onboarded_active')::bigint AS onboarded_count,
      COUNT(*) FILTER (WHERE funnel_stage='rejected')::bigint AS rejected_count,
      COUNT(*) FILTER (WHERE funnel_stage='churned')::bigint AS churned_count,
      COALESCE(SUM(expected_bond_amount_rupees) FILTER (WHERE funnel_stage='onboarded_active'), 0)::numeric AS total_bond_value_rupees,
      PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (onboarded_at - identified_at)) / 86400.0
      ) FILTER (WHERE onboarded_at IS NOT NULL) AS median_days
    FROM base
  ),
  cat AS (
    SELECT supplier_category, COUNT(*)::bigint AS c
    FROM base WHERE supplier_category IS NOT NULL
    GROUP BY supplier_category ORDER BY c DESC LIMIT 1
  )
  SELECT
    agg.total_candidates,
    agg.identified_count,
    agg.first_call_count,
    agg.sample_request_count,
    agg.quote_review_count,
    agg.bond_negotiation_count,
    agg.onboarded_count,
    agg.rejected_count,
    agg.churned_count,
    CASE WHEN agg.total_candidates > 0
      THEN ROUND((agg.onboarded_count::numeric / agg.total_candidates::numeric) * 100, 1)
      ELSE 0 END AS conversion_pct,
    agg.total_bond_value_rupees,
    (SELECT supplier_category FROM cat) AS top_category,
    COALESCE((SELECT c FROM cat), 0) AS top_category_count,
    COALESCE(ROUND(agg.median_days::numeric, 1), 0) AS median_days_identified_to_onboarded,
    CASE WHEN (agg.onboarded_count + agg.churned_count) > 0
      THEN ROUND((agg.churned_count::numeric / (agg.onboarded_count + agg.churned_count)::numeric) * 100, 1)
      ELSE 0 END AS churn_rate_pct
  FROM agg;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_supplier_onboarding_funnel_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_supplier_onboarding_funnel_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_supplier_onboarding_candidates_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_supplier_onboarding_candidates_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 80
)
RETURNS TABLE (
  id uuid,
  supplier_company_name text,
  supplier_contact_name text,
  supplier_contact_phone text,
  supplier_contact_email text,
  supplier_category text,
  funnel_stage text,
  expected_bond_amount_rupees numeric,
  expected_categories text[],
  identified_at timestamptz,
  first_call_at timestamptz,
  sample_received_at timestamptz,
  bond_signed_at timestamptz,
  onboarded_at timestamptz,
  churned_at timestamptz,
  rejection_reason text,
  notes text,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT c.id, c.supplier_company_name, c.supplier_contact_name, c.supplier_contact_phone,
         c.supplier_contact_email, c.supplier_category, c.funnel_stage,
         c.expected_bond_amount_rupees, c.expected_categories,
         c.identified_at, c.first_call_at, c.sample_received_at, c.bond_signed_at,
         c.onboarded_at, c.churned_at, c.rejection_reason, c.notes, c.updated_at
  FROM public.founder_supplier_onboarding_candidates c
  WHERE (p_status IS NULL OR c.funnel_stage = p_status)
  ORDER BY c.updated_at DESC
  LIMIT COALESCE(p_limit, 80);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_supplier_onboarding_candidates_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_supplier_onboarding_candidates_recent(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_supplier_register(text, text, text, text, text, numeric, text[]);
CREATE OR REPLACE FUNCTION public.log_founder_supplier_register(
  p_company_name text,
  p_contact_name text,
  p_contact_phone text,
  p_contact_email text,
  p_category text,
  p_expected_bond numeric,
  p_expected_categories text[]
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_supplier_onboarding_candidates(
    supplier_company_name, supplier_contact_name, supplier_contact_phone,
    supplier_contact_email, supplier_category, expected_bond_amount_rupees,
    expected_categories, recruiter_user_id
  ) VALUES (
    p_company_name, p_contact_name, p_contact_phone,
    p_contact_email, p_category, p_expected_bond,
    p_expected_categories, auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_supplier_register(text, text, text, text, text, numeric, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_supplier_register(text, text, text, text, text, numeric, text[]) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_supplier_advance(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_supplier_advance(
  p_id uuid,
  p_new_stage text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_new_stage NOT IN ('identified','first_call','sample_request','quote_review',
                         'bond_negotiation','onboarded_active','rejected','churned') THEN
    RAISE EXCEPTION 'invalid stage %', p_new_stage USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_supplier_onboarding_candidates SET
    funnel_stage = p_new_stage,
    first_call_at = CASE WHEN p_new_stage='first_call' AND first_call_at IS NULL THEN now() ELSE first_call_at END,
    sample_received_at = CASE WHEN p_new_stage='sample_request' AND sample_received_at IS NULL THEN now() ELSE sample_received_at END,
    bond_signed_at = CASE WHEN p_new_stage='bond_negotiation' AND bond_signed_at IS NULL THEN now() ELSE bond_signed_at END,
    onboarded_at = CASE WHEN p_new_stage='onboarded_active' AND onboarded_at IS NULL THEN now() ELSE onboarded_at END,
    churned_at = CASE WHEN p_new_stage='churned' AND churned_at IS NULL THEN now() ELSE churned_at END,
    updated_at = now()
  WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_supplier_advance(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_supplier_advance(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_supplier_reject(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_supplier_reject(
  p_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_supplier_onboarding_candidates SET
    funnel_stage = 'rejected',
    rejection_reason = p_reason,
    updated_at = now()
  WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_supplier_reject(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_supplier_reject(uuid, text) TO authenticated;

COMMIT;