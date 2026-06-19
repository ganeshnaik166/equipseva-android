BEGIN;
-- r1351 — Founder quarterly headcount plan + budget tracker.
-- Internal hiring-budget surface. Tracks role-by-role hiring intent
-- per quarter (target_count, target_filled_by, monthly budget rupees,
-- status planned→recruiting→offer_out→hired, priority p0/p1/p2/p3).
-- Strictly founder-only. Not customer-facing.

-- ============================================================================
-- TABLE: founder_headcount_plan_roles
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_headcount_plan_roles (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label            text NOT NULL,
  role_title               text NOT NULL,
  role_kind                text CHECK (role_kind IN (
                             'engineer_field','engineer_software','operations',
                             'sales','marketing','finance','founder_admin','vertical_specialist')),
  target_count             int NOT NULL DEFAULT 1,
  target_filled_by         date,
  budget_monthly_rupees    numeric,
  status                   text NOT NULL DEFAULT 'planned' CHECK (status IN (
                             'planned','recruiting','offer_out','hired','cancelled','deferred')),
  priority                 text NOT NULL DEFAULT 'p1' CHECK (priority IN ('p0','p1','p2','p3')),
  justification            text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quarter_label, role_title)
);
COMMENT ON TABLE public.founder_headcount_plan_roles IS
  'Founder-only quarterly hiring plan + budget. Not customer-facing.';

CREATE INDEX IF NOT EXISTS idx_fhcp_quarter   ON public.founder_headcount_plan_roles (quarter_label, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhcp_status    ON public.founder_headcount_plan_roles (status, target_filled_by);
CREATE INDEX IF NOT EXISTS idx_fhcp_role_kind ON public.founder_headcount_plan_roles (role_kind);
CREATE INDEX IF NOT EXISTS idx_fhcp_priority  ON public.founder_headcount_plan_roles (priority, status);

ALTER TABLE public.founder_headcount_plan_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fhcp_no_direct ON public.founder_headcount_plan_roles;
CREATE POLICY fhcp_no_direct ON public.founder_headcount_plan_roles FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_headcount_plan_roles FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC: founder_headcount_plan_summary — 14 KPIs (optional quarter filter)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_headcount_plan_summary(text);
CREATE OR REPLACE FUNCTION public.founder_headcount_plan_summary(p_quarter text DEFAULT NULL)
RETURNS TABLE (
  latest_quarter                       text,
  total_planned_roles                  bigint,
  total_recruiting                     bigint,
  total_offer_out                      bigint,
  total_hired                          bigint,
  total_filled_pct                     numeric,
  total_planned_monthly_budget_rupees  numeric,
  total_actual_monthly_budget_rupees   numeric,
  deferred_count                       bigint,
  cancelled_count                      bigint,
  overdue_target_filled_count          bigint,
  top_role_kind                        text,
  top_role_kind_count                  bigint,
  days_until_quarter_end               int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_q             text;
  v_total         bigint;
  v_hired         bigint;
  v_top_kind      text;
  v_top_kind_n    bigint;
  v_quarter_end   date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_quarter IS NULL OR length(trim(p_quarter)) = 0 THEN
    SELECT quarter_label
      INTO v_q
      FROM public.founder_headcount_plan_roles
      ORDER BY created_at DESC
      LIMIT 1;
  ELSE
    v_q := trim(p_quarter);
  END IF;

  SELECT count(*) INTO v_total
    FROM public.founder_headcount_plan_roles
    WHERE v_q IS NULL OR quarter_label = v_q;

  SELECT count(*) INTO v_hired
    FROM public.founder_headcount_plan_roles
    WHERE (v_q IS NULL OR quarter_label = v_q) AND status = 'hired';

  SELECT role_kind, count(*)
    INTO v_top_kind, v_top_kind_n
    FROM public.founder_headcount_plan_roles
    WHERE (v_q IS NULL OR quarter_label = v_q) AND role_kind IS NOT NULL
    GROUP BY role_kind
    ORDER BY count(*) DESC NULLS LAST
    LIMIT 1;

  -- best-effort quarter-end estimate: parse "YYYYQn" suffix, else 90 days ahead
  v_quarter_end := CASE
    WHEN v_q ~ '^[0-9]{4}Q[1-4]$' THEN
      (substring(v_q FROM 1 FOR 4) || '-' ||
        CASE substring(v_q FROM 6 FOR 1)
          WHEN '1' THEN '03-31'
          WHEN '2' THEN '06-30'
          WHEN '3' THEN '09-30'
          WHEN '4' THEN '12-31'
        END
      )::date
    ELSE (now() + interval '90 days')::date
  END;

  RETURN QUERY
  SELECT
    COALESCE(v_q, 'n/a'),
    v_total,
    (SELECT count(*) FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q) AND status = 'recruiting'),
    (SELECT count(*) FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q) AND status = 'offer_out'),
    v_hired,
    CASE WHEN v_total = 0 THEN 0
         ELSE ROUND(100.0 * v_hired / v_total, 2)
    END,
    COALESCE((SELECT SUM(budget_monthly_rupees * target_count)
      FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q)
        AND status NOT IN ('cancelled','deferred')), 0),
    COALESCE((SELECT SUM(budget_monthly_rupees * target_count)
      FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q)
        AND status = 'hired'), 0),
    (SELECT count(*) FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q) AND status = 'deferred'),
    (SELECT count(*) FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q) AND status = 'cancelled'),
    (SELECT count(*) FROM public.founder_headcount_plan_roles
      WHERE (v_q IS NULL OR quarter_label = v_q)
        AND target_filled_by IS NOT NULL
        AND target_filled_by < CURRENT_DATE
        AND status NOT IN ('hired','cancelled')),
    COALESCE(v_top_kind, 'n/a'),
    COALESCE(v_top_kind_n, 0::bigint),
    GREATEST((v_quarter_end - CURRENT_DATE)::int, 0);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_headcount_plan_summary(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_headcount_plan_summary(text) TO authenticated;

-- ============================================================================
-- RPC: founder_headcount_plan_roles_recent — role ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_headcount_plan_roles_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_headcount_plan_roles_recent(
  p_quarter text DEFAULT NULL,
  p_limit   int  DEFAULT 50
) RETURNS TABLE (
  id                      uuid,
  quarter_label           text,
  role_title              text,
  role_kind               text,
  target_count            int,
  target_filled_by        date,
  budget_monthly_rupees   numeric,
  status                  text,
  priority                text,
  justification           text,
  days_to_target          int,
  is_overdue              boolean,
  created_at              timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_q text := NULLIF(trim(COALESCE(p_quarter, '')), '');
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.quarter_label,
    r.role_title,
    r.role_kind,
    r.target_count,
    r.target_filled_by,
    r.budget_monthly_rupees,
    r.status,
    r.priority,
    r.justification,
    CASE WHEN r.target_filled_by IS NULL THEN NULL
         ELSE (r.target_filled_by - CURRENT_DATE)::int END,
    (r.target_filled_by IS NOT NULL
      AND r.target_filled_by < CURRENT_DATE
      AND r.status NOT IN ('hired','cancelled')),
    r.created_at
  FROM public.founder_headcount_plan_roles r
  WHERE v_q IS NULL OR r.quarter_label = v_q
  ORDER BY
    CASE r.priority WHEN 'p0' THEN 1 WHEN 'p1' THEN 2 WHEN 'p2' THEN 3 WHEN 'p3' THEN 4 ELSE 5 END,
    CASE r.status
      WHEN 'offer_out'  THEN 1
      WHEN 'recruiting' THEN 2
      WHEN 'planned'    THEN 3
      WHEN 'hired'      THEN 4
      WHEN 'deferred'   THEN 5
      WHEN 'cancelled'  THEN 6
    END,
    r.target_filled_by NULLS LAST,
    r.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_headcount_plan_roles_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_headcount_plan_roles_recent(text, int) TO authenticated;

-- ============================================================================
-- WRITE RPC: log_founder_headcount_register_role
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_headcount_register_role(text, text, text, int, date, numeric, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_headcount_register_role(
  p_quarter_label         text,
  p_role_title            text,
  p_role_kind             text,
  p_target_count          int,
  p_target_filled_by      date,
  p_budget_monthly_rupees numeric,
  p_priority              text,
  p_justification         text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_quarter_label IS NULL OR length(trim(p_quarter_label)) = 0 THEN
    RAISE EXCEPTION 'quarter_label required' USING ERRCODE='22023';
  END IF;
  IF p_role_title IS NULL OR length(trim(p_role_title)) = 0 THEN
    RAISE EXCEPTION 'role_title required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_headcount_plan_roles (
    quarter_label, role_title, role_kind, target_count,
    target_filled_by, budget_monthly_rupees, priority, justification
  )
  VALUES (
    trim(p_quarter_label),
    trim(p_role_title),
    p_role_kind,
    GREATEST(COALESCE(p_target_count, 1), 1),
    p_target_filled_by,
    p_budget_monthly_rupees,
    COALESCE(p_priority, 'p1'),
    NULLIF(trim(COALESCE(p_justification, '')), '')
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_headcount_register_role(text, text, text, int, date, numeric, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_headcount_register_role(text, text, text, int, date, numeric, text, text) TO authenticated;

-- ============================================================================
-- WRITE RPC: log_founder_headcount_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_headcount_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_headcount_status(
  p_id         uuid,
  p_new_status text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_status NOT IN ('planned','recruiting','offer_out','hired','cancelled','deferred') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_headcount_plan_roles SET
    status     = p_new_status,
    updated_at = now()
  WHERE id = p_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_headcount_status(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_headcount_status(uuid, text) TO authenticated;

COMMIT;