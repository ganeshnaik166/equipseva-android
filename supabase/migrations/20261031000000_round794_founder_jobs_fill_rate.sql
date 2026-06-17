BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_fill_rate();
CREATE OR REPLACE FUNCTION public.founder_jobs_fill_rate()
RETURNS TABLE (
  window_label  text,
  posted        bigint,
  bid_within_7d bigint,
  fill_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text,  1, now() - interval '30 days'),
      ('60d'::text,  2, now() - interval '60 days'),
      ('90d'::text,  3, now() - interval '90 days')
  ),
  posted_jobs AS (
    SELECT w.label, w.ord, rj.id, rj.created_at
    FROM w
    JOIN public.repair_jobs rj ON rj.created_at >= w.cutoff
      AND rj.created_at < now() - interval '7 days'  -- only jobs old enough to have had their 7d window
  )
  SELECT
    pj.label,
    count(*)::bigint                                                   AS posted,
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.repair_job_bids b
         WHERE b.repair_job_id = pj.id
           AND b.created_at <= pj.created_at + interval '7 days'
      )
    )::bigint                                                          AS bid_within_7d,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_job_bids b
                WHERE b.repair_job_id = pj.id
                  AND b.created_at <= pj.created_at + interval '7 days'
             )
           )::numeric / count(*)::numeric * 100.0, 1)
    END                                                                AS fill_pct
  FROM posted_jobs pj
  GROUP BY pj.label, pj.ord
  ORDER BY pj.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_fill_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_fill_rate() TO authenticated;
COMMIT;
