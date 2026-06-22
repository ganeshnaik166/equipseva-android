BEGIN;

-- Round 2268: Customer revenue mix shifter
-- Tracks how revenue mix shifts each quarter across AMC / Repair / Parts / Install streams
-- to inform strategic resource allocation and customer concentration decisions.

CREATE TABLE IF NOT EXISTS public.customer_revenue_mix_snapshots_r2268 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid NOT NULL,
  customer_name text NOT NULL,
  quarter_label text NOT NULL,
  quarter_start_date date NOT NULL,
  amc_revenue_rupees bigint NOT NULL DEFAULT 0,
  repair_revenue_rupees bigint NOT NULL DEFAULT 0,
  parts_revenue_rupees bigint NOT NULL DEFAULT 0,
  install_revenue_rupees bigint NOT NULL DEFAULT 0,
  total_revenue_rupees bigint NOT NULL DEFAULT 0,
  amc_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  repair_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  parts_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  install_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  dominant_stream text NOT NULL CHECK (dominant_stream IN ('amc','repair','parts','install','balanced')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  UNIQUE (customer_org_id, quarter_start_date)
);

CREATE TABLE IF NOT EXISTS public.customer_revenue_mix_shift_signals_r2268 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid NOT NULL,
  customer_name text NOT NULL,
  from_quarter text NOT NULL,
  to_quarter text NOT NULL,
  shift_type text NOT NULL CHECK (shift_type IN ('amc_growth','amc_decline','repair_spike','parts_concentration','install_surge','balance_lost','balance_gained')),
  delta_pct numeric(6,2) NOT NULL,
  strategic_implication text NOT NULL,
  recommended_action text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','watch','act_now')),
  acknowledged_by uuid REFERENCES public.profiles(id),
  acknowledged_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_revenue_mix_snapshots_r2268 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_revenue_mix_shift_signals_r2268 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_revenue_mix_snapshots_r2268;
CREATE POLICY founder_all ON public.customer_revenue_mix_snapshots_r2268
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_revenue_mix_shift_signals_r2268;
CREATE POLICY founder_all ON public.customer_revenue_mix_shift_signals_r2268
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_revmix_snap_quarter_r2268 ON public.customer_revenue_mix_snapshots_r2268(quarter_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_revmix_snap_cust_r2268 ON public.customer_revenue_mix_snapshots_r2268(customer_org_id);
CREATE INDEX IF NOT EXISTS idx_revmix_signal_cust_r2268 ON public.customer_revenue_mix_shift_signals_r2268(customer_org_id);
CREATE INDEX IF NOT EXISTS idx_revmix_signal_severity_r2268 ON public.customer_revenue_mix_shift_signals_r2268(severity);

-- RPC 1: snapshot summary
DROP FUNCTION IF EXISTS public.founder_revmix_snapshot_summary_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_snapshot_summary_r2268()
RETURNS TABLE (
  total_snapshots int,
  total_customers int,
  total_quarters int,
  latest_quarter text,
  total_revenue_tracked_rupees bigint,
  avg_amc_share_pct numeric,
  avg_repair_share_pct numeric,
  avg_parts_share_pct numeric,
  avg_install_share_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_snapshots,
    (COUNT(DISTINCT customer_org_id))::int AS total_customers,
    (COUNT(DISTINCT quarter_label))::int AS total_quarters,
    (SELECT quarter_label FROM public.customer_revenue_mix_snapshots_r2268 ORDER BY quarter_start_date DESC LIMIT 1) AS latest_quarter,
    COALESCE(SUM(total_revenue_rupees),0)::bigint AS total_revenue_tracked_rupees,
    COALESCE(ROUND(AVG(amc_share_pct),2),0) AS avg_amc_share_pct,
    COALESCE(ROUND(AVG(repair_share_pct),2),0) AS avg_repair_share_pct,
    COALESCE(ROUND(AVG(parts_share_pct),2),0) AS avg_parts_share_pct,
    COALESCE(ROUND(AVG(install_share_pct),2),0) AS avg_install_share_pct
  FROM public.customer_revenue_mix_snapshots_r2268;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_snapshot_summary_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_snapshot_summary_r2268() TO authenticated;

-- RPC 2: mix by quarter
DROP FUNCTION IF EXISTS public.founder_revmix_by_quarter_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_by_quarter_r2268()
RETURNS TABLE (
  quarter_label text,
  customers int,
  total_revenue_rupees bigint,
  amc_share_pct numeric,
  repair_share_pct numeric,
  parts_share_pct numeric,
  install_share_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.quarter_label,
    (COUNT(DISTINCT s.customer_org_id))::int AS customers,
    COALESCE(SUM(s.total_revenue_rupees),0)::bigint AS total_revenue_rupees,
    ROUND(COALESCE(SUM(s.amc_revenue_rupees)::numeric / NULLIF(SUM(s.total_revenue_rupees),0) * 100,0),2) AS amc_share_pct,
    ROUND(COALESCE(SUM(s.repair_revenue_rupees)::numeric / NULLIF(SUM(s.total_revenue_rupees),0) * 100,0),2) AS repair_share_pct,
    ROUND(COALESCE(SUM(s.parts_revenue_rupees)::numeric / NULLIF(SUM(s.total_revenue_rupees),0) * 100,0),2) AS parts_share_pct,
    ROUND(COALESCE(SUM(s.install_revenue_rupees)::numeric / NULLIF(SUM(s.total_revenue_rupees),0) * 100,0),2) AS install_share_pct
  FROM public.customer_revenue_mix_snapshots_r2268 s
  GROUP BY s.quarter_label, s.quarter_start_date
  ORDER BY s.quarter_start_date DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_by_quarter_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_by_quarter_r2268() TO authenticated;

-- RPC 3: top customers by total revenue tracked
DROP FUNCTION IF EXISTS public.founder_revmix_top_customers_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_top_customers_r2268()
RETURNS TABLE (
  customer_name text,
  customer_org_id uuid,
  quarters_tracked int,
  total_revenue_rupees bigint,
  avg_amc_share_pct numeric,
  avg_repair_share_pct numeric,
  avg_parts_share_pct numeric,
  avg_install_share_pct numeric,
  dominant_stream_latest text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.customer_name,
    s.customer_org_id,
    (COUNT(*))::int AS quarters_tracked,
    COALESCE(SUM(s.total_revenue_rupees),0)::bigint AS total_revenue_rupees,
    ROUND(AVG(s.amc_share_pct),2) AS avg_amc_share_pct,
    ROUND(AVG(s.repair_share_pct),2) AS avg_repair_share_pct,
    ROUND(AVG(s.parts_share_pct),2) AS avg_parts_share_pct,
    ROUND(AVG(s.install_share_pct),2) AS avg_install_share_pct,
    (SELECT s2.dominant_stream FROM public.customer_revenue_mix_snapshots_r2268 s2
       WHERE s2.customer_org_id = s.customer_org_id
       ORDER BY s2.quarter_start_date DESC LIMIT 1) AS dominant_stream_latest
  FROM public.customer_revenue_mix_snapshots_r2268 s
  GROUP BY s.customer_org_id, s.customer_name
  ORDER BY SUM(s.total_revenue_rupees) DESC
  LIMIT 20;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_top_customers_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_top_customers_r2268() TO authenticated;

-- RPC 4: shift signals
DROP FUNCTION IF EXISTS public.founder_revmix_shift_signals_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_shift_signals_r2268()
RETURNS TABLE (
  customer_name text,
  from_quarter text,
  to_quarter text,
  shift_type text,
  delta_pct numeric,
  severity text,
  strategic_implication text,
  recommended_action text,
  acknowledged boolean,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.customer_name,
    g.from_quarter,
    g.to_quarter,
    g.shift_type,
    g.delta_pct,
    g.severity,
    g.strategic_implication,
    g.recommended_action,
    (g.acknowledged_at IS NOT NULL) AS acknowledged,
    g.created_at
  FROM public.customer_revenue_mix_shift_signals_r2268 g
  ORDER BY
    CASE g.severity WHEN 'act_now' THEN 1 WHEN 'watch' THEN 2 ELSE 3 END,
    g.created_at DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_shift_signals_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_shift_signals_r2268() TO authenticated;

-- RPC 5: signal counts by severity
DROP FUNCTION IF EXISTS public.founder_revmix_signal_counts_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_signal_counts_r2268()
RETURNS TABLE (
  total_signals int,
  act_now_count int,
  watch_count int,
  info_count int,
  acknowledged_count int,
  pending_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_signals,
    (COUNT(*) FILTER (WHERE severity = 'act_now'))::int AS act_now_count,
    (COUNT(*) FILTER (WHERE severity = 'watch'))::int AS watch_count,
    (COUNT(*) FILTER (WHERE severity = 'info'))::int AS info_count,
    (COUNT(*) FILTER (WHERE acknowledged_at IS NOT NULL))::int AS acknowledged_count,
    (COUNT(*) FILTER (WHERE acknowledged_at IS NULL))::int AS pending_count
  FROM public.customer_revenue_mix_shift_signals_r2268;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_signal_counts_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_signal_counts_r2268() TO authenticated;

-- RPC 6: dominant stream distribution
DROP FUNCTION IF EXISTS public.founder_revmix_dominant_distribution_r2268();
CREATE OR REPLACE FUNCTION public.founder_revmix_dominant_distribution_r2268()
RETURNS TABLE (
  dominant_stream text,
  snapshots int,
  customers int,
  revenue_rupees bigint,
  share_of_total_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total_rev bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(total_revenue_rupees),0) INTO total_rev FROM public.customer_revenue_mix_snapshots_r2268;
  RETURN QUERY
  SELECT
    s.dominant_stream,
    (COUNT(*))::int AS snapshots,
    (COUNT(DISTINCT s.customer_org_id))::int AS customers,
    COALESCE(SUM(s.total_revenue_rupees),0)::bigint AS revenue_rupees,
    ROUND(COALESCE(SUM(s.total_revenue_rupees)::numeric / NULLIF(total_rev,0) * 100,0),2) AS share_of_total_pct
  FROM public.customer_revenue_mix_snapshots_r2268 s
  GROUP BY s.dominant_stream
  ORDER BY revenue_rupees DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_dominant_distribution_r2268() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_dominant_distribution_r2268() TO authenticated;

-- RPC 7: acknowledge signal
DROP FUNCTION IF EXISTS public.founder_revmix_acknowledge_signal_r2268(uuid);
CREATE OR REPLACE FUNCTION public.founder_revmix_acknowledge_signal_r2268(p_signal_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_uid FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  UPDATE public.customer_revenue_mix_shift_signals_r2268
    SET acknowledged_by = v_uid, acknowledged_at = now()
    WHERE id = p_signal_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_revmix_acknowledge_signal_r2268(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revmix_acknowledge_signal_r2268(uuid) TO authenticated;

-- Seed
INSERT INTO public.customer_revenue_mix_snapshots_r2268
  (customer_org_id, customer_name, quarter_label, quarter_start_date,
   amc_revenue_rupees, repair_revenue_rupees, parts_revenue_rupees, install_revenue_rupees,
   total_revenue_rupees, amc_share_pct, repair_share_pct, parts_share_pct, install_share_pct,
   dominant_stream, notes)
VALUES
  (gen_random_uuid(), 'Apollo Hospitals Hyderabad', 'Q1-2026', '2026-01-01', 850000, 420000, 180000, 600000, 2050000, 41.46, 20.49, 8.78, 29.27, 'amc', 'Install-heavy from new wing'),
  (gen_random_uuid(), 'Apollo Hospitals Hyderabad', 'Q2-2026', '2026-04-01', 920000, 510000, 240000, 80000, 1750000, 52.57, 29.14, 13.71, 4.57, 'amc', 'Install tapered, repair rising'),
  (gen_random_uuid(), 'KIMS Secunderabad', 'Q1-2026', '2026-01-01', 380000, 720000, 410000, 0, 1510000, 25.17, 47.68, 27.15, 0.00, 'repair', 'Heavy break-fix mode'),
  (gen_random_uuid(), 'KIMS Secunderabad', 'Q2-2026', '2026-04-01', 410000, 690000, 380000, 0, 1480000, 27.70, 46.62, 25.68, 0.00, 'repair', 'Repair-dominant continues'),
  (gen_random_uuid(), 'Yashoda Hospitals', 'Q1-2026', '2026-01-01', 1200000, 280000, 90000, 150000, 1720000, 69.77, 16.28, 5.23, 8.72, 'amc', 'Healthy AMC-led mix'),
  (gen_random_uuid(), 'Yashoda Hospitals', 'Q2-2026', '2026-04-01', 1340000, 310000, 110000, 0, 1760000, 76.14, 17.61, 6.25, 0.00, 'amc', 'AMC share growing'),
  (gen_random_uuid(), 'Care Hospitals Banjara Hills', 'Q1-2026', '2026-01-01', 240000, 180000, 920000, 0, 1340000, 17.91, 13.43, 68.66, 0.00, 'parts', 'Parts-heavy — concentration risk'),
  (gen_random_uuid(), 'Care Hospitals Banjara Hills', 'Q2-2026', '2026-04-01', 260000, 195000, 1080000, 0, 1535000, 16.94, 12.70, 70.36, 0.00, 'parts', 'Parts dependency deepening'),
  (gen_random_uuid(), 'Continental Hospitals', 'Q1-2026', '2026-01-01', 540000, 380000, 220000, 980000, 2120000, 25.47, 17.92, 10.38, 46.23, 'install', 'New facility install phase'),
  (gen_random_uuid(), 'Continental Hospitals', 'Q2-2026', '2026-04-01', 720000, 410000, 240000, 120000, 1490000, 48.32, 27.52, 16.11, 8.05, 'amc', 'Install rolled off, AMC took over')
ON CONFLICT (customer_org_id, quarter_start_date) DO NOTHING;

INSERT INTO public.customer_revenue_mix_shift_signals_r2268
  (customer_org_id, customer_name, from_quarter, to_quarter, shift_type, delta_pct, strategic_implication, recommended_action, severity)
VALUES
  (gen_random_uuid(), 'Care Hospitals Banjara Hills', 'Q1-2026', 'Q2-2026', 'parts_concentration', 1.70, 'Parts share above 70 percent signals captive replacement-part dependency rather than service relationship', 'Pitch full-coverage AMC bundle to convert parts spend into recurring revenue', 'act_now'),
  (gen_random_uuid(), 'Continental Hospitals', 'Q1-2026', 'Q2-2026', 'amc_growth', 22.85, 'Post-install AMC conversion successful, customer entered steady-state recurring mode', 'Use as reference case for other install-phase customers in pipeline', 'info'),
  (gen_random_uuid(), 'KIMS Secunderabad', 'Q1-2026', 'Q2-2026', 'balance_lost', 1.06, 'Repair-dominant mix persists for two quarters, customer treats us as break-fix vendor not partner', 'Schedule QBR with biomed head, propose AMC pilot on top 5 critical assets', 'watch'),
  (gen_random_uuid(), 'Apollo Hospitals Hyderabad', 'Q1-2026', 'Q2-2026', 'install_surge', -24.70, 'Install revenue dropped post-wing-commission, expected lifecycle pattern', 'Forecast next install wave, smooth revenue with AMC upsell on commissioned assets', 'info'),
  (gen_random_uuid(), 'Yashoda Hospitals', 'Q1-2026', 'Q2-2026', 'amc_growth', 6.37, 'AMC share grew despite zero install activity, indicating organic deepening of recurring relationship', 'Pursue multi-year AMC lock-in with discount to defend the account', 'info'),
  (gen_random_uuid(), 'Apollo Hospitals Hyderabad', 'Q1-2026', 'Q2-2026', 'repair_spike', 8.65, 'Repair share rising alongside falling install, may indicate quality issues on commissioned units', 'Trigger 90-day post-install audit on Apollo wing assets', 'watch');

COMMIT;
