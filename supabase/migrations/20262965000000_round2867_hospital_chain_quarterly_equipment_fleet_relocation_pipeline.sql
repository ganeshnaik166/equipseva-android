BEGIN;

-- =====================================================================
-- Round 2867 — Hospital Chain Quarterly Equipment Fleet Relocation Pipeline
-- =====================================================================

-- Drop functions first (if re-run)
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_pipeline_kpis() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_list() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_by_chain() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_by_reason() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_by_outcome() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_cost_summary() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_milestones() CASCADE;
DROP FUNCTION IF EXISTS public.fn_r2867_relocation_top_assets() CASCADE;

-- ---------------------------------------------------------------------
-- Table 1: relocation requests
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_relocations_r2867 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name      text NOT NULL,
  asset_tag       text NOT NULL,
  asset_category  text NOT NULL,
  from_site       text NOT NULL,
  to_site         text NOT NULL,
  reason          text NOT NULL CHECK (reason IN ('underutilization','capacity_balancing','site_closure','tech_upgrade','specialty_consolidation','disaster_recovery')),
  planned_quarter text NOT NULL,
  scheduled_date  date NOT NULL,
  completed_date  date,
  cost_rupees     bigint NOT NULL DEFAULT 0,
  outcome         text NOT NULL CHECK (outcome IN ('queued','in_transit','installed','commissioned','blocked','cancelled')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_relocations_r2867 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_chain_relocations_r2867;
CREATE POLICY founder_all ON public.hospital_chain_relocations_r2867
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.hospital_chain_relocations_r2867
  (chain_name, asset_tag, asset_category, from_site, to_site, reason, planned_quarter, scheduled_date, completed_date, cost_rupees, outcome, notes)
VALUES
  ('Apollo Group','APL-CT-0214','CT Scanner','Apollo Hyd Jubilee Hills','Apollo Vizag','underutilization','Q3-2026','2026-07-08'::date,'2026-07-22'::date,485000,'commissioned','64-slice; 35% util at source for 6 months'),
  ('Manipal Health','MNP-MRI-0098','MRI 1.5T','Manipal Bangalore Whitefield','Manipal Goa','capacity_balancing','Q3-2026','2026-08-12'::date,NULL,920000,'in_transit','Goa onco demand surge'),
  ('Fortis Network','FRT-CATH-0041','Cath Lab','Fortis Noida','Fortis Mohali','site_closure','Q3-2026','2026-07-30'::date,'2026-08-14'::date,1240000,'commissioned','Noida B-wing decommissioned'),
  ('Yashoda Chain','YSD-DLZ-0017','Dialysis Bank-8','Yashoda Somajiguda','Yashoda Hitech City','specialty_consolidation','Q3-2026','2026-09-04'::date,NULL,310000,'queued','Renal hub consolidation'),
  ('KIMS Group','KMS-USG-0163','Ultrasound Premium','KIMS Secunderabad','KIMS Kondapur','tech_upgrade','Q3-2026','2026-08-25'::date,NULL,72000,'blocked','Awaiting Kondapur biomedical clearance'),
  ('Apollo Group','APL-VENT-0078','ICU Ventilator x4','Apollo Chennai','Apollo Madurai','disaster_recovery','Q3-2026','2026-07-15'::date,'2026-07-19'::date,84000,'commissioned','Cyclone surge prep'),
  ('Aster DM','AST-XRAY-0211','Digital X-Ray','Aster Kochi','Aster Kannur','underutilization','Q3-2026','2026-09-12'::date,NULL,55000,'queued','Source util 22%');

-- ---------------------------------------------------------------------
-- Table 2: relocation milestones / events
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_relocation_milestones_r2867 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relocation_id   uuid NOT NULL REFERENCES public.hospital_chain_relocations_r2867(id) ON DELETE CASCADE,
  milestone       text NOT NULL CHECK (milestone IN ('approval','decommission','packing','dispatch','arrival','installation','calibration','handover','blocker')),
  status          text NOT NULL CHECK (status IN ('pending','in_progress','done','failed')),
  occurred_on     date NOT NULL,
  cost_delta_rupees bigint NOT NULL DEFAULT 0,
  owner_name      text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_relocation_milestones_r2867 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_chain_relocation_milestones_r2867;
CREATE POLICY founder_all ON public.hospital_chain_relocation_milestones_r2867
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.hospital_chain_relocation_milestones_r2867
  (relocation_id, milestone, status, occurred_on, cost_delta_rupees, owner_name, notes)
SELECT id,'approval','done','2026-07-01'::date,0,'Chain Procurement Head','Board sign-off'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='APL-CT-0214'
UNION ALL
SELECT id,'dispatch','done','2026-07-09'::date,180000,'Logistics Lead','Insured transit'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='APL-CT-0214'
UNION ALL
SELECT id,'installation','done','2026-07-20'::date,210000,'OEM Service','Floor reinforced'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='APL-CT-0214'
UNION ALL
SELECT id,'calibration','done','2026-07-22'::date,45000,'AERB Tech','Dose audit cleared'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='APL-CT-0214'
UNION ALL
SELECT id,'packing','in_progress','2026-08-10'::date,42000,'Site Biomed','Coil crate built'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='MNP-MRI-0098'
UNION ALL
SELECT id,'dispatch','in_progress','2026-08-12'::date,640000,'Cold Chain Vendor','Quench-safe truck'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='MNP-MRI-0098'
UNION ALL
SELECT id,'blocker','failed','2026-08-26'::date,0,'Kondapur Facility','HVAC tonnage short'
  FROM public.hospital_chain_relocations_r2867 WHERE asset_tag='KMS-USG-0163';

-- ---------------------------------------------------------------------
-- RPC 1: KPIs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_pipeline_kpis()
RETURNS TABLE(
  total_relocations bigint,
  completed bigint,
  in_transit bigint,
  blocked bigint,
  total_cost_rupees bigint,
  avg_cost_rupees bigint,
  chains_active bigint,
  this_quarter bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE outcome = 'commissioned')::bigint,
    COUNT(*) FILTER (WHERE outcome = 'in_transit')::bigint,
    COUNT(*) FILTER (WHERE outcome = 'blocked')::bigint,
    COALESCE(SUM(cost_rupees),0)::bigint,
    COALESCE(AVG(cost_rupees),0)::bigint,
    COUNT(DISTINCT chain_name)::bigint,
    COUNT(*) FILTER (WHERE planned_quarter = 'Q3-2026')::bigint
  FROM public.hospital_chain_relocations_r2867;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_pipeline_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_pipeline_kpis() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: full list
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_list()
RETURNS TABLE(
  id uuid,
  chain_name text,
  asset_tag text,
  asset_category text,
  from_site text,
  to_site text,
  reason text,
  planned_quarter text,
  scheduled_date date,
  completed_date date,
  cost_rupees bigint,
  outcome text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.asset_tag, r.asset_category, r.from_site, r.to_site,
         r.reason, r.planned_quarter, r.scheduled_date, r.completed_date,
         r.cost_rupees, r.outcome, r.notes
  FROM public.hospital_chain_relocations_r2867 r
  ORDER BY r.scheduled_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_list() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: rollup by chain
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_by_chain()
RETURNS TABLE(
  chain_name text,
  relocations bigint,
  completed bigint,
  blocked bigint,
  total_cost_rupees bigint,
  avg_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE r.outcome = 'commissioned')::bigint,
         COUNT(*) FILTER (WHERE r.outcome = 'blocked')::bigint,
         COALESCE(SUM(r.cost_rupees),0)::bigint,
         COALESCE(AVG(r.cost_rupees),0)::bigint
  FROM public.hospital_chain_relocations_r2867 r
  GROUP BY r.chain_name
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_by_chain() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: rollup by reason
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_by_reason()
RETURNS TABLE(
  reason text,
  cnt bigint,
  total_cost_rupees bigint,
  avg_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.reason,
         COUNT(*)::bigint,
         COALESCE(SUM(r.cost_rupees),0)::bigint,
         COALESCE(AVG(r.cost_rupees),0)::bigint
  FROM public.hospital_chain_relocations_r2867 r
  GROUP BY r.reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_by_reason() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: outcome breakdown
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_by_outcome()
RETURNS TABLE(
  outcome text,
  cnt bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.hospital_chain_relocations_r2867;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT r.outcome,
         COUNT(*)::bigint,
         ROUND((COUNT(*)::numeric / total::numeric) * 100, 1)
  FROM public.hospital_chain_relocations_r2867 r
  GROUP BY r.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_by_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_by_outcome() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: cost summary by category
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_cost_summary()
RETURNS TABLE(
  asset_category text,
  units bigint,
  total_cost_rupees bigint,
  avg_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.asset_category,
         COUNT(*)::bigint,
         COALESCE(SUM(r.cost_rupees),0)::bigint,
         COALESCE(AVG(r.cost_rupees),0)::bigint
  FROM public.hospital_chain_relocations_r2867 r
  GROUP BY r.asset_category
  ORDER BY SUM(r.cost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_cost_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_cost_summary() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: milestone log
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_milestones()
RETURNS TABLE(
  asset_tag text,
  chain_name text,
  milestone text,
  status text,
  occurred_on date,
  cost_delta_rupees bigint,
  owner_name text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.asset_tag, r.chain_name, m.milestone, m.status,
         m.occurred_on, m.cost_delta_rupees, m.owner_name, m.notes
  FROM public.hospital_chain_relocation_milestones_r2867 m
  JOIN public.hospital_chain_relocations_r2867 r ON r.id = m.relocation_id
  ORDER BY m.occurred_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_milestones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_milestones() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 8: top assets by cost
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_r2867_relocation_top_assets()
RETURNS TABLE(
  asset_tag text,
  asset_category text,
  chain_name text,
  from_site text,
  to_site text,
  cost_rupees bigint,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.asset_tag, r.asset_category, r.chain_name, r.from_site, r.to_site,
         r.cost_rupees, r.outcome
  FROM public.hospital_chain_relocations_r2867 r
  ORDER BY r.cost_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r2867_relocation_top_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2867_relocation_top_assets() TO authenticated;

COMMIT;
