-- Round 333 — wrap recompute_engineer_rating_aggregates body in
-- BEGIN/EXCEPTION so a failure inside the trigger never aborts the
-- parent UPDATE.
--
-- AFTER UPDATE trigger fires when hospital_rating changes on a
-- repair_jobs row. Body does a SELECT AVG/COUNT then UPDATE on the
-- engineers row. If the engineer row has been deleted (FK cascade
-- mid-flight, or a concurrent admin purge), the UPDATE silently
-- affects 0 rows. But if any future helper called inside the trigger
-- raises (e.g., a stricter constraint, a missing FK target), the
-- exception bubbles up and rolls back the parent rating write
-- entirely. The hospital tap on "Submit rating" then fails with a
-- confusing postgres error instead of just losing the aggregator
-- side-effect.
--
-- Wrap in BEGIN/EXCEPTION WHEN OTHERS so the parent tx is preserved
-- and we log via RAISE NOTICE for ops triage. Same defensive pattern
-- used in notifications_dispatch_push and other AFTER triggers.

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

  BEGIN
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
  EXCEPTION WHEN OTHERS THEN
    -- Don't abort the parent rating write just because we couldn't
    -- aggregate. Backfill will catch up on the next manual run, or
    -- the next rating write will retry.
    RAISE NOTICE
      'recompute_engineer_rating_aggregates failed for engineer_id=%: %',
      NEW.engineer_id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.recompute_engineer_rating_aggregates() OWNER TO postgres;
