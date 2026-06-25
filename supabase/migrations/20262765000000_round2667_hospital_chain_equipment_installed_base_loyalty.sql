-- r2667 hospital chain equipment installed base loyalty

CREATE TABLE IF NOT EXISTS public.chain_installed_base_loyalty_r2667 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  our_equipment_count int NOT NULL DEFAULT 0,
  competitor_equipment_count int NOT NULL DEFAULT 0,
  our_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  loyalty_kind text NOT NULL CHECK (loyalty_kind IN ('strong','balanced','eroding','weak')),
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','intervening','dominating','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_expansion_actions_r2667 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loyalty_id uuid NOT NULL REFERENCES public.chain_installed_base_loyalty_r2667(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('equipment_swap','replacement_quote','exec_pitch','discount','multi_year_lock')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_installed_base_loyalty_r2667 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_expansion_actions_r2667 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_installed_base_loyalty_r2667;
CREATE POLICY founder_all ON public.chain_installed_base_loyalty_r2667
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.loyalty_expansion_actions_r2667;
CREATE POLICY founder_all ON public.loyalty_expansion_actions_r2667
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_installed_base_loyalty_r2667 (chain_name, our_equipment_count, competitor_equipment_count, our_share_pct, loyalty_kind, owner_email, status, notes) VALUES
  ('Apollo South Chain', 42, 18, 70.00, 'strong', 'rep1@equipseva.in', 'dominating', 'Multi-year service lock signed'),
  ('Yashoda Network', 28, 24, 53.85, 'balanced', 'rep2@equipseva.in', 'intervening', 'Competitor pushing replacement'),
  ('KIMS Group', 12, 36, 25.00, 'eroding', 'rep3@equipseva.in', 'intervening', 'Lost 4 units last quarter'),
  ('Medicover Chain', 6, 30, 16.67, 'weak', 'rep4@equipseva.in', 'monitoring', 'Competitor incumbent across sites'),
  ('Continental Group', 35, 15, 70.00, 'strong', 'rep1@equipseva.in', 'dominating', 'Exec relationship locked');

INSERT INTO public.loyalty_expansion_actions_r2667 (loyalty_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'multi_year_lock', 'positive', 'rep1@equipseva.in', 'done', 'Signed 3 year service contract'
FROM public.chain_installed_base_loyalty_r2667 WHERE chain_name = 'Apollo South Chain';

INSERT INTO public.loyalty_expansion_actions_r2667 (loyalty_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'replacement_quote', 'pending', 'rep2@equipseva.in', 'open', 'Quote sent for 8 unit refresh'
FROM public.chain_installed_base_loyalty_r2667 WHERE chain_name = 'Yashoda Network';

INSERT INTO public.loyalty_expansion_actions_r2667 (loyalty_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'exec_pitch', 'neutral', 'rep3@equipseva.in', 'open', 'CFO meeting scheduled'
FROM public.chain_installed_base_loyalty_r2667 WHERE chain_name = 'KIMS Group';

INSERT INTO public.loyalty_expansion_actions_r2667 (loyalty_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'discount', 'negative', 'rep4@equipseva.in', 'dropped', 'Discount rejected by procurement'
FROM public.chain_installed_base_loyalty_r2667 WHERE chain_name = 'Medicover Chain';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_loyalty_r2667()
RETURNS TABLE (
  id uuid, chain_name text, our_equipment_count int, competitor_equipment_count int,
  our_share_pct numeric, loyalty_kind text, owner_email text, status text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.our_equipment_count, l.competitor_equipment_count,
         l.our_share_pct, l.loyalty_kind, l.owner_email, l.status, l.notes, l.created_at
  FROM public.chain_installed_base_loyalty_r2667 l
  ORDER BY l.our_share_pct DESC, l.created_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_loyalty_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loyalty_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_expansion_actions_r2667()
RETURNS TABLE (
  id uuid, loyalty_id uuid, chain_name text, action_at timestamptz, action_kind text,
  outcome text, owner_email text, status text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.loyalty_id, l.chain_name, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.loyalty_expansion_actions_r2667 a
  JOIN public.chain_installed_base_loyalty_r2667 l ON l.id = a.loyalty_id
  ORDER BY a.action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_expansion_actions_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_expansion_actions_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_eroding_focus_r2667()
RETURNS TABLE (chain_name text, our_share_pct numeric, competitor_equipment_count int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.chain_name, l.our_share_pct, l.competitor_equipment_count, l.status
  FROM public.chain_installed_base_loyalty_r2667 l
  WHERE l.loyalty_kind IN ('eroding','weak')
  ORDER BY l.our_share_pct ASC
  LIMIT 5;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_eroding_focus_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_eroding_focus_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.loyalty_kind_distribution_r2667()
RETURNS TABLE (loyalty_kind text, chain_count bigint, total_our_units bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.loyalty_kind, COUNT(*)::bigint, COALESCE(SUM(l.our_equipment_count),0)::bigint
  FROM public.chain_installed_base_loyalty_r2667 l
  GROUP BY l.loyalty_kind
  ORDER BY l.loyalty_kind;
END; $$;
REVOKE EXECUTE ON FUNCTION public.loyalty_kind_distribution_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.loyalty_kind_distribution_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2667()
RETURNS TABLE (status text, chain_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.status, COUNT(*)::bigint
  FROM public.chain_installed_base_loyalty_r2667 l
  GROUP BY l.status
  ORDER BY l.status;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_loyalty_trend_r2667()
RETURNS TABLE (month_start timestamptz, chains_added bigint, avg_share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', l.created_at)::timestamptz AS month_start,
         COUNT(*)::bigint,
         ROUND(AVG(l.our_share_pct), 2)
  FROM public.chain_installed_base_loyalty_r2667 l
  GROUP BY date_trunc('month', l.created_at)
  ORDER BY month_start DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.monthly_loyalty_trend_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_loyalty_trend_r2667() TO authenticated;

CREATE OR REPLACE FUNCTION public.our_share_summary_r2667()
RETURNS TABLE (total_chains bigint, total_our_units bigint, total_competitor_units bigint, avg_share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint,
         COALESCE(SUM(l.our_equipment_count),0)::bigint,
         COALESCE(SUM(l.competitor_equipment_count),0)::bigint,
         COALESCE(ROUND(AVG(l.our_share_pct), 2), 0)
  FROM public.chain_installed_base_loyalty_r2667 l;
END; $$;
REVOKE EXECUTE ON FUNCTION public.our_share_summary_r2667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.our_share_summary_r2667() TO authenticated;
