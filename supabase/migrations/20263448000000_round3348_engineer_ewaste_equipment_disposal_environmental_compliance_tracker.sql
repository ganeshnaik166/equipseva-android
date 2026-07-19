-- Round 3348: Engineer E-Waste & End-of-Life Equipment Disposal Environmental-Compliance Tracker
-- E-Waste Rules compliance — equipment type × hazardous components × data sanitization × authorized recycler × EPR docs × manifest × disposal route × CAPA

-- =============================================================================
-- TABLE 1: ewaste_disposal_r3348 — per disposal-case compliance log
-- =============================================================================
create table if not exists public.ewaste_disposal_r3348 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  disposal_code text not null,
  equipment_type text not null check (equipment_type in (
    'imaging','patient_monitoring','dialysis','lab_analyzer',
    'batteries_ups','it_hardware','general_biomedical'
  )),
  decommission_date date not null,
  weight_kg numeric(8,2),
  hazardous_components text not null check (hazardous_components in (
    'lead_shielding','batteries','mercury','crt','radioactive_source','none'
  )),
  data_sanitization_done boolean not null default false,
  authorized_recycler_used boolean not null default false,
  epr_documentation_complete boolean not null default false,
  manifest_generated boolean not null default false,
  resale_or_recycle text not null check (resale_or_recycle in (
    'resold','recycled','scrapped','returned_oem','donated'
  )),
  pickup_completed boolean not null default false,
  compliance_verdict text not null check (compliance_verdict in (
    'compliant','documentation_pending','unauthorized_route','hazardous_gap','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ewaste_disposal_r3348 enable row level security;

create index if not exists idx_ewaste_disposal_r3348_org on public.ewaste_disposal_r3348(organization_id);
create index if not exists idx_ewaste_disposal_r3348_date on public.ewaste_disposal_r3348(decommission_date);
create index if not exists idx_ewaste_disposal_r3348_verdict on public.ewaste_disposal_r3348(compliance_verdict);

-- =============================================================================
-- TABLE 2: ewaste_disposal_capa_actions_r3348 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ewaste_disposal_capa_actions_r3348 (
  id uuid primary key default gen_random_uuid(),
  disposal_log_id uuid not null references public.ewaste_disposal_r3348(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'documentation_gap','rerouting_required','hazardous_handling','data_sanitization_gap',
    'manifest_missing','epr_noncompliance','pickup_delay'
  )),
  root_cause text not null check (root_cause in (
    'untrained_engineer','recycler_not_authorized','manifest_software_error','data_wipe_tool_unavailable',
    'hazard_labeling_missing','vendor_pickup_backlog','epr_credit_shortfall','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','switch_authorized_recycler','regenerate_manifest','complete_data_sanitization',
    'segregate_hazardous_components','expedite_vendor_pickup','file_epr_documentation','escalate_to_compliance','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cpcb_notifiable','spcb_finding','none','internal_only','epr_shortfall','hazardous_waste_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ewaste_disposal_capa_actions_r3348 enable row level security;

create index if not exists idx_ewaste_capa_r3348_log on public.ewaste_disposal_capa_actions_r3348(disposal_log_id);
create index if not exists idx_ewaste_capa_r3348_status on public.ewaste_disposal_capa_actions_r3348(capa_status);

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

  -- 14 disposal-case rows
  insert into public.ewaste_disposal_r3348 (
    organization_id, engineer_name, hospital_name, disposal_code, equipment_type,
    decommission_date, weight_kg, hazardous_components,
    data_sanitization_done, authorized_recycler_used, epr_documentation_complete, manifest_generated,
    resale_or_recycle, pickup_completed, compliance_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.dcode, q.etype,
    q.ddate::date, q.wkg, q.haz,
    q.dsan, q.arec, q.epr, q.manf,
    q.ror, q.pick, q.verd, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai Greams Road','EW-APL-2601','imaging','2026-06-20',780.50,'lead_shielding',
     true,true,true,true,'recycled',true,'compliant','Decommissioned CT gantry — lead shielding segregated, CPCB Form-6 manifest filed'),
    ('Suresh Nair','Fortis Gurgaon','EW-FRT-2602','patient_monitoring','2026-06-19',42.00,'batteries',
     true,true,true,true,'recycled',true,'compliant','12 bedside monitors retired — Li-ion batteries to authorized recycler'),
    ('Anita Desai','Manipal Bengaluru Old Airport Road','EW-MNP-2603','dialysis','2026-06-18',310.00,'none',
     false,true,false,false,'scrapped',true,'documentation_pending','8 RO/dialysis units scrapped — EPR docs and manifest pending'),
    ('Vikram Singh','AIIMS Delhi Ansari Nagar','EW-AIM-2604','imaging','2026-06-17',1250.00,'radioactive_source',
     false,false,false,false,'scrapped',false,'escalate','Gamma-camera source not routed via BRIT/AERB — escalated to RSO'),
    ('Priya Menon','CMC Vellore','EW-CMC-2605','lab_analyzer','2026-06-16',95.00,'mercury',
     true,true,true,true,'returned_oem',true,'compliant','Old analyzers with mercury cells returned to OEM under EPR buy-back'),
    ('Rahul Verma','KIMS Hyderabad','EW-KIM-2606','batteries_ups','2026-06-15',540.00,'batteries',
     true,false,true,true,'recycled',true,'unauthorized_route','UPS battery bank sent to unlisted scrap dealer — recycler not CPCB-authorized'),
    ('Deepa Iyer','Apollo Chennai Greams Road','EW-APL-2607','it_hardware','2026-06-14',120.00,'none',
     false,true,true,true,'donated',true,'documentation_pending','PACS workstations donated — data-sanitization certificate missing'),
    ('Manoj Pillai','Fortis Gurgaon','EW-FRT-2608','general_biomedical','2026-06-13',65.00,'none',
     true,true,true,true,'recycled',true,'compliant','Assorted infusion pumps recycled with full manifest and EPR docs'),
    ('Sunita Rao','Manipal Bengaluru Old Airport Road','EW-MNP-2609','imaging','2026-06-12',680.00,'lead_shielding',
     true,true,false,false,'recycled',true,'hazardous_gap','C-arm decommissioned — lead apron/shield handling log incomplete'),
    ('Arjun Reddy','KIMS Hyderabad','EW-KIM-2610','patient_monitoring','2026-06-11',28.50,'batteries',
     true,true,true,false,'scrapped',false,'documentation_pending','Central station retired — manifest not yet generated, pickup pending'),
    ('Kavya Krishnan','CMC Vellore','EW-CMC-2611','dialysis','2026-06-10',260.00,'none',
     true,true,true,true,'returned_oem',true,'compliant','Dialysis machines returned to OEM buy-back program'),
    ('Nikhil Joshi','AIIMS Delhi Ansari Nagar','EW-AIM-2612','lab_analyzer','2026-06-09',110.00,'mercury',
     false,false,false,false,'scrapped',false,'escalate','Analyzers with mercury sent to informal recycler — full compliance failure, escalated'),
    ('Meera Sharma','Yashoda Hyderabad','EW-YSH-2613','it_hardware','2026-06-08',75.00,'crt',
     true,true,true,true,'recycled',true,'compliant','Legacy CRT monitors recycled — leaded glass to authorized CRT processor'),
    ('Gopal Menon','Aster Kochi','EW-AST-2614','batteries_ups','2026-06-07',420.00,'batteries',
     true,false,false,true,'recycled',false,'unauthorized_route','Lead-acid UPS batteries picked up by unauthorized vendor — reroute ordered')
  ) as q(eng, hosp, dcode, etype, ddate, wkg, haz, dsan, arec, epr, manf, ror, pick, verd, nt);

  -- CAPA seed — attach to specific disposal cases via disposal_code
  insert into public.ewaste_disposal_capa_actions_r3348 (
    disposal_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EW-KIM-2606','rerouting_required','recycler_not_authorized','switch_authorized_recycler','in_progress','spcb_finding','2026-06-25',null,35000.00,'Reroute UPS batteries to CPCB-listed recycler — pickup rescheduled'),
    ('EW-AIM-2604','hazardous_handling','hazard_labeling_missing','segregate_hazardous_components','escalated','hazardous_waste_alert','2026-06-24',null,120000.00,'Radioactive source must route via BRIT/AERB — RSO and CPCB notified'),
    ('EW-MNP-2603','documentation_gap','manifest_software_error','regenerate_manifest','closed','internal_only','2026-06-22','2026-06-21',8000.00,'EPR docs and Form-6 manifest regenerated and filed'),
    ('EW-APL-2607','data_sanitization_gap','data_wipe_tool_unavailable','complete_data_sanitization','verification_pending','epr_shortfall','2026-06-20',null,15000.00,'NIST-purge wipe run on PACS drives — awaiting sanitization certificate'),
    ('EW-MNP-2609','hazardous_handling','hazard_labeling_missing','segregate_hazardous_components','open','spcb_finding','2026-06-26',null,22000.00,'Lead-shield handling log to be completed for C-arm decommission'),
    ('EW-AIM-2612','documentation_gap','untrained_engineer','retrain_engineer','escalated','cpcb_notifiable','2026-06-23',null,50000.00,'Mercury analyzers to informal recycler — CPCB notifiable, engineer retraining ordered'),
    ('EW-AST-2614','pickup_delay','vendor_pickup_backlog','expedite_vendor_pickup','overdue','hazardous_waste_alert','2026-06-18',null,18000.00,'Lead-acid battery pickup overdue — expedite authorized vendor')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ewaste_disposal_r3348 e
    on e.organization_id = v_org_id and e.disposal_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3348_compliance_verdict_rollup()
returns table(compliance_verdict text, cases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ewaste_disposal_r3348)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ewaste_disposal_r3348 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3348_compliance_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3348_hospital_scorecard()
returns table(
  hospital_name text,
  total_cases bigint,
  compliant bigint,
  doc_pending bigint,
  noncompliant bigint,
  data_sanitization_missing bigint,
  unauthorized_recycler bigint,
  epr_incomplete bigint,
  compliant_pct numeric
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
    count(*) filter (where l.compliance_verdict = 'compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'documentation_pending')::bigint,
    count(*) filter (where l.compliance_verdict in ('unauthorized_route','hazardous_gap','escalate'))::bigint,
    count(*) filter (where l.data_sanitization_done = false)::bigint,
    count(*) filter (where l.authorized_recycler_used = false)::bigint,
    count(*) filter (where l.epr_documentation_complete = false)::bigint,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.ewaste_disposal_r3348 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3348_hospital_scorecard() to authenticated;

-- 3) Equipment type × hazardous components matrix
create or replace function public.founder_r3348_equipment_hazard_matrix()
returns table(equipment_type text, hazardous_components text, cases bigint, compliant bigint, total_weight_kg numeric, avg_weight_kg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.hazardous_components, count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'compliant')::bigint,
    round(coalesce(sum(l.weight_kg),0), 2),
    round(avg(l.weight_kg), 2)
  from public.ewaste_disposal_r3348 l
  group by l.equipment_type, l.hazardous_components
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_equipment_hazard_matrix() from public, anon;
grant execute on function public.founder_r3348_equipment_hazard_matrix() to authenticated;

-- 4) Daily disposal trend
create or replace function public.founder_r3348_daily_disposal_trend()
returns table(decommission_date date, cases bigint, compliant bigint, noncompliant bigint, total_weight_kg numeric, pickup_pending bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.decommission_date,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'compliant')::bigint,
    count(*) filter (where l.compliance_verdict in ('unauthorized_route','hazardous_gap','escalate'))::bigint,
    round(coalesce(sum(l.weight_kg),0), 2),
    count(*) filter (where l.pickup_completed = false)::bigint
  from public.ewaste_disposal_r3348 l
  group by l.decommission_date
  order by l.decommission_date desc;
end;
$$;

revoke execute on function public.founder_r3348_daily_disposal_trend() from public, anon;
grant execute on function public.founder_r3348_daily_disposal_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3348_capa_status_board()
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
  from public.ewaste_disposal_capa_actions_r3348 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_capa_status_board() from public, anon;
grant execute on function public.founder_r3348_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3348_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ewaste_disposal_capa_actions_r3348)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ewaste_disposal_capa_actions_r3348 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3348_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3348_regulatory_impact_digest()
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
  from public.ewaste_disposal_capa_actions_r3348 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3348_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3348_regulatory_impact_digest() to authenticated;

-- 8) High-risk disposal queue (top individual concerns)
create or replace function public.founder_r3348_high_risk_queue()
returns table(
  hospital_name text,
  disposal_code text,
  engineer_name text,
  decommission_date date,
  compliance_verdict text,
  equipment_type text,
  hazardous_components text,
  data_sanitization_done boolean,
  authorized_recycler_used boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.disposal_code, l.engineer_name, l.decommission_date,
    l.compliance_verdict, l.equipment_type, l.hazardous_components,
    l.data_sanitization_done, l.authorized_recycler_used, l.notes
  from public.ewaste_disposal_r3348 l
  where l.compliance_verdict in ('documentation_pending','unauthorized_route','hazardous_gap','escalate')
     or l.data_sanitization_done = false
     or l.authorized_recycler_used = false
     or l.epr_documentation_complete = false
     or l.manifest_generated = false
     or l.pickup_completed = false
  order by l.decommission_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3348_high_risk_queue() from public, anon;
grant execute on function public.founder_r3348_high_risk_queue() to authenticated;
