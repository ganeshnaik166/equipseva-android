BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_pending_by_engineer();
CREATE OR REPLACE FUNCTION public.founder_payouts_pending_by_engineer()
RETURNS TABLE (
  engineer_name      text,
  pending_cnt        bigint,
  pending_inr        numeric,
  oldest_queued_at   timestamptz,
  failed_cnt_90d     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(pr.full_name, '(no name)')::text                              AS engineer_name,
    count(*)::bigint                                                        AS pending_cnt,
    coalesce(sum(p.amount_inr), 0)::numeric                                 AS pending_inr,
    min(p.queued_at)                                                        AS oldest_queued_at,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p2
              WHERE p2.engineer_id = p.engineer_id
                AND p2.status = 'failed'
                AND p2.queued_at >= now() - interval '90 days'), 0)::bigint  AS failed_cnt_90d
  FROM public.engineer_payouts p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_id
  WHERE p.status IN ('queued','processing')
  GROUP BY pr.full_name, p.engineer_id
  ORDER BY sum(p.amount_inr) DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_pending_by_engineer() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_pending_by_engineer() TO authenticated;
COMMIT;
