BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audit_pass_rate();
CREATE OR REPLACE FUNCTION public.founder_spot_audit_pass_rate()
RETURNS TABLE (
  window_label    text,
  responses       bigint,
  high_4plus      bigint,
  low_2less       bigint,
  pass_pct        numeric,
  avg_rating      numeric
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
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff AND r.rating >= 4), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff AND r.rating <= 2), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff AND r.rating >= 4)
           / (SELECT count(*)::numeric FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff)
           * 100.0, 1)
    END,
    coalesce((SELECT round(avg(r.rating)::numeric, 2) FROM public.spot_audit_responses r
              WHERE r.responded_at >= w.cutoff), 0::numeric)
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audit_pass_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audit_pass_rate() TO authenticated;
COMMIT;
