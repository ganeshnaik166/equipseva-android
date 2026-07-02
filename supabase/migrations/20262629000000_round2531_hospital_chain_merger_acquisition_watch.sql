-- Round 2531: Hospital Chain Merger & Acquisition Watch
-- chain × M&A signals × ownership change × deal impact × renegotiation needs

CREATE TABLE IF NOT EXISTS public.chain_ma_signals_r2531 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  signal_at timestamptz NOT NULL DEFAULT now(),
  signal_kind text NOT NULL CHECK (signal_kind IN ('ipo_chatter','private_equity','strategic_acquirer','board_change','cfo_change','divestment')),
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','moderate','strong','confirmed')),
  source text,
  observed_by_email text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','monitoring','escalated','closed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.ma_renegotiation_plans_r2531 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  signal_id uuid NOT NULL REFERENCES public.chain_ma_signals_r2531(id) ON DELETE CASCADE,
  renegotiation_kind text NOT NULL CHECK (renegotiation_kind IN ('contract_review','price_lock','ownership_clause','walkaway_option','expand_scope')),
  expected_outcome_md text,
  owner_email text,
  action_due_at timestamptz,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text
);

ALTER TABLE public.chain_ma_signals_r2531 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ma_renegotiation_plans_r2531 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_ma_signals_r2531;
CREATE POLICY founder_all ON public.chain_ma_signals_r2531 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.ma_renegotiation_plans_r2531;
CREATE POLICY founder_all ON public.ma_renegotiation_plans_r2531 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed M&A signals
INSERT INTO public.chain_ma_signals_r2531 (chain_name, signal_at, signal_kind, signal_strength, source, observed_by_email, owner_email, status, notes) VALUES
  ('Apollo Group', '2026-05-10T09:00:00+05:30'::timestamptz, 'ipo_chatter', 'moderate', 'Mint article + banker tipoff', 'analyst@equipseva.example', 'founder@equipseva.example', 'monitoring', 'Pre-IPO chatter for hospitals arm; expect Q3 filing'),
  ('Fortis Chain', '2026-05-18T11:00:00+05:30'::timestamptz, 'private_equity', 'strong', 'Reuters - KKR stake talks', 'analyst@equipseva.example', 'founder@equipseva.example', 'escalated', 'KKR reportedly buying 26% stake; impacts our 3-yr AMC'),
  ('Manipal Network', '2026-04-22T14:00:00+05:30'::timestamptz, 'strategic_acquirer', 'confirmed', 'Press release', 'analyst@equipseva.example', 'cs@equipseva.example', 'escalated', 'Confirmed acquired AMRI Hospitals - 1500 beds added'),
  ('Max Healthcare', '2026-05-25T10:00:00+05:30'::timestamptz, 'cfo_change', 'confirmed', 'LinkedIn announcement', 'analyst@equipseva.example', 'cs@equipseva.example', 'open', 'New CFO ex-Aster; renegotiation risk on annual rate card'),
  ('Yashoda Hospitals', '2026-03-15T09:00:00+05:30'::timestamptz, 'board_change', 'weak', 'ROC filing trail', 'analyst@equipseva.example', 'founder@equipseva.example', 'closed', '2 new independent directors; no commercial impact');

-- Seed renegotiation plans
INSERT INTO public.ma_renegotiation_plans_r2531 (signal_id, renegotiation_kind, expected_outcome_md, owner_email, action_due_at, status, outcome, notes)
SELECT id, 'price_lock', 'Lock current AMC rates until 2028 before IPO listing premium hits', 'founder@equipseva.example', '2026-07-15T12:00:00+05:30'::timestamptz, 'in_progress', 'pending', 'Pre-IPO leverage to lock 3yr rate'
FROM public.chain_ma_signals_r2531 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.ma_renegotiation_plans_r2531 (signal_id, renegotiation_kind, expected_outcome_md, owner_email, action_due_at, status, outcome, notes)
SELECT id, 'ownership_clause', 'Trigger change-of-control review with KKR-side procurement', 'founder@equipseva.example', '2026-06-30T12:00:00+05:30'::timestamptz, 'open', 'pending', 'Activate change-of-control clause review'
FROM public.chain_ma_signals_r2531 WHERE chain_name='Fortis Chain' LIMIT 1;

INSERT INTO public.ma_renegotiation_plans_r2531 (signal_id, renegotiation_kind, expected_outcome_md, owner_email, action_due_at, status, outcome, notes)
SELECT id, 'expand_scope', 'Expand AMC to cover newly acquired AMRI 1500 beds', 'cs@equipseva.example', '2026-07-01T12:00:00+05:30'::timestamptz, 'in_progress', 'positive', 'AMRI integration window - land grab'
FROM public.chain_ma_signals_r2531 WHERE chain_name='Manipal Network' LIMIT 1;

INSERT INTO public.ma_renegotiation_plans_r2531 (signal_id, renegotiation_kind, expected_outcome_md, owner_email, action_due_at, status, outcome, notes)
SELECT id, 'contract_review', 'Schedule intro meet with new CFO before rate card cycle', 'cs@equipseva.example', '2026-06-25T12:00:00+05:30'::timestamptz, 'open', 'pending', 'New CFO relationship hygiene'
FROM public.chain_ma_signals_r2531 WHERE chain_name='Max Healthcare' LIMIT 1;

INSERT INTO public.ma_renegotiation_plans_r2531 (signal_id, renegotiation_kind, expected_outcome_md, owner_email, action_due_at, status, outcome, notes)
SELECT id, 'walkaway_option', 'Document walkaway clauses if board pivots away from premium service', 'founder@equipseva.example', '2026-04-15T12:00:00+05:30'::timestamptz, 'done', 'neutral', 'Walkaway clauses logged; no action needed'
FROM public.chain_ma_signals_r2531 WHERE chain_name='Yashoda Hospitals' LIMIT 1;

-- RPC 1: list M&A signals
CREATE OR REPLACE FUNCTION public.list_ma_signals_r2531()
RETURNS TABLE(id uuid, chain_name text, signal_at timestamptz, signal_kind text, signal_strength text, source text, observed_by_email text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.signal_at, s.signal_kind, s.signal_strength, s.source, s.observed_by_email, s.owner_email, s.status, s.notes
    FROM public.chain_ma_signals_r2531 s
    ORDER BY s.signal_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_ma_signals_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ma_signals_r2531() TO authenticated;

-- RPC 2: list renegotiation plans
CREATE OR REPLACE FUNCTION public.list_renegotiation_plans_r2531()
RETURNS TABLE(id uuid, signal_id uuid, chain_name text, renegotiation_kind text, expected_outcome_md text, owner_email text, action_due_at timestamptz, status text, outcome text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.signal_id, s.chain_name, p.renegotiation_kind, p.expected_outcome_md, p.owner_email, p.action_due_at, p.status, p.outcome, p.notes
    FROM public.ma_renegotiation_plans_r2531 p
    JOIN public.chain_ma_signals_r2531 s ON s.id = p.signal_id
    ORDER BY COALESCE(p.action_due_at, p.created_at) ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_renegotiation_plans_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renegotiation_plans_r2531() TO authenticated;

-- RPC 3: confirmed signals focus
CREATE OR REPLACE FUNCTION public.confirmed_signals_focus_r2531()
RETURNS TABLE(id uuid, chain_name text, signal_at timestamptz, signal_kind text, signal_strength text, status text, owner_email text, days_since_signal integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.signal_at, s.signal_kind, s.signal_strength, s.status, s.owner_email,
           EXTRACT(DAY FROM (now() - s.signal_at))::integer AS days_since_signal
    FROM public.chain_ma_signals_r2531 s
    WHERE s.signal_strength IN ('strong','confirmed') AND s.status <> 'closed'
    ORDER BY s.signal_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.confirmed_signals_focus_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirmed_signals_focus_r2531() TO authenticated;

-- RPC 4: signal kind breakdown
CREATE OR REPLACE FUNCTION public.signal_kind_breakdown_r2531()
RETURNS TABLE(signal_kind text, signal_count bigint, strong_or_confirmed bigint, open_or_escalated bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_kind,
           COUNT(*)::bigint AS signal_count,
           COUNT(*) FILTER (WHERE s.signal_strength IN ('strong','confirmed'))::bigint AS strong_or_confirmed,
           COUNT(*) FILTER (WHERE s.status IN ('open','monitoring','escalated'))::bigint AS open_or_escalated
    FROM public.chain_ma_signals_r2531 s
    GROUP BY s.signal_kind
    ORDER BY signal_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.signal_kind_breakdown_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signal_kind_breakdown_r2531() TO authenticated;

-- RPC 5: top at-risk chains
CREATE OR REPLACE FUNCTION public.top_at_risk_chains_r2531()
RETURNS TABLE(chain_name text, signal_count bigint, strong_or_confirmed bigint, open_renegotiations bigint, latest_signal_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name,
           COUNT(*)::bigint AS signal_count,
           COUNT(*) FILTER (WHERE s.signal_strength IN ('strong','confirmed'))::bigint AS strong_or_confirmed,
           COALESCE(SUM(CASE WHEN p.status IN ('open','in_progress') THEN 1 ELSE 0 END),0)::bigint AS open_renegotiations,
           MAX(s.signal_at) AS latest_signal_at
    FROM public.chain_ma_signals_r2531 s
    LEFT JOIN public.ma_renegotiation_plans_r2531 p ON p.signal_id = s.id
    GROUP BY s.chain_name
    ORDER BY strong_or_confirmed DESC, signal_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_at_risk_chains_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_chains_r2531() TO authenticated;

-- RPC 6: monthly signal trend
CREATE OR REPLACE FUNCTION public.monthly_signal_trend_r2531()
RETURNS TABLE(month_label text, signal_count bigint, strong_or_confirmed bigint, escalated_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', s.signal_at), 'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS signal_count,
           COUNT(*) FILTER (WHERE s.signal_strength IN ('strong','confirmed'))::bigint AS strong_or_confirmed,
           COUNT(*) FILTER (WHERE s.status = 'escalated')::bigint AS escalated_count
    FROM public.chain_ma_signals_r2531 s
    GROUP BY date_trunc('month', s.signal_at)
    ORDER BY date_trunc('month', s.signal_at) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_signal_trend_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_signal_trend_r2531() TO authenticated;

-- RPC 7: renegotiation status funnel
CREATE OR REPLACE FUNCTION public.renegotiation_status_funnel_r2531()
RETURNS TABLE(status text, plan_count bigint, positive_outcome bigint, neutral_outcome bigint, negative_outcome bigint, pending_outcome bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.status,
           COUNT(*)::bigint AS plan_count,
           COUNT(*) FILTER (WHERE p.outcome = 'positive')::bigint AS positive_outcome,
           COUNT(*) FILTER (WHERE p.outcome = 'neutral')::bigint AS neutral_outcome,
           COUNT(*) FILTER (WHERE p.outcome = 'negative')::bigint AS negative_outcome,
           COUNT(*) FILTER (WHERE p.outcome = 'pending')::bigint AS pending_outcome
    FROM public.ma_renegotiation_plans_r2531 p
    GROUP BY p.status
    ORDER BY plan_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.renegotiation_status_funnel_r2531() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renegotiation_status_funnel_r2531() TO authenticated;
