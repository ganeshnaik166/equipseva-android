BEGIN;
-- r1350 — Founder board meeting prep.
--
-- Board hygiene = governance hygiene. A startup that drifts on board cadence
-- starts drifting on accountability: prep decks land late, decisions get
-- re-litigated, action items rot in slack threads. This module is the founder's
-- board operating system: every meeting tracked, every decision logged, every
-- action item owned + due-dated + closed.
--
-- Two tables:
--   * founder_board_meetings — one row per scheduled board touchpoint. Holds
--     status state machine, prep deadline, agenda + decisions + materials.
--   * founder_board_meeting_action_items — one row per action item committed
--     in a meeting. FK to meeting, owner, due date, status.
--
-- KPIs surface: total meetings, status funnel (scheduled → held), days-to-next
-- meeting, days-since-last, action item open/overdue/closed%, prep-deadline
-- overdue, formal meetings YTD, last decision recency.

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_board_meetings (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_label         text NOT NULL UNIQUE,
  scheduled_at          timestamptz NOT NULL,
  kind                  text CHECK (kind IN ('formal_board','informal_check_in','observer_only','strategy_offsite')),
  location              text,
  attendees_planned     text,
  attendees_actual      text,
  status                text NOT NULL DEFAULT 'scheduled' CHECK (status IN
                          ('scheduled','prepped','held','rescheduled','cancelled')),
  prep_deadline         date,
  agenda_summary        text,
  decisions_log         text,
  action_items_count    int NOT NULL DEFAULT 0,
  materials_url         text,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_board_meetings IS
  'Board meeting prep ledger — one row per scheduled board touchpoint with agenda + decisions + materials.';

CREATE INDEX IF NOT EXISTS idx_founder_board_meetings_status     ON public.founder_board_meetings (status);
CREATE INDEX IF NOT EXISTS idx_founder_board_meetings_scheduled  ON public.founder_board_meetings (scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_board_meetings_kind       ON public.founder_board_meetings (kind);
CREATE INDEX IF NOT EXISTS idx_founder_board_meetings_prep       ON public.founder_board_meetings (prep_deadline) WHERE prep_deadline IS NOT NULL;

ALTER TABLE public.founder_board_meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_board_meetings_no_direct ON public.founder_board_meetings;
CREATE POLICY founder_board_meetings_no_direct ON public.founder_board_meetings FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_board_meetings FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.founder_board_meeting_action_items (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id      uuid NOT NULL REFERENCES public.founder_board_meetings(id) ON DELETE CASCADE,
  description     text NOT NULL,
  owner_user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  due_date        date,
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','wont_do')),
  closed_at       timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_board_meeting_action_items IS
  'Action items committed during a board meeting. Owner + due date + status state machine.';

CREATE INDEX IF NOT EXISTS idx_founder_board_action_items_meeting ON public.founder_board_meeting_action_items (meeting_id, status);
CREATE INDEX IF NOT EXISTS idx_founder_board_action_items_owner   ON public.founder_board_meeting_action_items (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_founder_board_action_items_due     ON public.founder_board_meeting_action_items (due_date) WHERE status IN ('open','in_progress');
CREATE INDEX IF NOT EXISTS idx_founder_board_action_items_status  ON public.founder_board_meeting_action_items (status);

ALTER TABLE public.founder_board_meeting_action_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_board_action_items_no_direct ON public.founder_board_meeting_action_items;
CREATE POLICY founder_board_action_items_no_direct ON public.founder_board_meeting_action_items FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_board_meeting_action_items FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_board_meeting_create(text, timestamptz, text, text, text, date, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_board_meeting_create(
  p_label            text,
  p_scheduled_at     timestamptz,
  p_kind             text DEFAULT 'formal_board',
  p_location         text DEFAULT NULL,
  p_attendees        text DEFAULT NULL,
  p_prep_deadline    date DEFAULT NULL,
  p_agenda_summary   text DEFAULT NULL,
  p_materials_url    text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_kind IS NOT NULL AND p_kind NOT IN ('formal_board','informal_check_in','observer_only','strategy_offsite') THEN
    RAISE EXCEPTION 'invalid kind %', p_kind USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.founder_board_meetings
    (meeting_label, scheduled_at, kind, location, attendees_planned,
     prep_deadline, agenda_summary, materials_url)
  VALUES
    (p_label, p_scheduled_at, coalesce(p_kind, 'formal_board'), p_location, p_attendees,
     p_prep_deadline, p_agenda_summary, p_materials_url)
  ON CONFLICT (meeting_label) DO UPDATE
    SET scheduled_at      = EXCLUDED.scheduled_at,
        kind              = coalesce(EXCLUDED.kind, public.founder_board_meetings.kind),
        location          = coalesce(EXCLUDED.location, public.founder_board_meetings.location),
        attendees_planned = coalesce(EXCLUDED.attendees_planned, public.founder_board_meetings.attendees_planned),
        prep_deadline     = coalesce(EXCLUDED.prep_deadline, public.founder_board_meetings.prep_deadline),
        agenda_summary    = coalesce(EXCLUDED.agenda_summary, public.founder_board_meetings.agenda_summary),
        materials_url     = coalesce(EXCLUDED.materials_url, public.founder_board_meetings.materials_url),
        updated_at        = now()
    RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_board_meeting_create(text, timestamptz, text, text, text, date, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_board_meeting_create(text, timestamptz, text, text, text, date, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_board_meeting_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_board_meeting_status(
  p_id          uuid,
  p_new_status  text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_new_status NOT IN ('scheduled','prepped','held','rescheduled','cancelled') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE = '22023';
  END IF;
  UPDATE public.founder_board_meetings
    SET status     = p_new_status,
        updated_at = now()
    WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_board_meeting_status(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_board_meeting_status(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_board_meeting_add_action_item(uuid, text, uuid, date);
CREATE OR REPLACE FUNCTION public.log_founder_board_meeting_add_action_item(
  p_meeting_id  uuid,
  p_desc        text,
  p_owner       uuid DEFAULT NULL,
  p_due         date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_desc IS NULL OR length(trim(p_desc)) = 0 THEN
    RAISE EXCEPTION 'description required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.founder_board_meeting_action_items
    (meeting_id, description, owner_user_id, due_date)
  VALUES
    (p_meeting_id, p_desc, p_owner, p_due)
  RETURNING id INTO v_id;

  UPDATE public.founder_board_meetings
    SET action_items_count = (SELECT count(*)::int FROM public.founder_board_meeting_action_items
                                WHERE meeting_id = p_meeting_id),
        updated_at         = now()
    WHERE id = p_meeting_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_board_meeting_add_action_item(uuid, text, uuid, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_board_meeting_add_action_item(uuid, text, uuid, date) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_board_meeting_close_action_item(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_board_meeting_close_action_item(p_item_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_board_meeting_action_items
    SET status    = 'closed',
        closed_at = now()
    WHERE id = p_item_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_board_meeting_close_action_item(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_board_meeting_close_action_item(uuid) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_board_meeting_prep_summary();
CREATE OR REPLACE FUNCTION public.founder_board_meeting_prep_summary()
RETURNS TABLE (
  total_meetings              bigint,
  scheduled_count             bigint,
  prepped_count               bigint,
  held_count                  bigint,
  days_to_next_meeting        int,
  days_since_last_held        int,
  action_items_open_count     bigint,
  action_items_overdue_count  bigint,
  action_items_closed_pct     numeric,
  formal_meetings_ytd         bigint,
  prep_deadline_overdue_count bigint,
  last_decision_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings WHERE status = 'scheduled'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings WHERE status = 'prepped'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings WHERE status = 'held'), 0),
    coalesce((SELECT extract(day from (scheduled_at - now()))::int
              FROM public.founder_board_meetings
              WHERE status IN ('scheduled','prepped') AND scheduled_at >= now()
              ORDER BY scheduled_at ASC LIMIT 1), 0),
    coalesce((SELECT extract(day from (now() - scheduled_at))::int
              FROM public.founder_board_meetings
              WHERE status = 'held'
              ORDER BY scheduled_at DESC LIMIT 1), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meeting_action_items
              WHERE status IN ('open','in_progress')), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meeting_action_items
              WHERE status IN ('open','in_progress')
                AND due_date IS NOT NULL AND due_date < current_date), 0),
    coalesce((SELECT round(100.0 * count(*) FILTER (WHERE status = 'closed') / nullif(count(*), 0), 1)
              FROM public.founder_board_meeting_action_items), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings
              WHERE kind = 'formal_board'
                AND scheduled_at >= date_trunc('year', now())), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_board_meetings
              WHERE status IN ('scheduled','prepped')
                AND prep_deadline IS NOT NULL AND prep_deadline < current_date), 0),
    (SELECT max(scheduled_at) FROM public.founder_board_meetings
       WHERE status = 'held' AND decisions_log IS NOT NULL AND length(trim(decisions_log)) > 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_board_meeting_prep_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_board_meeting_prep_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_board_meetings_recent(int);
CREATE OR REPLACE FUNCTION public.founder_board_meetings_recent(p_limit int DEFAULT 20)
RETURNS TABLE (
  id                  uuid,
  meeting_label       text,
  scheduled_at        timestamptz,
  kind                text,
  location            text,
  status              text,
  prep_deadline       date,
  days_to_prep        int,
  attendees_planned   text,
  action_items_count  int,
  open_action_items   bigint,
  materials_url       text,
  agenda_summary      text,
  created_at          timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT m.id,
         m.meeting_label,
         m.scheduled_at,
         m.kind,
         m.location,
         m.status,
         m.prep_deadline,
         CASE WHEN m.prep_deadline IS NULL THEN NULL
              ELSE (m.prep_deadline - current_date)::int END,
         m.attendees_planned,
         m.action_items_count,
         (SELECT count(*)::bigint FROM public.founder_board_meeting_action_items a
           WHERE a.meeting_id = m.id AND a.status IN ('open','in_progress')),
         m.materials_url,
         m.agenda_summary,
         m.created_at
    FROM public.founder_board_meetings m
    ORDER BY m.scheduled_at DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_board_meetings_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_board_meetings_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_board_meeting_action_items_open(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_board_meeting_action_items_open(
  p_meeting_id uuid DEFAULT NULL,
  p_limit      int  DEFAULT 50
)
RETURNS TABLE (
  id              uuid,
  meeting_id      uuid,
  meeting_label   text,
  description     text,
  owner_user_id   uuid,
  due_date        date,
  days_to_due     int,
  status          text,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT a.id,
         a.meeting_id,
         m.meeting_label,
         a.description,
         a.owner_user_id,
         a.due_date,
         CASE WHEN a.due_date IS NULL THEN NULL
              ELSE (a.due_date - current_date)::int END,
         a.status,
         a.created_at
    FROM public.founder_board_meeting_action_items a
    JOIN public.founder_board_meetings m ON m.id = a.meeting_id
    WHERE a.status IN ('open','in_progress')
      AND (p_meeting_id IS NULL OR a.meeting_id = p_meeting_id)
    ORDER BY CASE WHEN a.due_date IS NULL THEN 1 ELSE 0 END,
             a.due_date ASC,
             a.created_at DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_board_meeting_action_items_open(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_board_meeting_action_items_open(uuid, int) TO authenticated;

COMMIT;