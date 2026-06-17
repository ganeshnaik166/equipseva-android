BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_release_rate();
CREATE OR REPLACE FUNCTION public.founder_escrow_release_rate()
RETURNS TABLE (
  window_label    text,
  completed_jobs  bigint,
  with_release    bigint,
  release_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  ),
  jobs AS (
    SELECT w.label, w.ord, rj.id
    FROM w
    JOIN public.repair_jobs rj ON rj.status = 'completed' AND rj.completed_at >= w.cutoff
  )
  SELECT
    j.label,
    count(*)::bigint AS completed_jobs,
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.repair_job_escrow e
         WHERE e.repair_job_id = j.id AND e.released_at IS NOT NULL
      )
    )::bigint AS with_release,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_job_escrow e
                WHERE e.repair_job_id = j.id AND e.released_at IS NOT NULL
             )
           )::numeric / count(*)::numeric * 100.0, 1)
    END AS release_pct
  FROM jobs j
  GROUP BY j.label, j.ord
  ORDER BY j.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_release_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_release_rate() TO authenticated;
COMMIT;
