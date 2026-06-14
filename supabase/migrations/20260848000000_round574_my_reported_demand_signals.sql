-- Round 574 — Engineer self-view for demand signals (v0.5 P3 #2 transparency)
--
-- WHY: r571 shipped record_spare_part_demand_signal() so engineers and
-- hospitals can flag "I searched for this part, you don't carry it" /
-- "my RFQ found zero suppliers". Founder sees the aggregated dashboard
-- and resolves rows. But the original reporter has NO way to see what
-- they reported or whether anyone is acting on it. That's a trust hole:
-- engineers who don't see their reports acknowledged stop reporting.
--
-- This RPC closes the loop: every authenticated caller can list their
-- own reported demand signals, see if the founder flagged them
-- low/med/high priority, and see if/when/how they were resolved.
--
-- Privacy minimisation:
--   - Filters strictly by reporter_user_id = auth.uid(); no cross-user
--     leakage even if two engineers reported the same part.
--   - DOES NOT expose: notes (may contain founder-internal commentary),
--     hospital_org_id / job_id (cross-tenant context), search_query_norm
--     (may contain PHI-adjacent free text), reporter_role (derivable
--     anyway from the caller's own profile).
--   - DOES expose: founder_priority and resolved_via because they are
--     the actual "we see you" signal the engineer needs.
--
-- LIMIT 50, sorted occurred_at DESC — most engineers will have <10 rows,
-- 50 is enough to cover heavy reporters without unbounded scans.

BEGIN;

-- ----------------------------------------------------------------
-- RPC: my_reported_demand_signals
-- authenticated only; every caller sees ONLY their own rows.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_reported_demand_signals();
CREATE OR REPLACE FUNCTION public.my_reported_demand_signals()
RETURNS TABLE (
  id                uuid,
  occurred_at       timestamptz,
  equipment_brand   text,
  equipment_model   text,
  part_number       text,
  urgency           text,
  founder_priority  text,
  resolved_at       timestamptz,
  resolved_via      text,
  days_open         integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.occurred_at,
    s.equipment_brand,
    s.equipment_model,
    s.part_number,
    s.urgency,
    s.founder_priority,
    s.resolved_at,
    s.resolved_via,
    (
      extract(
        epoch FROM (
          CASE
            WHEN s.resolved_at IS NULL THEN (now() - s.occurred_at)
            ELSE (s.resolved_at - s.occurred_at)
          END
        )
      ) / 86400
    )::int AS days_open
  FROM public.spare_part_demand_signals s
  WHERE s.reporter_user_id = v_uid
  ORDER BY s.occurred_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_reported_demand_signals() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_reported_demand_signals() TO authenticated;

COMMIT;
