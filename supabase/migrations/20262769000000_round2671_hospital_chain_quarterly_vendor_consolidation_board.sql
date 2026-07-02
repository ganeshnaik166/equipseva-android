BEGIN;

-- r2671 hospital chain quarterly vendor consolidation board

CREATE TABLE IF NOT EXISTS public.chain_vendor_consolidation_r2671 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  current_vendors_count int NOT NULL DEFAULT 0,
  consolidation_target_count int NOT NULL DEFAULT 0,
  est_savings_rupees bigint NOT NULL DEFAULT 0,
  action_kind text NOT NULL CHECK (action_kind IN ('rfp_relaunch','single_source_pilot','master_msa','tier_collapse','exit_vendor')),
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending','approved','rejected','deferred','executed')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consolidation_vendor_lines_r2671 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consolidation_id uuid NOT NULL REFERENCES public.chain_vendor_consolidation_r2671(id) ON DELETE CASCADE,
  vendor_name text NOT NULL,
  spend_rupees bigint NOT NULL DEFAULT 0,
  retain_kind text NOT NULL CHECK (retain_kind IN ('retain','consolidate','exit','renegotiate')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','win','loss','draw')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_vendor_consolidation_r2671 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consolidation_vendor_lines_r2671 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_vendor_consolidation_r2671;
CREATE POLICY founder_all ON public.chain_vendor_consolidation_r2671
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.consolidation_vendor_lines_r2671;
CREATE POLICY founder_all ON public.consolidation_vendor_lines_r2671
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed consolidation rows
INSERT INTO public.chain_vendor_consolidation_r2671 (chain_name, quarter_label, current_vendors_count, consolidation_target_count, est_savings_rupees, action_kind, decision, owner_email, status, notes) VALUES
  ('Apollo South Chain', 'Q2-2026', 14, 6, 4200000, 'master_msa', 'approved', 'cfo@equipseva.in', 'in_progress', 'CFO approved master MSA route'),
  ('Yashoda Network', 'Q2-2026', 9, 5, 2150000, 'rfp_relaunch', 'pending', 'rep2@equipseva.in', 'open', 'RFP draft circulating with procurement'),
  ('KIMS Group', 'Q2-2026', 11, 4, 3680000, 'tier_collapse', 'deferred', 'rep3@equipseva.in', 'open', 'Deferred to Q3 — bandwidth issue'),
  ('Medicover Chain', 'Q2-2026', 7, 3, 1450000, 'single_source_pilot', 'approved', 'rep4@equipseva.in', 'in_progress', '90-day single-source pilot on imaging'),
  ('Continental Group', 'Q2-2026', 12, 5, 5100000, 'exit_vendor', 'executed', 'cfo@equipseva.in', 'done', 'Exited 4 underperformers — saved 51L'),
  ('Sunshine Hospitals', 'Q2-2026', 8, 4, 1820000, 'rfp_relaunch', 'rejected', 'rep1@equipseva.in', 'dropped', 'Board rejected — vendor lobbying');

-- Seed vendor lines
INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Acme Imaging Co', 1800000, 'retain', 'win', 'cfo@equipseva.in', 'done', 'Strategic supplier — kept'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'Apollo South Chain';

INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Beta Diagnostics Ltd', 920000, 'exit', 'loss', 'cfo@equipseva.in', 'done', 'Exited Q1 — quality issues'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'Apollo South Chain';

INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Gamma Parts Supply', 540000, 'consolidate', 'pending', 'rep2@equipseva.in', 'open', 'Consolidating to single SKU vendor'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'Yashoda Network';

INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Delta MedTech', 1250000, 'renegotiate', 'win', 'rep3@equipseva.in', 'done', 'Renegotiated 18% off on parts'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'KIMS Group';

INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Epsilon Service Co', 680000, 'exit', 'win', 'rep4@equipseva.in', 'done', 'Exited — pilot succeeded'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'Medicover Chain';

INSERT INTO public.consolidation_vendor_lines_r2671 (consolidation_id, vendor_name, spend_rupees, retain_kind, outcome, owner_email, status, notes)
SELECT id, 'Zeta Imaging', 1900000, 'retain', 'win', 'cfo@equipseva.in', 'done', 'Long-term strategic'
FROM public.chain_vendor_consolidation_r2671 WHERE chain_name = 'Continental Group';

-- RPCs

DROP FUNCTION IF EXISTS public.list_consolidation_r2671();
CREATE OR REPLACE FUNCTION public.list_consolidation_r2671()
RETURNS TABLE (
  id uuid, chain_name text, quarter_label text, current_vendors_count int,
  consolidation_target_count int, est_savings_rupees bigint, action_kind text,
  decision text, owner_email text, status text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.quarter_label, c.current_vendors_count,
         c.consolidation_target_count, c.est_savings_rupees, c.action_kind,
         c.decision, c.owner_email, c.status, c.notes, c.created_at
  FROM public.chain_vendor_consolidation_r2671 c
  ORDER BY c.est_savings_rupees DESC, c.created_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_consolidation_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_consolidation_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.list_vendor_lines_r2671();
CREATE OR REPLACE FUNCTION public.list_vendor_lines_r2671()
RETURNS TABLE (
  id uuid, consolidation_id uuid, chain_name text, vendor_name text,
  spend_rupees bigint, retain_kind text, outcome text, owner_email text,
  status text, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.consolidation_id, c.chain_name, v.vendor_name,
         v.spend_rupees, v.retain_kind, v.outcome, v.owner_email,
         v.status, v.notes, v.created_at
  FROM public.consolidation_vendor_lines_r2671 v
  JOIN public.chain_vendor_consolidation_r2671 c ON c.id = v.consolidation_id
  ORDER BY v.spend_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_vendor_lines_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_vendor_lines_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.top_savings_focus_r2671();
CREATE OR REPLACE FUNCTION public.top_savings_focus_r2671()
RETURNS TABLE (chain_name text, est_savings_rupees bigint, current_vendors_count int, consolidation_target_count int, decision text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.est_savings_rupees, c.current_vendors_count, c.consolidation_target_count, c.decision, c.status
  FROM public.chain_vendor_consolidation_r2671 c
  WHERE c.decision IN ('pending','approved')
  ORDER BY c.est_savings_rupees DESC
  LIMIT 5;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_savings_focus_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_savings_focus_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.decision_funnel_r2671();
CREATE OR REPLACE FUNCTION public.decision_funnel_r2671()
RETURNS TABLE (decision text, chain_count bigint, total_savings_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.decision, COUNT(*)::bigint, COALESCE(SUM(c.est_savings_rupees),0)::bigint
  FROM public.chain_vendor_consolidation_r2671 c
  GROUP BY c.decision
  ORDER BY c.decision;
END; $$;
REVOKE EXECUTE ON FUNCTION public.decision_funnel_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_funnel_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.status_funnel_r2671();
CREATE OR REPLACE FUNCTION public.status_funnel_r2671()
RETURNS TABLE (status text, chain_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status, COUNT(*)::bigint
  FROM public.chain_vendor_consolidation_r2671 c
  GROUP BY c.status
  ORDER BY c.status;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.quarterly_consolidation_trend_r2671();
CREATE OR REPLACE FUNCTION public.quarterly_consolidation_trend_r2671()
RETURNS TABLE (quarter_label text, chain_count bigint, total_savings_rupees bigint, avg_vendor_reduction numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.quarter_label,
         COUNT(*)::bigint,
         COALESCE(SUM(c.est_savings_rupees),0)::bigint,
         ROUND(AVG(c.current_vendors_count - c.consolidation_target_count)::numeric, 2)
  FROM public.chain_vendor_consolidation_r2671 c
  GROUP BY c.quarter_label
  ORDER BY c.quarter_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_consolidation_trend_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_consolidation_trend_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.consolidation_summary_r2671();
CREATE OR REPLACE FUNCTION public.consolidation_summary_r2671()
RETURNS TABLE (total_chains bigint, total_current_vendors bigint, total_target_vendors bigint, total_savings_rupees bigint, executed_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint,
         COALESCE(SUM(c.current_vendors_count),0)::bigint,
         COALESCE(SUM(c.consolidation_target_count),0)::bigint,
         COALESCE(SUM(c.est_savings_rupees),0)::bigint,
         COALESCE(SUM(CASE WHEN c.decision = 'executed' THEN 1 ELSE 0 END),0)::bigint
  FROM public.chain_vendor_consolidation_r2671 c;
END; $$;
REVOKE EXECUTE ON FUNCTION public.consolidation_summary_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consolidation_summary_r2671() TO authenticated;

DROP FUNCTION IF EXISTS public.owner_load_r2671();
CREATE OR REPLACE FUNCTION public.owner_load_r2671()
RETURNS TABLE (owner_email text, chain_count bigint, open_count bigint, total_savings_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(c.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint,
         COALESCE(SUM(CASE WHEN c.status IN ('open','in_progress') THEN 1 ELSE 0 END),0)::bigint,
         COALESCE(SUM(c.est_savings_rupees),0)::bigint
  FROM public.chain_vendor_consolidation_r2671 c
  GROUP BY c.owner_email
  ORDER BY total_savings_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2671() TO authenticated;

COMMIT;