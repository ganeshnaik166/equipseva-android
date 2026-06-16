-- Round 729 — backfill engineers.completion_rate
--
-- r728 fixed engineer_public_profile to compute completion_rate dynamically
-- at read-time. But recommended_engineers_for_hospital (r311) still reads
-- the stored e.completion_rate column for ranking weight:
--
--     + 15.0 * (b.completion_rate / 100.0)   -- r311 line 224
--
-- Since the column is permanently 0, the 15% ranking weight from completion
-- is effectively dead — all engineers tied at 0. Backfilling lights up
-- the ranking signal so engineers with proven completion records rise.
--
-- Backfill formula matches r728:
--     completion_rate = completed / (completed + cancelled) × 100
--
-- Engineers with no resolved jobs stay at default 0 (current state).
BEGIN;

WITH stats AS (
  SELECT
    engineer_id,
    count(*) FILTER (WHERE status = 'completed')::numeric                                            AS done,
    count(*) FILTER (WHERE status IN ('completed','cancelled'))::numeric                             AS resolved
  FROM public.repair_jobs
  WHERE engineer_id IS NOT NULL
  GROUP BY engineer_id
  HAVING count(*) FILTER (WHERE status IN ('completed','cancelled')) > 0
)
UPDATE public.engineers e
   SET completion_rate = round(stats.done / stats.resolved * 100.0, 1)
  FROM stats
 WHERE e.id = stats.engineer_id;

COMMIT;
