-- Round 2580: customer-quarterly-equipment-utilization-bench
-- Hospital quarterly equipment utilization vs peer benchmark & top-quartile gap + growth lever actions.

BEGIN;

-- ============================================================================
-- TABLE: customer_quarterly_utilization_r2580
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_quarterly_utilization_r2580 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  equipment_kind text NOT NULL,
  our_utilization_pct numeric NOT NULL DEFAULT 0,
  peer_benchmark_pct numeric NOT NULL DEFAULT 0,
  top_quartile_pct numeric NOT NULL DEFAULT 0,
  gap_to_top_pct numeric NOT NULL DEFAULT 0,
  growth_lever_kind text NOT NULL CHECK (growth_lever_kind IN ('extended_hours','cross_dept','marketing','training','second_shift','replacement')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','in_discussion','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_util_r2580_hosp ON public.customer_quarterly_utilization_r2580(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_util_r2580_quarter ON public.customer_quarterly_utilization_r2580(quarter_label);
CREATE INDEX IF NOT EXISTS idx_util_r2580_kind ON public.customer_quarterly_utilization_r2580(equipment_kind);
CREATE INDEX IF NOT EXISTS idx_util_r2580_lever ON public.customer_quarterly_utilization_r2580(growth_lever_kind);
CREATE INDEX IF NOT EXISTS idx_util_r2580_status ON public.customer_quarterly_utilization_r2580(status);
CREATE INDEX IF NOT EXISTS idx_util_r2580_gap ON public.customer_quarterly_utilization_r2580(gap_to_top_pct DESC);

ALTER TABLE public.customer_quarterly_utilization_r2580 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_quarterly_utilization_r2580;
CREATE POLICY founder_all ON public.customer_quarterly_utilization_r2580
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: utilization_growth_lever_actions_r2580
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.utilization_growth_lever_actions_r2580 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  utilization_id uuid NOT NULL REFERENCES public.customer_quarterly_utilization_r2580(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  expected_uplift_rupees bigint NOT NULL DEFAULT 0,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_util_actions_r2580_util ON public.utilization_growth_lever_actions_r2580(utilization_id);
CREATE INDEX IF NOT EXISTS idx_util_actions_r2580_status ON public.utilization_growth_lever_actions_r2580(status);
CREATE INDEX IF NOT EXISTS idx_util_actions_r2580_action ON public.utilization_growth_lever_actions_r2580(action_at DESC);
CREATE INDEX IF NOT EXISTS idx_util_actions_r2580_outcome ON public.utilization_growth_lever_actions_r2580(outcome);

ALTER TABLE public.utilization_growth_lever_actions_r2580 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.utilization_growth_lever_actions_r2580;
CREATE POLICY founder_all ON public.utilization_growth_lever_actions_r2580
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_hosp uuid;
  v_u1 uuid;
  v_u2 uuid;
  v_u3 uuid;
  v_u4 uuid;
BEGIN
  SELECT id INTO v_hosp FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  IF v_hosp IS NULL THEN
    SELECT id INTO v_hosp FROM public.profiles ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_hosp IS NOT NULL THEN
    INSERT INTO public.customer_quarterly_utilization_r2580
      (hospital_user_id, quarter_label, equipment_kind, our_utilization_pct, peer_benchmark_pct, top_quartile_pct, gap_to_top_pct, growth_lever_kind, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-Q2', 'MRI', 58.0, 65.0, 78.0, 20.0, 'extended_hours', 'founder@equipseva.in', 'in_discussion', 'evening slot proposal')
    RETURNING id INTO v_u1;

    INSERT INTO public.customer_quarterly_utilization_r2580
      (hospital_user_id, quarter_label, equipment_kind, our_utilization_pct, peer_benchmark_pct, top_quartile_pct, gap_to_top_pct, growth_lever_kind, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-Q2', 'CT', 72.0, 70.0, 82.0, 10.0, 'cross_dept', 'founder@equipseva.in', 'monitoring', 'ER cross-flow opportunity')
    RETURNING id INTO v_u2;

    INSERT INTO public.customer_quarterly_utilization_r2580
      (hospital_user_id, quarter_label, equipment_kind, our_utilization_pct, peer_benchmark_pct, top_quartile_pct, gap_to_top_pct, growth_lever_kind, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-Q1', 'Ultrasound', 45.0, 60.0, 75.0, 30.0, 'marketing', 'founder@equipseva.in', 'won', 'OBGYN referral push worked')
    RETURNING id INTO v_u3;

    INSERT INTO public.customer_quarterly_utilization_r2580
      (hospital_user_id, quarter_label, equipment_kind, our_utilization_pct, peer_benchmark_pct, top_quartile_pct, gap_to_top_pct, growth_lever_kind, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-Q1', 'Cath Lab', 38.0, 55.0, 70.0, 32.0, 'second_shift', 'founder@equipseva.in', 'lost', 'budget rejected by board')
    RETURNING id INTO v_u4;

    INSERT INTO public.utilization_growth_lever_actions_r2580
      (utilization_id, action_at, owner_email, status, expected_uplift_rupees, outcome, notes)
    VALUES
      (v_u1, (now() - interval '10 days')::timestamptz, 'founder@equipseva.in', 'in_progress', 250000, 'pending', 'piloting 7-9pm slots'),
      (v_u2, (now() - interval '20 days')::timestamptz, 'founder@equipseva.in', 'open', 150000, 'pending', 'ER lead time analysis'),
      (v_u3, (now() - interval '60 days')::timestamptz, 'founder@equipseva.in', 'done', 320000, 'positive', 'OBGYN campaign delivered +18%'),
      (v_u4, (now() - interval '75 days')::timestamptz, 'founder@equipseva.in', 'dropped', 0, 'negative', 'second shift killed by capex pushback');
  END IF;
END $seed$;

-- ============================================================================
-- RPC: list_utilization_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_utilization_r2580()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  quarter_label text,
  equipment_kind text,
  our_utilization_pct numeric,
  peer_benchmark_pct numeric,
  top_quartile_pct numeric,
  gap_to_top_pct numeric,
  growth_lever_kind text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.id,
    u.hospital_user_id,
    p.email::text AS hospital_email,
    u.quarter_label,
    u.equipment_kind,
    u.our_utilization_pct,
    u.peer_benchmark_pct,
    u.top_quartile_pct,
    u.gap_to_top_pct,
    u.growth_lever_kind,
    u.owner_email,
    u.status,
    u.notes,
    u.created_at
  FROM public.customer_quarterly_utilization_r2580 u
  LEFT JOIN public.profiles p ON p.id = u.hospital_user_id
  ORDER BY u.quarter_label DESC, u.gap_to_top_pct DESC NULLS LAST, u.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_utilization_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_utilization_r2580() TO authenticated;

-- ============================================================================
-- RPC: list_growth_lever_actions_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_growth_lever_actions_r2580()
RETURNS TABLE (
  id uuid,
  utilization_id uuid,
  quarter_label text,
  equipment_kind text,
  hospital_email text,
  action_at timestamptz,
  owner_email text,
  status text,
  expected_uplift_rupees bigint,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.utilization_id,
    u.quarter_label,
    u.equipment_kind,
    p.email::text AS hospital_email,
    a.action_at,
    a.owner_email,
    a.status,
    a.expected_uplift_rupees,
    a.outcome,
    a.notes,
    a.created_at
  FROM public.utilization_growth_lever_actions_r2580 a
  JOIN public.customer_quarterly_utilization_r2580 u ON u.id = a.utilization_id
  LEFT JOIN public.profiles p ON p.id = u.hospital_user_id
  ORDER BY a.action_at DESC NULLS LAST, a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_growth_lever_actions_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_growth_lever_actions_r2580() TO authenticated;

-- ============================================================================
-- RPC: top_gap_focus_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_gap_focus_r2580()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  quarter_label text,
  equipment_kind text,
  our_utilization_pct numeric,
  top_quartile_pct numeric,
  gap_to_top_pct numeric,
  growth_lever_kind text,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.id,
    p.email::text AS hospital_email,
    u.quarter_label,
    u.equipment_kind,
    u.our_utilization_pct,
    u.top_quartile_pct,
    u.gap_to_top_pct,
    u.growth_lever_kind,
    u.status,
    u.owner_email
  FROM public.customer_quarterly_utilization_r2580 u
  LEFT JOIN public.profiles p ON p.id = u.hospital_user_id
  WHERE u.status IN ('monitoring','in_discussion')
  ORDER BY u.gap_to_top_pct DESC NULLS LAST, u.quarter_label DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_gap_focus_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_gap_focus_r2580() TO authenticated;

-- ============================================================================
-- RPC: equipment_kind_summary_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.equipment_kind_summary_r2580()
RETURNS TABLE (
  equipment_kind text,
  row_count bigint,
  avg_our_pct numeric,
  avg_peer_pct numeric,
  avg_top_pct numeric,
  avg_gap_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.equipment_kind,
    count(*)::bigint AS row_count,
    round(avg(u.our_utilization_pct)::numeric, 1) AS avg_our_pct,
    round(avg(u.peer_benchmark_pct)::numeric, 1) AS avg_peer_pct,
    round(avg(u.top_quartile_pct)::numeric, 1) AS avg_top_pct,
    round(avg(u.gap_to_top_pct)::numeric, 1) AS avg_gap_pct
  FROM public.customer_quarterly_utilization_r2580 u
  GROUP BY u.equipment_kind
  ORDER BY avg_gap_pct DESC NULLS LAST, u.equipment_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2580() TO authenticated;

-- ============================================================================
-- RPC: growth_lever_distribution_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.growth_lever_distribution_r2580()
RETURNS TABLE (
  growth_lever_kind text,
  row_count bigint,
  won_count bigint,
  lost_count bigint,
  avg_gap_pct numeric,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total FROM public.customer_quarterly_utilization_r2580;
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    u.growth_lever_kind,
    count(*)::bigint AS row_count,
    count(*) FILTER (WHERE u.status = 'won')::bigint AS won_count,
    count(*) FILTER (WHERE u.status = 'lost')::bigint AS lost_count,
    round(avg(u.gap_to_top_pct)::numeric, 1) AS avg_gap_pct,
    round((count(*)::numeric * 100.0) / v_total::numeric, 1) AS pct
  FROM public.customer_quarterly_utilization_r2580 u
  GROUP BY u.growth_lever_kind
  ORDER BY row_count DESC, u.growth_lever_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.growth_lever_distribution_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.growth_lever_distribution_r2580() TO authenticated;

-- ============================================================================
-- RPC: quarterly_utilization_trend_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.quarterly_utilization_trend_r2580()
RETURNS TABLE (
  quarter_label text,
  row_count bigint,
  avg_our_pct numeric,
  avg_peer_pct numeric,
  avg_top_pct numeric,
  avg_gap_pct numeric,
  won_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.quarter_label,
    count(*)::bigint AS row_count,
    round(avg(u.our_utilization_pct)::numeric, 1) AS avg_our_pct,
    round(avg(u.peer_benchmark_pct)::numeric, 1) AS avg_peer_pct,
    round(avg(u.top_quartile_pct)::numeric, 1) AS avg_top_pct,
    round(avg(u.gap_to_top_pct)::numeric, 1) AS avg_gap_pct,
    count(*) FILTER (WHERE u.status = 'won')::bigint AS won_count
  FROM public.customer_quarterly_utilization_r2580 u
  GROUP BY u.quarter_label
  ORDER BY u.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_utilization_trend_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_utilization_trend_r2580() TO authenticated;

-- ============================================================================
-- RPC: owner_load_r2580
-- ============================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2580()
RETURNS TABLE (
  owner_email text,
  utilization_count bigint,
  open_action_count bigint,
  done_action_count bigint,
  expected_uplift_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH util AS (
    SELECT
      coalesce(u.owner_email, '(unassigned)') AS owner_email,
      count(*)::bigint AS utilization_count
    FROM public.customer_quarterly_utilization_r2580 u
    GROUP BY coalesce(u.owner_email, '(unassigned)')
  ),
  acts AS (
    SELECT
      coalesce(a.owner_email, '(unassigned)') AS owner_email,
      count(*) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_action_count,
      count(*) FILTER (WHERE a.status = 'done')::bigint AS done_action_count,
      coalesce(sum(a.expected_uplift_rupees), 0)::bigint AS expected_uplift_rupees
    FROM public.utilization_growth_lever_actions_r2580 a
    GROUP BY coalesce(a.owner_email, '(unassigned)')
  )
  SELECT
    coalesce(util.owner_email, acts.owner_email) AS owner_email,
    coalesce(util.utilization_count, 0)::bigint AS utilization_count,
    coalesce(acts.open_action_count, 0)::bigint AS open_action_count,
    coalesce(acts.done_action_count, 0)::bigint AS done_action_count,
    coalesce(acts.expected_uplift_rupees, 0)::bigint AS expected_uplift_rupees
  FROM util
  FULL OUTER JOIN acts ON acts.owner_email = util.owner_email
  ORDER BY expected_uplift_rupees DESC NULLS LAST, utilization_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2580() TO authenticated;

