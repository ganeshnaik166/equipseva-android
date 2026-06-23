BEGIN;

-- =========================================================================
-- r2368 — Customer service-cost-per-job analysis
-- Cost (engineer time + parts + travel) per closed job, by hospital, by
-- equipment class. Founder console only.
-- =========================================================================

-- ---- table 1: per-job cost ledger ----
CREATE TABLE IF NOT EXISTS public.service_cost_per_job_r2368 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_class text NOT NULL,
  closed_at timestamptz NOT NULL DEFAULT now(),
  engineer_minutes integer NOT NULL DEFAULT 0 CHECK (engineer_minutes >= 0),
  engineer_rate_per_hour_rupees integer NOT NULL DEFAULT 0 CHECK (engineer_rate_per_hour_rupees >= 0),
  engineer_cost_rupees integer NOT NULL DEFAULT 0 CHECK (engineer_cost_rupees >= 0),
  parts_cost_rupees integer NOT NULL DEFAULT 0 CHECK (parts_cost_rupees >= 0),
  travel_km integer NOT NULL DEFAULT 0 CHECK (travel_km >= 0),
  travel_cost_rupees integer NOT NULL DEFAULT 0 CHECK (travel_cost_rupees >= 0),
  total_cost_rupees integer NOT NULL DEFAULT 0 CHECK (total_cost_rupees >= 0),
  invoice_amount_rupees integer NOT NULL DEFAULT 0 CHECK (invoice_amount_rupees >= 0),
  margin_rupees integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (repair_job_id)
);

CREATE INDEX IF NOT EXISTS scpj_r2368_hospital_idx ON public.service_cost_per_job_r2368(hospital_user_id);
CREATE INDEX IF NOT EXISTS scpj_r2368_eqclass_idx ON public.service_cost_per_job_r2368(equipment_class);
CREATE INDEX IF NOT EXISTS scpj_r2368_closed_idx ON public.service_cost_per_job_r2368(closed_at DESC);

ALTER TABLE public.service_cost_per_job_r2368 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scpj_r2368_founder_all ON public.service_cost_per_job_r2368;
CREATE POLICY scpj_r2368_founder_all ON public.service_cost_per_job_r2368
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---- table 2: monthly rollup snapshots ----
CREATE TABLE IF NOT EXISTS public.service_cost_monthly_rollup_r2368 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_month date NOT NULL,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_class text NOT NULL,
  jobs_closed integer NOT NULL DEFAULT 0 CHECK (jobs_closed >= 0),
  total_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (total_cost_rupees >= 0),
  total_invoice_rupees bigint NOT NULL DEFAULT 0 CHECK (total_invoice_rupees >= 0),
  total_margin_rupees bigint NOT NULL DEFAULT 0,
  avg_cost_per_job_rupees integer NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (period_month, hospital_user_id, equipment_class)
);

CREATE INDEX IF NOT EXISTS scmr_r2368_period_idx ON public.service_cost_monthly_rollup_r2368(period_month DESC);
CREATE INDEX IF NOT EXISTS scmr_r2368_hospital_idx ON public.service_cost_monthly_rollup_r2368(hospital_user_id);

ALTER TABLE public.service_cost_monthly_rollup_r2368 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scmr_r2368_founder_all ON public.service_cost_monthly_rollup_r2368;
CREATE POLICY scmr_r2368_founder_all ON public.service_cost_monthly_rollup_r2368
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs — 7 founder-gated functions
-- =========================================================================

-- 1) list recent job-cost rows
DROP FUNCTION IF EXISTS public.list_service_cost_jobs_r2368(integer);
CREATE FUNCTION public.list_service_cost_jobs_r2368(p_limit integer DEFAULT 200)
RETURNS TABLE (
  id uuid,
  repair_job_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  engineer_user_id uuid,
  engineer_email text,
  equipment_class text,
  closed_at timestamptz,
  engineer_minutes integer,
  engineer_cost_rupees integer,
  parts_cost_rupees integer,
  travel_km integer,
  travel_cost_rupees integer,
  total_cost_rupees integer,
  invoice_amount_rupees integer,
  margin_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.repair_job_id,
    s.hospital_user_id,
    hp.email AS hospital_email,
    s.engineer_user_id,
    ep.email AS engineer_email,
    s.equipment_class,
    s.closed_at,
    s.engineer_minutes,
    s.engineer_cost_rupees,
    s.parts_cost_rupees,
    s.travel_km,
    s.travel_cost_rupees,
    s.total_cost_rupees,
    s.invoice_amount_rupees,
    s.margin_rupees
  FROM public.service_cost_per_job_r2368 s
  LEFT JOIN public.profiles hp ON hp.id = s.hospital_user_id
  LEFT JOIN public.profiles ep ON ep.id = s.engineer_user_id
  ORDER BY s.closed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.list_service_cost_jobs_r2368(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_service_cost_jobs_r2368(integer) TO authenticated;

-- 2) by-hospital aggregate
DROP FUNCTION IF EXISTS public.cost_by_hospital_r2368();
CREATE FUNCTION public.cost_by_hospital_r2368()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  jobs_closed integer,
  total_cost_rupees bigint,
  total_invoice_rupees bigint,
  total_margin_rupees bigint,
  avg_cost_per_job_rupees integer,
  margin_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.hospital_user_id,
    hp.email AS hospital_email,
    COUNT(*)::integer AS jobs_closed,
    COALESCE(SUM(s.total_cost_rupees), 0)::bigint AS total_cost_rupees,
    COALESCE(SUM(s.invoice_amount_rupees), 0)::bigint AS total_invoice_rupees,
    COALESCE(SUM(s.margin_rupees), 0)::bigint AS total_margin_rupees,
    (COALESCE(SUM(s.total_cost_rupees), 0) / GREATEST(COUNT(*), 1))::integer AS avg_cost_per_job_rupees,
    CASE
      WHEN COALESCE(SUM(s.invoice_amount_rupees), 0) = 0 THEN 0::numeric
      ELSE ROUND((COALESCE(SUM(s.margin_rupees), 0)::numeric / NULLIF(SUM(s.invoice_amount_rupees), 0)::numeric) * 100, 2)
    END AS margin_pct
  FROM public.service_cost_per_job_r2368 s
  LEFT JOIN public.profiles hp ON hp.id = s.hospital_user_id
  GROUP BY s.hospital_user_id, hp.email
  ORDER BY total_cost_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.cost_by_hospital_r2368() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_by_hospital_r2368() TO authenticated;

-- 3) by-equipment-class aggregate
DROP FUNCTION IF EXISTS public.cost_by_equipment_class_r2368();
CREATE FUNCTION public.cost_by_equipment_class_r2368()
RETURNS TABLE (
  equipment_class text,
  jobs_closed integer,
  total_cost_rupees bigint,
  total_invoice_rupees bigint,
  total_margin_rupees bigint,
  avg_cost_per_job_rupees integer,
  avg_engineer_minutes integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.equipment_class,
    COUNT(*)::integer AS jobs_closed,
    COALESCE(SUM(s.total_cost_rupees), 0)::bigint AS total_cost_rupees,
    COALESCE(SUM(s.invoice_amount_rupees), 0)::bigint AS total_invoice_rupees,
    COALESCE(SUM(s.margin_rupees), 0)::bigint AS total_margin_rupees,
    (COALESCE(SUM(s.total_cost_rupees), 0) / GREATEST(COUNT(*), 1))::integer AS avg_cost_per_job_rupees,
    (COALESCE(SUM(s.engineer_minutes), 0) / GREATEST(COUNT(*), 1))::integer AS avg_engineer_minutes
  FROM public.service_cost_per_job_r2368 s
  GROUP BY s.equipment_class
  ORDER BY total_cost_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.cost_by_equipment_class_r2368() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_by_equipment_class_r2368() TO authenticated;

-- 4) cost-breakdown summary (totals across components)
DROP FUNCTION IF EXISTS public.cost_breakdown_summary_r2368();
CREATE FUNCTION public.cost_breakdown_summary_r2368()
RETURNS TABLE (
  jobs_closed integer,
  total_engineer_cost_rupees bigint,
  total_parts_cost_rupees bigint,
  total_travel_cost_rupees bigint,
  total_cost_rupees bigint,
  total_invoice_rupees bigint,
  total_margin_rupees bigint,
  engineer_pct numeric,
  parts_pct numeric,
  travel_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(s.total_cost_rupees), 0) INTO v_total FROM public.service_cost_per_job_r2368 s;
  RETURN QUERY
  SELECT
    COUNT(*)::integer AS jobs_closed,
    COALESCE(SUM(s.engineer_cost_rupees), 0)::bigint,
    COALESCE(SUM(s.parts_cost_rupees), 0)::bigint,
    COALESCE(SUM(s.travel_cost_rupees), 0)::bigint,
    COALESCE(SUM(s.total_cost_rupees), 0)::bigint,
    COALESCE(SUM(s.invoice_amount_rupees), 0)::bigint,
    COALESCE(SUM(s.margin_rupees), 0)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE ROUND((COALESCE(SUM(s.engineer_cost_rupees), 0)::numeric / v_total::numeric) * 100, 2) END,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE ROUND((COALESCE(SUM(s.parts_cost_rupees), 0)::numeric / v_total::numeric) * 100, 2) END,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE ROUND((COALESCE(SUM(s.travel_cost_rupees), 0)::numeric / v_total::numeric) * 100, 2) END
  FROM public.service_cost_per_job_r2368 s;
END;
$$;

REVOKE ALL ON FUNCTION public.cost_breakdown_summary_r2368() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_breakdown_summary_r2368() TO authenticated;

-- 5) top loss-making jobs (negative margin)
DROP FUNCTION IF EXISTS public.top_loss_jobs_r2368(integer);
CREATE FUNCTION public.top_loss_jobs_r2368(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id uuid,
  repair_job_id uuid,
  hospital_email text,
  equipment_class text,
  total_cost_rupees integer,
  invoice_amount_rupees integer,
  margin_rupees integer,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.repair_job_id,
    hp.email AS hospital_email,
    s.equipment_class,
    s.total_cost_rupees,
    s.invoice_amount_rupees,
    s.margin_rupees,
    s.closed_at
  FROM public.service_cost_per_job_r2368 s
  LEFT JOIN public.profiles hp ON hp.id = s.hospital_user_id
  WHERE s.margin_rupees < 0
  ORDER BY s.margin_rupees ASC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.top_loss_jobs_r2368(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loss_jobs_r2368(integer) TO authenticated;

-- 6) monthly trend
DROP FUNCTION IF EXISTS public.cost_monthly_trend_r2368(integer);
CREATE FUNCTION public.cost_monthly_trend_r2368(p_months integer DEFAULT 12)
RETURNS TABLE (
  period_month date,
  jobs_closed integer,
  total_cost_rupees bigint,
  total_invoice_rupees bigint,
  total_margin_rupees bigint,
  avg_cost_per_job_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', s.closed_at)::date AS period_month,
    COUNT(*)::integer AS jobs_closed,
    COALESCE(SUM(s.total_cost_rupees), 0)::bigint,
    COALESCE(SUM(s.invoice_amount_rupees), 0)::bigint,
    COALESCE(SUM(s.margin_rupees), 0)::bigint,
    (COALESCE(SUM(s.total_cost_rupees), 0) / GREATEST(COUNT(*), 1))::integer
  FROM public.service_cost_per_job_r2368 s
  WHERE s.closed_at >= (now() - (GREATEST(p_months, 1) || ' months')::interval)
  GROUP BY date_trunc('month', s.closed_at)
  ORDER BY period_month DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.cost_monthly_trend_r2368(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cost_monthly_trend_r2368(integer) TO authenticated;

-- 7) record a cost row (founder seeds / corrects)
DROP FUNCTION IF EXISTS public.record_service_cost_r2368(uuid, uuid, uuid, text, integer, integer, integer, integer, integer, integer, text);
CREATE FUNCTION public.record_service_cost_r2368(
  p_repair_job_id uuid,
  p_hospital_user_id uuid,
  p_engineer_user_id uuid,
  p_equipment_class text,
  p_engineer_minutes integer,
  p_engineer_rate_per_hour_rupees integer,
  p_parts_cost_rupees integer,
  p_travel_km integer,
  p_travel_cost_rupees integer,
  p_invoice_amount_rupees integer,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_cost integer;
  v_total integer;
  v_margin integer;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_engineer_cost := ((COALESCE(p_engineer_minutes, 0) * COALESCE(p_engineer_rate_per_hour_rupees, 0)) / 60);
  v_total := v_engineer_cost + COALESCE(p_parts_cost_rupees, 0) + COALESCE(p_travel_cost_rupees, 0);
  v_margin := COALESCE(p_invoice_amount_rupees, 0) - v_total;

  INSERT INTO public.service_cost_per_job_r2368 (
    repair_job_id, hospital_user_id, engineer_user_id, equipment_class,
    engineer_minutes, engineer_rate_per_hour_rupees, engineer_cost_rupees,
    parts_cost_rupees, travel_km, travel_cost_rupees,
    total_cost_rupees, invoice_amount_rupees, margin_rupees, notes
  )
  VALUES (
    p_repair_job_id, p_hospital_user_id, p_engineer_user_id, p_equipment_class,
    COALESCE(p_engineer_minutes, 0), COALESCE(p_engineer_rate_per_hour_rupees, 0), v_engineer_cost,
    COALESCE(p_parts_cost_rupees, 0), COALESCE(p_travel_km, 0), COALESCE(p_travel_cost_rupees, 0),
    v_total, COALESCE(p_invoice_amount_rupees, 0), v_margin, p_notes
  )
  ON CONFLICT (repair_job_id) DO UPDATE
    SET hospital_user_id = EXCLUDED.hospital_user_id,
        engineer_user_id = EXCLUDED.engineer_user_id,
        equipment_class = EXCLUDED.equipment_class,
        engineer_minutes = EXCLUDED.engineer_minutes,
        engineer_rate_per_hour_rupees = EXCLUDED.engineer_rate_per_hour_rupees,
        engineer_cost_rupees = EXCLUDED.engineer_cost_rupees,
        parts_cost_rupees = EXCLUDED.parts_cost_rupees,
        travel_km = EXCLUDED.travel_km,
        travel_cost_rupees = EXCLUDED.travel_cost_rupees,
        total_cost_rupees = EXCLUDED.total_cost_rupees,
        invoice_amount_rupees = EXCLUDED.invoice_amount_rupees,
        margin_rupees = EXCLUDED.margin_rupees,
        notes = EXCLUDED.notes,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_service_cost_r2368(uuid, uuid, uuid, text, integer, integer, integer, integer, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_service_cost_r2368(uuid, uuid, uuid, text, integer, integer, integer, integer, integer, integer, text) TO authenticated;

COMMIT;
