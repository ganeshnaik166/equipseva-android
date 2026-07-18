-- Round 3205: Founder Partnership & Channel-Alliance Pipeline Health Board
-- Partnership pipeline log — partner type × stage × deal value × revenue-share × exclusivity × health score × verdict × CAPA follow-through

-- =============================================================================
-- TABLE 1: partnership_pipeline_r3205 — partnership & channel-alliance deals
-- =============================================================================
create table if not exists public.partnership_pipeline_r3205 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  partner_name text not null,
  partner_code text not null,
  anchor_hospital_name text not null,
  partner_type text not null check (partner_type in (
    'oem_manufacturer','regional_distributor','insurer_tpa',
    'hospital_chain','equipment_financier','biomedical_service_partner'
  )),
  pipeline_stage text not null check (pipeline_stage in (
    'prospecting','intro_call_done','pilot_scoping','pilot_running',
    'commercial_negotiation','contract_signed','live_scaling','stalled','churned'
  )),
  deal_value_potential_rupees numeric(14,2) not null,
  revenue_share_pct numeric(5,2),
  exclusivity_flag boolean not null default false,
  review_date date not null,
  next_milestone_type text not null check (next_milestone_type in (
    'pilot_kickoff','mou_signature','pricing_workshop','integration_demo',
    'contract_redline_review','quarterly_business_review','renewal_negotiation','escalation_meeting'
  )),
  next_milestone_date date,
  health_score int not null check (health_score between 0 and 100),
  pipeline_verdict text not null check (pipeline_verdict in (
    'on_track','needs_attention','at_risk','critical','won','lost','paused'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.partnership_pipeline_r3205 enable row level security;

create index if not exists idx_partnership_pipeline_r3205_org on public.partnership_pipeline_r3205(organization_id);
create index if not exists idx_partnership_pipeline_r3205_review on public.partnership_pipeline_r3205(review_date);
create index if not exists idx_partnership_pipeline_r3205_verdict on public.partnership_pipeline_r3205(pipeline_verdict);

-- =============================================================================
-- TABLE 2: partnership_pipeline_capa_actions_r3205 — follow-up / CAPA actions
-- =============================================================================
create table if not exists public.partnership_pipeline_capa_actions_r3205 (
  id uuid primary key default gen_random_uuid(),
  pipeline_id uuid not null references public.partnership_pipeline_r3205(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'milestone_slippage','revenue_share_dispute','exclusivity_conflict',
    'pilot_underperformance','contract_redline_deadlock','champion_exit',
    'payment_delay','integration_blocker','competitor_poaching','compliance_gap'
  )),
  root_cause text not null check (root_cause in (
    'pricing_misalignment','unclear_success_metrics','partner_bandwidth_shortage',
    'internal_legal_backlog','stakeholder_churn','product_gap',
    'data_sharing_concerns','slow_procurement_cycle','relationship_underinvestment','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_revenue_share','redefine_pilot_kpis','assign_dedicated_account_manager',
    'escalate_to_founder_call','fast_track_legal_review','ship_integration_fix',
    'run_joint_gtm_workshop','offer_limited_exclusivity','pause_and_reassess','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','contract_breach_risk','data_privacy_dpdp','cdsco_licensing','irdai_insurance_filing'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.partnership_pipeline_capa_actions_r3205 enable row level security;

create index if not exists idx_partnership_capa_r3205_pipeline on public.partnership_pipeline_capa_actions_r3205(pipeline_id);
create index if not exists idx_partnership_capa_r3205_status on public.partnership_pipeline_capa_actions_r3205(capa_status);

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

  -- 14 pipeline rows
  insert into public.partnership_pipeline_r3205 (
    organization_id, partner_name, partner_code, anchor_hospital_name,
    partner_type, pipeline_stage, deal_value_potential_rupees, revenue_share_pct,
    exclusivity_flag, review_date, next_milestone_type, next_milestone_date,
    health_score, pipeline_verdict, notes
  )
  select v_org_id, q.pn, q.pc, q.hosp,
    q.ptype, q.stage, q.dv, q.rs,
    q.ex, q.rd::date, q.nmt, q.nmd::date,
    q.hsc, q.pv, q.nt
  from (values
    ('GE Healthcare India','PRT-001','Apollo Hyderabad Jubilee Hills','oem_manufacturer','commercial_negotiation',
     18500000.00,12.50,false,'2026-07-15','contract_redline_review','2026-07-24',78,'on_track','Multi-vendor AMC servicing rights across imaging fleet'),
    ('Siemens Healthineers India','PRT-002','Fortis Bannerghatta Bengaluru','oem_manufacturer','pilot_running',
     12000000.00,10.00,false,'2026-07-14','quarterly_business_review','2026-08-05',64,'needs_attention','Cath-lab uptime SLA pilot; response-time metric slipping'),
    ('Medikabazaar','PRT-003','Manipal Whitefield Bengaluru','regional_distributor','contract_signed',
     6500000.00,18.00,true,'2026-07-15','pilot_kickoff','2026-07-20',85,'won','South-India spares distribution signed with exclusivity'),
    ('Star Health Insurance','PRT-004','AIIMS New Delhi Ansari Nagar','insurer_tpa','pilot_scoping',
     9000000.00,8.00,false,'2026-07-12','pricing_workshop','2026-07-28',55,'needs_attention','Equipment-breakdown cover rider; actuarial data requested'),
    ('Apollo Hospitals Enterprise','PRT-005','Apollo Hyderabad Jubilee Hills','hospital_chain','live_scaling',
     32000000.00,15.00,true,'2026-07-16','quarterly_business_review','2026-08-10',92,'on_track','Chain-wide rollout live in 11 units'),
    ('Bajaj Finserv Health','PRT-006','KIMS Secunderabad','equipment_financier','commercial_negotiation',
     14000000.00,9.50,false,'2026-07-13','contract_redline_review','2026-07-22',48,'at_risk','Interest-subvention clause deadlocked in legal'),
    ('Trivitron Healthcare','PRT-007','Care Hospitals Banjara Hills','regional_distributor','intro_call_done',
     4200000.00,20.00,false,'2026-07-10','integration_demo','2026-07-25',60,'needs_attention','Seeking Telangana lab-equipment service territory'),
    ('Philips Healthcare India','PRT-008','Yashoda Somajiguda Hyderabad','oem_manufacturer','pilot_running',
     16800000.00,11.00,false,'2026-07-14','integration_demo','2026-07-21',71,'on_track','Patient-monitor fleet telemetry integration pilot'),
    ('Skanray Technologies','PRT-009','St John''s Bengaluru','oem_manufacturer','stalled',
     5400000.00,14.00,false,'2026-07-08','escalation_meeting','2026-07-19',31,'critical','Champion exited; no partner response for three weeks'),
    ('ICICI Lombard','PRT-010','Rainbow Children''s Hyderabad','insurer_tpa','prospecting',
     7500000.00,7.50,false,'2026-07-11','pricing_workshop','2026-07-30',52,'needs_attention','Pediatric-equipment cover concept pitched to underwriting'),
    ('Tata Capital Healthcare Finance','PRT-011','Manipal Whitefield Bengaluru','equipment_financier','pilot_scoping',
     11000000.00,8.50,false,'2026-07-12','mou_signature','2026-07-26',66,'on_track','Lease-to-own refurbished equipment pilot scoping'),
    ('Mindray Medical India','PRT-012','KIMS Secunderabad','oem_manufacturer','churned',
     3800000.00,10.00,false,'2026-07-05','escalation_meeting','2026-07-18',12,'lost','Chose competing service network on price'),
    ('BPL Medical Technologies','PRT-013','Fortis Bannerghatta Bengaluru','oem_manufacturer','commercial_negotiation',
     8800000.00,13.00,true,'2026-07-15','contract_redline_review','2026-07-23',74,'on_track','Exclusive Karnataka install-base servicing under redline'),
    ('Draeger India','PRT-014','Yashoda Somajiguda Hyderabad','biomedical_service_partner','pilot_scoping',
     5800000.00,16.00,false,'2026-07-09','mou_signature','2026-08-15',44,'paused','ICU ventilator service co-delivery paused till Q3 budget')
  ) as q(pn, pc, hosp, ptype, stage, dv, rs, ex, rd, nmt, nmd, hsc, pv, nt);

  -- CAPA seed — attach to specific partnerships
  insert into public.partnership_pipeline_capa_actions_r3205 (
    pipeline_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('PRT-006','contract_redline_deadlock','internal_legal_backlog','fast_track_legal_review','2026-07-25',null,'in_progress','contract_breach_risk',120000.00,'External counsel engaged on interest-subvention clause'),
    ('PRT-009','champion_exit','stakeholder_churn','escalate_to_founder_call','2026-07-20',null,'escalated','none',0.00,'Founder-to-founder call requested with Skanray leadership'),
    ('PRT-002','pilot_underperformance','unclear_success_metrics','redefine_pilot_kpis','2026-07-30',null,'open','internal_only',45000.00,'Rebaseline cath-lab uptime SLA and response-time KPI'),
    ('PRT-012','competitor_poaching','pricing_misalignment','pause_and_reassess','2026-07-10','2026-07-08','closed','none',0.00,'Loss review logged; revisit account in two quarters'),
    ('PRT-004','compliance_gap','data_sharing_concerns','fast_track_legal_review','2026-08-01',null,'in_progress','data_privacy_dpdp',85000.00,'DPDP consent framework needed before claims-data pilot'),
    ('PRT-013','exclusivity_conflict','pending_investigation','offer_limited_exclusivity','2026-07-27',null,'verification_pending','contract_breach_risk',60000.00,'Territory overlap with distributor exclusivity under review'),
    ('PRT-008','payment_delay','slow_procurement_cycle','assign_dedicated_account_manager','2026-07-15',null,'overdue','internal_only',30000.00,'Pilot telemetry invoice pending 45 days')
  ) as q(pcode, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.partnership_pipeline_r3205 e
    on e.organization_id = v_org_id and e.partner_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Pipeline verdict distribution
create or replace function public.founder_r3205_verdict_rollup()
returns table(pipeline_verdict text, partnerships bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.partnership_pipeline_r3205)
  select p.pipeline_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.partnership_pipeline_r3205 p
  group by p.pipeline_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_verdict_rollup() from public, anon;
grant execute on function public.founder_r3205_verdict_rollup() to authenticated;

-- 2) Anchor-hospital scorecard
create or replace function public.founder_r3205_hospital_scorecard()
returns table(
  anchor_hospital_name text,
  partnerships bigint,
  total_deal_value_rupees numeric,
  avg_health_score numeric,
  exclusive_deals bigint,
  on_track bigint,
  at_risk bigint,
  won bigint,
  lost bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.anchor_hospital_name,
    count(*)::bigint,
    coalesce(sum(p.deal_value_potential_rupees),0)::numeric,
    round(avg(p.health_score)::numeric, 1),
    count(*) filter (where p.exclusivity_flag)::bigint,
    count(*) filter (where p.pipeline_verdict = 'on_track')::bigint,
    count(*) filter (where p.pipeline_verdict in ('at_risk','critical'))::bigint,
    count(*) filter (where p.pipeline_verdict = 'won')::bigint,
    count(*) filter (where p.pipeline_verdict = 'lost')::bigint
  from public.partnership_pipeline_r3205 p
  group by p.anchor_hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3205_hospital_scorecard() to authenticated;

-- 3) Partner type × stage matrix
create or replace function public.founder_r3205_type_stage_matrix()
returns table(partner_type text, pipeline_stage text, partnerships bigint, total_deal_value_rupees numeric, avg_health_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.partner_type, p.pipeline_stage, count(*)::bigint,
    coalesce(sum(p.deal_value_potential_rupees),0)::numeric,
    round(avg(p.health_score)::numeric, 1)
  from public.partnership_pipeline_r3205 p
  group by p.partner_type, p.pipeline_stage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_type_stage_matrix() from public, anon;
grant execute on function public.founder_r3205_type_stage_matrix() to authenticated;

-- 4) Review-date trend
create or replace function public.founder_r3205_review_daily_trend()
returns table(review_date date, partnerships_reviewed bigint, avg_health_score numeric, at_risk_or_critical bigint, total_deal_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.review_date,
    count(*)::bigint,
    round(avg(p.health_score)::numeric, 1),
    count(*) filter (where p.pipeline_verdict in ('at_risk','critical'))::bigint,
    coalesce(sum(p.deal_value_potential_rupees),0)::numeric
  from public.partnership_pipeline_r3205 p
  group by p.review_date
  order by p.review_date desc;
end;
$$;

revoke execute on function public.founder_r3205_review_daily_trend() from public, anon;
grant execute on function public.founder_r3205_review_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3205_capa_status_board()
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
  from public.partnership_pipeline_capa_actions_r3205 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_capa_status_board() from public, anon;
grant execute on function public.founder_r3205_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3205_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.partnership_pipeline_capa_actions_r3205)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.partnership_pipeline_capa_actions_r3205 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3205_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3205_regulatory_impact_digest()
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
  from public.partnership_pipeline_capa_actions_r3205 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3205_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3205_regulatory_impact_digest() to authenticated;

-- 8) High-risk partnership queue
create or replace function public.founder_r3205_high_risk_queue()
returns table(
  partner_name text,
  partner_type text,
  anchor_hospital_name text,
  pipeline_stage text,
  health_score int,
  pipeline_verdict text,
  next_milestone_type text,
  next_milestone_date date,
  deal_value_potential_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.partner_name, p.partner_type, p.anchor_hospital_name, p.pipeline_stage,
    p.health_score, p.pipeline_verdict, p.next_milestone_type, p.next_milestone_date,
    p.deal_value_potential_rupees, p.notes
  from public.partnership_pipeline_r3205 p
  where p.pipeline_verdict in ('needs_attention','at_risk','critical')
     or p.health_score < 50
     or p.pipeline_stage = 'stalled'
  order by p.health_score asc, p.partner_name;
end;
$$;

revoke execute on function public.founder_r3205_high_risk_queue() from public, anon;
grant execute on function public.founder_r3205_high_risk_queue() to authenticated;
