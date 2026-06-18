BEGIN;
DROP FUNCTION IF EXISTS public.founder_failed_payouts_by_reason_90d();
CREATE OR REPLACE FUNCTION public.founder_failed_payouts_by_reason_90d()
RETURNS TABLE (
  failure_reason  text,
  cnt             bigint,
  total_inr       numeric,
  distinct_engs   bigint,
  last_failed_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.failure_reason, '(no reason)')::text                       AS failure_reason,
    count(*)::bigint                                                       AS cnt,
    coalesce(sum(p.amount_inr), 0)::numeric                                AS total_inr,
    count(DISTINCT p.engineer_id)::bigint                                  AS distinct_engs,
    max(p.queued_at)                                                       AS last_failed_at
  FROM public.engineer_payouts p
  WHERE p.status = 'failed'
    AND p.queued_at >= now() - interval '90 days'
  GROUP BY coalesce(p.failure_reason, '(no reason)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_failed_payouts_by_reason_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_failed_payouts_by_reason_90d() TO authenticated;
COMMIT;
