BEGIN;

-- ============================================================================
-- r1397: AI-assisted Code Red triage infrastructure (v0.6 Phase 4)
-- ============================================================================

-- Table 1: model versions registry
CREATE TABLE IF NOT EXISTS public.founder_ai_triage_model_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_label text NOT NULL UNIQUE,
  model_family text NOT NULL CHECK (model_family IN (
    'logistic_regression','random_forest','gradient_boost',
    'neural_network','heuristic_baseline','external_api'
  )),
  training_data_through_date date,
  accuracy_pct numeric CHECK (accuracy_pct IS NULL OR (accuracy_pct >= 0 AND accuracy_pct <= 100)),
  precision_pct numeric CHECK (precision_pct IS NULL OR (precision_pct >= 0 AND precision_pct <= 100)),
  recall_pct numeric CHECK (recall_pct IS NULL OR (recall_pct >= 0 AND recall_pct <= 100)),
  f1_score numeric CHECK (f1_score IS NULL OR (f1_score >= 0 AND f1_score <= 1)),
  false_positive_rate_pct numeric CHECK (false_positive_rate_pct IS NULL OR (false_positive_rate_pct >= 0 AND false_positive_rate_pct <= 100)),
  false_negative_rate_pct numeric CHECK (false_negative_rate_pct IS NULL OR (false_negative_rate_pct >= 0 AND false_negative_rate_pct <= 100)),
  shadow_mode boolean NOT NULL DEFAULT true,
  activated_at timestamptz,
  deactivated_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_triage_models_active
  ON public.founder_ai_triage_model_versions(shadow_mode, activated_at DESC);

ALTER TABLE public.founder_ai_triage_model_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_triage_models_founder_all ON public.founder_ai_triage_model_versions;
CREATE POLICY ai_triage_models_founder_all
  ON public.founder_ai_triage_model_versions
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: predictions log
CREATE TABLE IF NOT EXISTS public.founder_ai_triage_predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version_id uuid NOT NULL REFERENCES public.founder_ai_triage_model_versions(id) ON DELETE CASCADE,
  code_red_request_id uuid REFERENCES public.code_red_requests(id) ON DELETE CASCADE,
  recommended_engineer_id uuid REFERENCES public.engineers(id),
  confidence_pct numeric CHECK (confidence_pct IS NULL OR (confidence_pct >= 0 AND confidence_pct <= 100)),
  predicted_response_minutes int,
  ranked_engineers jsonb,
  prediction_basis_summary text,
  predicted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_triage_preds_recent
  ON public.founder_ai_triage_predictions(predicted_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_triage_preds_model
  ON public.founder_ai_triage_predictions(model_version_id, predicted_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_triage_preds_code_red
  ON public.founder_ai_triage_predictions(code_red_request_id);

ALTER TABLE public.founder_ai_triage_predictions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_triage_preds_founder_all ON public.founder_ai_triage_predictions;
CREATE POLICY ai_triage_preds_founder_all
  ON public.founder_ai_triage_predictions
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 3: feedback
CREATE TABLE IF NOT EXISTS public.founder_ai_triage_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prediction_id uuid NOT NULL REFERENCES public.founder_ai_triage_predictions(id) ON DELETE CASCADE,
  actual_engineer_id uuid REFERENCES public.engineers(id),
  recommendation_was_correct boolean,
  recommendation_was_followed boolean,
  actual_response_minutes int,
  founder_notes text,
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_triage_fb_recent
  ON public.founder_ai_triage_feedback(reviewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_triage_fb_prediction
  ON public.founder_ai_triage_feedback(prediction_id);

ALTER TABLE public.founder_ai_triage_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_triage_fb_founder_all ON public.founder_ai_triage_feedback;
CREATE POLICY ai_triage_fb_founder_all
  ON public.founder_ai_triage_feedback
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: summary — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ai_triage_summary();
CREATE OR REPLACE FUNCTION public.founder_ai_triage_summary()
RETURNS TABLE(
  model_count bigint,
  active_model_label text,
  active_model_family text,
  shadow_mode_active boolean,
  predictions_lifetime bigint,
  predictions_last_7d bigint,
  predictions_last_30d bigint,
  feedback_received bigint,
  feedback_pending bigint,
  correct_pct numeric,
  followed_pct numeric,
  avg_confidence_pct numeric,
  avg_predicted_minutes numeric,
  avg_actual_minutes numeric,
  false_positive_count bigint,
  false_negative_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  WITH active AS (
    SELECT model_label, model_family, shadow_mode
    FROM public.founder_ai_triage_model_versions
    WHERE shadow_mode = false AND deactivated_at IS NULL
    ORDER BY activated_at DESC NULLS LAST
    LIMIT 1
  ),
  preds AS (
    SELECT * FROM public.founder_ai_triage_predictions
  ),
  fb AS (
    SELECT * FROM public.founder_ai_triage_feedback
  )
  SELECT
    (SELECT count(*) FROM public.founder_ai_triage_model_versions),
    (SELECT model_label FROM active),
    (SELECT model_family FROM active),
    COALESCE((SELECT NOT shadow_mode FROM active), false),
    (SELECT count(*) FROM preds),
    (SELECT count(*) FROM preds WHERE predicted_at >= now() - interval '7 days'),
    (SELECT count(*) FROM preds WHERE predicted_at >= now() - interval '30 days'),
    (SELECT count(*) FROM fb),
    (SELECT count(*) FROM preds p WHERE NOT EXISTS (SELECT 1 FROM fb WHERE fb.prediction_id = p.id)),
    (SELECT round(100.0 * count(*) FILTER (WHERE recommendation_was_correct) / NULLIF(count(*) FILTER (WHERE recommendation_was_correct IS NOT NULL), 0), 1) FROM fb),
    (SELECT round(100.0 * count(*) FILTER (WHERE recommendation_was_followed) / NULLIF(count(*) FILTER (WHERE recommendation_was_followed IS NOT NULL), 0), 1) FROM fb),
    (SELECT round(avg(confidence_pct)::numeric, 1) FROM preds),
    (SELECT round(avg(predicted_response_minutes)::numeric, 1) FROM preds),
    (SELECT round(avg(actual_response_minutes)::numeric, 1) FROM fb),
    (SELECT count(*) FROM fb WHERE recommendation_was_correct = false AND recommendation_was_followed = true),
    (SELECT count(*) FROM fb WHERE recommendation_was_correct = false AND recommendation_was_followed = false);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ai_triage_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ai_triage_summary() TO authenticated;

-- ============================================================================
-- RPC 2: recent predictions
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ai_triage_predictions_recent(int);
CREATE OR REPLACE FUNCTION public.founder_ai_triage_predictions_recent(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  model_label text,
  code_red_request_id uuid,
  recommended_engineer_id uuid,
  confidence_pct numeric,
  predicted_response_minutes int,
  prediction_basis_summary text,
  predicted_at timestamptz,
  has_feedback boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT
    p.id,
    m.model_label,
    p.code_red_request_id,
    p.recommended_engineer_id,
    p.confidence_pct,
    p.predicted_response_minutes,
    p.prediction_basis_summary,
    p.predicted_at,
    EXISTS (SELECT 1 FROM public.founder_ai_triage_feedback fb WHERE fb.prediction_id = p.id) AS has_feedback
  FROM public.founder_ai_triage_predictions p
  JOIN public.founder_ai_triage_model_versions m ON m.id = p.model_version_id
  ORDER BY p.predicted_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ai_triage_predictions_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ai_triage_predictions_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3: recent feedback
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ai_triage_feedback_recent(int);
CREATE OR REPLACE FUNCTION public.founder_ai_triage_feedback_recent(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  prediction_id uuid,
  model_label text,
  recommendation_was_correct boolean,
  recommendation_was_followed boolean,
  actual_response_minutes int,
  founder_notes text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT
    fb.id,
    fb.prediction_id,
    m.model_label,
    fb.recommendation_was_correct,
    fb.recommendation_was_followed,
    fb.actual_response_minutes,
    fb.founder_notes,
    fb.reviewed_at
  FROM public.founder_ai_triage_feedback fb
  JOIN public.founder_ai_triage_predictions p ON p.id = fb.prediction_id
  JOIN public.founder_ai_triage_model_versions m ON m.id = p.model_version_id
  ORDER BY fb.reviewed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ai_triage_feedback_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ai_triage_feedback_recent(int) TO authenticated;

-- ============================================================================
-- RPC 4: active model
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ai_triage_active_model();
CREATE OR REPLACE FUNCTION public.founder_ai_triage_active_model()
RETURNS TABLE(
  id uuid,
  model_label text,
  model_family text,
  accuracy_pct numeric,
  precision_pct numeric,
  recall_pct numeric,
  f1_score numeric,
  false_positive_rate_pct numeric,
  false_negative_rate_pct numeric,
  training_data_through_date date,
  shadow_mode boolean,
  activated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT
    m.id, m.model_label, m.model_family,
    m.accuracy_pct, m.precision_pct, m.recall_pct, m.f1_score,
    m.false_positive_rate_pct, m.false_negative_rate_pct,
    m.training_data_through_date, m.shadow_mode, m.activated_at
  FROM public.founder_ai_triage_model_versions m
  WHERE m.deactivated_at IS NULL
  ORDER BY m.shadow_mode ASC, m.activated_at DESC NULLS LAST
  LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ai_triage_active_model() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ai_triage_active_model() TO authenticated;

-- ============================================================================
-- RPC 5: register model version
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ai_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_ai_register_model_version(
  p_model_label text,
  p_model_family text,
  p_training_through date,
  p_accuracy numeric,
  p_precision numeric,
  p_recall numeric,
  p_f1 numeric,
  p_fpr numeric,
  p_fnr numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_ai_triage_model_versions(
    model_label, model_family, training_data_through_date,
    accuracy_pct, precision_pct, recall_pct, f1_score,
    false_positive_rate_pct, false_negative_rate_pct,
    shadow_mode, created_by
  ) VALUES (
    p_model_label, p_model_family, p_training_through,
    p_accuracy, p_precision, p_recall, p_f1, p_fpr, p_fnr,
    true, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_ai_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ai_register_model_version(text, text, date, numeric, numeric, numeric, numeric, numeric, numeric) TO authenticated;

-- ============================================================================
-- RPC 6: activate model (deactivates others)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ai_activate_model_version(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_ai_activate_model_version(p_model_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  UPDATE public.founder_ai_triage_model_versions
     SET deactivated_at = now(), updated_at = now()
   WHERE shadow_mode = false AND deactivated_at IS NULL AND id <> p_model_id;
  UPDATE public.founder_ai_triage_model_versions
     SET shadow_mode = false,
         activated_at = COALESCE(activated_at, now()),
         deactivated_at = NULL,
         updated_at = now()
   WHERE id = p_model_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_ai_activate_model_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ai_activate_model_version(uuid) TO authenticated;

-- ============================================================================
-- RPC 7: record prediction
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ai_record_prediction(uuid, uuid, uuid, numeric, int, jsonb, text);
CREATE OR REPLACE FUNCTION public.log_founder_ai_record_prediction(
  p_model_version_id uuid,
  p_code_red_request_id uuid,
  p_recommended_engineer_id uuid,
  p_confidence_pct numeric,
  p_predicted_minutes int,
  p_ranked_engineers jsonb,
  p_basis text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_ai_triage_predictions(
    model_version_id, code_red_request_id, recommended_engineer_id,
    confidence_pct, predicted_response_minutes, ranked_engineers, prediction_basis_summary
  ) VALUES (
    p_model_version_id, p_code_red_request_id, p_recommended_engineer_id,
    p_confidence_pct, p_predicted_minutes, p_ranked_engineers, p_basis
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_ai_record_prediction(uuid, uuid, uuid, numeric, int, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ai_record_prediction(uuid, uuid, uuid, numeric, int, jsonb, text) TO authenticated;

-- ============================================================================
-- RPC 8: record feedback
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ai_record_feedback(uuid, uuid, boolean, boolean, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_ai_record_feedback(
  p_prediction_id uuid,
  p_actual_engineer_id uuid,
  p_correct boolean,
  p_followed boolean,
  p_actual_minutes int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_ai_triage_feedback(
    prediction_id, actual_engineer_id, recommendation_was_correct,
    recommendation_was_followed, actual_response_minutes, founder_notes, reviewed_by
  ) VALUES (
    p_prediction_id, p_actual_engineer_id, p_correct, p_followed,
    p_actual_minutes, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_ai_record_feedback(uuid, uuid, boolean, boolean, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_ai_record_feedback(uuid, uuid, boolean, boolean, int, text) TO authenticated;

COMMIT;