BEGIN;
DROP FUNCTION IF EXISTS public.founder_disputes_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_disputes_by_day_30d()
RETURNS TABLE (
  day_ist          date,
  submitted        bigint,
  resolved         bigint,
  open_eod         bigint
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
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs e
              WHERE e.submitted_at IS NOT NULL
                AND (e.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS submitted,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs e
              WHERE e.status IN ('accepted','rejected')
                AND e.mediator_decision_at IS NOT NULL
                AND (e.mediator_decision_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)               AS resolved,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs e
              WHERE e.status = 'submitted'
                AND e.submitted_at IS NOT NULL
                AND (e.submitted_at AT TIME ZONE 'Asia/Kolkata')::date <= d.day_ist
                AND (e.mediator_decision_at IS NULL OR (e.mediator_decision_at AT TIME ZONE 'Asia/Kolkata')::date > d.day_ist)), 0) AS open_eod
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_disputes_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_disputes_by_day_30d() TO authenticated;
COMMIT;
