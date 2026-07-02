BEGIN;

-- ============================================================================
-- Round 2719: Hospital Chain Quarterly Equipment Procurement Cycle
-- ============================================================================

-- Procurement cycles per chain per quarter
DROP TABLE IF EXISTS public.hospital_chain_procurement_cycles_r2719 CASCADE;
CREATE TABLE public.hospital_chain_procurement_cycles_r2719 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier_1','tier_2','tier_3','super_specialty')),
  quarter_label text NOT NULL,
  cycle_status text NOT NULL CHECK (cycle_status IN ('planning','rfp_open','bidding','evaluation','awarded','closed','cancelled')),
  budget_total_lakh numeric(12,2) NOT NULL CHECK (budget_total_lakh >= 0),
  budget_committed_lakh numeric(12,2) NOT NULL DEFAULT 0 CHECK (budget_committed_lakh >= 0),
  budget_remaining_lakh numeric(12,2) NOT NULL DEFAULT 0,
  equipment_categories text[] NOT NULL DEFAULT '{}',
  hospitals_in_scope int NOT NULL CHECK (hospitals_in_scope > 0),
  procurement_lead_name text NOT NULL,
  rfp_opened_at date,
  award_decided_at date,
  lessons_learned text,
  equipseva_share_lakh numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_procurement_cycles_r2719 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_chain_procurement_cycles_r2719;
CREATE POLICY founder_all ON public.hospital_chain_procurement_cycles_r2719
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.hospital_chain_procurement_cycles_r2719
(chain_name, chain_tier, quarter_label, cycle_status, budget_total_lakh, budget_committed_lakh, budget_remaining_lakh, equipment_categories, hospitals_in_scope, procurement_lead_name, rfp_opened_at, award_decided_at, lessons_learned, equipseva_share_lakh)
VALUES
('Apollo Hospitals Group','tier_1','Q1-2026','awarded',850.00,780.50,69.50,ARRAY['ventilators','dialysis','imaging'],38,'Suresh Kumar','2026-01-10'::date,'2026-02-25'::date,'Single-vendor lock-in caused 12% premium; recommend split award next quarter',92.00),
('Manipal Health Chain','tier_1','Q2-2026','evaluation',620.00,420.00,200.00,ARRAY['surgical','monitoring'],24,'Priya Iyer','2026-04-05'::date,NULL,NULL,0),
('Narayana Health Network','tier_1','Q1-2026','closed',1100.00,1085.00,15.00,ARRAY['cath_lab','imaging','dialysis'],22,'Dr. Devi Shetty Office','2026-01-15'::date,'2026-03-01'::date,'AMC bundled at procurement saved 8% lifecycle cost — replicate everywhere',128.50),
('KIMS Super-Specialty','super_specialty','Q2-2026','rfp_open',480.00,0,480.00,ARRAY['neuro_navigation','robotic_surgery'],8,'Bhaskar Rao','2026-04-20'::date,NULL,NULL,0),
('Fortis Tier-2 South','tier_2','Q1-2026','awarded',310.00,295.00,15.00,ARRAY['monitoring','sterilizers'],14,'Anita Menon','2026-01-25'::date,'2026-03-10'::date,'Tier-2 spec drift — chain HQ overrode hospital-level requirements thrice',34.50),
('Aster DM Healthcare','tier_1','Q2-2026','bidding',720.00,0,720.00,ARRAY['imaging','lab_diagnostics'],19,'Rajesh Nair','2026-04-12'::date,NULL,NULL,0),
('Yashoda Hospitals','tier_2','Q1-2026','cancelled',180.00,0,180.00,ARRAY['ventilators'],6,'Pavan Reddy','2026-02-01'::date,NULL,'Cancelled — chain restructuring froze capex; revisit Q3',0);

-- Bidder participation per cycle
DROP TABLE IF EXISTS public.hospital_chain_procurement_bidders_r2719 CASCADE;
CREATE TABLE public.hospital_chain_procurement_bidders_r2719 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.hospital_chain_procurement_cycles_r2719(id) ON DELETE CASCADE,
  bidder_name text NOT NULL,
  bidder_type text NOT NULL CHECK (bidder_type IN ('oem','distributor','reseller','direct_import')),
  bid_amount_lakh numeric(12,2) NOT NULL CHECK (bid_amount_lakh >= 0),
  bid_status text NOT NULL CHECK (bid_status IN ('submitted','shortlisted','rejected','winner','runner_up','withdrawn')),
  technical_score numeric(5,2) CHECK (technical_score IS NULL OR (technical_score >= 0 AND technical_score <= 100)),
  commercial_score numeric(5,2) CHECK (commercial_score IS NULL OR (commercial_score >= 0 AND commercial_score <= 100)),
  amc_bundled boolean NOT NULL DEFAULT false,
  equipseva_referred boolean NOT NULL DEFAULT false,
  evaluation_notes text,
  submitted_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_procurement_bidders_r2719 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_chain_procurement_bidders_r2719;
CREATE POLICY founder_all ON public.hospital_chain_procurement_bidders_r2719
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.hospital_chain_procurement_bidders_r2719
(cycle_id, bidder_name, bidder_type, bid_amount_lakh, bid_status, technical_score, commercial_score, amc_bundled, equipseva_referred, evaluation_notes, submitted_at)
SELECT id,'Philips Healthcare India','oem',780.50,'winner',92.00,85.50,true,true,'AMC bundled — Equipseva referral closed it', '2026-01-20'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Apollo Hospitals Group'
UNION ALL
SELECT id,'GE Healthcare','oem',810.00,'runner_up',90.50,78.00,false,false,'Higher commercial — lost on price', '2026-01-22'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Apollo Hospitals Group'
UNION ALL
SELECT id,'Siemens Healthineers','oem',1085.00,'winner',95.50,88.00,true,true,'Cath-lab bundle + AMC won decisively', '2026-02-05'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Narayana Health Network'
UNION ALL
SELECT id,'Mindray India','oem',420.00,'shortlisted',82.00,87.50,true,false,'Tech demos pending Q2 evaluation', '2026-04-15'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Manipal Health Chain'
UNION ALL
SELECT id,'Skanray Technologies','oem',295.00,'winner',78.00,92.00,true,true,'Domestic make-in-India edge + Equipseva intro', '2026-02-10'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Fortis Tier-2 South'
UNION ALL
SELECT id,'Medtronic India','distributor',320.00,'rejected',75.00,72.00,false,false,'Below technical threshold on sterilizers', '2026-02-08'::date FROM public.hospital_chain_procurement_cycles_r2719 WHERE chain_name='Fortis Tier-2 South';

-- recompute remaining
UPDATE public.hospital_chain_procurement_cycles_r2719
SET budget_remaining_lakh = budget_total_lakh - budget_committed_lakh;

-- ============================================================================
-- RPCs (all SECURITY DEFINER, founder-gated)
-- ============================================================================

-- 1. KPI snapshot
DROP FUNCTION IF EXISTS public.r2719_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.r2719_kpi_snapshot()
RETURNS TABLE (
  total_cycles int,
  awarded_cycles int,
  active_cycles int,
  total_budget_lakh numeric,
  committed_lakh numeric,
  equipseva_share_lakh numeric,
  win_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE cycle_status IN ('awarded','closed'))::int,
    COUNT(*) FILTER (WHERE cycle_status IN ('planning','rfp_open','bidding','evaluation'))::int,
    COALESCE(SUM(budget_total_lakh),0),
    COALESCE(SUM(budget_committed_lakh),0),
    COALESCE(SUM(equipseva_share_lakh),0),
    CASE WHEN COUNT(*) FILTER (WHERE cycle_status IN ('awarded','closed')) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE equipseva_share_lakh > 0)::numeric
                    / NULLIF(COUNT(*) FILTER (WHERE cycle_status IN ('awarded','closed')),0), 1)
    END
  FROM public.hospital_chain_procurement_cycles_r2719;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_kpi_snapshot() TO authenticated;

-- 2. Cycles list
DROP FUNCTION IF EXISTS public.r2719_cycles_list();
CREATE OR REPLACE FUNCTION public.r2719_cycles_list()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  quarter_label text,
  cycle_status text,
  budget_total_lakh numeric,
  budget_committed_lakh numeric,
  budget_remaining_lakh numeric,
  hospitals_in_scope int,
  equipseva_share_lakh numeric,
  award_decided_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.chain_tier, c.quarter_label, c.cycle_status,
         c.budget_total_lakh, c.budget_committed_lakh, c.budget_remaining_lakh,
         c.hospitals_in_scope, c.equipseva_share_lakh, c.award_decided_at
  FROM public.hospital_chain_procurement_cycles_r2719 c
  ORDER BY c.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_cycles_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_cycles_list() TO authenticated;

-- 3. Bidders list (joined with chain)
DROP FUNCTION IF EXISTS public.r2719_bidders_list();
CREATE OR REPLACE FUNCTION public.r2719_bidders_list()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  bidder_name text,
  bidder_type text,
  bid_amount_lakh numeric,
  bid_status text,
  technical_score numeric,
  commercial_score numeric,
  amc_bundled boolean,
  equipseva_referred boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, c.chain_name, c.quarter_label, b.bidder_name, b.bidder_type,
         b.bid_amount_lakh, b.bid_status, b.technical_score, b.commercial_score,
         b.amc_bundled, b.equipseva_referred
  FROM public.hospital_chain_procurement_bidders_r2719 b
  JOIN public.hospital_chain_procurement_cycles_r2719 c ON c.id = b.cycle_id
  ORDER BY c.quarter_label DESC, b.bid_amount_lakh DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_bidders_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_bidders_list() TO authenticated;

-- 4. Tier breakdown
DROP FUNCTION IF EXISTS public.r2719_tier_breakdown();
CREATE OR REPLACE FUNCTION public.r2719_tier_breakdown()
RETURNS TABLE (
  chain_tier text,
  cycle_count int,
  total_budget_lakh numeric,
  committed_lakh numeric,
  equipseva_share_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_tier, COUNT(*)::int,
         COALESCE(SUM(c.budget_total_lakh),0),
         COALESCE(SUM(c.budget_committed_lakh),0),
         COALESCE(SUM(c.equipseva_share_lakh),0)
  FROM public.hospital_chain_procurement_cycles_r2719 c
  GROUP BY c.chain_tier
  ORDER BY COALESCE(SUM(c.budget_total_lakh),0) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_tier_breakdown() TO authenticated;

-- 5. Winners only
DROP FUNCTION IF EXISTS public.r2719_winners_list();
CREATE OR REPLACE FUNCTION public.r2719_winners_list()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  bidder_name text,
  bid_amount_lakh numeric,
  amc_bundled boolean,
  equipseva_referred boolean,
  technical_score numeric,
  commercial_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.quarter_label, b.bidder_name, b.bid_amount_lakh,
         b.amc_bundled, b.equipseva_referred, b.technical_score, b.commercial_score
  FROM public.hospital_chain_procurement_bidders_r2719 b
  JOIN public.hospital_chain_procurement_cycles_r2719 c ON c.id = b.cycle_id
  WHERE b.bid_status = 'winner'
  ORDER BY b.bid_amount_lakh DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_winners_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_winners_list() TO authenticated;

-- 6. Lessons learned digest
DROP FUNCTION IF EXISTS public.r2719_lessons_digest();
CREATE OR REPLACE FUNCTION public.r2719_lessons_digest()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  cycle_status text,
  lessons_learned text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.quarter_label, c.cycle_status, c.lessons_learned
  FROM public.hospital_chain_procurement_cycles_r2719 c
  WHERE c.lessons_learned IS NOT NULL AND length(c.lessons_learned) > 0
  ORDER BY c.award_decided_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_lessons_digest() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_lessons_digest() TO authenticated;

-- 7. Equipseva attach analytics
DROP FUNCTION IF EXISTS public.r2719_equipseva_attach();
CREATE OR REPLACE FUNCTION public.r2719_equipseva_attach()
RETURNS TABLE (
  chain_name text,
  cycles_total int,
  cycles_referred int,
  total_bid_value_lakh numeric,
  referred_bid_value_lakh numeric,
  attach_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name,
         COUNT(DISTINCT c.id)::int,
         COUNT(DISTINCT c.id) FILTER (WHERE b.equipseva_referred)::int,
         COALESCE(SUM(b.bid_amount_lakh),0),
         COALESCE(SUM(b.bid_amount_lakh) FILTER (WHERE b.equipseva_referred),0),
         CASE WHEN COUNT(DISTINCT c.id) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(DISTINCT c.id) FILTER (WHERE b.equipseva_referred)::numeric
                         / NULLIF(COUNT(DISTINCT c.id),0), 1) END
  FROM public.hospital_chain_procurement_cycles_r2719 c
  LEFT JOIN public.hospital_chain_procurement_bidders_r2719 b ON b.cycle_id = c.id
  GROUP BY c.chain_name
  ORDER BY COALESCE(SUM(b.bid_amount_lakh),0) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_equipseva_attach() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_equipseva_attach() TO authenticated;

-- 8. Quarter pipeline (active vs awarded)
DROP FUNCTION IF EXISTS public.r2719_quarter_pipeline();
CREATE OR REPLACE FUNCTION public.r2719_quarter_pipeline()
RETURNS TABLE (
  quarter_label text,
  active_count int,
  awarded_count int,
  cancelled_count int,
  pipeline_lakh numeric,
  awarded_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.quarter_label,
         COUNT(*) FILTER (WHERE c.cycle_status IN ('planning','rfp_open','bidding','evaluation'))::int,
         COUNT(*) FILTER (WHERE c.cycle_status IN ('awarded','closed'))::int,
         COUNT(*) FILTER (WHERE c.cycle_status = 'cancelled')::int,
         COALESCE(SUM(c.budget_total_lakh) FILTER (WHERE c.cycle_status IN ('planning','rfp_open','bidding','evaluation')),0),
         COALESCE(SUM(c.budget_committed_lakh) FILTER (WHERE c.cycle_status IN ('awarded','closed')),0)
  FROM public.hospital_chain_procurement_cycles_r2719 c
  GROUP BY c.quarter_label
  ORDER BY c.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.r2719_quarter_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2719_quarter_pipeline() TO authenticated;

COMMIT;