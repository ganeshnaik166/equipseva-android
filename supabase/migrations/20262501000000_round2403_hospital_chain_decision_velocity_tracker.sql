BEGIN;

-- Table 1: chain RFP cycles
CREATE TABLE IF NOT EXISTS public.chain_rfp_cycles_r2403 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier_1','tier_2','tier_3','tier_4')),
  hospital_count integer NOT NULL DEFAULT 0,
  rfp_issued_at timestamptz NOT NULL,
  proposal_submitted_at timestamptz,
  shortlist_notified_at timestamptz,
  negotiation_started_at timestamptz,
  contract_signed_at timestamptz,
  contract_value_rupees bigint,
  outcome text NOT NULL DEFAULT 'in_flight' CHECK (outcome IN ('in_flight','won','lost','stalled','withdrawn')),
  bottleneck_owner text CHECK (bottleneck_owner IN ('us_sales','us_legal','us_finance','us_engineering','chain_procurement','chain_clinical','chain_legal','chain_finance','chain_board','none')),
  bottleneck_notes text,
  our_days_active integer NOT NULL DEFAULT 0,
  their_days_active integer NOT NULL DEFAULT 0,
  recorded_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_rfp_cycles_r2403_chain ON public.chain_rfp_cycles_r2403(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_rfp_cycles_r2403_outcome ON public.chain_rfp_cycles_r2403(outcome);
CREATE INDEX IF NOT EXISTS idx_chain_rfp_cycles_r2403_issued ON public.chain_rfp_cycles_r2403(rfp_issued_at DESC);

ALTER TABLE public.chain_rfp_cycles_r2403 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_rfp_cycles_r2403;
CREATE POLICY founder_all ON public.chain_rfp_cycles_r2403 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Table 2: stage transitions (event log)
CREATE TABLE IF NOT EXISTS public.chain_rfp_stage_events_r2403 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.chain_rfp_cycles_r2403(id) ON DELETE CASCADE,
  stage text NOT NULL CHECK (stage IN ('rfp_issued','proposal_submitted','shortlist_notified','negotiation_started','contract_signed','stalled','lost','withdrawn')),
  occurred_at timestamptz NOT NULL,
  owner_side text NOT NULL CHECK (owner_side IN ('us','chain','both')),
  owner_role text,
  dwell_days numeric,
  notes text,
  logged_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_rfp_stage_events_r2403_cycle ON public.chain_rfp_stage_events_r2403(cycle_id, occurred_at);

ALTER TABLE public.chain_rfp_stage_events_r2403 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_rfp_stage_events_r2403;
CREATE POLICY founder_all ON public.chain_rfp_stage_events_r2403 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list active cycles
CREATE OR REPLACE FUNCTION public.fn_r2403_list_cycles()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  hospital_count integer,
  rfp_issued_at timestamptz,
  contract_signed_at timestamptz,
  total_days integer,
  our_days_active integer,
  their_days_active integer,
  outcome text,
  bottleneck_owner text,
  contract_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.chain_tier, c.hospital_count, c.rfp_issued_at, c.contract_signed_at,
    CASE
      WHEN c.contract_signed_at IS NOT NULL THEN EXTRACT(DAY FROM c.contract_signed_at - c.rfp_issued_at)::integer
      ELSE EXTRACT(DAY FROM now() - c.rfp_issued_at)::integer
    END AS total_days,
    c.our_days_active, c.their_days_active, c.outcome, c.bottleneck_owner, c.contract_value_rupees
  FROM public.chain_rfp_cycles_r2403 c
  ORDER BY c.rfp_issued_at DESC
  LIMIT 200;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_list_cycles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_list_cycles() TO authenticated;

-- RPC 2: bottleneck breakdown
CREATE OR REPLACE FUNCTION public.fn_r2403_bottleneck_breakdown()
RETURNS TABLE (
  bottleneck_owner text,
  active_cycles bigint,
  avg_dwell_days numeric,
  pipeline_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(c.bottleneck_owner,'none') AS bottleneck_owner,
    COUNT(*)::bigint AS active_cycles,
    ROUND(AVG(EXTRACT(DAY FROM now() - c.rfp_issued_at))::numeric, 1) AS avg_dwell_days,
    COALESCE(SUM(c.contract_value_rupees),0)::bigint AS pipeline_value_rupees
  FROM public.chain_rfp_cycles_r2403 c
  WHERE c.outcome = 'in_flight'
  GROUP BY COALESCE(c.bottleneck_owner,'none')
  ORDER BY active_cycles DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_bottleneck_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_bottleneck_breakdown() TO authenticated;

-- RPC 3: tier velocity averages
CREATE OR REPLACE FUNCTION public.fn_r2403_tier_velocity()
RETURNS TABLE (
  chain_tier text,
  cycles_won bigint,
  avg_days_to_sign numeric,
  avg_our_days numeric,
  avg_their_days numeric,
  win_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_tier,
    COUNT(*) FILTER (WHERE c.outcome = 'won')::bigint AS cycles_won,
    ROUND(AVG(EXTRACT(DAY FROM c.contract_signed_at - c.rfp_issued_at)) FILTER (WHERE c.outcome='won')::numeric, 1) AS avg_days_to_sign,
    ROUND(AVG(c.our_days_active) FILTER (WHERE c.outcome='won')::numeric, 1) AS avg_our_days,
    ROUND(AVG(c.their_days_active) FILTER (WHERE c.outcome='won')::numeric, 1) AS avg_their_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.outcome='won') / NULLIF(COUNT(*) FILTER (WHERE c.outcome IN ('won','lost')),0), 1) AS win_rate_pct
  FROM public.chain_rfp_cycles_r2403 c
  GROUP BY c.chain_tier
  ORDER BY c.chain_tier;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_tier_velocity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_tier_velocity() TO authenticated;

-- RPC 4: stuck cycles (>30 days dwell on our side)
CREATE OR REPLACE FUNCTION public.fn_r2403_stuck_cycles()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  bottleneck_owner text,
  our_days_active integer,
  their_days_active integer,
  total_days integer,
  contract_value_rupees bigint,
  bottleneck_notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.chain_tier, c.bottleneck_owner, c.our_days_active, c.their_days_active,
    EXTRACT(DAY FROM now() - c.rfp_issued_at)::integer AS total_days,
    c.contract_value_rupees, c.bottleneck_notes
  FROM public.chain_rfp_cycles_r2403 c
  WHERE c.outcome = 'in_flight'
    AND (c.our_days_active >= 30 OR c.their_days_active >= 60)
  ORDER BY c.our_days_active DESC, c.their_days_active DESC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_stuck_cycles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_stuck_cycles() TO authenticated;

-- RPC 5: stage dwell averages (where time is spent)
CREATE OR REPLACE FUNCTION public.fn_r2403_stage_dwell()
RETURNS TABLE (
  stage text,
  events_count bigint,
  avg_dwell_days numeric,
  us_owned_pct numeric,
  chain_owned_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.stage,
    COUNT(*)::bigint AS events_count,
    ROUND(AVG(e.dwell_days)::numeric, 1) AS avg_dwell_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE e.owner_side='us') / NULLIF(COUNT(*),0), 1) AS us_owned_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE e.owner_side='chain') / NULLIF(COUNT(*),0), 1) AS chain_owned_pct
  FROM public.chain_rfp_stage_events_r2403 e
  GROUP BY e.stage
  ORDER BY avg_dwell_days DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_stage_dwell() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_stage_dwell() TO authenticated;

-- RPC 6: monthly closed-won trend
CREATE OR REPLACE FUNCTION public.fn_r2403_monthly_wins()
RETURNS TABLE (
  month_start date,
  wins bigint,
  total_value_rupees bigint,
  avg_days_to_sign numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', c.contract_signed_at)::date AS month_start,
    COUNT(*)::bigint AS wins,
    COALESCE(SUM(c.contract_value_rupees),0)::bigint AS total_value_rupees,
    ROUND(AVG(EXTRACT(DAY FROM c.contract_signed_at - c.rfp_issued_at))::numeric, 1) AS avg_days_to_sign
  FROM public.chain_rfp_cycles_r2403 c
  WHERE c.outcome = 'won' AND c.contract_signed_at IS NOT NULL
  GROUP BY date_trunc('month', c.contract_signed_at)
  ORDER BY month_start DESC
  LIMIT 12;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_monthly_wins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_monthly_wins() TO authenticated;

-- RPC 7: summary kpis
CREATE OR REPLACE FUNCTION public.fn_r2403_summary()
RETURNS TABLE (
  active_cycles bigint,
  won_last_90d bigint,
  lost_last_90d bigint,
  avg_cycle_days numeric,
  pipeline_value_rupees bigint,
  our_share_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE outcome = 'in_flight')::bigint AS active_cycles,
    COUNT(*) FILTER (WHERE outcome = 'won' AND contract_signed_at >= now() - interval '90 days')::bigint AS won_last_90d,
    COUNT(*) FILTER (WHERE outcome = 'lost' AND updated_at >= now() - interval '90 days')::bigint AS lost_last_90d,
    ROUND(AVG(EXTRACT(DAY FROM contract_signed_at - rfp_issued_at)) FILTER (WHERE outcome='won')::numeric, 1) AS avg_cycle_days,
    COALESCE(SUM(contract_value_rupees) FILTER (WHERE outcome='in_flight'),0)::bigint AS pipeline_value_rupees,
    ROUND(100.0 * SUM(our_days_active) / NULLIF(SUM(our_days_active) + SUM(their_days_active), 0), 1) AS our_share_pct
  FROM public.chain_rfp_cycles_r2403;
END;
$$;
REVOKE ALL ON FUNCTION public.fn_r2403_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2403_summary() TO authenticated;

COMMIT;
