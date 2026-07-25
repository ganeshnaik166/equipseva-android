-- Round 3448: Engineer Installation Punch-List / Snag Defect-Closure Tracker
-- Post-installation punch-list / snag defect capture + closure tracker — discipline × severity ×
-- snag status × aging × handover-blocking flag × CAPA root-cause & closure across Indian-hospital projects.

-- =============================================================================
-- TABLE 1: install_punchlist_snag_r3448 — per-snag punch-list defect log
-- =============================================================================
create table if not exists public.install_punchlist_snag_r3448 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  snag_ref text not null,
  project_code text not null,
  snag_item text not null,
  discipline text not null check (discipline in (
    'mechanical','electrical','civil','plumbing','network','calibration','documentation','cosmetic'
  )),
  severity text not null check (severity in (
    'critical','major','minor','cosmetic'
  )),
  snag_status text not null check (snag_status in (
    'open','in_progress','fixed','verified','closed','deferred'
  )),
  raised_date date not null,
  target_date date,
  closed_date date,
  aging_days int,
  blocks_handover boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.install_punchlist_snag_r3448 enable row level security;

create index if not exists idx_install_punchlist_snag_r3448_org on public.install_punchlist_snag_r3448(organization_id);
create index if not exists idx_install_punchlist_snag_r3448_raised on public.install_punchlist_snag_r3448(raised_date);
create index if not exists idx_install_punchlist_snag_r3448_status on public.install_punchlist_snag_r3448(snag_status);

-- =============================================================================
-- TABLE 2: install_punchlist_snag_capa_actions_r3448 — CAPA & closure actions
-- =============================================================================
create table if not exists public.install_punchlist_snag_capa_actions_r3448 (
  id uuid primary key default gen_random_uuid(),
  snag_log_id uuid not null references public.install_punchlist_snag_r3448(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'mechanical_defect','electrical_defect','civil_defect','plumbing_leak','network_fault',
    'calibration_out_of_spec','documentation_gap','cosmetic_finish','safety_hazard','handover_blocker'
  )),
  root_cause text not null check (root_cause in (
    'poor_workmanship','material_defect','design_change','vendor_delay','incorrect_installation',
    'missing_component','site_condition','specification_mismatch','coordination_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rework_onsite','replace_component','recalibrate','rewire','reseal_plumbing','update_documentation',
    'reconfigure_network','touch_up_finish','schedule_vendor_visit','escalate_to_pm','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  handover_impact text not null check (handover_impact in (
    'blocks_handover','delays_handover','none','internal_only','client_witnessed_defect','warranty_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.install_punchlist_snag_capa_actions_r3448 enable row level security;

create index if not exists idx_install_punchlist_capa_r3448_log on public.install_punchlist_snag_capa_actions_r3448(snag_log_id);
create index if not exists idx_install_punchlist_capa_r3448_status on public.install_punchlist_snag_capa_actions_r3448(capa_status);

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

  -- 16 punch-list snag rows
  insert into public.install_punchlist_snag_r3448 (
    organization_id, engineer_name, hospital_name, snag_ref, project_code, snag_item,
    discipline, severity, snag_status, raised_date, target_date, closed_date,
    aging_days, blocks_handover, notes
  )
  select v_org_id, q.eng, q.hosp, q.sref, q.pcode, q.item,
    q.disc, q.sev, q.st, q.rd::date, q.td::date, q.cd::date,
    q.age::int, q.blk, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai','SNG-APL-01','PRJ-APL-CT','CT scanner chiller vibration above spec',
     'mechanical','critical','open','2026-07-02','2026-07-10',null,23,true,'Chiller anti-vibration mount fault blocks CT commissioning handover'),
    ('Rajesh Kumar','Apollo Chennai','SNG-APL-02','PRJ-APL-CT','Isolation transformer earth bond loose',
     'electrical','major','in_progress','2026-07-03','2026-07-12',null,22,true,'Earth continuity fail on CT room isolation panel'),
    ('Priya Nair','Fortis Gurgaon','SNG-FRT-11','PRJ-FRT-OT','OT laminar flow ceiling panel gap',
     'civil','major','fixed','2026-06-28','2026-07-08',null,27,false,'Modular OT ceiling grid gap sealed — verification pending'),
    ('Priya Nair','Fortis Gurgaon','SNG-FRT-12','PRJ-FRT-OT','Medical gas pipeline pressure drop',
     'plumbing','critical','open','2026-06-29','2026-07-09',null,26,true,'MGPS oxygen line pressure drop — handover blocked'),
    ('Anil Verma','Manipal Bengaluru','SNG-MNP-21','PRJ-MNP-ICU','Nurse call network switch port dead',
     'network','minor','in_progress','2026-07-01','2026-07-11',null,24,false,'Two nurse-call ports non-responsive in ICU bay'),
    ('Anil Verma','Manipal Bengaluru','SNG-MNP-22','PRJ-MNP-ICU','Ventilator flow sensor calibration drift',
     'calibration','major','verified','2026-06-30','2026-07-07','2026-07-06',7,false,'Flow sensor recalibrated and verified against reference'),
    ('Sunita Rao','AIIMS Delhi','SNG-AIM-31','PRJ-AIM-CATH','Cath lab table height limit switch faulty',
     'electrical','critical','open','2026-06-27','2026-07-05',null,28,true,'Table travel limit switch faulty — patient-safety hold'),
    ('Sunita Rao','AIIMS Delhi','SNG-AIM-32','PRJ-AIM-CATH','As-built drawings not submitted',
     'documentation','major','open','2026-06-27','2026-07-15',null,28,true,'As-built and O&M manuals pending — blocks handover sign-off'),
    ('Vikram Singh','CMC Vellore','SNG-CMC-41','PRJ-CMC-LAB','Lab bench laminate edge chipped',
     'cosmetic','cosmetic','deferred','2026-06-26','2026-07-20',null,29,false,'Cosmetic laminate chip — deferred to snag round 2'),
    ('Vikram Singh','CMC Vellore','SNG-CMC-42','PRJ-CMC-LAB','Autoclave steam trap leak',
     'plumbing','major','fixed','2026-06-25','2026-07-06',null,30,false,'Steam trap reseated — awaiting leak verification'),
    ('Meera Iyer','KIMS Hyderabad','SNG-KIM-51','PRJ-KIM-MRI','MRI RF shield door seal gap',
     'civil','critical','in_progress','2026-06-24','2026-07-04',null,31,true,'RF door seal leakage above spec — blocks MRI go-live'),
    ('Meera Iyer','KIMS Hyderabad','SNG-KIM-52','PRJ-KIM-MRI','Chilled water flow below design',
     'mechanical','major','open','2026-06-24','2026-07-08',null,31,false,'MRI chiller flow 15 percent below design value'),
    ('Karthik Menon','Yashoda Hyderabad','SNG-YSH-61','PRJ-YSH-NICU','NICU wall oxygen outlet mislabelled',
     'documentation','minor','closed','2026-06-20','2026-06-28','2026-06-27',7,false,'Outlet labels corrected and closed'),
    ('Karthik Menon','Yashoda Hyderabad','SNG-YSH-62','PRJ-YSH-NICU','Warmer power socket polarity reversed',
     'electrical','critical','closed','2026-06-20','2026-06-25','2026-06-24',4,true,'Polarity corrected, retested and closed'),
    ('Deepa Shah','Kokilaben Mumbai','SNG-KKB-71','PRJ-KKB-ER','ER pendant boom brake drift',
     'mechanical','major','in_progress','2026-06-22','2026-07-05',null,33,false,'Ceiling pendant brake drift — awaiting spare'),
    ('Deepa Shah','Kokilaben Mumbai','SNG-KKB-72','PRJ-KKB-ER','Corridor wall scuff paint touch-up',
     'cosmetic','cosmetic','open','2026-06-22','2026-07-18',null,33,false,'Corridor wall scuff paint touch-up pending')
  ) as q(eng, hosp, sref, pcode, item, disc, sev, st, rd, td, cd, age, blk, nt);

  -- CAPA seed — attach to specific snags via snag_ref
  insert into public.install_punchlist_snag_capa_actions_r3448 (
    snag_log_id, finding_category, root_cause, corrective_action,
    capa_status, handover_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.hi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SNG-APL-01','mechanical_defect','poor_workmanship','rework_onsite','in_progress','blocks_handover','2026-07-10',null,45000.00,'Chiller anti-vibration mounts to be reworked and re-tested'),
    ('SNG-FRT-12','plumbing_leak','incorrect_installation','reseal_plumbing','open','blocks_handover','2026-07-09',null,28000.00,'MGPS joint rework and full pressure re-test'),
    ('SNG-AIM-31','electrical_defect','material_defect','replace_component','escalated','blocks_handover','2026-07-05',null,18000.00,'Limit switch RMA raised with OEM — safety critical'),
    ('SNG-KIM-51','civil_defect','poor_workmanship','rework_onsite','in_progress','delays_handover','2026-07-04',null,62000.00,'RF door seal re-machined and re-tested for attenuation'),
    ('SNG-YSH-62','electrical_defect','incorrect_installation','rewire','closed','client_witnessed_defect','2026-06-25','2026-06-24',9500.00,'Warmer socket polarity corrected and client witnessed'),
    ('SNG-AIM-32','documentation_gap','coordination_gap','update_documentation','open','blocks_handover','2026-07-15',null,0.00,'As-built pack and O&M manuals to be compiled and submitted'),
    ('SNG-CMC-42','plumbing_leak','poor_workmanship','reseal_plumbing','verification_pending','internal_only','2026-07-06',null,7500.00,'Steam trap reseated — verify no leak over next cycle'),
    ('SNG-MNP-21','network_fault','missing_component','reconfigure_network','overdue','delays_handover','2026-07-06',null,12000.00,'Nurse-call switch SFP module awaited — past target date')
  ) as q(sref, fc, rc, ca, cst, hi, tcd, acd, cost, nt)
  join public.install_punchlist_snag_r3448 e
    on e.organization_id = v_org_id and e.snag_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Snag status distribution
create or replace function public.founder_r3448_snag_status_rollup()
returns table(snag_status text, snags bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.install_punchlist_snag_r3448)
  select l.snag_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.install_punchlist_snag_r3448 l
  group by l.snag_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_snag_status_rollup() from public, anon;
grant execute on function public.founder_r3448_snag_status_rollup() to authenticated;

-- 2) Discipline-level scorecard
create or replace function public.founder_r3448_discipline_scorecard()
returns table(
  discipline text,
  total_snags bigint,
  open_snags bigint,
  critical bigint,
  blocks_handover bigint,
  closed bigint,
  avg_aging_days numeric,
  closure_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.discipline,
    count(*)::bigint,
    count(*) filter (where l.snag_status in ('open','in_progress','deferred'))::bigint,
    count(*) filter (where l.severity = 'critical')::bigint,
    count(*) filter (where l.blocks_handover = true)::bigint,
    count(*) filter (where l.snag_status in ('closed','verified'))::bigint,
    round(avg(l.aging_days), 1),
    round(100.0 * count(*) filter (where l.snag_status in ('closed','verified'))::numeric / nullif(count(*),0), 1)
  from public.install_punchlist_snag_r3448 l
  group by l.discipline
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_discipline_scorecard() from public, anon;
grant execute on function public.founder_r3448_discipline_scorecard() to authenticated;

-- 3) Discipline × severity matrix
create or replace function public.founder_r3448_discipline_severity_matrix()
returns table(discipline text, severity text, snags bigint, open_snags bigint, closed bigint, avg_aging_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.discipline, l.severity, count(*)::bigint,
    count(*) filter (where l.snag_status in ('open','in_progress','deferred'))::bigint,
    count(*) filter (where l.snag_status in ('closed','verified'))::bigint,
    round(avg(l.aging_days), 1)
  from public.install_punchlist_snag_r3448 l
  group by l.discipline, l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_discipline_severity_matrix() from public, anon;
grant execute on function public.founder_r3448_discipline_severity_matrix() to authenticated;

-- 4) Monthly snag trend
create or replace function public.founder_r3448_monthly_snag_trend()
returns table(snag_month text, snags bigint, closed bigint, open_snags bigint, critical bigint, blocks_handover bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.raised_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.snag_status in ('closed','verified'))::bigint,
    count(*) filter (where l.snag_status in ('open','in_progress','deferred'))::bigint,
    count(*) filter (where l.severity = 'critical')::bigint,
    count(*) filter (where l.blocks_handover = true)::bigint
  from public.install_punchlist_snag_r3448 l
  group by to_char(date_trunc('month', l.raised_date), 'YYYY-MM')
  order by to_char(date_trunc('month', l.raised_date), 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3448_monthly_snag_trend() from public, anon;
grant execute on function public.founder_r3448_monthly_snag_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3448_capa_status_board()
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
  from public.install_punchlist_snag_capa_actions_r3448 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_capa_status_board() from public, anon;
grant execute on function public.founder_r3448_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3448_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.install_punchlist_snag_capa_actions_r3448)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.install_punchlist_snag_capa_actions_r3448 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3448_root_cause_pareto() to authenticated;

-- 7) Handover-impact digest
create or replace function public.founder_r3448_handover_impact_digest()
returns table(handover_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.handover_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.install_punchlist_snag_capa_actions_r3448 c
  group by c.handover_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3448_handover_impact_digest() from public, anon;
grant execute on function public.founder_r3448_handover_impact_digest() to authenticated;

-- 8) High-risk snag queue (critical / aging / blocks-handover)
create or replace function public.founder_r3448_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  snag_ref text,
  project_code text,
  discipline text,
  severity text,
  snag_status text,
  raised_date date,
  aging_days int,
  blocks_handover boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.snag_ref, l.project_code, l.discipline,
    l.severity, l.snag_status, l.raised_date, l.aging_days, l.blocks_handover, l.notes
  from public.install_punchlist_snag_r3448 l
  where l.severity = 'critical'
     or l.blocks_handover = true
     or (l.aging_days >= 25 and l.snag_status not in ('closed','verified'))
     or l.snag_status = 'deferred'
  order by l.aging_days desc nulls last, l.raised_date;
end;
$$;

revoke execute on function public.founder_r3448_high_risk_queue() from public, anon;
grant execute on function public.founder_r3448_high_risk_queue() to authenticated;
