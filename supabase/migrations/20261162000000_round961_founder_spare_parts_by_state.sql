BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_by_state();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_state()
RETURNS TABLE (
  state          text,
  buyers         bigint,
  orders_90d     bigint,
  rupees_90d     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      o.buyer_user_id,
      o.total_amount
    FROM public.spare_part_orders o
    LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
    WHERE o.created_at >= now() - interval '90 days'
  )
  SELECT
    b.state,
    count(DISTINCT b.buyer_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(b.total_amount), 0)::numeric
  FROM base b
  GROUP BY b.state
  ORDER BY rupees_90d DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_by_state() TO authenticated;
COMMIT;
