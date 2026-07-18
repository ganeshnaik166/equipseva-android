-- Round 1515 — hospital-scoped list of escrows awaiting payment.
--
-- Companion to the client r1509 "Awaiting payment" badge (which does per-job
-- lookups on the Bookings list) and the r1515 Home banner: a hospital who
-- accepted a bid but never completed the escrow payment has a STALLED job —
-- the engineer is blocked until funds land, and before this the only pay CTA
-- lived inside the job detail. Home needs one cheap call to know "you have
-- N jobs waiting on payment".
--
-- Mirrors engineer_active_escrows (v21) exactly in shape: auth.uid()-scoped
-- SECURITY DEFINER, STABLE, unauthenticated → 42501.

CREATE OR REPLACE FUNCTION public.hospital_pending_escrows()
RETURNS TABLE (
  escrow_id       uuid,
  repair_job_id   uuid,
  job_number      text,
  amount_rupees   numeric,
  equipment_brand text,
  equipment_model text,
  equipment_type  text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id            AS escrow_id,
    e.repair_job_id,
    rj.job_number,
    e.amount_rupees,
    rj.equipment_brand,
    rj.equipment_model,
    rj.equipment_type::text
    FROM public.repair_job_escrow e
    JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
   WHERE rj.hospital_user_id = v_caller
     AND e.status = 'pending'
     -- Only jobs still moving toward work: an accepted-but-unpaid job is
     -- Assigned. Cancelled/disputed jobs have their own recovery flows.
     AND rj.status = 'assigned'
   ORDER BY rj.updated_at DESC NULLS LAST;
END;
$$;

REVOKE ALL   ON FUNCTION public.hospital_pending_escrows() FROM public;
GRANT EXECUTE ON FUNCTION public.hospital_pending_escrows() TO authenticated;

COMMENT ON FUNCTION public.hospital_pending_escrows() IS
  'Round 1515: caller-scoped escrows awaiting payment on Assigned jobs — feeds the hospital Home "complete your payment" banner.';
