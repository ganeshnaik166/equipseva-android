-- Round 3691: Founder Office HVAC / Split-AC AMC & Service Board
-- Own-premises comfort HVAC — unit class × site × AMC validity × service compliance × gas top-ups × breakdowns × repair turnaround × CAPA

-- =============================================================================
-- TABLE 1: office_hvac_r3691 — per-unit monthly HVAC / split-AC AMC & service log
-- =============================================================================
create table if not exists public.office_hvac_r3691 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  unit_code text not null,
  site_name text not null,
  period_month date not null,
  unit_capacity_tr numeric(5,2),
  amc_valid_till date,
  days_to_amc_expiry int,
  services_due int not null default 0,
  services_done int not null default 0,
  service_pct numeric(5,1),
  gas_topups int not null default 0,
  breakdowns int not null default 0,
  avg_repair_days numeric(5,2),
  energy_rating text,
  unit_class text not null check (unit_class in (
    'split_ac','cassette_ac','ducted_package','vrf_indoor','window_ac'
  )),
  service_status text not null check (service_status in (
    'current','service_due','amc_expiring','breakdown_prone','out_of_service'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.office_hvac_r3691 enable row level security;

create index if not exists idx_office_hvac_r3691_org on public.office_hvac_r3691(organization_id);
create index if not exists idx_office_hvac_r3691_month on public.office_hvac_r3691(period_month);
create index if not exists idx_office_hvac_r3691_status on public.office_hvac_r3691(service_status);

-- =============================================================================
-- TABLE 2: office_hvac_capa_actions_r3691 — CAPA actions on HVAC units
-- =============================================================================
create table if not exists public.office_hvac_capa_actions_r3691 (
  id uuid primary key default gen_random_uuid(),
  hvac_unit_id uuid not null references public.office_hvac_r3691(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'gas_leak','compressor_wear','pcb_failure','clogged_filter_coil',
    'condenser_fan_fault','drain_blockage','vendor_no_show','power_fluctuation',
    'unit_end_of_life','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'gas_recharge_leak_fix','compressor_replacement','pcb_replacement',
    'deep_coil_cleaning','fan_motor_replacement','drain_line_clearing',
    'vendor_escalation','install_stabilizer','unit_replacement','renew_amc','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.office_hvac_capa_actions_r3691 enable row level security;

create index if not exists idx_office_hvac_capa_r3691_unit on public.office_hvac_capa_actions_r3691(hvac_unit_id);
create index if not exists idx_office_hvac_capa_r3691_status on public.office_hvac_capa_actions_r3691(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Service status distribution
create or replace function public.founder_r3691_service_status_rollup()
returns table(service_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.office_hvac_r3691)
  select l.service_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.office_hvac_r3691 l
  group by l.service_status
  order by count(*) desc;
end;
$$;

-- 2) Site scorecard
create or replace function public.founder_r3691_site_scorecard()
returns table(
  site_name text,
  total_units bigint,
  current_units bigint,
  service_due_units bigint,
  amc_expiring_units bigint,
  breakdown_prone_units bigint,
  out_of_service_units bigint,
  total_breakdowns bigint,
  avg_service_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.service_status = 'current')::bigint,
    count(*) filter (where l.service_status = 'service_due')::bigint,
    count(*) filter (where l.service_status = 'amc_expiring')::bigint,
    count(*) filter (where l.service_status = 'breakdown_prone')::bigint,
    count(*) filter (where l.service_status = 'out_of_service')::bigint,
    coalesce(sum(l.breakdowns),0)::bigint,
    round(avg(l.service_pct), 1)
  from public.office_hvac_r3691 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Unit class × service status matrix
create or replace function public.founder_r3691_unit_class_status_matrix()
returns table(unit_class text, service_status text, units bigint, total_breakdowns bigint, avg_service_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_class, l.service_status, count(*)::bigint,
    coalesce(sum(l.breakdowns),0)::bigint,
    round(avg(l.service_pct), 1)
  from public.office_hvac_r3691 l
  group by l.unit_class, l.service_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly service trend
create or replace function public.founder_r3691_monthly_service_trend()
returns table(period_month date, units bigint, services_due bigint, services_done bigint, avg_service_pct numeric, gas_topups bigint, breakdowns bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.services_due),0)::bigint,
    coalesce(sum(l.services_done),0)::bigint,
    round(avg(l.service_pct), 1),
    coalesce(sum(l.gas_topups),0)::bigint,
    coalesce(sum(l.breakdowns),0)::bigint
  from public.office_hvac_r3691 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3691_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.office_hvac_capa_actions_r3691 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3691_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.office_hvac_capa_actions_r3691)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.office_hvac_capa_actions_r3691 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Breakdown & gas top-up digest by site
create or replace function public.founder_r3691_breakdown_digest()
returns table(site_name text, units bigint, total_breakdowns bigint, total_gas_topups bigint, avg_repair_days numeric, worsening_units bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.breakdowns),0)::bigint,
    coalesce(sum(l.gas_topups),0)::bigint,
    round(avg(l.avg_repair_days), 2),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.office_hvac_r3691 l
  group by l.site_name
  order by coalesce(sum(l.breakdowns),0) desc;
end;
$$;

-- 8) High-risk unit queue (out_of_service / breakdown_prone / AMC cliff)
create or replace function public.founder_r3691_high_risk_queue()
returns table(
  unit_code text,
  site_name text,
  unit_class text,
  period_month date,
  service_status text,
  trend_dir text,
  breakdowns int,
  gas_topups int,
  avg_repair_days numeric,
  days_to_amc_expiry int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_code, l.site_name, l.unit_class, l.period_month,
    l.service_status, l.trend_dir, l.breakdowns, l.gas_topups,
    l.avg_repair_days, l.days_to_amc_expiry, l.notes
  from public.office_hvac_r3691 l
  where l.service_status in ('out_of_service','breakdown_prone')
     or l.breakdowns >= 2
     or (l.days_to_amc_expiry is not null and l.days_to_amc_expiry <= 45)
  order by l.breakdowns desc, l.days_to_amc_expiry asc, l.unit_code;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3691_service_status_rollup() from public, anon;
revoke all on function public.founder_r3691_site_scorecard() from public, anon;
revoke all on function public.founder_r3691_unit_class_status_matrix() from public, anon;
revoke all on function public.founder_r3691_monthly_service_trend() from public, anon;
revoke all on function public.founder_r3691_capa_status_board() from public, anon;
revoke all on function public.founder_r3691_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3691_breakdown_digest() from public, anon;
revoke all on function public.founder_r3691_high_risk_queue() from public, anon;

grant execute on function public.founder_r3691_service_status_rollup() to authenticated;
grant execute on function public.founder_r3691_site_scorecard() to authenticated;
grant execute on function public.founder_r3691_unit_class_status_matrix() to authenticated;
grant execute on function public.founder_r3691_monthly_service_trend() to authenticated;
grant execute on function public.founder_r3691_capa_status_board() to authenticated;
grant execute on function public.founder_r3691_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3691_breakdown_digest() to authenticated;
grant execute on function public.founder_r3691_high_risk_queue() to authenticated;

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 HVAC unit-month rows
  insert into public.office_hvac_r3691 (
    organization_id, unit_code, site_name, period_month, unit_capacity_tr,
    amc_valid_till, days_to_amc_expiry, services_due, services_done, service_pct,
    gas_topups, breakdowns, avg_repair_days, energy_rating,
    unit_class, service_status, trend_dir, notes
  )
  select v_org_id, q.ucode, q.site, q.pmon::date, q.cap,
    q.amcv::date, q.dexp, q.sdue, q.sdone, q.spct,
    q.gtop, q.brk, q.ardays, q.erate,
    q.ucls, q.sstat, q.tdir, q.nt
  from (values
    ('AC-MUM-01','Mumbai HQ','2026-07-01',1.5,'2027-03-31',238,2,2,100.0,
     0,0,null,'5_star','split_ac','current','stable','Reception split AC — both AMC services done on schedule'),
    ('AC-MUM-02','Mumbai HQ','2026-07-01',2.0,'2026-08-20',45,2,1,50.0,
     1,1,1.5,'3_star','split_ac','amc_expiring','worsening','Server room backup AC — Voltas AMC renewal quote awaited'),
    ('CAS-MUM-03','Mumbai HQ','2026-07-01',3.0,'2027-01-15',163,2,2,100.0,
     0,0,null,'4_star','cassette_ac','current','improving','Boardroom cassette unit cooling well post deep-clean'),
    ('VRF-MUM-04','Mumbai HQ','2026-07-01',1.8,'2027-03-31',238,3,2,66.7,
     0,1,2.0,'inverter_5_star','vrf_indoor','service_due','stable','Third-floor VRF indoor unit — one Blue Star service visit pending'),
    ('AC-MUM-05','Mumbai HQ','2026-06-01',1.5,'2027-03-31',268,2,2,100.0,
     0,1,1.0,'4_star','split_ac','current','stable','Finance bay AC — minor drain fix during June service'),
    ('AC-CHN-01','Chennai Branch','2026-07-01',1.5,'2026-09-10',66,2,2,100.0,
     1,0,null,'3_star','split_ac','current','stable','Branch manager cabin AC — R32 gas topped up during service'),
    ('AC-CHN-02','Chennai Branch','2026-07-01',2.0,'2026-08-05',30,2,1,50.0,
     2,3,3.5,'2_star','split_ac','breakdown_prone','worsening','Demo-area split AC — three breakdowns this quarter, leak suspected'),
    ('WIN-CHN-03','Chennai Branch','2026-07-01',1.0,'2026-07-31',25,2,1,50.0,
     0,1,4.0,'2_star','window_ac','amc_expiring','worsening','Pantry window AC — AMC expiring, replacement proposed'),
    ('AC-CHN-04','Chennai Branch','2026-06-01',1.5,'2026-09-10',96,2,1,50.0,
     1,1,2.0,'3_star','split_ac','service_due','stable','Training room AC — June service rescheduled after voltage trip'),
    ('DUC-DEL-01','Delhi Warehouse','2026-07-01',8.5,'2027-02-28',209,4,3,75.0,
     1,1,2.5,'3_star','ducted_package','service_due','stable','Warehouse office ducted package — quarterly filter service slipped'),
    ('AC-DEL-02','Delhi Warehouse','2026-07-01',2.0,'2026-12-31',150,2,2,100.0,
     0,0,null,'5_star','split_ac','current','improving','Dispatch office split AC nominal after coil cleaning'),
    ('AC-DEL-03','Delhi Warehouse','2026-07-01',1.5,'2026-08-15',40,2,0,0.0,
     1,2,6.0,'3_star','split_ac','out_of_service','worsening','Security cabin AC compressor seized — unit down, spare awaited'),
    ('DUC-DEL-04','Delhi Warehouse','2026-06-01',11.0,'2027-02-28',239,4,4,100.0,
     0,0,null,'3_star','ducted_package','current','improving','Main warehouse ducted package — Carrier vendor completed all visits'),
    ('CAS-BLR-01','Bengaluru Refurb Center','2026-07-01',3.0,'2027-04-30',268,2,2,100.0,
     0,0,null,'4_star','cassette_ac','current','stable','Refurb lab cassette AC — coil cleaned and filters replaced'),
    ('AC-BLR-02','Bengaluru Refurb Center','2026-07-01',2.0,'2026-10-31',89,2,1,50.0,
     1,2,2.8,'3_star','split_ac','breakdown_prone','worsening','ESD room split AC tripping intermittently — inverter PCB suspected'),
    ('VRF-BLR-03','Bengaluru Refurb Center','2026-07-01',1.8,'2027-04-30',268,3,3,100.0,
     0,0,null,'inverter_5_star','vrf_indoor','current','improving','Calibration bay VRF indoor unit — all AMC services completed')
  ) as q(ucode, site, pmon, cap, amcv, dexp, sdue, sdone, spct, gtop, brk, ardays, erate, ucls, sstat, tdir, nt);

  -- 8 CAPA rows — attach to units via unit_code
  insert into public.office_hvac_capa_actions_r3691 (
    hvac_unit_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('AC-DEL-03','compressor_wear','compressor_replacement','in_progress',24500.00,'Admin - Delhi','2026-07-20',null,'Compressor ordered from Voltas dealer — installation this week'),
    ('AC-CHN-02','gas_leak','gas_recharge_leak_fix','verification_pending',6800.00,'Admin - Chennai','2026-07-12',null,'Leak brazed and R32 recharged — verify cooling for a week'),
    ('AC-BLR-02','pcb_failure','pcb_replacement','open',9200.00,'Facilities - Bengaluru','2026-07-25',null,'Inverter PCB quote received from Blue Star authorised service partner'),
    ('WIN-CHN-03','unit_end_of_life','unit_replacement','escalated',32000.00,'Admin - Chennai','2026-07-15',null,'Window unit beyond economic repair — capex approval pending'),
    ('AC-MUM-02','vendor_no_show','vendor_escalation','overdue',0.00,'Facilities - Mumbai','2026-07-05',null,'AMC vendor missed two service slots — penalty clause invoked'),
    ('DUC-DEL-01','clogged_filter_coil','deep_coil_cleaning','closed',4500.00,'Admin - Delhi','2026-07-08','2026-07-06','Duct filters and coil deep-cleaned — airflow restored'),
    ('VRF-MUM-04','drain_blockage','drain_line_clearing','closed',1200.00,'Facilities - Mumbai','2026-07-04','2026-07-03','Drain line flushed — ceiling seepage stopped'),
    ('AC-CHN-04','power_fluctuation','install_stabilizer','in_progress',5600.00,'Admin - Chennai','2026-07-18',null,'Voltage stabilizer ordered for training room circuit')
  ) as q(ucode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.office_hvac_r3691 e
    on e.organization_id = v_org_id and e.unit_code = q.ucode;
end;
$seed$;
