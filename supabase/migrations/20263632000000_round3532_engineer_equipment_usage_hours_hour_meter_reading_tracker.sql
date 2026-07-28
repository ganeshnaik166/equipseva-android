-- Round 3532: Engineer Equipment Usage-Hours / Hour-Meter Reading Tracker
-- Usage-based PM trigger tracker — meter type × device model × current/previous reading ×
-- usage-since-PM × PM threshold × % to threshold × usage status × PM-triggered flag × CAPA

-- =============================================================================
-- TABLE 1: usage_hours_meter_r3532 — per-asset hour-meter / usage reading log
-- =============================================================================
create table if not exists public.usage_hours_meter_r3532 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  asset_tag text not null,
  meter_type text not null check (meter_type in (
    'run_hours','cycle_count','shots','patient_count','km','print_hours'
  )),
  current_reading numeric(12,2) not null,
  previous_reading numeric(12,2),
  usage_since_pm numeric(12,2),
  pm_threshold numeric(12,2),
  pct_to_threshold numeric(6,2),
  usage_status text not null check (usage_status in (
    'normal','approaching','due','overdue','over_utilized'
  )),
  reading_date date not null,
  pm_triggered boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.usage_hours_meter_r3532 enable row level security;

create index if not exists idx_usage_hours_meter_r3532_org on public.usage_hours_meter_r3532(organization_id);
create index if not exists idx_usage_hours_meter_r3532_date on public.usage_hours_meter_r3532(reading_date);
create index if not exists idx_usage_hours_meter_r3532_status on public.usage_hours_meter_r3532(usage_status);

-- =============================================================================
-- TABLE 2: usage_hours_meter_capa_actions_r3532 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.usage_hours_meter_capa_actions_r3532 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  meter_log_id uuid not null references public.usage_hours_meter_r3532(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pm_overdue','over_utilization','threshold_reached','reading_gap_anomaly',
    'meter_rollover','duty_cycle_exceeded','usage_spike','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'high_case_load','deferred_pm_backlog','meter_reset_error','manual_reading_error',
    'device_overuse','staffing_shortage','pending_investigation','scheduling_conflict','parts_unavailable'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_pm','perform_pm_now','redistribute_load','recalibrate_meter','retrain_operator',
    'order_consumables','extend_amc_coverage','decommission_device','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  utilization_impact text not null check (utilization_impact in (
    'unplanned_downtime_risk','warranty_void_risk','none','sla_breach_risk',
    'patient_safety_risk','capacity_bottleneck'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.usage_hours_meter_capa_actions_r3532 enable row level security;

create index if not exists idx_usage_hours_meter_capa_r3532_log on public.usage_hours_meter_capa_actions_r3532(meter_log_id);
create index if not exists idx_usage_hours_meter_capa_r3532_status on public.usage_hours_meter_capa_actions_r3532(capa_status);

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

  -- 16 meter-reading rows
  insert into public.usage_hours_meter_r3532 (
    organization_id, engineer_name, hospital_name, device_model, asset_tag, meter_type,
    current_reading, previous_reading, usage_since_pm, pm_threshold, pct_to_threshold,
    usage_status, reading_date, pm_triggered, notes
  )
  select v_org_id, q.eng, q.hosp, q.model, q.tag, q.mtype,
    q.cread, q.pread, q.usince, q.thresh, q.pct,
    q.status, q.rdate::date, q.pmtrig, q.nt
  from (values
    ('Ramesh Kumar','Apollo Chennai','Maquet Servo-i Ventilator','VENT-APL-01','run_hours',
     5200,4800,400,500,80.0,'approaching','2026-07-10',false,'Ventilator run-hours nearing 500h PM interval'),
    ('Ramesh Kumar','Apollo Chennai','Drager Fabius Anesthesia','ANES-APL-02','run_hours',
     9800,9000,800,750,106.7,'overdue','2026-07-10',true,'Anesthesia machine past 750h PM threshold — PM auto-triggered'),
    ('Suresh Nair','Fortis Gurgaon','GE Optima CT Tube','CT-FRT-11','shots',
     195000,178000,17000,20000,85.0,'due','2026-07-08',false,'CT tube exposures reached PM band — schedule tube service'),
    ('Suresh Nair','Fortis Gurgaon','Siemens Ysio X-ray Tube','XRAY-FRT-12','shots',
     88000,86000,2000,8000,25.0,'normal','2026-06-28',false,'X-ray tube well within exposure PM interval'),
    ('Anil Verma','Manipal Bengaluru','Getinge HS66 Autoclave','AUTO-MNP-21','cycle_count',
     42000,40000,2000,2500,80.0,'approaching','2026-07-05',false,'Autoclave sterilization cycles approaching PM interval'),
    ('Anil Verma','Manipal Bengaluru','B.Braun Infusomat Pump','INFP-MNP-22','cycle_count',
     15600,14000,1600,1500,106.7,'overdue','2026-07-05',true,'Infusion pump cycle count over interval — PM triggered'),
    ('Priya Sharma','AIIMS Delhi','Fresenius 4008S Dialysis','DIAL-AIM-31','run_hours',
     12000,11000,1000,1200,83.3,'approaching','2026-06-20',false,'Dialysis machine run-hours nearing PM window'),
    ('Priya Sharma','AIIMS Delhi','Lumenis Surgical Laser','LASER-AIM-32','run_hours',
     3400,2800,600,500,120.0,'over_utilized','2026-06-20',true,'Surgical laser run-hours 120% of interval — heavy duty cycle'),
    ('Thomas Jacob','CMC Vellore','GE Voluson Ultrasound','USG-CMC-41','patient_count',
     48000,45000,3000,3500,85.7,'due','2026-06-15',false,'USG patient-count reached PM band — probe QC due'),
    ('Thomas Jacob','CMC Vellore','Philips Affiniti Ultrasound','USG-CMC-42','patient_count',
     22000,21500,500,4000,12.5,'normal','2026-05-30',false,'USG patient count low since last PM'),
    ('Rao Prasad','KIMS Hyderabad','Force Motors Ambulance','AMBU-KIM-51','km',
     128000,120000,8000,10000,80.0,'approaching','2026-07-02',false,'Ambulance km nearing PM service interval'),
    ('Rao Prasad','KIMS Hyderabad','Tata Winger Ambulance','AMBU-KIM-52','km',
     205000,193000,11500,10000,115.0,'overdue','2026-07-02',true,'Ambulance km past PM interval — service overdue'),
    ('Deepak Reddy','Yashoda Hyderabad','Carestream Dry Film Printer','FILM-YSH-61','print_hours',
     6200,5800,400,900,44.4,'normal','2026-06-10',false,'Dry film printer print-hours within PM interval'),
    ('Deepak Reddy','Yashoda Hyderabad','Canon Aquilion CT Tube','CT-YSH-62','shots',
     260000,238000,22000,20000,110.0,'over_utilized','2026-05-25',true,'CT tube exposures over interval — high duty cycle site'),
    ('Farhan Shaikh','Kokilaben Mumbai','Hamilton C6 Ventilator','VENT-KKB-71','run_hours',
     7400,7000,470,500,94.0,'due','2026-07-12',false,'Ventilator run-hours due PM — schedule within week'),
    ('Farhan Shaikh','Kokilaben Mumbai','Mindray BeneFusion Pump','INFP-KKB-72','cycle_count',
     9800,9600,200,1500,13.3,'normal','2026-06-05',false,'Infusion pump cycles low since last PM')
  ) as q(eng, hosp, model, tag, mtype, cread, pread, usince, thresh, pct, status, rdate, pmtrig, nt);

  -- CAPA seed — attach to specific meter rows via asset_tag
  insert into public.usage_hours_meter_capa_actions_r3532 (
    organization_id, meter_log_id, finding_category, root_cause, corrective_action,
    capa_status, utilization_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.organization_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ui, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ANES-APL-02','pm_overdue','deferred_pm_backlog','perform_pm_now','in_progress','unplanned_downtime_risk','Biomed Team A','2026-07-15',null,18000.00,'Anesthesia PM overdue by ~50h — engineer dispatched'),
    ('INFP-MNP-22','pm_overdue','high_case_load','schedule_pm','open','sla_breach_risk','Anil Verma','2026-07-14',null,4500.00,'Infusion pump cycle count over interval — batch PM planned'),
    ('LASER-AIM-32','over_utilization','device_overuse','redistribute_load','escalated','warranty_void_risk','Priya Sharma','2026-07-12',null,26000.00,'Surgical laser at 120% of interval — load rebalance escalated'),
    ('CT-FRT-11','threshold_reached','high_case_load','schedule_pm','open','capacity_bottleneck','Suresh Nair','2026-07-16',null,32000.00,'CT tube exposures at PM band — tube PM scheduled'),
    ('AMBU-KIM-52','pm_overdue','scheduling_conflict','perform_pm_now','verification_pending','sla_breach_risk','Fleet Cell','2026-07-11',null,9500.00,'Ambulance km past PM — service done, verifying readings'),
    ('CT-YSH-62','over_utilization','device_overuse','extend_amc_coverage','closed','warranty_void_risk','Deepak Reddy','2026-07-05','2026-07-09',54000.00,'CT tube over-utilized — AMC extended and tube PM completed'),
    ('VENT-KKB-71','threshold_reached','deferred_pm_backlog','schedule_pm','overdue','unplanned_downtime_risk','Farhan Shaikh','2026-07-06',null,7000.00,'Ventilator due PM slipped on scheduling — backlog cleared next'),
    ('USG-CMC-41','preventive_maintenance_due','manual_reading_error','recalibrate_meter','open','none','Thomas Jacob','2026-07-18',null,3000.00,'USG patient-count reading discrepancy — recount and recalibrate')
  ) as q(tag, fc, rc, ca, cst, ui, own, tcd, acd, cost, nt)
  join public.usage_hours_meter_r3532 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Usage-status distribution
create or replace function public.founder_r3532_usage_status_rollup()
returns table(usage_status text, meters bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.usage_hours_meter_r3532)
  select l.usage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.usage_hours_meter_r3532 l
  group by l.usage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_usage_status_rollup() from public, anon;
grant execute on function public.founder_r3532_usage_status_rollup() to authenticated;

-- 2) Device-model scorecard
create or replace function public.founder_r3532_device_model_scorecard()
returns table(
  device_model text,
  total_meters bigint,
  normal bigint,
  approaching bigint,
  due_cnt bigint,
  overdue bigint,
  over_utilized bigint,
  pm_triggered_cnt bigint,
  avg_pct_to_threshold numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.usage_status = 'normal')::bigint,
    count(*) filter (where l.usage_status = 'approaching')::bigint,
    count(*) filter (where l.usage_status = 'due')::bigint,
    count(*) filter (where l.usage_status = 'overdue')::bigint,
    count(*) filter (where l.usage_status = 'over_utilized')::bigint,
    count(*) filter (where l.pm_triggered = true)::bigint,
    round(avg(l.pct_to_threshold), 1)
  from public.usage_hours_meter_r3532 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3532_device_model_scorecard() to authenticated;

-- 3) Meter-type × usage-status matrix
create or replace function public.founder_r3532_meter_type_status_matrix()
returns table(meter_type text, usage_status text, meters bigint, avg_usage_since_pm numeric, avg_pct_to_threshold numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.meter_type, l.usage_status, count(*)::bigint,
    round(avg(l.usage_since_pm), 1),
    round(avg(l.pct_to_threshold), 1)
  from public.usage_hours_meter_r3532 l
  group by l.meter_type, l.usage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_meter_type_status_matrix() from public, anon;
grant execute on function public.founder_r3532_meter_type_status_matrix() to authenticated;

-- 4) Monthly usage trend
create or replace function public.founder_r3532_monthly_usage_trend()
returns table(reading_month text, meters bigint, pm_triggered_cnt bigint, due_or_overdue bigint, avg_pct_to_threshold numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.reading_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.pm_triggered = true)::bigint,
    count(*) filter (where l.usage_status in ('due','overdue','over_utilized'))::bigint,
    round(avg(l.pct_to_threshold), 1)
  from public.usage_hours_meter_r3532 l
  group by to_char(l.reading_date, 'YYYY-MM')
  order by to_char(l.reading_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3532_monthly_usage_trend() from public, anon;
grant execute on function public.founder_r3532_monthly_usage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3532_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.usage_hours_meter_capa_actions_r3532 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_capa_status_board() from public, anon;
grant execute on function public.founder_r3532_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3532_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.usage_hours_meter_capa_actions_r3532)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.usage_hours_meter_capa_actions_r3532 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3532_root_cause_pareto() to authenticated;

-- 7) Utilization-impact digest
create or replace function public.founder_r3532_utilization_impact_digest()
returns table(utilization_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.utilization_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.usage_hours_meter_capa_actions_r3532 c
  group by c.utilization_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3532_utilization_impact_digest() from public, anon;
grant execute on function public.founder_r3532_utilization_impact_digest() to authenticated;

-- 8) High-risk usage queue (due / overdue / over-utilized / PM-triggered)
create or replace function public.founder_r3532_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  device_model text,
  asset_tag text,
  meter_type text,
  usage_status text,
  current_reading numeric,
  usage_since_pm numeric,
  pm_threshold numeric,
  pct_to_threshold numeric,
  reading_date date,
  pm_triggered boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.device_model, l.asset_tag, l.meter_type,
    l.usage_status, l.current_reading, l.usage_since_pm, l.pm_threshold, l.pct_to_threshold,
    l.reading_date, l.pm_triggered, l.notes
  from public.usage_hours_meter_r3532 l
  where l.usage_status in ('due','overdue','over_utilized')
     or l.pm_triggered = true
  order by l.pct_to_threshold desc nulls last, l.reading_date desc;
end;
$$;

revoke execute on function public.founder_r3532_high_risk_queue() from public, anon;
grant execute on function public.founder_r3532_high_risk_queue() to authenticated;
