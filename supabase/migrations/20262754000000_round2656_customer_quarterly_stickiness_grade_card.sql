-- r2656 customer-quarterly-stickiness-grade-card
-- Tables: customer_stickiness_r2656 + stickiness_improvement_actions_r2656

BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_stickiness_r2656 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  equipment_count int NOT NULL DEFAULT 0,
  integration_depth_score int NOT NULL DEFAULT 0 CHECK (integration_depth_score BETWEEN 0 AND 100),
  switching_cost_rupees bigint NOT NULL DEFAULT 0,
  stickiness_grade text NOT NULL DEFAULT 'C' CHECK (stickiness_grade IN ('A','B','C','D','F')),
  owner_email text,
  status text NOT NULL DEFAULT 'strong' CHECK (status IN ('strong','eroding','weak','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_stickiness_r2656_hospital ON public.customer_stickiness_r2656(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_customer_stickiness_r2656_quarter ON public.customer_stickiness_r2656(quarter_label);
CREATE INDEX IF NOT EXISTS idx_customer_stickiness_r2656_grade ON public.customer_stickiness_r2656(stickiness_grade);
CREATE INDEX IF NOT EXISTS idx_customer_stickiness_r2656_status ON public.customer_stickiness_r2656(status);

ALTER TABLE public.customer_stickiness_r2656 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_stickiness_r2656;
CREATE POLICY founder_all ON public.customer_stickiness_r2656 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.stickiness_improvement_actions_r2656 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stickiness_id uuid NOT NULL REFERENCES public.customer_stickiness_r2656(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('integration_add','training','data_lock','multi_year_lock','exec_relationship')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stickiness_actions_r2656_stickiness ON public.stickiness_improvement_actions_r2656(stickiness_id);
CREATE INDEX IF NOT EXISTS idx_stickiness_actions_r2656_kind ON public.stickiness_improvement_actions_r2656(action_kind);
CREATE INDEX IF NOT EXISTS idx_stickiness_actions_r2656_status ON public.stickiness_improvement_actions_r2656(status);

ALTER TABLE public.stickiness_improvement_actions_r2656 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.stickiness_improvement_actions_r2656;
CREATE POLICY founder_all ON public.stickiness_improvement_actions_r2656 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_h4 uuid;
  v_s1 uuid;
  v_s2 uuid;
  v_s3 uuid;
  v_s4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h4 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h3, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;

  IF v_h1 IS NOT NULL THEN
    INSERT INTO public.customer_stickiness_r2656 (hospital_user_id, quarter_label, equipment_count, integration_depth_score, switching_cost_rupees, stickiness_grade, owner_email, status, notes)
    VALUES (v_h1, 'Q1-2026', 42, 88, 1850000, 'A', 'founder@equipseva.com', 'strong', 'Deep HIS integration plus multi-year lock')
    RETURNING id INTO v_s1;

    INSERT INTO public.stickiness_improvement_actions_r2656 (stickiness_id, action_at, action_kind, outcome, owner_email, status, notes)
    VALUES (v_s1, now() - interval '40 days', 'multi_year_lock', 'positive', 'founder@equipseva.com', 'done', 'Renewed 3-year AMC bundle'),
           (v_s1, now() - interval '12 days', 'exec_relationship', 'positive', 'founder@equipseva.com', 'done', 'Quarterly business review with CMO');
  END IF;

  IF v_h2 IS NOT NULL THEN
    INSERT INTO public.customer_stickiness_r2656 (hospital_user_id, quarter_label, equipment_count, integration_depth_score, switching_cost_rupees, stickiness_grade, owner_email, status, notes)
    VALUES (v_h2, 'Q1-2026', 18, 62, 540000, 'B', 'sales@equipseva.com', 'strong', 'Solid AMC base, integration light')
    RETURNING id INTO v_s2;

    INSERT INTO public.stickiness_improvement_actions_r2656 (stickiness_id, action_at, action_kind, outcome, owner_email, status, notes)
    VALUES (v_s2, now() - interval '20 days', 'integration_add', 'pending', 'sales@equipseva.com', 'open', 'PACS integration scoping in progress');
  END IF;

  IF v_h3 IS NOT NULL THEN
    INSERT INTO public.customer_stickiness_r2656 (hospital_user_id, quarter_label, equipment_count, integration_depth_score, switching_cost_rupees, stickiness_grade, owner_email, status, notes)
    VALUES (v_h3, 'Q1-2026', 7, 28, 95000, 'D', 'csm@equipseva.com', 'eroding', 'Low integration, RFP risk Q3')
    RETURNING id INTO v_s3;

    INSERT INTO public.stickiness_improvement_actions_r2656 (stickiness_id, action_at, action_kind, outcome, owner_email, status, notes)
    VALUES (v_s3, now() - interval '8 days', 'training', 'pending', 'csm@equipseva.com', 'open', 'Biomed team training scheduled'),
           (v_s3, now() - interval '3 days', 'data_lock', 'pending', 'csm@equipseva.com', 'open', 'Migrate maintenance history into our portal');
  END IF;

  IF v_h4 IS NOT NULL THEN
    INSERT INTO public.customer_stickiness_r2656 (hospital_user_id, quarter_label, equipment_count, integration_depth_score, switching_cost_rupees, stickiness_grade, owner_email, status, notes)
    VALUES (v_h4, 'Q4-2025', 3, 12, 22000, 'F', 'csm@equipseva.com', 'lost', 'Churned to in-house biomed team')
    RETURNING id INTO v_s4;

    INSERT INTO public.stickiness_improvement_actions_r2656 (stickiness_id, action_at, action_kind, outcome, owner_email, status, notes)
    VALUES (v_s4, now() - interval '60 days', 'exec_relationship', 'negative', 'csm@equipseva.com', 'dropped', 'Final save attempt failed');
  END IF;
END $seed$;

-- RPC 1: list_stickiness_r2656
CREATE OR REPLACE FUNCTION public.list_stickiness_r2656()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  quarter_label text,
  equipment_count int,
  integration_depth_score int,
  switching_cost_rupees bigint,
  stickiness_grade text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, p.email::text AS hospital_email,
         s.quarter_label, s.equipment_count, s.integration_depth_score,
         s.switching_cost_rupees, s.stickiness_grade, s.owner_email,
         s.status, s.notes, s.created_at
  FROM public.customer_stickiness_r2656 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.quarter_label DESC, s.stickiness_grade ASC, s.switching_cost_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_stickiness_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stickiness_r2656() TO authenticated;

-- RPC 2: list_improvement_actions_r2656
CREATE OR REPLACE FUNCTION public.list_improvement_actions_r2656()
RETURNS TABLE (
  id uuid,
  stickiness_id uuid,
  hospital_email text,
  quarter_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.stickiness_id, p.email::text AS hospital_email,
         s.quarter_label, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes, a.created_at
  FROM public.stickiness_improvement_actions_r2656 a
  JOIN public.customer_stickiness_r2656 s ON s.id = a.stickiness_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_improvement_actions_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_improvement_actions_r2656() TO authenticated;

-- RPC 3: top_weak_focus_r2656
CREATE OR REPLACE FUNCTION public.top_weak_focus_r2656()
RETURNS TABLE (
  hospital_email text,
  quarter_label text,
  stickiness_grade text,
  integration_depth_score int,
  switching_cost_rupees bigint,
  equipment_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email::text AS hospital_email, s.quarter_label, s.stickiness_grade,
         s.integration_depth_score, s.switching_cost_rupees, s.equipment_count, s.status
  FROM public.customer_stickiness_r2656 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.stickiness_grade IN ('C','D','F') OR s.status IN ('eroding','weak','lost')
  ORDER BY
    CASE s.stickiness_grade WHEN 'F' THEN 0 WHEN 'D' THEN 1 WHEN 'C' THEN 2 ELSE 3 END ASC,
    s.switching_cost_rupees DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_weak_focus_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_weak_focus_r2656() TO authenticated;

-- RPC 4: grade_distribution_r2656
CREATE OR REPLACE FUNCTION public.grade_distribution_r2656()
RETURNS TABLE (
  stickiness_grade text,
  customer_count bigint,
  avg_integration_depth numeric,
  total_switching_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stickiness_grade,
         COUNT(*)::bigint AS customer_count,
         ROUND(AVG(s.integration_depth_score)::numeric, 1) AS avg_integration_depth,
         COALESCE(SUM(s.switching_cost_rupees), 0)::bigint AS total_switching_cost_rupees
  FROM public.customer_stickiness_r2656 s
  GROUP BY s.stickiness_grade
  ORDER BY s.stickiness_grade ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.grade_distribution_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_distribution_r2656() TO authenticated;

-- RPC 5: status_funnel_r2656
CREATE OR REPLACE FUNCTION public.status_funnel_r2656()
RETURNS TABLE (
  status text,
  customer_count bigint,
  total_switching_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status,
         COUNT(*)::bigint AS customer_count,
         COALESCE(SUM(s.switching_cost_rupees), 0)::bigint AS total_switching_cost_rupees
  FROM public.customer_stickiness_r2656 s
  GROUP BY s.status
  ORDER BY
    CASE s.status WHEN 'strong' THEN 0 WHEN 'eroding' THEN 1 WHEN 'weak' THEN 2 WHEN 'lost' THEN 3 END ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2656() TO authenticated;

-- RPC 6: quarterly_stickiness_trend_r2656
CREATE OR REPLACE FUNCTION public.quarterly_stickiness_trend_r2656()
RETURNS TABLE (
  quarter_label text,
  customer_count bigint,
  avg_integration_depth numeric,
  total_switching_cost_rupees bigint,
  grade_a_count bigint,
  grade_f_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         COUNT(*)::bigint AS customer_count,
         ROUND(AVG(s.integration_depth_score)::numeric, 1) AS avg_integration_depth,
         COALESCE(SUM(s.switching_cost_rupees), 0)::bigint AS total_switching_cost_rupees,
         COUNT(*) FILTER (WHERE s.stickiness_grade = 'A')::bigint AS grade_a_count,
         COUNT(*) FILTER (WHERE s.stickiness_grade = 'F')::bigint AS grade_f_count
  FROM public.customer_stickiness_r2656 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_stickiness_trend_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_stickiness_trend_r2656() TO authenticated;

-- RPC 7: owner_load_r2656
CREATE OR REPLACE FUNCTION public.owner_load_r2656()
RETURNS TABLE (
  owner_email text,
  account_count bigint,
  open_actions bigint,
  total_switching_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(s.owner_email, 'unassigned') AS owner_email,
         COUNT(DISTINCT s.id)::bigint AS account_count,
         COUNT(a.id) FILTER (WHERE a.status = 'open')::bigint AS open_actions,
         COALESCE(SUM(s.switching_cost_rupees), 0)::bigint AS total_switching_cost_rupees
  FROM public.customer_stickiness_r2656 s
  LEFT JOIN public.stickiness_improvement_actions_r2656 a ON a.stickiness_id = s.id
  GROUP BY COALESCE(s.owner_email, 'unassigned')
  ORDER BY account_count DESC, total_switching_cost_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2656() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2656() TO authenticated;

COMMIT;
