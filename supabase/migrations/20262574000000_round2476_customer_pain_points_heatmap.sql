-- Round 2476: Customer Pain Points Heatmap
-- Tracks pain points across hospitals with frequency, severity, revenue impact, kill priority

CREATE TABLE IF NOT EXISTS public.customer_pain_points_r2476 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pain_point_signature text NOT NULL,
  pain_kind text NOT NULL CHECK (pain_kind IN ('workflow','billing','communication','equipment','training','scheduling','reporting')),
  frequency_score int NOT NULL CHECK (frequency_score BETWEEN 0 AND 100),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  associated_revenue_rupees bigint NOT NULL DEFAULT 0,
  kill_priority int NOT NULL CHECK (kill_priority BETWEEN 1 AND 5),
  fix_team_owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','fixed','dropped')),
  reported_at timestamptz NOT NULL DEFAULT now(),
  fixed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pain_point_fix_actions_r2476 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pain_id uuid NOT NULL REFERENCES public.customer_pain_points_r2476(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('product','process','training','policy','staffing')),
  action_summary text NOT NULL,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  follow_up_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_pain_points_r2476 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pain_point_fix_actions_r2476 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_pain_points_r2476;
CREATE POLICY founder_all ON public.customer_pain_points_r2476 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.pain_point_fix_actions_r2476;
CREATE POLICY founder_all ON public.pain_point_fix_actions_r2476 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_hospital uuid;
  v_pain1 uuid;
  v_pain2 uuid;
  v_pain3 uuid;
  v_pain4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' LIMIT 1;
  IF v_hospital IS NULL THEN
    SELECT id INTO v_hospital FROM public.profiles LIMIT 1;
  END IF;

  IF v_hospital IS NOT NULL THEN
    INSERT INTO public.customer_pain_points_r2476 (hospital_user_id, pain_point_signature, pain_kind, frequency_score, severity, associated_revenue_rupees, kill_priority, fix_team_owner_email, status, reported_at, notes)
    VALUES (v_hospital, 'No SLA visibility on repair ETA', 'communication', 85, 'high', 480000, 1, 'product@equipseva.in', 'in_progress', now() - interval '20 days', 'Hospital ops complains weekly')
    RETURNING id INTO v_pain1;

    INSERT INTO public.customer_pain_points_r2476 (hospital_user_id, pain_point_signature, pain_kind, frequency_score, severity, associated_revenue_rupees, kill_priority, fix_team_owner_email, status, reported_at, notes)
    VALUES (v_hospital, 'GST invoice format mismatch with hospital ERP', 'billing', 70, 'medium', 220000, 2, 'finance@equipseva.in', 'open', now() - interval '15 days', 'AP team requests new format')
    RETURNING id INTO v_pain2;

    INSERT INTO public.customer_pain_points_r2476 (hospital_user_id, pain_point_signature, pain_kind, frequency_score, severity, associated_revenue_rupees, kill_priority, fix_team_owner_email, status, reported_at, notes)
    VALUES (v_hospital, 'Engineer scheduling collides with OT hours', 'scheduling', 60, 'high', 380000, 1, 'ops@equipseva.in', 'open', now() - interval '10 days', 'Need OT-aware scheduler')
    RETURNING id INTO v_pain3;

    INSERT INTO public.customer_pain_points_r2476 (hospital_user_id, pain_point_signature, pain_kind, frequency_score, severity, associated_revenue_rupees, kill_priority, fix_team_owner_email, status, reported_at, fixed_at, notes)
    VALUES (v_hospital, 'Training material outdated for ventilators', 'training', 40, 'low', 90000, 4, 'training@equipseva.in', 'fixed', now() - interval '45 days', now() - interval '5 days', 'Refreshed module v2')
    RETURNING id INTO v_pain4;

    INSERT INTO public.pain_point_fix_actions_r2476 (pain_id, action_at, action_kind, action_summary, outcome, owner_email, follow_up_at, status, notes)
    VALUES (v_pain1, now() - interval '12 days', 'product', 'Shipped repair-job ETA widget v1', 'positive', 'product@equipseva.in', now() + interval '7 days', 'open', 'Hospital piloted Tier-1');

    INSERT INTO public.pain_point_fix_actions_r2476 (pain_id, action_at, action_kind, action_summary, outcome, owner_email, follow_up_at, status, notes)
    VALUES (v_pain2, now() - interval '8 days', 'process', 'Mapped ERP fields to GST invoice template', 'pending', 'finance@equipseva.in', now() + interval '14 days', 'open', 'Awaiting hospital sign-off');

    INSERT INTO public.pain_point_fix_actions_r2476 (pain_id, action_at, action_kind, action_summary, outcome, owner_email, follow_up_at, status, notes)
    VALUES (v_pain3, now() - interval '5 days', 'staffing', 'Added evening-shift engineer to OT-heavy hospitals', 'neutral', 'ops@equipseva.in', now() + interval '21 days', 'open', '2 engineers onboarded');

    INSERT INTO public.pain_point_fix_actions_r2476 (pain_id, action_at, action_kind, action_summary, outcome, owner_email, status, notes)
    VALUES (v_pain4, now() - interval '5 days', 'training', 'Published ventilator module v2 with new SOPs', 'positive', 'training@equipseva.in', 'done', 'Closed loop');
  END IF;
END
$seed$;

-- RPC 1: list_pain_points_r2476
CREATE OR REPLACE FUNCTION public.list_pain_points_r2476()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  pain_point_signature text,
  pain_kind text,
  frequency_score int,
  severity text,
  associated_revenue_rupees bigint,
  kill_priority int,
  fix_team_owner_email text,
  status text,
  reported_at timestamptz,
  fixed_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, pr.email, p.pain_point_signature, p.pain_kind, p.frequency_score, p.severity,
         p.associated_revenue_rupees, p.kill_priority, p.fix_team_owner_email, p.status,
         p.reported_at, p.fixed_at, p.notes
  FROM public.customer_pain_points_r2476 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  ORDER BY p.kill_priority ASC, p.frequency_score DESC, p.reported_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pain_points_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pain_points_r2476() TO authenticated;

-- RPC 2: list_fix_actions_r2476
CREATE OR REPLACE FUNCTION public.list_fix_actions_r2476()
RETURNS TABLE (
  id uuid,
  pain_id uuid,
  pain_point_signature text,
  action_at timestamptz,
  action_kind text,
  action_summary text,
  outcome text,
  owner_email text,
  follow_up_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pain_id, p.pain_point_signature, a.action_at, a.action_kind, a.action_summary,
         a.outcome, a.owner_email, a.follow_up_at, a.status, a.notes
  FROM public.pain_point_fix_actions_r2476 a
  LEFT JOIN public.customer_pain_points_r2476 p ON p.id = a.pain_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_fix_actions_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_fix_actions_r2476() TO authenticated;

-- RPC 3: top_kill_priority_r2476
CREATE OR REPLACE FUNCTION public.top_kill_priority_r2476()
RETURNS TABLE (
  id uuid,
  pain_point_signature text,
  pain_kind text,
  hospital_email text,
  kill_priority int,
  frequency_score int,
  severity text,
  associated_revenue_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pain_point_signature, p.pain_kind, pr.email, p.kill_priority, p.frequency_score,
         p.severity, p.associated_revenue_rupees, p.status
  FROM public.customer_pain_points_r2476 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  WHERE p.status IN ('open','in_progress')
  ORDER BY p.kill_priority ASC, p.associated_revenue_rupees DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_kill_priority_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_kill_priority_r2476() TO authenticated;

-- RPC 4: severity_x_frequency_grid_r2476
CREATE OR REPLACE FUNCTION public.severity_x_frequency_grid_r2476()
RETURNS TABLE (
  severity text,
  frequency_bucket text,
  pain_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.severity,
         CASE
           WHEN p.frequency_score >= 75 THEN 'very_high'
           WHEN p.frequency_score >= 50 THEN 'high'
           WHEN p.frequency_score >= 25 THEN 'medium'
           ELSE 'low'
         END AS frequency_bucket,
         COUNT(*)::bigint AS pain_count,
         COALESCE(SUM(p.associated_revenue_rupees), 0)::bigint AS total_revenue_rupees
  FROM public.customer_pain_points_r2476 p
  GROUP BY p.severity,
           CASE
             WHEN p.frequency_score >= 75 THEN 'very_high'
             WHEN p.frequency_score >= 50 THEN 'high'
             WHEN p.frequency_score >= 25 THEN 'medium'
             ELSE 'low'
           END
  ORDER BY p.severity, frequency_bucket;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.severity_x_frequency_grid_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_x_frequency_grid_r2476() TO authenticated;

-- RPC 5: top_hospitals_by_pain_r2476
CREATE OR REPLACE FUNCTION public.top_hospitals_by_pain_r2476()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  pain_count bigint,
  open_count bigint,
  total_revenue_rupees bigint,
  avg_frequency numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.hospital_user_id,
         pr.email,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.status IN ('open','in_progress'))::bigint,
         COALESCE(SUM(p.associated_revenue_rupees), 0)::bigint,
         ROUND(AVG(p.frequency_score)::numeric, 2)
  FROM public.customer_pain_points_r2476 p
  LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
  GROUP BY p.hospital_user_id, pr.email
  ORDER BY COUNT(*) FILTER (WHERE p.status IN ('open','in_progress')) DESC,
           SUM(p.associated_revenue_rupees) DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_pain_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_pain_r2476() TO authenticated;

-- RPC 6: kind_breakdown_r2476
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2476()
RETURNS TABLE (
  pain_kind text,
  pain_count bigint,
  open_count bigint,
  fixed_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pain_kind,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.status IN ('open','in_progress'))::bigint,
         COUNT(*) FILTER (WHERE p.status = 'fixed')::bigint,
         COALESCE(SUM(p.associated_revenue_rupees), 0)::bigint
  FROM public.customer_pain_points_r2476 p
  GROUP BY p.pain_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2476() TO authenticated;

-- RPC 7: monthly_fix_velocity_r2476
CREATE OR REPLACE FUNCTION public.monthly_fix_velocity_r2476()
RETURNS TABLE (
  month_start timestamptz,
  actions_logged bigint,
  positive_outcomes bigint,
  pain_points_fixed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH actions_by_month AS (
    SELECT date_trunc('month', a.action_at) AS m,
           COUNT(*)::bigint AS actions_logged,
           COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_outcomes
    FROM public.pain_point_fix_actions_r2476 a
    GROUP BY date_trunc('month', a.action_at)
  ),
  fixed_by_month AS (
    SELECT date_trunc('month', p.fixed_at) AS m,
           COUNT(*)::bigint AS pain_points_fixed
    FROM public.customer_pain_points_r2476 p
    WHERE p.fixed_at IS NOT NULL
    GROUP BY date_trunc('month', p.fixed_at)
  )
  SELECT COALESCE(ab.m, fb.m) AS month_start,
         COALESCE(ab.actions_logged, 0),
         COALESCE(ab.positive_outcomes, 0),
         COALESCE(fb.pain_points_fixed, 0)
  FROM actions_by_month ab
  FULL OUTER JOIN fixed_by_month fb ON ab.m = fb.m
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_fix_velocity_r2476() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_fix_velocity_r2476() TO authenticated;
