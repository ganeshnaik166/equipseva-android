-- Light up the engineers.rating_avg / total_jobs columns so the directory
-- ranking (engineers_directory_search RPC sorts by rating_avg DESC) actually
-- reflects reality. The columns existed since 20260427010000 but were never
-- populated — every engineer surfaced with rating_avg=0.
--
-- Trigger fires AFTER UPDATE on repair_jobs whenever hospital_rating is set
-- to a non-null value. SECURITY DEFINER + owner=postgres clears the
-- engineers_trust_columns_guard via its existing session_user='postgres'
-- bypass (see 20260428290000_security_engineers_replace_lockdown_with_guard).
-- We do NOT touch the bid-side or rating-side guards; this trigger only
-- updates the engineer's aggregate row.
--
-- A one-time idempotent backfill at the bottom lights up history so the
-- first directory load after this migration ranks correctly without waiting
-- for new ratings to roll in.

CREATE OR REPLACE FUNCTION public.recompute_engineer_rating_aggregates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_avg numeric;
  v_cnt int;
BEGIN
  IF NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(AVG(hospital_rating)::numeric(10,2), 0), COUNT(*)
    INTO v_avg, v_cnt
    FROM public.repair_jobs
    WHERE engineer_id = NEW.engineer_id
      AND hospital_rating IS NOT NULL
      AND status::text = 'completed';

  UPDATE public.engineers
     SET rating_avg = v_avg,
         total_jobs = v_cnt
   WHERE id = NEW.engineer_id;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.recompute_engineer_rating_aggregates() OWNER TO postgres;

DROP TRIGGER IF EXISTS recompute_engineer_rating_aggregates_trg ON public.repair_jobs;
CREATE TRIGGER recompute_engineer_rating_aggregates_trg
  AFTER UPDATE OF hospital_rating ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.hospital_rating IS DISTINCT FROM OLD.hospital_rating
    AND NEW.hospital_rating IS NOT NULL
    AND NEW.engineer_id IS NOT NULL
  )
  EXECUTE FUNCTION public.recompute_engineer_rating_aggregates();

-- Idempotent historical backfill. Re-running this migration after data
-- drifts is safe: the join overwrites engineers.rating_avg / total_jobs
-- with the recomputed values; engineers with no rated completed jobs
-- aren't touched (so they keep their default 0).
WITH agg AS (
  SELECT engineer_id,
         COALESCE(AVG(hospital_rating)::numeric(10,2), 0) AS avg_rating,
         COUNT(*)                                          AS total
    FROM public.repair_jobs
   WHERE hospital_rating IS NOT NULL
     AND status::text = 'completed'
     AND engineer_id IS NOT NULL
   GROUP BY engineer_id
)
UPDATE public.engineers e
   SET rating_avg = agg.avg_rating,
       total_jobs = agg.total
  FROM agg
 WHERE e.id = agg.engineer_id;

REVOKE ALL ON FUNCTION public.recompute_engineer_rating_aggregates() FROM PUBLIC;
