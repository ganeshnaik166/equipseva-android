BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_retention_rate();
CREATE OR REPLACE FUNCTION public.founder_engineer_retention_rate()
RETURNS TABLE (
  window_label    text,
  engineers       bigint,
  repeaters       bigint,
  retention_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text,  1, now() - interval '30 days'),
      ('90d'::text,  2, now() - interval '90 days'),
      ('180d'::text, 3, now() - interval '180 days')
  ),
  per_window AS (
    SELECT w.label, w.ord, b.engineer_user_id, count(*) AS jobs
    FROM w
    JOIN public.repair_jobs rj
      ON rj.status = 'completed' AND rj.completed_at >= w.cutoff
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
    GROUP BY w.label, w.ord, b.engineer_user_id
  )
  SELECT pw.label,
    count(*)::bigint                                     AS engineers,
    count(*) FILTER (WHERE pw.jobs >= 2)::bigint         AS repeaters,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE pw.jobs >= 2)::numeric
                    / count(*)::numeric * 100.0, 1)
    END AS retention_pct
  FROM per_window pw
  GROUP BY pw.label, pw.ord
  ORDER BY pw.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_retention_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_retention_rate() TO authenticated;
COMMIT;
