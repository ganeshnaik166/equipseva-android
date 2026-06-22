BEGIN;

-- =========================================================================
-- r2282 — Engineer Pay-Equity Audit
-- Same-tier same-role pay deltas, gender/region disparity, equity scores, action log
-- =========================================================================

-- ---- Tables ----
CREATE TABLE IF NOT EXISTS public.engineer_pay_equity_snapshots_r2282 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier_band text NOT NULL CHECK (tier_band IN ('tier_1','tier_2','tier_3','tier_4','tier_5')),
  role_label text NOT NULL CHECK (role_label IN ('field_engineer','senior_engineer','lead_engineer','specialist','trainee')),
  gender text CHECK (gender IN ('male','female','nonbinary','undisclosed')),
  region text NOT NULL CHECK (region IN ('north','south','east','west','central','northeast')),
  city text,
  jobs_completed_90d int NOT NULL DEFAULT 0 CHECK (jobs_completed_90d >= 0),
  avg_payout_rupees_90d numeric(12,2) NOT NULL DEFAULT 0 CHECK (avg_payout_rupees_90d >= 0),
  cohort_median_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (cohort_median_rupees >= 0),
  delta_vs_cohort_pct numeric(6,2) NOT NULL DEFAULT 0,
  equity_score numeric(5,2) NOT NULL DEFAULT 0 CHECK (equity_score BETWEEN 0 AND 100),
  flag_underpaid boolean NOT NULL DEFAULT false,
  flag_overpaid boolean NOT NULL DEFAULT false,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pay_equity_snap_r2282_eng ON public.engineer_pay_equity_snapshots_r2282(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_pay_equity_snap_r2282_tier ON public.engineer_pay_equity_snapshots_r2282(tier_band, role_label);
CREATE INDEX IF NOT EXISTS idx_pay_equity_snap_r2282_region ON public.engineer_pay_equity_snapshots_r2282(region);
CREATE INDEX IF NOT EXISTS idx_pay_equity_snap_r2282_flag ON public.engineer_pay_equity_snapshots_r2282(flag_underpaid) WHERE flag_underpaid;

CREATE TABLE IF NOT EXISTS public.engineer_pay_equity_actions_r2282 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid REFERENCES public.engineer_pay_equity_snapshots_r2282(id) ON DELETE SET NULL,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('rate_adjustment','bonus_grant','review_scheduled','no_action','tier_promotion','region_rebalance')),
  rationale text NOT NULL,
  amount_rupees numeric(12,2) CHECK (amount_rupees IS NULL OR amount_rupees >= 0),
  taken_by_email text NOT NULL,
  taken_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','applied','reversed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pay_equity_act_r2282_eng ON public.engineer_pay_equity_actions_r2282(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_pay_equity_act_r2282_status ON public.engineer_pay_equity_actions_r2282(status);
CREATE INDEX IF NOT EXISTS idx_pay_equity_act_r2282_taken ON public.engineer_pay_equity_actions_r2282(taken_at DESC);

-- ---- RLS ----
ALTER TABLE public.engineer_pay_equity_snapshots_r2282 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_pay_equity_actions_r2282 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_pay_equity_snapshots_r2282;
CREATE POLICY founder_all ON public.engineer_pay_equity_snapshots_r2282
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_pay_equity_actions_r2282;
CREATE POLICY founder_all ON public.engineer_pay_equity_actions_r2282
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---- Seed data ----
DO $seed$
DECLARE
  v_engineers uuid[];
  v_eng uuid;
  v_idx int := 0;
  v_tiers text[] := ARRAY['tier_1','tier_2','tier_3','tier_4','tier_5'];
  v_roles text[] := ARRAY['field_engineer','senior_engineer','lead_engineer','specialist','trainee'];
  v_genders text[] := ARRAY['male','female','nonbinary','undisclosed'];
  v_regions text[] := ARRAY['north','south','east','west','central','northeast'];
  v_cities text[] := ARRAY['Hyderabad','Bengaluru','Chennai','Mumbai','Delhi','Pune','Kolkata','Ahmedabad'];
  v_tier text;
  v_role text;
  v_gender text;
  v_region text;
  v_city text;
  v_avg numeric;
  v_median numeric;
  v_delta numeric;
  v_score numeric;
  v_under boolean;
  v_over boolean;
  v_snap_id uuid;
BEGIN
  SELECT array_agg(id) INTO v_engineers
  FROM (
    SELECT id FROM public.profiles
    WHERE role IN ('engineer','hospital_admin','supplier','manufacturer','logistics')
    ORDER BY created_at DESC
    LIMIT 30
  ) p;

  IF v_engineers IS NULL OR array_length(v_engineers,1) IS NULL THEN
    RAISE NOTICE 'r2282 seed skipped — no profiles found';
    RETURN;
  END IF;

  FOREACH v_eng IN ARRAY v_engineers LOOP
    v_idx := v_idx + 1;
    v_tier := v_tiers[1 + (v_idx % 5)];
    v_role := v_roles[1 + (v_idx % 5)];
    v_gender := v_genders[1 + (v_idx % 4)];
    v_region := v_regions[1 + (v_idx % 6)];
    v_city := v_cities[1 + (v_idx % 8)];
    v_median := 18000 + (v_idx % 5) * 6500;
    v_avg := v_median * (0.78 + ((v_idx * 13) % 50) / 100.0);
    v_delta := round(((v_avg - v_median) / v_median * 100)::numeric, 2);
    v_under := v_delta < -8;
    v_over := v_delta > 12;
    v_score := GREATEST(0, LEAST(100, 100 - abs(v_delta) * 1.4));

    INSERT INTO public.engineer_pay_equity_snapshots_r2282(
      engineer_user_id, tier_band, role_label, gender, region, city,
      jobs_completed_90d, avg_payout_rupees_90d, cohort_median_rupees,
      delta_vs_cohort_pct, equity_score, flag_underpaid, flag_overpaid
    ) VALUES (
      v_eng, v_tier, v_role, v_gender, v_region, v_city,
      12 + (v_idx % 28), v_avg, v_median,
      v_delta, v_score, v_under, v_over
    ) RETURNING id INTO v_snap_id;

    IF v_under AND v_idx % 3 = 0 THEN
      INSERT INTO public.engineer_pay_equity_actions_r2282(
        snapshot_id, engineer_user_id, action_type, rationale, amount_rupees, taken_by_email, status
      ) VALUES (
        v_snap_id, v_eng, 'rate_adjustment',
        'Cohort median delta ' || v_delta::text || '%% — proactive correction',
        round((v_median - v_avg)::numeric, 2),
        'founder@equipseva.in', 'applied'
      );
    ELSIF v_over AND v_idx % 5 = 0 THEN
      INSERT INTO public.engineer_pay_equity_actions_r2282(
        snapshot_id, engineer_user_id, action_type, rationale, taken_by_email, status
      ) VALUES (
        v_snap_id, v_eng, 'review_scheduled',
        'Above cohort by ' || v_delta::text || '%% — verify tier ladder',
        'founder@equipseva.in', 'pending'
      );
    END IF;
  END LOOP;
END;
$seed$;

-- =========================================================================
-- RPC FUNCTIONS (7) — all is_founder gated
-- =========================================================================

-- 1. KPIs
DROP FUNCTION IF EXISTS public.founder_pay_equity_kpis_r2282();
CREATE FUNCTION public.founder_pay_equity_kpis_r2282()
RETURNS TABLE(
  total_engineers int,
  underpaid_count int,
  overpaid_count int,
  avg_equity_score numeric,
  avg_delta_pct numeric,
  actions_pending int,
  actions_applied int,
  total_rupees_adjusted numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(DISTINCT engineer_user_id))::int FROM public.engineer_pay_equity_snapshots_r2282),
    (SELECT (COUNT(*) FILTER (WHERE flag_underpaid))::int FROM public.engineer_pay_equity_snapshots_r2282),
    (SELECT (COUNT(*) FILTER (WHERE flag_overpaid))::int FROM public.engineer_pay_equity_snapshots_r2282),
    (SELECT ROUND(AVG(equity_score)::numeric, 2) FROM public.engineer_pay_equity_snapshots_r2282),
    (SELECT ROUND(AVG(delta_vs_cohort_pct)::numeric, 2) FROM public.engineer_pay_equity_snapshots_r2282),
    (SELECT (COUNT(*) FILTER (WHERE status = 'pending'))::int FROM public.engineer_pay_equity_actions_r2282),
    (SELECT (COUNT(*) FILTER (WHERE status = 'applied'))::int FROM public.engineer_pay_equity_actions_r2282),
    (SELECT COALESCE(SUM(amount_rupees), 0) FROM public.engineer_pay_equity_actions_r2282 WHERE status = 'applied');
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_kpis_r2282() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_kpis_r2282() TO authenticated;

-- 2. Top underpaid
DROP FUNCTION IF EXISTS public.founder_pay_equity_top_underpaid_r2282(int);
CREATE FUNCTION public.founder_pay_equity_top_underpaid_r2282(p_limit int DEFAULT 20)
RETURNS TABLE(
  snapshot_id uuid,
  engineer_email text,
  tier_band text,
  role_label text,
  region text,
  city text,
  avg_payout_rupees_90d numeric,
  cohort_median_rupees numeric,
  delta_vs_cohort_pct numeric,
  equity_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    p.email,
    s.tier_band,
    s.role_label,
    s.region,
    s.city,
    s.avg_payout_rupees_90d,
    s.cohort_median_rupees,
    s.delta_vs_cohort_pct,
    s.equity_score
  FROM public.engineer_pay_equity_snapshots_r2282 s
  JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.flag_underpaid
  ORDER BY s.delta_vs_cohort_pct ASC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_top_underpaid_r2282(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_top_underpaid_r2282(int) TO authenticated;

-- 3. Region disparity
DROP FUNCTION IF EXISTS public.founder_pay_equity_by_region_r2282();
CREATE FUNCTION public.founder_pay_equity_by_region_r2282()
RETURNS TABLE(
  region text,
  engineer_count int,
  avg_payout numeric,
  avg_delta_pct numeric,
  underpaid_count int,
  avg_equity_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.region,
    (COUNT(DISTINCT s.engineer_user_id))::int,
    ROUND(AVG(s.avg_payout_rupees_90d)::numeric, 2),
    ROUND(AVG(s.delta_vs_cohort_pct)::numeric, 2),
    (COUNT(*) FILTER (WHERE s.flag_underpaid))::int,
    ROUND(AVG(s.equity_score)::numeric, 2)
  FROM public.engineer_pay_equity_snapshots_r2282 s
  GROUP BY s.region
  ORDER BY ROUND(AVG(s.delta_vs_cohort_pct)::numeric, 2) ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_by_region_r2282() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_by_region_r2282() TO authenticated;

-- 4. Gender disparity
DROP FUNCTION IF EXISTS public.founder_pay_equity_by_gender_r2282();
CREATE FUNCTION public.founder_pay_equity_by_gender_r2282()
RETURNS TABLE(
  gender text,
  engineer_count int,
  avg_payout numeric,
  avg_delta_pct numeric,
  avg_equity_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(s.gender, 'undisclosed'),
    (COUNT(DISTINCT s.engineer_user_id))::int,
    ROUND(AVG(s.avg_payout_rupees_90d)::numeric, 2),
    ROUND(AVG(s.delta_vs_cohort_pct)::numeric, 2),
    ROUND(AVG(s.equity_score)::numeric, 2)
  FROM public.engineer_pay_equity_snapshots_r2282 s
  GROUP BY COALESCE(s.gender, 'undisclosed')
  ORDER BY ROUND(AVG(s.delta_vs_cohort_pct)::numeric, 2) ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_by_gender_r2282() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_by_gender_r2282() TO authenticated;

-- 5. Tier x role matrix
DROP FUNCTION IF EXISTS public.founder_pay_equity_tier_role_matrix_r2282();
CREATE FUNCTION public.founder_pay_equity_tier_role_matrix_r2282()
RETURNS TABLE(
  tier_band text,
  role_label text,
  engineer_count int,
  avg_payout numeric,
  min_payout numeric,
  max_payout numeric,
  spread_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.tier_band,
    s.role_label,
    (COUNT(DISTINCT s.engineer_user_id))::int,
    ROUND(AVG(s.avg_payout_rupees_90d)::numeric, 2),
    MIN(s.avg_payout_rupees_90d),
    MAX(s.avg_payout_rupees_90d),
    CASE WHEN MIN(s.avg_payout_rupees_90d) > 0
      THEN ROUND(((MAX(s.avg_payout_rupees_90d) - MIN(s.avg_payout_rupees_90d)) / MIN(s.avg_payout_rupees_90d) * 100)::numeric, 2)
      ELSE 0 END
  FROM public.engineer_pay_equity_snapshots_r2282 s
  GROUP BY s.tier_band, s.role_label
  ORDER BY s.tier_band, s.role_label;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_tier_role_matrix_r2282() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_tier_role_matrix_r2282() TO authenticated;

-- 6. Recent actions
DROP FUNCTION IF EXISTS public.founder_pay_equity_recent_actions_r2282(int);
CREATE FUNCTION public.founder_pay_equity_recent_actions_r2282(p_limit int DEFAULT 25)
RETURNS TABLE(
  action_id uuid,
  engineer_email text,
  action_type text,
  rationale text,
  amount_rupees numeric,
  taken_by_email text,
  taken_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    p.email,
    a.action_type,
    a.rationale,
    a.amount_rupees,
    a.taken_by_email,
    a.taken_at,
    a.status
  FROM public.engineer_pay_equity_actions_r2282 a
  JOIN public.profiles p ON p.id = a.engineer_user_id
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_recent_actions_r2282(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_recent_actions_r2282(int) TO authenticated;

-- 7. Log action
DROP FUNCTION IF EXISTS public.founder_pay_equity_log_action_r2282(uuid, text, text, numeric);
CREATE FUNCTION public.founder_pay_equity_log_action_r2282(
  p_snapshot_id uuid,
  p_action_type text,
  p_rationale text,
  p_amount_rupees numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
  v_eng uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';

  SELECT engineer_user_id INTO v_eng
  FROM public.engineer_pay_equity_snapshots_r2282
  WHERE id = p_snapshot_id;

  IF v_eng IS NULL THEN RAISE EXCEPTION 'snapshot not found'; END IF;

  INSERT INTO public.engineer_pay_equity_actions_r2282(
    snapshot_id, engineer_user_id, action_type, rationale, amount_rupees, taken_by_email, status
  ) VALUES (
    p_snapshot_id, v_eng, p_action_type, p_rationale, p_amount_rupees, v_email, 'pending'
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_pay_equity_log_action_r2282(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pay_equity_log_action_r2282(uuid, text, text, numeric) TO authenticated;

COMMIT;
