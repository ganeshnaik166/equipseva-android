-- Round 3377: Founder Distributor / Channel-Partner Onboarding & Certification Governance Board
-- Channel-partner lifecycle — partner firm × territory × partner type × onboarding stage × agreement status × KYC × engineers trained × certification × credit terms × YTD revenue × SLA adherence × escalations × partner verdict × CAPA

-- =============================================================================
-- TABLE 1: channel_partner_r3377 — per partner onboarding & certification record
-- =============================================================================
create table if not exists public.channel_partner_r3377 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  partner_firm text not null,
  partner_code text not null,
  territory text not null check (territory in (
    'north','south','east','west','northeast','tier2_cities'
  )),
  partner_type text not null check (partner_type in (
    'reseller','service_partner','referral_partner','oem_authorized_dealer','regional_distributor'
  )),
  onboarding_start_date date not null,
  onboarding_stage text not null check (onboarding_stage in (
    'prospect','agreement_signed','kyc_verified','trained_certified','activated','underperforming','offboarding'
  )),
  agreement_status text not null check (agreement_status in (
    'signed','pending','expired','under_renewal'
  )),
  kyc_compliance_ok boolean not null,
  engineers_trained int not null,
  certification_current boolean not null,
  credit_terms_days int not null,
  ytd_revenue_rupees numeric(14,2) not null,
  sla_adherence_pct numeric(5,2),
  escalations_open int not null,
  partner_verdict text not null check (partner_verdict in (
    'strategic','performing','develop','probation','terminate','onboard_expedite'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.channel_partner_r3377 enable row level security;

create index if not exists idx_channel_partner_r3377_org on public.channel_partner_r3377(organization_id);
create index if not exists idx_channel_partner_r3377_start on public.channel_partner_r3377(onboarding_start_date);
create index if not exists idx_channel_partner_r3377_verdict on public.channel_partner_r3377(partner_verdict);

-- =============================================================================
-- TABLE 2: channel_partner_capa_actions_r3377 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.channel_partner_capa_actions_r3377 (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.channel_partner_r3377(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'kyc_documentation_gap','training_shortfall','certification_expired','agreement_renewal_overdue',
    'sla_breach','revenue_underperformance','credit_limit_exceeded','escalation_backlog',
    'territory_conflict','onboarding_delay'
  )),
  root_cause text not null check (root_cause in (
    'partner_bandwidth','document_collection_delay','trainer_unavailable','policy_ambiguity',
    'market_slowdown','partner_disengagement','onboarding_process_gap','pending_investigation',
    'credit_risk_flag','competitive_pressure'
  )),
  corrective_action text not null check (corrective_action in (
    'collect_kyc_documents','schedule_engineer_training','renew_certification','initiate_agreement_renewal',
    'sla_recovery_plan','joint_business_plan','tighten_credit_terms','escalation_review_meeting',
    'reassign_territory','offboard_partner','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'dealer_agreement_breach','gst_registration_lapse','msme_norms','none','internal_only','data_privacy_dpdp'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.channel_partner_capa_actions_r3377 enable row level security;

create index if not exists idx_channel_partner_capa_r3377_partner on public.channel_partner_capa_actions_r3377(partner_id);
create index if not exists idx_channel_partner_capa_r3377_status on public.channel_partner_capa_actions_r3377(capa_status);

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

  -- 14 channel-partner rows
  insert into public.channel_partner_r3377 (
    organization_id, partner_firm, partner_code, territory, partner_type,
    onboarding_start_date, onboarding_stage, agreement_status, kyc_compliance_ok,
    engineers_trained, certification_current, credit_terms_days, ytd_revenue_rupees,
    sla_adherence_pct, escalations_open, partner_verdict, notes
  )
  select v_org_id, q.firm, q.code, q.terr, q.ptype,
    q.osd::date, q.stage, q.agr, q.kyc,
    q.eng::int, q.cert, q.credit::int, q.rev::numeric,
    q.sla::numeric, q.esc::int, q.verdict, q.nt
  from (values
    ('MedTech Distributors Pvt Ltd','CP-001','south','regional_distributor',
     '2025-08-15','activated','signed',true,
     8,true,45,12500000.00,
     96.5,0,'strategic','Anchor south distributor; highest YTD revenue'),
    ('Surgicare Solutions','CP-002','south','service_partner',
     '2025-09-01','activated','signed',true,
     6,true,30,8200000.00,
     92.0,1,'performing','Bengaluru service partner; strong OT install base'),
    ('Northern MediEquip','CP-003','north','regional_distributor',
     '2025-06-20','activated','signed',true,
     10,true,60,15800000.00,
     88.5,2,'strategic','Delhi NCR flagship; largest engineer bench'),
    ('Kolkata Health Systems','CP-004','east','reseller',
     '2025-11-10','trained_certified','signed',true,
     4,true,30,4200000.00,
     90.0,0,'performing','East reseller; certified, ramping activation'),
    ('Rajasthan BioMedical Agencies','CP-005','west','oem_authorized_dealer',
     '2025-07-05','activated','under_renewal',true,
     5,false,45,6700000.00,
     84.0,3,'develop','Jaipur OEM dealer; certification lapsed, renewal underway'),
    ('Guwahati Medical Traders','CP-006','northeast','referral_partner',
     '2026-05-12','kyc_verified','pending',true,
     1,false,15,900000.00,
     78.0,1,'onboard_expedite','Northeast referral partner; training not yet complete'),
    ('Pune Care Instruments','CP-007','west','service_partner',
     '2025-10-01','activated','signed',true,
     7,true,30,9100000.00,
     94.5,0,'performing','Pune service partner; excellent SLA'),
    ('Hyderabad HealthLink Distributors','CP-008','south','regional_distributor',
     '2025-05-18','underperforming','under_renewal',true,
     3,true,60,3100000.00,
     71.0,5,'probation','SLA slipping; 5 escalations open — on probation'),
    ('Lucknow MedSupplies','CP-009','north','reseller',
     '2026-06-25','agreement_signed','signed',false,
     0,false,30,0.00,
     null,0,'onboard_expedite','Agreement signed; KYC and training pending'),
    ('Bhubaneswar Surgical Agencies','CP-010','east','service_partner',
     '2025-04-22','underperforming','expired',true,
     2,false,45,2400000.00,
     68.5,4,'terminate','Agreement expired; cert lapsed; termination review'),
    ('Indore Medisys Tier-2 Network','CP-011','tier2_cities','reseller',
     '2025-12-03','trained_certified','signed',true,
     3,true,30,3800000.00,
     89.0,1,'develop','Tier-2 reseller; certified, growth potential'),
    ('Coimbatore Biomed Partners','CP-012','tier2_cities','referral_partner',
     '2026-07-01','prospect','pending',false,
     0,false,0,0.00,
     null,0,'onboard_expedite','Prospect; pre-agreement due diligence stage'),
    ('Chandigarh MedEquip Alliance','CP-013','north','oem_authorized_dealer',
     '2025-08-28','activated','signed',true,
     9,true,60,11200000.00,
     95.0,1,'strategic','Chandigarh OEM dealer; strong north performer'),
    ('Nagpur Healthcare Distributors','CP-014','tier2_cities','regional_distributor',
     '2025-03-15','offboarding','expired',true,
     4,false,45,1500000.00,
     62.0,6,'terminate','Offboarding; sustained underperformance, 6 escalations')
  ) as q(firm, code, terr, ptype, osd, stage, agr, kyc, eng, cert, credit, rev, sla, esc, verdict, nt);

  -- CAPA seed — attach to specific partners by partner_code
  insert into public.channel_partner_capa_actions_r3377 (
    partner_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('CP-005','certification_expired','document_collection_delay','renew_certification',
     'in_progress','internal_only','2026-07-28',null,18000.00,'Dealer cert lapsed; renewal docs collected, exam pending'),
    ('CP-006','onboarding_delay','partner_bandwidth','schedule_engineer_training',
     'open','internal_only','2026-08-05',null,25000.00,'Northeast partner slow to nominate engineers for training'),
    ('CP-008','sla_breach','partner_disengagement','sla_recovery_plan',
     'escalated','dealer_agreement_breach','2026-07-25',null,60000.00,'SLA at 71 pct; 5 escalations open — recovery plan enforced'),
    ('CP-009','kyc_documentation_gap','document_collection_delay','collect_kyc_documents',
     'in_progress','data_privacy_dpdp','2026-07-30',null,5000.00,'GST, PAN and DPDP consent pending before activation'),
    ('CP-010','agreement_renewal_overdue','market_slowdown','initiate_agreement_renewal',
     'overdue','dealer_agreement_breach','2026-07-10',null,40000.00,'Agreement expired; east region revenue below floor'),
    ('CP-014','revenue_underperformance','competitive_pressure','offboard_partner',
     'open','none',null,null,0.00,'Tier-2 distributor offboarding; territory to be reassigned'),
    ('CP-014','escalation_backlog','partner_disengagement','escalation_review_meeting',
     'overdue','internal_only','2026-07-05',null,15000.00,'6 escalations open; partner non-responsive')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.channel_partner_r3377 e
    on e.organization_id = v_org_id and e.partner_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Partner verdict distribution
create or replace function public.founder_r3377_partner_verdict_rollup()
returns table(partner_verdict text, partners bigint, total_revenue_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.channel_partner_r3377)
  select p.partner_verdict, count(*)::bigint,
         coalesce(sum(p.ytd_revenue_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.channel_partner_r3377 p
  group by p.partner_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_partner_verdict_rollup() from public, anon;
grant execute on function public.founder_r3377_partner_verdict_rollup() to authenticated;

-- 2) Territory scorecard
create or replace function public.founder_r3377_territory_scorecard()
returns table(
  territory text,
  total_partners bigint,
  activated bigint,
  underperforming bigint,
  kyc_ok bigint,
  cert_current bigint,
  total_revenue_rupees numeric,
  avg_sla_adherence_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.territory,
    count(*)::bigint,
    count(*) filter (where p.onboarding_stage = 'activated')::bigint,
    count(*) filter (where p.onboarding_stage in ('underperforming','offboarding'))::bigint,
    count(*) filter (where p.kyc_compliance_ok)::bigint,
    count(*) filter (where p.certification_current)::bigint,
    coalesce(sum(p.ytd_revenue_rupees),0)::numeric,
    round(avg(p.sla_adherence_pct), 1)
  from public.channel_partner_r3377 p
  group by p.territory
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_territory_scorecard() from public, anon;
grant execute on function public.founder_r3377_territory_scorecard() to authenticated;

-- 3) Partner type × onboarding stage matrix
create or replace function public.founder_r3377_type_stage_matrix()
returns table(partner_type text, onboarding_stage text, partners bigint, total_revenue_rupees numeric, avg_engineers_trained numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.partner_type, p.onboarding_stage, count(*)::bigint,
    coalesce(sum(p.ytd_revenue_rupees),0)::numeric,
    round(avg(p.engineers_trained), 1)
  from public.channel_partner_r3377 p
  group by p.partner_type, p.onboarding_stage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_type_stage_matrix() from public, anon;
grant execute on function public.founder_r3377_type_stage_matrix() to authenticated;

-- 4) Onboarding-start date trend
create or replace function public.founder_r3377_onboarding_trend()
returns table(onboarding_start_date date, partners bigint, activated bigint, avg_sla_adherence_pct numeric, total_revenue_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.onboarding_start_date,
    count(*)::bigint,
    count(*) filter (where p.onboarding_stage = 'activated')::bigint,
    round(avg(p.sla_adherence_pct), 1),
    coalesce(sum(p.ytd_revenue_rupees),0)::numeric
  from public.channel_partner_r3377 p
  group by p.onboarding_start_date
  order by p.onboarding_start_date desc;
end;
$$;

revoke execute on function public.founder_r3377_onboarding_trend() from public, anon;
grant execute on function public.founder_r3377_onboarding_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3377_capa_status_board()
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
  from public.channel_partner_capa_actions_r3377 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_capa_status_board() from public, anon;
grant execute on function public.founder_r3377_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3377_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.channel_partner_capa_actions_r3377)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.channel_partner_capa_actions_r3377 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3377_root_cause_pareto() to authenticated;

-- 7) Regulatory / compliance impact digest
create or replace function public.founder_r3377_regulatory_impact_digest()
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
  from public.channel_partner_capa_actions_r3377 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3377_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3377_regulatory_impact_digest() to authenticated;

-- 8) High-risk partners queue (top governance concerns)
create or replace function public.founder_r3377_high_risk_partners()
returns table(
  partner_firm text,
  partner_code text,
  territory text,
  partner_type text,
  onboarding_stage text,
  agreement_status text,
  kyc_compliance text,
  certification_status text,
  sla_adherence_pct numeric,
  escalations_open int,
  partner_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.partner_firm, p.partner_code, p.territory, p.partner_type,
    p.onboarding_stage, p.agreement_status,
    case when p.kyc_compliance_ok then 'ok' else 'gap' end,
    case when p.certification_current then 'current' else 'expired' end,
    p.sla_adherence_pct, p.escalations_open, p.partner_verdict, p.notes
  from public.channel_partner_r3377 p
  where p.partner_verdict in ('develop','probation','terminate','onboard_expedite')
     or p.onboarding_stage in ('underperforming','offboarding')
     or p.agreement_status in ('expired','under_renewal')
     or p.kyc_compliance_ok = false
     or p.certification_current = false
     or p.escalations_open >= 3
  order by case p.partner_verdict
             when 'terminate' then 0
             when 'probation' then 1
             when 'develop' then 2
             when 'onboard_expedite' then 3
             else 4
           end,
           p.partner_firm;
end;
$$;

revoke execute on function public.founder_r3377_high_risk_partners() from public, anon;
grant execute on function public.founder_r3377_high_risk_partners() to authenticated;
