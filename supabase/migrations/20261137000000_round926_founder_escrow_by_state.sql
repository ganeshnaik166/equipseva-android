BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_by_state();
CREATE OR REPLACE FUNCTION public.founder_escrow_by_state()
RETURNS TABLE (
  state         text,
  held_rupees   numeric,
  released_90d  numeric,
  refunded_90d  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      e.amount_rupees,
      e.status,
      e.updated_at
    FROM public.repair_job_escrow e
    JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  )
  SELECT
    b.state,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status IN ('paid','disputed','held')), 0)::numeric,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='released' AND b.updated_at >= now() - interval '90 days'), 0)::numeric,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status='refunded' AND b.updated_at >= now() - interval '90 days'), 0)::numeric
  FROM base b
  GROUP BY b.state
  ORDER BY held_rupees DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_by_state() TO authenticated;
COMMIT;
