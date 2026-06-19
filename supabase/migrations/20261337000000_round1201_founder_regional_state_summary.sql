BEGIN;
DROP FUNCTION IF EXISTS public.founder_regional_state_summary();
CREATE OR REPLACE FUNCTION public.founder_regional_state_summary()
RETURNS TABLE (
  distinct_states_30d         bigint,
  top1_state                  text,
  top1_jobs_30d               bigint,
  top1_revenue_rupees_30d     numeric,
  top1_active_amcs            bigint,
  top1_engineers_30d          bigint,
  top1_hospitals_30d          bigint,
  top2_state                  text,
  top2_jobs_30d               bigint,
  top3_state                  text,
  top3_jobs_30d               bigint,
  top1_share_jobs_pct         numeric,
  total_jobs_30d              bigint,
  total_revenue_rupees_30d    numeric,
  unknown_state_jobs_30d      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total_jobs_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- Build per-state rollup over last 30d window using profiles.state as ground-truth geography.
  -- engineers.user_id bridges to profiles for engineer-side state grouping. repair_jobs.engineer_id
  -- FKs to engineers.id (not profiles), so we join via engineers when grouping engineers by state.
  CREATE TEMP TABLE IF NOT EXISTS _tmp_regional_rollup ON COMMIT DROP AS
  WITH job_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      rj.id            AS job_id,
      rj.hospital_user_id,
      rj.engineer_id,
      rj.status,
      rj.completed_at,
      rj.created_at,
      rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
    WHERE rj.created_at >= now() - interval '30 days'
  ),
  amc_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      c.id AS amc_id,
      c.status
    FROM public.amc_contracts c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ),
  eng_state AS (
    SELECT
      coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
      e.id AS engineer_row_id
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
  ),
  agg AS (
    SELECT
      js.state,
      count(DISTINCT js.job_id)::bigint                                                    AS jobs_30d,
      count(DISTINCT js.hospital_user_id)::bigint                                          AS hospitals_30d,
      count(DISTINCT js.engineer_id) FILTER (WHERE js.engineer_id IS NOT NULL)::bigint     AS engineers_30d,
      coalesce(sum(js.contracted_amount_rupees) FILTER (WHERE js.status = 'completed'
        AND js.completed_at >= now() - interval '30 days'), 0)::numeric                    AS revenue_30d
    FROM job_state js
    GROUP BY js.state
  ),
  amc_agg AS (
    SELECT a.state, count(*) FILTER (WHERE a.status = 'active')::bigint AS active_amcs
    FROM amc_state a GROUP BY a.state
  )
  SELECT
    agg.state,
    agg.jobs_30d,
    agg.hospitals_30d,
    agg.engineers_30d,
    agg.revenue_30d,
    coalesce(amc_agg.active_amcs, 0)::bigint AS active_amcs,
    -- composite-activity score: jobs + revenue/1000 + engineers*5 + hospitals*5 + active_amcs*3
    (agg.jobs_30d
      + (agg.revenue_30d / 1000.0)
      + (agg.engineers_30d * 5)
      + (agg.hospitals_30d * 5)
      + (coalesce(amc_agg.active_amcs, 0) * 3))::numeric AS score
  FROM agg
  LEFT JOIN amc_agg ON amc_agg.state = agg.state
  WHERE agg.state <> '(unknown)';

  SELECT coalesce(sum(r.jobs_30d), 0)::bigint INTO v_total_jobs_30d FROM _tmp_regional_rollup r;
  IF v_total_jobs_30d IS NULL THEN v_total_jobs_30d := 0; END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT
      r.*,
      row_number() OVER (ORDER BY r.score DESC NULLS LAST, r.jobs_30d DESC, r.state ASC) AS rk
    FROM _tmp_regional_rollup r
  ),
  t1 AS (SELECT * FROM ranked WHERE rk = 1),
  t2 AS (SELECT * FROM ranked WHERE rk = 2),
  t3 AS (SELECT * FROM ranked WHERE rk = 3)
  SELECT
    coalesce((SELECT count(*)::bigint FROM _tmp_regional_rollup), 0),
    coalesce((SELECT state FROM t1), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t1), 0)::bigint,
    coalesce((SELECT revenue_30d FROM t1), 0)::numeric,
    coalesce((SELECT active_amcs FROM t1), 0)::bigint,
    coalesce((SELECT engineers_30d FROM t1), 0)::bigint,
    coalesce((SELECT hospitals_30d FROM t1), 0)::bigint,
    coalesce((SELECT state FROM t2), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t2), 0)::bigint,
    coalesce((SELECT state FROM t3), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t3), 0)::bigint,
    CASE WHEN v_total_jobs_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT jobs_30d FROM t1), 0)::numeric / v_total_jobs_30d, 1) END,
    v_total_jobs_30d,
    coalesce((SELECT sum(revenue_30d)::numeric FROM _tmp_regional_rollup), 0),
    coalesce((SELECT count(*)::bigint
              FROM public.repair_jobs rj
              LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
              WHERE rj.created_at >= now() - interval '30 days'
                AND coalesce(nullif(trim(p.state), ''), '(unknown)') = '(unknown)'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_regional_state_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_regional_state_summary() TO authenticated;
COMMIT;
