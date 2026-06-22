BEGIN;

-- =====================================================================
-- Round 1879: Hospital Service Cost Per Job
-- Track per-job true cost (engineer time, travel, parts, overhead)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: hospital_service_cost_per_job_r1879
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_service_cost_per_job_r1879 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL,
  engineer_minutes int NOT NULL DEFAULT 0,
  travel_cost_rupees int NOT NULL DEFAULT 0,
  parts_cost_rupees int NOT NULL DEFAULT 0,
  overhead_allocation_rupees int NOT NULL DEFAULT 0,
  total_cost_rupees bigint NOT NULL DEFAULT 0,
  billed_amount_rupees bigint NOT NULL DEFAULT 0,
  margin_pct numeric(8,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hscpj_r1879_repair_job
  ON public.hospital_service_cost_per_job_r1879 (repair_job_id);
CREATE INDEX IF NOT EXISTS idx_hscpj_r1879_recorded
  ON public.hospital_service_cost_per_job_r1879 (recorded_at DESC);

ALTER TABLE public.hospital_service_cost_per_job_r1879 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hscpj_r1879_founder_all ON public.hospital_service_cost_per_job_r1879;
CREATE POLICY hscpj_r1879_founder_all
  ON public.hospital_service_cost_per_job_r1879
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- Table 2: hospital_cost_breakdown_anomalies_r1879
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_cost_breakdown_anomalies_r1879 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cost_id uuid NOT NULL REFERENCES public.hospital_service_cost_per_job_r1879(id) ON DELETE CASCADE,
  anomaly_type text NOT NULL CHECK (anomaly_type IN ('unusual_travel','parts_overrun','time_overrun','missing_billing')),
  anomaly_text text NOT NULL,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcba_r1879_cost ON public.hospital_cost_breakdown_anomalies_r1879 (cost_id);
CREATE INDEX IF NOT EXISTS idx_hcba_r1879_type ON public.hospital_cost_breakdown_anomalies_r1879 (anomaly_type);

ALTER TABLE public.hospital_cost_breakdown_anomalies_r1879 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcba_r1879_founder_all ON public.hospital_cost_breakdown_anomalies_r1879;
CREATE POLICY hcba_r1879_founder_all
  ON public.hospital_cost_breakdown_anomalies_r1879
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- RPC 1: list_costs_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_costs_r1879(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  repair_job_id uuid,
  engineer_minutes int,
  travel_cost_rupees int,
  parts_cost_rupees int,
  overhead_allocation_rupees int,
  total_cost_rupees bigint,
  billed_amount_rupees bigint,
  margin_pct numeric,
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
    SELECT c.id, c.repair_job_id, c.engineer_minutes, c.travel_cost_rupees,
           c.parts_cost_rupees, c.overhead_allocation_rupees, c.total_cost_rupees,
           c.billed_amount_rupees, c.margin_pct, c.recorded_at
      FROM public.hospital_service_cost_per_job_r1879 c
     ORDER BY c.recorded_at DESC
     LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_costs_r1879(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_costs_r1879(int) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: log_cost_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_cost_r1879(
  p_repair_job_id uuid,
  p_engineer_minutes int,
  p_travel_cost_rupees int,
  p_parts_cost_rupees int,
  p_overhead_allocation_rupees int,
  p_billed_amount_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_total bigint;
  v_margin numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_total := COALESCE(p_travel_cost_rupees,0) + COALESCE(p_parts_cost_rupees,0) + COALESCE(p_overhead_allocation_rupees,0);
  IF p_billed_amount_rupees > 0 THEN
    v_margin := ROUND(((p_billed_amount_rupees - v_total)::numeric / p_billed_amount_rupees::numeric) * 100, 2);
  ELSE
    v_margin := 0;
  END IF;

  INSERT INTO public.hospital_service_cost_per_job_r1879(
    repair_job_id, engineer_minutes, travel_cost_rupees, parts_cost_rupees,
    overhead_allocation_rupees, total_cost_rupees, billed_amount_rupees, margin_pct
  ) VALUES (
    p_repair_job_id, p_engineer_minutes, p_travel_cost_rupees, p_parts_cost_rupees,
    p_overhead_allocation_rupees, v_total, p_billed_amount_rupees, v_margin
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_cost_r1879',
    jsonb_build_object('cost_id', v_id, 'repair_job_id', p_repair_job_id, 'total_cost', v_total, 'margin_pct', v_margin)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_cost_r1879(uuid,int,int,int,int,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cost_r1879(uuid,int,int,int,int,bigint) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: list_anomalies_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_anomalies_r1879(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  cost_id uuid,
  anomaly_type text,
  anomaly_text text,
  founder_note text,
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
    SELECT a.id, a.cost_id, a.anomaly_type, a.anomaly_text, a.founder_note, a.created_at
      FROM public.hospital_cost_breakdown_anomalies_r1879 a
     ORDER BY a.created_at DESC
     LIMIT GREATEST(1, LEAST(p_limit, 1000));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_anomalies_r1879(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_anomalies_r1879(int) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: log_anomaly_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_anomaly_r1879(
  p_cost_id uuid,
  p_anomaly_type text,
  p_anomaly_text text,
  p_founder_note text
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

  IF p_anomaly_type NOT IN ('unusual_travel','parts_overrun','time_overrun','missing_billing') THEN
    RAISE EXCEPTION 'invalid anomaly_type';
  END IF;

  INSERT INTO public.hospital_cost_breakdown_anomalies_r1879(cost_id, anomaly_type, anomaly_text, founder_note)
  VALUES (p_cost_id, p_anomaly_type, p_anomaly_text, p_founder_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_anomaly_r1879',
    jsonb_build_object('anomaly_id', v_id, 'cost_id', p_cost_id, 'type', p_anomaly_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_anomaly_r1879(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_anomaly_r1879(uuid,text,text,text) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: monthly_margin_summary_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.monthly_margin_summary_r1879()
RETURNS TABLE(
  month_start date,
  jobs_count int,
  total_cost_rupees bigint,
  total_billed_rupees bigint,
  avg_margin_pct numeric
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
    SELECT date_trunc('month', c.recorded_at)::date AS month_start,
           (COUNT(*))::int AS jobs_count,
           COALESCE(SUM(c.total_cost_rupees), 0)::bigint AS total_cost_rupees,
           COALESCE(SUM(c.billed_amount_rupees), 0)::bigint AS total_billed_rupees,
           COALESCE(ROUND(AVG(c.margin_pct), 2), 0)::numeric AS avg_margin_pct
      FROM public.hospital_service_cost_per_job_r1879 c
     GROUP BY 1
     ORDER BY 1 DESC
     LIMIT 24;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.monthly_margin_summary_r1879() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_margin_summary_r1879() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: top_loss_jobs_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.top_loss_jobs_r1879(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  repair_job_id uuid,
  total_cost_rupees bigint,
  billed_amount_rupees bigint,
  loss_rupees bigint,
  margin_pct numeric,
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
    SELECT c.id, c.repair_job_id, c.total_cost_rupees, c.billed_amount_rupees,
           (c.total_cost_rupees - c.billed_amount_rupees)::bigint AS loss_rupees,
           c.margin_pct, c.recorded_at
      FROM public.hospital_service_cost_per_job_r1879 c
     WHERE c.total_cost_rupees > c.billed_amount_rupees
     ORDER BY (c.total_cost_rupees - c.billed_amount_rupees) DESC
     LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_loss_jobs_r1879(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loss_jobs_r1879(int) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: top_profit_jobs_r1879
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.top_profit_jobs_r1879(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  repair_job_id uuid,
  total_cost_rupees bigint,
  billed_amount_rupees bigint,
  profit_rupees bigint,
  margin_pct numeric,
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
    SELECT c.id, c.repair_job_id, c.total_cost_rupees, c.billed_amount_rupees,
           (c.billed_amount_rupees - c.total_cost_rupees)::bigint AS profit_rupees,
           c.margin_pct, c.recorded_at
      FROM public.hospital_service_cost_per_job_r1879 c
     WHERE c.billed_amount_rupees > c.total_cost_rupees
     ORDER BY (c.billed_amount_rupees - c.total_cost_rupees) DESC
     LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_profit_jobs_r1879(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_profit_jobs_r1879(int) TO authenticated;

COMMIT;