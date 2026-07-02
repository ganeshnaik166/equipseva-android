BEGIN;

-- =====================================================================
-- r1455 — Investor SAFE / Convertible conversion tracker
-- Log SAFEs + convertibles with cap, discount, maturity, trigger events.
-- Surface upcoming maturities + dilution scenarios for founder console.
-- =====================================================================

-- ------------------------------------------------------------------
-- 1. investor_safes — one row per signed SAFE / convertible note
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_safes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_entity_type text NOT NULL DEFAULT 'angel'
    CHECK (investor_entity_type IN ('angel','vc','family_office','syndicate','strategic','employee')),
  instrument_kind text NOT NULL
    CHECK (instrument_kind IN ('safe_post','safe_pre','convertible_note','iSAFE')),
  principal_rupees bigint NOT NULL CHECK (principal_rupees > 0),
  valuation_cap_rupees bigint CHECK (valuation_cap_rupees IS NULL OR valuation_cap_rupees > 0),
  discount_pct numeric(5,2) CHECK (discount_pct IS NULL OR (discount_pct >= 0 AND discount_pct <= 100)),
  mfn_clause boolean NOT NULL DEFAULT false,
  pro_rata_rights boolean NOT NULL DEFAULT false,
  interest_pct numeric(5,2) CHECK (interest_pct IS NULL OR interest_pct >= 0),
  signed_at date NOT NULL,
  maturity_at date,
  trigger_event text NOT NULL DEFAULT 'priced_round'
    CHECK (trigger_event IN ('priced_round','maturity','liquidity','ipo','dissolution')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','converted','repaid','extended','defaulted','cancelled')),
  converted_at timestamptz,
  converted_shares bigint,
  converted_price_per_share_rupees numeric(18,4),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_safes_status ON public.investor_safes(status);
CREATE INDEX IF NOT EXISTS idx_investor_safes_maturity ON public.investor_safes(maturity_at) WHERE status='active';
CREATE INDEX IF NOT EXISTS idx_investor_safes_signed ON public.investor_safes(signed_at DESC);

ALTER TABLE public.investor_safes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='investor_safes' AND policyname='safes_founder_all') THEN
    CREATE POLICY safes_founder_all ON public.investor_safes
      FOR ALL TO authenticated
      USING (public.is_founder())
      WITH CHECK (public.is_founder());
  END IF;
END $$;

-- ------------------------------------------------------------------
-- 2. investor_safe_events — audit log + trigger event history
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_safe_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  safe_id uuid REFERENCES public.investor_safes(id) ON DELETE CASCADE,
  event_kind text NOT NULL
    CHECK (event_kind IN ('signed','amendment','maturity_warning','converted','extended','repaid','defaulted','dilution_modelled','cancelled')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_safe_events_safe ON public.investor_safe_events(safe_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_safe_events_kind ON public.investor_safe_events(event_kind, created_at DESC);

ALTER TABLE public.investor_safe_events ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='investor_safe_events' AND policyname='safe_events_founder_all') THEN
    CREATE POLICY safe_events_founder_all ON public.investor_safe_events
      FOR ALL TO authenticated
      USING (public.is_founder())
      WITH CHECK (public.is_founder());
  END IF;
END $$;

-- =====================================================================
-- READ RPCs — 7 SECDEF STABLE plpgsql, founder-gated
-- =====================================================================

-- 1. headline KPIs
DROP FUNCTION IF EXISTS public.founder_safe_kpis();
CREATE OR REPLACE FUNCTION public.founder_safe_kpis()
RETURNS TABLE (
  total_safes bigint,
  active_safes bigint,
  converted_safes bigint,
  repaid_safes bigint,
  defaulted_safes bigint,
  total_principal_rupees bigint,
  active_principal_rupees bigint,
  converted_principal_rupees bigint,
  weighted_avg_cap_rupees bigint,
  weighted_avg_discount_pct numeric,
  mfn_count bigint,
  pro_rata_count bigint,
  maturing_next_30d bigint,
  maturing_next_90d bigint,
  matured_overdue bigint,
  signed_last_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='active')::bigint,
    COUNT(*) FILTER (WHERE status='converted')::bigint,
    COUNT(*) FILTER (WHERE status='repaid')::bigint,
    COUNT(*) FILTER (WHERE status='defaulted')::bigint,
    COALESCE(SUM(principal_rupees),0)::bigint,
    COALESCE(SUM(principal_rupees) FILTER (WHERE status='active'),0)::bigint,
    COALESCE(SUM(principal_rupees) FILTER (WHERE status='converted'),0)::bigint,
    COALESCE(
      (SUM(valuation_cap_rupees::numeric * principal_rupees) FILTER (WHERE status='active' AND valuation_cap_rupees IS NOT NULL))
      / NULLIF(SUM(principal_rupees) FILTER (WHERE status='active' AND valuation_cap_rupees IS NOT NULL),0)
    ,0)::bigint,
    COALESCE(
      (SUM(discount_pct * principal_rupees) FILTER (WHERE status='active' AND discount_pct IS NOT NULL))
      / NULLIF(SUM(principal_rupees) FILTER (WHERE status='active' AND discount_pct IS NOT NULL),0)
    ,0)::numeric,
    COUNT(*) FILTER (WHERE mfn_clause AND status='active')::bigint,
    COUNT(*) FILTER (WHERE pro_rata_rights AND status='active')::bigint,
    COUNT(*) FILTER (WHERE status='active' AND maturity_at IS NOT NULL AND maturity_at <= (CURRENT_DATE + INTERVAL '30 days') AND maturity_at >= CURRENT_DATE)::bigint,
    COUNT(*) FILTER (WHERE status='active' AND maturity_at IS NOT NULL AND maturity_at <= (CURRENT_DATE + INTERVAL '90 days') AND maturity_at >= CURRENT_DATE)::bigint,
    COUNT(*) FILTER (WHERE status='active' AND maturity_at IS NOT NULL AND maturity_at < CURRENT_DATE)::bigint,
    COUNT(*) FILTER (WHERE signed_at >= CURRENT_DATE - INTERVAL '90 days')::bigint
  FROM investor_safes;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_kpis() TO authenticated;

-- 2. all SAFEs ranked by principal
DROP FUNCTION IF EXISTS public.founder_safe_list();
CREATE OR REPLACE FUNCTION public.founder_safe_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  instrument_kind text,
  principal_rupees bigint,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  signed_at date,
  maturity_at date,
  status text,
  days_to_maturity int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.instrument_kind, s.principal_rupees,
         s.valuation_cap_rupees, s.discount_pct, s.signed_at, s.maturity_at, s.status,
         CASE WHEN s.maturity_at IS NULL THEN NULL ELSE (s.maturity_at - CURRENT_DATE)::int END
  FROM investor_safes s
  ORDER BY s.principal_rupees DESC;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_list() TO authenticated;

-- 3. upcoming maturities (next 180d) + overdue
DROP FUNCTION IF EXISTS public.founder_safe_maturity_calendar();
CREATE OR REPLACE FUNCTION public.founder_safe_maturity_calendar()
RETURNS TABLE (
  id uuid,
  investor_name text,
  principal_rupees bigint,
  maturity_at date,
  days_to_maturity int,
  bucket text,
  trigger_event text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.principal_rupees, s.maturity_at,
         (s.maturity_at - CURRENT_DATE)::int AS days_to_maturity,
         CASE
           WHEN s.maturity_at < CURRENT_DATE THEN 'overdue'
           WHEN s.maturity_at <= CURRENT_DATE + INTERVAL '30 days' THEN '30d'
           WHEN s.maturity_at <= CURRENT_DATE + INTERVAL '90 days' THEN '90d'
           ELSE '180d'
         END,
         s.trigger_event
  FROM investor_safes s
  WHERE s.status = 'active'
    AND s.maturity_at IS NOT NULL
    AND s.maturity_at <= CURRENT_DATE + INTERVAL '180 days'
  ORDER BY s.maturity_at ASC;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_maturity_calendar() TO authenticated;

-- 4. dilution scenario @ priced-round valuation (param-free preview)
DROP FUNCTION IF EXISTS public.founder_safe_dilution_scenarios();
CREATE OR REPLACE FUNCTION public.founder_safe_dilution_scenarios()
RETURNS TABLE (
  scenario_label text,
  next_round_valuation_rupees bigint,
  total_safe_principal_rupees bigint,
  weighted_conversion_price_rupees numeric,
  est_safe_dilution_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_principal bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(principal_rupees),0) INTO v_principal FROM investor_safes WHERE status='active';
  RETURN QUERY
  SELECT * FROM (VALUES
    ('priced_5cr',   500000000::bigint,  v_principal, (v_principal::numeric / NULLIF(500000000,0))::numeric,  ROUND((v_principal::numeric / NULLIF(500000000,0)) * 100, 2)),
    ('priced_10cr',  1000000000::bigint, v_principal, (v_principal::numeric / NULLIF(1000000000,0))::numeric, ROUND((v_principal::numeric / NULLIF(1000000000,0)) * 100, 2)),
    ('priced_25cr',  2500000000::bigint, v_principal, (v_principal::numeric / NULLIF(2500000000,0))::numeric, ROUND((v_principal::numeric / NULLIF(2500000000,0)) * 100, 2)),
    ('priced_50cr',  5000000000::bigint, v_principal, (v_principal::numeric / NULLIF(5000000000,0))::numeric, ROUND((v_principal::numeric / NULLIF(5000000000,0)) * 100, 2)),
    ('priced_100cr', 10000000000::bigint,v_principal, (v_principal::numeric / NULLIF(10000000000,0))::numeric,ROUND((v_principal::numeric / NULLIF(10000000000,0)) * 100, 2))
  ) AS t(scenario_label, next_round_valuation_rupees, total_safe_principal_rupees, weighted_conversion_price_rupees, est_safe_dilution_pct);
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_dilution_scenarios() TO authenticated;

-- 5. cap-stack concentration by investor
DROP FUNCTION IF EXISTS public.founder_safe_top_investors();
CREATE OR REPLACE FUNCTION public.founder_safe_top_investors()
RETURNS TABLE (
  investor_name text,
  safe_count bigint,
  total_principal_rupees bigint,
  active_principal_rupees bigint,
  share_of_active_pct numeric,
  has_mfn boolean,
  has_pro_rata boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_active bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(principal_rupees),0) INTO v_total_active FROM investor_safes WHERE status='active';
  RETURN QUERY
  SELECT s.investor_name,
         COUNT(*)::bigint,
         COALESCE(SUM(s.principal_rupees),0)::bigint,
         COALESCE(SUM(s.principal_rupees) FILTER (WHERE s.status='active'),0)::bigint,
         CASE WHEN v_total_active = 0 THEN 0
              ELSE ROUND((COALESCE(SUM(s.principal_rupees) FILTER (WHERE s.status='active'),0)::numeric / v_total_active) * 100, 2)
         END,
         bool_or(s.mfn_clause),
         bool_or(s.pro_rata_rights)
  FROM investor_safes s
  GROUP BY s.investor_name
  ORDER BY SUM(s.principal_rupees) DESC NULLS LAST
  LIMIT 50;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_top_investors() TO authenticated;

-- 6. recent event timeline
DROP FUNCTION IF EXISTS public.founder_safe_event_timeline();
CREATE OR REPLACE FUNCTION public.founder_safe_event_timeline()
RETURNS TABLE (
  id uuid,
  safe_id uuid,
  investor_name text,
  event_kind text,
  payload jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.safe_id, s.investor_name, e.event_kind, e.payload, e.created_at
  FROM investor_safe_events e
  LEFT JOIN investor_safes s ON s.id = e.safe_id
  ORDER BY e.created_at DESC
  LIMIT 200;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_event_timeline() TO authenticated;

-- 7. instrument-kind breakdown
DROP FUNCTION IF EXISTS public.founder_safe_instrument_mix();
CREATE OR REPLACE FUNCTION public.founder_safe_instrument_mix()
RETURNS TABLE (
  instrument_kind text,
  cnt bigint,
  total_principal_rupees bigint,
  avg_cap_rupees bigint,
  avg_discount_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.instrument_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(s.principal_rupees),0)::bigint,
         COALESCE(AVG(s.valuation_cap_rupees),0)::bigint,
         COALESCE(AVG(s.discount_pct),0)::numeric
  FROM investor_safes s
  GROUP BY s.instrument_kind
  ORDER BY SUM(s.principal_rupees) DESC NULLS LAST;
END; $$;
GRANT EXECUTE ON FUNCTION public.founder_safe_instrument_mix() TO authenticated;

-- =====================================================================
-- WRITE helpers — log_founder_* VOLATILE SECDEF plpgsql
-- =====================================================================

-- helper 1: log SAFE
DROP FUNCTION IF EXISTS public.log_founder_safe(text, text, text, bigint, bigint, numeric, date, date, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_safe(
  p_investor_name text,
  p_investor_entity_type text,
  p_instrument_kind text,
  p_principal_rupees bigint,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric,
  p_signed_at date,
  p_maturity_at date,
  p_trigger_event text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_safes (
    investor_name, investor_entity_type, instrument_kind, principal_rupees,
    valuation_cap_rupees, discount_pct, signed_at, maturity_at, trigger_event, notes
  ) VALUES (
    p_investor_name, p_investor_entity_type, p_instrument_kind, p_principal_rupees,
    p_valuation_cap_rupees, p_discount_pct, p_signed_at, p_maturity_at,
    COALESCE(p_trigger_event,'priced_round'), p_notes
  ) RETURNING id INTO v_id;
  INSERT INTO investor_safe_events (safe_id, event_kind, payload, created_by)
  VALUES (v_id, 'signed', jsonb_build_object('principal', p_principal_rupees, 'cap', p_valuation_cap_rupees), auth.uid());
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.log_founder_safe(text, text, text, bigint, bigint, numeric, date, date, text, text) TO authenticated;

-- helper 2: mark converted
DROP FUNCTION IF EXISTS public.log_founder_safe_converted(uuid, bigint, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_safe_converted(
  p_safe_id uuid,
  p_shares bigint,
  p_price_per_share_rupees numeric
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_safes
     SET status='converted',
         converted_at = now(),
         converted_shares = p_shares,
         converted_price_per_share_rupees = p_price_per_share_rupees,
         updated_at = now()
   WHERE id = p_safe_id;
  INSERT INTO investor_safe_events (safe_id, event_kind, payload, created_by)
  VALUES (p_safe_id, 'converted', jsonb_build_object('shares', p_shares, 'pps', p_price_per_share_rupees), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION public.log_founder_safe_converted(uuid, bigint, numeric) TO authenticated;

-- helper 3: extend maturity
DROP FUNCTION IF EXISTS public.log_founder_safe_extension(uuid, date, text);
CREATE OR REPLACE FUNCTION public.log_founder_safe_extension(
  p_safe_id uuid,
  p_new_maturity date,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_safes
     SET maturity_at = p_new_maturity,
         status = 'extended',
         updated_at = now()
   WHERE id = p_safe_id;
  INSERT INTO investor_safe_events (safe_id, event_kind, payload, created_by)
  VALUES (p_safe_id, 'extended', jsonb_build_object('new_maturity', p_new_maturity, 'reason', p_reason), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION public.log_founder_safe_extension(uuid, date, text) TO authenticated;

-- helper 4: cancel / void
DROP FUNCTION IF EXISTS public.log_founder_safe_cancelled(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_safe_cancelled(
  p_safe_id uuid,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_safes
     SET status='cancelled', updated_at = now()
   WHERE id = p_safe_id;
  INSERT INTO investor_safe_events (safe_id, event_kind, payload, created_by)
  VALUES (p_safe_id, 'cancelled', jsonb_build_object('reason', p_reason), auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION public.log_founder_safe_cancelled(uuid, text) TO authenticated;

COMMIT;