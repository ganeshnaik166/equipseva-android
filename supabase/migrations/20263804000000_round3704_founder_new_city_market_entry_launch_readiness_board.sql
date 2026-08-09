-- Round 3704: Founder New-City Market-Entry / Launch-Readiness Board
-- Market-entry governance — city × launch wave × period × engineer hiring × demand pipeline × statutory registrations × warehouse readiness × readiness % × workstream status × CAPA

-- =============================================================================
-- TABLE 1: market_entry_r3704 — per-city per-workstream launch-readiness facts
-- =============================================================================
create table if not exists public.market_entry_r3704 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  city_name text not null,
  entry_ref text not null,
  launch_wave text not null,
  period_month date not null,
  target_launch_date date not null,
  days_to_launch int,
  engineers_hired int not null,
  engineers_target int not null,
  hiring_pct numeric(5,1),
  hospitals_prospected int not null,
  anchor_accounts_signed int not null,
  statutory_registrations_pct numeric(5,1),
  warehouse_ready boolean not null,
  readiness_pct numeric(5,1),
  workstream text not null check (workstream in (
    'hiring','demand_pipeline','statutory','warehouse_logistics','marketing_launch'
  )),
  readiness_status text not null check (readiness_status in (
    'on_track','ahead','at_risk','blocked','launched'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.market_entry_r3704 enable row level security;

create index if not exists idx_market_entry_r3704_org on public.market_entry_r3704(organization_id);
create index if not exists idx_market_entry_r3704_month on public.market_entry_r3704(period_month);
create index if not exists idx_market_entry_r3704_status on public.market_entry_r3704(readiness_status);

-- =============================================================================
-- TABLE 2: market_entry_capa_actions_r3704 — CAPA & launch-blocker actions
-- =============================================================================
create table if not exists public.market_entry_capa_actions_r3704 (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.market_entry_r3704(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'engineer_hiring_shortfall','anchor_account_slippage','statutory_registration_delay',
    'warehouse_fitout_delay','spare_parts_stocking_gap','launch_marketing_delay',
    'pricing_approval_pending','logistics_partner_gap'
  )),
  root_cause text not null check (root_cause in (
    'talent_market_shortage','offer_dropouts','gst_registration_backlog',
    'shop_establishment_license_delay','landlord_negotiation_stalled','vendor_fitout_slippage',
    'budget_approval_pending','anchor_hospital_procurement_cycle',
    'local_agency_underperformance','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'engage_recruitment_agency','revise_compensation_band','expedite_statutory_filing',
    'appoint_local_consultant','switch_warehouse_vendor','sign_backup_logistics_partner',
    'escalate_to_founder_office','rephase_launch_wave','add_field_sales_support','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  delay_impact_days numeric(6,1),
  owner_name text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.market_entry_capa_actions_r3704 enable row level security;

create index if not exists idx_market_entry_capa_r3704_entry on public.market_entry_capa_actions_r3704(entry_id);
create index if not exists idx_market_entry_capa_r3704_status on public.market_entry_capa_actions_r3704(capa_status);

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

  -- 16 launch-readiness rows
  insert into public.market_entry_r3704 (
    organization_id, city_name, entry_ref, launch_wave, period_month,
    target_launch_date, days_to_launch, engineers_hired, engineers_target, hiring_pct,
    hospitals_prospected, anchor_accounts_signed, statutory_registrations_pct,
    warehouse_ready, readiness_pct, workstream, readiness_status, trend_dir, notes
  )
  select v_org_id, q.city, q.eref, q.wave, q.pm::date,
    q.tld::date, q.dtl, q.ehired, q.etgt, q.hpct,
    q.hprosp, q.anch, q.spct,
    q.whrdy, q.rpct, q.wstream, q.rstat, q.tdir, q.nt
  from (values
    ('Pune','ME-PUN-01','wave_1','2026-07-01','2026-08-15',38,9,10,90.0,34,5,100.0,true,92.5,
     'hiring','on_track','improving','Pune hiring nearly complete — 9 of 10 engineers onboarded'),
    ('Pune','ME-PUN-02','wave_1','2026-07-01','2026-08-15',38,9,10,90.0,34,5,100.0,true,88.0,
     'demand_pipeline','ahead','improving','Anchor accounts ahead of plan — Ruby Hall and Sahyadri signed'),
    ('Kochi','ME-KOC-01','wave_1','2026-07-01','2026-08-20',43,6,8,75.0,22,3,80.0,true,78.5,
     'statutory','on_track','stable','Kochi GST and shop-establishment filings on schedule'),
    ('Kochi','ME-KOC-02','wave_1','2026-07-01','2026-08-20',43,6,8,75.0,22,3,80.0,true,81.0,
     'warehouse_logistics','on_track','improving','Warehouse fit-out complete — spare-parts stocking underway'),
    ('Jaipur','ME-JAI-01','wave_2','2026-07-01','2026-09-10',64,3,8,37.5,18,2,60.0,false,52.0,
     'hiring','at_risk','worsening','Two offer dropouts in Jaipur — hiring at 37.5% of plan'),
    ('Jaipur','ME-JAI-02','wave_2','2026-07-01','2026-09-10',64,3,8,37.5,18,2,60.0,false,55.5,
     'warehouse_logistics','at_risk','stable','Landlord negotiation stalled on Sitapura warehouse'),
    ('Lucknow','ME-LKO-01','wave_2','2026-07-01','2026-09-15',69,4,8,50.0,15,1,40.0,false,44.0,
     'statutory','blocked','worsening','Shop & establishment license stuck at district office'),
    ('Lucknow','ME-LKO-02','wave_2','2026-07-01','2026-09-15',69,4,8,50.0,15,1,40.0,false,48.5,
     'demand_pipeline','at_risk','stable','Anchor hospital procurement cycle slipped a quarter'),
    ('Indore','ME-IND-01','wave_2','2026-07-01','2026-09-05',59,5,6,83.3,20,3,90.0,true,84.0,
     'hiring','on_track','improving','Indore hiring on track — final offer in acceptance stage'),
    ('Indore','ME-IND-02','wave_2','2026-07-01','2026-09-05',59,5,6,83.3,20,3,90.0,true,86.5,
     'marketing_launch','ahead','improving','Launch event and dealer meet booked ahead of schedule'),
    ('Nagpur','ME-NAG-01','wave_3','2026-06-01','2026-10-01',85,2,6,33.3,12,1,30.0,false,38.0,
     'hiring','at_risk','stable','Nagpur talent pool thin — recruitment agency engaged'),
    ('Nagpur','ME-NAG-02','wave_3','2026-06-01','2026-10-01',85,2,6,33.3,12,1,30.0,false,35.5,
     'statutory','on_track','stable','Registrations filed — awaiting GST ARN confirmation'),
    ('Coimbatore','ME-CBE-01','wave_3','2026-06-01','2026-10-10',94,1,6,16.7,10,0,25.0,false,28.0,
     'demand_pipeline','at_risk','worsening','Prospecting slow — only 10 hospitals mapped, no anchor signed'),
    ('Coimbatore','ME-CBE-02','wave_3','2026-06-01','2026-10-10',94,1,6,16.7,10,0,25.0,false,30.5,
     'marketing_launch','on_track','stable','Launch collateral in design — vernacular assets pending'),
    ('Bhubaneswar','ME-BBS-01','wave_3','2026-06-01','2026-10-20',104,0,5,0.0,8,0,15.0,false,18.0,
     'hiring','blocked','worsening','No engineer offers out — compensation band under review'),
    ('Ahmedabad','ME-AMD-01','wave_1','2026-06-01','2026-07-15',7,8,8,100.0,30,6,100.0,true,100.0,
     'marketing_launch','launched','stable','Ahmedabad went live — launch event done, first AMC signed')
  ) as q(city, eref, wave, pm, tld, dtl, ehired, etgt, hpct, hprosp, anch, spct, whrdy, rpct, wstream, rstat, tdir, nt);

  -- CAPA seed — attach to specific readiness rows via entry_ref
  insert into public.market_entry_capa_actions_r3704 (
    entry_id, finding_category, root_cause, corrective_action,
    capa_status, delay_impact_days, owner_name,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.dly, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('ME-JAI-01','engineer_hiring_shortfall','offer_dropouts','revise_compensation_band',
     'in_progress',12.0,'Ravi Deshmukh','2026-08-20',null,'Revised band approved — re-offers going out this week'),
    ('ME-JAI-02','warehouse_fitout_delay','landlord_negotiation_stalled','switch_warehouse_vendor',
     'open',10.0,'Meera Nair','2026-08-25',null,'Backup site in Mansarovar shortlisted for inspection'),
    ('ME-LKO-01','statutory_registration_delay','shop_establishment_license_delay','appoint_local_consultant',
     'escalated',21.0,'Arjun Saxena','2026-08-18',null,'District-office follow-up escalated to founder office'),
    ('ME-LKO-02','anchor_account_slippage','anchor_hospital_procurement_cycle','add_field_sales_support',
     'in_progress',14.0,'Kavita Rao','2026-08-30',null,'Second field-sales engineer deployed to Lucknow'),
    ('ME-NAG-01','engineer_hiring_shortfall','talent_market_shortage','engage_recruitment_agency',
     'verification_pending',7.0,'Ravi Deshmukh','2026-08-15',null,'Agency shortlist of six candidates in interview loop'),
    ('ME-CBE-01','anchor_account_slippage','local_agency_underperformance','escalate_to_founder_office',
     'open',9.0,'Suresh Iyer','2026-09-05',null,'Prospecting agency put on notice — weekly review started'),
    ('ME-BBS-01','engineer_hiring_shortfall','budget_approval_pending','rephase_launch_wave',
     'overdue',30.0,'Meera Nair','2026-08-01',null,'Bhubaneswar rephased pending budget sign-off'),
    ('ME-KOC-02','spare_parts_stocking_gap','vendor_fitout_slippage','sign_backup_logistics_partner',
     'closed',3.0,'Arjun Saxena','2026-07-25','2026-07-20','Backup 3PL signed — stocking completed early')
  ) as q(eref, fc, rc, ca, cst, dly, ownr, tcd, acd, nt)
  join public.market_entry_r3704 e
    on e.organization_id = v_org_id and e.entry_ref = q.eref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness-status distribution
create or replace function public.founder_r3704_readiness_status_rollup()
returns table(readiness_status text, entries bigint, avg_readiness_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.market_entry_r3704)
  select l.readiness_status, count(*)::bigint,
         round(avg(l.readiness_pct), 1),
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.market_entry_r3704 l
  group by l.readiness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3704_readiness_status_rollup() from public, anon;
grant execute on function public.founder_r3704_readiness_status_rollup() to authenticated;

-- 2) Launch-wave scorecard
create or replace function public.founder_r3704_launch_wave_scorecard()
returns table(
  launch_wave text,
  entries bigint,
  on_track bigint,
  ahead bigint,
  at_risk bigint,
  blocked bigint,
  launched bigint,
  avg_readiness_pct numeric,
  avg_hiring_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.launch_wave,
    count(*)::bigint,
    count(*) filter (where l.readiness_status = 'on_track')::bigint,
    count(*) filter (where l.readiness_status = 'ahead')::bigint,
    count(*) filter (where l.readiness_status = 'at_risk')::bigint,
    count(*) filter (where l.readiness_status = 'blocked')::bigint,
    count(*) filter (where l.readiness_status = 'launched')::bigint,
    round(avg(l.readiness_pct), 1),
    round(avg(l.hiring_pct), 1)
  from public.market_entry_r3704 l
  group by l.launch_wave
  order by l.launch_wave;
end;
$$;

revoke all on function public.founder_r3704_launch_wave_scorecard() from public, anon;
grant execute on function public.founder_r3704_launch_wave_scorecard() to authenticated;

-- 3) Workstream × readiness-status matrix
create or replace function public.founder_r3704_workstream_status_matrix()
returns table(workstream text, readiness_status text, entries bigint, avg_readiness_pct numeric, worsening bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.workstream, l.readiness_status, count(*)::bigint,
    round(avg(l.readiness_pct), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.market_entry_r3704 l
  group by l.workstream, l.readiness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3704_workstream_status_matrix() from public, anon;
grant execute on function public.founder_r3704_workstream_status_matrix() to authenticated;

-- 4) Monthly readiness trend
create or replace function public.founder_r3704_monthly_readiness_trend()
returns table(period_month date, entries bigint, avg_readiness_pct numeric, avg_hiring_pct numeric, at_risk bigint, blocked bigint, launched bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.readiness_pct), 1),
    round(avg(l.hiring_pct), 1),
    count(*) filter (where l.readiness_status = 'at_risk')::bigint,
    count(*) filter (where l.readiness_status = 'blocked')::bigint,
    count(*) filter (where l.readiness_status = 'launched')::bigint
  from public.market_entry_r3704 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3704_monthly_readiness_trend() from public, anon;
grant execute on function public.founder_r3704_monthly_readiness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3704_capa_status_board()
returns table(capa_status text, findings bigint, avg_delay_impact_days numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.delay_impact_days)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.market_entry_capa_actions_r3704 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3704_capa_status_board() from public, anon;
grant execute on function public.founder_r3704_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3704_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_delay_days numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.market_entry_capa_actions_r3704)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.delay_impact_days),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.market_entry_capa_actions_r3704 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3704_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3704_root_cause_pareto() to authenticated;

-- 7) Blocker digest (by finding category)
create or replace function public.founder_r3704_blocker_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_delay_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.delay_impact_days),0)::numeric
  from public.market_entry_capa_actions_r3704 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3704_blocker_digest() from public, anon;
grant execute on function public.founder_r3704_blocker_digest() to authenticated;

-- 8) High-risk queue (blocked / at-risk / worsening cities)
create or replace function public.founder_r3704_high_risk_queue()
returns table(
  city_name text,
  entry_ref text,
  launch_wave text,
  workstream text,
  target_launch_date date,
  days_to_launch int,
  readiness_pct numeric,
  readiness_status text,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.city_name, l.entry_ref, l.launch_wave, l.workstream, l.target_launch_date,
    l.days_to_launch, l.readiness_pct, l.readiness_status, l.trend_dir, l.notes
  from public.market_entry_r3704 l
  where l.readiness_status in ('blocked','at_risk')
     or l.trend_dir = 'worsening'
     or l.warehouse_ready = false
     or l.hiring_pct < 50.0
  order by l.readiness_pct asc, l.city_name;
end;
$$;

revoke all on function public.founder_r3704_high_risk_queue() from public, anon;
grant execute on function public.founder_r3704_high_risk_queue() to authenticated;
