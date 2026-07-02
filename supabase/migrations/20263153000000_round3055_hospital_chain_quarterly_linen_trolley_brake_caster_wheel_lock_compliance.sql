-- Round 3055 — Hospital Chain Quarterly Linen Trolley Brake Caster & Wheel Lock Compliance

create table if not exists hospital_chain_linen_trolley_inspections_r3055 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_name text not null,
  hospital_unit text not null,
  ward_zone text not null,
  trolley_asset_tag text not null,
  trolley_model text not null,
  inspection_quarter text not null,
  inspected_on date not null,
  caster_count int not null,
  casters_with_brake int not null,
  casters_brake_passed int not null,
  wheel_lock_passed_count int not null,
  swivel_freeplay_mm numeric(5,2) not null,
  load_test_kg numeric(6,2) not null,
  compliance_status text not null,
  defect_severity text not null,
  remediation_eta_days int,
  inspector_name text not null,
  signed_off boolean not null default false,
  constraint chk_status_r3055 check (compliance_status in ('compliant','minor_nc','major_nc','critical_fail','pending_recheck')),
  constraint chk_sev_r3055 check (defect_severity in ('none','low','medium','high','critical'))
);

alter table hospital_chain_linen_trolley_inspections_r3055 enable row level security;
drop policy if exists pol_sel_r3055_a on hospital_chain_linen_trolley_inspections_r3055;
create policy pol_sel_r3055_a on hospital_chain_linen_trolley_inspections_r3055 for select to authenticated using (is_founder());

create table if not exists hospital_chain_caster_remediation_actions_r3055 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  inspection_id uuid references hospital_chain_linen_trolley_inspections_r3055(id) on delete cascade,
  action_kind text not null,
  vendor_name text not null,
  part_replaced text not null,
  units_serviced int not null,
  cost_rupees numeric(10,2) not null,
  scheduled_on date not null,
  completed_on date,
  outcome text not null,
  signed_by text not null,
  constraint chk_kind_r3055b check (action_kind in ('caster_swap','brake_pad_replace','wheel_lock_repair','full_trolley_retire','lubrication','axle_realign')),
  constraint chk_outcome_r3055b check (outcome in ('pending','in_progress','completed','failed','rescheduled'))
);

alter table hospital_chain_caster_remediation_actions_r3055 enable row level security;
drop policy if exists pol_sel_r3055_b on hospital_chain_caster_remediation_actions_r3055;
create policy pol_sel_r3055_b on hospital_chain_caster_remediation_actions_r3055 for select to authenticated using (is_founder());

insert into hospital_chain_linen_trolley_inspections_r3055 (chain_name, hospital_unit, ward_zone, trolley_asset_tag, trolley_model, inspection_quarter, inspected_on, caster_count, casters_with_brake, casters_brake_passed, wheel_lock_passed_count, swivel_freeplay_mm, load_test_kg, compliance_status, defect_severity, remediation_eta_days, inspector_name, signed_off) values
('Apollo','Hyd-Jubilee','ICU-3','LT-AP-0001','Hupfer 4W','Q1-2026','2026-01-08'::date,4,4,4,4,1.20,180.00,'compliant','none',null,'R. Iyer',true),
('Apollo','Hyd-Jubilee','OT-Wing','LT-AP-0017','Hupfer 4W','Q1-2026','2026-01-09'::date,4,4,3,3,2.40,160.00,'minor_nc','low',7,'R. Iyer',true),
('Apollo','Chennai-Greams','Ward-7','LT-AP-0044','MetroLink HD','Q1-2026','2026-01-11'::date,4,4,2,2,3.10,150.00,'major_nc','medium',14,'P. Naidu',true),
('Apollo','Bangalore-Bann','CCU','LT-AP-0078','Hupfer 4W','Q2-2026','2026-04-04'::date,4,4,4,4,0.90,200.00,'compliant','none',null,'S. Kumar',true),
('Manipal','Bangalore-Old','PostOp','LT-MN-0112','SteelCo Pro','Q2-2026','2026-04-12'::date,4,4,1,1,4.80,140.00,'critical_fail','critical',3,'L. Pinto',true),
('Manipal','Jaipur-MGH','Ward-2','LT-MN-0133','SteelCo Pro','Q2-2026','2026-04-15'::date,4,4,3,4,2.10,170.00,'minor_nc','low',10,'L. Pinto',false),
('Fortis','Mumbai-Mulund','ICU-1','LT-FT-0201','MetroLink HD','Q2-2026','2026-05-02'::date,4,4,4,4,1.00,190.00,'compliant','none',null,'A. Shah',true),
('Fortis','Mumbai-Mulund','OT-2','LT-FT-0223','MetroLink HD','Q2-2026','2026-05-03'::date,4,4,2,3,3.50,155.00,'major_nc','high',12,'A. Shah',true),
('Fortis','Delhi-Vasant','Ward-4','LT-FT-0265','Hupfer 4W','Q3-2026','2026-07-09'::date,4,4,4,4,1.50,175.00,'compliant','none',null,'V. Khanna',true),
('Max','Delhi-Saket','ICU-2','LT-MX-0301','SteelCo Pro','Q3-2026','2026-07-14'::date,4,4,3,3,2.80,165.00,'minor_nc','medium',7,'D. Mehta',true),
('Max','Mohali','CCU','LT-MX-0322','SteelCo Pro','Q3-2026','2026-07-17'::date,4,4,0,1,5.50,130.00,'critical_fail','critical',2,'D. Mehta',true),
('Narayana','Bangalore-Hosur','Ward-9','LT-NR-0401','MetroLink HD','Q3-2026','2026-08-20'::date,4,4,4,4,1.10,195.00,'compliant','none',null,'K. Rao',true),
('Narayana','Kolkata-Howrah','OT-Wing','LT-NR-0419','Hupfer 4W','Q3-2026','2026-08-22'::date,4,4,2,2,3.90,150.00,'major_nc','high',15,'K. Rao',false),
('Medanta','Gurgaon','ICU-4','LT-MD-0501','Hupfer 4W','Q4-2026','2026-10-05'::date,4,4,4,4,0.80,205.00,'compliant','none',null,'B. Singh',true),
('Medanta','Lucknow','PostOp','LT-MD-0530','SteelCo Pro','Q4-2026','2026-10-08'::date,4,4,3,4,2.20,170.00,'minor_nc','low',9,'B. Singh',true),
('AIIMS','Delhi-Ansari','Ward-12','LT-AI-0601','MetroLink HD','Q4-2026','2026-10-15'::date,4,4,1,2,4.30,145.00,'critical_fail','critical',4,'M. Chopra',true),
('AIIMS','Bhopal','ICU-1','LT-AI-0633','Hupfer 4W','Q4-2026','2026-10-18'::date,4,4,4,4,1.30,180.00,'compliant','none',null,'M. Chopra',true),
('KIMS','Hyd-Secund','Ward-3','LT-KM-0701','SteelCo Pro','Q1-2026','2026-02-04'::date,4,4,3,3,2.60,160.00,'pending_recheck','medium',8,'T. Reddy',false),
('KIMS','Hyd-Secund','OT-5','LT-KM-0719','Hupfer 4W','Q1-2026','2026-02-06'::date,4,4,4,4,1.40,185.00,'compliant','none',null,'T. Reddy',true);

insert into hospital_chain_caster_remediation_actions_r3055 (action_kind, vendor_name, part_replaced, units_serviced, cost_rupees, scheduled_on, completed_on, outcome, signed_by) values
('caster_swap','Tente India','5in TPR caster',4,4800.00,'2026-01-15'::date,'2026-01-16'::date,'completed','R. Iyer'),
('brake_pad_replace','Blickle','pedal brake pad',2,1800.00,'2026-01-18'::date,'2026-01-18'::date,'completed','R. Iyer'),
('wheel_lock_repair','Tente India','locking lever',1,650.00,'2026-04-18'::date,null,'pending','L. Pinto'),
('full_trolley_retire','Hupfer','full unit',1,38500.00,'2026-04-22'::date,'2026-04-25'::date,'completed','L. Pinto'),
('lubrication','InHouse','axle grease',4,420.00,'2026-05-08'::date,'2026-05-08'::date,'completed','A. Shah'),
('axle_realign','MetroLink','axle bolt set',2,2200.00,'2026-05-14'::date,'2026-05-15'::date,'completed','A. Shah'),
('caster_swap','Tente India','6in PU caster',4,5400.00,'2026-07-20'::date,'2026-07-21'::date,'completed','D. Mehta'),
('brake_pad_replace','Blickle','pedal brake pad',3,2700.00,'2026-07-22'::date,null,'in_progress','D. Mehta'),
('full_trolley_retire','SteelCo','full unit',2,72000.00,'2026-07-25'::date,'2026-07-29'::date,'completed','D. Mehta'),
('wheel_lock_repair','Tente India','locking lever',2,1300.00,'2026-08-28'::date,'2026-08-30'::date,'completed','K. Rao'),
('caster_swap','Tente India','5in TPR caster',3,3600.00,'2026-09-01'::date,null,'rescheduled','K. Rao'),
('lubrication','InHouse','axle grease',4,420.00,'2026-10-12'::date,'2026-10-12'::date,'completed','B. Singh'),
('full_trolley_retire','MetroLink','full unit',3,108000.00,'2026-10-20'::date,null,'pending','M. Chopra'),
('brake_pad_replace','Blickle','pedal brake pad',4,3600.00,'2026-10-24'::date,'2026-10-25'::date,'completed','M. Chopra'),
('axle_realign','Hupfer','axle bolt set',1,1100.00,'2026-02-10'::date,null,'failed','T. Reddy'),
('caster_swap','Tente India','5in TPR caster',2,2400.00,'2026-02-14'::date,'2026-02-16'::date,'completed','T. Reddy');

create or replace function r3055_chain_summary()
returns table(chain_name text, inspections int, compliant int, critical_fails int, avg_freeplay numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.chain_name,
         count(*)::int,
         (count(*) filter (where i.compliance_status='compliant'))::int,
         (count(*) filter (where i.compliance_status='critical_fail'))::int,
         round(avg(i.swivel_freeplay_mm)::numeric,2)
  from hospital_chain_linen_trolley_inspections_r3055 i
  group by i.chain_name
  order by i.chain_name;
end; $$;
revoke all on function r3055_chain_summary() from public, anon;
grant execute on function r3055_chain_summary() to authenticated;

create or replace function r3055_quarterly_compliance()
returns table(inspection_quarter text, total int, pass_rate numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.inspection_quarter,
         count(*)::int,
         round((count(*) filter (where i.compliance_status='compliant'))::numeric * 100.0 / nullif(count(*),0), 1),
         (count(*) filter (where i.compliance_status='critical_fail'))::int
  from hospital_chain_linen_trolley_inspections_r3055 i
  group by i.inspection_quarter
  order by i.inspection_quarter;
end; $$;
revoke all on function r3055_quarterly_compliance() from public, anon;
grant execute on function r3055_quarterly_compliance() to authenticated;

create or replace function r3055_top_critical_units()
returns table(chain_name text, hospital_unit text, ward_zone text, trolley_asset_tag text, swivel_freeplay_mm numeric, inspected_on date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.chain_name, i.hospital_unit, i.ward_zone, i.trolley_asset_tag, i.swivel_freeplay_mm, i.inspected_on
  from hospital_chain_linen_trolley_inspections_r3055 i
  where i.defect_severity in ('high','critical')
  order by i.swivel_freeplay_mm desc nulls last
  limit 10;
end; $$;
revoke all on function r3055_top_critical_units() from public, anon;
grant execute on function r3055_top_critical_units() to authenticated;

create or replace function r3055_vendor_spend()
returns table(vendor_name text, actions int, total_spend numeric, completed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.vendor_name,
         count(*)::int,
         sum(a.cost_rupees)::numeric,
         (count(*) filter (where a.outcome='completed'))::int
  from hospital_chain_caster_remediation_actions_r3055 a
  group by a.vendor_name
  order by sum(a.cost_rupees) desc;
end; $$;
revoke all on function r3055_vendor_spend() from public, anon;
grant execute on function r3055_vendor_spend() to authenticated;

create or replace function r3055_model_failure_rate()
returns table(trolley_model text, inspections int, fail_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.trolley_model,
         count(*)::int,
         round((count(*) filter (where i.compliance_status in ('major_nc','critical_fail')))::numeric * 100.0 / nullif(count(*),0), 1)
  from hospital_chain_linen_trolley_inspections_r3055 i
  group by i.trolley_model
  order by i.trolley_model;
end; $$;
revoke all on function r3055_model_failure_rate() from public, anon;
grant execute on function r3055_model_failure_rate() to authenticated;

create or replace function r3055_action_kind_breakdown()
returns table(action_kind text, total int, completed int, pending int, total_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.action_kind,
         count(*)::int,
         (count(*) filter (where a.outcome='completed'))::int,
         (count(*) filter (where a.outcome='pending'))::int,
         sum(a.cost_rupees)::numeric
  from hospital_chain_caster_remediation_actions_r3055 a
  group by a.action_kind
  order by a.action_kind;
end; $$;
revoke all on function r3055_action_kind_breakdown() from public, anon;
grant execute on function r3055_action_kind_breakdown() to authenticated;

create or replace function r3055_unsigned_inspections()
returns table(chain_name text, hospital_unit text, trolley_asset_tag text, inspection_quarter text, compliance_status text, inspected_on date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select i.chain_name, i.hospital_unit, i.trolley_asset_tag, i.inspection_quarter, i.compliance_status, i.inspected_on
  from hospital_chain_linen_trolley_inspections_r3055 i
  where i.signed_off = false
  order by i.inspected_on desc;
end; $$;
revoke all on function r3055_unsigned_inspections() from public, anon;
grant execute on function r3055_unsigned_inspections() to authenticated;
