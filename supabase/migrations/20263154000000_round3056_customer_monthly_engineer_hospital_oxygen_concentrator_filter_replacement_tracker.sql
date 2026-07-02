-- Round 3056 — Customer Monthly Engineer Hospital Oxygen Concentrator Filter Replacement Tracker

create table if not exists oxygen_filter_devices_r3056 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text not null,
  city text not null,
  device_serial text not null,
  device_model text not null,
  install_date date not null,
  last_filter_change_date date not null,
  next_filter_due_date date not null,
  filter_status text not null check (filter_status in ('current','due_soon','overdue','critical')),
  service_tier text not null check (service_tier in ('basic','standard','premium')),
  assigned_engineer text not null,
  monthly_runtime_hours int not null,
  filter_health_pct int not null,
  amc_active boolean not null default true
);

create table if not exists oxygen_filter_replacements_r3056 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  device_id uuid not null references oxygen_filter_devices_r3056(id) on delete cascade,
  replacement_date date not null,
  engineer_name text not null,
  filter_type text not null check (filter_type in ('hepa','carbon','pre_filter','molecular_sieve','combo')),
  outcome text not null check (outcome in ('success','partial','rework','failed')),
  parts_cost_rupees int not null,
  labor_cost_rupees int not null,
  downtime_minutes int not null,
  customer_rating int check (customer_rating between 1 and 5),
  notes text
);

alter table oxygen_filter_devices_r3056 enable row level security;
alter table oxygen_filter_replacements_r3056 enable row level security;

drop policy if exists ofd_r3056_founder_all on oxygen_filter_devices_r3056;
create policy ofd_r3056_founder_all on oxygen_filter_devices_r3056 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists ofr_r3056_founder_all on oxygen_filter_replacements_r3056;
create policy ofr_r3056_founder_all on oxygen_filter_replacements_r3056 for all to authenticated using (is_founder()) with check (is_founder());

insert into oxygen_filter_devices_r3056 (hospital_name, city, device_serial, device_model, install_date, last_filter_change_date, next_filter_due_date, filter_status, service_tier, assigned_engineer, monthly_runtime_hours, filter_health_pct, amc_active) values
('Apollo Hyderabad','Hyderabad','OXC-2401-001','Philips EverFlo','2025-03-12'::date,'2026-05-15'::date,'2026-06-15'::date,'due_soon','premium','Ramesh K',520,42,true),
('KIMS Secunderabad','Hyderabad','OXC-2401-002','DeVilbiss 1025','2025-04-08'::date,'2026-04-20'::date,'2026-05-20'::date,'overdue','premium','Suresh M',610,18,true),
('Yashoda Somajiguda','Hyderabad','OXC-2401-003','Invacare Perfecto2','2025-05-22'::date,'2026-05-01'::date,'2026-06-01'::date,'overdue','standard','Anil G',480,22,true),
('Care Banjara','Hyderabad','OXC-2401-004','Philips EverFlo','2025-06-15'::date,'2026-06-10'::date,'2026-07-10'::date,'current','premium','Ramesh K',440,78,true),
('Citizens Nallagandla','Hyderabad','OXC-2401-005','DeVilbiss 525','2025-07-01'::date,'2026-05-28'::date,'2026-06-28'::date,'due_soon','standard','Vinod P',390,55,true),
('Continental Gachibowli','Hyderabad','OXC-2401-006','Invacare Platinum','2025-08-19'::date,'2026-03-10'::date,'2026-04-10'::date,'critical','basic','Anil G',720,8,true),
('AIG Gachibowli','Hyderabad','OXC-2401-007','Philips Respironics','2025-09-05'::date,'2026-06-12'::date,'2026-07-12'::date,'current','premium','Ramesh K',410,82,true),
('Medicover Hitech','Hyderabad','OXC-2401-008','DeVilbiss 1025','2025-10-22'::date,'2026-05-18'::date,'2026-06-18'::date,'due_soon','standard','Suresh M',500,48,true),
('Star Banjara','Hyderabad','OXC-2401-009','Invacare Perfecto2','2025-11-08'::date,'2026-04-25'::date,'2026-05-25'::date,'overdue','basic','Vinod P',580,30,false),
('Sunshine Secunderabad','Hyderabad','OXC-2401-010','Philips EverFlo','2025-12-14'::date,'2026-06-08'::date,'2026-07-08'::date,'current','premium','Ramesh K',360,85,true),
('Manipal Tadepalli','Vijayawada','OXC-2401-011','DeVilbiss 525','2026-01-09'::date,'2026-05-30'::date,'2026-06-30'::date,'due_soon','standard','Karthik R',430,52,true),
('NRI Chinakakani','Guntur','OXC-2401-012','Invacare Platinum','2026-01-25'::date,'2026-02-15'::date,'2026-03-15'::date,'critical','basic','Karthik R',650,5,true),
('Apollo Visakhapatnam','Visakhapatnam','OXC-2401-013','Philips Respironics','2026-02-11'::date,'2026-06-11'::date,'2026-07-11'::date,'current','premium','Praveen D',380,88,true),
('Care Vizag','Visakhapatnam','OXC-2401-014','DeVilbiss 1025','2026-02-28'::date,'2026-05-22'::date,'2026-06-22'::date,'due_soon','standard','Praveen D',470,46,true),
('Aster Prime Ameerpet','Hyderabad','OXC-2401-015','Invacare Perfecto2','2026-03-17'::date,'2026-04-30'::date,'2026-05-30'::date,'overdue','premium','Ramesh K',540,25,true),
('Olive Tolichowki','Hyderabad','OXC-2401-016','Philips EverFlo','2026-03-30'::date,'2026-06-14'::date,'2026-07-14'::date,'current','premium','Suresh M',420,80,true),
('Virinchi Banjara','Hyderabad','OXC-2401-017','DeVilbiss 525','2026-04-12'::date,'2026-05-25'::date,'2026-06-25'::date,'due_soon','basic','Anil G',460,50,true),
('Renova Sarojini','Hyderabad','OXC-2401-018','Invacare Platinum','2026-04-25'::date,'2026-03-20'::date,'2026-04-20'::date,'critical','standard','Vinod P',680,12,true);

insert into oxygen_filter_replacements_r3056 (device_id, replacement_date, engineer_name, filter_type, outcome, parts_cost_rupees, labor_cost_rupees, downtime_minutes, customer_rating, notes) 
select id, '2026-05-15'::date, 'Ramesh K', 'hepa', 'success', 1800, 600, 45, 5, 'clean swap' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-001'
union all select id, '2026-04-20'::date, 'Suresh M', 'combo', 'partial', 3200, 900, 90, 3, 'sieve degraded' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-002'
union all select id, '2026-05-01'::date, 'Anil G', 'carbon', 'success', 1200, 500, 35, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-003'
union all select id, '2026-06-10'::date, 'Ramesh K', 'hepa', 'success', 1900, 650, 40, 5, 'premium tier' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-004'
union all select id, '2026-05-28'::date, 'Vinod P', 'pre_filter', 'success', 800, 450, 30, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-005'
union all select id, '2026-03-10'::date, 'Anil G', 'molecular_sieve', 'rework', 4500, 1200, 180, 2, 'leak found' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-006'
union all select id, '2026-06-12'::date, 'Ramesh K', 'combo', 'success', 3000, 800, 55, 5, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-007'
union all select id, '2026-05-18'::date, 'Suresh M', 'hepa', 'success', 1850, 600, 42, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-008'
union all select id, '2026-04-25'::date, 'Vinod P', 'carbon', 'failed', 1300, 550, 220, 1, 'wrong part' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-009'
union all select id, '2026-06-08'::date, 'Ramesh K', 'hepa', 'success', 1900, 650, 38, 5, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-010'
union all select id, '2026-05-30'::date, 'Karthik R', 'pre_filter', 'success', 850, 500, 32, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-011'
union all select id, '2026-02-15'::date, 'Karthik R', 'molecular_sieve', 'failed', 4800, 1400, 300, 1, 'compressor issue' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-012'
union all select id, '2026-06-11'::date, 'Praveen D', 'combo', 'success', 3100, 850, 50, 5, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-013'
union all select id, '2026-05-22'::date, 'Praveen D', 'hepa', 'success', 1850, 620, 44, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-014'
union all select id, '2026-04-30'::date, 'Ramesh K', 'carbon', 'partial', 1250, 580, 95, 3, 'second visit' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-015'
union all select id, '2026-06-14'::date, 'Suresh M', 'hepa', 'success', 1900, 650, 41, 5, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-016'
union all select id, '2026-05-25'::date, 'Anil G', 'pre_filter', 'success', 820, 480, 33, 4, null from oxygen_filter_devices_r3056 where device_serial='OXC-2401-017'
union all select id, '2026-03-20'::date, 'Vinod P', 'molecular_sieve', 'rework', 4600, 1300, 200, 2, 'tubing crack' from oxygen_filter_devices_r3056 where device_serial='OXC-2401-018';

create or replace function rpc_r3056_device_overview()
returns table (hospital_name text, city text, device_serial text, device_model text, filter_status text, service_tier text, assigned_engineer text, next_filter_due_date date, filter_health_pct int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select d.hospital_name, d.city, d.device_serial, d.device_model, d.filter_status, d.service_tier, d.assigned_engineer, d.next_filter_due_date, d.filter_health_pct
    from oxygen_filter_devices_r3056 d order by d.next_filter_due_date asc;
end; $$;

create or replace function rpc_r3056_status_breakdown()
returns table (filter_status text, device_count int, avg_health_pct int, overdue_pct int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select d.filter_status,
    count(*)::int as device_count,
    coalesce(avg(d.filter_health_pct),0)::int as avg_health_pct,
    ((count(*) filter (where d.filter_status in ('overdue','critical')))::numeric * 100 / nullif(count(*),0))::int as overdue_pct
    from oxygen_filter_devices_r3056 d group by d.filter_status order by d.filter_status;
end; $$;

create or replace function rpc_r3056_engineer_performance()
returns table (engineer_name text, replacements int, success_count int, success_pct int, avg_rating numeric, total_revenue_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select r.engineer_name,
    count(*)::int as replacements,
    (count(*) filter (where r.outcome='success'))::int as success_count,
    ((count(*) filter (where r.outcome='success'))::numeric * 100 / nullif(count(*),0))::int as success_pct,
    round(avg(r.customer_rating)::numeric, 2) as avg_rating,
    sum(r.parts_cost_rupees + r.labor_cost_rupees)::int as total_revenue_rupees
    from oxygen_filter_replacements_r3056 r group by r.engineer_name order by replacements desc;
end; $$;

create or replace function rpc_r3056_filter_type_mix()
returns table (filter_type text, replacement_count int, avg_parts_cost int, avg_downtime_min int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select r.filter_type,
    count(*)::int as replacement_count,
    coalesce(avg(r.parts_cost_rupees),0)::int as avg_parts_cost,
    coalesce(avg(r.downtime_minutes),0)::int as avg_downtime_min
    from oxygen_filter_replacements_r3056 r group by r.filter_type order by replacement_count desc;
end; $$;

create or replace function rpc_r3056_overdue_devices()
returns table (hospital_name text, city text, device_serial text, next_filter_due_date date, filter_health_pct int, assigned_engineer text, days_overdue int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select d.hospital_name, d.city, d.device_serial, d.next_filter_due_date, d.filter_health_pct, d.assigned_engineer,
    greatest(0, (current_date - d.next_filter_due_date))::int as days_overdue
    from oxygen_filter_devices_r3056 d where d.filter_status in ('overdue','critical') order by days_overdue desc;
end; $$;

create or replace function rpc_r3056_city_rollup()
returns table (city text, total_devices int, critical_devices int, amc_active_pct int, avg_runtime_hours int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select d.city,
    count(*)::int as total_devices,
    (count(*) filter (where d.filter_status='critical'))::int as critical_devices,
    ((count(*) filter (where d.amc_active))::numeric * 100 / nullif(count(*),0))::int as amc_active_pct,
    coalesce(avg(d.monthly_runtime_hours),0)::int as avg_runtime_hours
    from oxygen_filter_devices_r3056 d group by d.city order by total_devices desc;
end; $$;

create or replace function rpc_r3056_recent_replacements()
returns table (replacement_date date, hospital_name text, engineer_name text, filter_type text, outcome text, parts_cost_rupees int, customer_rating int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select r.replacement_date, d.hospital_name, r.engineer_name, r.filter_type, r.outcome, r.parts_cost_rupees, r.customer_rating
    from oxygen_filter_replacements_r3056 r join oxygen_filter_devices_r3056 d on d.id=r.device_id
    order by r.replacement_date desc;
end; $$;

revoke all on function rpc_r3056_device_overview() from public, anon;
revoke all on function rpc_r3056_status_breakdown() from public, anon;
revoke all on function rpc_r3056_engineer_performance() from public, anon;
revoke all on function rpc_r3056_filter_type_mix() from public, anon;
revoke all on function rpc_r3056_overdue_devices() from public, anon;
revoke all on function rpc_r3056_city_rollup() from public, anon;
revoke all on function rpc_r3056_recent_replacements() from public, anon;

grant execute on function rpc_r3056_device_overview() to authenticated;
grant execute on function rpc_r3056_status_breakdown() to authenticated;
grant execute on function rpc_r3056_engineer_performance() to authenticated;
grant execute on function rpc_r3056_filter_type_mix() to authenticated;
grant execute on function rpc_r3056_overdue_devices() to authenticated;
grant execute on function rpc_r3056_city_rollup() to authenticated;
grant execute on function rpc_r3056_recent_replacements() to authenticated;
