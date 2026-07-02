-- Round 2557: founder-monthly-cofounder-1on1-quality
-- Cofounder × 1:1 × agenda quality × decisions × alignment × tension flags

BEGIN;

-- ============================================================
-- Table 1: founder_cofounder_1on1s_r2557
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_cofounder_1on1s_r2557 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cofounder_name text NOT NULL,
  month_label text NOT NULL,
  held_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 60,
  agenda_quality_score int NOT NULL DEFAULT 0 CHECK (agenda_quality_score BETWEEN 0 AND 100),
  decisions_made_count int NOT NULL DEFAULT 0,
  alignment_score int NOT NULL DEFAULT 0 CHECK (alignment_score BETWEEN 0 AND 100),
  tension_flags_md text,
  action_items_count int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','done','cancelled','rescheduled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_cofounder_1on1s_r2557 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_cofounder_1on1s_r2557;
CREATE POLICY founder_all ON public.founder_cofounder_1on1s_r2557
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_cof_1on1s_r2557_held_at ON public.founder_cofounder_1on1s_r2557(held_at DESC);
CREATE INDEX IF NOT EXISTS idx_cof_1on1s_r2557_cofounder ON public.founder_cofounder_1on1s_r2557(cofounder_name);
CREATE INDEX IF NOT EXISTS idx_cof_1on1s_r2557_month ON public.founder_cofounder_1on1s_r2557(month_label);

-- ============================================================
-- Table 2: cofounder_action_items_r2557
-- ============================================================
CREATE TABLE IF NOT EXISTS public.cofounder_action_items_r2557 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.founder_cofounder_1on1s_r2557(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cofounder_action_items_r2557 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.cofounder_action_items_r2557;
CREATE POLICY founder_all ON public.cofounder_action_items_r2557
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_cof_ai_r2557_meeting ON public.cofounder_action_items_r2557(meeting_id);
CREATE INDEX IF NOT EXISTS idx_cof_ai_r2557_status ON public.cofounder_action_items_r2557(status);
CREATE INDEX IF NOT EXISTS idx_cof_ai_r2557_owner ON public.cofounder_action_items_r2557(owner_email);

-- ============================================================
-- Seed data: 4 meetings, 6 action items
-- ============================================================
DO $seed$
DECLARE
  m1 uuid;
  m2 uuid;
  m3 uuid;
  m4 uuid;
BEGIN
  INSERT INTO public.founder_cofounder_1on1s_r2557
    (cofounder_name, month_label, held_at, duration_minutes, agenda_quality_score, decisions_made_count,
     alignment_score, tension_flags_md, action_items_count, owner_email, status, notes)
  VALUES ('Priya R.', '2026-04', '2026-04-12T10:00:00Z'::timestamptz, 75, 82, 4, 88,
          '- Hiring pace vs runway tension', 2, 'priya@equipseva.in', 'done',
          'Strong agenda, decisions on hiring pace landed clean.')
  RETURNING id INTO m1;

  INSERT INTO public.founder_cofounder_1on1s_r2557
    (cofounder_name, month_label, held_at, duration_minutes, agenda_quality_score, decisions_made_count,
     alignment_score, tension_flags_md, action_items_count, owner_email, status, notes)
  VALUES ('Priya R.', '2026-05', '2026-05-10T10:00:00Z'::timestamptz, 60, 70, 2, 72,
          '- Engineering vs ops priority pull', 2, 'priya@equipseva.in', 'done',
          'Agenda thin; some alignment drift on roadmap order.')
  RETURNING id INTO m2;

  INSERT INTO public.founder_cofounder_1on1s_r2557
    (cofounder_name, month_label, held_at, duration_minutes, agenda_quality_score, decisions_made_count,
     alignment_score, tension_flags_md, action_items_count, owner_email, status, notes)
  VALUES ('Arjun K.', '2026-05', '2026-05-18T11:00:00Z'::timestamptz, 90, 91, 5, 94,
          NULL, 1, 'arjun@equipseva.in', 'done',
          'Excellent prep, alignment high on Tier-1 expansion.')
  RETURNING id INTO m3;

  INSERT INTO public.founder_cofounder_1on1s_r2557
    (cofounder_name, month_label, held_at, duration_minutes, agenda_quality_score, decisions_made_count,
     alignment_score, tension_flags_md, action_items_count, owner_email, status, notes)
  VALUES ('Arjun K.', '2026-06', '2026-06-15T11:00:00Z'::timestamptz, 60, 85, 3, 80,
          '- Equity refresh discussion deferred again', 1, 'arjun@equipseva.in', 'done',
          'Equity topic keeps slipping; needs dedicated session.')
  RETURNING id INTO m4;

  INSERT INTO public.cofounder_action_items_r2557
    (meeting_id, action_text, owner_email, due_at, status, outcome, closed_at, notes)
  VALUES
    (m1, 'Draft hiring plan with runway model', 'priya@equipseva.in', '2026-04-26T00:00:00Z'::timestamptz, 'done', 'positive', '2026-04-24T00:00:00Z'::timestamptz, 'Shared in shared drive'),
    (m1, 'Lock Q2 OKRs with leads', 'ganesh@equipseva.in', '2026-04-30T00:00:00Z'::timestamptz, 'done', 'positive', '2026-04-29T00:00:00Z'::timestamptz, 'OKRs published'),
    (m2, 'Reconcile roadmap with eng lead', 'priya@equipseva.in', '2026-05-24T00:00:00Z'::timestamptz, 'in_progress', 'neutral', NULL, 'Slow progress'),
    (m2, 'Founder sync cadence review', 'ganesh@equipseva.in', '2026-05-31T00:00:00Z'::timestamptz, 'done', 'neutral', '2026-05-30T00:00:00Z'::timestamptz, 'Agreed on weekly 15-min'),
    (m3, 'Tier-1 chain pilot scoping doc', 'arjun@equipseva.in', '2026-06-01T00:00:00Z'::timestamptz, 'done', 'positive', '2026-05-30T00:00:00Z'::timestamptz, 'Doc circulated'),
    (m4, 'Schedule equity refresh deep-dive', 'ganesh@equipseva.in', '2026-06-30T00:00:00Z'::timestamptz, 'open', 'pending', NULL, 'Still pending');
END
$seed$;

-- ============================================================
-- RPC 1: list_meetings_r2557
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_meetings_r2557()
RETURNS TABLE (
  id uuid,
  cofounder_name text,
  month_label text,
  held_at timestamptz,
  duration_minutes int,
  agenda_quality_score int,
  decisions_made_count int,
  alignment_score int,
  action_items_count int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.cofounder_name, m.month_label, m.held_at, m.duration_minutes,
         m.agenda_quality_score, m.decisions_made_count, m.alignment_score,
         m.action_items_count, m.owner_email, m.status, m.notes
  FROM public.founder_cofounder_1on1s_r2557 m
  ORDER BY m.held_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meetings_r2557() TO authenticated;

-- ============================================================
-- RPC 2: list_action_items_r2557
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_action_items_r2557()
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  cofounder_name text,
  action_text text,
  owner_email text,
  due_at timestamptz,
  status text,
  outcome text,
  closed_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.meeting_id, m.cofounder_name, a.action_text, a.owner_email,
         a.due_at, a.status, a.outcome, a.closed_at, a.notes
  FROM public.cofounder_action_items_r2557 a
  JOIN public.founder_cofounder_1on1s_r2557 m ON m.id = a.meeting_id
  ORDER BY a.due_at ASC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_items_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_items_r2557() TO authenticated;

-- ============================================================
-- RPC 3: tension_focus_r2557
-- Meetings with tension flags raised
-- ============================================================
CREATE OR REPLACE FUNCTION public.tension_focus_r2557()
RETURNS TABLE (
  cofounder_name text,
  month_label text,
  held_at timestamptz,
  alignment_score int,
  tension_flags_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.cofounder_name, m.month_label, m.held_at, m.alignment_score, m.tension_flags_md
  FROM public.founder_cofounder_1on1s_r2557 m
  WHERE m.tension_flags_md IS NOT NULL AND length(trim(m.tension_flags_md)) > 0
  ORDER BY m.held_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.tension_focus_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tension_focus_r2557() TO authenticated;

-- ============================================================
-- RPC 4: alignment_trend_r2557
-- Per cofounder × month alignment trend
-- ============================================================
CREATE OR REPLACE FUNCTION public.alignment_trend_r2557()
RETURNS TABLE (
  cofounder_name text,
  month_label text,
  meetings_count bigint,
  avg_alignment numeric,
  avg_agenda_quality numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.cofounder_name, m.month_label,
         count(*)::bigint,
         round(avg(m.alignment_score)::numeric, 1),
         round(avg(m.agenda_quality_score)::numeric, 1)
  FROM public.founder_cofounder_1on1s_r2557 m
  WHERE m.status = 'done'
  GROUP BY m.cofounder_name, m.month_label
  ORDER BY m.cofounder_name ASC NULLS LAST, m.month_label ASC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.alignment_trend_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.alignment_trend_r2557() TO authenticated;

-- ============================================================
-- RPC 5: action_completion_rate_r2557
-- Per cofounder action item completion rate
-- ============================================================
CREATE OR REPLACE FUNCTION public.action_completion_rate_r2557()
RETURNS TABLE (
  cofounder_name text,
  total_actions bigint,
  done_count bigint,
  open_count bigint,
  in_progress_count bigint,
  dropped_count bigint,
  completion_rate_pct numeric,
  positive_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.cofounder_name,
         count(*)::bigint,
         count(*) FILTER (WHERE a.status = 'done')::bigint,
         count(*) FILTER (WHERE a.status = 'open')::bigint,
         count(*) FILTER (WHERE a.status = 'in_progress')::bigint,
         count(*) FILTER (WHERE a.status = 'dropped')::bigint,
         CASE WHEN count(*) > 0
              THEN round((count(*) FILTER (WHERE a.status = 'done')::numeric * 100.0) / count(*)::numeric, 1)
              ELSE 0 END,
         count(*) FILTER (WHERE a.outcome = 'positive')::bigint
  FROM public.cofounder_action_items_r2557 a
  JOIN public.founder_cofounder_1on1s_r2557 m ON m.id = a.meeting_id
  GROUP BY m.cofounder_name
  ORDER BY m.cofounder_name ASC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.action_completion_rate_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_completion_rate_r2557() TO authenticated;

-- ============================================================
-- RPC 6: monthly_quality_summary_r2557
-- Roll-up by month across all cofounders
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_quality_summary_r2557()
RETURNS TABLE (
  month_label text,
  meetings_count bigint,
  avg_agenda_quality numeric,
  avg_alignment numeric,
  total_decisions bigint,
  total_action_items bigint,
  tension_flag_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.month_label,
         count(*)::bigint,
         round(avg(m.agenda_quality_score)::numeric, 1),
         round(avg(m.alignment_score)::numeric, 1),
         coalesce(sum(m.decisions_made_count), 0)::bigint,
         coalesce(sum(m.action_items_count), 0)::bigint,
         count(*) FILTER (WHERE m.tension_flags_md IS NOT NULL AND length(trim(m.tension_flags_md)) > 0)::bigint
  FROM public.founder_cofounder_1on1s_r2557 m
  WHERE m.status = 'done'
  GROUP BY m.month_label
  ORDER BY m.month_label DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_quality_summary_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_quality_summary_r2557() TO authenticated;

-- ============================================================
-- RPC 7: owner_load_r2557
-- Action-item load per owner
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2557()
RETURNS TABLE (
  owner_email text,
  total_actions bigint,
  open_actions bigint,
  in_progress_actions bigint,
  done_actions bigint,
  overdue_open bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.owner_email,
         count(*)::bigint,
         count(*) FILTER (WHERE a.status = 'open')::bigint,
         count(*) FILTER (WHERE a.status = 'in_progress')::bigint,
         count(*) FILTER (WHERE a.status = 'done')::bigint,
         count(*) FILTER (WHERE a.status IN ('open','in_progress') AND a.due_at < now())::bigint
  FROM public.cofounder_action_items_r2557 a
  WHERE a.owner_email IS NOT NULL
  GROUP BY a.owner_email
  ORDER BY count(*) FILTER (WHERE a.status IN ('open','in_progress'))::bigint DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2557() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2557() TO authenticated;

