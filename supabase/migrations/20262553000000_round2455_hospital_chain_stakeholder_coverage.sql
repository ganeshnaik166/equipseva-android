-- Round r2455: Hospital chain stakeholder coverage
-- Track stakeholder coverage across hospital chains: who is covered, who owns the gap, risk level.

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_stakeholder_coverage_r2455 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  role_kind text NOT NULL CHECK (role_kind IN ('c_suite','biomed_lead','procurement','finance','clinical_user','it','legal')),
  is_covered boolean NOT NULL DEFAULT false,
  primary_contact_email text,
  last_touch_at timestamptz,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('weak','developing','strong','champion')),
  risk_level text NOT NULL CHECK (risk_level IN ('low','medium','high','critical')),
  gap_owner_email text,
  gap_notes text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chain_coverage_action_plans_r2455 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  role_kind text NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  recommended_action_md text,
  owner_email text,
  action_due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_stakeholder_coverage_r2455 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_coverage_action_plans_r2455 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_stakeholder_coverage_r2455;
CREATE POLICY founder_all ON public.chain_stakeholder_coverage_r2455
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_coverage_action_plans_r2455;
CREATE POLICY founder_all ON public.chain_coverage_action_plans_r2455
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed coverage rows
INSERT INTO public.chain_stakeholder_coverage_r2455
  (chain_name, role_kind, is_covered, primary_contact_email, last_touch_at, relationship_strength, risk_level, gap_owner_email, gap_notes, notes)
VALUES
  ('Apollo', 'c_suite', true, 'cmo@apollo.example', (now() - interval '5 days')::timestamptz, 'champion', 'low', NULL, NULL, 'CMO is internal champion, monthly steering call.'),
  ('Apollo', 'procurement', false, NULL, NULL, 'weak', 'high', 'ganesh@equipseva.in', 'No procurement entry point yet; relying on biomed.', 'Need to break in via shared dental supplier.'),
  ('Fortis', 'biomed_lead', true, 'biomed.head@fortis.example', (now() - interval '12 days')::timestamptz, 'strong', 'medium', NULL, NULL, 'Strong technical sponsor across 4 sites.'),
  ('Fortis', 'finance', false, NULL, NULL, 'developing', 'critical', 'cfo-team@equipseva.in', 'CFO blocking renewal; never had a finance touchpoint.', 'Renewal at risk in 60 days.'),
  ('Manipal', 'clinical_user', true, 'icu.lead@manipal.example', (now() - interval '2 days')::timestamptz, 'developing', 'low', NULL, NULL, 'ICU lead trialing AMC pool.');

-- Seed action plan rows
INSERT INTO public.chain_coverage_action_plans_r2455
  (chain_name, role_kind, opened_at, recommended_action_md, owner_email, action_due_at, status, outcome, notes)
VALUES
  ('Apollo', 'procurement', (now() - interval '3 days')::timestamptz, 'Get warm intro via shared dental supplier; aim for 30-min discovery call.', 'ganesh@equipseva.in', (now() + interval '10 days')::timestamptz, 'in_progress', 'pending', 'Supplier intro confirmed.'),
  ('Fortis', 'finance', (now() - interval '1 day')::timestamptz, 'Schedule CFO briefing with ROI deck; bring biomed champion.', 'cfo-team@equipseva.in', (now() + interval '14 days')::timestamptz, 'open', 'pending', 'Critical for renewal.'),
  ('Apollo', 'c_suite', (now() - interval '20 days')::timestamptz, 'Send quarterly executive summary deck.', 'ganesh@equipseva.in', (now() - interval '5 days')::timestamptz, 'done', 'positive', 'CMO replied positively.');

-- RPC 1: list coverage
CREATE OR REPLACE FUNCTION public.list_coverage_r2455()
RETURNS TABLE (
  id uuid,
  chain_name text,
  role_kind text,
  is_covered boolean,
  primary_contact_email text,
  last_touch_at timestamptz,
  relationship_strength text,
  risk_level text,
  gap_owner_email text,
  gap_notes text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.role_kind, c.is_covered, c.primary_contact_email, c.last_touch_at,
         c.relationship_strength, c.risk_level, c.gap_owner_email, c.gap_notes, c.notes, c.created_at
  FROM public.chain_stakeholder_coverage_r2455 c
  ORDER BY c.chain_name ASC, c.role_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_coverage_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coverage_r2455() TO authenticated;

-- RPC 2: list action plans
CREATE OR REPLACE FUNCTION public.list_action_plans_r2455()
RETURNS TABLE (
  id uuid,
  chain_name text,
  role_kind text,
  opened_at timestamptz,
  recommended_action_md text,
  owner_email text,
  action_due_at timestamptz,
  status text,
  outcome text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.role_kind, a.opened_at, a.recommended_action_md, a.owner_email,
         a.action_due_at, a.status, a.outcome, a.closed_at, a.closed_by_email, a.notes
  FROM public.chain_coverage_action_plans_r2455 a
  ORDER BY a.opened_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_plans_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_plans_r2455() TO authenticated;

-- RPC 3: uncovered focus
CREATE OR REPLACE FUNCTION public.uncovered_focus_r2455()
RETURNS TABLE (
  id uuid,
  chain_name text,
  role_kind text,
  risk_level text,
  relationship_strength text,
  gap_owner_email text,
  gap_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.role_kind, c.risk_level, c.relationship_strength, c.gap_owner_email, c.gap_notes
  FROM public.chain_stakeholder_coverage_r2455 c
  WHERE c.is_covered = false
  ORDER BY
    CASE c.risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END,
    c.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.uncovered_focus_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.uncovered_focus_r2455() TO authenticated;

-- RPC 4: high risk chains
CREATE OR REPLACE FUNCTION public.high_risk_chains_r2455()
RETURNS TABLE (
  chain_name text,
  total_roles bigint,
  covered_roles bigint,
  high_risk_count bigint,
  critical_risk_count bigint,
  coverage_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name,
         COUNT(*)::bigint AS total_roles,
         COUNT(*) FILTER (WHERE c.is_covered = true)::bigint AS covered_roles,
         COUNT(*) FILTER (WHERE c.risk_level = 'high')::bigint AS high_risk_count,
         COUNT(*) FILTER (WHERE c.risk_level = 'critical')::bigint AS critical_risk_count,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.is_covered = true)::numeric / NULLIF(COUNT(*),0), 1) AS coverage_pct
  FROM public.chain_stakeholder_coverage_r2455 c
  GROUP BY c.chain_name
  ORDER BY critical_risk_count DESC, high_risk_count DESC, c.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.high_risk_chains_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.high_risk_chains_r2455() TO authenticated;

-- RPC 5: role coverage summary
CREATE OR REPLACE FUNCTION public.role_coverage_summary_r2455()
RETURNS TABLE (
  role_kind text,
  total_chains bigint,
  covered_chains bigint,
  uncovered_chains bigint,
  coverage_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.role_kind,
         COUNT(*)::bigint AS total_chains,
         COUNT(*) FILTER (WHERE c.is_covered = true)::bigint AS covered_chains,
         COUNT(*) FILTER (WHERE c.is_covered = false)::bigint AS uncovered_chains,
         ROUND(100.0 * COUNT(*) FILTER (WHERE c.is_covered = true)::numeric / NULLIF(COUNT(*),0), 1) AS coverage_pct
  FROM public.chain_stakeholder_coverage_r2455 c
  GROUP BY c.role_kind
  ORDER BY coverage_pct ASC NULLS LAST, c.role_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_coverage_summary_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_coverage_summary_r2455() TO authenticated;

-- RPC 6: action owner load
CREATE OR REPLACE FUNCTION public.action_owner_load_r2455()
RETURNS TABLE (
  owner_email text,
  open_count bigint,
  in_progress_count bigint,
  done_count bigint,
  dropped_count bigint,
  overdue_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, 'unassigned') AS owner_email,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS open_count,
         COUNT(*) FILTER (WHERE a.status = 'in_progress')::bigint AS in_progress_count,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE a.status = 'dropped')::bigint AS dropped_count,
         COUNT(*) FILTER (WHERE a.status IN ('open','in_progress') AND a.action_due_at IS NOT NULL AND a.action_due_at < now())::bigint AS overdue_count
  FROM public.chain_coverage_action_plans_r2455 a
  GROUP BY COALESCE(a.owner_email, 'unassigned')
  ORDER BY overdue_count DESC, open_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_owner_load_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_owner_load_r2455() TO authenticated;

-- RPC 7: recently touched summary
CREATE OR REPLACE FUNCTION public.recently_touched_summary_r2455()
RETURNS TABLE (
  bucket text,
  role_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT bkt AS bucket, COUNT(*)::bigint AS role_count
  FROM (
    SELECT
      CASE
        WHEN c.last_touch_at IS NULL THEN 'never'
        WHEN c.last_touch_at >= (now() - interval '7 days') THEN 'last_7d'
        WHEN c.last_touch_at >= (now() - interval '30 days') THEN 'last_30d'
        WHEN c.last_touch_at >= (now() - interval '90 days') THEN 'last_90d'
        ELSE 'older'
      END AS bkt
    FROM public.chain_stakeholder_coverage_r2455 c
  ) s
  GROUP BY bkt
  ORDER BY
    CASE bkt WHEN 'last_7d' THEN 1 WHEN 'last_30d' THEN 2 WHEN 'last_90d' THEN 3 WHEN 'older' THEN 4 WHEN 'never' THEN 5 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recently_touched_summary_r2455() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recently_touched_summary_r2455() TO authenticated;

