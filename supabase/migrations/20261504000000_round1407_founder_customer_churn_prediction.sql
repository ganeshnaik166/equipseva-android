BEGIN;
-- r1407 — Customer Churn Prediction infra (model registry + feature store + outcome ledger)
-- HEAVY: 3 tables + 8 RPCs



-- ============================================================================
-- TABLE 1: model registry
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_churn_prediction_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_label text UNIQUE NOT NULL,
  model_family text NOT NULL CHECK (model_family IN ('logistic_regression','gradient_boost','xgboost','random_forest','rule_based','external_api')),
  trained_through date,
  accuracy_pct numeric,
  precision_pct numeric,
  recall_pct numeric,
  auc_roc numeric,
  churn_threshold_pct numeric DEFAULT 50,
  shadow_mode boolean DEFAULT true,
  activated_at timestamptz,
  deactivated_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churn_models_active ON public.founder_churn_prediction_models (activated_at) WHERE deactivated_at IS NULL;

ALTER TABLE public.founder_churn_prediction_models ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS churn_models_founder_all ON public.founder_churn_prediction_models;
CREATE POLICY churn_models_founder_all ON public.founder_churn_prediction_models FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: feature snapshots (feature store)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_churn_prediction_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  feature_snapshot_at timestamptz DEFAULT now(),
  days_since_last_visit int,
  sla_breach_count_90d int,
  code_red_count_180d int,
  payment_overdue_days int,
  open_dispute_count int,
  nps_score int,
  monthly_fee_rupees numeric,
  days_active int,
  computed_churn_score numeric,
  model_version_id uuid REFERENCES public.founder_churn_prediction_models(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churn_features_hospital ON public.founder_churn_prediction_features (hospital_org_id, feature_snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_churn_features_score ON public.founder_churn_prediction_features (computed_churn_score DESC);

ALTER TABLE public.founder_churn_prediction_features ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS churn_features_founder_all ON public.founder_churn_prediction_features;
CREATE POLICY churn_features_founder_all ON public.founder_churn_prediction_features FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 3: outcome ledger (for back-testing accuracy)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_churn_prediction_outcomes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_snapshot_id uuid REFERENCES public.founder_churn_prediction_features(id) ON DELETE CASCADE,
  observed_churn boolean,
  observed_at timestamptz,
  prediction_was_correct boolean,
  false_positive boolean,
  false_negative boolean,
  evaluated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churn_outcomes_snapshot ON public.founder_churn_prediction_outcomes (feature_snapshot_id);

ALTER TABLE public.founder_churn_prediction_outcomes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS churn_outcomes_founder_all ON public.founder_churn_prediction_outcomes;
CREATE POLICY churn_outcomes_founder_all ON public.founder_churn_prediction_outcomes FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: summary (16 KPIs)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_churn_prediction_summary();
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_summary()
RETURNS TABLE (
  total_models bigint,
  active_models bigint,
  shadow_models bigint,
  active_threshold_pct numeric,
  total_feature_snapshots bigint,
  snapshots_last_7d bigint,
  snapshots_last_30d bigint,
  hospitals_scored bigint,
  hospitals_at_risk bigint,
  avg_churn_score numeric,
  max_churn_score numeric,
  total_outcomes bigint,
  correct_predictions bigint,
  false_positives bigint,
  false_negatives bigint,
  precision_observed_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT churn_threshold_pct INTO v_threshold
  FROM public.founder_churn_prediction_models
  WHERE activated_at IS NOT NULL AND deactivated_at IS NULL AND shadow_mode = false
  ORDER BY activated_at DESC LIMIT 1;
  v_threshold := COALESCE(v_threshold, 50);

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_churn_prediction_models),
    (SELECT count(*) FROM public.founder_churn_prediction_models WHERE activated_at IS NOT NULL AND deactivated_at IS NULL AND shadow_mode = false),
    (SELECT count(*) FROM public.founder_churn_prediction_models WHERE shadow_mode = true),
    v_threshold,
    (SELECT count(*) FROM public.founder_churn_prediction_features),
    (SELECT count(*) FROM public.founder_churn_prediction_features WHERE feature_snapshot_at >= now() - interval '7 days'),
    (SELECT count(*) FROM public.founder_churn_prediction_features WHERE feature_snapshot_at >= now() - interval '30 days'),
    (SELECT count(DISTINCT hospital_org_id) FROM public.founder_churn_prediction_features),
    (SELECT count(DISTINCT hospital_org_id) FROM public.founder_churn_prediction_features WHERE computed_churn_score > v_threshold),
    (SELECT round(avg(computed_churn_score)::numeric, 2) FROM public.founder_churn_prediction_features WHERE computed_churn_score IS NOT NULL),
    (SELECT max(computed_churn_score) FROM public.founder_churn_prediction_features),
    (SELECT count(*) FROM public.founder_churn_prediction_outcomes),
    (SELECT count(*) FROM public.founder_churn_prediction_outcomes WHERE prediction_was_correct = true),
    (SELECT count(*) FROM public.founder_churn_prediction_outcomes WHERE false_positive = true),
    (SELECT count(*) FROM public.founder_churn_prediction_outcomes WHERE false_negative = true),
    (SELECT CASE WHEN count(*) = 0 THEN NULL ELSE round((sum(CASE WHEN prediction_was_correct THEN 1 ELSE 0 END)::numeric * 100.0 / count(*))::numeric, 2) END FROM public.founder_churn_prediction_outcomes);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_churn_prediction_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_churn_prediction_summary() TO authenticated;

-- ============================================================================
-- RPC 2: recent feature snapshots
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_churn_prediction_features_recent(int);
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_features_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  feature_snapshot_at timestamptz,
  days_since_last_visit int,
  sla_breach_count_90d int,
  code_red_count_180d int,
  payment_overdue_days int,
  open_dispute_count int,
  nps_score int,
  monthly_fee_rupees numeric,
  computed_churn_score numeric,
  model_label text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT f.id, f.hospital_org_id, o.name, f.feature_snapshot_at,
         f.days_since_last_visit, f.sla_breach_count_90d, f.code_red_count_180d,
         f.payment_overdue_days, f.open_dispute_count, f.nps_score,
         f.monthly_fee_rupees, f.computed_churn_score, m.model_label
  FROM public.founder_churn_prediction_features f
  LEFT JOIN public.organizations o ON o.id = f.hospital_org_id
  LEFT JOIN public.founder_churn_prediction_models m ON m.id = f.model_version_id
  ORDER BY f.feature_snapshot_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_churn_prediction_features_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_churn_prediction_features_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3: recent outcomes
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_churn_prediction_outcomes_recent(int);
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_outcomes_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  feature_snapshot_id uuid,
  hospital_name text,
  computed_churn_score numeric,
  observed_churn boolean,
  observed_at timestamptz,
  prediction_was_correct boolean,
  false_positive boolean,
  false_negative boolean,
  evaluated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT ou.id, ou.feature_snapshot_id, o.name, f.computed_churn_score,
         ou.observed_churn, ou.observed_at, ou.prediction_was_correct,
         ou.false_positive, ou.false_negative, ou.evaluated_at
  FROM public.founder_churn_prediction_outcomes ou
  LEFT JOIN public.founder_churn_prediction_features f ON f.id = ou.feature_snapshot_id
  LEFT JOIN public.organizations o ON o.id = f.hospital_org_id
  ORDER BY ou.evaluated_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_churn_prediction_outcomes_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_churn_prediction_outcomes_recent(int) TO authenticated;

-- ============================================================================
-- RPC 4: currently active model
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_churn_prediction_active_model();
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_active_model()
RETURNS TABLE (
  id uuid,
  model_label text,
  model_family text,
  trained_through date,
  accuracy_pct numeric,
  precision_pct numeric,
  recall_pct numeric,
  auc_roc numeric,
  churn_threshold_pct numeric,
  shadow_mode boolean,
  activated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT m.id, m.model_label, m.model_family, m.trained_through,
         m.accuracy_pct, m.precision_pct, m.recall_pct, m.auc_roc,
         m.churn_threshold_pct, m.shadow_mode, m.activated_at
  FROM public.founder_churn_prediction_models m
  WHERE m.activated_at IS NOT NULL AND m.deactivated_at IS NULL
  ORDER BY m.activated_at DESC
  LIMIT 5;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_churn_prediction_active_model() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_churn_prediction_active_model() TO authenticated;

-- ============================================================================
-- RPC 5: at-risk hospitals (score > threshold)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_churn_prediction_at_risk_hospitals(int);
CREATE OR REPLACE FUNCTION public.founder_churn_prediction_at_risk_hospitals(p_limit int DEFAULT 50)
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  latest_score numeric,
  latest_snapshot_at timestamptz,
  days_since_last_visit int,
  sla_breach_count_90d int,
  open_dispute_count int,
  monthly_fee_rupees numeric,
  threshold_pct numeric,
  exceeds_threshold_by numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT churn_threshold_pct INTO v_threshold
  FROM public.founder_churn_prediction_models
  WHERE activated_at IS NOT NULL AND deactivated_at IS NULL AND shadow_mode = false
  ORDER BY activated_at DESC LIMIT 1;
  v_threshold := COALESCE(v_threshold, 50);

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (hospital_org_id)
      hospital_org_id, computed_churn_score, feature_snapshot_at,
      days_since_last_visit, sla_breach_count_90d, open_dispute_count, monthly_fee_rupees
    FROM public.founder_churn_prediction_features
    WHERE computed_churn_score IS NOT NULL
    ORDER BY hospital_org_id, feature_snapshot_at DESC
  )
  SELECT l.hospital_org_id, o.name, l.computed_churn_score, l.feature_snapshot_at,
         l.days_since_last_visit, l.sla_breach_count_90d, l.open_dispute_count,
         l.monthly_fee_rupees, v_threshold,
         (l.computed_churn_score - v_threshold)
  FROM latest l
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  WHERE l.computed_churn_score > v_threshold
  ORDER BY l.computed_churn_score DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_churn_prediction_at_risk_hospitals(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_churn_prediction_at_risk_hospitals(int) TO authenticated;

-- ============================================================================
-- RPC 6: register model version (write)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_churn_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, boolean);
CREATE OR REPLACE FUNCTION public.log_founder_churn_register_model_version(
  p_model_label text,
  p_model_family text,
  p_trained_through date,
  p_accuracy_pct numeric DEFAULT NULL,
  p_precision_pct numeric DEFAULT NULL,
  p_recall_pct numeric DEFAULT NULL,
  p_auc_roc numeric DEFAULT NULL,
  p_threshold_pct numeric DEFAULT 50,
  p_shadow_mode boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_churn_prediction_models (
    model_label, model_family, trained_through, accuracy_pct,
    precision_pct, recall_pct, auc_roc, churn_threshold_pct, shadow_mode, activated_at
  ) VALUES (
    p_model_label, p_model_family, p_trained_through, p_accuracy_pct,
    p_precision_pct, p_recall_pct, p_auc_roc, p_threshold_pct, p_shadow_mode, now()
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_churn_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_churn_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, boolean) TO authenticated;

-- ============================================================================
-- RPC 7: record feature snapshot (write)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_churn_record_feature_snapshot(uuid, int, int, int, int, int, int, numeric, int, numeric, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_churn_record_feature_snapshot(
  p_hospital_org_id uuid,
  p_days_since_last_visit int,
  p_sla_breach_count_90d int,
  p_code_red_count_180d int,
  p_payment_overdue_days int,
  p_open_dispute_count int,
  p_nps_score int,
  p_monthly_fee_rupees numeric,
  p_days_active int,
  p_computed_churn_score numeric,
  p_model_version_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_churn_prediction_features (
    hospital_org_id, days_since_last_visit, sla_breach_count_90d, code_red_count_180d,
    payment_overdue_days, open_dispute_count, nps_score, monthly_fee_rupees,
    days_active, computed_churn_score, model_version_id
  ) VALUES (
    p_hospital_org_id, p_days_since_last_visit, p_sla_breach_count_90d, p_code_red_count_180d,
    p_payment_overdue_days, p_open_dispute_count, p_nps_score, p_monthly_fee_rupees,
    p_days_active, p_computed_churn_score, p_model_version_id
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_churn_record_feature_snapshot(uuid, int, int, int, int, int, int, numeric, int, numeric, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_churn_record_feature_snapshot(uuid, int, int, int, int, int, int, numeric, int, numeric, uuid) TO authenticated;

-- ============================================================================
-- RPC 8: record outcome (write — back-test ledger)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_churn_record_outcome(uuid, boolean, timestamptz);
CREATE OR REPLACE FUNCTION public.log_founder_churn_record_outcome(
  p_feature_snapshot_id uuid,
  p_observed_churn boolean,
  p_observed_at timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_score numeric;
  v_threshold numeric;
  v_predicted boolean;
  v_correct boolean;
  v_fp boolean;
  v_fn boolean;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT f.computed_churn_score, COALESCE(m.churn_threshold_pct, 50)
  INTO v_score, v_threshold
  FROM public.founder_churn_prediction_features f
  LEFT JOIN public.founder_churn_prediction_models m ON m.id = f.model_version_id
  WHERE f.id = p_feature_snapshot_id;

  v_predicted := COALESCE(v_score, 0) > COALESCE(v_threshold, 50);
  v_correct := (v_predicted = p_observed_churn);
  v_fp := (v_predicted = true AND p_observed_churn = false);
  v_fn := (v_predicted = false AND p_observed_churn = true);

  INSERT INTO public.founder_churn_prediction_outcomes (
    feature_snapshot_id, observed_churn, observed_at,
    prediction_was_correct, false_positive, false_negative
  ) VALUES (
    p_feature_snapshot_id, p_observed_churn, p_observed_at,
    v_correct, v_fp, v_fn
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_churn_record_outcome(uuid, boolean, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_churn_record_outcome(uuid, boolean, timestamptz) TO authenticated;

COMMIT;