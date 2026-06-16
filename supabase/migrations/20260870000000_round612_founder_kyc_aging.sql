-- =====================================================================
-- Round 612 — Founder KYC pipeline aging view
-- =====================================================================
-- Engineers stuck in 'pending' KYC are a real conversion leak. r612
-- surfaces how long they've been waiting by bucket so the founder can
-- triage the oldest first.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_kyc_aging();
CREATE OR REPLACE FUNCTION public.founder_kyc_aging()
RETURNS TABLE (
  bucket          text,
  pending_count   bigint,
  rejected_count  bigint,
  oldest_age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      CASE
        WHEN e.created_at >= now() - interval '3 days'  THEN '0-3d'
        WHEN e.created_at >= now() - interval '7 days'  THEN '3-7d'
        WHEN e.created_at >= now() - interval '30 days' THEN '7-30d'
        ELSE '>30d'
      END                                                 AS bucket,
      coalesce(e.verification_status, 'pending')          AS vs,
      extract(epoch FROM (now() - e.created_at))::int / 86400 AS age_days
    FROM public.engineers e
    WHERE coalesce(e.verification_status, 'pending') IN ('pending','rejected')
  )
  SELECT
    b.bucket,
    count(*) FILTER (WHERE b.vs = 'pending')::bigint   AS pending_count,
    count(*) FILTER (WHERE b.vs = 'rejected')::bigint  AS rejected_count,
    max(b.age_days)                                    AS oldest_age_days
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

REVOKE EXECUTE ON FUNCTION public.founder_kyc_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_kyc_aging() TO authenticated;
COMMIT;
