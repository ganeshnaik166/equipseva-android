-- Round 2521 — Founder monthly strategic debt inventory
-- Tables:
--   founder_strategic_debt_r2521
--   strategic_debt_pay_off_plans_r2521
-- RPCs:
--   list_debt_inventory_r2521
--   list_pay_off_plans_r2521
--   top_priority_debt_r2521
--   kind_breakdown_r2521
--   cost_of_carry_summary_r2521
--   monthly_pay_off_trend_r2521
--   owner_load_r2521

BEGIN;

-- =====================================================================
-- TABLE: founder_strategic_debt_r2521
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_strategic_debt_r2521 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_title text NOT NULL,
  debt_kind text NOT NULL CHECK (debt_kind IN ('tech','process','people','legal','financial','customer')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  age_days integer NOT NULL DEFAULT 0,
  cost_to_fix_rupees bigint NOT NULL DEFAULT 0,
  cost_of_carry_per_month_rupees bigint NOT NULL DEFAULT 0,
  pay_off_priority integer NOT NULL DEFAULT 3 CHECK (pay_off_priority BETWEEN 1 AND 5),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','scheduled','in_progress','paid_off','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_debt_r2521 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_debt_r2521;
CREATE POLICY founder_all ON public.founder_strategic_debt_r2521
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE: strategic_debt_pay_off_plans_r2521
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.strategic_debt_pay_off_plans_r2521 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id uuid NOT NULL REFERENCES public.founder_strategic_debt_r2521(id) ON DELETE CASCADE,
  planned_at timestamptz NOT NULL DEFAULT now(),
  plan_md text,
  target_completion_at timestamptz,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done','dropped')),
  realized_savings_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.strategic_debt_pay_off_plans_r2521 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.strategic_debt_pay_off_plans_r2521;
CREATE POLICY founder_all ON public.strategic_debt_pay_off_plans_r2521
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $seed$
DECLARE
  v_debt1 uuid;
  v_debt2 uuid;
  v_debt3 uuid;
  v_debt4 uuid;
  v_debt5 uuid;
BEGIN
  INSERT INTO public.founder_strategic_debt_r2521
    (debt_title, debt_kind, opened_at, age_days, cost_to_fix_rupees, cost_of_carry_per_month_rupees, pay_off_priority, owner_email, status, notes)
  VALUES
    ('Legacy AMC reconciliation script', 'tech', '2026-01-10'::timestamptz, 164, 250000, 45000, 1, 'eng-lead@equipseva.in', 'in_progress', 'Manual SQL each month-end; needs cron + audit log')
  RETURNING id INTO v_debt1;

  INSERT INTO public.founder_strategic_debt_r2521
    (debt_title, debt_kind, opened_at, age_days, cost_to_fix_rupees, cost_of_carry_per_month_rupees, pay_off_priority, owner_email, status, notes)
  VALUES
    ('Engineer onboarding lacks shadowing SOP', 'process', '2026-02-15'::timestamptz, 128, 80000, 22000, 2, 'ops-lead@equipseva.in', 'scheduled', 'Causes 3x ramp-up time; add 5-job shadow checklist')
  RETURNING id INTO v_debt2;

  INSERT INTO public.founder_strategic_debt_r2521
    (debt_title, debt_kind, opened_at, age_days, cost_to_fix_rupees, cost_of_carry_per_month_rupees, pay_off_priority, owner_email, status, notes)
  VALUES
    ('Missing DPDP data-purge automation', 'legal', '2026-03-01'::timestamptz, 114, 175000, 60000, 1, 'legal@equipseva.in', 'open', 'Regulatory exposure; 30-day grievance window not enforced in code')
  RETURNING id INTO v_debt3;

  INSERT INTO public.founder_strategic_debt_r2521
    (debt_title, debt_kind, opened_at, age_days, cost_to_fix_rupees, cost_of_carry_per_month_rupees, pay_off_priority, owner_email, status, notes)
  VALUES
    ('Spare-part vendor float settlement lag', 'financial', '2025-12-20'::timestamptz, 185, 320000, 95000, 1, 'finance@equipseva.in', 'in_progress', 'Carry ~95k/month in vendor float; need T+3 settlement')
  RETURNING id INTO v_debt4;

  INSERT INTO public.founder_strategic_debt_r2521
    (debt_title, debt_kind, opened_at, age_days, cost_to_fix_rupees, cost_of_carry_per_month_rupees, pay_off_priority, owner_email, status, notes)
  VALUES
    ('Hospital admin churn — no CSM ownership map', 'customer', '2026-04-10'::timestamptz, 74, 120000, 38000, 3, 'cs-lead@equipseva.in', 'open', 'Top-30 hospitals lack assigned CSM; renewal risk')
  RETURNING id INTO v_debt5;

  -- pay-off plans
  INSERT INTO public.strategic_debt_pay_off_plans_r2521
    (debt_id, planned_at, plan_md, target_completion_at, status, realized_savings_rupees, owner_email, notes)
  VALUES
    (v_debt1, '2026-05-01'::timestamptz, '## Plan\n- Move SQL to pg_cron\n- Emit audit rows\n- 2-week ETA', '2026-07-15'::timestamptz, 'in_progress', 0, 'eng-lead@equipseva.in', 'On track');

  INSERT INTO public.strategic_debt_pay_off_plans_r2521
    (debt_id, planned_at, plan_md, target_completion_at, status, realized_savings_rupees, owner_email, notes)
  VALUES
    (v_debt2, '2026-06-01'::timestamptz, '## Plan\n- Draft SOP\n- 5-job shadow checklist\n- Pilot with cohort-3', '2026-08-01'::timestamptz, 'planned', 0, 'ops-lead@equipseva.in', 'Awaiting ops bandwidth');

  INSERT INTO public.strategic_debt_pay_off_plans_r2521
    (debt_id, planned_at, plan_md, target_completion_at, status, realized_savings_rupees, owner_email, notes)
  VALUES
    (v_debt4, '2026-04-15'::timestamptz, '## Plan\n- T+3 settlement via Cashfree payouts\n- Vendor cohort A pilot', '2026-06-30'::timestamptz, 'done', 280000, 'finance@equipseva.in', 'Saved 280k cumulative in float');

  INSERT INTO public.strategic_debt_pay_off_plans_r2521
    (debt_id, planned_at, plan_md, target_completion_at, status, realized_savings_rupees, owner_email, notes)
  VALUES
    (v_debt3, '2026-06-10'::timestamptz, '## Plan\n- DPDP cron job\n- Grievance routing\n- Quarterly audit', '2026-09-15'::timestamptz, 'planned', 0, 'legal@equipseva.in', 'High regulatory priority');
END
$seed$;

-- =====================================================================
-- RPC: list_debt_inventory_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_debt_inventory_r2521()
RETURNS TABLE (
  id uuid,
  debt_title text,
  debt_kind text,
  opened_at timestamptz,
  age_days integer,
  cost_to_fix_rupees bigint,
  cost_of_carry_per_month_rupees bigint,
  pay_off_priority integer,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.debt_title, d.debt_kind, d.opened_at, d.age_days,
           d.cost_to_fix_rupees, d.cost_of_carry_per_month_rupees,
           d.pay_off_priority, d.owner_email, d.status, d.notes
    FROM public.founder_strategic_debt_r2521 d
    ORDER BY d.pay_off_priority ASC, d.cost_of_carry_per_month_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_debt_inventory_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_debt_inventory_r2521() TO authenticated;

-- =====================================================================
-- RPC: list_pay_off_plans_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_pay_off_plans_r2521()
RETURNS TABLE (
  id uuid,
  debt_id uuid,
  debt_title text,
  planned_at timestamptz,
  target_completion_at timestamptz,
  status text,
  realized_savings_rupees bigint,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.debt_id, d.debt_title, p.planned_at, p.target_completion_at,
           p.status, p.realized_savings_rupees, p.owner_email, p.notes
    FROM public.strategic_debt_pay_off_plans_r2521 p
    JOIN public.founder_strategic_debt_r2521 d ON d.id = p.debt_id
    ORDER BY p.planned_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pay_off_plans_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pay_off_plans_r2521() TO authenticated;

-- =====================================================================
-- RPC: top_priority_debt_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_priority_debt_r2521()
RETURNS TABLE (
  id uuid,
  debt_title text,
  debt_kind text,
  pay_off_priority integer,
  cost_to_fix_rupees bigint,
  cost_of_carry_per_month_rupees bigint,
  age_days integer,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.debt_title, d.debt_kind, d.pay_off_priority,
           d.cost_to_fix_rupees, d.cost_of_carry_per_month_rupees,
           d.age_days, d.status, d.owner_email
    FROM public.founder_strategic_debt_r2521 d
    WHERE d.status NOT IN ('paid_off','dropped')
    ORDER BY d.pay_off_priority ASC, d.cost_of_carry_per_month_rupees DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_priority_debt_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_priority_debt_r2521() TO authenticated;

-- =====================================================================
-- RPC: kind_breakdown_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2521()
RETURNS TABLE (
  debt_kind text,
  open_count bigint,
  total_count bigint,
  total_cost_to_fix bigint,
  total_carry_per_month bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.debt_kind,
           SUM(CASE WHEN d.status NOT IN ('paid_off','dropped') THEN 1 ELSE 0 END)::bigint AS open_count,
           COUNT(*)::bigint AS total_count,
           COALESCE(SUM(d.cost_to_fix_rupees),0)::bigint AS total_cost_to_fix,
           COALESCE(SUM(CASE WHEN d.status NOT IN ('paid_off','dropped') THEN d.cost_of_carry_per_month_rupees ELSE 0 END),0)::bigint AS total_carry_per_month
    FROM public.founder_strategic_debt_r2521 d
    GROUP BY d.debt_kind
    ORDER BY total_carry_per_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2521() TO authenticated;

-- =====================================================================
-- RPC: cost_of_carry_summary_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.cost_of_carry_summary_r2521()
RETURNS TABLE (
  open_debt_count bigint,
  total_cost_to_fix bigint,
  monthly_carry bigint,
  annualized_carry bigint,
  realized_savings_to_date bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::bigint FROM public.founder_strategic_debt_r2521 WHERE status NOT IN ('paid_off','dropped')),
      (SELECT COALESCE(SUM(cost_to_fix_rupees),0)::bigint FROM public.founder_strategic_debt_r2521 WHERE status NOT IN ('paid_off','dropped')),
      (SELECT COALESCE(SUM(cost_of_carry_per_month_rupees),0)::bigint FROM public.founder_strategic_debt_r2521 WHERE status NOT IN ('paid_off','dropped')),
      (SELECT COALESCE(SUM(cost_of_carry_per_month_rupees),0)::bigint * 12 FROM public.founder_strategic_debt_r2521 WHERE status NOT IN ('paid_off','dropped')),
      (SELECT COALESCE(SUM(realized_savings_rupees),0)::bigint FROM public.strategic_debt_pay_off_plans_r2521 WHERE status = 'done');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cost_of_carry_summary_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_of_carry_summary_r2521() TO authenticated;

-- =====================================================================
-- RPC: monthly_pay_off_trend_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_pay_off_trend_r2521()
RETURNS TABLE (
  month_bucket text,
  plans_planned bigint,
  plans_done bigint,
  realized_savings bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      to_char(date_trunc('month', p.planned_at), 'YYYY-MM') AS month_bucket,
      COUNT(*)::bigint AS plans_planned,
      SUM(CASE WHEN p.status = 'done' THEN 1 ELSE 0 END)::bigint AS plans_done,
      COALESCE(SUM(CASE WHEN p.status = 'done' THEN p.realized_savings_rupees ELSE 0 END),0)::bigint AS realized_savings
    FROM public.strategic_debt_pay_off_plans_r2521 p
    GROUP BY date_trunc('month', p.planned_at)
    ORDER BY month_bucket DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pay_off_trend_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pay_off_trend_r2521() TO authenticated;

-- =====================================================================
-- RPC: owner_load_r2521
-- =====================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2521()
RETURNS TABLE (
  owner_email text,
  open_debts bigint,
  in_progress_plans bigint,
  monthly_carry bigint,
  realized_savings bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COALESCE(d.owner_email, 'unassigned') AS owner_email,
      SUM(CASE WHEN d.status NOT IN ('paid_off','dropped') THEN 1 ELSE 0 END)::bigint AS open_debts,
      COALESCE((
        SELECT COUNT(*)::bigint
        FROM public.strategic_debt_pay_off_plans_r2521 p
        WHERE p.owner_email = d.owner_email AND p.status = 'in_progress'
      ), 0)::bigint AS in_progress_plans,
      COALESCE(SUM(CASE WHEN d.status NOT IN ('paid_off','dropped') THEN d.cost_of_carry_per_month_rupees ELSE 0 END),0)::bigint AS monthly_carry,
      COALESCE((
        SELECT SUM(p.realized_savings_rupees)::bigint
        FROM public.strategic_debt_pay_off_plans_r2521 p
        WHERE p.owner_email = d.owner_email AND p.status = 'done'
      ), 0)::bigint AS realized_savings
    FROM public.founder_strategic_debt_r2521 d
    GROUP BY d.owner_email
    ORDER BY monthly_carry DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2521() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2521() TO authenticated;

