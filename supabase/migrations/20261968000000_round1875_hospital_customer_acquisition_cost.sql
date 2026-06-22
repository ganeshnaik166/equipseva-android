BEGIN;

-- ============================================================================
-- Round 1875 — Hospital Customer Acquisition Cost (CAC)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_cac_metrics_r1875 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_period_start date NOT NULL,
  snapshot_period_end date NOT NULL,
  total_sales_spend_rupees bigint NOT NULL DEFAULT 0,
  total_marketing_spend_rupees bigint NOT NULL DEFAULT 0,
  total_founder_time_value_rupees bigint NOT NULL DEFAULT 0,
  new_customers_acquired int NOT NULL DEFAULT 0,
  cac_rupees bigint NOT NULL DEFAULT 0,
  payback_months numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cac_segment_breakdown_r1875 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_id uuid NOT NULL REFERENCES public.hospital_cac_metrics_r1875(id) ON DELETE CASCADE,
  segment text NOT NULL CHECK (segment IN ('tier_1','tier_2','tier_3','dental','multispec')),
  customers_acquired int NOT NULL DEFAULT 0,
  segment_cac_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cac_metrics_r1875_recorded ON public.hospital_cac_metrics_r1875(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_cac_metrics_r1875_status ON public.hospital_cac_metrics_r1875(status);
CREATE INDEX IF NOT EXISTS idx_cac_segment_r1875_metric ON public.hospital_cac_segment_breakdown_r1875(metric_id);

ALTER TABLE public.hospital_cac_metrics_r1875 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cac_segment_breakdown_r1875 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cac_metrics_r1875 ON public.hospital_cac_metrics_r1875;
CREATE POLICY founder_all_cac_metrics_r1875 ON public.hospital_cac_metrics_r1875
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_cac_segments_r1875 ON public.hospital_cac_segment_breakdown_r1875;
CREATE POLICY founder_all_cac_segments_r1875 ON public.hospital_cac_segment_breakdown_r1875
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_cac_metrics_r1875(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  snapshot_period_start date,
  snapshot_period_end date,
  total_sales_spend_rupees bigint,
  total_marketing_spend_rupees bigint,
  total_founder_time_value_rupees bigint,
  new_customers_acquired int,
  cac_rupees bigint,
  payback_months numeric,
  status text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.snapshot_period_start, m.snapshot_period_end,
           m.total_sales_spend_rupees, m.total_marketing_spend_rupees,
           m.total_founder_time_value_rupees, m.new_customers_acquired,
           m.cac_rupees, m.payback_months, m.status, m.recorded_at
    FROM public.hospital_cac_metrics_r1875 m
    ORDER BY m.recorded_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

CREATE OR REPLACE FUNCTION public.take_cac_snapshot_r1875(
  p_period_start date,
  p_period_end date,
  p_sales_spend bigint,
  p_marketing_spend bigint,
  p_founder_time_value bigint,
  p_new_customers int,
  p_payback_months numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_cac bigint;
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_total := COALESCE(p_sales_spend,0) + COALESCE(p_marketing_spend,0) + COALESCE(p_founder_time_value,0);
  v_cac := CASE WHEN COALESCE(p_new_customers,0) > 0 THEN (v_total / p_new_customers)::bigint ELSE 0 END;

  UPDATE public.hospital_cac_metrics_r1875 SET status = 'superseded', updated_at = now()
   WHERE status = 'current';

  INSERT INTO public.hospital_cac_metrics_r1875(
    snapshot_period_start, snapshot_period_end,
    total_sales_spend_rupees, total_marketing_spend_rupees, total_founder_time_value_rupees,
    new_customers_acquired, cac_rupees, payback_months, status
  ) VALUES (
    p_period_start, p_period_end,
    COALESCE(p_sales_spend,0), COALESCE(p_marketing_spend,0), COALESCE(p_founder_time_value,0),
    COALESCE(p_new_customers,0), v_cac, COALESCE(p_payback_months,0), 'current'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'take_cac_snapshot_r1875',
          jsonb_build_object('id', v_id, 'cac_rupees', v_cac, 'new_customers', p_new_customers),
          now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_cac_segments_r1875(p_metric_id uuid)
RETURNS TABLE (
  id uuid,
  metric_id uuid,
  segment text,
  customers_acquired int,
  segment_cac_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.metric_id, s.segment, s.customers_acquired, s.segment_cac_rupees
    FROM public.hospital_cac_segment_breakdown_r1875 s
    WHERE s.metric_id = p_metric_id
    ORDER BY s.segment_cac_rupees DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_cac_segment_r1875(
  p_metric_id uuid,
  p_segment text,
  p_customers int,
  p_segment_cac bigint
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
  INSERT INTO public.hospital_cac_segment_breakdown_r1875(
    metric_id, segment, customers_acquired, segment_cac_rupees
  ) VALUES (
    p_metric_id, p_segment, COALESCE(p_customers,0), COALESCE(p_segment_cac,0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cac_segment_r1875',
          jsonb_build_object('id', v_id, 'metric_id', p_metric_id, 'segment', p_segment,
                             'customers', p_customers, 'segment_cac', p_segment_cac),
          now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.latest_cac_r1875()
RETURNS TABLE (
  id uuid,
  cac_rupees bigint,
  new_customers_acquired int,
  payback_months numeric,
  total_spend_rupees bigint,
  snapshot_period_start date,
  snapshot_period_end date,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.cac_rupees, m.new_customers_acquired, m.payback_months,
           (m.total_sales_spend_rupees + m.total_marketing_spend_rupees + m.total_founder_time_value_rupees)::bigint,
           m.snapshot_period_start, m.snapshot_period_end, m.recorded_at
    FROM public.hospital_cac_metrics_r1875 m
    WHERE m.status = 'current'
    ORDER BY m.recorded_at DESC
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.cac_trend_r1875(p_limit int DEFAULT 12)
RETURNS TABLE (
  period_start date,
  period_end date,
  cac_rupees bigint,
  new_customers_acquired int,
  payback_months numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.snapshot_period_start, m.snapshot_period_end, m.cac_rupees,
           m.new_customers_acquired, m.payback_months
    FROM public.hospital_cac_metrics_r1875 m
    ORDER BY m.snapshot_period_start DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 12));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_cost_segment_r1875()
RETURNS TABLE (
  segment text,
  customers_acquired int,
  segment_cac_rupees bigint,
  metric_id uuid,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment, s.customers_acquired, s.segment_cac_rupees, s.metric_id, m.recorded_at
    FROM public.hospital_cac_segment_breakdown_r1875 s
    JOIN public.hospital_cac_metrics_r1875 m ON m.id = s.metric_id
    WHERE m.status = 'current'
    ORDER BY s.segment_cac_rupees DESC
    LIMIT 5;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_cac_metrics_r1875(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cac_metrics_r1875(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.take_cac_snapshot_r1875(date, date, bigint, bigint, bigint, int, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.take_cac_snapshot_r1875(date, date, bigint, bigint, bigint, int, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_cac_segments_r1875(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cac_segments_r1875(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_cac_segment_r1875(uuid, text, int, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cac_segment_r1875(uuid, text, int, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.latest_cac_r1875() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.latest_cac_r1875() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.cac_trend_r1875(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cac_trend_r1875(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_cost_segment_r1875() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cost_segment_r1875() TO authenticated;

COMMIT;