BEGIN;
DROP FUNCTION IF EXISTS public.founder_equipment_type_breakdown();
CREATE OR REPLACE FUNCTION public.founder_equipment_type_breakdown()
RETURNS TABLE (
  equipment_type   text,
  total_jobs       bigint,
  completed_jobs   bigint,
  open_jobs        bigint,
  avg_completion_h numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(j.equipment_type), ''), '(unspecified)')::text       AS equipment_type,
    count(*)::bigint                                                          AS total_jobs,
    count(*) FILTER (WHERE j.status = 'completed')::bigint                    AS completed_jobs,
    count(*) FILTER (WHERE j.status IN ('open','posted'))::bigint             AS open_jobs,
    round(
      avg(extract(epoch from (j.completed_at - j.created_at)) / 3600.0)
        FILTER (WHERE j.status = 'completed' AND j.completed_at IS NOT NULL),
      1
    )::numeric                                                                AS avg_completion_h
  FROM public.repair_jobs j
  WHERE j.created_at >= now() - interval '90 days'
  GROUP BY coalesce(nullif(trim(j.equipment_type), ''), '(unspecified)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_type_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_type_breakdown() TO authenticated;
COMMIT;
