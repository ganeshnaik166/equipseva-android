-- Round 3651: Founder Medical-Device Shelf-Life / Stability-Study Board
-- Shelf-life stability studies — device × study ref × real-time/accelerated aging × labeled vs validated shelf life × timepoint completion × failures × claim gaps × CAPA

-- =============================================================================
-- TABLE 1: shelf_life_r3651 — per-device shelf-life / stability-study register
-- =============================================================================
create table if not exists public.shelf_life_r3651 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_name text not null,
  study_ref text not null,
  period_month date not null,
  labeled_shelf_life_months int not null,
  validated_shelf_life_months int not null,
  timepoints_planned int not null,
  timepoints_completed int not null,
  failures_observed int not null,
  aging_factor numeric(5,2),
  study_start date,
  study_completion_due date,
  study_method text not null check (study_method in (
    'real_time','accelerated','both','extension_protocol'
  )),
  study_status text not null check (study_status in (
    'supporting_claim','on_track','timepoint_failure','claim_gap','not_started'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.shelf_life_r3651 enable row level security;

create index if not exists idx_shelf_life_r3651_org on public.shelf_life_r3651(organization_id);
create index if not exists idx_shelf_life_r3651_month on public.shelf_life_r3651(period_month);
create index if not exists idx_shelf_life_r3651_status on public.shelf_life_r3651(study_status);

-- =============================================================================
-- TABLE 2: shelf_life_capa_actions_r3651 — CAPA & stability-study actions
-- =============================================================================
create table if not exists public.shelf_life_capa_actions_r3651 (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.shelf_life_r3651(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'protocol_deviation','chamber_excursion','packaging_seal_degradation',
    'sterile_barrier_failure','material_supplier_change','test_lab_backlog',
    'aging_factor_misapplied','documentation_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'repeat_timepoint_testing','extend_real_time_study','revise_labeled_shelf_life',
    'requalify_packaging','change_packaging_supplier','update_stability_protocol',
    'expedite_lab_testing','field_safety_notice','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.shelf_life_capa_actions_r3651 enable row level security;

create index if not exists idx_shelf_life_capa_r3651_study on public.shelf_life_capa_actions_r3651(study_id);
create index if not exists idx_shelf_life_capa_r3651_status on public.shelf_life_capa_actions_r3651(capa_status);

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

  -- 16 shelf-life study rows
  insert into public.shelf_life_r3651 (
    organization_id, device_name, study_ref, period_month,
    labeled_shelf_life_months, validated_shelf_life_months,
    timepoints_planned, timepoints_completed, failures_observed,
    aging_factor, study_start, study_completion_due,
    study_method, study_status, trend_dir, notes
  )
  select v_org_id, q.dname, q.sref, q.pm::date,
    q.lbl, q.vld,
    q.tpp, q.tpc, q.fobs,
    q.af, q.sst::date, q.sdue::date,
    q.meth, q.stat, q.tdir, q.nt
  from (values
    ('ICU Ventilator VX-500','SLS-VEN-001','2026-07-01',
     60,60,8,8,0,1.00,'2021-06-15','2026-06-15','real_time','supporting_claim','stable','Real-time study complete — 5-year label claim fully supported'),
    ('Infusion Pump IP-230','SLS-INF-002','2026-07-01',
     36,24,6,4,1,4.00,'2025-01-10','2026-10-10','accelerated','timepoint_failure','worsening','Occlusion-sensor drift at 24-month accelerated timepoint'),
    ('Patient Monitor PM-12','SLS-MON-003','2026-07-01',
     48,48,7,5,0,2.00,'2024-03-01','2027-03-01','both','on_track','stable','Accelerated arm complete, real-time pulls on schedule'),
    ('Dialysis Machine DL-88','SLS-DIA-004','2026-07-01',
     60,36,8,5,2,3.50,'2023-08-20','2027-02-20','accelerated','claim_gap','worsening','Hydraulic seal embrittlement — validated life 24 months short of label'),
    ('Defibrillator DF-Pro','SLS-DEF-005','2026-06-01',
     72,72,9,6,0,1.00,'2022-11-05','2028-11-05','real_time','on_track','improving','66-month pull passed all electrical safety and energy-delivery specs'),
    ('C-Arm Imaging CA-9','SLS-CRM-006','2026-06-01',
     84,84,10,10,0,1.00,'2019-04-12','2026-04-12','real_time','supporting_claim','stable','7-year real-time study closed — image chain within tolerance'),
    ('Syringe Pump SP-55','SLS-SYR-007','2026-06-01',
     36,36,6,3,0,4.20,'2025-09-01','2026-12-01','accelerated','on_track','stable','Accelerated aging at 55C — mid-study pulls nominal'),
    ('Pulse Oximeter PO-2','SLS-OXI-008','2026-06-01',
     24,18,5,4,1,2.50,'2024-12-15','2026-09-15','both','claim_gap','stable','LED emitter drift — 18-month validated vs 24-month label'),
    ('ICU Ventilator VX-500','SLS-VEN-009','2026-05-01',
     60,48,8,6,1,3.00,'2023-02-01','2026-12-01','extension_protocol','timepoint_failure','worsening','O2 cell housing crack at 48-month extension pull'),
    ('Anaesthesia Workstation AW-4','SLS-ANE-010','2026-05-01',
     60,0,8,0,0,null,'2026-09-01','2031-09-01','real_time','not_started','stable','Study protocol approved — stability chamber slot awaited'),
    ('Infusion Pump IP-230','SLS-INF-011','2026-05-01',
     36,36,6,6,0,4.00,'2024-06-18','2026-03-18','accelerated','supporting_claim','improving','Full accelerated series passed — claim supported pending real-time confirmation'),
    ('Patient Monitor PM-12','SLS-MON-012','2026-05-01',
     48,36,7,4,1,2.80,'2024-10-02','2027-04-02','both','timepoint_failure','stable','Pouch seal-strength failure at 36-month timepoint'),
    ('Dialysis Machine DL-88','SLS-DIA-013','2026-04-01',
     60,60,8,7,0,1.00,'2021-12-01','2026-12-01','real_time','on_track','stable','54-month pull passed conductivity and pressure-hold tests'),
    ('Defibrillator DF-Pro','SLS-DEF-014','2026-04-01',
     72,54,9,7,2,3.20,'2022-07-22','2026-10-22','extension_protocol','claim_gap','worsening','Battery pack capacity fade beyond 54 months — label revision under review'),
    ('C-Arm Imaging CA-9','SLS-CRM-015','2026-04-01',
     84,0,10,0,0,null,'2026-10-15','2033-10-15','real_time','not_started','stable','Next-gen detector variant — study registered, first pull not due'),
    ('Syringe Pump SP-55','SLS-SYR-016','2026-04-01',
     36,30,6,5,1,4.50,'2024-01-30','2026-08-30','accelerated','timepoint_failure','improving','30-month pull retested after lab backlog — one motor-torque outlier')
  ) as q(dname, sref, pm, lbl, vld, tpp, tpc, fobs, af, sst, sdue, meth, stat, tdir, nt);

  -- CAPA seed — attach to specific studies via study_ref
  insert into public.shelf_life_capa_actions_r3651 (
    study_id, root_cause, corrective_action, capa_status,
    cost_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SLS-INF-002','packaging_seal_degradation','repeat_timepoint_testing','in_progress',180000.00,'Kavya Raman','2026-08-15',null,'24-month timepoint repeat under expedited chamber slot'),
    ('SLS-DIA-004','material_supplier_change','revise_labeled_shelf_life','escalated',520000.00,'Arjun Mehta','2026-08-01',null,'Label revision dossier with regulatory — seal supplier changed in 2024'),
    ('SLS-OXI-008','aging_factor_misapplied','extend_real_time_study','open',95000.00,'Sneha Kulkarni','2026-09-10',null,'Accelerated aging factor overstated — real-time arm extended to close gap'),
    ('SLS-VEN-009','chamber_excursion','repeat_timepoint_testing','verification_pending',140000.00,'Rohit Sharma','2026-07-20',null,'Chamber temperature excursion invalidated 48-month pull — retest done, review pending'),
    ('SLS-MON-012','sterile_barrier_failure','requalify_packaging','in_progress',310000.00,'Priya Nair','2026-08-25',null,'Pouch seal-strength failure at 36 months — packaging requalification started'),
    ('SLS-DEF-014','pending_investigation','field_safety_notice','escalated',760000.00,'Vikram Iyer','2026-07-30',null,'Battery fade beyond validated life — FSN draft with regulatory affairs'),
    ('SLS-SYR-016','test_lab_backlog','expedite_lab_testing','closed',60000.00,'Anita Deshpande','2026-06-30','2026-06-24','Backlogged 30-month pull expedited at NABL lab and passed'),
    ('SLS-CRM-006','documentation_gap','update_stability_protocol','closed',25000.00,'Manoj Pillai','2026-05-15','2026-05-10','Protocol annex updated to capture humidity logging — no product impact')
  ) as q(sref, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.shelf_life_r3651 e
    on e.organization_id = v_org_id and e.study_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Study status distribution
create or replace function public.founder_r3651_study_status_rollup()
returns table(study_status text, studies bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.shelf_life_r3651)
  select l.study_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.shelf_life_r3651 l
  group by l.study_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_study_status_rollup() from public, anon;
grant execute on function public.founder_r3651_study_status_rollup() to authenticated;

-- 2) Study-method scorecard
create or replace function public.founder_r3651_study_method_scorecard()
returns table(
  study_method text,
  total_studies bigint,
  supporting bigint,
  on_track bigint,
  failing bigint,
  claim_gaps bigint,
  not_started bigint,
  avg_completion_pct numeric,
  supporting_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.study_method,
    count(*)::bigint,
    count(*) filter (where l.study_status = 'supporting_claim')::bigint,
    count(*) filter (where l.study_status = 'on_track')::bigint,
    count(*) filter (where l.study_status = 'timepoint_failure')::bigint,
    count(*) filter (where l.study_status = 'claim_gap')::bigint,
    count(*) filter (where l.study_status = 'not_started')::bigint,
    round(avg(100.0 * l.timepoints_completed / nullif(l.timepoints_planned,0)), 1),
    round(100.0 * count(*) filter (where l.study_status = 'supporting_claim')::numeric / nullif(count(*),0), 1)
  from public.shelf_life_r3651 l
  group by l.study_method
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_study_method_scorecard() from public, anon;
grant execute on function public.founder_r3651_study_method_scorecard() to authenticated;

-- 3) Study-method × study-status matrix
create or replace function public.founder_r3651_method_status_matrix()
returns table(study_method text, study_status text, studies bigint, total_failures bigint, avg_aging_factor numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.study_method, l.study_status, count(*)::bigint,
    coalesce(sum(l.failures_observed),0)::bigint,
    round(avg(l.aging_factor), 2)
  from public.shelf_life_r3651 l
  group by l.study_method, l.study_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_method_status_matrix() from public, anon;
grant execute on function public.founder_r3651_method_status_matrix() to authenticated;

-- 4) Monthly timepoint trend
create or replace function public.founder_r3651_monthly_timepoint_trend()
returns table(period_month date, studies bigint, planned bigint, completed bigint, failures bigint, completion_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.timepoints_planned),0)::bigint,
    coalesce(sum(l.timepoints_completed),0)::bigint,
    coalesce(sum(l.failures_observed),0)::bigint,
    round(100.0 * coalesce(sum(l.timepoints_completed),0)::numeric / nullif(sum(l.timepoints_planned),0), 1)
  from public.shelf_life_r3651 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3651_monthly_timepoint_trend() from public, anon;
grant execute on function public.founder_r3651_monthly_timepoint_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3651_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.shelf_life_capa_actions_r3651 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_capa_status_board() from public, anon;
grant execute on function public.founder_r3651_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3651_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.shelf_life_capa_actions_r3651)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.shelf_life_capa_actions_r3651 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3651_root_cause_pareto() to authenticated;

-- 7) Claim-gap digest by device
create or replace function public.founder_r3651_claim_gap_digest()
returns table(device_name text, studies bigint, claim_gaps bigint, timepoint_failures bigint, avg_gap_months numeric, worsening bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name,
    count(*)::bigint,
    count(*) filter (where l.study_status = 'claim_gap')::bigint,
    count(*) filter (where l.study_status = 'timepoint_failure')::bigint,
    round(avg((l.labeled_shelf_life_months - l.validated_shelf_life_months)::numeric) filter (where l.study_status = 'claim_gap'), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.shelf_life_r3651 l
  group by l.device_name
  order by count(*) filter (where l.study_status = 'claim_gap') desc, count(*) desc;
end;
$$;

revoke all on function public.founder_r3651_claim_gap_digest() from public, anon;
grant execute on function public.founder_r3651_claim_gap_digest() to authenticated;

-- 8) High-risk study queue (timepoint failures / claim gaps)
create or replace function public.founder_r3651_high_risk_queue()
returns table(
  device_name text,
  study_ref text,
  period_month date,
  study_method text,
  study_status text,
  labeled_months int,
  validated_months int,
  failures_observed int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.study_ref, l.period_month, l.study_method, l.study_status,
    l.labeled_shelf_life_months, l.validated_shelf_life_months,
    l.failures_observed, l.trend_dir, l.notes
  from public.shelf_life_r3651 l
  where l.study_status in ('timepoint_failure','claim_gap')
     or l.trend_dir = 'worsening'
     or l.failures_observed > 0
     or (l.validated_shelf_life_months < l.labeled_shelf_life_months
         and l.study_status not in ('not_started'))
  order by l.period_month desc, l.device_name;
end;
$$;

revoke all on function public.founder_r3651_high_risk_queue() from public, anon;
grant execute on function public.founder_r3651_high_risk_queue() to authenticated;
