-- Round 2556: customer-quarterly-budget-cycle-discount-ask
-- Hospital × quarter × budget tightening × discount ask × decision × ARR impact

BEGIN;

-- ============================================================================
-- TABLE 1: customer_quarterly_budget_asks_r2556
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_quarterly_budget_asks_r2556 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  budget_tightening_kind text NOT NULL CHECK (budget_tightening_kind IN ('none','mild','moderate','severe')),
  discount_asked_pct numeric(6,2) NOT NULL DEFAULT 0,
  discount_given_pct numeric(6,2) NOT NULL DEFAULT 0,
  decision_kind text NOT NULL CHECK (decision_kind IN ('approve','reject','counter_offer','postpone')),
  arr_impact_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_quarterly_budget_asks_r2556 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_quarterly_budget_asks_r2556;
CREATE POLICY founder_all ON public.customer_quarterly_budget_asks_r2556
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: budget_cycle_decision_log_r2556
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.budget_cycle_decision_log_r2556 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ask_id uuid REFERENCES public.customer_quarterly_budget_asks_r2556(id) ON DELETE CASCADE,
  decided_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL,
  founder_approval_required boolean NOT NULL DEFAULT false,
  founder_approved boolean NOT NULL DEFAULT false,
  summary_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.budget_cycle_decision_log_r2556 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.budget_cycle_decision_log_r2556;
CREATE POLICY founder_all ON public.budget_cycle_decision_log_r2556
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_hospital uuid;
  v_ask1 uuid;
  v_ask2 uuid;
  v_ask3 uuid;
  v_ask4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' LIMIT 1;

  INSERT INTO public.customer_quarterly_budget_asks_r2556
    (hospital_user_id, quarter_label, budget_tightening_kind, discount_asked_pct, discount_given_pct, decision_kind, arr_impact_rupees, owner_email, status, notes)
  VALUES (v_hospital, 'Q1-2026', 'mild', 8.00, 5.00, 'counter_offer', 240000, 'founder@equipseva.in', 'closed', 'CFO pushed for cut; settled at 5%')
  RETURNING id INTO v_ask1;

  INSERT INTO public.customer_quarterly_budget_asks_r2556
    (hospital_user_id, quarter_label, budget_tightening_kind, discount_asked_pct, discount_given_pct, decision_kind, arr_impact_rupees, owner_email, status, notes)
  VALUES (v_hospital, 'Q2-2026', 'severe', 20.00, 0.00, 'reject', 0, 'founder@equipseva.in', 'closed', 'Hospital threatened churn; held line; renewed at full price')
  RETURNING id INTO v_ask2;

  INSERT INTO public.customer_quarterly_budget_asks_r2556
    (hospital_user_id, quarter_label, budget_tightening_kind, discount_asked_pct, discount_given_pct, decision_kind, arr_impact_rupees, owner_email, status, notes)
  VALUES (v_hospital, 'Q3-2026', 'moderate', 12.00, 10.00, 'approve', 180000, 'sales@equipseva.in', 'in_progress', 'Multi-year extension in exchange for 10% cut')
  RETURNING id INTO v_ask3;

  INSERT INTO public.customer_quarterly_budget_asks_r2556
    (hospital_user_id, quarter_label, budget_tightening_kind, discount_asked_pct, discount_given_pct, decision_kind, arr_impact_rupees, owner_email, status, notes)
  VALUES (v_hospital, 'Q4-2026', 'none', 0.00, 0.00, 'postpone', 60000, 'sales@equipseva.in', 'open', 'No tightening; deferred discussion to Q1-2027')
  RETURNING id INTO v_ask4;

  INSERT INTO public.budget_cycle_decision_log_r2556 (ask_id, decided_at, decision_kind, founder_approval_required, founder_approved, summary_md, owner_email, notes)
  VALUES (v_ask1, now() - interval '60 days', 'counter_offer', true, true, '# Counter at 5%
- CFO asked 8%, we held 5%
- 12 month commit', 'founder@equipseva.in', 'Logged in CRM');

  INSERT INTO public.budget_cycle_decision_log_r2556 (ask_id, decided_at, decision_kind, founder_approval_required, founder_approved, summary_md, owner_email, notes)
  VALUES (v_ask2, now() - interval '30 days', 'reject', true, true, '# Hold the line
- Severe tightening claim
- Threat of churn; we did not budge', 'founder@equipseva.in', 'Renewed at full price two weeks later');

  INSERT INTO public.budget_cycle_decision_log_r2556 (ask_id, decided_at, decision_kind, founder_approval_required, founder_approved, summary_md, owner_email, notes)
  VALUES (v_ask3, now() - interval '7 days', 'approve', true, true, '# 10% in exchange for 24-month
- Locks ARR
- Better than churn risk', 'founder@equipseva.in', 'Contract amendment drafted');

  INSERT INTO public.budget_cycle_decision_log_r2556 (ask_id, decided_at, decision_kind, founder_approval_required, founder_approved, summary_md, owner_email, notes)
  VALUES (v_ask4, now() - interval '1 day', 'postpone', false, false, '# Postpone to next quarter
- No active pressure
- Revisit Jan-2027', 'sales@equipseva.in', 'Calendar reminder set');
END
$seed$;

-- ============================================================================
-- RPC 1: list_asks_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_asks_r2556()
RETURNS TABLE(
  id uuid,
  quarter_label text,
  budget_tightening_kind text,
  discount_asked_pct numeric,
  discount_given_pct numeric,
  decision_kind text,
  arr_impact_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.quarter_label, a.budget_tightening_kind, a.discount_asked_pct, a.discount_given_pct,
         a.decision_kind, a.arr_impact_rupees, a.owner_email, a.status, a.notes, a.created_at
  FROM public.customer_quarterly_budget_asks_r2556 a
  ORDER BY a.created_at DESC NULLS LAST
  LIMIT 200;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_asks_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_asks_r2556() TO authenticated;

-- ============================================================================
-- RPC 2: list_decision_log_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_decision_log_r2556()
RETURNS TABLE(
  id uuid,
  ask_id uuid,
  decided_at timestamptz,
  decision_kind text,
  founder_approval_required boolean,
  founder_approved boolean,
  summary_md text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.ask_id, l.decided_at, l.decision_kind, l.founder_approval_required,
         l.founder_approved, l.summary_md, l.owner_email, l.notes
  FROM public.budget_cycle_decision_log_r2556 l
  ORDER BY l.decided_at DESC NULLS LAST
  LIMIT 200;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_decision_log_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_log_r2556() TO authenticated;

-- ============================================================================
-- RPC 3: top_arr_impact_focus_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_arr_impact_focus_r2556()
RETURNS TABLE(
  id uuid,
  quarter_label text,
  budget_tightening_kind text,
  decision_kind text,
  arr_impact_rupees bigint,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.quarter_label, a.budget_tightening_kind, a.decision_kind,
         a.arr_impact_rupees, a.status, a.owner_email
  FROM public.customer_quarterly_budget_asks_r2556 a
  ORDER BY a.arr_impact_rupees DESC NULLS LAST
  LIMIT 50;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_arr_impact_focus_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_impact_focus_r2556() TO authenticated;

-- ============================================================================
-- RPC 4: budget_tightening_breakdown_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.budget_tightening_breakdown_r2556()
RETURNS TABLE(
  budget_tightening_kind text,
  ask_count bigint,
  avg_discount_asked_pct numeric,
  avg_discount_given_pct numeric,
  total_arr_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.budget_tightening_kind,
         count(*)::bigint AS ask_count,
         round(avg(a.discount_asked_pct), 2) AS avg_discount_asked_pct,
         round(avg(a.discount_given_pct), 2) AS avg_discount_given_pct,
         coalesce(sum(a.arr_impact_rupees), 0)::bigint AS total_arr_impact_rupees
  FROM public.customer_quarterly_budget_asks_r2556 a
  GROUP BY a.budget_tightening_kind
  ORDER BY total_arr_impact_rupees DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.budget_tightening_breakdown_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_tightening_breakdown_r2556() TO authenticated;

-- ============================================================================
-- RPC 5: decision_kind_summary_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.decision_kind_summary_r2556()
RETURNS TABLE(
  decision_kind text,
  ask_count bigint,
  total_arr_impact_rupees bigint,
  avg_discount_given_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.decision_kind,
         count(*)::bigint AS ask_count,
         coalesce(sum(a.arr_impact_rupees), 0)::bigint AS total_arr_impact_rupees,
         round(avg(a.discount_given_pct), 2) AS avg_discount_given_pct
  FROM public.customer_quarterly_budget_asks_r2556 a
  GROUP BY a.decision_kind
  ORDER BY ask_count DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_summary_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_summary_r2556() TO authenticated;

-- ============================================================================
-- RPC 6: quarterly_ask_trend_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.quarterly_ask_trend_r2556()
RETURNS TABLE(
  quarter_label text,
  ask_count bigint,
  avg_discount_asked_pct numeric,
  avg_discount_given_pct numeric,
  total_arr_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.quarter_label,
         count(*)::bigint AS ask_count,
         round(avg(a.discount_asked_pct), 2) AS avg_discount_asked_pct,
         round(avg(a.discount_given_pct), 2) AS avg_discount_given_pct,
         coalesce(sum(a.arr_impact_rupees), 0)::bigint AS total_arr_impact_rupees
  FROM public.customer_quarterly_budget_asks_r2556 a
  GROUP BY a.quarter_label
  ORDER BY a.quarter_label ASC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_ask_trend_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_ask_trend_r2556() TO authenticated;

-- ============================================================================
-- RPC 7: founder_approval_pipeline_r2556
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_approval_pipeline_r2556()
RETURNS TABLE(
  id uuid,
  ask_id uuid,
  decided_at timestamptz,
  decision_kind text,
  founder_approval_required boolean,
  founder_approved boolean,
  owner_email text,
  summary_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.ask_id, l.decided_at, l.decision_kind, l.founder_approval_required,
         l.founder_approved, l.owner_email, l.summary_md
  FROM public.budget_cycle_decision_log_r2556 l
  WHERE l.founder_approval_required = true
  ORDER BY l.decided_at DESC NULLS LAST
  LIMIT 50;
END
$$;
REVOKE EXECUTE ON FUNCTION public.founder_approval_pipeline_r2556() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_approval_pipeline_r2556() TO authenticated;

