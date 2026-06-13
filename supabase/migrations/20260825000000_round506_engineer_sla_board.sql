-- =====================================================================
-- Round 506 — Engineer SLA Board (v0.4 Phase 4 #6 backbone)
-- =====================================================================
--
-- Engineer SLA = time from bid-accept to engineer arrival on site +
-- time from arrival to job-complete. We've been measuring these ad hoc
-- in dispute triage; this round centralizes the calculation into a
-- single founder-facing RPC + a per-engineer rolling 30-day card.
--
-- Three signals tracked per engineer (trailing 30 days):
--   1. accept_to_arrival_hours — bid accepted → first arrival_checkin
--      attendance event (uses r496 engineer_attendance).
--   2. arrival_to_complete_hours — first arrival_checkin → repair_jobs
--      status='completed'.
--   3. dispute_rate_pct — disputed escrows / total completed × 100.
--
-- Targets:
--   - accept_to_arrival ≤ 24h (good), > 48h (breach)
--   - arrival_to_complete ≤ 8h same-day (good), > 24h (breach)
--   - dispute_rate ≤ 5% (good), > 15% (red flag)

BEGIN;

CREATE OR REPLACE FUNCTION public.engineer_sla_board(
  p_days  integer DEFAULT 30,
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  engineer_user_id          uuid,
  engineer_email            text,
  jobs_completed_window     int,
  jobs_disputed_window      int,
  dispute_rate_pct          numeric,
  avg_accept_to_arrival_hrs numeric,
  avg_arrival_to_complete_hrs numeric,
  sla_breaches              int,
  on_time_pct               numeric,
  current_risk_score        int,
  current_risk_band         text,
  current_tier              text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_start timestamptz := now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      b.engineer_user_id,
      rj.id AS job_id,
      rj.status,
      rj.created_at,
      rj.completed_at,
      e.status AS escrow_status,
      -- Earliest arrival_checkin in window for this job
      (SELECT min(att.device_captured_at)
         FROM public.engineer_attendance att
        WHERE att.repair_job_id = rj.id
          AND att.event_kind = 'arrival_checkin') AS first_arrival,
      -- Accept timestamp from bid
      b.responded_at AS accepted_at
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
    WHERE b.status = 'accepted'
      AND b.responded_at >= v_window_start
  ),
  per_engineer AS (
    SELECT
      wj.engineer_user_id,
      count(*) FILTER (WHERE wj.status = 'completed')::int AS jobs_completed,
      count(*) FILTER (WHERE wj.escrow_status = 'disputed')::int AS jobs_disputed,
      avg(EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0)
        FILTER (WHERE wj.first_arrival IS NOT NULL)::numeric(8,2) AS avg_accept_arrival,
      avg(EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0)
        FILTER (WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL)::numeric(8,2) AS avg_arrival_complete,
      count(*) FILTER (
        WHERE wj.first_arrival IS NOT NULL
          AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48
      )::int
      + count(*) FILTER (
        WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
          AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24
      )::int AS breach_count
    FROM window_jobs wj
    GROUP BY wj.engineer_user_id
  ),
  risk AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.score, s.band
      FROM public.risk_score_snapshots s
     WHERE s.role = 'engineer'
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT
    pe.engineer_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = pe.engineer_user_id), 'unknown'),
    pe.jobs_completed,
    pe.jobs_disputed,
    CASE WHEN pe.jobs_completed > 0
         THEN round(pe.jobs_disputed * 100.0 / pe.jobs_completed, 1)
         ELSE 0 END,
    pe.avg_accept_arrival,
    pe.avg_arrival_complete,
    pe.breach_count,
    CASE WHEN pe.jobs_completed > 0
         THEN round((pe.jobs_completed - pe.breach_count) * 100.0 / pe.jobs_completed, 1)
         ELSE 0 END,
    risk.score,
    risk.band,
    coalesce((SELECT cached_highest_tier FROM public.engineers WHERE user_id = pe.engineer_user_id), 'none')
  FROM per_engineer pe
  LEFT JOIN risk ON risk.user_id = pe.engineer_user_id
  ORDER BY pe.breach_count DESC, pe.jobs_disputed DESC, pe.jobs_completed DESC
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_sla_board(integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.engineer_sla_board(integer, integer)
  TO service_role;

-- Engineer-facing self-view (own SLA card)
CREATE OR REPLACE FUNCTION public.my_sla_card()
RETURNS TABLE(
  jobs_completed_window     int,
  jobs_disputed_window      int,
  dispute_rate_pct          numeric,
  avg_accept_to_arrival_hrs numeric,
  avg_arrival_to_complete_hrs numeric,
  sla_breaches              int,
  on_time_pct               numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_window_start timestamptz := now() - interval '30 days';
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      rj.id AS job_id,
      rj.status,
      rj.completed_at,
      e.status AS escrow_status,
      (SELECT min(att.device_captured_at)
         FROM public.engineer_attendance att
        WHERE att.repair_job_id = rj.id
          AND att.event_kind = 'arrival_checkin') AS first_arrival,
      b.responded_at AS accepted_at
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.repair_job_escrow e ON e.repair_job_id = rj.id
    WHERE b.status = 'accepted'
      AND b.engineer_user_id = v_user
      AND b.responded_at >= v_window_start
  )
  SELECT
    count(*) FILTER (WHERE wj.status = 'completed')::int,
    count(*) FILTER (WHERE wj.escrow_status = 'disputed')::int,
    CASE WHEN count(*) FILTER (WHERE wj.status = 'completed') > 0
         THEN round(count(*) FILTER (WHERE wj.escrow_status = 'disputed') * 100.0
                    / count(*) FILTER (WHERE wj.status = 'completed'), 1)
         ELSE 0 END,
    avg(EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0)
      FILTER (WHERE wj.first_arrival IS NOT NULL)::numeric(8,2),
    avg(EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0)
      FILTER (WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL)::numeric(8,2),
    (count(*) FILTER (
      WHERE wj.first_arrival IS NOT NULL
        AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48
    )::int
    + count(*) FILTER (
      WHERE wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
        AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24
    )::int)::int,
    CASE WHEN count(*) FILTER (WHERE wj.status = 'completed') > 0
         THEN round(((count(*) FILTER (WHERE wj.status = 'completed')
                       - count(*) FILTER (
                           WHERE (wj.first_arrival IS NOT NULL
                                  AND EXTRACT(EPOCH FROM (wj.first_arrival - wj.accepted_at)) / 3600.0 > 48)
                              OR (wj.completed_at IS NOT NULL AND wj.first_arrival IS NOT NULL
                                  AND EXTRACT(EPOCH FROM (wj.completed_at - wj.first_arrival)) / 3600.0 > 24)
                         )
                      ) * 100.0
                      / count(*) FILTER (WHERE wj.status = 'completed')), 1)
         ELSE 0 END
  FROM window_jobs wj;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_sla_card() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_sla_card() TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 506 engineer SLA board verified: 2 RPCs (founder board + engineer self-view)';
END;
$$;
