BEGIN;
-- r1334 — /founder-action-items-cockpit — unified action-items cockpit.
--
-- Aggregates two distinct action-tracking surfaces into one single-screen view:
--   1) founder_priority_actions (r1306) — write-transition log for /founder-action-center.
--      The founder marks each priority queue item as acked/resolved/escalated/ignored.
--   2) founder_incident_postmortem_action_items (r1332) — concrete owner+due-date
--      action items emerging from incident postmortems (open/in_progress/closed/wont_do).
--
-- This is the engineer + leadership single-screen action-tracker.
-- Pair with /founder-action-center for the priority queue itself.
--
-- NO new tables. Pure read aggregator over existing rows.

-- ============================================================================
-- RPC: founder_action_items_cockpit_summary — 16 KPIs across both sources
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_action_items_cockpit_summary();
CREATE OR REPLACE FUNCTION public.founder_action_items_cockpit_summary()
RETURNS TABLE (
  priority_actions_open         bigint,
  priority_acked                bigint,
  priority_resolved             bigint,
  priority_escalated            bigint,
  priority_ignored              bigint,
  postmortem_actions_open       bigint,
  postmortem_actions_in_progress bigint,
  postmortem_actions_closed     bigint,
  postmortem_actions_overdue    bigint,
  total_open                    bigint,
  oldest_open_age_days          int,
  today_added                   bigint,
  this_week_added               bigint,
  last_30d_added                bigint,
  escalated_ratio_pct           numeric,
  completion_ratio_pct          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start  timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_priority_30d bigint;
  v_pm_total     bigint;
  v_priority_total bigint;
  v_priority_esc bigint;
  v_pm_open      bigint;
  v_pm_in_prog   bigint;
  v_pm_closed    bigint;
  v_total_open   bigint;
  v_oldest_priority_age int;
  v_oldest_pm_age int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Priority-action rollups (last 30 days for "open" semantics — i.e. recent actions taken)
  SELECT count(*)::bigint INTO v_priority_30d
    FROM public.founder_priority_actions
    WHERE created_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_priority_total
    FROM public.founder_priority_actions;

  SELECT count(*)::bigint INTO v_priority_esc
    FROM public.founder_priority_actions
    WHERE action_taken = 'escalated';

  -- Postmortem action item rollups
  SELECT count(*)::bigint INTO v_pm_open
    FROM public.founder_incident_postmortem_action_items
    WHERE status = 'open';

  SELECT count(*)::bigint INTO v_pm_in_prog
    FROM public.founder_incident_postmortem_action_items
    WHERE status = 'in_progress';

  SELECT count(*)::bigint INTO v_pm_closed
    FROM public.founder_incident_postmortem_action_items
    WHERE status = 'closed';

  SELECT count(*)::bigint INTO v_pm_total
    FROM public.founder_incident_postmortem_action_items;

  -- Total-open = postmortem (open + in_progress) + priority actions in last 30d
  v_total_open := v_pm_open + v_pm_in_prog + v_priority_30d;

  -- Oldest open age — max across both sources
  SELECT coalesce(extract(day from (now() - min(created_at)))::int, 0)
    INTO v_oldest_priority_age
    FROM public.founder_priority_actions
    WHERE created_at >= now() - interval '30 days';

  SELECT coalesce(extract(day from (now() - min(created_at)))::int, 0)
    INTO v_oldest_pm_age
    FROM public.founder_incident_postmortem_action_items
    WHERE status IN ('open','in_progress');

  RETURN QUERY
  SELECT
    -- priority slice
    v_priority_30d AS priority_actions_open,
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE action_taken = 'acked' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE action_taken = 'resolved' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE action_taken = 'escalated' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE action_taken = 'ignored' AND created_at >= now() - interval '30 days'), 0),
    -- postmortem slice
    v_pm_open,
    v_pm_in_prog,
    v_pm_closed,
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortem_action_items
              WHERE status IN ('open','in_progress')
                AND due_date IS NOT NULL
                AND due_date < CURRENT_DATE), 0),
    -- aggregates
    v_total_open,
    GREATEST(v_oldest_priority_age, v_oldest_pm_age)::int,
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE created_at >= v_today_start), 0)
    + coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortem_action_items
              WHERE created_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE created_at >= now() - interval '7 days'), 0)
    + coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortem_action_items
              WHERE created_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_priority_actions
              WHERE created_at >= now() - interval '30 days'), 0)
    + coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortem_action_items
              WHERE created_at >= now() - interval '30 days'), 0),
    CASE WHEN v_priority_total = 0 THEN 0::numeric
         ELSE round(100.0 * v_priority_esc / v_priority_total, 1) END,
    CASE WHEN v_pm_total = 0 THEN 0::numeric
         ELSE round(100.0 * v_pm_closed / v_pm_total, 1) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_action_items_cockpit_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_action_items_cockpit_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_action_items_cockpit_combined — merged list of both sources
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_action_items_cockpit_combined(int);
CREATE OR REPLACE FUNCTION public.founder_action_items_cockpit_combined(p_limit int DEFAULT 100)
RETURNS TABLE (
  source_kind   text,
  item_id       uuid,
  title         text,
  kind_label    text,
  status        text,
  owner         text,
  age_days      int,
  due_date      date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH priority_slice AS (
    SELECT
      'priority'::text AS source_kind,
      pa.id            AS item_id,
      ('[' || pa.source_domain || '] ' || pa.item_kind ||
        coalesce(' — ' || pa.note, ''))::text AS title,
      pa.item_kind     AS kind_label,
      pa.action_taken  AS status,
      coalesce(prof.full_name, 'founder')::text AS owner,
      extract(day from (now() - pa.created_at))::int AS age_days,
      NULL::date       AS due_date,
      pa.created_at    AS created_at
    FROM public.founder_priority_actions pa
    LEFT JOIN public.profiles prof ON prof.id = pa.founder_user_id
    WHERE pa.created_at >= now() - interval '30 days'
  ),
  postmortem_slice AS (
    SELECT
      'postmortem'::text AS source_kind,
      ai.id              AS item_id,
      (coalesce(pm.title, '(unlinked)') || ' — ' || ai.description)::text AS title,
      coalesce(pm.root_cause_classification, 'other')::text AS kind_label,
      ai.status          AS status,
      coalesce(u.email, '(unassigned)')::text AS owner,
      extract(day from (now() - ai.created_at))::int AS age_days,
      ai.due_date        AS due_date,
      ai.created_at      AS created_at
    FROM public.founder_incident_postmortem_action_items ai
    LEFT JOIN public.founder_incident_postmortems pm ON pm.id = ai.postmortem_id
    LEFT JOIN auth.users u ON u.id = ai.owner_user_id
  )
  SELECT
    c.source_kind, c.item_id, c.title, c.kind_label,
    c.status, c.owner, c.age_days, c.due_date
  FROM (
    SELECT * FROM priority_slice
    UNION ALL
    SELECT * FROM postmortem_slice
  ) c
  ORDER BY c.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_action_items_cockpit_combined(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_action_items_cockpit_combined(int) TO authenticated;

COMMIT;