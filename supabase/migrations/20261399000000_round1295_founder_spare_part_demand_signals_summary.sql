BEGIN;
-- Round 1281 — /spare-part-demand-signals-summary
-- 14-KPI demand-intent supply-gap radar from public.spare_part_demand_signals.
-- Pairs with the existing /demand-signals dashboard but rolls everything into
-- a single founder-only RPC for the snapshot landing.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_spare_part_demand_signals_summary();
CREATE OR REPLACE FUNCTION public.founder_spare_part_demand_signals_summary()
RETURNS TABLE (
  total_signals_all_time     bigint,
  total_unresolved           bigint,
  total_resolved             bigint,
  resolved_pct               numeric,
  critical_unresolved        bigint,
  urgent_unresolved          bigint,
  high_priority_unresolved   bigint,
  distinct_groups_unresolved bigint,
  unique_reporters_30d       bigint,
  signals_30d                bigint,
  signals_7d                 bigint,
  signals_today              bigint,
  resolved_supplier_onboard  bigint,
  resolved_bonded_intake     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.spare_part_demand_signals
  )
  SELECT
    (SELECT count(*)::bigint FROM base)                                                                                                  AS total_signals_all_time,
    (SELECT count(*)::bigint FROM base WHERE resolved_at IS NULL)                                                                        AS total_unresolved,
    (SELECT count(*)::bigint FROM base WHERE resolved_at IS NOT NULL)                                                                    AS total_resolved,
    CASE
      WHEN (SELECT count(*) FROM base) = 0 THEN 0::numeric
      ELSE round( (SELECT count(*) FROM base WHERE resolved_at IS NOT NULL)::numeric
                / (SELECT count(*) FROM base)::numeric * 100, 1)
    END                                                                                                                                  AS resolved_pct,
    (SELECT count(*)::bigint FROM base WHERE resolved_at IS NULL AND urgency = 'critical')                                               AS critical_unresolved,
    (SELECT count(*)::bigint FROM base WHERE resolved_at IS NULL AND urgency = 'urgent')                                                 AS urgent_unresolved,
    (SELECT count(*)::bigint FROM base WHERE resolved_at IS NULL AND founder_priority = 'high')                                          AS high_priority_unresolved,
    (SELECT count(DISTINCT
        coalesce(lower(equipment_brand),'?') ||'|'||
        coalesce(lower(equipment_model),'?') ||'|'||
        coalesce(lower(part_number),'?')
      )::bigint
       FROM base WHERE resolved_at IS NULL)                                                                                              AS distinct_groups_unresolved,
    (SELECT count(DISTINCT reporter_user_id)::bigint FROM base WHERE occurred_at >= now() - interval '30 days')                          AS unique_reporters_30d,
    (SELECT count(*)::bigint FROM base WHERE occurred_at >= now() - interval '30 days')                                                  AS signals_30d,
    (SELECT count(*)::bigint FROM base WHERE occurred_at >= now() - interval '7 days')                                                   AS signals_7d,
    (SELECT count(*)::bigint FROM base WHERE occurred_at::date = (now() AT TIME ZONE 'Asia/Kolkata')::date)                              AS signals_today,
    (SELECT count(*)::bigint FROM base WHERE resolved_via = 'supplier_onboarded')                                                        AS resolved_supplier_onboard,
    (SELECT count(*)::bigint FROM base WHERE resolved_via = 'bonded_intake')                                                             AS resolved_bonded_intake;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_spare_part_demand_signals_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_part_demand_signals_summary() TO authenticated;

COMMIT;
