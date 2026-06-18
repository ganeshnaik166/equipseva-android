BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_flow_by_day();
CREATE OR REPLACE FUNCTION public.founder_escrow_flow_by_day()
RETURNS TABLE (
  day_ist        date,
  inflow_rupees  numeric,
  release_rupees numeric,
  refund_rupees  numeric,
  net_rupees     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
              WHERE e.status IN ('paid','disputed','held','released','refunded')
                AND (e.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric,
    coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
              WHERE e.status = 'released'
                AND (e.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric,
    coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
              WHERE e.status = 'refunded'
                AND (e.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric,
    coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
              WHERE e.status IN ('paid','disputed','held','released','refunded')
                AND (e.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric
    -
    coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
              WHERE e.status IN ('released','refunded')
                AND (e.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_flow_by_day() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_flow_by_day() TO authenticated;
COMMIT;
