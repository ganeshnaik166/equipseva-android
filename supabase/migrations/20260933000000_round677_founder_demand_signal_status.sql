BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_signal_status();
CREATE OR REPLACE FUNCTION public.founder_demand_signal_status()
RETURNS TABLE (
  bucket  text,
  cnt     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH buckets(label, ord) AS (
    VALUES
      ('Open · low priority'::text,   1),
      ('Open · med priority'::text,   2),
      ('Open · high priority'::text,  3),
      ('Open · unprioritized'::text,  4),
      ('Resolved'::text,              5)
  )
  SELECT b.label,
    coalesce(count(*) FILTER (
      WHERE (b.ord = 1 AND s.resolved_at IS NULL AND s.founder_priority = 'low')
         OR (b.ord = 2 AND s.resolved_at IS NULL AND s.founder_priority = 'med')
         OR (b.ord = 3 AND s.resolved_at IS NULL AND s.founder_priority = 'high')
         OR (b.ord = 4 AND s.resolved_at IS NULL AND s.founder_priority IS NULL)
         OR (b.ord = 5 AND s.resolved_at IS NOT NULL)
    ), 0)::bigint
  FROM buckets b LEFT JOIN public.spare_part_demand_signals s ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_signal_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signal_status() TO authenticated;
COMMIT;
