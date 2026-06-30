-- Round 3083: Hospital Chain Quarterly Surgical Loupe & Headlight Battery Cycle Audit
-- Two tables (_r3083) + 7 RPCs (is_founder gated) + seed rows.

create table if not exists hospital_chain_loupe_headlight_devices_r3083 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  device_kind text not null check (device_kind in ('loupe','headlight','combo')),
  brand text not null,
  model_code text not null,
  battery_chemistry text not null check (battery_chemistry in ('li_ion','li_po','nimh','sla')),
  battery_capacity_mah int not null check (battery_capacity_mah > 0),
  rated_cycle_count int not null check (rated_cycle_count > 0),
  purchased_on date not null,
  warranty_until date,
  current_status text not null check (current_status in ('healthy','degraded','retire_soon','retired','swapped_out')),
  assigned_surgeon_user_id uuid references profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);
alter table hospital_chain_loupe_headlight_devices_r3083 enable row level security;
drop policy if exists hclhd_r3083_founder_all on hospital_chain_loupe_headlight_devices_r3083;
create policy hclhd_r3083_founder_all on hospital_chain_loupe_headlight_devices_r3083 for all using (is_founder()) with check (is_founder());
revoke all on hospital_chain_loupe_headlight_devices_r3083 from public, anon;
grant select, insert, update, delete on hospital_chain_loupe_headlight_devices_r3083 to authenticated;

create table if not exists hospital_chain_loupe_headlight_cycle_audits_r3083 (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references hospital_chain_loupe_headlight_devices_r3083(id) on delete cascade,
  audit_quarter text not null check (audit_quarter in ('Q1_2026','Q2_2026','Q3_2026','Q4_2026')),
  audit_date date not null,
  cycles_used int not null check (cycles_used >= 0),
  measured_capacity_mah int not null check (measured_capacity_mah >= 0),
  health_score numeric(5,2) not null check (health_score >= 0 and health_score <= 100),
  needs_replacement boolean not null default false,
  recommendation text not null check (recommendation in ('continue','recalibrate','replace_cell','retire')),
  technician_user_id uuid references profiles(id) on delete set null,
  cost_estimate_rupees int,
  follow_up_due date,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table hospital_chain_loupe_headlight_cycle_audits_r3083 enable row level security;
drop policy if exists hclhca_r3083_founder_all on hospital_chain_loupe_headlight_cycle_audits_r3083;
create policy hclhca_r3083_founder_all on hospital_chain_loupe_headlight_cycle_audits_r3083 for all using (is_founder()) with check (is_founder());
revoke all on hospital_chain_loupe_headlight_cycle_audits_r3083 from public, anon;
grant select, insert, update, delete on hospital_chain_loupe_headlight_cycle_audits_r3083 to authenticated;

-- Seed devices
insert into hospital_chain_loupe_headlight_devices_r3083
  (chain_name, hospital_site, device_kind, brand, model_code, battery_chemistry, battery_capacity_mah, rated_cycle_count, purchased_on, warranty_until, current_status, notes)
values
  ('Apollo','Apollo Jubilee','loupe','Heine','HR-2.5','li_ion',2200,500,'2024-03-15'::date,'2026-03-15'::date,'healthy','primary surgeon set'),
  ('Apollo','Apollo Hyderguda','headlight','Heine','LED-LoupeLight','li_po',2400,600,'2024-05-10'::date,'2026-05-10'::date,'degraded','flicker reported'),
  ('Apollo','Apollo Vizag','combo','SurgiTel','EVO-CMBO','li_ion',3000,700,'2023-11-22'::date,'2025-11-22'::date,'retire_soon','warranty expiring'),
  ('Yashoda','Yashoda Secunderabad','loupe','Designs For Vision','LumiVu','li_ion',2500,550,'2024-07-08'::date,'2026-07-08'::date,'healthy',null),
  ('Yashoda','Yashoda Somajiguda','headlight','SurgiTel','MicroLine','nimh',1800,400,'2023-09-12'::date,'2025-09-12'::date,'retired','battery swelling'),
  ('Yashoda','Yashoda Malakpet','combo','Heine','ML-4 LED','li_po',2800,650,'2025-01-20'::date,'2027-01-20'::date,'healthy',null),
  ('KIMS','KIMS Kondapur','loupe','Orascoptic','XV1','li_ion',2200,500,'2024-02-14'::date,'2026-02-14'::date,'degraded','one lens loose'),
  ('KIMS','KIMS Begumpet','headlight','Orascoptic','Endeavour','li_po',2600,600,'2024-08-30'::date,'2026-08-30'::date,'healthy',null),
  ('KIMS','KIMS Secunderabad','combo','Heine','HR Combo','li_ion',3200,750,'2023-12-05'::date,'2025-12-05'::date,'retire_soon','sla advisory'),
  ('Continental','Continental Gachibowli','loupe','SurgiTel','OmniOptic','li_ion',2400,550,'2025-03-18'::date,'2027-03-18'::date,'healthy',null),
  ('Continental','Continental Nallagandla','headlight','Designs For Vision','Q LED','li_po',2700,650,'2024-06-01'::date,'2026-06-01'::date,'swapped_out','swapped under amc'),
  ('Continental','Continental Banjara','combo','Heine','ML-4 Combo','li_ion',3000,700,'2024-09-15'::date,'2026-09-15'::date,'degraded','dim after 2h'),
  ('Sunshine','Sunshine Paradise','loupe','Heine','HR-3.0','li_ion',2200,500,'2024-01-25'::date,'2026-01-25'::date,'retired','obsolete model'),
  ('Sunshine','Sunshine Secunderabad','headlight','SurgiTel','MicroLine 2','li_po',2500,600,'2025-02-10'::date,'2027-02-10'::date,'healthy',null),
  ('Sunshine','Sunshine Kompally','combo','Orascoptic','Spark','li_ion',2900,700,'2024-10-08'::date,'2026-10-08'::date,'healthy',null),
  ('Care','Care Banjara','loupe','Designs For Vision','LumiVu HD','li_ion',2400,550,'2024-04-12'::date,'2026-04-12'::date,'degraded','cable fray'),
  ('Care','Care Nampally','headlight','Heine','LED-Pro','nimh',1900,450,'2023-08-20'::date,'2025-08-20'::date,'retire_soon','low runtime'),
  ('Care','Care Hi-Tech','combo','SurgiTel','EVO-X','li_po',3100,750,'2025-04-01'::date,'2027-04-01'::date,'healthy',null);

-- Seed audits referencing devices via chain+site+kind lookup
insert into hospital_chain_loupe_headlight_cycle_audits_r3083
  (device_id, audit_quarter, audit_date, cycles_used, measured_capacity_mah, health_score, needs_replacement, recommendation, cost_estimate_rupees, follow_up_due, closed_at)
select d.id, q.audit_quarter, q.audit_date, q.cycles_used, q.measured_capacity_mah, q.health_score, q.needs_replacement, q.recommendation, q.cost_estimate_rupees, q.follow_up_due, q.closed_at
from hospital_chain_loupe_headlight_devices_r3083 d
join (
  select 'Apollo Jubilee'::text as site, 'loupe'::text as kind, 'Q1_2026'::text as audit_quarter, '2026-02-15'::date as audit_date, 120 as cycles_used, 2100 as measured_capacity_mah, 92.50::numeric as health_score, false as needs_replacement, 'continue'::text as recommendation, 0 as cost_estimate_rupees, '2026-05-15'::date as follow_up_due, '2026-02-16T09:00:00Z'::timestamptz as closed_at
  union all select 'Apollo Hyderguda','headlight','Q1_2026','2026-02-18'::date,340,1900,72.00::numeric,false,'recalibrate',1500,'2026-05-18'::date,'2026-02-19T10:00:00Z'::timestamptz
  union all select 'Apollo Vizag','combo','Q1_2026','2026-02-20'::date,580,2200,58.00::numeric,true,'replace_cell',8500,'2026-05-20'::date,'2026-02-21T11:00:00Z'::timestamptz
  union all select 'Yashoda Secunderabad','loupe','Q1_2026','2026-02-22'::date,80,2450,96.00::numeric,false,'continue',0,'2026-05-22'::date,'2026-02-23T09:30:00Z'::timestamptz
  union all select 'Yashoda Somajiguda','headlight','Q1_2026','2026-02-25'::date,420,900,32.00::numeric,true,'retire',0,'2026-03-25'::date,'2026-02-26T08:00:00Z'::timestamptz
  union all select 'Yashoda Malakpet','combo','Q1_2026','2026-03-01'::date,40,2780,98.00::numeric,false,'continue',0,'2026-06-01'::date,'2026-03-02T14:00:00Z'::timestamptz
  union all select 'KIMS Kondapur','loupe','Q1_2026','2026-03-04'::date,260,1850,70.00::numeric,false,'recalibrate',1200,'2026-06-04'::date,'2026-03-05T09:00:00Z'::timestamptz
  union all select 'KIMS Begumpet','headlight','Q1_2026','2026-03-08'::date,150,2500,94.00::numeric,false,'continue',0,'2026-06-08'::date,'2026-03-09T10:00:00Z'::timestamptz
  union all select 'KIMS Secunderabad','combo','Q1_2026','2026-03-12'::date,620,2400,62.00::numeric,true,'replace_cell',9500,'2026-06-12'::date,null::timestamptz
  union all select 'Continental Gachibowli','loupe','Q1_2026','2026-03-15'::date,25,2380,99.00::numeric,false,'continue',0,'2026-06-15'::date,'2026-03-16T11:00:00Z'::timestamptz
  union all select 'Continental Nallagandla','headlight','Q1_2026','2026-03-18'::date,200,2600,89.00::numeric,false,'continue',0,'2026-06-18'::date,'2026-03-19T09:00:00Z'::timestamptz
  union all select 'Continental Banjara','combo','Q1_2026','2026-03-22'::date,310,2100,68.00::numeric,false,'recalibrate',2200,'2026-06-22'::date,'2026-03-23T15:00:00Z'::timestamptz
  union all select 'Sunshine Paradise','loupe','Q1_2026','2026-03-25'::date,500,1100,28.00::numeric,true,'retire',0,'2026-04-25'::date,'2026-03-26T08:30:00Z'::timestamptz
  union all select 'Sunshine Secunderabad','headlight','Q1_2026','2026-03-28'::date,15,2480,99.50::numeric,false,'continue',0,'2026-06-28'::date,'2026-03-29T09:00:00Z'::timestamptz
  union all select 'Sunshine Kompally','combo','Q1_2026','2026-04-02'::date,90,2820,95.00::numeric,false,'continue',0,'2026-07-02'::date,'2026-04-03T10:00:00Z'::timestamptz
  union all select 'Care Banjara','loupe','Q1_2026','2026-04-05'::date,280,2000,76.00::numeric,false,'recalibrate',1800,'2026-07-05'::date,null::timestamptz
  union all select 'Care Nampally','headlight','Q1_2026','2026-04-08'::date,380,1100,42.00::numeric,true,'retire',0,'2026-05-08'::date,'2026-04-09T08:00:00Z'::timestamptz
  union all select 'Care Hi-Tech','combo','Q1_2026','2026-04-10'::date,30,3050,98.50::numeric,false,'continue',0,'2026-07-10'::date,'2026-04-11T11:00:00Z'::timestamptz
) q on q.site = d.hospital_site and q.kind = d.device_kind;

-- RPC 1: list devices
create or replace function list_chain_loupe_devices_r3083()
returns setof hospital_chain_loupe_headlight_devices_r3083
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select * from hospital_chain_loupe_headlight_devices_r3083
    order by chain_name asc, hospital_site asc, device_kind asc;
end;
$$;
revoke all on function list_chain_loupe_devices_r3083() from public, anon;
grant execute on function list_chain_loupe_devices_r3083() to authenticated;

-- RPC 2: list audits
create or replace function list_chain_loupe_audits_r3083()
returns table(
  audit_id uuid,
  device_id uuid,
  chain_name text,
  hospital_site text,
  device_kind text,
  audit_quarter text,
  audit_date date,
  cycles_used int,
  measured_capacity_mah int,
  health_score numeric,
  needs_replacement boolean,
  recommendation text,
  cost_estimate_rupees int,
  follow_up_due date,
  closed_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select a.id, d.id, d.chain_name, d.hospital_site, d.device_kind,
      a.audit_quarter, a.audit_date, a.cycles_used, a.measured_capacity_mah, a.health_score,
      a.needs_replacement, a.recommendation, a.cost_estimate_rupees, a.follow_up_due, a.closed_at
    from hospital_chain_loupe_headlight_cycle_audits_r3083 a
    join hospital_chain_loupe_headlight_devices_r3083 d on d.id = a.device_id
    order by a.audit_date desc;
end;
$$;
revoke all on function list_chain_loupe_audits_r3083() from public, anon;
grant execute on function list_chain_loupe_audits_r3083() to authenticated;

-- RPC 3: chain rollup
create or replace function chain_loupe_rollup_r3083()
returns table(
  chain_name text,
  device_count int,
  healthy_count int,
  degraded_count int,
  retire_soon_count int,
  retired_count int,
  avg_health_score numeric,
  replace_needed_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select d.chain_name,
      count(*)::int as device_count,
      (count(*) filter (where d.current_status = 'healthy'))::int as healthy_count,
      (count(*) filter (where d.current_status = 'degraded'))::int as degraded_count,
      (count(*) filter (where d.current_status = 'retire_soon'))::int as retire_soon_count,
      (count(*) filter (where d.current_status = 'retired'))::int as retired_count,
      coalesce(avg(a.health_score),0)::numeric as avg_health_score,
      (count(*) filter (where a.needs_replacement))::int as replace_needed_count
    from hospital_chain_loupe_headlight_devices_r3083 d
    left join hospital_chain_loupe_headlight_cycle_audits_r3083 a on a.device_id = d.id
    group by d.chain_name
    order by d.chain_name asc;
end;
$$;
revoke all on function chain_loupe_rollup_r3083() from public, anon;
grant execute on function chain_loupe_rollup_r3083() to authenticated;

-- RPC 4: replacement candidates
create or replace function chain_loupe_replacement_candidates_r3083()
returns table(
  device_id uuid,
  chain_name text,
  hospital_site text,
  device_kind text,
  brand text,
  model_code text,
  health_score numeric,
  cycles_used int,
  rated_cycle_count int,
  recommendation text,
  cost_estimate_rupees int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select d.id, d.chain_name, d.hospital_site, d.device_kind, d.brand, d.model_code,
      a.health_score, a.cycles_used, d.rated_cycle_count, a.recommendation, a.cost_estimate_rupees
    from hospital_chain_loupe_headlight_cycle_audits_r3083 a
    join hospital_chain_loupe_headlight_devices_r3083 d on d.id = a.device_id
    where a.needs_replacement = true or a.recommendation in ('replace_cell','retire')
    order by a.health_score asc;
end;
$$;
revoke all on function chain_loupe_replacement_candidates_r3083() from public, anon;
grant execute on function chain_loupe_replacement_candidates_r3083() to authenticated;

-- RPC 5: battery chemistry breakdown
create or replace function chain_loupe_chemistry_breakdown_r3083()
returns table(
  battery_chemistry text,
  device_count int,
  avg_capacity_mah numeric,
  avg_rated_cycles numeric,
  avg_health_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select d.battery_chemistry,
      count(*)::int as device_count,
      avg(d.battery_capacity_mah)::numeric as avg_capacity_mah,
      avg(d.rated_cycle_count)::numeric as avg_rated_cycles,
      coalesce(avg(a.health_score),0)::numeric as avg_health_score
    from hospital_chain_loupe_headlight_devices_r3083 d
    left join hospital_chain_loupe_headlight_cycle_audits_r3083 a on a.device_id = d.id
    group by d.battery_chemistry
    order by d.battery_chemistry asc;
end;
$$;
revoke all on function chain_loupe_chemistry_breakdown_r3083() from public, anon;
grant execute on function chain_loupe_chemistry_breakdown_r3083() to authenticated;

-- RPC 6: warranty expiring soon
create or replace function chain_loupe_warranty_expiring_r3083()
returns table(
  device_id uuid,
  chain_name text,
  hospital_site text,
  device_kind text,
  brand text,
  model_code text,
  warranty_until date,
  days_to_expiry int,
  current_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select d.id, d.chain_name, d.hospital_site, d.device_kind, d.brand, d.model_code,
      d.warranty_until,
      (d.warranty_until - current_date)::int as days_to_expiry,
      d.current_status
    from hospital_chain_loupe_headlight_devices_r3083 d
    where d.warranty_until is not null
      and d.warranty_until <= (current_date + interval '180 days')::date
    order by d.warranty_until asc;
end;
$$;
revoke all on function chain_loupe_warranty_expiring_r3083() from public, anon;
grant execute on function chain_loupe_warranty_expiring_r3083() to authenticated;

-- RPC 7: quarter summary
create or replace function chain_loupe_quarter_summary_r3083()
returns table(
  audit_quarter text,
  audit_count int,
  continue_count int,
  recalibrate_count int,
  replace_cell_count int,
  retire_count int,
  avg_health_score numeric,
  total_replacement_cost int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
    select a.audit_quarter,
      count(*)::int as audit_count,
      (count(*) filter (where a.recommendation = 'continue'))::int as continue_count,
      (count(*) filter (where a.recommendation = 'recalibrate'))::int as recalibrate_count,
      (count(*) filter (where a.recommendation = 'replace_cell'))::int as replace_cell_count,
      (count(*) filter (where a.recommendation = 'retire'))::int as retire_count,
      coalesce(avg(a.health_score),0)::numeric as avg_health_score,
      coalesce(sum(a.cost_estimate_rupees),0)::int as total_replacement_cost
    from hospital_chain_loupe_headlight_cycle_audits_r3083 a
    group by a.audit_quarter
    order by a.audit_quarter asc;
end;
$$;
revoke all on function chain_loupe_quarter_summary_r3083() from public, anon;
grant execute on function chain_loupe_quarter_summary_r3083() to authenticated;
