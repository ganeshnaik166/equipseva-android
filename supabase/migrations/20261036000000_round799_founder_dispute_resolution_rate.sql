BEGIN;
DROP FUNCTION IF EXISTS public.founder_dispute_resolution_rate();
CREATE OR REPLACE FUNCTION public.founder_dispute_resolution_rate()
RETURNS TABLE (
  window_label    text,
  submitted       bigint,
  resolved        bigint,
  pending         bigint,
  resolution_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff
                AND d.mediator_decision_at IS NOT NULL), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff
                AND d.mediator_decision_at IS NULL), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff
                AND d.mediator_decision_at IS NOT NULL)
           / (SELECT count(*)::numeric FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL AND d.submitted_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dispute_resolution_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_resolution_rate() TO authenticated;
COMMIT;
