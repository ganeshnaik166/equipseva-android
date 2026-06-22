BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_procurement_predictions_r2232 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  predicted_cycle_start date NOT NULL,
  predicted_cycle_end date NOT NULL,
  predicted_value_rupees bigint NOT NULL DEFAULT 0,
  predicted_equipment_class text NOT NULL,
  cycle_days_observed int NOT NULL DEFAULT 0,
  historical_buy_count int NOT NULL DEFAULT 0,
  founder_confidence_pct int NOT NULL DEFAULT 50 CHECK (founder_confidence_pct BETWEEN 0 AND 100),
  prediction_basis text,
  last_buy_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_procurement_cycle_events_r2232 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prediction_id uuid NOT NULL REFERENCES public.hospital_procurement_predictions_r2232(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('observed_buy','predicted','confirmed','missed','rescored')),
  event_at timestamptz NOT NULL DEFAULT now(),
  value_rupees bigint NOT NULL DEFAULT 0,
  equipment_class text,
  notes text,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_procurement_predictions_r2232 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_procurement_cycle_events_r2232 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_procurement_predictions_r2232;
CREATE POLICY founder_all ON public.hospital_procurement_predictions_r2232
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_procurement_cycle_events_r2232;
CREATE POLICY founder_all ON public.hospital_procurement_cycle_events_r2232
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_hpp_r2232_hospital ON public.hospital_procurement_predictions_r2232(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hpp_r2232_cycle_start ON public.hospital_procurement_predictions_r2232(predicted_cycle_start);
CREATE INDEX IF NOT EXISTS idx_hpce_r2232_prediction ON public.hospital_procurement_cycle_events_r2232(prediction_id);
CREATE INDEX IF NOT EXISTS idx_hpce_r2232_hospital ON public.hospital_procurement_cycle_events_r2232(hospital_org_id);

CREATE OR REPLACE FUNCTION public.r2232_list_predictions()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  predicted_cycle_start date,
  predicted_cycle_end date,
  predicted_value_rupees bigint,
  predicted_equipment_class text,
  founder_confidence_pct int,
  historical_buy_count int,
  cycle_days_observed int,
  last_buy_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_name, p.predicted_cycle_start, p.predicted_cycle_end,
         p.predicted_value_rupees, p.predicted_equipment_class,
         p.founder_confidence_pct, p.historical_buy_count, p.cycle_days_observed,
         p.last_buy_at
  FROM public.hospital_procurement_predictions_r2232 p
  ORDER BY p.predicted_cycle_start ASC, p.founder_confidence_pct DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_summary_stats()
RETURNS TABLE (
  total_predictions int,
  high_confidence_count int,
  upcoming_30d_count int,
  total_predicted_value_rupees bigint,
  avg_confidence_pct int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE founder_confidence_pct >= 70))::int,
    (COUNT(*) FILTER (WHERE predicted_cycle_start <= (now()::date + 30) AND predicted_cycle_start >= now()::date))::int,
    COALESCE(SUM(predicted_value_rupees),0)::bigint,
    COALESCE(AVG(founder_confidence_pct),0)::int
  FROM public.hospital_procurement_predictions_r2232;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_by_equipment_class()
RETURNS TABLE (
  equipment_class text,
  prediction_count int,
  total_value_rupees bigint,
  avg_confidence_pct int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.predicted_equipment_class,
         (COUNT(*))::int,
         COALESCE(SUM(p.predicted_value_rupees),0)::bigint,
         COALESCE(AVG(p.founder_confidence_pct),0)::int
  FROM public.hospital_procurement_predictions_r2232 p
  GROUP BY p.predicted_equipment_class
  ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_upcoming_cycles(p_days int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  predicted_cycle_start date,
  predicted_value_rupees bigint,
  predicted_equipment_class text,
  founder_confidence_pct int,
  days_until_cycle int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_name, p.predicted_cycle_start,
         p.predicted_value_rupees, p.predicted_equipment_class,
         p.founder_confidence_pct,
         (p.predicted_cycle_start - now()::date)::int
  FROM public.hospital_procurement_predictions_r2232 p
  WHERE p.predicted_cycle_start >= now()::date
    AND p.predicted_cycle_start <= (now()::date + p_days)
  ORDER BY p.predicted_cycle_start ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_recent_events()
RETURNS TABLE (
  id uuid,
  prediction_id uuid,
  event_type text,
  event_at timestamptz,
  value_rupees bigint,
  equipment_class text,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.prediction_id, e.event_type, e.event_at,
         e.value_rupees, e.equipment_class, e.notes
  FROM public.hospital_procurement_cycle_events_r2232 e
  ORDER BY e.event_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_confidence_bands()
RETURNS TABLE (
  band text,
  prediction_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN founder_confidence_pct >= 80 THEN 'high (80-100)'
      WHEN founder_confidence_pct >= 50 THEN 'medium (50-79)'
      ELSE 'low (0-49)'
    END,
    (COUNT(*))::int,
    COALESCE(SUM(predicted_value_rupees),0)::bigint
  FROM public.hospital_procurement_predictions_r2232
  GROUP BY 1
  ORDER BY 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2232_top_hospitals()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  prediction_count int,
  total_value_rupees bigint,
  avg_confidence_pct int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.hospital_org_id, p.hospital_name,
         (COUNT(*))::int,
         COALESCE(SUM(p.predicted_value_rupees),0)::bigint,
         COALESCE(AVG(p.founder_confidence_pct),0)::int
  FROM public.hospital_procurement_predictions_r2232 p
  GROUP BY p.hospital_org_id, p.hospital_name
  ORDER BY SUM(p.predicted_value_rupees) DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.r2232_list_predictions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_summary_stats() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_by_equipment_class() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_upcoming_cycles(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_recent_events() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_confidence_bands() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2232_top_hospitals() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2232_list_predictions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_summary_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_by_equipment_class() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_upcoming_cycles(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_recent_events() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_confidence_bands() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2232_top_hospitals() TO authenticated;

COMMIT;
