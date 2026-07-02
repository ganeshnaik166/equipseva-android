-- Round 2512: customer-onboarding-time-to-first-value
-- Tracks hospital onboarding journey from signup to first PM/repair/AMC value events.

BEGIN;

-- ============================================================
-- TABLE 1: customer_first_value_metrics_r2512
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_first_value_metrics_r2512 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  signup_at timestamptz NOT NULL,
  first_pm_at timestamptz,
  first_repair_at timestamptz,
  first_amc_at timestamptz,
  days_to_first_pm int,
  days_to_first_repair int,
  days_to_first_amc int,
  bottleneck_kind text NOT NULL DEFAULT 'no_bottleneck'
    CHECK (bottleneck_kind IN ('no_engineer','missed_call','training_gap','integration','equipment_unavailable','no_bottleneck')),
  north_star_score int NOT NULL DEFAULT 0 CHECK (north_star_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'onboarding'
    CHECK (status IN ('onboarding','first_value','active','stuck','lapsed')),
  owner_email text,
  notes text
);

ALTER TABLE public.customer_first_value_metrics_r2512 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_first_value_metrics_r2512;
CREATE POLICY founder_all ON public.customer_first_value_metrics_r2512
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_cfv_r2512_hospital ON public.customer_first_value_metrics_r2512(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cfv_r2512_status ON public.customer_first_value_metrics_r2512(status);
CREATE INDEX IF NOT EXISTS idx_cfv_r2512_bottleneck ON public.customer_first_value_metrics_r2512(bottleneck_kind);

-- ============================================================
-- TABLE 2: first_value_action_log_r2512
-- ============================================================
CREATE TABLE IF NOT EXISTS public.first_value_action_log_r2512 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  metric_id uuid NOT NULL REFERENCES public.customer_first_value_metrics_r2512(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL
    CHECK (action_kind IN ('call','visit','training','integration','equipment_swap')),
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  notes text
);

ALTER TABLE public.first_value_action_log_r2512 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.first_value_action_log_r2512;
CREATE POLICY founder_all ON public.first_value_action_log_r2512
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fval_r2512_metric ON public.first_value_action_log_r2512(metric_id);
CREATE INDEX IF NOT EXISTS idx_fval_r2512_status ON public.first_value_action_log_r2512(status);
CREATE INDEX IF NOT EXISTS idx_fval_r2512_outcome ON public.first_value_action_log_r2512(outcome);

-- ============================================================
-- SEED DATA
-- ============================================================
DO $seed$
DECLARE
  v_hospital uuid;
  v_metric_a uuid;
  v_metric_b uuid;
  v_metric_c uuid;
  v_metric_d uuid;
BEGIN
  SELECT id INTO v_hospital
  FROM public.profiles
  WHERE role = 'hospital_admin'
  ORDER BY created_at
  LIMIT 1;

  IF v_hospital IS NULL THEN
    RAISE NOTICE 'No hospital_admin profile found; skipping seed';
    RETURN;
  END IF;

  INSERT INTO public.customer_first_value_metrics_r2512
    (hospital_user_id, signup_at, first_pm_at, first_repair_at, first_amc_at,
     days_to_first_pm, days_to_first_repair, days_to_first_amc,
     bottleneck_kind, north_star_score, status, owner_email, notes)
  VALUES
    (v_hospital, (now() - interval '45 days')::timestamptz, (now() - interval '40 days')::timestamptz,
     (now() - interval '38 days')::timestamptz, (now() - interval '30 days')::timestamptz,
     5, 7, 15, 'no_bottleneck', 92, 'active', 'cs1@equipseva.in',
     'Smooth ramp; PM in 5d, AMC in 15d')
  RETURNING id INTO v_metric_a;

  INSERT INTO public.customer_first_value_metrics_r2512
    (hospital_user_id, signup_at, first_pm_at, first_repair_at, first_amc_at,
     days_to_first_pm, days_to_first_repair, days_to_first_amc,
     bottleneck_kind, north_star_score, status, owner_email, notes)
  VALUES
    (v_hospital, (now() - interval '30 days')::timestamptz, (now() - interval '20 days')::timestamptz,
     NULL, NULL, 10, NULL, NULL,
     'training_gap', 55, 'first_value', 'cs2@equipseva.in',
     'PM done but no repair or AMC yet; biomed staff needs training')
  RETURNING id INTO v_metric_b;

  INSERT INTO public.customer_first_value_metrics_r2512
    (hospital_user_id, signup_at, first_pm_at, first_repair_at, first_amc_at,
     days_to_first_pm, days_to_first_repair, days_to_first_amc,
     bottleneck_kind, north_star_score, status, owner_email, notes)
  VALUES
    (v_hospital, (now() - interval '60 days')::timestamptz, NULL, NULL, NULL,
     NULL, NULL, NULL,
     'no_engineer', 18, 'stuck', 'cs1@equipseva.in',
     'No engineer assigned in region; 60d stuck')
  RETURNING id INTO v_metric_c;

  INSERT INTO public.customer_first_value_metrics_r2512
    (hospital_user_id, signup_at, first_pm_at, first_repair_at, first_amc_at,
     days_to_first_pm, days_to_first_repair, days_to_first_amc,
     bottleneck_kind, north_star_score, status, owner_email, notes)
  VALUES
    (v_hospital, (now() - interval '12 days')::timestamptz, NULL, NULL, NULL,
     NULL, NULL, NULL,
     'missed_call', 30, 'onboarding', 'cs3@equipseva.in',
     'Called twice, both missed; retry scheduled')
  RETURNING id INTO v_metric_d;

  INSERT INTO public.first_value_action_log_r2512
    (metric_id, action_at, action_kind, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_metric_a, (now() - interval '40 days')::timestamptz, 'visit', 'positive',
     NULL, 'cs1@equipseva.in', 'done', 'On-site PM run; equipment baseline captured');

  INSERT INTO public.first_value_action_log_r2512
    (metric_id, action_at, action_kind, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_metric_b, (now() - interval '5 days')::timestamptz, 'training', 'neutral',
     (now() + interval '7 days')::timestamptz, 'cs2@equipseva.in', 'in_progress',
     'Biomed training scheduled; need to follow up next week');

  INSERT INTO public.first_value_action_log_r2512
    (metric_id, action_at, action_kind, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_metric_c, (now() - interval '10 days')::timestamptz, 'call', 'negative',
     (now() + interval '2 days')::timestamptz, 'cs1@equipseva.in', 'open',
     'Hospital frustrated; escalate to engineer hiring');

  INSERT INTO public.first_value_action_log_r2512
    (metric_id, action_at, action_kind, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_metric_d, (now() - interval '1 days')::timestamptz, 'call', 'pending',
     (now() + interval '1 days')::timestamptz, 'cs3@equipseva.in', 'open',
     'Retry call tomorrow morning');

  INSERT INTO public.first_value_action_log_r2512
    (metric_id, action_at, action_kind, outcome, follow_up_at, owner_email, status, notes)
  VALUES
    (v_metric_a, (now() - interval '15 days')::timestamptz, 'integration', 'positive',
     NULL, 'cs1@equipseva.in', 'done', 'CMMS integration complete; AMC tier confirmed');
END
$seed$;

-- ============================================================
-- RPC 1: list_first_value_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_first_value_r2512()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  signup_at timestamptz,
  first_pm_at timestamptz,
  first_repair_at timestamptz,
  first_amc_at timestamptz,
  days_to_first_pm int,
  days_to_first_repair int,
  days_to_first_amc int,
  bottleneck_kind text,
  north_star_score int,
  status text,
  owner_email text,
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
  SELECT m.id, m.hospital_user_id, p.email::text, m.signup_at,
         m.first_pm_at, m.first_repair_at, m.first_amc_at,
         m.days_to_first_pm, m.days_to_first_repair, m.days_to_first_amc,
         m.bottleneck_kind, m.north_star_score, m.status,
         m.owner_email, m.notes, m.created_at
  FROM public.customer_first_value_metrics_r2512 m
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  ORDER BY m.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_first_value_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_first_value_r2512() TO authenticated;

-- ============================================================
-- RPC 2: list_action_log_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_action_log_r2512()
RETURNS TABLE (
  id uuid,
  metric_id uuid,
  hospital_email text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  follow_up_at timestamptz,
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
  SELECT a.id, a.metric_id, p.email::text, a.action_at, a.action_kind,
         a.outcome, a.follow_up_at, a.owner_email, a.status, a.notes, a.created_at
  FROM public.first_value_action_log_r2512 a
  JOIN public.customer_first_value_metrics_r2512 m ON m.id = a.metric_id
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_log_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_log_r2512() TO authenticated;

-- ============================================================
-- RPC 3: stuck_hospitals_focus_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.stuck_hospitals_focus_r2512()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  days_since_signup int,
  bottleneck_kind text,
  north_star_score int,
  owner_email text,
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
  SELECT m.id, p.email::text,
         EXTRACT(DAY FROM (now() - m.signup_at))::int AS days_since_signup,
         m.bottleneck_kind, m.north_star_score, m.owner_email, m.notes
  FROM public.customer_first_value_metrics_r2512 m
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  WHERE m.status IN ('stuck','lapsed') OR m.north_star_score < 40
  ORDER BY m.north_star_score ASC, m.signup_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.stuck_hospitals_focus_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stuck_hospitals_focus_r2512() TO authenticated;

-- ============================================================
-- RPC 4: bottleneck_breakdown_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.bottleneck_breakdown_r2512()
RETURNS TABLE (
  bottleneck_kind text,
  hospital_count bigint,
  avg_north_star numeric,
  avg_days_to_pm numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.bottleneck_kind,
         COUNT(*)::bigint AS hospital_count,
         ROUND(AVG(m.north_star_score)::numeric, 1) AS avg_north_star,
         ROUND(AVG(m.days_to_first_pm)::numeric, 1) AS avg_days_to_pm
  FROM public.customer_first_value_metrics_r2512 m
  GROUP BY m.bottleneck_kind
  ORDER BY hospital_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bottleneck_breakdown_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bottleneck_breakdown_r2512() TO authenticated;

-- ============================================================
-- RPC 5: north_star_distribution_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.north_star_distribution_r2512()
RETURNS TABLE (
  bucket text,
  hospital_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT CASE
           WHEN m.north_star_score < 25 THEN '00-24 critical'
           WHEN m.north_star_score < 50 THEN '25-49 weak'
           WHEN m.north_star_score < 75 THEN '50-74 ok'
           ELSE '75-100 strong'
         END AS bucket,
         COUNT(*)::bigint AS hospital_count
  FROM public.customer_first_value_metrics_r2512 m
  GROUP BY bucket
  ORDER BY bucket;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.north_star_distribution_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.north_star_distribution_r2512() TO authenticated;

-- ============================================================
-- RPC 6: monthly_first_value_trend_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_first_value_trend_r2512()
RETURNS TABLE (
  month_start date,
  signups bigint,
  first_pm_count bigint,
  first_repair_count bigint,
  first_amc_count bigint,
  avg_days_to_pm numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', m.signup_at)::date AS month_start,
         COUNT(*)::bigint AS signups,
         COUNT(m.first_pm_at)::bigint AS first_pm_count,
         COUNT(m.first_repair_at)::bigint AS first_repair_count,
         COUNT(m.first_amc_at)::bigint AS first_amc_count,
         ROUND(AVG(m.days_to_first_pm)::numeric, 1) AS avg_days_to_pm
  FROM public.customer_first_value_metrics_r2512 m
  GROUP BY month_start
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_first_value_trend_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_first_value_trend_r2512() TO authenticated;

-- ============================================================
-- RPC 7: owner_load_r2512
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2512()
RETURNS TABLE (
  owner_email text,
  hospital_count bigint,
  stuck_count bigint,
  open_actions bigint,
  avg_north_star numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(m.owner_email, 'unassigned')::text AS owner_email,
         COUNT(DISTINCT m.id)::bigint AS hospital_count,
         COUNT(DISTINCT m.id) FILTER (WHERE m.status IN ('stuck','lapsed'))::bigint AS stuck_count,
         COUNT(a.id) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_actions,
         ROUND(AVG(m.north_star_score)::numeric, 1) AS avg_north_star
  FROM public.customer_first_value_metrics_r2512 m
  LEFT JOIN public.first_value_action_log_r2512 a ON a.metric_id = m.id
  GROUP BY COALESCE(m.owner_email, 'unassigned')
  ORDER BY hospital_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2512() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2512() TO authenticated;

