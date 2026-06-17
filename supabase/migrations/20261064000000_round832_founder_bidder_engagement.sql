BEGIN;
DROP FUNCTION IF EXISTS public.founder_bidder_engagement();
CREATE OR REPLACE FUNCTION public.founder_bidder_engagement()
RETURNS TABLE (
  window_label     text,
  verified_total   bigint,
  active_bidders   bigint,
  engagement_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.engineers e WHERE e.verification_status = 'verified';
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    v_total,
    coalesce((SELECT count(DISTINCT b.engineer_user_id)::bigint
              FROM public.repair_job_bids b
              JOIN public.engineers e ON e.user_id = b.engineer_user_id
              WHERE e.verification_status = 'verified'
                AND b.created_at >= w.cutoff), 0)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT count(DISTINCT b.engineer_user_id)::numeric
                     FROM public.repair_job_bids b
                     JOIN public.engineers e ON e.user_id = b.engineer_user_id
                     WHERE e.verification_status = 'verified'
                       AND b.created_at >= w.cutoff), 0)
           / v_total::numeric * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bidder_engagement() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bidder_engagement() TO authenticated;
COMMIT;
