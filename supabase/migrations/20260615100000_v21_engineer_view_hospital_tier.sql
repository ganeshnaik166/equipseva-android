-- v2.1 PR-D38: engineer-side commission preview on assigned job.
--
-- PR-D2 made commission tier-aware (7% / 5% / 3% by hospital's
-- 12mo job count). PR-D36 made Earnings reflect the actual payout
-- after commission. But the engineer still doesn't know the rate
-- BEFORE the job completes — they just see the bid amount, the work
-- happens, then the payout lands smaller than expected.
--
-- Tier transparency BEFORE work helps the engineer plan. We expose
-- tier only on jobs the engineer is already assigned to (avoids
-- pre-bid tier-shopping that could become discriminatory). Caller
-- must be the engineer_id on the job.
--
-- Returns single-row tier preview:
--   * commission_rate    — 0.07 / 0.05 / 0.03
--   * effective_payout   — contracted_amount * (1 - rate), shown
--                          alongside contracted so engineer sees both
--   * is_warranty_covered — when true, commission is zero (PR-D12)

CREATE OR REPLACE FUNCTION public.engineer_view_hospital_tier(
  p_repair_job_id uuid
)
RETURNS TABLE (
  commission_rate           numeric,
  contracted_amount_rupees  numeric,
  effective_payout_rupees   numeric,
  is_warranty_covered       boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_engineer_id uuid;
  v_job        record;
  v_rate       numeric;
  v_amount     numeric;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_engineer_id
    FROM public.engineers
   WHERE user_id = v_caller
   LIMIT 1;
  IF v_engineer_id IS NULL THEN RETURN; END IF;

  SELECT engineer_id, hospital_user_id, contracted_amount_rupees, is_warranty_covered
    INTO v_job
    FROM public.repair_jobs
   WHERE id = p_repair_job_id;
  IF v_job IS NULL THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = '02000';
  END IF;

  -- Caller must be the engineer assigned to this job. Pre-bid tier
  -- shopping is intentionally blocked.
  IF v_job.engineer_id IS DISTINCT FROM v_engineer_id THEN
    RAISE EXCEPTION 'caller is not the assigned engineer' USING ERRCODE = '42501';
  END IF;

  v_rate   := public.commission_rate_for_hospital(v_job.hospital_user_id);
  v_amount := coalesce(v_job.contracted_amount_rupees, 0);

  IF v_job.is_warranty_covered THEN
    -- PR-D12 zeros platform_commission for warranty rows.
    RETURN QUERY SELECT 0::numeric, v_amount, v_amount, true;
  ELSE
    RETURN QUERY
    SELECT
      v_rate,
      v_amount,
      round(v_amount * (1 - v_rate), 2),
      false;
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_view_hospital_tier(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_view_hospital_tier(uuid) TO authenticated;
