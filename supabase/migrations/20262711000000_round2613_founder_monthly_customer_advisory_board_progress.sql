-- r2613 founder monthly customer advisory board progress

CREATE TABLE IF NOT EXISTS public.founder_advisory_board_r2613 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  member_count int NOT NULL DEFAULT 0,
  meeting_held boolean NOT NULL DEFAULT false,
  attendance_count int NOT NULL DEFAULT 0,
  top_insights_md text,
  founder_actions_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','held','cancelled','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.advisory_board_action_log_r2613 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id uuid NOT NULL REFERENCES public.founder_advisory_board_r2613(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('feature_request','policy_change','intro_offer','case_study','escalation')),
  description_md text NOT NULL,
  owner_email text,
  target_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_advisory_board_r2613 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advisory_board_action_log_r2613 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_advisory_board_r2613;
CREATE POLICY founder_all ON public.founder_advisory_board_r2613
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.advisory_board_action_log_r2613;
CREATE POLICY founder_all ON public.advisory_board_action_log_r2613
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed boards
INSERT INTO public.founder_advisory_board_r2613 (month_label, member_count, meeting_held, attendance_count, top_insights_md, founder_actions_md, owner_email, status, notes)
VALUES
  ('2026-02', 8, true, 7, 'Hospitals want predictable AMC budgets and quarterly health reports.', 'Pilot quarterly AMC summary pack for Tier-1 hospitals.', 'founder@equipseva.in', 'closed', 'High signal session.'),
  ('2026-03', 9, true, 6, 'Engineer rotation transparency requested by chain procurement leads.', 'Publish rotation policy doc to chain admins.', 'founder@equipseva.in', 'closed', 'Two new members onboarded.'),
  ('2026-04', 10, true, 9, 'Faster spare-part ETA visibility tops customer wishlist.', 'Wire ETA badge into hospital portal home.', 'founder@equipseva.in', 'closed', 'Best attendance to date.'),
  ('2026-05', 11, true, 8, 'Hospitals open to multi-year AMC if SLA credits clearer.', 'Draft SLA-credit explainer one-pager.', 'founder@equipseva.in', 'held', 'Pending follow-ups.'),
  ('2026-06', 12, false, 0, NULL, NULL, 'founder@equipseva.in', 'planned', 'Scheduled last Friday of month.');

-- Seed action log
WITH b AS (
  SELECT id, month_label FROM public.founder_advisory_board_r2613
)
INSERT INTO public.advisory_board_action_log_r2613 (board_id, action_kind, description_md, owner_email, target_at, status, notes)
SELECT b.id, 'feature_request', 'Add quarterly AMC summary pack download for hospitals.', 'product@equipseva.in', '2026-04-15T00:00:00+05:30'::timestamptz, 'done', 'Shipped r1820.'
FROM b WHERE b.month_label = '2026-02'
UNION ALL
SELECT b.id, 'policy_change', 'Publish engineer rotation policy doc to chain admins.', 'ops@equipseva.in', '2026-05-01T00:00:00+05:30'::timestamptz, 'done', 'Doc live in portal.'
FROM b WHERE b.month_label = '2026-03'
UNION ALL
SELECT b.id, 'feature_request', 'Spare-part ETA badge on hospital portal home.', 'product@equipseva.in', '2026-06-30T00:00:00+05:30'::timestamptz, 'in_progress', 'Backend ready, UI pending.'
FROM b WHERE b.month_label = '2026-04'
UNION ALL
SELECT b.id, 'case_study', 'Draft SLA-credit explainer one-pager for advisory board.', 'marketing@equipseva.in', '2026-07-15T00:00:00+05:30'::timestamptz, 'open', 'Need legal review.'
FROM b WHERE b.month_label = '2026-05'
UNION ALL
SELECT b.id, 'intro_offer', 'Connect Tier-1 chain with diagnostics vertical pilot lead.', 'founder@equipseva.in', '2026-06-20T00:00:00+05:30'::timestamptz, 'open', 'Warm intro queued.'
FROM b WHERE b.month_label = '2026-05';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_boards_r2613()
RETURNS TABLE(
  id uuid,
  month_label text,
  member_count int,
  meeting_held boolean,
  attendance_count int,
  top_insights_md text,
  founder_actions_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.month_label, b.member_count, b.meeting_held, b.attendance_count,
         b.top_insights_md, b.founder_actions_md, b.owner_email, b.status, b.notes, b.created_at
  FROM public.founder_advisory_board_r2613 b
  ORDER BY b.month_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_boards_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_boards_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_action_log_r2613()
RETURNS TABLE(
  id uuid,
  board_id uuid,
  month_label text,
  action_kind text,
  description_md text,
  owner_email text,
  target_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.board_id, b.month_label, a.action_kind, a.description_md, a.owner_email,
         a.target_at, a.status, a.notes, a.created_at
  FROM public.advisory_board_action_log_r2613 a
  JOIN public.founder_advisory_board_r2613 b ON b.id = a.board_id
  ORDER BY a.created_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_action_log_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_log_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_insight_focus_r2613()
RETURNS TABLE(month_label text, focus_summary text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.month_label,
         COALESCE(LEFT(b.top_insights_md, 160), 'No insight captured.') AS focus_summary
  FROM public.founder_advisory_board_r2613 b
  WHERE b.top_insights_md IS NOT NULL
  ORDER BY b.month_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_insight_focus_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_insight_focus_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_rate_summary_r2613()
RETURNS TABLE(month_label text, member_count int, attendance_count int, attendance_rate_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.month_label, b.member_count, b.attendance_count,
         CASE WHEN b.member_count > 0
              THEN ROUND((b.attendance_count::numeric / b.member_count::numeric) * 100, 1)
              ELSE 0 END AS attendance_rate_pct
  FROM public.founder_advisory_board_r2613 b
  WHERE b.meeting_held = true
  ORDER BY b.month_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.attendance_rate_summary_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attendance_rate_summary_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_kind_distribution_r2613()
RETURNS TABLE(action_kind text, total bigint, open_count bigint, done_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS open_count,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_count
  FROM public.advisory_board_action_log_r2613 a
  GROUP BY a.action_kind
  ORDER BY total DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.action_kind_distribution_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_distribution_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_board_trend_r2613()
RETURNS TABLE(month_label text, member_count int, attendance_count int, meeting_held boolean, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.month_label, b.member_count, b.attendance_count, b.meeting_held, b.status
  FROM public.founder_advisory_board_r2613 b
  ORDER BY b.month_label ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.monthly_board_trend_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_board_trend_r2613() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2613()
RETURNS TABLE(owner_email text, open_actions bigint, in_progress_actions bigint, done_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, 'unassigned') AS owner_email,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS open_actions,
         COUNT(*) FILTER (WHERE a.status = 'in_progress')::bigint AS in_progress_actions,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_actions
  FROM public.advisory_board_action_log_r2613 a
  GROUP BY COALESCE(a.owner_email, 'unassigned')
  ORDER BY open_actions DESC, in_progress_actions DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2613() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2613() TO authenticated;
