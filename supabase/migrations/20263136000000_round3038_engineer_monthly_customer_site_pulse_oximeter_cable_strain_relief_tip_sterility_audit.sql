-- round r3038 — Engineer Monthly Customer Site Pulse-Oximeter Cable Strain-Relief & Tip Sterility Audit
-- 2 tables + 7 RPCs, founder-gated

create table if not exists engineer_pulseox_cable_audits_r3038 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  engineer_name text not null,
  customer_site text not null,
  device_serial text not null,
  audit_month date not null,
  cable_strain_relief_grade text not null check (cable_strain_relief_grade in ('pristine','minor_wear','moderate_wear','frayed','exposed_conductor')),
  tip_sterility_status text not null check (tip_sterility_status in ('sterile','acceptable','borderline','contaminated','rejected')),
  bend_test_cycles_passed int not null check (bend_test_cycles_passed between 0 and 5000),
  flex_resistance_ohm numeric(8,3) not null check (flex_resistance_ohm between 0 and 50),
  tip_swab_atp_rlu int not null check (tip_swab_atp_rlu between 0 and 10000),
  finger_clip_spring_newtons numeric(6,2) not null check (finger_clip_spring_newtons between 0 and 20),
  cable_replaced boolean not null default false,
  tip_replaced boolean not null default false,
  audit_outcome text not null check (audit_outcome in ('pass','pass_with_advice','fail_replace_cable','fail_replace_tip','fail_full_assembly','escalated')),
  customer_signature_captured boolean not null default false,
  audit_duration_minutes int not null check (audit_duration_minutes between 5 and 180),
  risk_score numeric(5,2) not null check (risk_score between 0 and 100),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists engineer_pulseox_audit_findings_r3038 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null references engineer_pulseox_cable_audits_r3038(audit_code) on delete cascade,
  finding_category text not null check (finding_category in ('strain_relief','cable_jacket','connector_pin','tip_optics','tip_sleeve','spring_clip','calibration_drift','documentation')),
  severity text not null check (severity in ('info','low','medium','high','critical')),
  finding_summary text not null,
  corrective_action text not null check (corrective_action in ('none','clean_and_log','replace_part','replace_assembly','quarantine_device','schedule_followup')),
  part_sku text,
  cost_rupees numeric(10,2) not null check (cost_rupees between 0 and 50000),
  resolved boolean not null default false,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table engineer_pulseox_cable_audits_r3038 enable row level security;
alter table engineer_pulseox_audit_findings_r3038 enable row level security;

drop policy if exists pulseox_audits_founder_r3038 on engineer_pulseox_cable_audits_r3038;
create policy pulseox_audits_founder_r3038 on engineer_pulseox_cable_audits_r3038 for select to authenticated using (is_founder());

drop policy if exists pulseox_findings_founder_r3038 on engineer_pulseox_audit_findings_r3038;
create policy pulseox_findings_founder_r3038 on engineer_pulseox_audit_findings_r3038 for select to authenticated using (is_founder());

-- seed audits (16 rows)
insert into engineer_pulseox_cable_audits_r3038 (audit_code, engineer_name, customer_site, device_serial, audit_month, cable_strain_relief_grade, tip_sterility_status, bend_test_cycles_passed, flex_resistance_ohm, tip_swab_atp_rlu, finger_clip_spring_newtons, cable_replaced, tip_replaced, audit_outcome, customer_signature_captured, audit_duration_minutes, risk_score, notes) values
('PO-AUD-3038-001','Ravi Kumar','Apollo Jubilee Hills ICU-3','POX-A7-22318','2026-06-01'::date,'pristine','sterile',5000,0.412,42,9.85,false,false,'pass',true,22,4.20,'gold standard unit'),
('PO-AUD-3038-002','Priya Sharma','KIMS Secunderabad NICU','POX-B2-19044','2026-06-01'::date,'minor_wear','acceptable',4200,1.215,128,8.40,false,false,'pass_with_advice',true,38,18.50,'advised quarterly recheck'),
('PO-AUD-3038-003','Suresh Reddy','Yashoda Somajiguda CTVS','POX-C9-30771','2026-06-01'::date,'moderate_wear','borderline',2100,4.380,612,7.10,false,false,'pass_with_advice',true,55,42.10,'borderline ATP, advised tip swap next month'),
('PO-AUD-3038-004','Anita Patel','Continental Gachibowli OT-2','POX-D4-28215','2026-06-01'::date,'frayed','acceptable',900,8.920,180,6.85,true,false,'fail_replace_cable',true,72,68.40,'cable replaced on-site'),
('PO-AUD-3038-005','Mohan Iyer','Care Banjara Pediatrics','POX-E1-31905','2026-06-01'::date,'minor_wear','contaminated',3800,1.504,2840,8.20,false,true,'fail_replace_tip',true,48,55.20,'tip contaminated, replaced'),
('PO-AUD-3038-006','Deepa Nair','Rainbow Hyderguda NICU','POX-F6-25618','2026-06-01'::date,'exposed_conductor','rejected',300,18.450,4150,5.20,true,true,'fail_full_assembly',true,95,92.80,'full assembly swap, escalated to QA'),
('PO-AUD-3038-007','Kiran Joshi','AIG Hospitals Gachibowli','POX-G3-27884','2026-06-01'::date,'pristine','sterile',4900,0.508,55,9.60,false,false,'pass',true,25,5.10,null),
('PO-AUD-3038-008','Vandana Rao','Sunshine Paradise ICU','POX-H8-23156','2026-06-01'::date,'minor_wear','sterile',4500,1.020,68,9.10,false,false,'pass',true,28,8.40,'clean unit'),
('PO-AUD-3038-009','Arun Pillai','Star Hospitals OT-4','POX-I2-29407','2026-06-01'::date,'moderate_wear','acceptable',2400,3.815,210,7.40,false,false,'pass_with_advice',true,52,38.60,'schedule followup 4 weeks'),
('PO-AUD-3038-010','Lakshmi Menon','Olive Healthcare Madhapur','POX-J5-26733','2026-06-01'::date,'frayed','borderline',1100,7.640,780,6.50,true,false,'fail_replace_cable',true,68,71.20,null),
('PO-AUD-3038-011','Rahul Verma','MediCover Hitec NICU','POX-K7-32108','2026-06-01'::date,'minor_wear','sterile',4700,0.918,38,9.30,false,false,'pass',true,24,6.80,'fresh deployment'),
('PO-AUD-3038-012','Sangeeta Bose','Asian Institute ICU-1','POX-L9-21998','2026-06-01'::date,'moderate_wear','contaminated',2050,4.105,3120,7.05,false,true,'fail_replace_tip',true,58,64.50,'tip swap, advised disinfection SOP refresh'),
('PO-AUD-3038-013','Naveen Rao','Aware Gleneagles ICU','POX-M1-28640','2026-06-01'::date,'exposed_conductor','acceptable',420,16.280,160,5.80,true,false,'escalated',true,88,84.40,'escalated to founder QA review'),
('PO-AUD-3038-014','Meera Krishnan','Citizens Specialty NICU','POX-N4-30215','2026-06-01'::date,'pristine','sterile',5000,0.385,28,9.90,false,false,'pass',true,20,3.10,'cleanest in fleet'),
('PO-AUD-3038-015','Tarun Bhat','Maxcure Madhapur CTVS','POX-O6-24871','2026-06-01'::date,'minor_wear','acceptable',4100,1.380,140,8.60,false,false,'pass_with_advice',true,40,22.80,null),
('PO-AUD-3038-016','Pooja Desai','Virinchi LB Nagar ICU','POX-P8-27319','2026-06-01'::date,'frayed','rejected',780,9.620,4880,6.10,true,true,'fail_full_assembly',true,98,89.20,'full assembly, customer signed off');

-- seed findings (24 rows)
insert into engineer_pulseox_audit_findings_r3038 (audit_code, finding_category, severity, finding_summary, corrective_action, part_sku, cost_rupees, resolved, resolved_at) values
('PO-AUD-3038-002','strain_relief','low','Slight kink at proximal connector','clean_and_log','SR-PROX-22',0,true,now()),
('PO-AUD-3038-003','cable_jacket','medium','Surface scuff 12cm from tip','clean_and_log','CJ-SCUF-08',0,true,now()),
('PO-AUD-3038-003','tip_optics','medium','LED brightness 78% nominal','schedule_followup','TIP-LED-PA1',0,false,null),
('PO-AUD-3038-004','strain_relief','high','Strain relief boot torn at distal end','replace_part','SR-DIST-44',1840.00,true,now()),
('PO-AUD-3038-004','cable_jacket','high','Frayed jacket exposing braid','replace_part','CJ-BRAID-12',2100.00,true,now()),
('PO-AUD-3038-005','tip_sleeve','high','Silicone sleeve discoloured, ATP 2840 RLU','replace_part','TIP-SLV-RD3',1450.00,true,now()),
('PO-AUD-3038-005','documentation','low','Last clean log missing 2 weeks','clean_and_log',null,0,true,now()),
('PO-AUD-3038-006','connector_pin','critical','Pin 3 oxidised, intermittent SpO2','replace_assembly','PROBE-FULL-A7',8400.00,true,now()),
('PO-AUD-3038-006','tip_optics','critical','Photodiode window cracked','replace_assembly','PROBE-FULL-A7',0,true,now()),
('PO-AUD-3038-006','tip_sleeve','critical','Biofilm visible, ATP 4150 RLU','quarantine_device','QUARANTINE-Q1',0,true,now()),
('PO-AUD-3038-008','spring_clip','info','Spring tension nominal 9.1N','none',null,0,true,now()),
('PO-AUD-3038-009','calibration_drift','medium','SpO2 reads 1.8% high vs reference','schedule_followup','CAL-KIT-R2',0,false,null),
('PO-AUD-3038-010','strain_relief','high','Strain relief detached proximal','replace_part','SR-PROX-22',1840.00,true,now()),
('PO-AUD-3038-010','cable_jacket','high','Jacket frayed 6 spots','replace_part','CJ-BRAID-12',2100.00,true,now()),
('PO-AUD-3038-010','tip_optics','medium','Mild residue on emitter window','clean_and_log',null,0,true,now()),
('PO-AUD-3038-012','tip_sleeve','high','ATP 3120 RLU, contamination confirmed','replace_part','TIP-SLV-RD3',1450.00,true,now()),
('PO-AUD-3038-012','documentation','medium','Disinfection log gaps 3 days','schedule_followup',null,0,false,null),
('PO-AUD-3038-013','connector_pin','critical','Exposed conductor at proximal','replace_part','SR-PROX-22',1840.00,true,now()),
('PO-AUD-3038-013','cable_jacket','critical','Conductor visible 4cm','quarantine_device','QUARANTINE-Q1',0,true,now()),
('PO-AUD-3038-013','calibration_drift','high','Drift 3.2% — escalate','schedule_followup','CAL-KIT-R2',0,false,null),
('PO-AUD-3038-015','strain_relief','low','Minor scuff','clean_and_log',null,0,true,now()),
('PO-AUD-3038-016','connector_pin','critical','Pin 5 bent','replace_assembly','PROBE-FULL-A7',8400.00,true,now()),
('PO-AUD-3038-016','tip_sleeve','critical','ATP 4880 — full reject','replace_assembly','PROBE-FULL-A7',0,true,now()),
('PO-AUD-3038-016','documentation','medium','Customer SOP outdated','schedule_followup',null,0,false,null);

revoke all on engineer_pulseox_cable_audits_r3038 from public, anon;
revoke all on engineer_pulseox_audit_findings_r3038 from public, anon;
grant select on engineer_pulseox_cable_audits_r3038 to authenticated;
grant select on engineer_pulseox_audit_findings_r3038 to authenticated;

-- RPC 1: monthly audit summary
create or replace function rpc_pulseox_r3038_monthly_summary()
returns table(audit_month date, audits_count int, pass_count int, fail_count int, escalated_count int, avg_risk_score numeric, total_repair_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(*)::int as audits_count,
         (count(*) filter (where a.audit_outcome in ('pass','pass_with_advice')))::int as pass_count,
         (count(*) filter (where a.audit_outcome in ('fail_replace_cable','fail_replace_tip','fail_full_assembly')))::int as fail_count,
         (count(*) filter (where a.audit_outcome = 'escalated'))::int as escalated_count,
         round(avg(a.risk_score)::numeric, 2) as avg_risk_score,
         coalesce((select sum(f.cost_rupees) from engineer_pulseox_audit_findings_r3038 f join engineer_pulseox_cable_audits_r3038 a2 on a2.audit_code = f.audit_code where a2.audit_month = a.audit_month), 0)::numeric as total_repair_cost
  from engineer_pulseox_cable_audits_r3038 a
  group by a.audit_month
  order by a.audit_month desc;
end;$$;

-- RPC 2: engineer leaderboard
create or replace function rpc_pulseox_r3038_engineer_leaderboard()
returns table(engineer_name text, audits int, passes int, escalations int, avg_risk numeric, avg_duration_minutes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int as audits,
         (count(*) filter (where a.audit_outcome in ('pass','pass_with_advice')))::int as passes,
         (count(*) filter (where a.audit_outcome = 'escalated'))::int as escalations,
         round(avg(a.risk_score)::numeric, 2) as avg_risk,
         round(avg(a.audit_duration_minutes)::numeric, 1) as avg_duration_minutes
  from engineer_pulseox_cable_audits_r3038 a
  group by a.engineer_name
  order by avg_risk asc;
end;$$;

-- RPC 3: strain relief grade distribution
create or replace function rpc_pulseox_r3038_strain_relief_distribution()
returns table(cable_strain_relief_grade text, units int, cables_replaced int, avg_flex_resistance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.cable_strain_relief_grade,
         count(*)::int as units,
         (count(*) filter (where a.cable_replaced))::int as cables_replaced,
         round(avg(a.flex_resistance_ohm)::numeric, 3) as avg_flex_resistance
  from engineer_pulseox_cable_audits_r3038 a
  group by a.cable_strain_relief_grade
  order by units desc;
end;$$;

-- RPC 4: tip sterility distribution
create or replace function rpc_pulseox_r3038_tip_sterility_distribution()
returns table(tip_sterility_status text, units int, tips_replaced int, avg_atp numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.tip_sterility_status,
         count(*)::int as units,
         (count(*) filter (where a.tip_replaced))::int as tips_replaced,
         round(avg(a.tip_swab_atp_rlu)::numeric, 1) as avg_atp
  from engineer_pulseox_cable_audits_r3038 a
  group by a.tip_sterility_status
  order by avg_atp desc;
end;$$;

-- RPC 5: findings by severity
create or replace function rpc_pulseox_r3038_findings_by_severity()
returns table(severity text, findings int, resolved int, total_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         count(*)::int as findings,
         (count(*) filter (where f.resolved))::int as resolved,
         round(coalesce(sum(f.cost_rupees),0)::numeric, 2) as total_cost
  from engineer_pulseox_audit_findings_r3038 f
  group by f.severity
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end;$$;

-- RPC 6: top risk audits
create or replace function rpc_pulseox_r3038_top_risk_audits()
returns table(audit_code text, customer_site text, engineer_name text, risk_score numeric, audit_outcome text, finding_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_code, a.customer_site, a.engineer_name, a.risk_score, a.audit_outcome,
         (select count(*)::int from engineer_pulseox_audit_findings_r3038 f where f.audit_code = a.audit_code) as finding_count
  from engineer_pulseox_cable_audits_r3038 a
  order by a.risk_score desc
  limit 10;
end;$$;

-- RPC 7: corrective action mix
create or replace function rpc_pulseox_r3038_corrective_action_mix()
returns table(corrective_action text, occurrences int, distinct_audits int, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.corrective_action,
         count(*)::int as occurrences,
         count(distinct f.audit_code)::int as distinct_audits,
         round(avg(f.cost_rupees)::numeric, 2) as avg_cost
  from engineer_pulseox_audit_findings_r3038 f
  group by f.corrective_action
  order by occurrences desc;
end;$$;

-- RPC 8: unresolved findings list
create or replace function rpc_pulseox_r3038_unresolved_findings()
returns table(audit_code text, customer_site text, finding_category text, severity text, finding_summary text, corrective_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.audit_code, a.customer_site, f.finding_category, f.severity, f.finding_summary, f.corrective_action
  from engineer_pulseox_audit_findings_r3038 f
  join engineer_pulseox_cable_audits_r3038 a on a.audit_code = f.audit_code
  where f.resolved = false
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end;$$;

revoke all on function rpc_pulseox_r3038_monthly_summary() from public, anon;
revoke all on function rpc_pulseox_r3038_engineer_leaderboard() from public, anon;
revoke all on function rpc_pulseox_r3038_strain_relief_distribution() from public, anon;
revoke all on function rpc_pulseox_r3038_tip_sterility_distribution() from public, anon;
revoke all on function rpc_pulseox_r3038_findings_by_severity() from public, anon;
revoke all on function rpc_pulseox_r3038_top_risk_audits() from public, anon;
revoke all on function rpc_pulseox_r3038_corrective_action_mix() from public, anon;
revoke all on function rpc_pulseox_r3038_unresolved_findings() from public, anon;

grant execute on function rpc_pulseox_r3038_monthly_summary() to authenticated;
grant execute on function rpc_pulseox_r3038_engineer_leaderboard() to authenticated;
grant execute on function rpc_pulseox_r3038_strain_relief_distribution() to authenticated;
grant execute on function rpc_pulseox_r3038_tip_sterility_distribution() to authenticated;
grant execute on function rpc_pulseox_r3038_findings_by_severity() to authenticated;
grant execute on function rpc_pulseox_r3038_top_risk_audits() to authenticated;
grant execute on function rpc_pulseox_r3038_corrective_action_mix() to authenticated;
grant execute on function rpc_pulseox_r3038_unresolved_findings() to authenticated;
