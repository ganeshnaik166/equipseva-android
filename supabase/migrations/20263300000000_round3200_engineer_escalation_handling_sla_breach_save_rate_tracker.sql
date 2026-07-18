-- Round 3200: Engineer Escalation-Handling & SLA-Breach Save-Rate Tracker
-- Escalation log — source × severity × response min × resolved-before-breach × customer retained × de-escalation quality × verdict × CAPA

-- =============================================================================
-- TABLE 1: escalation_save_r3200 — individual escalation handling records
-- =============================================================================
create table if not exists public.escalation_save_r3200 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  escalation_code text not null,
  escalation_date date not null,
  escalated_at timestamptz not null,
  first_response_at timestamptz,
  escalation_source text not null check (escalation_source in (
    'customer_complaint','sla_timer_auto','oem_escalation',
    'internal_audit','management_referral','repeat_failure_pattern'
  )),
  severity text not null check (severity in (
    'sev1_critical','sev2_high','sev3_moderate','sev4_low'
  )),
  equipment_category text not null check (equipment_category in (
    'ventilator','patient_monitor','ct_scanner','mri','dialysis_machine',
    'infusion_pump','anesthesia_workstation','autoclave','defibrillator','c_arm'
  )),
  sla_deadline_at timestamptz,
  response_time_minutes int not null,
  resolution_time_minutes int,
  resolved_before_breach boolean not null default false,
  breach_minutes int,
  customer_retained boolean,
  de_escalation_quality text check (de_escalation_quality in (
    'exemplary','good','adequate','poor','damaging','not_assessed'
  )),
  escalation_verdict text not null check (escalation_verdict in (
    'saved_before_breach','saved_after_breach','breached_customer_lost',
    'ongoing','withdrawn','de_escalated_no_action'
  )),
  engineer_id uuid references public.engineers(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.escalation_save_r3200 enable row level security;

create index if not exists idx_escalation_save_r3200_org on public.escalation_save_r3200(organization_id);
create index if not exists idx_escalation_save_r3200_date on public.escalation_save_r3200(escalation_date);
create index if not exists idx_escalation_save_r3200_verdict on public.escalation_save_r3200(escalation_verdict);

-- =============================================================================
-- TABLE 2: escalation_save_capa_actions_r3200 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.escalation_save_capa_actions_r3200 (
  id uuid primary key default gen_random_uuid(),
  escalation_id uuid not null references public.escalation_save_r3200(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'late_first_response','skill_gap','spare_unavailable','communication_breakdown',
    'wrong_diagnosis','sla_config_error','handover_gap','customer_expectation_mismatch',
    'vendor_dependency','process_noncompliance'
  )),
  root_cause text not null check (root_cause in (
    'engineer_overloaded','training_deficit','spare_logistics_delay',
    'oem_support_slow','ticket_misrouted','sla_timer_misconfigured',
    'poor_shift_handover','pending_investigation','customer_site_access_delay','knowledge_base_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','rebalance_territory_load','pre_stock_critical_spares',
    'escalate_oem_contract','fix_sla_timer_config','update_runbook',
    'assign_senior_buddy','customer_recovery_visit','none_required','automate_escalation_alerts'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'customer_contract_breach','nabh_finding','none','internal_only',
    'penalty_clause_triggered','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.escalation_save_capa_actions_r3200 enable row level security;

create index if not exists idx_escalation_capa_r3200_escalation on public.escalation_save_capa_actions_r3200(escalation_id);
create index if not exists idx_escalation_capa_r3200_status on public.escalation_save_capa_actions_r3200(capa_status);

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

  -- 14 escalation rows
  insert into public.escalation_save_r3200 (
    organization_id, hospital_name, engineer_name, escalation_code,
    escalation_date, escalated_at, first_response_at,
    escalation_source, severity, equipment_category, sla_deadline_at,
    response_time_minutes, resolution_time_minutes, resolved_before_breach,
    breach_minutes, customer_retained, de_escalation_quality, escalation_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.code,
    q.ed::date, q.ea::timestamptz, q.fr::timestamptz,
    q.src, q.sev, q.eq, q.sla::timestamptz,
    q.rt, q.rm, q.rbb,
    q.bm, q.cr, q.dq, q.ev, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','ESC-3200-001','2026-07-02','2026-07-02 09:15:00+05:30','2026-07-02 09:27:00+05:30',
     'customer_complaint','sev2_high','ventilator','2026-07-02 13:15:00+05:30',12,150,true,null,true,'exemplary','saved_before_breach','ICU vent alarm complaint — resolved on first visit'),
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','ESC-3200-002','2026-07-03','2026-07-03 14:40:00+05:30','2026-07-03 15:05:00+05:30',
     'sla_timer_auto','sev3_moderate','patient_monitor','2026-07-03 18:40:00+05:30',25,300,true,null,true,'good','saved_before_breach','Auto-escalated at 75% SLA — closed with time to spare'),
    ('Fortis Bannerghatta Bengaluru','Sneha Patil','ESC-3200-003','2026-07-03','2026-07-03 06:50:00+05:30','2026-07-03 08:35:00+05:30',
     'sla_timer_auto','sev1_critical','ct_scanner','2026-07-03 08:50:00+05:30',105,540,false,90,true,'adequate','saved_after_breach','CT tube fault — breach 90 min, customer placated with loaner'),
    ('Fortis Bannerghatta Bengaluru','Sneha Patil','ESC-3200-004','2026-07-04','2026-07-04 11:20:00+05:30','2026-07-04 11:32:00+05:30',
     'oem_escalation','sev2_high','mri','2026-07-04 17:20:00+05:30',12,null,false,null,null,'not_assessed','ongoing','OEM flagged helium level anomaly — parts in transit'),
    ('Manipal Whitefield Bengaluru','Arjun Mehta','ESC-3200-005','2026-07-01','2026-07-01 08:05:00+05:30','2026-07-01 08:20:00+05:30',
     'customer_complaint','sev1_critical','dialysis_machine','2026-07-01 10:05:00+05:30',15,110,true,null,true,'exemplary','saved_before_breach','Conductivity alarm mid-session — standby machine swapped in 20 min'),
    ('Manipal Whitefield Bengaluru','Arjun Mehta','ESC-3200-006','2026-07-05','2026-07-05 16:10:00+05:30','2026-07-05 19:40:00+05:30',
     'internal_audit','sev3_moderate','infusion_pump','2026-07-05 20:10:00+05:30',210,480,false,110,false,'poor','breached_customer_lost','Late response — ward moved to rental pumps from competitor'),
    ('AIIMS New Delhi Ansari Nagar','Priya Nair','ESC-3200-007','2026-07-02','2026-07-02 07:30:00+05:30','2026-07-02 07:42:00+05:30',
     'sla_timer_auto','sev2_high','anesthesia_workstation','2026-07-02 11:30:00+05:30',12,200,true,null,true,'good','saved_before_breach','Vaporizer swap under SLA — OT list unaffected'),
    ('AIIMS New Delhi Ansari Nagar','Priya Nair','ESC-3200-008','2026-07-06','2026-07-06 13:00:00+05:30','2026-07-06 13:18:00+05:30',
     'management_referral','sev4_low','autoclave','2026-07-07 13:00:00+05:30',18,90,true,null,true,'adequate','withdrawn','Dean referral — duplicate of existing ticket, withdrawn'),
    ('KIMS Secunderabad','Vikram Singh','ESC-3200-009','2026-07-04','2026-07-04 05:55:00+05:30','2026-07-04 07:50:00+05:30',
     'customer_complaint','sev1_critical','defibrillator','2026-07-04 07:55:00+05:30',115,260,false,140,true,'good','saved_after_breach','Crash-cart defib failed self-test — breach but strong recovery visit'),
    ('KIMS Secunderabad','Vikram Singh','ESC-3200-010','2026-07-07','2026-07-07 10:25:00+05:30','2026-07-07 10:34:00+05:30',
     'repeat_failure_pattern','sev2_high','c_arm','2026-07-07 16:25:00+05:30',9,320,true,null,true,'exemplary','saved_before_breach','Third C-arm fault this month — pattern flagged, collimator replaced'),
    ('Care Hospitals Banjara Hills','Deepak Sharma','ESC-3200-011','2026-07-05','2026-07-05 09:45:00+05:30','2026-07-05 10:05:00+05:30',
     'oem_escalation','sev3_moderate','ct_scanner','2026-07-05 15:45:00+05:30',20,null,false,null,null,'not_assessed','ongoing','OEM remote diagnostics running — detector calibration drift'),
    ('Yashoda Somajiguda Hyderabad','Kavya Reddy','ESC-3200-012','2026-07-06','2026-07-06 06:40:00+05:30','2026-07-06 06:52:00+05:30',
     'sla_timer_auto','sev2_high','ventilator','2026-07-06 10:40:00+05:30',12,180,true,null,true,'good','saved_before_breach','NICU vent O2 cell — replaced from van stock'),
    ('St John''s Bengaluru','Mohammed Irfan','ESC-3200-013','2026-07-03','2026-07-03 12:15:00+05:30','2026-07-03 14:55:00+05:30',
     'customer_complaint','sev3_moderate','patient_monitor','2026-07-03 16:15:00+05:30',160,420,false,80,true,'adequate','saved_after_breach','Telemetry dropouts — response late due to overlapping calls'),
    ('Rainbow Children''s Hyderabad','Mohammed Irfan','ESC-3200-014','2026-07-07','2026-07-07 08:10:00+05:30','2026-07-07 08:19:00+05:30',
     'internal_audit','sev4_low','infusion_pump','2026-07-08 08:10:00+05:30',9,60,true,null,true,'exemplary','saved_before_breach','Audit found firmware lag — patched same morning')
  ) as q(hosp, eng, code, ed, ea, fr, src, sev, eq, sla, rt, rm, rbb, bm, cr, dq, ev, nt);

  -- CAPA seed — attach to specific escalations by code
  insert into public.escalation_save_capa_actions_r3200 (
    escalation_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('ESC-3200-003','late_first_response','engineer_overloaded','rebalance_territory_load','2026-07-12',null,'in_progress','penalty_clause_triggered',85000.00,'CT downtime penalty clause invoked — territory split proposed'),
    ('ESC-3200-006','late_first_response','ticket_misrouted','fix_sla_timer_config','2026-07-10','2026-07-08','closed','customer_contract_breach',120000.00,'Pump ward lost to rental competitor — routing rule fixed'),
    ('ESC-3200-009','spare_unavailable','spare_logistics_delay','pre_stock_critical_spares','2026-07-14',null,'verification_pending','patient_safety_alert',36000.00,'Defib battery and pads now van-stocked for crash carts'),
    ('ESC-3200-013','communication_breakdown','poor_shift_handover','update_runbook','2026-07-11',null,'open','internal_only',4500.00,'Handover checklist adding open-escalation section'),
    ('ESC-3200-010','wrong_diagnosis','knowledge_base_gap','assign_senior_buddy','2026-07-15',null,'in_progress','none',12000.00,'Repeat C-arm faults — junior paired with senior imaging engineer'),
    ('ESC-3200-006','customer_expectation_mismatch','oem_support_slow','customer_recovery_visit','2026-07-09',null,'escalated','customer_contract_breach',25000.00,'Recovery visit with regional manager scheduled'),
    ('ESC-3200-003','sla_config_error','sla_timer_misconfigured','fix_sla_timer_config','2026-07-06','2026-07-05','closed','internal_only',0.00,'Sev1 CT SLA was 2h in config vs 4h in contract — corrected')
  ) as q(code, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.escalation_save_r3200 e
    on e.organization_id = v_org_id and e.escalation_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Escalation verdict distribution
create or replace function public.founder_r3200_verdict_rollup()
returns table(escalation_verdict text, escalations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.escalation_save_r3200)
  select e.escalation_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.escalation_save_r3200 e
  group by e.escalation_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_verdict_rollup() from public, anon;
grant execute on function public.founder_r3200_verdict_rollup() to authenticated;

-- 2) Engineer save-rate scorecard
create or replace function public.founder_r3200_engineer_scorecard()
returns table(
  engineer_name text,
  total_escalations bigint,
  saved_before_breach bigint,
  saved_after_breach bigint,
  customers_lost bigint,
  avg_response_min numeric,
  save_rate_pct numeric,
  customer_retention_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.engineer_name,
    count(*)::bigint,
    count(*) filter (where e.escalation_verdict = 'saved_before_breach')::bigint,
    count(*) filter (where e.escalation_verdict = 'saved_after_breach')::bigint,
    count(*) filter (where e.escalation_verdict = 'breached_customer_lost')::bigint,
    round(avg(e.response_time_minutes)::numeric, 0),
    round(100.0 * count(*) filter (where e.resolved_before_breach)::numeric / nullif(count(*),0), 1),
    round(100.0 * count(*) filter (where e.customer_retained)::numeric / nullif(count(*) filter (where e.customer_retained is not null),0), 1)
  from public.escalation_save_r3200 e
  group by e.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3200_engineer_scorecard() to authenticated;

-- 3) Source × severity matrix
create or replace function public.founder_r3200_source_severity_matrix()
returns table(escalation_source text, severity text, escalations bigint, saved bigint, avg_response_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.escalation_source, e.severity, count(*)::bigint,
    count(*) filter (where e.resolved_before_breach)::bigint,
    round(avg(e.response_time_minutes)::numeric, 0)
  from public.escalation_save_r3200 e
  group by e.escalation_source, e.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_source_severity_matrix() from public, anon;
grant execute on function public.founder_r3200_source_severity_matrix() to authenticated;

-- 4) Daily escalation trend
create or replace function public.founder_r3200_daily_trend()
returns table(escalation_date date, escalations bigint, saved bigint, breached bigint, avg_response_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.escalation_date, count(*)::bigint,
    count(*) filter (where e.resolved_before_breach)::bigint,
    count(*) filter (where e.breach_minutes is not null)::bigint,
    round(avg(e.response_time_minutes)::numeric, 0)
  from public.escalation_save_r3200 e
  group by e.escalation_date
  order by e.escalation_date desc;
end;
$$;

revoke execute on function public.founder_r3200_daily_trend() from public, anon;
grant execute on function public.founder_r3200_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3200_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.escalation_save_capa_actions_r3200 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_capa_status_board() from public, anon;
grant execute on function public.founder_r3200_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3200_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.escalation_save_capa_actions_r3200)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.escalation_save_capa_actions_r3200 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3200_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3200_regulatory_impact_digest()
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
  from public.escalation_save_capa_actions_r3200 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3200_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3200_regulatory_impact_digest() to authenticated;

-- 8) High-risk escalation queue (individual concerns)
create or replace function public.founder_r3200_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  escalation_code text,
  escalation_date date,
  escalation_source text,
  severity text,
  response_time_minutes int,
  escalation_verdict text,
  de_escalation_quality text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.hospital_name, e.engineer_name, e.escalation_code, e.escalation_date,
    e.escalation_source, e.severity, e.response_time_minutes, e.escalation_verdict, e.de_escalation_quality, e.notes
  from public.escalation_save_r3200 e
  where e.escalation_verdict in ('saved_after_breach','breached_customer_lost','ongoing')
     or e.severity = 'sev1_critical'
     or e.de_escalation_quality in ('poor','damaging')
     or e.customer_retained is false
  order by e.escalation_date desc, e.hospital_name;
end;
$$;

revoke execute on function public.founder_r3200_high_risk_queue() from public, anon;
grant execute on function public.founder_r3200_high_risk_queue() to authenticated;
