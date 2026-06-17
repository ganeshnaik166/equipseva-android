BEGIN;
DROP FUNCTION IF EXISTS public.founder_spot_audit_rating_distribution();
CREATE OR REPLACE FUNCTION public.founder_spot_audit_rating_distribution()
RETURNS TABLE (
  rating     int,
  cnt        bigint,
  share_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.spot_audit_responses r
    WHERE r.responded_at >= now() - interval '180 days';
  RETURN QUERY
  WITH ratings(rating) AS (
    VALUES (1::int),(2),(3),(4),(5)
  )
  SELECT
    r.rating,
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_responses sar
              WHERE sar.rating = r.rating AND sar.responded_at >= now() - interval '180 days'), 0)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT count(*)::numeric FROM public.spot_audit_responses sar
                     WHERE sar.rating = r.rating AND sar.responded_at >= now() - interval '180 days'), 0)
           / v_total::numeric * 100.0, 1)
    END
  FROM ratings r
  ORDER BY r.rating DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audit_rating_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audit_rating_distribution() TO authenticated;
COMMIT;
