-- Round 2436: customer-amc-upsell-opportunity-scanner
-- Hospital × current AMC × upsell target × probability × incremental ARR × owner

CREATE TABLE IF NOT EXISTS public.amc_upsell_opportunities_r2436 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_amc_tier text NOT NULL CHECK (current_amc_tier IN ('bronze','silver','gold','platinum')),
  upsell_target_tier text NOT NULL CHECK (upsell_target_tier IN ('silver','gold','platinum','diamond')),
  upsell_probability_pct int NOT NULL CHECK (upsell_probability_pct BETWEEN 0 AND 100),
  incremental_arr_rupees bigint NOT NULL CHECK (incremental_arr_rupees >= 0),
  signal_kind text NOT NULL CHECK (signal_kind IN ('usage_growth','equipment_added','contract_expiring','csat_drop_recovery','upsell_ask','cross_sell_match')),
  signal_strength text NOT NULL CHECK (signal_strength IN ('low','medium','high','critical')),
  proposed_action text NOT NULL,
  owner_email text NOT NULL,
  action_due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','contacted','quoted','won','lost','dropped')),
  close_reason text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_amc_upsell_opps_r2436_status ON public.amc_upsell_opportunities_r2436(status);
CREATE INDEX IF NOT EXISTS idx_amc_upsell_opps_r2436_owner ON public.amc_upsell_opportunities_r2436(owner_email);
CREATE INDEX IF NOT EXISTS idx_amc_upsell_opps_r2436_due ON public.amc_upsell_opportunities_r2436(action_due_at);

ALTER TABLE public.amc_upsell_opportunities_r2436 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.amc_upsell_opportunities_r2436;
CREATE POLICY founder_all ON public.amc_upsell_opportunities_r2436
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.amc_upsell_signals_log_r2436 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  opportunity_id uuid NOT NULL REFERENCES public.amc_upsell_opportunities_r2436(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  signal_kind text NOT NULL,
  signal_value text NOT NULL,
  signal_score_delta int NOT NULL DEFAULT 0,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_amc_upsell_signals_log_r2436_opp ON public.amc_upsell_signals_log_r2436(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_amc_upsell_signals_log_r2436_observed ON public.amc_upsell_signals_log_r2436(observed_at);

ALTER TABLE public.amc_upsell_signals_log_r2436 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.amc_upsell_signals_log_r2436;
CREATE POLICY founder_all ON public.amc_upsell_signals_log_r2436
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_h4 uuid;
  v_opp1 uuid;
  v_opp2 uuid;
  v_opp3 uuid;
  v_opp4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h4 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_h1 IS NULL THEN
    SELECT id INTO v_h1 FROM public.profiles ORDER BY created_at LIMIT 1;
  END IF;
  IF v_h2 IS NULL THEN v_h2 := v_h1; END IF;
  IF v_h3 IS NULL THEN v_h3 := v_h1; END IF;
  IF v_h4 IS NULL THEN v_h4 := v_h1; END IF;

  IF v_h1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.amc_upsell_opportunities_r2436 (hospital_user_id, current_amc_tier, upsell_target_tier, upsell_probability_pct, incremental_arr_rupees, signal_kind, signal_strength, proposed_action, owner_email, action_due_at, status, notes)
  VALUES (v_h1, 'silver', 'gold', 75, 240000, 'usage_growth', 'high', 'Schedule QBR + present gold pack', 'sales-lead@equipseva.in', now() + interval '3 days', 'open', '40% MoM ticket volume')
  RETURNING id INTO v_opp1;

  INSERT INTO public.amc_upsell_opportunities_r2436 (hospital_user_id, current_amc_tier, upsell_target_tier, upsell_probability_pct, incremental_arr_rupees, signal_kind, signal_strength, proposed_action, owner_email, action_due_at, status, notes)
  VALUES (v_h2, 'gold', 'platinum', 55, 480000, 'equipment_added', 'medium', 'Send platinum quote + onsite engineer SLA', 'amit@equipseva.in', now() + interval '7 days', 'contacted', '3 new ventilators added')
  RETURNING id INTO v_opp2;

  INSERT INTO public.amc_upsell_opportunities_r2436 (hospital_user_id, current_amc_tier, upsell_target_tier, upsell_probability_pct, incremental_arr_rupees, signal_kind, signal_strength, proposed_action, owner_email, action_due_at, status, notes)
  VALUES (v_h3, 'bronze', 'silver', 90, 96000, 'contract_expiring', 'critical', 'Renewal call before expiry', 'priya@equipseva.in', now() + interval '1 day', 'quoted', 'Renewal window opens')
  RETURNING id INTO v_opp3;

  INSERT INTO public.amc_upsell_opportunities_r2436 (hospital_user_id, current_amc_tier, upsell_target_tier, upsell_probability_pct, incremental_arr_rupees, signal_kind, signal_strength, proposed_action, owner_email, action_due_at, status, close_reason, notes)
  VALUES (v_h4, 'platinum', 'diamond', 30, 720000, 'upsell_ask', 'low', 'Awaiting board approval', 'sales-lead@equipseva.in', now() + interval '14 days', 'won', NULL, 'CFO greenlit')
  RETURNING id INTO v_opp4;

  INSERT INTO public.amc_upsell_signals_log_r2436 (opportunity_id, observed_at, signal_kind, signal_value, signal_score_delta, notes) VALUES
    (v_opp1, now() - interval '5 days', 'usage_growth', '42% MoM', 15, 'ticket volume spike'),
    (v_opp1, now() - interval '2 days', 'csat_drop_recovery', '4.6 -> 4.8', 10, 'NPS recovered after onsite'),
    (v_opp2, now() - interval '6 days', 'equipment_added', '3 ventilators', 20, 'new ICU wing'),
    (v_opp3, now() - interval '10 days', 'contract_expiring', '14 days left', 25, 'renewal trigger'),
    (v_opp4, now() - interval '1 day', 'upsell_ask', 'CFO call', 30, 'Diamond pack requested');
END
$seed$ LANGUAGE plpgsql;

-- RPC 1: list_opportunities_r2436
CREATE OR REPLACE FUNCTION public.list_opportunities_r2436()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  current_amc_tier text,
  upsell_target_tier text,
  upsell_probability_pct int,
  incremental_arr_rupees bigint,
  signal_kind text,
  signal_strength text,
  proposed_action text,
  owner_email text,
  action_due_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, p.email, o.current_amc_tier, o.upsell_target_tier, o.upsell_probability_pct, o.incremental_arr_rupees,
         o.signal_kind, o.signal_strength, o.proposed_action, o.owner_email, o.action_due_at, o.status, o.notes
  FROM public.amc_upsell_opportunities_r2436 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  ORDER BY o.upsell_probability_pct DESC, o.incremental_arr_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_opportunities_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_opportunities_r2436() TO authenticated;

-- RPC 2: list_signals_log_r2436
CREATE OR REPLACE FUNCTION public.list_signals_log_r2436()
RETURNS TABLE (
  id uuid,
  opportunity_id uuid,
  hospital_email text,
  observed_at timestamptz,
  signal_kind text,
  signal_value text,
  signal_score_delta int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.opportunity_id, p.email, s.observed_at, s.signal_kind, s.signal_value, s.signal_score_delta, s.notes
  FROM public.amc_upsell_signals_log_r2436 s
  JOIN public.amc_upsell_opportunities_r2436 o ON o.id = s.opportunity_id
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  ORDER BY s.observed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_signals_log_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_signals_log_r2436() TO authenticated;

-- RPC 3: top_arr_opportunities_r2436
CREATE OR REPLACE FUNCTION public.top_arr_opportunities_r2436()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  current_amc_tier text,
  upsell_target_tier text,
  incremental_arr_rupees bigint,
  weighted_arr_rupees bigint,
  upsell_probability_pct int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, p.email, o.current_amc_tier, o.upsell_target_tier, o.incremental_arr_rupees,
         (o.incremental_arr_rupees * o.upsell_probability_pct / 100)::bigint AS weighted_arr_rupees,
         o.upsell_probability_pct, o.status
  FROM public.amc_upsell_opportunities_r2436 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  WHERE o.status NOT IN ('lost','dropped')
  ORDER BY weighted_arr_rupees DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_arr_opportunities_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_opportunities_r2436() TO authenticated;

-- RPC 4: status_funnel_r2436
CREATE OR REPLACE FUNCTION public.status_funnel_r2436()
RETURNS TABLE (
  status text,
  opp_count bigint,
  total_arr_rupees bigint,
  weighted_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.status,
         COUNT(*)::bigint AS opp_count,
         COALESCE(SUM(o.incremental_arr_rupees), 0)::bigint AS total_arr_rupees,
         COALESCE(SUM(o.incremental_arr_rupees * o.upsell_probability_pct / 100), 0)::bigint AS weighted_arr_rupees
  FROM public.amc_upsell_opportunities_r2436 o
  GROUP BY o.status
  ORDER BY weighted_arr_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2436() TO authenticated;

-- RPC 5: signal_strength_breakdown_r2436
CREATE OR REPLACE FUNCTION public.signal_strength_breakdown_r2436()
RETURNS TABLE (
  signal_strength text,
  opp_count bigint,
  avg_probability_pct numeric,
  total_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.signal_strength,
         COUNT(*)::bigint AS opp_count,
         ROUND(AVG(o.upsell_probability_pct)::numeric, 1) AS avg_probability_pct,
         COALESCE(SUM(o.incremental_arr_rupees), 0)::bigint AS total_arr_rupees
  FROM public.amc_upsell_opportunities_r2436 o
  GROUP BY o.signal_strength
  ORDER BY
    CASE o.signal_strength
      WHEN 'critical' THEN 0
      WHEN 'high' THEN 1
      WHEN 'medium' THEN 2
      WHEN 'low' THEN 3
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.signal_strength_breakdown_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signal_strength_breakdown_r2436() TO authenticated;

-- RPC 6: owner_load_r2436
CREATE OR REPLACE FUNCTION public.owner_load_r2436()
RETURNS TABLE (
  owner_email text,
  open_opps bigint,
  total_opps bigint,
  pipeline_arr_rupees bigint,
  weighted_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.owner_email,
         COUNT(*) FILTER (WHERE o.status IN ('open','contacted','quoted'))::bigint AS open_opps,
         COUNT(*)::bigint AS total_opps,
         COALESCE(SUM(o.incremental_arr_rupees) FILTER (WHERE o.status NOT IN ('lost','dropped')), 0)::bigint AS pipeline_arr_rupees,
         COALESCE(SUM(o.incremental_arr_rupees * o.upsell_probability_pct / 100) FILTER (WHERE o.status NOT IN ('lost','dropped')), 0)::bigint AS weighted_arr_rupees
  FROM public.amc_upsell_opportunities_r2436 o
  GROUP BY o.owner_email
  ORDER BY weighted_arr_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2436() TO authenticated;

-- RPC 7: this_week_action_calendar_r2436
CREATE OR REPLACE FUNCTION public.this_week_action_calendar_r2436()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  proposed_action text,
  owner_email text,
  action_due_at timestamptz,
  signal_strength text,
  upsell_probability_pct int,
  incremental_arr_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, p.email, o.proposed_action, o.owner_email, o.action_due_at, o.signal_strength,
         o.upsell_probability_pct, o.incremental_arr_rupees, o.status
  FROM public.amc_upsell_opportunities_r2436 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  WHERE o.action_due_at IS NOT NULL
    AND o.action_due_at >= now() - interval '1 day'
    AND o.action_due_at <= now() + interval '7 days'
    AND o.status NOT IN ('lost','dropped','won')
  ORDER BY o.action_due_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.this_week_action_calendar_r2436() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_action_calendar_r2436() TO authenticated;
