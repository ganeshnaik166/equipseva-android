BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_utilization();
CREATE OR REPLACE FUNCTION public.founder_engineer_utilization()
RETURNS TABLE (
  window_label    text,
  total_verified  bigint,
  active_count    bigint,
  active_pct      numeric
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
  WITH active AS (
    SELECT b.engineer_user_id, rj.completed_at
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  ), w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    v_total,
    coalesce(count(DISTINCT a.engineer_user_id), 0)::bigint AS active_count,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round((count(DISTINCT a.engineer_user_id)::numeric / v_total::numeric) * 100.0, 1)
    END AS active_pct
  FROM w LEFT JOIN active a ON a.completed_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_utilization() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_utilization() TO authenticated;
COMMIT;
