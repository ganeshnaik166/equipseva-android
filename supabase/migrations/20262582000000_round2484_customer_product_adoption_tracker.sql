-- Round r2484: customer-product-adoption-tracker
-- feature x hospital x adopted x usage frequency x value derived x stuck users x help-needed

BEGIN;

-- =====================================================================
-- TABLE 1: customer_product_adoption_r2484
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.customer_product_adoption_r2484 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  feature_name text NOT NULL,
  adopted boolean NOT NULL DEFAULT false,
  adopted_at timestamptz,
  usage_frequency_per_week int NOT NULL DEFAULT 0 CHECK (usage_frequency_per_week >= 0),
  value_derived_rupees bigint NOT NULL DEFAULT 0 CHECK (value_derived_rupees >= 0),
  stuck_user_count int NOT NULL DEFAULT 0 CHECK (stuck_user_count >= 0),
  help_needed boolean NOT NULL DEFAULT false,
  help_request_count int NOT NULL DEFAULT 0 CHECK (help_request_count >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'not_adopted' CHECK (status IN ('not_adopted','adopting','active','lapsed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpa_r2484_hospital ON public.customer_product_adoption_r2484(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cpa_r2484_feature ON public.customer_product_adoption_r2484(feature_name);
CREATE INDEX IF NOT EXISTS idx_cpa_r2484_status ON public.customer_product_adoption_r2484(status);
CREATE INDEX IF NOT EXISTS idx_cpa_r2484_help ON public.customer_product_adoption_r2484(help_needed);

ALTER TABLE public.customer_product_adoption_r2484 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_product_adoption_r2484;
CREATE POLICY founder_all ON public.customer_product_adoption_r2484
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: adoption_help_requests_r2484
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.adoption_help_requests_r2484 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  adoption_id uuid NOT NULL REFERENCES public.customer_product_adoption_r2484(id) ON DELETE CASCADE,
  request_at timestamptz NOT NULL DEFAULT now(),
  request_kind text NOT NULL CHECK (request_kind IN ('training','integration','bug','documentation','feature_clarification')),
  resolved_at timestamptz,
  owner_email text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ahr_r2484_adoption ON public.adoption_help_requests_r2484(adoption_id);
CREATE INDEX IF NOT EXISTS idx_ahr_r2484_kind ON public.adoption_help_requests_r2484(request_kind);
CREATE INDEX IF NOT EXISTS idx_ahr_r2484_outcome ON public.adoption_help_requests_r2484(outcome);

ALTER TABLE public.adoption_help_requests_r2484 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.adoption_help_requests_r2484;
CREATE POLICY founder_all ON public.adoption_help_requests_r2484
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $$
DECLARE
  v_hospital_a uuid;
  v_hospital_b uuid;
  v_hospital_c uuid;
  v_adopt_a uuid;
  v_adopt_b uuid;
  v_adopt_c uuid;
  v_adopt_d uuid;
  v_adopt_e uuid;
BEGIN
  SELECT id INTO v_hospital_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_hospital_c FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_hospital_a IS NULL THEN
    RAISE NOTICE 'r2484 seed skipped — no hospital_admin profiles found';
    RETURN;
  END IF;

  INSERT INTO public.customer_product_adoption_r2484
    (hospital_user_id, feature_name, adopted, adopted_at, usage_frequency_per_week, value_derived_rupees, stuck_user_count, help_needed, help_request_count, owner_email, status, notes)
    VALUES (v_hospital_a, 'amc_dashboard', true, (now() - interval '45 days')::timestamptz, 12, 180000, 0, false, 0, 'founder@equipseva.com', 'active', 'core feature — sticky')
    RETURNING id INTO v_adopt_a;

  INSERT INTO public.customer_product_adoption_r2484
    (hospital_user_id, feature_name, adopted, adopted_at, usage_frequency_per_week, value_derived_rupees, stuck_user_count, help_needed, help_request_count, owner_email, status, notes)
    VALUES (COALESCE(v_hospital_b, v_hospital_a), 'spot_audit_invitations', true, (now() - interval '20 days')::timestamptz, 4, 65000, 2, true, 3, 'cs@equipseva.com', 'adopting', 'training needed for compliance officer')
    RETURNING id INTO v_adopt_b;

  INSERT INTO public.customer_product_adoption_r2484
    (hospital_user_id, feature_name, adopted, adopted_at, usage_frequency_per_week, value_derived_rupees, stuck_user_count, help_needed, help_request_count, owner_email, status, notes)
    VALUES (COALESCE(v_hospital_c, v_hospital_a), 'cert_ladder_report', false, NULL, 0, 0, 5, true, 2, 'cs@equipseva.com', 'not_adopted', 'integration with HIS pending')
    RETURNING id INTO v_adopt_c;

  INSERT INTO public.customer_product_adoption_r2484
    (hospital_user_id, feature_name, adopted, adopted_at, usage_frequency_per_week, value_derived_rupees, stuck_user_count, help_needed, help_request_count, owner_email, status, notes)
    VALUES (v_hospital_a, 'engineer_rotation_calendar', true, (now() - interval '90 days')::timestamptz, 8, 95000, 1, false, 0, 'ops@equipseva.com', 'active', 'stable usage')
    RETURNING id INTO v_adopt_d;

  INSERT INTO public.customer_product_adoption_r2484
    (hospital_user_id, feature_name, adopted, adopted_at, usage_frequency_per_week, value_derived_rupees, stuck_user_count, help_needed, help_request_count, owner_email, status, notes)
    VALUES (COALESCE(v_hospital_b, v_hospital_a), 'gst_invoice_auto_dispatch', true, (now() - interval '120 days')::timestamptz, 2, 40000, 3, false, 1, 'finance@equipseva.com', 'lapsed', 'finance team switched to manual — recover')
    RETURNING id INTO v_adopt_e;

  INSERT INTO public.adoption_help_requests_r2484
    (adoption_id, request_at, request_kind, resolved_at, owner_email, outcome, notes)
  VALUES
    (v_adopt_b, (now() - interval '18 days')::timestamptz, 'training', (now() - interval '15 days')::timestamptz, 'cs@equipseva.com', 'positive', 'live demo with compliance team'),
    (v_adopt_b, (now() - interval '10 days')::timestamptz, 'documentation', (now() - interval '8 days')::timestamptz, 'cs@equipseva.com', 'neutral', 'shared SOP doc'),
    (v_adopt_b, (now() - interval '4 days')::timestamptz, 'feature_clarification', NULL, 'cs@equipseva.com', 'pending', 'unclear on rejection rules'),
    (v_adopt_c, (now() - interval '14 days')::timestamptz, 'integration', NULL, 'cs@equipseva.com', 'pending', 'awaiting HIS vendor confirmation'),
    (v_adopt_c, (now() - interval '6 days')::timestamptz, 'bug', NULL, 'eng@equipseva.com', 'pending', 'login redirect issue'),
    (v_adopt_e, (now() - interval '30 days')::timestamptz, 'training', (now() - interval '25 days')::timestamptz, 'finance@equipseva.com', 'negative', 'finance lead left org — replacement re-train needed');
END $$;

-- =====================================================================
-- RPC: list_adoption_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_adoption_r2484()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  feature_name text,
  adopted boolean,
  adopted_at timestamptz,
  usage_frequency_per_week int,
  value_derived_rupees bigint,
  stuck_user_count int,
  help_needed boolean,
  help_request_count int,
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
  SELECT a.id, a.hospital_user_id, a.feature_name, a.adopted, a.adopted_at,
         a.usage_frequency_per_week, a.value_derived_rupees, a.stuck_user_count,
         a.help_needed, a.help_request_count, a.owner_email, a.status, a.notes, a.created_at
  FROM public.customer_product_adoption_r2484 a
  ORDER BY a.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_adoption_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_adoption_r2484() TO authenticated;

-- =====================================================================
-- RPC: list_help_requests_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_help_requests_r2484()
RETURNS TABLE (
  id uuid,
  adoption_id uuid,
  feature_name text,
  request_at timestamptz,
  request_kind text,
  resolved_at timestamptz,
  owner_email text,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.adoption_id, a.feature_name, h.request_at, h.request_kind,
         h.resolved_at, h.owner_email, h.outcome, h.notes, h.created_at
  FROM public.adoption_help_requests_r2484 h
  JOIN public.customer_product_adoption_r2484 a ON a.id = h.adoption_id
  ORDER BY h.request_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_help_requests_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_help_requests_r2484() TO authenticated;

-- =====================================================================
-- RPC: stuck_users_focus_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.stuck_users_focus_r2484()
RETURNS TABLE (
  adoption_id uuid,
  hospital_user_id uuid,
  feature_name text,
  stuck_user_count int,
  help_request_count int,
  help_needed boolean,
  status text,
  owner_email text,
  unresolved_help_count bigint,
  focus_score bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, a.feature_name, a.stuck_user_count, a.help_request_count,
         a.help_needed, a.status, a.owner_email,
         COALESCE((SELECT count(*) FROM public.adoption_help_requests_r2484 h
                   WHERE h.adoption_id = a.id AND h.resolved_at IS NULL), 0) AS unresolved_help_count,
         ((a.stuck_user_count * 10) + (a.help_request_count * 5) +
          CASE WHEN a.help_needed THEN 25 ELSE 0 END +
          CASE WHEN a.status IN ('lapsed','dropped') THEN 30 ELSE 0 END)::bigint AS focus_score
  FROM public.customer_product_adoption_r2484 a
  WHERE a.stuck_user_count > 0 OR a.help_needed OR a.status IN ('lapsed','dropped')
  ORDER BY focus_score DESC, a.stuck_user_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.stuck_users_focus_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stuck_users_focus_r2484() TO authenticated;

-- =====================================================================
-- RPC: top_value_features_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_value_features_r2484()
RETURNS TABLE (
  feature_name text,
  hospital_count bigint,
  adopted_count bigint,
  total_value_rupees bigint,
  avg_usage_per_week numeric,
  active_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.feature_name,
         count(*)::bigint AS hospital_count,
         count(*) FILTER (WHERE a.adopted)::bigint AS adopted_count,
         COALESCE(sum(a.value_derived_rupees), 0)::bigint AS total_value_rupees,
         ROUND(AVG(a.usage_frequency_per_week)::numeric, 2) AS avg_usage_per_week,
         count(*) FILTER (WHERE a.status = 'active')::bigint AS active_count
  FROM public.customer_product_adoption_r2484 a
  GROUP BY a.feature_name
  ORDER BY total_value_rupees DESC, adopted_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_value_features_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_features_r2484() TO authenticated;

-- =====================================================================
-- RPC: feature_adoption_funnel_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.feature_adoption_funnel_r2484()
RETURNS TABLE (
  status text,
  cohort_count bigint,
  total_value_rupees bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM public.customer_product_adoption_r2484;
  RETURN QUERY
  SELECT a.status,
         count(*)::bigint AS cohort_count,
         COALESCE(sum(a.value_derived_rupees), 0)::bigint AS total_value_rupees,
         CASE WHEN v_total = 0 THEN 0::numeric
              ELSE ROUND((count(*)::numeric / v_total::numeric) * 100, 2)
         END AS pct_of_total
  FROM public.customer_product_adoption_r2484 a
  GROUP BY a.status
  ORDER BY
    CASE a.status
      WHEN 'not_adopted' THEN 1
      WHEN 'adopting' THEN 2
      WHEN 'active' THEN 3
      WHEN 'lapsed' THEN 4
      WHEN 'dropped' THEN 5
      ELSE 6
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.feature_adoption_funnel_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feature_adoption_funnel_r2484() TO authenticated;

-- =====================================================================
-- RPC: owner_load_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2484()
RETURNS TABLE (
  owner_email text,
  adoption_count bigint,
  active_count bigint,
  help_needed_count bigint,
  open_help_requests bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, 'unassigned') AS owner_email,
         count(*)::bigint AS adoption_count,
         count(*) FILTER (WHERE a.status = 'active')::bigint AS active_count,
         count(*) FILTER (WHERE a.help_needed)::bigint AS help_needed_count,
         COALESCE((SELECT count(*) FROM public.adoption_help_requests_r2484 h
                   WHERE h.owner_email = a.owner_email AND h.resolved_at IS NULL), 0) AS open_help_requests,
         COALESCE(sum(a.value_derived_rupees), 0)::bigint AS total_value_rupees
  FROM public.customer_product_adoption_r2484 a
  GROUP BY a.owner_email
  ORDER BY help_needed_count DESC, adoption_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2484() TO authenticated;

-- =====================================================================
-- RPC: weekly_adoption_trend_r2484
-- =====================================================================
CREATE OR REPLACE FUNCTION public.weekly_adoption_trend_r2484()
RETURNS TABLE (
  week_start timestamptz,
  adopted_count bigint,
  help_request_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '11 weeks'),
      date_trunc('week', now()),
      interval '1 week'
    )::timestamptz AS week_start
  )
  SELECT w.week_start,
         COALESCE((SELECT count(*) FROM public.customer_product_adoption_r2484 a
                   WHERE a.adopted_at >= w.week_start
                     AND a.adopted_at < (w.week_start + interval '1 week')), 0)::bigint AS adopted_count,
         COALESCE((SELECT count(*) FROM public.adoption_help_requests_r2484 h
                   WHERE h.request_at >= w.week_start
                     AND h.request_at < (w.week_start + interval '1 week')), 0)::bigint AS help_request_count,
         COALESCE((SELECT count(*) FROM public.adoption_help_requests_r2484 h
                   WHERE h.resolved_at >= w.week_start
                     AND h.resolved_at < (w.week_start + interval '1 week')), 0)::bigint AS resolved_count
  FROM weeks w
  ORDER BY w.week_start;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_adoption_trend_r2484() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_adoption_trend_r2484() TO authenticated;

