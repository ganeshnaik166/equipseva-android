-- v2.1 PR-D23: engineer-side "money in flight" summary.
--
-- Anti-disintermediation reinforcement: the engineer's earnings tab
-- currently estimates "paid vs pending" from bid amounts, ignoring
-- whether the hospital has actually paid into escrow. That makes the
-- app look like a worse bookkeeping tool than the engineer's notebook.
--
-- This RPC returns a single-row summary the engineer can see at the
-- top of Earnings:
--   * total_held_rupees     — hospital paid, awaiting release
--   * count_held            — number of held escrow rows
--   * next_release_at       — soonest scheduled_release_at (held only)
--   * total_released_rupees_30d — actual money settled in last 30 days
--   * count_in_dispute      — disputes blocking payout
--
-- Visible incoming money is the strongest "use the app to get paid"
-- signal we have. SECDEF + caller-uid filter so engineers only see
-- their own row.

CREATE OR REPLACE FUNCTION public.engineer_escrow_summary()
RETURNS TABLE (
  total_held_rupees           numeric,
  count_held                  int,
  next_release_at             timestamptz,
  total_released_rupees_30d   numeric,
  count_in_dispute            int,
  count_pending_payment       int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    coalesce(sum(amount_rupees) FILTER (WHERE status = 'held'), 0)::numeric    AS total_held_rupees,
    coalesce(count(*) FILTER (WHERE status = 'held'), 0)::int                  AS count_held,
    min(scheduled_release_at) FILTER (WHERE status = 'held')                   AS next_release_at,
    coalesce(
      sum(amount_rupees) FILTER (
        WHERE status = 'released'
          AND released_at >= now() - interval '30 days'
      ), 0
    )::numeric                                                                AS total_released_rupees_30d,
    coalesce(count(*) FILTER (WHERE status = 'in_dispute'), 0)::int           AS count_in_dispute,
    coalesce(count(*) FILTER (WHERE status = 'pending'), 0)::int              AS count_pending_payment
  FROM public.repair_job_escrow
  WHERE engineer_user_id = v_caller;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_escrow_summary() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_escrow_summary() TO authenticated;
