-- Round 3654: Founder Medical-Device Regulatory-Intelligence / Standard-Update Impact Board
-- Regulatory intelligence — standard/regulation updates (IEC/ISO/CDSCO/BIS/MDR/AERB) × impact assessment ×
-- transition deadlines × gap items × action-plan progress × CAPA

-- =============================================================================
-- TABLE 1: reg_intel_r3654 — per-update regulatory-intelligence impact assessments
-- =============================================================================
create table if not exists public.reg_intel_r3654 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  update_ref text not null,
  standard_name text not null,
  period_month date not null,
  published_date date not null,
  transition_deadline date not null,
  days_to_deadline int not null,
  devices_affected int not null,
  gap_items int not null,
  impact_assessment_done boolean not null,
  action_plan_pct numeric(5,2),
  source_body text not null check (source_body in (
    'cdsco','bis','iec','iso','mdr_amendment','aerb'
  )),
  impact_level text not null check (impact_level in (
    'critical','major','moderate','minor','no_impact'
  )),
  assessment_status text not null check (assessment_status in (
    'closed','action_in_progress','under_assessment','not_assessed','deadline_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reg_intel_r3654 enable row level security;

create index if not exists idx_reg_intel_r3654_org on public.reg_intel_r3654(organization_id);
create index if not exists idx_reg_intel_r3654_month on public.reg_intel_r3654(period_month);
create index if not exists idx_reg_intel_r3654_status on public.reg_intel_r3654(assessment_status);

-- =============================================================================
-- TABLE 2: reg_intel_capa_actions_r3654 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.reg_intel_capa_actions_r3654 (
  id uuid primary key default gen_random_uuid(),
  update_id uuid not null references public.reg_intel_r3654(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'late_standard_monitoring','no_gap_assessment_owner','design_documentation_gap',
    'test_lab_capacity_shortage','supplier_component_noncompliance','regulatory_team_bandwidth',
    'translation_interpretation_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'complete_gap_assessment','update_technical_file','retest_at_accredited_lab',
    'redesign_component','update_risk_management_file','engage_notified_body',
    'hire_regulatory_consultant','subscribe_standard_watch_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  compliance_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reg_intel_capa_actions_r3654 enable row level security;

create index if not exists idx_reg_intel_capa_r3654_update on public.reg_intel_capa_actions_r3654(update_id);
create index if not exists idx_reg_intel_capa_r3654_status on public.reg_intel_capa_actions_r3654(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Assessment-status distribution
create or replace function public.founder_r3654_assessment_status_rollup()
returns table(assessment_status text, updates bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reg_intel_r3654)
  select l.assessment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.reg_intel_r3654 l
  group by l.assessment_status
  order by count(*) desc;
end;
$$;

-- 2) Source-body scorecard
create or replace function public.founder_r3654_source_body_scorecard()
returns table(
  source_body text,
  total_updates bigint,
  closed_cnt bigint,
  in_action bigint,
  deadline_risk_cnt bigint,
  devices_affected_total bigint,
  gap_items_total bigint,
  avg_action_plan_pct numeric,
  assessed_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.source_body,
    count(*)::bigint,
    count(*) filter (where l.assessment_status = 'closed')::bigint,
    count(*) filter (where l.assessment_status = 'action_in_progress')::bigint,
    count(*) filter (where l.assessment_status = 'deadline_risk')::bigint,
    coalesce(sum(l.devices_affected),0)::bigint,
    coalesce(sum(l.gap_items),0)::bigint,
    round(avg(l.action_plan_pct), 1),
    round(100.0 * count(*) filter (where l.impact_assessment_done)::numeric / nullif(count(*),0), 1)
  from public.reg_intel_r3654 l
  group by l.source_body
  order by count(*) desc;
end;
$$;

-- 3) Impact-level × assessment-status matrix
create or replace function public.founder_r3654_impact_status_matrix()
returns table(impact_level text, assessment_status text, updates bigint, devices_affected_total bigint, avg_days_to_deadline numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.impact_level, l.assessment_status, count(*)::bigint,
    coalesce(sum(l.devices_affected),0)::bigint,
    round(avg(l.days_to_deadline), 0)
  from public.reg_intel_r3654 l
  group by l.impact_level, l.assessment_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly update trend
create or replace function public.founder_r3654_monthly_update_trend()
returns table(period_month date, updates bigint, critical_major bigint, closed_cnt bigint, deadline_risk_cnt bigint, avg_action_plan_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.impact_level in ('critical','major'))::bigint,
    count(*) filter (where l.assessment_status = 'closed')::bigint,
    count(*) filter (where l.assessment_status = 'deadline_risk')::bigint,
    round(avg(l.action_plan_pct), 1)
  from public.reg_intel_r3654 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3654_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.compliance_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.reg_intel_capa_actions_r3654 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3654_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reg_intel_capa_actions_r3654)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.compliance_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.reg_intel_capa_actions_r3654 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Deadline-exposure digest
create or replace function public.founder_r3654_deadline_exposure_digest()
returns table(deadline_band text, updates bigint, devices_affected_total bigint, gap_items_total bigint, avg_action_plan_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with b as (
    select case
      when l.days_to_deadline < 90 then 'under_90_days'
      when l.days_to_deadline <= 180 then 'days_90_to_180'
      when l.days_to_deadline <= 365 then 'days_181_to_365'
      else 'over_365_days'
    end as band,
    l.days_to_deadline, l.devices_affected, l.gap_items, l.action_plan_pct
    from public.reg_intel_r3654 l
  )
  select b.band, count(*)::bigint,
    coalesce(sum(b.devices_affected),0)::bigint,
    coalesce(sum(b.gap_items),0)::bigint,
    round(avg(b.action_plan_pct), 1)
  from b
  group by b.band
  order by min(b.days_to_deadline);
end;
$$;

-- 8) High-risk update queue (deadline_risk / not_assessed / critical exposure)
create or replace function public.founder_r3654_high_risk_queue()
returns table(
  update_ref text,
  standard_name text,
  source_body text,
  impact_level text,
  assessment_status text,
  transition_deadline date,
  days_to_deadline int,
  devices_affected int,
  gap_items int,
  action_plan_pct numeric,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.update_ref, l.standard_name, l.source_body, l.impact_level, l.assessment_status,
    l.transition_deadline, l.days_to_deadline, l.devices_affected, l.gap_items,
    l.action_plan_pct, l.trend_dir, l.notes
  from public.reg_intel_r3654 l
  where l.assessment_status in ('deadline_risk','not_assessed')
     or l.impact_level = 'critical'
     or l.trend_dir = 'worsening'
     or (l.days_to_deadline <= 120 and coalesce(l.action_plan_pct, 0) < 50)
  order by l.days_to_deadline asc, l.update_ref;
end;
$$;

-- =============================================================================
-- Grants — founder RPCs restricted to authenticated
-- =============================================================================
revoke all on function public.founder_r3654_assessment_status_rollup() from public, anon;
revoke all on function public.founder_r3654_source_body_scorecard() from public, anon;
revoke all on function public.founder_r3654_impact_status_matrix() from public, anon;
revoke all on function public.founder_r3654_monthly_update_trend() from public, anon;
revoke all on function public.founder_r3654_capa_status_board() from public, anon;
revoke all on function public.founder_r3654_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3654_deadline_exposure_digest() from public, anon;
revoke all on function public.founder_r3654_high_risk_queue() from public, anon;

grant execute on function public.founder_r3654_assessment_status_rollup() to authenticated;
grant execute on function public.founder_r3654_source_body_scorecard() to authenticated;
grant execute on function public.founder_r3654_impact_status_matrix() to authenticated;
grant execute on function public.founder_r3654_monthly_update_trend() to authenticated;
grant execute on function public.founder_r3654_capa_status_board() to authenticated;
grant execute on function public.founder_r3654_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3654_deadline_exposure_digest() to authenticated;
grant execute on function public.founder_r3654_high_risk_queue() to authenticated;

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

  -- 16 regulatory-update rows
  insert into public.reg_intel_r3654 (
    organization_id, update_ref, standard_name, period_month, published_date,
    transition_deadline, days_to_deadline, devices_affected, gap_items,
    impact_assessment_done, action_plan_pct, source_body, impact_level,
    assessment_status, trend_dir, notes
  )
  select v_org_id, q.uref, q.sname, q.pmon::date, q.pdate::date,
    q.tdead::date, q.dtd, q.daf, q.gitems,
    q.iad, q.app, q.sbody, q.ilvl,
    q.astat, q.tdir, q.nt
  from (values
    ('RIU-2026-001','IEC 60601-1 Am.3 General Safety','2026-07-01','2026-06-18','2027-06-30',
     332,14,22,true,35.0,'iec','critical','action_in_progress','improving',
     'Amendment 3 essential-performance clauses mapped; design gap list issued to R&D for ICU ventilator line'),
    ('RIU-2026-002','IEC 60601-1-2 Ed.4.1 EMC','2026-07-01','2026-06-05','2026-12-31',
     151,11,9,true,60.0,'iec','major','action_in_progress','stable',
     'EMC retest slots booked at NABL lab for patient-monitor family'),
    ('RIU-2026-003','ISO 13485:2016 Am.1 QMS','2026-06-01','2026-05-12','2027-03-31',
     241,26,6,true,80.0,'iso','moderate','action_in_progress','improving',
     'QMS procedure deltas drafted; internal audit scheduled for August'),
    ('RIU-2026-004','CDSCO MDR-2017 Schedule 5 Amendment','2026-07-01','2026-06-25','2026-10-31',
     90,19,15,false,10.0,'cdsco','critical','deadline_risk','worsening',
     'Essential-principles checklist changes not yet assessed for legacy infusion-pump SKUs'),
    ('RIU-2026-005','IS 23485 BIS Medical Device QMS','2026-05-01','2026-04-20','2027-04-30',
     271,31,4,true,100.0,'bis','minor','closed','improving',
     'BIS QMS alignment verified against existing ISO 13485 system — no additional gaps'),
    ('RIU-2026-006','EU MDR 2017/745 Legacy-Device Amendment','2026-06-01','2026-05-28','2027-12-31',
     516,7,12,true,45.0,'mdr_amendment','major','action_in_progress','stable',
     'Notified-body query list answered; dialysis-machine technical file updates in progress'),
    ('RIU-2026-007','ISO 14971:2019 Risk-File Guidance Update','2026-05-01','2026-04-15','2026-11-30',
     120,24,8,true,70.0,'iso','moderate','action_in_progress','improving',
     'Risk-management files being re-templated to new benefit-risk guidance'),
    ('RIU-2026-008','AERB RF-MED/SC-3 Radiology Safety Code','2026-06-01','2026-05-20','2026-09-30',
     59,3,7,false,0.0,'aerb','major','not_assessed','worsening',
     'X-ray accessory line impact not yet assessed — RA owner unassigned'),
    ('RIU-2026-009','IEC 62304 Am.2 Software Lifecycle','2026-04-01','2026-03-18','2027-03-31',
     241,9,11,true,55.0,'iec','major','action_in_progress','stable',
     'SOUP inventory refresh underway for infusion-pump firmware'),
    ('RIU-2026-010','CDSCO Essential Principles Checklist Rev.4','2026-04-01','2026-03-30','2026-08-31',
     29,28,3,true,90.0,'cdsco','moderate','action_in_progress','improving',
     'Checklist re-mapping 90% complete; two labelling gaps pending closure'),
    ('RIU-2026-011','ISO 15223-1:2025 Labelling Symbols','2026-03-01','2026-02-25','2026-12-31',
     151,33,5,true,100.0,'iso','minor','closed','stable',
     'Label artwork updated and released across full catalogue'),
    ('RIU-2026-012','IS 13450 Part-1 BIS Adoption Update','2026-03-01','2026-02-10','2027-06-30',
     332,12,10,true,25.0,'bis','moderate','under_assessment','stable',
     'Awaiting BIS clarification on parallel IEC certification acceptance'),
    ('RIU-2026-013','IEC 80601-2-49 Multiparameter Monitor Particular','2026-02-01','2026-01-22','2026-10-31',
     90,6,13,true,40.0,'iec','critical','deadline_risk','worsening',
     'Alarm-system clause retest capacity blocked at accredited test lab'),
    ('RIU-2026-014','EU MDR Class-Up Reclassification Notice','2026-02-01','2026-01-15','2027-05-26',
     297,4,9,true,65.0,'mdr_amendment','major','action_in_progress','improving',
     'Reclassification dossier for dialysis consumables in notified-body review'),
    ('RIU-2026-015','AERB CT Dose-Notification Circular','2026-04-01','2026-03-25','2026-09-15',
     44,2,2,true,100.0,'aerb','no_impact','closed','stable',
     'Circular reviewed — no impact on EquipSeva-serviced CT install base'),
    ('RIU-2026-016','CDSCO Field-Safety Recall Guidance Rev.2','2026-05-01','2026-04-28','2026-08-15',
     13,21,4,false,15.0,'cdsco','major','under_assessment','worsening',
     'Recall SOP delta assessment started late — transition deadline in two weeks')
  ) as q(uref, sname, pmon, pdate, tdead, dtd, daf, gitems, iad, app, sbody, ilvl, astat, tdir, nt);

  -- 8 CAPA rows — attach to specific updates via update_ref
  insert into public.reg_intel_capa_actions_r3654 (
    update_id, root_cause, corrective_action, capa_status,
    compliance_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RIU-2026-004','no_gap_assessment_owner','complete_gap_assessment','escalated',
     180000.00,'Head RA - Priya Nair','2026-08-20',null,
     'Schedule-5 gap assessment fast-tracked; escalated to management review'),
    ('RIU-2026-008','regulatory_team_bandwidth','hire_regulatory_consultant','open',
     250000.00,'QA Director - Arvind Menon','2026-08-25',null,
     'AERB specialist consultant shortlisted for radiology accessory line'),
    ('RIU-2026-013','test_lab_capacity_shortage','retest_at_accredited_lab','in_progress',
     640000.00,'RA Manager - Kavitha Rao','2026-09-10',null,
     'Alarm-clause retest slot confirmed at TUV Bengaluru for monitor family'),
    ('RIU-2026-016','late_standard_monitoring','subscribe_standard_watch_service','in_progress',
     95000.00,'Compliance Lead - Rohit Shah','2026-08-08',null,
     'Standard-watch subscription activated; recall SOP delta in drafting'),
    ('RIU-2026-001','design_documentation_gap','update_technical_file','in_progress',
     420000.00,'R&D Head - Suresh Iyer','2026-10-31',null,
     'Essential-performance rationale being added to ventilator technical files'),
    ('RIU-2026-002','supplier_component_noncompliance','redesign_component','verification_pending',
     310000.00,'SQE - Meera Joshi','2026-09-30',null,
     'EMC filter module redesigned; pre-scan passed, full retest pending'),
    ('RIU-2026-006','translation_interpretation_delay','engage_notified_body','closed',
     150000.00,'RA Manager - Kavitha Rao','2026-07-15','2026-07-10',
     'Notified-body clarification received; legacy-device transition plan approved'),
    ('RIU-2026-012','pending_investigation','complete_gap_assessment','open',
     60000.00,'RA Associate - Nikhil Verma','2026-09-20',null,
     'BIS clarification awaited before gap list can be finalised')
  ) as q(uref, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.reg_intel_r3654 e
    on e.organization_id = v_org_id and e.update_ref = q.uref;
end;
$seed$;
