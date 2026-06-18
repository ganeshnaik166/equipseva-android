BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_signals_recent();
CREATE OR REPLACE FUNCTION public.founder_demand_signals_recent()
RETURNS TABLE (
  id              uuid,
  source          text,
  reporter_role   text,
  part_number     text,
  equipment_model text,
  founder_priority text,
  resolved_at     timestamptz,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.source,
    d.reporter_role,
    d.part_number,
    d.equipment_model,
    d.founder_priority,
    d.resolved_at,
    d.created_at
  FROM public.spare_part_demand_signals d
  WHERE d.created_at >= now() - interval '30 days'
  ORDER BY d.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_signals_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signals_recent() TO authenticated;
COMMIT;
