BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_jobs_by_source();
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_by_source()
RETURNS TABLE (
  source       text,
  jobs_90d     bigint,
  gross_90d    numeric,
  share_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days';
  RETURN QUERY
  WITH classified AS (
    SELECT
      rj.id,
      rj.contracted_amount_rupees,
      CASE
        WHEN rj.amc_contract_id IS NOT NULL THEN 'amc_visit'
        WHEN EXISTS (SELECT 1 FROM public.code_red_requests r WHERE r.resolution_repair_job_id = rj.id) THEN 'code_red'
        ELSE 'direct'
      END AS source
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '90 days'
  )
  SELECT
    c.source,
    count(*)::bigint,
    coalesce(sum(c.contracted_amount_rupees), 0)::numeric,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(count(*)::numeric / v_total::numeric * 100.0, 1)
    END
  FROM classified c
  GROUP BY c.source
  ORDER BY jobs_90d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_jobs_by_source() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_jobs_by_source() TO authenticated;
COMMIT;
