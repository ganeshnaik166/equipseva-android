BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_velocity();
CREATE OR REPLACE FUNCTION public.founder_escrow_velocity()
RETURNS TABLE (
  window_label  text,
  released_cnt  bigint,
  avg_hours     numeric,
  p50_hours     numeric,
  p90_hours     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      e.created_at,
      e.released_at,
      extract(epoch FROM (e.released_at - e.created_at)) / 3600.0 AS hrs
    FROM public.repair_job_escrow e
    WHERE e.released_at IS NOT NULL
  ),
  w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    count(*)::bigint,
    coalesce(round(avg(b.hrs)::numeric, 1), 0),
    coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY b.hrs))::numeric, 1), 0),
    coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY b.hrs))::numeric, 1), 0)
  FROM w
  LEFT JOIN base b ON b.released_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_velocity() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_velocity() TO authenticated;
COMMIT;
