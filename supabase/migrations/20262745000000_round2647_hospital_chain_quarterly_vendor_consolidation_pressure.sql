-- r2647 hospital chain quarterly vendor consolidation pressure

CREATE TABLE IF NOT EXISTS public.chain_consolidation_pressure_r2647 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  vendor_count_today int NOT NULL DEFAULT 0,
  target_vendor_count int NOT NULL DEFAULT 0,
  our_threat_kind text NOT NULL CHECK (our_threat_kind IN ('reduced','eliminated','expanded','stable')),
  counter_strategy_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('monitoring','escalated','resolved','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consolidation_counter_actions_r2647 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pressure_id uuid NOT NULL REFERENCES public.chain_consolidation_pressure_r2647(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('price_match','bundle_offer','exec_pitch','feature_demo','multi_year_lock')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_consolidation_pressure_r2647 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consolidation_counter_actions_r2647 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_consolidation_pressure_r2647;
CREATE POLICY founder_all ON public.chain_consolidation_pressure_r2647
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.consolidation_counter_actions_r2647;
CREATE POLICY founder_all ON public.consolidation_counter_actions_r2647
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_consolidation_pressure_r2647
  (chain_name, quarter_label, vendor_count_today, target_vendor_count, our_threat_kind, counter_strategy_md, owner_email, status, notes)
VALUES
  ('Apollo Group', '2026-Q1', 14, 6, 'reduced', 'Lock in 3 year master contract with bundle pricing across 9 sites; pitch consolidation savings of 18 percent', 'founder@equipseva.in', 'escalated', 'Procurement RFP closes August 15; high stakes'),
  ('Manipal Hospitals', '2026-Q1', 9, 4, 'eliminated', 'Build case study showing single vendor uptime advantage; pitch CFO directly on opex reduction', 'founder@equipseva.in', 'monitoring', 'CFO meeting booked for July 12'),
  ('Fortis Healthcare', '2026-Q2', 11, 5, 'stable', 'Defend slot by pre-empting RFP with multi year lock at 92 percent of current pricing', 'founder@equipseva.in', 'monitoring', 'No immediate threat but quarterly review approaching'),
  ('Yashoda Hospitals', '2026-Q2', 7, 7, 'expanded', 'Opportunity to add ventilator and dialysis categories to existing contract', 'founder@equipseva.in', 'monitoring', 'Bullish signal; expanding vendor list not shrinking'),
  ('Aster DM Healthcare', '2026-Q2', 12, 5, 'reduced', 'Risk of being dropped; deploy exec pitch and feature demo blitz over next 6 weeks', 'founder@equipseva.in', 'escalated', 'Critical defense quarter');

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-15 11:00:00+05:30'::timestamptz, 'multi_year_lock', 'positive', 'founder@equipseva.in', 'done', 'Signed 3 year master at Apollo across 9 sites'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-12 15:00:00+05:30'::timestamptz, 'exec_pitch', 'pending', 'founder@equipseva.in', 'open', 'CFO pitch scheduled with consolidation savings model'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Manipal Hospitals' LIMIT 1;

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-20 10:00:00+05:30'::timestamptz, 'price_match', 'neutral', 'founder@equipseva.in', 'done', 'Matched competitor on cath lab AMC line item'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Fortis Healthcare' LIMIT 1;

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-05 09:30:00+05:30'::timestamptz, 'bundle_offer', 'positive', 'founder@equipseva.in', 'done', 'Bundled ventilator + dialysis added to Yashoda contract'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Yashoda Hospitals' LIMIT 1;

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-18 14:00:00+05:30'::timestamptz, 'feature_demo', 'pending', 'founder@equipseva.in', 'open', 'Demo blitz scheduled with biomed team at Aster'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Aster DM Healthcare' LIMIT 1;

INSERT INTO public.consolidation_counter_actions_r2647
  (pressure_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-25 10:00:00+05:30'::timestamptz, 'exec_pitch', 'pending', 'founder@equipseva.in', 'open', 'Aster COO pitch booked'
FROM public.chain_consolidation_pressure_r2647 WHERE chain_name='Aster DM Healthcare' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_pressure_r2647()
RETURNS SETOF public.chain_consolidation_pressure_r2647
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.chain_consolidation_pressure_r2647 ORDER BY quarter_label DESC, vendor_count_today DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_pressure_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pressure_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_counter_actions_r2647()
RETURNS TABLE(
  id uuid,
  pressure_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.pressure_id, p.chain_name, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
    FROM public.consolidation_counter_actions_r2647 a
    JOIN public.chain_consolidation_pressure_r2647 p ON p.id = a.pressure_id
    ORDER BY a.action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_counter_actions_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_counter_actions_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_threat_focus_r2647()
RETURNS TABLE(
  id uuid,
  chain_name text,
  quarter_label text,
  vendor_count_today int,
  target_vendor_count int,
  our_threat_kind text,
  vendor_gap int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.chain_name, p.quarter_label, p.vendor_count_today, p.target_vendor_count,
           p.our_threat_kind, (p.vendor_count_today - p.target_vendor_count) AS vendor_gap, p.status
    FROM public.chain_consolidation_pressure_r2647 p
    WHERE p.our_threat_kind IN ('reduced','eliminated') AND p.status IN ('monitoring','escalated')
    ORDER BY (p.vendor_count_today - p.target_vendor_count) DESC, p.quarter_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_threat_focus_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_threat_focus_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.our_threat_kind_distribution_r2647()
RETURNS TABLE(
  our_threat_kind text,
  pressure_count bigint,
  avg_vendor_count_today numeric,
  avg_target_vendor_count numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.our_threat_kind,
           COUNT(*)::bigint AS pressure_count,
           ROUND(AVG(p.vendor_count_today)::numeric, 1) AS avg_vendor_count_today,
           ROUND(AVG(p.target_vendor_count)::numeric, 1) AS avg_target_vendor_count
    FROM public.chain_consolidation_pressure_r2647 p
    GROUP BY p.our_threat_kind
    ORDER BY pressure_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.our_threat_kind_distribution_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.our_threat_kind_distribution_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2647()
RETURNS TABLE(
  status text,
  pressure_count bigint,
  total_vendor_gap bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.status,
           COUNT(*)::bigint AS pressure_count,
           COALESCE(SUM(p.vendor_count_today - p.target_vendor_count), 0)::bigint AS total_vendor_gap
    FROM public.chain_consolidation_pressure_r2647 p
    GROUP BY p.status
    ORDER BY pressure_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_pressure_trend_r2647()
RETURNS TABLE(
  quarter_label text,
  pressure_count bigint,
  escalated_count bigint,
  resolved_count bigint,
  avg_vendor_gap numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.quarter_label,
           COUNT(*)::bigint AS pressure_count,
           COUNT(*) FILTER (WHERE p.status='escalated')::bigint AS escalated_count,
           COUNT(*) FILTER (WHERE p.status='resolved')::bigint AS resolved_count,
           ROUND(AVG(p.vendor_count_today - p.target_vendor_count)::numeric, 1) AS avg_vendor_gap
    FROM public.chain_consolidation_pressure_r2647 p
    GROUP BY p.quarter_label
    ORDER BY p.quarter_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_pressure_trend_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_pressure_trend_r2647() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2647()
RETURNS TABLE(
  owner_email text,
  pressure_count bigint,
  action_count bigint,
  open_action_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(p.owner_email, 'unassigned') AS owner_email,
           COUNT(DISTINCT p.id)::bigint AS pressure_count,
           COUNT(a.id)::bigint AS action_count,
           COUNT(a.id) FILTER (WHERE a.status='open')::bigint AS open_action_count
    FROM public.chain_consolidation_pressure_r2647 p
    LEFT JOIN public.consolidation_counter_actions_r2647 a ON a.pressure_id = p.id
    GROUP BY COALESCE(p.owner_email, 'unassigned')
    ORDER BY pressure_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2647() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2647() TO authenticated;
