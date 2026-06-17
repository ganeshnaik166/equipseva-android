BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_equipment_type();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_equipment_type()
RETURNS TABLE (
  equipment_type text,
  jobs_count     bigint,
  gross_rupees   numeric,
  avg_rupees     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS equipment_type,
    count(*)::bigint,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END
  FROM public.repair_jobs rj
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY jobs_count DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_equipment_type() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_equipment_type() TO authenticated;
COMMIT;
