BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_sla_warranty_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_sla_warranty_snapshot_summary()
RETURNS TABLE (
  total_breaches_all_time         bigint,
  open_breaches                   bigint,
  breaches_today                  bigint,
  breaches_30d                    bigint,
  emergency_breaches_30d          bigint,
  credits_issued_30d_rupees       numeric,
  credits_owed_open_rupees        numeric,
  avg_actual_hours_30d            numeric,
  avg_target_hours_30d            numeric,
  warranty_jobs_30d               bigint,
  warranty_jobs_today             bigint,
  warranty_fee_waived_30d_rupees  numeric,
  contracts_with_breach_30d       bigint,
  top_breaching_engineer_breaches bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.amc_sla_breaches), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_sla_breaches WHERE resolved_at IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_sla_breaches
              WHERE detected_at >= v_today_start AND detected_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days' AND severity = 'emergency'), 0),
    coalesce((SELECT round(sum(credit_issued_rupees)::numeric, 2) FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT round(sum(credit_issued_rupees)::numeric, 2) FROM public.amc_sla_breaches
              WHERE resolved_at IS NULL), 0)::numeric,
    coalesce((SELECT round(avg(actual_hours)::numeric, 2) FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days' AND actual_hours IS NOT NULL), 0)::numeric,
    coalesce((SELECT round(avg(expected_within_hours)::numeric, 2) FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
              WHERE is_warranty_covered = true AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
              WHERE is_warranty_covered = true AND created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT round(sum(contracted_amount_rupees)::numeric, 2) FROM public.repair_jobs
              WHERE is_warranty_covered = true
                AND status::text = 'completed'
                AND completed_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(DISTINCT amc_contract_id)::bigint FROM public.amc_sla_breaches
              WHERE detected_at >= now() - interval '30 days'), 0),
    coalesce((SELECT max(c)::bigint FROM (
                SELECT count(*)::bigint AS c
                FROM public.amc_sla_breaches b
                JOIN public.repair_jobs rj ON rj.id = b.visit_id
                WHERE b.detected_at >= now() - interval '30 days'
                  AND rj.engineer_id IS NOT NULL
                GROUP BY rj.engineer_id
              ) t), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_sla_warranty_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_sla_warranty_snapshot_summary() TO authenticated;
COMMIT;
