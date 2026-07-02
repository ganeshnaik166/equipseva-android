-- Round 2600: customer-quarterly-revenue-concentration-risk
-- Founder-only: track per-hospital revenue concentration, dependency risk, hedge actions, and outcomes.

BEGIN;

-- =========================================================================
-- Table 1: customer_revenue_concentration_r2600
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.customer_revenue_concentration_r2600 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  revenue_rupees bigint NOT NULL DEFAULT 0,
  share_of_total_pct numeric(6,2) NOT NULL DEFAULT 0,
  dependency_risk_kind text NOT NULL CHECK (dependency_risk_kind IN ('low','moderate','high','critical')),
  diversification_action_md text NOT NULL DEFAULT '',
  hedge_kind text NOT NULL CHECK (hedge_kind IN ('price_lock','contract_extension','new_dept','cross_sell','none')),
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('monitoring','in_progress','diversified','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crc_r2600_hospital ON public.customer_revenue_concentration_r2600(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_crc_r2600_status ON public.customer_revenue_concentration_r2600(status);
CREATE INDEX IF NOT EXISTS idx_crc_r2600_risk ON public.customer_revenue_concentration_r2600(dependency_risk_kind);
CREATE INDEX IF NOT EXISTS idx_crc_r2600_quarter ON public.customer_revenue_concentration_r2600(quarter_label);

ALTER TABLE public.customer_revenue_concentration_r2600 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_revenue_concentration_r2600;
CREATE POLICY founder_all ON public.customer_revenue_concentration_r2600
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Table 2: concentration_diversification_outcomes_r2600
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.concentration_diversification_outcomes_r2600 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concentration_id uuid NOT NULL REFERENCES public.customer_revenue_concentration_r2600(id) ON DELETE CASCADE,
  outcome_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('diversified','still_concentrated','lost_account','no_action')),
  new_share_pct numeric(6,2) NOT NULL DEFAULT 0,
  lessons_md text NOT NULL DEFAULT '',
  owner_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cdo_r2600_concentration ON public.concentration_diversification_outcomes_r2600(concentration_id);
CREATE INDEX IF NOT EXISTS idx_cdo_r2600_status ON public.concentration_diversification_outcomes_r2600(status);
CREATE INDEX IF NOT EXISTS idx_cdo_r2600_outcome ON public.concentration_diversification_outcomes_r2600(outcome_kind);

ALTER TABLE public.concentration_diversification_outcomes_r2600 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.concentration_diversification_outcomes_r2600;
CREATE POLICY founder_all ON public.concentration_diversification_outcomes_r2600
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Seed data (3-5 rows each)
-- =========================================================================
DO $seed$
DECLARE
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_hosp4 uuid;
  v_c1 uuid;
  v_c2 uuid;
  v_c3 uuid;
  v_c4 uuid;
BEGIN
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> v_hosp1 ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_hosp1, gen_random_uuid()), COALESCE(v_hosp2, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp4 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_hosp1, gen_random_uuid()), COALESCE(v_hosp2, gen_random_uuid()), COALESCE(v_hosp3, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;

  IF v_hosp1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_revenue_concentration_r2600
    (hospital_user_id, quarter_label, revenue_rupees, share_of_total_pct, dependency_risk_kind, diversification_action_md, hedge_kind, owner_email, status, notes)
  VALUES
    (v_hosp1, 'Q1-2026', 4200000, 38.50, 'critical', 'Land 2 new hospital chains in Hyderabad before Q2 close. De-risk by signing AMC with 3 standalone clinics.', 'new_dept', 'founder@equipseva.in', 'in_progress', 'Anchor account; cannot lose')
  RETURNING id INTO v_c1;

  IF v_hosp2 IS NOT NULL THEN
    INSERT INTO public.customer_revenue_concentration_r2600
      (hospital_user_id, quarter_label, revenue_rupees, share_of_total_pct, dependency_risk_kind, diversification_action_md, hedge_kind, owner_email, status, notes)
    VALUES
      (v_hosp2, 'Q1-2026', 2100000, 19.30, 'high', 'Cross-sell AMC to radiology dept. Lock pricing with 2-year contract.', 'contract_extension', 'sales@equipseva.in', 'monitoring', 'Stable but concentrated in ortho dept')
    RETURNING id INTO v_c2;
  END IF;

  IF v_hosp3 IS NOT NULL THEN
    INSERT INTO public.customer_revenue_concentration_r2600
      (hospital_user_id, quarter_label, revenue_rupees, share_of_total_pct, dependency_risk_kind, diversification_action_md, hedge_kind, owner_email, status, notes)
    VALUES
      (v_hosp3, 'Q4-2025', 950000, 8.70, 'moderate', 'Maintain quarterly review cadence; pitch cardiology dept in Q2.', 'cross_sell', 'founder@equipseva.in', 'monitoring', 'Healthy diversification across 4 depts')
    RETURNING id INTO v_c3;
  END IF;

  IF v_hosp4 IS NOT NULL THEN
    INSERT INTO public.customer_revenue_concentration_r2600
      (hospital_user_id, quarter_label, revenue_rupees, share_of_total_pct, dependency_risk_kind, diversification_action_md, hedge_kind, owner_email, status, notes)
    VALUES
      (v_hosp4, 'Q4-2025', 350000, 3.20, 'low', 'No action needed; rotate in standard quarterly review.', 'none', 'sales@equipseva.in', 'diversified', 'Healthy mix; sub-5% share')
    RETURNING id INTO v_c4;
  END IF;

  -- outcomes
  IF v_c1 IS NOT NULL THEN
    INSERT INTO public.concentration_diversification_outcomes_r2600
      (concentration_id, outcome_kind, new_share_pct, lessons_md, owner_email, status, notes)
    VALUES
      (v_c1, 'still_concentrated', 36.10, 'New chains signed but anchor still 36 percent. Need 3 more accounts to drop below 25 percent.', 'founder@equipseva.in', 'open', 'Tracking weekly');
  END IF;

  IF v_c2 IS NOT NULL THEN
    INSERT INTO public.concentration_diversification_outcomes_r2600
      (concentration_id, outcome_kind, new_share_pct, lessons_md, owner_email, status, notes)
    VALUES
      (v_c2, 'diversified', 14.80, 'Radiology AMC cross-sell worked; share dropped 4.5pp. Replicate in other accounts.', 'sales@equipseva.in', 'done', 'Win - radiology cross-sell playbook validated');
  END IF;

  IF v_c3 IS NOT NULL THEN
    INSERT INTO public.concentration_diversification_outcomes_r2600
      (concentration_id, outcome_kind, new_share_pct, lessons_md, owner_email, status, notes)
    VALUES
      (v_c3, 'no_action', 8.70, 'No action taken this quarter; account stable. Revisit next quarter.', 'founder@equipseva.in', 'open', 'Stable account - low priority');
  END IF;

  IF v_c4 IS NOT NULL THEN
    INSERT INTO public.concentration_diversification_outcomes_r2600
      (concentration_id, outcome_kind, new_share_pct, lessons_md, owner_email, status, notes)
    VALUES
      (v_c4, 'diversified', 3.20, 'Account naturally diversified; share is already healthy.', 'sales@equipseva.in', 'done', 'No intervention needed');
  END IF;
END;
$seed$ LANGUAGE plpgsql;

-- =========================================================================
-- RPC 1: list_concentration_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_concentration_r2600()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  quarter_label text,
  revenue_rupees bigint,
  share_of_total_pct numeric,
  dependency_risk_kind text,
  diversification_action_md text,
  hedge_kind text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    p.email::text AS hospital_email,
    c.quarter_label,
    c.revenue_rupees,
    c.share_of_total_pct,
    c.dependency_risk_kind,
    c.diversification_action_md,
    c.hedge_kind,
    c.owner_email,
    c.status,
    c.notes,
    c.created_at
  FROM public.customer_revenue_concentration_r2600 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY c.share_of_total_pct DESC NULLS LAST, c.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_concentration_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_concentration_r2600() TO authenticated;

-- =========================================================================
-- RPC 2: list_diversification_outcomes_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_diversification_outcomes_r2600()
RETURNS TABLE (
  id uuid,
  concentration_id uuid,
  hospital_email text,
  quarter_label text,
  outcome_at timestamptz,
  outcome_kind text,
  new_share_pct numeric,
  lessons_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.concentration_id,
    p.email::text AS hospital_email,
    c.quarter_label,
    o.outcome_at,
    o.outcome_kind,
    o.new_share_pct,
    o.lessons_md,
    o.owner_email,
    o.status,
    o.notes
  FROM public.concentration_diversification_outcomes_r2600 o
  LEFT JOIN public.customer_revenue_concentration_r2600 c ON c.id = o.concentration_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY o.outcome_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_diversification_outcomes_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_diversification_outcomes_r2600() TO authenticated;

-- =========================================================================
-- RPC 3: top_critical_dependency_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_critical_dependency_r2600()
RETURNS TABLE (
  hospital_email text,
  quarter_label text,
  revenue_rupees bigint,
  share_of_total_pct numeric,
  dependency_risk_kind text,
  hedge_kind text,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email::text AS hospital_email,
    c.quarter_label,
    c.revenue_rupees,
    c.share_of_total_pct,
    c.dependency_risk_kind,
    c.hedge_kind,
    c.status
  FROM public.customer_revenue_concentration_r2600 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.dependency_risk_kind IN ('high','critical')
  ORDER BY c.share_of_total_pct DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_critical_dependency_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_critical_dependency_r2600() TO authenticated;

-- =========================================================================
-- RPC 4: hedge_kind_distribution_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.hedge_kind_distribution_r2600()
RETURNS TABLE (
  hedge_kind text,
  account_count bigint,
  total_revenue_rupees bigint,
  avg_share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.hedge_kind,
    COUNT(*)::bigint AS account_count,
    COALESCE(SUM(c.revenue_rupees),0)::bigint AS total_revenue_rupees,
    COALESCE(ROUND(AVG(c.share_of_total_pct)::numeric, 2), 0) AS avg_share_pct
  FROM public.customer_revenue_concentration_r2600 c
  GROUP BY c.hedge_kind
  ORDER BY total_revenue_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hedge_kind_distribution_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hedge_kind_distribution_r2600() TO authenticated;

-- =========================================================================
-- RPC 5: quarterly_concentration_trend_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.quarterly_concentration_trend_r2600()
RETURNS TABLE (
  quarter_label text,
  account_count bigint,
  total_revenue_rupees bigint,
  max_share_pct numeric,
  critical_accounts bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.quarter_label,
    COUNT(*)::bigint AS account_count,
    COALESCE(SUM(c.revenue_rupees),0)::bigint AS total_revenue_rupees,
    COALESCE(MAX(c.share_of_total_pct), 0) AS max_share_pct,
    COUNT(*) FILTER (WHERE c.dependency_risk_kind = 'critical')::bigint AS critical_accounts
  FROM public.customer_revenue_concentration_r2600 c
  GROUP BY c.quarter_label
  ORDER BY c.quarter_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_concentration_trend_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_concentration_trend_r2600() TO authenticated;

-- =========================================================================
-- RPC 6: lessons_summary_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.lessons_summary_r2600()
RETURNS TABLE (
  outcome_kind text,
  outcome_count bigint,
  avg_new_share_pct numeric,
  done_count bigint,
  open_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.outcome_kind,
    COUNT(*)::bigint AS outcome_count,
    COALESCE(ROUND(AVG(o.new_share_pct)::numeric, 2), 0) AS avg_new_share_pct,
    COUNT(*) FILTER (WHERE o.status = 'done')::bigint AS done_count,
    COUNT(*) FILTER (WHERE o.status = 'open')::bigint AS open_count
  FROM public.concentration_diversification_outcomes_r2600 o
  GROUP BY o.outcome_kind
  ORDER BY outcome_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lessons_summary_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lessons_summary_r2600() TO authenticated;

-- =========================================================================
-- RPC 7: owner_load_r2600
-- =========================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2600()
RETURNS TABLE (
  owner_email text,
  concentration_count bigint,
  outcome_count bigint,
  critical_count bigint,
  in_progress_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c_load AS (
    SELECT
      c.owner_email,
      COUNT(*)::bigint AS concentration_count,
      COUNT(*) FILTER (WHERE c.dependency_risk_kind = 'critical')::bigint AS critical_count,
      COUNT(*) FILTER (WHERE c.status = 'in_progress')::bigint AS in_progress_count
    FROM public.customer_revenue_concentration_r2600 c
    GROUP BY c.owner_email
  ),
  o_load AS (
    SELECT
      o.owner_email,
      COUNT(*)::bigint AS outcome_count
    FROM public.concentration_diversification_outcomes_r2600 o
    GROUP BY o.owner_email
  )
  SELECT
    COALESCE(cl.owner_email, ol.owner_email) AS owner_email,
    COALESCE(cl.concentration_count, 0) AS concentration_count,
    COALESCE(ol.outcome_count, 0) AS outcome_count,
    COALESCE(cl.critical_count, 0) AS critical_count,
    COALESCE(cl.in_progress_count, 0) AS in_progress_count
  FROM c_load cl
  FULL OUTER JOIN o_load ol ON ol.owner_email = cl.owner_email
  ORDER BY COALESCE(cl.concentration_count, 0) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2600() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2600() TO authenticated;

