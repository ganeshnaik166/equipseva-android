-- Round 3528: Engineer Hazardous-Material / MSDS Handling-Safety Compliance Tracker
-- Hazmat (chemicals/gases) SDS-MSDS handling QA — hazard class x location x SDS availability x PPE x storage x labeling x spill-kit x compliance verdict x CAPA

-- =============================================================================
-- TABLE 1: hazmat_msds_compliance_r3528 — per-material SDS/PPE/storage compliance checks
-- =============================================================================
create table if not exists public.hazmat_msds_compliance_r3528 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  location_name text not null,
  record_code text not null,
  material_name text not null,
  un_number text,
  hazard_class text not null check (hazard_class in (
    'flammable','corrosive','toxic','compressed_gas','oxidizer','cryogenic','biohazard'
  )),
  sds_available boolean not null,
  ppe_compliant boolean not null,
  storage_compliant boolean not null,
  label_compliant boolean not null,
  spill_kit_ok boolean not null,
  last_audit date not null,
  compliance_status text not null check (compliance_status in (
    'compliant','minor_gap','major_gap','non_compliant','remediated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hazmat_msds_compliance_r3528 enable row level security;

create index if not exists idx_hazmat_msds_compliance_r3528_org on public.hazmat_msds_compliance_r3528(organization_id);
create index if not exists idx_hazmat_msds_compliance_r3528_audit on public.hazmat_msds_compliance_r3528(last_audit);
create index if not exists idx_hazmat_msds_compliance_r3528_status on public.hazmat_msds_compliance_r3528(compliance_status);

-- =============================================================================
-- TABLE 2: hazmat_msds_compliance_capa_actions_r3528 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hazmat_msds_compliance_capa_actions_r3528 (
  id uuid primary key default gen_random_uuid(),
  compliance_log_id uuid not null references public.hazmat_msds_compliance_r3528(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sds_missing','sds_outdated','ppe_non_compliance','storage_incompatible','labeling_deficiency',
    'spill_kit_deficiency','ventilation_inadequate','container_damaged','expiry_exceeded','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'sds_not_procured','vendor_sds_not_supplied','ppe_stock_shortage','staff_untrained','incorrect_storage_layout',
    'label_degraded','spill_kit_depleted','ventilation_fault','procurement_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'obtain_current_sds','replenish_ppe','reorganize_storage','relabel_container','restock_spill_kit',
    'repair_ventilation','retrain_staff','quarantine_material','dispose_expired_stock','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  safety_impact text not null check (safety_impact in (
    'peso_notifiable','factories_act_deviation','pcb_notifiable','worker_safety_alert','internal_only','none'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hazmat_msds_compliance_capa_actions_r3528 enable row level security;

create index if not exists idx_hazmat_msds_capa_r3528_log on public.hazmat_msds_compliance_capa_actions_r3528(compliance_log_id);
create index if not exists idx_hazmat_msds_capa_r3528_status on public.hazmat_msds_compliance_capa_actions_r3528(capa_status);

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

  -- 16 compliance-check rows
  insert into public.hazmat_msds_compliance_r3528 (
    organization_id, engineer_name, location_name, record_code, material_name, un_number,
    hazard_class, sds_available, ppe_compliant, storage_compliant, label_compliant, spill_kit_ok,
    last_audit, compliance_status, notes
  )
  select v_org_id, q.eng, q.loc, q.rcode, q.mat, q.un,
    q.hc, q.sds, q.ppe, q.stor, q.lbl, q.spill,
    q.aud::date, q.cs, q.nt
  from (values
    ('Rakesh Menon','Apollo Chennai - CSSD','HZ-APL-01','Ethylene Oxide','UN1040',
     'compressed_gas',true,true,true,true,true,'2026-07-05','compliant','EtO steriliser cylinder — SDS current, PPE and manifold storage compliant'),
    ('Rakesh Menon','Apollo Chennai - CSSD','HZ-APL-02','Isopropyl Alcohol 70%','UN1219',
     'flammable',true,true,false,true,true,'2026-07-05','minor_gap','IPA stored near ignition source — flammable cabinet relocation pending'),
    ('Sunil Iyer','Fortis Gurgaon - Lab Block','HZ-FRT-11','Glutaraldehyde (Cidex)','UN2810',
     'toxic',true,false,true,true,false,'2026-07-04','major_gap','Glutaraldehyde — respirator PPE not worn and spill kit depleted'),
    ('Sunil Iyer','Fortis Gurgaon - Lab Block','HZ-FRT-12','Formalin 10%','UN2209',
     'toxic',false,true,true,false,true,'2026-07-04','non_compliant','Formalin — SDS missing and container unlabelled, ventilation flagged'),
    ('Deepa Nair','Manipal Bengaluru - OT Complex','HZ-MNP-21','Nitrous Oxide','UN1070',
     'compressed_gas',true,true,true,true,true,'2026-07-03','compliant','N2O manifold — chained cylinders, SDS and PPE compliant'),
    ('Deepa Nair','Manipal Bengaluru - OT Complex','HZ-MNP-22','Hydrogen Peroxide 35%','UN2014',
     'oxidizer',true,true,false,true,true,'2026-07-03','minor_gap','H2O2 stored with organics — segregation gap noted'),
    ('Arjun Rao','AIIMS Delhi - Central Store','HZ-AIM-31','Sodium Hypochlorite','UN1791',
     'corrosive',true,true,true,false,true,'2026-06-30','minor_gap','Hypochlorite drum label faded — relabel scheduled'),
    ('Arjun Rao','AIIMS Delhi - Central Store','HZ-AIM-32','Hydrochloric Acid 30%','UN1789',
     'corrosive',false,false,false,false,false,'2026-06-30','non_compliant','HCl — no SDS, no PPE, incompatible storage and no spill kit at point of use'),
    ('Farhan Khan','CMC Vellore - Histopath Lab','HZ-CMC-41','Xylene','UN1307',
     'flammable',true,true,true,true,true,'2026-06-29','compliant','Xylene — flammable cabinet, bonding-grounding and PPE all compliant'),
    ('Farhan Khan','CMC Vellore - Histopath Lab','HZ-CMC-42','Methanol','UN1230',
     'flammable',true,true,true,true,false,'2026-06-29','minor_gap','Methanol — spill kit past refill date, otherwise compliant'),
    ('Vikram Sethi','KIMS Hyderabad - Biomedical Store','HZ-KIM-51','Peracetic Acid','UN3105',
     'oxidizer',true,false,true,true,true,'2026-06-28','major_gap','Peracetic acid — face shield PPE not available at point of use'),
    ('Vikram Sethi','KIMS Hyderabad - Biomedical Store','HZ-KIM-52','Medical Oxygen','UN1072',
     'compressed_gas',true,true,true,true,true,'2026-06-28','compliant','O2 cylinders — segregated from flammables, valves capped, compliant'),
    ('Priya Das','Yashoda Hyderabad - Gas Manifold Room','HZ-YSH-61','Acetone','UN1090',
     'flammable',true,true,false,true,true,'2026-06-27','remediated','Acetone storage segregation corrected after last audit — verified remediated'),
    ('Priya Das','Yashoda Hyderabad - Gas Manifold Room','HZ-YSH-62','Cytotoxic Drug Waste',null,
     'biohazard',true,true,true,true,true,'2026-06-27','compliant','Chemo waste — leak-proof cytotoxic bins, PPE and labelling compliant'),
    ('Manoj Pillai','Kokilaben Mumbai - Cryo Bay','HZ-KKB-71','Liquid Nitrogen','UN1977',
     'cryogenic',true,false,true,true,false,'2026-06-26','major_gap','LN2 — cryo gloves and face shield not worn, spill kit not cryo-rated'),
    ('Manoj Pillai','Kokilaben Mumbai - Cryo Bay','HZ-KKB-72','Liquid Oxygen','UN1073',
     'cryogenic',false,true,true,false,true,'2026-06-26','non_compliant','LOX vessel — SDS missing and hazard placard absent at cryo bay')
  ) as q(eng, loc, rcode, mat, un, hc, sds, ppe, stor, lbl, spill, aud, cs, nt);

  -- CAPA seed — attach to specific checks via record_code
  insert into public.hazmat_msds_compliance_capa_actions_r3528 (
    compliance_log_id, finding_category, root_cause, corrective_action,
    capa_status, safety_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HZ-FRT-12','sds_missing','vendor_sds_not_supplied','obtain_current_sds','in_progress','factories_act_deviation','Sunil Iyer','2026-07-10',null,6500.00,'Formalin SDS requested from vendor; container relabelled pending SDS receipt'),
    ('HZ-AIM-32','storage_incompatible','incorrect_storage_layout','reorganize_storage','escalated','peso_notifiable','Arjun Rao','2026-07-08',null,42000.00,'HCl stored with alkalis and cylinders — corrosive bay rebuild escalated'),
    ('HZ-FRT-11','ppe_non_compliance','ppe_stock_shortage','replenish_ppe','open','worker_safety_alert','Sunil Iyer','2026-07-09',null,8500.00,'Glutaraldehyde vapour respirators out of stock — PPE reorder raised'),
    ('HZ-KKB-72','labeling_deficiency','label_degraded','relabel_container','verification_pending','peso_notifiable','Manoj Pillai','2026-07-07',null,3000.00,'LOX cryo bay hazard placard reprinted; SDS also being sourced'),
    ('HZ-KIM-51','ppe_non_compliance','ppe_stock_shortage','replenish_ppe','closed','internal_only','Vikram Sethi','2026-07-02','2026-06-30',5200.00,'Peracetic acid face shields issued at point of use — verified closed'),
    ('HZ-KKB-71','spill_kit_deficiency','spill_kit_depleted','restock_spill_kit','overdue','factories_act_deviation','Manoj Pillai','2026-06-30',null,12000.00,'Cryo-rated spill kit and gloves overdue — vendor delay past target date'),
    ('HZ-YSH-61','storage_incompatible','incorrect_storage_layout','reorganize_storage','closed','internal_only','Priya Das','2026-06-28','2026-06-27',9000.00,'Acetone moved to flammable cabinet — remediation verified and closed'),
    ('HZ-CMC-42','spill_kit_deficiency','spill_kit_depleted','restock_spill_kit','open','none','Farhan Khan','2026-07-01',null,2500.00,'Methanol spill kit refill ordered — low priority')
  ) as q(rcode, fc, rc, ca, cst, si, own, tcd, acd, cost, nt)
  join public.hazmat_msds_compliance_r3528 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3528_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hazmat_msds_compliance_r3528)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hazmat_msds_compliance_r3528 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3528_compliance_status_rollup() to authenticated;

-- 2) Hazard-class scorecard
create or replace function public.founder_r3528_hazard_class_scorecard()
returns table(
  hazard_class text,
  total_records bigint,
  compliant bigint,
  minor_gap bigint,
  major_gap bigint,
  non_compliant bigint,
  remediated bigint,
  sds_missing bigint,
  ppe_gap bigint,
  storage_gap bigint,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hazard_class,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'minor_gap')::bigint,
    count(*) filter (where l.compliance_status = 'major_gap')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    count(*) filter (where l.compliance_status = 'remediated')::bigint,
    count(*) filter (where l.sds_available = false)::bigint,
    count(*) filter (where l.ppe_compliant = false)::bigint,
    count(*) filter (where l.storage_compliant = false)::bigint,
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.hazmat_msds_compliance_r3528 l
  group by l.hazard_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_hazard_class_scorecard() from public, anon;
grant execute on function public.founder_r3528_hazard_class_scorecard() to authenticated;

-- 3) Hazard-class x compliance-status matrix
create or replace function public.founder_r3528_hazard_compliance_matrix()
returns table(hazard_class text, compliance_status text, records bigint, sds_missing bigint, ppe_gap bigint, storage_gap bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hazard_class, l.compliance_status, count(*)::bigint,
    count(*) filter (where l.sds_available = false)::bigint,
    count(*) filter (where l.ppe_compliant = false)::bigint,
    count(*) filter (where l.storage_compliant = false)::bigint
  from public.hazmat_msds_compliance_r3528 l
  group by l.hazard_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_hazard_compliance_matrix() from public, anon;
grant execute on function public.founder_r3528_hazard_compliance_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3528_monthly_compliance_trend()
returns table(audit_month date, records bigint, compliant bigint, non_compliant bigint, sds_missing bigint, ppe_gap bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.last_audit)::date as audit_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status in ('non_compliant','major_gap'))::bigint,
    count(*) filter (where l.sds_available = false)::bigint,
    count(*) filter (where l.ppe_compliant = false)::bigint
  from public.hazmat_msds_compliance_r3528 l
  group by 1
  order by 1 desc;
end;
$$;

revoke execute on function public.founder_r3528_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3528_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3528_capa_status_board()
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
  from public.hazmat_msds_compliance_capa_actions_r3528 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_capa_status_board() from public, anon;
grant execute on function public.founder_r3528_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3528_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hazmat_msds_compliance_capa_actions_r3528)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hazmat_msds_compliance_capa_actions_r3528 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3528_root_cause_pareto() to authenticated;

-- 7) Safety-risk impact digest
create or replace function public.founder_r3528_safety_impact_digest()
returns table(safety_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.safety_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.hazmat_msds_compliance_capa_actions_r3528 c
  group by c.safety_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3528_safety_impact_digest() from public, anon;
grant execute on function public.founder_r3528_safety_impact_digest() to authenticated;

-- 8) High-risk compliance queue (non-compliant / major-gap / missing-SDS / any gap)
create or replace function public.founder_r3528_high_risk_queue()
returns table(
  engineer_name text,
  location_name text,
  material_name text,
  un_number text,
  hazard_class text,
  compliance_status text,
  sds_available text,
  ppe_compliant text,
  storage_compliant text,
  last_audit date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.location_name, l.material_name, l.un_number,
    l.hazard_class, l.compliance_status,
    case when l.sds_available then 'yes' else 'no' end,
    case when l.ppe_compliant then 'yes' else 'no' end,
    case when l.storage_compliant then 'yes' else 'no' end,
    l.last_audit, l.notes
  from public.hazmat_msds_compliance_r3528 l
  where l.compliance_status in ('major_gap','non_compliant')
     or l.sds_available = false
     or l.ppe_compliant = false
     or l.storage_compliant = false
     or l.label_compliant = false
     or l.spill_kit_ok = false
  order by l.last_audit desc, l.location_name;
end;
$$;

revoke execute on function public.founder_r3528_high_risk_queue() from public, anon;
grant execute on function public.founder_r3528_high_risk_queue() to authenticated;
