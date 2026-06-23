BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_journey_stages_r2360 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  organization_name text,
  current_stage text NOT NULL CHECK (current_stage IN ('prospect','onboard','active','renewal','advocate')),
  stage_entered_at timestamptz NOT NULL DEFAULT now(),
  prev_stage text CHECK (prev_stage IN ('prospect','onboard','active','renewal','advocate')),
  health_score integer NOT NULL DEFAULT 50 CHECK (health_score BETWEEN 0 AND 100),
  arr_rupees bigint NOT NULL DEFAULT 0,
  owner_csm_email text,
  next_action text,
  next_action_due_at timestamptz,
  is_at_risk boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cjs_r2360_stage ON public.customer_journey_stages_r2360(current_stage);
CREATE INDEX IF NOT EXISTS idx_cjs_r2360_cust ON public.customer_journey_stages_r2360(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_cjs_r2360_risk ON public.customer_journey_stages_r2360(is_at_risk);

CREATE TABLE IF NOT EXISTS public.customer_journey_transitions_r2360 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journey_id uuid NOT NULL REFERENCES public.customer_journey_stages_r2360(id) ON DELETE CASCADE,
  from_stage text CHECK (from_stage IN ('prospect','onboard','active','renewal','advocate')),
  to_stage text NOT NULL CHECK (to_stage IN ('prospect','onboard','active','renewal','advocate')),
  transitioned_at timestamptz NOT NULL DEFAULT now(),
  days_in_prev_stage integer,
  reason text,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cjt_r2360_journey ON public.customer_journey_transitions_r2360(journey_id);
CREATE INDEX IF NOT EXISTS idx_cjt_r2360_at ON public.customer_journey_transitions_r2360(transitioned_at DESC);

ALTER TABLE public.customer_journey_stages_r2360 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_journey_transitions_r2360 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_journey_stages_r2360;
CREATE POLICY founder_all ON public.customer_journey_stages_r2360
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_journey_transitions_r2360;
CREATE POLICY founder_all ON public.customer_journey_transitions_r2360
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: stage distribution snapshot
CREATE OR REPLACE FUNCTION public.r2360_stage_distribution()
RETURNS TABLE(stage text, customer_count bigint, total_arr_rupees bigint, avg_health numeric, at_risk_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.stage::text,
    COALESCE(c.cnt, 0) AS customer_count,
    COALESCE(c.arr, 0) AS total_arr_rupees,
    COALESCE(c.avg_h, 0) AS avg_health,
    COALESCE(c.risk, 0) AS at_risk_count
  FROM (VALUES ('prospect'),('onboard'),('active'),('renewal'),('advocate')) AS s(stage)
  LEFT JOIN (
    SELECT current_stage,
           count(*)::bigint AS cnt,
           sum(arr_rupees)::bigint AS arr,
           round(avg(health_score)::numeric, 1) AS avg_h,
           count(*) FILTER (WHERE is_at_risk)::bigint AS risk
    FROM public.customer_journey_stages_r2360
    GROUP BY current_stage
  ) c ON c.current_stage = s.stage
  ORDER BY array_position(ARRAY['prospect','onboard','active','renewal','advocate'], s.stage);
END;
$$;

-- RPC 2: avg time in each stage
CREATE OR REPLACE FUNCTION public.r2360_avg_stage_duration()
RETURNS TABLE(stage text, avg_days numeric, samples bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT from_stage::text AS stage,
         round(avg(days_in_prev_stage)::numeric, 1) AS avg_days,
         count(*)::bigint AS samples
  FROM public.customer_journey_transitions_r2360
  WHERE from_stage IS NOT NULL AND days_in_prev_stage IS NOT NULL
  GROUP BY from_stage
  ORDER BY avg_days DESC NULLS LAST;
END;
$$;

-- RPC 3: at-risk customers
CREATE OR REPLACE FUNCTION public.r2360_at_risk_list()
RETURNS TABLE(id uuid, customer_name text, customer_email text, current_stage text, health_score integer, arr_rupees bigint, owner_csm_email text, next_action text, next_action_due_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.customer_name, s.customer_email, s.current_stage, s.health_score, s.arr_rupees, s.owner_csm_email, s.next_action, s.next_action_due_at
  FROM public.customer_journey_stages_r2360 s
  WHERE s.is_at_risk = true
  ORDER BY s.health_score ASC, s.arr_rupees DESC
  LIMIT 200;
END;
$$;

-- RPC 4: recent transitions
CREATE OR REPLACE FUNCTION public.r2360_recent_transitions(p_limit integer DEFAULT 50)
RETURNS TABLE(id uuid, customer_name text, from_stage text, to_stage text, transitioned_at timestamptz, days_in_prev_stage integer, reason text, actor_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, s.customer_name, t.from_stage, t.to_stage, t.transitioned_at, t.days_in_prev_stage, t.reason, t.actor_email
  FROM public.customer_journey_transitions_r2360 t
  JOIN public.customer_journey_stages_r2360 s ON s.id = t.journey_id
  ORDER BY t.transitioned_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- RPC 5: stuck customers (in stage too long)
CREATE OR REPLACE FUNCTION public.r2360_stuck_customers(p_min_days integer DEFAULT 30)
RETURNS TABLE(id uuid, customer_name text, current_stage text, days_in_stage integer, arr_rupees bigint, health_score integer, owner_csm_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.customer_name, s.current_stage,
         extract(day FROM (now() - s.stage_entered_at))::integer AS days_in_stage,
         s.arr_rupees, s.health_score, s.owner_csm_email
  FROM public.customer_journey_stages_r2360 s
  WHERE s.stage_entered_at < now() - make_interval(days => GREATEST(1, p_min_days))
    AND s.current_stage IN ('prospect','onboard','renewal')
  ORDER BY s.stage_entered_at ASC
  LIMIT 200;
END;
$$;

-- RPC 6: advocates (top of funnel)
CREATE OR REPLACE FUNCTION public.r2360_advocates_list()
RETURNS TABLE(id uuid, customer_name text, customer_email text, organization_name text, arr_rupees bigint, health_score integer, stage_entered_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.customer_name, s.customer_email, s.organization_name, s.arr_rupees, s.health_score, s.stage_entered_at
  FROM public.customer_journey_stages_r2360 s
  WHERE s.current_stage = 'advocate'
  ORDER BY s.arr_rupees DESC, s.health_score DESC
  LIMIT 100;
END;
$$;

-- RPC 7: KPI summary
CREATE OR REPLACE FUNCTION public.r2360_kpi_summary()
RETURNS TABLE(total_customers bigint, total_arr_rupees bigint, at_risk_count bigint, avg_health numeric, advocate_count bigint, prospect_count bigint, renewal_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    COALESCE(sum(arr_rupees),0)::bigint,
    count(*) FILTER (WHERE is_at_risk)::bigint,
    COALESCE(round(avg(health_score)::numeric, 1), 0),
    count(*) FILTER (WHERE current_stage='advocate')::bigint,
    count(*) FILTER (WHERE current_stage='prospect')::bigint,
    count(*) FILTER (WHERE current_stage='renewal')::bigint
  FROM public.customer_journey_stages_r2360;
END;
$$;

REVOKE ALL ON FUNCTION public.r2360_stage_distribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_avg_stage_duration() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_at_risk_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_recent_transitions(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_stuck_customers(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_advocates_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2360_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2360_stage_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_avg_stage_duration() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_at_risk_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_recent_transitions(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_stuck_customers(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_advocates_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2360_kpi_summary() TO authenticated;

COMMIT;
