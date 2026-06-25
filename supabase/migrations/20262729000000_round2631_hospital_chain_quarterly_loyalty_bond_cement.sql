BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_loyalty_bond_actions_r2631 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('exclusive_pricing','joint_marketing','co_innovation','founder_gift','strategic_review')),
  value_rupees bigint NOT NULL DEFAULT 0,
  bond_strength_after text NOT NULL CHECK (bond_strength_after IN ('weak','developing','strong','champion')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_bond_outcomes_r2631 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id uuid NOT NULL REFERENCES public.chain_loyalty_bond_actions_r2631(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('referral_made','contract_extended','case_study','no_change')),
  revenue_realized_rupees bigint NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_loyalty_bond_actions_r2631 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_bond_outcomes_r2631 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_loyalty_bond_actions_r2631;
CREATE POLICY founder_all ON public.chain_loyalty_bond_actions_r2631
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.loyalty_bond_outcomes_r2631;
CREATE POLICY founder_all ON public.loyalty_bond_outcomes_r2631
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed actions
INSERT INTO public.chain_loyalty_bond_actions_r2631 (chain_name, quarter_label, action_kind, value_rupees, bond_strength_after, owner_email, status, notes) VALUES
  ('Apollo Group', 'Q2-2026', 'exclusive_pricing', 1200000, 'champion', 'kam.apollo@equipseva.in', 'done', 'Locked 12 percent volume discount for next 4 quarters'),
  ('Manipal Hospitals', 'Q2-2026', 'joint_marketing', 450000, 'strong', 'kam.manipal@equipseva.in', 'planned', 'Co-branded uptime case study at HIMSS booth'),
  ('Fortis Healthcare', 'Q2-2026', 'co_innovation', 800000, 'developing', 'kam.fortis@equipseva.in', 'planned', 'AI triage pilot on ICU ventilator fleet'),
  ('Yashoda Hospitals', 'Q2-2026', 'founder_gift', 75000, 'strong', 'founder@equipseva.in', 'done', 'CXO appreciation hamper plus handwritten note'),
  ('KIMS Hospitals', 'Q2-2026', 'strategic_review', 0, 'developing', 'kam.kims@equipseva.in', 'planned', 'CFO QBR scheduled covering tier breakdown and SLA scorecard');

-- Seed outcomes against first action
INSERT INTO public.loyalty_bond_outcomes_r2631 (action_id, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'contract_extended', 2400000, 'kam.apollo@equipseva.in', 'done', 'AMC extended for 2 hospitals in chain'
FROM public.chain_loyalty_bond_actions_r2631 WHERE chain_name = 'Apollo Group' LIMIT 1;

INSERT INTO public.loyalty_bond_outcomes_r2631 (action_id, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'referral_made', 600000, 'kam.apollo@equipseva.in', 'open', 'CMO intro to peer chain CFO in pipeline'
FROM public.chain_loyalty_bond_actions_r2631 WHERE chain_name = 'Apollo Group' LIMIT 1;

INSERT INTO public.loyalty_bond_outcomes_r2631 (action_id, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'case_study', 0, 'kam.manipal@equipseva.in', 'open', 'Draft case study under legal review at chain HQ'
FROM public.chain_loyalty_bond_actions_r2631 WHERE chain_name = 'Manipal Hospitals' LIMIT 1;

INSERT INTO public.loyalty_bond_outcomes_r2631 (action_id, outcome_kind, revenue_realized_rupees, owner_email, status, notes)
SELECT id, 'no_change', 0, 'kam.fortis@equipseva.in', 'dropped', 'Pilot deferred to next quarter due to procurement freeze'
FROM public.chain_loyalty_bond_actions_r2631 WHERE chain_name = 'Fortis Healthcare' LIMIT 1;

-- RPC 1
CREATE OR REPLACE FUNCTION public.list_bond_actions_r2631()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  action_kind text,
  value_rupees bigint,
  bond_strength_after text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.chain_name, a.quarter_label, a.action_kind, a.value_rupees,
           a.bond_strength_after, a.owner_email, a.status, a.notes, a.created_at
    FROM public.chain_loyalty_bond_actions_r2631 a
    ORDER BY a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bond_actions_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bond_actions_r2631() TO authenticated;

-- RPC 2
CREATE OR REPLACE FUNCTION public.list_outcomes_r2631()
RETURNS TABLE (
  id uuid,
  action_id uuid,
  chain_name text,
  outcome_kind text,
  revenue_realized_rupees bigint,
  owner_email text,
  status text,
  notes text,
  observed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.action_id, a.chain_name, o.outcome_kind, o.revenue_realized_rupees,
           o.owner_email, o.status, o.notes, o.observed_at
    FROM public.loyalty_bond_outcomes_r2631 o
    JOIN public.chain_loyalty_bond_actions_r2631 a ON a.id = o.action_id
    ORDER BY o.observed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2631() TO authenticated;

-- RPC 3
CREATE OR REPLACE FUNCTION public.top_bond_focus_r2631()
RETURNS TABLE (
  chain_name text,
  total_actions bigint,
  total_value_rupees bigint,
  champion_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.chain_name,
           COUNT(*)::bigint AS total_actions,
           COALESCE(SUM(a.value_rupees),0)::bigint AS total_value_rupees,
           COUNT(*) FILTER (WHERE a.bond_strength_after = 'champion')::bigint AS champion_count
    FROM public.chain_loyalty_bond_actions_r2631 a
    GROUP BY a.chain_name
    ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_bond_focus_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_bond_focus_r2631() TO authenticated;

-- RPC 4
CREATE OR REPLACE FUNCTION public.action_kind_distribution_r2631()
RETURNS TABLE (
  action_kind text,
  cnt bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.action_kind,
           COUNT(*)::bigint AS cnt,
           COALESCE(SUM(a.value_rupees),0)::bigint AS total_value_rupees
    FROM public.chain_loyalty_bond_actions_r2631 a
    GROUP BY a.action_kind
    ORDER BY cnt DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_distribution_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_distribution_r2631() TO authenticated;

-- RPC 5
CREATE OR REPLACE FUNCTION public.status_funnel_r2631()
RETURNS TABLE (
  bucket text,
  status text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'actions'::text AS bucket, a.status, COUNT(*)::bigint AS cnt
    FROM public.chain_loyalty_bond_actions_r2631 a
    GROUP BY a.status
    UNION ALL
    SELECT 'outcomes'::text AS bucket, o.status, COUNT(*)::bigint AS cnt
    FROM public.loyalty_bond_outcomes_r2631 o
    GROUP BY o.status
    ORDER BY 1, 2;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2631() TO authenticated;

-- RPC 6
CREATE OR REPLACE FUNCTION public.quarterly_bond_trend_r2631()
RETURNS TABLE (
  quarter_label text,
  total_actions bigint,
  total_value_rupees bigint,
  realized_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.quarter_label,
           COUNT(*)::bigint AS total_actions,
           COALESCE(SUM(a.value_rupees),0)::bigint AS total_value_rupees,
           COALESCE((SELECT SUM(o.revenue_realized_rupees)
                     FROM public.loyalty_bond_outcomes_r2631 o
                     JOIN public.chain_loyalty_bond_actions_r2631 ax ON ax.id = o.action_id
                     WHERE ax.quarter_label = a.quarter_label),0)::bigint AS realized_revenue_rupees
    FROM public.chain_loyalty_bond_actions_r2631 a
    GROUP BY a.quarter_label
    ORDER BY a.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_bond_trend_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_bond_trend_r2631() TO authenticated;

-- RPC 7
CREATE OR REPLACE FUNCTION public.owner_load_r2631()
RETURNS TABLE (
  owner_email text,
  open_actions bigint,
  open_outcomes bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.owner_email,
           COALESCE(SUM(CASE WHEN u.src = 'action' AND u.status = 'planned' THEN 1 ELSE 0 END),0)::bigint AS open_actions,
           COALESCE(SUM(CASE WHEN u.src = 'outcome' AND u.status = 'open' THEN 1 ELSE 0 END),0)::bigint AS open_outcomes,
           COALESCE(SUM(u.val),0)::bigint AS total_value_rupees
    FROM (
      SELECT 'action'::text AS src, a.owner_email, a.status, a.value_rupees AS val
      FROM public.chain_loyalty_bond_actions_r2631 a
      UNION ALL
      SELECT 'outcome'::text AS src, o.owner_email, o.status, o.revenue_realized_rupees AS val
      FROM public.loyalty_bond_outcomes_r2631 o
    ) u
    GROUP BY u.owner_email
    ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2631() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2631() TO authenticated;

COMMIT;
