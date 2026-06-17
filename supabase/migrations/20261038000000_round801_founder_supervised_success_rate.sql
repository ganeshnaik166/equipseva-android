BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_success_rate();
CREATE OR REPLACE FUNCTION public.founder_supervised_success_rate()
RETURNS TABLE (
  window_label    text,
  completed       bigint,
  successful      bigint,
  failed          bigint,
  success_pct     numeric
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
      ('365d'::text, 3, now() - interval '365 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status IN ('completed_successful','completed_failed') AND s.completed_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'completed_successful' AND s.completed_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
              WHERE s.status = 'completed_failed' AND s.completed_at >= w.cutoff), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.supervised_job_assignments s
              WHERE s.status IN ('completed_successful','completed_failed') AND s.completed_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.supervised_job_assignments s
              WHERE s.status = 'completed_successful' AND s.completed_at >= w.cutoff)
           / (SELECT count(*)::numeric FROM public.supervised_job_assignments s
              WHERE s.status IN ('completed_successful','completed_failed') AND s.completed_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_success_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_success_rate() TO authenticated;
COMMIT;
