BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_by_day_of_week();
CREATE OR REPLACE FUNCTION public.founder_amc_by_day_of_week()
RETURNS TABLE (
  dow_num   int,
  dow_label text,
  new_amcs  bigint,
  new_mrr   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days(num, label) AS (
    VALUES (0, 'Sun'::text), (1, 'Mon'), (2, 'Tue'), (3, 'Wed'),
           (4, 'Thu'), (5, 'Fri'), (6, 'Sat')
  )
  SELECT
    d.num,
    d.label,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.created_at >= now() - interval '180 days'
                AND extract(dow FROM (c.created_at AT TIME ZONE 'Asia/Kolkata'))::int = d.num), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.created_at >= now() - interval '180 days'
                AND extract(dow FROM (c.created_at AT TIME ZONE 'Asia/Kolkata'))::int = d.num), 0)::numeric
  FROM days d
  ORDER BY d.num;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_by_day_of_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_by_day_of_week() TO authenticated;
COMMIT;
