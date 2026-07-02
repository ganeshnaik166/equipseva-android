-- Round r3068: Customer Monthly Engineer Hospital Specimen-Bag Heat-Seal Pouch Integrity Audit
-- Two tables (_r3068) + 7 SECDEF RPCs is_founder() gated.

create table if not exists specimen_bag_heat_seal_audits_r3068 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_date date not null,
  hospital_org_id uuid,
  hospital_name text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  pouch_lot_code text not null,
  pouches_inspected int not null check (pouches_inspected between 1 and 5000),
  pouches_failed int not null check (pouches_failed between 0 and 5000),
  seal_temperature_c numeric(5,2) not null check (seal_temperature_c between 100 and 250),
  seal_pressure_kpa numeric(6,2) not null check (seal_pressure_kpa between 50 and 600),
  burst_pressure_kpa numeric(6,2) not null check (burst_pressure_kpa between 10 and 400),
  integrity_grade text not null check (integrity_grade in ('a_pristine','b_acceptable','c_marginal','d_fail')),
  failure_mode text check (failure_mode in ('channel_leak','wrinkle','incomplete_seal','contamination','tear','none')),
  region text not null check (region in ('north','south','east','west','central')),
  status text not null check (status in ('scheduled','in_progress','passed','failed','remediation','closed')),
  remediation_required boolean not null default false,
  notes text
);

create table if not exists specimen_bag_remediation_actions_r3068 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references specimen_bag_heat_seal_audits_r3068(id) on delete cascade,
  hospital_name text not null,
  action_type text not null check (action_type in ('recalibrate_sealer','replace_pouch_lot','retrain_staff','vendor_escalation','quarantine_batch','reaudit')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  assigned_to text not null,
  due_date date not null,
  completed_at timestamptz,
  status text not null check (status in ('open','in_progress','blocked','completed','verified','cancelled')),
  cost_rupees int not null check (cost_rupees between 0 and 5000000),
  outcome_notes text
);

alter table specimen_bag_heat_seal_audits_r3068 enable row level security;
alter table specimen_bag_remediation_actions_r3068 enable row level security;

drop policy if exists sba_r3068_founder_all on specimen_bag_heat_seal_audits_r3068;
create policy sba_r3068_founder_all on specimen_bag_heat_seal_audits_r3068
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists sbr_r3068_founder_all on specimen_bag_remediation_actions_r3068;
create policy sbr_r3068_founder_all on specimen_bag_remediation_actions_r3068
  for all to authenticated using (is_founder()) with check (is_founder());

revoke all on specimen_bag_heat_seal_audits_r3068 from public, anon;
revoke all on specimen_bag_remediation_actions_r3068 from public, anon;
grant select, insert, update, delete on specimen_bag_heat_seal_audits_r3068 to authenticated;
grant select, insert, update, delete on specimen_bag_remediation_actions_r3068 to authenticated;

-- Seed audits (18 rows)
insert into specimen_bag_heat_seal_audits_r3068
  (audit_date, hospital_name, engineer_name, pouch_lot_code, pouches_inspected, pouches_failed,
   seal_temperature_c, seal_pressure_kpa, burst_pressure_kpa, integrity_grade, failure_mode, region, status, remediation_required, notes)
values
  ('2026-06-01'::date,'Apollo Hyderabad','Ravi K.','LOT-A101',200,1,180.50,310.00,265.00,'a_pristine','none','south','passed',false,'All seals nominal'),
  ('2026-06-02'::date,'Fortis Mumbai','Sneha P.','LOT-A102',180,4,178.20,305.50,240.00,'b_acceptable','wrinkle','west','passed',false,'Minor wrinkle on 4 pouches'),
  ('2026-06-03'::date,'AIIMS Delhi','Arjun M.','LOT-A103',250,18,165.00,280.00,140.00,'c_marginal','channel_leak','north','failed',true,'Channel leak detected, escalate'),
  ('2026-06-04'::date,'Manipal Bangalore','Priya R.','LOT-A104',220,2,182.00,315.00,270.00,'a_pristine','none','south','passed',false,null),
  ('2026-06-05'::date,'KIMS Hyderabad','Vikram S.','LOT-A105',150,25,158.30,260.00,95.00,'d_fail','incomplete_seal','south','failed',true,'Sealer recalibration urgent'),
  ('2026-06-06'::date,'Max Saket','Neha J.','LOT-A106',300,6,179.00,308.00,255.00,'b_acceptable','wrinkle','north','passed',false,'Within tolerance'),
  ('2026-06-07'::date,'Narayana Health','Sunil G.','LOT-A107',210,3,181.50,312.00,261.00,'a_pristine','none','south','passed',false,null),
  ('2026-06-08'::date,'Medanta Gurgaon','Asha T.','LOT-A108',190,12,170.00,290.00,180.00,'c_marginal','contamination','north','remediation',true,'Lot contaminated, quarantine'),
  ('2026-06-09'::date,'Tata Memorial','Rohit B.','LOT-A109',240,0,183.00,316.00,272.00,'a_pristine','none','west','passed',false,'Best lot this month'),
  ('2026-06-10'::date,'Christian Medical','Divya N.','LOT-A110',170,2,180.00,309.00,258.00,'a_pristine','none','south','passed',false,null),
  ('2026-06-11'::date,'Sankara Nethralaya','Karthik V.','LOT-A111',130,8,176.00,300.00,220.00,'b_acceptable','wrinkle','south','passed',false,'Acceptable variance'),
  ('2026-06-12'::date,'PGI Chandigarh','Manish D.','LOT-A112',200,30,160.00,265.00,80.00,'d_fail','tear','north','failed',true,'Pouch material defect'),
  ('2026-06-13'::date,'Ruby Hall','Anand K.','LOT-A113',220,5,178.50,306.00,250.00,'b_acceptable','wrinkle','west','passed',false,null),
  ('2026-06-14'::date,'BLK Super','Pooja S.','LOT-A114',260,1,182.50,314.00,268.00,'a_pristine','none','north','passed',false,'Excellent batch'),
  ('2026-06-15'::date,'Lilavati Mumbai','Vinod L.','LOT-A115',180,14,168.00,285.00,160.00,'c_marginal','channel_leak','west','remediation',true,'Channel leak on 14 pouches'),
  ('2026-06-16'::date,'Yashoda Hyd','Geeta R.','LOT-A116',240,3,181.00,311.00,263.00,'a_pristine','none','south','closed',false,null),
  ('2026-06-17'::date,'CARE Hospitals','Suresh M.','LOT-A117',195,22,162.00,272.00,110.00,'d_fail','incomplete_seal','south','failed',true,'Replace sealer head'),
  ('2026-06-18'::date,'Hinduja Mumbai','Reshma A.','LOT-A118',210,2,180.00,310.00,259.00,'a_pristine','none','west','in_progress',false,'Audit ongoing');

-- Seed remediations (16 rows) — link to a subset via audit_id from above
insert into specimen_bag_remediation_actions_r3068
  (audit_id, hospital_name, action_type, priority, assigned_to, due_date, completed_at, status, cost_rupees, outcome_notes)
values
  (null,'AIIMS Delhi','recalibrate_sealer','p0','Arjun M.','2026-06-05'::date,'2026-06-05 14:00:00+05:30'::timestamptz,'completed',12000,'Sealer recalibrated to 180C'),
  (null,'KIMS Hyderabad','replace_pouch_lot','p0','Vikram S.','2026-06-06'::date,'2026-06-06 10:00:00+05:30'::timestamptz,'verified',85000,'Lot A105 quarantined'),
  (null,'Medanta Gurgaon','quarantine_batch','p1','Asha T.','2026-06-10'::date,null::timestamptz,'in_progress',15000,'Quarantine in progress'),
  (null,'PGI Chandigarh','vendor_escalation','p0','Manish D.','2026-06-13'::date,null::timestamptz,'open',0,'Awaiting vendor response'),
  (null,'Lilavati Mumbai','reaudit','p1','Vinod L.','2026-06-17'::date,null::timestamptz,'open',5000,'Reaudit scheduled'),
  (null,'CARE Hospitals','recalibrate_sealer','p0','Suresh M.','2026-06-19'::date,null::timestamptz,'blocked',18000,'Parts on order'),
  (null,'Fortis Mumbai','retrain_staff','p2','Sneha P.','2026-06-20'::date,'2026-06-09 11:30:00+05:30'::timestamptz,'completed',8000,'3 staff retrained'),
  (null,'Max Saket','retrain_staff','p3','Neha J.','2026-06-25'::date,null::timestamptz,'open',6000,'Pending scheduling'),
  (null,'Sankara Nethralaya','reaudit','p2','Karthik V.','2026-06-22'::date,null::timestamptz,'open',5000,null),
  (null,'AIIMS Delhi','retrain_staff','p1','Arjun M.','2026-06-12'::date,'2026-06-11 16:00:00+05:30'::timestamptz,'verified',9500,'Full team retrained'),
  (null,'Ruby Hall','reaudit','p3','Anand K.','2026-06-28'::date,null::timestamptz,'open',5000,null),
  (null,'KIMS Hyderabad','retrain_staff','p1','Vikram S.','2026-06-15'::date,'2026-06-14 09:00:00+05:30'::timestamptz,'completed',7500,'Staff sign-off received'),
  (null,'Manipal Bangalore','reaudit','p3','Priya R.','2026-07-05'::date,null::timestamptz,'open',5000,'Routine'),
  (null,'PGI Chandigarh','quarantine_batch','p0','Manish D.','2026-06-14'::date,'2026-06-13 18:00:00+05:30'::timestamptz,'completed',22000,'250 pouches quarantined'),
  (null,'Hinduja Mumbai','reaudit','p2','Reshma A.','2026-06-26'::date,null::timestamptz,'in_progress',5500,null),
  (null,'CARE Hospitals','vendor_escalation','p1','Suresh M.','2026-06-23'::date,null::timestamptz,'in_progress',0,'Escalated to vendor QA');

-- RPC 1: summary KPIs
create or replace function founder_r3068_summary()
returns table (
  total_audits int,
  total_pouches_inspected int,
  total_pouches_failed int,
  failure_rate_pct numeric,
  audits_failed int,
  remediations_required int,
  open_remediations int,
  total_remediation_cost int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select
    (select count(*) from specimen_bag_heat_seal_audits_r3068)::int,
    coalesce((select sum(pouches_inspected) from specimen_bag_heat_seal_audits_r3068),0)::int,
    coalesce((select sum(pouches_failed) from specimen_bag_heat_seal_audits_r3068),0)::int,
    case when coalesce((select sum(pouches_inspected) from specimen_bag_heat_seal_audits_r3068),0)=0 then 0
         else round(100.0 * (select sum(pouches_failed) from specimen_bag_heat_seal_audits_r3068)::numeric
                         / (select sum(pouches_inspected) from specimen_bag_heat_seal_audits_r3068)::numeric, 2)
    end,
    (select count(*) filter (where status='failed') from specimen_bag_heat_seal_audits_r3068)::int,
    (select count(*) filter (where remediation_required) from specimen_bag_heat_seal_audits_r3068)::int,
    (select count(*) filter (where status in ('open','in_progress','blocked')) from specimen_bag_remediation_actions_r3068)::int,
    coalesce((select sum(cost_rupees) from specimen_bag_remediation_actions_r3068),0)::int;
end;
$$;

-- RPC 2: by region
create or replace function founder_r3068_by_region()
returns table (region text, audits int, pouches_inspected int, pouches_failed int, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.region,
         count(*)::int,
         sum(a.pouches_inspected)::int,
         sum(a.pouches_failed)::int,
         round(100.0 * sum(a.pouches_failed)::numeric / nullif(sum(a.pouches_inspected),0)::numeric, 2)
  from specimen_bag_heat_seal_audits_r3068 a
  group by a.region
  order by sum(a.pouches_failed) desc nulls last;
end;
$$;

-- RPC 3: by integrity grade
create or replace function founder_r3068_by_grade()
returns table (integrity_grade text, audits int, pouches_failed int, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  select count(*) into total from specimen_bag_heat_seal_audits_r3068;
  return query
  select a.integrity_grade,
         count(*)::int,
         sum(a.pouches_failed)::int,
         case when total=0 then 0 else round(100.0 * count(*)::numeric / total::numeric, 2) end
  from specimen_bag_heat_seal_audits_r3068 a
  group by a.integrity_grade
  order by a.integrity_grade;
end;
$$;

-- RPC 4: failure-mode breakdown
create or replace function founder_r3068_failure_modes()
returns table (failure_mode text, occurrences int, pouches_failed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select coalesce(a.failure_mode,'unspecified'),
         count(*)::int,
         sum(a.pouches_failed)::int
  from specimen_bag_heat_seal_audits_r3068 a
  group by a.failure_mode
  order by count(*) desc;
end;
$$;

-- RPC 5: top hospitals by failures
create or replace function founder_r3068_top_hospitals()
returns table (hospital_name text, audits int, pouches_failed int, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.hospital_name,
         count(*)::int,
         sum(a.pouches_failed)::int,
         round(100.0 * sum(a.pouches_failed)::numeric / nullif(sum(a.pouches_inspected),0)::numeric, 2)
  from specimen_bag_heat_seal_audits_r3068 a
  group by a.hospital_name
  order by sum(a.pouches_failed) desc nulls last
  limit 10;
end;
$$;

-- RPC 6: engineer leaderboard
create or replace function founder_r3068_engineer_leaderboard()
returns table (engineer_name text, audits int, pouches_inspected int, pristine_audits int, fail_audits int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.engineer_name,
         count(*)::int,
         sum(a.pouches_inspected)::int,
         (count(*) filter (where a.integrity_grade='a_pristine'))::int,
         (count(*) filter (where a.status='failed'))::int
  from specimen_bag_heat_seal_audits_r3068 a
  group by a.engineer_name
  order by (count(*) filter (where a.integrity_grade='a_pristine')) desc, count(*) desc;
end;
$$;

-- RPC 7: open remediations
create or replace function founder_r3068_open_remediations()
returns table (id uuid, hospital_name text, action_type text, priority text, assigned_to text, due_date date, status text, cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select r.id, r.hospital_name, r.action_type, r.priority, r.assigned_to, r.due_date, r.status, r.cost_rupees
  from specimen_bag_remediation_actions_r3068 r
  where r.status in ('open','in_progress','blocked')
  order by case r.priority when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end, r.due_date;
end;
$$;

-- RPC 8: recent audits feed
create or replace function founder_r3068_recent_audits()
returns table (id uuid, audit_date date, hospital_name text, engineer_name text, pouch_lot_code text,
               pouches_inspected int, pouches_failed int, integrity_grade text, status text, region text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
  select a.id, a.audit_date, a.hospital_name, a.engineer_name, a.pouch_lot_code,
         a.pouches_inspected, a.pouches_failed, a.integrity_grade, a.status, a.region
  from specimen_bag_heat_seal_audits_r3068 a
  order by a.audit_date desc, a.created_at desc
  limit 25;
end;
$$;

revoke all on function founder_r3068_summary() from public, anon;
revoke all on function founder_r3068_by_region() from public, anon;
revoke all on function founder_r3068_by_grade() from public, anon;
revoke all on function founder_r3068_failure_modes() from public, anon;
revoke all on function founder_r3068_top_hospitals() from public, anon;
revoke all on function founder_r3068_engineer_leaderboard() from public, anon;
revoke all on function founder_r3068_open_remediations() from public, anon;
revoke all on function founder_r3068_recent_audits() from public, anon;

grant execute on function founder_r3068_summary() to authenticated;
grant execute on function founder_r3068_by_region() to authenticated;
grant execute on function founder_r3068_by_grade() to authenticated;
grant execute on function founder_r3068_failure_modes() to authenticated;
grant execute on function founder_r3068_top_hospitals() to authenticated;
grant execute on function founder_r3068_engineer_leaderboard() to authenticated;
grant execute on function founder_r3068_open_remediations() to authenticated;
grant execute on function founder_r3068_recent_audits() to authenticated;
