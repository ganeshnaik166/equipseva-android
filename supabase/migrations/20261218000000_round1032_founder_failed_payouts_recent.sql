BEGIN;
DROP FUNCTION IF EXISTS public.founder_failed_payouts_recent();
CREATE OR REPLACE FUNCTION public.founder_failed_payouts_recent()
RETURNS TABLE (
  payout_id          uuid,
  engineer_name      text,
  amount_inr         bigint,
  failure_reason     text,
  queued_at          timestamptz,
  age_h              int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.id                                                                      AS payout_id,
    coalesce(pr.full_name, '(no name)')::text                                 AS engineer_name,
    p.amount_inr::bigint                                                       AS amount_inr,
    coalesce(p.failure_reason, '(no reason)')::text                           AS failure_reason,
    p.queued_at                                                                AS queued_at,
    extract(hour from (now() - p.queued_at))::int                              AS age_h
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_id
  WHERE p.status = 'failed'
    AND p.queued_at >= now() - interval '90 days'
  ORDER BY p.queued_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_failed_payouts_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_failed_payouts_recent() TO authenticated;
COMMIT;
