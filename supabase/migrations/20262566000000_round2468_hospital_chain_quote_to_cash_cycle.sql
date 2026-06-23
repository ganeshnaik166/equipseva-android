-- Round 2468: hospital-chain-quote-to-cash-cycle
-- Two new tables + 7 founder-gated RPCs

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_quote_to_cash_cycles_r2468 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quote_external_ref text NOT NULL,
  quoted_at timestamptz NOT NULL,
  po_received_at timestamptz,
  invoice_issued_at timestamptz,
  cash_received_at timestamptz,
  days_quote_to_po int,
  days_po_to_invoice int,
  days_invoice_to_cash int,
  days_total int,
  bottleneck_stage text NOT NULL CHECK (bottleneck_stage IN ('quote','po','invoice','cash')),
  dso_impact_kind text NOT NULL CHECK (dso_impact_kind IN ('positive','neutral','negative')),
  value_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.chain_dso_snapshots_r2468 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  snapshot_date date NOT NULL,
  total_cycles int NOT NULL DEFAULT 0,
  avg_days_total numeric(10,2) NOT NULL DEFAULT 0,
  avg_dso_days numeric(10,2) NOT NULL DEFAULT 0,
  top_bottleneck_stage text,
  total_outstanding_rupees bigint NOT NULL DEFAULT 0,
  ar_aging_30d_rupees bigint NOT NULL DEFAULT 0,
  ar_aging_60d_rupees bigint NOT NULL DEFAULT 0,
  ar_aging_90d_plus_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('green','amber','red')),
  notes text
);

ALTER TABLE public.chain_quote_to_cash_cycles_r2468 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_dso_snapshots_r2468 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_quote_to_cash_cycles_r2468;
CREATE POLICY founder_all ON public.chain_quote_to_cash_cycles_r2468
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_dso_snapshots_r2468;
CREATE POLICY founder_all ON public.chain_dso_snapshots_r2468
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed cycles
INSERT INTO public.chain_quote_to_cash_cycles_r2468
  (chain_name, quote_external_ref, quoted_at, po_received_at, invoice_issued_at, cash_received_at,
   days_quote_to_po, days_po_to_invoice, days_invoice_to_cash, days_total,
   bottleneck_stage, dso_impact_kind, value_rupees, owner_email, notes)
VALUES
  ('Apollo Hospitals', 'Q-APL-2026-0117', '2026-05-01'::timestamptz, '2026-05-08'::timestamptz, '2026-05-12'::timestamptz, '2026-06-15'::timestamptz,
   7, 4, 34, 45, 'cash', 'negative', 4250000, 'finance@apollo.example', 'Cash leg slow; AP team backlog.'),
  ('Manipal Hospitals', 'Q-MAN-2026-0204', '2026-05-10'::timestamptz, '2026-05-13'::timestamptz, '2026-05-15'::timestamptz, '2026-06-05'::timestamptz,
   3, 2, 21, 26, 'cash', 'neutral', 1850000, 'ap@manipal.example', 'On standard 30d terms.'),
  ('Fortis Healthcare', 'Q-FOR-2026-0331', '2026-04-20'::timestamptz, '2026-05-15'::timestamptz, '2026-05-20'::timestamptz, '2026-06-18'::timestamptz,
   25, 5, 29, 59, 'quote', 'negative', 6700000, 'procurement@fortis.example', 'Quote sat 25 days in procurement.'),
  ('Yashoda Hospitals', 'Q-YSD-2026-0412', '2026-05-25'::timestamptz, '2026-05-27'::timestamptz, '2026-05-29'::timestamptz, '2026-06-08'::timestamptz,
   2, 2, 10, 14, 'invoice', 'positive', 920000, 'finance@yashoda.example', 'Fast turnaround; early-pay discount.'),
  ('KIMS Hospitals', 'Q-KIM-2026-0508', '2026-04-15'::timestamptz, '2026-04-30'::timestamptz, '2026-05-25'::timestamptz, NULL,
   15, 25, NULL, NULL, 'invoice', 'negative', 3200000, 'ar@kims.example', 'Invoice still unpaid past 30d.');

-- Seed DSO snapshots
INSERT INTO public.chain_dso_snapshots_r2468
  (chain_name, snapshot_date, total_cycles, avg_days_total, avg_dso_days, top_bottleneck_stage,
   total_outstanding_rupees, ar_aging_30d_rupees, ar_aging_60d_rupees, ar_aging_90d_plus_rupees, status, notes)
VALUES
  ('Apollo Hospitals', '2026-06-20', 14, 42.50, 38.20, 'cash', 8500000, 4200000, 3100000, 1200000, 'amber', 'Cash stage drag.'),
  ('Manipal Hospitals', '2026-06-20', 9, 28.10, 25.00, 'cash', 2400000, 2400000, 0, 0, 'green', 'Clean book.'),
  ('Fortis Healthcare', '2026-06-20', 11, 55.80, 49.40, 'quote', 12300000, 3300000, 5700000, 3300000, 'red', '90+ aging concerning.'),
  ('Yashoda Hospitals', '2026-06-20', 6, 18.20, 15.50, 'invoice', 1100000, 1100000, 0, 0, 'green', 'Early-pay culture.'),
  ('KIMS Hospitals', '2026-06-20', 8, 47.30, 44.10, 'invoice', 5400000, 1200000, 2800000, 1400000, 'amber', 'Invoice stage backlog.');

-- RPC 1: list cycles
CREATE OR REPLACE FUNCTION public.list_cycles_r2468()
RETURNS TABLE (
  id uuid, chain_name text, quote_external_ref text, quoted_at timestamptz,
  po_received_at timestamptz, invoice_issued_at timestamptz, cash_received_at timestamptz,
  days_total int, bottleneck_stage text, dso_impact_kind text, value_rupees bigint, owner_email text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.chain_name, c.quote_external_ref, c.quoted_at,
           c.po_received_at, c.invoice_issued_at, c.cash_received_at,
           c.days_total, c.bottleneck_stage, c.dso_impact_kind, c.value_rupees, c.owner_email, c.notes
    FROM public.chain_quote_to_cash_cycles_r2468 c
    ORDER BY c.quoted_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cycles_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cycles_r2468() TO authenticated;

-- RPC 2: list DSO snapshots
CREATE OR REPLACE FUNCTION public.list_dso_snapshots_r2468()
RETURNS TABLE (
  id uuid, chain_name text, snapshot_date date, total_cycles int,
  avg_days_total numeric, avg_dso_days numeric, top_bottleneck_stage text,
  total_outstanding_rupees bigint, ar_aging_30d_rupees bigint,
  ar_aging_60d_rupees bigint, ar_aging_90d_plus_rupees bigint, status text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.snapshot_date, s.total_cycles,
           s.avg_days_total, s.avg_dso_days, s.top_bottleneck_stage,
           s.total_outstanding_rupees, s.ar_aging_30d_rupees,
           s.ar_aging_60d_rupees, s.ar_aging_90d_plus_rupees, s.status, s.notes
    FROM public.chain_dso_snapshots_r2468 s
    ORDER BY s.snapshot_date DESC, s.chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_dso_snapshots_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dso_snapshots_r2468() TO authenticated;

-- RPC 3: top slow cycles
CREATE OR REPLACE FUNCTION public.top_slow_cycles_r2468()
RETURNS TABLE (
  id uuid, chain_name text, quote_external_ref text, days_total int,
  bottleneck_stage text, value_rupees bigint, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.chain_name, c.quote_external_ref, c.days_total,
           c.bottleneck_stage, c.value_rupees, c.owner_email
    FROM public.chain_quote_to_cash_cycles_r2468 c
    WHERE c.days_total IS NOT NULL
    ORDER BY c.days_total DESC NULLS LAST
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_slow_cycles_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_slow_cycles_r2468() TO authenticated;

-- RPC 4: bottleneck breakdown
CREATE OR REPLACE FUNCTION public.bottleneck_breakdown_r2468()
RETURNS TABLE (
  bottleneck_stage text, cycles_count bigint, avg_days numeric, total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.bottleneck_stage,
           COUNT(*)::bigint AS cycles_count,
           COALESCE(AVG(c.days_total), 0)::numeric AS avg_days,
           COALESCE(SUM(c.value_rupees), 0)::bigint AS total_value_rupees
    FROM public.chain_quote_to_cash_cycles_r2468 c
    GROUP BY c.bottleneck_stage
    ORDER BY cycles_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bottleneck_breakdown_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bottleneck_breakdown_r2468() TO authenticated;

-- RPC 5: top chains by DSO
CREATE OR REPLACE FUNCTION public.top_chains_by_dso_r2468()
RETURNS TABLE (
  chain_name text, avg_dso_days numeric, total_outstanding_rupees bigint,
  ar_aging_90d_plus_rupees bigint, status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.avg_dso_days, s.total_outstanding_rupees,
           s.ar_aging_90d_plus_rupees, s.status
    FROM public.chain_dso_snapshots_r2468 s
    WHERE s.snapshot_date = (SELECT MAX(snapshot_date) FROM public.chain_dso_snapshots_r2468)
    ORDER BY s.avg_dso_days DESC NULLS LAST
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_dso_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_chains_by_dso_r2468() TO authenticated;

-- RPC 6: monthly DSO trend
CREATE OR REPLACE FUNCTION public.monthly_dso_trend_r2468()
RETURNS TABLE (
  month_start date, snapshot_count bigint, avg_dso numeric, avg_outstanding numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', s.snapshot_date)::date AS month_start,
           COUNT(*)::bigint AS snapshot_count,
           COALESCE(AVG(s.avg_dso_days), 0)::numeric AS avg_dso,
           COALESCE(AVG(s.total_outstanding_rupees), 0)::numeric AS avg_outstanding
    FROM public.chain_dso_snapshots_r2468 s
    GROUP BY date_trunc('month', s.snapshot_date)
    ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_dso_trend_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_dso_trend_r2468() TO authenticated;

-- RPC 7: outstanding AR focus
CREATE OR REPLACE FUNCTION public.outstanding_ar_focus_r2468()
RETURNS TABLE (
  chain_name text, total_outstanding_rupees bigint, ar_aging_30d_rupees bigint,
  ar_aging_60d_rupees bigint, ar_aging_90d_plus_rupees bigint,
  pct_90d_plus numeric, status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.total_outstanding_rupees, s.ar_aging_30d_rupees,
           s.ar_aging_60d_rupees, s.ar_aging_90d_plus_rupees,
           CASE WHEN s.total_outstanding_rupees > 0
                THEN (s.ar_aging_90d_plus_rupees::numeric * 100.0 / s.total_outstanding_rupees::numeric)
                ELSE 0::numeric END AS pct_90d_plus,
           s.status
    FROM public.chain_dso_snapshots_r2468 s
    WHERE s.snapshot_date = (SELECT MAX(snapshot_date) FROM public.chain_dso_snapshots_r2468)
    ORDER BY s.ar_aging_90d_plus_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.outstanding_ar_focus_r2468() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outstanding_ar_focus_r2468() TO authenticated;

