BEGIN;

-- =========================================================================
-- Round 2756 — Customer Monthly Portable Equipment Loss Recovery
-- HEAVY founder console: asset x last seen x loss type x recovery x cost x prevention
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: portable_equipment_loss_events_r2756
-- One row per portable asset reported missing / damaged / mis-located.
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.portable_equipment_loss_events_r2756 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_at timestamptz NOT NULL DEFAULT now(),
  month_key date NOT NULL,
  hospital_name text NOT NULL,
  asset_tag text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN (
    'pulse_oximeter','infusion_pump','glucometer','ecg_lead_kit',
    'doppler_probe','vital_monitor_battery','nebulizer','thermometer_gun'
  )),
  asset_replacement_cost_rupees numeric(12,2) NOT NULL CHECK (asset_replacement_cost_rupees >= 0),
  last_seen_location text NOT NULL,
  last_seen_at timestamptz NOT NULL,
  last_seen_custodian text NOT NULL,
  loss_type text NOT NULL CHECK (loss_type IN (
    'misplaced_in_ward','stolen','damaged_drop','taken_home_by_staff',
    'lost_in_transfer','battery_swapped','vendor_loaner_unreturned'
  )),
  recovery_status text NOT NULL CHECK (recovery_status IN (
    'open','located_in_ward','recovered_partial','recovered_full',
    'written_off','insurance_claimed','recharged_to_staff'
  )),
  recovered_at timestamptz,
  recovery_amount_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (recovery_amount_rupees >= 0),
  net_loss_rupees numeric(12,2) NOT NULL CHECK (net_loss_rupees >= 0),
  prevention_action text NOT NULL,
  prevention_owner text NOT NULL,
  prevention_due_date date NOT NULL,
  prevention_done boolean NOT NULL DEFAULT false,
  notes text
);

ALTER TABLE public.portable_equipment_loss_events_r2756 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.portable_equipment_loss_events_r2756;
CREATE POLICY founder_all ON public.portable_equipment_loss_events_r2756
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.portable_equipment_loss_events_r2756 (
  reported_at, month_key, hospital_name, asset_tag, asset_category,
  asset_replacement_cost_rupees, last_seen_location, last_seen_at, last_seen_custodian,
  loss_type, recovery_status, recovered_at, recovery_amount_rupees, net_loss_rupees,
  prevention_action, prevention_owner, prevention_due_date, prevention_done, notes
) VALUES
  ('2026-06-04 09:12:00+05:30','2026-06-01'::date,'Apollo Jubilee Hills','PO-JH-118','pulse_oximeter',
    4200,'ICU Bay 3','2026-06-03 22:40:00+05:30','Night Nurse Reema',
    'misplaced_in_ward','recovered_full','2026-06-04 11:05:00+05:30',4200,0,
    'BLE tag on every probe; nightly ward sweep at 23:00','Biomed Lead Rajesh','2026-06-15'::date,true,
    'Found inside crash-cart drawer 4.'),
  ('2026-06-07 14:50:00+05:30','2026-06-01'::date,'KIMS Secunderabad','IP-KS-077','infusion_pump',
    62000,'Oncology Day-Care','2026-06-06 18:30:00+05:30','Tech Aravind',
    'taken_home_by_staff','recharged_to_staff','2026-06-12 10:00:00+05:30',62000,0,
    'Mandatory asset-out register + biometric exit scan','Admin Sunita','2026-06-20'::date,true,
    'Tech borrowed for home use; full cost deducted from salary.'),
  ('2026-06-11 08:25:00+05:30','2026-06-01'::date,'Yashoda Somajiguda','GLU-YS-204','glucometer',
    1800,'Endo OPD','2026-06-10 17:15:00+05:30','OPD Sister Lakshmi',
    'stolen','written_off',NULL,0,1800,
    'CCTV review + lockable OPD trolleys','Security Head Mahesh','2026-06-25'::date,false,
    'CCTV blind-spot; FIR not filed (below threshold).'),
  ('2026-06-14 19:40:00+05:30','2026-06-01'::date,'Continental Hospital','ECG-CH-031','ecg_lead_kit',
    9500,'Cath Lab 2','2026-06-14 16:20:00+05:30','Cath Tech Vivek',
    'damaged_drop','recovered_partial','2026-06-16 12:30:00+05:30',3200,6300,
    'Rubberised cable trays + drop-replacement SOP','Cath Lab In-charge','2026-06-28'::date,false,
    'Connector cracked; salvage credit from vendor.'),
  ('2026-06-18 11:10:00+05:30','2026-06-01'::date,'Care Hospitals Banjara','DPR-CB-014','doppler_probe',
    145000,'Vascular OT','2026-06-17 20:00:00+05:30','OT Tech Ramya',
    'lost_in_transfer','insurance_claimed','2026-06-30 09:00:00+05:30',132000,13000,
    'Pelican case + sign-in/sign-out at OT door','OT Manager Priya','2026-07-05'::date,false,
    'Lost between OT and sterilisation; claim 91 percent.'),
  ('2026-06-21 15:30:00+05:30','2026-06-01'::date,'Sunshine Hospitals Gachibowli','BAT-SG-099','vital_monitor_battery',
    3400,'Step-Down ICU','2026-06-21 06:30:00+05:30','Tech Hemanth',
    'battery_swapped','located_in_ward','2026-06-22 08:00:00+05:30',3400,0,
    'Serial-number scan at every shift handover','Biomed Lead Rajesh','2026-07-01'::date,true,
    'Swapped with weaker unit from ER; restored.'),
  ('2026-06-24 10:00:00+05:30','2026-06-01'::date,'AIG Hospitals','NEB-AG-052','nebulizer',
    5800,'Pediatric Ward','2026-06-23 21:45:00+05:30','Nurse Anjali',
    'misplaced_in_ward','recovered_full','2026-06-24 14:00:00+05:30',5800,0,
    'Color-coded ward tagging + weekly audit','Ward Sister Kavitha','2026-07-08'::date,false,
    'Found in adjacent ward 7B trolley.'),
  ('2026-06-26 16:20:00+05:30','2026-06-01'::date,'Medicover Hitech City','TMG-MH-018','thermometer_gun',
    2100,'OPD Reception','2026-06-26 09:00:00+05:30','Reception Lead Pavan',
    'stolen','open',NULL,0,2100,
    'Tethered counter mount + reception SOP','OPD Manager','2026-07-10'::date,false,
    'Suspected visitor pilferage; CCTV inconclusive.'),
  ('2026-06-28 12:00:00+05:30','2026-06-01'::date,'Olive Hospitals','LOAN-OL-007','infusion_pump',
    58000,'Vendor Loaner Pool','2026-06-15 11:00:00+05:30','Vendor Rep Dinesh',
    'vendor_loaner_unreturned','recovered_full','2026-06-29 17:00:00+05:30',58000,0,
    'Loaner agreement with 7-day auto-bill clause','Procurement Head','2026-07-12'::date,true,
    'Vendor returned after escalation; full credit.');

CREATE INDEX IF NOT EXISTS idx_pelev_r2756_month ON public.portable_equipment_loss_events_r2756 (month_key);
CREATE INDEX IF NOT EXISTS idx_pelev_r2756_hospital ON public.portable_equipment_loss_events_r2756 (hospital_name);
CREATE INDEX IF NOT EXISTS idx_pelev_r2756_status ON public.portable_equipment_loss_events_r2756 (recovery_status);

-- -------------------------------------------------------------------------
-- Table 2: portable_equipment_prevention_playbook_r2756
-- Standing prevention controls + drill outcomes.
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.portable_equipment_prevention_playbook_r2756 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  control_code text NOT NULL UNIQUE,
  control_name text NOT NULL,
  control_category text NOT NULL CHECK (control_category IN (
    'tagging','physical_lock','sop','audit','insurance','staff_training','vendor_clause'
  )),
  rollout_status text NOT NULL CHECK (rollout_status IN (
    'planned','piloting','rolled_out','paused','retired'
  )),
  hospitals_covered int NOT NULL CHECK (hospitals_covered >= 0),
  monthly_cost_rupees numeric(12,2) NOT NULL CHECK (monthly_cost_rupees >= 0),
  estimated_loss_avoided_rupees numeric(12,2) NOT NULL CHECK (estimated_loss_avoided_rupees >= 0),
  effectiveness_score int NOT NULL CHECK (effectiveness_score BETWEEN 0 AND 100),
  owner_name text NOT NULL,
  last_review_date date NOT NULL,
  notes text
);

ALTER TABLE public.portable_equipment_prevention_playbook_r2756 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.portable_equipment_prevention_playbook_r2756;
CREATE POLICY founder_all ON public.portable_equipment_prevention_playbook_r2756
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.portable_equipment_prevention_playbook_r2756 (
  control_code, control_name, control_category, rollout_status, hospitals_covered,
  monthly_cost_rupees, estimated_loss_avoided_rupees, effectiveness_score,
  owner_name, last_review_date, notes
) VALUES
  ('CTRL-BLE-01','BLE asset tags on all portable probes','tagging','rolled_out',6,
    18500,142000,88,'Biomed Lead Rajesh','2026-06-15'::date,
    'Tag cost amortised over 12 months; 88 percent recovery uplift.'),
  ('CTRL-LOCK-02','Lockable OPD trolleys for glucometers/thermometers','physical_lock','piloting',3,
    9200,38000,72,'Security Head Mahesh','2026-06-20'::date,
    'Pilot in 3 hospitals; 72 percent reduction in stolen losses.'),
  ('CTRL-SOP-03','Shift-handover serial-number scan SOP','sop','rolled_out',8,
    4200,96000,81,'Ward Operations','2026-06-18'::date,
    'Battery and probe swaps caught within one shift.'),
  ('CTRL-AUDIT-04','Weekly portable-asset ward sweep','audit','rolled_out',7,
    12000,118000,84,'Internal Audit','2026-06-22'::date,
    'Catches misplaced-in-ward losses before month close.'),
  ('CTRL-INS-05','Portable-equipment rider on hospital insurance','insurance','rolled_out',9,
    22000,260000,67,'CFO Office','2026-05-30'::date,
    'Covers high-value probes; 91 percent claim ratio.'),
  ('CTRL-TRAIN-06','Quarterly tech training on loaner returns','staff_training','piloting',4,
    7500,52000,70,'HR Learning','2026-06-10'::date,
    'Reduced vendor-loaner unreturned events.'),
  ('CTRL-VEND-07','7-day auto-bill clause on vendor loaner agreements','vendor_clause','rolled_out',9,
    0,182000,92,'Procurement Head','2026-06-25'::date,
    'Zero monthly cost; pure contract leverage.'),
  ('CTRL-LOCK-08','Tethered counter-mount for OPD thermometer guns','physical_lock','planned',0,
    0,0,0,'Security Head Mahesh','2026-06-26'::date,
    'Quote stage; rollout July.');

CREATE INDEX IF NOT EXISTS idx_pepp_r2756_status ON public.portable_equipment_prevention_playbook_r2756 (rollout_status);
CREATE INDEX IF NOT EXISTS idx_pepp_r2756_category ON public.portable_equipment_prevention_playbook_r2756 (control_category);

-- =========================================================================
-- RPCs — all is_founder() gated, LANGUAGE plpgsql, SECURITY DEFINER
-- =========================================================================

-- RPC 1: monthly KPI summary
DROP FUNCTION IF EXISTS public.rpc_r2756_monthly_kpis();
CREATE OR REPLACE FUNCTION public.rpc_r2756_monthly_kpis()
RETURNS TABLE (
  total_events int,
  gross_loss_rupees numeric,
  recovery_rupees numeric,
  net_loss_rupees numeric,
  recovery_rate_pct numeric,
  open_events int,
  prevention_done_pct numeric
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
    COUNT(*)::int,
    COALESCE(SUM(asset_replacement_cost_rupees),0)::numeric,
    COALESCE(SUM(recovery_amount_rupees),0)::numeric,
    COALESCE(SUM(net_loss_rupees),0)::numeric,
    CASE WHEN COALESCE(SUM(asset_replacement_cost_rupees),0) = 0 THEN 0
         ELSE ROUND(100.0 * SUM(recovery_amount_rupees) / SUM(asset_replacement_cost_rupees),1)
    END,
    COUNT(*) FILTER (WHERE recovery_status = 'open')::int,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE prevention_done) / COUNT(*),1)
    END
  FROM public.portable_equipment_loss_events_r2756;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_monthly_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_monthly_kpis() TO authenticated;

-- RPC 2: by hospital
DROP FUNCTION IF EXISTS public.rpc_r2756_by_hospital();
CREATE OR REPLACE FUNCTION public.rpc_r2756_by_hospital()
RETURNS TABLE (
  hospital_name text,
  events int,
  gross_loss numeric,
  recovered numeric,
  net_loss numeric,
  open_count int
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
    e.hospital_name,
    COUNT(*)::int,
    COALESCE(SUM(e.asset_replacement_cost_rupees),0)::numeric,
    COALESCE(SUM(e.recovery_amount_rupees),0)::numeric,
    COALESCE(SUM(e.net_loss_rupees),0)::numeric,
    COUNT(*) FILTER (WHERE e.recovery_status = 'open')::int
  FROM public.portable_equipment_loss_events_r2756 e
  GROUP BY e.hospital_name
  ORDER BY SUM(e.net_loss_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_by_hospital() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_by_hospital() TO authenticated;

-- RPC 3: by loss type
DROP FUNCTION IF EXISTS public.rpc_r2756_by_loss_type();
CREATE OR REPLACE FUNCTION public.rpc_r2756_by_loss_type()
RETURNS TABLE (
  loss_type text,
  events int,
  gross_loss numeric,
  net_loss numeric,
  avg_recovery_pct numeric
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
    e.loss_type,
    COUNT(*)::int,
    COALESCE(SUM(e.asset_replacement_cost_rupees),0)::numeric,
    COALESCE(SUM(e.net_loss_rupees),0)::numeric,
    CASE WHEN COALESCE(SUM(e.asset_replacement_cost_rupees),0) = 0 THEN 0
         ELSE ROUND(100.0 * SUM(e.recovery_amount_rupees) / SUM(e.asset_replacement_cost_rupees),1)
    END
  FROM public.portable_equipment_loss_events_r2756 e
  GROUP BY e.loss_type
  ORDER BY SUM(e.net_loss_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_by_loss_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_by_loss_type() TO authenticated;

-- RPC 4: by asset category
DROP FUNCTION IF EXISTS public.rpc_r2756_by_asset_category();
CREATE OR REPLACE FUNCTION public.rpc_r2756_by_asset_category()
RETURNS TABLE (
  asset_category text,
  events int,
  gross_loss numeric,
  net_loss numeric,
  avg_unit_cost numeric
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
    e.asset_category,
    COUNT(*)::int,
    COALESCE(SUM(e.asset_replacement_cost_rupees),0)::numeric,
    COALESCE(SUM(e.net_loss_rupees),0)::numeric,
    COALESCE(ROUND(AVG(e.asset_replacement_cost_rupees),0),0)::numeric
  FROM public.portable_equipment_loss_events_r2756 e
  GROUP BY e.asset_category
  ORDER BY SUM(e.net_loss_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_by_asset_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_by_asset_category() TO authenticated;

-- RPC 5: open events needing action
DROP FUNCTION IF EXISTS public.rpc_r2756_open_events();
CREATE OR REPLACE FUNCTION public.rpc_r2756_open_events()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  asset_tag text,
  asset_category text,
  loss_type text,
  net_loss_rupees numeric,
  prevention_action text,
  prevention_owner text,
  prevention_due_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_name, e.asset_tag, e.asset_category,
         e.loss_type, e.net_loss_rupees, e.prevention_action,
         e.prevention_owner, e.prevention_due_date
  FROM public.portable_equipment_loss_events_r2756 e
  WHERE e.recovery_status IN ('open','located_in_ward','recovered_partial')
     OR e.prevention_done = false
  ORDER BY e.prevention_due_date ASC NULLS LAST, e.net_loss_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_open_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_open_events() TO authenticated;

-- RPC 6: prevention controls roi
DROP FUNCTION IF EXISTS public.rpc_r2756_prevention_roi();
CREATE OR REPLACE FUNCTION public.rpc_r2756_prevention_roi()
RETURNS TABLE (
  control_code text,
  control_name text,
  control_category text,
  rollout_status text,
  hospitals_covered int,
  monthly_cost_rupees numeric,
  estimated_loss_avoided_rupees numeric,
  roi_multiple numeric,
  effectiveness_score int
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
    p.control_code, p.control_name, p.control_category, p.rollout_status,
    p.hospitals_covered, p.monthly_cost_rupees, p.estimated_loss_avoided_rupees,
    CASE WHEN p.monthly_cost_rupees = 0 THEN NULL
         ELSE ROUND(p.estimated_loss_avoided_rupees / p.monthly_cost_rupees, 2)
    END,
    p.effectiveness_score
  FROM public.portable_equipment_prevention_playbook_r2756 p
  ORDER BY p.estimated_loss_avoided_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_prevention_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_prevention_roi() TO authenticated;

-- RPC 7: full event list (recent first)
DROP FUNCTION IF EXISTS public.rpc_r2756_events_list();
CREATE OR REPLACE FUNCTION public.rpc_r2756_events_list()
RETURNS TABLE (
  id uuid,
  reported_at timestamptz,
  hospital_name text,
  asset_tag text,
  asset_category text,
  last_seen_location text,
  last_seen_custodian text,
  loss_type text,
  recovery_status text,
  recovery_amount_rupees numeric,
  net_loss_rupees numeric,
  prevention_owner text,
  prevention_done boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.reported_at, e.hospital_name, e.asset_tag, e.asset_category,
         e.last_seen_location, e.last_seen_custodian, e.loss_type,
         e.recovery_status, e.recovery_amount_rupees, e.net_loss_rupees,
         e.prevention_owner, e.prevention_done
  FROM public.portable_equipment_loss_events_r2756 e
  ORDER BY e.reported_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_events_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_events_list() TO authenticated;

-- RPC 8: mark prevention done
DROP FUNCTION IF EXISTS public.rpc_r2756_mark_prevention_done(uuid);
CREATE OR REPLACE FUNCTION public.rpc_r2756_mark_prevention_done(p_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.portable_equipment_loss_events_r2756
     SET prevention_done = true
   WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2756_mark_prevention_done(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2756_mark_prevention_done(uuid) TO authenticated;

COMMIT;
