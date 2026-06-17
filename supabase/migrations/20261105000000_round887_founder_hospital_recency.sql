BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_recency();
CREATE OR REPLACE FUNCTION public.founder_hospital_recency()
RETURNS TABLE (
  bucket      text,
  cnt         bigint,
  share_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.profiles WHERE role = 'hospital';
  RETURN QUERY
  WITH last_jobs AS (
    SELECT
      p.id AS hospital_id,
      coalesce((SELECT max(rj.created_at) FROM public.repair_jobs rj WHERE rj.hospital_user_id = p.id), p.created_at) AS last_at
    FROM public.profiles p
    WHERE p.role = 'hospital'
  ),
  recency AS (
    SELECT
      extract(epoch FROM (now() - last_at)) / 86400.0 AS days_old
    FROM last_jobs
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('Active (≤30d)'::text, 1, 0::numeric,   30::numeric),
      ('30-60d',               2, 30::numeric,  60::numeric),
      ('60-90d',               3, 60::numeric,  90::numeric),
      ('90-180d',              4, 90::numeric, 180::numeric),
      ('180-365d',             5, 180::numeric, 365::numeric),
      ('Dormant (>365d)',      6, 365::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE r.days_old >= b.lo AND r.days_old < b.hi)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE r.days_old >= b.lo AND r.days_old < b.hi)::numeric
           / v_total::numeric * 100.0, 1)
    END
  FROM buckets b LEFT JOIN recency r ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_recency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_recency() TO authenticated;
COMMIT;
