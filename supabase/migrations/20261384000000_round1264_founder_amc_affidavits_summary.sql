BEGIN;
-- =====================================================================
-- Round 1264 — /amc-affidavits-summary
-- Founder snapshot of AMC digital affidavits (round 493 table)
-- =====================================================================
-- 12 KPIs across signing velocity, declaration completeness, signer
-- designation mix, equipment-categories coverage, masked-Aadhaar
-- capture rate, evidence-ledger linkage, and unsigned-contract backlog.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_amc_affidavits_summary();

CREATE OR REPLACE FUNCTION public.founder_amc_affidavits_summary()
RETURNS TABLE (
  total_affidavits          bigint,
  signed_last_7d            bigint,
  signed_last_30d           bigint,
  signed_last_90d           bigint,
  unique_signer_hospitals   bigint,
  pct_with_aadhaar_masked   numeric,
  pct_with_designation      numeric,
  pct_with_evidence_ledger  numeric,
  avg_equipment_categories  numeric,
  top_signer_designation    text,
  amc_contracts_total       bigint,
  amc_contracts_unsigned    bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total              bigint;
  v_7d                 bigint;
  v_30d                bigint;
  v_90d                bigint;
  v_uniq_hosp          bigint;
  v_pct_aadhaar        numeric;
  v_pct_designation    numeric;
  v_pct_ledger         numeric;
  v_avg_cats           numeric;
  v_top_desig          text;
  v_contracts_total    bigint;
  v_contracts_unsigned bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE signed_at >= now() - interval '7 days')::bigint,
    count(*) FILTER (WHERE signed_at >= now() - interval '30 days')::bigint,
    count(*) FILTER (WHERE signed_at >= now() - interval '90 days')::bigint,
    count(DISTINCT hospital_user_id)::bigint,
    CASE WHEN count(*) > 0
      THEN round(100.0 * count(*) FILTER (WHERE signer_aadhaar_masked IS NOT NULL)::numeric / count(*)::numeric, 2)
      ELSE 0 END,
    CASE WHEN count(*) > 0
      THEN round(100.0 * count(*) FILTER (WHERE signer_designation IS NOT NULL AND length(trim(signer_designation)) > 0)::numeric / count(*)::numeric, 2)
      ELSE 0 END,
    CASE WHEN count(*) > 0
      THEN round(100.0 * count(*) FILTER (WHERE evidence_ledger_id IS NOT NULL)::numeric / count(*)::numeric, 2)
      ELSE 0 END,
    coalesce(round(avg(coalesce(array_length(equipment_categories, 1), 0))::numeric, 2), 0)
  INTO
    v_total, v_7d, v_30d, v_90d, v_uniq_hosp,
    v_pct_aadhaar, v_pct_designation, v_pct_ledger, v_avg_cats
  FROM public.amc_affidavits;

  SELECT coalesce(signer_designation, '(unspecified)')
    INTO v_top_desig
    FROM public.amc_affidavits
   WHERE signer_designation IS NOT NULL
     AND length(trim(signer_designation)) > 0
   GROUP BY signer_designation
   ORDER BY count(*) DESC, signer_designation ASC
   LIMIT 1;

  SELECT count(*)::bigint INTO v_contracts_total FROM public.amc_contracts;

  SELECT count(*)::bigint
    INTO v_contracts_unsigned
    FROM public.amc_contracts c
   WHERE NOT EXISTS (
     SELECT 1 FROM public.amc_affidavits a WHERE a.amc_contract_id = c.id
   );

  RETURN QUERY SELECT
    coalesce(v_total, 0),
    coalesce(v_7d, 0),
    coalesce(v_30d, 0),
    coalesce(v_90d, 0),
    coalesce(v_uniq_hosp, 0),
    coalesce(v_pct_aadhaar, 0),
    coalesce(v_pct_designation, 0),
    coalesce(v_pct_ledger, 0),
    coalesce(v_avg_cats, 0),
    coalesce(v_top_desig, '(none)'),
    coalesce(v_contracts_total, 0),
    coalesce(v_contracts_unsigned, 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_affidavits_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_affidavits_summary() TO authenticated;

COMMIT;
