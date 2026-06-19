BEGIN;

DROP FUNCTION IF EXISTS public.founder_repair_job_cost_revisions_summary();

CREATE OR REPLACE FUNCTION public.founder_repair_job_cost_revisions_summary()
RETURNS TABLE (
  total_all_time bigint,
  proposed_now bigint,
  approved_all_time bigint,
  rejected_all_time bigint,
  expired_all_time bigint,
  approval_pct_all_time numeric,
  proposed_30d bigint,
  approved_30d bigint,
  rejected_30d bigint,
  avg_uplift_pct_approved_30d numeric,
  total_uplift_inr_approved_30d numeric,
  jobs_with_revision_30d bigint,
  top_engineer_proposals_30d bigint,
  avg_decide_hours_30d numeric
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
  WITH base AS (
    SELECT * FROM public.repair_job_cost_revisions
  ),
  approved_30 AS (
    SELECT
      revised_amount_rupees,
      original_amount_rupees,
      (revised_amount_rupees - original_amount_rupees) AS uplift_inr,
      CASE WHEN original_amount_rupees > 0
           THEN ((revised_amount_rupees - original_amount_rupees) / original_amount_rupees) * 100.0
           ELSE 0 END AS uplift_pct
    FROM base
    WHERE status = 'approved'
      AND decided_at >= now() - interval '30 days'
  ),
  decided_30 AS (
    SELECT EXTRACT(EPOCH FROM (decided_at - created_at))/3600.0 AS hrs
    FROM base
    WHERE decided_at >= now() - interval '30 days'
      AND status IN ('approved','rejected')
  ),
  engineer_30 AS (
    SELECT engineer_user_id, count(*) AS c
    FROM base
    WHERE created_at >= now() - interval '30 days'
    GROUP BY engineer_user_id
    ORDER BY c DESC
    LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE status = 'proposed')::bigint,
    (SELECT count(*) FROM base WHERE status = 'approved')::bigint,
    (SELECT count(*) FROM base WHERE status = 'rejected')::bigint,
    (SELECT count(*) FROM base WHERE status = 'expired')::bigint,
    COALESCE(
      ROUND(
        (SELECT count(*) FROM base WHERE status = 'approved')::numeric
        / NULLIF((SELECT count(*) FROM base WHERE status IN ('approved','rejected','expired')), 0)
        * 100.0, 1),
      0)::numeric,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM base WHERE status = 'approved' AND decided_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM base WHERE status = 'rejected' AND decided_at >= now() - interval '30 days')::bigint,
    COALESCE(ROUND((SELECT AVG(uplift_pct) FROM approved_30)::numeric, 1), 0)::numeric,
    COALESCE((SELECT SUM(uplift_inr) FROM approved_30)::numeric, 0)::numeric,
    (SELECT count(DISTINCT repair_job_id) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    COALESCE((SELECT c FROM engineer_30), 0)::bigint,
    COALESCE(ROUND((SELECT AVG(hrs) FROM decided_30)::numeric, 1), 0)::numeric;
END;
$$;

ALTER FUNCTION public.founder_repair_job_cost_revisions_summary() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.founder_repair_job_cost_revisions_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_job_cost_revisions_summary() TO authenticated;

COMMIT;