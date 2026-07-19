-- Round 3385: Founder Supplier / OEM Risk, Financial-Health & Supply-Continuity Board
-- Supply-chain risk log — supplier category × criticality × financial health × lead-time trend × OTD × reject rate × second-source × contract status × continuity plan × supplier verdict × CAPA

-- =============================================================================
-- TABLE 1: supplier_oem_risk_r3385 — per-supplier risk & continuity assessment
-- =============================================================================
create table if not exists public.supplier_oem_risk_r3385 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  supplier_code text not null,
  supplier_category text not null check (supplier_category in (
    'imaging_oem','patient_monitoring_oem','dialysis_oem','spare_parts_distributor',
    'consumables','logistics','calibration_standards'
  )),
  criticality text not null check (criticality in (
    'single_source_critical','dual_source','commodity'
  )),
  annual_spend_rupees numeric(14,2) not null,
  financial_health text not null check (financial_health in (
    'strong','stable','watch','distressed','unknown'
  )),
  lead_time_days int not null,
  lead_time_trend text not null check (lead_time_trend in (
    'improving','stable','worsening'
  )),
  on_time_delivery_pct numeric(5,2),
  quality_reject_rate_pct numeric(5,2),
  second_source_identified boolean not null default false,
  supply_risk_events_last_year int not null default 0,
  contract_status text not null check (contract_status in (
    'active','expiring','no_contract','under_renegotiation'
  )),
  continuity_plan_ready boolean not null default false,
  supplier_verdict text not null check (supplier_verdict in (
    'strategic_secure','monitor','develop_second_source','de_risk_urgent','exit_replace'
  )),
  last_review_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_oem_risk_r3385 enable row level security;

create index if not exists idx_supplier_oem_risk_r3385_org on public.supplier_oem_risk_r3385(organization_id);
create index if not exists idx_supplier_oem_risk_r3385_review on public.supplier_oem_risk_r3385(last_review_date);
create index if not exists idx_supplier_oem_risk_r3385_verdict on public.supplier_oem_risk_r3385(supplier_verdict);

-- =============================================================================
-- TABLE 2: supplier_oem_risk_capa_actions_r3385 — de-risking / continuity actions
-- =============================================================================
create table if not exists public.supplier_oem_risk_capa_actions_r3385 (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.supplier_oem_risk_r3385(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'single_source_exposure','financial_distress','lead_time_spike','quality_reject_high',
    'contract_lapsed','delivery_shortfall','no_continuity_plan','price_escalation','geopolitical_import_risk'
  )),
  root_cause text not null check (root_cause in (
    'no_second_source_qualified','supplier_cashflow_stress','forex_import_dependency',
    'capacity_constraint','logistics_disruption','oem_end_of_life_part','contract_renewal_backlog',
    'pending_investigation','quality_process_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'qualify_second_source','negotiate_safety_stock','renew_contract','financial_covenant_monitoring',
    'localize_import_part','onboard_alternate_oem','build_continuity_plan','escalate_to_board',
    'price_renegotiation','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_import_license','bis_certification','none','internal_only','iso_13485_supplier_control','patient_safety_supply_risk'
  )),
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_oem_risk_capa_actions_r3385 enable row level security;

create index if not exists idx_supplier_capa_r3385_supplier on public.supplier_oem_risk_capa_actions_r3385(supplier_id);
create index if not exists idx_supplier_capa_r3385_status on public.supplier_oem_risk_capa_actions_r3385(capa_status);

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

  -- 14 supplier risk rows
  insert into public.supplier_oem_risk_r3385 (
    organization_id, supplier_name, supplier_code, supplier_category, criticality,
    annual_spend_rupees, financial_health, lead_time_days, lead_time_trend, on_time_delivery_pct,
    quality_reject_rate_pct, second_source_identified, supply_risk_events_last_year, contract_status, continuity_plan_ready,
    supplier_verdict, last_review_date, notes
  )
  select v_org_id, q.sname, q.scode, q.cat, q.crit,
    q.spend, q.fh, q.ltd, q.ltt, q.otd,
    q.qrr, q.ssi, q.sre, q.cs, q.cpr,
    q.verdict, q.lrd::date, q.nt
  from (values
    ('GE Healthcare India','SUP-GEH-01','imaging_oem','single_source_critical',
     42000000.00,'strong',45,'stable',96.50,
     0.80,true,1,'active',true,
     'strategic_secure','2026-07-05','CT/MRI OEM; sole source for high-end imaging spares — strong balance sheet'),
    ('Siemens Healthineers India','SUP-SIE-02','imaging_oem','dual_source',
     28000000.00,'strong',40,'improving',97.20,
     0.60,true,0,'active',true,
     'strategic_secure','2026-07-04','Dual-source with GE for imaging; reliable delivery and service'),
    ('Philips India','SUP-PHI-03','patient_monitoring_oem','dual_source',
     19500000.00,'stable',35,'stable',94.00,
     1.10,true,1,'active',true,
     'monitor','2026-07-03','Monitoring OEM; occasional module lead-time slips on imports'),
    ('Nihon Kohden India','SUP-NKH-04','patient_monitoring_oem','dual_source',
     12000000.00,'stable',52,'worsening',89.50,
     1.80,true,2,'expiring',false,
     'monitor','2026-07-02','Import lead-times worsening; supply contract expiring Sep 2026'),
    ('Mindray India','SUP-MIN-05','patient_monitoring_oem','commodity',
     8600000.00,'stable',30,'stable',92.30,
     1.40,true,0,'active',true,
     'strategic_secure','2026-07-02','Competitive commodity monitoring; good value and stock depth'),
    ('Fresenius Medical Care India','SUP-FRE-06','dialysis_oem','single_source_critical',
     34000000.00,'watch',60,'worsening',85.00,
     2.20,false,3,'under_renegotiation',false,
     'de_risk_urgent','2026-07-01','Single-source dialysis machines and dialyzers; no qualified alternate — urgent'),
    ('Nipro India','SUP-NIP-07','dialysis_oem','dual_source',
     15000000.00,'stable',48,'stable',90.80,
     1.60,true,1,'active',true,
     'monitor','2026-06-30','Alternate dialyzer source to Fresenius; qualification in progress'),
    ('B. Braun Medical India','SUP-BBR-08','consumables','dual_source',
     9800000.00,'strong',25,'stable',95.60,
     0.90,true,0,'active',true,
     'strategic_secure','2026-06-30','IV sets and consumables; strong service levels and local warehousing'),
    ('Trivitron Healthcare','SUP-TRV-09','spare_parts_distributor','dual_source',
     7200000.00,'watch',38,'worsening',87.40,
     2.60,false,2,'expiring',false,
     'develop_second_source','2026-06-29','Spare-parts distributor; margin pressure and rising reject rate'),
    ('Skanray Technologies','SUP-SKN-10','patient_monitoring_oem','commodity',
     5400000.00,'stable',28,'improving',93.10,
     1.30,true,0,'active',true,
     'strategic_secure','2026-06-29','Make-in-India monitoring OEM; localizes forex exposure'),
    ('BPL Medical Technologies','SUP-BPL-11','patient_monitoring_oem','commodity',
     4800000.00,'stable',26,'stable',91.50,
     1.70,true,1,'active',true,
     'monitor','2026-06-28','Domestic monitoring OEM; steady supply and pricing'),
    ('Allengers Medical Systems','SUP-ALG-12','imaging_oem','dual_source',
     11000000.00,'distressed',55,'worsening',82.00,
     3.10,false,4,'no_contract',false,
     'de_risk_urgent','2026-06-27','C-arm and X-ray parts; quality rejects high, operating without contract'),
    ('Blue Dart Med-Logistics','SUP-BLD-13','logistics','commodity',
     3600000.00,'strong',3,'stable',98.20,
     0.40,true,0,'active',true,
     'strategic_secure','2026-06-26','Cold-chain and spares logistics; excellent on-time delivery'),
    ('Fluke Biomedical Cal-Lab','SUP-FLK-14','calibration_standards','single_source_critical',
     2100000.00,'unknown',90,'worsening',78.00,
     null,false,2,'no_contract',false,
     'exit_replace','2026-06-25','Calibration standards import; opaque financials, long lead — seek NABL alternate')
  ) as q(sname, scode, cat, crit, spend, fh, ltd, ltt, otd, qrr, ssi, sre, cs, cpr, verdict, lrd, nt);

  -- CAPA seed — attach to specific suppliers by supplier_code
  insert into public.supplier_oem_risk_capa_actions_r3385 (
    supplier_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('SUP-FRE-06','single_source_exposure','no_second_source_qualified','qualify_second_source',
     '2026-08-15',null,'in_progress','patient_safety_supply_risk',1200000.00,'Qualifying Nipro dialyzers as alternate to Fresenius single source'),
    ('SUP-FRE-06','contract_lapsed','contract_renewal_backlog','renew_contract',
     '2026-07-30',null,'escalated','iso_13485_supplier_control',0.00,'AMC under renegotiation; 14% price hike proposed by OEM'),
    ('SUP-ALG-12','quality_reject_high','quality_process_gap','onboard_alternate_oem',
     '2026-08-20',null,'open','patient_safety_supply_risk',850000.00,'C-arm reject rate 3.1%; onboarding alternate imaging vendor'),
    ('SUP-ALG-12','contract_lapsed','contract_renewal_backlog','renew_contract',
     '2026-07-10',null,'overdue','internal_only',0.00,'Operating without contract past target date — supplier distressed'),
    ('SUP-NKH-04','lead_time_spike','forex_import_dependency','negotiate_safety_stock',
     '2026-08-05',null,'in_progress','cdsco_import_license',300000.00,'Building 60-day safety stock for monitoring modules'),
    ('SUP-TRV-09','delivery_shortfall','capacity_constraint','qualify_second_source',
     '2026-08-25',null,'open','iso_13485_supplier_control',220000.00,'Spare-parts OTD 87%; developing second distributor'),
    ('SUP-FLK-14','no_continuity_plan','oem_end_of_life_part','build_continuity_plan',
     '2026-07-15','2026-07-12','closed','none',60000.00,'NABL-accredited alternate cal-lab identified; continuity plan documented')
  ) as q(scode, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.supplier_oem_risk_r3385 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Supplier verdict distribution
create or replace function public.founder_r3385_supplier_verdict_rollup()
returns table(supplier_verdict text, suppliers bigint, total_spend_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_oem_risk_r3385)
  select s.supplier_verdict, count(*)::bigint,
         coalesce(sum(s.annual_spend_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.supplier_oem_risk_r3385 s
  group by s.supplier_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_supplier_verdict_rollup() from public, anon;
grant execute on function public.founder_r3385_supplier_verdict_rollup() to authenticated;

-- 2) Supplier category scorecard
create or replace function public.founder_r3385_category_scorecard()
returns table(
  supplier_category text,
  total_suppliers bigint,
  single_source bigint,
  distressed bigint,
  de_risk_urgent bigint,
  total_spend_rupees numeric,
  avg_on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.supplier_category,
    count(*)::bigint,
    count(*) filter (where s.criticality = 'single_source_critical')::bigint,
    count(*) filter (where s.financial_health = 'distressed')::bigint,
    count(*) filter (where s.supplier_verdict in ('de_risk_urgent','exit_replace'))::bigint,
    coalesce(sum(s.annual_spend_rupees),0)::numeric,
    round(avg(s.on_time_delivery_pct), 1)
  from public.supplier_oem_risk_r3385 s
  group by s.supplier_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_category_scorecard() from public, anon;
grant execute on function public.founder_r3385_category_scorecard() to authenticated;

-- 3) Supplier category × criticality matrix
create or replace function public.founder_r3385_category_criticality_matrix()
returns table(supplier_category text, criticality text, suppliers bigint, total_spend_rupees numeric, avg_lead_time_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.supplier_category, s.criticality, count(*)::bigint,
    coalesce(sum(s.annual_spend_rupees),0)::numeric,
    round(avg(s.lead_time_days), 1)
  from public.supplier_oem_risk_r3385 s
  group by s.supplier_category, s.criticality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_category_criticality_matrix() from public, anon;
grant execute on function public.founder_r3385_category_criticality_matrix() to authenticated;

-- 4) Supplier review-date trend
create or replace function public.founder_r3385_review_trend()
returns table(last_review_date date, reviews bigint, distressed bigint, de_risk_urgent bigint, single_source bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.last_review_date,
    count(*)::bigint,
    count(*) filter (where s.financial_health = 'distressed')::bigint,
    count(*) filter (where s.supplier_verdict in ('de_risk_urgent','exit_replace'))::bigint,
    count(*) filter (where s.criticality = 'single_source_critical')::bigint
  from public.supplier_oem_risk_r3385 s
  group by s.last_review_date
  order by s.last_review_date desc;
end;
$$;

revoke execute on function public.founder_r3385_review_trend() from public, anon;
grant execute on function public.founder_r3385_review_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3385_capa_status_board()
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
  from public.supplier_oem_risk_capa_actions_r3385 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_capa_status_board() from public, anon;
grant execute on function public.founder_r3385_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3385_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_oem_risk_capa_actions_r3385)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.supplier_oem_risk_capa_actions_r3385 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3385_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3385_regulatory_impact_digest()
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
  from public.supplier_oem_risk_capa_actions_r3385 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3385_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3385_regulatory_impact_digest() to authenticated;

-- 8) High-risk supplier queue (top supply-continuity concerns)
create or replace function public.founder_r3385_high_risk_suppliers()
returns table(
  supplier_name text,
  supplier_code text,
  supplier_category text,
  criticality text,
  financial_health text,
  contract_status text,
  supplier_verdict text,
  second_source_identified boolean,
  continuity_plan_ready boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.supplier_name, s.supplier_code, s.supplier_category, s.criticality,
    s.financial_health, s.contract_status, s.supplier_verdict,
    s.second_source_identified, s.continuity_plan_ready, s.notes
  from public.supplier_oem_risk_r3385 s
  where s.supplier_verdict in ('develop_second_source','de_risk_urgent','exit_replace')
     or s.financial_health in ('watch','distressed','unknown')
     or (s.criticality = 'single_source_critical' and s.second_source_identified = false)
     or s.contract_status in ('no_contract','under_renegotiation')
     or s.continuity_plan_ready = false
  order by case s.supplier_verdict
             when 'exit_replace' then 0
             when 'de_risk_urgent' then 1
             when 'develop_second_source' then 2
             else 3
           end,
           s.annual_spend_rupees desc;
end;
$$;

revoke execute on function public.founder_r3385_high_risk_suppliers() from public, anon;
grant execute on function public.founder_r3385_high_risk_suppliers() to authenticated;
