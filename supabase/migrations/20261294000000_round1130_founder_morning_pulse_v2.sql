BEGIN;
DROP FUNCTION IF EXISTS public.founder_morning_pulse_v2();
CREATE OR REPLACE FUNCTION public.founder_morning_pulse_v2()
RETURNS TABLE (
  metric          text,
  metric_order    int,
  today_val       bigint,
  yesterday_val   bigint,
  delta           bigint,
  category        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_yest  date := (now() AT TIME ZONE 'Asia/Kolkata')::date - 1;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH metrics AS (
    SELECT 'Signups (engineer)'::text AS metric, 1 AS metric_order, 'Growth'::text AS category,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'engineer' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint AS today_val,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'engineer' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint AS yesterday_val
    UNION ALL
    SELECT 'Signups (hospital)', 2, 'Growth',
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital' AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Jobs posted', 3, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Jobs completed', 4, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE j.status='completed' AND (j.completed_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j WHERE j.status='completed' AND (j.completed_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Bids placed', 5, 'Marketplace',
      coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'New AMCs', 6, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Payouts processed', 7, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status IN ('processed','paid') AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Payouts failed', 8, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p WHERE p.status = 'failed' AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Code Red opened', 9, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.code_red_requests r WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Disputes submitted', 10, 'Trust',
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d WHERE d.submitted_at IS NOT NULL AND (d.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d WHERE d.submitted_at IS NOT NULL AND (d.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Spare orders paid', 11, 'Revenue',
      coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o WHERE o.payment_status='paid' AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o WHERE o.payment_status='paid' AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
    UNION ALL
    SELECT 'Tier promotions', 12, 'Growth',
      coalesce((SELECT count(*)::bigint FROM public.engineer_tier_history h WHERE (h.changed_at AT TIME ZONE 'Asia/Kolkata')::date = v_today), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.engineer_tier_history h WHERE (h.changed_at AT TIME ZONE 'Asia/Kolkata')::date = v_yest), 0)::bigint
  )
  SELECT m.metric, m.metric_order, m.today_val, m.yesterday_val,
         (m.today_val - m.yesterday_val)::bigint AS delta,
         m.category
  FROM metrics m
  ORDER BY m.metric_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_morning_pulse_v2() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_morning_pulse_v2() TO authenticated;
COMMIT;
