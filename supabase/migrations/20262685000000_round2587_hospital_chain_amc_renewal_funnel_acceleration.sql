-- Round 2587: hospital-chain-amc-renewal-funnel-acceleration
-- Chain x AMC contracts x upcoming renewals x acceleration action x win prob x ARR

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.chain_amc_renewal_funnel_r2587 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  contract_external_ref text,
  renewal_due_at timestamptz NOT NULL DEFAULT now(),
  win_probability_pct int NOT NULL DEFAULT 50
    CHECK (win_probability_pct BETWEEN 0 AND 100),
  arr_at_stake_rupees bigint NOT NULL DEFAULT 0,
  acceleration_action_kind text NOT NULL DEFAULT 'price_lock'
    CHECK (acceleration_action_kind IN ('price_lock','early_discount','exec_lunch','extra_service','case_study')),
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.renewal_acceleration_outcomes_r2587 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  funnel_id uuid NOT NULL REFERENCES public.chain_amc_renewal_funnel_r2587(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL DEFAULT 'in_review'
    CHECK (outcome_kind IN ('closed_won','postponed','lost','in_review')),
  days_to_decision int NOT NULL DEFAULT 0,
  revenue_realized_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.chain_amc_renewal_funnel_r2587 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renewal_acceleration_outcomes_r2587 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_amc_renewal_funnel_r2587;
CREATE POLICY founder_all ON public.chain_amc_renewal_funnel_r2587
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.renewal_acceleration_outcomes_r2587;
CREATE POLICY founder_all ON public.renewal_acceleration_outcomes_r2587
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.chain_amc_renewal_funnel_r2587
  (chain_name, contract_external_ref, renewal_due_at, win_probability_pct, arr_at_stake_rupees, acceleration_action_kind, owner_email, status, notes)
VALUES
  ('Apollo Chain', 'AMC-APL-2026-018', '2026-07-15T00:00:00Z'::timestamptz, 80, 4800000, 'price_lock', 'founder@equipseva.in', 'in_progress', 'Locked 2027 pricing at 2026 rates; CFO meeting scheduled.'),
  ('Yashoda Chain', 'AMC-YSH-2026-022', '2026-08-02T00:00:00Z'::timestamptz, 65, 3200000, 'early_discount', 'founder@equipseva.in', 'open', 'Offering 7 percent discount if renewed 30 days early.'),
  ('Continental Chain', 'AMC-CNT-2026-031', '2026-09-10T00:00:00Z'::timestamptz, 45, 2100000, 'exec_lunch', 'founder@equipseva.in', 'open', 'Hospital director lunch booked; relationship at risk after engineer escalation.'),
  ('KIMS Chain', 'AMC-KIM-2026-040', '2026-07-28T00:00:00Z'::timestamptz, 90, 5400000, 'extra_service', 'founder@equipseva.in', 'in_progress', 'Bundling 4 free spot audits; chain CTO endorsement received.'),
  ('Care Hospitals Chain', 'AMC-CRE-2026-045', '2026-10-01T00:00:00Z'::timestamptz, 30, 1800000, 'case_study', 'founder@equipseva.in', 'open', 'Building Yashoda success case study to deflect competing bid.');

INSERT INTO public.renewal_acceleration_outcomes_r2587
  (funnel_id, outcome_kind, days_to_decision, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'closed_won', 12, 4800000, 'founder@equipseva.in', 'done',
       'Apollo signed 2 year renewal at locked 2026 pricing.'
FROM public.chain_amc_renewal_funnel_r2587 WHERE chain_name = 'Apollo Chain';

INSERT INTO public.renewal_acceleration_outcomes_r2587
  (funnel_id, outcome_kind, days_to_decision, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'in_review', 0, 0, 'founder@equipseva.in', 'open',
       'Yashoda CFO requested 14 day evaluation window.'
FROM public.chain_amc_renewal_funnel_r2587 WHERE chain_name = 'Yashoda Chain';

INSERT INTO public.renewal_acceleration_outcomes_r2587
  (funnel_id, outcome_kind, days_to_decision, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'postponed', 21, 0, 'founder@equipseva.in', 'open',
       'Continental delayed decision pending board approval.'
FROM public.chain_amc_renewal_funnel_r2587 WHERE chain_name = 'Continental Chain';

INSERT INTO public.renewal_acceleration_outcomes_r2587
  (funnel_id, outcome_kind, days_to_decision, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'closed_won', 8, 5400000, 'founder@equipseva.in', 'done',
       'KIMS signed renewal with bundled spot audit package.'
FROM public.chain_amc_renewal_funnel_r2587 WHERE chain_name = 'KIMS Chain';

INSERT INTO public.renewal_acceleration_outcomes_r2587
  (funnel_id, outcome_kind, days_to_decision, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'lost', 35, 0, 'founder@equipseva.in', 'done',
       'Care Hospitals switched to incumbent vendor at lower price.'
FROM public.chain_amc_renewal_funnel_r2587 WHERE chain_name = 'Care Hospitals Chain';

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_funnel_r2587()
RETURNS TABLE (
  id uuid,
  chain_name text,
  contract_external_ref text,
  renewal_due_at timestamptz,
  win_probability_pct int,
  arr_at_stake_rupees bigint,
  acceleration_action_kind text,
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
  SELECT f.id, f.chain_name, f.contract_external_ref, f.renewal_due_at,
         f.win_probability_pct, f.arr_at_stake_rupees, f.acceleration_action_kind,
         f.owner_email, f.status, f.notes, f.created_at
  FROM public.chain_amc_renewal_funnel_r2587 f
  ORDER BY f.renewal_due_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_funnel_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_funnel_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2587()
RETURNS TABLE (
  id uuid,
  chain_name text,
  observed_at timestamptz,
  outcome_kind text,
  days_to_decision int,
  revenue_realized_rupees bigint,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, f.chain_name, o.observed_at, o.outcome_kind,
         o.days_to_decision, o.revenue_realized_rupees,
         o.status, o.owner_email, o.notes
  FROM public.renewal_acceleration_outcomes_r2587 o
  JOIN public.chain_amc_renewal_funnel_r2587 f ON f.id = o.funnel_id
  ORDER BY o.observed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_arr_focus_r2587()
RETURNS TABLE (
  chain_name text,
  contract_external_ref text,
  renewal_due_at timestamptz,
  win_probability_pct int,
  arr_at_stake_rupees bigint,
  acceleration_action_kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.chain_name, f.contract_external_ref, f.renewal_due_at,
         f.win_probability_pct, f.arr_at_stake_rupees, f.acceleration_action_kind,
         f.status
  FROM public.chain_amc_renewal_funnel_r2587 f
  WHERE f.status IN ('open','in_progress')
  ORDER BY f.arr_at_stake_rupees DESC, f.renewal_due_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_arr_focus_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_focus_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.acceleration_kind_distribution_r2587()
RETURNS TABLE (
  acceleration_action_kind text,
  funnel_count bigint,
  total_arr_at_stake bigint,
  avg_win_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.acceleration_action_kind,
         COUNT(*)::bigint AS funnel_count,
         COALESCE(SUM(f.arr_at_stake_rupees),0)::bigint AS total_arr_at_stake,
         COALESCE(ROUND(AVG(f.win_probability_pct)::numeric, 2), 0) AS avg_win_pct
  FROM public.chain_amc_renewal_funnel_r2587 f
  GROUP BY f.acceleration_action_kind
  ORDER BY total_arr_at_stake DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.acceleration_kind_distribution_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acceleration_kind_distribution_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.win_probability_summary_r2587()
RETURNS TABLE (
  bucket text,
  funnel_count bigint,
  total_arr_at_stake bigint,
  expected_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN f.win_probability_pct >= 75 THEN 'high (75-100)'
      WHEN f.win_probability_pct >= 50 THEN 'medium (50-74)'
      WHEN f.win_probability_pct >= 25 THEN 'low (25-49)'
      ELSE 'cold (0-24)'
    END AS bucket,
    COUNT(*)::bigint AS funnel_count,
    COALESCE(SUM(f.arr_at_stake_rupees),0)::bigint AS total_arr_at_stake,
    COALESCE(SUM((f.arr_at_stake_rupees * f.win_probability_pct) / 100),0)::bigint AS expected_arr_rupees
  FROM public.chain_amc_renewal_funnel_r2587 f
  GROUP BY bucket
  ORDER BY expected_arr_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.win_probability_summary_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_probability_summary_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_funnel_trend_r2587()
RETURNS TABLE (
  due_month text,
  funnel_count bigint,
  total_arr_at_stake bigint,
  avg_win_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(f.renewal_due_at, 'YYYY-MM') AS due_month,
         COUNT(*)::bigint AS funnel_count,
         COALESCE(SUM(f.arr_at_stake_rupees),0)::bigint AS total_arr_at_stake,
         COALESCE(ROUND(AVG(f.win_probability_pct)::numeric, 2), 0) AS avg_win_pct
  FROM public.chain_amc_renewal_funnel_r2587 f
  GROUP BY due_month
  ORDER BY due_month ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_funnel_trend_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_funnel_trend_r2587() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2587()
RETURNS TABLE (
  owner_email text,
  funnel_count bigint,
  open_count bigint,
  total_arr_at_stake bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(f.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint AS funnel_count,
         COUNT(*) FILTER (WHERE f.status IN ('open','in_progress'))::bigint AS open_count,
         COALESCE(SUM(f.arr_at_stake_rupees),0)::bigint AS total_arr_at_stake
  FROM public.chain_amc_renewal_funnel_r2587 f
  GROUP BY COALESCE(f.owner_email, 'unassigned')
  ORDER BY total_arr_at_stake DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2587() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2587() TO authenticated;

