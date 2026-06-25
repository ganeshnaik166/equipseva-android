-- Round 2639: Hospital Chain Quarterly Equipment Investment Pipeline
-- Founder-only tracker for hospital chain quarterly equipment investment decisions

BEGIN;

-- =============================================================
-- TABLE 1: chain_equipment_investment_pipeline_r2639
-- =============================================================
CREATE TABLE IF NOT EXISTS public.chain_equipment_investment_pipeline_r2639 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  equipment_kind text NOT NULL,
  investment_value_rupees bigint NOT NULL DEFAULT 0,
  investment_decision_kind text NOT NULL CHECK (investment_decision_kind IN ('approved','postponed','rejected','under_negotiation')),
  our_share_kind text NOT NULL CHECK (our_share_kind IN ('amc','install','training','parts','none')),
  win_probability_pct int NOT NULL DEFAULT 0 CHECK (win_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'prospecting' CHECK (status IN ('prospecting','quoted','won','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_equipment_investment_pipeline_r2639 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_equipment_investment_pipeline_r2639;
CREATE POLICY founder_all ON public.chain_equipment_investment_pipeline_r2639
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pipeline_r2639_chain ON public.chain_equipment_investment_pipeline_r2639(chain_name);
CREATE INDEX IF NOT EXISTS idx_pipeline_r2639_quarter ON public.chain_equipment_investment_pipeline_r2639(quarter_label);
CREATE INDEX IF NOT EXISTS idx_pipeline_r2639_status ON public.chain_equipment_investment_pipeline_r2639(status);

-- =============================================================
-- TABLE 2: investment_decision_actions_r2639
-- =============================================================
CREATE TABLE IF NOT EXISTS public.investment_decision_actions_r2639 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.chain_equipment_investment_pipeline_r2639(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('proposal','exec_pitch','discount','financing','walkaway')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investment_decision_actions_r2639 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.investment_decision_actions_r2639;
CREATE POLICY founder_all ON public.investment_decision_actions_r2639
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_actions_r2639_pipeline ON public.investment_decision_actions_r2639(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_actions_r2639_at ON public.investment_decision_actions_r2639(action_at DESC);

-- =============================================================
-- SEED DATA
-- =============================================================
INSERT INTO public.chain_equipment_investment_pipeline_r2639
  (chain_name, quarter_label, equipment_kind, investment_value_rupees, investment_decision_kind, our_share_kind, win_probability_pct, owner_email, status, notes)
VALUES
  ('Apollo Group', 'Q3 2026', 'MRI 3T', 180000000, 'under_negotiation', 'amc', 65, 'founder@equipseva.com', 'quoted', 'Two-unit pipeline across Hyderabad and Chennai'),
  ('Manipal Health', 'Q3 2026', 'CT Scanner 128 slice', 75000000, 'approved', 'install', 80, 'sales@equipseva.com', 'won', 'PO signed, install kickoff next week'),
  ('Fortis Network', 'Q4 2026', 'Cath Lab', 95000000, 'postponed', 'training', 30, 'founder@equipseva.com', 'prospecting', 'Capex deferred to FY27 Q1'),
  ('Narayana Health', 'Q3 2026', 'Ventilator Fleet', 22000000, 'under_negotiation', 'parts', 55, 'sales@equipseva.com', 'quoted', 'Bulk parts contract under review'),
  ('Max Healthcare', 'Q4 2026', 'Ultrasound Cart', 12000000, 'rejected', 'none', 5, 'founder@equipseva.com', 'lost', 'Lost to incumbent OEM bundle')
ON CONFLICT DO NOTHING;

INSERT INTO public.investment_decision_actions_r2639
  (pipeline_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '7 days', 'proposal', 'positive', 'founder@equipseva.com', 'done', 'Initial deck shared with CFO'
FROM public.chain_equipment_investment_pipeline_r2639 WHERE chain_name = 'Apollo Group' LIMIT 1;

INSERT INTO public.investment_decision_actions_r2639
  (pipeline_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '3 days', 'exec_pitch', 'positive', 'sales@equipseva.com', 'done', 'COO meeting locked the AMC scope'
FROM public.chain_equipment_investment_pipeline_r2639 WHERE chain_name = 'Manipal Health' LIMIT 1;

INSERT INTO public.investment_decision_actions_r2639
  (pipeline_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '14 days', 'financing', 'neutral', 'founder@equipseva.com', 'open', 'Lease vs buy option being modeled'
FROM public.chain_equipment_investment_pipeline_r2639 WHERE chain_name = 'Narayana Health' LIMIT 1;

INSERT INTO public.investment_decision_actions_r2639
  (pipeline_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '21 days', 'walkaway', 'negative', 'founder@equipseva.com', 'done', 'Pricing gap too wide, walked'
FROM public.chain_equipment_investment_pipeline_r2639 WHERE chain_name = 'Max Healthcare' LIMIT 1;

-- =============================================================
-- RPC 1: list_pipeline_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_pipeline_r2639()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  equipment_kind text,
  investment_value_rupees bigint,
  investment_decision_kind text,
  our_share_kind text,
  win_probability_pct int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.chain_name, p.quarter_label, p.equipment_kind, p.investment_value_rupees,
           p.investment_decision_kind, p.our_share_kind, p.win_probability_pct,
           p.owner_email, p.status, p.notes, p.created_at
    FROM public.chain_equipment_investment_pipeline_r2639 p
    ORDER BY p.investment_value_rupees DESC, p.created_at DESC
    LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_r2639() TO authenticated;

-- =============================================================
-- RPC 2: list_decision_actions_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_decision_actions_r2639()
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.pipeline_id, p.chain_name, a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes
    FROM public.investment_decision_actions_r2639 a
    JOIN public.chain_equipment_investment_pipeline_r2639 p ON p.id = a.pipeline_id
    ORDER BY a.action_at DESC
    LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_decision_actions_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_actions_r2639() TO authenticated;

-- =============================================================
-- RPC 3: top_investment_value_focus_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.top_investment_value_focus_r2639()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  equipment_kind text,
  investment_value_rupees bigint,
  win_probability_pct int,
  weighted_value_rupees bigint,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.chain_name, p.quarter_label, p.equipment_kind, p.investment_value_rupees,
           p.win_probability_pct,
           (p.investment_value_rupees * p.win_probability_pct / 100)::bigint AS weighted_value_rupees,
           p.status
    FROM public.chain_equipment_investment_pipeline_r2639 p
    WHERE p.status IN ('prospecting','quoted')
    ORDER BY (p.investment_value_rupees * p.win_probability_pct) DESC
    LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_investment_value_focus_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_investment_value_focus_r2639() TO authenticated;

-- =============================================================
-- RPC 4: decision_kind_distribution_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.decision_kind_distribution_r2639()
RETURNS TABLE (
  investment_decision_kind text,
  deal_count bigint,
  total_value_rupees bigint,
  avg_win_probability numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.investment_decision_kind,
           count(*)::bigint AS deal_count,
           coalesce(sum(p.investment_value_rupees),0)::bigint AS total_value_rupees,
           round(avg(p.win_probability_pct)::numeric, 1) AS avg_win_probability
    FROM public.chain_equipment_investment_pipeline_r2639 p
    GROUP BY p.investment_decision_kind
    ORDER BY total_value_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_distribution_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_distribution_r2639() TO authenticated;

-- =============================================================
-- RPC 5: status_funnel_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2639()
RETURNS TABLE (
  status text,
  deal_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.status,
           count(*)::bigint AS deal_count,
           coalesce(sum(p.investment_value_rupees),0)::bigint AS total_value_rupees
    FROM public.chain_equipment_investment_pipeline_r2639 p
    GROUP BY p.status
    ORDER BY total_value_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2639() TO authenticated;

-- =============================================================
-- RPC 6: quarterly_pipeline_trend_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.quarterly_pipeline_trend_r2639()
RETURNS TABLE (
  quarter_label text,
  deal_count bigint,
  total_value_rupees bigint,
  won_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.quarter_label,
           count(*)::bigint AS deal_count,
           coalesce(sum(p.investment_value_rupees),0)::bigint AS total_value_rupees,
           coalesce(sum(p.investment_value_rupees) FILTER (WHERE p.status = 'won'),0)::bigint AS won_value_rupees
    FROM public.chain_equipment_investment_pipeline_r2639 p
    GROUP BY p.quarter_label
    ORDER BY p.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_pipeline_trend_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_pipeline_trend_r2639() TO authenticated;

-- =============================================================
-- RPC 7: our_share_summary_r2639
-- =============================================================
CREATE OR REPLACE FUNCTION public.our_share_summary_r2639()
RETURNS TABLE (
  our_share_kind text,
  deal_count bigint,
  total_value_rupees bigint,
  won_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.our_share_kind,
           count(*)::bigint AS deal_count,
           coalesce(sum(p.investment_value_rupees),0)::bigint AS total_value_rupees,
           count(*) FILTER (WHERE p.status = 'won')::bigint AS won_count
    FROM public.chain_equipment_investment_pipeline_r2639 p
    GROUP BY p.our_share_kind
    ORDER BY total_value_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.our_share_summary_r2639() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.our_share_summary_r2639() TO authenticated;

COMMIT;
