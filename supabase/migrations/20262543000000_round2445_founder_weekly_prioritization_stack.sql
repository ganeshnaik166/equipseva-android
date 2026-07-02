-- Round 2445: Founder Weekly Prioritization Stack
-- Top 5 priorities x started/done/blocked x ROI estimate x effort x done in week

CREATE TABLE IF NOT EXISTS public.founder_weekly_priorities_r2445 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  rank int NOT NULL CHECK (rank BETWEEN 1 AND 5),
  title text NOT NULL,
  hypothesis_md text NOT NULL,
  estimated_roi_rupees bigint NOT NULL DEFAULT 0 CHECK (estimated_roi_rupees >= 0),
  effort_hours int NOT NULL DEFAULT 0 CHECK (effort_hours >= 0),
  status text NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started','in_progress','blocked','done','dropped')),
  blocker_notes text,
  completed_at timestamptz,
  learnings_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_start, rank)
);

CREATE INDEX IF NOT EXISTS idx_fwp_r2445_week ON public.founder_weekly_priorities_r2445(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fwp_r2445_status ON public.founder_weekly_priorities_r2445(status);

CREATE TABLE IF NOT EXISTS public.founder_weekly_review_r2445 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  started_count int NOT NULL DEFAULT 0 CHECK (started_count >= 0),
  done_count int NOT NULL DEFAULT 0 CHECK (done_count >= 0),
  blocked_count int NOT NULL DEFAULT 0 CHECK (blocked_count >= 0),
  dropped_count int NOT NULL DEFAULT 0 CHECK (dropped_count >= 0),
  total_roi_realized_rupees bigint NOT NULL DEFAULT 0 CHECK (total_roi_realized_rupees >= 0),
  total_hours_spent int NOT NULL DEFAULT 0 CHECK (total_hours_spent >= 0),
  review_summary_md text NOT NULL,
  top_win text,
  top_miss text,
  next_week_focus_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwr_r2445_week ON public.founder_weekly_review_r2445(week_start DESC);

ALTER TABLE public.founder_weekly_priorities_r2445 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_weekly_review_r2445 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_weekly_priorities_r2445;
CREATE POLICY founder_all ON public.founder_weekly_priorities_r2445
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_weekly_review_r2445;
CREATE POLICY founder_all ON public.founder_weekly_review_r2445
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.founder_weekly_priorities_r2445
  (week_start, rank, title, hypothesis_md, estimated_roi_rupees, effort_hours, status, blocker_notes, completed_at, learnings_md, notes)
VALUES
  ('2026-06-15'::date, 1, 'Ship hospital-chain bulk-renew flow', 'Bulk renew unlocks 8 contracts in queue worth ~Rs 12L ARR', 1200000, 18, 'done', NULL, '2026-06-19T17:00:00+05:30'::timestamptz, 'Bulk flow shipped, 6 of 8 chains renewed same week', 'Top ROI win this week'),
  ('2026-06-15'::date, 2, 'Close Cashfree KYC re-submission', 'KYC unblocks payouts to 22 engineers (~Rs 3.4L queued)', 340000, 6, 'blocked', 'Waiting on Udyam cert PDF review by Cashfree compliance', NULL, NULL, 'External dependency'),
  ('2026-06-15'::date, 3, 'Engineer night-shift fairness v1', 'Reduce night-shift refusals by 40 percent via rotation', 80000, 12, 'in_progress', NULL, NULL, NULL, 'Rolled to next week'),
  ('2026-06-15'::date, 4, 'Founder weekly board pack auto-gen', 'Save 4 hours per week of manual deck assembly', 50000, 8, 'done', NULL, '2026-06-20T11:00:00+05:30'::timestamptz, 'Auto-pack works, screenshot mode pending', 'Quick win'),
  ('2026-06-15'::date, 5, 'Spare-parts JIT watch dashboard', 'Avoid stockouts on top-50 SKUs across 14 hospitals', 220000, 14, 'in_progress', NULL, NULL, NULL, 'Migration shipped, page in QA'),
  ('2026-06-08'::date, 1, 'GST filing pipeline H1 close', 'Close FY26 H1 GST without late fees', 75000, 20, 'done', NULL, '2026-06-13T19:30:00+05:30'::timestamptz, 'Pipeline shipped, GSTR-1 + GSTR-3B auto-export live', 'Compliance unlocked'),
  ('2026-06-08'::date, 2, 'AMC churn early-warning model v1', 'Catch 70 percent of churners 30 days before renewal', 450000, 16, 'done', NULL, '2026-06-14T15:00:00+05:30'::timestamptz, 'Model live, flagged 11 of 14 churners in test set', NULL),
  ('2026-06-08'::date, 3, 'Founder priority-actions write layer', 'Make priority list editable from console (was read-only)', 30000, 4, 'done', NULL, '2026-06-09T10:00:00+05:30'::timestamptz, 'Wrote in 4 hours, used same day', 'Shipped Phase 5 of v0.5 six weeks early'),
  ('2026-06-08'::date, 4, 'Public investor share v2', 'Token-gated investor portal with live KPIs', 0, 10, 'done', NULL, '2026-06-10T14:00:00+05:30'::timestamptz, 'Live, 3 investors clicked through', 'Phase 6 v0.5 shipped 8 weeks early'),
  ('2026-06-08'::date, 5, 'Tier-1 home redesign', 'Improve engineer Tier-1 home conversion to job-accept', 0, 6, 'dropped', NULL, NULL, 'Conversion already at 91 percent, no headroom', 'Killed Wed after data review');

INSERT INTO public.founder_weekly_review_r2445
  (week_start, started_count, done_count, blocked_count, dropped_count, total_roi_realized_rupees, total_hours_spent, review_summary_md, top_win, top_miss, next_week_focus_md, notes)
VALUES
  ('2026-06-15'::date, 5, 2, 1, 0, 1250000, 32, 'Shipped 2 of 5 priorities. Bulk-renew flow was the unlock, brought in Rs 12L ARR. Cashfree KYC still blocked.', 'Hospital-chain bulk-renew shipped, 6 of 8 chains renewed same week', 'Cashfree KYC re-submission still blocked on external compliance', '1. Close night-shift fairness v1\n2. Spare-parts JIT dashboard QA\n3. Spin up engineer innovation submissions intake', 'High-velocity week, ROI realized Rs 12.5L'),
  ('2026-06-08'::date, 5, 4, 0, 1, 555000, 56, 'Shipped 4 of 5 priorities. Dropped Tier-1 home redesign after data review (no headroom). Phase 5 + Phase 6 of v0.5 landed 6-8 weeks ahead.', 'Phase 5 + Phase 6 of v0.5 both shipped same week', 'Spent 6 hours on Tier-1 redesign before killing - should have validated data first', '1. Bulk-renew flow for hospital chains\n2. Cashfree KYC re-submission\n3. Founder board-pack auto-gen', 'Best velocity week of v0.5 so far');

-- RPC 1: list_priorities_r2445
CREATE OR REPLACE FUNCTION public.list_priorities_r2445()
RETURNS TABLE (
  id uuid,
  week_start date,
  rank int,
  title text,
  hypothesis_md text,
  estimated_roi_rupees bigint,
  effort_hours int,
  status text,
  blocker_notes text,
  completed_at timestamptz,
  learnings_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.week_start, p.rank, p.title, p.hypothesis_md, p.estimated_roi_rupees,
         p.effort_hours, p.status, p.blocker_notes, p.completed_at, p.learnings_md, p.notes
  FROM public.founder_weekly_priorities_r2445 p
  ORDER BY p.week_start DESC, p.rank ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_priorities_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_priorities_r2445() TO authenticated;

-- RPC 2: list_reviews_r2445
CREATE OR REPLACE FUNCTION public.list_reviews_r2445()
RETURNS TABLE (
  id uuid,
  week_start date,
  started_count int,
  done_count int,
  blocked_count int,
  dropped_count int,
  total_roi_realized_rupees bigint,
  total_hours_spent int,
  review_summary_md text,
  top_win text,
  top_miss text,
  next_week_focus_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.week_start, r.started_count, r.done_count, r.blocked_count, r.dropped_count,
         r.total_roi_realized_rupees, r.total_hours_spent, r.review_summary_md, r.top_win,
         r.top_miss, r.next_week_focus_md, r.notes
  FROM public.founder_weekly_review_r2445 r
  ORDER BY r.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews_r2445() TO authenticated;

-- RPC 3: current_week_focus_r2445
CREATE OR REPLACE FUNCTION public.current_week_focus_r2445()
RETURNS TABLE (
  week_start date,
  rank int,
  title text,
  status text,
  estimated_roi_rupees bigint,
  effort_hours int,
  blocker_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_latest date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT max(p.week_start) INTO v_latest FROM public.founder_weekly_priorities_r2445 p;
  RETURN QUERY
  SELECT p.week_start, p.rank, p.title, p.status, p.estimated_roi_rupees, p.effort_hours, p.blocker_notes
  FROM public.founder_weekly_priorities_r2445 p
  WHERE p.week_start = v_latest
  ORDER BY p.rank ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.current_week_focus_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_week_focus_r2445() TO authenticated;

-- RPC 4: weekly_completion_rate_r2445
CREATE OR REPLACE FUNCTION public.weekly_completion_rate_r2445()
RETURNS TABLE (
  week_start date,
  total_priorities bigint,
  done_count bigint,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start,
         count(*)::bigint AS total_priorities,
         count(*) FILTER (WHERE p.status = 'done')::bigint AS done_count,
         ROUND(100.0 * count(*) FILTER (WHERE p.status = 'done') / NULLIF(count(*),0), 1) AS completion_pct
  FROM public.founder_weekly_priorities_r2445 p
  GROUP BY p.week_start
  ORDER BY p.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_completion_rate_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_completion_rate_r2445() TO authenticated;

-- RPC 5: top_roi_completed_r2445
CREATE OR REPLACE FUNCTION public.top_roi_completed_r2445()
RETURNS TABLE (
  week_start date,
  rank int,
  title text,
  estimated_roi_rupees bigint,
  effort_hours int,
  completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start, p.rank, p.title, p.estimated_roi_rupees, p.effort_hours, p.completed_at
  FROM public.founder_weekly_priorities_r2445 p
  WHERE p.status = 'done'
  ORDER BY p.estimated_roi_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_roi_completed_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_completed_r2445() TO authenticated;

-- RPC 6: blocked_focus_r2445
CREATE OR REPLACE FUNCTION public.blocked_focus_r2445()
RETURNS TABLE (
  week_start date,
  rank int,
  title text,
  estimated_roi_rupees bigint,
  blocker_notes text,
  days_blocked int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start, p.rank, p.title, p.estimated_roi_rupees, p.blocker_notes,
         (CURRENT_DATE - p.week_start)::int AS days_blocked
  FROM public.founder_weekly_priorities_r2445 p
  WHERE p.status = 'blocked'
  ORDER BY p.estimated_roi_rupees DESC, p.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.blocked_focus_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocked_focus_r2445() TO authenticated;

-- RPC 7: monthly_review_pulse_r2445
CREATE OR REPLACE FUNCTION public.monthly_review_pulse_r2445()
RETURNS TABLE (
  month_start date,
  weeks_count bigint,
  total_started bigint,
  total_done bigint,
  total_blocked bigint,
  total_dropped bigint,
  total_roi_realized_rupees numeric,
  total_hours_spent numeric,
  avg_completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', r.week_start)::date AS month_start,
         count(*)::bigint AS weeks_count,
         sum(r.started_count)::bigint AS total_started,
         sum(r.done_count)::bigint AS total_done,
         sum(r.blocked_count)::bigint AS total_blocked,
         sum(r.dropped_count)::bigint AS total_dropped,
         sum(r.total_roi_realized_rupees)::numeric AS total_roi_realized_rupees,
         sum(r.total_hours_spent)::numeric AS total_hours_spent,
         ROUND(AVG(100.0 * r.done_count / NULLIF(r.started_count,0)), 1) AS avg_completion_pct
  FROM public.founder_weekly_review_r2445 r
  GROUP BY date_trunc('month', r.week_start)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_review_pulse_r2445() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_review_pulse_r2445() TO authenticated;
