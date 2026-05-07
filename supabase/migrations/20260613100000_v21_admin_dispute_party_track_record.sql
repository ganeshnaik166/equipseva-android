-- v2.1 PR-D35: dispute-party track record on admin dispute detail.
--
-- Today the admin dispute timeline (PR-D26) and resolve sheet
-- (PR-D32) show the immediate context — events + reason + engineer
-- response. They don't show pattern context: is THIS hospital filing
-- a lot of disputes? Is THIS engineer the recipient of many? That
-- pattern is exactly the weaponization signal admin needs to weight
-- judgement.
--
-- This RPC returns 90-day aggregated counts for both parties on a
-- given escrow:
--   * hospital: total disputes filed, count won (refunded), count
--     lost (released), count still open
--   * engineer: total disputes received, same breakdown
-- Single round-trip; admin reads numbers without leaving the screen.

CREATE OR REPLACE FUNCTION public.admin_dispute_party_track_record(
  p_escrow_id   uuid,
  p_window_days int DEFAULT 90
)
RETURNS TABLE (
  hospital_user_id        uuid,
  hospital_disputes_filed int,
  hospital_disputes_won   int,
  hospital_disputes_lost  int,
  hospital_disputes_open  int,
  engineer_user_id        uuid,
  engineer_disputes_recv  int,
  engineer_disputes_won   int,    -- engineer "won" = released to engineer
  engineer_disputes_lost  int,    -- engineer "lost" = refunded
  engineer_disputes_open  int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_escrow   record;
  v_since    timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_window_days <= 0 OR p_window_days > 365 THEN
    RAISE EXCEPTION 'window_days must be 1..365' USING ERRCODE = '22023';
  END IF;

  SELECT id, hospital_user_id, engineer_user_id INTO v_escrow
    FROM public.repair_job_escrow
   WHERE id = p_escrow_id;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;

  v_since := now() - make_interval(days => p_window_days);

  RETURN QUERY
  SELECT
    v_escrow.hospital_user_id  AS hospital_user_id,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
    ), 0) AS hospital_disputes_filed,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'refund'
    ), 0) AS hospital_disputes_won,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'release'
    ), 0) AS hospital_disputes_lost,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.status = 'in_dispute'
    ), 0) AS hospital_disputes_open,
    v_escrow.engineer_user_id  AS engineer_user_id,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
    ), 0) AS engineer_disputes_recv,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'release'
    ), 0) AS engineer_disputes_won,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'refund'
    ), 0) AS engineer_disputes_lost,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.status = 'in_dispute'
    ), 0) AS engineer_disputes_open;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_dispute_party_track_record(uuid, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_dispute_party_track_record(uuid, int) TO authenticated;
