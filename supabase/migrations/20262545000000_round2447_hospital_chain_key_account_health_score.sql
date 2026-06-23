-- Round r2447: hospital-chain-key-account-health-score
-- 2 tables + 7 RPCs. Founder-only RLS. plpgsql + is_founder() gate.

BEGIN;

-- =============================================================
-- TABLE 1: chain_health_snapshots_r2447
-- =============================================================
CREATE TABLE IF NOT EXISTS public.chain_health_snapshots_r2447 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  snapshot_date date NOT NULL DEFAULT (now()::date),
  nps int NOT NULL CHECK (nps BETWEEN -100 AND 100),
  mrr_rupees bigint NOT NULL CHECK (mrr_rupees >= 0),
  ticket_count_30d int NOT NULL CHECK (ticket_count_30d >= 0),
  avg_resolution_hours numeric(6,2) NOT NULL CHECK (avg_resolution_hours >= 0),
  engagement_score int NOT NULL CHECK (engagement_score BETWEEN 0 AND 100),
  renewal_probability_pct int NOT NULL CHECK (renewal_probability_pct BETWEEN 0 AND 100),
  health_composite int NOT NULL CHECK (health_composite BETWEEN 0 AND 100),
  health_label text NOT NULL CHECK (health_label IN ('red','amber','green','super')),
  top_risk text,
  top_opportunity text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_chain_health_snap_r2447_chain ON public.chain_health_snapshots_r2447(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_health_snap_r2447_date  ON public.chain_health_snapshots_r2447(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_chain_health_snap_r2447_label ON public.chain_health_snapshots_r2447(health_label);

ALTER TABLE public.chain_health_snapshots_r2447 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_health_snapshots_r2447;
CREATE POLICY founder_all ON public.chain_health_snapshots_r2447
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================
-- TABLE 2: chain_health_intervention_plans_r2447
-- =============================================================
CREATE TABLE IF NOT EXISTS public.chain_health_intervention_plans_r2447 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  current_health_label text NOT NULL CHECK (current_health_label IN ('red','amber','green','super')),
  target_health_label text NOT NULL CHECK (target_health_label IN ('red','amber','green','super')),
  recommended_action_md text NOT NULL,
  owner_email text NOT NULL,
  action_due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_chain_interv_r2447_chain  ON public.chain_health_intervention_plans_r2447(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_interv_r2447_status ON public.chain_health_intervention_plans_r2447(status);
CREATE INDEX IF NOT EXISTS idx_chain_interv_r2447_opened ON public.chain_health_intervention_plans_r2447(opened_at DESC);

ALTER TABLE public.chain_health_intervention_plans_r2447 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_health_intervention_plans_r2447;
CREATE POLICY founder_all ON public.chain_health_intervention_plans_r2447
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================
-- SEED DATA
-- =============================================================
INSERT INTO public.chain_health_snapshots_r2447
  (chain_name, snapshot_date, nps, mrr_rupees, ticket_count_30d, avg_resolution_hours, engagement_score, renewal_probability_pct, health_composite, health_label, top_risk, top_opportunity, notes)
VALUES
  ('Apollo South Chain',    '2026-06-15'::date,  62, 18500000,  42,  6.20, 88, 92, 91, 'super',  'Vendor consolidation pressure', 'Upsell AMC Premium across 6 units', 'CEO sponsor active'),
  ('Yashoda Hyderabad',     '2026-06-15'::date,  41, 12200000,  58,  9.80, 74, 78, 76, 'green',  'Recent CT downtime',            'Cross-sell biomed training',         'NPS dipped from 55'),
  ('KIMS Group',            '2026-06-15'::date,  18,  9800000,  91, 14.30, 52, 55, 51, 'amber',  'Tickets +43% MoM',              'Replace 2 aging analyzers',          'Procurement RFP coming Q3'),
  ('Care Hospitals',        '2026-06-15'::date,  -8,  7400000, 122, 22.10, 38, 32, 28, 'red',    'Renewal at risk - competitor pitching', 'Founder QBR + SLA credit',   'CFO requested cost cut'),
  ('AIG Hyderabad',         '2026-06-15'::date,  55, 14600000,  36,  5.40, 82, 86, 84, 'green',  'Single-point-of-failure on radiology', 'Add 24x7 biomed contract',    'Strong champion in CIO');

INSERT INTO public.chain_health_intervention_plans_r2447
  (chain_name, opened_at, current_health_label, target_health_label, recommended_action_md, owner_email, action_due_at, status, outcome, notes)
VALUES
  ('Care Hospitals',   '2026-06-16T09:00:00'::timestamptz, 'red',   'amber', '- Founder QBR within 7 days\n- Offer SLA credit 2 lakh\n- Assign dedicated biomed engineer', 'founder@equipseva.in', '2026-06-23T18:00:00'::timestamptz, 'in_progress', 'pending',  'CFO escalation'),
  ('KIMS Group',       '2026-06-14T10:30:00'::timestamptz, 'amber', 'green', '- Root-cause ticket spike\n- Free firmware audit\n- Schedule procurement lunch',         'kam@equipseva.in',     '2026-06-28T18:00:00'::timestamptz, 'open',        'pending',  'Pre-empt RFP'),
  ('Yashoda Hyderabad','2026-06-10T11:00:00'::timestamptz, 'green', 'super', '- Pitch biomed training package\n- Run NPS pulse survey\n- Quarterly CXO dinner',         'sales@equipseva.in',   '2026-07-05T18:00:00'::timestamptz, 'open',        'pending',  'Upsell push'),
  ('Apollo South Chain','2026-06-01T09:30:00'::timestamptz,'super', 'super', '- Lock multi-year renewal\n- Reference case study\n- Joint marketing event',              'founder@equipseva.in', '2026-07-15T18:00:00'::timestamptz, 'done',        'positive', 'Renewed 3yr');

-- =============================================================
-- RPC 1: list_snapshots_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_snapshots_r2447()
RETURNS TABLE (
  id uuid,
  chain_name text,
  snapshot_date date,
  nps int,
  mrr_rupees bigint,
  ticket_count_30d int,
  avg_resolution_hours numeric,
  engagement_score int,
  renewal_probability_pct int,
  health_composite int,
  health_label text,
  top_risk text,
  top_opportunity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.snapshot_date, s.nps, s.mrr_rupees, s.ticket_count_30d,
           s.avg_resolution_hours, s.engagement_score, s.renewal_probability_pct,
           s.health_composite, s.health_label, s.top_risk, s.top_opportunity
      FROM public.chain_health_snapshots_r2447 s
     ORDER BY s.snapshot_date DESC, s.health_composite DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_snapshots_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_snapshots_r2447() TO authenticated;

-- =============================================================
-- RPC 2: list_intervention_plans_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.list_intervention_plans_r2447()
RETURNS TABLE (
  id uuid,
  chain_name text,
  opened_at timestamptz,
  current_health_label text,
  target_health_label text,
  owner_email text,
  action_due_at timestamptz,
  status text,
  outcome text,
  recommended_action_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.chain_name, p.opened_at, p.current_health_label, p.target_health_label,
           p.owner_email, p.action_due_at, p.status, p.outcome, p.recommended_action_md
      FROM public.chain_health_intervention_plans_r2447 p
     ORDER BY p.opened_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_intervention_plans_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intervention_plans_r2447() TO authenticated;

-- =============================================================
-- RPC 3: red_focus_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.red_focus_r2447()
RETURNS TABLE (
  chain_name text,
  health_composite int,
  health_label text,
  mrr_rupees bigint,
  top_risk text,
  snapshot_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.health_composite, s.health_label, s.mrr_rupees, s.top_risk, s.snapshot_date
      FROM public.chain_health_snapshots_r2447 s
     WHERE s.health_label IN ('red','amber')
     ORDER BY s.mrr_rupees DESC, s.health_composite ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.red_focus_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.red_focus_r2447() TO authenticated;

-- =============================================================
-- RPC 4: health_label_distribution_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.health_label_distribution_r2447()
RETURNS TABLE (
  health_label text,
  chain_count bigint,
  total_mrr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.health_label, COUNT(*)::bigint AS chain_count, COALESCE(SUM(s.mrr_rupees),0)::bigint AS total_mrr_rupees
      FROM public.chain_health_snapshots_r2447 s
     GROUP BY s.health_label
     ORDER BY CASE s.health_label WHEN 'super' THEN 1 WHEN 'green' THEN 2 WHEN 'amber' THEN 3 WHEN 'red' THEN 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.health_label_distribution_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.health_label_distribution_r2447() TO authenticated;

-- =============================================================
-- RPC 5: top_renewal_risk_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.top_renewal_risk_r2447()
RETURNS TABLE (
  chain_name text,
  renewal_probability_pct int,
  mrr_rupees bigint,
  health_label text,
  top_risk text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.renewal_probability_pct, s.mrr_rupees, s.health_label, s.top_risk
      FROM public.chain_health_snapshots_r2447 s
     ORDER BY s.renewal_probability_pct ASC, s.mrr_rupees DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_renewal_risk_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_renewal_risk_r2447() TO authenticated;

-- =============================================================
-- RPC 6: top_engagement_chains_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.top_engagement_chains_r2447()
RETURNS TABLE (
  chain_name text,
  engagement_score int,
  nps int,
  health_label text,
  top_opportunity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.engagement_score, s.nps, s.health_label, s.top_opportunity
      FROM public.chain_health_snapshots_r2447 s
     ORDER BY s.engagement_score DESC, s.nps DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_engagement_chains_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engagement_chains_r2447() TO authenticated;

-- =============================================================
-- RPC 7: monthly_composite_trend_r2447
-- =============================================================
CREATE OR REPLACE FUNCTION public.monthly_composite_trend_r2447()
RETURNS TABLE (
  month_start date,
  avg_composite numeric,
  avg_nps numeric,
  chains_tracked bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', s.snapshot_date)::date AS month_start,
           ROUND(AVG(s.health_composite)::numeric, 1) AS avg_composite,
           ROUND(AVG(s.nps)::numeric, 1) AS avg_nps,
           COUNT(DISTINCT s.chain_name)::bigint AS chains_tracked
      FROM public.chain_health_snapshots_r2447 s
     GROUP BY date_trunc('month', s.snapshot_date)
     ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_composite_trend_r2447() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_composite_trend_r2447() TO authenticated;

