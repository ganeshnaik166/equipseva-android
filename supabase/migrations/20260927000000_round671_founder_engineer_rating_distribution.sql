BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_rating_distribution();
CREATE OR REPLACE FUNCTION public.founder_engineer_rating_distribution()
RETURNS TABLE (
  rating_bucket text,
  cnt           bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH buckets(label, ord) AS (
    VALUES
      ('5 stars'::text,         1),
      ('4 stars'::text,         2),
      ('3 stars'::text,         3),
      ('2 stars'::text,         4),
      ('1 star'::text,          5),
      ('(no rating)'::text,     6)
  )
  SELECT b.label,
    coalesce(count(*) FILTER (
      WHERE (b.ord = 1 AND rj.engineer_rating = 5)
         OR (b.ord = 2 AND rj.engineer_rating = 4)
         OR (b.ord = 3 AND rj.engineer_rating = 3)
         OR (b.ord = 4 AND rj.engineer_rating = 2)
         OR (b.ord = 5 AND rj.engineer_rating = 1)
         OR (b.ord = 6 AND rj.engineer_rating IS NULL)
    ), 0)::bigint
  FROM buckets b
  LEFT JOIN public.repair_jobs rj
    ON rj.status = 'completed'
   AND rj.completed_at >= now() - interval '180 days'
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_rating_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_rating_distribution() TO authenticated;
COMMIT;
