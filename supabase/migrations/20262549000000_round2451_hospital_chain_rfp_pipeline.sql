-- Round 2451: hospital-chain-rfp-pipeline
-- chain × RFP × stage × shortlisted vendors × our position × win probability × decision date

CREATE TABLE IF NOT EXISTS public.chain_rfps_r2451 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  rfp_external_ref text,
  rfp_kind text NOT NULL CHECK (rfp_kind IN ('amc','cmc','new_equipment','spare_parts','install_only','training')),
  issued_at timestamptz NOT NULL,
  submission_due_at timestamptz NOT NULL,
  decision_due_at timestamptz,
  stage text NOT NULL CHECK (stage IN ('received','qualified','proposal_sent','shortlisted','finalist','won','lost','withdrawn')),
  our_position text CHECK (our_position IN ('leader','second','third','other')),
  shortlisted_vendors_md text,
  win_probability_pct int NOT NULL DEFAULT 0 CHECK (win_probability_pct >= 0 AND win_probability_pct <= 100),
  value_rupees bigint NOT NULL DEFAULT 0 CHECK (value_rupees >= 0),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chain_rfp_competitor_intel_r2451 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfp_id uuid NOT NULL REFERENCES public.chain_rfps_r2451(id) ON DELETE CASCADE,
  competitor_name text NOT NULL,
  strength text,
  weakness text,
  pricing_known_rupees bigint CHECK (pricing_known_rupees IS NULL OR pricing_known_rupees >= 0),
  our_counter_strategy_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_rfps_r2451 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_rfp_competitor_intel_r2451 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_rfps_r2451;
CREATE POLICY founder_all ON public.chain_rfps_r2451
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_rfp_competitor_intel_r2451;
CREATE POLICY founder_all ON public.chain_rfp_competitor_intel_r2451
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_rfps_r2451 (chain_name, rfp_external_ref, rfp_kind, issued_at, submission_due_at, decision_due_at, stage, our_position, shortlisted_vendors_md, win_probability_pct, value_rupees, owner_email, notes) VALUES
  ('Apollo Hospitals Enterprise', 'APL-RFP-2026-0142', 'amc', '2026-05-01'::timestamptz, '2026-06-10'::timestamptz, '2026-07-15'::timestamptz, 'finalist', 'leader', '- EquipSeva (us)\n- Trivitron\n- Skanray Services', 65, 18500000, 'founder@equipseva.in', 'Final pricing review with CFO'),
  ('Fortis Healthcare', 'FHL-RFP-26-0089', 'new_equipment', '2026-04-15'::timestamptz, '2026-05-30'::timestamptz, '2026-06-30'::timestamptz, 'shortlisted', 'second', '- GE Healthcare\n- EquipSeva (us)\n- Philips India\n- Siemens Healthineers', 40, 42000000, 'sales@equipseva.in', 'OEM-heavy shortlist; we are dark horse'),
  ('Manipal Hospitals', 'MNP-2026-RFP-0214', 'cmc', '2026-05-20'::timestamptz, '2026-06-25'::timestamptz, '2026-07-30'::timestamptz, 'proposal_sent', 'leader', '- EquipSeva (us)\n- HCL Healthcare\n- Wipro GE JV', 55, 24500000, 'founder@equipseva.in', 'Strong incumbent advantage on 4 of 7 sites'),
  ('Max Healthcare', 'MAX-RFP-2026-Q2-031', 'spare_parts', '2026-06-01'::timestamptz, '2026-06-30'::timestamptz, '2026-07-20'::timestamptz, 'qualified', 'third', '- Trivitron\n- Skanray\n- EquipSeva (us)\n- Wipro GE', 25, 9800000, 'sales@equipseva.in', 'Bonded-parts angle our differentiator'),
  ('Narayana Health', 'NH-2026-AMC-0067', 'amc', '2026-03-10'::timestamptz, '2026-04-20'::timestamptz, '2026-05-15'::timestamptz, 'won', 'leader', '- EquipSeva (us)\n- BPL Medical', 100, 15600000, 'founder@equipseva.in', 'Closed at 14% premium to L1; quality wins'),
  ('KIMS Hospitals', 'KIMS-RFP-2026-018', 'training', '2026-02-01'::timestamptz, '2026-03-01'::timestamptz, '2026-03-30'::timestamptz, 'lost', 'second', '- BPL Academy\n- EquipSeva (us)\n- Wipro Learn', 0, 2800000, 'sales@equipseva.in', 'Lost on local-language coverage');

INSERT INTO public.chain_rfp_competitor_intel_r2451 (rfp_id, competitor_name, strength, weakness, pricing_known_rupees, our_counter_strategy_md, notes) VALUES
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='APL-RFP-2026-0142'), 'Trivitron', 'Pan-India spare-parts depot', 'Slow ticket SLA in tier-2 cities', 17500000, '- Highlight 4h response SLA + bonded parts', 'Strongest competition'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='APL-RFP-2026-0142'), 'Skanray Services', 'OEM lineage on monitors', 'Limited multi-OEM coverage', 19200000, '- Show multi-OEM cert ladder on engineers', 'Premium pricing'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='FHL-RFP-26-0089'), 'GE Healthcare', 'OEM trust + financing tie-ups', 'High lifetime cost', 45000000, '- Lifetime cost analysis at 7-year horizon', 'OEM incumbent'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='FHL-RFP-26-0089'), 'Philips India', 'Imaging portfolio breadth', 'Closed AMC ecosystem', 44500000, '- Open spare ecosystem pitch', 'Heavy lobbying'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='MNP-2026-RFP-0214'), 'HCL Healthcare', 'IT-managed-services pedigree', 'Thin biomed bench', 25800000, '- Engineer tier-ladder showcase', 'Bundling angle'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='MAX-RFP-2026-Q2-031'), 'Trivitron', 'Spare-parts depth', 'Counterfeit incidents flagged 2025', 9200000, '- Bonded-parts provenance demo', 'Trust gap to exploit'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='NH-2026-AMC-0067'), 'BPL Medical', 'Local presence in Karnataka', 'Limited OEM coverage', 14800000, '- N/A (won)', 'Closed deal'),
  ((SELECT id FROM public.chain_rfps_r2451 WHERE rfp_external_ref='KIMS-RFP-2026-018'), 'BPL Academy', 'Telugu language coverage', 'No certification ladder', 2600000, '- Build Telugu module before next KIMS RFP', 'Lost on language');

-- RPCs

CREATE OR REPLACE FUNCTION public.list_rfps_r2451()
RETURNS TABLE (
  id uuid,
  chain_name text,
  rfp_external_ref text,
  rfp_kind text,
  issued_at timestamptz,
  submission_due_at timestamptz,
  decision_due_at timestamptz,
  stage text,
  our_position text,
  win_probability_pct int,
  value_rupees bigint,
  owner_email text,
  shortlisted_vendors_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.chain_name, r.rfp_external_ref, r.rfp_kind,
           r.issued_at, r.submission_due_at, r.decision_due_at,
           r.stage, r.our_position, r.win_probability_pct,
           r.value_rupees, r.owner_email, r.shortlisted_vendors_md
    FROM public.chain_rfps_r2451 r
    ORDER BY r.submission_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_rfps_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rfps_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_competitor_intel_r2451()
RETURNS TABLE (
  id uuid,
  rfp_id uuid,
  chain_name text,
  rfp_external_ref text,
  competitor_name text,
  strength text,
  weakness text,
  pricing_known_rupees bigint,
  our_counter_strategy_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.rfp_id, r.chain_name, r.rfp_external_ref,
           c.competitor_name, c.strength, c.weakness,
           c.pricing_known_rupees, c.our_counter_strategy_md
    FROM public.chain_rfp_competitor_intel_r2451 c
    JOIN public.chain_rfps_r2451 r ON r.id = c.rfp_id
    ORDER BY r.chain_name ASC, c.competitor_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_competitor_intel_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_competitor_intel_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.stage_funnel_r2451()
RETURNS TABLE (
  stage text,
  rfps int,
  total_value_rupees bigint,
  avg_win_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.stage,
           COUNT(*)::int AS rfps,
           COALESCE(SUM(r.value_rupees), 0)::bigint AS total_value_rupees,
           ROUND(AVG(r.win_probability_pct)::numeric, 1) AS avg_win_probability_pct
    FROM public.chain_rfps_r2451 r
    GROUP BY r.stage
    ORDER BY
      CASE r.stage
        WHEN 'received' THEN 1
        WHEN 'qualified' THEN 2
        WHEN 'proposal_sent' THEN 3
        WHEN 'shortlisted' THEN 4
        WHEN 'finalist' THEN 5
        WHEN 'won' THEN 6
        WHEN 'lost' THEN 7
        WHEN 'withdrawn' THEN 8
        ELSE 9
      END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.stage_funnel_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_funnel_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_value_rfps_r2451()
RETURNS TABLE (
  id uuid,
  chain_name text,
  rfp_external_ref text,
  rfp_kind text,
  stage text,
  our_position text,
  win_probability_pct int,
  value_rupees bigint,
  expected_value_rupees bigint,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.chain_name, r.rfp_external_ref, r.rfp_kind,
           r.stage, r.our_position, r.win_probability_pct,
           r.value_rupees,
           ((r.value_rupees * r.win_probability_pct) / 100)::bigint AS expected_value_rupees,
           r.owner_email
    FROM public.chain_rfps_r2451 r
    WHERE r.stage NOT IN ('won','lost','withdrawn')
    ORDER BY r.value_rupees DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_rfps_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_rfps_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.upcoming_decisions_r2451()
RETURNS TABLE (
  id uuid,
  chain_name text,
  rfp_external_ref text,
  rfp_kind text,
  stage text,
  decision_due_at timestamptz,
  days_to_decision int,
  win_probability_pct int,
  value_rupees bigint,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.chain_name, r.rfp_external_ref, r.rfp_kind,
           r.stage, r.decision_due_at,
           EXTRACT(DAY FROM (r.decision_due_at - now()))::int AS days_to_decision,
           r.win_probability_pct, r.value_rupees, r.owner_email
    FROM public.chain_rfps_r2451 r
    WHERE r.decision_due_at IS NOT NULL
      AND r.stage NOT IN ('won','lost','withdrawn')
    ORDER BY r.decision_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.upcoming_decisions_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_decisions_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.win_rate_by_kind_r2451()
RETURNS TABLE (
  rfp_kind text,
  total_closed int,
  won_count int,
  lost_count int,
  withdrawn_count int,
  win_rate_pct numeric,
  total_won_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.rfp_kind,
           COUNT(*) FILTER (WHERE r.stage IN ('won','lost','withdrawn'))::int AS total_closed,
           COUNT(*) FILTER (WHERE r.stage = 'won')::int AS won_count,
           COUNT(*) FILTER (WHERE r.stage = 'lost')::int AS lost_count,
           COUNT(*) FILTER (WHERE r.stage = 'withdrawn')::int AS withdrawn_count,
           CASE
             WHEN COUNT(*) FILTER (WHERE r.stage IN ('won','lost','withdrawn')) = 0 THEN 0
             ELSE ROUND(
               (COUNT(*) FILTER (WHERE r.stage = 'won')::numeric * 100.0)
               / NULLIF(COUNT(*) FILTER (WHERE r.stage IN ('won','lost','withdrawn'))::numeric, 0),
               1)
           END AS win_rate_pct,
           COALESCE(SUM(r.value_rupees) FILTER (WHERE r.stage = 'won'), 0)::bigint AS total_won_value_rupees
    FROM public.chain_rfps_r2451 r
    GROUP BY r.rfp_kind
    ORDER BY r.rfp_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.win_rate_by_kind_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_rate_by_kind_r2451() TO authenticated;


CREATE OR REPLACE FUNCTION public.monthly_pipeline_trend_r2451()
RETURNS TABLE (
  month_label text,
  rfps_received int,
  total_value_rupees bigint,
  expected_value_rupees bigint,
  won_count int,
  lost_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', r.issued_at), 'YYYY-MM') AS month_label,
           COUNT(*)::int AS rfps_received,
           COALESCE(SUM(r.value_rupees), 0)::bigint AS total_value_rupees,
           COALESCE(SUM((r.value_rupees * r.win_probability_pct) / 100), 0)::bigint AS expected_value_rupees,
           COUNT(*) FILTER (WHERE r.stage = 'won')::int AS won_count,
           COUNT(*) FILTER (WHERE r.stage = 'lost')::int AS lost_count
    FROM public.chain_rfps_r2451 r
    GROUP BY date_trunc('month', r.issued_at)
    ORDER BY date_trunc('month', r.issued_at) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2451() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2451() TO authenticated;
