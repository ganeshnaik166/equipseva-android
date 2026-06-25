-- Round 2655: Hospital Chain Quarterly Procurement Velocity Tracker
-- Founder-only tracker for RFP-to-PO-to-Payment cycle times across chain customers,
-- plus acceleration actions to unblock slow chains.

-- ============================================================================
-- Table 1: chain_procurement_velocity_r2655
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chain_procurement_velocity_r2655 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  rfp_to_po_days integer NOT NULL DEFAULT 0,
  po_to_payment_days integer NOT NULL DEFAULT 0,
  total_cycle_days integer NOT NULL DEFAULT 0,
  velocity_kind text NOT NULL DEFAULT 'normal' CHECK (velocity_kind IN ('slow','normal','fast','blocked')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','improving','declining','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpv_r2655_quarter ON public.chain_procurement_velocity_r2655(quarter_label);
CREATE INDEX IF NOT EXISTS idx_cpv_r2655_kind ON public.chain_procurement_velocity_r2655(velocity_kind);
CREATE INDEX IF NOT EXISTS idx_cpv_r2655_status ON public.chain_procurement_velocity_r2655(status);

ALTER TABLE public.chain_procurement_velocity_r2655 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_procurement_velocity_r2655;
CREATE POLICY founder_all ON public.chain_procurement_velocity_r2655
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- Table 2: procurement_acceleration_actions_r2655
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.procurement_acceleration_actions_r2655 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.chain_procurement_velocity_r2655(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('automated_quote','exec_intro','legal_template','payment_advance','financing_help')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_paa_r2655_velocity ON public.procurement_acceleration_actions_r2655(velocity_id);
CREATE INDEX IF NOT EXISTS idx_paa_r2655_kind ON public.procurement_acceleration_actions_r2655(action_kind);
CREATE INDEX IF NOT EXISTS idx_paa_r2655_status ON public.procurement_acceleration_actions_r2655(status);

ALTER TABLE public.procurement_acceleration_actions_r2655 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.procurement_acceleration_actions_r2655;
CREATE POLICY founder_all ON public.procurement_acceleration_actions_r2655
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================
INSERT INTO public.chain_procurement_velocity_r2655
  (chain_name, quarter_label, rfp_to_po_days, po_to_payment_days, total_cycle_days, velocity_kind, owner_email, status, notes)
VALUES
  ('Apollo Hospitals Group', 'Q2 2026', 45, 35, 80, 'slow', 'ops@equipseva.com', 'improving', 'Long legal review at HQ. Templates helped.'),
  ('Manipal Health Enterprises', 'Q2 2026', 22, 18, 40, 'normal', 'sales@equipseva.com', 'monitoring', 'Standard procurement cadence holding steady.'),
  ('Fortis Healthcare', 'Q2 2026', 65, 50, 115, 'blocked', 'founder@equipseva.com', 'declining', 'CFO sign-off bottleneck. Need exec intro.'),
  ('Narayana Health', 'Q2 2026', 12, 8, 20, 'fast', 'ops@equipseva.com', 'improving', 'Centralized procurement. Reference account.'),
  ('Max Healthcare', 'Q2 2026', 30, 28, 58, 'normal', 'sales@equipseva.com', 'monitoring', 'Quarter-end push expected to compress cycle.');

INSERT INTO public.procurement_acceleration_actions_r2655
  (velocity_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'legal_template', 'positive', 'ops@equipseva.com', 'done', 'Provided pre-vetted master service agreement.'
FROM public.chain_procurement_velocity_r2655 WHERE chain_name = 'Apollo Hospitals Group' LIMIT 1;

INSERT INTO public.procurement_acceleration_actions_r2655
  (velocity_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'exec_intro', 'pending', 'founder@equipseva.com', 'open', 'Scheduled founder-to-CFO call next week.'
FROM public.chain_procurement_velocity_r2655 WHERE chain_name = 'Fortis Healthcare' LIMIT 1;

INSERT INTO public.procurement_acceleration_actions_r2655
  (velocity_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'financing_help', 'positive', 'ops@equipseva.com', 'done', 'Connected to NBFC for 60-day payment terms.'
FROM public.chain_procurement_velocity_r2655 WHERE chain_name = 'Max Healthcare' LIMIT 1;

-- ============================================================================
-- RPC 1: list_velocity_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_velocity_r2655()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  rfp_to_po_days integer,
  po_to_payment_days integer,
  total_cycle_days integer,
  velocity_kind text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.chain_name, v.quarter_label, v.rfp_to_po_days, v.po_to_payment_days,
         v.total_cycle_days, v.velocity_kind, v.owner_email, v.status, v.notes, v.created_at
  FROM public.chain_procurement_velocity_r2655 v
  ORDER BY v.total_cycle_days DESC, v.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_velocity_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_velocity_r2655() TO authenticated;

-- ============================================================================
-- RPC 2: list_acceleration_actions_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_acceleration_actions_r2655()
RETURNS TABLE (
  id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, v.chain_name, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.procurement_acceleration_actions_r2655 a
  JOIN public.chain_procurement_velocity_r2655 v ON v.id = a.velocity_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_acceleration_actions_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_acceleration_actions_r2655() TO authenticated;

-- ============================================================================
-- RPC 3: top_slow_focus_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_slow_focus_r2655()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  total_cycle_days integer,
  velocity_kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.chain_name, v.quarter_label, v.total_cycle_days, v.velocity_kind, v.status
  FROM public.chain_procurement_velocity_r2655 v
  WHERE v.velocity_kind IN ('slow','blocked')
  ORDER BY v.total_cycle_days DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_slow_focus_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_slow_focus_r2655() TO authenticated;

-- ============================================================================
-- RPC 4: velocity_kind_distribution_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.velocity_kind_distribution_r2655()
RETURNS TABLE (velocity_kind text, chain_count bigint, avg_cycle_days numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.velocity_kind, count(*)::bigint, round(avg(v.total_cycle_days)::numeric, 1)
  FROM public.chain_procurement_velocity_r2655 v
  GROUP BY v.velocity_kind
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.velocity_kind_distribution_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.velocity_kind_distribution_r2655() TO authenticated;

-- ============================================================================
-- RPC 5: status_funnel_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2655()
RETURNS TABLE (status text, chain_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.status, count(*)::bigint
  FROM public.chain_procurement_velocity_r2655 v
  GROUP BY v.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2655() TO authenticated;

-- ============================================================================
-- RPC 6: quarterly_velocity_trend_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.quarterly_velocity_trend_r2655()
RETURNS TABLE (quarter_label text, chain_count bigint, avg_rfp_to_po numeric, avg_po_to_payment numeric, avg_total_cycle numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.quarter_label,
         count(*)::bigint,
         round(avg(v.rfp_to_po_days)::numeric, 1),
         round(avg(v.po_to_payment_days)::numeric, 1),
         round(avg(v.total_cycle_days)::numeric, 1)
  FROM public.chain_procurement_velocity_r2655 v
  GROUP BY v.quarter_label
  ORDER BY v.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_velocity_trend_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_velocity_trend_r2655() TO authenticated;

-- ============================================================================
-- RPC 7: owner_load_r2655
-- ============================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2655()
RETURNS TABLE (owner_email text, chain_count bigint, slow_or_blocked bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(v.owner_email, 'unassigned') AS owner_email,
         count(*)::bigint,
         count(*) FILTER (WHERE v.velocity_kind IN ('slow','blocked'))::bigint
  FROM public.chain_procurement_velocity_r2655 v
  GROUP BY coalesce(v.owner_email, 'unassigned')
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2655() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2655() TO authenticated;
