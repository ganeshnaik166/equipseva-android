-- Round 3185: Founder Hiring-Funnel Velocity & Offer-Acceptance Board
-- Hiring funnel log — role family × level × source channel × sourced/screened/interviewed/offered/accepted/joined × days-to-offer × offer-acceptance % × CAPA

-- =============================================================================
-- TABLE 1: hiring_funnel_r3185 — per-requisition hiring funnel log
-- =============================================================================
create table if not exists public.hiring_funnel_r3185 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  requisition_code text not null,
  role_title text not null,
  role_family text not null check (role_family in (
    'field_service_engineer','biomedical_engineer','sales_executive','customer_success',
    'operations_manager','software_engineer','quality_regulatory','finance_analyst'
  )),
  level text not null check (level in (
    'intern','associate','mid_level','senior','lead','manager','director'
  )),
  source_channel text not null check (source_channel in (
    'employee_referral','linkedin_inbound','job_portal_naukri','campus_placement',
    'agency_recruiter','walk_in','internal_transfer','headhunted_passive'
  )),
  funnel_stage_status text not null check (funnel_stage_status in (
    'sourcing','screening','interviewing','offer_extended','offer_accepted',
    'offer_declined','joined','dropped_out','on_hold','requisition_cancelled'
  )),
  sourced_count int not null default 0,
  screened_count int not null default 0,
  interviewed_count int not null default 0,
  offered_count int not null default 0,
  accepted_count int not null default 0,
  joined_count int not null default 0,
  requisition_opened_on date not null,
  offer_extended_on date,
  days_to_offer int,
  offer_acceptance_pct numeric(5,2),
  recruiter_name text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hiring_funnel_r3185 enable row level security;

create index if not exists idx_hiring_funnel_r3185_org on public.hiring_funnel_r3185(organization_id);
create index if not exists idx_hiring_funnel_r3185_stage on public.hiring_funnel_r3185(funnel_stage_status);
create index if not exists idx_hiring_funnel_r3185_opened on public.hiring_funnel_r3185(requisition_opened_on);

-- =============================================================================
-- TABLE 2: hiring_funnel_capa_actions_r3185 — funnel follow-up & CAPA actions
-- =============================================================================
create table if not exists public.hiring_funnel_capa_actions_r3185 (
  id uuid primary key default gen_random_uuid(),
  funnel_id uuid not null references public.hiring_funnel_r3185(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'offer_decline_spike','slow_screening','interview_no_show','low_sourcing_volume',
    'salary_band_mismatch','candidate_ghosting','joining_delay','panel_unavailability',
    'jd_quality_issue','background_check_delay'
  )),
  root_cause text not null check (root_cause in (
    'compensation_below_market','slow_feedback_loop','weak_employer_brand',
    'agency_dependency','panel_bandwidth_crunch','unclear_role_scope',
    'notice_period_buyout_missing','location_constraint','pending_investigation','competitor_counter_offer'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_salary_band','add_interview_panelists','sla_on_feedback_48h',
    'activate_referral_bonus','switch_sourcing_channel','rewrite_job_description',
    'offer_notice_buyout','fast_track_top_candidates','none_required','engage_new_agency'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'labor_law_exposure','contract_sla_breach','audit_flag','offer_compliance_issue','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hiring_funnel_capa_actions_r3185 enable row level security;

create index if not exists idx_hiring_capa_r3185_funnel on public.hiring_funnel_capa_actions_r3185(funnel_id);
create index if not exists idx_hiring_capa_r3185_status on public.hiring_funnel_capa_actions_r3185(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 hiring funnel rows
  insert into public.hiring_funnel_r3185 (
    organization_id, hospital_name, requisition_code, role_title, role_family,
    level, source_channel, funnel_stage_status,
    sourced_count, screened_count, interviewed_count, offered_count, accepted_count, joined_count,
    requisition_opened_on, offer_extended_on, days_to_offer, offer_acceptance_pct,
    recruiter_name, notes
  )
  select v_org_id, q.hosp, q.req, q.rt, q.rf,
    q.lv, q.sc, q.st,
    q.src, q.scr, q.iv, q.ofr, q.acc, q.jn,
    q.op::date, q.oe::date, q.dto, q.oap,
    q.rec, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','REQ-3185-001','Senior Field Service Engineer','field_service_engineer','senior','employee_referral','joined',
     18,9,5,2,2,2,'2026-05-04','2026-06-01',28,100.00,'Kavya Menon','Both offers accepted and joined on time'),
    ('Apollo Hyderabad Jubilee Hills','REQ-3185-002','Biomedical Engineer - OT Support','biomedical_engineer','mid_level','job_portal_naukri','offer_declined',
     34,15,7,3,1,0,'2026-05-18','2026-06-15',28,33.33,'Kavya Menon','Two declines citing compensation band'),
    ('Fortis Bannerghatta Bengaluru','REQ-3185-003','Field Service Engineer','field_service_engineer','associate','campus_placement','joined',
     40,22,10,4,4,3,'2026-04-20','2026-05-22',32,100.00,'Rohit Shetty','Campus batch; one joiner deferred to next month'),
    ('Fortis Bannerghatta Bengaluru','REQ-3185-004','Customer Success Manager','customer_success','manager','linkedin_inbound','offer_extended',
     26,12,6,2,0,0,'2026-06-02','2026-07-08',36,0.00,'Rohit Shetty','Awaiting candidate decision this week'),
    ('Manipal Whitefield Bengaluru','REQ-3185-005','Operations Manager - Service Hub','operations_manager','manager','agency_recruiter','interviewing',
     15,8,4,0,0,0,'2026-06-10',null,null,null,'Divya Rao','Panel round two scheduled'),
    ('Manipal Whitefield Bengaluru','REQ-3185-006','Quality & Regulatory Associate','quality_regulatory','associate','walk_in','screening',
     21,6,0,0,0,0,'2026-06-25',null,null,null,'Divya Rao','ISO 13485 exposure preferred'),
    ('AIIMS New Delhi Ansari Nagar','REQ-3185-007','Senior Biomedical Engineer','biomedical_engineer','senior','headhunted_passive','offer_accepted',
     9,6,4,2,2,0,'2026-05-25','2026-06-28',34,100.00,'Arjun Malhotra','Both accepted; sixty-day notice periods running'),
    ('AIIMS New Delhi Ansari Nagar','REQ-3185-008','Sales Executive - Govt Accounts','sales_executive','mid_level','employee_referral','dropped_out',
     12,7,3,1,1,0,'2026-04-15','2026-05-12',27,100.00,'Arjun Malhotra','Accepted then ghosted before joining date'),
    ('KIMS Secunderabad','REQ-3185-009','Field Service Engineer','field_service_engineer','mid_level','job_portal_naukri','joined',
     31,14,8,3,2,2,'2026-04-28','2026-05-30',32,66.67,'Kavya Menon','One decline on location constraint'),
    ('Care Hospitals Banjara Hills','REQ-3185-010','Customer Success Associate','customer_success','associate','internal_transfer','joined',
     5,4,3,1,1,1,'2026-05-10','2026-05-24',14,100.00,'Sneha Iyer','Fastest close this quarter'),
    ('Yashoda Somajiguda Hyderabad','REQ-3185-011','Lead Software Engineer - Ops Console','software_engineer','lead','linkedin_inbound','offer_declined',
     48,20,9,3,1,1,'2026-05-02','2026-06-10',39,33.33,'Sneha Iyer','Two competitor counter-offers lost'),
    ('St John''s Bengaluru','REQ-3185-012','Finance Analyst - Escrow Ops','finance_analyst','associate','campus_placement','on_hold',
     17,9,4,0,0,0,'2026-06-05',null,null,null,'Rohit Shetty','Requisition paused pending budget review'),
    ('Rainbow Children''s Hyderabad','REQ-3185-013','Biomedical Engineer - NICU Equipment','biomedical_engineer','mid_level','agency_recruiter','sourcing',
     7,0,0,0,0,0,'2026-07-01',null,null,null,'Divya Rao','Agency briefed; pipeline building'),
    ('Apollo Hyderabad Jubilee Hills','REQ-3185-014','Director of Service Operations','operations_manager','director','headhunted_passive','requisition_cancelled',
     6,3,2,1,0,0,'2026-03-20','2026-04-30',41,0.00,'Arjun Malhotra','Org restructure; requisition cancelled after decline')
  ) as q(hosp, req, rt, rf, lv, sc, st, src, scr, iv, ofr, acc, jn, op, oe, dto, oap, rec, nt);

  -- CAPA seed — attach to specific requisitions
  insert into public.hiring_funnel_capa_actions_r3185 (
    funnel_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('REQ-3185-002','offer_decline_spike','compensation_below_market','revise_salary_band','2026-07-20',null,'in_progress','audit_flag',250000.00,'Band revision proposal with finance'),
    ('REQ-3185-004','slow_screening','panel_bandwidth_crunch','add_interview_panelists','2026-07-15','2026-07-10','closed','internal_only',0.00,'Two senior engineers added to interview panel'),
    ('REQ-3185-008','candidate_ghosting','notice_period_buyout_missing','offer_notice_buyout','2026-07-25',null,'open','contract_sla_breach',180000.00,'Notice buyout budget approval pending'),
    ('REQ-3185-011','offer_decline_spike','competitor_counter_offer','fast_track_top_candidates','2026-07-12',null,'escalated','none',75000.00,'Forty-eight hour offer turnaround mandated'),
    ('REQ-3185-013','low_sourcing_volume','agency_dependency','activate_referral_bonus','2026-07-30',null,'verification_pending','internal_only',60000.00,'Referral bonus doubled for NICU role'),
    ('REQ-3185-012','joining_delay','unclear_role_scope','rewrite_job_description','2026-07-05',null,'overdue','labor_law_exposure',0.00,'JD rewrite blocked on budget freeze')
  ) as q(req_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.hiring_funnel_r3185 e
    on e.organization_id = v_org_id and e.requisition_code = q.req_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Funnel stage status distribution
create or replace function public.founder_r3185_stage_status_rollup()
returns table(funnel_stage_status text, requisitions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hiring_funnel_r3185)
  select l.funnel_stage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hiring_funnel_r3185 l
  group by l.funnel_stage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_stage_status_rollup() from public, anon;
grant execute on function public.founder_r3185_stage_status_rollup() to authenticated;

-- 2) Hospital-site hiring scorecard
create or replace function public.founder_r3185_hospital_scorecard()
returns table(
  hospital_name text,
  requisitions bigint,
  sourced_total bigint,
  offered_total bigint,
  accepted_total bigint,
  joined_total bigint,
  avg_days_to_offer numeric,
  acceptance_pct numeric
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
    coalesce(sum(l.sourced_count),0)::bigint,
    coalesce(sum(l.offered_count),0)::bigint,
    coalesce(sum(l.accepted_count),0)::bigint,
    coalesce(sum(l.joined_count),0)::bigint,
    round(avg(l.days_to_offer)::numeric, 1),
    round(100.0 * coalesce(sum(l.accepted_count),0)::numeric / nullif(sum(l.offered_count),0), 1)
  from public.hiring_funnel_r3185 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3185_hospital_scorecard() to authenticated;

-- 3) Role family × source channel matrix
create or replace function public.founder_r3185_role_source_matrix()
returns table(role_family text, source_channel text, requisitions bigint, offered_total bigint, accepted_total bigint, acceptance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.role_family, l.source_channel, count(*)::bigint,
    coalesce(sum(l.offered_count),0)::bigint,
    coalesce(sum(l.accepted_count),0)::bigint,
    round(100.0 * coalesce(sum(l.accepted_count),0)::numeric / nullif(sum(l.offered_count),0), 1)
  from public.hiring_funnel_r3185 l
  group by l.role_family, l.source_channel
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_role_source_matrix() from public, anon;
grant execute on function public.founder_r3185_role_source_matrix() to authenticated;

-- 4) Requisition-opening daily funnel trend
create or replace function public.founder_r3185_funnel_daily_trend()
returns table(opened_on date, requisitions bigint, sourced_total bigint, offered_total bigint, accepted_total bigint, joined_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.requisition_opened_on,
    count(*)::bigint,
    coalesce(sum(l.sourced_count),0)::bigint,
    coalesce(sum(l.offered_count),0)::bigint,
    coalesce(sum(l.accepted_count),0)::bigint,
    coalesce(sum(l.joined_count),0)::bigint
  from public.hiring_funnel_r3185 l
  group by l.requisition_opened_on
  order by l.requisition_opened_on desc;
end;
$$;

revoke execute on function public.founder_r3185_funnel_daily_trend() from public, anon;
grant execute on function public.founder_r3185_funnel_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3185_capa_status_board()
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
  from public.hiring_funnel_capa_actions_r3185 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_capa_status_board() from public, anon;
grant execute on function public.founder_r3185_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3185_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hiring_funnel_capa_actions_r3185)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hiring_funnel_capa_actions_r3185 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3185_root_cause_pareto() to authenticated;

-- 7) Regulatory / compliance impact digest
create or replace function public.founder_r3185_regulatory_impact_digest()
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
  from public.hiring_funnel_capa_actions_r3185 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3185_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3185_regulatory_impact_digest() to authenticated;

-- 8) Stalled / at-risk requisitions queue
create or replace function public.founder_r3185_stalled_requisitions_queue()
returns table(
  hospital_name text,
  requisition_code text,
  role_title text,
  role_family text,
  funnel_stage_status text,
  days_to_offer int,
  offer_acceptance_pct numeric,
  source_channel text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.requisition_code, l.role_title, l.role_family,
    l.funnel_stage_status, l.days_to_offer, l.offer_acceptance_pct, l.source_channel, l.notes
  from public.hiring_funnel_r3185 l
  where l.funnel_stage_status in ('offer_declined','dropped_out','on_hold','requisition_cancelled')
     or l.offer_acceptance_pct < 50
     or l.days_to_offer > 35
  order by l.requisition_opened_on desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3185_stalled_requisitions_queue() from public, anon;
grant execute on function public.founder_r3185_stalled_requisitions_queue() to authenticated;
