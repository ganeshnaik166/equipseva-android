BEGIN;
DROP FUNCTION IF EXISTS public.founder_open_disputes_list();
CREATE OR REPLACE FUNCTION public.founder_open_disputes_list()
RETURNS TABLE (
  pack_id              uuid,
  filed_by_user_id     uuid,
  filer_role           text,
  repair_job_escrow_id uuid,
  evidence_count       int,
  amount_at_stake      numeric,
  submitted_at         timestamptz,
  days_open            int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.filed_by_user_id,
    d.filer_role,
    d.repair_job_escrow_id,
    d.evidence_count,
    d.total_money_at_stake_rupees,
    d.submitted_at,
    (extract(epoch FROM (now() - d.submitted_at))::int / 86400)
  FROM public.dispute_evidence_packs d
  WHERE d.status = 'submitted'
    AND d.submitted_at IS NOT NULL
  ORDER BY d.submitted_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_open_disputes_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_open_disputes_list() TO authenticated;
COMMIT;
