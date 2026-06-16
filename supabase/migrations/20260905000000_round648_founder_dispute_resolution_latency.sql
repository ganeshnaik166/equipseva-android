BEGIN;
DROP FUNCTION IF EXISTS public.founder_dispute_resolution_latency();
CREATE OR REPLACE FUNCTION public.founder_dispute_resolution_latency()
RETURNS TABLE (
  window_label    text,
  resolved_cnt    bigint,
  avg_hours       numeric,
  p50_hours       numeric,
  p90_hours       numeric,
  unresolved_now  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_pending bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_pending
    FROM public.dispute_evidence_packs WHERE status = 'submitted';
  RETURN QUERY
  WITH base AS (
    SELECT
      d.submitted_at,
      d.mediator_decision_at,
      extract(epoch FROM (d.mediator_decision_at - d.submitted_at)) / 3600.0 AS hrs
    FROM public.dispute_evidence_packs d
    WHERE d.status IN ('accepted','rejected')
      AND d.mediator_decision_at IS NOT NULL
      AND d.submitted_at IS NOT NULL
  ),
  w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    count(*)::bigint                                                     AS resolved_cnt,
    coalesce(round(avg(b.hrs)::numeric, 1), 0)                           AS avg_hours,
    coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY b.hrs))::numeric, 1), 0) AS p50_hours,
    coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY b.hrs))::numeric, 1), 0) AS p90_hours,
    v_pending                                                            AS unresolved_now
  FROM w
  LEFT JOIN base b ON b.mediator_decision_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dispute_resolution_latency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_resolution_latency() TO authenticated;
COMMIT;
