-- Round 3094: Hospital Pharmacy Cold-Chain Refrigerator Compressor Vibration Audit
-- Monthly engineer compressor vibration audit for pharmacy & blood-bank refrigerators.

set search_path = public, pg_temp;

-- =====================================================================
-- Table 1: compressor vibration audit records
-- =====================================================================
create table if not exists public.coldchain_compressor_audits_r3094 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  hospital_org_id uuid references public.organizations(id) on delete set null,
  hospital_name text not null,
  unit_location text not null check (unit_location in ('pharmacy_main','pharmacy_oncology','blood_bank','vaccine_room','plasma_store','iv_compounding','nicu_milk_bank')),
  refrigerator_make text not null check (refrigerator_make in ('Vestfrost','Haier_Biomedical','Blue_Star','Voltas','Godrej','Western','Remi')),
  refrigerator_model text not null,
  refrigerator_serial text not null,
  compressor_type text not null check (compressor_type in ('reciprocating','rotary','scroll','inverter_scroll','hermetic')),
  refrigerant text not null check (refrigerant in ('R134a','R600a','R290','R404A','R290_R600a_blend')),
  audit_month date not null,
  engineer_id uuid references public.engineers(id) on delete set null,
  engineer_name text not null,
  ambient_temp_c numeric(5,2) not null check (ambient_temp_c between -5 and 55),
  cabinet_temp_c numeric(5,2) not null check (cabinet_temp_c between -90 and 30),
  vibration_rms_mm_s numeric(6,3) not null check (vibration_rms_mm_s between 0 and 80),
  vibration_peak_mm_s numeric(6,3) not null check (vibration_peak_mm_s between 0 and 200),
  band_1x_amplitude numeric(6,3) not null check (band_1x_amplitude between 0 and 60),
  band_2x_amplitude numeric(6,3) not null check (band_2x_amplitude between 0 and 60),
  band_high_freq_amplitude numeric(6,3) not null check (band_high_freq_amplitude between 0 and 60),
  bearing_wear_flag boolean not null default false,
  oil_seepage_observed boolean not null default false,
  failure_risk_score int not null check (failure_risk_score between 0 and 100),
  iso_10816_zone text not null check (iso_10816_zone in ('A_good','B_acceptable','C_unsatisfactory','D_unacceptable')),
  audit_status text not null check (audit_status in ('passed','watch','corrective_needed','urgent_replacement','rescheduled')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_compaudit_r3094_hosp on public.coldchain_compressor_audits_r3094(hospital_org_id, audit_month);
create index if not exists idx_compaudit_r3094_status on public.coldchain_compressor_audits_r3094(audit_status);
create index if not exists idx_compaudit_r3094_risk on public.coldchain_compressor_audits_r3094(failure_risk_score desc);

-- =====================================================================
-- Table 2: corrective action queue tied to audits
-- =====================================================================
create table if not exists public.coldchain_compressor_corrective_queue_r3094 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.coldchain_compressor_audits_r3094(id) on delete cascade,
  ticket_code text not null unique,
  action_type text not null check (action_type in ('compressor_replacement','bearing_replacement','refrigerant_topup','vibration_dampener','mounting_retorque','filter_drier_swap','full_unit_swap','oil_change','condenser_clean')),
  priority text not null check (priority in ('p0_critical','p1_high','p2_medium','p3_low')),
  estimated_cost_rupees int not null check (estimated_cost_rupees between 500 and 1500000),
  spare_part_required text,
  spare_supplier_org_id uuid references public.organizations(id) on delete set null,
  assigned_engineer_id uuid references public.engineers(id) on delete set null,
  scheduled_date date,
  sla_due_date date not null,
  resolution_status text not null check (resolution_status in ('open','scheduled','parts_awaited','in_progress','completed','escalated','cancelled')),
  hospital_acknowledged boolean not null default false,
  downtime_risk_hours int not null default 0 check (downtime_risk_hours between 0 and 720),
  created_at timestamptz not null default now()
);

create index if not exists idx_corrq_r3094_audit on public.coldchain_compressor_corrective_queue_r3094(audit_id);
create index if not exists idx_corrq_r3094_priority on public.coldchain_compressor_corrective_queue_r3094(priority, resolution_status);

-- =====================================================================
-- Seed data
-- =====================================================================
insert into public.coldchain_compressor_audits_r3094
(audit_code, hospital_name, unit_location, refrigerator_make, refrigerator_model, refrigerator_serial, compressor_type, refrigerant, audit_month, engineer_name, ambient_temp_c, cabinet_temp_c, vibration_rms_mm_s, vibration_peak_mm_s, band_1x_amplitude, band_2x_amplitude, band_high_freq_amplitude, bearing_wear_flag, oil_seepage_observed, failure_risk_score, iso_10816_zone, audit_status, notes)
values
('CCA-3094-001','Apollo Hospitals Hyderabad','pharmacy_main','Vestfrost','MK304','VF-MK304-9912','hermetic','R134a','2026-05-01','Ramesh Kumar',32.40,4.20,2.150,4.800,1.200,0.450,0.380,false,false,12,'A_good','passed','Within ISO band A, stable spectrum.'),
('CCA-3094-002','Fortis Bangalore','blood_bank','Haier_Biomedical','HBC-260S','HB-260S-44021','inverter_scroll','R290','2026-05-01','Sneha Reddy',29.80,-30.50,3.420,7.100,1.800,0.620,0.540,false,false,22,'B_acceptable','watch','Mild 1x rise, watch next month.'),
('CCA-3094-003','AIIMS Delhi','vaccine_room','Vestfrost','VLS-100','VLS-100-77810','reciprocating','R600a','2026-05-02','Anil Verma',28.10,3.80,5.910,12.400,3.200,1.250,0.910,false,false,38,'C_unsatisfactory','corrective_needed','Mounting retorque + dampener required.'),
('CCA-3094-004','Manipal Hospital Vijayawada','plasma_store','Blue_Star','BS-PLS-120','BSP-120-30021','rotary','R404A','2026-05-03','Karthik Iyer',34.20,-25.60,8.450,18.200,5.100,2.300,1.870,true,true,71,'D_unacceptable','urgent_replacement','Bearing wear confirmed, oil seepage at brazing.'),
('CCA-3094-005','KIMS Secunderabad','pharmacy_oncology','Godrej','GR-PMC-90','GR-PMC-90-55512','scroll','R134a','2026-05-03','Sneha Reddy',31.50,2.10,4.020,8.900,2.400,0.880,0.760,false,false,29,'B_acceptable','watch','Slight 2x rise, schedule cleaning.'),
('CCA-3094-006','Yashoda Hyderabad','iv_compounding','Voltas','VL-IVC-180','VLT-IVC-180-2241','reciprocating','R134a','2026-05-04','Ramesh Kumar',30.20,5.40,6.780,14.100,4.200,1.610,1.220,true,false,58,'C_unsatisfactory','corrective_needed','Bearing wear flag tripped on high-freq band.'),
('CCA-3094-007','CARE Hospital Banjara Hills','nicu_milk_bank','Western','WST-NMB-60','WST-NMB-60-90122','hermetic','R600a','2026-05-04','Pooja Sharma',27.80,3.90,1.850,3.900,0.920,0.380,0.290,false,false,8,'A_good','passed','Excellent condition, new unit.'),
('CCA-3094-008','Rainbow Childrens Hospital','vaccine_room','Haier_Biomedical','HBC-310','HB-310-66201','inverter_scroll','R290','2026-05-05','Anil Verma',29.50,4.10,2.940,6.200,1.520,0.560,0.480,false,false,18,'B_acceptable','passed','Minor scroll harmonic, acceptable.'),
('CCA-3094-009','Continental Hospital Gachibowli','blood_bank','Remi','REM-BB-300','REM-BB-300-11099','reciprocating','R404A','2026-05-05','Karthik Iyer',33.10,-28.40,7.620,16.800,4.800,2.110,1.640,true,true,67,'D_unacceptable','urgent_replacement','Critical vibration on blood-bank unit.'),
('CCA-3094-010','Sunshine Hospital Secunderabad','pharmacy_main','Blue_Star','BS-PMR-150','BSP-150-44120','rotary','R134a','2026-05-06','Pooja Sharma',31.20,3.20,3.180,6.700,1.760,0.720,0.610,false,false,24,'B_acceptable','watch','Stable but trending up vs March.');

-- Capture audit IDs for corrective queue
do $$
declare
  a4 uuid; a3 uuid; a6 uuid; a9 uuid; a5 uuid; a10 uuid;
begin
  select id into a4 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-004';
  select id into a3 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-003';
  select id into a6 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-006';
  select id into a9 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-009';
  select id into a5 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-005';
  select id into a10 from public.coldchain_compressor_audits_r3094 where audit_code='CCA-3094-010';

  insert into public.coldchain_compressor_corrective_queue_r3094
  (audit_id, ticket_code, action_type, priority, estimated_cost_rupees, spare_part_required, scheduled_date, sla_due_date, resolution_status, hospital_acknowledged, downtime_risk_hours)
  values
  (a4, 'CCQ-3094-001','compressor_replacement','p0_critical', 185000,'Tecumseh AE2425Z compressor','2026-05-09','2026-05-10','scheduled', true, 24),
  (a4, 'CCQ-3094-002','bearing_replacement','p0_critical', 22000,'NSK 6203Z bearing set','2026-05-09','2026-05-10','parts_awaited', true, 18),
  (a3, 'CCQ-3094-003','vibration_dampener','p1_high', 4500,'EPDM dampener pad x4','2026-05-12','2026-05-15','open', false, 4),
  (a3, 'CCQ-3094-004','mounting_retorque','p2_medium', 800, null, '2026-05-12','2026-05-15','open', false, 2),
  (a6, 'CCQ-3094-005','bearing_replacement','p1_high', 18500,'SKF 6202-2RS','2026-05-11','2026-05-14','in_progress', true, 12),
  (a9, 'CCQ-3094-006','full_unit_swap','p0_critical', 420000,'Remi REM-BB-300 replacement unit','2026-05-08','2026-05-09','escalated', true, 48),
  (a5, 'CCQ-3094-007','condenser_clean','p2_medium', 2500, null, '2026-05-15','2026-05-20','completed', true, 1),
  (a10,'CCQ-3094-008','oil_change','p3_low', 1800,'Suniso 3GS oil 1L','2026-05-18','2026-05-25','open', false, 1);
end $$;

-- =====================================================================
-- RPC 1: status summary
-- =====================================================================
create or replace function public.rpc_r3094_status_summary()
returns table (audit_status text, audits int, avg_risk numeric, avg_vibration numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_status,
         count(*)::int,
         round(avg(a.failure_risk_score)::numeric, 2),
         round(avg(a.vibration_rms_mm_s)::numeric, 3)
  from public.coldchain_compressor_audits_r3094 a
  group by a.audit_status
  order by avg(a.failure_risk_score) desc nulls last;
end $$;

revoke execute on function public.rpc_r3094_status_summary() from public, anon;
grant execute on function public.rpc_r3094_status_summary() to authenticated;

-- =====================================================================
-- RPC 2: monthly trend
-- =====================================================================
create or replace function public.rpc_r3094_monthly_trend()
returns table (audit_month date, audits int, urgent_count int, avg_risk numeric, avg_vibration numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(*)::int,
         count(*) filter (where a.audit_status = 'urgent_replacement')::int,
         round(avg(a.failure_risk_score)::numeric, 2),
         round(avg(a.vibration_rms_mm_s)::numeric, 3)
  from public.coldchain_compressor_audits_r3094 a
  group by a.audit_month
  order by a.audit_month desc;
end $$;

revoke execute on function public.rpc_r3094_monthly_trend() from public, anon;
grant execute on function public.rpc_r3094_monthly_trend() to authenticated;

-- =====================================================================
-- RPC 3: vendor breakdown
-- =====================================================================
create or replace function public.rpc_r3094_vendor_breakdown()
returns table (refrigerator_make text, units int, avg_risk numeric, urgent_units int, bearing_wear_units int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.refrigerator_make,
         count(*)::int,
         round(avg(a.failure_risk_score)::numeric, 2),
         count(*) filter (where a.audit_status = 'urgent_replacement')::int,
         count(*) filter (where a.bearing_wear_flag)::int
  from public.coldchain_compressor_audits_r3094 a
  group by a.refrigerator_make
  order by avg(a.failure_risk_score) desc;
end $$;

revoke execute on function public.rpc_r3094_vendor_breakdown() from public, anon;
grant execute on function public.rpc_r3094_vendor_breakdown() to authenticated;

-- =====================================================================
-- RPC 4: hotlist (top risk audits)
-- =====================================================================
create or replace function public.rpc_r3094_risk_hotlist()
returns table (audit_code text, hospital_name text, unit_location text, refrigerator_make text, vibration_rms_mm_s numeric, failure_risk_score int, iso_10816_zone text, audit_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_code, a.hospital_name, a.unit_location, a.refrigerator_make,
         a.vibration_rms_mm_s, a.failure_risk_score, a.iso_10816_zone, a.audit_status
  from public.coldchain_compressor_audits_r3094 a
  where a.failure_risk_score >= 30
  order by a.failure_risk_score desc
  limit 25;
end $$;

revoke execute on function public.rpc_r3094_risk_hotlist() from public, anon;
grant execute on function public.rpc_r3094_risk_hotlist() to authenticated;

-- =====================================================================
-- RPC 5: corrective queue overview
-- =====================================================================
create or replace function public.rpc_r3094_corrective_queue()
returns table (ticket_code text, action_type text, priority text, estimated_cost_rupees int, resolution_status text, sla_due_date date, downtime_risk_hours int, hospital_acknowledged boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select q.ticket_code, q.action_type, q.priority, q.estimated_cost_rupees,
         q.resolution_status, q.sla_due_date, q.downtime_risk_hours, q.hospital_acknowledged
  from public.coldchain_compressor_corrective_queue_r3094 q
  order by case q.priority
    when 'p0_critical' then 1
    when 'p1_high' then 2
    when 'p2_medium' then 3
    when 'p3_low' then 4
    else 5 end,
    q.sla_due_date asc;
end $$;

revoke execute on function public.rpc_r3094_corrective_queue() from public, anon;
grant execute on function public.rpc_r3094_corrective_queue() to authenticated;

-- =====================================================================
-- RPC 6: engineer scorecard
-- =====================================================================
create or replace function public.rpc_r3094_engineer_scorecard()
returns table (engineer_name text, audits int, avg_risk numeric, urgent_finds int, watch_finds int, passed_finds int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int,
         round(avg(a.failure_risk_score)::numeric, 2),
         count(*) filter (where a.audit_status = 'urgent_replacement')::int,
         count(*) filter (where a.audit_status = 'watch')::int,
         count(*) filter (where a.audit_status = 'passed')::int
  from public.coldchain_compressor_audits_r3094 a
  group by a.engineer_name
  order by count(*) desc;
end $$;

revoke execute on function public.rpc_r3094_engineer_scorecard() from public, anon;
grant execute on function public.rpc_r3094_engineer_scorecard() to authenticated;

-- =====================================================================
-- RPC 7: location heatmap
-- =====================================================================
create or replace function public.rpc_r3094_location_heatmap()
returns table (unit_location text, audits int, avg_vibration numeric, avg_risk numeric, urgent_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.unit_location,
         count(*)::int,
         round(avg(a.vibration_rms_mm_s)::numeric, 3),
         round(avg(a.failure_risk_score)::numeric, 2),
         count(*) filter (where a.audit_status = 'urgent_replacement')::int
  from public.coldchain_compressor_audits_r3094 a
  group by a.unit_location
  order by avg(a.failure_risk_score) desc;
end $$;

revoke execute on function public.rpc_r3094_location_heatmap() from public, anon;
grant execute on function public.rpc_r3094_location_heatmap() to authenticated;

-- =====================================================================
-- RPC 8: ISO 10816 zone distribution
-- =====================================================================
create or replace function public.rpc_r3094_iso_zone_distribution()
returns table (iso_10816_zone text, audits int, avg_vibration numeric, bearing_wear_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.iso_10816_zone,
         count(*)::int,
         round(avg(a.vibration_rms_mm_s)::numeric, 3),
         count(*) filter (where a.bearing_wear_flag)::int
  from public.coldchain_compressor_audits_r3094 a
  group by a.iso_10816_zone
  order by a.iso_10816_zone;
end $$;

revoke execute on function public.rpc_r3094_iso_zone_distribution() from public, anon;
grant execute on function public.rpc_r3094_iso_zone_distribution() to authenticated;

-- =====================================================================
-- RPC 9: cost exposure
-- =====================================================================
create or replace function public.rpc_r3094_cost_exposure()
returns table (priority text, tickets int, total_cost_rupees bigint, total_downtime_hours bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select q.priority,
         count(*)::int,
         sum(q.estimated_cost_rupees)::bigint,
         sum(q.downtime_risk_hours)::bigint
  from public.coldchain_compressor_corrective_queue_r3094 q
  group by q.priority
  order by case q.priority
    when 'p0_critical' then 1
    when 'p1_high' then 2
    when 'p2_medium' then 3
    when 'p3_low' then 4
    else 5 end;
end $$;

revoke execute on function public.rpc_r3094_cost_exposure() from public, anon;
grant execute on function public.rpc_r3094_cost_exposure() to authenticated;
