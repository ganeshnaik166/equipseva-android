BEGIN;
DROP FUNCTION IF EXISTS public.founder_disputes_resolution_time_distribution();
CREATE OR REPLACE FUNCTION public.founder_disputes_resolution_time_distribution()
RETURNS TABLE (
  bucket          text,
  bucket_order    int,
  cnt             bigint,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_tot
  FROM public.dispute_evidence_packs
  WHERE status IN ('accepted','rejected')
    AND mediator_decision_at IS NOT NULL
    AND submitted_at IS NOT NULL
    AND mediator_decision_at >= now() - interval '90 days';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT
      extract(epoch from (d.mediator_decision_at - d.submitted_at)) / 3600.0 AS hrs
    FROM public.dispute_evidence_packs d
    WHERE d.status IN ('accepted','rejected')
      AND d.mediator_decision_at IS NOT NULL
      AND d.submitted_at IS NOT NULL
      AND d.mediator_decision_at >= now() - interval '90 days'
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN hrs < 4    THEN '<4h'
        WHEN hrs < 24   THEN '4-24h'
        WHEN hrs < 72   THEN '1-3d'
        WHEN hrs < 168  THEN '3-7d'
        WHEN hrs < 336  THEN '7-14d'
        ELSE '>14d'
      END                                  AS bucket,
      CASE
        WHEN hrs < 4    THEN 1
        WHEN hrs < 24   THEN 2
        WHEN hrs < 72   THEN 3
        WHEN hrs < 168  THEN 4
        WHEN hrs < 336  THEN 5
        ELSE 6
      END                                  AS bucket_order
    FROM agg
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                  AS cnt,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END  AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_disputes_resolution_time_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_disputes_resolution_time_distribution() TO authenticated;
COMMIT;
