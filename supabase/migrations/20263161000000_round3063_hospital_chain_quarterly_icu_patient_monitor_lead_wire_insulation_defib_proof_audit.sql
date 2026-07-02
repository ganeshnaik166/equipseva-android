-- Round 3063: Hospital Chain Quarterly ICU Patient Monitor Lead-Wire Insulation & Defib-Proof Audit
-- Batch 440 milestone, HEAVY ★★★★

create table if not exists icu_monitor_leadwire_audits_r3063 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_chain text not null,
  hospital_unit text not null,
  city text not null,
  icu_bed_count int not null check (icu_bed_count between 0 and 500),
  monitor_model text not null,
  monitor_serial text not null,
  audit_quarter text not null check (audit_quarter in ('Q1','Q2','Q3','Q4')),
  audit_year int not null check (audit_year between 2024 and 2030),
  audit_date date not null,
  insulation_resistance_megohm numeric(8,2) not null check (insulation_resistance_megohm between 0 and 9999),
  leakage_current_microamp numeric(8,2) not null check (leakage_current_microamp between 0 and 999),
  defib_proof_status text not null check (defib_proof_status in ('compliant','non_compliant','marginal','not_tested')),
  leadwire_condition text not null check (leadwire_condition in ('new','good','worn','damaged','recall')),
  iec_60601_2_27_pass boolean not null,
  ce_marking_intact boolean not null,
  follow_up_required boolean not null,
  remediation_due_date date,
  auditor_engineer_id uuid,
  remediation_cost_rupees int check (remediation_cost_rupees between 0 and 5000000)
);

alter table icu_monitor_leadwire_audits_r3063 enable row level security;

drop policy if exists icu_monitor_leadwire_audits_r3063_founder_all on icu_monitor_leadwire_audits_r3063;
create policy icu_monitor_leadwire_audits_r3063_founder_all on icu_monitor_leadwire_audits_r3063
  for all to authenticated using (is_founder()) with check (is_founder());

create table if not exists icu_monitor_leadwire_remediation_r3063 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references icu_monitor_leadwire_audits_r3063(id) on delete cascade,
  hospital_chain text not null,
  remediation_type text not null check (remediation_type in ('leadwire_replace','insulation_repair','defib_module_swap','full_recall','reterminate','retrain_staff')),
  status text not null check (status in ('open','in_progress','parts_ordered','completed','escalated','cancelled')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  raised_at timestamptz not null default now(),
  closed_at timestamptz,
  parts_cost_rupees int not null check (parts_cost_rupees between 0 and 2000000),
  labour_cost_rupees int not null check (labour_cost_rupees between 0 and 500000),
  downtime_hours numeric(6,2) not null check (downtime_hours between 0 and 999),
  vendor_name text,
  notes text
);

alter table icu_monitor_leadwire_remediation_r3063 enable row level security;

drop policy if exists icu_monitor_leadwire_remediation_r3063_founder_all on icu_monitor_leadwire_remediation_r3063;
create policy icu_monitor_leadwire_remediation_r3063_founder_all on icu_monitor_leadwire_remediation_r3063
  for all to authenticated using (is_founder()) with check (is_founder());

-- Seeds: audits
insert into icu_monitor_leadwire_audits_r3063 (hospital_chain, hospital_unit, city, icu_bed_count, monitor_model, monitor_serial, audit_quarter, audit_year, audit_date, insulation_resistance_megohm, leakage_current_microamp, defib_proof_status, leadwire_condition, iec_60601_2_27_pass, ce_marking_intact, follow_up_required, remediation_due_date, remediation_cost_rupees) values
('Apollo','Jubilee Hills','Hyderabad',42,'Philips IntelliVue MX450','PIM-2401-A','Q1',2026,'2026-01-14'::date,120.50,8.20,'compliant','good',true,true,false,null::date,0),
('Apollo','Bannerghatta','Bengaluru',38,'GE B125','GEB-77821','Q1',2026,'2026-01-19'::date,42.10,32.50,'marginal','worn',false,true,true,'2026-03-01'::date,185000),
('Manipal','Whitefield','Bengaluru',56,'Mindray uMEC15','MMU-5512','Q1',2026,'2026-02-02'::date,98.30,12.40,'compliant','good',true,true,false,null::date,0),
('Manipal','Hal Airport','Bengaluru',28,'Drager Infinity M540','DIM-3301','Q1',2026,'2026-02-08'::date,15.60,68.90,'non_compliant','damaged',false,false,true,'2026-02-25'::date,420000),
('Fortis','Mulund','Mumbai',64,'Philips IntelliVue MX550','PIM-9914','Q1',2026,'2026-02-15'::date,135.20,6.80,'compliant','new',true,true,false,null::date,0),
('Fortis','Anandapur','Kolkata',46,'GE Carescape B650','GEC-4421','Q1',2026,'2026-02-21'::date,52.40,28.10,'marginal','worn',true,true,true,'2026-03-15'::date,95000),
('Max','Saket','Delhi',72,'Philips IntelliVue MX750','PIM-7755','Q1',2026,'2026-03-01'::date,142.80,5.20,'compliant','new',true,true,false,null::date,0),
('Max','Patparganj','Delhi',38,'Mindray BeneVision N15','MBN-8821','Q1',2026,'2026-03-06'::date,8.40,95.60,'non_compliant','recall',false,false,true,'2026-03-12'::date,680000),
('Narayana','Bommasandra','Bengaluru',48,'Schiller Argus Pro','SAP-2211','Q1',2026,'2026-03-12'::date,72.50,18.30,'compliant','good',true,true,false,null::date,0),
('Narayana','Howrah','Kolkata',32,'GE B125','GEB-7733','Q1',2026,'2026-03-18'::date,38.20,42.10,'marginal','worn',false,true,true,'2026-04-05'::date,140000),
('AIIMS','Jodhpur','Jodhpur',54,'Philips IntelliVue MX450','PIM-2299','Q4',2025,'2025-12-08'::date,118.40,9.80,'compliant','good',true,true,false,null::date,0),
('AIIMS','Bhopal','Bhopal',46,'GE Carescape B450','GEC-1182','Q4',2025,'2025-12-14'::date,11.20,78.40,'non_compliant','damaged',false,false,true,'2025-12-28'::date,520000),
('KIMS','Secunderabad','Hyderabad',58,'Mindray uMEC15','MMU-6612','Q4',2025,'2025-12-20'::date,88.60,14.20,'compliant','good',true,true,false,null::date,0),
('Yashoda','Somajiguda','Hyderabad',44,'Philips IntelliVue MX550','PIM-8821','Q4',2025,'2025-11-25'::date,46.80,30.20,'marginal','worn',true,true,true,'2026-01-15'::date,108000),
('Continental','Gachibowli','Hyderabad',36,'Drager Infinity Acute','DIA-4412','Q1',2026,'2026-03-22'::date,128.50,7.10,'compliant','new',true,true,false,null::date,0),
('Rainbow','Banjara Hills','Hyderabad',24,'Mindray uMEC12','MMU-3318','Q1',2026,'2026-02-26'::date,0.00,142.30,'not_tested','damaged',false,false,true,'2026-03-08'::date,310000),
('Aster','Whitefield','Bengaluru',52,'Philips IntelliVue MX450','PIM-5544','Q1',2026,'2026-03-04'::date,106.40,11.50,'compliant','good',true,true,false,null::date,0),
('Aster','Kochi','Kochi',62,'GE Carescape B650','GEC-9921','Q1',2026,'2026-03-09'::date,58.90,22.40,'marginal','worn',true,true,true,'2026-04-10'::date,72000);

-- Seeds: remediation
insert into icu_monitor_leadwire_remediation_r3063 (hospital_chain, remediation_type, status, priority, raised_at, closed_at, parts_cost_rupees, labour_cost_rupees, downtime_hours, vendor_name, notes) values
('Apollo','leadwire_replace','completed','p2','2026-01-22 09:00+05:30'::timestamptz,'2026-01-25 17:00+05:30'::timestamptz,140000,32000,6.50,'Philips India','12 lead sets swapped'),
('Manipal','full_recall','escalated','p0','2026-02-10 14:00+05:30'::timestamptz,null::timestamptz,380000,40000,48.00,'Drager India','Defib-proof failure on 4 units'),
('Fortis','insulation_repair','completed','p2','2026-02-23 10:30+05:30'::timestamptz,'2026-02-27 16:00+05:30'::timestamptz,72000,18000,3.50,'GE Healthcare','Reterminate connectors'),
('Max','defib_module_swap','in_progress','p0','2026-03-08 08:00+05:30'::timestamptz,null::timestamptz,620000,55000,72.00,'Mindray India','Recall lot MBN-2401'),
('Narayana','reterminate','parts_ordered','p2','2026-03-20 11:00+05:30'::timestamptz,null::timestamptz,110000,28000,4.00,'GE Healthcare','Awaiting connector kits'),
('AIIMS','full_recall','completed','p1','2025-12-16 09:30+05:30'::timestamptz,'2025-12-30 18:00+05:30'::timestamptz,470000,48000,52.00,'GE Healthcare','8 monitors recalled'),
('Yashoda','leadwire_replace','completed','p2','2025-11-28 13:00+05:30'::timestamptz,'2026-01-12 17:00+05:30'::timestamptz,85000,22000,5.00,'Philips India','Worn ECG snap leads'),
('Rainbow','defib_module_swap','in_progress','p1','2026-03-01 16:00+05:30'::timestamptz,null::timestamptz,265000,42000,28.00,'Mindray India','Untested defib path'),
('Aster','reterminate','completed','p3','2026-03-12 10:00+05:30'::timestamptz,'2026-03-15 15:00+05:30'::timestamptz,58000,14000,2.50,'GE Healthcare','Routine retermination'),
('Continental','retrain_staff','open','p3','2026-03-23 09:00+05:30'::timestamptz,null::timestamptz,0,12000,0.00,'In-house','Quarterly refresher'),
('Apollo','insulation_repair','completed','p2','2026-01-30 09:00+05:30'::timestamptz,'2026-02-02 17:00+05:30'::timestamptz,46000,11000,2.00,'Philips India','Cable jacket re-sleeve'),
('Manipal','retrain_staff','completed','p3','2026-02-18 10:00+05:30'::timestamptz,'2026-02-19 16:00+05:30'::timestamptz,0,9000,0.00,'In-house','Biomed team brief'),
('Fortis','leadwire_replace','open','p2','2026-03-02 14:00+05:30'::timestamptz,null::timestamptz,92000,21000,4.50,'GE Healthcare','Pending PO'),
('Max','full_recall','cancelled','p1','2026-03-05 09:00+05:30'::timestamptz,'2026-03-07 12:00+05:30'::timestamptz,0,0,0.00,'Mindray India','Duplicate of MBN recall');

-- RPC 1: chain rollup
create or replace function fn_r3063_chain_rollup()
returns table (hospital_chain text, audits int, compliant int, non_compliant int, marginal int, units int, total_remediation_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select a.hospital_chain,
    count(*)::int as audits,
    (count(*) filter (where a.defib_proof_status = 'compliant'))::int,
    (count(*) filter (where a.defib_proof_status = 'non_compliant'))::int,
    (count(*) filter (where a.defib_proof_status = 'marginal'))::int,
    count(distinct a.hospital_unit)::int as units,
    coalesce(sum(a.remediation_cost_rupees),0)::bigint
  from icu_monitor_leadwire_audits_r3063 a
  group by a.hospital_chain
  order by audits desc;
end; $$;

revoke all on function fn_r3063_chain_rollup() from public, anon;
grant execute on function fn_r3063_chain_rollup() to authenticated;

-- RPC 2: defib-proof failures
create or replace function fn_r3063_defib_failures()
returns table (hospital_chain text, hospital_unit text, monitor_model text, monitor_serial text, leakage_current_microamp numeric, defib_proof_status text, audit_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select a.hospital_chain, a.hospital_unit, a.monitor_model, a.monitor_serial, a.leakage_current_microamp, a.defib_proof_status, a.audit_date
  from icu_monitor_leadwire_audits_r3063 a
  where a.defib_proof_status in ('non_compliant','marginal','not_tested')
  order by a.leakage_current_microamp desc;
end; $$;

revoke all on function fn_r3063_defib_failures() from public, anon;
grant execute on function fn_r3063_defib_failures() to authenticated;

-- RPC 3: leadwire condition mix
create or replace function fn_r3063_leadwire_mix()
returns table (leadwire_condition text, audits int, pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'founder only'; end if;
  select count(*)::int into total from icu_monitor_leadwire_audits_r3063;
  return query
  select a.leadwire_condition, count(*)::int,
    round((count(*)::numeric / nullif(total,0)) * 100, 2)
  from icu_monitor_leadwire_audits_r3063 a
  group by a.leadwire_condition
  order by 2 desc;
end; $$;

revoke all on function fn_r3063_leadwire_mix() from public, anon;
grant execute on function fn_r3063_leadwire_mix() to authenticated;

-- RPC 4: remediation pipeline
create or replace function fn_r3063_remediation_pipeline()
returns table (status text, priority text, jobs int, parts_rupees bigint, labour_rupees bigint, downtime_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select r.status, r.priority, count(*)::int,
    coalesce(sum(r.parts_cost_rupees),0)::bigint,
    coalesce(sum(r.labour_cost_rupees),0)::bigint,
    coalesce(sum(r.downtime_hours),0)::numeric
  from icu_monitor_leadwire_remediation_r3063 r
  group by r.status, r.priority
  order by r.priority, r.status;
end; $$;

revoke all on function fn_r3063_remediation_pipeline() from public, anon;
grant execute on function fn_r3063_remediation_pipeline() to authenticated;

-- RPC 5: high leakage outliers
create or replace function fn_r3063_high_leakage()
returns table (hospital_chain text, hospital_unit text, monitor_model text, leakage_current_microamp numeric, insulation_resistance_megohm numeric, iec_60601_2_27_pass boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select a.hospital_chain, a.hospital_unit, a.monitor_model, a.leakage_current_microamp, a.insulation_resistance_megohm, a.iec_60601_2_27_pass
  from icu_monitor_leadwire_audits_r3063 a
  where a.leakage_current_microamp > 20
  order by a.leakage_current_microamp desc
  limit 25;
end; $$;

revoke all on function fn_r3063_high_leakage() from public, anon;
grant execute on function fn_r3063_high_leakage() to authenticated;

-- RPC 6: quarter comparison
create or replace function fn_r3063_quarter_compare()
returns table (audit_quarter text, audit_year int, audits int, avg_leakage numeric, avg_insulation numeric, fail_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select a.audit_quarter, a.audit_year, count(*)::int,
    round(avg(a.leakage_current_microamp), 2),
    round(avg(a.insulation_resistance_megohm), 2),
    round((count(*) filter (where a.defib_proof_status in ('non_compliant','marginal')))::numeric / nullif(count(*),0) * 100, 2)
  from icu_monitor_leadwire_audits_r3063 a
  group by a.audit_quarter, a.audit_year
  order by a.audit_year desc, a.audit_quarter;
end; $$;

revoke all on function fn_r3063_quarter_compare() from public, anon;
grant execute on function fn_r3063_quarter_compare() to authenticated;

-- RPC 7: cost burndown by vendor
create or replace function fn_r3063_vendor_cost()
returns table (vendor_name text, jobs int, parts_rupees bigint, labour_rupees bigint, avg_downtime numeric, closed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'founder only'; end if;
  return query
  select coalesce(r.vendor_name,'(unassigned)'), count(*)::int,
    coalesce(sum(r.parts_cost_rupees),0)::bigint,
    coalesce(sum(r.labour_cost_rupees),0)::bigint,
    round(avg(r.downtime_hours), 2),
    (count(*) filter (where r.status = 'completed'))::int
  from icu_monitor_leadwire_remediation_r3063 r
  group by r.vendor_name
  order by 3 desc;
end; $$;

revoke all on function fn_r3063_vendor_cost() from public, anon;
grant execute on function fn_r3063_vendor_cost() to authenticated;
