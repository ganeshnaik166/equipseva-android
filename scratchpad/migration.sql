-- Round 2651: Hospital Chain Quarterly Revenue Leakage Audit

CREATE TABLE IF NOT EXISTS public.chain_revenue_leakage_r2651 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  leakage_kind text NOT NULL CHECK (leakage_kind IN ('missed_amc','wrong_pricing','missing_invoice','discount_unauthorized','scope_under_billed')),
  leakage_rupees bigint NOT NULL DEFAULT 0,
  root_cause_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.leakage_recovery_actions_r2651 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  leakage_id uuid NOT NULL REFERENCES public.chain_revenue_leakage_r2651(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('reissue_invoice','billing_correction','policy_change','process_fix','escalation')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_revenue_leakage_r2651 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leakage_recovery_actions_r2651 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_revenue_leakage_r2651;
CREATE POLICY founder_all ON public.chain_revenue_leakage_r2651
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.leakage_recovery_actions_r2651;
CREATE POLICY founder_all ON public.leakage_recovery_actions_r2651
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.chain_revenue_leakage_r2651 (chain_name, quarter_label, leakage_kind, leakage_rupees, root_cause_md, owner_email, status, notes) VALUES
('Apollo South Chain', 'Q1 FY27', 'missed_amc', 450000, 'Two ventilator AMCs lapsed and were not renewed on time', 'finance@equipseva.in', 'under_review', 'Recovery in progress with chain finance'),
('Medanta North', 'Q1 FY27', 'wrong_pricing', 180000, 'Old price list applied to new MRI service contract', 'ops@equipseva.in', 'open', 'Pricing variance flagged by audit'),
('Yashoda Mid Chain', 'Q1 FY27', 'missing_invoice', 95000, 'Three repair jobs closed without invoice generation', 'billing@equipseva.in', 'closed', 'Invoices reissued and paid'),
('KIMS Coastal', 'Q1 FY27', 'discount_unauthorized', 240000, 'Field engineer offered unauthorized loyalty discount', 'cfo@equipseva.in', 'open', 'Needs policy enforcement'),
('Manipal Highland', 'Q1 FY27', 'scope_under_billed', 320000, 'Add-on calibration scope billed at base rate', 'ops@equipseva.in', 'under_review', 'Scope adjustment letter being drafted')
ON CONFLICT DO NOTHING;

INSERT INTO public.leakage_recovery_actions_r2651 (leakage_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'reissue_invoice', 'positive', 'billing@equipseva.in', 'done', 'Reissued invoices accepted by chain'
FROM public.chain_revenue_leakage_r2651 WHERE chain_name = 'Yashoda Mid Chain' LIMIT 1;

INSERT INTO public.leakage_recovery_actions_r2651 (leakage_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'billing_correction', 'pending', 'ops@equipseva.in', 'open', 'Correction memo drafted'
FROM public.chain_revenue_leakage_r2651 WHERE chain_name = 'Medanta North' LIMIT 1;

INSERT INTO public.leakage_recovery_actions_r2651 (leakage_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'policy_change', 'neutral', 'cfo@equipseva.in', 'open', 'New discount approval gating in design'
FROM public.chain_revenue_leakage_r2651 WHERE chain_name = 'KIMS Coastal' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_leakage_r2651()
RETURNS SETOF public.chain_revenue_leakage_r2651
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.chain_revenue_leakage_r2651 ORDER BY created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_leakage_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_leakage_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2651()
RETURNS SETOF public.leakage_recovery_actions_r2651
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.leakage_recovery_actions_r2651 ORDER BY action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_leakage_focus_r2651()
RETURNS TABLE(chain_name text, quarter_label text, leakage_rupees bigint, leakage_kind text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.chain_name, l.quarter_label, l.leakage_rupees, l.leakage_kind, l.status
    FROM public.chain_revenue_leakage_r2651 l
    WHERE l.status IN ('open','under_review')
    ORDER BY l.leakage_rupees DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_leakage_focus_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_leakage_focus_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.leakage_kind_distribution_r2651()
RETURNS TABLE(leakage_kind text, leakage_count bigint, total_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.leakage_kind, COUNT(*)::bigint, COALESCE(SUM(l.leakage_rupees),0)::bigint
    FROM public.chain_revenue_leakage_r2651 l
    GROUP BY l.leakage_kind
    ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.leakage_kind_distribution_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leakage_kind_distribution_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2651()
RETURNS TABLE(status text, leakage_count bigint, total_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.status, COUNT(*)::bigint, COALESCE(SUM(l.leakage_rupees),0)::bigint
    FROM public.chain_revenue_leakage_r2651 l
    GROUP BY l.status
    ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_leakage_trend_r2651()
RETURNS TABLE(quarter_label text, leakage_count bigint, total_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.quarter_label, COUNT(*)::bigint, COALESCE(SUM(l.leakage_rupees),0)::bigint
    FROM public.chain_revenue_leakage_r2651 l
    GROUP BY l.quarter_label
    ORDER BY l.quarter_label;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_leakage_trend_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_leakage_trend_r2651() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_leakage_summary_r2651()
RETURNS TABLE(total_leakage_count bigint, total_rupees bigint, open_rupees bigint, recovered_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::bigint,
      COALESCE(SUM(l.leakage_rupees),0)::bigint,
      COALESCE(SUM(CASE WHEN l.status IN ('open','under_review') THEN l.leakage_rupees ELSE 0 END),0)::bigint,
      COALESCE(SUM(CASE WHEN l.status = 'closed' THEN l.leakage_rupees ELSE 0 END),0)::bigint
    FROM public.chain_revenue_leakage_r2651 l;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_leakage_summary_r2651() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_leakage_summary_r2651() TO authenticated;
