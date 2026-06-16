-- =====================================================================
-- Round 607 — Founder escrow age-bucket view
-- =====================================================================
--
-- Money held in escrow >7d / >30d is a real cash-flow concern: it's
-- either a stuck dispute, an absent hospital signoff, or an engineer
-- who walked away. Today the only way to see this is to scroll the
-- per-job escrow table. r607 ships a single roll-up with one row per
-- age bucket × status so the founder can spot stuck cash in one glance.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_escrow_age_buckets();

CREATE OR REPLACE FUNCTION public.founder_escrow_age_buckets()
RETURNS TABLE (
  bucket          text,
  status          text,
  job_count       bigint,
  total_rupees    numeric,
  oldest_age_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH live AS (
    SELECT
      CASE
        WHEN e.created_at >= now() - interval '7 days'  THEN '0-7d'
        WHEN e.created_at >= now() - interval '30 days' THEN '7-30d'
        WHEN e.created_at >= now() - interval '90 days' THEN '30-90d'
        ELSE '>90d'
      END                                                  AS bucket,
      e.status,
      e.amount_rupees,
      extract(epoch FROM (now() - e.created_at))::int / 86400 AS age_days
    FROM public.repair_job_escrow e
    WHERE e.status IN ('pending','held','in_dispute')
  )
  SELECT
    l.bucket,
    l.status,
    count(*)::bigint                                  AS job_count,
    coalesce(sum(l.amount_rupees), 0)::numeric        AS total_rupees,
    max(l.age_days)                                   AS oldest_age_days
  FROM live l
  GROUP BY l.bucket, l.status
  ORDER BY
    CASE l.bucket
      WHEN '>90d'  THEN 1
      WHEN '30-90d' THEN 2
      WHEN '7-30d'  THEN 3
      WHEN '0-7d'   THEN 4
    END,
    l.status;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_escrow_age_buckets() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_age_buckets() TO authenticated;

COMMENT ON FUNCTION public.founder_escrow_age_buckets() IS
  'r607: founder-only escrow age × status roll-up. Surfaces stuck cash by bucket (0-7d / 7-30d / 30-90d / >90d) × status (pending / held / in_dispute).';

COMMIT;
