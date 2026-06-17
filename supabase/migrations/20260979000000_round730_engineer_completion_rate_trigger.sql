-- Round 730 — keep engineers.completion_rate fresh via trigger
--
-- The three-act fix for the stale completion_rate column:
--   r728 — read-path fix in engineer_public_profile (dynamic compute)
--   r729 — one-time backfill of the stored column for ranking weight
--   r730 — THIS — trigger that recomputes on every status transition
--          so the column stays fresh going forward (no drift)
--
-- Trigger fires AFTER UPDATE OF status when transitioning into a
-- terminal state (completed/cancelled). Recomputes completion_rate for
-- the affected engineer using the same formula as r728/r729:
--     completed / (completed + cancelled) * 100
--
-- SECURITY DEFINER + owner=postgres clears the engineers_trust_columns_guard
-- the same way recompute_engineer_rating_aggregates (r503) does.
BEGIN;

CREATE OR REPLACE FUNCTION public.recompute_engineer_completion_rate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rate numeric;
BEGIN
  IF NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT
    CASE WHEN count(*) FILTER (WHERE status IN ('completed','cancelled')) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE status = 'completed')::numeric
           / count(*) FILTER (WHERE status IN ('completed','cancelled'))::numeric
           * 100.0, 1)
    END
    INTO v_rate
    FROM public.repair_jobs
    WHERE engineer_id = NEW.engineer_id;

  UPDATE public.engineers
     SET completion_rate = v_rate
   WHERE id = NEW.engineer_id;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.recompute_engineer_completion_rate() OWNER TO postgres;

DROP TRIGGER IF EXISTS recompute_engineer_completion_rate_trg ON public.repair_jobs;
CREATE TRIGGER recompute_engineer_completion_rate_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.status::text IS DISTINCT FROM OLD.status::text
    AND NEW.status::text IN ('completed','cancelled')
    AND NEW.engineer_id IS NOT NULL
  )
  EXECUTE FUNCTION public.recompute_engineer_completion_rate();

REVOKE ALL ON FUNCTION public.recompute_engineer_completion_rate() FROM PUBLIC;

COMMIT;
