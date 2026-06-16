BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_stuck_30d();
CREATE OR REPLACE FUNCTION public.founder_escrow_stuck_30d()
RETURNS TABLE (
  escrow_id        uuid,
  repair_job_id    uuid,
  status           text,
  amount_rupees    numeric,
  age_days         int,
  hospital_user_id uuid,
  engineer_user_id uuid
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.repair_job_id,
    e.status,
    e.amount_rupees,
    (extract(epoch FROM (now() - e.created_at))::int / 86400),
    e.hospital_user_id,
    e.engineer_user_id
  FROM public.repair_job_escrow e
  WHERE e.status IN ('pending','held','in_dispute')
    AND e.created_at < now() - interval '30 days'
  ORDER BY e.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_stuck_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_stuck_30d() TO authenticated;
COMMIT;
