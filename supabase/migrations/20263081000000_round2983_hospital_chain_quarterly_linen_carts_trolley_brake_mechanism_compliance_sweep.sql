-- Round r2983 — Hospital Chain Quarterly Linen-Carts-and-Trolley Brake-Mechanism Compliance Sweep
-- Batch 420 milestone · HEAVY ★★★★

create table if not exists hospital_chain_linen_trolley_inspections_r2983 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_branch text not null,
  trolley_asset_tag text not null,
  trolley_type text not null check (trolley_type in ('linen_clean','linen_soiled','meal_service','medication_cart','laundry_bulk')),
  quarter_label text not null,
  brake_mechanism_kind text not null check (brake_mechanism_kind in ('foot_pedal','swivel_lock','dual_directional','central_locking','manual_lever')),
  brake_status text not null check (brake_status in ('pass','marginal','fail','seized','missing')),
  load_test_kg numeric(6,2) not null check (load_test_kg between 0 and 500),
  defect_score int not null check (defect_score between 0 and 100),
  inspected_at timestamptz not null,
  next_due_at timestamptz not null,
  remediation_owner text not null,
  created_at timestamptz not null default now()
);

alter table hospital_chain_linen_trolley_inspections_r2983 enable row level security;

drop policy if exists hclti_r2983_sel on hospital_chain_linen_trolley_inspections_r2983;
create policy hclti_r2983_sel on hospital_chain_linen_trolley_inspections_r2983
  for select to authenticated using (is_founder());

insert into hospital_chain_linen_trolley_inspections_r2983
  (chain_name, hospital_branch, trolley_asset_tag, trolley_type, quarter_label, brake_mechanism_kind, brake_status, load_test_kg, defect_score, inspected_at, next_due_at, remediation_owner)
values
  ('Apollo','Hyderabad-Jubilee','TR-AP-JH-001','linen_clean','2026-Q2','foot_pedal','pass',180.00,5,'2026-05-12'::timestamptz,'2026-08-12'::timestamptz,'branch_facilities'),
  ('Apollo','Hyderabad-Jubilee','TR-AP-JH-002','linen_soiled','2026-Q2','swivel_lock','marginal',160.00,42,'2026-05-12'::timestamptz,'2026-06-26'::timestamptz,'branch_facilities'),
  ('Apollo','Chennai-Greams','TR-AP-CG-014','meal_service','2026-Q2','foot_pedal','fail',95.50,71,'2026-05-15'::timestamptz,'2026-06-05'::timestamptz,'chain_ops'),
  ('Apollo','Chennai-Greams','TR-AP-CG-022','medication_cart','2026-Q2','central_locking','pass',45.00,8,'2026-05-15'::timestamptz,'2026-08-15'::timestamptz,'pharmacy_lead'),
  ('Manipal','Bangalore-Old','TR-MN-BO-005','linen_clean','2026-Q2','dual_directional','seized',200.00,88,'2026-05-18'::timestamptz,'2026-05-28'::timestamptz,'chain_ops'),
  ('Manipal','Bangalore-Old','TR-MN-BO-009','laundry_bulk','2026-Q2','manual_lever','fail',310.00,77,'2026-05-18'::timestamptz,'2026-06-08'::timestamptz,'chain_ops'),
  ('Manipal','Bangalore-Yelahanka','TR-MN-BY-018','linen_soiled','2026-Q2','foot_pedal','marginal',155.00,38,'2026-05-20'::timestamptz,'2026-07-04'::timestamptz,'branch_facilities'),
  ('Fortis','Delhi-Vasant','TR-FT-DV-003','meal_service','2026-Q2','swivel_lock','pass',88.00,12,'2026-05-21'::timestamptz,'2026-08-21'::timestamptz,'branch_facilities'),
  ('Fortis','Delhi-Vasant','TR-FT-DV-011','linen_clean','2026-Q2','foot_pedal','missing',0.00,100,'2026-05-21'::timestamptz,'2026-05-25'::timestamptz,'chain_ops'),
  ('Fortis','Mumbai-Mulund','TR-FT-MM-007','medication_cart','2026-Q2','central_locking','pass',42.00,4,'2026-05-22'::timestamptz,'2026-08-22'::timestamptz,'pharmacy_lead'),
  ('Fortis','Mumbai-Mulund','TR-FT-MM-019','laundry_bulk','2026-Q2','dual_directional','fail',285.00,68,'2026-05-22'::timestamptz,'2026-06-12'::timestamptz,'chain_ops'),
  ('Max','Delhi-Saket','TR-MX-DS-004','linen_soiled','2026-Q2','foot_pedal','pass',170.00,9,'2026-05-23'::timestamptz,'2026-08-23'::timestamptz,'branch_facilities'),
  ('Max','Delhi-Saket','TR-MX-DS-012','meal_service','2026-Q2','swivel_lock','marginal',92.00,44,'2026-05-23'::timestamptz,'2026-07-07'::timestamptz,'branch_facilities'),
  ('Narayana','Bangalore-HSR','TR-NR-BH-006','linen_clean','2026-Q2','manual_lever','seized',175.00,82,'2026-05-25'::timestamptz,'2026-06-04'::timestamptz,'chain_ops'),
  ('Narayana','Bangalore-HSR','TR-NR-BH-013','medication_cart','2026-Q2','central_locking','pass',40.00,6,'2026-05-25'::timestamptz,'2026-08-25'::timestamptz,'pharmacy_lead'),
  ('Narayana','Kolkata-Mukundapur','TR-NR-KM-021','laundry_bulk','2026-Q2','dual_directional','marginal',295.00,49,'2026-05-26'::timestamptz,'2026-07-10'::timestamptz,'chain_ops'),
  ('Medanta','Gurgaon-Sector38','TR-MD-GS-008','linen_clean','2026-Q2','foot_pedal','pass',185.00,11,'2026-05-27'::timestamptz,'2026-08-27'::timestamptz,'branch_facilities'),
  ('Medanta','Gurgaon-Sector38','TR-MD-GS-016','linen_soiled','2026-Q2','swivel_lock','fail',165.00,72,'2026-05-27'::timestamptz,'2026-06-17'::timestamptz,'chain_ops'),
  ('AIIMS','Delhi-Ansari','TR-AI-DA-010','meal_service','2026-Q2','foot_pedal','pass',90.00,14,'2026-05-28'::timestamptz,'2026-08-28'::timestamptz,'branch_facilities'),
  ('AIIMS','Delhi-Ansari','TR-AI-DA-020','medication_cart','2026-Q2','central_locking','marginal',44.00,39,'2026-05-28'::timestamptz,'2026-07-12'::timestamptz,'pharmacy_lead'),
  ('Kokilaben','Mumbai-Andheri','TR-KK-MA-015','laundry_bulk','2026-Q2','manual_lever','pass',300.00,17,'2026-05-30'::timestamptz,'2026-08-30'::timestamptz,'branch_facilities'),
  ('Kokilaben','Mumbai-Andheri','TR-KK-MA-024','linen_clean','2026-Q2','dual_directional','seized',180.00,91,'2026-05-30'::timestamptz,'2026-06-09'::timestamptz,'chain_ops');

create table if not exists hospital_chain_linen_trolley_remediations_r2983 (
  id uuid primary key default gen_random_uuid(),
  inspection_ref text not null,
  chain_name text not null,
  remediation_kind text not null check (remediation_kind in ('brake_pad_replace','caster_swap','full_cart_retire','lubrication','lock_recalibrate','wheel_bearing_swap')),
  vendor_name text not null,
  cost_rupees numeric(10,2) not null check (cost_rupees between 0 and 200000),
  sla_hours int not null check (sla_hours between 4 and 168),
  status text not null check (status in ('queued','dispatched','in_progress','closed','overdue','cancelled')),
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table hospital_chain_linen_trolley_remediations_r2983 enable row level security;

drop policy if exists hcltr_r2983_sel on hospital_chain_linen_trolley_remediations_r2983;
create policy hcltr_r2983_sel on hospital_chain_linen_trolley_remediations_r2983
  for select to authenticated using (is_founder());

insert into hospital_chain_linen_trolley_remediations_r2983
  (inspection_ref, chain_name, remediation_kind, vendor_name, cost_rupees, sla_hours, status, closed_at)
values
  ('TR-AP-JH-002','Apollo','lock_recalibrate','CasterPro India',1800.00,24,'closed','2026-05-13'::timestamptz),
  ('TR-AP-CG-014','Apollo','brake_pad_replace','CasterPro India',4200.00,48,'closed','2026-05-17'::timestamptz),
  ('TR-MN-BO-005','Manipal','full_cart_retire','EquipSeva Internal',26500.00,72,'in_progress',null),
  ('TR-MN-BO-009','Manipal','wheel_bearing_swap','SouthernCart Works',8800.00,48,'closed','2026-05-21'::timestamptz),
  ('TR-MN-BY-018','Manipal','lubrication','EquipSeva Internal',650.00,12,'closed','2026-05-21'::timestamptz),
  ('TR-FT-DV-011','Fortis','full_cart_retire','HospiCart Mumbai',28000.00,96,'dispatched',null),
  ('TR-FT-MM-019','Fortis','caster_swap','HospiCart Mumbai',12400.00,48,'overdue',null),
  ('TR-MX-DS-012','Max','lock_recalibrate','NorthCart Service',1500.00,24,'closed','2026-05-24'::timestamptz),
  ('TR-NR-BH-006','Narayana','full_cart_retire','SouthernCart Works',27800.00,96,'in_progress',null),
  ('TR-NR-KM-021','Narayana','brake_pad_replace','EasternCart',4900.00,48,'queued',null),
  ('TR-MD-GS-016','Medanta','wheel_bearing_swap','NorthCart Service',9100.00,48,'closed','2026-05-30'::timestamptz),
  ('TR-AI-DA-020','AIIMS','lock_recalibrate','EquipSeva Internal',1400.00,24,'closed','2026-05-29'::timestamptz),
  ('TR-KK-MA-024','Kokilaben','full_cart_retire','HospiCart Mumbai',29500.00,96,'overdue',null),
  ('TR-AP-CG-014','Apollo','caster_swap','CasterPro India',11200.00,48,'cancelled',null),
  ('TR-FT-MM-019','Fortis','brake_pad_replace','HospiCart Mumbai',5200.00,48,'closed','2026-05-26'::timestamptz),
  ('TR-MN-BO-009','Manipal','lubrication','EquipSeva Internal',700.00,12,'closed','2026-05-20'::timestamptz);

create or replace function r2983_summary_by_chain()
returns table(chain_name text, inspected int, pass_count int, fail_count int, seized_count int, avg_defect numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.chain_name,
         count(*)::int as inspected,
         (count(*) filter (where i.brake_status='pass'))::int as pass_count,
         (count(*) filter (where i.brake_status='fail'))::int as fail_count,
         (count(*) filter (where i.brake_status='seized'))::int as seized_count,
         round(avg(i.defect_score)::numeric,2) as avg_defect
  from hospital_chain_linen_trolley_inspections_r2983 i
  group by i.chain_name
  order by avg_defect desc;
end;$$;
revoke all on function r2983_summary_by_chain() from public, anon;
grant execute on function r2983_summary_by_chain() to authenticated;

create or replace function r2983_brake_kind_failure_rate()
returns table(brake_mechanism_kind text, total int, failing int, fail_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.brake_mechanism_kind,
         count(*)::int as total,
         (count(*) filter (where i.brake_status in ('fail','seized','missing')))::int as failing,
         round(100.0 * (count(*) filter (where i.brake_status in ('fail','seized','missing')))::numeric / nullif(count(*),0)::numeric, 2) as fail_pct
  from hospital_chain_linen_trolley_inspections_r2983 i
  group by i.brake_mechanism_kind
  order by fail_pct desc nulls last;
end;$$;
revoke all on function r2983_brake_kind_failure_rate() from public, anon;
grant execute on function r2983_brake_kind_failure_rate() to authenticated;

create or replace function r2983_overdue_remediations()
returns table(inspection_ref text, chain_name text, remediation_kind text, vendor_name text, sla_hours int, cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.inspection_ref, r.chain_name, r.remediation_kind, r.vendor_name, r.sla_hours, r.cost_rupees
  from hospital_chain_linen_trolley_remediations_r2983 r
  where r.status = 'overdue'
  order by r.cost_rupees desc;
end;$$;
revoke all on function r2983_overdue_remediations() from public, anon;
grant execute on function r2983_overdue_remediations() to authenticated;

create or replace function r2983_branch_hotlist()
returns table(chain_name text, hospital_branch text, fail_or_seized int, avg_defect numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.chain_name, i.hospital_branch,
         (count(*) filter (where i.brake_status in ('fail','seized','missing')))::int as fail_or_seized,
         round(avg(i.defect_score)::numeric,2) as avg_defect
  from hospital_chain_linen_trolley_inspections_r2983 i
  group by i.chain_name, i.hospital_branch
  having (count(*) filter (where i.brake_status in ('fail','seized','missing'))) > 0
  order by fail_or_seized desc, avg_defect desc;
end;$$;
revoke all on function r2983_branch_hotlist() from public, anon;
grant execute on function r2983_branch_hotlist() to authenticated;

create or replace function r2983_vendor_spend()
returns table(vendor_name text, jobs int, total_spend numeric, closed_jobs int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.vendor_name,
         count(*)::int as jobs,
         sum(r.cost_rupees)::numeric as total_spend,
         (count(*) filter (where r.status='closed'))::int as closed_jobs
  from hospital_chain_linen_trolley_remediations_r2983 r
  group by r.vendor_name
  order by total_spend desc;
end;$$;
revoke all on function r2983_vendor_spend() from public, anon;
grant execute on function r2983_vendor_spend() to authenticated;

create or replace function r2983_trolley_type_defects()
returns table(trolley_type text, inspected int, avg_defect numeric, avg_load_kg numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.trolley_type,
         count(*)::int as inspected,
         round(avg(i.defect_score)::numeric,2) as avg_defect,
         round(avg(i.load_test_kg)::numeric,2) as avg_load_kg
  from hospital_chain_linen_trolley_inspections_r2983 i
  group by i.trolley_type
  order by avg_defect desc;
end;$$;
revoke all on function r2983_trolley_type_defects() from public, anon;
grant execute on function r2983_trolley_type_defects() to authenticated;

create or replace function r2983_due_within_14d()
returns table(chain_name text, hospital_branch text, trolley_asset_tag text, next_due_at timestamptz, brake_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.chain_name, i.hospital_branch, i.trolley_asset_tag, i.next_due_at, i.brake_status
  from hospital_chain_linen_trolley_inspections_r2983 i
  where i.next_due_at <= (now() + interval '14 days')
  order by i.next_due_at asc;
end;$$;
revoke all on function r2983_due_within_14d() from public, anon;
grant execute on function r2983_due_within_14d() to authenticated;
