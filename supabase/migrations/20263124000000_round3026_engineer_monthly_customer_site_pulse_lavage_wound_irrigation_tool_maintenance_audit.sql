-- Round 3026: Engineer Monthly Customer Site Pulse-Lavage Wound-Irrigation Tool Maintenance Audit
-- Pulse-lavage devices used in OT wound debridement need monthly engineer-led site audits.
-- Tracks device fleet, audit visits, findings, remediation, calibration, and consumable burn.

-- ============================================================================
-- TABLE 1: pulse_lavage_tool_audit_findings_r3026
-- Per-device monthly audit finding rows (one row per device per audit visit)
-- ============================================================================
create table if not exists public.pulse_lavage_tool_audit_findings_r3026 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  city text not null,
  device_serial text not null,
  device_model text not null check (device_model in ('Stryker InterPulse','Zimmer Pulsavac Plus','Davol SimPulse Solo','BD GenesisII Lavage','MicroAire ProLav')),
  ot_room_code text not null,
  audit_month date not null,
  engineer_name text not null,
  visit_status text not null check (visit_status in ('completed','partial','no_access','rescheduled','cancelled')),
  pressure_psi_actual numeric(6,2),
  pressure_psi_spec_min numeric(6,2) not null,
  pressure_psi_spec_max numeric(6,2) not null,
  flow_lpm_actual numeric(6,2),
  battery_health_pct int check (battery_health_pct is null or (battery_health_pct between 0 and 100)),
  suction_seal_ok boolean,
  trigger_response_ms int check (trigger_response_ms is null or trigger_response_ms between 0 and 5000),
  splash_shield_intact boolean,
  consumable_tip_stock int check (consumable_tip_stock is null or consumable_tip_stock >= 0),
  saline_bag_stock int check (saline_bag_stock is null or saline_bag_stock >= 0),
  finding_severity text not null check (finding_severity in ('clean','observation','minor','major','critical')),
  finding_summary text not null,
  remediation_action text,
  remediation_due_by date,
  remediation_completed_at timestamptz,
  next_audit_due date not null,
  audit_duration_minutes int not null check (audit_duration_minutes between 0 and 600),
  customer_signoff boolean not null default false,
  signoff_contact_name text,
  signoff_designation text check (signoff_designation is null or signoff_designation in ('biomed_engineer','ot_manager','nursing_lead','procurement_head','hospital_admin'))
);

alter table public.pulse_lavage_tool_audit_findings_r3026 enable row level security;

drop policy if exists pl_audit_find_r3026_founder_select on public.pulse_lavage_tool_audit_findings_r3026;
create policy pl_audit_find_r3026_founder_select on public.pulse_lavage_tool_audit_findings_r3026
  for select to authenticated using (public.is_founder());

-- Seed (18 rows)
insert into public.pulse_lavage_tool_audit_findings_r3026 (
  hospital_name, city, device_serial, device_model, ot_room_code, audit_month, engineer_name,
  visit_status, pressure_psi_actual, pressure_psi_spec_min, pressure_psi_spec_max,
  flow_lpm_actual, battery_health_pct, suction_seal_ok, trigger_response_ms,
  splash_shield_intact, consumable_tip_stock, saline_bag_stock,
  finding_severity, finding_summary, remediation_action, remediation_due_by, remediation_completed_at,
  next_audit_due, audit_duration_minutes, customer_signoff, signoff_contact_name, signoff_designation
)
select 'Apollo Jubilee Hills','Hyderabad','SIP-2231','Stryker InterPulse','OT-3','2026-06-01'::date,'Ravi Kumar',
  'completed',62.4,55,70,1.8,92,true,140,true,24,18,'clean','All parameters in spec, splash shield clean',null,null,null,'2026-07-01'::date,45,true,'Dr. Suresh','biomed_engineer'
union all select 'Yashoda Secunderabad','Hyderabad','ZPP-1144','Zimmer Pulsavac Plus','OT-1','2026-06-01'::date,'Ravi Kumar',
  'completed',58.1,50,65,1.6,76,true,210,true,8,4,'minor','Saline stock below threshold (4 bags)','Reorder 20 bags via marketplace','2026-06-15'::date,'2026-06-12 11:00+05:30'::timestamptz,'2026-07-01'::date,55,true,'Mrs. Lata','procurement_head'
union all select 'KIMS Kondapur','Hyderabad','DVS-7788','Davol SimPulse Solo','OT-2','2026-06-01'::date,'Anita Reddy',
  'completed',71.0,55,70,2.1,68,false,380,true,12,10,'major','Pressure overshoot 71 psi (spec max 70), suction seal slipping','Replace pressure regulator + suction gasket','2026-06-20'::date,null,'2026-07-01'::date,90,true,'Mr. Naidu','ot_manager'
union all select 'Continental Gachibowli','Hyderabad','SIP-2294','Stryker InterPulse','OT-4','2026-06-02'::date,'Ravi Kumar',
  'completed',60.0,55,70,1.7,88,true,160,true,30,22,'clean','Within spec, customer happy',null,null,null,'2026-07-02'::date,40,true,'Dr. Iyer','biomed_engineer'
union all select 'Sunshine Paradise','Hyderabad','BDG-5512','BD GenesisII Lavage','OT-1','2026-06-02'::date,'Anita Reddy',
  'partial',null,60,75,null,null,null,null,true,6,2,'observation','OT in use, only external inspection done; battery indicator dim','Schedule full audit when OT free','2026-06-09'::date,null,'2026-06-15'::date,20,false,'Sister Mary','nursing_lead'
union all select 'Manipal Vijayawada','Vijayawada','MAP-3301','MicroAire ProLav','OT-2','2026-06-03'::date,'Kiran Bose',
  'completed',54.2,50,65,1.5,81,true,190,true,15,12,'clean','Clean audit; consumable burn tracking on plan',null,null,null,'2026-07-03'::date,50,true,'Dr. Rao','biomed_engineer'
union all select 'AIG Mindspace','Hyderabad','ZPP-1188','Zimmer Pulsavac Plus','OT-6','2026-06-03'::date,'Ravi Kumar',
  'completed',61.0,50,65,1.7,72,true,240,false,18,14,'minor','Splash shield cracked along hinge','Replace splash shield assembly','2026-06-18'::date,'2026-06-17 09:30+05:30'::timestamptz,'2026-07-03'::date,60,true,'Mr. Pawan','ot_manager'
union all select 'Care Banjara','Hyderabad','SIP-2350','Stryker InterPulse','OT-2','2026-06-04'::date,'Ravi Kumar',
  'completed',45.0,55,70,1.1,42,false,520,true,5,3,'critical','Pressure 45 psi (below spec 55), battery at 42%, suction seal failed','Quarantine device + courier replacement loaner unit + RMA root unit','2026-06-06'::date,'2026-06-06 14:00+05:30'::timestamptz,'2026-07-04'::date,150,true,'Dr. Vijay','ot_manager'
union all select 'Citizens Specialty','Hyderabad','DVS-7820','Davol SimPulse Solo','OT-3','2026-06-04'::date,'Anita Reddy',
  'completed',64.0,55,70,1.9,90,true,150,true,20,16,'clean','Excellent maintenance; trainee shadowed visit',null,null,null,'2026-07-04'::date,55,true,'Dr. Anjali','biomed_engineer'
union all select 'Asian Institute Gastro','Hyderabad','BDG-5544','BD GenesisII Lavage','OT-5','2026-06-05'::date,'Kiran Bose',
  'completed',69.0,60,75,2.0,55,true,260,true,10,8,'observation','Battery health declining (55%); schedule replacement within 60d','Add battery RFQ to chain bulk order','2026-08-05'::date,null,'2026-07-05'::date,50,true,'Mr. Krish','procurement_head'
union all select 'Aware Gleneagles','Hyderabad','MAP-3318','MicroAire ProLav','OT-3','2026-06-05'::date,'Anita Reddy',
  'rescheduled',null,50,65,null,null,null,null,null,null,null,'observation','Customer requested reschedule (annual maintenance overlap)','Rebook for 2026-06-19','2026-06-19'::date,null,'2026-06-19'::date,5,false,null,null
union all select 'Care Outpatient','Hyderabad','SIP-2401','Stryker InterPulse','OT-1','2026-06-06'::date,'Ravi Kumar',
  'completed',59.0,55,70,1.6,84,true,180,true,22,17,'clean','Standard audit, no findings',null,null,null,'2026-07-06'::date,45,true,'Dr. Padma','biomed_engineer'
union all select 'KIMS Gachibowli','Hyderabad','ZPP-1199','Zimmer Pulsavac Plus','OT-2','2026-06-06'::date,'Ravi Kumar',
  'completed',57.0,50,65,1.5,79,true,200,true,14,10,'minor','Trigger response 200ms (high end); recommend service','Service trigger assembly within 30d','2026-07-06'::date,null,'2026-07-06'::date,55,true,'Mr. Ramana','biomed_engineer'
union all select 'Yashoda Malakpet','Hyderabad','DVS-7855','Davol SimPulse Solo','OT-4','2026-06-08'::date,'Anita Reddy',
  'no_access','-99'::numeric,55,70,null,null,null,null,null,null,null,'observation','OT under fumigation 24h; security denied access','Reschedule for 2026-06-10','2026-06-10'::date,null,'2026-06-10'::date,10,false,null,null
union all select 'SLG Bachupally','Hyderabad','BDG-5571','BD GenesisII Lavage','OT-2','2026-06-09'::date,'Kiran Bose',
  'completed',66.0,60,75,1.9,86,true,170,true,25,20,'clean','Site exemplary; flagged as reference site',null,null,null,'2026-07-09'::date,40,true,'Dr. Sneha','ot_manager'
union all select 'Olive Hospitals','Hyderabad','MAP-3340','MicroAire ProLav','OT-1','2026-06-10'::date,'Ravi Kumar',
  'completed',52.0,50,65,1.4,63,true,230,true,9,5,'minor','Consumable tips below reorder threshold','Auto-trigger marketplace order','2026-06-13'::date,'2026-06-12 16:00+05:30'::timestamptz,'2026-07-10'::date,50,true,'Mrs. Devi','procurement_head'
union all select 'Star Hospitals','Hyderabad','SIP-2455','Stryker InterPulse','OT-2','2026-06-11'::date,'Anita Reddy',
  'cancelled',null,55,70,null,null,null,null,null,null,null,'observation','Hospital cancelled — billing dispute being resolved','Hold audit until AR escalation closed','2026-06-25'::date,null,'2026-07-11'::date,0,false,null,null
union all select 'Rainbow Children Banjara','Hyderabad','ZPP-1220','Zimmer Pulsavac Plus','OT-Ped-1','2026-06-12'::date,'Kiran Bose',
  'completed',55.0,50,65,1.5,77,true,210,true,17,13,'clean','Paediatric OT, low pressure profile validated',null,null,null,'2026-07-12'::date,50,true,'Dr. Shilpa','biomed_engineer';

-- ============================================================================
-- TABLE 2: pulse_lavage_tool_audit_calibrations_r3026
-- Calibration certs + cost-of-quality tracking per device
-- ============================================================================
create table if not exists public.pulse_lavage_tool_audit_calibrations_r3026 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  device_serial text not null,
  device_model text not null check (device_model in ('Stryker InterPulse','Zimmer Pulsavac Plus','Davol SimPulse Solo','BD GenesisII Lavage','MicroAire ProLav')),
  hospital_name text not null,
  city text not null,
  calibration_date date not null,
  calibration_engineer text not null,
  cert_number text not null,
  cert_lab text not null check (cert_lab in ('NABL-Hyd','NABL-Pune','NABL-Chennai','In-house','OEM-Direct')),
  pre_cal_pressure_psi numeric(6,2) not null,
  post_cal_pressure_psi numeric(6,2) not null,
  drift_pct numeric(6,2) not null,
  cal_outcome text not null check (cal_outcome in ('pass','pass_with_adjustment','marginal','fail','re_cal_required')),
  parts_replaced text,
  parts_cost_rupees int not null check (parts_cost_rupees >= 0),
  labor_cost_rupees int not null check (labor_cost_rupees >= 0),
  travel_cost_rupees int not null check (travel_cost_rupees >= 0),
  invoiced_to_customer_rupees int not null check (invoiced_to_customer_rupees >= 0),
  amc_covered boolean not null default false,
  next_cal_due date not null,
  warranty_status text not null check (warranty_status in ('in_warranty','out_of_warranty','amc_active','expired'))
);

alter table public.pulse_lavage_tool_audit_calibrations_r3026 enable row level security;

drop policy if exists pl_cal_r3026_founder_select on public.pulse_lavage_tool_audit_calibrations_r3026;
create policy pl_cal_r3026_founder_select on public.pulse_lavage_tool_audit_calibrations_r3026
  for select to authenticated using (public.is_founder());

-- Seed (16 rows)
insert into public.pulse_lavage_tool_audit_calibrations_r3026 (
  device_serial, device_model, hospital_name, city, calibration_date, calibration_engineer,
  cert_number, cert_lab, pre_cal_pressure_psi, post_cal_pressure_psi, drift_pct, cal_outcome,
  parts_replaced, parts_cost_rupees, labor_cost_rupees, travel_cost_rupees,
  invoiced_to_customer_rupees, amc_covered, next_cal_due, warranty_status
) values
  ('SIP-2231','Stryker InterPulse','Apollo Jubilee Hills','Hyderabad','2026-06-01'::date,'Ravi Kumar','CAL-2026-0601-01','NABL-Hyd',62.5,62.4,0.16,'pass',null,0,1500,400,0,true,'2026-12-01'::date,'amc_active'),
  ('ZPP-1144','Zimmer Pulsavac Plus','Yashoda Secunderabad','Hyderabad','2026-06-01'::date,'Ravi Kumar','CAL-2026-0601-02','NABL-Hyd',57.0,58.1,1.93,'pass_with_adjustment','Pressure regulator clean',0,1800,400,0,true,'2026-12-01'::date,'amc_active'),
  ('DVS-7788','Davol SimPulse Solo','KIMS Kondapur','Hyderabad','2026-06-01'::date,'Anita Reddy','CAL-2026-0601-03','OEM-Direct',73.0,68.0,6.85,'marginal','Pressure regulator + suction gasket',8400,3200,600,12200,false,'2026-09-01'::date,'out_of_warranty'),
  ('SIP-2294','Stryker InterPulse','Continental Gachibowli','Hyderabad','2026-06-02'::date,'Ravi Kumar','CAL-2026-0602-04','NABL-Hyd',60.2,60.0,0.33,'pass',null,0,1500,400,0,true,'2026-12-02'::date,'amc_active'),
  ('MAP-3301','MicroAire ProLav','Manipal Vijayawada','Vijayawada','2026-06-03'::date,'Kiran Bose','CAL-2026-0603-05','NABL-Pune',54.5,54.2,0.55,'pass',null,0,2000,1200,0,true,'2026-12-03'::date,'amc_active'),
  ('ZPP-1188','Zimmer Pulsavac Plus','AIG Mindspace','Hyderabad','2026-06-03'::date,'Ravi Kumar','CAL-2026-0603-06','NABL-Hyd',61.2,61.0,0.33,'pass','Splash shield assembly',2400,1500,400,0,true,'2026-12-03'::date,'amc_active'),
  ('SIP-2350','Stryker InterPulse','Care Banjara','Hyderabad','2026-06-06'::date,'Ravi Kumar','CAL-2026-0606-07','OEM-Direct',45.0,60.0,33.33,'fail','Full pump head + battery pack + suction seal',15600,4500,400,0,true,'2026-09-06'::date,'amc_active'),
  ('DVS-7820','Davol SimPulse Solo','Citizens Specialty','Hyderabad','2026-06-04'::date,'Anita Reddy','CAL-2026-0604-08','NABL-Hyd',64.2,64.0,0.31,'pass',null,0,1500,400,0,true,'2026-12-04'::date,'amc_active'),
  ('BDG-5544','BD GenesisII Lavage','Asian Institute Gastro','Hyderabad','2026-06-05'::date,'Kiran Bose','CAL-2026-0605-09','NABL-Hyd',69.0,69.0,0.00,'pass',null,0,1800,400,0,true,'2026-12-05'::date,'amc_active'),
  ('SIP-2401','Stryker InterPulse','Care Outpatient','Hyderabad','2026-06-06'::date,'Ravi Kumar','CAL-2026-0606-10','NABL-Hyd',59.1,59.0,0.17,'pass',null,0,1500,400,0,true,'2026-12-06'::date,'amc_active'),
  ('ZPP-1199','Zimmer Pulsavac Plus','KIMS Gachibowli','Hyderabad','2026-06-06'::date,'Ravi Kumar','CAL-2026-0606-11','NABL-Hyd',57.0,57.0,0.00,'pass_with_adjustment','Trigger spring',1200,1800,400,3400,false,'2026-12-06'::date,'out_of_warranty'),
  ('BDG-5571','BD GenesisII Lavage','SLG Bachupally','Hyderabad','2026-06-09'::date,'Kiran Bose','CAL-2026-0609-12','NABL-Hyd',66.2,66.0,0.30,'pass',null,0,1800,400,0,true,'2026-12-09'::date,'amc_active'),
  ('MAP-3340','MicroAire ProLav','Olive Hospitals','Hyderabad','2026-06-10'::date,'Ravi Kumar','CAL-2026-0610-13','NABL-Hyd',52.4,52.0,0.76,'pass',null,0,1500,400,0,true,'2026-12-10'::date,'amc_active'),
  ('ZPP-1220','Zimmer Pulsavac Plus','Rainbow Children Banjara','Hyderabad','2026-06-12'::date,'Kiran Bose','CAL-2026-0612-14','NABL-Hyd',55.2,55.0,0.36,'pass',null,0,1800,400,0,true,'2026-12-12'::date,'amc_active'),
  ('SIP-2455','Stryker InterPulse','Star Hospitals','Hyderabad','2026-05-11'::date,'Anita Reddy','CAL-2026-0511-15','In-house',58.0,58.0,0.00,'re_cal_required',null,0,800,400,0,false,'2026-06-25'::date,'expired'),
  ('DVS-7855','Davol SimPulse Solo','Yashoda Malakpet','Hyderabad','2026-05-25'::date,'Anita Reddy','CAL-2026-0525-16','NABL-Hyd',63.0,63.0,0.00,'pass',null,0,1500,400,0,true,'2026-11-25'::date,'amc_active');

-- ============================================================================
-- RPC 1: visit roll-up by month
-- ============================================================================
create or replace function public.pulse_lavage_r3026_visit_rollup()
returns table (
  audit_month date,
  visits_total int,
  completed_count int,
  partial_count int,
  no_access_count int,
  rescheduled_count int,
  cancelled_count int,
  signoff_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.audit_month,
    count(*)::int as visits_total,
    (count(*) filter (where f.visit_status='completed'))::int as completed_count,
    (count(*) filter (where f.visit_status='partial'))::int as partial_count,
    (count(*) filter (where f.visit_status='no_access'))::int as no_access_count,
    (count(*) filter (where f.visit_status='rescheduled'))::int as rescheduled_count,
    (count(*) filter (where f.visit_status='cancelled'))::int as cancelled_count,
    round(100.0 * (count(*) filter (where f.customer_signoff)) / nullif(count(*),0), 2) as signoff_rate_pct
  from public.pulse_lavage_tool_audit_findings_r3026 f
  group by f.audit_month
  order by f.audit_month desc;
end $$;

revoke all on function public.pulse_lavage_r3026_visit_rollup() from public, anon;
grant execute on function public.pulse_lavage_r3026_visit_rollup() to authenticated;

-- ============================================================================
-- RPC 2: severity heatmap per engineer
-- ============================================================================
create or replace function public.pulse_lavage_r3026_severity_by_engineer()
returns table (
  engineer_name text,
  visits int,
  clean_count int,
  minor_count int,
  major_count int,
  critical_count int,
  avg_duration_min numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.engineer_name,
    count(*)::int as visits,
    (count(*) filter (where f.finding_severity='clean'))::int,
    (count(*) filter (where f.finding_severity='minor'))::int,
    (count(*) filter (where f.finding_severity='major'))::int,
    (count(*) filter (where f.finding_severity='critical'))::int,
    round(avg(f.audit_duration_minutes)::numeric, 1) as avg_duration_min
  from public.pulse_lavage_tool_audit_findings_r3026 f
  group by f.engineer_name
  order by visits desc;
end $$;

revoke all on function public.pulse_lavage_r3026_severity_by_engineer() from public, anon;
grant execute on function public.pulse_lavage_r3026_severity_by_engineer() to authenticated;

-- ============================================================================
-- RPC 3: out-of-spec devices (pressure deviation)
-- ============================================================================
create or replace function public.pulse_lavage_r3026_out_of_spec_devices()
returns table (
  device_serial text,
  device_model text,
  hospital_name text,
  pressure_psi_actual numeric,
  pressure_psi_spec_min numeric,
  pressure_psi_spec_max numeric,
  deviation_pct numeric,
  finding_severity text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.device_serial,
    f.device_model,
    f.hospital_name,
    f.pressure_psi_actual,
    f.pressure_psi_spec_min,
    f.pressure_psi_spec_max,
    case
      when f.pressure_psi_actual is null then null
      when f.pressure_psi_actual < f.pressure_psi_spec_min then
        round(100.0 * (f.pressure_psi_spec_min - f.pressure_psi_actual) / f.pressure_psi_spec_min, 2)
      when f.pressure_psi_actual > f.pressure_psi_spec_max then
        round(100.0 * (f.pressure_psi_actual - f.pressure_psi_spec_max) / f.pressure_psi_spec_max, 2)
      else 0
    end as deviation_pct,
    f.finding_severity
  from public.pulse_lavage_tool_audit_findings_r3026 f
  where f.pressure_psi_actual is not null
    and (f.pressure_psi_actual < f.pressure_psi_spec_min
         or f.pressure_psi_actual > f.pressure_psi_spec_max)
  order by deviation_pct desc nulls last;
end $$;

revoke all on function public.pulse_lavage_r3026_out_of_spec_devices() from public, anon;
grant execute on function public.pulse_lavage_r3026_out_of_spec_devices() to authenticated;

-- ============================================================================
-- RPC 4: remediation SLA tracker
-- ============================================================================
create or replace function public.pulse_lavage_r3026_remediation_sla()
returns table (
  device_serial text,
  hospital_name text,
  finding_severity text,
  remediation_action text,
  remediation_due_by date,
  remediation_completed_at timestamptz,
  sla_state text,
  days_remaining int
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.device_serial,
    f.hospital_name,
    f.finding_severity,
    f.remediation_action,
    f.remediation_due_by,
    f.remediation_completed_at,
    case
      when f.remediation_action is null then 'no_action'
      when f.remediation_completed_at is not null and f.remediation_completed_at::date <= f.remediation_due_by then 'closed_on_time'
      when f.remediation_completed_at is not null then 'closed_late'
      when f.remediation_due_by < current_date then 'overdue'
      else 'open_in_window'
    end as sla_state,
    case
      when f.remediation_due_by is null then null
      else (f.remediation_due_by - current_date)
    end as days_remaining
  from public.pulse_lavage_tool_audit_findings_r3026 f
  where f.remediation_action is not null
  order by f.remediation_due_by asc nulls last;
end $$;

revoke all on function public.pulse_lavage_r3026_remediation_sla() from public, anon;
grant execute on function public.pulse_lavage_r3026_remediation_sla() to authenticated;

-- ============================================================================
-- RPC 5: consumable burn & reorder triggers
-- ============================================================================
create or replace function public.pulse_lavage_r3026_consumable_burn()
returns table (
  hospital_name text,
  device_serial text,
  consumable_tip_stock int,
  saline_bag_stock int,
  reorder_flag text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    f.hospital_name,
    f.device_serial,
    f.consumable_tip_stock,
    f.saline_bag_stock,
    case
      when f.consumable_tip_stock is null or f.saline_bag_stock is null then 'unknown'
      when f.consumable_tip_stock < 10 or f.saline_bag_stock < 6 then 'reorder_now'
      when f.consumable_tip_stock < 15 or f.saline_bag_stock < 10 then 'reorder_soon'
      else 'ok'
    end as reorder_flag
  from public.pulse_lavage_tool_audit_findings_r3026 f
  where f.visit_status in ('completed','partial')
  order by f.consumable_tip_stock nulls last;
end $$;

revoke all on function public.pulse_lavage_r3026_consumable_burn() from public, anon;
grant execute on function public.pulse_lavage_r3026_consumable_burn() to authenticated;

-- ============================================================================
-- RPC 6: calibration cost & cost-of-quality split
-- ============================================================================
create or replace function public.pulse_lavage_r3026_calibration_cost()
returns table (
  device_model text,
  cal_visits int,
  pass_count int,
  fail_count int,
  total_parts_rupees bigint,
  total_labor_rupees bigint,
  total_travel_rupees bigint,
  total_invoiced_rupees bigint,
  amc_absorbed_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.device_model,
    count(*)::int as cal_visits,
    (count(*) filter (where c.cal_outcome in ('pass','pass_with_adjustment')))::int as pass_count,
    (count(*) filter (where c.cal_outcome in ('fail','re_cal_required','marginal')))::int as fail_count,
    coalesce(sum(c.parts_cost_rupees),0)::bigint,
    coalesce(sum(c.labor_cost_rupees),0)::bigint,
    coalesce(sum(c.travel_cost_rupees),0)::bigint,
    coalesce(sum(c.invoiced_to_customer_rupees),0)::bigint,
    coalesce(sum(case when c.amc_covered then (c.parts_cost_rupees + c.labor_cost_rupees + c.travel_cost_rupees) else 0 end),0)::bigint as amc_absorbed_rupees
  from public.pulse_lavage_tool_audit_calibrations_r3026 c
  group by c.device_model
  order by cal_visits desc;
end $$;

revoke all on function public.pulse_lavage_r3026_calibration_cost() from public, anon;
grant execute on function public.pulse_lavage_r3026_calibration_cost() to authenticated;

-- ============================================================================
-- RPC 7: upcoming audit + calibration calendar (next 60 days)
-- ============================================================================
create or replace function public.pulse_lavage_r3026_upcoming_calendar()
returns table (
  due_date date,
  kind text,
  hospital_name text,
  device_serial text,
  device_model text,
  detail text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.next_audit_due as due_date,
         'audit'::text as kind,
         f.hospital_name,
         f.device_serial,
         f.device_model,
         ('Next monthly audit · last severity '||f.finding_severity)::text as detail
  from public.pulse_lavage_tool_audit_findings_r3026 f
  where f.next_audit_due between current_date and current_date + 60
  union all
  select c.next_cal_due as due_date,
         'calibration'::text as kind,
         c.hospital_name,
         c.device_serial,
         c.device_model,
         ('NABL recal · last outcome '||c.cal_outcome)::text as detail
  from public.pulse_lavage_tool_audit_calibrations_r3026 c
  where c.next_cal_due between current_date and current_date + 60
  order by due_date asc;
end $$;

revoke all on function public.pulse_lavage_r3026_upcoming_calendar() from public, anon;
grant execute on function public.pulse_lavage_r3026_upcoming_calendar() to authenticated;

-- ============================================================================
-- RPC 8: warranty & AMC coverage mix
-- ============================================================================
create or replace function public.pulse_lavage_r3026_warranty_mix()
returns table (
  warranty_status text,
  device_count int,
  total_invoiced_rupees bigint,
  avg_drift_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.warranty_status,
         count(distinct c.device_serial)::int as device_count,
         coalesce(sum(c.invoiced_to_customer_rupees),0)::bigint as total_invoiced_rupees,
         round(avg(c.drift_pct)::numeric, 2) as avg_drift_pct
  from public.pulse_lavage_tool_audit_calibrations_r3026 c
  group by c.warranty_status
  order by device_count desc;
end $$;

revoke all on function public.pulse_lavage_r3026_warranty_mix() from public, anon;
grant execute on function public.pulse_lavage_r3026_warranty_mix() to authenticated;