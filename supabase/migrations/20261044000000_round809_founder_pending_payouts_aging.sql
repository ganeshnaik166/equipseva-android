BEGIN;
DROP FUNCTION IF EXISTS public.founder_pending_payouts_aging();
CREATE OR REPLACE FUNCTION public.founder_pending_payouts_aging()
RETURNS TABLE (
  bucket         text,
  cnt            bigint,
  rupees_sum     numeric,
  oldest_hours   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      p.amount_rupees,
      p.queued_at,
      extract(epoch FROM (now() - p.queued_at)) / 3600.0 AS hours_old
    FROM public.engineer_payouts p
    WHERE p.status = 'pending'
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 1h'::text,   1, 0::numeric,    1::numeric),
      ('1-6h',         2, 1::numeric,    6::numeric),
      ('6-24h',        3, 6::numeric,   24::numeric),
      ('1-3d',         4, 24::numeric,  72::numeric),
      ('3-7d',         5, 72::numeric, 168::numeric),
      ('>7d',          6, 168::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi)::bigint,
    coalesce(sum(base.amount_rupees) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi), 0)::numeric,
    coalesce(max(base.hours_old) FILTER (WHERE base.hours_old >= b.lo AND base.hours_old < b.hi), 0)::numeric
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pending_payouts_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pending_payouts_aging() TO authenticated;
COMMIT;
