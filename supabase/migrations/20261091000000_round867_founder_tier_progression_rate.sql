BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_progression_rate();
CREATE OR REPLACE FUNCTION public.founder_tier_progression_rate()
RETURNS TABLE (
  window_label    text,
  active_engineers bigint,
  promoted         bigint,
  demoted          bigint,
  net_promoted     bigint,
  promotion_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text,  1, now() - interval '30 days'),
      ('90d'::text,  2, now() - interval '90 days'),
      ('365d'::text, 3, now() - interval '365 days')
  ),
  tier_rank(tier, rank) AS (
    VALUES ('none'::text, 0), ('bronze', 1), ('silver', 2), ('gold', 3)
  ),
  events AS (
    SELECT h.user_id, h.changed_at,
           tr_old.rank AS old_rank, tr_new.rank AS new_rank
    FROM public.engineer_tier_history h
    LEFT JOIN tier_rank tr_old ON tr_old.tier = h.old_tier
    LEFT JOIN tier_rank tr_new ON tr_new.tier = h.new_tier
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.engineer_certification_progress), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank < e.old_rank), 0)::bigint,
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)::bigint
    -
    coalesce((SELECT count(DISTINCT e.user_id)::bigint FROM events e
              WHERE e.changed_at >= w.cutoff AND e.new_rank < e.old_rank), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.engineer_certification_progress), 0) = 0
         THEN 0::numeric
         ELSE round(
           coalesce((SELECT count(DISTINCT e.user_id)::numeric FROM events e
                     WHERE e.changed_at >= w.cutoff AND e.new_rank > e.old_rank), 0)
           / (SELECT count(*)::numeric FROM public.engineer_certification_progress)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_progression_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_progression_rate() TO authenticated;
COMMIT;
