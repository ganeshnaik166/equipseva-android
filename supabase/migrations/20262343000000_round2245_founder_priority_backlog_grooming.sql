BEGIN;

-- Round 2245: Founder priority backlog grooming
-- Incoming founder-only requests/ideas, prioritize, assign or defer, completion log

CREATE TABLE IF NOT EXISTS public.founder_backlog_items_r2245 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  source text NOT NULL DEFAULT 'founder_note' CHECK (source IN ('founder_note','engineer_field','hospital_request','investor_ask','partner_request','audit_finding','data_signal','customer_voice')),
  category text NOT NULL DEFAULT 'product' CHECK (category IN ('product','ops','growth','finance','compliance','platform','people','partnerships')),
  ice_impact int NOT NULL DEFAULT 5 CHECK (ice_impact BETWEEN 1 AND 10),
  ice_confidence int NOT NULL DEFAULT 5 CHECK (ice_confidence BETWEEN 1 AND 10),
  ice_ease int NOT NULL DEFAULT 5 CHECK (ice_ease BETWEEN 1 AND 10),
  ice_score numeric GENERATED ALWAYS AS ((ice_impact::numeric * ice_confidence::numeric * ice_ease::numeric) / 10.0) STORED,
  priority text NOT NULL DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  status text NOT NULL DEFAULT 'inbox' CHECK (status IN ('inbox','triaged','assigned','in_progress','deferred','done','dropped')),
  assignee_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  defer_until date,
  effort_days numeric,
  expected_value_rupees numeric,
  groomed_at timestamptz,
  groomed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  completed_at timestamptz,
  outcome_note text,
  raised_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbi_r2245_status ON public.founder_backlog_items_r2245(status);
CREATE INDEX IF NOT EXISTS idx_fbi_r2245_priority ON public.founder_backlog_items_r2245(priority);
CREATE INDEX IF NOT EXISTS idx_fbi_r2245_score ON public.founder_backlog_items_r2245(ice_score DESC);
CREATE INDEX IF NOT EXISTS idx_fbi_r2245_assignee ON public.founder_backlog_items_r2245(assignee_user_id);

CREATE TABLE IF NOT EXISTS public.founder_backlog_events_r2245 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.founder_backlog_items_r2245(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','re_scored','re_prioritized','assigned','reassigned','deferred','status_changed','commented','completed','dropped')),
  old_value text,
  new_value text,
  note text,
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbe_r2245_item ON public.founder_backlog_events_r2245(item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fbe_r2245_type ON public.founder_backlog_events_r2245(event_type);

ALTER TABLE public.founder_backlog_items_r2245 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_backlog_events_r2245 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fbi_r2245 ON public.founder_backlog_items_r2245;
CREATE POLICY founder_all_fbi_r2245 ON public.founder_backlog_items_r2245
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fbe_r2245 ON public.founder_backlog_events_r2245;
CREATE POLICY founder_all_fbe_r2245 ON public.founder_backlog_events_r2245
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed sample items for the founder's own backlog
INSERT INTO public.founder_backlog_items_r2245 (title, description, source, category, ice_impact, ice_confidence, ice_ease, priority, status, raised_by_email)
SELECT * FROM (VALUES
  ('AMC tier upgrade nudge in app','Auto-prompt Standard customers to upgrade after 3 successful tickets','data_signal','product',8,7,6,'p1','triaged','founder@equipseva.com'),
  ('Engineer payout SLA dashboard','Show median + p95 payout-cycle hours by region for finance ops','founder_note','finance',7,8,7,'p1','inbox','founder@equipseva.com'),
  ('Hospital chain consolidated invoice','Single PDF + GST across all branches of a chain monthly','hospital_request','finance',9,6,4,'p1','assigned','procurement@yashoda.in'),
  ('CDSCO compliance pre-flight checklist','Block parts orders without bonded-warehouse provenance','audit_finding','compliance',9,9,6,'p0','in_progress','founder@equipseva.com'),
  ('Engineer leaderboard public link','Marketing wants public top-10 page','partner_request','growth',5,6,7,'p3','deferred','marketing@equipseva.com'),
  ('Investor SAFE drawdown calendar','Show projected SAFE conversions vs cash runway','investor_ask','finance',7,7,5,'p2','triaged','arjun@accel.in'),
  ('Telugu i18n review pass','Native speaker audit of all engineer-app strings','customer_voice','product',6,8,5,'p2','inbox','engineer@equipseva.com'),
  ('Spare-part bonded warehouse expansion HYD','Open second bonded warehouse near HITEC city','partner_request','ops',8,5,3,'p2','deferred','ops@equipseva.com'),
  ('Cashfree Payouts batch reconciliation','Daily auto-match payout webhooks vs CF batch reports','data_signal','platform',7,8,6,'p1','in_progress','founder@equipseva.com'),
  ('Founder weekly board pack auto-render','One-click PDF from current week numbers','founder_note','platform',7,9,7,'p1','done','founder@equipseva.com')
) v(title, description, source, category, ice_impact, ice_confidence, ice_ease, priority, status, raised_by_email)
WHERE NOT EXISTS (SELECT 1 FROM public.founder_backlog_items_r2245);

-- RPC 1: Summary
CREATE OR REPLACE FUNCTION public.fbg_summary_r2245()
RETURNS TABLE(
  inbox_count int,
  triaged_count int,
  in_progress_count int,
  deferred_count int,
  done_count int,
  p0_open int,
  p1_open int,
  avg_ice_open numeric,
  high_ice_open int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'inbox'))::int,
    (COUNT(*) FILTER (WHERE status = 'triaged'))::int,
    (COUNT(*) FILTER (WHERE status = 'in_progress'))::int,
    (COUNT(*) FILTER (WHERE status = 'deferred'))::int,
    (COUNT(*) FILTER (WHERE status = 'done'))::int,
    (COUNT(*) FILTER (WHERE priority = 'p0' AND status NOT IN ('done','dropped')))::int,
    (COUNT(*) FILTER (WHERE priority = 'p1' AND status NOT IN ('done','dropped')))::int,
    COALESCE(ROUND(AVG(ice_score) FILTER (WHERE status NOT IN ('done','dropped')), 2), 0)::numeric,
    (COUNT(*) FILTER (WHERE ice_score >= 5.0 AND status NOT IN ('done','dropped')))::int
  FROM public.founder_backlog_items_r2245;
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_summary_r2245() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_summary_r2245() TO authenticated;

-- RPC 2: Inbox top
CREATE OR REPLACE FUNCTION public.fbg_inbox_top_r2245(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  title text,
  source text,
  category text,
  priority text,
  ice_score numeric,
  raised_by_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.title, b.source, b.category, b.priority, b.ice_score, b.raised_by_email, b.created_at
  FROM public.founder_backlog_items_r2245 b
  WHERE b.status = 'inbox'
  ORDER BY b.ice_score DESC, b.created_at ASC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_inbox_top_r2245(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_inbox_top_r2245(int) TO authenticated;

-- RPC 3: Active queue (assigned/in_progress)
CREATE OR REPLACE FUNCTION public.fbg_active_r2245()
RETURNS TABLE(
  id uuid,
  title text,
  priority text,
  status text,
  ice_score numeric,
  assignee_email text,
  effort_days numeric,
  expected_value_rupees numeric,
  groomed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.title, b.priority, b.status, b.ice_score,
         p.email, b.effort_days, b.expected_value_rupees, b.groomed_at
  FROM public.founder_backlog_items_r2245 b
  LEFT JOIN public.profiles p ON p.id = b.assignee_user_id
  WHERE b.status IN ('assigned','in_progress')
  ORDER BY
    CASE b.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    b.ice_score DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_active_r2245() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_active_r2245() TO authenticated;

-- RPC 4: Deferred items due to re-review
CREATE OR REPLACE FUNCTION public.fbg_deferred_due_r2245()
RETURNS TABLE(
  id uuid,
  title text,
  priority text,
  ice_score numeric,
  defer_until date,
  days_overdue int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.title, b.priority, b.ice_score, b.defer_until,
         GREATEST(0, (CURRENT_DATE - b.defer_until))::int
  FROM public.founder_backlog_items_r2245 b
  WHERE b.status = 'deferred'
  ORDER BY b.defer_until ASC NULLS LAST, b.ice_score DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_deferred_due_r2245() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_deferred_due_r2245() TO authenticated;

-- RPC 5: Category breakdown
CREATE OR REPLACE FUNCTION public.fbg_category_breakdown_r2245()
RETURNS TABLE(
  category text,
  open_count int,
  done_count int,
  avg_ice numeric,
  top_priority text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.category,
    (COUNT(*) FILTER (WHERE b.status NOT IN ('done','dropped')))::int,
    (COUNT(*) FILTER (WHERE b.status = 'done'))::int,
    COALESCE(ROUND(AVG(b.ice_score) FILTER (WHERE b.status NOT IN ('done','dropped')), 2), 0)::numeric,
    (
      SELECT b2.priority FROM public.founder_backlog_items_r2245 b2
      WHERE b2.category = b.category AND b2.status NOT IN ('done','dropped')
      ORDER BY CASE b2.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END
      LIMIT 1
    )
  FROM public.founder_backlog_items_r2245 b
  GROUP BY b.category
  ORDER BY (COUNT(*) FILTER (WHERE b.status NOT IN ('done','dropped')))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_category_breakdown_r2245() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_category_breakdown_r2245() TO authenticated;

-- RPC 6: Recent completion log
CREATE OR REPLACE FUNCTION public.fbg_completion_log_r2245(p_days int DEFAULT 30)
RETURNS TABLE(
  id uuid,
  title text,
  category text,
  priority text,
  ice_score numeric,
  outcome_note text,
  completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.title, b.category, b.priority, b.ice_score, b.outcome_note, b.completed_at
  FROM public.founder_backlog_items_r2245 b
  WHERE b.status = 'done'
    AND (b.completed_at IS NULL OR b.completed_at >= now() - make_interval(days => GREATEST(1, COALESCE(p_days, 30))))
  ORDER BY b.completed_at DESC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_completion_log_r2245(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_completion_log_r2245(int) TO authenticated;

-- RPC 7: Recent events trail
CREATE OR REPLACE FUNCTION public.fbg_events_recent_r2245(p_limit int DEFAULT 40)
RETURNS TABLE(
  id uuid,
  item_title text,
  event_type text,
  old_value text,
  new_value text,
  note text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, b.title, e.event_type, e.old_value, e.new_value, e.note, p.email, e.created_at
  FROM public.founder_backlog_events_r2245 e
  JOIN public.founder_backlog_items_r2245 b ON b.id = e.item_id
  LEFT JOIN public.profiles p ON p.id = e.actor_user_id
  ORDER BY e.created_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 40));
END;
$$;

REVOKE ALL ON FUNCTION public.fbg_events_recent_r2245(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fbg_events_recent_r2245(int) TO authenticated;

COMMIT;
