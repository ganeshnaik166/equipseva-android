-- Round 2567: hospital-chain-equipment-vendor-comparison-matrix
-- Chain x kind x competitor brand x pros/cons x positioning x win factors

CREATE TABLE IF NOT EXISTS public.chain_vendor_comparison_r2567 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_kind text NOT NULL,
  competitor_brand text NOT NULL,
  our_pros_md text,
  our_cons_md text,
  competitor_pros_md text,
  competitor_cons_md text,
  our_positioning_md text,
  win_factors_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendor_comparison_win_loss_log_r2567 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  comparison_id uuid NOT NULL REFERENCES public.chain_vendor_comparison_r2567(id) ON DELETE CASCADE,
  decision_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL CHECK (decision_kind IN ('we_won','competitor_won','no_decision','postponed')),
  value_rupees bigint,
  lessons_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_vendor_comparison_r2567 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_comparison_win_loss_log_r2567 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_vendor_comparison_r2567;
CREATE POLICY founder_all ON public.chain_vendor_comparison_r2567
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.vendor_comparison_win_loss_log_r2567;
CREATE POLICY founder_all ON public.vendor_comparison_win_loss_log_r2567
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_vendor_comparison_r2567
  (chain_name, equipment_kind, competitor_brand, our_pros_md, our_cons_md, competitor_pros_md, competitor_cons_md, our_positioning_md, win_factors_md, owner_email, status, notes)
VALUES
  ('Apollo', 'ventilator', 'GE Healthcare', '- 4hr SLA\n- Bonded parts', '- Smaller install base', '- Brand recall\n- OEM support', '- 24-48hr SLA\n- Premium pricing', 'Faster + cheaper for tier-2 cities', '- Response time\n- Local engineer density', 'founder@equipseva.com', 'active', 'Apollo Hyd POC'),
  ('Fortis', 'ultrasound', 'Philips', '- Pan-India AMC pool', '- New entrant', '- Established refurb chain', '- Long parts lead time', 'AMC pool absorbs spike repairs', '- AMC tier upgrades\n- Spot-audit reliability', 'founder@equipseva.com', 'active', NULL),
  ('Manipal', 'dialysis_machine', 'Fresenius', '- Engineer rotation', '- Limited refurb stock', '- Vertical integration', '- Vendor lock-in', 'Independent multi-brand service', '- Multi-brand engineers\n- No lock-in', 'founder@equipseva.com', 'active', 'Manipal Bangalore eval'),
  ('Max Healthcare', 'ct_scanner', 'Siemens', '- Cost discipline', '- Brand perception gap', '- Direct OEM\n- Software updates', '- Expensive AMC', 'Independent service at 60% cost', '- TCO transparency\n- Uptime SLA', 'founder@equipseva.com', 'superseded', 'Lost Max round-1');

INSERT INTO public.vendor_comparison_win_loss_log_r2567
  (comparison_id, decision_at, decision_kind, value_rupees, lessons_md, owner_email, notes)
SELECT id, now() - interval '20 days', 'we_won', 4200000, '- Local engineer density swung Apollo Hyd', 'founder@equipseva.com', NULL
FROM public.chain_vendor_comparison_r2567 WHERE chain_name='Apollo' LIMIT 1;

INSERT INTO public.vendor_comparison_win_loss_log_r2567
  (comparison_id, decision_at, decision_kind, value_rupees, lessons_md, owner_email, notes)
SELECT id, now() - interval '12 days', 'competitor_won', 8500000, '- Max procurement wanted single-vendor stack\n- Need TCO whitepaper', 'founder@equipseva.com', 'Max round-1'
FROM public.chain_vendor_comparison_r2567 WHERE chain_name='Max Healthcare' LIMIT 1;

INSERT INTO public.vendor_comparison_win_loss_log_r2567
  (comparison_id, decision_at, decision_kind, value_rupees, lessons_md, owner_email, notes)
SELECT id, now() - interval '5 days', 'postponed', 0, '- Fortis CFO change; revisit Q3', 'founder@equipseva.com', NULL
FROM public.chain_vendor_comparison_r2567 WHERE chain_name='Fortis' LIMIT 1;

INSERT INTO public.vendor_comparison_win_loss_log_r2567
  (comparison_id, decision_at, decision_kind, value_rupees, lessons_md, owner_email, notes)
SELECT id, now() - interval '2 days', 'we_won', 2300000, '- Multi-brand engineer rotation closed Manipal', 'founder@equipseva.com', NULL
FROM public.chain_vendor_comparison_r2567 WHERE chain_name='Manipal' LIMIT 1;

-- RPC 1: list comparisons
CREATE OR REPLACE FUNCTION public.list_comparisons_r2567()
RETURNS TABLE (
  id uuid, chain_name text, equipment_kind text, competitor_brand text,
  our_positioning_md text, win_factors_md text, status text, owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.equipment_kind, c.competitor_brand,
         c.our_positioning_md, c.win_factors_md, c.status, c.owner_email, c.created_at
  FROM public.chain_vendor_comparison_r2567 c
  ORDER BY c.created_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_comparisons_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_comparisons_r2567() TO authenticated;

-- RPC 2: list win/loss log
CREATE OR REPLACE FUNCTION public.list_win_loss_log_r2567()
RETURNS TABLE (
  id uuid, comparison_id uuid, chain_name text, competitor_brand text, equipment_kind text,
  decision_at timestamptz, decision_kind text, value_rupees bigint, lessons_md text, owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.comparison_id, c.chain_name, c.competitor_brand, c.equipment_kind,
         l.decision_at, l.decision_kind, l.value_rupees, l.lessons_md, l.owner_email
  FROM public.vendor_comparison_win_loss_log_r2567 l
  JOIN public.chain_vendor_comparison_r2567 c ON c.id = l.comparison_id
  ORDER BY l.decision_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_win_loss_log_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_win_loss_log_r2567() TO authenticated;

-- RPC 3: top competitor brands
CREATE OR REPLACE FUNCTION public.top_competitor_brands_r2567()
RETURNS TABLE (
  competitor_brand text,
  encounters bigint,
  we_won_count bigint,
  competitor_won_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.competitor_brand,
         COUNT(*)::bigint AS encounters,
         COUNT(*) FILTER (WHERE l.decision_kind='we_won')::bigint AS we_won_count,
         COUNT(*) FILTER (WHERE l.decision_kind='competitor_won')::bigint AS competitor_won_count,
         COALESCE(SUM(l.value_rupees),0)::bigint AS total_value_rupees
  FROM public.chain_vendor_comparison_r2567 c
  LEFT JOIN public.vendor_comparison_win_loss_log_r2567 l ON l.comparison_id = c.id
  GROUP BY c.competitor_brand
  ORDER BY encounters DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_competitor_brands_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_competitor_brands_r2567() TO authenticated;

-- RPC 4: equipment kind breakdown
CREATE OR REPLACE FUNCTION public.equipment_kind_breakdown_r2567()
RETURNS TABLE (
  equipment_kind text,
  comparison_count bigint,
  distinct_brands bigint,
  active_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.equipment_kind,
         COUNT(*)::bigint AS comparison_count,
         COUNT(DISTINCT c.competitor_brand)::bigint AS distinct_brands,
         COUNT(*) FILTER (WHERE c.status='active')::bigint AS active_count
  FROM public.chain_vendor_comparison_r2567 c
  GROUP BY c.equipment_kind
  ORDER BY comparison_count DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.equipment_kind_breakdown_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.equipment_kind_breakdown_r2567() TO authenticated;

-- RPC 5: win rate summary
CREATE OR REPLACE FUNCTION public.win_rate_summary_r2567()
RETURNS TABLE (
  total_decisions bigint,
  we_won bigint,
  competitor_won bigint,
  no_decision bigint,
  postponed bigint,
  win_rate_pct numeric,
  total_won_value_rupees bigint,
  total_lost_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_decisions,
    COUNT(*) FILTER (WHERE l.decision_kind='we_won')::bigint AS we_won,
    COUNT(*) FILTER (WHERE l.decision_kind='competitor_won')::bigint AS competitor_won,
    COUNT(*) FILTER (WHERE l.decision_kind='no_decision')::bigint AS no_decision,
    COUNT(*) FILTER (WHERE l.decision_kind='postponed')::bigint AS postponed,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE l.decision_kind='we_won')::numeric
      / NULLIF(COUNT(*) FILTER (WHERE l.decision_kind IN ('we_won','competitor_won'))::numeric, 0),
      2
    ) AS win_rate_pct,
    COALESCE(SUM(l.value_rupees) FILTER (WHERE l.decision_kind='we_won'),0)::bigint AS total_won_value_rupees,
    COALESCE(SUM(l.value_rupees) FILTER (WHERE l.decision_kind='competitor_won'),0)::bigint AS total_lost_value_rupees
  FROM public.vendor_comparison_win_loss_log_r2567 l;
END $$;
REVOKE EXECUTE ON FUNCTION public.win_rate_summary_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_rate_summary_r2567() TO authenticated;

-- RPC 6: monthly decision trend
CREATE OR REPLACE FUNCTION public.monthly_decision_trend_r2567()
RETURNS TABLE (
  month_label text,
  total bigint,
  we_won bigint,
  competitor_won bigint,
  value_won_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.decision_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE l.decision_kind='we_won')::bigint AS we_won,
         COUNT(*) FILTER (WHERE l.decision_kind='competitor_won')::bigint AS competitor_won,
         COALESCE(SUM(l.value_rupees) FILTER (WHERE l.decision_kind='we_won'),0)::bigint AS value_won_rupees
  FROM public.vendor_comparison_win_loss_log_r2567 l
  GROUP BY date_trunc('month', l.decision_at)
  ORDER BY date_trunc('month', l.decision_at) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_decision_trend_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_decision_trend_r2567() TO authenticated;

-- RPC 7: lessons focus (recent lost/postponed lessons)
CREATE OR REPLACE FUNCTION public.lessons_focus_r2567()
RETURNS TABLE (
  id uuid,
  decision_at timestamptz,
  chain_name text,
  competitor_brand text,
  equipment_kind text,
  decision_kind text,
  value_rupees bigint,
  lessons_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.decision_at, c.chain_name, c.competitor_brand, c.equipment_kind,
         l.decision_kind, l.value_rupees, l.lessons_md
  FROM public.vendor_comparison_win_loss_log_r2567 l
  JOIN public.chain_vendor_comparison_r2567 c ON c.id = l.comparison_id
  WHERE l.decision_kind IN ('competitor_won','postponed','no_decision')
    AND l.lessons_md IS NOT NULL
  ORDER BY l.decision_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.lessons_focus_r2567() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lessons_focus_r2567() TO authenticated;
