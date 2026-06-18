BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_buyer_mix();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_buyer_mix()
RETURNS TABLE (
  buyer_role  text,
  orders_90d  bigint,
  rupees_90d  numeric,
  share_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_amount numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(o.total_amount), 0)::numeric INTO v_total_amount
    FROM public.spare_part_orders o
    WHERE o.created_at >= now() - interval '90 days';
  RETURN QUERY
  SELECT
    coalesce(p.role::text, '(unknown)') AS buyer_role,
    count(*)::bigint,
    coalesce(sum(o.total_amount), 0)::numeric,
    CASE WHEN v_total_amount = 0 THEN 0::numeric
         ELSE round(coalesce(sum(o.total_amount), 0)::numeric / v_total_amount * 100.0, 1)
    END
  FROM public.spare_part_orders o
  LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
  WHERE o.created_at >= now() - interval '90 days'
  GROUP BY p.role
  ORDER BY rupees_90d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_buyer_mix() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_buyer_mix() TO authenticated;
COMMIT;
