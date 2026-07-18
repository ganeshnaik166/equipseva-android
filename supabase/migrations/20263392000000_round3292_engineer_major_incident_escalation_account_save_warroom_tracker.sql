-- Round 3292: Engineer Major-Incident Escalation & Customer Account-Save War-Room Tracker
-- Critical equipment down at key hospital — war-room × account tier × equipment × severity × SLA-penalty risk × relationship risk × root cause × verdict × CAPA (preventive + relationship actions)

-- =============================================================================
-- TABLE 1: major_incident_warroom_r3292 — per major-incident war-room record
-- =============================================================================
create table if not exists public.major_incident_warroom_r3292 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  account_tier text not null check (account_tier in (
    'platinum','gold','silver','strategic_logo'
  )),
  incident_code text not null,
  equipment_type text not null check (equipment_type in (
    'mri','ct','cath_lab','ventilator_fleet','dialysis_fleet','patient_monitoring','lab_analyzer'
  )),
  severity text not null check (severity in (
    'sev1_total_outage','sev2_degraded','sev3_recurring'
  )),
  reported_date date not null,
  warroom_convened boolean not null,
  lead_engineer text not null,
  oem_engaged boolean not null,
  loaner_deployed boolean not null,
  time_to_restore_hours numeric(6,1),
  sla_penalty_risk_rupees numeric(12,2),
  relationship_risk text not null check (relationship_risk in (
    'low','medium','high','churn_threat'
  )),
  root_cause_category text not null check (root_cause_category in (
    'part_failure','install_defect','user_error','oem_delay','power_environment','wear_maintenance'
  )),
  incident_verdict text not null check (incident_verdict in (
    'resolved_saved','resolved_with_credit','escalated_ongoing','churn_risk_open','lost'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.major_incident_warroom_r3292 enable row level security;

create index if not exists idx_major_incident_warroom_r3292_org on public.major_incident_warroom_r3292(organization_id);
create index if not exists idx_major_incident_warroom_r3292_date on public.major_incident_warroom_r3292(reported_date);
create index if not exists idx_major_incident_warroom_r3292_verdict on public.major_incident_warroom_r3292(incident_verdict);

-- =============================================================================
-- TABLE 2: major_incident_warroom_capa_actions_r3292 — preventive & relationship CAPA actions
-- =============================================================================
create table if not exists public.major_incident_warroom_capa_actions_r3292 (
  id uuid primary key default gen_random_uuid(),
  incident_log_id uuid not null references public.major_incident_warroom_r3292(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'spares_stocking','oem_sla_renegotiation','loaner_pool_expansion','preventive_maintenance_gap',
    'staff_retraining','account_relationship_repair','contract_sla_review','escalation_process_gap'
  )),
  root_cause text not null check (root_cause in (
    'chronic_part_failure','oem_response_slow','no_local_loaner','install_quality',
    'user_handling','power_environment','maintenance_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'stock_critical_spares','sign_priority_oem_sla','add_regional_loaner','schedule_preventive_service',
    'retrain_biomed_staff','executive_account_review','issue_sla_credit','revise_escalation_matrix','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  account_impact text not null check (account_impact in (
    'churn_threat','sla_penalty','reference_at_risk','renewal_risk','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.major_incident_warroom_capa_actions_r3292 enable row level security;

create index if not exists idx_major_incident_capa_r3292_log on public.major_incident_warroom_capa_actions_r3292(incident_log_id);
create index if not exists idx_major_incident_capa_r3292_status on public.major_incident_warroom_capa_actions_r3292(capa_status);

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

  -- 14 major-incident war-room rows
  insert into public.major_incident_warroom_r3292 (
    organization_id, hospital_name, account_tier, incident_code, equipment_type, severity,
    reported_date, warroom_convened, lead_engineer, oem_engaged, loaner_deployed,
    time_to_restore_hours, sla_penalty_risk_rupees, relationship_risk, root_cause_category,
    incident_verdict, notes
  )
  select v_org_id, q.hosp, q.tier, q.code, q.equip, q.sev,
    q.rdate::date, q.wconv, q.lead, q.oem, q.loaner,
    q.ttr, q.sla, q.relrisk, q.rootcat,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai','platinum','INC-2026-0412','mri','sev1_total_outage',
     '2026-07-14',true,'Rajesh Kumar',true,true,
     18.5,450000.00,'high','part_failure',
     'resolved_saved','MRI cold-head failed; war-room convened, loaner coil deployed, OEM cryo team restored in 18.5h'),
    ('Fortis Gurgaon','gold','INC-2026-0409','cath_lab','sev1_total_outage',
     '2026-07-12',true,'Anil Menon',true,true,
     26.0,620000.00,'churn_threat','oem_delay',
     'escalated_ongoing','Cath-lab flat-panel down; OEM part stuck in customs; exec escalation active'),
    ('Manipal Bengaluru','strategic_logo','INC-2026-0401','ct','sev2_degraded',
     '2026-07-10',true,'Priya Nair',true,false,
     9.0,180000.00,'medium','part_failure',
     'resolved_saved','CT tube arc; degraded scans; tube swap from regional stock restored service'),
    ('AIIMS Delhi','platinum','INC-2026-0398','ventilator_fleet','sev1_total_outage',
     '2026-07-09',true,'Suresh Iyer',false,true,
     6.5,300000.00,'high','wear_maintenance',
     'resolved_saved','ICU vent fleet blower failures; 4 loaners deployed within 6.5h'),
    ('CMC Vellore','gold','INC-2026-0395','dialysis_fleet','sev2_degraded',
     '2026-07-08',true,'Deepak Rao',true,false,
     14.0,210000.00,'medium','power_environment',
     'resolved_with_credit','RO water conductivity excursion; 3 stations offline; SLA credit issued for downtime'),
    ('KIMS Hyderabad','silver','INC-2026-0390','patient_monitoring','sev3_recurring',
     '2026-07-06',false,'Vivek Sharma',false,false,
     4.0,45000.00,'low','user_error',
     'resolved_saved','Recurring central-station dropouts traced to network config; no war-room needed'),
    ('Apollo Chennai','platinum','INC-2026-0386','lab_analyzer','sev2_degraded',
     '2026-07-05',true,'Rajesh Kumar',true,false,
     11.5,160000.00,'medium','part_failure',
     'resolved_saved','Biochem analyzer probe crash; OEM part flown in; restored 11.5h'),
    ('Fortis Gurgaon','gold','INC-2026-0380','mri','sev2_degraded',
     '2026-07-03',true,'Anil Menon',true,true,
     22.0,260000.00,'high','oem_delay',
     'resolved_with_credit','MRI gradient amp intermittent; loaner scan slots + credit while OEM board shipped'),
    ('Manipal Bengaluru','strategic_logo','INC-2026-0377','cath_lab','sev1_total_outage',
     '2026-07-02',true,'Priya Nair',true,true,
     30.5,700000.00,'churn_threat','install_defect',
     'churn_risk_open','Repeat cath-lab outage post-install; customer threatening exit; CEO-level war-room open'),
    ('AIIMS Delhi','platinum','INC-2026-0370','ct','sev1_total_outage',
     '2026-06-30',true,'Suresh Iyer',true,true,
     20.0,400000.00,'high','part_failure',
     'resolved_saved','CT gantry slip-ring failure; OEM plus loaner scanner bridged; restored 20h'),
    ('CMC Vellore','gold','INC-2026-0364','ventilator_fleet','sev3_recurring',
     '2026-06-28',false,'Deepak Rao',false,false,
     5.0,60000.00,'low','wear_maintenance',
     'resolved_saved','Recurring vent flow-sensor alarms; PM cycle refreshed sensors; closed'),
    ('KIMS Hyderabad','silver','INC-2026-0359','dialysis_fleet','sev2_degraded',
     '2026-06-26',true,'Vivek Sharma',true,false,
     16.0,140000.00,'medium','part_failure',
     'resolved_with_credit','Dialysis pump board failures across 2 units; partial credit while boards sourced'),
    ('Fortis Gurgaon','gold','INC-2026-0351','lab_analyzer','sev1_total_outage',
     '2026-06-24',true,'Anil Menon',true,true,
     40.0,520000.00,'churn_threat','oem_delay',
     'lost','Immunoassay line down 40h; OEM missed SLA repeatedly; customer moved contract to competitor'),
    ('Apollo Chennai','platinum','INC-2026-0345','patient_monitoring','sev2_degraded',
     '2026-06-22',true,'Rajesh Kumar',true,true,
     null,90000.00,'medium','power_environment',
     'escalated_ongoing','Telemetry coverage gaps after UPS event; scope of remediation still being agreed')
  ) as q(hosp, tier, code, equip, sev, rdate, wconv, lead, oem, loaner, ttr, sla, relrisk, rootcat, verdict, nt);

  -- CAPA seed — preventive & relationship actions attached via incident_code
  insert into public.major_incident_warroom_capa_actions_r3292 (
    incident_log_id, finding_category, root_cause, corrective_action,
    capa_status, account_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ai, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('INC-2026-0409','oem_sla_renegotiation','oem_response_slow','sign_priority_oem_sla','escalated','churn_threat','2026-07-20',null,0.00,'Negotiating 4h priority OEM SLA for cath-lab spares to prevent churn'),
    ('INC-2026-0377','account_relationship_repair','install_quality','executive_account_review','in_progress','churn_threat','2026-07-16',null,150000.00,'CEO account review plus free re-commissioning to save strategic logo'),
    ('INC-2026-0351','contract_sla_review','oem_response_slow','revise_escalation_matrix','closed','reference_at_risk','2026-06-30','2026-06-29',25000.00,'Post-mortem after contract loss; escalation matrix revised to auto-page director at 8h'),
    ('INC-2026-0398','preventive_maintenance_gap','maintenance_backlog','schedule_preventive_service','verification_pending','sla_penalty','2026-07-18',null,48000.00,'PM backlog on vent blowers cleared; verifying no repeat alarms'),
    ('INC-2026-0359','spares_stocking','chronic_part_failure','stock_critical_spares','open','renewal_risk','2026-07-22',null,85000.00,'Stock dialysis pump boards at Hyderabad hub to cut restore time'),
    ('INC-2026-0412','loaner_pool_expansion','no_local_loaner','add_regional_loaner','in_progress','renewal_risk','2026-07-25',null,120000.00,'Add South-region MRI coil loaner pool to shorten platinum-account outages'),
    ('INC-2026-0390','staff_retraining','user_handling','retrain_biomed_staff','closed','internal_only','2026-07-01','2026-06-30',8000.00,'Retrained biomed team on central-station network config; recurrence closed')
  ) as q(code, fc, rc, ca, cst, ai, tcd, acd, cost, nt)
  join public.major_incident_warroom_r3292 e
    on e.organization_id = v_org_id and e.incident_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Incident verdict distribution
create or replace function public.founder_r3292_incident_verdict_rollup()
returns table(incident_verdict text, incidents bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.major_incident_warroom_r3292)
  select l.incident_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.major_incident_warroom_r3292 l
  group by l.incident_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_incident_verdict_rollup() from public, anon;
grant execute on function public.founder_r3292_incident_verdict_rollup() to authenticated;

-- 2) Hospital-level war-room scorecard
create or replace function public.founder_r3292_hospital_scorecard()
returns table(
  hospital_name text,
  total_incidents bigint,
  sev1 bigint,
  saved bigint,
  credit_issued bigint,
  churn_open bigint,
  lost bigint,
  total_sla_penalty_rupees numeric,
  save_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.severity = 'sev1_total_outage')::bigint,
    count(*) filter (where l.incident_verdict = 'resolved_saved')::bigint,
    count(*) filter (where l.incident_verdict = 'resolved_with_credit')::bigint,
    count(*) filter (where l.incident_verdict in ('escalated_ongoing','churn_risk_open'))::bigint,
    count(*) filter (where l.incident_verdict = 'lost')::bigint,
    coalesce(sum(l.sla_penalty_risk_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.incident_verdict in ('resolved_saved','resolved_with_credit'))::numeric / nullif(count(*),0), 1)
  from public.major_incident_warroom_r3292 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3292_hospital_scorecard() to authenticated;

-- 3) Equipment type × severity matrix
create or replace function public.founder_r3292_equipment_severity_matrix()
returns table(equipment_type text, severity text, incidents bigint, saved bigint, avg_restore_hours numeric, total_sla_penalty_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.severity, count(*)::bigint,
    count(*) filter (where l.incident_verdict in ('resolved_saved','resolved_with_credit'))::bigint,
    round(avg(l.time_to_restore_hours), 1),
    coalesce(sum(l.sla_penalty_risk_rupees),0)::numeric
  from public.major_incident_warroom_r3292 l
  group by l.equipment_type, l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_equipment_severity_matrix() from public, anon;
grant execute on function public.founder_r3292_equipment_severity_matrix() to authenticated;

-- 4) Daily incident trend
create or replace function public.founder_r3292_daily_incident_trend()
returns table(reported_date date, incidents bigint, sev1 bigint, warrooms bigint, lost bigint, total_sla_penalty_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reported_date,
    count(*)::bigint,
    count(*) filter (where l.severity = 'sev1_total_outage')::bigint,
    count(*) filter (where l.warroom_convened)::bigint,
    count(*) filter (where l.incident_verdict = 'lost')::bigint,
    coalesce(sum(l.sla_penalty_risk_rupees),0)::numeric
  from public.major_incident_warroom_r3292 l
  group by l.reported_date
  order by l.reported_date desc;
end;
$$;

revoke execute on function public.founder_r3292_daily_incident_trend() from public, anon;
grant execute on function public.founder_r3292_daily_incident_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3292_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.major_incident_warroom_capa_actions_r3292 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_capa_status_board() from public, anon;
grant execute on function public.founder_r3292_capa_status_board() to authenticated;

-- 6) Root cause pareto (main-table incident root causes)
create or replace function public.founder_r3292_root_cause_pareto()
returns table(root_cause_category text, incidents bigint, total_sla_penalty_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.major_incident_warroom_r3292)
  select l.root_cause_category, count(*)::bigint,
    coalesce(sum(l.sla_penalty_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.major_incident_warroom_r3292 l
  group by l.root_cause_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3292_root_cause_pareto() to authenticated;

-- 7) Account-tier commercial risk digest
create or replace function public.founder_r3292_account_risk_digest()
returns table(
  account_tier text,
  incidents bigint,
  sev1 bigint,
  churn_threat_incidents bigint,
  lost bigint,
  total_sla_penalty_rupees numeric,
  avg_restore_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.account_tier,
    count(*)::bigint,
    count(*) filter (where l.severity = 'sev1_total_outage')::bigint,
    count(*) filter (where l.relationship_risk = 'churn_threat')::bigint,
    count(*) filter (where l.incident_verdict = 'lost')::bigint,
    coalesce(sum(l.sla_penalty_risk_rupees),0)::numeric,
    round(avg(l.time_to_restore_hours), 1)
  from public.major_incident_warroom_r3292 l
  group by l.account_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3292_account_risk_digest() from public, anon;
grant execute on function public.founder_r3292_account_risk_digest() to authenticated;

-- 8) High-risk incident queue (open account-save concerns)
create or replace function public.founder_r3292_high_risk_queue()
returns table(
  hospital_name text,
  incident_code text,
  equipment_type text,
  severity text,
  reported_date date,
  relationship_risk text,
  incident_verdict text,
  sla_penalty_risk_rupees numeric,
  lead_engineer text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.incident_code, l.equipment_type, l.severity, l.reported_date,
    l.relationship_risk, l.incident_verdict, l.sla_penalty_risk_rupees, l.lead_engineer, l.notes
  from public.major_incident_warroom_r3292 l
  where l.relationship_risk in ('high','churn_threat')
     or l.severity = 'sev1_total_outage'
     or l.incident_verdict in ('escalated_ongoing','churn_risk_open','lost')
  order by l.reported_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3292_high_risk_queue() from public, anon;
grant execute on function public.founder_r3292_high_risk_queue() to authenticated;
