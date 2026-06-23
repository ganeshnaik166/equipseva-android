BEGIN;

CREATE TABLE IF NOT EXISTS public.cross_functional_syncs_r2365 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_title text NOT NULL,
  sync_date date NOT NULL,
  week_iso text NOT NULL,
  teams_involved text[] NOT NULL DEFAULT '{}',
  invited_count int NOT NULL DEFAULT 0 CHECK (invited_count >= 0),
  attended_count int NOT NULL DEFAULT 0 CHECK (attended_count >= 0),
  duration_minutes int NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
  agenda_md text NOT NULL DEFAULT '',
  notes_md text NOT NULL DEFAULT '',
  facilitator_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','held','cancelled','rescheduled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cross_functional_sync_decisions_r2365 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_id uuid NOT NULL REFERENCES public.cross_functional_syncs_r2365(id) ON DELETE CASCADE,
  decision_text text NOT NULL,
  decision_type text NOT NULL DEFAULT 'decision' CHECK (decision_type IN ('decision','action_item','blocker','followup')),
  owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cross_functional_syncs_r2365 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cross_functional_sync_decisions_r2365 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_syncs_r2365 ON public.cross_functional_syncs_r2365;
CREATE POLICY founder_all_syncs_r2365 ON public.cross_functional_syncs_r2365
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_decisions_r2365 ON public.cross_functional_sync_decisions_r2365;
CREATE POLICY founder_all_decisions_r2365 ON public.cross_functional_sync_decisions_r2365
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list syncs with rollup
CREATE OR REPLACE FUNCTION public.list_syncs_r2365()
RETURNS TABLE (
  id uuid,
  sync_title text,
  sync_date date,
  week_iso text,
  teams_count int,
  invited_count int,
  attended_count int,
  attendance_pct numeric,
  duration_minutes int,
  status text,
  decision_count int,
  open_action_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.sync_title, s.sync_date, s.week_iso,
    (COALESCE(array_length(s.teams_involved, 1), 0))::int AS teams_count,
    s.invited_count, s.attended_count,
    CASE WHEN s.invited_count = 0 THEN 0::numeric
      ELSE ROUND((s.attended_count::numeric / s.invited_count::numeric) * 100, 1) END AS attendance_pct,
    s.duration_minutes, s.status,
    (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d WHERE d.sync_id = s.id) AS decision_count,
    (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d WHERE d.sync_id = s.id AND d.decision_type = 'action_item' AND d.status IN ('open','in_progress')) AS open_action_count
  FROM public.cross_functional_syncs_r2365 s
  ORDER BY s.sync_date DESC, s.created_at DESC;
END;
$$;

-- RPC 2: schedule sync
CREATE OR REPLACE FUNCTION public.schedule_sync_r2365(
  p_sync_title text,
  p_sync_date date,
  p_week_iso text,
  p_teams_involved text[],
  p_invited_count int,
  p_duration_minutes int,
  p_agenda_md text,
  p_facilitator_id uuid
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.cross_functional_syncs_r2365 (sync_title, sync_date, week_iso, teams_involved, invited_count, duration_minutes, agenda_md, facilitator_id)
  VALUES (p_sync_title, p_sync_date, p_week_iso, COALESCE(p_teams_involved, '{}'), GREATEST(p_invited_count, 0), GREATEST(p_duration_minutes, 1), COALESCE(p_agenda_md, ''), p_facilitator_id)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 3: mark held with attendance + notes
CREATE OR REPLACE FUNCTION public.mark_sync_held_r2365(
  p_sync_id uuid,
  p_attended_count int,
  p_notes_md text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.cross_functional_syncs_r2365
  SET status = 'held',
      attended_count = GREATEST(p_attended_count, 0),
      notes_md = COALESCE(p_notes_md, notes_md),
      updated_at = now()
  WHERE id = p_sync_id;
END;
$$;

-- RPC 4: add decision/action
CREATE OR REPLACE FUNCTION public.add_sync_decision_r2365(
  p_sync_id uuid,
  p_decision_text text,
  p_decision_type text,
  p_owner_id uuid,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.cross_functional_sync_decisions_r2365 (sync_id, decision_text, decision_type, owner_id, due_date)
  VALUES (p_sync_id, p_decision_text, COALESCE(p_decision_type, 'decision'), p_owner_id, p_due_date)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 5: close decision/action
CREATE OR REPLACE FUNCTION public.close_sync_decision_r2365(
  p_decision_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.cross_functional_sync_decisions_r2365
  SET status = COALESCE(p_status, 'done'),
      closed_at = CASE WHEN COALESCE(p_status, 'done') IN ('done','dropped') THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_decision_id;
END;
$$;

-- RPC 6: open actions across all syncs
CREATE OR REPLACE FUNCTION public.open_sync_actions_r2365()
RETURNS TABLE (
  id uuid,
  sync_id uuid,
  sync_title text,
  sync_date date,
  decision_text text,
  decision_type text,
  owner_id uuid,
  owner_email text,
  due_date date,
  days_overdue int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.sync_id, s.sync_title, s.sync_date, d.decision_text, d.decision_type,
    d.owner_id, p.email AS owner_email, d.due_date,
    CASE WHEN d.due_date IS NULL OR d.due_date >= CURRENT_DATE THEN 0
      ELSE (CURRENT_DATE - d.due_date)::int END AS days_overdue,
    d.status
  FROM public.cross_functional_sync_decisions_r2365 d
  JOIN public.cross_functional_syncs_r2365 s ON s.id = d.sync_id
  LEFT JOIN public.profiles p ON p.id = d.owner_id
  WHERE d.status IN ('open','in_progress')
  ORDER BY (d.due_date IS NULL), d.due_date ASC, s.sync_date DESC;
END;
$$;

-- RPC 7: weekly ROI rollup (attendance x decisions ratio)
CREATE OR REPLACE FUNCTION public.weekly_sync_roi_r2365()
RETURNS TABLE (
  week_iso text,
  syncs_held int,
  syncs_cancelled int,
  total_invited int,
  total_attended int,
  attendance_pct numeric,
  total_decisions int,
  total_actions int,
  closed_actions int,
  open_actions int,
  decisions_per_sync numeric,
  attendance_x_decisions numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT s.week_iso,
      SUM(CASE WHEN s.status = 'held' THEN 1 ELSE 0 END)::int AS syncs_held,
      SUM(CASE WHEN s.status = 'cancelled' THEN 1 ELSE 0 END)::int AS syncs_cancelled,
      SUM(s.invited_count)::int AS total_invited,
      SUM(s.attended_count)::int AS total_attended,
      (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d
        JOIN public.cross_functional_syncs_r2365 s2 ON s2.id = d.sync_id
        WHERE s2.week_iso = s.week_iso AND d.decision_type = 'decision') AS total_decisions,
      (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d
        JOIN public.cross_functional_syncs_r2365 s2 ON s2.id = d.sync_id
        WHERE s2.week_iso = s.week_iso AND d.decision_type = 'action_item') AS total_actions,
      (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d
        JOIN public.cross_functional_syncs_r2365 s2 ON s2.id = d.sync_id
        WHERE s2.week_iso = s.week_iso AND d.decision_type = 'action_item' AND d.status = 'done') AS closed_actions,
      (SELECT (COUNT(*))::int FROM public.cross_functional_sync_decisions_r2365 d
        JOIN public.cross_functional_syncs_r2365 s2 ON s2.id = d.sync_id
        WHERE s2.week_iso = s.week_iso AND d.decision_type = 'action_item' AND d.status IN ('open','in_progress')) AS open_actions
    FROM public.cross_functional_syncs_r2365 s
    GROUP BY s.week_iso
  )
  SELECT a.week_iso, a.syncs_held, a.syncs_cancelled, a.total_invited, a.total_attended,
    CASE WHEN a.total_invited = 0 THEN 0::numeric
      ELSE ROUND((a.total_attended::numeric / a.total_invited::numeric) * 100, 1) END AS attendance_pct,
    a.total_decisions, a.total_actions, a.closed_actions, a.open_actions,
    CASE WHEN a.syncs_held = 0 THEN 0::numeric
      ELSE ROUND((a.total_decisions + a.total_actions)::numeric / a.syncs_held::numeric, 2) END AS decisions_per_sync,
    CASE WHEN a.total_invited = 0 OR a.syncs_held = 0 THEN 0::numeric
      ELSE ROUND(((a.total_attended::numeric / a.total_invited::numeric) * ((a.total_decisions + a.total_actions)::numeric / a.syncs_held::numeric)) * 100, 2) END AS attendance_x_decisions
  FROM agg a
  ORDER BY a.week_iso DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_syncs_r2365() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.schedule_sync_r2365(text, date, text, text[], int, int, text, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_sync_held_r2365(uuid, int, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.add_sync_decision_r2365(uuid, text, text, uuid, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.close_sync_decision_r2365(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.open_sync_actions_r2365() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.weekly_sync_roi_r2365() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_syncs_r2365() TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_sync_r2365(text, date, text, text[], int, int, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_sync_held_r2365(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_sync_decision_r2365(uuid, text, text, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_sync_decision_r2365(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_sync_actions_r2365() TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_sync_roi_r2365() TO authenticated;

COMMIT;
