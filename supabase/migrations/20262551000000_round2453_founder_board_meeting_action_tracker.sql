-- Round 2453: founder-board-meeting-action-tracker
-- meeting × decisions × action items × owner × due date × completion status

CREATE TABLE IF NOT EXISTS public.board_meetings_r2453 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_label text NOT NULL,
  held_at timestamptz NOT NULL,
  attendees_md text,
  decisions_md text,
  key_resolutions_md text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','held','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_meeting_actions_r2453 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.board_meetings_r2453(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  owner_role text NOT NULL CHECK (owner_role IN ('founder','investor','external')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  outcome_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_meetings_r2453 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_meeting_actions_r2453 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.board_meetings_r2453;
CREATE POLICY founder_all ON public.board_meetings_r2453
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.board_meeting_actions_r2453;
CREATE POLICY founder_all ON public.board_meeting_actions_r2453
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.board_meetings_r2453 (meeting_label, held_at, attendees_md, decisions_md, key_resolutions_md, status, notes) VALUES
  ('Q1 FY27 Board Meeting', '2026-04-15'::timestamptz, '- Founder\n- Lead Investor (Accel)\n- Independent Director\n- CFO', '- Approved Series B fundraise plan\n- Greenlit Tier-1 expansion to 5 cities', '- Resolution 27/1: Authorize ESOP pool top-up by 4%\n- Resolution 27/2: Appoint statutory auditor', 'held', 'Strong support for v0.6 roadmap'),
  ('Q2 FY27 Board Meeting', '2026-07-15'::timestamptz, '- Founder\n- Lead Investor\n- Independent Director\n- CFO\n- New Co-Investor', '- Pending', '- Pending', 'scheduled', 'Investor data room prep needed'),
  ('Special Resolution Meeting - ESOP', '2026-05-20'::timestamptz, '- Founder\n- Lead Investor\n- Company Secretary', '- Approved ESOP pool expansion 4%\n- Approved new grant policy', '- Resolution SR/2026/01: ESOP pool 12% to 16%', 'held', 'Special resolution filed with MCA'),
  ('Annual Strategy Offsite', '2026-03-10'::timestamptz, '- Founder\n- All board members\n- Senior leadership', '- Pivot focus to clinical outcome linkage\n- Kill franchise pilot (deferred)', '- Resolution AS/2026/01: 18-month plan approved', 'held', 'Bangalore offsite'),
  ('Emergency Board Call - Vendor Crisis', '2026-06-05'::timestamptz, '- Founder\n- Lead Investor\n- Legal Counsel', '- Approved emergency legal counsel switch\n- Authorized 2Cr contingency spend', '- Resolution EM/2026/01: Emergency spend approval', 'held', 'Sundar & Co exit triggered');

INSERT INTO public.board_meeting_actions_r2453 (meeting_id, action_text, owner_email, owner_role, priority, due_at, status, closed_at, closed_by_email, outcome_md, notes) VALUES
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Q1 FY27 Board Meeting'), 'Prepare Series B pitch deck with v0.6 milestones', 'founder@equipseva.in', 'founder', 'urgent', '2026-06-30'::timestamptz, 'in_progress', NULL, NULL, NULL, 'Draft v3 in review'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Q1 FY27 Board Meeting'), 'Share Tier-1 expansion city-by-city plan', 'founder@equipseva.in', 'founder', 'high', '2026-05-30'::timestamptz, 'done', '2026-05-25'::timestamptz, 'founder@equipseva.in', '- Shared on 2026-05-25\n- Board approved 5-city plan', 'Done ahead of schedule'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Q1 FY27 Board Meeting'), 'Introduce founder to 3 strategic LPs', 'partner@accel.com', 'investor', 'high', '2026-06-15'::timestamptz, 'in_progress', NULL, NULL, NULL, '2 of 3 intros done'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Special Resolution Meeting - ESOP'), 'File ESOP pool resolution with MCA', 'cs@equipseva.in', 'external', 'urgent', '2026-06-01'::timestamptz, 'done', '2026-05-28'::timestamptz, 'cs@equipseva.in', '- Filed SH-7 on 2026-05-28\n- Acknowledged by MCA', 'Filed early'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Special Resolution Meeting - ESOP'), 'Communicate ESOP refresh to top performers', 'hr@equipseva.in', 'founder', 'medium', '2026-06-20'::timestamptz, 'open', NULL, NULL, NULL, 'Awaiting HR plan'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Annual Strategy Offsite'), 'Document 18-month clinical outcome linkage plan', 'founder@equipseva.in', 'founder', 'high', '2026-04-30'::timestamptz, 'done', '2026-04-25'::timestamptz, 'founder@equipseva.in', '- v0.5 roadmap published\n- Board signed off', 'Closed'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Annual Strategy Offsite'), 'Kill franchise pilot - communicate to ops team', 'ops@equipseva.in', 'founder', 'medium', '2026-04-15'::timestamptz, 'done', '2026-04-12'::timestamptz, 'ops@equipseva.in', '- Pilot stopped\n- Team reassigned', 'Smooth wind-down'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Emergency Board Call - Vendor Crisis'), 'Finalize new legal partner', 'founder@equipseva.in', 'founder', 'urgent', '2026-07-15'::timestamptz, 'in_progress', NULL, NULL, NULL, '2 firms shortlisted'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Emergency Board Call - Vendor Crisis'), 'Review contingency spend monthly with CFO', 'cfo@equipseva.in', 'founder', 'high', '2026-12-31'::timestamptz, 'in_progress', NULL, NULL, NULL, 'Monthly checkpoint'),
  ((SELECT id FROM public.board_meetings_r2453 WHERE meeting_label='Annual Strategy Offsite'), 'Stale action - draft franchise reentry memo', 'founder@equipseva.in', 'founder', 'low', '2026-05-15'::timestamptz, 'dropped', '2026-06-01'::timestamptz, 'founder@equipseva.in', '- Dropped per offsite decision\n- No reentry within 18 months', 'Closed as not relevant');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_meetings_r2453()
RETURNS TABLE (
  id uuid,
  meeting_label text,
  held_at timestamptz,
  status text,
  decisions_md text,
  key_resolutions_md text,
  attendees_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.meeting_label, m.held_at, m.status,
           m.decisions_md, m.key_resolutions_md, m.attendees_md
    FROM public.board_meetings_r2453 m
    ORDER BY m.held_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meetings_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_actions_r2453()
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  meeting_label text,
  action_text text,
  owner_email text,
  owner_role text,
  priority text,
  due_at timestamptz,
  status text,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.meeting_id, m.meeting_label, a.action_text,
           a.owner_email, a.owner_role, a.priority, a.due_at,
           a.status, a.closed_at
    FROM public.board_meeting_actions_r2453 a
    JOIN public.board_meetings_r2453 m ON m.id = a.meeting_id
    ORDER BY
      CASE a.status WHEN 'open' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'done' THEN 3 ELSE 4 END,
      a.due_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.overdue_actions_r2453()
RETURNS TABLE (
  id uuid,
  meeting_label text,
  action_text text,
  owner_email text,
  owner_role text,
  priority text,
  due_at timestamptz,
  days_overdue int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, m.meeting_label, a.action_text, a.owner_email, a.owner_role,
           a.priority, a.due_at,
           EXTRACT(DAY FROM (now() - a.due_at))::int AS days_overdue,
           a.status
    FROM public.board_meeting_actions_r2453 a
    JOIN public.board_meetings_r2453 m ON m.id = a.meeting_id
    WHERE a.status IN ('open','in_progress')
      AND a.due_at IS NOT NULL
      AND a.due_at < now()
    ORDER BY a.due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.overdue_actions_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_actions_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.owner_role_breakdown_r2453()
RETURNS TABLE (
  owner_role text,
  total_actions int,
  open_count int,
  in_progress_count int,
  done_count int,
  dropped_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.owner_role,
           COUNT(*)::int AS total_actions,
           COUNT(*) FILTER (WHERE a.status = 'open')::int AS open_count,
           COUNT(*) FILTER (WHERE a.status = 'in_progress')::int AS in_progress_count,
           COUNT(*) FILTER (WHERE a.status = 'done')::int AS done_count,
           COUNT(*) FILTER (WHERE a.status = 'dropped')::int AS dropped_count
    FROM public.board_meeting_actions_r2453 a
    GROUP BY a.owner_role
    ORDER BY total_actions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_role_breakdown_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_role_breakdown_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.completion_rate_r2453()
RETURNS TABLE (
  total_actions int,
  done_count int,
  dropped_count int,
  open_count int,
  in_progress_count int,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::int AS total_actions,
           COUNT(*) FILTER (WHERE a.status = 'done')::int AS done_count,
           COUNT(*) FILTER (WHERE a.status = 'dropped')::int AS dropped_count,
           COUNT(*) FILTER (WHERE a.status = 'open')::int AS open_count,
           COUNT(*) FILTER (WHERE a.status = 'in_progress')::int AS in_progress_count,
           CASE WHEN COUNT(*) = 0 THEN 0
                ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.status = 'done') / COUNT(*), 1)
           END AS completion_pct
    FROM public.board_meeting_actions_r2453 a;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.completion_rate_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.completion_rate_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_open_actions_r2453()
RETURNS TABLE (
  id uuid,
  meeting_label text,
  action_text text,
  owner_email text,
  owner_role text,
  priority text,
  due_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, m.meeting_label, a.action_text, a.owner_email, a.owner_role,
           a.priority, a.due_at, a.status
    FROM public.board_meeting_actions_r2453 a
    JOIN public.board_meetings_r2453 m ON m.id = a.meeting_id
    WHERE a.status IN ('open','in_progress')
    ORDER BY
      CASE a.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
      a.due_at ASC NULLS LAST
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_open_actions_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_open_actions_r2453() TO authenticated;


CREATE OR REPLACE FUNCTION public.recent_decisions_r2453()
RETURNS TABLE (
  id uuid,
  meeting_label text,
  held_at timestamptz,
  decisions_md text,
  key_resolutions_md text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.meeting_label, m.held_at, m.decisions_md,
           m.key_resolutions_md, m.status
    FROM public.board_meetings_r2453 m
    WHERE m.status = 'held'
    ORDER BY m.held_at DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_decisions_r2453() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_decisions_r2453() TO authenticated;
