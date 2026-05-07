-- v2.1 PR-D24: engineer's active-escrows list RPC.
--
-- PR-D23 shipped a money-in-flight summary card on the engineer's
-- Earnings tab. The next step is making the card tappable so the
-- engineer can drill down to the actual rows: which job, how much,
-- when does it release.
--
-- Filter: held + pending + in_dispute. Released + refunded + cancelled
-- never need to surface here — completed transactions live in the
-- bid-driven transactions list already.
--
-- Joined to repair_jobs (job_number) + profiles (hospital name) so
-- the list renders without N+1 lookups. SECDEF + auth.uid() filter
-- keeps engineers scoped to their own rows.

CREATE OR REPLACE FUNCTION public.engineer_active_escrows()
RETURNS TABLE (
  escrow_id            uuid,
  repair_job_id        uuid,
  job_number           text,
  hospital_name        text,
  amount_rupees        numeric,
  status               text,
  paid_at              timestamptz,
  scheduled_release_at timestamptz,
  dispute_opened_at    timestamptz,
  dispute_reason       text
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
    e.id                                AS escrow_id,
    e.repair_job_id,
    rj.job_number,
    coalesce(p.full_name, '(unnamed)')  AS hospital_name,
    e.amount_rupees,
    e.status,
    e.paid_at,
    e.scheduled_release_at,
    e.dispute_opened_at,
    e.dispute_reason
    FROM public.repair_job_escrow e
    LEFT JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
    LEFT JOIN public.profiles    p  ON p.id  = e.hospital_user_id
   WHERE e.engineer_user_id = v_caller
     AND e.status IN ('pending', 'held', 'in_dispute')
   ORDER BY
     -- Disputes first (most urgent), then by scheduled release ascending
     -- (soonest payout next), then pending payments at the bottom.
     CASE e.status
       WHEN 'in_dispute' THEN 0
       WHEN 'held'       THEN 1
       WHEN 'pending'    THEN 2
       ELSE 3
     END,
     e.scheduled_release_at ASC NULLS LAST,
     e.paid_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_active_escrows() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_active_escrows() TO authenticated;
