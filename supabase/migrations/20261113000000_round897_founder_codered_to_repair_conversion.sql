BEGIN;
DROP FUNCTION IF EXISTS public.founder_codered_to_repair_conversion();
CREATE OR REPLACE FUNCTION public.founder_codered_to_repair_conversion()
RETURNS TABLE (
  window_label   text,
  code_red_total bigint,
  spawned_repair bigint,
  completed      bigint,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text, 1, now() - interval '30 days'),
      ('90d'::text, 2, now() - interval '90 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.created_at >= w.cutoff
                AND r.resolution_repair_job_id IS NOT NULL), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              JOIN public.repair_jobs rj ON rj.id = r.resolution_repair_job_id
              WHERE r.created_at >= w.cutoff
                AND rj.status = 'completed'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.code_red_requests r WHERE r.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.code_red_requests r
              WHERE r.created_at >= w.cutoff AND r.resolution_repair_job_id IS NOT NULL)
           / (SELECT count(*)::numeric FROM public.code_red_requests r WHERE r.created_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_codered_to_repair_conversion() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_codered_to_repair_conversion() TO authenticated;
COMMIT;
