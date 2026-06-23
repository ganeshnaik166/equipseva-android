-- Round r2466: founder-decision-quality-postmortem
-- Tables: founder_decisions_r2466, decision_review_sessions_r2466
-- RPCs: 7 (founder-gated, plpgsql, STABLE SECDEF)

BEGIN;

-- =============================================================
-- TABLE 1: founder_decisions_r2466
-- =============================================================
CREATE TABLE IF NOT EXISTS public.founder_decisions_r2466 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_name text NOT NULL,
  decided_at timestamptz NOT NULL,
  decision_kind text NOT NULL CHECK (decision_kind IN ('hire','fire','pricing','feature_kill','launch','investment','partnership','policy')),
  hypothesis_md text NOT NULL,
  actual_outcome_md text NOT NULL,
  delta_summary text NOT NULL,
  delta_kind text NOT NULL CHECK (delta_kind IN ('better','as_expected','worse','much_worse')),
  root_cause_md text NOT NULL,
  lesson_md text NOT NULL,
  repeat_avoidance_md text NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decisions_r2466 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_decisions_r2466;
CREATE POLICY founder_all ON public.founder_decisions_r2466
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================
-- TABLE 2: decision_review_sessions_r2466
-- =============================================================
CREATE TABLE IF NOT EXISTS public.decision_review_sessions_r2466 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewed_at timestamptz NOT NULL,
  reviewer_email text NOT NULL,
  decisions_reviewed_count int NOT NULL DEFAULT 0,
  top_lesson text NOT NULL,
  top_win text NOT NULL,
  top_miss text NOT NULL,
  repeat_pattern_count int NOT NULL DEFAULT 0,
  action_items_md text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.decision_review_sessions_r2466 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.decision_review_sessions_r2466;
CREATE POLICY founder_all ON public.decision_review_sessions_r2466
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================
-- SEED DATA
-- =============================================================
INSERT INTO public.founder_decisions_r2466
  (decision_name, decided_at, decision_kind, hypothesis_md, actual_outcome_md, delta_summary, delta_kind, root_cause_md, lesson_md, repeat_avoidance_md, owner_email, status, notes)
VALUES
  ('Kill SaaS-only tier', '2026-03-15T10:00:00+05:30'::timestamptz, 'feature_kill',
   'SaaS-only tier dilutes service narrative; killing focuses GTM.',
   'GTM clarity +30%, lost 2 deals worth 8L ARR, net positive at quarter close.',
   'Better than expected on focus; small revenue hit absorbed.', 'better',
   'Hospitals buy outcomes not software; SaaS-only had no anchor.',
   'Kill orphan SKUs early when narrative confusion costs more than ARR.',
   'Quarterly SKU review with narrative-fit score; auto-flag <0.6.',
   'founder@equipseva.io', 'closed', 'Validated by Q2 GTM clarity NPS jump.'),
  ('Hire VP Ops from Tier-1 hospital chain', '2026-04-02T11:00:00+05:30'::timestamptz, 'hire',
   'VP Ops will scale engineer ops 3x in 90 days.',
   'Scaled 1.4x; cultural friction with engineer pod; departed at day 75.',
   'Much worse on speed and retention.', 'much_worse',
   'Optimized for hospital pedigree over startup-velocity fit; missed culture screen.',
   'Velocity-fit > pedigree for first 50 hires; structured culture interview mandatory.',
   'Add 2-hour culture-fit panel + startup-velocity reference for all senior hires.',
   'founder@equipseva.io', 'reviewed', 'Cost: 2 months runway + team morale dip.'),
  ('Raise AMC tier 3 price 18%', '2026-04-20T09:30:00+05:30'::timestamptz, 'pricing',
   'Tier-3 underpriced vs unit economics; 15% churn acceptable.',
   '8% churn, 22% revenue lift, NPS unchanged.', 'Outperformed across all metrics.', 'better',
   'Tier-3 customers were highly price-insensitive; we under-estimated stickiness.',
   'Test pricing earlier and more aggressively for sticky tiers.',
   'Run quarterly price-sensitivity sprint; default to 10-20% raise hypothesis.',
   'founder@equipseva.io', 'closed', 'Replicate playbook for Tier-2 in Q3.'),
  ('Launch dental vertical', '2026-05-10T14:00:00+05:30'::timestamptz, 'launch',
   '50 dental clinics signed in 60 days; LTV/CAC > 4.',
   '12 clinics in 60 days; LTV/CAC = 1.8; sales cycle 3x longer than hospitals.',
   'Worse than plan; sales cycle and ICP mismatch.', 'worse',
   'Dental clinics are owner-operated; decision cycle slow; ticket-size too small for our cost structure.',
   'Validate ICP unit economics before vertical launch; require LTV/CAC>3 in pilot.',
   'Add ICP-validation gate to vertical-launch checklist; require 10-clinic pilot first.',
   'founder@equipseva.io', 'open', 'Decide: kill or pivot to dental-chain only?'),
  ('Partner with NABH for accreditation tooling', '2026-05-25T15:30:00+05:30'::timestamptz, 'partnership',
   'NABH endorsement drives 30% deal acceleration.',
   'Endorsement landed; deal acceleration 28%; 5 marquee logos closed.', 'As expected across metrics.', 'as_expected',
   'Aligned incentives + co-marketing motion worked as modeled.',
   'Accreditation partnerships are high-leverage when aligned on outcomes.',
   'Pursue 2 more accreditation partnerships (JCI, ISO) using same playbook.',
   'founder@equipseva.io', 'closed', 'Template the playbook in playbook-library.');

INSERT INTO public.decision_review_sessions_r2466
  (reviewed_at, reviewer_email, decisions_reviewed_count, top_lesson, top_win, top_miss, repeat_pattern_count, action_items_md, status, notes)
VALUES
  ('2026-05-30T16:00:00+05:30'::timestamptz, 'founder@equipseva.io', 5,
   'Velocity-fit beats pedigree for first 50 hires.',
   'AMC tier-3 18% price raise: +22% rev, churn -7pp vs plan.',
   'Dental launch without ICP unit-economics gate.', 2,
   'Add culture-fit panel; add ICP gate to vertical-launch SOP; quarterly pricing sprint.',
   'done', 'Q2 board pre-read; 3 SOP updates queued.'),
  ('2026-06-15T17:00:00+05:30'::timestamptz, 'founder@equipseva.io', 3,
   'Kill orphan SKUs early.', 'SaaS-tier kill drove 30% narrative clarity.',
   'VP Ops hire missed culture screen.', 1,
   'Run SKU narrative-fit review; close VP Ops post-mortem follow-ups.',
   'pending', 'Monthly review cadence locked.');

-- =============================================================
-- RPC 1: list_decisions_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_decisions_r2466()
RETURNS TABLE (
  id uuid, decision_name text, decided_at timestamptz, decision_kind text,
  delta_summary text, delta_kind text, owner_email text, status text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.decision_name, d.decided_at, d.decision_kind,
         d.delta_summary, d.delta_kind, d.owner_email, d.status, d.notes
  FROM public.founder_decisions_r2466 d
  ORDER BY d.decided_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decisions_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decisions_r2466() TO authenticated;

-- =============================================================
-- RPC 2: list_review_sessions_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_review_sessions_r2466()
RETURNS TABLE (
  id uuid, reviewed_at timestamptz, reviewer_email text,
  decisions_reviewed_count int, top_lesson text, top_win text, top_miss text,
  repeat_pattern_count int, status text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.reviewed_at, s.reviewer_email,
         s.decisions_reviewed_count, s.top_lesson, s.top_win, s.top_miss,
         s.repeat_pattern_count, s.status, s.notes
  FROM public.decision_review_sessions_r2466 s
  ORDER BY s.reviewed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_review_sessions_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_review_sessions_r2466() TO authenticated;

-- =============================================================
-- RPC 3: decision_kind_breakdown_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.decision_kind_breakdown_r2466()
RETURNS TABLE (decision_kind text, count_total bigint, count_better bigint, count_worse bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_kind,
         count(*)::bigint AS count_total,
         count(*) FILTER (WHERE d.delta_kind = 'better')::bigint AS count_better,
         count(*) FILTER (WHERE d.delta_kind IN ('worse','much_worse'))::bigint AS count_worse
  FROM public.founder_decisions_r2466 d
  GROUP BY d.decision_kind
  ORDER BY count_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_breakdown_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_breakdown_r2466() TO authenticated;

-- =============================================================
-- RPC 4: delta_distribution_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.delta_distribution_r2466()
RETURNS TABLE (delta_kind text, count_total bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM public.founder_decisions_r2466;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT d.delta_kind,
         count(*)::bigint AS count_total,
         round((count(*)::numeric / v_total) * 100, 2) AS pct
  FROM public.founder_decisions_r2466 d
  GROUP BY d.delta_kind
  ORDER BY count_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.delta_distribution_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delta_distribution_r2466() TO authenticated;

-- =============================================================
-- RPC 5: top_lessons_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.top_lessons_r2466()
RETURNS TABLE (decision_name text, decision_kind text, delta_kind text, lesson_md text, decided_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_name, d.decision_kind, d.delta_kind, d.lesson_md, d.decided_at
  FROM public.founder_decisions_r2466 d
  WHERE d.delta_kind IN ('worse','much_worse','better')
  ORDER BY d.decided_at DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lessons_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lessons_r2466() TO authenticated;

-- =============================================================
-- RPC 6: repeat_patterns_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.repeat_patterns_r2466()
RETURNS TABLE (decision_kind text, miss_count bigint, latest_lesson text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.decision_kind,
         count(*)::bigint AS miss_count,
         (SELECT d2.lesson_md
            FROM public.founder_decisions_r2466 d2
           WHERE d2.decision_kind = d.decision_kind
             AND d2.delta_kind IN ('worse','much_worse')
           ORDER BY d2.decided_at DESC
           LIMIT 1) AS latest_lesson
  FROM public.founder_decisions_r2466 d
  WHERE d.delta_kind IN ('worse','much_worse')
  GROUP BY d.decision_kind
  HAVING count(*) >= 1
  ORDER BY miss_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.repeat_patterns_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repeat_patterns_r2466() TO authenticated;

-- =============================================================
-- RPC 7: monthly_postmortem_trend_r2466
-- =============================================================
CREATE OR REPLACE FUNCTION public.monthly_postmortem_trend_r2466()
RETURNS TABLE (month_start timestamptz, decisions_count bigint, better_count bigint, worse_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', d.decided_at) AS month_start,
         count(*)::bigint AS decisions_count,
         count(*) FILTER (WHERE d.delta_kind = 'better')::bigint AS better_count,
         count(*) FILTER (WHERE d.delta_kind IN ('worse','much_worse'))::bigint AS worse_count
  FROM public.founder_decisions_r2466 d
  GROUP BY date_trunc('month', d.decided_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_postmortem_trend_r2466() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_postmortem_trend_r2466() TO authenticated;

