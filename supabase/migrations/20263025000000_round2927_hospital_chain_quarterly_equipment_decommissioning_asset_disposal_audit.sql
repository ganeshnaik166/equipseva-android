-- Round r2927: Hospital Chain Quarterly Equipment Decommissioning & Asset Disposal Audit
-- 1500 +50-MAJORS MILESTONE BATCH. HEAVY.

BEGIN;

-- =========================================================================
-- TABLE 1: decommission_audits_r2927
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.decommission_audits_r2927 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_branch text NOT NULL,
  city text NOT NULL,
  quarter text NOT NULL,
  audit_window_start date NOT NULL,
  audit_window_end date NOT NULL,
  equipment_category text NOT NULL,
  asset_tag text NOT NULL,
  asset_serial text NOT NULL,
  manufacturer text NOT NULL,
  acquisition_year int NOT NULL,
  acquisition_cost_rupees bigint NOT NULL,
  book_value_rupees bigint NOT NULL,
  salvage_value_rupees bigint NOT NULL,
  decommission_reason text NOT NULL,
  disposal_method text NOT NULL,
  disposal_status text NOT NULL,
  certified_by_engineer_email text,
  biohazard_flag boolean NOT NULL DEFAULT false,
  radiation_flag boolean NOT NULL DEFAULT false,
  data_wipe_required boolean NOT NULL DEFAULT false,
  data_wipe_completed boolean NOT NULL DEFAULT false,
  cpcb_eligible boolean NOT NULL DEFAULT false,
  cpcb_form_filed boolean NOT NULL DEFAULT false,
  disposed_at timestamptz,
  audit_findings text
);

ALTER TABLE public.decommission_audits_r2927 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: disposal_vendors_r2927
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.disposal_vendors_r2927 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  vendor_name text NOT NULL,
  vendor_city text NOT NULL,
  cpcb_registration_no text NOT NULL,
  cpcb_expires_on date NOT NULL,
  vendor_category text NOT NULL,
  total_units_handled int NOT NULL DEFAULT 0,
  total_kg_recycled numeric(12,2) NOT NULL DEFAULT 0,
  total_payout_rupees bigint NOT NULL DEFAULT 0,
  rating numeric(3,2) NOT NULL DEFAULT 0,
  last_pickup_at timestamptz,
  compliance_flag text NOT NULL DEFAULT 'green',
  is_active boolean NOT NULL DEFAULT true,
  insurance_cover_lakhs int NOT NULL DEFAULT 0,
  contract_signed_on date,
  notes text
);

ALTER TABLE public.disposal_vendors_r2927 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED: decommission_audits_r2927 (20 rows)
-- =========================================================================
INSERT INTO public.decommission_audits_r2927
  (chain_name, hospital_branch, city, quarter, audit_window_start, audit_window_end,
   equipment_category, asset_tag, asset_serial, manufacturer, acquisition_year,
   acquisition_cost_rupees, book_value_rupees, salvage_value_rupees,
   decommission_reason, disposal_method, disposal_status, certified_by_engineer_email,
   biohazard_flag, radiation_flag, data_wipe_required, data_wipe_completed,
   cpcb_eligible, cpcb_form_filed, disposed_at, audit_findings)
VALUES
  ('Apollo','Apollo Jubilee Hills','Hyderabad','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'CT Scanner','APL-CT-0192','GE-CT-7782311','GE Healthcare',2012,42000000,3800000,1800000,'EOL - 14 yr','authorized_recycler','disposed','rajesh@equipseva.in',false,true,true,true,true,true,'2026-02-14'::timestamptz,'Lead shielding intact; CPCB filed'),
  ('Apollo','Apollo Hyderguda','Hyderabad','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Ventilator','APL-VENT-0411','PHL-VENT-44A1','Philips',2015,1800000,420000,90000,'beyond_repair','authorized_recycler','disposed','suresh@equipseva.in',true,false,false,false,false,false,'2026-02-22'::timestamptz,'Biohazard tag verified'),
  ('Manipal','Manipal Whitefield','Bangalore','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'MRI 1.5T','MNP-MRI-0033','SMS-MRI-99X','Siemens',2010,98000000,4200000,3500000,'EOL - 16 yr','manufacturer_buyback','pending_pickup','arjun@equipseva.in',false,true,true,false,true,false,NULL,'Helium offload pending'),
  ('Manipal','Manipal Old Airport Rd','Bangalore','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Ultrasound','MNP-USG-1102','GE-USG-LE9-22','GE Healthcare',2014,2200000,540000,180000,'EOL - 12 yr','resale_charity','disposed','arjun@equipseva.in',false,false,true,true,false,false,'2026-03-04'::timestamptz,'Donated to PHC Anekal'),
  ('Fortis','Fortis Anandapur','Kolkata','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Defibrillator','FRT-DEF-0218','PHL-DEF-2055','Philips',2013,420000,38000,12000,'beyond_repair','authorized_recycler','disposed','debasis@equipseva.in',false,false,false,false,false,false,'2026-02-09'::timestamptz,'Battery pack quarantined'),
  ('Fortis','Fortis Mulund','Mumbai','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'X-Ray Portable','FRT-XR-0904','SMS-XR-PMX','Siemens',2011,3200000,210000,80000,'EOL - 15 yr','authorized_recycler','quarantined','milind@equipseva.in',false,true,false,false,true,false,NULL,'AERB clearance pending'),
  ('Max Healthcare','Max Saket','Delhi','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Dialysis Machine','MAX-DLY-0670','FRS-DLY-K3','Fresenius',2014,1400000,310000,75000,'EOL - 12 yr','authorized_recycler','disposed','vikas@equipseva.in',true,false,false,false,false,false,'2026-03-12'::timestamptz,'Decontaminated pre-pickup'),
  ('Max Healthcare','Max Patparganj','Delhi','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Patient Monitor','MAX-MON-1455','PHL-MON-IX9','Philips',2016,180000,42000,9000,'obsolete_os','authorized_recycler','disposed','vikas@equipseva.in',false,false,true,true,false,false,'2026-03-18'::timestamptz,'Data wipe verified NIST 800-88'),
  ('Narayana Health','NH Bangalore','Bangalore','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Cath Lab','NH-CL-0009','GE-CL-IGS-7','GE Healthcare',2009,140000000,5100000,4200000,'EOL - 17 yr','manufacturer_buyback','disposed','arjun@equipseva.in',false,true,true,true,true,true,'2026-03-24'::timestamptz,'GE buyback complete'),
  ('Medanta','Medanta Gurgaon','Gurgaon','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Infusion Pump','MED-INF-2210','BBR-INF-PA','B Braun',2017,95000,28000,4000,'beyond_repair','authorized_recycler','disposed','vikas@equipseva.in',false,false,false,false,false,false,'2026-02-27'::timestamptz,NULL),
  ('AIIMS','AIIMS Delhi','Delhi','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Anesthesia Workstation','AIIMS-ANS-0042','GE-AVANCE-2','GE Healthcare',2013,2800000,520000,130000,'EOL - 13 yr','authorized_recycler','pending_pickup','vikas@equipseva.in',true,false,true,false,false,false,NULL,'CISF clearance scheduled'),
  ('Apollo','Apollo Chennai','Chennai','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Linac (Radiotherapy)','APL-LIN-0006','VAR-LIN-CLN','Varian',2008,210000000,6200000,5500000,'EOL - 18 yr','authorized_recycler','quarantined','rajesh@equipseva.in',false,true,true,false,true,false,NULL,'AERB Form-X awaited'),
  ('Apollo','Apollo Bhubaneswar','Bhubaneswar','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'ECG Machine','APL-ECG-3320','BPL-CARDIO-12','BPL',2018,140000,52000,11000,'obsolete_os','resale_charity','disposed','debasis@equipseva.in',false,false,true,true,false,false,'2026-03-09'::timestamptz,'Donated CHC Khurda'),
  ('Fortis','Fortis Bannerghatta','Bangalore','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'CT Scanner','FRT-CT-0061','SMS-SOMA-AS','Siemens',2011,55000000,4100000,2100000,'EOL - 15 yr','manufacturer_buyback','disposed','arjun@equipseva.in',false,true,true,true,true,true,'2026-03-15'::timestamptz,'Buyback credited 35L'),
  ('Manipal','Manipal Vijayawada','Vijayawada','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Surgical Microscope','MNP-MIC-0518','LEI-OPMI-9','Leica',2012,3800000,610000,180000,'EOL - 14 yr','resale_charity','disposed','rajesh@equipseva.in',false,false,false,false,false,false,'2026-02-19'::timestamptz,'Donated dental college'),
  ('Max Healthcare','Max Shalimar Bagh','Delhi','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Autoclave','MAX-AUT-0091','GTI-AUT-50','Getinge',2010,820000,71000,18000,'EOL - 16 yr','authorized_recycler','disposed','vikas@equipseva.in',true,false,false,false,false,false,'2026-03-02'::timestamptz,'Pressure vessel scrapped'),
  ('Narayana Health','NH Howrah','Kolkata','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'C-Arm','NH-CARM-0144','SMS-CIOS-A','Siemens',2013,4200000,720000,240000,'EOL - 13 yr','authorized_recycler','pending_pickup','debasis@equipseva.in',false,true,true,false,true,false,NULL,'Lead apron audit pending'),
  ('Medanta','Medanta Lucknow','Lucknow','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Hemodialysis Unit','MED-HD-0299','NIP-HD-2','Nipro',2015,1100000,290000,68000,'EOL - 11 yr','authorized_recycler','disposed','vikas@equipseva.in',true,false,false,false,false,false,'2026-03-21'::timestamptz,NULL),
  ('Apollo','Apollo Vizag','Visakhapatnam','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Mammography','APL-MAM-0072','HOL-SEL-3D','Hologic',2014,9800000,1800000,520000,'EOL - 12 yr','manufacturer_buyback','disposed','rajesh@equipseva.in',false,true,true,true,true,true,'2026-03-26'::timestamptz,'Hologic trade-in done'),
  ('Fortis','Fortis Noida','Noida','Q1-2026','2026-01-01'::date,'2026-03-31'::date,'Endoscopy Tower','FRT-END-0510','OLY-CV190','Olympus',2016,5600000,1400000,360000,'EOL - 10 yr','authorized_recycler','disposed','vikas@equipseva.in',true,false,true,true,false,false,'2026-03-28'::timestamptz,'Optical fibres salvaged');

-- =========================================================================
-- SEED: disposal_vendors_r2927 (15 rows)
-- =========================================================================
INSERT INTO public.disposal_vendors_r2927
  (vendor_name, vendor_city, cpcb_registration_no, cpcb_expires_on, vendor_category,
   total_units_handled, total_kg_recycled, total_payout_rupees, rating, last_pickup_at,
   compliance_flag, is_active, insurance_cover_lakhs, contract_signed_on, notes)
VALUES
  ('Attero Recycling','Roorkee','CPCB-EW-2018-0042','2027-08-31'::date,'e_waste_authorized',412,18200.50,2840000,4.80,'2026-03-28'::timestamptz,'green',true,500,'2024-04-01'::date,'Pan-India coverage'),
  ('EcoCentric Management','Hyderabad','CPCB-BMW-2019-0177','2026-11-30'::date,'biomedical_waste',289,9120.00,1620000,4.55,'2026-03-26'::timestamptz,'green',true,250,'2024-06-12'::date,'TS/AP zone'),
  ('Saahas Zero Waste','Bangalore','CPCB-EW-2020-0061','2027-03-15'::date,'e_waste_authorized',198,7400.75,920000,4.40,'2026-03-22'::timestamptz,'green',true,200,'2024-09-01'::date,'Karnataka exclusive'),
  ('Ramky Enviro','Hyderabad','CPCB-HZ-2017-0019','2026-07-31'::date,'hazardous_waste',367,21500.00,3120000,4.65,'2026-03-21'::timestamptz,'amber',true,800,'2023-11-20'::date,'CPCB renewal due Q3'),
  ('TES-AMM Recycling','Chennai','CPCB-EW-2018-0099','2027-12-31'::date,'e_waste_authorized',452,19800.25,3450000,4.85,'2026-03-27'::timestamptz,'green',true,600,'2023-08-15'::date,'ITAD specialist'),
  ('Greenscape Eco','Pune','CPCB-EW-2021-0008','2028-01-31'::date,'e_waste_authorized',141,5200.00,610000,4.20,'2026-03-19'::timestamptz,'green',true,150,'2025-02-01'::date,'New entrant'),
  ('GE Healthcare TradeIn','Bangalore','OEM-BUYBACK-GE-22','2027-06-30'::date,'manufacturer_buyback',62,0.00,11200000,4.95,'2026-03-24'::timestamptz,'green',true,2000,'2022-04-01'::date,'OEM channel'),
  ('Siemens ReFurb','Mumbai','OEM-BUYBACK-SMS-19','2027-09-30'::date,'manufacturer_buyback',48,0.00,9800000,4.92,'2026-03-15'::timestamptz,'green',true,2000,'2022-06-20'::date,'OEM channel'),
  ('Philips Lifecycle','Pune','OEM-BUYBACK-PHL-21','2027-11-30'::date,'manufacturer_buyback',39,0.00,6400000,4.88,'2026-03-12'::timestamptz,'green',true,1500,'2022-09-01'::date,'OEM channel'),
  ('Greentek Reman','Kolkata','CPCB-EW-2019-0144','2025-08-31'::date,'e_waste_authorized',88,3100.00,420000,3.80,'2026-03-08'::timestamptz,'red',false,80,'2024-01-15'::date,'CPCB EXPIRED — DO NOT USE'),
  ('Cerebra Integrated','Bangalore','CPCB-EW-2018-0066','2026-09-30'::date,'e_waste_authorized',176,6800.00,820000,4.10,'2026-03-11'::timestamptz,'green',true,180,'2024-05-10'::date,NULL),
  ('Hulladek Recycling','Kolkata','CPCB-EW-2020-0091','2027-04-30'::date,'e_waste_authorized',103,4200.00,540000,4.30,'2026-03-17'::timestamptz,'green',true,120,'2024-08-22'::date,'East India'),
  ('Saraplast 3S','Pune','CPCB-BMW-2017-0024','2026-10-31'::date,'biomedical_waste',225,8400.00,1290000,4.45,'2026-03-23'::timestamptz,'green',true,300,'2023-12-01'::date,NULL),
  ('Re Sustainability','Hyderabad','CPCB-HZ-2018-0011','2027-02-28'::date,'hazardous_waste',314,17200.00,2180000,4.70,'2026-03-25'::timestamptz,'green',true,750,'2023-07-10'::date,NULL),
  ('Synergy Waste Mgmt','Gurgaon','CPCB-BMW-2019-0202','2026-12-31'::date,'biomedical_waste',192,7100.00,1080000,4.35,'2026-03-20'::timestamptz,'green',true,260,'2024-03-05'::date,'NCR zone');

-- =========================================================================
-- is_founder() helper assumption — already exists in schema. Inline guard.
-- =========================================================================

-- ---- RPC 1: chain_summary_r2927 ------------------------------------------
DROP FUNCTION IF EXISTS public.chain_summary_r2927();
CREATE OR REPLACE FUNCTION public.chain_summary_r2927()
RETURNS TABLE (
  id uuid,
  chain_name text,
  branches int,
  total_units int,
  total_book_value_lakhs numeric,
  total_salvage_lakhs numeric,
  pending_pickup_units int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    gen_random_uuid()                                                   AS id,
    d.chain_name                                                        AS chain_name,
    COUNT(DISTINCT d.hospital_branch)::int                              AS branches,
    COUNT(*)::int                                                       AS total_units,
    ROUND(SUM(d.book_value_rupees)::numeric / 100000.0, 2)              AS total_book_value_lakhs,
    ROUND(SUM(d.salvage_value_rupees)::numeric / 100000.0, 2)           AS total_salvage_lakhs,
    SUM(CASE WHEN d.disposal_status = 'pending_pickup' THEN 1 ELSE 0 END)::int AS pending_pickup_units
  FROM public.decommission_audits_r2927 d
  GROUP BY d.chain_name
  ORDER BY total_book_value_lakhs DESC;
END;
$$;

-- ---- RPC 2: category_breakdown_r2927 -------------------------------------
DROP FUNCTION IF EXISTS public.category_breakdown_r2927();
CREATE OR REPLACE FUNCTION public.category_breakdown_r2927()
RETURNS TABLE (
  id uuid,
  equipment_category text,
  units int,
  avg_acquisition_lakhs numeric,
  avg_book_lakhs numeric,
  recovery_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    gen_random_uuid()                                              AS id,
    d.equipment_category                                           AS equipment_category,
    COUNT(*)::int                                                  AS units,
    ROUND(AVG(d.acquisition_cost_rupees)::numeric/100000.0, 2)     AS avg_acquisition_lakhs,
    ROUND(AVG(d.book_value_rupees)::numeric/100000.0, 2)           AS avg_book_lakhs,
    ROUND(
      100.0 * SUM(d.salvage_value_rupees)::numeric
      / NULLIF(SUM(d.book_value_rupees), 0),
      2
    )                                                              AS recovery_pct
  FROM public.decommission_audits_r2927 d
  GROUP BY d.equipment_category
  ORDER BY units DESC;
END;
$$;

-- ---- RPC 3: vendor_scorecard_r2927 ---------------------------------------
DROP FUNCTION IF EXISTS public.vendor_scorecard_r2927();
CREATE OR REPLACE FUNCTION public.vendor_scorecard_r2927()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  vendor_city text,
  total_units_handled int,
  total_payout_lakhs numeric,
  rating numeric,
  compliance_flag text,
  days_to_cpcb_expiry int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    v.id,
    v.vendor_name,
    v.vendor_category,
    v.vendor_city,
    v.total_units_handled,
    ROUND(v.total_payout_rupees::numeric / 100000.0, 2) AS total_payout_lakhs,
    v.rating,
    v.compliance_flag,
    (v.cpcb_expires_on - CURRENT_DATE)::int AS days_to_cpcb_expiry
  FROM public.disposal_vendors_r2927 v
  ORDER BY v.compliance_flag DESC, v.rating DESC;
END;
$$;

-- ---- RPC 4: compliance_risk_queue_r2927 ----------------------------------
DROP FUNCTION IF EXISTS public.compliance_risk_queue_r2927();
CREATE OR REPLACE FUNCTION public.compliance_risk_queue_r2927()
RETURNS TABLE (
  id uuid,
  asset_tag text,
  chain_name text,
  hospital_branch text,
  equipment_category text,
  risk_reason text,
  severity text,
  audit_findings text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.asset_tag,
    d.chain_name,
    d.hospital_branch,
    d.equipment_category,
    CASE
      WHEN d.cpcb_eligible AND NOT d.cpcb_form_filed THEN 'CPCB form NOT filed'
      WHEN d.data_wipe_required AND NOT d.data_wipe_completed THEN 'Data wipe pending'
      WHEN d.radiation_flag AND d.disposal_status <> 'disposed' THEN 'Radiation source quarantined'
      WHEN d.biohazard_flag AND d.disposal_status = 'pending_pickup' THEN 'Biohazard awaiting pickup'
      ELSE 'unspecified'
    END AS risk_reason,
    CASE
      WHEN d.cpcb_eligible AND NOT d.cpcb_form_filed THEN 'p0'
      WHEN d.radiation_flag AND d.disposal_status <> 'disposed' THEN 'p0'
      WHEN d.data_wipe_required AND NOT d.data_wipe_completed THEN 'p1'
      WHEN d.biohazard_flag AND d.disposal_status = 'pending_pickup' THEN 'p1'
      ELSE 'p2'
    END AS severity,
    d.audit_findings
  FROM public.decommission_audits_r2927 d
  WHERE
       (d.cpcb_eligible AND NOT d.cpcb_form_filed)
    OR (d.data_wipe_required AND NOT d.data_wipe_completed)
    OR (d.radiation_flag AND d.disposal_status <> 'disposed')
    OR (d.biohazard_flag AND d.disposal_status = 'pending_pickup')
  ORDER BY severity ASC;
END;
$$;

-- ---- RPC 5: city_heatmap_r2927 -------------------------------------------
DROP FUNCTION IF EXISTS public.city_heatmap_r2927();
CREATE OR REPLACE FUNCTION public.city_heatmap_r2927()
RETURNS TABLE (
  id uuid,
  city text,
  units int,
  disposed int,
  pending int,
  quarantined int,
  total_book_lakhs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    gen_random_uuid() AS id,
    d.city,
    COUNT(*)::int AS units,
    SUM(CASE WHEN d.disposal_status='disposed' THEN 1 ELSE 0 END)::int AS disposed,
    SUM(CASE WHEN d.disposal_status='pending_pickup' THEN 1 ELSE 0 END)::int AS pending,
    SUM(CASE WHEN d.disposal_status='quarantined' THEN 1 ELSE 0 END)::int AS quarantined,
    ROUND(SUM(d.book_value_rupees)::numeric/100000.0, 2) AS total_book_lakhs
  FROM public.decommission_audits_r2927 d
  GROUP BY d.city
  ORDER BY units DESC;
END;
$$;

-- ---- RPC 6: vintage_distribution_r2927 -----------------------------------
DROP FUNCTION IF EXISTS public.vintage_distribution_r2927();
CREATE OR REPLACE FUNCTION public.vintage_distribution_r2927()
RETURNS TABLE (
  id uuid,
  vintage_band text,
  units int,
  avg_age_years numeric,
  total_book_lakhs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now int := EXTRACT(YEAR FROM CURRENT_DATE)::int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    gen_random_uuid() AS id,
    CASE
      WHEN (v_now - d.acquisition_year) <= 10 THEN '<= 10 yr'
      WHEN (v_now - d.acquisition_year) <= 14 THEN '11-14 yr'
      ELSE '15+ yr'
    END AS vintage_band,
    COUNT(*)::int AS units,
    ROUND(AVG(v_now - d.acquisition_year)::numeric, 1) AS avg_age_years,
    ROUND(SUM(d.book_value_rupees)::numeric/100000.0, 2) AS total_book_lakhs
  FROM public.decommission_audits_r2927 d
  GROUP BY 2
  ORDER BY 2;
END;
$$;

-- ---- RPC 7: disposal_method_mix_r2927 ------------------------------------
DROP FUNCTION IF EXISTS public.disposal_method_mix_r2927();
CREATE OR REPLACE FUNCTION public.disposal_method_mix_r2927()
RETURNS TABLE (
  id uuid,
  disposal_method text,
  units int,
  pct_of_total numeric,
  total_salvage_lakhs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*) INTO v_total FROM public.decommission_audits_r2927;
  RETURN QUERY
  SELECT
    gen_random_uuid() AS id,
    d.disposal_method,
    COUNT(*)::int AS units,
    ROUND(100.0 * COUNT(*)::numeric / NULLIF(v_total,0), 2) AS pct_of_total,
    ROUND(SUM(d.salvage_value_rupees)::numeric/100000.0, 2) AS total_salvage_lakhs
  FROM public.decommission_audits_r2927 d
  GROUP BY d.disposal_method
  ORDER BY units DESC;
END;
$$;

-- ---- RPC 8: q1_topline_r2927 ---------------------------------------------
DROP FUNCTION IF EXISTS public.q1_topline_r2927();
CREATE OR REPLACE FUNCTION public.q1_topline_r2927()
RETURNS TABLE (
  id uuid,
  metric text,
  value_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_units int;
  v_disposed int;
  v_book bigint;
  v_salvage bigint;
  v_vendors int;
  v_red int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COUNT(*), SUM(CASE WHEN disposal_status='disposed' THEN 1 ELSE 0 END),
         SUM(book_value_rupees), SUM(salvage_value_rupees)
    INTO v_units, v_disposed, v_book, v_salvage
  FROM public.decommission_audits_r2927;

  SELECT COUNT(*) INTO v_vendors FROM public.disposal_vendors_r2927 WHERE is_active = true;
  SELECT COUNT(*) INTO v_red FROM public.disposal_vendors_r2927 WHERE compliance_flag = 'red';

  RETURN QUERY
  SELECT gen_random_uuid(), 'Total units audited'::text, v_units::text
  UNION ALL SELECT gen_random_uuid(), 'Units disposed'::text, v_disposed::text
  UNION ALL SELECT gen_random_uuid(), 'Disposal completion %'::text,
    (ROUND(100.0 * v_disposed::numeric / NULLIF(v_units,0), 1))::text || ' %'
  UNION ALL SELECT gen_random_uuid(), 'Net book value at risk (Lakhs)'::text,
    ROUND(v_book::numeric/100000.0, 2)::text
  UNION ALL SELECT gen_random_uuid(), 'Salvage realised (Lakhs)'::text,
    ROUND(v_salvage::numeric/100000.0, 2)::text
  UNION ALL SELECT gen_random_uuid(), 'Recovery %'::text,
    (ROUND(100.0 * v_salvage::numeric / NULLIF(v_book,0), 2))::text || ' %'
  UNION ALL SELECT gen_random_uuid(), 'Active vendors'::text, v_vendors::text
  UNION ALL SELECT gen_random_uuid(), 'Red-flag vendors'::text, v_red::text;
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.chain_summary_r2927()             FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.category_breakdown_r2927()        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vendor_scorecard_r2927()          FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compliance_risk_queue_r2927()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.city_heatmap_r2927()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vintage_distribution_r2927()      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.disposal_method_mix_r2927()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.q1_topline_r2927()                FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.chain_summary_r2927()             TO authenticated;
GRANT EXECUTE ON FUNCTION public.category_breakdown_r2927()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_scorecard_r2927()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.compliance_risk_queue_r2927()     TO authenticated;
GRANT EXECUTE ON FUNCTION public.city_heatmap_r2927()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.vintage_distribution_r2927()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.disposal_method_mix_r2927()       TO authenticated;
GRANT EXECUTE ON FUNCTION public.q1_topline_r2927()                TO authenticated;

COMMIT;
