BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_balance_rollup();
CREATE OR REPLACE FUNCTION public.founder_escrow_balance_rollup()
RETURNS TABLE (
  status        text,
  job_count     bigint,
  total_rupees  numeric,
  avg_rupees    numeric,
  oldest_days   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    e.status,
    count(*)::bigint                                                       AS job_count,
    coalesce(sum(e.amount_rupees), 0)::numeric                             AS total_rupees,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(e.amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END                                                                    AS avg_rupees,
    coalesce((extract(epoch FROM (now() - min(e.created_at)))::int / 86400), 0) AS oldest_days
  FROM public.repair_job_escrow e
  GROUP BY e.status
  ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_balance_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_balance_rollup() TO authenticated;
COMMIT;
