BEGIN;

-- ============================================================================
-- Round 1888: Engineer Equipment ROI Per Customer
-- Track per-hospital × per-equipment-category service ROI
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_roi_r1888 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_engineer_hours int NOT NULL DEFAULT 0,
  total_billed_rupees bigint NOT NULL DEFAULT 0,
  total_repair_cost_rupees bigint NOT NULL DEFAULT 0,
  net_margin_rupees bigint NOT NULL DEFAULT 0,
  roi_pct numeric(10,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eq_roi_r1888_hospital ON public.engineer_equipment_roi_r1888(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_eq_roi_r1888_category ON public.engineer_equipment_roi_r1888(equipment_category);
CREATE INDEX IF NOT EXISTS idx_eq_roi_r1888_period ON public.engineer_equipment_roi_r1888(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_eq_roi_r1888_roi ON public.engineer_equipment_roi_r1888(roi_pct DESC);

ALTER TABLE public.engineer_equipment_roi_r1888 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eq_roi_r1888 ON public.engineer_equipment_roi_r1888;
CREATE POLICY founder_all_eq_roi_r1888 ON public.engineer_equipment_roi_r1888
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_roi_anomalies_r1888 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roi_id uuid NOT NULL REFERENCES public.engineer_equipment_roi_r1888(id) ON DELETE CASCADE,
  anomaly_type text NOT NULL CHECK (anomaly_type IN ('loss','extreme_profit','zero_billing','missing_parts','quality_dispute')),
  anomaly_text text NOT NULL,
  founder_action_taken text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eq_roi_anom_r1888_roi ON public.engineer_roi_anomalies_r1888(roi_id);
CREATE INDEX IF NOT EXISTS idx_eq_roi_anom_r1888_type ON public.engineer_roi_anomalies_r1888(anomaly_type);
CREATE INDEX IF NOT EXISTS idx_eq_roi_anom_r1888_created ON public.engineer_roi_anomalies_r1888(created_at DESC);

ALTER TABLE public.engineer_roi_anomalies_r1888 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eq_roi_anom_r1888 ON public.engineer_roi_anomalies_r1888;
CREATE POLICY founder_all_eq_roi_anom_r1888 ON public.engineer_roi_anomalies_r1888
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_rois
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_rois_r1888(int);
CREATE OR REPLACE FUNCTION public.list_rois_r1888(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  equipment_category text,
  period_start date,
  period_end date,
  total_engineer_hours int,
  total_billed_rupees bigint,
  total_repair_cost_rupees bigint,
  net_margin_rupees bigint,
  roi_pct numeric,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    r.equipment_category,
    r.period_start,
    r.period_end,
    r.total_engineer_hours,
    r.total_billed_rupees,
    r.total_repair_cost_rupees,
    r.net_margin_rupees,
    r.roi_pct,
    r.recorded_at
  FROM public.engineer_equipment_roi_r1888 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY r.recorded_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_rois_r1888(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rois_r1888(int) TO authenticated;

-- ============================================================================
-- RPC 2: refresh_roi
-- ============================================================================
DROP FUNCTION IF EXISTS public.refresh_roi_r1888(uuid, text, date, date, int, bigint, bigint);
CREATE OR REPLACE FUNCTION public.refresh_roi_r1888(
  p_hospital_user_id uuid,
  p_equipment_category text,
  p_period_start date,
  p_period_end date,
  p_hours int,
  p_billed_rupees bigint,
  p_repair_cost_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_margin bigint;
  v_roi numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_margin := p_billed_rupees - p_repair_cost_rupees;
  IF p_repair_cost_rupees > 0 THEN
    v_roi := ROUND((v_margin::numeric / p_repair_cost_rupees::numeric) * 100, 2);
  ELSE
    v_roi := 0;
  END IF;

  INSERT INTO public.engineer_equipment_roi_r1888(
    hospital_user_id, equipment_category, period_start, period_end,
    total_engineer_hours, total_billed_rupees, total_repair_cost_rupees,
    net_margin_rupees, roi_pct
  )
  VALUES (
    p_hospital_user_id, p_equipment_category, p_period_start, p_period_end,
    p_hours, p_billed_rupees, p_repair_cost_rupees, v_margin, v_roi
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'refresh_roi_r1888',
    jsonb_build_object(
      'roi_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'equipment_category', p_equipment_category,
      'roi_pct', v_roi
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_roi_r1888(uuid, text, date, date, int, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_roi_r1888(uuid, text, date, date, int, bigint, bigint) TO authenticated;

-- ============================================================================
-- RPC 3: list_anomalies
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_anomalies_r1888(int);
CREATE OR REPLACE FUNCTION public.list_anomalies_r1888(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  roi_id uuid,
  hospital_user_id uuid,
  hospital_name text,
  equipment_category text,
  anomaly_type text,
  anomaly_text text,
  founder_action_taken text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.roi_id,
    r.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    r.equipment_category,
    a.anomaly_type,
    a.anomaly_text,
    a.founder_action_taken,
    a.created_at
  FROM public.engineer_roi_anomalies_r1888 a
  JOIN public.engineer_equipment_roi_r1888 r ON r.id = a.roi_id
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_anomalies_r1888(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_anomalies_r1888(int) TO authenticated;

-- ============================================================================
-- RPC 4: log_anomaly
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_anomaly_r1888(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_anomaly_r1888(
  p_roi_id uuid,
  p_anomaly_type text,
  p_anomaly_text text,
  p_founder_action_taken text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_roi_anomalies_r1888(roi_id, anomaly_type, anomaly_text, founder_action_taken)
  VALUES (p_roi_id, p_anomaly_type, p_anomaly_text, p_founder_action_taken)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_anomaly_r1888',
    jsonb_build_object(
      'anomaly_id', v_id,
      'roi_id', p_roi_id,
      'anomaly_type', p_anomaly_type
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_anomaly_r1888(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_anomaly_r1888(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: top_roi_combinations
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_roi_combinations_r1888(int);
CREATE OR REPLACE FUNCTION public.top_roi_combinations_r1888(p_limit int DEFAULT 20)
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_name text,
  equipment_category text,
  avg_roi_pct numeric,
  total_margin_rupees bigint,
  record_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    r.equipment_category,
    ROUND(AVG(r.roi_pct), 2) AS avg_roi_pct,
    SUM(r.net_margin_rupees)::bigint AS total_margin_rupees,
    (COUNT(*))::int AS record_count
  FROM public.engineer_equipment_roi_r1888 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  GROUP BY r.hospital_user_id, o.name, p.full_name, r.equipment_category
  ORDER BY avg_roi_pct DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_roi_combinations_r1888(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_combinations_r1888(int) TO authenticated;

-- ============================================================================
-- RPC 6: low_roi_combinations
-- ============================================================================
DROP FUNCTION IF EXISTS public.low_roi_combinations_r1888(int);
CREATE OR REPLACE FUNCTION public.low_roi_combinations_r1888(p_limit int DEFAULT 20)
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_name text,
  equipment_category text,
  avg_roi_pct numeric,
  total_margin_rupees bigint,
  record_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    r.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
    r.equipment_category,
    ROUND(AVG(r.roi_pct), 2) AS avg_roi_pct,
    SUM(r.net_margin_rupees)::bigint AS total_margin_rupees,
    (COUNT(*))::int AS record_count
  FROM public.engineer_equipment_roi_r1888 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  GROUP BY r.hospital_user_id, o.name, p.full_name, r.equipment_category
  ORDER BY avg_roi_pct ASC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.low_roi_combinations_r1888(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_roi_combinations_r1888(int) TO authenticated;

-- ============================================================================
-- RPC 7: recent_anomalies
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_anomalies_r1888(int);
CREATE OR REPLACE FUNCTION public.recent_anomalies_r1888(p_days int DEFAULT 7)
RETURNS TABLE(
  anomaly_type text,
  count_total int,
  count_unresolved int,
  most_recent timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.anomaly_type,
    (COUNT(*))::int AS count_total,
    (COUNT(*) FILTER (WHERE a.founder_action_taken IS NULL))::int AS count_unresolved,
    MAX(a.created_at) AS most_recent
  FROM public.engineer_roi_anomalies_r1888 a
  WHERE a.created_at >= (now() - (p_days || ' days')::interval)
  GROUP BY a.anomaly_type
  ORDER BY count_total DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_anomalies_r1888(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_anomalies_r1888(int) TO authenticated;

COMMIT;