-- Round 3441: Founder Supplier-Concentration / Single-Source Dependency-Risk Board
-- Supplier concentration risk per spend category — supplier × category × annual spend × spend share × sourcing status × qualified alternates × lead time × criticality × risk rating × contingency readiness × CAPA

-- =============================================================================
-- TABLE 1: supplier_concentration_risk_r3441 — per-supplier concentration & dependency risk
-- =============================================================================
create table if not exists public.supplier_concentration_risk_r3441 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  supplier_code text not null,
  spend_category text not null,
  annual_spend_rupees numeric(14,2) not null,
  spend_share_pct numeric(5,2) not null,
  sourcing_status text not null check (sourcing_status in (
    'single_source','sole_source','dual_source','multi_source'
  )),
  alt_suppliers_qualified int not null,
  lead_time_days int not null,
  criticality text not null check (criticality in (
    'critical','high','medium','low'
  )),
  risk_rating text not null check (risk_rating in (
    'severe','elevated','moderate','low'
  )),
  contingency_ready boolean not null,
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_concentration_risk_r3441 enable row level security;

create index if not exists idx_scr_r3441_org on public.supplier_concentration_risk_r3441(organization_id);
create index if not exists idx_scr_r3441_month on public.supplier_concentration_risk_r3441(period_month);
create index if not exists idx_scr_r3441_risk on public.supplier_concentration_risk_r3441(risk_rating);

-- =============================================================================
-- TABLE 2: supplier_concentration_risk_capa_actions_r3441 — CAPA & mitigation actions
-- =============================================================================
create table if not exists public.supplier_concentration_risk_capa_actions_r3441 (
  id uuid primary key default gen_random_uuid(),
  risk_id uuid not null references public.supplier_concentration_risk_r3441(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'single_source_no_backup','sole_source_locked','no_qualified_alternate','no_contingency_plan',
    'critical_part_dependency','high_spend_concentration','long_lead_time','supplier_financial_risk',
    'geographic_concentration','contract_expiry_risk'
  )),
  root_cause text not null check (root_cause in (
    'oem_exclusive_supply','proprietary_technology','regulatory_lock_in','no_alternate_qualified',
    'cost_optimization_single_vendor','long_qualification_cycle','supplier_consolidation',
    'pending_investigation','legacy_contract','niche_component_market'
  )),
  corrective_action text not null check (corrective_action in (
    'qualify_alternate_supplier','develop_dual_source','build_safety_stock','negotiate_backup_agreement',
    'renegotiate_contract_terms','redesign_to_standard_part','establish_contingency_plan',
    'escalate_to_procurement_board','accept_risk_documented','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supplier_concentration_risk_capa_actions_r3441 enable row level security;

create index if not exists idx_scr_capa_r3441_link on public.supplier_concentration_risk_capa_actions_r3441(risk_id);
create index if not exists idx_scr_capa_r3441_status on public.supplier_concentration_risk_capa_actions_r3441(capa_status);

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

  -- 16 supplier-concentration rows
  insert into public.supplier_concentration_risk_r3441 (
    organization_id, supplier_name, supplier_code, spend_category,
    annual_spend_rupees, spend_share_pct, sourcing_status,
    alt_suppliers_qualified, lead_time_days, criticality, risk_rating,
    contingency_ready, period_month, notes
  )
  select v_org_id, q.sname, q.scode, q.scat,
    q.spend, q.shr, q.sstat,
    q.altq, q.ldt, q.crit, q.risk,
    q.cont, q.pmon::date, q.nt
  from (values
    ('GE Healthcare India','SUP-GE-01','imaging_xray_tubes',
     8200000,14.5,'sole_source',0,75,'critical','severe',false,'2026-07-01',
     'Proprietary X-ray tube — OEM sole source, no qualified alternate'),
    ('Siemens Healthineers India','SUP-SIE-02','ct_mri_spares',
     9600000,17.0,'sole_source',0,90,'critical','severe',false,'2026-07-01',
     'CT/MRI gradient & coil spares locked to OEM, no backup'),
    ('Philips India','SUP-PHI-03','patient_monitor_spares',
     3100000,5.5,'single_source',1,30,'high','elevated',false,'2026-07-01',
     'Monitor modules single-sourced, one alternate under qualification'),
    ('Trivitron Healthcare','SUP-TRV-04','lab_analyzer_reagents',
     2400000,4.2,'dual_source',2,18,'medium','moderate',true,'2026-07-01',
     'Reagents dual-sourced with buffer stock held'),
    ('Fresenius Medical Care India','SUP-FRS-05','dialysis_consumables',
     5400000,9.6,'single_source',1,25,'critical','elevated',true,'2026-07-01',
     'Dialyzer consumables single source, contingency stock maintained'),
    ('Karl Storz India','SUP-KRZ-06','endoscopy_spares',
     2900000,5.1,'sole_source',0,60,'high','severe',false,'2026-07-01',
     'Endoscope optics OEM-exclusive, long lead time'),
    ('Draeger India','SUP-DRG-07','biomedical_gas_systems',
     3600000,6.4,'single_source',0,45,'critical','severe',false,'2026-07-01',
     'Medical gas pipeline spares single source, no backup vendor'),
    ('Nihon Kohden India','SUP-NKH-08','patient_monitor_spares',
     1800000,3.2,'dual_source',2,22,'medium','moderate',true,'2026-07-01',
     'ECG acquisition modules dual-sourced'),
    ('BPL Medical Technologies','SUP-BPL-09','ventilator_spares',
     2100000,3.7,'dual_source',3,20,'high','moderate',true,'2026-07-01',
     'Ventilator spares with multiple qualified alternates'),
    ('Skanray Technologies','SUP-SKN-10','ventilator_spares',
     1500000,2.7,'multi_source',3,15,'medium','low',true,'2026-07-01',
     'Domestic vendor, commodity spares multi-source'),
    ('Erba Mannheim India','SUP-ERB-11','lab_analyzer_reagents',
     2650000,4.7,'single_source',1,28,'high','elevated',false,'2026-06-01',
     'Closed-system analyzer reagents locked, alternate pending'),
    ('Wipro GE','SUP-WGE-12','calibration_services',
     1200000,2.1,'dual_source',2,10,'medium','moderate',true,'2026-06-01',
     'Calibration NABL labs dual-sourced'),
    ('Vertiv India','SUP-VRT-13','ups_battery_systems',
     1700000,3.0,'multi_source',4,12,'low','low',true,'2026-06-01',
     'UPS & battery systems multi-source commodity'),
    ('Mindray India','SUP-MDR-14','ultrasound_probes',
     3300000,5.9,'single_source',0,55,'high','severe',false,'2026-06-01',
     'Ultrasound probe repair single-sourced, no alternate qualified'),
    ('Sterimed','SUP-STM-15','sterilizer_spares',
     1400000,2.5,'dual_source',2,24,'medium','moderate',true,'2026-06-01',
     'Autoclave & sterilizer spares dual-sourced'),
    ('Allengers Medical','SUP-ALG-16','imaging_xray_tubes',
     1900000,3.4,'single_source',1,40,'high','elevated',false,'2026-06-01',
     'C-arm image intensifier single source, alternate in trial')
  ) as q(sname, scode, scat, spend, shr, sstat, altq, ldt, crit, risk, cont, pmon, nt);

  -- CAPA seed — attach to specific suppliers via supplier_code
  insert into public.supplier_concentration_risk_capa_actions_r3441 (
    risk_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.exp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SUP-GE-01','single_source_no_backup','oem_exclusive_supply','qualify_alternate_supplier','in_progress',8200000,'Procurement Head','2026-09-30',null,'Seeking refurbished-tube alternate vendor for X-ray'),
    ('SUP-SIE-02','sole_source_locked','proprietary_technology','build_safety_stock','open',9600000,'Biomedical Lead','2026-10-15',null,'Critical CT/MRI spares — build safety-stock buffer'),
    ('SUP-KRZ-06','no_qualified_alternate','oem_exclusive_supply','develop_dual_source','escalated',2900000,'Category Manager','2026-08-20',null,'Endoscopy optics dependency escalated to procurement board'),
    ('SUP-DRG-07','no_contingency_plan','regulatory_lock_in','establish_contingency_plan','open',3600000,'Facilities Manager','2026-09-10',null,'Medical gas pipeline — no contingency, drafting plan'),
    ('SUP-MDR-14','critical_part_dependency','no_alternate_qualified','qualify_alternate_supplier','in_progress',3300000,'Service Manager','2026-08-31',null,'Ultrasound probe repair alternate under qualification'),
    ('SUP-FRS-05','high_spend_concentration','cost_optimization_single_vendor','negotiate_backup_agreement','verification_pending',5400000,'Procurement Head','2026-08-05',null,'Dialysis consumables backup agreement drafted, verifying'),
    ('SUP-ERB-11','sole_source_locked','regulatory_lock_in','accept_risk_documented','closed',2650000,'Lab Head','2026-07-15','2026-07-12','Closed-system reagents risk accepted and documented'),
    ('SUP-ALG-16','long_lead_time','long_qualification_cycle','develop_dual_source','overdue',1900000,'Category Manager','2026-07-05',null,'C-arm intensifier alternate trial slipped past target')
  ) as q(scode, fc, rc, ca, cst, exp, own, tcd, acd, nt)
  join public.supplier_concentration_risk_r3441 e
    on e.organization_id = v_org_id and e.supplier_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Risk-rating distribution
create or replace function public.founder_r3441_risk_rating_rollup()
returns table(risk_rating text, suppliers bigint, total_spend_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_concentration_risk_r3441)
  select l.risk_rating, count(*)::bigint,
         coalesce(sum(l.annual_spend_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.supplier_concentration_risk_r3441 l
  group by l.risk_rating
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3441_risk_rating_rollup() from public, anon;
grant execute on function public.founder_r3441_risk_rating_rollup() to authenticated;

-- 2) Spend-category scorecard
create or replace function public.founder_r3441_spend_category_scorecard()
returns table(
  spend_category text,
  suppliers bigint,
  total_spend_rupees numeric,
  avg_share_pct numeric,
  single_source bigint,
  severe bigint,
  no_contingency bigint,
  avg_lead_time_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.spend_category,
    count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    round(avg(l.spend_share_pct), 2),
    count(*) filter (where l.sourcing_status in ('single_source','sole_source'))::bigint,
    count(*) filter (where l.risk_rating = 'severe')::bigint,
    count(*) filter (where l.contingency_ready = false)::bigint,
    round(avg(l.lead_time_days), 1)
  from public.supplier_concentration_risk_r3441 l
  group by l.spend_category
  order by coalesce(sum(l.annual_spend_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3441_spend_category_scorecard() from public, anon;
grant execute on function public.founder_r3441_spend_category_scorecard() to authenticated;

-- 3) Sourcing-status × criticality matrix
create or replace function public.founder_r3441_sourcing_criticality_matrix()
returns table(sourcing_status text, criticality text, suppliers bigint, total_spend_rupees numeric, severe bigint, avg_alt_suppliers numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sourcing_status, l.criticality, count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    count(*) filter (where l.risk_rating = 'severe')::bigint,
    round(avg(l.alt_suppliers_qualified), 2)
  from public.supplier_concentration_risk_r3441 l
  group by l.sourcing_status, l.criticality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3441_sourcing_criticality_matrix() from public, anon;
grant execute on function public.founder_r3441_sourcing_criticality_matrix() to authenticated;

-- 4) Monthly spend / risk trend
create or replace function public.founder_r3441_monthly_spend_risk_trend()
returns table(period_month date, suppliers bigint, total_spend_rupees numeric, severe bigint, single_source bigint, no_contingency bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    count(*) filter (where l.risk_rating = 'severe')::bigint,
    count(*) filter (where l.sourcing_status in ('single_source','sole_source'))::bigint,
    count(*) filter (where l.contingency_ready = false)::bigint
  from public.supplier_concentration_risk_r3441 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3441_monthly_spend_risk_trend() from public, anon;
grant execute on function public.founder_r3441_monthly_spend_risk_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3441_capa_status_board()
returns table(capa_status text, findings bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.supplier_concentration_risk_capa_actions_r3441 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3441_capa_status_board() from public, anon;
grant execute on function public.founder_r3441_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3441_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.supplier_concentration_risk_capa_actions_r3441)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.supplier_concentration_risk_capa_actions_r3441 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3441_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3441_root_cause_pareto() to authenticated;

-- 7) Spend-impact digest by criticality
create or replace function public.founder_r3441_spend_impact_digest()
returns table(criticality text, suppliers bigint, total_spend_rupees numeric, avg_share_pct numeric, single_source bigint, severe bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.criticality,
    count(*)::bigint,
    coalesce(sum(l.annual_spend_rupees),0)::numeric,
    round(avg(l.spend_share_pct), 2),
    count(*) filter (where l.sourcing_status in ('single_source','sole_source'))::bigint,
    count(*) filter (where l.risk_rating = 'severe')::bigint
  from public.supplier_concentration_risk_r3441 l
  group by l.criticality
  order by coalesce(sum(l.annual_spend_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3441_spend_impact_digest() from public, anon;
grant execute on function public.founder_r3441_spend_impact_digest() to authenticated;

-- 8) High-risk dependency queue (single/sole source, severe, or no contingency)
create or replace function public.founder_r3441_high_risk_queue()
returns table(
  supplier_name text,
  supplier_code text,
  spend_category text,
  sourcing_status text,
  criticality text,
  risk_rating text,
  annual_spend_rupees numeric,
  spend_share_pct numeric,
  lead_time_days int,
  alt_suppliers_qualified int,
  contingency_ready boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.supplier_code, l.spend_category, l.sourcing_status,
    l.criticality, l.risk_rating, l.annual_spend_rupees, l.spend_share_pct,
    l.lead_time_days, l.alt_suppliers_qualified, l.contingency_ready, l.notes
  from public.supplier_concentration_risk_r3441 l
  where l.sourcing_status in ('single_source','sole_source')
     or l.risk_rating in ('severe','elevated')
     or l.contingency_ready = false
     or l.criticality = 'critical'
     or l.alt_suppliers_qualified = 0
  order by l.annual_spend_rupees desc, l.supplier_name;
end;
$$;

revoke execute on function public.founder_r3441_high_risk_queue() from public, anon;
grant execute on function public.founder_r3441_high_risk_queue() to authenticated;
