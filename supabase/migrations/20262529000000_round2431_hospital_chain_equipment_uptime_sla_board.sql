-- Round r2431: hospital-chain-equipment-uptime-sla-board
-- Track per-chain per-equipment uptime against SLA, penalties, credits owed

BEGIN;

-- ============================================================
-- Table 1: chain_equipment_uptime_r2431
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chain_equipment_uptime_r2431 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL CHECK (equipment_kind IN ('ventilator','dialysis','mri','ct','xray','ultrasound','ecg','monitor','infusion_pump','autoclave','other')),
  uptime_target_pct numeric(5,2) NOT NULL CHECK (uptime_target_pct >= 0 AND uptime_target_pct <= 100),
  actual_uptime_pct numeric(5,2) NOT NULL CHECK (actual_uptime_pct >= 0 AND actual_uptime_pct <= 100),
  sla_status text NOT NULL CHECK (sla_status IN ('on_target','at_risk','breach','severe_breach')),
  uptime_window_start date NOT NULL,
  uptime_window_end date NOT NULL,
  downtime_minutes int NOT NULL CHECK (downtime_minutes >= 0),
  slo_breaches int NOT NULL DEFAULT 0 CHECK (slo_breaches >= 0),
  penalty_rupees bigint NOT NULL DEFAULT 0 CHECK (penalty_rupees >= 0),
  credit_owed_rupees bigint NOT NULL DEFAULT 0 CHECK (credit_owed_rupees >= 0),
  notes text
);

ALTER TABLE public.chain_equipment_uptime_r2431 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_equipment_uptime_r2431;
CREATE POLICY founder_all ON public.chain_equipment_uptime_r2431
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: chain_sla_credits_owed_r2431
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chain_sla_credits_owed_r2431 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  credit_period_start date NOT NULL,
  credit_period_end date NOT NULL,
  total_credit_owed_rupees bigint NOT NULL DEFAULT 0 CHECK (total_credit_owed_rupees >= 0),
  total_credit_paid_rupees bigint NOT NULL DEFAULT 0 CHECK (total_credit_paid_rupees >= 0),
  balance_rupees bigint NOT NULL DEFAULT 0,
  payment_status text NOT NULL CHECK (payment_status IN ('pending','processing','paid','disputed')),
  payment_due_at timestamptz,
  payment_owner_email text,
  notes text
);

ALTER TABLE public.chain_sla_credits_owed_r2431 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_sla_credits_owed_r2431;
CREATE POLICY founder_all ON public.chain_sla_credits_owed_r2431
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_uptime_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.list_uptime_r2431();
CREATE OR REPLACE FUNCTION public.list_uptime_r2431()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  chain_name text,
  equipment_label text,
  equipment_kind text,
  uptime_target_pct numeric,
  actual_uptime_pct numeric,
  sla_status text,
  uptime_window_start date,
  uptime_window_end date,
  downtime_minutes int,
  slo_breaches int,
  penalty_rupees bigint,
  credit_owed_rupees bigint,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.id, u.created_at, u.chain_name, u.equipment_label, u.equipment_kind,
    u.uptime_target_pct, u.actual_uptime_pct, u.sla_status,
    u.uptime_window_start, u.uptime_window_end,
    u.downtime_minutes, u.slo_breaches, u.penalty_rupees, u.credit_owed_rupees, u.notes
  FROM public.chain_equipment_uptime_r2431 u
  ORDER BY
    CASE u.sla_status
      WHEN 'severe_breach' THEN 1
      WHEN 'breach' THEN 2
      WHEN 'at_risk' THEN 3
      WHEN 'on_target' THEN 4
      ELSE 5
    END,
    u.actual_uptime_pct ASC,
    u.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_uptime_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_uptime_r2431() TO authenticated;

-- ============================================================
-- RPC 2: list_credits_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.list_credits_r2431();
CREATE OR REPLACE FUNCTION public.list_credits_r2431()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  chain_name text,
  credit_period_start date,
  credit_period_end date,
  total_credit_owed_rupees bigint,
  total_credit_paid_rupees bigint,
  balance_rupees bigint,
  payment_status text,
  payment_due_at timestamptz,
  payment_owner_email text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id, c.created_at, c.chain_name,
    c.credit_period_start, c.credit_period_end,
    c.total_credit_owed_rupees, c.total_credit_paid_rupees, c.balance_rupees,
    c.payment_status, c.payment_due_at, c.payment_owner_email, c.notes
  FROM public.chain_sla_credits_owed_r2431 c
  ORDER BY
    CASE c.payment_status
      WHEN 'disputed' THEN 1
      WHEN 'pending' THEN 2
      WHEN 'processing' THEN 3
      WHEN 'paid' THEN 4
      ELSE 5
    END,
    c.balance_rupees DESC,
    c.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_credits_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_credits_r2431() TO authenticated;

-- ============================================================
-- RPC 3: sla_status_breakdown_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.sla_status_breakdown_r2431();
CREATE OR REPLACE FUNCTION public.sla_status_breakdown_r2431()
RETURNS TABLE (
  sla_status text,
  equipment_count bigint,
  total_downtime_minutes bigint,
  total_penalty_rupees bigint,
  total_credit_owed_rupees bigint,
  avg_actual_uptime_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.sla_status,
    COUNT(*)::bigint AS equipment_count,
    COALESCE(SUM(u.downtime_minutes),0)::bigint AS total_downtime_minutes,
    COALESCE(SUM(u.penalty_rupees),0)::bigint AS total_penalty_rupees,
    COALESCE(SUM(u.credit_owed_rupees),0)::bigint AS total_credit_owed_rupees,
    ROUND(AVG(u.actual_uptime_pct)::numeric, 2) AS avg_actual_uptime_pct
  FROM public.chain_equipment_uptime_r2431 u
  GROUP BY u.sla_status
  ORDER BY
    CASE u.sla_status
      WHEN 'severe_breach' THEN 1
      WHEN 'breach' THEN 2
      WHEN 'at_risk' THEN 3
      WHEN 'on_target' THEN 4
      ELSE 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.sla_status_breakdown_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sla_status_breakdown_r2431() TO authenticated;

-- ============================================================
-- RPC 4: top_at_risk_chains_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.top_at_risk_chains_r2431();
CREATE OR REPLACE FUNCTION public.top_at_risk_chains_r2431()
RETURNS TABLE (
  chain_name text,
  equipment_count bigint,
  breach_count bigint,
  severe_breach_count bigint,
  total_downtime_minutes bigint,
  total_penalty_rupees bigint,
  total_credit_owed_rupees bigint,
  avg_actual_uptime_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.chain_name,
    COUNT(*)::bigint AS equipment_count,
    COUNT(*) FILTER (WHERE u.sla_status = 'breach')::bigint AS breach_count,
    COUNT(*) FILTER (WHERE u.sla_status = 'severe_breach')::bigint AS severe_breach_count,
    COALESCE(SUM(u.downtime_minutes),0)::bigint AS total_downtime_minutes,
    COALESCE(SUM(u.penalty_rupees),0)::bigint AS total_penalty_rupees,
    COALESCE(SUM(u.credit_owed_rupees),0)::bigint AS total_credit_owed_rupees,
    ROUND(AVG(u.actual_uptime_pct)::numeric, 2) AS avg_actual_uptime_pct
  FROM public.chain_equipment_uptime_r2431 u
  GROUP BY u.chain_name
  ORDER BY
    severe_breach_count DESC,
    breach_count DESC,
    total_credit_owed_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_chains_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_chains_r2431() TO authenticated;

-- ============================================================
-- RPC 5: credit_balance_summary_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.credit_balance_summary_r2431();
CREATE OR REPLACE FUNCTION public.credit_balance_summary_r2431()
RETURNS TABLE (
  payment_status text,
  credit_count bigint,
  total_owed_rupees bigint,
  total_paid_rupees bigint,
  total_balance_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.payment_status,
    COUNT(*)::bigint AS credit_count,
    COALESCE(SUM(c.total_credit_owed_rupees),0)::bigint AS total_owed_rupees,
    COALESCE(SUM(c.total_credit_paid_rupees),0)::bigint AS total_paid_rupees,
    COALESCE(SUM(c.balance_rupees),0)::bigint AS total_balance_rupees
  FROM public.chain_sla_credits_owed_r2431 c
  GROUP BY c.payment_status
  ORDER BY
    CASE c.payment_status
      WHEN 'disputed' THEN 1
      WHEN 'pending' THEN 2
      WHEN 'processing' THEN 3
      WHEN 'paid' THEN 4
      ELSE 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.credit_balance_summary_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.credit_balance_summary_r2431() TO authenticated;

-- ============================================================
-- RPC 6: equipment_kind_summary_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.equipment_kind_summary_r2431();
CREATE OR REPLACE FUNCTION public.equipment_kind_summary_r2431()
RETURNS TABLE (
  equipment_kind text,
  equipment_count bigint,
  avg_actual_uptime_pct numeric,
  total_downtime_minutes bigint,
  total_penalty_rupees bigint,
  total_credit_owed_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.equipment_kind,
    COUNT(*)::bigint AS equipment_count,
    ROUND(AVG(u.actual_uptime_pct)::numeric, 2) AS avg_actual_uptime_pct,
    COALESCE(SUM(u.downtime_minutes),0)::bigint AS total_downtime_minutes,
    COALESCE(SUM(u.penalty_rupees),0)::bigint AS total_penalty_rupees,
    COALESCE(SUM(u.credit_owed_rupees),0)::bigint AS total_credit_owed_rupees
  FROM public.chain_equipment_uptime_r2431 u
  GROUP BY u.equipment_kind
  ORDER BY total_credit_owed_rupees DESC, equipment_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_summary_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_summary_r2431() TO authenticated;

-- ============================================================
-- RPC 7: weekly_uptime_trend_r2431
-- ============================================================
DROP FUNCTION IF EXISTS public.weekly_uptime_trend_r2431();
CREATE OR REPLACE FUNCTION public.weekly_uptime_trend_r2431()
RETURNS TABLE (
  week_start date,
  equipment_count bigint,
  avg_actual_uptime_pct numeric,
  total_downtime_minutes bigint,
  total_breaches bigint,
  total_credit_owed_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', u.uptime_window_start)::date AS week_start,
    COUNT(*)::bigint AS equipment_count,
    ROUND(AVG(u.actual_uptime_pct)::numeric, 2) AS avg_actual_uptime_pct,
    COALESCE(SUM(u.downtime_minutes),0)::bigint AS total_downtime_minutes,
    COUNT(*) FILTER (WHERE u.sla_status IN ('breach','severe_breach'))::bigint AS total_breaches,
    COALESCE(SUM(u.credit_owed_rupees),0)::bigint AS total_credit_owed_rupees
  FROM public.chain_equipment_uptime_r2431 u
  GROUP BY date_trunc('week', u.uptime_window_start)
  ORDER BY week_start DESC
  LIMIT 26;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_uptime_trend_r2431() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_uptime_trend_r2431() TO authenticated;

-- ============================================================
-- Seed rows
-- ============================================================
INSERT INTO public.chain_equipment_uptime_r2431 (
  chain_name, equipment_label, equipment_kind,
  uptime_target_pct, actual_uptime_pct, sla_status,
  uptime_window_start, uptime_window_end,
  downtime_minutes, slo_breaches, penalty_rupees, credit_owed_rupees, notes
) VALUES
  ('Apollo Hospitals Chain', 'Ventilator Block-A #07', 'ventilator',
    99.50, 99.78, 'on_target',
    '2026-06-09', '2026-06-15',
    132, 0, 0, 0, 'Within SLA; preventive maintenance scheduled.'),
  ('Yashoda Hospitals Chain', 'MRI 1.5T Banjara Hills', 'mri',
    99.00, 97.40, 'at_risk',
    '2026-06-09', '2026-06-15',
    2624, 2, 0, 45000, 'Coil intermittent fault; vendor RMA in progress.'),
  ('Care Hospitals Chain', 'Dialysis Bay-3 #12', 'dialysis',
    99.50, 95.20, 'breach',
    '2026-06-09', '2026-06-15',
    4838, 5, 75000, 225000, 'Membrane replacement delayed; SLA breach confirmed.'),
  ('KIMS Chain', 'CT 64-Slice Secunderabad', 'ct',
    99.50, 88.30, 'severe_breach',
    '2026-06-09', '2026-06-15',
    11716, 9, 250000, 600000, 'Tube failure; spare ETA 4 days; escalated to CXO.'),
  ('Continental Hospitals Chain', 'Infusion Pump Ward-5 #21', 'infusion_pump',
    99.00, 99.10, 'on_target',
    '2026-06-09', '2026-06-15',
    906, 1, 0, 0, 'Minor logged event; auto-recovered.');

INSERT INTO public.chain_sla_credits_owed_r2431 (
  chain_name, credit_period_start, credit_period_end,
  total_credit_owed_rupees, total_credit_paid_rupees, balance_rupees,
  payment_status, payment_due_at, payment_owner_email, notes
) VALUES
  ('Apollo Hospitals Chain', '2026-05-01', '2026-05-31',
    0, 0, 0,
    'paid', '2026-06-30 18:00:00+05:30', 'finance@equipseva.in',
    'No credits owed; chain on target.'),
  ('Yashoda Hospitals Chain', '2026-05-01', '2026-05-31',
    45000, 0, 45000,
    'pending', '2026-06-30 18:00:00+05:30', 'finance@equipseva.in',
    'Credit memo drafted; awaiting GST validation.'),
  ('Care Hospitals Chain', '2026-05-01', '2026-05-31',
    225000, 100000, 125000,
    'processing', '2026-06-30 18:00:00+05:30', 'finance@equipseva.in',
    'Partial offset against June invoice already applied.'),
  ('KIMS Chain', '2026-05-01', '2026-05-31',
    600000, 0, 600000,
    'disputed', '2026-06-30 18:00:00+05:30', 'finance@equipseva.in',
    'Chain disputes 2 of 9 breaches; dispute review with QA.'),
  ('Continental Hospitals Chain', '2026-05-01', '2026-05-31',
    0, 0, 0,
    'paid', '2026-06-30 18:00:00+05:30', 'finance@equipseva.in',
    'Within SLA; no credit memo issued.');

