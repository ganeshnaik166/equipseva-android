BEGIN;

-- ============================================================================
-- r1462 — Hospital Contract Renewals Queue
-- All AMC contracts in next 90 days for renewal; renewal-likelihood score;
-- founder-action ladder; lost-renewal post-mortem capture.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: founder_renewal_actions — action ladder log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_renewal_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  rung text NOT NULL CHECK (rung IN ('soft_ping','call','site_visit','discount_offer','escalate_md','final_offer')),
  notes text,
  outcome text CHECK (outcome IS NULL OR outcome IN ('promised_renew','wants_discount','wants_meeting','silent','will_not_renew')),
  taken_by uuid REFERENCES public.profiles(id),
  taken_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_renewal_actions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Table 2: founder_renewal_postmortems — lost-renewal capture
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_renewal_postmortems (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  loss_reason text NOT NULL CHECK (loss_reason IN ('price','service_quality','competitor','budget_cut','equipment_decommissioned','no_response','other')),
  competitor_name text,
  price_gap_rupees integer,
  lessons_learned text,
  preventable boolean NOT NULL DEFAULT false,
  captured_by uuid REFERENCES public.profiles(id),
  captured_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_renewal_postmortems ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_renewal_actions_contract ON public.founder_renewal_actions(contract_id, taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_renewal_postmortems_contract ON public.founder_renewal_postmortems(contract_id);

-- ===========================================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.log_founder_renewal_action(
  p_contract_id uuid,
  p_rung text,
  p_notes text DEFAULT NULL,
  p_outcome text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_renewal_actions(contract_id, rung, notes, outcome, taken_by)
  VALUES (p_contract_id, p_rung, p_notes, p_outcome, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.log_founder_renewal_action(uuid,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_renewal_postmortem(
  p_contract_id uuid,
  p_loss_reason text,
  p_competitor_name text DEFAULT NULL,
  p_price_gap_rupees integer DEFAULT NULL,
  p_lessons_learned text DEFAULT NULL,
  p_preventable boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_renewal_postmortems(contract_id, loss_reason, competitor_name, price_gap_rupees, lessons_learned, preventable, captured_by)
  VALUES (p_contract_id, p_loss_reason, p_competitor_name, p_price_gap_rupees, p_lessons_learned, p_preventable, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.log_founder_renewal_postmortem(uuid,text,text,integer,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_renewal_view(
  p_contract_id uuid DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- silent view-log placeholder
  PERFORM 1;
END $$;
GRANT EXECUTE ON FUNCTION public.log_founder_renewal_view(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_renewal_export() RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  PERFORM 1;
END $$;
GRANT EXECUTE ON FUNCTION public.log_founder_renewal_export() TO authenticated;

-- ===========================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- ===========================================================================

-- RPC 1: KPI roll-up
CREATE OR REPLACE FUNCTION public.founder_renewal_kpis()
RETURNS TABLE(
  contracts_due_90d integer,
  contracts_due_30d integer,
  contracts_due_7d integer,
  contracts_overdue integer,
  arr_at_risk_rupees bigint,
  arr_due_30d_rupees bigint,
  high_likelihood_count integer,
  med_likelihood_count integer,
  low_likelihood_count integer,
  actions_logged_30d integer,
  postmortems_30d integer,
  preventable_losses_30d integer,
  avg_likelihood_pct numeric,
  total_at_risk_orgs integer,
  silent_orgs_count integer,
  escalations_pending integer
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH due AS (
    SELECT c.id, c.end_date, c.monthly_fee_rupees, c.organization_id
    FROM amc_contracts c
    WHERE c.status = 'active'
      AND c.end_date <= (now()::date + 90)
  ),
  scored AS (
    SELECT d.*,
      -- crude likelihood: base 60, +20 if recent action, -15 if no service ticket in 60d, capped 5..95
      LEAST(95, GREATEST(5,
        60
        + CASE WHEN EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = d.id AND a.outcome = 'promised_renew') THEN 25 ELSE 0 END
        - CASE WHEN EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = d.id AND a.outcome IN ('will_not_renew','silent')) THEN 30 ELSE 0 END
      ))::int AS likelihood
    FROM due d
  )
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE end_date <= now()::date + 30)::int,
    COUNT(*) FILTER (WHERE end_date <= now()::date + 7)::int,
    COUNT(*) FILTER (WHERE end_date < now()::date)::int,
    COALESCE(SUM(monthly_fee_rupees * 12), 0)::bigint,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE end_date <= now()::date + 30), 0)::bigint,
    COUNT(*) FILTER (WHERE likelihood >= 70)::int,
    COUNT(*) FILTER (WHERE likelihood BETWEEN 40 AND 69)::int,
    COUNT(*) FILTER (WHERE likelihood < 40)::int,
    (SELECT COUNT(*) FROM founder_renewal_actions WHERE taken_at >= now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM founder_renewal_postmortems WHERE captured_at >= now() - interval '30 days')::int,
    (SELECT COUNT(*) FROM founder_renewal_postmortems WHERE captured_at >= now() - interval '30 days' AND preventable)::int,
    COALESCE(ROUND(AVG(likelihood)::numeric, 1), 0),
    COUNT(DISTINCT organization_id)::int,
    COUNT(DISTINCT organization_id) FILTER (WHERE NOT EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = scored.id))::int,
    COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = scored.id AND a.rung = 'escalate_md' AND a.outcome IS NULL))::int
  FROM scored;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_kpis() TO authenticated;

-- RPC 2: queue (next 90 days)
CREATE OR REPLACE FUNCTION public.founder_renewal_queue()
RETURNS TABLE(
  contract_id uuid,
  organization_id uuid,
  org_name text,
  org_city text,
  amc_tier text,
  monthly_fee_rupees integer,
  annual_value_rupees bigint,
  end_date date,
  days_to_expiry integer,
  likelihood_pct integer,
  bucket text,
  last_action_rung text,
  last_action_outcome text,
  last_action_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH due AS (
    SELECT c.id, c.organization_id, c.amc_tier, c.monthly_fee_rupees, c.end_date
    FROM amc_contracts c
    WHERE c.status = 'active' AND c.end_date <= now()::date + 90
  ),
  last_act AS (
    SELECT DISTINCT ON (a.contract_id) a.contract_id, a.rung, a.outcome, a.taken_at
    FROM founder_renewal_actions a
    ORDER BY a.contract_id, a.taken_at DESC
  )
  SELECT
    d.id,
    d.organization_id,
    o.name,
    o.city,
    d.amc_tier,
    d.monthly_fee_rupees,
    (d.monthly_fee_rupees * 12)::bigint,
    d.end_date,
    (d.end_date - now()::date)::int,
    LEAST(95, GREATEST(5,
      60
      + CASE WHEN la.outcome = 'promised_renew' THEN 25 ELSE 0 END
      - CASE WHEN la.outcome IN ('will_not_renew','silent') THEN 30 ELSE 0 END
    ))::int,
    CASE
      WHEN d.end_date < now()::date THEN 'overdue'
      WHEN d.end_date <= now()::date + 7 THEN 'this_week'
      WHEN d.end_date <= now()::date + 30 THEN 'this_month'
      ELSE 'next_quarter'
    END,
    la.rung,
    la.outcome,
    la.taken_at
  FROM due d
  JOIN organizations o ON o.id = d.organization_id
  LEFT JOIN last_act la ON la.contract_id = d.id
  ORDER BY d.end_date ASC;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_queue() TO authenticated;

-- RPC 3: action ladder feed
CREATE OR REPLACE FUNCTION public.founder_renewal_action_ladder()
RETURNS TABLE(
  action_id uuid,
  contract_id uuid,
  org_name text,
  rung text,
  outcome text,
  notes text,
  taken_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.contract_id, o.name, a.rung, a.outcome, a.notes, a.taken_at
  FROM founder_renewal_actions a
  JOIN amc_contracts c ON c.id = a.contract_id
  JOIN organizations o ON o.id = c.organization_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_action_ladder() TO authenticated;

-- RPC 4: lost-renewal postmortems
CREATE OR REPLACE FUNCTION public.founder_renewal_postmortem_log()
RETURNS TABLE(
  postmortem_id uuid,
  contract_id uuid,
  org_name text,
  loss_reason text,
  competitor_name text,
  price_gap_rupees integer,
  preventable boolean,
  lessons_learned text,
  captured_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.contract_id, o.name, p.loss_reason, p.competitor_name, p.price_gap_rupees, p.preventable, p.lessons_learned, p.captured_at
  FROM founder_renewal_postmortems p
  JOIN amc_contracts c ON c.id = p.contract_id
  JOIN organizations o ON o.id = c.organization_id
  ORDER BY p.captured_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_postmortem_log() TO authenticated;

-- RPC 5: silent / no-touch contracts
CREATE OR REPLACE FUNCTION public.founder_renewal_silent_contracts()
RETURNS TABLE(
  contract_id uuid,
  org_name text,
  org_city text,
  end_date date,
  days_to_expiry integer,
  annual_value_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, o.name, o.city, c.end_date,
         (c.end_date - now()::date)::int,
         (c.monthly_fee_rupees * 12)::bigint
  FROM amc_contracts c
  JOIN organizations o ON o.id = c.organization_id
  WHERE c.status = 'active'
    AND c.end_date <= now()::date + 60
    AND NOT EXISTS (SELECT 1 FROM founder_renewal_actions a WHERE a.contract_id = c.id)
  ORDER BY c.end_date ASC
  LIMIT 50;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_silent_contracts() TO authenticated;

-- RPC 6: loss-reason rollup
CREATE OR REPLACE FUNCTION public.founder_renewal_loss_reasons()
RETURNS TABLE(
  loss_reason text,
  cnt integer,
  preventable_cnt integer,
  total_arr_lost_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.loss_reason,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.preventable)::int,
         COALESCE(SUM(c.monthly_fee_rupees * 12), 0)::bigint
  FROM founder_renewal_postmortems p
  JOIN amc_contracts c ON c.id = p.contract_id
  GROUP BY p.loss_reason
  ORDER BY COUNT(*) DESC;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_loss_reasons() TO authenticated;

-- RPC 7: rung distribution
CREATE OR REPLACE FUNCTION public.founder_renewal_rung_distribution()
RETURNS TABLE(
  rung text,
  cnt integer,
  promised_cnt integer,
  silent_cnt integer
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.rung,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE a.outcome = 'promised_renew')::int,
         COUNT(*) FILTER (WHERE a.outcome = 'silent')::int
  FROM founder_renewal_actions a
  WHERE a.taken_at >= now() - interval '90 days'
  GROUP BY a.rung
  ORDER BY COUNT(*) DESC;
END $$;
GRANT EXECUTE ON FUNCTION public.founder_renewal_rung_distribution() TO authenticated;

COMMIT;