BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_graduations_recent();
CREATE OR REPLACE FUNCTION public.founder_tier_graduations_recent()
RETURNS TABLE (
  user_id        uuid,
  display_name   text,
  old_tier       text,
  new_tier       text,
  direction      text,
  changed_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tier_rank(tier, rank) AS (
    VALUES ('none'::text, 0), ('bronze', 1), ('silver', 2), ('gold', 3)
  )
  SELECT
    h.user_id,
    coalesce(p.full_name, '(engineer)'),
    h.old_tier,
    h.new_tier,
    CASE WHEN tr_new.rank > tr_old.rank THEN 'promotion'
         WHEN tr_new.rank < tr_old.rank THEN 'demotion'
         ELSE 'lateral'
    END,
    h.changed_at
  FROM public.engineer_tier_history h
  LEFT JOIN public.profiles p ON p.id = h.user_id
  LEFT JOIN tier_rank tr_old ON tr_old.tier = h.old_tier
  LEFT JOIN tier_rank tr_new ON tr_new.tier = h.new_tier
  WHERE h.changed_at >= now() - interval '30 days'
  ORDER BY h.changed_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_graduations_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_graduations_recent() TO authenticated;
COMMIT;
