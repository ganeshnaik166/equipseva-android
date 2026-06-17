BEGIN;
DROP FUNCTION IF EXISTS public.founder_payout_method_coverage();
CREATE OR REPLACE FUNCTION public.founder_payout_method_coverage()
RETURNS TABLE (
  window_label       text,
  earning_engineers  bigint,
  with_verified_vpa  bigint,
  coverage_pct       numeric
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
  earners AS (
    SELECT
      w.label,
      w.ord,
      b.engineer_user_id
    FROM w
    JOIN public.repair_jobs rj ON rj.status = 'completed' AND rj.completed_at >= w.cutoff
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
  )
  SELECT
    e.label,
    count(DISTINCT e.engineer_user_id)::bigint                                AS earning_engineers,
    count(DISTINCT e.engineer_user_id) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.engineer_payout_methods m
         WHERE m.engineer_user_id = e.engineer_user_id
           AND m.status = 'verified'
      )
    )::bigint                                                                  AS with_verified_vpa,
    CASE WHEN count(DISTINCT e.engineer_user_id) = 0 THEN 0::numeric
         ELSE round(
           count(DISTINCT e.engineer_user_id) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.engineer_payout_methods m
                WHERE m.engineer_user_id = e.engineer_user_id
                  AND m.status = 'verified'
             )
           )::numeric
           / count(DISTINCT e.engineer_user_id)::numeric * 100.0, 1)
    END                                                                        AS coverage_pct
  FROM earners e
  GROUP BY e.label, e.ord
  ORDER BY e.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payout_method_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payout_method_coverage() TO authenticated;
COMMIT;
