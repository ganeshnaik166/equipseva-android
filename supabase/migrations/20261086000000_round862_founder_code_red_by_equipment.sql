BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_by_equipment();
CREATE OR REPLACE FUNCTION public.founder_code_red_by_equipment()
RETURNS TABLE (
  equipment_type text,
  cnt_90d        bigint,
  resolved_90d   bigint,
  timed_out_90d  bigint,
  resolution_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(r.equipment_type), ''), '(unknown)') AS equipment_type,
      r.status
    FROM public.code_red_requests r
    WHERE r.created_at >= now() - interval '90 days'
  )
  SELECT
    b.equipment_type,
    count(*)::bigint,
    count(*) FILTER (WHERE b.status = 'resolved')::bigint,
    count(*) FILTER (WHERE b.status = 'timed_out')::bigint,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.status = 'resolved')::numeric
                    / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.equipment_type
  ORDER BY cnt_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_by_equipment() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_by_equipment() TO authenticated;
COMMIT;
