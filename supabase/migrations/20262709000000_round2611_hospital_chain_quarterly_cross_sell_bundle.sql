-- Round 2611: Hospital Chain Quarterly Cross-Sell Bundle
-- Tracks quarterly cross-sell bundles per hospital chain + attach log; founder-only.

CREATE TABLE IF NOT EXISTS public.chain_cross_sell_bundles_r2611 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  bundle_items_md text NOT NULL,
  bundle_value_rupees bigint NOT NULL DEFAULT 0,
  attach_rate_pct numeric NOT NULL DEFAULT 0,
  decision_kind text NOT NULL DEFAULT 'open' CHECK (decision_kind IN ('open','quoted','won','lost','dropped')),
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','archived')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.bundle_attach_log_r2611 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  bundle_id uuid NOT NULL REFERENCES public.chain_cross_sell_bundles_r2611(id) ON DELETE CASCADE,
  logged_at timestamptz NOT NULL DEFAULT now(),
  item_label text NOT NULL,
  attached boolean NOT NULL DEFAULT false,
  revenue_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.chain_cross_sell_bundles_r2611 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bundle_attach_log_r2611 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_cross_sell_bundles_r2611;
CREATE POLICY founder_all ON public.chain_cross_sell_bundles_r2611
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.bundle_attach_log_r2611;
CREATE POLICY founder_all ON public.bundle_attach_log_r2611
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.chain_cross_sell_bundles_r2611
  (chain_name, quarter_label, bundle_items_md, bundle_value_rupees, attach_rate_pct, decision_kind, owner_email, status, notes)
VALUES
  ('Apollo Hospitals', 'Q2-2026', '- Ventilator AMC tier-2\n- Spare parts vault subscription\n- Engineer training credits', 1850000, 72.5, 'won', 'sales1@equipseva.com', 'closed', 'Tier-2 chain locked AMC + vault combo'),
  ('Yashoda Hospitals', 'Q2-2026', '- ECG AMC tier-1\n- Calibration drive add-on\n- Quarterly audit pack', 1240000, 58.0, 'quoted', 'sales2@equipseva.com', 'active', 'Awaiting CFO sign-off on calibration drive'),
  ('Care Hospitals', 'Q3-2026', '- Anesthesia AMC tier-3\n- Spare parts express SLA\n- Hospital-side training', 2200000, 81.0, 'won', 'sales1@equipseva.com', 'closed', 'Express SLA pushed attach rate above 80'),
  ('KIMS Hospitals', 'Q3-2026', '- Defib AMC tier-2\n- Loaner pool access\n- Engineer dedicated shift', 960000, 44.0, 'lost', 'sales3@equipseva.com', 'closed', 'Competitor undercut on loaner pool'),
  ('Continental Hospitals', 'Q3-2026', '- Imaging AMC tier-3\n- Bonded parts top-up\n- Quarterly tech review', 1580000, 65.5, 'open', 'sales2@equipseva.com', 'active', 'CFO meeting scheduled next month');

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-05-15T09:00:00Z'::timestamptz, 'Ventilator AMC tier-2', true, 950000, 'sales1@equipseva.com', 'done', 'Signed master agreement'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-05-20T11:00:00Z'::timestamptz, 'Spare parts vault subscription', true, 600000, 'sales1@equipseva.com', 'done', 'Vault provisioned to Apollo Hyd'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-06-02T10:00:00Z'::timestamptz, 'Calibration drive add-on', false, 0, 'sales2@equipseva.com', 'open', 'Awaiting CFO sign-off'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'Yashoda Hospitals' LIMIT 1;

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-06-10T14:00:00Z'::timestamptz, 'Spare parts express SLA', true, 880000, 'sales1@equipseva.com', 'done', 'Express SLA active across 4 sites'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'Care Hospitals' LIMIT 1;

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-06-18T16:00:00Z'::timestamptz, 'Loaner pool access', false, 0, 'sales3@equipseva.com', 'dropped', 'Competitor priced lower'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'KIMS Hospitals' LIMIT 1;

INSERT INTO public.bundle_attach_log_r2611
  (bundle_id, logged_at, item_label, attached, revenue_rupees, owner_email, status, notes)
SELECT id, '2026-06-20T09:30:00Z'::timestamptz, 'Bonded parts top-up', true, 540000, 'sales2@equipseva.com', 'open', 'Top-up pending PO from Continental'
FROM public.chain_cross_sell_bundles_r2611 WHERE chain_name = 'Continental Hospitals' LIMIT 1;

-- RPC 1: list bundles
CREATE OR REPLACE FUNCTION public.list_bundles_r2611()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  bundle_items_md text,
  bundle_value_rupees bigint,
  attach_rate_pct numeric,
  decision_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.chain_name, b.quarter_label, b.bundle_items_md, b.bundle_value_rupees,
           b.attach_rate_pct, b.decision_kind, b.owner_email, b.status, b.notes
    FROM public.chain_cross_sell_bundles_r2611 b
    ORDER BY b.quarter_label DESC, b.attach_rate_pct DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_bundles_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bundles_r2611() TO authenticated;

-- RPC 2: list attach log
CREATE OR REPLACE FUNCTION public.list_attach_log_r2611()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  logged_at timestamptz,
  item_label text,
  attached boolean,
  revenue_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, b.chain_name, b.quarter_label, l.logged_at, l.item_label, l.attached,
           l.revenue_rupees, l.owner_email, l.status, l.notes
    FROM public.bundle_attach_log_r2611 l
    JOIN public.chain_cross_sell_bundles_r2611 b ON b.id = l.bundle_id
    ORDER BY l.logged_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_attach_log_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attach_log_r2611() TO authenticated;

-- RPC 3: top attach rate
CREATE OR REPLACE FUNCTION public.top_attach_rate_r2611()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  attach_rate_pct numeric,
  bundle_value_rupees bigint,
  decision_kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.chain_name, b.quarter_label, b.attach_rate_pct, b.bundle_value_rupees, b.decision_kind, b.status
    FROM public.chain_cross_sell_bundles_r2611 b
    ORDER BY b.attach_rate_pct DESC, b.bundle_value_rupees DESC
    LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_attach_rate_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_attach_rate_r2611() TO authenticated;

-- RPC 4: decision distribution
CREATE OR REPLACE FUNCTION public.decision_distribution_r2611()
RETURNS TABLE (
  decision_kind text,
  total_bundles int,
  total_value_rupees bigint,
  avg_attach_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.decision_kind,
           COUNT(*)::int AS total_bundles,
           COALESCE(SUM(b.bundle_value_rupees), 0)::bigint AS total_value_rupees,
           ROUND(COALESCE(AVG(b.attach_rate_pct), 0)::numeric, 2) AS avg_attach_rate
    FROM public.chain_cross_sell_bundles_r2611 b
    GROUP BY b.decision_kind
    ORDER BY total_bundles DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.decision_distribution_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_distribution_r2611() TO authenticated;

-- RPC 5: quarterly bundle trend
CREATE OR REPLACE FUNCTION public.quarterly_bundle_trend_r2611()
RETURNS TABLE (
  quarter_label text,
  total_bundles int,
  won_bundles int,
  total_value_rupees bigint,
  avg_attach_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.quarter_label,
           COUNT(*)::int AS total_bundles,
           SUM(CASE WHEN b.decision_kind = 'won' THEN 1 ELSE 0 END)::int AS won_bundles,
           COALESCE(SUM(b.bundle_value_rupees), 0)::bigint AS total_value_rupees,
           ROUND(COALESCE(AVG(b.attach_rate_pct), 0)::numeric, 2) AS avg_attach_rate
    FROM public.chain_cross_sell_bundles_r2611 b
    GROUP BY b.quarter_label
    ORDER BY b.quarter_label DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_bundle_trend_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_bundle_trend_r2611() TO authenticated;

-- RPC 6: total revenue summary
CREATE OR REPLACE FUNCTION public.total_revenue_summary_r2611()
RETURNS TABLE (
  metric_label text,
  metric_value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'total_bundles'::text, COUNT(*)::numeric FROM public.chain_cross_sell_bundles_r2611
    UNION ALL
    SELECT 'total_bundle_value_rupees'::text, COALESCE(SUM(bundle_value_rupees), 0)::numeric FROM public.chain_cross_sell_bundles_r2611
    UNION ALL
    SELECT 'attached_revenue_rupees'::text, COALESCE(SUM(revenue_rupees), 0)::numeric FROM public.bundle_attach_log_r2611 WHERE attached = true
    UNION ALL
    SELECT 'avg_attach_rate_pct'::text, COALESCE(ROUND(AVG(attach_rate_pct)::numeric, 2), 0) FROM public.chain_cross_sell_bundles_r2611
    UNION ALL
    SELECT 'won_count'::text, COUNT(*)::numeric FROM public.chain_cross_sell_bundles_r2611 WHERE decision_kind = 'won';
END;$$;
REVOKE EXECUTE ON FUNCTION public.total_revenue_summary_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_revenue_summary_r2611() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2611()
RETURNS TABLE (
  owner_email text,
  total_bundles int,
  won_bundles int,
  total_value_rupees bigint,
  avg_attach_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(b.owner_email, 'unassigned') AS owner_email,
           COUNT(*)::int AS total_bundles,
           SUM(CASE WHEN b.decision_kind = 'won' THEN 1 ELSE 0 END)::int AS won_bundles,
           COALESCE(SUM(b.bundle_value_rupees), 0)::bigint AS total_value_rupees,
           ROUND(COALESCE(AVG(b.attach_rate_pct), 0)::numeric, 2) AS avg_attach_rate
    FROM public.chain_cross_sell_bundles_r2611 b
    GROUP BY COALESCE(b.owner_email, 'unassigned')
    ORDER BY total_bundles DESC, owner_email ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2611() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2611() TO authenticated;
