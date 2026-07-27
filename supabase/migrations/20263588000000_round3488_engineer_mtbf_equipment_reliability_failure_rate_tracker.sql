-- Round 3488: Engineer MTBF / Equipment-Reliability Failure-Rate Tracker
-- Per device-model reliability — installed units × operating hours × failures × MTBF vs target ×
-- failure-rate/1000h × availability × reliability status × dominant failure mode × monthly trend × CAPA

-- =============================================================================
-- TABLE 1: mtbf_reliability_r3488 — per-device-model MTBF / failure-rate reliability
-- =============================================================================
create table if not exists public.mtbf_reliability_r3488 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  model_code text not null,
  device_model text not null,
  device_category text not null,
  installed_units int not null,
  operating_hours numeric(12,1) not null,
  failures int not null,
  mtbf_hours numeric(12,1) not null,
  target_mtbf_hours numeric(12,1) not null,
  failure_rate_per_1000h numeric(8,3),
  availability_pct numeric(5,2),
  reliability_status text not null check (reliability_status in (
    'excellent','acceptable','marginal','poor'
  )),
  dominant_failure_mode text not null check (dominant_failure_mode in (
    'electronic','mechanical','wear','software','power','sensor','user_induced'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mtbf_reliability_r3488 enable row level security;

create index if not exists idx_mtbf_reliability_r3488_org on public.mtbf_reliability_r3488(organization_id);
create index if not exists idx_mtbf_reliability_r3488_month on public.mtbf_reliability_r3488(period_month);
create index if not exists idx_mtbf_reliability_r3488_status on public.mtbf_reliability_r3488(reliability_status);

-- =============================================================================
-- TABLE 2: mtbf_reliability_capa_actions_r3488 — CAPA & reliability-improvement actions
-- =============================================================================
create table if not exists public.mtbf_reliability_capa_actions_r3488 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reliability_id uuid not null references public.mtbf_reliability_r3488(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'below_target_mtbf','high_failure_rate','low_availability','worsening_trend',
    'recurring_failure_mode','preventive_maintenance_gap','warranty_reliability_gap'
  )),
  root_cause text not null check (root_cause in (
    'component_wear_out','design_weakness','power_supply_fault','firmware_defect',
    'sensor_degradation','operator_misuse','environmental_stress','spare_parts_delay',
    'inadequate_preventive_maintenance','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_worn_components','vendor_design_escalation','install_power_conditioner',
    'firmware_upgrade','replace_sensor','operator_retraining','environmental_control',
    'expedite_spare_parts','revise_pm_schedule','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text not null,
  availability_impact_pct numeric(5,2),
  estimated_cost_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mtbf_reliability_capa_actions_r3488 enable row level security;

create index if not exists idx_mtbf_reliability_capa_r3488_link on public.mtbf_reliability_capa_actions_r3488(reliability_id);
create index if not exists idx_mtbf_reliability_capa_r3488_status on public.mtbf_reliability_capa_actions_r3488(capa_status);

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

  -- 16 device-model reliability rows
  insert into public.mtbf_reliability_r3488 (
    organization_id, model_code, device_model, device_category, installed_units,
    operating_hours, failures, mtbf_hours, target_mtbf_hours, failure_rate_per_1000h,
    availability_pct, reliability_status, dominant_failure_mode, period_month, trend_dir, notes
  )
  select v_org_id, q.mc, q.dm, q.dc, q.units::int,
    q.ophrs::numeric, q.fail::int, q.mtbf::numeric, q.tgt::numeric, q.frate::numeric,
    q.avail::numeric, q.rstat, q.fmode, q.pmonth::date, q.trend, q.nt
  from (values
    ('VNT-DRG-EVITA','Draeger Evita V500 Ventilator','ventilator',18,54000,6,9000,8000,0.111,
     99.2,'excellent','electronic','2026-07-01','stable','ICU ventilator fleet exceeding target MTBF'),
    ('VNT-HAM-C3','Hamilton C3 Ventilator','ventilator',12,33000,9,3667,5000,0.273,
     97.1,'marginal','power','2026-07-01','worsening','Repeated power-board resets, below target'),
    ('MON-PHL-MX40','Philips IntelliVue MX40 Monitor','patient_monitor',40,120000,10,12000,9000,0.083,
     99.5,'excellent','sensor','2026-07-01','improving','Telemetry monitors reliable post firmware update'),
    ('MON-MND-BEN','Mindray BeneVision N15 Monitor','patient_monitor',30,84000,18,4667,7000,0.214,
     98.0,'acceptable','sensor','2026-07-01','stable','SpO2 sensor-cable failures dominate mode'),
    ('INF-BBR-SPACE','B.Braun Infusomat Space Pump','infusion_pump',60,150000,42,3571,5000,0.280,
     97.6,'marginal','wear','2026-06-01','worsening','Pump-mechanism wear driving failure rate'),
    ('INF-BD-ALARIS','BD Alaris Infusion Pump','infusion_pump',50,130000,20,6500,5000,0.154,
     98.8,'acceptable','mechanical','2026-06-01','stable','Door-latch mechanicals occasionally fail'),
    ('DIA-FRE-4008','Fresenius 4008S Dialysis Machine','dialysis',14,42000,7,6000,6000,0.167,
     98.5,'acceptable','mechanical','2026-06-01','stable','Hydraulic-valve wear within tolerance'),
    ('DIA-NIP-SUR','Nipro Surdial Dialysis Machine','dialysis',10,26000,13,2000,5000,0.500,
     95.4,'poor','power','2026-06-01','worsening','Frequent PSU faults, well below target MTBF'),
    ('DEF-ZOL-RSER','Zoll R Series Defibrillator','defibrillator',22,44000,4,11000,8000,0.091,
     99.6,'excellent','electronic','2026-05-01','stable','Crash-cart defibrillators highly reliable'),
    ('DEF-PHL-XL','Philips HeartStart XL Defibrillator','defibrillator',16,30000,12,2500,7000,0.400,
     96.2,'poor','wear','2026-05-01','worsening','Battery and paddle wear failures recurrent'),
    ('ANS-GE-A5','GE Aisys CS2 Anesthesia Machine','anesthesia',12,36000,6,6000,7000,0.167,
     98.7,'acceptable','mechanical','2026-05-01','stable','Vaporizer seals need scheduled PM'),
    ('SYR-TRM-TE','Terumo TE-SS830 Syringe Pump','syringe_pump',45,108000,15,7200,5000,0.139,
     99.0,'excellent','user_induced','2026-05-01','improving','Occlusion alarms mostly operator loading errors'),
    ('IMG-GE-VIVID','GE Vivid E95 Ultrasound','imaging',8,20000,10,2000,6000,0.500,
     94.8,'poor','software','2026-04-01','worsening','Software lockups and probe faults dominate'),
    ('IMG-SAM-HS60','Samsung HS60 Ultrasound','imaging',6,15000,3,5000,6000,0.200,
     98.3,'acceptable','sensor','2026-04-01','stable','Transducer element degradation observed'),
    ('WRM-GE-GIRAF','GE Giraffe Infant Warmer','infant_warmer',10,26000,4,6500,6000,0.154,
     99.1,'excellent','sensor','2026-04-01','stable','Skin-probe replacements only, otherwise reliable'),
    ('SUC-DEV-VAC','Devilbiss Vacu-Aide Suction Unit','suction',20,40000,22,1818,4000,0.550,
     96.9,'poor','mechanical','2026-04-01','worsening','Motor-brush wear driving high failure count')
  ) as q(mc, dm, dc, units, ophrs, fail, mtbf, tgt, frate, avail, rstat, fmode, pmonth, trend, nt);

  -- CAPA seed — attach to specific device models via model_code business key
  insert into public.mtbf_reliability_capa_actions_r3488 (
    organization_id, reliability_id, finding_category, root_cause, corrective_action,
    capa_status, owner, availability_impact_pct, estimated_cost_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.owner, q.aimpact::numeric, q.cost::numeric,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('VNT-HAM-C3','below_target_mtbf','power_supply_fault','install_power_conditioner','in_progress','Biomed Lead - S. Rao',1.5,45000.00,'2026-08-15',null,'Power-board resets; line conditioner install underway'),
    ('INF-BBR-SPACE','high_failure_rate','component_wear_out','replace_worn_components','open','Biomed Tech - A. Khan',0.8,60000.00,'2026-08-20',null,'Pump-mechanism wear kits ordered fleet-wide'),
    ('DIA-NIP-SUR','low_availability','power_supply_fault','vendor_design_escalation','escalated','Service Mgr - P. Nair',2.6,120000.00,'2026-08-10',null,'Recurrent PSU faults escalated to Nipro OEM'),
    ('DEF-PHL-XL','recurring_failure_mode','component_wear_out','replace_worn_components','verification_pending','Biomed Tech - R. Das',1.9,38000.00,'2026-07-30',null,'Battery/paddle replaced; verify next cycle'),
    ('IMG-GE-VIVID','worsening_trend','firmware_defect','firmware_upgrade','open','Imaging Eng - M. Iyer',2.2,0.00,'2026-08-25',null,'GE firmware patch pending scheduling window'),
    ('SUC-DEV-VAC','high_failure_rate','component_wear_out','replace_worn_components','overdue','Biomed Tech - A. Khan',1.1,15000.00,'2026-07-15',null,'Motor-brush kits overdue — vendor delay'),
    ('MON-MND-BEN','recurring_failure_mode','sensor_degradation','replace_sensor','closed','Biomed Tech - R. Das',0.5,22000.00,'2026-07-10','2026-07-08','SpO2 cables replaced fleet-wide and verified'),
    ('IMG-SAM-HS60','preventive_maintenance_gap','inadequate_preventive_maintenance','revise_pm_schedule','in_progress','Imaging Eng - M. Iyer',0.6,8000.00,'2026-08-05',null,'Transducer PM interval shortened per usage')
  ) as q(mc, fc, rc, ca, cst, owner, aimpact, cost, tcd, acd, nt)
  join public.mtbf_reliability_r3488 e
    on e.organization_id = v_org_id and e.model_code = q.mc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reliability-status distribution
create or replace function public.founder_r3488_reliability_status_rollup()
returns table(reliability_status text, models bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mtbf_reliability_r3488)
  select l.reliability_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mtbf_reliability_r3488 l
  group by l.reliability_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_reliability_status_rollup() from public, anon;
grant execute on function public.founder_r3488_reliability_status_rollup() to authenticated;

-- 2) Device-category reliability scorecard
create or replace function public.founder_r3488_category_scorecard()
returns table(
  device_category text,
  models bigint,
  total_installed bigint,
  total_failures bigint,
  avg_mtbf_hours numeric,
  avg_availability_pct numeric,
  below_target bigint,
  poor_models bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_category,
    count(*)::bigint,
    coalesce(sum(l.installed_units),0)::bigint,
    coalesce(sum(l.failures),0)::bigint,
    round(avg(l.mtbf_hours), 0),
    round(avg(l.availability_pct), 2),
    count(*) filter (where l.mtbf_hours < l.target_mtbf_hours)::bigint,
    count(*) filter (where l.reliability_status = 'poor')::bigint
  from public.mtbf_reliability_r3488 l
  group by l.device_category
  order by count(*) filter (where l.reliability_status = 'poor') desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_category_scorecard() from public, anon;
grant execute on function public.founder_r3488_category_scorecard() to authenticated;

-- 3) Category × dominant-failure-mode matrix
create or replace function public.founder_r3488_category_failure_mode_matrix()
returns table(
  device_category text,
  dominant_failure_mode text,
  models bigint,
  total_failures bigint,
  avg_failure_rate_per_1000h numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_category, l.dominant_failure_mode, count(*)::bigint,
    coalesce(sum(l.failures),0)::bigint,
    round(avg(l.failure_rate_per_1000h), 3)
  from public.mtbf_reliability_r3488 l
  group by l.device_category, l.dominant_failure_mode
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_category_failure_mode_matrix() from public, anon;
grant execute on function public.founder_r3488_category_failure_mode_matrix() to authenticated;

-- 4) Monthly MTBF / availability trend
create or replace function public.founder_r3488_monthly_mtbf_trend()
returns table(
  period_month date,
  models bigint,
  avg_mtbf_hours numeric,
  avg_availability_pct numeric,
  total_failures bigint,
  worsening_models bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.mtbf_hours), 0),
    round(avg(l.availability_pct), 2),
    coalesce(sum(l.failures),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.mtbf_reliability_r3488 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3488_monthly_mtbf_trend() from public, anon;
grant execute on function public.founder_r3488_monthly_mtbf_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3488_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_escalated bigint)
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
  from public.mtbf_reliability_capa_actions_r3488 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_capa_status_board() from public, anon;
grant execute on function public.founder_r3488_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3488_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mtbf_reliability_capa_actions_r3488)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mtbf_reliability_capa_actions_r3488 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3488_root_cause_pareto() to authenticated;

-- 7) Availability-impact digest (by finding category)
create or replace function public.founder_r3488_availability_impact_digest()
returns table(
  finding_category text,
  actions bigint,
  open_actions bigint,
  total_availability_impact_pct numeric,
  total_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    round(coalesce(sum(c.availability_impact_pct),0)::numeric, 2),
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.mtbf_reliability_capa_actions_r3488 c
  group by c.finding_category
  order by round(coalesce(sum(c.availability_impact_pct),0)::numeric, 2) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3488_availability_impact_digest() from public, anon;
grant execute on function public.founder_r3488_availability_impact_digest() to authenticated;

-- 8) High-risk reliability queue (poor / below-target / worsening)
create or replace function public.founder_r3488_high_risk_queue()
returns table(
  device_model text,
  model_code text,
  device_category text,
  reliability_status text,
  mtbf_hours numeric,
  target_mtbf_hours numeric,
  availability_pct numeric,
  dominant_failure_mode text,
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
  select l.device_model, l.model_code, l.device_category, l.reliability_status,
    l.mtbf_hours, l.target_mtbf_hours, l.availability_pct,
    l.dominant_failure_mode, l.trend_dir, l.notes
  from public.mtbf_reliability_r3488 l
  where l.reliability_status in ('marginal','poor')
     or l.mtbf_hours < l.target_mtbf_hours
     or l.trend_dir = 'worsening'
  order by l.availability_pct asc, l.mtbf_hours asc;
end;
$$;

revoke execute on function public.founder_r3488_high_risk_queue() from public, anon;
grant execute on function public.founder_r3488_high_risk_queue() to authenticated;
