BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_by_tenure();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_by_tenure()
RETURNS TABLE (
  tenure_bucket  text,
  attempted_90d  bigint,
  succeeded_90d  bigint,
  success_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH attempts AS (
    SELECT
      a.status,
      extract(epoch FROM (a.attempted_at - c.start_date)) / 86400.0 AS tenure_days
    FROM public.amc_renewal_attempts a
    JOIN public.amc_contracts c ON c.id = a.amc_contract_id
    WHERE a.attempted_at >= now() - interval '90 days'
      AND a.status <> 'pending'
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 6 mo'::text, 1, 0::numeric,    180::numeric),
      ('6-12 mo',      2, 180::numeric,  365::numeric),
      ('1-2 yr',       3, 365::numeric,  730::numeric),
      ('2-3 yr',       4, 730::numeric,  1095::numeric),
      ('> 3 yr',       5, 1095::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE attempts.tenure_days >= b.lo AND attempts.tenure_days < b.hi)::bigint,
    count(*) FILTER (WHERE attempts.tenure_days >= b.lo AND attempts.tenure_days < b.hi AND attempts.status = 'succeeded')::bigint,
    CASE WHEN count(*) FILTER (WHERE attempts.tenure_days >= b.lo AND attempts.tenure_days < b.hi) = 0
         THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE attempts.tenure_days >= b.lo AND attempts.tenure_days < b.hi AND attempts.status = 'succeeded')::numeric
           / count(*) FILTER (WHERE attempts.tenure_days >= b.lo AND attempts.tenure_days < b.hi)::numeric
           * 100.0, 1)
    END
  FROM buckets b LEFT JOIN attempts ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_by_tenure() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_by_tenure() TO authenticated;
COMMIT;
