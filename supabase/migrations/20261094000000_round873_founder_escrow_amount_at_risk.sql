BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_amount_at_risk();
CREATE OR REPLACE FUNCTION public.founder_escrow_amount_at_risk()
RETURNS TABLE (
  bucket         text,
  cnt            bigint,
  rupees_sum     numeric,
  oldest_days    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      e.amount_rupees,
      e.status,
      extract(epoch FROM (now() - e.created_at)) / 86400.0 AS days_old
    FROM public.repair_job_escrow e
    WHERE e.status IN ('paid','disputed','held')
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 7d'::text,   1, 0::numeric,    7::numeric),
      ('7-30d',        2, 7::numeric,   30::numeric),
      ('30-60d',       3, 30::numeric,  60::numeric),
      ('60-90d',       4, 60::numeric,  90::numeric),
      ('> 90d (high risk)', 5, 90::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi)::bigint,
    coalesce(sum(base.amount_rupees) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric,
    coalesce(max(base.days_old) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_amount_at_risk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_amount_at_risk() TO authenticated;
COMMIT;
