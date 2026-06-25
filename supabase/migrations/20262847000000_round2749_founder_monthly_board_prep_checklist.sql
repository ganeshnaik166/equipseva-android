BEGIN;

-- ============================================================================
-- Round 2749 — Founder Monthly Board Prep Checklist
-- Tracks board prep items with owner, status, evidence, dependency, completion
-- ============================================================================

-- Drop policies only if tables exist (safety)
DROP TABLE IF EXISTS public.board_prep_checklist_items_r2749 CASCADE;
DROP TABLE IF EXISTS public.board_prep_checklist_evidence_r2749 CASCADE;

-- ----------------------------------------------------------------------------
-- Table 1: board_prep_checklist_items_r2749
-- ----------------------------------------------------------------------------
CREATE TABLE public.board_prep_checklist_items_r2749 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  board_month     date NOT NULL,
  item_code       text NOT NULL,
  item_title      text NOT NULL,
  category        text NOT NULL CHECK (category IN ('financials','metrics','strategy','governance','risk','people','product')),
  owner_role      text NOT NULL CHECK (owner_role IN ('founder','cfo','coo','cto','vp_sales','board_secretary','external_auditor')),
  status          text NOT NULL CHECK (status IN ('not_started','in_progress','blocked','submitted','approved','board_ready')),
  priority        text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  due_date        date NOT NULL,
  completed_at    timestamptz,
  completion_pct  int  NOT NULL DEFAULT 0 CHECK (completion_pct BETWEEN 0 AND 100),
  depends_on_code text,
  notes           text,
  is_board_ready  boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (board_month, item_code)
);

ALTER TABLE public.board_prep_checklist_items_r2749 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.board_prep_checklist_items_r2749
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------
-- Table 2: board_prep_checklist_evidence_r2749
-- ----------------------------------------------------------------------------
CREATE TABLE public.board_prep_checklist_evidence_r2749 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id         uuid NOT NULL REFERENCES public.board_prep_checklist_items_r2749(id) ON DELETE CASCADE,
  evidence_type   text NOT NULL CHECK (evidence_type IN ('document','spreadsheet','dashboard_url','signoff','memo','metric_snapshot')),
  evidence_label  text NOT NULL,
  evidence_url    text,
  submitted_by    text NOT NULL,
  submitted_at    timestamptz NOT NULL DEFAULT now(),
  reviewed_by     text,
  reviewed_at     timestamptz,
  approved        boolean NOT NULL DEFAULT false,
  review_notes    text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_prep_checklist_evidence_r2749 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON public.board_prep_checklist_evidence_r2749
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------
-- Seed data — items
-- ----------------------------------------------------------------------------
INSERT INTO public.board_prep_checklist_items_r2749
  (board_month, item_code, item_title, category, owner_role, status, priority, due_date, completion_pct, depends_on_code, notes, is_board_ready, completed_at)
VALUES
  ('2026-07-01'::date, 'FIN-001', 'June MRR + GMV close',           'financials', 'cfo',              'board_ready', 'p0', '2026-07-05'::date, 100, NULL,      'closed by accounting; reconciled to bank', true,  '2026-07-04 18:00+05:30'::timestamptz),
  ('2026-07-01'::date, 'FIN-002', 'Cash runway projection 18 month','financials', 'cfo',              'approved',    'p0', '2026-07-08'::date,  95, 'FIN-001', 'awaiting founder signoff on scenario B',     false, NULL),
  ('2026-07-01'::date, 'MET-001', 'Repair job NPS + SLA scorecard', 'metrics',    'coo',              'submitted',   'p0', '2026-07-09'::date,  85, NULL,      'engineer team rotation impact noted',         false, NULL),
  ('2026-07-01'::date, 'MET-002', 'AMC churn cohort analysis Q1',   'metrics',    'coo',              'in_progress', 'p1', '2026-07-10'::date,  60, 'MET-001', 'cohorts cut by tier; pending hospital chain breakout', false, NULL),
  ('2026-07-01'::date, 'STR-001', 'v0.6 roadmap update + 3 verticals','strategy', 'founder',          'in_progress', 'p1', '2026-07-11'::date,  70, NULL,      'dental + radiology + dialysis sequencing',    false, NULL),
  ('2026-07-01'::date, 'GOV-001', 'Section 173 board minutes draft','governance', 'board_secretary',  'not_started', 'p1', '2026-07-12'::date,   0, NULL,      'circulate 48h before meeting',                false, NULL),
  ('2026-07-01'::date, 'RSK-001', 'DPDP grievance escalation log',  'risk',       'founder',          'submitted',   'p1', '2026-07-09'::date,  90, NULL,      'zero grievances unresolved past 30d',         false, NULL),
  ('2026-07-01'::date, 'PPL-001', 'Org chart + 6 mo hiring plan',   'people',     'coo',              'blocked',     'p2', '2026-07-13'::date,  40, 'STR-001', 'blocked on roadmap finalization',             false, NULL),
  ('2026-07-01'::date, 'PRD-001', 'Engineer app v0.6 release notes','product',    'cto',              'in_progress', 'p2', '2026-07-13'::date,  50, NULL,      'AI triage section pending QA signoff',        false, NULL);

-- ----------------------------------------------------------------------------
-- Seed data — evidence
-- ----------------------------------------------------------------------------
INSERT INTO public.board_prep_checklist_evidence_r2749
  (item_id, evidence_type, evidence_label, evidence_url, submitted_by, reviewed_by, reviewed_at, approved, review_notes)
SELECT id, 'spreadsheet',     'June_close_v3.xlsx',        'https://drive.example/june-close', 'cfo@equipseva.com', 'founder@equipseva.com', now() - interval '2 day', true,  'tied to bank to the rupee'
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='FIN-001'
UNION ALL
SELECT id, 'dashboard_url',   'Runway dashboard scenario A','https://app.equipseva.com/founder/runway', 'cfo@equipseva.com', 'founder@equipseva.com', now() - interval '1 day', true,  'scenario A approved'
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='FIN-002'
UNION ALL
SELECT id, 'metric_snapshot', 'NPS_scorecard_june.pdf',    'https://drive.example/nps-june', 'coo@equipseva.com', NULL, NULL, false, NULL
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='MET-001'
UNION ALL
SELECT id, 'document',        'AMC_cohort_draft.docx',     'https://drive.example/amc-cohort', 'coo@equipseva.com', NULL, NULL, false, 'draft only'
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='MET-002'
UNION ALL
SELECT id, 'memo',             'v06_roadmap_memo.md',       'https://drive.example/v06-memo', 'founder@equipseva.com', NULL, NULL, false, NULL
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='STR-001'
UNION ALL
SELECT id, 'signoff',         'DPDP_grievance_log_june',   'https://app.equipseva.com/founder/dpdp', 'founder@equipseva.com', NULL, NULL, false, 'pending board secretary review'
  FROM public.board_prep_checklist_items_r2749 WHERE item_code='RSK-001';

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. KPIs
DROP FUNCTION IF EXISTS public.fn_r2749_board_prep_kpis();
CREATE OR REPLACE FUNCTION public.fn_r2749_board_prep_kpis()
RETURNS TABLE (
  total_items        bigint,
  board_ready_items  bigint,
  blocked_items      bigint,
  overdue_items      bigint,
  avg_completion_pct numeric,
  p0_open            bigint,
  evidence_submitted bigint,
  evidence_approved  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.board_prep_checklist_items_r2749),
    (SELECT count(*) FROM public.board_prep_checklist_items_r2749 WHERE is_board_ready),
    (SELECT count(*) FROM public.board_prep_checklist_items_r2749 WHERE status='blocked'),
    (SELECT count(*) FROM public.board_prep_checklist_items_r2749 WHERE due_date < current_date AND status NOT IN ('board_ready','approved')),
    (SELECT coalesce(round(avg(completion_pct)::numeric,1),0) FROM public.board_prep_checklist_items_r2749),
    (SELECT count(*) FROM public.board_prep_checklist_items_r2749 WHERE priority='p0' AND status NOT IN ('board_ready','approved')),
    (SELECT count(*) FROM public.board_prep_checklist_evidence_r2749),
    (SELECT count(*) FROM public.board_prep_checklist_evidence_r2749 WHERE approved);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_board_prep_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_board_prep_kpis() TO authenticated;

-- 2. List all items
DROP FUNCTION IF EXISTS public.fn_r2749_list_items();
CREATE OR REPLACE FUNCTION public.fn_r2749_list_items()
RETURNS TABLE (
  id uuid, item_code text, item_title text, category text, owner_role text,
  status text, priority text, due_date date, completion_pct int,
  depends_on_code text, is_board_ready boolean, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.item_code, i.item_title, i.category, i.owner_role,
         i.status, i.priority, i.due_date, i.completion_pct,
         i.depends_on_code, i.is_board_ready, i.notes
  FROM public.board_prep_checklist_items_r2749 i
  ORDER BY i.priority, i.due_date, i.item_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_list_items() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_list_items() TO authenticated;

-- 3. Items by category breakdown
DROP FUNCTION IF EXISTS public.fn_r2749_category_breakdown();
CREATE OR REPLACE FUNCTION public.fn_r2749_category_breakdown()
RETURNS TABLE (category text, total bigint, ready bigint, blocked bigint, avg_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.category,
         count(*)::bigint,
         count(*) FILTER (WHERE i.is_board_ready)::bigint,
         count(*) FILTER (WHERE i.status='blocked')::bigint,
         round(avg(i.completion_pct)::numeric,1)
  FROM public.board_prep_checklist_items_r2749 i
  GROUP BY i.category
  ORDER BY i.category;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_category_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_category_breakdown() TO authenticated;

-- 4. Owner load
DROP FUNCTION IF EXISTS public.fn_r2749_owner_load();
CREATE OR REPLACE FUNCTION public.fn_r2749_owner_load()
RETURNS TABLE (owner_role text, total bigint, open_items bigint, p0_open bigint, avg_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.owner_role,
         count(*)::bigint,
         count(*) FILTER (WHERE i.status NOT IN ('board_ready','approved'))::bigint,
         count(*) FILTER (WHERE i.priority='p0' AND i.status NOT IN ('board_ready','approved'))::bigint,
         round(avg(i.completion_pct)::numeric,1)
  FROM public.board_prep_checklist_items_r2749 i
  GROUP BY i.owner_role
  ORDER BY count(*) FILTER (WHERE i.status NOT IN ('board_ready','approved')) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_owner_load() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_owner_load() TO authenticated;

-- 5. Dependency chain (items that block others)
DROP FUNCTION IF EXISTS public.fn_r2749_dependency_chain();
CREATE OR REPLACE FUNCTION public.fn_r2749_dependency_chain()
RETURNS TABLE (blocker_code text, blocker_status text, blocker_pct int, blocked_code text, blocked_status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.item_code, b.status, b.completion_pct, d.item_code, d.status
  FROM public.board_prep_checklist_items_r2749 d
  JOIN public.board_prep_checklist_items_r2749 b ON b.item_code = d.depends_on_code
  ORDER BY b.priority, b.item_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_dependency_chain() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_dependency_chain() TO authenticated;

-- 6. Evidence log
DROP FUNCTION IF EXISTS public.fn_r2749_evidence_log();
CREATE OR REPLACE FUNCTION public.fn_r2749_evidence_log()
RETURNS TABLE (item_code text, evidence_type text, evidence_label text, submitted_by text, submitted_at timestamptz, approved boolean, review_notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.item_code, e.evidence_type, e.evidence_label, e.submitted_by, e.submitted_at, e.approved, e.review_notes
  FROM public.board_prep_checklist_evidence_r2749 e
  JOIN public.board_prep_checklist_items_r2749 i ON i.id = e.item_id
  ORDER BY e.submitted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_evidence_log() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_evidence_log() TO authenticated;

-- 7. Mark item board-ready
DROP FUNCTION IF EXISTS public.fn_r2749_mark_board_ready(uuid);
CREATE OR REPLACE FUNCTION public.fn_r2749_mark_board_ready(p_item_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.board_prep_checklist_items_r2749
     SET is_board_ready = true,
         status = 'board_ready',
         completion_pct = 100,
         completed_at = COALESCE(completed_at, now()),
         updated_at = now()
   WHERE id = p_item_id;
  RETURN FOUND;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_mark_board_ready(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_mark_board_ready(uuid) TO authenticated;

-- 8. Overdue items
DROP FUNCTION IF EXISTS public.fn_r2749_overdue_items();
CREATE OR REPLACE FUNCTION public.fn_r2749_overdue_items()
RETURNS TABLE (item_code text, item_title text, owner_role text, due_date date, days_overdue int, status text, priority text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.item_code, i.item_title, i.owner_role, i.due_date,
         (current_date - i.due_date)::int AS days_overdue,
         i.status, i.priority
  FROM public.board_prep_checklist_items_r2749 i
  WHERE i.due_date < current_date
    AND i.status NOT IN ('board_ready','approved')
  ORDER BY i.priority, i.due_date;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2749_overdue_items() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_r2749_overdue_items() TO authenticated;

COMMIT;
