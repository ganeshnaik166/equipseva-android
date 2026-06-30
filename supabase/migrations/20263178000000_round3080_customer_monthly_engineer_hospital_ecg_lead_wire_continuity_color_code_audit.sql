-- Round r3080: Customer Monthly Engineer Hospital ECG Lead-Wire Continuity & Color-Code Audit
-- HEAVY ★★★★

create table if not exists ecg_lead_wire_continuity_audits_r3080 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  hospital_name text not null,
  hospital_city text not null check (hospital_city in ('Hyderabad','Mumbai','Delhi','Bengaluru','Chennai','Pune','Kolkata','Ahmedabad')),
  device_model text not null,
  serial_no text not null,
  ward text not null check (ward in ('ICU','CCU','OT','ER','NICU','PICU','GenWard','Cath-Lab')),
  audit_month date not null,
  engineer_name text not null,
  lead_configuration text not null check (lead_configuration in ('3-lead','5-lead','10-lead','12-lead')),
  color_standard text not null check (color_standard in ('AHA','IEC')),
  total_wires int not null,
  passed_wires int not null,
  failed_wires int not null,
  resistance_max_ohms numeric(8,2),
  color_mismatch_count int not null default 0,
  shielding_status text not null check (shielding_status in ('intact','frayed','exposed','broken')),
  insulation_status text not null check (insulation_status in ('good','cracked','peeling','melted')),
  outcome text not null check (outcome in ('pass','partial','fail','replaced')),
  customer_signoff_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists ecg_color_code_findings_r3080 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references ecg_lead_wire_continuity_audits_r3080(id) on delete cascade,
  lead_label text not null check (lead_label in ('RA','LA','LL','RL','V1','V2','V3','V4','V5','V6','C','N','F')),
  expected_color text not null,
  observed_color text not null,
  continuity_ohms numeric(8,2),
  is_continuous boolean not null,
  is_color_correct boolean not null,
  severity text not null check (severity in ('ok','minor','major','critical')),
  action_taken text not null check (action_taken in ('none','recolor_tag','replace_wire','replace_set','escalate')),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

alter table ecg_lead_wire_continuity_audits_r3080 enable row level security;
alter table ecg_color_code_findings_r3080 enable row level security;

drop policy if exists r3080_audits_founder_read on ecg_lead_wire_continuity_audits_r3080;
create policy r3080_audits_founder_read on ecg_lead_wire_continuity_audits_r3080 for select using (is_founder());

drop policy if exists r3080_findings_founder_read on ecg_color_code_findings_r3080;
create policy r3080_findings_founder_read on ecg_color_code_findings_r3080 for select using (is_founder());

insert into ecg_lead_wire_continuity_audits_r3080 (audit_code, hospital_name, hospital_city, device_model, serial_no, ward, audit_month, engineer_name, lead_configuration, color_standard, total_wires, passed_wires, failed_wires, resistance_max_ohms, color_mismatch_count, shielding_status, insulation_status, outcome, customer_signoff_at, notes) values
('ECG-R3080-001','Apollo Jubilee','Hyderabad','Philips IntelliVue MX450','PHI-2389A1','ICU','2026-06-01'::date,'Suresh Kumar','5-lead','AHA',5,5,0,2.10,0,'intact','good','pass','2026-06-02 10:15:00+05:30'::timestamptz,'all leads within spec'),
('ECG-R3080-002','Fortis Bandra','Mumbai','GE MAC 2000','GE-771823','CCU','2026-06-01'::date,'Anita Desai','12-lead','IEC',10,8,2,4.80,1,'frayed','cracked','partial','2026-06-03 14:22:00+05:30'::timestamptz,'V3 wire exposed shielding'),
('ECG-R3080-003','AIIMS','Delhi','Schiller Cardiovit','SCH-44102','OT','2026-06-01'::date,'Rajesh Verma','10-lead','AHA',10,10,0,1.95,0,'intact','good','pass','2026-06-04 09:00:00+05:30'::timestamptz,null),
('ECG-R3080-004','Manipal Whitefield','Bengaluru','Mindray Beneview T8','MIN-8821X','ER','2026-06-02'::date,'Kavya Reddy','5-lead','AHA',5,3,2,9.50,2,'exposed','peeling','fail',null,'replaced full set'),
('ECG-R3080-005','MIOT International','Chennai','Nihon Kohden Cardiofax','NK-66523','Cath-Lab','2026-06-02'::date,'Mohammed Ali','12-lead','IEC',10,10,0,2.30,0,'intact','good','pass','2026-06-05 11:40:00+05:30'::timestamptz,'pre-procedure cleared'),
('ECG-R3080-006','Ruby Hall','Pune','Philips PageWriter TC30','PHI-9912B2','ICU','2026-06-02'::date,'Priya Iyer','12-lead','AHA',10,9,1,5.10,0,'frayed','good','partial','2026-06-06 16:10:00+05:30'::timestamptz,'LL wire intermittent'),
('ECG-R3080-007','AMRI Salt Lake','Kolkata','GE CASE','GE-330912','OT','2026-06-03'::date,'Debabrata Roy','10-lead','IEC',10,6,4,11.20,3,'broken','melted','replaced',null,'fire damage suspected near unit'),
('ECG-R3080-008','Sterling','Ahmedabad','Schiller Cardiovit FT-1','SCH-22018','NICU','2026-06-03'::date,'Hetal Patel','3-lead','AHA',3,3,0,1.50,0,'intact','good','pass','2026-06-07 08:30:00+05:30'::timestamptz,'neonatal set'),
('ECG-R3080-009','KIMS Secunderabad','Hyderabad','Mindray ePM 12','MIN-7732K','PICU','2026-06-04'::date,'Suresh Kumar','5-lead','IEC',5,4,1,6.40,1,'frayed','cracked','partial','2026-06-08 12:00:00+05:30'::timestamptz,'LA color tag faded'),
('ECG-R3080-010','Lilavati','Mumbai','Philips IntelliVue MX40','PHI-4451L','GenWard','2026-06-04'::date,'Anita Desai','3-lead','AHA',3,3,0,1.80,0,'intact','good','pass','2026-06-09 13:15:00+05:30'::timestamptz,null),
('ECG-R3080-011','Max Saket','Delhi','GE MAC 5500','GE-998811','ICU','2026-06-05'::date,'Rajesh Verma','12-lead','AHA',10,7,3,8.20,2,'exposed','peeling','fail',null,'recommended full replacement'),
('ECG-R3080-012','Narayana Health City','Bengaluru','Nihon Kohden ECG-2350','NK-12278','Cath-Lab','2026-06-05'::date,'Kavya Reddy','12-lead','IEC',10,10,0,2.05,0,'intact','good','pass','2026-06-10 10:00:00+05:30'::timestamptz,'fresh set installed last month'),
('ECG-R3080-013','Apollo Greams Road','Chennai','Philips PageWriter TC50','PHI-7720T','CCU','2026-06-06'::date,'Mohammed Ali','12-lead','AHA',10,8,2,5.90,1,'frayed','good','partial','2026-06-11 15:20:00+05:30'::timestamptz,'V5 mismatched color'),
('ECG-R3080-014','Jehangir','Pune','Schiller Cardiovit AT-102','SCH-55401','ER','2026-06-06'::date,'Priya Iyer','10-lead','IEC',10,9,1,4.30,0,'intact','cracked','partial','2026-06-12 09:45:00+05:30'::timestamptz,null),
('ECG-R3080-015','Fortis Anandapur','Kolkata','GE MAC 1200ST','GE-660091','OT','2026-06-07'::date,'Debabrata Roy','12-lead','AHA',10,10,0,2.40,0,'intact','good','pass','2026-06-13 11:30:00+05:30'::timestamptz,'post-cleaning audit'),
('ECG-R3080-016','CIMS','Ahmedabad','Mindray Beneview T5','MIN-3320T','ICU','2026-06-07'::date,'Hetal Patel','5-lead','IEC',5,2,3,14.80,2,'broken','melted','replaced',null,'urgent ship of replacement set'),
('ECG-R3080-017','Yashoda Somajiguda','Hyderabad','Philips Efficia CM150','PHI-1144E','GenWard','2026-06-08'::date,'Suresh Kumar','3-lead','AHA',3,3,0,1.60,0,'intact','good','pass','2026-06-14 14:00:00+05:30'::timestamptz,null),
('ECG-R3080-018','Hinduja','Mumbai','GE CASE Cardiosoft','GE-887712','Cath-Lab','2026-06-08'::date,'Anita Desai','12-lead','IEC',10,9,1,4.60,1,'frayed','good','partial','2026-06-15 10:30:00+05:30'::timestamptz,'RL tag faded'),
('ECG-R3080-019','BLK Super Speciality','Delhi','Schiller Cardiovit MS-2010','SCH-77620','NICU','2026-06-09'::date,'Rajesh Verma','3-lead','IEC',3,3,0,1.70,0,'intact','good','pass','2026-06-16 09:00:00+05:30'::timestamptz,'neonatal new install'),
('ECG-R3080-020','Sakra World','Bengaluru','Nihon Kohden Cardiofax M','NK-44023','ICU','2026-06-09'::date,'Kavya Reddy','5-lead','AHA',5,5,0,2.20,0,'intact','good','pass','2026-06-17 12:15:00+05:30'::timestamptz,null);

insert into ecg_color_code_findings_r3080 (audit_id, lead_label, expected_color, observed_color, continuity_ohms, is_continuous, is_color_correct, severity, action_taken, resolved) values
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-002'),'V3','green','green',4.80,true,true,'minor','recolor_tag',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-002'),'RA','white','yellow',3.10,true,false,'major','recolor_tag',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-004'),'LL','red','red',9.50,false,true,'critical','replace_wire',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-004'),'RL','black','grey',null,true,false,'major','replace_set',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-006'),'LL','red','red',5.10,false,true,'major','replace_wire',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-007'),'V1','brown/red','black',12.00,false,false,'critical','escalate',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-007'),'V2','brown/yellow','black',11.80,false,false,'critical','escalate',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-007'),'V3','brown/green','green',9.20,true,false,'major','replace_set',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-009'),'LA','black','grey',null,true,false,'minor','recolor_tag',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-011'),'V4','brown/blue','black',8.20,false,false,'critical','replace_set',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-011'),'V5','brown/orange','black',7.80,false,false,'major','replace_set',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-011'),'V6','brown/violet','black',7.10,true,false,'major','replace_set',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-013'),'V5','brown/orange','red',5.90,true,false,'minor','recolor_tag',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-014'),'V2','brown/yellow','yellow',4.30,true,true,'minor','none',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-016'),'RA','white','frayed',null,false,false,'critical','replace_set',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-016'),'LA','black','melted',null,false,false,'critical','replace_set',true),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-016'),'LL','red','melted',null,false,false,'critical','escalate',false),
((select id from ecg_lead_wire_continuity_audits_r3080 where audit_code='ECG-R3080-018'),'RL','green','green',4.60,true,true,'minor','recolor_tag',true);

-- RPC 1: monthly outcome rollup
create or replace function rpc_r3080_monthly_outcomes()
returns table(audit_month date, total int, passes int, partials int, fails int, replaced int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_month,
    count(*)::int as total,
    (count(*) filter (where a.outcome='pass'))::int,
    (count(*) filter (where a.outcome='partial'))::int,
    (count(*) filter (where a.outcome='fail'))::int,
    (count(*) filter (where a.outcome='replaced'))::int
  from ecg_lead_wire_continuity_audits_r3080 a
  group by a.audit_month
  order by a.audit_month;
end;$$;

-- RPC 2: by city
create or replace function rpc_r3080_by_city()
returns table(city text, audits int, fail_or_replace int, avg_resistance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.hospital_city,
    count(*)::int,
    (count(*) filter (where a.outcome in ('fail','replaced')))::int,
    round(avg(a.resistance_max_ohms)::numeric, 2)
  from ecg_lead_wire_continuity_audits_r3080 a
  group by a.hospital_city
  order by count(*) desc;
end;$$;

-- RPC 3: engineer leaderboard
create or replace function rpc_r3080_engineer_leaderboard()
returns table(engineer_name text, audits int, pass_rate numeric, total_wires int, failed_wires int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.engineer_name,
    count(*)::int,
    round((count(*) filter (where a.outcome='pass'))::numeric * 100.0 / nullif(count(*),0), 1),
    sum(a.total_wires)::int,
    sum(a.failed_wires)::int
  from ecg_lead_wire_continuity_audits_r3080 a
  group by a.engineer_name
  order by count(*) desc;
end;$$;

-- RPC 4: color mismatch findings
create or replace function rpc_r3080_color_mismatch_findings()
returns table(audit_code text, hospital_name text, lead_label text, expected_color text, observed_color text, severity text, action_taken text, resolved boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_code, a.hospital_name, f.lead_label, f.expected_color, f.observed_color, f.severity, f.action_taken, f.resolved
  from ecg_color_code_findings_r3080 f
  join ecg_lead_wire_continuity_audits_r3080 a on a.id = f.audit_id
  where f.is_color_correct = false
  order by f.severity desc, a.audit_code;
end;$$;

-- RPC 5: ward-level risk
create or replace function rpc_r3080_ward_risk()
returns table(ward text, audits int, critical_findings int, unresolved int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.ward,
    count(distinct a.id)::int,
    (count(f.id) filter (where f.severity='critical'))::int,
    (count(f.id) filter (where f.resolved=false))::int
  from ecg_lead_wire_continuity_audits_r3080 a
  left join ecg_color_code_findings_r3080 f on f.audit_id = a.id
  group by a.ward
  order by (count(f.id) filter (where f.severity='critical'))::int desc;
end;$$;

-- RPC 6: shielding/insulation degradation
create or replace function rpc_r3080_degradation_matrix()
returns table(shielding_status text, insulation_status text, count int, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.shielding_status, a.insulation_status,
    count(*)::int,
    (count(*) filter (where a.outcome in ('fail','replaced')))::int
  from ecg_lead_wire_continuity_audits_r3080 a
  group by a.shielding_status, a.insulation_status
  order by count(*) desc;
end;$$;

-- RPC 7: lead configuration summary
create or replace function rpc_r3080_lead_config_summary()
returns table(lead_configuration text, color_standard text, audits int, mismatch_total int, pass_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.lead_configuration, a.color_standard,
    count(*)::int,
    sum(a.color_mismatch_count)::int,
    round((count(*) filter (where a.outcome='pass'))::numeric * 100.0 / nullif(count(*),0), 1)
  from ecg_lead_wire_continuity_audits_r3080 a
  group by a.lead_configuration, a.color_standard
  order by a.lead_configuration, a.color_standard;
end;$$;

-- RPC 8: critical unresolved tracker
create or replace function rpc_r3080_critical_unresolved()
returns table(audit_code text, hospital_name text, hospital_city text, ward text, lead_label text, action_taken text, audit_month date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_code, a.hospital_name, a.hospital_city, a.ward, f.lead_label, f.action_taken, a.audit_month
  from ecg_color_code_findings_r3080 f
  join ecg_lead_wire_continuity_audits_r3080 a on a.id = f.audit_id
  where f.severity='critical' and f.resolved=false
  order by a.audit_month desc, a.audit_code;
end;$$;

revoke all on function rpc_r3080_monthly_outcomes() from public, anon;
revoke all on function rpc_r3080_by_city() from public, anon;
revoke all on function rpc_r3080_engineer_leaderboard() from public, anon;
revoke all on function rpc_r3080_color_mismatch_findings() from public, anon;
revoke all on function rpc_r3080_ward_risk() from public, anon;
revoke all on function rpc_r3080_degradation_matrix() from public, anon;
revoke all on function rpc_r3080_lead_config_summary() from public, anon;
revoke all on function rpc_r3080_critical_unresolved() from public, anon;

grant execute on function rpc_r3080_monthly_outcomes() to authenticated;
grant execute on function rpc_r3080_by_city() to authenticated;
grant execute on function rpc_r3080_engineer_leaderboard() to authenticated;
grant execute on function rpc_r3080_color_mismatch_findings() to authenticated;
grant execute on function rpc_r3080_ward_risk() to authenticated;
grant execute on function rpc_r3080_degradation_matrix() to authenticated;
grant execute on function rpc_r3080_lead_config_summary() to authenticated;
grant execute on function rpc_r3080_critical_unresolved() to authenticated;
