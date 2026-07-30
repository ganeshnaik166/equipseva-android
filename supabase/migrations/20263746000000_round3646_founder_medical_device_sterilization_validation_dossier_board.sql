-- Round 3646: Medical-Device Sterilization Validation Dossier Board
-- Sterilization validation dossier — EO-residual / bioburden / SAL per device + method: method type × validation
-- status × SAL achieved × bioburden CFU × EO residual vs limit × radiation dose kGy × revalidation due × CAPA

-- =============================================================================
-- TABLE 1: steril_valid_r3646 — per-device sterilization validation dossier
-- =============================================================================
create table if not exists public.steril_valid_r3646 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  dossier_code text not null,
  device_name text not null,
  method_type text not null check (method_type in (
    'ethylene_oxide','gamma','e_beam','steam','hydrogen_peroxide'
  )),
  sterilization_method text not null,
  period_month date not null,
  sal_achieved text,
  bioburden_cfu numeric(10,2),
  eo_residual_ppm numeric(10,2),
  eo_limit_ppm numeric(10,2),
  dose_kgy numeric(8,2),
  validation_date date,
  revalidation_due date,
  cycles_validated int,
  within_limits boolean not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  validation_status text not null check (validation_status in (
    'validated','revalidation_due','out_of_spec','under_validation','expired'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.steril_valid_r3646 enable row level security;

create index if not exists idx_steril_valid_r3646_org on public.steril_valid_r3646(organization_id);
create index if not exists idx_steril_valid_r3646_month on public.steril_valid_r3646(period_month);
create index if not exists idx_steril_valid_r3646_status on public.steril_valid_r3646(validation_status);

-- =============================================================================
-- TABLE 2: steril_valid_capa_actions_r3646 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.steril_valid_capa_actions_r3646 (
  id uuid primary key default gen_random_uuid(),
  dossier_id uuid not null references public.steril_valid_r3646(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'eo_residual_exceeded','bioburden_out_of_limit','sal_not_achieved','dose_below_minimum',
    'revalidation_overdue','validation_expired','cycle_parameter_deviation','worsening_trend'
  )),
  root_cause text not null check (root_cause in (
    'aeration_time_insufficient','load_configuration_error','preconditioning_failure',
    'sterilant_concentration_low','dosimetry_error','packaging_barrier_breach',
    'bioburden_control_lapse','pending_investigation','revalidation_backlog','sterilizer_parameter_drift'
  )),
  corrective_action text not null check (corrective_action in (
    'extend_aeration','requalify_cycle','recalibrate_dosimetry','adjust_sterilant_concentration',
    'reconfigure_load','repackage_and_reprocess','retrain_sterilization_staff',
    'schedule_revalidation','quarantine_and_reject_batch','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','iso_11135_deviation','iso_11137_deviation','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.steril_valid_capa_actions_r3646 enable row level security;

create index if not exists idx_steril_valid_capa_r3646_dossier on public.steril_valid_capa_actions_r3646(dossier_id);
create index if not exists idx_steril_valid_capa_r3646_status on public.steril_valid_capa_actions_r3646(capa_status);

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

  -- 16 sterilization validation dossier rows
  insert into public.steril_valid_r3646 (
    organization_id, dossier_code, device_name, method_type, sterilization_method, period_month,
    sal_achieved, bioburden_cfu, eo_residual_ppm, eo_limit_ppm, dose_kgy,
    validation_date, revalidation_due, cycles_validated, within_limits, trend_dir, validation_status, notes
  )
  select v_org_id, q.dcode, q.dname, q.mtype, q.smeth, q.pmon::date,
    q.sal, q.bio, q.eores, q.eolim, q.dose,
    q.vdate::date, q.revdue::date, q.cyc, q.wlim, q.trend, q.vstat, q.nt
  from (values
    ('STZ-EO-001','Disposable Infusion Set','ethylene_oxide','EO 100% 600mg/L 55C','2026-07-01',
     '10^-6',8.5,1.8,4.0,null,'2026-06-15','2027-06-15',3,true,'stable','validated','EO residual 1.8 ppm well under 4 ppm limit — validated'),
    ('STZ-EO-002','Suction Catheter','ethylene_oxide','EO 100% 600mg/L 50C','2026-07-01',
     '10^-6',12.0,5.2,4.0,null,'2026-06-20','2027-06-20',2,false,'worsening','out_of_spec','EO residual 5.2 ppm exceeds 4 ppm limit — aeration insufficient'),
    ('STZ-GA-003','Guidewire PTCA','gamma','Gamma Co-60 25 kGy','2026-06-01',
     '10^-6',3.2,null,null,26.5,'2026-05-20','2027-05-20',5,true,'stable','validated','Gamma dose 26.5 kGy meets 25 kGy minimum — SAL 10^-6 achieved'),
    ('STZ-GA-004','Orthopedic Implant Screw','gamma','Gamma Co-60 25 kGy','2026-05-01',
     '10^-6',4.1,null,null,25.8,'2025-05-10','2026-05-10',4,true,'stable','revalidation_due','Annual dose audit overdue — revalidation due'),
    ('STZ-EB-005','Surgical Drape Pack','e_beam','E-beam 10 MeV 25 kGy','2026-06-01',
     '10^-6',5.5,null,null,27.0,'2026-05-25','2027-05-25',6,true,'improving','validated','E-beam dose uniform — bioburden trend improving'),
    ('STZ-ST-006','Endoscope Reprocessing Tray','steam','Steam 134C 3.5min prevac','2026-07-01',
     '10^-6',6.0,null,null,null,'2026-06-28','2027-06-28',12,true,'stable','validated','Autoclave BI + Bowie-Dick pass — validated'),
    ('STZ-ST-007','Ventilator Breathing Circuit','steam','Steam 121C 15min','2026-07-01',
     '10^-3',85.0,null,null,null,'2026-06-30','2027-06-30',8,false,'worsening','out_of_spec','BI growth positive — SAL 10^-6 not achieved, only 10^-3'),
    ('STZ-HP-008','Defibrillator Pad Applicator','hydrogen_peroxide','VH2O2 plasma standard cycle','2026-06-01',
     '10^-6',4.5,null,null,null,'2026-05-30','2027-05-30',10,true,'stable','validated','VH2O2 plasma cycle validated — lumen challenge pass'),
    ('STZ-EO-009','Dialyzer Cartridge','ethylene_oxide','EO 100% new load config','2026-07-01',
     'pending',null,null,4.0,null,null,'2027-07-01',1,false,'stable','under_validation','New load configuration — half-cycle validation in progress'),
    ('STZ-GA-010','Bone Cement Kit','gamma','Gamma Co-60 25 kGy','2026-06-01',
     '10^-3',15.0,null,null,22.5,'2026-05-18','2027-05-18',3,false,'worsening','out_of_spec','Delivered dose 22.5 kGy below 25 kGy minimum — SAL at risk'),
    ('STZ-EO-011','IV Cannula','ethylene_oxide','EO 100% 600mg/L 55C','2026-06-01',
     '10^-6',7.0,2.5,4.0,null,'2026-05-22','2027-05-22',4,true,'stable','validated','EO residual 2.5 ppm within limit — validated'),
    ('STZ-ST-012','Hemodialysis Bloodline','steam','Steam 134C 3.5min','2025-04-01',
     '10^-6',9.0,null,null,null,'2024-04-01','2025-04-01',7,false,'worsening','expired','Validation expired Apr-2025 — requalification pending'),
    ('STZ-EB-013','ECG Electrode Pack','e_beam','E-beam 10 MeV 25 kGy','2026-05-01',
     '10^-6',5.0,null,null,25.5,'2025-05-15','2026-05-15',5,true,'stable','revalidation_due','Quarterly dose map due — revalidation scheduled'),
    ('STZ-HP-014','Oxygenator Membrane','hydrogen_peroxide','VH2O2 plasma long lumen','2026-07-01',
     '10^-3',22.0,null,null,null,'2026-06-29','2027-06-29',2,false,'worsening','out_of_spec','Long-lumen challenge failed — SAL 10^-6 not met'),
    ('STZ-EO-015','Syringe Pump Line','ethylene_oxide','EO 100% 600mg/L 55C','2026-06-01',
     '10^-6',6.5,3.1,4.0,null,'2026-05-28','2027-05-28',3,true,'improving','validated','EO residual 3.1 ppm — residual trend improving'),
    ('STZ-GA-016','Central Venous Catheter','gamma','Gamma Co-60 25 kGy','2026-06-01',
     '10^-6',2.8,null,null,28.0,'2026-05-12','2027-05-12',6,true,'stable','validated','Gamma dose 28 kGy — bioburden low, SAL 10^-6 achieved')
  ) as q(dcode, dname, mtype, smeth, pmon, sal, bio, eores, eolim, dose, vdate, revdue, cyc, wlim, trend, vstat, nt);

  -- CAPA seed — attach to specific dossiers via dossier_code
  insert into public.steril_valid_capa_actions_r3646 (
    dossier_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('STZ-EO-002','eo_residual_exceeded','aeration_time_insufficient','extend_aeration','in_progress','iso_11135_deviation','2026-07-20',null,18000.00,'Aeration extended to 12h — reverify residual next lot'),
    ('STZ-ST-007','sal_not_achieved','load_configuration_error','requalify_cycle','open','patient_safety_alert','2026-07-25',null,42000.00,'BI positive — full requalification of autoclave load'),
    ('STZ-GA-010','dose_below_minimum','dosimetry_error','recalibrate_dosimetry','escalated','iso_11137_deviation','2026-07-15',null,26000.00,'Dosimetry recalibration; source-decay reassessment escalated'),
    ('STZ-HP-014','sal_not_achieved','preconditioning_failure','reconfigure_load','open','cdsco_notifiable','2026-07-28',null,35000.00,'Long-lumen challenge — reconfigure load and revalidate'),
    ('STZ-ST-012','validation_expired','revalidation_backlog','schedule_revalidation','overdue','iso_11135_deviation','2026-06-30',null,50000.00,'Requalification overdue since Apr-2025 — vendor scheduling delay'),
    ('STZ-GA-004','revalidation_overdue','revalidation_backlog','schedule_revalidation','in_progress','internal_only','2026-07-31',null,15000.00,'Annual dose audit scheduled with gamma facility'),
    ('STZ-EB-013','revalidation_overdue','sterilizer_parameter_drift','requalify_cycle','verification_pending','internal_only','2026-07-22',null,12000.00,'Dose map recheck done — verifying beam uniformity'),
    ('STZ-EO-009','cycle_parameter_deviation','sterilizer_parameter_drift','requalify_cycle','closed','internal_only','2026-07-10','2026-07-28',9000.00,'Half-cycle parameters requalified and closed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.steril_valid_r3646 e
    on e.organization_id = v_org_id and e.dossier_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Validation status distribution
create or replace function public.founder_r3646_validation_status_rollup()
returns table(validation_status text, dossiers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.steril_valid_r3646)
  select l.validation_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.steril_valid_r3646 l
  group by l.validation_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3646_validation_status_rollup() from public, anon;
grant execute on function public.founder_r3646_validation_status_rollup() to authenticated;

-- 2) Method-type scorecard
create or replace function public.founder_r3646_method_type_scorecard()
returns table(
  method_type text,
  total_dossiers bigint,
  validated bigint,
  revalidation_due bigint,
  out_of_spec bigint,
  expired bigint,
  within_limits_count bigint,
  validated_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.method_type,
    count(*)::bigint,
    count(*) filter (where l.validation_status = 'validated')::bigint,
    count(*) filter (where l.validation_status = 'revalidation_due')::bigint,
    count(*) filter (where l.validation_status = 'out_of_spec')::bigint,
    count(*) filter (where l.validation_status = 'expired')::bigint,
    count(*) filter (where l.within_limits = true)::bigint,
    round(100.0 * count(*) filter (where l.validation_status = 'validated')::numeric / nullif(count(*),0), 1)
  from public.steril_valid_r3646 l
  group by l.method_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3646_method_type_scorecard() from public, anon;
grant execute on function public.founder_r3646_method_type_scorecard() to authenticated;

-- 3) Method-type × validation-status matrix
create or replace function public.founder_r3646_method_status_matrix()
returns table(method_type text, validation_status text, dossiers bigint, avg_bioburden_cfu numeric, avg_eo_residual_ppm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.method_type, l.validation_status, count(*)::bigint,
    round(avg(l.bioburden_cfu), 2),
    round(avg(l.eo_residual_ppm), 2)
  from public.steril_valid_r3646 l
  group by l.method_type, l.validation_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3646_method_status_matrix() from public, anon;
grant execute on function public.founder_r3646_method_status_matrix() to authenticated;

-- 4) Monthly validation trend
create or replace function public.founder_r3646_monthly_validation_trend()
returns table(period_month date, dossiers bigint, validated bigint, out_of_spec bigint, expired bigint, revalidation_due bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.validation_status = 'validated')::bigint,
    count(*) filter (where l.validation_status = 'out_of_spec')::bigint,
    count(*) filter (where l.validation_status = 'expired')::bigint,
    count(*) filter (where l.validation_status = 'revalidation_due')::bigint
  from public.steril_valid_r3646 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3646_monthly_validation_trend() from public, anon;
grant execute on function public.founder_r3646_monthly_validation_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3646_capa_status_board()
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
  from public.steril_valid_capa_actions_r3646 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3646_capa_status_board() from public, anon;
grant execute on function public.founder_r3646_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3646_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.steril_valid_capa_actions_r3646)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.steril_valid_capa_actions_r3646 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3646_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3646_root_cause_pareto() to authenticated;

-- 7) Out-of-spec digest by method type
create or replace function public.founder_r3646_out_of_spec_digest()
returns table(
  method_type text,
  out_of_spec_dossiers bigint,
  eo_over_limit bigint,
  avg_eo_residual_ppm numeric,
  avg_bioburden_cfu numeric,
  worsening_trend bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.method_type,
    count(*) filter (where l.validation_status in ('out_of_spec','expired'))::bigint,
    count(*) filter (where l.eo_residual_ppm > l.eo_limit_ppm)::bigint,
    round(avg(l.eo_residual_ppm), 2),
    round(avg(l.bioburden_cfu), 2),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.steril_valid_r3646 l
  where l.within_limits = false or l.validation_status in ('out_of_spec','expired')
  group by l.method_type
  order by count(*) filter (where l.validation_status in ('out_of_spec','expired')) desc;
end;
$$;

revoke execute on function public.founder_r3646_out_of_spec_digest() from public, anon;
grant execute on function public.founder_r3646_out_of_spec_digest() to authenticated;

-- 8) High-risk queue (out_of_spec / expired / revalidation_due / worsening / residual over limit)
create or replace function public.founder_r3646_high_risk_queue()
returns table(
  device_name text,
  dossier_code text,
  method_type text,
  period_month date,
  validation_status text,
  sal_achieved text,
  eo_residual_ppm numeric,
  eo_limit_ppm numeric,
  bioburden_cfu numeric,
  revalidation_due date,
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
  select l.device_name, l.dossier_code, l.method_type, l.period_month, l.validation_status,
    l.sal_achieved, l.eo_residual_ppm, l.eo_limit_ppm, l.bioburden_cfu, l.revalidation_due, l.trend_dir, l.notes
  from public.steril_valid_r3646 l
  where l.validation_status in ('out_of_spec','expired','revalidation_due')
     or l.within_limits = false
     or l.trend_dir = 'worsening'
     or (l.eo_residual_ppm is not null and l.eo_limit_ppm is not null and l.eo_residual_ppm > l.eo_limit_ppm)
  order by l.period_month desc, l.device_name;
end;
$$;

revoke execute on function public.founder_r3646_high_risk_queue() from public, anon;
grant execute on function public.founder_r3646_high_risk_queue() to authenticated;
