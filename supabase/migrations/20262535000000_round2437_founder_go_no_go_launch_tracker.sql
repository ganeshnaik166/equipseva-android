-- Round 2437: Founder Go/No-Go Launch Tracker
-- Tracks upcoming launches, their scope, dependencies, risk, and go/no-go readiness.

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_launches_r2437 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  launch_name text NOT NULL,
  scope_md text,
  planned_launch_at timestamptz,
  actual_launch_at timestamptz,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','at_risk','blocked','launched','delayed','cancelled')),
  risk_level text NOT NULL DEFAULT 'low'
    CHECK (risk_level IN ('low','medium','high','critical')),
  risk_notes text,
  dependencies_md text,
  go_no_go_criteria_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_launches_r2437_status        ON public.founder_launches_r2437(status);
CREATE INDEX IF NOT EXISTS idx_launches_r2437_risk          ON public.founder_launches_r2437(risk_level);
CREATE INDEX IF NOT EXISTS idx_launches_r2437_planned_at    ON public.founder_launches_r2437(planned_launch_at);

CREATE TABLE IF NOT EXISTS public.launch_dependency_status_r2437 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  launch_id uuid NOT NULL REFERENCES public.founder_launches_r2437(id) ON DELETE CASCADE,
  dependency_name text NOT NULL,
  dependency_kind text NOT NULL
    CHECK (dependency_kind IN ('team','legal','integration','marketing','infra','customer')),
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','blocked','dropped')),
  blocker_notes text,
  last_update_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dep_r2437_launch    ON public.launch_dependency_status_r2437(launch_id);
CREATE INDEX IF NOT EXISTS idx_dep_r2437_status    ON public.launch_dependency_status_r2437(status);
CREATE INDEX IF NOT EXISTS idx_dep_r2437_kind      ON public.launch_dependency_status_r2437(dependency_kind);
CREATE INDEX IF NOT EXISTS idx_dep_r2437_due_at    ON public.launch_dependency_status_r2437(due_at);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE public.founder_launches_r2437 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.launch_dependency_status_r2437 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_launches_r2437;
CREATE POLICY founder_all ON public.founder_launches_r2437
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.launch_dependency_status_r2437;
CREATE POLICY founder_all ON public.launch_dependency_status_r2437
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED
-- ============================================================================

INSERT INTO public.founder_launches_r2437
  (id, launch_name, scope_md, planned_launch_at, actual_launch_at, status, risk_level, risk_notes, dependencies_md, go_no_go_criteria_md, owner_email, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'v0.5 Android Release', 'Public Android release with AMC payment-first + chain bulk + Hindi i18n', now() + interval '14 days', NULL, 'in_progress', 'medium', 'Play Store review queue uncertain', 'Cashfree KYC, NABH digest, regression suite', 'All Audit-24 fixes verified · 0 crashes · GST invoices auto-send', 'founder@equipseva.in', 'Tracking Phase 2 of v0.5'),
  ('22222222-2222-2222-2222-222222222222', 'Hospital Chain Portal v2', 'Multi-site dashboard + bulk PO + chain-wide AMC', now() + interval '28 days', NULL, 'planned', 'high', 'Chain CTO has not signed integration MOU', 'Apollo CTO sign-off, SSO with chain IdP, RBAC redesign', 'SSO works · bulk PO E2E · chain-wide AMC pricing approved', 'founder@equipseva.in', 'Apollo + Yashoda anchor accounts'),
  ('33333333-3333-3333-3333-333333333333', 'Cashfree Payouts at Scale', 'Migrate from queued reaper to live disbursement at 500+/day', now() + interval '7 days', NULL, 'at_risk', 'high', 'Cashfree activation pending KYC re-verification', 'Cashfree KYC, payout webhook hardening, dispute flow', 'KYC active · 100-payout dry run clean · webhook idempotent', 'founder@equipseva.in', 'Blocked on external KYC team'),
  ('44444444-4444-4444-4444-444444444444', 'Sri Lanka Pilot', 'International pilot: 3 hospitals in Colombo', now() + interval '60 days', NULL, 'blocked', 'critical', 'No FX payout rails decided', 'Local payment partner, GST/VAT model, Sinhala i18n', 'Payment partner signed · legal entity registered · 1 hospital LOI', 'founder@equipseva.in', 'v0.6 Phase 10'),
  ('55555555-5555-5555-5555-555555555555', 'Founder Web Console v1.0', 'BMC console GA: 60+ routes, audit log, role separation', now() - interval '3 days', now() - interval '3 days', 'launched', 'low', NULL, 'CI green, security headers, RBAC on console actions', 'All Tier-1 routes live · 0 console-only RLS holes · founder-only access', 'founder@equipseva.in', 'Shipped at r1322 milestone');

INSERT INTO public.launch_dependency_status_r2437
  (launch_id, dependency_name, dependency_kind, owner_email, due_at, status, blocker_notes, last_update_at, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Play Store internal track approval', 'team',        'founder@equipseva.in', now() + interval '5 days',  'in_progress', NULL,                                 now(),                          'Bundle uploaded'),
  ('11111111-1111-1111-1111-111111111111', 'Regression smoke on 4 devices',       'team',        'founder@equipseva.in', now() + interval '4 days',  'in_progress', NULL,                                 now() - interval '1 day',       'Pixel + Samsung covered'),
  ('11111111-1111-1111-1111-111111111111', 'GST invoice e-mail dispatch',         'integration', 'founder@equipseva.in', now() + interval '2 days',  'done',        NULL,                                 now() - interval '6 hours',     'Verified via test invoice'),
  ('22222222-2222-2222-2222-222222222222', 'Apollo SSO integration',              'integration', 'cto@apollo.example',   now() + interval '21 days', 'open',        'Awaiting Apollo IdP metadata',       NULL,                           'Kicked off'),
  ('22222222-2222-2222-2222-222222222222', 'Chain RBAC redesign spec',            'team',        'founder@equipseva.in', now() + interval '10 days', 'in_progress', NULL,                                 now() - interval '2 days',      'Draft v2'),
  ('33333333-3333-3333-3333-333333333333', 'Cashfree KYC activation',             'legal',       'kyc@cashfree.example', now() + interval '3 days',  'blocked',     'Cashfree compliance re-verifying',   now() - interval '1 day',       'Escalated'),
  ('33333333-3333-3333-3333-333333333333', 'Payout webhook idempotency tests',    'infra',       'founder@equipseva.in', now() + interval '5 days',  'in_progress', NULL,                                 now() - interval '3 hours',     'Replay harness ready'),
  ('44444444-4444-4444-4444-444444444444', 'SL legal entity registration',        'legal',       'legal@equipseva.in',   now() + interval '45 days', 'open',        'Need local counsel',                 NULL,                           'CS introduced'),
  ('44444444-4444-4444-4444-444444444444', 'Sinhala i18n strings',                'marketing',   'founder@equipseva.in', now() + interval '40 days', 'open',        NULL,                                 NULL,                           'Strings inventory: 312'),
  ('55555555-5555-5555-5555-555555555555', 'Security headers + CSP',              'infra',       'founder@equipseva.in', now() - interval '10 days', 'done',        NULL,                                 now() - interval '10 days',     'Shipped pre-GA');

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_launches_r2437()
RETURNS TABLE (
  id uuid,
  launch_name text,
  status text,
  risk_level text,
  planned_launch_at timestamptz,
  actual_launch_at timestamptz,
  owner_email text,
  open_deps bigint,
  blocked_deps bigint,
  total_deps bigint,
  scope_md text,
  risk_notes text,
  go_no_go_criteria_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    l.launch_name,
    l.status,
    l.risk_level,
    l.planned_launch_at,
    l.actual_launch_at,
    l.owner_email,
    COALESCE(SUM(CASE WHEN d.status IN ('open','in_progress') THEN 1 ELSE 0 END), 0)::bigint AS open_deps,
    COALESCE(SUM(CASE WHEN d.status = 'blocked' THEN 1 ELSE 0 END), 0)::bigint AS blocked_deps,
    COALESCE(COUNT(d.id), 0)::bigint AS total_deps,
    l.scope_md,
    l.risk_notes,
    l.go_no_go_criteria_md
  FROM public.founder_launches_r2437 l
  LEFT JOIN public.launch_dependency_status_r2437 d ON d.launch_id = l.id
  GROUP BY l.id
  ORDER BY
    CASE l.risk_level WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    l.planned_launch_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_launches_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_launches_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_dependencies_r2437()
RETURNS TABLE (
  id uuid,
  launch_id uuid,
  launch_name text,
  dependency_name text,
  dependency_kind text,
  owner_email text,
  due_at timestamptz,
  status text,
  blocker_notes text,
  last_update_at timestamptz,
  days_to_due numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.launch_id,
    l.launch_name,
    d.dependency_name,
    d.dependency_kind,
    d.owner_email,
    d.due_at,
    d.status,
    d.blocker_notes,
    d.last_update_at,
    CASE WHEN d.due_at IS NOT NULL
         THEN ROUND(EXTRACT(EPOCH FROM (d.due_at - now())) / 86400.0, 1)
         ELSE NULL END AS days_to_due
  FROM public.launch_dependency_status_r2437 d
  JOIN public.founder_launches_r2437 l ON l.id = d.launch_id
  ORDER BY
    CASE d.status WHEN 'blocked' THEN 0 WHEN 'open' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'done' THEN 3 ELSE 4 END,
    d.due_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_dependencies_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dependencies_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.blocked_focus_r2437()
RETURNS TABLE (
  launch_id uuid,
  launch_name text,
  risk_level text,
  planned_launch_at timestamptz,
  blocked_count bigint,
  blockers text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id AS launch_id,
    l.launch_name,
    l.risk_level,
    l.planned_launch_at,
    COUNT(d.id)::bigint AS blocked_count,
    string_agg(d.dependency_name || ' (' || COALESCE(d.blocker_notes, 'no notes') || ')', ' | ' ORDER BY d.dependency_name) AS blockers
  FROM public.founder_launches_r2437 l
  JOIN public.launch_dependency_status_r2437 d ON d.launch_id = l.id
  WHERE d.status = 'blocked'
  GROUP BY l.id
  ORDER BY blocked_count DESC, l.planned_launch_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.blocked_focus_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocked_focus_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.at_risk_summary_r2437()
RETURNS TABLE (
  risk_level text,
  launches bigint,
  next_launch_in_days numeric,
  earliest_planned timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.risk_level,
    COUNT(*)::bigint AS launches,
    ROUND(EXTRACT(EPOCH FROM (MIN(l.planned_launch_at) - now())) / 86400.0, 1) AS next_launch_in_days,
    MIN(l.planned_launch_at) AS earliest_planned
  FROM public.founder_launches_r2437 l
  WHERE l.status NOT IN ('launched','cancelled')
  GROUP BY l.risk_level
  ORDER BY
    CASE l.risk_level WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.at_risk_summary_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.at_risk_summary_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.upcoming_launches_r2437()
RETURNS TABLE (
  launch_id uuid,
  launch_name text,
  planned_launch_at timestamptz,
  days_to_launch numeric,
  status text,
  risk_level text,
  open_deps bigint,
  blocked_deps bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id AS launch_id,
    l.launch_name,
    l.planned_launch_at,
    ROUND(EXTRACT(EPOCH FROM (l.planned_launch_at - now())) / 86400.0, 1) AS days_to_launch,
    l.status,
    l.risk_level,
    COALESCE(SUM(CASE WHEN d.status IN ('open','in_progress') THEN 1 ELSE 0 END), 0)::bigint AS open_deps,
    COALESCE(SUM(CASE WHEN d.status = 'blocked' THEN 1 ELSE 0 END), 0)::bigint AS blocked_deps
  FROM public.founder_launches_r2437 l
  LEFT JOIN public.launch_dependency_status_r2437 d ON d.launch_id = l.id
  WHERE l.status NOT IN ('launched','cancelled')
    AND l.planned_launch_at IS NOT NULL
    AND l.planned_launch_at >= now() - interval '7 days'
  GROUP BY l.id
  ORDER BY l.planned_launch_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_launches_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_launches_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.dependency_owner_load_r2437()
RETURNS TABLE (
  owner_email text,
  total_deps bigint,
  open_or_progress bigint,
  blocked bigint,
  done bigint,
  next_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(d.owner_email, '(unassigned)') AS owner_email,
    COUNT(*)::bigint AS total_deps,
    SUM(CASE WHEN d.status IN ('open','in_progress') THEN 1 ELSE 0 END)::bigint AS open_or_progress,
    SUM(CASE WHEN d.status = 'blocked' THEN 1 ELSE 0 END)::bigint AS blocked,
    SUM(CASE WHEN d.status = 'done' THEN 1 ELSE 0 END)::bigint AS done,
    MIN(CASE WHEN d.status IN ('open','in_progress','blocked') THEN d.due_at END) AS next_due_at
  FROM public.launch_dependency_status_r2437 d
  GROUP BY COALESCE(d.owner_email, '(unassigned)')
  ORDER BY blocked DESC, open_or_progress DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dependency_owner_load_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dependency_owner_load_r2437() TO authenticated;

CREATE OR REPLACE FUNCTION public.launch_status_funnel_r2437()
RETURNS TABLE (
  status text,
  launches bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.founder_launches_r2437;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT
    l.status,
    COUNT(*)::bigint AS launches,
    ROUND((COUNT(*)::numeric / total::numeric) * 100.0, 1) AS pct
  FROM public.founder_launches_r2437 l
  GROUP BY l.status
  ORDER BY
    CASE l.status
      WHEN 'blocked' THEN 0
      WHEN 'at_risk' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'planned' THEN 3
      WHEN 'delayed' THEN 4
      WHEN 'launched' THEN 5
      WHEN 'cancelled' THEN 6
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.launch_status_funnel_r2437() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.launch_status_funnel_r2437() TO authenticated;

