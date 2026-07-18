-- Round 3281: Founder Facility BMS, Access-Control, CCTV & Fire-Safety Systems Maintenance Board
-- EquipSeva office/warehouse building systems — system type × site × AMC × service-due × uptime × faults × spares × compliance-cert × cost × verdict × CAPA

-- =============================================================================
-- TABLE 1: facility_bms_r3281 — per-system maintenance governance rows
-- =============================================================================
create table if not exists public.facility_bms_r3281 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  city text not null,
  system_type text not null check (system_type in (
    'hvac_bms','access_control_biometric','cctv_surveillance','fire_alarm_panel',
    'intrusion_alarm','ups_power_backup','dg_set'
  )),
  system_asset_tag text not null,
  install_date date not null,
  amc_vendor text not null,
  amc_end date,
  last_service_date date,
  next_service_due date,
  uptime_pct numeric(5,2),
  open_faults int not null default 0,
  critical_fault_open boolean not null default false,
  spare_availability text not null check (spare_availability in (
    'adequate','low','none'
  )),
  compliance_cert_valid boolean not null default true,
  monthly_cost_rupees numeric(12,2),
  system_verdict text not null check (system_verdict in (
    'healthy','service_due','amc_expiring','faults_open','compliance_gap','critical'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.facility_bms_r3281 enable row level security;

create index if not exists idx_facility_bms_r3281_org on public.facility_bms_r3281(organization_id);
create index if not exists idx_facility_bms_r3281_due on public.facility_bms_r3281(next_service_due);
create index if not exists idx_facility_bms_r3281_verdict on public.facility_bms_r3281(system_verdict);

-- =============================================================================
-- TABLE 2: facility_bms_capa_actions_r3281 — service / renewal / compliance CAPA
-- =============================================================================
create table if not exists public.facility_bms_capa_actions_r3281 (
  id uuid primary key default gen_random_uuid(),
  system_log_id uuid not null references public.facility_bms_r3281(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'amc_expiry','service_overdue','critical_fault','compliance_cert_lapsed',
    'spare_shortage','uptime_degradation','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'vendor_sla_breach','component_end_of_life','spare_unavailable','config_drift',
    'power_environment_issue','vendor_delay','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'renew_amc_contract','schedule_service_visit','replace_faulty_component','order_spares',
    'renew_compliance_cert','escalate_to_vendor','replace_system','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'fire_noc_gap','statutory_compliance_finding','insurance_risk','none','internal_only','safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.facility_bms_capa_actions_r3281 enable row level security;

create index if not exists idx_facility_bms_capa_r3281_log on public.facility_bms_capa_actions_r3281(system_log_id);
create index if not exists idx_facility_bms_capa_r3281_status on public.facility_bms_capa_actions_r3281(capa_status);

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

  -- 14 facility-system rows
  insert into public.facility_bms_r3281 (
    organization_id, site_name, city, system_type, system_asset_tag,
    install_date, amc_vendor, amc_end, last_service_date, next_service_due,
    uptime_pct, open_faults, critical_fault_open, spare_availability,
    compliance_cert_valid, monthly_cost_rupees, system_verdict, notes
  )
  select v_org_id, q.site, q.city, q.stype, q.tag,
    q.idate::date, q.vendor, q.amc::date, q.lsd::date, q.nsd::date,
    q.uptime, q.faults::int, q.crit, q.spare,
    q.cert, q.cost, q.verdict, q.nt
  from (values
    ('EquipSeva HQ Bengaluru (Koramangala)','Bengaluru','hvac_bms','BMS-HQ-HVAC-01',
     '2021-03-15','Blue Star Ltd','2026-09-30','2026-06-20','2026-09-20',
     99.40,0,false,'adequate',true,45000.00,'healthy','Central HVAC + BMS controller — quarterly PM current'),
    ('EquipSeva HQ Bengaluru (Koramangala)','Bengaluru','access_control_biometric','BMS-HQ-ACS-02',
     '2021-03-20','Honeywell Building Solutions','2026-08-15','2026-05-10','2026-08-10',
     98.70,1,false,'adequate',true,18000.00,'amc_expiring','AMC lapses 15-Aug — renewal quote requested from Honeywell'),
    ('EquipSeva HQ Bengaluru (Koramangala)','Bengaluru','cctv_surveillance','BMS-HQ-CCTV-03',
     '2020-11-05','Securens Systems','2027-01-31','2026-06-25','2026-09-25',
     97.20,3,false,'low',true,22000.00,'faults_open','3 dome cameras offline in basement — NVR channels flapping'),
    ('EquipSeva HQ Bengaluru (Koramangala)','Bengaluru','fire_alarm_panel','BMS-HQ-FIRE-04',
     '2020-10-01','Agni Fire Safety Services','2026-12-31','2026-04-15','2026-07-15',
     100.00,0,false,'adequate',false,30000.00,'compliance_gap','Fire NOC renewal pending with fire dept — cert lapsed 30-Jun'),
    ('EquipSeva Warehouse Bengaluru (Bommasandra)','Bengaluru','dg_set','BMS-WHB-DG-05',
     '2019-06-12','Cummins India Service','2026-11-30','2026-06-01','2026-09-01',
     96.50,2,true,'none',true,55000.00,'critical','AVR board failure on 250kVA DG — no spare, mains-only risk'),
    ('EquipSeva Warehouse Bengaluru (Bommasandra)','Bengaluru','ups_power_backup','BMS-WHB-UPS-06',
     '2020-02-20','Vertiv Energy','2026-10-20','2026-05-28','2026-08-28',
     98.90,0,false,'adequate',true,26000.00,'healthy','40kVA UPS — battery bank health 92%, all rails nominal'),
    ('EquipSeva Warehouse Bengaluru (Bommasandra)','Bengaluru','intrusion_alarm','BMS-WHB-INT-07',
     '2021-01-10','Securens Systems','2026-08-05','2026-06-30','2026-09-30',
     99.10,0,false,'adequate',true,12000.00,'amc_expiring','Perimeter intrusion — AMC expiry 05-Aug, awaiting PO'),
    ('EquipSeva Chennai Office (T Nagar)','Chennai','hvac_bms','BMS-CHN-HVAC-08',
     '2021-07-08','Voltas Ltd','2027-02-28','2026-06-18','2026-09-18',
     99.00,1,false,'adequate',true,42000.00,'healthy','VRF + BMS — one minor sensor fault logged, non-critical'),
    ('EquipSeva Chennai Warehouse (Ambattur)','Chennai','cctv_surveillance','BMS-CHW-CCTV-09',
     '2020-09-14','Zicom SaaS','2026-07-25','2026-03-12','2026-06-12',
     94.30,5,false,'low',true,20000.00,'service_due','Quarterly service overdue since 12-Jun — 5 cameras degraded'),
    ('EquipSeva Chennai Warehouse (Ambattur)','Chennai','fire_alarm_panel','BMS-CHW-FIRE-10',
     '2020-08-30','Agni Fire Safety Services','2026-09-10','2026-05-20','2026-08-20',
     99.80,0,false,'adequate',false,28000.00,'compliance_gap','Fire NOC renewal in process with Chennai fire dept'),
    ('EquipSeva Hyderabad Hub (Gachibowli)','Hyderabad','dg_set','BMS-HYD-DG-11',
     '2019-12-01','Kirloskar Oil Engines','2026-10-05','2026-06-10','2026-09-10',
     97.60,1,false,'low',true,48000.00,'faults_open','Coolant temp sensor intermittent on 125kVA DG — spare low'),
    ('EquipSeva Delhi NCR Office (Gurugram)','Gurugram','access_control_biometric','BMS-DEL-ACS-12',
     '2021-05-22','Honeywell Building Solutions','2026-08-30','2026-06-05','2026-09-05',
     98.40,0,false,'adequate',true,19000.00,'amc_expiring','Biometric + card readers — AMC expiry 30-Aug flagged'),
    ('EquipSeva Mumbai Depot (Bhiwandi)','Mumbai','ups_power_backup','BMS-MUM-UPS-13',
     '2020-04-18','Schneider Electric APC','2026-12-15','2026-02-28','2026-05-28',
     93.10,4,true,'none',true,32000.00,'critical','Battery bank end-of-life, service overdue since 28-May'),
    ('EquipSeva Pune Service Center (Hinjewadi)','Pune','hvac_bms','BMS-PUN-HVAC-14',
     '2021-09-03','Blue Star Ltd','2027-03-31','2026-06-22','2026-09-22',
     99.60,0,false,'adequate',true,38000.00,'healthy','Ductable AC + BMS — all zones within setpoint band')
  ) as q(site, city, stype, tag, idate, vendor, amc, lsd, nsd, uptime, faults, crit, spare, cert, cost, verdict, nt);

  -- CAPA seed — attach to specific at-risk systems via asset tag
  insert into public.facility_bms_capa_actions_r3281 (
    system_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BMS-HQ-FIRE-04','compliance_cert_lapsed','vendor_delay','renew_compliance_cert','in_progress','fire_noc_gap','2026-07-30',null,35000.00,'Fire NOC file with dept — vendor Agni chasing inspection slot'),
    ('BMS-WHB-DG-05','critical_fault','component_end_of_life','replace_faulty_component','escalated','safety_alert','2026-07-25',null,120000.00,'AVR + controller board failed — Cummins expedited replacement'),
    ('BMS-CHW-CCTV-09','service_overdue','vendor_sla_breach','schedule_service_visit','open','statutory_compliance_finding','2026-07-20',null,15000.00,'Zicom PM overdue 5 weeks — SLA breach, service visit booked'),
    ('BMS-CHW-FIRE-10','compliance_cert_lapsed','pending_investigation','renew_compliance_cert','open','fire_noc_gap','2026-08-05',null,30000.00,'Chennai fire NOC renewal filed — awaiting drill sign-off'),
    ('BMS-MUM-UPS-13','critical_fault','component_end_of_life','replace_faulty_component','overdue','insurance_risk','2026-06-30',null,85000.00,'Battery bank end-of-life + overdue service — insurer flagged'),
    ('BMS-HYD-DG-11','uptime_degradation','power_environment_issue','schedule_service_visit','closed','internal_only','2026-06-25','2026-06-24',9000.00,'Coolant sensor swapped under AMC — uptime restored'),
    ('BMS-WHB-INT-07','amc_expiry','vendor_sla_breach','renew_amc_contract','verification_pending','none','2026-07-28',null,12000.00,'AMC renewal quote received from Securens — awaiting PO')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.facility_bms_r3281 e
    on e.organization_id = v_org_id and e.system_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) System verdict distribution
create or replace function public.founder_r3281_system_verdict_rollup()
returns table(system_verdict text, systems bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.facility_bms_r3281)
  select l.system_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.facility_bms_r3281 l
  group by l.system_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_system_verdict_rollup() from public, anon;
grant execute on function public.founder_r3281_system_verdict_rollup() to authenticated;

-- 2) Site-level maintenance scorecard
create or replace function public.founder_r3281_site_scorecard()
returns table(
  site_name text,
  total_systems bigint,
  healthy bigint,
  service_due bigint,
  critical bigint,
  faults_open_systems bigint,
  compliance_gap bigint,
  avg_uptime_pct numeric,
  monthly_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.system_verdict = 'healthy')::bigint,
    count(*) filter (where l.system_verdict in ('service_due','amc_expiring'))::bigint,
    count(*) filter (where l.system_verdict = 'critical')::bigint,
    count(*) filter (where l.open_faults > 0 or l.critical_fault_open)::bigint,
    count(*) filter (where l.compliance_cert_valid = false)::bigint,
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.monthly_cost_rupees),0)::numeric
  from public.facility_bms_r3281 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_site_scorecard() from public, anon;
grant execute on function public.founder_r3281_site_scorecard() to authenticated;

-- 3) System-type × verdict matrix
create or replace function public.founder_r3281_systemtype_verdict_matrix()
returns table(system_type text, system_verdict text, systems bigint, avg_uptime_pct numeric, total_open_faults bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.system_verdict, count(*)::bigint,
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.open_faults),0)::bigint
  from public.facility_bms_r3281 l
  group by l.system_type, l.system_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_systemtype_verdict_matrix() from public, anon;
grant execute on function public.founder_r3281_systemtype_verdict_matrix() to authenticated;

-- 4) Service-due calendar (date trend)
create or replace function public.founder_r3281_service_due_calendar()
returns table(next_service_due date, systems bigint, amc_expiring bigint, critical bigint, faults_open bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.next_service_due,
    count(*)::bigint,
    count(*) filter (where l.system_verdict = 'amc_expiring')::bigint,
    count(*) filter (where l.system_verdict = 'critical')::bigint,
    count(*) filter (where l.open_faults > 0)::bigint
  from public.facility_bms_r3281 l
  group by l.next_service_due
  order by l.next_service_due asc;
end;
$$;

revoke execute on function public.founder_r3281_service_due_calendar() from public, anon;
grant execute on function public.founder_r3281_service_due_calendar() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3281_capa_status_board()
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
  from public.facility_bms_capa_actions_r3281 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_capa_status_board() from public, anon;
grant execute on function public.founder_r3281_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3281_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.facility_bms_capa_actions_r3281)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.facility_bms_capa_actions_r3281 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3281_root_cause_pareto() to authenticated;

-- 7) Regulatory / compliance impact digest
create or replace function public.founder_r3281_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.facility_bms_capa_actions_r3281 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3281_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3281_regulatory_impact_digest() to authenticated;

-- 8) High-risk systems queue
create or replace function public.founder_r3281_high_risk_queue()
returns table(
  site_name text,
  city text,
  system_type text,
  system_asset_tag text,
  system_verdict text,
  amc_end date,
  next_service_due date,
  uptime_pct numeric,
  open_faults int,
  spare_availability text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.city, l.system_type, l.system_asset_tag,
    l.system_verdict, l.amc_end, l.next_service_due, l.uptime_pct,
    l.open_faults, l.spare_availability, l.notes
  from public.facility_bms_r3281 l
  where l.system_verdict in ('service_due','amc_expiring','faults_open','compliance_gap','critical')
     or l.critical_fault_open = true
     or l.compliance_cert_valid = false
     or l.open_faults > 0
     or l.spare_availability in ('low','none')
  order by l.next_service_due asc, l.site_name;
end;
$$;

revoke execute on function public.founder_r3281_high_risk_queue() from public, anon;
grant execute on function public.founder_r3281_high_risk_queue() to authenticated;
