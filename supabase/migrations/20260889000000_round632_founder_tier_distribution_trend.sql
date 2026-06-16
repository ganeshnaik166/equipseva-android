BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_distribution_trend();
CREATE OR REPLACE FUNCTION public.founder_tier_distribution_trend()
RETURNS TABLE (
  tier            text,
  current_cnt     bigint,
  promotions_30d  bigint,
  demotions_30d   bigint,
  net_30d         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '30 days';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze'::text, 2), ('silver'::text, 3), ('gold'::text, 4)
  ),
  cur AS (
    SELECT current_tier AS tier, count(*)::bigint AS cnt
    FROM public.engineer_certification_progress
    GROUP BY current_tier
  ),
  promo AS (
    SELECT h.new_tier AS tier, count(*)::bigint AS cnt
    FROM public.engineer_tier_history h
    WHERE h.changed_at >= v_cutoff
      AND CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
    GROUP BY h.new_tier
  ),
  demo AS (
    SELECT h.new_tier AS tier, count(*)::bigint AS cnt
    FROM public.engineer_tier_history h
    WHERE h.changed_at >= v_cutoff
      AND CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
        < CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
    GROUP BY h.new_tier
  )
  SELECT
    t.tier,
    coalesce(c.cnt, 0)::bigint,
    coalesce(p.cnt, 0)::bigint,
    coalesce(d.cnt, 0)::bigint,
    (coalesce(p.cnt, 0) - coalesce(d.cnt, 0))::bigint
  FROM tiers t
  LEFT JOIN cur   c ON c.tier = t.tier
  LEFT JOIN promo p ON p.tier = t.tier
  LEFT JOIN demo  d ON d.tier = t.tier
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_distribution_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_distribution_trend() TO authenticated;
COMMIT;
