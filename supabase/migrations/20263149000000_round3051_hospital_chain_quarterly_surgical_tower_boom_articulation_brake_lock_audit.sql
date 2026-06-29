-- Round 3051: Hospital Chain Quarterly Surgical Tower Boom Articulation & Brake Lock Audit
-- HEAVY x4

create table if not exists public.surgical_tower_boom_audits_r3051 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  hospital_site text not null,
  operating_room text not null,
  boom_asset_tag text not null,
  boom_type text not null check (boom_type in ('anesthesia','surgical','endoscopy','equipment','imaging','combo')),
  articulation_axes int not null check (articulation_axes between 2 and 8),
  articulation_score numeric(5,2) not null check (articulation_score between 0 and 100),
  brake_lock_score numeric(5,2) not null check (brake_lock_score between 0 and 100),
  drift_mm_per_hour numeric(6,2) not null check (drift_mm_per_hour >= 0),
  audit_quarter text not null check (audit_quarter in ('q1','q2','q3','q4')),
  audit_status text not null check (audit_status in ('passed','watch','failed','quarantined','remediated')),
  remediation_cost_rupees int not null check (remediation_cost_rupees >= 0),
  audited_at timestamptz not null
);

create table if not exists public.surgical_tower_boom_findings_r3051 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references public.surgical_tower_boom_audits_r3051(id) on delete cascade,
  finding_code text not null,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  category text not null check (category in ('brake_slip','axis_play','counterbalance','cable_drag','sterile_seal','grounding','load_rating')),
  measured_value numeric(8,2),
  spec_max numeric(8,2),
  resolved boolean not null default false,
  resolved_at timestamptz,
  notes text
);

alter table public.surgical_tower_boom_audits_r3051 enable row level security;
alter table public.surgical_tower_boom_findings_r3051 enable row level security;

drop policy if exists boom_audits_founder_r3051 on public.surgical_tower_boom_audits_r3051;
create policy boom_audits_founder_r3051 on public.surgical_tower_boom_audits_r3051 for select to authenticated using (public.is_founder());

drop policy if exists boom_findings_founder_r3051 on public.surgical_tower_boom_findings_r3051;
create policy boom_findings_founder_r3051 on public.surgical_tower_boom_findings_r3051 for select to authenticated using (public.is_founder());

insert into public.surgical_tower_boom_audits_r3051 (chain_code, hospital_site, operating_room, boom_asset_tag, boom_type, articulation_axes, articulation_score, brake_lock_score, drift_mm_per_hour, audit_quarter, audit_status, remediation_cost_rupees, audited_at) values
('APOLLO','Apollo Jubilee Hills','OR-01','BM-AP-J-0011','anesthesia',6,92.50,88.00,0.40,'q1','passed',0,'2026-04-02 09:00:00+05:30'::timestamptz),
('APOLLO','Apollo Jubilee Hills','OR-02','BM-AP-J-0012','surgical',5,76.00,71.50,1.80,'q1','watch',45000,'2026-04-02 10:30:00+05:30'::timestamptz),
('APOLLO','Apollo Secunderabad','OR-03','BM-AP-S-0021','equipment',4,55.00,48.00,3.20,'q1','failed',180000,'2026-04-03 11:00:00+05:30'::timestamptz),
('APOLLO','Apollo Hyderguda','OR-04','BM-AP-H-0031','endoscopy',5,89.00,90.00,0.60,'q1','passed',0,'2026-04-04 09:15:00+05:30'::timestamptz),
('FORTIS','Fortis Banjara','OR-01','BM-FR-B-0041','imaging',6,82.00,85.00,1.10,'q1','passed',12000,'2026-04-05 10:00:00+05:30'::timestamptz),
('FORTIS','Fortis Banjara','OR-02','BM-FR-B-0042','surgical',5,40.00,38.00,4.50,'q1','quarantined',320000,'2026-04-05 11:45:00+05:30'::timestamptz),
('FORTIS','Fortis Madhapur','OR-05','BM-FR-M-0051','combo',7,95.00,93.00,0.30,'q1','passed',0,'2026-04-06 09:30:00+05:30'::timestamptz),
('YASHODA','Yashoda Somajiguda','OR-01','BM-YS-S-0061','anesthesia',6,68.00,62.00,2.40,'q1','watch',62000,'2026-04-07 10:20:00+05:30'::timestamptz),
('YASHODA','Yashoda Malakpet','OR-02','BM-YS-M-0071','surgical',5,72.50,75.00,1.50,'q1','passed',8000,'2026-04-08 11:10:00+05:30'::timestamptz),
('YASHODA','Yashoda Secunderabad','OR-03','BM-YS-SC-0081','equipment',4,50.00,52.00,3.00,'q1','failed',155000,'2026-04-08 13:00:00+05:30'::timestamptz),
('KIMS','KIMS Kondapur','OR-01','BM-KM-K-0091','endoscopy',5,87.00,89.00,0.70,'q1','passed',0,'2026-04-09 09:00:00+05:30'::timestamptz),
('KIMS','KIMS Secunderabad','OR-02','BM-KM-S-0101','imaging',6,78.00,80.00,1.20,'q1','passed',15000,'2026-04-09 10:30:00+05:30'::timestamptz),
('KIMS','KIMS Begumpet','OR-03','BM-KM-B-0111','combo',7,45.00,42.00,4.80,'q1','quarantined',380000,'2026-04-10 11:00:00+05:30'::timestamptz),
('CONTINENTAL','Continental Gachibowli','OR-01','BM-CN-G-0121','anesthesia',6,90.00,92.00,0.50,'q1','passed',0,'2026-04-11 09:45:00+05:30'::timestamptz),
('CONTINENTAL','Continental Gachibowli','OR-02','BM-CN-G-0122','surgical',5,65.00,60.00,2.20,'q1','remediated',95000,'2026-04-11 10:50:00+05:30'::timestamptz),
('CARE','Care Banjara','OR-01','BM-CR-B-0131','equipment',4,58.00,55.00,2.80,'q1','watch',72000,'2026-04-12 09:15:00+05:30'::timestamptz),
('CARE','Care Hi-Tec','OR-02','BM-CR-H-0141','endoscopy',5,83.00,86.00,0.90,'q1','passed',5000,'2026-04-12 11:20:00+05:30'::timestamptz),
('AIG','AIG Gachibowli','OR-01','BM-AG-G-0151','combo',7,96.00,95.00,0.20,'q1','passed',0,'2026-04-13 09:00:00+05:30'::timestamptz),
('AIG','AIG Gachibowli','OR-02','BM-AG-G-0152','imaging',6,52.00,49.00,3.50,'q1','failed',210000,'2026-04-13 10:30:00+05:30'::timestamptz),
('STAR','Star Banjara','OR-01','BM-ST-B-0161','anesthesia',6,74.00,78.00,1.40,'q1','passed',18000,'2026-04-14 09:45:00+05:30'::timestamptz),
('STAR','Star Nampally','OR-02','BM-ST-N-0171','surgical',5,42.00,40.00,4.20,'q1','quarantined',290000,'2026-04-14 11:00:00+05:30'::timestamptz),
('OMNI','Omni Kothapet','OR-01','BM-OM-K-0181','equipment',4,69.00,66.00,2.00,'q1','remediated',85000,'2026-04-15 10:00:00+05:30'::timestamptz);

insert into public.surgical_tower_boom_findings_r3051 (audit_id, finding_code, severity, category, measured_value, spec_max, resolved, resolved_at, notes)
select a.id, 'F-' || substr(a.boom_asset_tag, -4) || '-01',
  case when a.audit_status in ('failed','quarantined') then 'p0' when a.audit_status='watch' then 'p1' when a.audit_status='remediated' then 'p2' else 'p3' end,
  case (abs(hashtext(a.boom_asset_tag)) % 7)
    when 0 then 'brake_slip' when 1 then 'axis_play' when 2 then 'counterbalance'
    when 3 then 'cable_drag' when 4 then 'sterile_seal' when 5 then 'grounding' else 'load_rating' end,
  a.drift_mm_per_hour, 1.50,
  a.audit_status in ('passed','remediated'),
  case when a.audit_status in ('passed','remediated') then a.audited_at + interval '7 days' else null end,
  'Boom ' || a.boom_asset_tag || ' quarterly finding'
from public.surgical_tower_boom_audits_r3051 a;

create or replace function public.r3051_chain_rollup()
returns table(chain_code text, audits int, failed int, quarantined int, avg_brake_lock numeric, total_remediation_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_code,
    count(*)::int,
    (count(*) filter (where a.audit_status='failed'))::int,
    (count(*) filter (where a.audit_status='quarantined'))::int,
    round(avg(a.brake_lock_score),2),
    sum(a.remediation_cost_rupees)::bigint
  from public.surgical_tower_boom_audits_r3051 a
  group by a.chain_code
  order by 4 desc;
end; $$;

create or replace function public.r3051_failed_booms()
returns table(chain_code text, hospital_site text, operating_room text, boom_asset_tag text, articulation_score numeric, brake_lock_score numeric, drift_mm_per_hour numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_code, a.hospital_site, a.operating_room, a.boom_asset_tag, a.articulation_score, a.brake_lock_score, a.drift_mm_per_hour
  from public.surgical_tower_boom_audits_r3051 a
  where a.audit_status in ('failed','quarantined')
  order by a.drift_mm_per_hour desc;
end; $$;

create or replace function public.r3051_boom_type_breakdown()
returns table(boom_type text, audits int, avg_articulation numeric, avg_brake_lock numeric, avg_drift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.boom_type, count(*)::int, round(avg(a.articulation_score),2), round(avg(a.brake_lock_score),2), round(avg(a.drift_mm_per_hour),2)
  from public.surgical_tower_boom_audits_r3051 a
  group by a.boom_type
  order by 5 desc;
end; $$;

create or replace function public.r3051_status_mix()
returns table(audit_status text, n int, pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total from public.surgical_tower_boom_audits_r3051;
  return query
  select a.audit_status, count(*)::int,
    round((count(*)::numeric * 100.0 / nullif(total,0)),2)
  from public.surgical_tower_boom_audits_r3051 a
  group by a.audit_status
  order by 2 desc;
end; $$;

create or replace function public.r3051_severity_findings()
returns table(severity text, findings int, resolved int, open_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity, count(*)::int,
    (count(*) filter (where f.resolved))::int,
    (count(*) filter (where not f.resolved))::int
  from public.surgical_tower_boom_findings_r3051 f
  group by f.severity
  order by 1;
end; $$;

create or replace function public.r3051_top_drift()
returns table(boom_asset_tag text, hospital_site text, operating_room text, drift_mm_per_hour numeric, audit_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.boom_asset_tag, a.hospital_site, a.operating_room, a.drift_mm_per_hour, a.audit_status
  from public.surgical_tower_boom_audits_r3051 a
  order by a.drift_mm_per_hour desc
  limit 10;
end; $$;

create or replace function public.r3051_category_findings()
returns table(category text, n int, avg_measured numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.category, count(*)::int, round(avg(f.measured_value),2)
  from public.surgical_tower_boom_findings_r3051 f
  group by f.category
  order by 2 desc;
end; $$;

create or replace function public.r3051_remediation_cost_by_chain()
returns table(chain_code text, failed_or_quarantined int, total_cost_rupees bigint, avg_cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_code,
    (count(*) filter (where a.audit_status in ('failed','quarantined')))::int,
    sum(a.remediation_cost_rupees)::bigint,
    avg(a.remediation_cost_rupees)::bigint
  from public.surgical_tower_boom_audits_r3051 a
  group by a.chain_code
  order by 3 desc;
end; $$;

revoke all on public.surgical_tower_boom_audits_r3051 from public, anon;
revoke all on public.surgical_tower_boom_findings_r3051 from public, anon;
grant select on public.surgical_tower_boom_audits_r3051 to authenticated;
grant select on public.surgical_tower_boom_findings_r3051 to authenticated;

revoke all on function public.r3051_chain_rollup() from public, anon;
revoke all on function public.r3051_failed_booms() from public, anon;
revoke all on function public.r3051_boom_type_breakdown() from public, anon;
revoke all on function public.r3051_status_mix() from public, anon;
revoke all on function public.r3051_severity_findings() from public, anon;
revoke all on function public.r3051_top_drift() from public, anon;
revoke all on function public.r3051_category_findings() from public, anon;
revoke all on function public.r3051_remediation_cost_by_chain() from public, anon;

grant execute on function public.r3051_chain_rollup() to authenticated;
grant execute on function public.r3051_failed_booms() to authenticated;
grant execute on function public.r3051_boom_type_breakdown() to authenticated;
grant execute on function public.r3051_status_mix() to authenticated;
grant execute on function public.r3051_severity_findings() to authenticated;
grant execute on function public.r3051_top_drift() to authenticated;
grant execute on function public.r3051_category_findings() to authenticated;
grant execute on function public.r3051_remediation_cost_by_chain() to authenticated;
