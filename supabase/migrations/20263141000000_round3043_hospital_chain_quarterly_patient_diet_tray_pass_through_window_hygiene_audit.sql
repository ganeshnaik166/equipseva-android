-- Round 3043: Hospital Chain Quarterly Patient-Diet Tray Pass-Through Window Hygiene Audit
-- 2 tables + 7 RPCs (is_founder gated) + seed rows

create table if not exists public.tray_window_audits_r3043 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_chain text not null,
  hospital_branch text not null,
  city text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null check (fiscal_year between 2024 and 2030),
  window_zone text not null check (window_zone in ('kitchen_side','ward_side','interlock_chamber','wash_return')),
  auditor_name text not null,
  audit_date date not null,
  swab_atp_rlu int not null check (swab_atp_rlu between 0 and 5000),
  visual_score int not null check (visual_score between 0 and 10),
  gasket_integrity_pct int not null check (gasket_integrity_pct between 0 and 100),
  sanitizer_residue_ppm numeric(6,2) not null check (sanitizer_residue_ppm between 0 and 500),
  pass_status text not null check (pass_status in ('pass','marginal','fail','critical_fail')),
  remediation_hours int check (remediation_hours between 0 and 720),
  notes text
);

create table if not exists public.tray_window_findings_r3043 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references public.tray_window_audits_r3043(id) on delete cascade,
  finding_category text not null check (finding_category in ('biofilm','grease','spillage','seal_breach','pest_evidence','condensation','rust','chipped_paint')),
  severity text not null check (severity in ('low','medium','high','critical')),
  location_detail text not null,
  recommended_action text not null,
  closure_status text not null check (closure_status in ('open','in_progress','closed','escalated')),
  closed_at timestamptz
);

alter table public.tray_window_audits_r3043 enable row level security;
alter table public.tray_window_findings_r3043 enable row level security;

drop policy if exists tray_window_audits_r3043_founder_all on public.tray_window_audits_r3043;
create policy tray_window_audits_r3043_founder_all on public.tray_window_audits_r3043 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists tray_window_findings_r3043_founder_all on public.tray_window_findings_r3043;
create policy tray_window_findings_r3043_founder_all on public.tray_window_findings_r3043 for all to authenticated using (is_founder()) with check (is_founder());

-- Seed audits (18 rows)
insert into public.tray_window_audits_r3043 (hospital_chain, hospital_branch, city, quarter, fiscal_year, window_zone, auditor_name, audit_date, swab_atp_rlu, visual_score, gasket_integrity_pct, sanitizer_residue_ppm, pass_status, remediation_hours, notes) values
('Apollo','Jubilee Hills','Hyderabad','Q1',2026,'kitchen_side','R. Iyer','2026-01-12'::date,120,9,95,180.50,'pass',0,'spotless'),
('Apollo','Jubilee Hills','Hyderabad','Q2',2026,'ward_side','R. Iyer','2026-04-14'::date,340,7,82,140.00,'marginal',24,'minor grease film'),
('Apollo','Banjara Hills','Hyderabad','Q1',2026,'interlock_chamber','S. Kapoor','2026-01-15'::date,210,8,88,160.25,'pass',8,'gasket aging'),
('Fortis','Sector 62','Noida','Q1',2026,'wash_return','M. Singh','2026-01-18'::date,890,5,70,90.00,'fail',96,'biofilm at drain'),
('Fortis','BG Road','Bangalore','Q2',2026,'kitchen_side','M. Singh','2026-04-22'::date,150,9,92,200.00,'pass',0,'clean'),
('Manipal','Old Airport','Bangalore','Q1',2026,'ward_side','D. Pillai','2026-01-25'::date,420,6,75,110.50,'marginal',48,'condensation on tray rails'),
('Manipal','Whitefield','Bangalore','Q2',2026,'interlock_chamber','D. Pillai','2026-04-27'::date,1850,3,55,40.00,'critical_fail',12,'rodent droppings near chamber'),
('Max','Saket','Delhi','Q1',2026,'kitchen_side','P. Chandra','2026-02-02'::date,180,8,90,170.75,'pass',4,'minor scuff'),
('Max','Saket','Delhi','Q2',2026,'wash_return','P. Chandra','2026-04-30'::date,720,5,68,85.00,'fail',72,'seal breach noted'),
('Narayana','HRBR','Bangalore','Q1',2026,'ward_side','A. Rao','2026-02-08'::date,260,7,84,150.00,'marginal',16,'paint chipping'),
('Narayana','Mazumdar','Bangalore','Q2',2026,'kitchen_side','A. Rao','2026-05-05'::date,140,9,93,190.00,'pass',0,null),
('Medanta','Gurgaon','Gurgaon','Q1',2026,'interlock_chamber','V. Bhatia','2026-02-12'::date,310,8,86,165.00,'pass',6,'gasket replaced'),
('Medanta','Gurgaon','Gurgaon','Q2',2026,'wash_return','V. Bhatia','2026-05-10'::date,2100,2,48,30.00,'critical_fail',8,'major biofilm + rust'),
('Aster','MIMS Calicut','Calicut','Q1',2026,'kitchen_side','K. Menon','2026-02-18'::date,170,9,94,185.00,'pass',0,'clean'),
('Aster','CMI Bangalore','Bangalore','Q2',2026,'ward_side','K. Menon','2026-05-14'::date,480,6,73,100.00,'fail',60,'recurring spillage'),
('KIMS','Secunderabad','Hyderabad','Q1',2026,'wash_return','L. Reddy','2026-02-22'::date,230,8,87,155.00,'pass',12,'minor condensation'),
('KIMS','Kondapur','Hyderabad','Q2',2026,'interlock_chamber','L. Reddy','2026-05-18'::date,560,6,72,95.50,'fail',48,null),
('Yashoda','Somajiguda','Hyderabad','Q1',2026,'kitchen_side','N. Goud','2026-02-26'::date,135,9,96,195.00,'pass',0,'best in class');

-- Seed findings (20 rows)
with a as (select id, hospital_branch, window_zone, row_number() over (order by audit_date) rn from public.tray_window_audits_r3043)
insert into public.tray_window_findings_r3043 (audit_id, finding_category, severity, location_detail, recommended_action, closure_status, closed_at)
select (select id from a where rn=2), 'grease','medium','south rail','degrease + polish','closed','2026-04-16'::timestamptz union all
select (select id from a where rn=3), 'seal_breach','low','upper gasket','replace gasket within 14d','closed','2026-01-22'::timestamptz union all
select (select id from a where rn=4), 'biofilm','critical','drain elbow','deep clean + ATP retest','closed','2026-01-24'::timestamptz union all
select (select id from a where rn=4), 'rust','high','frame corner','sand + epoxy coat','in_progress',null union all
select (select id from a where rn=6), 'condensation','medium','tray rails','dehumidify + insulate','closed','2026-01-30'::timestamptz union all
select (select id from a where rn=7), 'pest_evidence','critical','behind chamber','pest control + reseal','escalated',null union all
select (select id from a where rn=7), 'biofilm','high','interlock seal','dismantle + sanitize','in_progress',null union all
select (select id from a where rn=8), 'chipped_paint','low','door edge','touch-up paint','closed','2026-02-04'::timestamptz union all
select (select id from a where rn=9), 'seal_breach','high','lower gasket','replace urgently','closed','2026-05-04'::timestamptz union all
select (select id from a where rn=10), 'chipped_paint','medium','frame edge','sand + repaint','closed','2026-02-12'::timestamptz union all
select (select id from a where rn=12), 'seal_breach','medium','side gasket','replace + verify','closed','2026-02-15'::timestamptz union all
select (select id from a where rn=13), 'biofilm','critical','drain trap','full dismantle clean','escalated',null union all
select (select id from a where rn=13), 'rust','critical','base frame','replace frame section','open',null union all
select (select id from a where rn=13), 'grease','high','rail underside','degrease deep','in_progress',null union all
select (select id from a where rn=15), 'spillage','medium','tray catch','install drip tray','closed','2026-05-18'::timestamptz union all
select (select id from a where rn=15), 'grease','medium','door hinge','degrease + lubricate','closed','2026-05-18'::timestamptz union all
select (select id from a where rn=16), 'condensation','low','glass pane','adjust HVAC','closed','2026-02-25'::timestamptz union all
select (select id from a where rn=17), 'biofilm','medium','chamber wall','sanitize + recheck','in_progress',null union all
select (select id from a where rn=17), 'seal_breach','medium','top gasket','replace','open',null union all
select (select id from a where rn=11), 'spillage','low','tray edge','wipe protocol training','closed','2026-05-06'::timestamptz;

-- RPCs

create or replace function public.r3043_chain_rollup()
returns table(hospital_chain text, audits int, pass_count int, fail_count int, critical_count int, avg_atp numeric, avg_visual numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain,
    count(*)::int,
    (count(*) filter (where a.pass_status='pass'))::int,
    (count(*) filter (where a.pass_status='fail'))::int,
    (count(*) filter (where a.pass_status='critical_fail'))::int,
    round(avg(a.swab_atp_rlu)::numeric,1),
    round(avg(a.visual_score)::numeric,2)
  from public.tray_window_audits_r3043 a
  group by a.hospital_chain
  order by critical_count desc, fail_count desc;
end;$$;

create or replace function public.r3043_branch_failures()
returns table(hospital_chain text, hospital_branch text, city text, pass_status text, swab_atp_rlu int, gasket_integrity_pct int, audit_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain, a.hospital_branch, a.city, a.pass_status, a.swab_atp_rlu, a.gasket_integrity_pct, a.audit_date
  from public.tray_window_audits_r3043 a
  where a.pass_status in ('fail','critical_fail')
  order by a.swab_atp_rlu desc;
end;$$;

create or replace function public.r3043_zone_hygiene()
returns table(window_zone text, audits int, avg_atp numeric, avg_gasket numeric, fail_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.window_zone,
    count(*)::int,
    round(avg(a.swab_atp_rlu)::numeric,1),
    round(avg(a.gasket_integrity_pct)::numeric,1),
    round((100.0 * (count(*) filter (where a.pass_status in ('fail','critical_fail'))) / nullif(count(*),0))::numeric,1)
  from public.tray_window_audits_r3043 a
  group by a.window_zone
  order by fail_rate_pct desc;
end;$$;

create or replace function public.r3043_findings_by_category()
returns table(finding_category text, total int, critical_count int, open_count int, closed_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_category,
    count(*)::int,
    (count(*) filter (where f.severity='critical'))::int,
    (count(*) filter (where f.closure_status='open'))::int,
    (count(*) filter (where f.closure_status='closed'))::int
  from public.tray_window_findings_r3043 f
  group by f.finding_category
  order by critical_count desc, total desc;
end;$$;

create or replace function public.r3043_open_escalations()
returns table(hospital_chain text, hospital_branch text, finding_category text, severity text, location_detail text, recommended_action text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain, a.hospital_branch, f.finding_category, f.severity, f.location_detail, f.recommended_action
  from public.tray_window_findings_r3043 f
  join public.tray_window_audits_r3043 a on a.id=f.audit_id
  where f.closure_status in ('open','escalated','in_progress')
  order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end;$$;

create or replace function public.r3043_quarter_trend()
returns table(quarter text, audits int, avg_atp numeric, pass_rate_pct numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.quarter,
    count(*)::int,
    round(avg(a.swab_atp_rlu)::numeric,1),
    round((100.0 * (count(*) filter (where a.pass_status='pass')) / nullif(count(*),0))::numeric,1),
    (count(*) filter (where a.pass_status='critical_fail'))::int
  from public.tray_window_audits_r3043 a
  group by a.quarter
  order by a.quarter;
end;$$;

create or replace function public.r3043_city_leaderboard()
returns table(city text, audits int, avg_visual numeric, avg_sanitizer numeric, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.city,
    count(*)::int,
    round(avg(a.visual_score)::numeric,2),
    round(avg(a.sanitizer_residue_ppm)::numeric,2),
    (count(*) filter (where a.pass_status in ('fail','critical_fail')))::int
  from public.tray_window_audits_r3043 a
  group by a.city
  order by fail_count desc, avg_visual asc;
end;$$;

revoke all on function public.r3043_chain_rollup() from public, anon;
revoke all on function public.r3043_branch_failures() from public, anon;
revoke all on function public.r3043_zone_hygiene() from public, anon;
revoke all on function public.r3043_findings_by_category() from public, anon;
revoke all on function public.r3043_open_escalations() from public, anon;
revoke all on function public.r3043_quarter_trend() from public, anon;
revoke all on function public.r3043_city_leaderboard() from public, anon;

grant execute on function public.r3043_chain_rollup() to authenticated;
grant execute on function public.r3043_branch_failures() to authenticated;
grant execute on function public.r3043_zone_hygiene() to authenticated;
grant execute on function public.r3043_findings_by_category() to authenticated;
grant execute on function public.r3043_open_escalations() to authenticated;
grant execute on function public.r3043_quarter_trend() to authenticated;
grant execute on function public.r3043_city_leaderboard() to authenticated;

revoke all on public.tray_window_audits_r3043 from public, anon;
revoke all on public.tray_window_findings_r3043 from public, anon;
grant select on public.tray_window_audits_r3043 to authenticated;
grant select on public.tray_window_findings_r3043 to authenticated;
