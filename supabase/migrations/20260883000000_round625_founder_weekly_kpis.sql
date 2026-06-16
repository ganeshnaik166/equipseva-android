BEGIN;
DROP FUNCTION IF EXISTS public.founder_weekly_kpis();
CREATE OR REPLACE FUNCTION public.founder_weekly_kpis()
RETURNS TABLE (
  metric        text,
  this_week     bigint,
  last_week     bigint,
  delta_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cur_start  timestamptz := now() - interval '7 days';
  v_prior_start timestamptz := now() - interval '14 days';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH rows(metric, ord, this_w, last_w) AS (
    VALUES
    ('signups'::text, 1,
      (SELECT count(*)::bigint FROM auth.users WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::bigint FROM auth.users WHERE created_at >= v_prior_start AND created_at < v_cur_start)
    ),
    ('repair_jobs_posted', 2,
      (SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= v_prior_start AND created_at < v_cur_start)
    ),
    ('completed_jobs', 3,
      (SELECT count(*)::bigint FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_cur_start AND completed_at < now()),
      (SELECT count(*)::bigint FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_prior_start AND completed_at < v_cur_start)
    ),
    ('new_amc', 4,
      (SELECT count(*)::bigint FROM public.amc_contracts WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::bigint FROM public.amc_contracts WHERE created_at >= v_prior_start AND created_at < v_cur_start)
    ),
    ('disputes_opened', 5,
      (SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status='submitted' AND created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status='submitted' AND created_at >= v_prior_start AND created_at < v_cur_start)
    ),
    ('demand_signals', 6,
      (SELECT count(*)::bigint FROM public.spare_part_demand_signals WHERE occurred_at >= v_cur_start AND occurred_at < now()),
      (SELECT count(*)::bigint FROM public.spare_part_demand_signals WHERE occurred_at >= v_prior_start AND occurred_at < v_cur_start)
    ),
    ('tier_promotions', 7,
      (SELECT count(*)::bigint FROM public.engineer_tier_history h
        WHERE h.changed_at >= v_cur_start AND h.changed_at < now()
          AND CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
            > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END),
      (SELECT count(*)::bigint FROM public.engineer_tier_history h
        WHERE h.changed_at >= v_prior_start AND h.changed_at < v_cur_start
          AND CASE h.new_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END
            > CASE h.prev_tier WHEN 'none' THEN 0 WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0 END)
    )
  )
  SELECT
    r.metric,
    r.this_w,
    r.last_w,
    CASE WHEN r.last_w = 0 THEN NULL
         ELSE round(((r.this_w - r.last_w)::numeric / r.last_w::numeric) * 100.0, 1)
    END
  FROM rows r
  ORDER BY r.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_weekly_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_weekly_kpis() TO authenticated;
COMMIT;
