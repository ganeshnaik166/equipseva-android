-- r2415 — hospital-chain-quarterly-business-review-tracker
-- QBR meetings × attendees × action items × follow-up status × NPS at QBR

BEGIN;

-- =====================================================================
-- TABLE 1: chain_qbr_meetings_r2415
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_qbr_meetings_r2415 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  qbr_quarter text NOT NULL CHECK (qbr_quarter ~ '^[0-9]{4}Q[1-4]$'),
  held_on date,
  attendee_count integer NOT NULL DEFAULT 0 CHECK (attendee_count >= 0),
  attendee_titles text,
  our_attendee_emails text,
  agenda_md text,
  summary_md text,
  nps_at_qbr integer CHECK (nps_at_qbr IS NULL OR nps_at_qbr BETWEEN -100 AND 100),
  next_qbr_due_on date,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','held','cancelled','rescheduled')),
  notes text
);

ALTER TABLE public.chain_qbr_meetings_r2415 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.chain_qbr_meetings_r2415
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS chain_qbr_meetings_r2415_chain_idx
  ON public.chain_qbr_meetings_r2415(chain_name);
CREATE INDEX IF NOT EXISTS chain_qbr_meetings_r2415_quarter_idx
  ON public.chain_qbr_meetings_r2415(qbr_quarter);
CREATE INDEX IF NOT EXISTS chain_qbr_meetings_r2415_status_idx
  ON public.chain_qbr_meetings_r2415(status);
CREATE INDEX IF NOT EXISTS chain_qbr_meetings_r2415_next_due_idx
  ON public.chain_qbr_meetings_r2415(next_qbr_due_on);

-- =====================================================================
-- TABLE 2: chain_qbr_action_items_r2415
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_qbr_action_items_r2415 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  qbr_meeting_id uuid NOT NULL REFERENCES public.chain_qbr_meetings_r2415(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text NOT NULL,
  owner_side text NOT NULL CHECK (owner_side IN ('ours','theirs')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

ALTER TABLE public.chain_qbr_action_items_r2415 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.chain_qbr_action_items_r2415
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS chain_qbr_actions_r2415_meeting_idx
  ON public.chain_qbr_action_items_r2415(qbr_meeting_id);
CREATE INDEX IF NOT EXISTS chain_qbr_actions_r2415_status_idx
  ON public.chain_qbr_action_items_r2415(status);
CREATE INDEX IF NOT EXISTS chain_qbr_actions_r2415_priority_idx
  ON public.chain_qbr_action_items_r2415(priority);
CREATE INDEX IF NOT EXISTS chain_qbr_actions_r2415_due_idx
  ON public.chain_qbr_action_items_r2415(due_at);

-- =====================================================================
-- RPC 1: list_qbrs_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_qbrs_r2415()
RETURNS TABLE(
  id uuid,
  chain_name text,
  qbr_quarter text,
  held_on date,
  attendee_count integer,
  attendee_titles text,
  our_attendee_emails text,
  nps_at_qbr integer,
  next_qbr_due_on date,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.chain_name,
    m.qbr_quarter,
    m.held_on,
    m.attendee_count,
    m.attendee_titles,
    m.our_attendee_emails,
    m.nps_at_qbr,
    m.next_qbr_due_on,
    m.status,
    m.notes,
    m.created_at
  FROM public.chain_qbr_meetings_r2415 m
  ORDER BY COALESCE(m.held_on, m.created_at::date) DESC, m.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_qbrs_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_qbrs_r2415() TO authenticated;

-- =====================================================================
-- RPC 2: list_actions_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r2415()
RETURNS TABLE(
  id uuid,
  qbr_meeting_id uuid,
  chain_name text,
  qbr_quarter text,
  action_text text,
  owner_email text,
  owner_side text,
  priority text,
  due_at timestamptz,
  status text,
  closed_at timestamptz,
  closed_by_email text,
  days_to_due integer,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.qbr_meeting_id,
    m.chain_name,
    m.qbr_quarter,
    a.action_text,
    a.owner_email,
    a.owner_side,
    a.priority,
    a.due_at,
    a.status,
    a.closed_at,
    a.closed_by_email,
    CASE WHEN a.due_at IS NULL THEN NULL
         ELSE EXTRACT(DAY FROM (a.due_at - now()))::integer END AS days_to_due,
    a.notes,
    a.created_at
  FROM public.chain_qbr_action_items_r2415 a
  JOIN public.chain_qbr_meetings_r2415 m ON m.id = a.qbr_meeting_id
  ORDER BY
    CASE a.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    a.due_at NULLS LAST,
    a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2415() TO authenticated;

-- =====================================================================
-- RPC 3: overdue_qbrs_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.overdue_qbrs_r2415()
RETURNS TABLE(
  chain_name text,
  last_held_on date,
  next_qbr_due_on date,
  days_overdue integer,
  last_status text,
  last_quarter text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (m.chain_name)
      m.chain_name,
      m.held_on,
      m.next_qbr_due_on,
      m.status,
      m.qbr_quarter
    FROM public.chain_qbr_meetings_r2415 m
    ORDER BY m.chain_name, COALESCE(m.held_on, m.created_at::date) DESC
  )
  SELECT
    l.chain_name,
    l.held_on,
    l.next_qbr_due_on,
    (current_date - l.next_qbr_due_on)::integer AS days_overdue,
    l.status,
    l.qbr_quarter
  FROM latest l
  WHERE l.next_qbr_due_on IS NOT NULL AND l.next_qbr_due_on < current_date
  ORDER BY (current_date - l.next_qbr_due_on) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.overdue_qbrs_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_qbrs_r2415() TO authenticated;

-- =====================================================================
-- RPC 4: action_completion_rate_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.action_completion_rate_r2415()
RETURNS TABLE(
  chain_name text,
  total_actions integer,
  done_count integer,
  open_count integer,
  in_progress_count integer,
  dropped_count integer,
  completion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.chain_name,
    COUNT(a.id)::integer AS total_actions,
    COUNT(*) FILTER (WHERE a.status = 'done')::integer AS done_count,
    COUNT(*) FILTER (WHERE a.status = 'open')::integer AS open_count,
    COUNT(*) FILTER (WHERE a.status = 'in_progress')::integer AS in_progress_count,
    COUNT(*) FILTER (WHERE a.status = 'dropped')::integer AS dropped_count,
    CASE WHEN COUNT(a.id) = 0 THEN 0::numeric
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.status = 'done') / COUNT(a.id), 1)
    END AS completion_rate_pct
  FROM public.chain_qbr_meetings_r2415 m
  LEFT JOIN public.chain_qbr_action_items_r2415 a ON a.qbr_meeting_id = m.id
  GROUP BY m.chain_name
  ORDER BY completion_rate_pct ASC, total_actions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_completion_rate_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_completion_rate_r2415() TO authenticated;

-- =====================================================================
-- RPC 5: top_open_actions_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_open_actions_r2415()
RETURNS TABLE(
  id uuid,
  chain_name text,
  qbr_quarter text,
  action_text text,
  owner_email text,
  owner_side text,
  priority text,
  due_at timestamptz,
  days_overdue integer,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    m.chain_name,
    m.qbr_quarter,
    a.action_text,
    a.owner_email,
    a.owner_side,
    a.priority,
    a.due_at,
    CASE WHEN a.due_at IS NULL THEN NULL
         WHEN a.due_at >= now() THEN 0
         ELSE EXTRACT(DAY FROM (now() - a.due_at))::integer END AS days_overdue,
    a.status
  FROM public.chain_qbr_action_items_r2415 a
  JOIN public.chain_qbr_meetings_r2415 m ON m.id = a.qbr_meeting_id
  WHERE a.status IN ('open','in_progress')
  ORDER BY
    CASE a.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    a.due_at NULLS LAST
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_open_actions_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_open_actions_r2415() TO authenticated;

-- =====================================================================
-- RPC 6: chain_nps_at_qbr_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.chain_nps_at_qbr_r2415()
RETURNS TABLE(
  chain_name text,
  qbrs_with_nps integer,
  latest_nps integer,
  latest_quarter text,
  latest_held_on date,
  avg_nps numeric,
  min_nps integer,
  max_nps integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (m.chain_name)
      m.chain_name,
      m.nps_at_qbr,
      m.qbr_quarter,
      m.held_on
    FROM public.chain_qbr_meetings_r2415 m
    WHERE m.nps_at_qbr IS NOT NULL
    ORDER BY m.chain_name, COALESCE(m.held_on, m.created_at::date) DESC
  ),
  agg AS (
    SELECT
      m.chain_name,
      COUNT(*) FILTER (WHERE m.nps_at_qbr IS NOT NULL)::integer AS qbrs_with_nps,
      ROUND(AVG(m.nps_at_qbr)::numeric, 1) AS avg_nps,
      MIN(m.nps_at_qbr)::integer AS min_nps,
      MAX(m.nps_at_qbr)::integer AS max_nps
    FROM public.chain_qbr_meetings_r2415 m
    GROUP BY m.chain_name
  )
  SELECT
    a.chain_name,
    a.qbrs_with_nps,
    l.nps_at_qbr AS latest_nps,
    l.qbr_quarter AS latest_quarter,
    l.held_on AS latest_held_on,
    a.avg_nps,
    a.min_nps,
    a.max_nps
  FROM agg a
  LEFT JOIN latest l ON l.chain_name = a.chain_name
  ORDER BY a.avg_nps DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.chain_nps_at_qbr_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_nps_at_qbr_r2415() TO authenticated;

-- =====================================================================
-- RPC 7: qbr_completion_funnel_r2415
-- =====================================================================
CREATE OR REPLACE FUNCTION public.qbr_completion_funnel_r2415()
RETURNS TABLE(
  status text,
  meeting_count integer,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::integer INTO v_total FROM public.chain_qbr_meetings_r2415;
  RETURN QUERY
  SELECT
    s.status,
    COUNT(m.id)::integer AS meeting_count,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(100.0 * COUNT(m.id) / v_total, 1)
    END AS pct_of_total
  FROM (VALUES ('scheduled'),('held'),('cancelled'),('rescheduled')) AS s(status)
  LEFT JOIN public.chain_qbr_meetings_r2415 m ON m.status = s.status
  GROUP BY s.status
  ORDER BY
    CASE s.status WHEN 'scheduled' THEN 1 WHEN 'held' THEN 2 WHEN 'rescheduled' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.qbr_completion_funnel_r2415() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qbr_completion_funnel_r2415() TO authenticated;

-- =====================================================================
-- SEED DATA
-- =====================================================================
INSERT INTO public.chain_qbr_meetings_r2415
  (chain_name, qbr_quarter, held_on, attendee_count, attendee_titles, our_attendee_emails, agenda_md, summary_md, nps_at_qbr, next_qbr_due_on, status, notes)
VALUES
  ('Apollo Hospitals', '2026Q1', '2026-03-18', 6, 'CMO, Biomed Head, Procurement Lead, CIO', 'founder@equipseva.io, success@equipseva.io',
   '# Q1 Agenda\n- Uptime review\n- AMC renewals\n- Spare parts SLO', '# Summary\n- Strong uptime\n- 2 AMCs renewed\n- 1 escalation flagged', 62,
   '2026-06-18', 'held', 'Strong relationship, expanding to 2 more sites'),
  ('Manipal Health', '2026Q1', '2026-03-25', 4, 'COO, Biomed Manager, Finance', 'founder@equipseva.io',
   '# Q1 Agenda\n- Pricing review\n- Engineer SLA', '# Summary\n- Pricing pushback\n- SLA acceptable', 18,
   '2026-06-25', 'held', 'Need to revisit AMC pricing band'),
  ('Fortis Healthcare', '2026Q2', '2026-06-12', 5, 'CMO, Biomed Lead, Procurement', 'founder@equipseva.io, success@equipseva.io',
   '# Q2 Agenda\n- Multi-site rollout\n- Training plan', '# Summary\n- Expansion approved\n- 12 engineers to train', 45,
   '2026-09-12', 'held', 'Best quarter so far with Fortis'),
  ('Narayana Health', '2026Q2', NULL, 0, NULL, 'founder@equipseva.io',
   '# Q2 Agenda\n- Renewal pricing\n- SLA review', NULL, NULL,
   '2026-09-30', 'scheduled', 'Confirming date with COO office'),
  ('Aster DM Healthcare', '2026Q1', '2026-02-28', 3, 'Biomed Director, Finance', 'success@equipseva.io',
   '# Q1 Agenda\n- Onboarding wrap-up', '# Summary\n- Soft start, baseline set', 5,
   '2026-05-28', 'held', 'First QBR after onboarding');

-- Seed action items linked to held meetings
INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, closed_at, closed_by_email, notes)
SELECT m.id, 'Send Q1 uptime PDF to CMO', 'success@equipseva.io', 'ours', 'high',
       now() - interval '40 days', 'done', now() - interval '38 days', 'success@equipseva.io', 'Delivered'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Apollo Hospitals' AND m.qbr_quarter = '2026Q1';

INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, notes)
SELECT m.id, 'Procurement to share FY27 capex plan', 'procurement@apollo.example', 'theirs', 'medium',
       now() - interval '10 days', 'open', 'Awaiting CFO sign-off'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Apollo Hospitals' AND m.qbr_quarter = '2026Q1';

INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, notes)
SELECT m.id, 'Re-quote AMC pricing band', 'founder@equipseva.io', 'ours', 'urgent',
       now() - interval '20 days', 'in_progress', 'Drafted, pending review'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Manipal Health' AND m.qbr_quarter = '2026Q1';

INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, notes)
SELECT m.id, 'Schedule training for 12 engineers', 'success@equipseva.io', 'ours', 'high',
       now() + interval '14 days', 'in_progress', 'Vendor confirmed'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Fortis Healthcare' AND m.qbr_quarter = '2026Q2';

INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, closed_at, closed_by_email, notes)
SELECT m.id, 'Share onboarding checklist', 'success@equipseva.io', 'ours', 'low',
       now() - interval '60 days', 'done', now() - interval '55 days', 'success@equipseva.io', 'Shared'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Aster DM Healthcare' AND m.qbr_quarter = '2026Q1';

INSERT INTO public.chain_qbr_action_items_r2415
  (qbr_meeting_id, action_text, owner_email, owner_side, priority, due_at, status, notes)
SELECT m.id, 'Aster to nominate biomed champion', 'biomed@aster.example', 'theirs', 'medium',
       now() - interval '30 days', 'dropped', 'Org change, deprioritized'
FROM public.chain_qbr_meetings_r2415 m WHERE m.chain_name = 'Aster DM Healthcare' AND m.qbr_quarter = '2026Q1';

