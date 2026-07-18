-- Round 3233: Founder Quarterly-OKR Confidence & Key-Result Trajectory Board
-- OKR board — quarter × objective × key result × owner × target/current × progress % × confidence 1-10 × trajectory × blocker × verdict; + course-correct/CAPA actions

-- =============================================================================
-- TABLE 1: okr_trajectory_r3233 — quarterly key-result trajectory log
-- =============================================================================
create table if not exists public.okr_trajectory_r3233 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  quarter_label text not null check (quarter_label in (
    'q1_fy2026','q2_fy2026','q3_fy2026','q4_fy2026','q1_fy2027'
  )),
  objective_code text not null check (objective_code in (
    'expand_amc_coverage','improve_first_time_fix','grow_marketplace_gmv',
    'compliance_audit_readiness','hospital_nps_uplift','reduce_ticket_resolution_time',
    'uptime_sla_assurance','engineer_retention_uplift'
  )),
  objective_title text not null,
  key_result_code text not null,
  key_result_desc text not null,
  owner_name text not null,
  owner_role text not null check (owner_role in (
    'founder','ops_lead','sales_lead','engineering_lead',
    'finance_lead','customer_success_lead','product_lead'
  )),
  metric_unit text not null check (metric_unit in (
    'percent','rupees_lakh','count','nps_points','days','hours'
  )),
  target_value numeric(12,2) not null,
  baseline_value numeric(12,2),
  current_value numeric(12,2) not null,
  progress_pct numeric(5,1) not null,
  confidence_score int not null check (confidence_score between 1 and 10),
  trajectory text not null check (trajectory in (
    'ahead','on_track','at_risk','off_track'
  )),
  blocker_noted boolean not null default false,
  blocker_summary text,
  review_date date not null,
  verdict text not null check (verdict in (
    'committed_green','watchlist_amber','recovery_plan_red',
    'stretch_exceeded','carried_forward','descoped'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.okr_trajectory_r3233 enable row level security;

create index if not exists idx_okr_trajectory_r3233_org on public.okr_trajectory_r3233(organization_id);
create index if not exists idx_okr_trajectory_r3233_traj on public.okr_trajectory_r3233(trajectory);
create index if not exists idx_okr_trajectory_r3233_verdict on public.okr_trajectory_r3233(verdict);

-- =============================================================================
-- TABLE 2: okr_trajectory_capa_actions_r3233 — course-correct / CAPA actions
-- =============================================================================
create table if not exists public.okr_trajectory_capa_actions_r3233 (
  id uuid primary key default gen_random_uuid(),
  okr_id uuid not null references public.okr_trajectory_r3233(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'velocity_shortfall','confidence_collapse','metric_definition_drift',
    'owner_bandwidth_gap','dependency_slip','data_pipeline_gap',
    'sandbagged_target','scope_creep'
  )),
  root_cause text not null check (root_cause in (
    'hiring_delay','vendor_dependency','pricing_pushback','engineer_attrition',
    'instrumentation_missing','competing_priorities','seasonal_demand_dip',
    'process_not_defined','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reallocate_owner','descope_key_result','add_weekly_checkin',
    'unblock_dependency','revise_target','spin_up_task_force',
    'fix_metric_instrumentation','escalate_to_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_reportable','investor_update_flag','none','internal_only',
    'audit_committee_flag','statutory_filing_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.okr_trajectory_capa_actions_r3233 enable row level security;

create index if not exists idx_okr_capa_r3233_okr on public.okr_trajectory_capa_actions_r3233(okr_id);
create index if not exists idx_okr_capa_r3233_status on public.okr_trajectory_capa_actions_r3233(capa_status);

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

  -- 14 key-result trajectory rows
  insert into public.okr_trajectory_r3233 (
    organization_id, entity_name, quarter_label, objective_code, objective_title,
    key_result_code, key_result_desc, owner_name, owner_role, metric_unit,
    target_value, baseline_value, current_value, progress_pct, confidence_score,
    trajectory, blocker_noted, blocker_summary, review_date, verdict, notes
  )
  select v_org_id, q.ent, q.ql, q.oc, q.ot,
    q.krc, q.krd, q.own, q.orole, q.mu,
    q.tv, q.bv, q.cv, q.pp, q.cs,
    q.tr, q.bn, q.bs, q.rd::date, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','q3_fy2026','expand_amc_coverage','Deepen AMC penetration in flagship accounts',
     'kr_amc_apollo_coverage','Grow AMC-covered assets from 120 to 180','Ganesh','founder','count',
     180.00,120.00,158.00,63.3,8,'on_track',false,null,'2026-07-15','committed_green','Renewal wave landing ahead of plan'),
    ('Fortis Bannerghatta Bengaluru','q3_fy2026','improve_first_time_fix','Lift first-time-fix rate on priority tickets',
     'kr_ftf_fortis_rate','Raise first-time-fix from 68% to 85%','Meera Iyer','ops_lead','percent',
     85.00,68.00,74.00,35.3,5,'at_risk',true,'Spare-part logistics delaying repeat visits','2026-07-14','watchlist_amber','FTF stuck below glidepath for 3 weeks'),
    ('Manipal Whitefield Bengaluru','q3_fy2026','grow_marketplace_gmv','Scale marketplace repair GMV',
     'kr_gmv_manipal_market','Grow quarterly GMV from 12L to 45L','Arjun Rao','sales_lead','rupees_lakh',
     45.00,12.00,47.00,106.1,10,'ahead',false,null,'2026-07-12','stretch_exceeded','Beat target 3 weeks early on ortho-drill bids'),
    ('AIIMS New Delhi Ansari Nagar','q3_fy2026','compliance_audit_readiness','Be audit-ready for institutional buyers',
     'kr_audit_aiims_binder','Close 100% of calibration-certificate gaps','Sanya Kapoor','customer_success_lead','percent',
     100.00,40.00,55.00,25.0,3,'off_track',true,'Calibration certificate backlog blocking audit binder','2026-07-15','recovery_plan_red','Recovery plan owned by founder from this week'),
    ('KIMS Secunderabad','q3_fy2026','hospital_nps_uplift','Raise biomedical-team NPS in anchor accounts',
     'kr_nps_kims_uplift','Lift NPS from 48 to 65','Meera Iyer','ops_lead','nps_points',
     65.00,48.00,57.00,52.9,7,'on_track',false,null,'2026-07-13','committed_green','Detractor follow-ups converting well'),
    ('Care Hospitals Banjara Hills','q3_fy2026','reduce_ticket_resolution_time','Cut median ticket resolution time',
     'kr_ttr_care_hours','Bring median resolution from 72h to 24h','Vikram Shetty','engineering_lead','hours',
     24.00,72.00,40.00,66.7,7,'on_track',false,null,'2026-07-11','committed_green','Triage bot deflecting misrouted tickets'),
    ('Yashoda Somajiguda Hyderabad','q3_fy2026','uptime_sla_assurance','Guarantee uptime SLA on critical-care fleet',
     'kr_uptime_yashoda_sla','Raise monitored-fleet uptime from 94.5% to 99%','Vikram Shetty','engineering_lead','percent',
     99.00,94.50,96.20,37.8,5,'at_risk',true,'Two telemetry monitors awaiting OEM parts','2026-07-14','watchlist_amber','OEM ETA slipped twice'),
    ('St John''s Bengaluru','q3_fy2026','expand_amc_coverage','Deepen AMC penetration in flagship accounts',
     'kr_amc_stjohns_expand','Grow AMC-covered assets from 40 to 90','Arjun Rao','sales_lead','count',
     90.00,40.00,44.00,8.0,2,'off_track',true,'Procurement committee deferred AMC decision to Q4','2026-07-15','recovery_plan_red','Considering retarget to 60 assets'),
    ('Rainbow Children''s Hyderabad','q3_fy2026','hospital_nps_uplift','Raise biomedical-team NPS in anchor accounts',
     'kr_nps_rainbow_uplift','Lift NPS from 61 to 70','Sanya Kapoor','customer_success_lead','nps_points',
     70.00,61.00,66.00,55.6,8,'on_track',false,null,'2026-07-12','committed_green','Paediatric ICU team now promoter cohort'),
    ('Apollo Hyderabad Jubilee Hills','q3_fy2026','grow_marketplace_gmv','Scale marketplace repair GMV',
     'kr_gmv_apollo_market','Grow quarterly GMV from 8L to 30L','Arjun Rao','sales_lead','rupees_lakh',
     30.00,8.00,12.00,18.2,4,'at_risk',true,'Marketplace bids stuck in hospital finance approval','2026-07-14','watchlist_amber','Three bids worth 6L pending sign-off'),
    ('Manipal Whitefield Bengaluru','q3_fy2026','improve_first_time_fix','Lift first-time-fix rate on priority tickets',
     'kr_ftf_manipal_rate','Raise first-time-fix from 75% to 88%','Meera Iyer','ops_lead','percent',
     88.00,75.00,84.00,69.2,8,'ahead',false,null,'2026-07-13','committed_green','Van-stock refresh paying off'),
    ('Fortis Bannerghatta Bengaluru','q3_fy2026','compliance_audit_readiness','Be audit-ready for institutional buyers',
     'kr_audit_fortis_nabh','Clear 100% of NABH mock-audit observations','Sanya Kapoor','customer_success_lead','percent',
     100.00,55.00,58.00,6.7,3,'off_track',true,'NABH mock-audit slot slipped to August','2026-07-15','recovery_plan_red','Task force proposed at Monday review'),
    ('KIMS Secunderabad','q2_fy2026','engineer_retention_uplift','Retain senior field engineers in Hyderabad pod',
     'kr_retention_kims_engineers','Hold 12-month retention at 92% vs 80% baseline','Ganesh','founder','percent',
     92.00,80.00,86.00,50.0,6,'on_track',false,null,'2026-07-10','carried_forward','Carried from Q2 with revised comp bands'),
    ('Yashoda Somajiguda Hyderabad','q2_fy2026','grow_marketplace_gmv','Scale marketplace repair GMV',
     'kr_gmv_yashoda_market','Grow quarterly GMV from 5L to 20L','Arjun Rao','sales_lead','rupees_lakh',
     20.00,5.00,6.00,6.7,2,'off_track',true,'Hospital moved to rival marketplace pilot','2026-07-09','descoped','Descoped after account review; revisit in Q4')
  ) as q(ent, ql, oc, ot, krc, krd, own, orole, mu, tv, bv, cv, pp, cs, tr, bn, bs, rd, vd, nt);

  -- CAPA / course-correct seed — attach to specific key results
  insert into public.okr_trajectory_capa_actions_r3233 (
    okr_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('kr_ftf_fortis_rate','velocity_shortfall','vendor_dependency','unblock_dependency','2026-07-25',null,'in_progress','internal_only',65000.00,'Advance-stock top-20 spares at Bengaluru hub'),
    ('kr_audit_aiims_binder','dependency_slip','instrumentation_missing','fix_metric_instrumentation','2026-07-20',null,'escalated','board_reportable',120000.00,'Calibration tracker rollout pulled forward by 4 weeks'),
    ('kr_amc_stjohns_expand','confidence_collapse','pricing_pushback','revise_target','2026-08-05',null,'open','investor_update_flag',0.00,'Retarget to 60 assets pending procurement vote'),
    ('kr_gmv_apollo_market','velocity_shortfall','competing_priorities','add_weekly_checkin','2026-07-18','2026-07-16','closed','internal_only',8000.00,'Weekly finance-desk cadence unblocked three bids'),
    ('kr_audit_fortis_nabh','dependency_slip','vendor_dependency','spin_up_task_force','2026-08-10',null,'open','audit_committee_flag',45000.00,'Cross-functional NABH task force staffed 3 FTE-weeks'),
    ('kr_uptime_yashoda_sla','dependency_slip','vendor_dependency','unblock_dependency','2026-07-05',null,'overdue','none',90000.00,'OEM part escalation raised to regional manager'),
    ('kr_gmv_yashoda_market','confidence_collapse','pricing_pushback','descope_key_result','2026-07-10','2026-07-08','closed','investor_update_flag',15000.00,'Descope ratified; account moved to nurture list')
  ) as q(krc, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.okr_trajectory_r3233 e
    on e.organization_id = v_org_id and e.key_result_code = q.krc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution across key results
create or replace function public.founder_r3233_verdict_trajectory_rollup()
returns table(verdict text, key_results bigint, avg_confidence numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.okr_trajectory_r3233)
  select l.verdict, count(*)::bigint,
         round(avg(l.confidence_score)::numeric, 1),
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.okr_trajectory_r3233 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_verdict_trajectory_rollup() from public, anon;
grant execute on function public.founder_r3233_verdict_trajectory_rollup() to authenticated;

-- 2) Entity / account scorecard
create or replace function public.founder_r3233_entity_scorecard()
returns table(
  entity_name text,
  key_results bigint,
  ahead bigint,
  on_track bigint,
  at_risk bigint,
  off_track bigint,
  blockers bigint,
  avg_confidence numeric,
  avg_progress_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.trajectory = 'ahead')::bigint,
    count(*) filter (where l.trajectory = 'on_track')::bigint,
    count(*) filter (where l.trajectory = 'at_risk')::bigint,
    count(*) filter (where l.trajectory = 'off_track')::bigint,
    count(*) filter (where l.blocker_noted)::bigint,
    round(avg(l.confidence_score)::numeric, 1),
    round(avg(l.progress_pct)::numeric, 1)
  from public.okr_trajectory_r3233 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_entity_scorecard() from public, anon;
grant execute on function public.founder_r3233_entity_scorecard() to authenticated;

-- 3) Objective × quarter matrix
create or replace function public.founder_r3233_objective_quarter_matrix()
returns table(objective_code text, quarter_label text, key_results bigint, avg_progress_pct numeric, avg_confidence numeric, off_track bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.objective_code, l.quarter_label, count(*)::bigint,
    round(avg(l.progress_pct)::numeric, 1),
    round(avg(l.confidence_score)::numeric, 1),
    count(*) filter (where l.trajectory = 'off_track')::bigint
  from public.okr_trajectory_r3233 l
  group by l.objective_code, l.quarter_label
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_objective_quarter_matrix() from public, anon;
grant execute on function public.founder_r3233_objective_quarter_matrix() to authenticated;

-- 4) Review-date confidence trend
create or replace function public.founder_r3233_review_confidence_trend()
returns table(review_date date, key_results bigint, avg_confidence numeric, avg_progress_pct numeric, blockers bigint, at_risk_or_off bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_date, count(*)::bigint,
    round(avg(l.confidence_score)::numeric, 1),
    round(avg(l.progress_pct)::numeric, 1),
    count(*) filter (where l.blocker_noted)::bigint,
    count(*) filter (where l.trajectory in ('at_risk','off_track'))::bigint
  from public.okr_trajectory_r3233 l
  group by l.review_date
  order by l.review_date desc;
end;
$$;

revoke execute on function public.founder_r3233_review_confidence_trend() from public, anon;
grant execute on function public.founder_r3233_review_confidence_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3233_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, escalated_or_overdue bigint)
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
  from public.okr_trajectory_capa_actions_r3233 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_capa_status_board() from public, anon;
grant execute on function public.founder_r3233_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3233_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.okr_trajectory_capa_actions_r3233)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.okr_trajectory_capa_actions_r3233 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3233_root_cause_pareto() to authenticated;

-- 7) Regulatory / governance impact digest
create or replace function public.founder_r3233_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.okr_trajectory_capa_actions_r3233 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3233_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3233_regulatory_impact_digest() to authenticated;

-- 8) Low-confidence / at-risk key-result queue
create or replace function public.founder_r3233_low_confidence_queue()
returns table(
  entity_name text,
  quarter_label text,
  key_result_code text,
  key_result_desc text,
  owner_name text,
  trajectory text,
  confidence_score int,
  progress_pct numeric,
  verdict text,
  blocker_summary text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.quarter_label, l.key_result_code, l.key_result_desc, l.owner_name,
    l.trajectory, l.confidence_score, l.progress_pct, l.verdict, l.blocker_summary
  from public.okr_trajectory_r3233 l
  where l.trajectory in ('at_risk','off_track')
     or l.confidence_score <= 4
     or l.blocker_noted
  order by l.confidence_score asc, l.progress_pct asc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3233_low_confidence_queue() from public, anon;
grant execute on function public.founder_r3233_low_confidence_queue() to authenticated;
