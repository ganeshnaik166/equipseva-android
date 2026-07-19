-- Round 3320: Engineer New-Hire Onboarding, Joining-Formalities & Field-Readiness Tracker
-- HR/ops ramp log — onboarding verdict × region scorecard × role×region matrix × joining trend
--   × documents/statutory setup × tool-kit × training modules × buddy × supervised visit × CAPA

-- =============================================================================
-- TABLE 1: engineer_onboarding_r3320 — one row per new field-engineer hire
-- =============================================================================
create table if not exists public.engineer_onboarding_r3320 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  employee_code text not null,
  region text not null,
  role text not null check (role in (
    'junior_bmet','field_engineer','senior_engineer','specialist','area_lead'
  )),
  base_hospital text not null,
  joining_date date not null,
  documents_verified boolean not null default false,
  bank_pf_esi_setup boolean not null default false,
  tool_kit_issued boolean not null default false,
  id_uniform_issued boolean not null default false,
  safety_induction_done boolean not null default false,
  product_training_modules_completed int not null default 0,
  product_training_total int not null default 0,
  buddy_assigned boolean not null default false,
  first_supervised_visit_done boolean not null default false,
  days_to_first_solo_visit int,
  readiness_pct numeric(5,2),
  onboarding_verdict text not null check (onboarding_verdict in (
    'on_track','ahead','delayed','at_risk_attrition','ready_for_solo'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_onboarding_r3320 enable row level security;

create index if not exists idx_engineer_onboarding_r3320_org on public.engineer_onboarding_r3320(organization_id);
create index if not exists idx_engineer_onboarding_r3320_join on public.engineer_onboarding_r3320(joining_date);
create index if not exists idx_engineer_onboarding_r3320_verdict on public.engineer_onboarding_r3320(onboarding_verdict);

-- =============================================================================
-- TABLE 2: engineer_onboarding_capa_actions_r3320 — expedite / support actions
-- =============================================================================
create table if not exists public.engineer_onboarding_capa_actions_r3320 (
  id uuid primary key default gen_random_uuid(),
  onboarding_id uuid not null references public.engineer_onboarding_r3320(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'documents_pending','statutory_setup_delay','tool_kit_shortage','credential_access_delay',
    'training_backlog','buddy_unassigned','field_readiness_gap','attrition_risk'
  )),
  root_cause text not null check (root_cause in (
    'candidate_document_delay','hr_backlog','procurement_delay','vendor_lead_time',
    'trainer_unavailable','buddy_on_leave','manager_bandwidth','relocation_issue',
    'pending_investigation','compensation_mismatch'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_document_collection','escalate_to_hr_ops','issue_loaner_tool_kit','fast_track_credentials',
    'schedule_extra_training','assign_backup_buddy','manager_checkin','revise_offer_retention',
    'extend_supervised_period','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  support_impact text not null check (support_impact in (
    'delays_first_solo_visit','sla_coverage_gap','attrition_risk','none','onboarding_only','compliance_statutory'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_onboarding_capa_actions_r3320 enable row level security;

create index if not exists idx_engineer_onboarding_capa_r3320_log on public.engineer_onboarding_capa_actions_r3320(onboarding_id);
create index if not exists idx_engineer_onboarding_capa_r3320_status on public.engineer_onboarding_capa_actions_r3320(capa_status);

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

  -- 14 new-hire onboarding rows
  insert into public.engineer_onboarding_r3320 (
    organization_id, employee_name, employee_code, region, role, base_hospital,
    joining_date, documents_verified, bank_pf_esi_setup, tool_kit_issued,
    id_uniform_issued, safety_induction_done, product_training_modules_completed,
    product_training_total, buddy_assigned, first_supervised_visit_done,
    days_to_first_solo_visit, readiness_pct, onboarding_verdict, notes
  )
  select v_org_id, q.name, q.code, q.region, q.role, q.base,
    q.jd::date, q.docv, q.bank, q.kit,
    q.idu, q.safety, q.modc,
    q.modt, q.buddy, q.fsv,
    q.dsolo, q.rpct, q.verdict, q.nt
  from (values
    ('Arjun Nair','ENG-3320-01','Chennai','field_engineer','Apollo Chennai Greams Road','2026-06-15',
     true,true,true,true,true,8,8,true,true,11,100.00,'ready_for_solo','All formalities complete — cleared for independent field visits'),
    ('Priya Raman','ENG-3320-02','Bengaluru','junior_bmet','Manipal Whitefield Bengaluru','2026-06-20',
     true,true,true,true,true,6,8,true,true,14,88.00,'on_track','Two training modules pending — on track for solo by week 3'),
    ('Vikram Singh','ENG-3320-03','Delhi NCR','field_engineer','Fortis Gurgaon','2026-06-22',
     true,true,true,true,true,8,8,true,true,9,100.00,'ahead','Prior BMET experience — ahead of ramp curve'),
    ('Sneha Iyer','ENG-3320-04','Hyderabad','junior_bmet','KIMS Secunderabad','2026-06-25',
     true,false,true,true,true,4,8,true,false,null,62.00,'delayed','PF/ESI setup stuck at HR — supervised visit not yet done'),
    ('Rahul Deshmukh','ENG-3320-05','Mumbai','field_engineer','Kokilaben Mumbai','2026-06-18',
     true,true,false,true,true,7,8,true,true,null,74.00,'delayed','Tool kit not issued — procurement backorder blocking solo visits'),
    ('Ananya Ghosh','ENG-3320-06','Kolkata','junior_bmet','AMRI Kolkata','2026-06-28',
     false,false,false,false,false,1,8,false,false,null,15.00,'at_risk_attrition','No response to onboarding since day 2 — relocation being reconsidered'),
    ('Karthik Menon','ENG-3320-07','Vellore','senior_engineer','CMC Vellore','2026-06-10',
     true,true,true,true,true,8,8,true,true,7,100.00,'ready_for_solo','Senior hire — fast-tracked, now mentoring two juniors'),
    ('Meera Pillai','ENG-3320-08','Chennai','specialist','Apollo Chennai Greams Road','2026-06-26',
     true,true,true,true,false,5,10,true,false,null,68.00,'on_track','Imaging specialist — safety induction rescheduled to next batch'),
    ('Aditya Rao','ENG-3320-09','Bengaluru','field_engineer','Narayana Health Bengaluru','2026-06-23',
     true,true,true,false,true,6,8,true,true,13,84.00,'on_track','ID card and uniform pending — otherwise field-ready'),
    ('Divya Krishnan','ENG-3320-10','Delhi NCR','junior_bmet','AIIMS Delhi Ansari Nagar','2026-06-29',
     true,false,true,true,true,3,8,false,false,null,55.00,'delayed','Buddy unassigned and training behind — supervisor bandwidth low'),
    ('Suresh Kumar','ENG-3320-11','Hyderabad','area_lead','Yashoda Somajiguda Hyderabad','2026-06-12',
     true,true,true,true,true,10,10,true,true,6,100.00,'ready_for_solo','Area lead onboarded — taking regional ownership'),
    ('Nisha Verma','ENG-3320-12','Pune','junior_bmet','Ruby Hall Pune','2026-07-01',
     true,true,true,true,true,2,8,true,false,null,58.00,'on_track','Recently joined — early in training, ramp nominal'),
    ('Faisal Khan','ENG-3320-13','Mumbai','field_engineer','Fortis Mulund Mumbai','2026-06-16',
     true,true,true,true,true,7,8,true,true,15,92.00,'on_track','One advanced module left — solo visit slated this week'),
    ('Lakshmi Nair','ENG-3320-14','Kochi','junior_bmet','Amrita Kochi','2026-06-30',
     false,false,true,false,false,2,8,true,false,null,32.00,'at_risk_attrition','Documents incomplete, competing offer — retention conversation open')
  ) as q(name, code, region, role, base, jd, docv, bank, kit, idu, safety, modc, modt, buddy, fsv, dsolo, rpct, verdict, nt);

  -- CAPA seed — attach to specific hires via employee_code
  insert into public.engineer_onboarding_capa_actions_r3320 (
    onboarding_id, finding_category, root_cause, corrective_action,
    capa_status, support_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ENG-3320-04','statutory_setup_delay','hr_backlog','escalate_to_hr_ops','in_progress','delays_first_solo_visit','2026-07-10',null,0.00,'HR expediting PF/ESI enrolment — solo visit blocked until complete'),
    ('ENG-3320-05','tool_kit_shortage','procurement_delay','issue_loaner_tool_kit','in_progress','delays_first_solo_visit','2026-07-08',null,8500.00,'Loaner kit arranged from Mumbai depot pending own kit delivery'),
    ('ENG-3320-06','attrition_risk','relocation_issue','revise_offer_retention','escalated','attrition_risk','2026-07-05',null,0.00,'Escalated to regional HR — relocation support package offered'),
    ('ENG-3320-10','buddy_unassigned','manager_bandwidth','assign_backup_buddy','open','delays_first_solo_visit','2026-07-12',null,0.00,'Backup buddy from AIIMS team to be assigned this week'),
    ('ENG-3320-14','documents_pending','candidate_document_delay','expedite_document_collection','overdue','attrition_risk','2026-06-28',null,0.00,'Documents overdue and competing offer — retention call pending'),
    ('ENG-3320-08','field_readiness_gap','trainer_unavailable','schedule_extra_training','verification_pending','onboarding_only','2026-07-06','2026-07-04',3000.00,'Safety induction completed in next batch — verifying certificate'),
    ('ENG-3320-10','training_backlog','trainer_unavailable','schedule_extra_training','in_progress','delays_first_solo_visit','2026-07-14',null,4500.00,'Extra weekend training scheduled to clear module backlog')
  ) as q(code, fc, rc, ca, cst, si, tcd, acd, cost, nt)
  join public.engineer_onboarding_r3320 e
    on e.organization_id = v_org_id and e.employee_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Onboarding verdict distribution
create or replace function public.founder_r3320_onboarding_verdict_rollup()
returns table(onboarding_verdict text, hires bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_onboarding_r3320)
  select l.onboarding_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_onboarding_r3320 l
  group by l.onboarding_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_onboarding_verdict_rollup() from public, anon;
grant execute on function public.founder_r3320_onboarding_verdict_rollup() to authenticated;

-- 2) Region-level onboarding scorecard
create or replace function public.founder_r3320_region_scorecard()
returns table(
  region text,
  total_hires bigint,
  ready_for_solo bigint,
  on_track_ahead bigint,
  delayed bigint,
  at_risk bigint,
  docs_pending bigint,
  training_incomplete bigint,
  avg_readiness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.onboarding_verdict = 'ready_for_solo')::bigint,
    count(*) filter (where l.onboarding_verdict in ('on_track','ahead'))::bigint,
    count(*) filter (where l.onboarding_verdict = 'delayed')::bigint,
    count(*) filter (where l.onboarding_verdict = 'at_risk_attrition')::bigint,
    count(*) filter (where l.documents_verified = false)::bigint,
    count(*) filter (where l.product_training_modules_completed < l.product_training_total)::bigint,
    round(avg(l.readiness_pct), 1)
  from public.engineer_onboarding_r3320 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_region_scorecard() from public, anon;
grant execute on function public.founder_r3320_region_scorecard() to authenticated;

-- 3) Role × region readiness matrix
create or replace function public.founder_r3320_role_region_matrix()
returns table(role text, region text, hires bigint, ready_for_solo bigint, avg_readiness_pct numeric, avg_days_to_first_solo_visit numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.role, l.region, count(*)::bigint,
    count(*) filter (where l.onboarding_verdict = 'ready_for_solo')::bigint,
    round(avg(l.readiness_pct), 1),
    round(avg(l.days_to_first_solo_visit), 1)
  from public.engineer_onboarding_r3320 l
  group by l.role, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_role_region_matrix() from public, anon;
grant execute on function public.founder_r3320_role_region_matrix() to authenticated;

-- 4) Joining-date onboarding trend
create or replace function public.founder_r3320_joining_trend()
returns table(joining_date date, hires bigint, ready_for_solo bigint, delayed bigint, at_risk bigint, avg_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.joining_date,
    count(*)::bigint,
    count(*) filter (where l.onboarding_verdict = 'ready_for_solo')::bigint,
    count(*) filter (where l.onboarding_verdict = 'delayed')::bigint,
    count(*) filter (where l.onboarding_verdict = 'at_risk_attrition')::bigint,
    round(avg(l.readiness_pct), 1)
  from public.engineer_onboarding_r3320 l
  group by l.joining_date
  order by l.joining_date desc;
end;
$$;

revoke execute on function public.founder_r3320_joining_trend() from public, anon;
grant execute on function public.founder_r3320_joining_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3320_capa_status_board()
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
  from public.engineer_onboarding_capa_actions_r3320 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_capa_status_board() from public, anon;
grant execute on function public.founder_r3320_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3320_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_onboarding_capa_actions_r3320)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_onboarding_capa_actions_r3320 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3320_root_cause_pareto() to authenticated;

-- 7) Support-impact / cost-risk digest
create or replace function public.founder_r3320_support_impact_digest()
returns table(support_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.support_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_onboarding_capa_actions_r3320 c
  group by c.support_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3320_support_impact_digest() from public, anon;
grant execute on function public.founder_r3320_support_impact_digest() to authenticated;

-- 8) High-risk onboarding queue (individual concerns)
create or replace function public.founder_r3320_high_risk_queue()
returns table(
  employee_name text,
  employee_code text,
  region text,
  role text,
  joining_date date,
  onboarding_verdict text,
  readiness_pct numeric,
  documents_verified boolean,
  product_training_modules_completed int,
  product_training_total int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.employee_code, l.region, l.role, l.joining_date,
    l.onboarding_verdict, l.readiness_pct, l.documents_verified,
    l.product_training_modules_completed, l.product_training_total, l.notes
  from public.engineer_onboarding_r3320 l
  where l.onboarding_verdict in ('delayed','at_risk_attrition')
     or l.documents_verified = false
     or l.bank_pf_esi_setup = false
     or l.tool_kit_issued = false
     or l.safety_induction_done = false
     or l.buddy_assigned = false
     or l.product_training_modules_completed < l.product_training_total
  order by l.readiness_pct asc, l.joining_date desc;
end;
$$;

revoke execute on function public.founder_r3320_high_risk_queue() from public, anon;
grant execute on function public.founder_r3320_high_risk_queue() to authenticated;
