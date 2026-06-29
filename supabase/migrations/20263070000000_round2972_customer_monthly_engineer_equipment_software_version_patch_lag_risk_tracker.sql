-- Round 2972: Customer Monthly Engineer Equipment-Software Version Patch-Lag Risk Tracker
-- HEAVY ★★★★

create table if not exists customer_engineer_patch_lag_snapshots_r2972 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  snapshot_month date not null,
  hospital_org_id uuid,
  hospital_name text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  equipment_id uuid,
  equipment_label text not null,
  equipment_category text not null check (equipment_category in ('imaging','life_support','diagnostic','surgical','monitoring','lab','dental')),
  installed_firmware_version text not null,
  latest_firmware_version text not null,
  patch_lag_days int not null,
  patches_behind int not null,
  criticality text not null check (criticality in ('low','medium','high','critical')),
  risk_score numeric(5,2) not null,
  risk_band text not null check (risk_band in ('green','amber','red','black')),
  last_patched_at timestamptz,
  next_scheduled_patch_at timestamptz,
  status text not null check (status in ('on_track','watch','overdue','breach','resolved')),
  cve_count int not null default 0,
  notes text
);

alter table customer_engineer_patch_lag_snapshots_r2972 enable row level security;

drop policy if exists pl_select_r2972 on customer_engineer_patch_lag_snapshots_r2972;
create policy pl_select_r2972 on customer_engineer_patch_lag_snapshots_r2972 for select to authenticated using (is_founder());

create table if not exists customer_engineer_patch_lag_actions_r2972 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  snapshot_id uuid references customer_engineer_patch_lag_snapshots_r2972(id) on delete cascade,
  action_month date not null,
  action_type text not null check (action_type in ('remote_patch','onsite_patch','rollback','escalation','vendor_ticket','training','audit')),
  action_status text not null check (action_status in ('queued','in_progress','blocked','completed','cancelled')),
  owner_user_id uuid,
  owner_name text not null,
  sla_hours int not null,
  hours_elapsed int not null,
  sla_breached boolean not null default false,
  resolution_summary text,
  resolved_at timestamptz
);

alter table customer_engineer_patch_lag_actions_r2972 enable row level security;

drop policy if exists pa_select_r2972 on customer_engineer_patch_lag_actions_r2972;
create policy pa_select_r2972 on customer_engineer_patch_lag_actions_r2972 for select to authenticated using (is_founder());

-- Seeds: snapshots (20 rows)
insert into customer_engineer_patch_lag_snapshots_r2972 (snapshot_month, hospital_name, engineer_name, equipment_label, equipment_category, installed_firmware_version, latest_firmware_version, patch_lag_days, patches_behind, criticality, risk_score, risk_band, last_patched_at, next_scheduled_patch_at, status, cve_count, notes) values
('2026-06-01'::date,'Apollo Jubilee','Ravi Kumar','MRI Magnetom 3T','imaging','7.2.1','7.4.0',45,3,'high',78.50,'red','2026-04-17'::timestamptz,'2026-07-05'::timestamptz,'overdue',4,'vendor patch held for QA'),
('2026-06-01'::date,'Yashoda Secunderabad','Priya Sharma','Ventilator V60','life_support','3.1.0','3.1.2',12,2,'critical',88.20,'red','2026-05-19'::timestamptz,'2026-07-01'::timestamptz,'watch',2,'CVE-2026-1188 mitigated'),
('2026-06-01'::date,'KIMS Kondapur','Arun Reddy','CT Aquilion 64','imaging','5.0.4','5.1.0',92,4,'high',91.40,'black','2026-03-01'::timestamptz,null,'breach',7,'patch blocked by OEM'),
('2026-06-01'::date,'Care Banjara','Meena Iyer','Defibrillator LP15','life_support','2.4.0','2.4.1',8,1,'critical',62.10,'amber','2026-05-23'::timestamptz,'2026-07-10'::timestamptz,'on_track',1,null),
('2026-06-01'::date,'Continental Gachibowli','Sunil Patil','Anesthesia Aestiva','surgical','4.5.2','4.5.2',0,0,'high',12.00,'green','2026-06-02'::timestamptz,'2026-09-02'::timestamptz,'on_track',0,'fully patched'),
('2026-06-01'::date,'Sunshine Paradise','Kavita Joshi','Ultrasound Voluson','imaging','6.1.0','6.2.3',60,2,'medium',55.75,'amber','2026-04-01'::timestamptz,'2026-07-15'::timestamptz,'watch',2,null),
('2026-06-01'::date,'Star Hospital Banjara','Rajesh Nair','Patient Monitor IntelliVue','monitoring','9.3.0','9.4.1',25,1,'medium',41.20,'amber','2026-05-05'::timestamptz,'2026-07-08'::timestamptz,'on_track',1,null),
('2026-06-01'::date,'Continental Gachibowli','Sunil Patil','Lab Analyzer Cobas','lab','11.0.0','11.0.0',0,0,'low',5.50,'green','2026-06-10'::timestamptz,'2026-09-10'::timestamptz,'on_track',0,null),
('2026-06-01'::date,'Apollo Jubilee','Ravi Kumar','Dental Chair Pelton','dental','1.2.0','1.3.0',150,3,'low',38.00,'amber','2026-01-15'::timestamptz,'2026-07-20'::timestamptz,'overdue',0,'low-criticality deferral'),
('2026-06-01'::date,'KIMS Kondapur','Arun Reddy','Infusion Pump Plum360','life_support','5.5.1','5.5.3',18,2,'critical',82.30,'red','2026-05-12'::timestamptz,'2026-07-02'::timestamptz,'watch',3,'CVE-2026-2204'),
('2026-05-01'::date,'Yashoda Secunderabad','Priya Sharma','Ventilator V60','life_support','3.0.9','3.1.2',40,3,'critical',86.40,'red','2026-04-01'::timestamptz,'2026-06-01'::timestamptz,'resolved',2,'patched in June'),
('2026-05-01'::date,'Star Hospital Banjara','Rajesh Nair','ECG MAC 2000','diagnostic','2.1.1','2.1.1',0,0,'medium',9.80,'green','2026-05-05'::timestamptz,'2026-08-05'::timestamptz,'on_track',0,null),
('2026-05-01'::date,'Care Banjara','Meena Iyer','X-Ray DR-F','imaging','7.0.0','7.0.4',75,4,'high',74.10,'red','2026-02-20'::timestamptz,'2026-06-15'::timestamptz,'overdue',2,null),
('2026-04-01'::date,'Apollo Jubilee','Ravi Kumar','MRI Magnetom 3T','imaging','7.1.0','7.4.0',105,5,'high',95.00,'black','2026-01-15'::timestamptz,null,'breach',6,'rollback in progress'),
('2026-04-01'::date,'Continental Gachibowli','Sunil Patil','Anesthesia Aestiva','surgical','4.5.0','4.5.2',30,2,'high',48.20,'amber','2026-03-04'::timestamptz,'2026-05-02'::timestamptz,'resolved',1,null),
('2026-04-01'::date,'KIMS Kondapur','Arun Reddy','CT Aquilion 64','imaging','5.0.0','5.1.0',180,5,'high',97.20,'black','2025-12-01'::timestamptz,null,'breach',9,null),
('2026-03-01'::date,'Sunshine Paradise','Kavita Joshi','Ultrasound Voluson','imaging','6.0.0','6.2.3',120,3,'medium',68.00,'red','2025-11-01'::timestamptz,'2026-05-15'::timestamptz,'resolved',2,null),
('2026-03-01'::date,'Star Hospital Banjara','Rajesh Nair','Patient Monitor IntelliVue','monitoring','9.2.0','9.4.1',60,2,'medium',50.40,'amber','2026-01-02'::timestamptz,'2026-04-08'::timestamptz,'resolved',1,null),
('2026-06-01'::date,'Yashoda Secunderabad','Priya Sharma','Lab Analyzer Cobas','lab','10.9.0','11.0.0',20,1,'low',22.10,'green','2026-05-11'::timestamptz,'2026-08-11'::timestamptz,'on_track',0,null),
('2026-06-01'::date,'Care Banjara','Meena Iyer','Dental Chair Pelton','dental','1.2.0','1.3.0',150,3,'low',36.50,'amber','2026-01-15'::timestamptz,'2026-07-20'::timestamptz,'overdue',0,null);

-- Seeds: actions (18 rows)
insert into customer_engineer_patch_lag_actions_r2972 (snapshot_id, action_month, action_type, action_status, owner_name, sla_hours, hours_elapsed, sla_breached, resolution_summary, resolved_at) values
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Apollo Jubilee' and equipment_label='MRI Magnetom 3T' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'vendor_ticket','in_progress','Ravi Kumar',72,96,true,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Yashoda Secunderabad' and equipment_label='Ventilator V60' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'remote_patch','queued','Priya Sharma',24,4,false,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='KIMS Kondapur' and equipment_label='CT Aquilion 64' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'escalation','blocked','Arun Reddy',48,140,true,'awaiting OEM ack',null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Care Banjara' and equipment_label='Defibrillator LP15' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'onsite_patch','completed','Meena Iyer',24,18,false,'patched onsite','2026-06-04'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Continental Gachibowli' and equipment_label='Anesthesia Aestiva' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'audit','completed','Sunil Patil',8,6,false,'audit pass','2026-06-02'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Sunshine Paradise' and equipment_label='Ultrasound Voluson' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'remote_patch','in_progress','Kavita Joshi',24,12,false,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Star Hospital Banjara' and equipment_label='Patient Monitor IntelliVue' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'training','queued','Rajesh Nair',48,2,false,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Apollo Jubilee' and equipment_label='Dental Chair Pelton' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'onsite_patch','queued','Ravi Kumar',72,1,false,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='KIMS Kondapur' and equipment_label='Infusion Pump Plum360' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'remote_patch','in_progress','Arun Reddy',24,22,false,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Yashoda Secunderabad' and equipment_label='Ventilator V60' and snapshot_month='2026-05-01'::date),'2026-05-01'::date,'onsite_patch','completed','Priya Sharma',24,20,false,'firmware 3.1.2 applied','2026-05-29'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Star Hospital Banjara' and equipment_label='ECG MAC 2000' and snapshot_month='2026-05-01'::date),'2026-05-01'::date,'audit','completed','Rajesh Nair',8,5,false,'audit pass','2026-05-06'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Care Banjara' and equipment_label='X-Ray DR-F' and snapshot_month='2026-05-01'::date),'2026-05-01'::date,'vendor_ticket','in_progress','Meena Iyer',72,180,true,null,null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Apollo Jubilee' and equipment_label='MRI Magnetom 3T' and snapshot_month='2026-04-01'::date),'2026-04-01'::date,'rollback','completed','Ravi Kumar',48,40,false,'rolled back to 7.1.0','2026-04-15'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Continental Gachibowli' and equipment_label='Anesthesia Aestiva' and snapshot_month='2026-04-01'::date),'2026-04-01'::date,'remote_patch','completed','Sunil Patil',24,12,false,'patched','2026-04-20'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='KIMS Kondapur' and equipment_label='CT Aquilion 64' and snapshot_month='2026-04-01'::date),'2026-04-01'::date,'escalation','blocked','Arun Reddy',48,720,true,'OEM dispute',null),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Sunshine Paradise' and equipment_label='Ultrasound Voluson' and snapshot_month='2026-03-01'::date),'2026-03-01'::date,'onsite_patch','completed','Kavita Joshi',48,44,false,'patched','2026-05-14'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Star Hospital Banjara' and equipment_label='Patient Monitor IntelliVue' and snapshot_month='2026-03-01'::date),'2026-03-01'::date,'remote_patch','completed','Rajesh Nair',24,18,false,'patched','2026-04-07'::timestamptz),
((select id from customer_engineer_patch_lag_snapshots_r2972 where hospital_name='Yashoda Secunderabad' and equipment_label='Lab Analyzer Cobas' and snapshot_month='2026-06-01'::date),'2026-06-01'::date,'training','queued','Priya Sharma',24,3,false,null,null);

-- RPC 1: monthly risk band rollup
create or replace function rpc_r2972_monthly_risk_rollup()
returns table(snapshot_month date, snapshots int, green_count int, amber_count int, red_count int, black_count int, avg_risk numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.snapshot_month,
    count(*)::int as snapshots,
    (count(*) filter (where s.risk_band='green'))::int,
    (count(*) filter (where s.risk_band='amber'))::int,
    (count(*) filter (where s.risk_band='red'))::int,
    (count(*) filter (where s.risk_band='black'))::int,
    round(avg(s.risk_score),2) as avg_risk
  from customer_engineer_patch_lag_snapshots_r2972 s
  group by s.snapshot_month
  order by s.snapshot_month desc;
end;$$;

-- RPC 2: top lag offenders current month
create or replace function rpc_r2972_top_lag_offenders()
returns table(hospital_name text, equipment_label text, engineer_name text, patch_lag_days int, risk_score numeric, risk_band text, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name, s.equipment_label, s.engineer_name, s.patch_lag_days, s.risk_score, s.risk_band, s.status
  from customer_engineer_patch_lag_snapshots_r2972 s
  where s.snapshot_month = '2026-06-01'::date
  order by s.risk_score desc
  limit 10;
end;$$;

-- RPC 3: per-hospital risk profile
create or replace function rpc_r2972_per_hospital_profile()
returns table(hospital_name text, devices int, avg_lag_days numeric, max_lag_days int, critical_count int, avg_risk numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name,
    count(*)::int,
    round(avg(s.patch_lag_days),1),
    max(s.patch_lag_days),
    (count(*) filter (where s.criticality='critical'))::int,
    round(avg(s.risk_score),2)
  from customer_engineer_patch_lag_snapshots_r2972 s
  where s.snapshot_month = '2026-06-01'::date
  group by s.hospital_name
  order by avg(s.risk_score) desc;
end;$$;

-- RPC 4: per-engineer scorecard
create or replace function rpc_r2972_per_engineer_scorecard()
returns table(engineer_name text, devices int, overdue_count int, breach_count int, avg_risk numeric, total_cves int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.engineer_name,
    count(*)::int,
    (count(*) filter (where s.status='overdue'))::int,
    (count(*) filter (where s.status='breach'))::int,
    round(avg(s.risk_score),2),
    sum(s.cve_count)::int
  from customer_engineer_patch_lag_snapshots_r2972 s
  where s.snapshot_month = '2026-06-01'::date
  group by s.engineer_name
  order by avg(s.risk_score) desc;
end;$$;

-- RPC 5: category-level lag
create or replace function rpc_r2972_category_lag()
returns table(equipment_category text, devices int, avg_lag numeric, max_patches_behind int, avg_risk numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.equipment_category,
    count(*)::int,
    round(avg(s.patch_lag_days),1),
    max(s.patches_behind),
    round(avg(s.risk_score),2)
  from customer_engineer_patch_lag_snapshots_r2972 s
  where s.snapshot_month = '2026-06-01'::date
  group by s.equipment_category
  order by avg(s.risk_score) desc;
end;$$;

-- RPC 6: SLA breach actions
create or replace function rpc_r2972_action_sla_breach()
returns table(action_month date, action_type text, owner_name text, sla_hours int, hours_elapsed int, action_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_month, a.action_type, a.owner_name, a.sla_hours, a.hours_elapsed, a.action_status
  from customer_engineer_patch_lag_actions_r2972 a
  where a.sla_breached = true
  order by a.hours_elapsed desc;
end;$$;

-- RPC 7: action mix by status
create or replace function rpc_r2972_action_mix()
returns table(action_type text, queued_count int, in_progress_count int, blocked_count int, completed_count int, cancelled_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.action_type,
    (count(*) filter (where a.action_status='queued'))::int,
    (count(*) filter (where a.action_status='in_progress'))::int,
    (count(*) filter (where a.action_status='blocked'))::int,
    (count(*) filter (where a.action_status='completed'))::int,
    (count(*) filter (where a.action_status='cancelled'))::int
  from customer_engineer_patch_lag_actions_r2972 a
  group by a.action_type
  order by a.action_type;
end;$$;

-- RPC 8: CVE exposure rollup
create or replace function rpc_r2972_cve_exposure()
returns table(hospital_name text, total_cves int, critical_devices int, black_band int, red_band int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.hospital_name,
    sum(s.cve_count)::int,
    (count(*) filter (where s.criticality='critical'))::int,
    (count(*) filter (where s.risk_band='black'))::int,
    (count(*) filter (where s.risk_band='red'))::int
  from customer_engineer_patch_lag_snapshots_r2972 s
  where s.snapshot_month = '2026-06-01'::date
  group by s.hospital_name
  order by sum(s.cve_count) desc;
end;$$;

revoke all on customer_engineer_patch_lag_snapshots_r2972 from public, anon;
revoke all on customer_engineer_patch_lag_actions_r2972 from public, anon;
grant select on customer_engineer_patch_lag_snapshots_r2972 to authenticated;
grant select on customer_engineer_patch_lag_actions_r2972 to authenticated;

revoke all on function rpc_r2972_monthly_risk_rollup() from public, anon;
revoke all on function rpc_r2972_top_lag_offenders() from public, anon;
revoke all on function rpc_r2972_per_hospital_profile() from public, anon;
revoke all on function rpc_r2972_per_engineer_scorecard() from public, anon;
revoke all on function rpc_r2972_category_lag() from public, anon;
revoke all on function rpc_r2972_action_sla_breach() from public, anon;
revoke all on function rpc_r2972_action_mix() from public, anon;
revoke all on function rpc_r2972_cve_exposure() from public, anon;

grant execute on function rpc_r2972_monthly_risk_rollup() to authenticated;
grant execute on function rpc_r2972_top_lag_offenders() to authenticated;
grant execute on function rpc_r2972_per_hospital_profile() to authenticated;
grant execute on function rpc_r2972_per_engineer_scorecard() to authenticated;
grant execute on function rpc_r2972_category_lag() to authenticated;
grant execute on function rpc_r2972_action_sla_breach() to authenticated;
grant execute on function rpc_r2972_action_mix() to authenticated;
grant execute on function rpc_r2972_cve_exposure() to authenticated;
