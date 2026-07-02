BEGIN;

-- r2387 hospital chain MRR concentration risk
-- Top 5 chains as % of total MRR, dependency risk scoring, diversification plan

CREATE TABLE IF NOT EXISTS public.hospital_chain_mrr_snapshot_r2387 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_count integer NOT NULL DEFAULT 0,
  active_amc_contracts integer NOT NULL DEFAULT 0,
  monthly_recurring_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  share_of_total_mrr_pct numeric(6,2) NOT NULL DEFAULT 0,
  concentration_rank integer NOT NULL DEFAULT 0,
  dependency_risk_score integer NOT NULL DEFAULT 0 CHECK (dependency_risk_score BETWEEN 0 AND 100),
  risk_tier text NOT NULL DEFAULT 'low' CHECK (risk_tier IN ('low','elevated','high','critical')),
  contract_end_date date,
  notes text,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_diversification_actions_r2387 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  action_type text NOT NULL CHECK (action_type IN ('new_chain_outreach','contract_renewal','tier_upgrade','geographic_expansion','vertical_diversify','retention_visit')),
  target_chain text,
  target_mrr_rupees numeric(14,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','won','lost','deferred')),
  owner_email text,
  due_date date,
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_mrr_snapshot_r2387 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_diversification_actions_r2387 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_mrr_snapshot_r2387;
CREATE POLICY founder_all ON public.hospital_chain_mrr_snapshot_r2387
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_diversification_actions_r2387;
CREATE POLICY founder_all ON public.hospital_chain_diversification_actions_r2387
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS hcmrr_r2387_rank_idx ON public.hospital_chain_mrr_snapshot_r2387(concentration_rank);
CREATE INDEX IF NOT EXISTS hcmrr_r2387_risk_idx ON public.hospital_chain_mrr_snapshot_r2387(risk_tier);
CREATE INDEX IF NOT EXISTS hcda_r2387_status_idx ON public.hospital_chain_diversification_actions_r2387(status);
CREATE INDEX IF NOT EXISTS hcda_r2387_due_idx ON public.hospital_chain_diversification_actions_r2387(due_date);

-- RPC 1: snapshot top chain
CREATE OR REPLACE FUNCTION public.r2387_snapshot_chain(
  p_chain_name text,
  p_chain_org_id uuid,
  p_hospital_count integer,
  p_active_amc_contracts integer,
  p_mrr_rupees numeric,
  p_total_mrr_rupees numeric,
  p_concentration_rank integer,
  p_contract_end_date date,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_share numeric(6,2);
  v_risk_score integer;
  v_tier text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_share := CASE WHEN p_total_mrr_rupees > 0 THEN ROUND((p_mrr_rupees / p_total_mrr_rupees) * 100, 2) ELSE 0 END;
  v_risk_score := LEAST(100, GREATEST(0, FLOOR(v_share * 2)::integer + CASE WHEN p_concentration_rank = 1 THEN 20 WHEN p_concentration_rank <= 3 THEN 10 ELSE 0 END));
  v_tier := CASE WHEN v_risk_score >= 70 THEN 'critical' WHEN v_risk_score >= 50 THEN 'high' WHEN v_risk_score >= 30 THEN 'elevated' ELSE 'low' END;
  INSERT INTO public.hospital_chain_mrr_snapshot_r2387(chain_name, chain_org_id, hospital_count, active_amc_contracts, monthly_recurring_revenue_rupees, share_of_total_mrr_pct, concentration_rank, dependency_risk_score, risk_tier, contract_end_date, notes, recorded_by)
  VALUES (p_chain_name, p_chain_org_id, p_hospital_count, p_active_amc_contracts, p_mrr_rupees, v_share, p_concentration_rank, v_risk_score, v_tier, p_contract_end_date, p_notes, (SELECT id FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 2: list top chains
CREATE OR REPLACE FUNCTION public.r2387_list_top_chains(p_limit integer)
RETURNS TABLE(id uuid, chain_name text, hospital_count integer, monthly_recurring_revenue_rupees numeric, share_of_total_mrr_pct numeric, concentration_rank integer, dependency_risk_score integer, risk_tier text, contract_end_date date, snapshot_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.chain_name, s.hospital_count, s.monthly_recurring_revenue_rupees, s.share_of_total_mrr_pct, s.concentration_rank, s.dependency_risk_score, s.risk_tier, s.contract_end_date, s.snapshot_at
  FROM public.hospital_chain_mrr_snapshot_r2387 s
  ORDER BY s.concentration_rank ASC, s.snapshot_at DESC
  LIMIT COALESCE(p_limit, 5);
END;
$$;

-- RPC 3: concentration totals (top 5 share)
CREATE OR REPLACE FUNCTION public.r2387_concentration_totals()
RETURNS TABLE(top_5_share_pct numeric, top_1_share_pct numeric, critical_chains integer, high_risk_chains integer, total_tracked_mrr_rupees numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT * FROM public.hospital_chain_mrr_snapshot_r2387
    ORDER BY concentration_rank ASC LIMIT 5
  )
  SELECT
    COALESCE(SUM(share_of_total_mrr_pct), 0)::numeric AS top_5_share_pct,
    COALESCE((SELECT share_of_total_mrr_pct FROM ranked WHERE concentration_rank = 1 LIMIT 1), 0)::numeric AS top_1_share_pct,
    (SELECT COUNT(*)::integer FROM public.hospital_chain_mrr_snapshot_r2387 WHERE risk_tier = 'critical') AS critical_chains,
    (SELECT COUNT(*)::integer FROM public.hospital_chain_mrr_snapshot_r2387 WHERE risk_tier = 'high') AS high_risk_chains,
    COALESCE(SUM(monthly_recurring_revenue_rupees), 0)::numeric AS total_tracked_mrr_rupees
  FROM ranked;
END;
$$;

-- RPC 4: list diversification actions
CREATE OR REPLACE FUNCTION public.r2387_list_actions()
RETURNS TABLE(id uuid, chain_name text, action_type text, target_chain text, target_mrr_rupees numeric, status text, owner_email text, due_date date, notes text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.chain_name, a.action_type, a.target_chain, a.target_mrr_rupees, a.status, a.owner_email, a.due_date, a.notes, a.created_at
  FROM public.hospital_chain_diversification_actions_r2387 a
  ORDER BY (CASE a.status WHEN 'in_progress' THEN 1 WHEN 'planned' THEN 2 WHEN 'won' THEN 3 WHEN 'deferred' THEN 4 ELSE 5 END), a.due_date NULLS LAST;
END;
$$;

-- RPC 5: create diversification action
CREATE OR REPLACE FUNCTION public.r2387_create_action(
  p_chain_name text,
  p_chain_org_id uuid,
  p_action_type text,
  p_target_chain text,
  p_target_mrr_rupees numeric,
  p_owner_email text,
  p_due_date date,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_diversification_actions_r2387(chain_name, chain_org_id, action_type, target_chain, target_mrr_rupees, owner_email, due_date, notes, created_by)
  VALUES (p_chain_name, p_chain_org_id, p_action_type, p_target_chain, COALESCE(p_target_mrr_rupees,0), p_owner_email, p_due_date, p_notes, (SELECT id FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 6: update action status
CREATE OR REPLACE FUNCTION public.r2387_update_action_status(p_action_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_chain_diversification_actions_r2387
  SET status = p_status, updated_at = now()
  WHERE id = p_action_id;
END;
$$;

-- RPC 7: risk distribution
CREATE OR REPLACE FUNCTION public.r2387_risk_distribution()
RETURNS TABLE(risk_tier text, chain_count integer, total_mrr_rupees numeric, avg_share_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.risk_tier, COUNT(*)::integer, COALESCE(SUM(s.monthly_recurring_revenue_rupees),0)::numeric, COALESCE(AVG(s.share_of_total_mrr_pct),0)::numeric
  FROM public.hospital_chain_mrr_snapshot_r2387 s
  GROUP BY s.risk_tier
  ORDER BY (CASE s.risk_tier WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'elevated' THEN 3 ELSE 4 END);
END;
$$;

REVOKE ALL ON FUNCTION public.r2387_snapshot_chain(text, uuid, integer, integer, numeric, numeric, integer, date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_list_top_chains(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_concentration_totals() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_list_actions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_create_action(text, uuid, text, text, numeric, text, date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_update_action_status(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2387_risk_distribution() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2387_snapshot_chain(text, uuid, integer, integer, numeric, numeric, integer, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_list_top_chains(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_concentration_totals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_create_action(text, uuid, text, text, numeric, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_update_action_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2387_risk_distribution() TO authenticated;

COMMIT;
