BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_renewal_predictions_r2332 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_segment text NOT NULL CHECK (customer_segment IN ('enterprise','mid_market','smb','government','non_profit')),
  customer_tier text NOT NULL CHECK (customer_tier IN ('platinum','gold','silver','bronze')),
  amc_contract_value_rupees bigint NOT NULL DEFAULT 0,
  model_version text NOT NULL,
  predicted_renewal_probability numeric(5,4) NOT NULL CHECK (predicted_renewal_probability BETWEEN 0 AND 1),
  predicted_outcome text NOT NULL CHECK (predicted_outcome IN ('will_renew','at_risk','will_churn')),
  confidence_score numeric(5,4) NOT NULL DEFAULT 0.5 CHECK (confidence_score BETWEEN 0 AND 1),
  top_feature_drivers jsonb NOT NULL DEFAULT '[]'::jsonb,
  prediction_date date NOT NULL DEFAULT CURRENT_DATE,
  renewal_due_date date NOT NULL,
  actual_outcome text CHECK (actual_outcome IN ('renewed','churned','partial_renewal','pending')),
  actual_outcome_recorded_at timestamptz,
  prediction_correct boolean,
  error_magnitude numeric(5,4),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renewal_pred_r2332_customer ON public.customer_renewal_predictions_r2332(customer_profile_id);
CREATE INDEX IF NOT EXISTS idx_renewal_pred_r2332_segment ON public.customer_renewal_predictions_r2332(customer_segment);
CREATE INDEX IF NOT EXISTS idx_renewal_pred_r2332_model ON public.customer_renewal_predictions_r2332(model_version);
CREATE INDEX IF NOT EXISTS idx_renewal_pred_r2332_due ON public.customer_renewal_predictions_r2332(renewal_due_date);
CREATE INDEX IF NOT EXISTS idx_renewal_pred_r2332_outcome ON public.customer_renewal_predictions_r2332(actual_outcome);

ALTER TABLE public.customer_renewal_predictions_r2332 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_customer_renewal_predictions_r2332 ON public.customer_renewal_predictions_r2332;
CREATE POLICY founder_all_customer_renewal_predictions_r2332 ON public.customer_renewal_predictions_r2332
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.model_refinement_log_r2332 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version text NOT NULL,
  previous_version text,
  refinement_type text NOT NULL CHECK (refinement_type IN ('feature_added','feature_removed','threshold_adjusted','retrained','algorithm_changed','hyperparameter_tuned')),
  refinement_summary text NOT NULL,
  trigger_reason text NOT NULL CHECK (trigger_reason IN ('accuracy_drop','segment_drift','new_data','manual_review','scheduled_retrain','founder_directive')),
  prior_accuracy_pct numeric(5,2),
  new_accuracy_pct numeric(5,2),
  accuracy_delta numeric(5,2),
  training_sample_size integer NOT NULL DEFAULT 0,
  features_changed jsonb NOT NULL DEFAULT '[]'::jsonb,
  segments_affected jsonb NOT NULL DEFAULT '[]'::jsonb,
  refined_by_email text NOT NULL,
  deployed_at timestamptz NOT NULL DEFAULT now(),
  rollback_eligible boolean NOT NULL DEFAULT true,
  validation_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_model_refine_r2332_version ON public.model_refinement_log_r2332(model_version);
CREATE INDEX IF NOT EXISTS idx_model_refine_r2332_deployed ON public.model_refinement_log_r2332(deployed_at DESC);
CREATE INDEX IF NOT EXISTS idx_model_refine_r2332_trigger ON public.model_refinement_log_r2332(trigger_reason);

ALTER TABLE public.model_refinement_log_r2332 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_model_refinement_log_r2332 ON public.model_refinement_log_r2332;
CREATE POLICY founder_all_model_refinement_log_r2332 ON public.model_refinement_log_r2332
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_renewal_predictions_r2332()
RETURNS TABLE (
  id uuid,
  customer_email text,
  customer_segment text,
  customer_tier text,
  amc_contract_value_rupees bigint,
  model_version text,
  predicted_renewal_probability numeric,
  predicted_outcome text,
  confidence_score numeric,
  prediction_date date,
  renewal_due_date date,
  actual_outcome text,
  prediction_correct boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, prof.email, p.customer_segment, p.customer_tier, p.amc_contract_value_rupees,
         p.model_version, p.predicted_renewal_probability, p.predicted_outcome, p.confidence_score,
         p.prediction_date, p.renewal_due_date, p.actual_outcome, p.prediction_correct
  FROM public.customer_renewal_predictions_r2332 p
  LEFT JOIN public.profiles prof ON prof.id = p.customer_profile_id
  ORDER BY p.renewal_due_date ASC, p.predicted_renewal_probability DESC
  LIMIT 500;
END;
$$;
REVOKE ALL ON FUNCTION public.list_renewal_predictions_r2332() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renewal_predictions_r2332() TO authenticated;

CREATE OR REPLACE FUNCTION public.accuracy_by_segment_r2332()
RETURNS TABLE (
  customer_segment text,
  total_predictions bigint,
  resolved_predictions bigint,
  correct_predictions bigint,
  accuracy_pct numeric,
  avg_predicted_prob numeric,
  renewal_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.customer_segment,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending')::bigint,
         COUNT(*) FILTER (WHERE p.prediction_correct = true)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.prediction_correct = true)
               / NULLIF(COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending'),0), 2),
         ROUND(AVG(p.predicted_renewal_probability)::numeric, 4),
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.actual_outcome = 'renewed')
               / NULLIF(COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending'),0), 2)
  FROM public.customer_renewal_predictions_r2332 p
  GROUP BY p.customer_segment
  ORDER BY accuracy_pct DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.accuracy_by_segment_r2332() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accuracy_by_segment_r2332() TO authenticated;

CREATE OR REPLACE FUNCTION public.accuracy_by_model_version_r2332()
RETURNS TABLE (
  model_version text,
  total_predictions bigint,
  resolved_predictions bigint,
  accuracy_pct numeric,
  avg_confidence numeric,
  earliest_prediction date,
  latest_prediction date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.model_version,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending')::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE p.prediction_correct = true)
               / NULLIF(COUNT(*) FILTER (WHERE p.actual_outcome IS NOT NULL AND p.actual_outcome <> 'pending'),0), 2),
         ROUND(AVG(p.confidence_score)::numeric, 4),
         MIN(p.prediction_date),
         MAX(p.prediction_date)
  FROM public.customer_renewal_predictions_r2332 p
  GROUP BY p.model_version
  ORDER BY MAX(p.prediction_date) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.accuracy_by_model_version_r2332() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accuracy_by_model_version_r2332() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_refinement_log_r2332()
RETURNS TABLE (
  id uuid,
  model_version text,
  previous_version text,
  refinement_type text,
  refinement_summary text,
  trigger_reason text,
  prior_accuracy_pct numeric,
  new_accuracy_pct numeric,
  accuracy_delta numeric,
  training_sample_size integer,
  refined_by_email text,
  deployed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.model_version, r.previous_version, r.refinement_type, r.refinement_summary,
         r.trigger_reason, r.prior_accuracy_pct, r.new_accuracy_pct, r.accuracy_delta,
         r.training_sample_size, r.refined_by_email, r.deployed_at
  FROM public.model_refinement_log_r2332 r
  ORDER BY r.deployed_at DESC
  LIMIT 200;
END;
$$;
REVOKE ALL ON FUNCTION public.list_refinement_log_r2332() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_refinement_log_r2332() TO authenticated;

CREATE OR REPLACE FUNCTION public.summary_renewal_accuracy_r2332()
RETURNS TABLE (
  total_predictions bigint,
  pending_outcome bigint,
  resolved_outcome bigint,
  overall_accuracy_pct numeric,
  avg_predicted_prob numeric,
  total_amc_value_at_risk bigint,
  high_confidence_correct_pct numeric,
  active_model_version text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_active text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT model_version INTO v_active FROM public.model_refinement_log_r2332 ORDER BY deployed_at DESC LIMIT 1;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE actual_outcome IS NULL OR actual_outcome = 'pending')::bigint,
    COUNT(*) FILTER (WHERE actual_outcome IS NOT NULL AND actual_outcome <> 'pending')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE prediction_correct = true)
          / NULLIF(COUNT(*) FILTER (WHERE actual_outcome IS NOT NULL AND actual_outcome <> 'pending'),0), 2),
    ROUND(AVG(predicted_renewal_probability)::numeric, 4),
    COALESCE(SUM(amc_contract_value_rupees) FILTER (WHERE predicted_outcome IN ('at_risk','will_churn')),0)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE prediction_correct = true AND confidence_score >= 0.8)
          / NULLIF(COUNT(*) FILTER (WHERE confidence_score >= 0.8 AND actual_outcome IS NOT NULL AND actual_outcome <> 'pending'),0), 2),
    v_active
  FROM public.customer_renewal_predictions_r2332;
END;
$$;
REVOKE ALL ON FUNCTION public.summary_renewal_accuracy_r2332() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.summary_renewal_accuracy_r2332() TO authenticated;

CREATE OR REPLACE FUNCTION public.record_actual_outcome_r2332(
  p_prediction_id uuid,
  p_actual_outcome text,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pred numeric;
  v_correct boolean;
  v_err numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_actual_outcome NOT IN ('renewed','churned','partial_renewal','pending') THEN
    RAISE EXCEPTION 'invalid actual_outcome';
  END IF;
  SELECT predicted_renewal_probability INTO v_pred FROM public.customer_renewal_predictions_r2332 WHERE id = p_prediction_id;
  IF v_pred IS NULL THEN RAISE EXCEPTION 'prediction not found'; END IF;
  v_correct := CASE
    WHEN p_actual_outcome = 'renewed' AND v_pred >= 0.5 THEN true
    WHEN p_actual_outcome = 'churned' AND v_pred < 0.5 THEN true
    WHEN p_actual_outcome = 'partial_renewal' AND v_pred BETWEEN 0.3 AND 0.7 THEN true
    ELSE false
  END;
  v_err := CASE
    WHEN p_actual_outcome = 'renewed' THEN ABS(1 - v_pred)
    WHEN p_actual_outcome = 'churned' THEN ABS(0 - v_pred)
    WHEN p_actual_outcome = 'partial_renewal' THEN ABS(0.5 - v_pred)
    ELSE NULL
  END;
  UPDATE public.customer_renewal_predictions_r2332
  SET actual_outcome = p_actual_outcome,
      actual_outcome_recorded_at = now(),
      prediction_correct = v_correct,
      error_magnitude = v_err,
      notes = COALESCE(p_notes, notes),
      updated_at = now()
  WHERE id = p_prediction_id;
  RETURN p_prediction_id;
END;
$$;
REVOKE ALL ON FUNCTION public.record_actual_outcome_r2332(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_actual_outcome_r2332(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_model_refinement_r2332(
  p_model_version text,
  p_previous_version text,
  p_refinement_type text,
  p_refinement_summary text,
  p_trigger_reason text,
  p_prior_accuracy_pct numeric,
  p_new_accuracy_pct numeric,
  p_training_sample_size integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.model_refinement_log_r2332(
    model_version, previous_version, refinement_type, refinement_summary, trigger_reason,
    prior_accuracy_pct, new_accuracy_pct, accuracy_delta, training_sample_size, refined_by_email
  )
  VALUES (
    p_model_version, p_previous_version, p_refinement_type, p_refinement_summary, p_trigger_reason,
    p_prior_accuracy_pct, p_new_accuracy_pct, COALESCE(p_new_accuracy_pct,0) - COALESCE(p_prior_accuracy_pct,0),
    p_training_sample_size, v_email
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_model_refinement_r2332(text, text, text, text, text, numeric, numeric, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_model_refinement_r2332(text, text, text, text, text, numeric, numeric, integer) TO authenticated;

COMMIT;