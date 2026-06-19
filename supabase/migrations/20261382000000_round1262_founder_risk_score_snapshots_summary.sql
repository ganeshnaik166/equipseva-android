BEGIN;

DROP FUNCTION IF EXISTS public.founder_risk_score_snapshots_summary();

CREATE OR REPLACE FUNCTION public.founder_risk_score_snapshots_summary()
RETURNS TABLE (
  total_snapshots                bigint,
  distinct_actors_scored         bigint,
  engineer_snapshots             bigint,
  hospital_snapshots             bigint,
  admin_snapshots                bigint,
  founder_snapshots              bigint,
  latest_clean_actors            bigint,
  latest_watch_actors            bigint,
  latest_high_actors             bigint,
  latest_critical_actors         bigint,
  avg_latest_score               numeric,
  median_latest_score            numeric,
  max_latest_score               int,
  min_latest_score               int,
  alert_only_count               bigint,
  founder_reviewed_count         bigint,
  blocked_count                  bigint,
  cleared_count                  bigint,
  snapshots_today_ist            bigint,
  snapshots_last_7d              bigint,
  snapshots_last_30d             bigint,
  newest_computed_at             timestamptz,
  oldest_computed_at             timestamptz,
  hours_since_last_snapshot      numeric,
  high_or_critical_share_pct     numeric,
  engineers_in_critical_band     bigint,
  hospitals_in_critical_band     bigint,
  band_transitions_7d            bigint,
  worsened_actors_7d             bigint,
  improved_actors_7d             bigint,
  avg_disputed_jobs_signal       numeric,
  avg_overdue_renewals_signal    numeric,
  avg_suspicious_distance_signal numeric,
  top_score_email                text,
  top_score_value                int,
  top_score_band                 text,
  top_score_role                 text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start_utc timestamptz := (date_trunc('day', (now() AT TIME ZONE 'Asia/Kolkata')) AT TIME ZONE 'Asia/Kolkata');
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.user_id) s.*
      FROM public.risk_score_snapshots s
     ORDER BY s.user_id, s.computed_at DESC
  ),
  prev_week AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.band AS prev_band, s.score AS prev_score
      FROM public.risk_score_snapshots s
     WHERE s.computed_at < now() - interval '7 days'
     ORDER BY s.user_id, s.computed_at DESC
  ),
  totals AS (
    SELECT
      count(*)::bigint                              AS total_snapshots,
      count(DISTINCT user_id)::bigint               AS distinct_actors_scored,
      count(*) FILTER (WHERE role = 'engineer')::bigint AS engineer_snapshots,
      count(*) FILTER (WHERE role = 'hospital')::bigint AS hospital_snapshots,
      count(*) FILTER (WHERE role = 'admin')::bigint    AS admin_snapshots,
      count(*) FILTER (WHERE role = 'founder')::bigint  AS founder_snapshots,
      count(*) FILTER (WHERE computed_at >= v_today_start_utc)::bigint    AS snapshots_today_ist,
      count(*) FILTER (WHERE computed_at >= now() - interval '7 days')::bigint  AS snapshots_last_7d,
      count(*) FILTER (WHERE computed_at >= now() - interval '30 days')::bigint AS snapshots_last_30d,
      count(*) FILTER (WHERE action_taken = 'alert_only')::bigint        AS alert_only_count,
      count(*) FILTER (WHERE action_taken = 'founder_reviewed')::bigint  AS founder_reviewed_count,
      count(*) FILTER (WHERE action_taken = 'blocked')::bigint           AS blocked_count,
      count(*) FILTER (WHERE action_taken = 'cleared')::bigint           AS cleared_count,
      max(computed_at)                              AS newest_computed_at,
      min(computed_at)                              AS oldest_computed_at
    FROM public.risk_score_snapshots
  ),
  latest_stats AS (
    SELECT
      count(*) FILTER (WHERE band = 'clean')::bigint    AS latest_clean_actors,
      count(*) FILTER (WHERE band = 'watch')::bigint    AS latest_watch_actors,
      count(*) FILTER (WHERE band = 'high')::bigint     AS latest_high_actors,
      count(*) FILTER (WHERE band = 'critical')::bigint AS latest_critical_actors,
      count(*) FILTER (WHERE band = 'critical' AND role = 'engineer')::bigint AS engineers_in_critical_band,
      count(*) FILTER (WHERE band = 'critical' AND role = 'hospital')::bigint AS hospitals_in_critical_band,
      avg(score)::numeric                                 AS avg_latest_score,
      percentile_cont(0.5) WITHIN GROUP (ORDER BY score)::numeric AS median_latest_score,
      coalesce(max(score), 0)                             AS max_latest_score,
      coalesce(min(score), 0)                             AS min_latest_score,
      count(*) FILTER (WHERE band IN ('high','critical'))::bigint AS hi_or_crit,
      count(*)::bigint                                    AS total_actors,
      avg(coalesce((signal_breakdown->>'disputed_jobs')::numeric, 0))::numeric           AS avg_disputed_jobs_signal,
      avg(coalesce((signal_breakdown->>'overdue_renewals')::numeric, 0))::numeric        AS avg_overdue_renewals_signal,
      avg(coalesce((signal_breakdown->>'suspicious_distance_events')::numeric, 0))::numeric AS avg_suspicious_distance_signal
    FROM latest
  ),
  transitions AS (
    SELECT
      count(*) FILTER (WHERE l.band <> pw.prev_band)::bigint AS band_transitions_7d,
      count(*) FILTER (WHERE l.score > pw.prev_score)::bigint AS worsened_actors_7d,
      count(*) FILTER (WHERE l.score < pw.prev_score)::bigint AS improved_actors_7d
    FROM latest l
    JOIN prev_week pw ON pw.user_id = l.user_id
  ),
  top_actor AS (
    SELECT
      coalesce((SELECT u.email FROM auth.users u WHERE u.id = l.user_id), 'unknown') AS top_score_email,
      l.score AS top_score_value,
      l.band  AS top_score_band,
      l.role  AS top_score_role
    FROM latest l
    ORDER BY l.score DESC, l.computed_at DESC
    LIMIT 1
  )
  SELECT
    t.total_snapshots,
    t.distinct_actors_scored,
    t.engineer_snapshots,
    t.hospital_snapshots,
    t.admin_snapshots,
    t.founder_snapshots,
    ls.latest_clean_actors,
    ls.latest_watch_actors,
    ls.latest_high_actors,
    ls.latest_critical_actors,
    round(coalesce(ls.avg_latest_score, 0), 2)    AS avg_latest_score,
    round(coalesce(ls.median_latest_score, 0), 2) AS median_latest_score,
    ls.max_latest_score,
    ls.min_latest_score,
    t.alert_only_count,
    t.founder_reviewed_count,
    t.blocked_count,
    t.cleared_count,
    t.snapshots_today_ist,
    t.snapshots_last_7d,
    t.snapshots_last_30d,
    t.newest_computed_at,
    t.oldest_computed_at,
    CASE
      WHEN t.newest_computed_at IS NULL THEN NULL::numeric
      ELSE round(extract(epoch FROM (now() - t.newest_computed_at)) / 3600.0, 2)
    END AS hours_since_last_snapshot,
    CASE
      WHEN ls.total_actors = 0 THEN 0::numeric
      ELSE round((ls.hi_or_crit::numeric / ls.total_actors::numeric) * 100.0, 2)
    END AS high_or_critical_share_pct,
    ls.engineers_in_critical_band,
    ls.hospitals_in_critical_band,
    coalesce(tr.band_transitions_7d, 0)  AS band_transitions_7d,
    coalesce(tr.worsened_actors_7d, 0)   AS worsened_actors_7d,
    coalesce(tr.improved_actors_7d, 0)   AS improved_actors_7d,
    round(coalesce(ls.avg_disputed_jobs_signal, 0), 2)       AS avg_disputed_jobs_signal,
    round(coalesce(ls.avg_overdue_renewals_signal, 0), 2)    AS avg_overdue_renewals_signal,
    round(coalesce(ls.avg_suspicious_distance_signal, 0), 2) AS avg_suspicious_distance_signal,
    ta.top_score_email,
    ta.top_score_value,
    ta.top_score_band,
    ta.top_score_role
  FROM totals t
  CROSS JOIN latest_stats ls
  LEFT JOIN transitions tr ON TRUE
  LEFT JOIN top_actor ta ON TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_risk_score_snapshots_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_risk_score_snapshots_summary() TO authenticated;

COMMIT;