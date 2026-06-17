BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_rate();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_rate()
RETURNS TABLE (
  window_label   text,
  attempted      bigint,
  succeeded      bigint,
  failed         bigint,
  abandoned      bigint,
  success_pct    numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status <> 'pending'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status = 'succeeded'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status = 'failed'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status = 'abandoned'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status <> 'pending'), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status = 'succeeded')
           / (SELECT count(*)::numeric FROM public.amc_renewal_attempts a
              WHERE a.attempted_at >= w.cutoff AND a.status <> 'pending')
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_rate() TO authenticated;
COMMIT;
