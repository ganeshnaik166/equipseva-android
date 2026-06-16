BEGIN;
DROP FUNCTION IF EXISTS public.founder_payout_volume_30d();
CREATE OR REPLACE FUNCTION public.founder_payout_volume_30d()
RETURNS TABLE (
  status        text,
  payout_count  bigint,
  total_rupees  numeric,
  avg_rupees    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    p.status,
    count(*)::bigint                                                       AS payout_count,
    round(coalesce(sum(p.amount_paise), 0)::numeric / 100.0, 2)            AS total_rupees,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(p.amount_paise), 0)::numeric / count(*)::numeric / 100.0, 2)
    END                                                                    AS avg_rupees
  FROM public.engineer_payouts p
  WHERE p.queued_at >= now() - interval '30 days'
  GROUP BY p.status
  ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_volume_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_volume_30d() TO authenticated;
COMMIT;
