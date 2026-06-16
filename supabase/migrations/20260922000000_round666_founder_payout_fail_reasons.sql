BEGIN;
DROP FUNCTION IF EXISTS public.founder_payout_fail_reasons();
CREATE OR REPLACE FUNCTION public.founder_payout_fail_reasons()
RETURNS TABLE (
  razorpayx_status text,
  cnt              bigint,
  total_rupees     numeric,
  oldest_age_days  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.razorpayx_status, '(null)'),
    count(*)::bigint,
    round(coalesce(sum(p.amount_paise), 0)::numeric / 100.0, 2),
    (extract(epoch FROM (now() - min(p.queued_at)))::int / 86400)
  FROM public.engineer_payouts p
  WHERE p.status IN ('failed','queued','reversed')
  GROUP BY coalesce(p.razorpayx_status, '(null)')
  ORDER BY cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_fail_reasons() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_fail_reasons() TO authenticated;
COMMIT;
