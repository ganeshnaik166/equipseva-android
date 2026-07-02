-- Round 2417: Founder Weekly Team 1:1 Cadence Tracker
-- Tracks 1:1 meetings, gap days, topics covered, and action items pending.

BEGIN;

-- ============================================================
-- TABLE: founder_one_on_ones_r2417
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_one_on_ones_r2417 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  team_member_email text NOT NULL,
  team_member_role text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  held_on timestamptz,
  duration_minutes integer,
  agenda_md text,
  key_topics text[] NOT NULL DEFAULT '{}',
  summary_md text,
  gap_days_since_last integer,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','held','cancelled','no_show')),
  notes text,
  CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 0 AND 480),
  CHECK (gap_days_since_last IS NULL OR gap_days_since_last >= 0)
);

ALTER TABLE public.founder_one_on_ones_r2417 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_one_on_ones_r2417;
CREATE POLICY founder_all ON public.founder_one_on_ones_r2417
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_one_on_ones_r2417_member
  ON public.founder_one_on_ones_r2417(team_member_email);
CREATE INDEX IF NOT EXISTS idx_one_on_ones_r2417_scheduled
  ON public.founder_one_on_ones_r2417(scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_one_on_ones_r2417_status
  ON public.founder_one_on_ones_r2417(status);

-- ============================================================
-- TABLE: one_on_one_action_items_r2417
-- ============================================================
CREATE TABLE IF NOT EXISTS public.one_on_one_action_items_r2417 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  one_on_one_id uuid NOT NULL REFERENCES public.founder_one_on_ones_r2417(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text NOT NULL,
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

ALTER TABLE public.one_on_one_action_items_r2417 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.one_on_one_action_items_r2417;
CREATE POLICY founder_all ON public.one_on_one_action_items_r2417
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_one_on_one_actions_r2417_parent
  ON public.one_on_one_action_items_r2417(one_on_one_id);
CREATE INDEX IF NOT EXISTS idx_one_on_one_actions_r2417_status
  ON public.one_on_one_action_items_r2417(status);
CREATE INDEX IF NOT EXISTS idx_one_on_one_actions_r2417_due
  ON public.one_on_one_action_items_r2417(due_at);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.founder_one_on_ones_r2417
  (team_member_email, team_member_role, scheduled_at, held_on, duration_minutes, agenda_md, key_topics, summary_md, gap_days_since_last, status, notes)
VALUES
  ('priya.sharma@equipseva.com', 'Head of Engineering',
   now() - interval '5 days', now() - interval '5 days', 45,
   'Sprint review, hiring pipeline, on-call rotation',
   ARRAY['sprint_velocity','hiring','on_call'],
   'Velocity steady. Two offers out this week. On-call burnout flagged for SRE-2.',
   7, 'held', 'Strong session. Follow-up on SRE-2 workload.'),
  ('rahul.verma@equipseva.com', 'VP Sales',
   now() - interval '3 days', now() - interval '3 days', 30,
   'Q3 pipeline, hospital chain wins, AMC renewals',
   ARRAY['pipeline','chains','amc_renewals'],
   'Pipeline 1.4Cr. 3 chain wins pending. AMC renewal rate at 78%.',
   14, 'held', 'AMC churn concerning, route to ops.'),
  ('anita.rao@equipseva.com', 'Customer Success Lead',
   now() - interval '1 day', null, null,
   'NPS, escalations, hospital onboarding',
   ARRAY['nps','escalations','onboarding'],
   null,
   10, 'scheduled', null),
  ('vikram.singh@equipseva.com', 'Head of Operations',
   now() - interval '21 days', null, null,
   'SLO breaches, spare parts, supervisor coverage',
   ARRAY['slo','spare_parts','supervisors'],
   null,
   21, 'cancelled', 'Cancelled, reschedule pending.'),
  ('sneha.iyer@equipseva.com', 'Finance Lead',
   now() + interval '2 days', null, null,
   'Burn rate, runway, investor reporting',
   ARRAY['burn','runway','investor_pack'],
   null,
   30, 'scheduled', null);

-- Action items seed
WITH one_on_ones AS (
  SELECT id, team_member_email FROM public.founder_one_on_ones_r2417
)
INSERT INTO public.one_on_one_action_items_r2417
  (one_on_one_id, action_text, owner_email, priority, due_at, status, closed_at, closed_by_email, notes)
SELECT id, 'Pair SRE-2 with senior on-call for 2 weeks', 'priya.sharma@equipseva.com',
       'high', (now() + interval '7 days')::timestamptz, 'in_progress', null::timestamptz, null::text, 'In progress'::text
FROM one_on_ones WHERE team_member_email = 'priya.sharma@equipseva.com'
UNION ALL
SELECT id, 'Close 2 chain deals by EOW', 'rahul.verma@equipseva.com',
       'urgent', (now() + interval '4 days')::timestamptz, 'open', null::timestamptz, null::text, null::text
FROM one_on_ones WHERE team_member_email = 'rahul.verma@equipseva.com'
UNION ALL
SELECT id, 'Route AMC churn analysis to ops', 'rahul.verma@equipseva.com',
       'medium', now() + interval '10 days', 'done', now() - interval '1 day',
       'rahul.verma@equipseva.com', 'Sent report to vikram.'
FROM one_on_ones WHERE team_member_email = 'rahul.verma@equipseva.com'
UNION ALL
SELECT id, 'Draft NPS recovery plan for top-3 detractors', 'anita.rao@equipseva.com',
       'high', now() + interval '5 days', 'open', null, null, null
FROM one_on_ones WHERE team_member_email = 'anita.rao@equipseva.com'
UNION ALL
SELECT id, 'Reschedule SLO breach review', 'vikram.singh@equipseva.com',
       'low', now() + interval '14 days', 'dropped', now() - interval '2 days',
       'vikram.singh@equipseva.com', 'Folded into ops weekly.'
FROM one_on_ones WHERE team_member_email = 'vikram.singh@equipseva.com';

-- ============================================================
-- RPC: list_one_on_ones_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_one_on_ones_r2417()
RETURNS TABLE (
  id uuid,
  team_member_email text,
  team_member_role text,
  scheduled_at timestamptz,
  held_on timestamptz,
  duration_minutes integer,
  key_topics text[],
  gap_days_since_last integer,
  status text,
  open_actions bigint,
  total_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.team_member_email, o.team_member_role, o.scheduled_at, o.held_on,
         o.duration_minutes, o.key_topics, o.gap_days_since_last, o.status,
         COALESCE(SUM(CASE WHEN a.status IN ('open','in_progress') THEN 1 ELSE 0 END), 0)::bigint AS open_actions,
         COUNT(a.id)::bigint AS total_actions
  FROM public.founder_one_on_ones_r2417 o
  LEFT JOIN public.one_on_one_action_items_r2417 a ON a.one_on_one_id = o.id
  GROUP BY o.id
  ORDER BY o.scheduled_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_one_on_ones_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_one_on_ones_r2417() TO authenticated;

-- ============================================================
-- RPC: overdue_one_on_ones_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.overdue_one_on_ones_r2417()
RETURNS TABLE (
  team_member_email text,
  team_member_role text,
  last_held_on timestamptz,
  days_since_last numeric,
  next_scheduled_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH last_held AS (
    SELECT team_member_email, MAX(held_on) AS last_held_on
    FROM public.founder_one_on_ones_r2417
    WHERE status = 'held'
    GROUP BY team_member_email
  ),
  next_sched AS (
    SELECT DISTINCT ON (team_member_email)
           team_member_email, scheduled_at, status, team_member_role
    FROM public.founder_one_on_ones_r2417
    WHERE status = 'scheduled' AND scheduled_at >= now()
    ORDER BY team_member_email, scheduled_at ASC
  ),
  members AS (
    SELECT DISTINCT team_member_email, team_member_role
    FROM public.founder_one_on_ones_r2417
  )
  SELECT m.team_member_email, m.team_member_role,
         lh.last_held_on,
         ROUND(EXTRACT(EPOCH FROM (now() - lh.last_held_on))/86400.0, 1)::numeric AS days_since_last,
         ns.scheduled_at AS next_scheduled_at,
         COALESCE(ns.status, 'none') AS status
  FROM members m
  LEFT JOIN last_held lh ON lh.team_member_email = m.team_member_email
  LEFT JOIN next_sched ns ON ns.team_member_email = m.team_member_email
  WHERE lh.last_held_on IS NULL
     OR EXTRACT(EPOCH FROM (now() - lh.last_held_on))/86400.0 > 14
  ORDER BY days_since_last DESC NULLS FIRST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.overdue_one_on_ones_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_one_on_ones_r2417() TO authenticated;

-- ============================================================
-- RPC: gap_distribution_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.gap_distribution_r2417()
RETURNS TABLE (
  bucket text,
  count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT bucket, COUNT(*)::bigint
  FROM (
    SELECT CASE
      WHEN gap_days_since_last IS NULL THEN 'unknown'
      WHEN gap_days_since_last <= 7 THEN '0-7 days'
      WHEN gap_days_since_last <= 14 THEN '8-14 days'
      WHEN gap_days_since_last <= 21 THEN '15-21 days'
      ELSE '22+ days'
    END AS bucket
    FROM public.founder_one_on_ones_r2417
    WHERE status = 'held'
  ) sub
  GROUP BY bucket
  ORDER BY bucket;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.gap_distribution_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gap_distribution_r2417() TO authenticated;

-- ============================================================
-- RPC: top_open_actions_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_open_actions_r2417()
RETURNS TABLE (
  id uuid,
  action_text text,
  owner_email text,
  priority text,
  due_at timestamptz,
  days_until_due numeric,
  status text,
  team_member_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.action_text, a.owner_email, a.priority, a.due_at,
         CASE WHEN a.due_at IS NULL THEN NULL
              ELSE ROUND(EXTRACT(EPOCH FROM (a.due_at - now()))/86400.0, 1)::numeric
         END AS days_until_due,
         a.status, o.team_member_email
  FROM public.one_on_one_action_items_r2417 a
  JOIN public.founder_one_on_ones_r2417 o ON o.id = a.one_on_one_id
  WHERE a.status IN ('open','in_progress')
  ORDER BY
    CASE a.priority
      WHEN 'urgent' THEN 1 WHEN 'high' THEN 2
      WHEN 'medium' THEN 3 ELSE 4
    END,
    a.due_at NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_open_actions_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_open_actions_r2417() TO authenticated;

-- ============================================================
-- RPC: action_completion_rate_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.action_completion_rate_r2417()
RETURNS TABLE (
  total_actions bigint,
  done_count bigint,
  open_count bigint,
  in_progress_count bigint,
  dropped_count bigint,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_actions,
    COUNT(*) FILTER (WHERE status='done')::bigint AS done_count,
    COUNT(*) FILTER (WHERE status='open')::bigint AS open_count,
    COUNT(*) FILTER (WHERE status='in_progress')::bigint AS in_progress_count,
    COUNT(*) FILTER (WHERE status='dropped')::bigint AS dropped_count,
    CASE WHEN COUNT(*) = 0 THEN 0::numeric
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status='done')::numeric / COUNT(*)::numeric, 1)
    END AS completion_pct
  FROM public.one_on_one_action_items_r2417;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_completion_rate_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_completion_rate_r2417() TO authenticated;

-- ============================================================
-- RPC: team_member_cadence_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.team_member_cadence_r2417()
RETURNS TABLE (
  team_member_email text,
  team_member_role text,
  total_one_on_ones bigint,
  held_count bigint,
  cancelled_count bigint,
  no_show_count bigint,
  avg_gap_days numeric,
  last_held_on timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.team_member_email,
         MAX(o.team_member_role) AS team_member_role,
         COUNT(*)::bigint AS total_one_on_ones,
         COUNT(*) FILTER (WHERE o.status='held')::bigint AS held_count,
         COUNT(*) FILTER (WHERE o.status='cancelled')::bigint AS cancelled_count,
         COUNT(*) FILTER (WHERE o.status='no_show')::bigint AS no_show_count,
         ROUND(AVG(o.gap_days_since_last)::numeric, 1) AS avg_gap_days,
         MAX(o.held_on) FILTER (WHERE o.status='held') AS last_held_on
  FROM public.founder_one_on_ones_r2417 o
  GROUP BY o.team_member_email
  ORDER BY held_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.team_member_cadence_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.team_member_cadence_r2417() TO authenticated;

-- ============================================================
-- RPC: this_week_schedule_r2417
-- ============================================================
CREATE OR REPLACE FUNCTION public.this_week_schedule_r2417()
RETURNS TABLE (
  id uuid,
  team_member_email text,
  team_member_role text,
  scheduled_at timestamptz,
  days_from_now numeric,
  agenda_md text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.team_member_email, o.team_member_role, o.scheduled_at,
         ROUND(EXTRACT(EPOCH FROM (o.scheduled_at - now()))/86400.0, 1)::numeric AS days_from_now,
         o.agenda_md, o.status
  FROM public.founder_one_on_ones_r2417 o
  WHERE o.scheduled_at >= now() - interval '1 day'
    AND o.scheduled_at <= now() + interval '7 days'
  ORDER BY o.scheduled_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.this_week_schedule_r2417() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_schedule_r2417() TO authenticated;

