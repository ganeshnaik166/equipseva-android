-- =====================================================================
-- Round 613 — Founder dispute resolution aging view
-- =====================================================================
BEGIN;

DROP FUNCTION IF EXISTS public.founder_dispute_aging();
CREATE OR REPLACE FUNCTION public.founder_dispute_aging()
RETURNS TABLE (
  bucket             text,
  submitted_count    bigint,
  accepted_count     bigint,
  rejected_count     bigint,
  oldest_age_days    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      CASE
        WHEN d.created_at >= now() - interval '3 days'  THEN '0-3d'
        WHEN d.created_at >= now() - interval '7 days'  THEN '3-7d'
        WHEN d.created_at >= now() - interval '30 days' THEN '7-30d'
        ELSE '>30d'
      END                                                  AS bucket,
      d.status,
      extract(epoch FROM (now() - d.created_at))::int / 86400 AS age_days
    FROM public.dispute_evidence_packs d
    WHERE d.status IN ('submitted','accepted','rejected')
  )
  SELECT
    b.bucket,
    count(*) FILTER (WHERE b.status = 'submitted')::bigint AS submitted_count,
    count(*) FILTER (WHERE b.status = 'accepted')::bigint  AS accepted_count,
    count(*) FILTER (WHERE b.status = 'rejected')::bigint  AS rejected_count,
    max(b.age_days)                                        AS oldest_age_days
  FROM base b
  GROUP BY b.bucket
  ORDER BY
    CASE b.bucket
      WHEN '>30d'  THEN 1
      WHEN '7-30d' THEN 2
      WHEN '3-7d'  THEN 3
      WHEN '0-3d'  THEN 4
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_dispute_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dispute_aging() TO authenticated;
COMMIT;
