BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_utilization();
CREATE OR REPLACE FUNCTION public.founder_hospital_utilization()
RETURNS TABLE (
  window_label    text,
  total_ever      bigint,
  active_count    bigint,
  active_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_total
    FROM public.repair_jobs rj;
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
    coalesce(count(DISTINCT rj.hospital_user_id), 0)::bigint AS active_count,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round((count(DISTINCT rj.hospital_user_id)::numeric / v_total::numeric) * 100.0, 1)
    END AS active_pct
  FROM w
  LEFT JOIN public.repair_jobs rj ON rj.created_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_utilization() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_utilization() TO authenticated;
COMMIT;
