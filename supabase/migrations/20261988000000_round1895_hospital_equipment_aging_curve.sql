BEGIN;

-- ============================================================
-- Round 1895 — Hospital Equipment Aging Curve
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_aging_curves_r1895 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL,
  age_bucket text NOT NULL CHECK (age_bucket IN ('0_2y','2_5y','5_10y','10_15y','15plus_y')),
  total_units int NOT NULL DEFAULT 0 CHECK (total_units >= 0),
  units_failed_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (units_failed_pct >= 0 AND units_failed_pct <= 100),
  avg_repair_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (avg_repair_cost_rupees >= 0),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_aging_replacement_recommendations_r1895 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curve_id uuid NOT NULL REFERENCES public.hospital_equipment_aging_curves_r1895(id) ON DELETE CASCADE,
  recommendation text NOT NULL CHECK (recommendation IN ('monitor','preemptive_repair','replace_soon','replace_now')),
  estimated_savings_rupees bigint NOT NULL DEFAULT 0 CHECK (estimated_savings_rupees >= 0),
  founder_decision text CHECK (founder_decision IN ('accepted','declined','deferred')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aging_curves_r1895_cat ON public.hospital_equipment_aging_curves_r1895(equipment_category);
CREATE INDEX IF NOT EXISTS idx_aging_curves_r1895_bucket ON public.hospital_equipment_aging_curves_r1895(age_bucket);
CREATE INDEX IF NOT EXISTS idx_aging_recos_r1895_curve ON public.hospital_aging_replacement_recommendations_r1895(curve_id);
CREATE INDEX IF NOT EXISTS idx_aging_recos_r1895_decision ON public.hospital_aging_replacement_recommendations_r1895(founder_decision);

ALTER TABLE public.hospital_equipment_aging_curves_r1895 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_aging_replacement_recommendations_r1895 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_aging_curves_r1895 ON public.hospital_equipment_aging_curves_r1895;
CREATE POLICY founder_all_aging_curves_r1895 ON public.hospital_equipment_aging_curves_r1895
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_aging_recos_r1895 ON public.hospital_aging_replacement_recommendations_r1895;
CREATE POLICY founder_all_aging_recos_r1895 ON public.hospital_aging_replacement_recommendations_r1895
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_curves
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_aging_curves_r1895()
RETURNS TABLE (
  id uuid,
  equipment_category text,
  age_bucket text,
  total_units int,
  units_failed_pct numeric,
  avg_repair_cost_rupees bigint,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.equipment_category, c.age_bucket, c.total_units,
         c.units_failed_pct, c.avg_repair_cost_rupees, c.recorded_at
  FROM public.hospital_equipment_aging_curves_r1895 c
  ORDER BY c.equipment_category ASC, c.age_bucket ASC;
END;
$$;

-- ============================================================
-- RPC 2: refresh_curve
-- ============================================================
CREATE OR REPLACE FUNCTION public.refresh_aging_curve_r1895(
  p_equipment_category text,
  p_age_bucket text,
  p_total_units int,
  p_units_failed_pct numeric,
  p_avg_repair_cost_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_equipment_aging_curves_r1895
    (equipment_category, age_bucket, total_units, units_failed_pct, avg_repair_cost_rupees, recorded_at)
  VALUES
    (p_equipment_category, p_age_bucket, p_total_units, p_units_failed_pct, p_avg_repair_cost_rupees, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'refresh_aging_curve_r1895',
    jsonb_build_object(
      'curve_id', v_id,
      'equipment_category', p_equipment_category,
      'age_bucket', p_age_bucket,
      'total_units', p_total_units,
      'units_failed_pct', p_units_failed_pct
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_recommendations
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_aging_recommendations_r1895()
RETURNS TABLE (
  id uuid,
  curve_id uuid,
  equipment_category text,
  age_bucket text,
  recommendation text,
  estimated_savings_rupees bigint,
  founder_decision text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.curve_id, c.equipment_category, c.age_bucket,
         r.recommendation, r.estimated_savings_rupees, r.founder_decision, r.created_at
  FROM public.hospital_aging_replacement_recommendations_r1895 r
  JOIN public.hospital_equipment_aging_curves_r1895 c ON c.id = r.curve_id
  ORDER BY r.created_at DESC;
END;
$$;

-- ============================================================
-- RPC 4: log_recommendation
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_aging_recommendation_r1895(
  p_curve_id uuid,
  p_recommendation text,
  p_estimated_savings_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_aging_replacement_recommendations_r1895
    (curve_id, recommendation, estimated_savings_rupees)
  VALUES
    (p_curve_id, p_recommendation, p_estimated_savings_rupees)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_aging_recommendation_r1895',
    jsonb_build_object(
      'reco_id', v_id,
      'curve_id', p_curve_id,
      'recommendation', p_recommendation,
      'estimated_savings_rupees', p_estimated_savings_rupees
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: decide_recommendation
-- ============================================================
CREATE OR REPLACE FUNCTION public.decide_aging_recommendation_r1895(
  p_reco_id uuid,
  p_decision text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_aging_replacement_recommendations_r1895
  SET founder_decision = p_decision,
      updated_at = now()
  WHERE id = p_reco_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'decide_aging_recommendation_r1895',
    jsonb_build_object(
      'reco_id', p_reco_id,
      'decision', p_decision
    )
  );
END;
$$;

-- ============================================================
-- RPC 6: top_aging_categories
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_aging_categories_r1895()
RETURNS TABLE (
  equipment_category text,
  total_units bigint,
  weighted_failure_pct numeric,
  total_avg_repair_cost bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.equipment_category,
         SUM(c.total_units)::bigint AS total_units,
         CASE WHEN SUM(c.total_units) > 0
              THEN ROUND((SUM(c.total_units * c.units_failed_pct) / NULLIF(SUM(c.total_units), 0))::numeric, 2)
              ELSE 0
         END AS weighted_failure_pct,
         SUM(c.avg_repair_cost_rupees)::bigint AS total_avg_repair_cost
  FROM public.hospital_equipment_aging_curves_r1895 c
  GROUP BY c.equipment_category
  ORDER BY weighted_failure_pct DESC NULLS LAST
  LIMIT 20;
END;
$$;

-- ============================================================
-- RPC 7: recent_decisions
-- ============================================================
CREATE OR REPLACE FUNCTION public.recent_aging_decisions_r1895()
RETURNS TABLE (
  id uuid,
  equipment_category text,
  age_bucket text,
  recommendation text,
  founder_decision text,
  estimated_savings_rupees bigint,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.equipment_category, c.age_bucket, r.recommendation,
         r.founder_decision, r.estimated_savings_rupees, r.updated_at
  FROM public.hospital_aging_replacement_recommendations_r1895 r
  JOIN public.hospital_equipment_aging_curves_r1895 c ON c.id = r.curve_id
  WHERE r.founder_decision IS NOT NULL
  ORDER BY r.updated_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_aging_curves_r1895() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_aging_curve_r1895(text, text, int, numeric, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_aging_recommendations_r1895() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_aging_recommendation_r1895(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_aging_recommendation_r1895(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_aging_categories_r1895() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_aging_decisions_r1895() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_aging_curves_r1895() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_aging_curve_r1895(text, text, int, numeric, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_aging_recommendations_r1895() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_aging_recommendation_r1895(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_aging_recommendation_r1895(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_aging_categories_r1895() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_aging_decisions_r1895() TO authenticated;

COMMIT;