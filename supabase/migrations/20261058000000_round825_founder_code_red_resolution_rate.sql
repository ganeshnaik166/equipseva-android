BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_resolution_rate();
CREATE OR REPLACE FUNCTION public.founder_code_red_resolution_rate()
RETURNS TABLE (
  window_label     text,
  total_requests   bigint,
  resolved         bigint,
  timed_out        bigint,
  in_flight        bigint,
  resolution_pct   numeric
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
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE r.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE r.created_at >= w.cutoff AND r.status = 'resolved'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE r.created_at >= w.cutoff AND r.status = 'timed_out'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE r.created_at >= w.cutoff AND r.status NOT IN ('resolved','timed_out')), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.code_red_requests r WHERE r.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.code_red_requests r WHERE r.created_at >= w.cutoff AND r.status = 'resolved')
           / (SELECT count(*)::numeric FROM public.code_red_requests r WHERE r.created_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_resolution_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_resolution_rate() TO authenticated;
COMMIT;
