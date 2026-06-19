BEGIN;
DROP FUNCTION IF EXISTS public.founder_consent_ledger_summary();
CREATE OR REPLACE FUNCTION public.founder_consent_ledger_summary()
RETURNS TABLE (
  events_total                bigint,
  events_today                bigint,
  events_30d                  bigint,
  granted_30d                 bigint,
  revoked_30d                 bigint,
  granted_today               bigint,
  revoked_today               bigint,
  distinct_users_consented    bigint,
  marketing_granted_latest    bigint,
  marketing_revoked_latest    bigint,
  location_granted_latest     bigint,
  privacy_policy_grants_30d   bigint,
  top_revoked_type            text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_top_revoked_type text;
  v_top_revoked_count bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- precompute most-revoked consent_type in last 30d (revocation velocity signal)
  SELECT cl.consent_type, count(*)::bigint
    INTO v_top_revoked_type, v_top_revoked_count
    FROM public.consent_log cl
   WHERE cl.action = 'revoked'
     AND cl.created_at >= now() - interval '30 days'
   GROUP BY cl.consent_type
   ORDER BY count(*) DESC
   LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.consent_log), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE action = 'granted'
                 AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE action = 'revoked'
                 AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE action = 'granted'
                 AND created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE action = 'revoked'
                 AND created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.consent_log), 0),
    -- latest-state KPIs: count users whose MOST RECENT marketing_emails row is granted/revoked
    coalesce((SELECT count(*)::bigint FROM (
                SELECT DISTINCT ON (cl.user_id) cl.user_id, cl.action
                  FROM public.consent_log cl
                 WHERE cl.consent_type = 'marketing_emails'
                 ORDER BY cl.user_id, cl.created_at DESC
             ) latest WHERE latest.action = 'granted'), 0),
    coalesce((SELECT count(*)::bigint FROM (
                SELECT DISTINCT ON (cl.user_id) cl.user_id, cl.action
                  FROM public.consent_log cl
                 WHERE cl.consent_type = 'marketing_emails'
                 ORDER BY cl.user_id, cl.created_at DESC
             ) latest WHERE latest.action = 'revoked'), 0),
    coalesce((SELECT count(*)::bigint FROM (
                SELECT DISTINCT ON (cl.user_id) cl.user_id, cl.action
                  FROM public.consent_log cl
                 WHERE cl.consent_type = 'location_tracking'
                 ORDER BY cl.user_id, cl.created_at DESC
             ) latest WHERE latest.action = 'granted'), 0),
    coalesce((SELECT count(*)::bigint FROM public.consent_log
               WHERE consent_type = 'privacy_policy'
                 AND action = 'granted'
                 AND created_at >= now() - interval '30 days'), 0),
    coalesce(v_top_revoked_type, '(none)')::text
  ;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_consent_ledger_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_consent_ledger_summary() TO authenticated;
COMMIT;
