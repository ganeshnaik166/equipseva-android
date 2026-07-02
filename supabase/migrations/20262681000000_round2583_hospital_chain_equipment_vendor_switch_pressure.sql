-- Round 2583: hospital-chain-equipment-vendor-switch-pressure
-- chain x vendor under pressure x switch signals x counter-strategy x decision risk

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_vendor_switch_pressure_r2583 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  vendor_under_pressure text NOT NULL,
  signal_kind text NOT NULL CHECK (signal_kind IN ('rfp_for_alternatives','competitor_pitch','exec_call_with_competitor','decreased_spend','contract_renegotiation')),
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','moderate','strong','confirmed')),
  counter_strategy_md text,
  decision_risk_kind text NOT NULL CHECK (decision_risk_kind IN ('low','medium','high','critical')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','escalated','saved','lost','dropped')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.switch_pressure_counter_actions_r2583 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  pressure_id uuid NOT NULL REFERENCES public.chain_vendor_switch_pressure_r2583(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('price_match','feature_demo','exec_lunch','free_audit','bonus_service')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text
);

ALTER TABLE public.chain_vendor_switch_pressure_r2583 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.switch_pressure_counter_actions_r2583 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_vendor_switch_pressure_r2583;
CREATE POLICY founder_all ON public.chain_vendor_switch_pressure_r2583
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.switch_pressure_counter_actions_r2583;
CREATE POLICY founder_all ON public.switch_pressure_counter_actions_r2583
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed pressures
INSERT INTO public.chain_vendor_switch_pressure_r2583 (chain_name, vendor_under_pressure, signal_kind, signal_strength, counter_strategy_md, decision_risk_kind, owner_email, status, notes) VALUES
  ('Apollo Hospitals','EquipSeva','rfp_for_alternatives','strong','Lead with NABH-ready uptime data + bundled AMC discount','high','ceo@equipseva.io','escalated','RFP closes in 14 days; need response by next Monday'),
  ('Yashoda Group','EquipSeva','competitor_pitch','moderate','Demo new tier-2 features to procurement head','medium','sales@equipseva.io','monitoring','Competitor offered 15 percent lower AMC pricing'),
  ('KIMS Network','EquipSeva','exec_call_with_competitor','confirmed','Founder visit + free chain-wide audit offer','critical','ceo@equipseva.io','escalated','CFO took meeting with Siemens last week'),
  ('Care Hospitals','EquipSeva','decreased_spend','weak','Review usage patterns; offer training','low','sales@equipseva.io','monitoring','Spend down 12 percent QoQ'),
  ('Continental Hospitals','EquipSeva','contract_renegotiation','strong','Lock multi-year with volume rebate','high','founder@equipseva.io','escalated','Asking for 20 percent discount on renewal');

INSERT INTO public.switch_pressure_counter_actions_r2583 (pressure_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'free_audit','positive','ceo@equipseva.io','done','Audit revealed 6 critical gaps competitor cannot address'
FROM public.chain_vendor_switch_pressure_r2583 WHERE chain_name='KIMS Network' LIMIT 1;

INSERT INTO public.switch_pressure_counter_actions_r2583 (pressure_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'price_match','pending','sales@equipseva.io','in_progress','Matched competitor AMC pricing for 18 months'
FROM public.chain_vendor_switch_pressure_r2583 WHERE chain_name='Yashoda Group' LIMIT 1;

INSERT INTO public.switch_pressure_counter_actions_r2583 (pressure_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'exec_lunch','neutral','founder@equipseva.io','done','Lunch with CFO; warm but non-committal'
FROM public.chain_vendor_switch_pressure_r2583 WHERE chain_name='Continental Hospitals' LIMIT 1;

-- RPC 1: list pressures
CREATE OR REPLACE FUNCTION public.list_switch_pressure_r2583()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  chain_name text,
  vendor_under_pressure text,
  signal_kind text,
  signal_strength text,
  decision_risk_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.created_at, p.chain_name, p.vendor_under_pressure,
           p.signal_kind, p.signal_strength, p.decision_risk_kind,
           p.owner_email, p.status, p.notes
      FROM public.chain_vendor_switch_pressure_r2583 p
     ORDER BY p.created_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_switch_pressure_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_switch_pressure_r2583() TO authenticated;

-- RPC 2: list counter actions
CREATE OR REPLACE FUNCTION public.list_counter_actions_r2583()
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  pressure_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.created_at, a.pressure_id, p.chain_name,
           a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes
      FROM public.switch_pressure_counter_actions_r2583 a
      JOIN public.chain_vendor_switch_pressure_r2583 p ON p.id = a.pressure_id
     ORDER BY a.action_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_counter_actions_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_counter_actions_r2583() TO authenticated;

-- RPC 3: top at-risk chains
CREATE OR REPLACE FUNCTION public.top_at_risk_chains_r2583()
RETURNS TABLE (
  chain_name text,
  pressure_count bigint,
  critical_count bigint,
  high_count bigint,
  escalated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.chain_name,
           count(*)::bigint AS pressure_count,
           count(*) FILTER (WHERE p.decision_risk_kind='critical')::bigint AS critical_count,
           count(*) FILTER (WHERE p.decision_risk_kind='high')::bigint AS high_count,
           count(*) FILTER (WHERE p.status='escalated')::bigint AS escalated_count
      FROM public.chain_vendor_switch_pressure_r2583 p
     GROUP BY p.chain_name
     ORDER BY critical_count DESC NULLS LAST, high_count DESC NULLS LAST, pressure_count DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_chains_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_chains_r2583() TO authenticated;

-- RPC 4: signal kind distribution
CREATE OR REPLACE FUNCTION public.signal_kind_distribution_r2583()
RETURNS TABLE (
  signal_kind text,
  pressure_count bigint,
  strong_or_confirmed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.signal_kind,
           count(*)::bigint AS pressure_count,
           count(*) FILTER (WHERE p.signal_strength IN ('strong','confirmed'))::bigint AS strong_or_confirmed
      FROM public.chain_vendor_switch_pressure_r2583 p
     GROUP BY p.signal_kind
     ORDER BY pressure_count DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.signal_kind_distribution_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signal_kind_distribution_r2583() TO authenticated;

-- RPC 5: counter kind summary
CREATE OR REPLACE FUNCTION public.counter_kind_summary_r2583()
RETURNS TABLE (
  action_kind text,
  action_count bigint,
  positive_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.action_kind,
           count(*)::bigint AS action_count,
           count(*) FILTER (WHERE a.outcome='positive')::bigint AS positive_count,
           count(*) FILTER (WHERE a.outcome='pending')::bigint AS pending_count
      FROM public.switch_pressure_counter_actions_r2583 a
     GROUP BY a.action_kind
     ORDER BY action_count DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.counter_kind_summary_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.counter_kind_summary_r2583() TO authenticated;

-- RPC 6: monthly pressure trend
CREATE OR REPLACE FUNCTION public.monthly_pressure_trend_r2583()
RETURNS TABLE (
  month_start timestamptz,
  pressure_count bigint,
  critical_count bigint,
  saved_count bigint,
  lost_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', p.created_at) AS month_start,
           count(*)::bigint AS pressure_count,
           count(*) FILTER (WHERE p.decision_risk_kind='critical')::bigint AS critical_count,
           count(*) FILTER (WHERE p.status='saved')::bigint AS saved_count,
           count(*) FILTER (WHERE p.status='lost')::bigint AS lost_count
      FROM public.chain_vendor_switch_pressure_r2583 p
     GROUP BY date_trunc('month', p.created_at)
     ORDER BY month_start DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_pressure_trend_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pressure_trend_r2583() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2583()
RETURNS TABLE (
  owner_email text,
  pressure_count bigint,
  escalated_count bigint,
  action_count bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(p.owner_email,'(unassigned)') AS owner_email,
           count(DISTINCT p.id)::bigint AS pressure_count,
           count(DISTINCT p.id) FILTER (WHERE p.status='escalated')::bigint AS escalated_count,
           count(a.id)::bigint AS action_count,
           count(a.id) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_actions
      FROM public.chain_vendor_switch_pressure_r2583 p
      LEFT JOIN public.switch_pressure_counter_actions_r2583 a ON a.pressure_id = p.id
     GROUP BY COALESCE(p.owner_email,'(unassigned)')
     ORDER BY pressure_count DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2583() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2583() TO authenticated;

