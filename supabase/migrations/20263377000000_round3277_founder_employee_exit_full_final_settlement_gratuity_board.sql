-- Round 3277: Founder Employee Exit / Full-and-Final (F&F) Settlement, Gratuity & Leave-Encashment Board
-- HR-finance governance — department × exit-type × notice-period × gratuity eligibility × leave encashment × pending-dues recovery × F&F settlement verdict × CAPA

-- =============================================================================
-- TABLE 1: employee_exit_fnf_r3277 — per exiting employee F&F settlement record
-- =============================================================================
create table if not exists public.employee_exit_fnf_r3277 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_code text not null,
  employee_name text not null,
  department text not null check (department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  exit_type text not null check (exit_type in (
    'resignation','termination','retirement','end_of_contract','absconding'
  )),
  last_working_date date not null,
  notice_period_served text not null check (notice_period_served in (
    'full','shortfall','waived','buyout'
  )),
  tenure_years numeric(5,2) not null,
  gratuity_eligible boolean not null,
  gratuity_amount_rupees numeric(12,2),
  leave_encashment_rupees numeric(12,2),
  pending_dues_recovery_rupees numeric(12,2),
  net_settlement_rupees numeric(12,2),
  fnf_target_date date not null,
  fnf_actual_date date,
  asset_return_complete boolean not null,
  exit_interview_done boolean not null,
  settlement_verdict text not null check (settlement_verdict in (
    'settled_on_time','settled_late','pending_clearance','disputed','withheld_recovery'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.employee_exit_fnf_r3277 enable row level security;

create index if not exists idx_employee_exit_fnf_r3277_org on public.employee_exit_fnf_r3277(organization_id);
create index if not exists idx_employee_exit_fnf_r3277_lwd on public.employee_exit_fnf_r3277(last_working_date);
create index if not exists idx_employee_exit_fnf_r3277_verdict on public.employee_exit_fnf_r3277(settlement_verdict);

-- =============================================================================
-- TABLE 2: employee_exit_fnf_capa_actions_r3277 — clearance/recovery/settlement CAPA actions
-- =============================================================================
create table if not exists public.employee_exit_fnf_capa_actions_r3277 (
  id uuid primary key default gen_random_uuid(),
  exit_id uuid not null references public.employee_exit_fnf_r3277(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'notice_shortfall_recovery','asset_not_returned','advance_recovery_pending','gratuity_dispute',
    'leave_encashment_dispute','settlement_delay','exit_interview_pending','fnf_documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'employee_absconded','manager_clearance_delay','finance_processing_backlog','asset_tracking_gap',
    'policy_interpretation_dispute','payroll_system_error','pending_investigation','vendor_dues_reconciliation'
  )),
  corrective_action text not null check (corrective_action in (
    'deduct_from_settlement','initiate_asset_recovery','expedite_manager_clearance','recompute_gratuity',
    'recompute_leave_encashment','legal_notice_issued','escalate_to_leadership','release_withheld_amount',
    'update_payroll_records','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gratuity_act_compliance','labour_law_notifiable','none','internal_only','statutory_pf_esi','legal_dispute_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.employee_exit_fnf_capa_actions_r3277 enable row level security;

create index if not exists idx_employee_exit_fnf_capa_r3277_exit on public.employee_exit_fnf_capa_actions_r3277(exit_id);
create index if not exists idx_employee_exit_fnf_capa_r3277_status on public.employee_exit_fnf_capa_actions_r3277(capa_status);

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

  -- 14 employee exit / F&F settlement rows
  insert into public.employee_exit_fnf_r3277 (
    organization_id, employee_code, employee_name, department, exit_type,
    last_working_date, notice_period_served, tenure_years, gratuity_eligible,
    gratuity_amount_rupees, leave_encashment_rupees, pending_dues_recovery_rupees, net_settlement_rupees,
    fnf_target_date, fnf_actual_date, asset_return_complete, exit_interview_done,
    settlement_verdict, notes
  )
  select v_org_id, q.code, q.name, q.dept, q.etype,
    q.lwd::date, q.nps, q.tenure, q.grel,
    q.gamt, q.lenc, q.dues, q.netamt,
    q.ftd::date, q.fad::date, q.arc, q.eid,
    q.sv, q.nt
  from (values
    ('EMP-1042','Rahul Verma','field_engineering','resignation','2026-06-15','full',5.50,true,
     78000.00,22000.00,0.00,265000.00,'2026-06-30','2026-06-28',true,true,
     'settled_on_time','Standard resignation, full notice served, cleared ahead of target'),
    ('EMP-0987','Priya Nair','sales','resignation','2026-06-20','shortfall',3.20,false,
     0.00,18000.00,35000.00,198000.00,'2026-07-05',null,false,true,
     'pending_clearance','Notice shortfall 15 days — buyout recovery pending, laptop not returned'),
    ('EMP-1120','Arjun Reddy','field_engineering','termination','2026-06-10','waived',2.10,false,
     0.00,9000.00,48000.00,62000.00,'2026-06-25','2026-07-08',true,false,
     'settled_late','Terminated for misconduct — tool-kit recovery deducted, F&F cleared 13 days late'),
    ('EMP-0754','Sneha Iyer','finance','retirement','2026-05-31','full',12.75,true,
     425000.00,68000.00,0.00,892000.00,'2026-06-15','2026-06-14',true,true,
     'settled_on_time','Superannuation — gratuity and leave encashment paid on retirement'),
    ('EMP-1201','Vikram Singh','field_engineering','absconding','2026-05-20','waived',1.40,false,
     0.00,0.00,85000.00,0.00,'2026-06-05',null,false,false,
     'withheld_recovery','Absconded with service laptop and demo unit — settlement withheld, recovery in progress'),
    ('EMP-0899','Deepa Menon','support','resignation','2026-06-25','full',5.60,true,
     92000.00,26000.00,0.00,288000.00,'2026-07-10',null,true,true,
     'pending_clearance','Full notice served — awaiting finance sign-off on F&F'),
    ('EMP-1055','Karthik Rao','office_ops','end_of_contract','2026-06-30','full',1.00,false,
     0.00,6000.00,0.00,54000.00,'2026-07-14',null,true,false,
     'pending_clearance','Fixed-term contract ended — exit interview not yet scheduled'),
    ('EMP-0666','Anjali Desai','leadership','resignation','2026-06-18','buyout',8.30,true,
     310000.00,88000.00,0.00,645000.00,'2026-07-03','2026-07-02',true,true,
     'settled_on_time','VP Ops resigned, notice bought out by new employer — cleared on time'),
    ('EMP-1188','Suresh Kumar','field_engineering','resignation','2026-06-05','shortfall',6.90,true,
     118000.00,31000.00,22000.00,342000.00,'2026-06-20','2026-07-01',true,true,
     'settled_late','Notice shortfall 10 days — recovery adjusted, cleared 11 days late'),
    ('EMP-0812','Meera Joshi','sales','termination','2026-06-12','waived',3.80,false,
     0.00,14000.00,58000.00,71000.00,'2026-06-27',null,false,true,
     'disputed','Terminated for target fraud — commission clawback disputed, asset return pending'),
    ('EMP-0733','Ramesh Pillai','finance','retirement','2026-06-28','full',15.20,true,
     512000.00,74000.00,0.00,985000.00,'2026-07-12',null,true,true,
     'pending_clearance','Retirement — gratuity computed, statutory PF settlement pending'),
    ('EMP-1099','Neha Gupta','support','resignation','2026-06-22','full',2.50,false,
     0.00,11000.00,0.00,96000.00,'2026-07-07','2026-07-06',true,true,
     'settled_on_time','Below 5-yr gratuity threshold — leave encashed, cleared on time'),
    ('EMP-0945','Manoj Yadav','field_engineering','end_of_contract','2026-06-08','full',4.90,false,
     0.00,16000.00,12000.00,138000.00,'2026-06-23','2026-07-04',true,false,
     'settled_late','Contract not renewed — minor advance recovery, cleared 11 days late'),
    ('EMP-1150','Lakshmi Menon','office_ops','resignation','2026-06-14','full',7.10,true,
     104000.00,29000.00,0.00,318000.00,'2026-06-29','2026-06-27',true,true,
     'settled_on_time','Relocation resignation — full clearance completed on time')
  ) as q(code, name, dept, etype, lwd, nps, tenure, grel, gamt, lenc, dues, netamt, ftd, fad, arc, eid, sv, nt);

  -- CAPA seed — attach to specific exits via employee_code
  insert into public.employee_exit_fnf_capa_actions_r3277 (
    exit_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EMP-0987','asset_not_returned','asset_tracking_gap','initiate_asset_recovery','in_progress','internal_only','2026-07-08',null,35000.00,'Laptop recovery initiated — notice buyout deduction applied to settlement'),
    ('EMP-1201','advance_recovery_pending','employee_absconded','legal_notice_issued','escalated','labour_law_notifiable','2026-06-30',null,85000.00,'Absconded with assets — legal notice issued, full settlement withheld'),
    ('EMP-1120','settlement_delay','manager_clearance_delay','expedite_manager_clearance','closed','internal_only','2026-06-25','2026-07-08',48000.00,'Reporting-manager clearance delayed — tool-kit recovery deducted, F&F closed'),
    ('EMP-0812','advance_recovery_pending','policy_interpretation_dispute','escalate_to_leadership','open','legal_dispute_risk','2026-07-15',null,58000.00,'Commission clawback disputed by employee — escalated to leadership review'),
    ('EMP-0733','fnf_documentation_gap','finance_processing_backlog','update_payroll_records','verification_pending','statutory_pf_esi','2026-07-14',null,0.00,'PF settlement documents pending with finance — payroll records being updated'),
    ('EMP-1055','exit_interview_pending','manager_clearance_delay','expedite_manager_clearance','open','internal_only','2026-07-16',null,0.00,'Exit interview not scheduled — HR to expedite before F&F release'),
    ('EMP-1188','notice_shortfall_recovery','policy_interpretation_dispute','deduct_from_settlement','closed','gratuity_act_compliance','2026-06-20','2026-07-01',22000.00,'Notice shortfall buyout recovered against gratuity-eligible dues — closed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.employee_exit_fnf_r3277 e
    on e.organization_id = v_org_id and e.employee_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Settlement verdict distribution
create or replace function public.founder_r3277_settlement_verdict_rollup()
returns table(settlement_verdict text, exits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.employee_exit_fnf_r3277)
  select l.settlement_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.employee_exit_fnf_r3277 l
  group by l.settlement_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_settlement_verdict_rollup() from public, anon;
grant execute on function public.founder_r3277_settlement_verdict_rollup() to authenticated;

-- 2) Department-level F&F scorecard
create or replace function public.founder_r3277_department_scorecard()
returns table(
  department text,
  total_exits bigint,
  settled_on_time bigint,
  settled_late bigint,
  pending bigint,
  disputed bigint,
  gratuity_paid_rupees numeric,
  recovery_rupees numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.settlement_verdict = 'settled_on_time')::bigint,
    count(*) filter (where l.settlement_verdict = 'settled_late')::bigint,
    count(*) filter (where l.settlement_verdict = 'pending_clearance')::bigint,
    count(*) filter (where l.settlement_verdict in ('disputed','withheld_recovery'))::bigint,
    coalesce(sum(l.gratuity_amount_rupees) filter (where l.gratuity_eligible),0)::numeric,
    coalesce(sum(l.pending_dues_recovery_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.settlement_verdict = 'settled_on_time')::numeric / nullif(count(*),0), 1)
  from public.employee_exit_fnf_r3277 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_department_scorecard() from public, anon;
grant execute on function public.founder_r3277_department_scorecard() to authenticated;

-- 3) Exit-type × department matrix
create or replace function public.founder_r3277_exit_type_department_matrix()
returns table(exit_type text, department text, exits bigint, settled_on_time bigint, avg_tenure_years numeric, avg_net_settlement_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exit_type, l.department, count(*)::bigint,
    count(*) filter (where l.settlement_verdict = 'settled_on_time')::bigint,
    round(avg(l.tenure_years), 2),
    round(avg(l.net_settlement_rupees), 0)
  from public.employee_exit_fnf_r3277 l
  group by l.exit_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_exit_type_department_matrix() from public, anon;
grant execute on function public.founder_r3277_exit_type_department_matrix() to authenticated;

-- 4) Daily exit / F&F trend (by last working date)
create or replace function public.founder_r3277_daily_fnf_trend()
returns table(exit_date date, exits bigint, settled_on_time bigint, settled_late bigint, pending bigint, disputed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.last_working_date,
    count(*)::bigint,
    count(*) filter (where l.settlement_verdict = 'settled_on_time')::bigint,
    count(*) filter (where l.settlement_verdict = 'settled_late')::bigint,
    count(*) filter (where l.settlement_verdict = 'pending_clearance')::bigint,
    count(*) filter (where l.settlement_verdict in ('disputed','withheld_recovery'))::bigint
  from public.employee_exit_fnf_r3277 l
  group by l.last_working_date
  order by l.last_working_date desc;
end;
$$;

revoke execute on function public.founder_r3277_daily_fnf_trend() from public, anon;
grant execute on function public.founder_r3277_daily_fnf_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3277_capa_status_board()
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
  from public.employee_exit_fnf_capa_actions_r3277 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_capa_status_board() from public, anon;
grant execute on function public.founder_r3277_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3277_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.employee_exit_fnf_capa_actions_r3277)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.employee_exit_fnf_capa_actions_r3277 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3277_root_cause_pareto() to authenticated;

-- 7) Regulatory / statutory impact digest
create or replace function public.founder_r3277_regulatory_impact_digest()
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
  from public.employee_exit_fnf_capa_actions_r3277 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3277_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3277_regulatory_impact_digest() to authenticated;

-- 8) High-risk F&F queue (individual exits needing attention)
create or replace function public.founder_r3277_high_risk_queue()
returns table(
  employee_code text,
  employee_name text,
  department text,
  exit_type text,
  last_working_date date,
  settlement_verdict text,
  notice_period_served text,
  net_settlement_rupees numeric,
  pending_dues_recovery_rupees numeric,
  asset_return_complete boolean,
  exit_interview_done boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_code, l.employee_name, l.department, l.exit_type, l.last_working_date,
    l.settlement_verdict, l.notice_period_served, l.net_settlement_rupees, l.pending_dues_recovery_rupees,
    l.asset_return_complete, l.exit_interview_done, l.notes
  from public.employee_exit_fnf_r3277 l
  where l.settlement_verdict in ('settled_late','pending_clearance','disputed','withheld_recovery')
     or l.asset_return_complete = false
     or l.exit_interview_done = false
     or l.notice_period_served = 'shortfall'
     or l.exit_type = 'absconding'
     or coalesce(l.pending_dues_recovery_rupees,0) > 0
  order by l.last_working_date desc, l.employee_name;
end;
$$;

revoke execute on function public.founder_r3277_high_risk_queue() from public, anon;
grant execute on function public.founder_r3277_high_risk_queue() to authenticated;
