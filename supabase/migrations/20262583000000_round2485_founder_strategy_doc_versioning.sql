-- Round 2485: founder-strategy-doc-versioning
-- Tables: founder_strategy_docs_r2485, strategy_doc_stakeholder_reviews_r2485

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategy_docs_r2485 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_title text NOT NULL,
  version_label text NOT NULL,
  prior_version_label text,
  delta_summary_md text,
  decisions_changed_md text,
  drafted_at timestamptz,
  locked_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','locked','superseded','archived')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.strategy_doc_stakeholder_reviews_r2485 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id uuid NOT NULL REFERENCES public.founder_strategy_docs_r2485(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  reviewed_at timestamptz,
  signoff_status text NOT NULL DEFAULT 'pending' CHECK (signoff_status IN ('approved','needs_changes','rejected','pending')),
  feedback_md text,
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategy_docs_r2485 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strategy_doc_stakeholder_reviews_r2485 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategy_docs_r2485;
CREATE POLICY founder_all ON public.founder_strategy_docs_r2485
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.strategy_doc_stakeholder_reviews_r2485;
CREATE POLICY founder_all ON public.strategy_doc_stakeholder_reviews_r2485
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed docs
INSERT INTO public.founder_strategy_docs_r2485
  (id, doc_title, version_label, prior_version_label, delta_summary_md, decisions_changed_md, drafted_at, locked_at, status, owner_email, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'EquipSeva North-Star Strategy', 'v0.6', 'v0.5', 'Added franchise model + dropped Tier-2 Hindi-belt expansion', 'Reverse decision: NOT pursuing manufacturer-led OEM model; doubling down on hospital chains', '2026-06-10T09:00:00Z'::timestamptz, '2026-06-18T17:00:00Z'::timestamptz, 'locked', 'founder@equipseva.in', 'Locked after 3 stakeholder rounds'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'EquipSeva North-Star Strategy', 'v0.5', 'v0.4', 'Phase 3 hospital-chains + Phase 9 morning digest folded in', 'Killed: free-tier AMC; Added: tiered AMC pricing', '2026-04-12T10:00:00Z'::timestamptz, '2026-04-20T18:00:00Z'::timestamptz, 'superseded', 'founder@equipseva.in', 'Superseded by v0.6'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'Hiring Plan FY27', 'v0.2', 'v0.1', 'Senior backend hire moved Q3->Q2; added 2 sales reps', 'Decision change: hire sales BEFORE marketing lead', '2026-06-15T11:00:00Z'::timestamptz, NULL, 'in_review', 'people@equipseva.in', 'Awaiting CFO signoff'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'Pricing Strategy 2026 H2', 'v0.1', NULL, 'Initial draft of usage-based pricing for AMC tier-3', 'New decision: pilot usage-based for top-20 hospital chains', '2026-06-20T14:00:00Z'::timestamptz, NULL, 'draft', 'founder@equipseva.in', 'Draft only'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'GTM Playbook 2026', 'v1.0', 'v0.9', 'Removed cold-call motion; added hospital-chain CXO outbound', 'Reversed: stop cold-calling; ABM instead', '2026-05-22T09:30:00Z'::timestamptz, '2026-05-30T16:00:00Z'::timestamptz, 'locked', 'sales@equipseva.in', 'Locked v1.0');

-- Seed reviews
INSERT INTO public.strategy_doc_stakeholder_reviews_r2485
  (doc_id, reviewer_email, reviewed_at, signoff_status, feedback_md, follow_up_required, follow_up_at, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'cfo@equipseva.in', '2026-06-15T10:00:00Z'::timestamptz, 'approved', 'Numbers tie out; runway model holds', false, NULL, 'CFO green light'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'investor.lead@vc.in', '2026-06-16T11:00:00Z'::timestamptz, 'approved', 'Aligned with thesis; like the franchise pivot', false, NULL, 'Lead investor approved'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'board.chair@equipseva.in', '2026-06-17T14:00:00Z'::timestamptz, 'needs_changes', 'Want clearer kill-criteria for franchise pilot', true, '2026-07-01T10:00:00Z'::timestamptz, 'Chair needs revision'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'cfo@equipseva.in', '2026-04-18T10:00:00Z'::timestamptz, 'approved', 'AMC tier model solid', false, NULL, 'Approved v0.5'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'board.chair@equipseva.in', '2026-04-19T15:00:00Z'::timestamptz, 'approved', 'Hospital chains focus is right', false, NULL, 'Chair approved'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'cfo@equipseva.in', NULL, 'pending', NULL, false, NULL, 'CFO pending'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'founder@equipseva.in', '2026-06-16T09:00:00Z'::timestamptz, 'needs_changes', 'Want backend hire Q2 confirmed only after Series A close', true, '2026-06-30T10:00:00Z'::timestamptz, 'Founder wants revision'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'sales@equipseva.in', NULL, 'pending', NULL, false, NULL, 'Sales lead pending'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'cfo@equipseva.in', NULL, 'pending', NULL, false, NULL, 'CFO pending'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'cfo@equipseva.in', '2026-05-25T11:00:00Z'::timestamptz, 'approved', 'CAC payback model clean', false, NULL, 'Approved'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'sales@equipseva.in', '2026-05-26T10:00:00Z'::timestamptz, 'approved', 'ABM motion ready to execute', false, NULL, 'Sales approved'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'investor.lead@vc.in', '2026-05-28T14:00:00Z'::timestamptz, 'rejected', 'Want one more pricing experiment first', true, '2026-06-10T10:00:00Z'::timestamptz, 'Investor rejected — later resolved');

-- RPC 1: list docs
CREATE OR REPLACE FUNCTION public.list_docs_r2485()
RETURNS TABLE (
  id uuid,
  doc_title text,
  version_label text,
  prior_version_label text,
  delta_summary_md text,
  decisions_changed_md text,
  drafted_at timestamptz,
  locked_at timestamptz,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.doc_title, d.version_label, d.prior_version_label,
         d.delta_summary_md, d.decisions_changed_md, d.drafted_at, d.locked_at,
         d.status, d.owner_email, d.notes
  FROM public.founder_strategy_docs_r2485 d
  ORDER BY d.drafted_at DESC NULLS LAST, d.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_docs_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_docs_r2485() TO authenticated;

-- RPC 2: list stakeholder reviews
CREATE OR REPLACE FUNCTION public.list_stakeholder_reviews_r2485()
RETURNS TABLE (
  id uuid,
  doc_title text,
  version_label text,
  reviewer_email text,
  reviewed_at timestamptz,
  signoff_status text,
  feedback_md text,
  follow_up_required boolean,
  follow_up_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, d.doc_title, d.version_label, r.reviewer_email, r.reviewed_at,
         r.signoff_status, r.feedback_md, r.follow_up_required, r.follow_up_at, r.notes
  FROM public.strategy_doc_stakeholder_reviews_r2485 r
  JOIN public.founder_strategy_docs_r2485 d ON d.id = r.doc_id
  ORDER BY r.reviewed_at DESC NULLS LAST, r.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_stakeholder_reviews_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stakeholder_reviews_r2485() TO authenticated;

-- RPC 3: latest locked docs
CREATE OR REPLACE FUNCTION public.latest_locked_docs_r2485()
RETURNS TABLE (
  doc_title text,
  version_label text,
  locked_at timestamptz,
  owner_email text,
  days_since_lock int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (d.doc_title)
         d.doc_title, d.version_label, d.locked_at, d.owner_email,
         EXTRACT(DAY FROM (now() - d.locked_at))::int AS days_since_lock
  FROM public.founder_strategy_docs_r2485 d
  WHERE d.status = 'locked'
  ORDER BY d.doc_title, d.locked_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.latest_locked_docs_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.latest_locked_docs_r2485() TO authenticated;

-- RPC 4: pending reviews focus
CREATE OR REPLACE FUNCTION public.pending_reviews_focus_r2485()
RETURNS TABLE (
  doc_title text,
  version_label text,
  reviewer_email text,
  status text,
  days_pending int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.doc_title, d.version_label, r.reviewer_email, d.status,
         EXTRACT(DAY FROM (now() - COALESCE(d.drafted_at, d.created_at)))::int AS days_pending
  FROM public.strategy_doc_stakeholder_reviews_r2485 r
  JOIN public.founder_strategy_docs_r2485 d ON d.id = r.doc_id
  WHERE r.signoff_status IN ('pending','needs_changes')
    AND d.status IN ('draft','in_review')
  ORDER BY days_pending DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.pending_reviews_focus_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pending_reviews_focus_r2485() TO authenticated;

-- RPC 5: version history per doc title
CREATE OR REPLACE FUNCTION public.version_history_r2485()
RETURNS TABLE (
  doc_title text,
  version_count bigint,
  latest_version text,
  latest_status text,
  first_drafted_at timestamptz,
  latest_locked_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (d.doc_title) d.doc_title, d.version_label, d.status
    FROM public.founder_strategy_docs_r2485 d
    ORDER BY d.doc_title, d.drafted_at DESC NULLS LAST, d.created_at DESC
  )
  SELECT d.doc_title,
         COUNT(*)::bigint AS version_count,
         l.version_label AS latest_version,
         l.status AS latest_status,
         MIN(d.drafted_at) AS first_drafted_at,
         MAX(d.locked_at) AS latest_locked_at
  FROM public.founder_strategy_docs_r2485 d
  JOIN latest l ON l.doc_title = d.doc_title
  GROUP BY d.doc_title, l.version_label, l.status
  ORDER BY d.doc_title;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.version_history_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.version_history_r2485() TO authenticated;

-- RPC 6: signoff status summary
CREATE OR REPLACE FUNCTION public.signoff_status_summary_r2485()
RETURNS TABLE (
  signoff_status text,
  review_count bigint,
  follow_ups_required bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.signoff_status,
         COUNT(*)::bigint AS review_count,
         COUNT(*) FILTER (WHERE r.follow_up_required)::bigint AS follow_ups_required
  FROM public.strategy_doc_stakeholder_reviews_r2485 r
  GROUP BY r.signoff_status
  ORDER BY review_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.signoff_status_summary_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signoff_status_summary_r2485() TO authenticated;

-- RPC 7: top changed decisions
CREATE OR REPLACE FUNCTION public.top_changed_decisions_r2485()
RETURNS TABLE (
  doc_title text,
  version_label text,
  decisions_changed_md text,
  drafted_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.doc_title, d.version_label, d.decisions_changed_md, d.drafted_at, d.status
  FROM public.founder_strategy_docs_r2485 d
  WHERE d.decisions_changed_md IS NOT NULL
    AND length(d.decisions_changed_md) > 0
  ORDER BY d.drafted_at DESC NULLS LAST
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_changed_decisions_r2485() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_changed_decisions_r2485() TO authenticated;

