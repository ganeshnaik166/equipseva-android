BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_visits_cadence();
CREATE OR REPLACE FUNCTION public.founder_amc_visits_cadence()
RETURNS TABLE (
  visit_frequency text,
  active_cnt      bigint,
  visits_done     bigint,
  visits_sched    bigint,
  completion_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH freqs(visit_frequency, ord) AS (
    VALUES ('weekly'::text, 1), ('biweekly'::text, 2), ('monthly'::text, 3), ('quarterly'::text, 4)
  )
  SELECT
    f.visit_frequency,
    count(c.id)::bigint                                              AS active_cnt,
    coalesce(sum(c.visits_completed), 0)::bigint                     AS visits_done,
    coalesce(sum(c.visits_scheduled), 0)::bigint                     AS visits_sched,
    CASE WHEN coalesce(sum(c.visits_scheduled), 0) = 0 THEN 0::numeric
         ELSE round(
           coalesce(sum(c.visits_completed), 0)::numeric
           / coalesce(sum(c.visits_scheduled), 0)::numeric * 100.0, 1)
    END AS completion_pct
  FROM freqs f
  LEFT JOIN public.amc_contracts c ON c.visit_frequency = f.visit_frequency AND c.status = 'active'
  GROUP BY f.visit_frequency, f.ord
  ORDER BY f.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_visits_cadence() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_visits_cadence() TO authenticated;
COMMIT;
