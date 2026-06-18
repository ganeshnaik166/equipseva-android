BEGIN;
DROP FUNCTION IF EXISTS public.founder_disputes_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_disputes_by_week_13wk()
RETURNS TABLE (
  week_start    date,
  submitted     bigint,
  resolved      bigint,
  open_eow      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL
                AND date_trunc('week', (d.submitted_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS submitted,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.status IN ('accepted','rejected')
                AND d.mediator_decision_at IS NOT NULL
                AND date_trunc('week', (d.mediator_decision_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)      AS resolved,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.status = 'submitted'
                AND d.submitted_at IS NOT NULL
                AND (d.submitted_at AT TIME ZONE 'Asia/Kolkata')::date <= (w.week_start + interval '6 days')::date
                AND (d.mediator_decision_at IS NULL OR (d.mediator_decision_at AT TIME ZONE 'Asia/Kolkata')::date > (w.week_start + interval '6 days')::date)), 0) AS open_eow
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_disputes_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_disputes_by_week_13wk() TO authenticated;
COMMIT;
