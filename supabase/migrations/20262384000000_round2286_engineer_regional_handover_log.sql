BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_regional_handover_log_r2286 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outgoing_engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  incoming_engineer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  handover_reason text NOT NULL CHECK (handover_reason IN ('region_change','left_company','promotion','leave_long','reassignment','other')),
  from_region text NOT NULL,
  to_region text,
  effective_date date NOT NULL,
  status text NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated','in_progress','accounts_transferred','knowledge_transferred','tools_returned','completed','blocked','cancelled')),
  accounts_count int NOT NULL DEFAULT 0,
  amc_contracts_count int NOT NULL DEFAULT 0,
  open_jobs_count int NOT NULL DEFAULT 0,
  tools_assigned_count int NOT NULL DEFAULT 0,
  tools_returned_count int NOT NULL DEFAULT 0,
  knowledge_doc_url text,
  manager_signoff_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehl_r2286_outgoing ON public.engineer_regional_handover_log_r2286(outgoing_engineer_id);
CREATE INDEX IF NOT EXISTS idx_ehl_r2286_incoming ON public.engineer_regional_handover_log_r2286(incoming_engineer_id);
CREATE INDEX IF NOT EXISTS idx_ehl_r2286_status ON public.engineer_regional_handover_log_r2286(status);
CREATE INDEX IF NOT EXISTS idx_ehl_r2286_effective ON public.engineer_regional_handover_log_r2286(effective_date DESC);

ALTER TABLE public.engineer_regional_handover_log_r2286 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ehl_r2286_founder_all ON public.engineer_regional_handover_log_r2286;
CREATE POLICY ehl_r2286_founder_all ON public.engineer_regional_handover_log_r2286
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_regional_handover_items_r2286 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handover_id uuid NOT NULL REFERENCES public.engineer_regional_handover_log_r2286(id) ON DELETE CASCADE,
  item_kind text NOT NULL CHECK (item_kind IN ('account','amc_contract','open_job','tool','knowledge_doc','credential','escalation_contact','sla_commitment')),
  item_ref text NOT NULL,
  item_description text,
  transferred boolean NOT NULL DEFAULT false,
  transferred_at timestamptz,
  verified_by_incoming boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  risk_level text NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low','medium','high','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehi_r2286_handover ON public.engineer_regional_handover_items_r2286(handover_id);
CREATE INDEX IF NOT EXISTS idx_ehi_r2286_kind ON public.engineer_regional_handover_items_r2286(item_kind);
CREATE INDEX IF NOT EXISTS idx_ehi_r2286_transferred ON public.engineer_regional_handover_items_r2286(transferred);

ALTER TABLE public.engineer_regional_handover_items_r2286 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ehi_r2286_founder_all ON public.engineer_regional_handover_items_r2286;
CREATE POLICY ehi_r2286_founder_all ON public.engineer_regional_handover_items_r2286
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: summary KPIs
CREATE OR REPLACE FUNCTION public.fn_r2286_handover_summary()
RETURNS TABLE(
  total_handovers int,
  active_handovers int,
  completed_handovers int,
  blocked_handovers int,
  avg_days_to_complete numeric,
  total_items_pending int,
  critical_items_pending int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_log_r2286),
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_log_r2286 WHERE status IN ('initiated','in_progress','accounts_transferred','knowledge_transferred','tools_returned')),
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_log_r2286 WHERE status = 'completed'),
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_log_r2286 WHERE status = 'blocked'),
    (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (manager_signoff_at - created_at))/86400.0), 0)::numeric FROM public.engineer_regional_handover_log_r2286 WHERE manager_signoff_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_items_r2286 WHERE transferred = false),
    (SELECT COUNT(*)::int FROM public.engineer_regional_handover_items_r2286 WHERE transferred = false AND risk_level = 'critical');
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_handover_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_handover_summary() TO authenticated;

-- RPC 2: list handovers
CREATE OR REPLACE FUNCTION public.fn_r2286_list_handovers(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  outgoing_email text,
  incoming_email text,
  handover_reason text,
  from_region text,
  to_region text,
  effective_date date,
  status text,
  accounts_count int,
  amc_contracts_count int,
  open_jobs_count int,
  tools_returned_count int,
  tools_assigned_count int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, po.email::text, pi.email::text, h.handover_reason, h.from_region, h.to_region,
    h.effective_date, h.status, h.accounts_count, h.amc_contracts_count, h.open_jobs_count,
    h.tools_returned_count, h.tools_assigned_count, h.created_at
  FROM public.engineer_regional_handover_log_r2286 h
  LEFT JOIN public.profiles po ON po.id = h.outgoing_engineer_id
  LEFT JOIN public.profiles pi ON pi.id = h.incoming_engineer_id
  ORDER BY h.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_list_handovers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_list_handovers(int) TO authenticated;

-- RPC 3: items by kind aggregation
CREATE OR REPLACE FUNCTION public.fn_r2286_items_by_kind()
RETURNS TABLE(
  item_kind text,
  total_items int,
  transferred_items int,
  pending_items int,
  critical_pending int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.item_kind,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE i.transferred)::int,
    COUNT(*) FILTER (WHERE NOT i.transferred)::int,
    COUNT(*) FILTER (WHERE NOT i.transferred AND i.risk_level = 'critical')::int
  FROM public.engineer_regional_handover_items_r2286 i
  GROUP BY i.item_kind
  ORDER BY COUNT(*) FILTER (WHERE NOT i.transferred) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_items_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_items_by_kind() TO authenticated;

-- RPC 4: handovers by reason
CREATE OR REPLACE FUNCTION public.fn_r2286_handovers_by_reason()
RETURNS TABLE(
  handover_reason text,
  total int,
  completed int,
  avg_accounts numeric,
  avg_amc_contracts numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.handover_reason,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE h.status = 'completed')::int,
    COALESCE(AVG(h.accounts_count), 0)::numeric,
    COALESCE(AVG(h.amc_contracts_count), 0)::numeric
  FROM public.engineer_regional_handover_log_r2286 h
  GROUP BY h.handover_reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_handovers_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_handovers_by_reason() TO authenticated;

-- RPC 5: blocked / at-risk handovers
CREATE OR REPLACE FUNCTION public.fn_r2286_blocked_handovers()
RETURNS TABLE(
  id uuid,
  outgoing_email text,
  from_region text,
  status text,
  open_jobs_count int,
  tools_pending int,
  effective_date date,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, po.email::text, h.from_region, h.status, h.open_jobs_count,
    (h.tools_assigned_count - h.tools_returned_count)::int,
    h.effective_date, h.notes
  FROM public.engineer_regional_handover_log_r2286 h
  LEFT JOIN public.profiles po ON po.id = h.outgoing_engineer_id
  WHERE h.status IN ('blocked','initiated','in_progress')
    AND (h.effective_date <= CURRENT_DATE OR h.status = 'blocked')
  ORDER BY h.effective_date ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_blocked_handovers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_blocked_handovers() TO authenticated;

-- RPC 6: region churn
CREATE OR REPLACE FUNCTION public.fn_r2286_region_churn()
RETURNS TABLE(
  region text,
  exits_count int,
  arrivals_count int,
  net_flow int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH exits AS (
    SELECT from_region AS region, COUNT(*)::int AS c
    FROM public.engineer_regional_handover_log_r2286
    GROUP BY from_region
  ),
  arrivals AS (
    SELECT to_region AS region, COUNT(*)::int AS c
    FROM public.engineer_regional_handover_log_r2286
    WHERE to_region IS NOT NULL
    GROUP BY to_region
  )
  SELECT COALESCE(e.region, a.region)::text,
    COALESCE(e.c, 0),
    COALESCE(a.c, 0),
    (COALESCE(a.c, 0) - COALESCE(e.c, 0))
  FROM exits e
  FULL OUTER JOIN arrivals a ON a.region = e.region
  ORDER BY COALESCE(e.c, 0) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_region_churn() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_region_churn() TO authenticated;

-- RPC 7: seed demo handover
CREATE OR REPLACE FUNCTION public.fn_r2286_seed_demo()
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_out uuid;
  v_in uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_out FROM public.profiles WHERE role = 'engineer' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_in FROM public.profiles WHERE role = 'engineer' AND id <> v_out ORDER BY created_at DESC LIMIT 1;
  IF v_out IS NULL THEN RAISE EXCEPTION 'no engineer profile available for seed'; END IF;

  INSERT INTO public.engineer_regional_handover_log_r2286(
    outgoing_engineer_id, incoming_engineer_id, handover_reason, from_region, to_region,
    effective_date, status, accounts_count, amc_contracts_count, open_jobs_count,
    tools_assigned_count, tools_returned_count, notes
  ) VALUES (
    v_out, v_in, 'region_change', 'Hyderabad-South', 'Bengaluru-Central',
    CURRENT_DATE + 7, 'in_progress', 12, 8, 3, 5, 2,
    'demo handover seed'
  ) RETURNING id INTO v_id;

  INSERT INTO public.engineer_regional_handover_items_r2286(handover_id, item_kind, item_ref, item_description, transferred, risk_level)
  VALUES
    (v_id, 'account', 'ACC-001', 'Apollo Hospital - Jubilee Hills', true, 'medium'),
    (v_id, 'amc_contract', 'AMC-2025-091', 'Yearly AMC - 12 ventilators', false, 'high'),
    (v_id, 'open_job', 'JOB-4421', 'Pending part install', false, 'critical'),
    (v_id, 'tool', 'TOOL-LX900', 'Calibration kit', false, 'medium'),
    (v_id, 'knowledge_doc', 'KB-2841', 'Site quirks doc - Apollo HVAC', true, 'low'),
    (v_id, 'credential', 'CRED-VPN-04', 'Site VPN credential rotation', false, 'critical');

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2286_seed_demo() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2286_seed_demo() TO authenticated;

COMMIT;
