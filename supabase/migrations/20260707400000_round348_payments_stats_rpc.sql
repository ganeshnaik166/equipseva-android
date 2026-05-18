-- Round 348 — admin_recent_payments_stats: GMV + status counts for the
-- Founder Payments header. Sums over the full window, not just the 50-row
-- page surfaced by admin_recent_payments, so the card stays accurate when
-- ops volume crosses the page size.

CREATE OR REPLACE FUNCTION public.admin_recent_payments_stats(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  window_days int,
  total_orders bigint,
  paid_count bigint,
  failed_count bigint,
  pending_count bigint,
  refunded_count bigint,
  gmv_paid_inr numeric,
  gmv_refunded_inr numeric,
  largest_paid_inr numeric,
  last_paid_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
  v_cutoff timestamptz := now() - make_interval(days => v_days);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      v_days,
      count(*)::bigint,
      count(*) FILTER (WHERE o.payment_status::text = 'paid')::bigint,
      count(*) FILTER (WHERE o.payment_status::text = 'failed')::bigint,
      count(*) FILTER (WHERE o.payment_status::text = 'pending')::bigint,
      count(*) FILTER (WHERE o.payment_status::text = 'refunded')::bigint,
      coalesce(sum(o.total_amount) FILTER (WHERE o.payment_status::text = 'paid'), 0)::numeric,
      coalesce(sum(o.total_amount) FILTER (WHERE o.payment_status::text = 'refunded'), 0)::numeric,
      coalesce(max(o.total_amount) FILTER (WHERE o.payment_status::text = 'paid'), 0)::numeric,
      max(o.created_at) FILTER (WHERE o.payment_status::text = 'paid')
    FROM public.spare_part_orders o
    WHERE o.created_at >= v_cutoff;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_recent_payments_stats(int) TO authenticated;
