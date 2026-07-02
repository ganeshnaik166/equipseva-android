BEGIN;
-- r1420 ★★★★ — Investor open-tracker (engagement signal aggregator).
--
-- HEAVY pure aggregator: NO new tables. Reads from r1419
-- founder_investor_quarterly_updates + recipients + r1390 data_room access log
-- to produce a single engagement dashboard so founder sees who is reading
-- updates, who is poking the data room, and which firms have gone cold.
--
-- 6 RPCs:
--   founder_investor_open_tracker_summary           — 16 KPIs
--   founder_investor_open_tracker_engaged_investors — top-30 by total engagement
--   founder_investor_open_tracker_dormant_investors — no open in 60d
--   founder_investor_open_tracker_recent_events     — combined feed
--   founder_investor_open_tracker_quarterly_rollup  — open rate per quarter
--   log_founder_investor_open_tracker_mark_unsubscribed — opt-out write

-- ============================================================================
-- 1. SUMMARY (16 KPIs)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_open_tracker_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_summary()
RETURNS TABLE (
  total_recipients        int,
  lifetime_emails_sent    int,
  recipients_opened_30d   int,
  recipients_opened_lifetime int,
  open_rate_pct_30d       numeric,
  open_rate_pct_lifetime  numeric,
  replied_30d             int,
  replied_lifetime        int,
  reply_rate_pct          numeric,
  opt_out_count           int,
  opt_out_rate_pct        numeric,
  data_room_views_30d     int,
  data_room_views_lifetime int,
  distinct_investor_viewers int,
  top_engaged_firm        text,
  top_engaged_views_count int,
  unique_firms_total      int,
  last_open_at            timestamptz,
  generated_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_sent_life int;
  v_open_30 int;
  v_open_life int;
  v_sent_30 int;
  v_rep_30 int;
  v_rep_life int;
  v_opt int;
  v_dr_30 int;
  v_dr_life int;
  v_dr_inv int;
  v_top_firm text;
  v_top_views int;
  v_firms int;
  v_last_open timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*)::int,
         count(*) FILTER (WHERE sent_at IS NOT NULL)::int,
         count(*) FILTER (WHERE opened_at IS NOT NULL AND opened_at >= now() - interval '30 days')::int,
         count(*) FILTER (WHERE opened_at IS NOT NULL)::int,
         count(*) FILTER (WHERE sent_at IS NOT NULL AND sent_at >= now() - interval '30 days')::int,
         count(*) FILTER (WHERE replied_at IS NOT NULL AND replied_at >= now() - interval '30 days')::int,
         count(*) FILTER (WHERE replied_at IS NOT NULL)::int,
         count(*) FILTER (WHERE opt_out_at IS NOT NULL)::int,
         count(DISTINCT investor_firm_name)::int,
         max(opened_at)
    INTO v_total, v_sent_life, v_open_30, v_open_life, v_sent_30,
         v_rep_30, v_rep_life, v_opt, v_firms, v_last_open
    FROM public.founder_investor_quarterly_update_recipients;

  SELECT (count(*) FILTER (WHERE outcome = 'ok' AND action_kind = 'view_doc' AND accessed_at >= now() - interval '30 days'))::int,
         (count(*) FILTER (WHERE outcome = 'ok' AND action_kind = 'view_doc'))::int,
         (count(DISTINCT grant_id) FILTER (WHERE outcome = 'ok' AND action_kind = 'view_doc'))::int
    INTO v_dr_30, v_dr_life, v_dr_inv
    FROM public.founder_investor_data_room_access_log;

  SELECT firm, views INTO v_top_firm, v_top_views FROM (
    SELECT g.investor_firm_name AS firm, count(*)::int AS views
    FROM public.founder_investor_data_room_access_grants g
    JOIN public.founder_investor_data_room_access_log l ON l.grant_id = g.id
    WHERE l.outcome = 'ok' AND l.action_kind = 'view_doc'
    GROUP BY g.investor_firm_name
    ORDER BY count(*) DESC LIMIT 1
  ) t;

  RETURN QUERY SELECT
    coalesce(v_total, 0),
    coalesce(v_sent_life, 0),
    coalesce(v_open_30, 0),
    coalesce(v_open_life, 0),
    CASE WHEN coalesce(v_sent_30, 0) > 0 THEN round(100.0 * v_open_30 / v_sent_30, 2) ELSE 0 END,
    CASE WHEN coalesce(v_sent_life, 0) > 0 THEN round(100.0 * v_open_life / v_sent_life, 2) ELSE 0 END,
    coalesce(v_rep_30, 0),
    coalesce(v_rep_life, 0),
    CASE WHEN coalesce(v_open_life, 0) > 0 THEN round(100.0 * v_rep_life / v_open_life, 2) ELSE 0 END,
    coalesce(v_opt, 0),
    CASE WHEN coalesce(v_total, 0) > 0 THEN round(100.0 * v_opt / v_total, 2) ELSE 0 END,
    coalesce(v_dr_30, 0),
    coalesce(v_dr_life, 0),
    coalesce(v_dr_inv, 0),
    coalesce(v_top_firm, '—'),
    coalesce(v_top_views, 0),
    coalesce(v_firms, 0),
    v_last_open,
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_open_tracker_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_open_tracker_summary() TO authenticated;

-- ============================================================================
-- 2. ENGAGED INVESTORS — top-30 by total engagement score
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_open_tracker_engaged_investors();
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_engaged_investors()
RETURNS TABLE (
  investor_firm_name  text,
  emails_sent         int,
  emails_opened       int,
  emails_replied      int,
  data_room_views     int,
  engagement_score    int,
  last_touch_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH email_side AS (
    SELECT investor_firm_name,
           count(*) FILTER (WHERE sent_at IS NOT NULL)::int AS sent_n,
           count(*) FILTER (WHERE opened_at IS NOT NULL)::int AS open_n,
           count(*) FILTER (WHERE replied_at IS NOT NULL)::int AS reply_n,
           max(GREATEST(coalesce(opened_at, 'epoch'::timestamptz),
                        coalesce(replied_at, 'epoch'::timestamptz),
                        coalesce(sent_at, 'epoch'::timestamptz))) AS last_email_touch
    FROM public.founder_investor_quarterly_update_recipients
    GROUP BY investor_firm_name
  ),
  dr_side AS (
    SELECT g.investor_firm_name,
           (count(*) FILTER (WHERE l.outcome = 'ok' AND l.action_kind = 'view_doc'))::int AS dr_views,
           max(l.accessed_at) AS last_dr_touch
    FROM public.founder_investor_data_room_access_grants g
    LEFT JOIN public.founder_investor_data_room_access_log l ON l.grant_id = g.id
    GROUP BY g.investor_firm_name
  ),
  unified AS (
    SELECT coalesce(e.investor_firm_name, d.investor_firm_name) AS firm,
           coalesce(e.sent_n, 0) AS sent_n,
           coalesce(e.open_n, 0) AS open_n,
           coalesce(e.reply_n, 0) AS reply_n,
           coalesce(d.dr_views, 0) AS dr_n,
           GREATEST(coalesce(e.last_email_touch, 'epoch'::timestamptz),
                    coalesce(d.last_dr_touch, 'epoch'::timestamptz)) AS last_touch
    FROM email_side e
    FULL OUTER JOIN dr_side d ON d.investor_firm_name = e.investor_firm_name
  )
  SELECT firm, sent_n, open_n, reply_n, dr_n,
         (open_n * 1 + reply_n * 5 + dr_n * 3)::int AS score,
         CASE WHEN last_touch = 'epoch'::timestamptz THEN NULL ELSE last_touch END
  FROM unified
  WHERE firm IS NOT NULL
  ORDER BY (open_n * 1 + reply_n * 5 + dr_n * 3) DESC, last_touch DESC NULLS LAST
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_open_tracker_engaged_investors() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_open_tracker_engaged_investors() TO authenticated;

-- ============================================================================
-- 3. DORMANT INVESTORS — no open in 60d (warning banner data)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_open_tracker_dormant_investors();
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_dormant_investors()
RETURNS TABLE (
  investor_firm_name text,
  investor_partner_email text,
  last_sent_at      timestamptz,
  last_opened_at    timestamptz,
  days_since_open   int,
  emails_sent_total int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT investor_firm_name,
         investor_partner_email,
         max(sent_at)        AS last_sent_at,
         max(opened_at)      AS last_opened_at,
         CASE WHEN max(opened_at) IS NULL THEN 9999
              ELSE extract(day FROM (now() - max(opened_at)))::int END AS days_since_open,
         count(*) FILTER (WHERE sent_at IS NOT NULL)::int AS emails_sent_total
  FROM public.founder_investor_quarterly_update_recipients
  GROUP BY investor_firm_name, investor_partner_email
  HAVING (max(opened_at) IS NULL OR max(opened_at) < now() - interval '60 days')
     AND count(*) FILTER (WHERE sent_at IS NOT NULL) > 0
     AND count(*) FILTER (WHERE opt_out_at IS NOT NULL) = 0
  ORDER BY days_since_open DESC NULLS LAST, last_sent_at DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_open_tracker_dormant_investors() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_open_tracker_dormant_investors() TO authenticated;

-- ============================================================================
-- 4. RECENT EVENTS — combined feed
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_open_tracker_recent_events();
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_recent_events()
RETURNS TABLE (
  event_kind         text,
  investor_firm_name text,
  detail             text,
  happened_at        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT 'email_open'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update') AS detail,
         r.opened_at AS happened_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.opened_at IS NOT NULL
  UNION ALL
  SELECT 'email_reply'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update'),
         r.replied_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.replied_at IS NOT NULL
  UNION ALL
  SELECT 'opt_out'::text, r.investor_firm_name,
         coalesce(u.quarter_label, 'update'),
         r.opt_out_at
  FROM public.founder_investor_quarterly_update_recipients r
  LEFT JOIN public.founder_investor_quarterly_updates u ON u.id = r.update_id
  WHERE r.opt_out_at IS NOT NULL
  UNION ALL
  SELECT 'dataroom_view'::text, g.investor_firm_name,
         coalesce(d.doc_label, l.action_kind),
         l.accessed_at
  FROM public.founder_investor_data_room_access_log l
  JOIN public.founder_investor_data_room_access_grants g ON g.id = l.grant_id
  LEFT JOIN public.founder_investor_data_room_documents d ON d.id = l.document_id
  WHERE l.outcome = 'ok' AND l.action_kind = 'view_doc'
  ORDER BY happened_at DESC NULLS LAST
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_open_tracker_recent_events() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_open_tracker_recent_events() TO authenticated;

-- ============================================================================
-- 5. QUARTERLY ROLLUP — open rate per quarter
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_open_tracker_quarterly_rollup();
CREATE OR REPLACE FUNCTION public.founder_investor_open_tracker_quarterly_rollup()
RETURNS TABLE (
  quarter_label     text,
  period_start      date,
  status            text,
  recipients_count  int,
  sent_count        int,
  opened_count      int,
  replied_count     int,
  open_rate_pct     numeric,
  reply_rate_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT u.quarter_label, u.period_start, u.status,
         count(r.*)::int AS recipients_count,
         count(*) FILTER (WHERE r.sent_at IS NOT NULL)::int AS sent_count,
         count(*) FILTER (WHERE r.opened_at IS NOT NULL)::int AS opened_count,
         count(*) FILTER (WHERE r.replied_at IS NOT NULL)::int AS replied_count,
         CASE WHEN count(*) FILTER (WHERE r.sent_at IS NOT NULL) > 0
              THEN round(100.0 * count(*) FILTER (WHERE r.opened_at IS NOT NULL)
                              / count(*) FILTER (WHERE r.sent_at IS NOT NULL), 2)
              ELSE 0 END AS open_rate_pct,
         CASE WHEN count(*) FILTER (WHERE r.opened_at IS NOT NULL) > 0
              THEN round(100.0 * count(*) FILTER (WHERE r.replied_at IS NOT NULL)
                              / count(*) FILTER (WHERE r.opened_at IS NOT NULL), 2)
              ELSE 0 END AS reply_rate_pct
  FROM public.founder_investor_quarterly_updates u
  LEFT JOIN public.founder_investor_quarterly_update_recipients r ON r.update_id = u.id
  GROUP BY u.id, u.quarter_label, u.period_start, u.status
  ORDER BY u.period_start DESC NULLS LAST
  LIMIT 16;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_open_tracker_quarterly_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_open_tracker_quarterly_rollup() TO authenticated;

-- ============================================================================
-- 6. WRITE — mark unsubscribed (founder-only)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_investor_open_tracker_mark_unsubscribed(text);
CREATE OR REPLACE FUNCTION public.log_founder_investor_open_tracker_mark_unsubscribed(
  p_partner_email text
) RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_n int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_partner_email IS NULL OR length(trim(p_partner_email)) < 3 THEN
    RAISE EXCEPTION 'partner email required' USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_investor_quarterly_update_recipients
  SET opt_out_at = COALESCE(opt_out_at, now())
  WHERE lower(investor_partner_email) = lower(trim(p_partner_email));
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_open_tracker_mark_unsubscribed(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_investor_open_tracker_mark_unsubscribed(text) TO authenticated;

COMMIT;