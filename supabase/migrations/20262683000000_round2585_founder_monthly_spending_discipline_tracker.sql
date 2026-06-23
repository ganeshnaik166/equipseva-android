-- Round 2585: founder-monthly-spending-discipline-tracker
-- Month x discretionary x required x debt-pay x savings x budget breach x correction

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_monthly_spending_r2585 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  discretionary_rupees bigint NOT NULL DEFAULT 0,
  required_rupees bigint NOT NULL DEFAULT 0,
  debt_payment_rupees bigint NOT NULL DEFAULT 0,
  savings_rupees bigint NOT NULL DEFAULT 0,
  budget_breach boolean NOT NULL DEFAULT false,
  breach_kind text NOT NULL DEFAULT 'none'
    CHECK (breach_kind IN ('none','discretionary','required','debt_skipped','savings_skipped')),
  correction_action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring'
    CHECK (status IN ('monitoring','in_review','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.spending_correction_actions_r2585 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spend_id uuid NOT NULL REFERENCES public.founder_monthly_spending_r2585(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL
    CHECK (action_kind IN ('reduce_discretionary','automate_savings','refi_debt','cut_subscription','income_boost')),
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.founder_monthly_spending_r2585 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spending_correction_actions_r2585 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_monthly_spending_r2585;
CREATE POLICY founder_all ON public.founder_monthly_spending_r2585
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.spending_correction_actions_r2585;
CREATE POLICY founder_all ON public.spending_correction_actions_r2585
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.founder_monthly_spending_r2585
  (month_label, discretionary_rupees, required_rupees, debt_payment_rupees, savings_rupees, budget_breach, breach_kind, correction_action_md, owner_email, status, notes)
VALUES
  ('2026-02', 45000, 180000, 60000, 80000, false, 'none', 'Budget held; carry savings forward.', 'founder@equipseva.in', 'closed', 'Clean month after Jan tightening.'),
  ('2026-03', 92000, 210000, 60000, 30000, true, 'discretionary', 'Trim dining and SaaS by 40 percent next cycle.', 'founder@equipseva.in', 'in_review', 'Travel for hospital pilot blew discretionary.'),
  ('2026-04', 38000, 245000, 60000, 70000, true, 'required', 'Renegotiate landlord and insurance premiums.', 'founder@equipseva.in', 'in_review', 'Office lease hike plus medical insurance renewal.'),
  ('2026-05', 55000, 195000, 0, 90000, true, 'debt_skipped', 'Restart EMI; route bonus to principal.', 'founder@equipseva.in', 'monitoring', 'Skipped car loan EMI to fund payroll.'),
  ('2026-06', 40000, 200000, 60000, 0, true, 'savings_skipped', 'Automate ten percent sweep on payday.', 'founder@equipseva.in', 'monitoring', 'Zero savings this month; runway tightened.');

INSERT INTO public.spending_correction_actions_r2585
  (spend_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'reduce_discretionary', 'positive', 'founder@equipseva.in', 'done',
       'Cancelled 4 SaaS subscriptions worth 18000 rupees per month.'
FROM public.founder_monthly_spending_r2585 WHERE month_label = '2026-03';

INSERT INTO public.spending_correction_actions_r2585
  (spend_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'cut_subscription', 'neutral', 'founder@equipseva.in', 'in_progress',
       'Negotiating insurance premium reduction with broker.'
FROM public.founder_monthly_spending_r2585 WHERE month_label = '2026-04';

INSERT INTO public.spending_correction_actions_r2585
  (spend_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'refi_debt', 'pending', 'founder@equipseva.in', 'open',
       'Exploring 9 percent car loan refi from current 11 percent.'
FROM public.founder_monthly_spending_r2585 WHERE month_label = '2026-05';

INSERT INTO public.spending_correction_actions_r2585
  (spend_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'automate_savings', 'positive', 'founder@equipseva.in', 'done',
       'Set up standing instruction: 10 percent of revenue auto-sweeps on day 1.'
FROM public.founder_monthly_spending_r2585 WHERE month_label = '2026-06';

INSERT INTO public.spending_correction_actions_r2585
  (spend_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'income_boost', 'pending', 'founder@equipseva.in', 'in_progress',
       'Signed 2 AMC contracts to lift monthly recurring revenue by 45000 rupees.'
FROM public.founder_monthly_spending_r2585 WHERE month_label = '2026-06';

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_spending_r2585()
RETURNS TABLE (
  id uuid,
  month_label text,
  discretionary_rupees bigint,
  required_rupees bigint,
  debt_payment_rupees bigint,
  savings_rupees bigint,
  budget_breach boolean,
  breach_kind text,
  status text,
  owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.month_label, s.discretionary_rupees, s.required_rupees,
         s.debt_payment_rupees, s.savings_rupees, s.budget_breach, s.breach_kind,
         s.status, s.owner_email, s.created_at
  FROM public.founder_monthly_spending_r2585 s
  ORDER BY s.month_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_spending_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_spending_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_correction_actions_r2585()
RETURNS TABLE (
  id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, s.month_label, a.action_at, a.action_kind, a.outcome,
         a.status, a.owner_email, a.notes
  FROM public.spending_correction_actions_r2585 a
  JOIN public.founder_monthly_spending_r2585 s ON s.id = a.spend_id
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_correction_actions_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_correction_actions_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_breach_trend_r2585()
RETURNS TABLE (
  month_label text,
  breach_kind text,
  discretionary_rupees bigint,
  required_rupees bigint,
  debt_payment_rupees bigint,
  savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.month_label, s.breach_kind, s.discretionary_rupees, s.required_rupees,
         s.debt_payment_rupees, s.savings_rupees
  FROM public.founder_monthly_spending_r2585 s
  ORDER BY s.month_label ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_breach_trend_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_breach_trend_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.breach_kind_distribution_r2585()
RETURNS TABLE (
  breach_kind text,
  months_count bigint,
  total_discretionary bigint,
  total_savings bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.breach_kind,
         COUNT(*)::bigint AS months_count,
         COALESCE(SUM(s.discretionary_rupees),0)::bigint AS total_discretionary,
         COALESCE(SUM(s.savings_rupees),0)::bigint AS total_savings
  FROM public.founder_monthly_spending_r2585 s
  GROUP BY s.breach_kind
  ORDER BY months_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.breach_kind_distribution_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.breach_kind_distribution_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.savings_rate_summary_r2585()
RETURNS TABLE (
  month_label text,
  total_inflow_rupees bigint,
  savings_rupees bigint,
  savings_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.month_label,
         (s.discretionary_rupees + s.required_rupees + s.debt_payment_rupees + s.savings_rupees)::bigint AS total_inflow_rupees,
         s.savings_rupees,
         CASE
           WHEN (s.discretionary_rupees + s.required_rupees + s.debt_payment_rupees + s.savings_rupees) = 0 THEN 0
           ELSE ROUND(
             (s.savings_rupees::numeric * 100.0) /
             (s.discretionary_rupees + s.required_rupees + s.debt_payment_rupees + s.savings_rupees)::numeric
           , 2)
         END AS savings_rate_pct
  FROM public.founder_monthly_spending_r2585 s
  ORDER BY s.month_label ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.savings_rate_summary_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.savings_rate_summary_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_correction_kinds_r2585()
RETURNS TABLE (
  action_kind text,
  actions_count bigint,
  positive_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::bigint AS actions_count,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE a.outcome = 'pending')::bigint AS pending_count
  FROM public.spending_correction_actions_r2585 a
  GROUP BY a.action_kind
  ORDER BY actions_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_correction_kinds_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_correction_kinds_r2585() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2585()
RETURNS TABLE (
  months_tracked bigint,
  breach_months bigint,
  total_savings_rupees bigint,
  open_corrections bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_monthly_spending_r2585),
    (SELECT COUNT(*)::bigint FROM public.founder_monthly_spending_r2585 WHERE budget_breach = true),
    (SELECT COALESCE(SUM(savings_rupees),0)::bigint FROM public.founder_monthly_spending_r2585),
    (SELECT COUNT(*)::bigint FROM public.spending_correction_actions_r2585 WHERE status IN ('open','in_progress'));
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2585() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2585() TO authenticated;

