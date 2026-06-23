-- Round r2479: hospital-chain-pricing-elasticity-experiments
-- Tracks chain x price test x variant x conversion x ARPU lift x churn impact x decision.

CREATE TABLE IF NOT EXISTS public.chain_pricing_experiments_r2479 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  experiment_name text NOT NULL,
  variant_kind text NOT NULL CHECK (variant_kind IN ('control','test_5','test_10','test_15','test_20')),
  price_increase_pct numeric NOT NULL DEFAULT 0 CHECK (price_increase_pct >= 0 AND price_increase_pct <= 100),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  conversion_pct numeric NOT NULL DEFAULT 0 CHECK (conversion_pct >= 0 AND conversion_pct <= 100),
  arpu_lift_rupees bigint NOT NULL DEFAULT 0,
  churn_impact_pct numeric NOT NULL DEFAULT 0,
  decision text NOT NULL DEFAULT 'extend' CHECK (decision IN ('adopt','reject','extend','dropped')),
  decision_at timestamptz,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pricing_experiment_observations_r2479 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id uuid NOT NULL REFERENCES public.chain_pricing_experiments_r2479(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  observation_kind text NOT NULL CHECK (observation_kind IN ('conversion','churn','csat','upsell','escalation')),
  observation_value numeric NOT NULL DEFAULT 0,
  observation_summary text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_pricing_experiments_r2479 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_experiment_observations_r2479 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_pricing_experiments_r2479;
CREATE POLICY founder_all ON public.chain_pricing_experiments_r2479
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.pricing_experiment_observations_r2479;
CREATE POLICY founder_all ON public.pricing_experiment_observations_r2479
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed experiments
INSERT INTO public.chain_pricing_experiments_r2479
  (chain_name, experiment_name, variant_kind, price_increase_pct, started_at, ended_at, conversion_pct, arpu_lift_rupees, churn_impact_pct, decision, decision_at, owner_email, notes)
VALUES
  ('Apollo Group', 'AMC Tier 2 +10% Q2', 'test_10', 10, (now() - interval '60 days')::timestamptz, (now() - interval '15 days')::timestamptz, 72.5, 18500, 1.2, 'adopt', (now() - interval '12 days')::timestamptz, 'pricing@equipseva.in', 'Strong adoption at +10%; minor churn signal acceptable'),
  ('Yashoda Hospitals', 'AMC Tier 3 +15% Pilot', 'test_15', 15, (now() - interval '45 days')::timestamptz, NULL, 58.0, 24500, 3.4, 'extend', NULL, 'pricing@equipseva.in', 'Mixed signal; extend by 30 days'),
  ('Care Hospitals', 'Repair Rate +5% Control', 'control', 0, (now() - interval '90 days')::timestamptz, (now() - interval '30 days')::timestamptz, 88.0, 0, 0.4, 'reject', (now() - interval '28 days')::timestamptz, 'pricing@equipseva.in', 'Baseline established; no change needed'),
  ('KIMS Group', 'AMC Premium +20% Stretch', 'test_20', 20, (now() - interval '30 days')::timestamptz, NULL, 41.0, 32000, 6.8, 'dropped', (now() - interval '5 days')::timestamptz, 'pricing@equipseva.in', 'Too aggressive; churn risk too high'),
  ('Continental Hospitals', 'AMC Basic +5% A/B', 'test_5', 5, (now() - interval '75 days')::timestamptz, (now() - interval '20 days')::timestamptz, 81.5, 9500, 0.6, 'adopt', (now() - interval '18 days')::timestamptz, 'pricing@equipseva.in', 'Safe lift; no churn impact');

-- Seed observations linked to first experiment
INSERT INTO public.pricing_experiment_observations_r2479
  (experiment_id, observed_at, observation_kind, observation_value, observation_summary, notes)
SELECT id, (now() - interval '50 days')::timestamptz, 'conversion', 70.2, 'Week 1 conversion rate', 'Initial signal positive' FROM public.chain_pricing_experiments_r2479 WHERE experiment_name = 'AMC Tier 2 +10% Q2' LIMIT 1;

INSERT INTO public.pricing_experiment_observations_r2479
  (experiment_id, observed_at, observation_kind, observation_value, observation_summary, notes)
SELECT id, (now() - interval '40 days')::timestamptz, 'churn', 1.0, 'Churn ticked up slightly', 'Within tolerance' FROM public.chain_pricing_experiments_r2479 WHERE experiment_name = 'AMC Tier 2 +10% Q2' LIMIT 1;

INSERT INTO public.pricing_experiment_observations_r2479
  (experiment_id, observed_at, observation_kind, observation_value, observation_summary, notes)
SELECT id, (now() - interval '30 days')::timestamptz, 'csat', 8.4, 'CSAT remained strong', 'Customers accepting price lift' FROM public.chain_pricing_experiments_r2479 WHERE experiment_name = 'AMC Tier 2 +10% Q2' LIMIT 1;

INSERT INTO public.pricing_experiment_observations_r2479
  (experiment_id, observed_at, observation_kind, observation_value, observation_summary, notes)
SELECT id, (now() - interval '25 days')::timestamptz, 'upsell', 12.0, 'Bundle attach rate', 'Tier upgrade triggered' FROM public.chain_pricing_experiments_r2479 WHERE experiment_name = 'AMC Tier 3 +15% Pilot' LIMIT 1;

INSERT INTO public.pricing_experiment_observations_r2479
  (experiment_id, observed_at, observation_kind, observation_value, observation_summary, notes)
SELECT id, (now() - interval '10 days')::timestamptz, 'escalation', 1.0, 'One escalation logged', 'Procurement asked for justification' FROM public.chain_pricing_experiments_r2479 WHERE experiment_name = 'AMC Premium +20% Stretch' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_experiments_r2479()
RETURNS TABLE (
  id uuid,
  chain_name text,
  experiment_name text,
  variant_kind text,
  price_increase_pct numeric,
  started_at timestamptz,
  ended_at timestamptz,
  conversion_pct numeric,
  arpu_lift_rupees bigint,
  churn_impact_pct numeric,
  decision text,
  decision_at timestamptz,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_name, e.experiment_name, e.variant_kind, e.price_increase_pct,
         e.started_at, e.ended_at, e.conversion_pct, e.arpu_lift_rupees,
         e.churn_impact_pct, e.decision, e.decision_at, e.owner_email, e.notes
  FROM public.chain_pricing_experiments_r2479 e
  ORDER BY e.started_at DESC NULLS LAST, e.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_experiments_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_experiments_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_observations_r2479()
RETURNS TABLE (
  id uuid,
  experiment_id uuid,
  experiment_name text,
  chain_name text,
  observed_at timestamptz,
  observation_kind text,
  observation_value numeric,
  observation_summary text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.experiment_id, e.experiment_name, e.chain_name,
         o.observed_at, o.observation_kind, o.observation_value,
         o.observation_summary, o.notes
  FROM public.pricing_experiment_observations_r2479 o
  JOIN public.chain_pricing_experiments_r2479 e ON e.id = o.experiment_id
  ORDER BY o.observed_at DESC NULLS LAST, o.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_observations_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_observations_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_arpu_lift_r2479()
RETURNS TABLE (
  experiment_id uuid,
  chain_name text,
  experiment_name text,
  variant_kind text,
  arpu_lift_rupees bigint,
  conversion_pct numeric,
  churn_impact_pct numeric,
  decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_name, e.experiment_name, e.variant_kind,
         e.arpu_lift_rupees, e.conversion_pct, e.churn_impact_pct, e.decision
  FROM public.chain_pricing_experiments_r2479 e
  ORDER BY e.arpu_lift_rupees DESC NULLS LAST
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_arpu_lift_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arpu_lift_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.variant_kind_breakdown_r2479()
RETURNS TABLE (
  variant_kind text,
  experiments_count bigint,
  avg_conversion_pct numeric,
  avg_arpu_lift_rupees numeric,
  avg_churn_impact_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.variant_kind,
         COUNT(*)::bigint,
         ROUND(AVG(e.conversion_pct)::numeric, 2),
         ROUND(AVG(e.arpu_lift_rupees)::numeric, 2),
         ROUND(AVG(e.churn_impact_pct)::numeric, 2)
  FROM public.chain_pricing_experiments_r2479 e
  GROUP BY e.variant_kind
  ORDER BY e.variant_kind;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.variant_kind_breakdown_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.variant_kind_breakdown_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.decision_funnel_r2479()
RETURNS TABLE (
  decision text,
  experiments_count bigint,
  avg_arpu_lift_rupees numeric,
  avg_churn_impact_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.decision,
         COUNT(*)::bigint,
         ROUND(AVG(e.arpu_lift_rupees)::numeric, 2),
         ROUND(AVG(e.churn_impact_pct)::numeric, 2)
  FROM public.chain_pricing_experiments_r2479 e
  GROUP BY e.decision
  ORDER BY e.decision;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_funnel_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_funnel_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_observation_trend_r2479()
RETURNS TABLE (
  week_start timestamptz,
  observations_count bigint,
  avg_observation_value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', o.observed_at) AS week_start,
         COUNT(*)::bigint,
         ROUND(AVG(o.observation_value)::numeric, 2)
  FROM public.pricing_experiment_observations_r2479 o
  GROUP BY date_trunc('week', o.observed_at)
  ORDER BY week_start DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_observation_trend_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_observation_trend_r2479() TO authenticated;

CREATE OR REPLACE FUNCTION public.chain_summary_r2479()
RETURNS TABLE (
  chain_name text,
  experiments_count bigint,
  total_arpu_lift_rupees bigint,
  avg_conversion_pct numeric,
  avg_churn_impact_pct numeric,
  adopt_count bigint,
  reject_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_name,
         COUNT(*)::bigint,
         SUM(e.arpu_lift_rupees)::bigint,
         ROUND(AVG(e.conversion_pct)::numeric, 2),
         ROUND(AVG(e.churn_impact_pct)::numeric, 2),
         COUNT(*) FILTER (WHERE e.decision = 'adopt')::bigint,
         COUNT(*) FILTER (WHERE e.decision = 'reject')::bigint
  FROM public.chain_pricing_experiments_r2479 e
  GROUP BY e.chain_name
  ORDER BY SUM(e.arpu_lift_rupees) DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.chain_summary_r2479() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_summary_r2479() TO authenticated;
