BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_revenue_by_city();
CREATE OR REPLACE FUNCTION public.founder_jobs_revenue_by_city()
RETURNS TABLE (
  city           text,
  hospital_cnt   bigint,
  completed      bigint,
  gross_rupees   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH completed AS (
    SELECT rj.hospital_user_id, rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  ),
  with_city AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      c.hospital_user_id,
      c.contracted_amount_rupees
    FROM completed c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(wc.contracted_amount_rupees), 0)::numeric
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY gross_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_revenue_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_revenue_by_city() TO authenticated;
COMMIT;
