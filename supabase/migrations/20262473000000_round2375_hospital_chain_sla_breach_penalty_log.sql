BEGIN;

-- =========================================================================
-- r2375: Hospital chain contractual-SLA breach penalty log
-- =========================================================================
-- When we breach a contractual SLA with a hospital chain, the customer
-- can invoke contractual penalties (liquidated damages, fee waivers,
-- credit notes, contract termination clauses). This log captures every
-- breach event, the penalty incurred, the post-incident negotiation
-- with the chain, and the final settlement so we can (a) pay what we
-- owe quickly, (b) defend disputed penalties, and (c) feed the lessons
-- back into chain pricing and operational SLAs.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.chain_sla_breach_events_r2375 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  breach_ref text NOT NULL UNIQUE,
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3','strategic')),
  hospital_site text,
  contract_ref text,
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0,
  sla_clause text NOT NULL,
  sla_metric text NOT NULL CHECK (sla_metric IN ('uptime_pct','response_time_hours','resolution_time_hours','first_visit_fix_pct','spare_availability_pct','escalation_response_hours','reporting_cadence','other')),
  contractual_threshold text NOT NULL,
  observed_value text NOT NULL,
  breach_severity text NOT NULL CHECK (breach_severity IN ('minor','material','major','catastrophic')),
  affected_equipment_count int NOT NULL DEFAULT 0 CHECK (affected_equipment_count >= 0),
  affected_revenue_at_risk_rupees bigint NOT NULL DEFAULT 0,
  breach_started_at timestamptz NOT NULL,
  breach_ended_at timestamptz,
  detected_at timestamptz NOT NULL DEFAULT now(),
  detection_source text NOT NULL CHECK (detection_source IN ('internal_monitor','chain_escalation','quarterly_review','audit','engineer_report','penalty_notice','press_release','other')),
  contractual_penalty_clause text NOT NULL,
  penalty_calculation_basis text NOT NULL,
  contractual_penalty_rupees bigint NOT NULL DEFAULT 0 CHECK (contractual_penalty_rupees >= 0),
  customer_claimed_penalty_rupees bigint NOT NULL DEFAULT 0 CHECK (customer_claimed_penalty_rupees >= 0),
  our_proposed_settlement_rupees bigint NOT NULL DEFAULT 0 CHECK (our_proposed_settlement_rupees >= 0),
  final_settlement_rupees bigint CHECK (final_settlement_rupees IS NULL OR final_settlement_rupees >= 0),
  settlement_form text CHECK (settlement_form IN ('cash_payment','fee_waiver','credit_note','service_extension','equipment_swap','contract_concession','mixed','disputed','none')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','negotiating','settled','paid','disputed','written_off','escalated_legal')),
  negotiation_lead_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  root_cause_category text CHECK (root_cause_category IN ('engineer_shortage','spare_stockout','wrong_diagnosis','logistics_delay','process_gap','tooling_gap','customer_blocked_access','force_majeure','other','unknown')),
  preventability text CHECK (preventability IN ('fully_preventable','partly_preventable','unpreventable','disputed')),
  relationship_impact text CHECK (relationship_impact IN ('strengthened','neutral','strained','damaged','contract_at_risk')),
  press_or_social_risk boolean NOT NULL DEFAULT false,
  legal_exposure_flag boolean NOT NULL DEFAULT false,
  due_date_for_settlement date,
  settled_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_csbe_r2375_status ON public.chain_sla_breach_events_r2375(status, breach_severity);
CREATE INDEX IF NOT EXISTS idx_csbe_r2375_chain ON public.chain_sla_breach_events_r2375(chain_name);
CREATE INDEX IF NOT EXISTS idx_csbe_r2375_detected ON public.chain_sla_breach_events_r2375(detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_csbe_r2375_due ON public.chain_sla_breach_events_r2375(due_date_for_settlement) WHERE status IN ('open','negotiating','settled');

ALTER TABLE public.chain_sla_breach_events_r2375 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS csbe_r2375_founder_all ON public.chain_sla_breach_events_r2375;
CREATE POLICY csbe_r2375_founder_all ON public.chain_sla_breach_events_r2375
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.chain_sla_breach_negotiations_r2375 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  breach_id uuid NOT NULL REFERENCES public.chain_sla_breach_events_r2375(id) ON DELETE CASCADE,
  round_number int NOT NULL CHECK (round_number > 0),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('email','phone','in_person','video_call','formal_letter','legal_notice','other')),
  participant_label text NOT NULL,
  customer_position_rupees bigint CHECK (customer_position_rupees IS NULL OR customer_position_rupees >= 0),
  our_position_rupees bigint CHECK (our_position_rupees IS NULL OR our_position_rupees >= 0),
  customer_tone text CHECK (customer_tone IN ('cooperative','firm','adversarial','threatening','silent')),
  ask_concession text,
  outcome text NOT NULL CHECK (outcome IN ('opened','progress','stalled','impasse','agreement_in_principle','signed_settlement','escalated')),
  summary text,
  next_action text,
  next_action_due date,
  logged_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (breach_id, round_number)
);

CREATE INDEX IF NOT EXISTS idx_csbn_r2375_breach ON public.chain_sla_breach_negotiations_r2375(breach_id, round_number);
CREATE INDEX IF NOT EXISTS idx_csbn_r2375_next ON public.chain_sla_breach_negotiations_r2375(next_action_due) WHERE next_action_due IS NOT NULL;

ALTER TABLE public.chain_sla_breach_negotiations_r2375 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS csbn_r2375_founder_all ON public.chain_sla_breach_negotiations_r2375;
CREATE POLICY csbn_r2375_founder_all ON public.chain_sla_breach_negotiations_r2375
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =========================================================================
-- RPC 1: KPI summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_breach_summary_r2375()
RETURNS TABLE(
  open_breaches int,
  negotiating int,
  catastrophic_or_major int,
  total_contractual_penalty_rupees bigint,
  total_customer_claim_rupees bigint,
  total_paid_last_90d_rupees bigint,
  total_arr_under_threat_rupees bigint,
  press_risk_count int,
  legal_exposure_count int,
  overdue_settlements int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE b.status = 'open')::int,
    COUNT(*) FILTER (WHERE b.status = 'negotiating')::int,
    COUNT(*) FILTER (WHERE b.breach_severity IN ('major','catastrophic') AND b.status NOT IN ('paid','written_off'))::int,
    COALESCE(SUM(b.contractual_penalty_rupees) FILTER (WHERE b.status NOT IN ('paid','written_off')), 0)::bigint,
    COALESCE(SUM(b.customer_claimed_penalty_rupees) FILTER (WHERE b.status NOT IN ('paid','written_off')), 0)::bigint,
    COALESCE(SUM(b.final_settlement_rupees) FILTER (WHERE b.paid_at IS NOT NULL AND b.paid_at >= now() - INTERVAL '90 days'), 0)::bigint,
    COALESCE(SUM(b.annual_contract_value_rupees) FILTER (WHERE b.relationship_impact IN ('strained','damaged','contract_at_risk') AND b.status NOT IN ('paid','written_off')), 0)::bigint,
    COUNT(*) FILTER (WHERE b.press_or_social_risk AND b.status NOT IN ('paid','written_off'))::int,
    COUNT(*) FILTER (WHERE b.legal_exposure_flag AND b.status NOT IN ('paid','written_off'))::int,
    COUNT(*) FILTER (WHERE b.due_date_for_settlement IS NOT NULL AND b.due_date_for_settlement < CURRENT_DATE AND b.status IN ('open','negotiating','settled'))::int
  FROM public.chain_sla_breach_events_r2375 b;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_breach_summary_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_breach_summary_r2375() TO authenticated;


-- =========================================================================
-- RPC 2: Breaches list with negotiation round count
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_breach_list_r2375()
RETURNS TABLE(
  id uuid,
  breach_ref text,
  chain_name text,
  chain_tier text,
  hospital_site text,
  sla_metric text,
  breach_severity text,
  contractual_threshold text,
  observed_value text,
  contractual_penalty_rupees bigint,
  customer_claimed_penalty_rupees bigint,
  our_proposed_settlement_rupees bigint,
  final_settlement_rupees bigint,
  status text,
  detected_at timestamptz,
  due_date_for_settlement date,
  relationship_impact text,
  press_or_social_risk boolean,
  legal_exposure_flag boolean,
  negotiation_round_count int,
  created_by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.breach_ref,
    b.chain_name,
    b.chain_tier,
    b.hospital_site,
    b.sla_metric,
    b.breach_severity,
    b.contractual_threshold,
    b.observed_value,
    b.contractual_penalty_rupees,
    b.customer_claimed_penalty_rupees,
    b.our_proposed_settlement_rupees,
    b.final_settlement_rupees,
    b.status,
    b.detected_at,
    b.due_date_for_settlement,
    b.relationship_impact,
    b.press_or_social_risk,
    b.legal_exposure_flag,
    COALESCE((SELECT COUNT(*) FROM public.chain_sla_breach_negotiations_r2375 n WHERE n.breach_id = b.id), 0)::int,
    (SELECT p.email FROM public.profiles p WHERE p.id = b.created_by)
  FROM public.chain_sla_breach_events_r2375 b
  ORDER BY
    CASE b.breach_severity WHEN 'catastrophic' THEN 0 WHEN 'major' THEN 1 WHEN 'material' THEN 2 ELSE 3 END,
    b.detected_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_breach_list_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_breach_list_r2375() TO authenticated;


-- =========================================================================
-- RPC 3: Penalty exposure by chain
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_exposure_by_chain_r2375()
RETURNS TABLE(
  chain_name text,
  chain_tier text,
  open_breaches int,
  total_contractual_penalty_rupees bigint,
  total_customer_claim_rupees bigint,
  total_paid_rupees bigint,
  arr_at_chain_rupees bigint,
  worst_severity text,
  contract_at_risk boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.chain_name,
    MAX(b.chain_tier),
    COUNT(*) FILTER (WHERE b.status NOT IN ('paid','written_off'))::int,
    COALESCE(SUM(b.contractual_penalty_rupees) FILTER (WHERE b.status NOT IN ('paid','written_off')), 0)::bigint,
    COALESCE(SUM(b.customer_claimed_penalty_rupees) FILTER (WHERE b.status NOT IN ('paid','written_off')), 0)::bigint,
    COALESCE(SUM(b.final_settlement_rupees) FILTER (WHERE b.paid_at IS NOT NULL), 0)::bigint,
    MAX(b.annual_contract_value_rupees)::bigint,
    (ARRAY_AGG(b.breach_severity ORDER BY CASE b.breach_severity WHEN 'catastrophic' THEN 0 WHEN 'major' THEN 1 WHEN 'material' THEN 2 ELSE 3 END))[1],
    BOOL_OR(b.relationship_impact = 'contract_at_risk')
  FROM public.chain_sla_breach_events_r2375 b
  GROUP BY b.chain_name
  ORDER BY COALESCE(SUM(b.contractual_penalty_rupees) FILTER (WHERE b.status NOT IN ('paid','written_off')), 0) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_exposure_by_chain_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_exposure_by_chain_r2375() TO authenticated;


-- =========================================================================
-- RPC 4: Breach mix by SLA metric (where do we breach most?)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_breach_by_metric_r2375()
RETURNS TABLE(
  sla_metric text,
  breach_count int,
  contractual_penalty_rupees bigint,
  paid_rupees bigint,
  avg_settlement_pct_of_claim numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.sla_metric,
    COUNT(*)::int,
    COALESCE(SUM(b.contractual_penalty_rupees), 0)::bigint,
    COALESCE(SUM(b.final_settlement_rupees) FILTER (WHERE b.paid_at IS NOT NULL), 0)::bigint,
    ROUND(
      AVG(
        CASE
          WHEN b.customer_claimed_penalty_rupees > 0 AND b.final_settlement_rupees IS NOT NULL
            THEN (b.final_settlement_rupees::numeric / b.customer_claimed_penalty_rupees::numeric) * 100
          ELSE NULL
        END
      ),
      2
    )
  FROM public.chain_sla_breach_events_r2375 b
  GROUP BY b.sla_metric
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_breach_by_metric_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_breach_by_metric_r2375() TO authenticated;


-- =========================================================================
-- RPC 5: Root cause mix and preventability
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_root_cause_mix_r2375()
RETURNS TABLE(
  root_cause_category text,
  breach_count int,
  fully_preventable int,
  partly_preventable int,
  unpreventable int,
  total_penalty_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(b.root_cause_category, 'unknown'),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE b.preventability = 'fully_preventable')::int,
    COUNT(*) FILTER (WHERE b.preventability = 'partly_preventable')::int,
    COUNT(*) FILTER (WHERE b.preventability = 'unpreventable')::int,
    COALESCE(SUM(b.contractual_penalty_rupees), 0)::bigint
  FROM public.chain_sla_breach_events_r2375 b
  GROUP BY COALESCE(b.root_cause_category, 'unknown')
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_root_cause_mix_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_root_cause_mix_r2375() TO authenticated;


-- =========================================================================
-- RPC 6: Negotiation rounds for all open + recent breaches
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_negotiations_r2375()
RETURNS TABLE(
  id uuid,
  breach_id uuid,
  breach_ref text,
  chain_name text,
  round_number int,
  occurred_at timestamptz,
  channel text,
  participant_label text,
  customer_position_rupees bigint,
  our_position_rupees bigint,
  customer_tone text,
  outcome text,
  next_action text,
  next_action_due date,
  logged_by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.breach_id,
    b.breach_ref,
    b.chain_name,
    n.round_number,
    n.occurred_at,
    n.channel,
    n.participant_label,
    n.customer_position_rupees,
    n.our_position_rupees,
    n.customer_tone,
    n.outcome,
    n.next_action,
    n.next_action_due,
    (SELECT p.email FROM public.profiles p WHERE p.id = n.logged_by_profile_id)
  FROM public.chain_sla_breach_negotiations_r2375 n
  JOIN public.chain_sla_breach_events_r2375 b ON b.id = n.breach_id
  WHERE b.status NOT IN ('paid','written_off')
     OR n.occurred_at >= now() - INTERVAL '60 days'
  ORDER BY n.occurred_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_negotiations_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_negotiations_r2375() TO authenticated;


-- =========================================================================
-- RPC 7: Overdue + high-risk action queue
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_chain_sla_action_queue_r2375()
RETURNS TABLE(
  id uuid,
  breach_ref text,
  chain_name text,
  chain_tier text,
  breach_severity text,
  status text,
  contractual_penalty_rupees bigint,
  customer_claimed_penalty_rupees bigint,
  due_date_for_settlement date,
  days_overdue int,
  press_or_social_risk boolean,
  legal_exposure_flag boolean,
  relationship_impact text,
  recommended_action text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.breach_ref,
    b.chain_name,
    b.chain_tier,
    b.breach_severity,
    b.status,
    b.contractual_penalty_rupees,
    b.customer_claimed_penalty_rupees,
    b.due_date_for_settlement,
    CASE
      WHEN b.due_date_for_settlement IS NOT NULL AND b.due_date_for_settlement < CURRENT_DATE
        THEN (CURRENT_DATE - b.due_date_for_settlement)::int
      ELSE 0
    END,
    b.press_or_social_risk,
    b.legal_exposure_flag,
    b.relationship_impact,
    CASE
      WHEN b.legal_exposure_flag THEN 'Loop in counsel today; pause public comms'
      WHEN b.press_or_social_risk THEN 'Pre-empt comms; settle quietly'
      WHEN b.breach_severity = 'catastrophic' THEN 'Founder takes call within 24h'
      WHEN b.due_date_for_settlement IS NOT NULL AND b.due_date_for_settlement < CURRENT_DATE THEN 'Pay or formally extend; do not let it age'
      WHEN b.status = 'open' THEN 'Open negotiation; propose settlement'
      WHEN b.status = 'negotiating' THEN 'Close to signed settlement this week'
      ELSE 'Monitor'
    END
  FROM public.chain_sla_breach_events_r2375 b
  WHERE b.status NOT IN ('paid','written_off')
    AND (
      b.legal_exposure_flag
      OR b.press_or_social_risk
      OR b.breach_severity IN ('major','catastrophic')
      OR (b.due_date_for_settlement IS NOT NULL AND b.due_date_for_settlement < CURRENT_DATE)
      OR b.relationship_impact IN ('damaged','contract_at_risk')
    )
  ORDER BY
    b.legal_exposure_flag DESC,
    b.press_or_social_risk DESC,
    CASE b.breach_severity WHEN 'catastrophic' THEN 0 WHEN 'major' THEN 1 WHEN 'material' THEN 2 ELSE 3 END,
    b.due_date_for_settlement NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_chain_sla_action_queue_r2375() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_chain_sla_action_queue_r2375() TO authenticated;

COMMIT;
