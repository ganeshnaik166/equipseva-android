BEGIN;

-- ============================================================================
-- Round r2875: Hospital Chain Quarterly Equipment Fleet Pre-Monsoon Audit
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: chain_monsoon_audit_assets_r2875
-- One row per chain × asset × audit cycle, with vulnerability scoring
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chain_monsoon_audit_assets_r2875 (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name                text NOT NULL,
  hospital_branch           text NOT NULL,
  city                      text NOT NULL,
  asset_code                text NOT NULL,
  asset_category            text NOT NULL CHECK (asset_category IN ('imaging','life_support','lab','sterilization','ot','dialysis','power_backup','hvac')),
  monsoon_vulnerability     text NOT NULL CHECK (monsoon_vulnerability IN ('low','moderate','high','critical')),
  last_audit_on             date NOT NULL,
  next_audit_due_on         date NOT NULL,
  checklist_items_total     integer NOT NULL CHECK (checklist_items_total >= 0),
  checklist_items_passed    integer NOT NULL CHECK (checklist_items_passed >= 0),
  prep_actions_done         integer NOT NULL CHECK (prep_actions_done >= 0),
  prep_actions_pending      integer NOT NULL CHECK (prep_actions_pending >= 0),
  outcome_status            text NOT NULL CHECK (outcome_status IN ('pass','pass_with_advisory','needs_remediation','fail')),
  verdict_score             numeric(5,2) NOT NULL CHECK (verdict_score >= 0 AND verdict_score <= 100),
  estimated_remediation_inr numeric(12,2) NOT NULL DEFAULT 0,
  created_at                timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_monsoon_audit_assets_r2875 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_monsoon_audit_assets_r2875;
CREATE POLICY founder_all ON public.chain_monsoon_audit_assets_r2875
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.chain_monsoon_audit_assets_r2875
  (chain_name, hospital_branch, city, asset_code, asset_category, monsoon_vulnerability, last_audit_on, next_audit_due_on, checklist_items_total, checklist_items_passed, prep_actions_done, prep_actions_pending, outcome_status, verdict_score, estimated_remediation_inr)
VALUES
  ('Apollo Group','Apollo Hyd-Jubilee','Hyderabad','MRI-A1','imaging','high','2026-06-15'::date,'2026-09-15'::date,42,40,12,2,'pass_with_advisory',92.50,45000.00),
  ('Apollo Group','Apollo Chennai-Greams','Chennai','VENT-7','life_support','critical','2026-06-12'::date,'2026-09-12'::date,38,30,8,6,'needs_remediation',68.40,180000.00),
  ('Manipal Hospitals','Manipal Blr-Whitefield','Bengaluru','DIAL-3','dialysis','high','2026-06-10'::date,'2026-09-10'::date,55,55,18,0,'pass',98.20,0.00),
  ('Fortis Healthcare','Fortis Mum-Mulund','Mumbai','UPS-12','power_backup','critical','2026-06-08'::date,'2026-09-08'::date,30,18,4,9,'fail',45.00,520000.00),
  ('Max Healthcare','Max Delhi-Saket','Delhi','HVAC-OT2','hvac','moderate','2026-06-14'::date,'2026-09-14'::date,28,26,9,1,'pass_with_advisory',88.75,32000.00),
  ('Narayana Health','Narayana Blr-HSR','Bengaluru','AUTOCLAVE-2','sterilization','moderate','2026-06-13'::date,'2026-09-13'::date,22,21,7,1,'pass',94.10,12000.00),
  ('AIIMS Network','AIIMS Patna','Patna','XRAY-MOB','imaging','critical','2026-06-09'::date,'2026-09-09'::date,40,28,6,7,'needs_remediation',62.30,240000.00);

-- ---------------------------------------------------------------------------
-- Table 2: chain_monsoon_audit_actions_r2875
-- Remediation / prep action tracker
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chain_monsoon_audit_actions_r2875 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id            uuid NOT NULL REFERENCES public.chain_monsoon_audit_assets_r2875(id) ON DELETE CASCADE,
  action_label        text NOT NULL,
  action_type         text NOT NULL CHECK (action_type IN ('seal_check','drainage','grounding','surge_protection','tarp_cover','dehumidifier','battery_swap','filter_change')),
  priority            text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  owner_role          text NOT NULL,
  due_on              date NOT NULL,
  completed_on        date,
  status              text NOT NULL CHECK (status IN ('open','in_progress','completed','blocked')),
  cost_inr            numeric(12,2) NOT NULL DEFAULT 0,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_monsoon_audit_actions_r2875 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_monsoon_audit_actions_r2875;
CREATE POLICY founder_all ON public.chain_monsoon_audit_actions_r2875
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'Seal MRI room ingress points', 'seal_check', 'p1', 'facility_lead', '2026-07-01'::date, '2026-06-20'::date, 'completed', 18000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='MRI-A1';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'Replace ventilator battery pack', 'battery_swap', 'p0', 'biomed_engineer', '2026-06-30'::date, NULL, 'in_progress', 95000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='VENT-7';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'Dialysis floor drainage check', 'drainage', 'p2', 'facility_lead', '2026-07-10'::date, '2026-06-18'::date, 'completed', 8000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='DIAL-3';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'UPS surge protection upgrade', 'surge_protection', 'p0', 'electrical_lead', '2026-06-25'::date, NULL, 'blocked', 320000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='UPS-12';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'OT HVAC filter swap', 'filter_change', 'p1', 'biomed_engineer', '2026-07-05'::date, NULL, 'open', 14000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='HVAC-OT2';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'Autoclave room dehumidifier deploy', 'dehumidifier', 'p2', 'facility_lead', '2026-07-08'::date, '2026-06-19'::date, 'completed', 22000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='AUTOCLAVE-2';

INSERT INTO public.chain_monsoon_audit_actions_r2875
  (asset_id, action_label, action_type, priority, owner_role, due_on, completed_on, status, cost_inr)
SELECT id, 'Mobile X-ray tarp cover procurement', 'tarp_cover', 'p1', 'procurement', '2026-06-28'::date, NULL, 'in_progress', 18000.00
FROM public.chain_monsoon_audit_assets_r2875 WHERE asset_code='XRAY-MOB';

-- ---------------------------------------------------------------------------
-- RPC 1: chain rollup
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_chain_rollup();
CREATE OR REPLACE FUNCTION public.r2875_chain_rollup()
RETURNS TABLE (
  chain_name text,
  asset_count bigint,
  avg_verdict numeric,
  critical_assets bigint,
  fail_or_remediation bigint,
  total_remediation_inr numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.chain_name,
    COUNT(*)::bigint,
    ROUND(AVG(a.verdict_score)::numeric, 2),
    COUNT(*) FILTER (WHERE a.monsoon_vulnerability = 'critical')::bigint,
    COUNT(*) FILTER (WHERE a.outcome_status IN ('fail','needs_remediation'))::bigint,
    COALESCE(SUM(a.estimated_remediation_inr), 0)::numeric
  FROM public.chain_monsoon_audit_assets_r2875 a
  GROUP BY a.chain_name
  ORDER BY COALESCE(SUM(a.estimated_remediation_inr),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_chain_rollup() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: vulnerability mix
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_vulnerability_mix();
CREATE OR REPLACE FUNCTION public.r2875_vulnerability_mix()
RETURNS TABLE (
  vulnerability text,
  asset_count bigint,
  avg_verdict numeric,
  total_pending_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.monsoon_vulnerability,
    COUNT(*)::bigint,
    ROUND(AVG(a.verdict_score)::numeric, 2),
    COALESCE(SUM(a.prep_actions_pending),0)::bigint
  FROM public.chain_monsoon_audit_assets_r2875 a
  GROUP BY a.monsoon_vulnerability
  ORDER BY CASE a.monsoon_vulnerability
    WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'moderate' THEN 2 ELSE 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_vulnerability_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_vulnerability_mix() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: outcome funnel
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_outcome_funnel();
CREATE OR REPLACE FUNCTION public.r2875_outcome_funnel()
RETURNS TABLE (
  outcome text,
  asset_count bigint,
  share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_count bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_count FROM public.chain_monsoon_audit_assets_r2875;
  IF total_count = 0 THEN total_count := 1; END IF;
  RETURN QUERY
  SELECT
    a.outcome_status,
    COUNT(*)::bigint,
    ROUND((COUNT(*)::numeric * 100 / total_count), 2)
  FROM public.chain_monsoon_audit_assets_r2875 a
  GROUP BY a.outcome_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_outcome_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_outcome_funnel() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: at-risk assets list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_at_risk_assets();
CREATE OR REPLACE FUNCTION public.r2875_at_risk_assets()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_branch text,
  asset_code text,
  asset_category text,
  monsoon_vulnerability text,
  verdict_score numeric,
  outcome_status text,
  prep_actions_pending integer,
  estimated_remediation_inr numeric,
  next_audit_due_on date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_branch, a.asset_code, a.asset_category,
         a.monsoon_vulnerability, a.verdict_score, a.outcome_status,
         a.prep_actions_pending, a.estimated_remediation_inr, a.next_audit_due_on
  FROM public.chain_monsoon_audit_assets_r2875 a
  WHERE a.outcome_status IN ('fail','needs_remediation')
     OR a.monsoon_vulnerability = 'critical'
  ORDER BY a.verdict_score ASC, a.estimated_remediation_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_at_risk_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_at_risk_assets() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: action board
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_action_board();
CREATE OR REPLACE FUNCTION public.r2875_action_board()
RETURNS TABLE (
  id uuid,
  chain_name text,
  asset_code text,
  action_label text,
  action_type text,
  priority text,
  owner_role text,
  due_on date,
  status text,
  cost_inr numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ac.id, a.chain_name, a.asset_code, ac.action_label, ac.action_type,
         ac.priority, ac.owner_role, ac.due_on, ac.status, ac.cost_inr
  FROM public.chain_monsoon_audit_actions_r2875 ac
  JOIN public.chain_monsoon_audit_assets_r2875 a ON a.id = ac.asset_id
  ORDER BY CASE ac.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
           ac.due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_action_board() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_action_board() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: category heatmap
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_category_heatmap();
CREATE OR REPLACE FUNCTION public.r2875_category_heatmap()
RETURNS TABLE (
  asset_category text,
  total_assets bigint,
  avg_verdict numeric,
  pending_actions bigint,
  remediation_inr numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_category,
         COUNT(*)::bigint,
         ROUND(AVG(a.verdict_score)::numeric, 2),
         COALESCE(SUM(a.prep_actions_pending),0)::bigint,
         COALESCE(SUM(a.estimated_remediation_inr),0)::numeric
  FROM public.chain_monsoon_audit_assets_r2875 a
  GROUP BY a.asset_category
  ORDER BY COALESCE(SUM(a.estimated_remediation_inr),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_category_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_category_heatmap() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: kpi snapshot
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.r2875_kpi_snapshot()
RETURNS TABLE (
  total_assets bigint,
  total_chains bigint,
  avg_verdict numeric,
  critical_assets bigint,
  failing_assets bigint,
  open_actions bigint,
  total_remediation_inr numeric,
  pass_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_n bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_n FROM public.chain_monsoon_audit_assets_r2875;
  IF total_n = 0 THEN total_n := 1; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.chain_monsoon_audit_assets_r2875)::bigint,
    (SELECT COUNT(DISTINCT chain_name) FROM public.chain_monsoon_audit_assets_r2875)::bigint,
    (SELECT ROUND(AVG(verdict_score)::numeric, 2) FROM public.chain_monsoon_audit_assets_r2875),
    (SELECT COUNT(*) FROM public.chain_monsoon_audit_assets_r2875 WHERE monsoon_vulnerability='critical')::bigint,
    (SELECT COUNT(*) FROM public.chain_monsoon_audit_assets_r2875 WHERE outcome_status IN ('fail','needs_remediation'))::bigint,
    (SELECT COUNT(*) FROM public.chain_monsoon_audit_actions_r2875 WHERE status IN ('open','in_progress','blocked'))::bigint,
    (SELECT COALESCE(SUM(estimated_remediation_inr),0)::numeric FROM public.chain_monsoon_audit_assets_r2875),
    ROUND(((SELECT COUNT(*) FROM public.chain_monsoon_audit_assets_r2875 WHERE outcome_status IN ('pass','pass_with_advisory'))::numeric * 100 / total_n), 2);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_kpi_snapshot() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: upcoming audits
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.r2875_upcoming_audits();
CREATE OR REPLACE FUNCTION public.r2875_upcoming_audits()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_branch text,
  asset_code text,
  next_audit_due_on date,
  days_until_due integer,
  monsoon_vulnerability text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_branch, a.asset_code,
         a.next_audit_due_on,
         (a.next_audit_due_on - CURRENT_DATE)::integer,
         a.monsoon_vulnerability
  FROM public.chain_monsoon_audit_assets_r2875 a
  ORDER BY a.next_audit_due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2875_upcoming_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2875_upcoming_audits() TO authenticated;

COMMIT;