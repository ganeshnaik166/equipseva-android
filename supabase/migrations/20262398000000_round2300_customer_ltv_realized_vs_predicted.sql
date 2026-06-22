BEGIN;

-- =========================================================================
-- r2300: Customer LTV realized vs predicted
-- Tables:
--   founder_customer_ltv_predictions_r2300 — one row per customer LTV prediction
--   founder_customer_ltv_accuracy_log_r2300 — accuracy snapshots + model adjustment notes
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_customer_ltv_predictions_r2300 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id          uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  customer_label           text NOT NULL,
  customer_segment         text NOT NULL DEFAULT 'standalone_clinic'
    CHECK (customer_segment IN ('standalone_clinic','small_hospital','mid_hospital','large_hospital','chain','diagnostic_lab','dental','vet','other')),
  cohort_month             date NOT NULL,
  predicted_ltv_rupees     bigint NOT NULL DEFAULT 0 CHECK (predicted_ltv_rupees >= 0),
  predicted_horizon_months int  NOT NULL DEFAULT 36 CHECK (predicted_horizon_months BETWEEN 1 AND 120),
  predicted_on             date NOT NULL DEFAULT CURRENT_DATE,
  prediction_model_version text NOT NULL DEFAULT 'v1',
  realized_to_date_rupees  bigint NOT NULL DEFAULT 0 CHECK (realized_to_date_rupees >= 0),
  last_realized_refresh_on date,
  months_elapsed           int  NOT NULL DEFAULT 0 CHECK (months_elapsed >= 0),
  status                   text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','churned','paused','closed_won','closed_lost')),
  confidence_band          text NOT NULL DEFAULT 'medium'
    CHECK (confidence_band IN ('low','medium','high')),
  notes                    text,
  created_by               uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fclp_r2300_segment ON public.founder_customer_ltv_predictions_r2300(customer_segment);
CREATE INDEX IF NOT EXISTS idx_fclp_r2300_status  ON public.founder_customer_ltv_predictions_r2300(status);
CREATE INDEX IF NOT EXISTS idx_fclp_r2300_cohort  ON public.founder_customer_ltv_predictions_r2300(cohort_month);
CREATE INDEX IF NOT EXISTS idx_fclp_r2300_org     ON public.founder_customer_ltv_predictions_r2300(customer_org_id);

CREATE TABLE IF NOT EXISTS public.founder_customer_ltv_accuracy_log_r2300 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prediction_id            uuid NOT NULL REFERENCES public.founder_customer_ltv_predictions_r2300(id) ON DELETE CASCADE,
  snapshot_on              date NOT NULL DEFAULT CURRENT_DATE,
  months_elapsed_at_snap   int  NOT NULL DEFAULT 0 CHECK (months_elapsed_at_snap >= 0),
  expected_realized_rupees bigint NOT NULL DEFAULT 0 CHECK (expected_realized_rupees >= 0),
  actual_realized_rupees   bigint NOT NULL DEFAULT 0 CHECK (actual_realized_rupees >= 0),
  variance_bps             int  NOT NULL DEFAULT 0,
  accuracy_band            text NOT NULL DEFAULT 'on_track'
    CHECK (accuracy_band IN ('severely_under','under','on_track','over','severely_over')),
  model_adjustment_note    text,
  adjusted_model_version   text,
  created_by               uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fclal_r2300_pred  ON public.founder_customer_ltv_accuracy_log_r2300(prediction_id);
CREATE INDEX IF NOT EXISTS idx_fclal_r2300_snap  ON public.founder_customer_ltv_accuracy_log_r2300(snapshot_on);
CREATE INDEX IF NOT EXISTS idx_fclal_r2300_band  ON public.founder_customer_ltv_accuracy_log_r2300(accuracy_band);

-- =========================================================================
-- RLS — founder_all
-- =========================================================================
ALTER TABLE public.founder_customer_ltv_predictions_r2300  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_ltv_accuracy_log_r2300 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fclp_r2300 ON public.founder_customer_ltv_predictions_r2300;
CREATE POLICY founder_all_fclp_r2300 ON public.founder_customer_ltv_predictions_r2300
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fclal_r2300 ON public.founder_customer_ltv_accuracy_log_r2300;
CREATE POLICY founder_all_fclal_r2300 ON public.founder_customer_ltv_accuracy_log_r2300
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs (7) — all is_founder gated, plpgsql SECURITY DEFINER
-- =========================================================================

-- 1. list_ltv_predictions
CREATE OR REPLACE FUNCTION public.list_ltv_predictions_r2300()
RETURNS TABLE (
  id uuid,
  customer_label text,
  customer_segment text,
  cohort_month date,
  predicted_ltv_rupees bigint,
  predicted_horizon_months int,
  realized_to_date_rupees bigint,
  months_elapsed int,
  status text,
  confidence_band text,
  realized_pct_of_predicted_bps int,
  predicted_on date,
  prediction_model_version text,
  last_realized_refresh_on date,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.customer_label, p.customer_segment, p.cohort_month,
         p.predicted_ltv_rupees, p.predicted_horizon_months,
         p.realized_to_date_rupees, p.months_elapsed, p.status, p.confidence_band,
         CASE WHEN p.predicted_ltv_rupees > 0
              THEN ((p.realized_to_date_rupees::numeric / p.predicted_ltv_rupees::numeric) * 10000)::int
              ELSE 0 END AS realized_pct_of_predicted_bps,
         p.predicted_on, p.prediction_model_version, p.last_realized_refresh_on,
         p.notes, p.created_at
    FROM public.founder_customer_ltv_predictions_r2300 p
   ORDER BY p.cohort_month DESC, p.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_ltv_predictions_r2300() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ltv_predictions_r2300() TO authenticated;

-- 2. create_ltv_prediction
CREATE OR REPLACE FUNCTION public.create_ltv_prediction_r2300(
  p_customer_label text,
  p_customer_segment text,
  p_cohort_month date,
  p_predicted_ltv_rupees bigint,
  p_predicted_horizon_months int,
  p_prediction_model_version text,
  p_confidence_band text,
  p_customer_org_id uuid,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  INSERT INTO public.founder_customer_ltv_predictions_r2300 (
    customer_org_id, customer_label, customer_segment, cohort_month,
    predicted_ltv_rupees, predicted_horizon_months, prediction_model_version,
    confidence_band, notes, created_by
  )
  VALUES (
    p_customer_org_id, p_customer_label, COALESCE(p_customer_segment,'standalone_clinic'), p_cohort_month,
    GREATEST(p_predicted_ltv_rupees, 0), COALESCE(p_predicted_horizon_months, 36),
    COALESCE(p_prediction_model_version,'v1'), COALESCE(p_confidence_band,'medium'),
    p_notes, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_ltv_prediction_r2300(text,text,date,bigint,int,text,text,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_ltv_prediction_r2300(text,text,date,bigint,int,text,text,uuid,text) TO authenticated;

-- 3. update_ltv_realized
CREATE OR REPLACE FUNCTION public.update_ltv_realized_r2300(
  p_prediction_id uuid,
  p_realized_to_date_rupees bigint,
  p_months_elapsed int,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_customer_ltv_predictions_r2300
     SET realized_to_date_rupees  = GREATEST(p_realized_to_date_rupees, 0),
         months_elapsed           = GREATEST(p_months_elapsed, 0),
         status                   = COALESCE(p_status, status),
         last_realized_refresh_on = CURRENT_DATE,
         updated_at               = now()
   WHERE id = p_prediction_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_ltv_realized_r2300(uuid,bigint,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_ltv_realized_r2300(uuid,bigint,int,text) TO authenticated;

-- 4. log_ltv_accuracy_snapshot
CREATE OR REPLACE FUNCTION public.log_ltv_accuracy_snapshot_r2300(
  p_prediction_id uuid,
  p_actual_realized_rupees bigint,
  p_model_adjustment_note text,
  p_adjusted_model_version text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
  v_predicted bigint;
  v_horizon int;
  v_elapsed int;
  v_expected bigint;
  v_variance_bps int;
  v_band text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  SELECT predicted_ltv_rupees, predicted_horizon_months, months_elapsed
    INTO v_predicted, v_horizon, v_elapsed
    FROM public.founder_customer_ltv_predictions_r2300 WHERE id = p_prediction_id;
  IF v_predicted IS NULL THEN RAISE EXCEPTION 'prediction_not_found'; END IF;
  v_expected := CASE WHEN v_horizon > 0
                     THEN (v_predicted::numeric * (LEAST(v_elapsed, v_horizon)::numeric / v_horizon::numeric))::bigint
                     ELSE 0 END;
  v_variance_bps := CASE WHEN v_expected > 0
                         THEN (((p_actual_realized_rupees::numeric - v_expected::numeric) / v_expected::numeric) * 10000)::int
                         ELSE 0 END;
  v_band := CASE
    WHEN v_variance_bps <= -3000 THEN 'severely_under'
    WHEN v_variance_bps <= -1000 THEN 'under'
    WHEN v_variance_bps >=  3000 THEN 'severely_over'
    WHEN v_variance_bps >=  1000 THEN 'over'
    ELSE 'on_track'
  END;
  INSERT INTO public.founder_customer_ltv_accuracy_log_r2300 (
    prediction_id, months_elapsed_at_snap, expected_realized_rupees,
    actual_realized_rupees, variance_bps, accuracy_band,
    model_adjustment_note, adjusted_model_version, created_by
  )
  VALUES (
    p_prediction_id, v_elapsed, GREATEST(v_expected,0),
    GREATEST(p_actual_realized_rupees,0), v_variance_bps, v_band,
    p_model_adjustment_note, p_adjusted_model_version, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_ltv_accuracy_snapshot_r2300(uuid,bigint,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_ltv_accuracy_snapshot_r2300(uuid,bigint,text,text) TO authenticated;

-- 5. list_ltv_accuracy_log
CREATE OR REPLACE FUNCTION public.list_ltv_accuracy_log_r2300(p_prediction_id uuid)
RETURNS TABLE (
  id uuid,
  prediction_id uuid,
  snapshot_on date,
  months_elapsed_at_snap int,
  expected_realized_rupees bigint,
  actual_realized_rupees bigint,
  variance_bps int,
  accuracy_band text,
  model_adjustment_note text,
  adjusted_model_version text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.prediction_id, l.snapshot_on, l.months_elapsed_at_snap,
         l.expected_realized_rupees, l.actual_realized_rupees, l.variance_bps,
         l.accuracy_band, l.model_adjustment_note, l.adjusted_model_version, l.created_at
    FROM public.founder_customer_ltv_accuracy_log_r2300 l
   WHERE (p_prediction_id IS NULL OR l.prediction_id = p_prediction_id)
   ORDER BY l.snapshot_on DESC, l.created_at DESC
   LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.list_ltv_accuracy_log_r2300(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ltv_accuracy_log_r2300(uuid) TO authenticated;

-- 6. ltv_accuracy_summary
CREATE OR REPLACE FUNCTION public.ltv_accuracy_summary_r2300()
RETURNS TABLE (
  total_predictions int,
  active_predictions int,
  churned_predictions int,
  total_predicted_rupees bigint,
  total_realized_rupees bigint,
  realized_pct_of_predicted_bps int,
  snapshots_logged int,
  on_track_snaps int,
  under_snaps int,
  over_snaps int,
  avg_variance_bps int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int; v_active int; v_churned int;
  v_pred bigint; v_real bigint; v_pct int;
  v_snaps int; v_on int; v_under int; v_over int; v_avgvar int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE status = 'active')::int,
         COUNT(*) FILTER (WHERE status = 'churned')::int,
         COALESCE(SUM(predicted_ltv_rupees),0)::bigint,
         COALESCE(SUM(realized_to_date_rupees),0)::bigint
    INTO v_total, v_active, v_churned, v_pred, v_real
    FROM public.founder_customer_ltv_predictions_r2300;
  v_pct := CASE WHEN v_pred > 0
                THEN ((v_real::numeric / v_pred::numeric) * 10000)::int
                ELSE 0 END;
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE accuracy_band = 'on_track')::int,
         COUNT(*) FILTER (WHERE accuracy_band IN ('under','severely_under'))::int,
         COUNT(*) FILTER (WHERE accuracy_band IN ('over','severely_over'))::int,
         COALESCE(AVG(variance_bps),0)::int
    INTO v_snaps, v_on, v_under, v_over, v_avgvar
    FROM public.founder_customer_ltv_accuracy_log_r2300;
  RETURN QUERY SELECT v_total, v_active, v_churned, v_pred, v_real, v_pct,
                      v_snaps, v_on, v_under, v_over, v_avgvar;
END;
$$;

REVOKE ALL ON FUNCTION public.ltv_accuracy_summary_r2300() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ltv_accuracy_summary_r2300() TO authenticated;

-- 7. ltv_segment_breakdown
CREATE OR REPLACE FUNCTION public.ltv_segment_breakdown_r2300()
RETURNS TABLE (
  customer_segment text,
  predictions_count int,
  total_predicted_rupees bigint,
  total_realized_rupees bigint,
  realized_pct_of_predicted_bps int,
  avg_predicted_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.customer_segment,
         COUNT(*)::int                                          AS predictions_count,
         COALESCE(SUM(p.predicted_ltv_rupees),0)::bigint        AS total_predicted_rupees,
         COALESCE(SUM(p.realized_to_date_rupees),0)::bigint     AS total_realized_rupees,
         CASE WHEN COALESCE(SUM(p.predicted_ltv_rupees),0) > 0
              THEN ((SUM(p.realized_to_date_rupees)::numeric / SUM(p.predicted_ltv_rupees)::numeric) * 10000)::int
              ELSE 0 END                                        AS realized_pct_of_predicted_bps,
         COALESCE(AVG(p.predicted_ltv_rupees),0)::bigint        AS avg_predicted_rupees
    FROM public.founder_customer_ltv_predictions_r2300 p
   GROUP BY p.customer_segment
   ORDER BY total_predicted_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.ltv_segment_breakdown_r2300() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ltv_segment_breakdown_r2300() TO authenticated;

COMMIT;
