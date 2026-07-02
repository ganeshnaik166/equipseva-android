-- Round 2420 — Customer Equipment Lemon Detector
-- Track equipment failures, CM cost, downtime, and lemon-score replacement decisions.

BEGIN;

-- ============================================================================
-- TABLE: equipment_failure_log_r2420
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.equipment_failure_log_r2420 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  equipment_label text NOT NULL,
  equipment_model text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  failure_at timestamptz NOT NULL DEFAULT now(),
  failure_kind text NOT NULL CHECK (failure_kind IN ('electrical','mechanical','software','sensor','calibration','other')),
  cm_visits integer NOT NULL DEFAULT 1 CHECK (cm_visits >= 0),
  cm_cost_rupees integer NOT NULL DEFAULT 0 CHECK (cm_cost_rupees >= 0),
  downtime_minutes integer NOT NULL DEFAULT 0 CHECK (downtime_minutes >= 0),
  root_cause text,
  repaired_at timestamptz,
  notes text
);

ALTER TABLE public.equipment_failure_log_r2420 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.equipment_failure_log_r2420
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: lemon_scorecards_r2420
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.lemon_scorecards_r2420 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  equipment_label text NOT NULL,
  equipment_model text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  total_failures integer NOT NULL DEFAULT 0 CHECK (total_failures >= 0),
  total_cm_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (total_cm_cost_rupees >= 0),
  total_downtime_minutes integer NOT NULL DEFAULT 0 CHECK (total_downtime_minutes >= 0),
  lemon_score integer NOT NULL DEFAULT 0 CHECK (lemon_score >= 0 AND lemon_score <= 100),
  recommendation text NOT NULL DEFAULT 'monitor' CHECK (recommendation IN ('monitor','refurbish','replace','escalate')),
  replacement_cost_rupees integer NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  repair_cost_to_date_rupees integer NOT NULL DEFAULT 0 CHECK (repair_cost_to_date_rupees >= 0),
  score_updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.lemon_scorecards_r2420 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.lemon_scorecards_r2420
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_failures_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_failures_r2420()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_model text,
  hospital_user_id uuid,
  failure_at timestamptz,
  failure_kind text,
  cm_visits integer,
  cm_cost_rupees integer,
  downtime_minutes integer,
  root_cause text,
  repaired_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.equipment_label, f.equipment_model, f.hospital_user_id,
           f.failure_at, f.failure_kind, f.cm_visits, f.cm_cost_rupees,
           f.downtime_minutes, f.root_cause, f.repaired_at, f.notes
      FROM public.equipment_failure_log_r2420 f
      ORDER BY f.failure_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_failures_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_failures_r2420() TO authenticated;

-- ============================================================================
-- RPC: list_scorecards_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_scorecards_r2420()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  equipment_model text,
  hospital_user_id uuid,
  total_failures integer,
  total_cm_cost_rupees bigint,
  total_downtime_minutes integer,
  lemon_score integer,
  recommendation text,
  replacement_cost_rupees integer,
  repair_cost_to_date_rupees integer,
  score_updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.equipment_label, s.equipment_model, s.hospital_user_id,
           s.total_failures, s.total_cm_cost_rupees, s.total_downtime_minutes,
           s.lemon_score, s.recommendation, s.replacement_cost_rupees,
           s.repair_cost_to_date_rupees, s.score_updated_at
      FROM public.lemon_scorecards_r2420 s
      ORDER BY s.lemon_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_scorecards_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_scorecards_r2420() TO authenticated;

-- ============================================================================
-- RPC: top_lemons_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_lemons_r2420()
RETURNS TABLE (
  equipment_label text,
  equipment_model text,
  lemon_score integer,
  total_failures integer,
  total_cm_cost_rupees bigint,
  total_downtime_minutes integer,
  recommendation text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.equipment_label, s.equipment_model, s.lemon_score,
           s.total_failures, s.total_cm_cost_rupees, s.total_downtime_minutes,
           s.recommendation
      FROM public.lemon_scorecards_r2420 s
      ORDER BY s.lemon_score DESC
      LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lemons_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lemons_r2420() TO authenticated;

-- ============================================================================
-- RPC: replacement_recommendations_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.replacement_recommendations_r2420()
RETURNS TABLE (
  recommendation text,
  unit_count bigint,
  total_repair_cost_rupees bigint,
  total_replacement_cost_rupees bigint,
  total_downtime_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.recommendation,
           COUNT(*)::bigint AS unit_count,
           COALESCE(SUM(s.repair_cost_to_date_rupees),0)::bigint AS total_repair_cost_rupees,
           COALESCE(SUM(s.replacement_cost_rupees),0)::bigint AS total_replacement_cost_rupees,
           COALESCE(SUM(s.total_downtime_minutes),0)::bigint AS total_downtime_minutes
      FROM public.lemon_scorecards_r2420 s
     GROUP BY s.recommendation
     ORDER BY unit_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.replacement_recommendations_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.replacement_recommendations_r2420() TO authenticated;

-- ============================================================================
-- RPC: model_failure_patterns_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.model_failure_patterns_r2420()
RETURNS TABLE (
  equipment_model text,
  failure_count bigint,
  total_cm_cost_rupees bigint,
  total_downtime_minutes bigint,
  most_common_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.equipment_model,
           COUNT(*)::bigint AS failure_count,
           COALESCE(SUM(f.cm_cost_rupees),0)::bigint AS total_cm_cost_rupees,
           COALESCE(SUM(f.downtime_minutes),0)::bigint AS total_downtime_minutes,
           (SELECT f2.failure_kind
              FROM public.equipment_failure_log_r2420 f2
             WHERE f2.equipment_model = f.equipment_model
             GROUP BY f2.failure_kind
             ORDER BY COUNT(*) DESC
             LIMIT 1) AS most_common_kind
      FROM public.equipment_failure_log_r2420 f
     GROUP BY f.equipment_model
     ORDER BY failure_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.model_failure_patterns_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.model_failure_patterns_r2420() TO authenticated;

-- ============================================================================
-- RPC: monthly_failure_trend_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_failure_trend_r2420()
RETURNS TABLE (
  month_start date,
  failure_count bigint,
  total_cm_cost_rupees bigint,
  total_downtime_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', f.failure_at)::date AS month_start,
           COUNT(*)::bigint AS failure_count,
           COALESCE(SUM(f.cm_cost_rupees),0)::bigint AS total_cm_cost_rupees,
           COALESCE(SUM(f.downtime_minutes),0)::bigint AS total_downtime_minutes
      FROM public.equipment_failure_log_r2420 f
     GROUP BY date_trunc('month', f.failure_at)::date
     ORDER BY month_start DESC
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_failure_trend_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_failure_trend_r2420() TO authenticated;

-- ============================================================================
-- RPC: repair_vs_replace_economics_r2420
-- ============================================================================
CREATE OR REPLACE FUNCTION public.repair_vs_replace_economics_r2420()
RETURNS TABLE (
  equipment_label text,
  equipment_model text,
  repair_cost_to_date_rupees integer,
  replacement_cost_rupees integer,
  repair_to_replace_pct numeric,
  recommendation text,
  lemon_score integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.equipment_label, s.equipment_model,
           s.repair_cost_to_date_rupees, s.replacement_cost_rupees,
           CASE WHEN s.replacement_cost_rupees > 0
                THEN ROUND((s.repair_cost_to_date_rupees::numeric / s.replacement_cost_rupees::numeric) * 100, 2)
                ELSE 0::numeric END AS repair_to_replace_pct,
           s.recommendation, s.lemon_score
      FROM public.lemon_scorecards_r2420 s
      ORDER BY repair_to_replace_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.repair_vs_replace_economics_r2420() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repair_vs_replace_economics_r2420() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.equipment_failure_log_r2420 (equipment_label, equipment_model, failure_at, failure_kind, cm_visits, cm_cost_rupees, downtime_minutes, root_cause, repaired_at, notes)
VALUES
  ('Apollo Hyd Ultrasound #2','Philips Affiniti 50', now() - interval '40 days', 'electrical', 2, 18000, 720, 'PSU board failure', now() - interval '39 days', 'Recurring electrical fault'),
  ('KIMS Sec X-ray #1','Siemens Multix Fusion', now() - interval '25 days', 'mechanical', 3, 45000, 1440, 'Tube head wear', now() - interval '23 days', 'Past warranty; high CM'),
  ('Yashoda CT #3','GE Revolution EVO', now() - interval '15 days', 'sensor', 1, 8000, 360, 'Cooling sensor drift', now() - interval '14 days', 'Single visit; resolved'),
  ('Care Hosp MRI #1','Siemens Magnetom Vida', now() - interval '8 days', 'calibration', 4, 60000, 2880, 'Gradient calibration drift', now() - interval '5 days', 'Repeat calibration; escalate'),
  ('Continental Dialysis #5','Fresenius 4008S', now() - interval '3 days', 'software', 1, 5000, 240, 'Firmware bug', now() - interval '2 days', 'Patched and stable');

INSERT INTO public.lemon_scorecards_r2420 (equipment_label, equipment_model, total_failures, total_cm_cost_rupees, total_downtime_minutes, lemon_score, recommendation, replacement_cost_rupees, repair_cost_to_date_rupees, score_updated_at)
VALUES
  ('Apollo Hyd Ultrasound #2','Philips Affiniti 50', 6, 95000, 4320, 72, 'refurbish', 1800000, 95000, now() - interval '1 day'),
  ('KIMS Sec X-ray #1','Siemens Multix Fusion', 8, 280000, 8640, 88, 'replace', 2400000, 280000, now() - interval '1 day'),
  ('Yashoda CT #3','GE Revolution EVO', 2, 18000, 720, 24, 'monitor', 12000000, 18000, now() - interval '1 day'),
  ('Care Hosp MRI #1','Siemens Magnetom Vida', 5, 220000, 7200, 81, 'escalate', 28000000, 220000, now() - interval '1 day'),
  ('Continental Dialysis #5','Fresenius 4008S', 1, 5000, 240, 12, 'monitor', 850000, 5000, now() - interval '1 day');

