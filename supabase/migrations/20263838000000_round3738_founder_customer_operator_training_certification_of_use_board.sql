-- Round 3738: Founder Customer Operator Training / Certification-of-Use Board
-- Operator training-completion & certification-of-use for HIGH-RISK equipment classes
-- (ventilators, defibrillators, radiotherapy) at customer hospitals — training delivered,
-- operators certified vs required, re-certification due, uncertified-use incidents.

-- =============================================================================
-- TABLE 1: user_cert_r3738 — training/certification-of-use facts
-- =============================================================================
create table if not exists public.user_cert_r3738 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  equipment_class text not null,
  period_month date not null,
  operators_required int not null,
  operators_certified int not null,
  certification_pct numeric,
  training_sessions_delivered int,
  recert_due_count int,
  uncertified_use_incidents int,
  avg_days_to_certify numeric,
  competency_score numeric,
  training_mode text,
  risk_class text not null check (risk_class in (
    'life_support','radiation_emitting','surgical_powered','diagnostic_imaging','general_low_risk'
  )),
  cert_status text not null check (cert_status in (
    'fully_certified','partial_gap','recert_due','uncertified_use_found','training_scheduled'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.user_cert_r3738 enable row level security;

create index if not exists idx_user_cert_r3738_org on public.user_cert_r3738(organization_id);
create index if not exists idx_user_cert_r3738_month on public.user_cert_r3738(period_month);
create index if not exists idx_user_cert_r3738_status on public.user_cert_r3738(cert_status);

-- =============================================================================
-- TABLE 2: user_cert_capa_actions_r3738 — CAPA for certification gaps
-- =============================================================================
create table if not exists public.user_cert_capa_actions_r3738 (
  id uuid primary key default gen_random_uuid(),
  user_cert_id uuid references public.user_cert_r3738(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.user_cert_capa_actions_r3738 enable row level security;

create index if not exists idx_user_cert_capa_r3738_cert on public.user_cert_capa_actions_r3738(user_cert_id);
create index if not exists idx_user_cert_capa_r3738_status on public.user_cert_capa_actions_r3738(capa_status);

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

  -- 16 certification rows
  insert into public.user_cert_r3738 (
    organization_id, hospital_name, equipment_class, period_month, operators_required,
    operators_certified, certification_pct, training_sessions_delivered, recert_due_count,
    uncertified_use_incidents, avg_days_to_certify, competency_score, training_mode,
    risk_class, cert_status, trend_dir, notes
  )
  select v_org_id, q.hn, q.ec, q.pm::date, q.opr::int,
    q.opc::int, q.cp::numeric, q.tsd::int, q.rdc::int,
    q.uui::int, q.adc::numeric, q.cs::numeric, q.tm,
    q.rc, q.cst, q.td, q.nt
  from (values
    ('Sunrise Multispecialty Hospital','Ventilator','2026-07-01',18,
     18,100.0,2,0,0,6.5,92.0,'vendor_onsite','life_support','fully_certified','stable','All ICU staff certified; annual OEM refresher completed on schedule'),
    ('Sunrise Multispecialty Hospital','Defibrillator','2026-07-01',22,
     16,72.7,1,3,1,9.0,78.0,'vendor_onsite','life_support','uncertified_use_found','worsening','Uncertified nurse used defibrillator during code-blue drill; escalated to hospital admin'),
    ('Lotus Care Hospital','Radiotherapy Unit','2026-07-01',6,
     6,100.0,1,0,0,14.0,95.0,'oem_certified_program','radiation_emitting','fully_certified','stable','AERB-mandated radiation-safety recertification current for all operators'),
    ('Lotus Care Hospital','Surgical C-Arm','2026-07-01',10,
     7,70.0,2,2,0,11.0,80.0,'vendor_onsite','surgical_powered','partial_gap','stable','Two new OT technicians pending hands-on certification session'),
    ('Green Valley Medical Center','Ventilator','2026-07-01',14,
     9,64.3,1,4,0,15.0,74.0,'e_learning','life_support','partial_gap','worsening','E-learning completion lagging; hands-on skill-check backlog growing'),
    ('Green Valley Medical Center','MRI Scanner','2026-07-01',8,
     8,100.0,1,1,0,8.0,90.0,'oem_certified_program','diagnostic_imaging','recert_due','stable','All operators certified but 1 recert window opens this month'),
    ('Apex Trauma Institute','Defibrillator','2026-07-01',20,
     20,100.0,2,0,0,5.0,94.0,'vendor_onsite','life_support','fully_certified','improving','Certification program matured after last quarter remediation drive'),
    ('Apex Trauma Institute','Ventilator','2026-06-01',16,
     10,62.5,1,2,2,17.0,70.0,'e_learning','life_support','uncertified_use_found','worsening','Second uncertified-use incident this quarter; ICU roster churn cited as cause'),
    ('Riverside Speciality Clinic','Radiotherapy Unit','2026-06-01',5,
     3,60.0,0,1,0,null,68.0,'oem_certified_program','radiation_emitting','training_scheduled','stable','OEM training team scheduled onsite for first week of August'),
    ('Riverside Speciality Clinic','CT Scanner','2026-06-01',7,
     7,100.0,1,0,0,7.0,88.0,'vendor_onsite','diagnostic_imaging','fully_certified','stable','Radiology team fully certified, no gaps this cycle'),
    ('Sunshine Diagnostics','Surgical Robotic Arm','2026-06-01',4,
     2,50.0,1,1,0,20.0,60.0,'vendor_onsite','surgical_powered','partial_gap','worsening','Only 2 of 4 assigned surgeons completed robotic-arm certification track'),
    ('Sunshine Diagnostics','X-Ray Unit','2026-06-01',12,
     12,100.0,1,2,0,6.0,91.0,'e_learning','general_low_risk','recert_due','stable','Low-risk class but 2 operators due for annual recert refresher'),
    ('National Heart Institute','Defibrillator','2026-06-01',24,
     24,100.0,2,0,0,4.0,96.0,'oem_certified_program','life_support','fully_certified','improving','Cardiac-care unit maintains gold-standard certification compliance'),
    ('National Heart Institute','Radiotherapy Unit','2026-05-01',7,
     4,57.1,1,3,0,18.0,66.0,'oem_certified_program','radiation_emitting','partial_gap','worsening','Radiation-oncology hiring surge outpacing OEM certification slot availability'),
    ('City Care Hospital','Ventilator','2026-05-01',15,
     15,100.0,2,0,0,9.0,89.0,'vendor_onsite','life_support','fully_certified','stable','ICU ventilator certification steady, no incidents this quarter'),
    ('City Care Hospital','Surgical Powered Instrument Set','2026-05-01',9,
     5,55.6,1,2,1,16.0,64.0,'e_learning','surgical_powered','uncertified_use_found','worsening','OT technician used powered instrument set without completed certification; incident logged')
  ) as q(hn, ec, pm, opr, opc, cp, tsd, rdc, uui, adc, cs, tm, rc, cst, td, nt);

  -- 8 CAPA rows — attach to certification rows via hospital_name + equipment_class
  insert into public.user_cert_capa_actions_r3738 (
    user_cert_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Sunrise Multispecialty Hospital','Defibrillator','Nurse roster rotation not cross-checked against certification list before code-blue duty','Add certification-gate check to duty-roster assignment workflow','in_progress','Clinical Training Manager','2026-08-25',null,'Second uncertified-use incident traced to same roster gap since May'),
    ('Green Valley Medical Center','Ventilator','E-learning module completion not tracked against hands-on skill-check schedule','Bundle e-learning and hands-on session into single mandatory sequence','open','Clinical Training Manager','2026-08-20',null,'Backlog growing across 5 pending operators'),
    ('Apex Trauma Institute','Ventilator','High ICU staff turnover outpacing e-learning certification cadence','Switch high-turnover units to vendor-onsite rapid certification track','overdue','Hospital Partnerships Lead','2026-08-10',null,'Second uncertified-use incident this quarter flagged as escalation'),
    ('Sunshine Diagnostics','Surgical Robotic Arm','Vendor certification slots limited, only 2 of 4 surgeons trained','Negotiate additional vendor training slots for remaining surgeons','open','Hospital Partnerships Lead','2026-08-28',null,'Vendor confirmed capacity constraint during last review call'),
    ('National Heart Institute','Radiotherapy Unit','Radiation-oncology hiring surge outpacing OEM certification capacity','Request expedited OEM certification batch for new hires','in_progress','Clinical Training Manager','2026-08-22',null,'OEM proposed a dedicated batch session for September'),
    ('City Care Hospital','Surgical Powered Instrument Set','OT technician began using instrument set before certification completion confirmed','Enforce hard system lock on instrument checkout pending certification status','open','Clinical Training Manager','2026-09-05',null,'Incident found during routine OT compliance audit'),
    ('Riverside Speciality Clinic','Radiotherapy Unit','OEM onsite training team unavailable in prior scheduling window','OEM training confirmed for first week of August, tracking to close','closed','Hospital Partnerships Lead','2026-07-30','2026-07-28','Training completed ahead of AERB recertification deadline'),
    ('Lotus Care Hospital','Surgical C-Arm','New OT technician onboarding lag between hire date and certification session','Align OT technician onboarding checklist to book certification within first 2 weeks','in_progress','Clinical Training Manager','2026-08-15',null,'Low-severity gap — only 2 technicians affected this cycle')
  ) as q(hn, ec, rc, ca, cst, ownr, tcd, acd, nt)
  join public.user_cert_r3738 e
    on e.organization_id = v_org_id and e.hospital_name = q.hn and e.equipment_class = q.ec;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Certification-status distribution
create or replace function public.founder_r3738_cert_status_rollup()
returns table(cert_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.user_cert_r3738)
  select l.cert_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.user_cert_r3738 l
  group by l.cert_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3738_cert_status_rollup() from public, anon;
grant execute on function public.founder_r3738_cert_status_rollup() to authenticated;

-- 2) Equipment-class scorecard
create or replace function public.founder_r3738_equipment_class_scorecard()
returns table(
  equipment_class text,
  records bigint,
  total_operators_required bigint,
  total_operators_certified bigint,
  avg_certification_pct numeric,
  total_uncertified_use_incidents bigint,
  avg_competency_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_class,
    count(*)::bigint,
    coalesce(sum(l.operators_required),0)::bigint,
    coalesce(sum(l.operators_certified),0)::bigint,
    round(avg(l.certification_pct), 1),
    coalesce(sum(l.uncertified_use_incidents),0)::bigint,
    round(avg(l.competency_score), 1)
  from public.user_cert_r3738 l
  group by l.equipment_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3738_equipment_class_scorecard() from public, anon;
grant execute on function public.founder_r3738_equipment_class_scorecard() to authenticated;

-- 3) Risk-class × cert-status matrix
create or replace function public.founder_r3738_risk_class_status_matrix()
returns table(risk_class text, cert_status text, records bigint, avg_certification_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.risk_class, l.cert_status, count(*)::bigint,
    round(avg(l.certification_pct), 1)
  from public.user_cert_r3738 l
  group by l.risk_class, l.cert_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3738_risk_class_status_matrix() from public, anon;
grant execute on function public.founder_r3738_risk_class_status_matrix() to authenticated;

-- 4) Monthly certification trend
create or replace function public.founder_r3738_monthly_certification_trend()
returns table(
  period_month date,
  records bigint,
  total_operators_required bigint,
  total_operators_certified bigint,
  total_uncertified_use_incidents bigint,
  worsening_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.operators_required),0)::bigint,
    coalesce(sum(l.operators_certified),0)::bigint,
    coalesce(sum(l.uncertified_use_incidents),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.user_cert_r3738 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3738_monthly_certification_trend() from public, anon;
grant execute on function public.founder_r3738_monthly_certification_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3738_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.user_cert_capa_actions_r3738 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3738_capa_status_board() from public, anon;
grant execute on function public.founder_r3738_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3738_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.user_cert_capa_actions_r3738)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.user_cert_capa_actions_r3738 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3738_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3738_root_cause_pareto() to authenticated;

-- 7) Uncertified-use digest (uncertified-use incidents found, unresolved risk)
create or replace function public.founder_r3738_uncertified_use_digest()
returns table(
  hospital_name text,
  records bigint,
  total_uncertified_use_incidents bigint,
  total_recert_due bigint,
  avg_certification_pct numeric,
  avg_competency_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.uncertified_use_incidents),0)::bigint,
    coalesce(sum(l.recert_due_count),0)::bigint,
    round(avg(l.certification_pct), 1),
    round(avg(l.competency_score), 1)
  from public.user_cert_r3738 l
  where l.cert_status = 'uncertified_use_found' or l.uncertified_use_incidents > 0
  group by l.hospital_name
  order by total_uncertified_use_incidents desc;
end;
$$;

revoke all on function public.founder_r3738_uncertified_use_digest() from public, anon;
grant execute on function public.founder_r3738_uncertified_use_digest() to authenticated;

-- 8) High-risk certification queue (uncertified-use / partial-gap, worst first)
create or replace function public.founder_r3738_high_risk_queue()
returns table(
  hospital_name text,
  equipment_class text,
  risk_class text,
  period_month date,
  cert_status text,
  operators_required int,
  operators_certified int,
  uncertified_use_incidents int,
  competency_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.equipment_class, l.risk_class, l.period_month,
    l.cert_status, l.operators_required, l.operators_certified,
    l.uncertified_use_incidents, l.competency_score, l.notes
  from public.user_cert_r3738 l
  where l.cert_status in ('uncertified_use_found','partial_gap')
  order by l.uncertified_use_incidents desc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3738_high_risk_queue() from public, anon;
grant execute on function public.founder_r3738_high_risk_queue() to authenticated;
