-- Round 2513: Founder Weekly Sales Pipeline Pulse
-- Tracks weekly pipeline movement, stage breakdown, forecast accuracy,
-- deal-level commitments, stalled deals, and owner load.

-- ============================================================
-- TABLE 1: weekly pulse rollup per stage
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_weekly_pipeline_pulse_r2513 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  stage_kind text NOT NULL CHECK (stage_kind IN (
    'prospect','qualified','proposal','diligence','contract','closed_won','closed_lost'
  )),
  dollars_added_rupees bigint NOT NULL DEFAULT 0,
  dollars_closed_rupees bigint NOT NULL DEFAULT 0,
  stalled_count int NOT NULL DEFAULT 0,
  forecast_accuracy_pct int NOT NULL DEFAULT 0 CHECK (forecast_accuracy_pct BETWEEN 0 AND 100),
  commitment_rupees bigint NOT NULL DEFAULT 0,
  top_stalled_deal text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('green','amber','red')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwpp_r2513_week ON public.founder_weekly_pipeline_pulse_r2513(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fwpp_r2513_stage ON public.founder_weekly_pipeline_pulse_r2513(stage_kind);

ALTER TABLE public.founder_weekly_pipeline_pulse_r2513 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_weekly_pipeline_pulse_r2513;
CREATE POLICY founder_all ON public.founder_weekly_pipeline_pulse_r2513
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: deal-level commitments
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pipeline_deal_commitments_r2513 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  deal_name text NOT NULL,
  stage_kind text NOT NULL CHECK (stage_kind IN (
    'prospect','qualified','proposal','diligence','contract','closed_won','closed_lost'
  )),
  commitment_amount_rupees bigint NOT NULL DEFAULT 0,
  expected_close_at timestamptz,
  actual_close_at timestamptz,
  status text NOT NULL CHECK (status IN ('open','won','lost','pushed_out','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pdc_r2513_week ON public.pipeline_deal_commitments_r2513(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_pdc_r2513_status ON public.pipeline_deal_commitments_r2513(status);
CREATE INDEX IF NOT EXISTS idx_pdc_r2513_owner ON public.pipeline_deal_commitments_r2513(owner_email);

ALTER TABLE public.pipeline_deal_commitments_r2513 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pipeline_deal_commitments_r2513;
CREATE POLICY founder_all ON public.pipeline_deal_commitments_r2513
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEEDS
-- ============================================================
INSERT INTO public.founder_weekly_pipeline_pulse_r2513
  (week_start, stage_kind, dollars_added_rupees, dollars_closed_rupees, stalled_count,
   forecast_accuracy_pct, commitment_rupees, top_stalled_deal, owner_email, status, notes)
VALUES
  ('2026-06-15','prospect',     1200000,       0, 3, 65,  800000, 'Apollo Bengaluru CT scanner', 'sales1@equipseva.in', 'amber', 'Top of funnel healthy.'),
  ('2026-06-15','qualified',     900000,       0, 2, 72, 1500000, 'Manipal Vijayawada ultrasound', 'sales2@equipseva.in', 'green', 'Two RFPs in flight.'),
  ('2026-06-15','proposal',      600000,  200000, 4, 58, 2200000, 'Yashoda Hyderabad cathlab',   'sales1@equipseva.in', 'red',   'Proposal velocity slipping.'),
  ('2026-06-15','contract',      300000,  500000, 1, 81, 1100000, 'KIMS Secunderabad MRI',       'founder@equipseva.in', 'green', 'Contract redlines progressing.'),
  ('2026-06-15','closed_won',         0,  750000, 0, 92,       0, NULL,                          'founder@equipseva.in', 'green', 'Two deals closed this week.');

INSERT INTO public.pipeline_deal_commitments_r2513
  (week_start, deal_name, stage_kind, commitment_amount_rupees, expected_close_at, actual_close_at, status, owner_email, notes)
VALUES
  ('2026-06-15','Apollo Bengaluru CT scanner',    'qualified',  800000, '2026-07-31'::timestamptz, NULL,                       'open',         'sales1@equipseva.in', 'Budget cycle dependency.'),
  ('2026-06-15','Manipal Vijayawada ultrasound',  'proposal',  1500000, '2026-07-15'::timestamptz, NULL,                       'open',         'sales2@equipseva.in', 'Awaiting technical reply.'),
  ('2026-06-15','Yashoda Hyderabad cathlab',      'proposal',  2200000, '2026-06-30'::timestamptz, NULL,                       'pushed_out',   'sales1@equipseva.in', 'Pushed to Q3 by hospital CFO.'),
  ('2026-06-15','KIMS Secunderabad MRI',          'contract',  1100000, '2026-06-25'::timestamptz, NULL,                       'open',         'founder@equipseva.in', 'Final legal review.'),
  ('2026-06-15','Care Hospitals Banjara dental',  'closed_won', 750000, '2026-06-20'::timestamptz, '2026-06-19'::timestamptz, 'won',          'founder@equipseva.in', 'Closed under commitment.');

-- ============================================================
-- RPCs
-- ============================================================

-- 1) list_pulse_r2513: latest weekly pulse rows
CREATE OR REPLACE FUNCTION public.list_pulse_r2513()
RETURNS TABLE (
  id uuid,
  week_start date,
  stage_kind text,
  dollars_added_rupees bigint,
  dollars_closed_rupees bigint,
  stalled_count int,
  forecast_accuracy_pct int,
  commitment_rupees bigint,
  top_stalled_deal text,
  owner_email text,
  status text,
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
    SELECT p.id, p.week_start, p.stage_kind, p.dollars_added_rupees, p.dollars_closed_rupees,
           p.stalled_count, p.forecast_accuracy_pct, p.commitment_rupees, p.top_stalled_deal,
           p.owner_email, p.status, p.notes
    FROM public.founder_weekly_pipeline_pulse_r2513 p
    ORDER BY p.week_start DESC, p.stage_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pulse_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pulse_r2513() TO authenticated;

-- 2) list_commitments_r2513
CREATE OR REPLACE FUNCTION public.list_commitments_r2513()
RETURNS TABLE (
  id uuid,
  week_start date,
  deal_name text,
  stage_kind text,
  commitment_amount_rupees bigint,
  expected_close_at timestamptz,
  actual_close_at timestamptz,
  status text,
  owner_email text,
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
    SELECT c.id, c.week_start, c.deal_name, c.stage_kind, c.commitment_amount_rupees,
           c.expected_close_at, c.actual_close_at, c.status, c.owner_email, c.notes
    FROM public.pipeline_deal_commitments_r2513 c
    ORDER BY c.week_start DESC, c.commitment_amount_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_commitments_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_commitments_r2513() TO authenticated;

-- 3) weekly_pulse_trend_r2513: roll up by week
CREATE OR REPLACE FUNCTION public.weekly_pulse_trend_r2513()
RETURNS TABLE (
  week_start date,
  total_added_rupees bigint,
  total_closed_rupees bigint,
  total_stalled int,
  total_commitment_rupees bigint,
  avg_forecast_accuracy_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.week_start,
           SUM(p.dollars_added_rupees)::bigint AS total_added_rupees,
           SUM(p.dollars_closed_rupees)::bigint AS total_closed_rupees,
           SUM(p.stalled_count)::int AS total_stalled,
           SUM(p.commitment_rupees)::bigint AS total_commitment_rupees,
           ROUND(AVG(p.forecast_accuracy_pct)::numeric, 1) AS avg_forecast_accuracy_pct
    FROM public.founder_weekly_pipeline_pulse_r2513 p
    GROUP BY p.week_start
    ORDER BY p.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_pulse_trend_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_pulse_trend_r2513() TO authenticated;

-- 4) stage_breakdown_r2513: by stage across all weeks
CREATE OR REPLACE FUNCTION public.stage_breakdown_r2513()
RETURNS TABLE (
  stage_kind text,
  rows_count bigint,
  added_rupees bigint,
  closed_rupees bigint,
  stalled_total int,
  commitment_total_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.stage_kind,
           COUNT(*)::bigint AS rows_count,
           SUM(p.dollars_added_rupees)::bigint AS added_rupees,
           SUM(p.dollars_closed_rupees)::bigint AS closed_rupees,
           SUM(p.stalled_count)::int AS stalled_total,
           SUM(p.commitment_rupees)::bigint AS commitment_total_rupees
    FROM public.founder_weekly_pipeline_pulse_r2513 p
    GROUP BY p.stage_kind
    ORDER BY commitment_total_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.stage_breakdown_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_breakdown_r2513() TO authenticated;

-- 5) top_stalled_deals_r2513
CREATE OR REPLACE FUNCTION public.top_stalled_deals_r2513()
RETURNS TABLE (
  week_start date,
  stage_kind text,
  top_stalled_deal text,
  stalled_count int,
  owner_email text,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.week_start, p.stage_kind, p.top_stalled_deal, p.stalled_count, p.owner_email, p.status
    FROM public.founder_weekly_pipeline_pulse_r2513 p
    WHERE p.top_stalled_deal IS NOT NULL
    ORDER BY p.stalled_count DESC, p.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_stalled_deals_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_stalled_deals_r2513() TO authenticated;

-- 6) forecast_accuracy_summary_r2513
CREATE OR REPLACE FUNCTION public.forecast_accuracy_summary_r2513()
RETURNS TABLE (
  rows_count bigint,
  avg_accuracy_pct numeric,
  min_accuracy_pct int,
  max_accuracy_pct int,
  red_rows bigint,
  amber_rows bigint,
  green_rows bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint AS rows_count,
           ROUND(AVG(p.forecast_accuracy_pct)::numeric, 1) AS avg_accuracy_pct,
           MIN(p.forecast_accuracy_pct)::int AS min_accuracy_pct,
           MAX(p.forecast_accuracy_pct)::int AS max_accuracy_pct,
           COUNT(*) FILTER (WHERE p.status = 'red')::bigint AS red_rows,
           COUNT(*) FILTER (WHERE p.status = 'amber')::bigint AS amber_rows,
           COUNT(*) FILTER (WHERE p.status = 'green')::bigint AS green_rows
    FROM public.founder_weekly_pipeline_pulse_r2513 p;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.forecast_accuracy_summary_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.forecast_accuracy_summary_r2513() TO authenticated;

-- 7) owner_load_r2513: by owner, aggregate commitments + open deals
CREATE OR REPLACE FUNCTION public.owner_load_r2513()
RETURNS TABLE (
  owner_email text,
  open_deals bigint,
  total_commitment_rupees bigint,
  won_rupees bigint,
  lost_rupees bigint,
  pushed_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.owner_email,
           COUNT(*) FILTER (WHERE c.status = 'open')::bigint AS open_deals,
           SUM(c.commitment_amount_rupees)::bigint AS total_commitment_rupees,
           COALESCE(SUM(c.commitment_amount_rupees) FILTER (WHERE c.status = 'won'), 0)::bigint AS won_rupees,
           COALESCE(SUM(c.commitment_amount_rupees) FILTER (WHERE c.status = 'lost'), 0)::bigint AS lost_rupees,
           COUNT(*) FILTER (WHERE c.status = 'pushed_out')::bigint AS pushed_count
    FROM public.pipeline_deal_commitments_r2513 c
    WHERE c.owner_email IS NOT NULL
    GROUP BY c.owner_email
    ORDER BY total_commitment_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2513() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2513() TO authenticated;
