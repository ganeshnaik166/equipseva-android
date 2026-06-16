BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineers_missing_payout();
CREATE OR REPLACE FUNCTION public.founder_engineers_missing_payout()
RETURNS TABLE (
  engineer_user_id   uuid,
  display_name       text,
  jobs_completed_30d bigint,
  gross_earned_30d   numeric,
  queued_payouts     bigint,
  oldest_queue_days  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active_earners AS (
    SELECT
      b.engineer_user_id,
      count(*)::bigint                                     AS jobs_completed_30d,
      coalesce(sum(rj.contracted_amount_rupees), 0)::numeric AS gross_earned_30d
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '30 days'
    GROUP BY b.engineer_user_id
  ),
  no_method AS (
    SELECT ae.engineer_user_id, ae.jobs_completed_30d, ae.gross_earned_30d
    FROM active_earners ae
    WHERE NOT EXISTS (
      SELECT 1 FROM public.engineer_payout_methods m
       WHERE m.engineer_user_id = ae.engineer_user_id
         AND m.status = 'verified'
    )
  )
  SELECT
    nm.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    nm.jobs_completed_30d,
    nm.gross_earned_30d,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts ep
              WHERE ep.engineer_user_id = nm.engineer_user_id
                AND ep.status = 'queued'
                AND ep.payout_method_id IS NULL), 0)::bigint AS queued_payouts,
    coalesce((SELECT (extract(epoch FROM (now() - min(ep.queued_at)))::int / 86400)
              FROM public.engineer_payouts ep
              WHERE ep.engineer_user_id = nm.engineer_user_id
                AND ep.status = 'queued'
                AND ep.payout_method_id IS NULL), 0)::int AS oldest_queue_days
  FROM no_method nm
  LEFT JOIN public.profiles p ON p.id = nm.engineer_user_id
  ORDER BY nm.gross_earned_30d DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_missing_payout() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_missing_payout() TO authenticated;
COMMIT;
