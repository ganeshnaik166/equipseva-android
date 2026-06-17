BEGIN;
DROP FUNCTION IF EXISTS public.founder_bid_amount_distribution();
CREATE OR REPLACE FUNCTION public.founder_bid_amount_distribution()
RETURNS TABLE (
  bucket text,
  cnt    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT b.amount_rupees AS amt
    FROM public.repair_job_bids b
    WHERE b.created_at >= now() - interval '90 days'
      AND b.amount_rupees IS NOT NULL
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< Rs.500'::text,           1, 0::numeric,        500::numeric),
      ('Rs.500-Rs.2k'::text,       2, 500::numeric,      2000::numeric),
      ('Rs.2k-Rs.5k'::text,        3, 2000::numeric,     5000::numeric),
      ('Rs.5k-Rs.10k'::text,       4, 5000::numeric,     10000::numeric),
      ('Rs.10k-Rs.25k'::text,      5, 10000::numeric,    25000::numeric),
      ('> Rs.25k'::text,           6, 25000::numeric,   1000000000::numeric)
  )
  SELECT b.label,
    coalesce(count(*) FILTER (WHERE base.amt >= b.lo AND base.amt < b.hi), 0)::bigint
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bid_amount_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bid_amount_distribution() TO authenticated;
COMMIT;
