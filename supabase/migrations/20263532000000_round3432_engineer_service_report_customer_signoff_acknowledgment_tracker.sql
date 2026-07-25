-- Round 3432: Engineer Service-Report / Job-Card Customer Sign-off & Acknowledgment Tracker
-- Field-engineer service-report / job-card customer sign-off tracker — report status ×
-- engineer scorecard × service-type/status matrix × monthly sign-off trend × sign-off lag ×
-- dispute impact × CAPA closure across NABH/AMC customer surfaces.

-- =============================================================================
-- TABLE 1: svc_report_signoff_r3432
-- =============================================================================
create table if not exists public.svc_report_signoff_r3432 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  report_number text not null,
  hospital_name text not null,
  equipment_type text not null,
  service_type text not null check (service_type in (
    'breakdown','preventive','installation','calibration','amc_visit'
  )),
  report_status text not null check (report_status in (
    'draft','submitted','customer_signed','disputed','rejected'
  )),
  signoff_method text not null check (signoff_method in (
    'digital_otp','physical_signature','email_ack','pending'
  )),
  visit_date date not null,
  signoff_date date,
  signoff_lag_hours int,
  customer_rating int,
  followup_required boolean not null,
  disputed boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.svc_report_signoff_r3432 enable row level security;

create index if not exists idx_esr_signoff_r3432_org on public.svc_report_signoff_r3432(organization_id);
create index if not exists idx_esr_signoff_r3432_visit on public.svc_report_signoff_r3432(visit_date);
create index if not exists idx_esr_signoff_r3432_status on public.svc_report_signoff_r3432(report_status);

-- =============================================================================
-- TABLE 2: svc_report_signoff_capa_actions_r3432
-- =============================================================================
create table if not exists public.svc_report_signoff_capa_actions_r3432 (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.svc_report_signoff_r3432(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'signoff_pending_aging','customer_dispute','report_rejected','missing_signature',
    'incomplete_job_card','low_customer_rating','signoff_lag_excessive',
    'wrong_report_details','amc_visit_unacknowledged','installation_not_accepted'
  )),
  root_cause text not null check (root_cause in (
    'engineer_delay_submission','customer_unavailable','documentation_incomplete',
    'workmanship_dispute','billing_disagreement','otp_delivery_failure',
    'wrong_contact_details','pending_investigation','spare_part_pending','coordinator_followup_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'resend_digital_otp','schedule_revisit','escalate_to_manager','correct_report_details',
    'obtain_physical_signature','retrain_engineer','update_customer_contacts',
    'issue_credit_note','close_with_email_ack','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'sla_breach','revenue_at_risk','none','internal_only','customer_escalation','amc_renewal_risk'
  )),
  impact_amount_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.svc_report_signoff_capa_actions_r3432 enable row level security;

create index if not exists idx_esr_signoff_capa_r3432_report on public.svc_report_signoff_capa_actions_r3432(report_id);
create index if not exists idx_esr_signoff_capa_r3432_status on public.svc_report_signoff_capa_actions_r3432(capa_status);

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

  -- 16 service-report rows
  insert into public.svc_report_signoff_r3432 (
    organization_id, engineer_name, report_number, hospital_name, equipment_type,
    service_type, report_status, signoff_method, visit_date, signoff_date,
    signoff_lag_hours, customer_rating, followup_required, disputed, notes
  )
  select v_org_id, q.engnm, q.rptno, q.hosp, q.eqt,
    q.svct, q.rst, q.som, q.vdt::date, q.sdt::date,
    q.lag, q.rating, q.fup, q.disp, q.nt
  from (values
    ('Rajesh Kumar','SR-2026-3301','Apollo Chennai','ventilator','breakdown','customer_signed','digital_otp','2026-07-01','2026-07-01',5,5,false,false,'Ventilator blower replaced; OTP sign-off same day'),
    ('Rajesh Kumar','SR-2026-3302','Apollo Chennai','patient_monitor','preventive','customer_signed','digital_otp','2026-07-02','2026-07-02',3,4,false,false,'Quarterly PM completed, signed via OTP'),
    ('Priya Nair','SR-2026-3303','Fortis Gurgaon','dialysis_machine','breakdown','disputed','physical_signature','2026-07-02','2026-07-04',48,2,true,true,'Customer disputes conductivity fix — revisit scheduled'),
    ('Priya Nair','SR-2026-3304','Fortis Gurgaon','infusion_pump','calibration','customer_signed','email_ack','2026-07-03','2026-07-03',6,5,false,false,'Flow calibration passed, email acknowledgment received'),
    ('Amit Sharma','SR-2026-3305','Manipal Bengaluru','ct_scanner','amc_visit','submitted','pending','2026-07-03',null,null,null,true,false,'AMC visit report submitted — awaiting customer sign-off'),
    ('Amit Sharma','SR-2026-3306','Manipal Bengaluru','ultrasound','installation','customer_signed','physical_signature','2026-07-04','2026-07-05',24,4,false,false,'New ultrasound installed and handover signed next day'),
    ('Sneha Reddy','SR-2026-3307','AIIMS Delhi','anesthesia_machine','preventive','customer_signed','digital_otp','2026-07-04','2026-07-04',2,5,false,false,'Anesthesia workstation PM, OTP sign-off'),
    ('Sneha Reddy','SR-2026-3308','AIIMS Delhi','x_ray_unit','breakdown','rejected','pending','2026-07-05',null,null,null,true,false,'Customer rejected report — parts still pending, job incomplete'),
    ('Vikram Singh','SR-2026-3309','CMC Vellore','defibrillator','calibration','customer_signed','email_ack','2026-07-05','2026-07-06',20,4,false,false,'Energy output calibrated, email acknowledgment'),
    ('Vikram Singh','SR-2026-3310','CMC Vellore','ecg_machine','preventive','draft','pending','2026-07-06',null,null,null,false,false,'Report drafted on device, not yet submitted'),
    ('Deepa Menon','SR-2026-3311','KIMS Hyderabad','ot_light','installation','customer_signed','physical_signature','2026-06-25','2026-06-25',4,5,false,false,'OT light installed and signed on-site'),
    ('Deepa Menon','SR-2026-3312','KIMS Hyderabad','dialysis_machine','amc_visit','disputed','physical_signature','2026-06-26','2026-06-29',72,1,true,true,'Customer disputes AMC scope — RO water issue unresolved'),
    ('Rahul Gupta','SR-2026-3313','Yashoda Hyderabad','ventilator','breakdown','customer_signed','digital_otp','2026-06-27','2026-06-28',18,3,true,false,'Turbine replaced, OTP sign-off; follow-up for spare warranty'),
    ('Rahul Gupta','SR-2026-3314','Yashoda Hyderabad','syringe_pump','calibration','submitted','pending','2026-06-28',null,null,null,false,false,'Calibration report submitted — customer OTP awaited'),
    ('Kavya Iyer','SR-2026-3315','Kokilaben Mumbai','mri_scanner','amc_visit','customer_signed','email_ack','2026-06-28','2026-06-29',26,4,false,false,'MRI chiller AMC visit, email acknowledgment received'),
    ('Kavya Iyer','SR-2026-3316','Kokilaben Mumbai','patient_monitor','breakdown','disputed','physical_signature','2026-06-29','2026-07-02',68,2,true,true,'Monitor SpO2 module dispute — customer wants replacement')
  ) as q(engnm, rptno, hosp, eqt, svct, rst, som, vdt, sdt, lag, rating, fup, disp, nt);

  -- 8 CAPA rows — attach to specific reports via report_number
  insert into public.svc_report_signoff_capa_actions_r3432 (
    report_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, impact_amount_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.amt, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('SR-2026-3303','customer_dispute','workmanship_dispute','schedule_revisit','in_progress','customer_escalation',25000.00,'Priya Nair','2026-07-08',null,'Dialysis conductivity dispute — revisit booked'),
    ('SR-2026-3308','report_rejected','spare_part_pending','escalate_to_manager','open','sla_breach',40000.00,'Sneha Reddy','2026-07-10',null,'X-ray job incomplete, parts on order; report rejected'),
    ('SR-2026-3312','customer_dispute','billing_disagreement','issue_credit_note','escalated','amc_renewal_risk',85000.00,'Deepa Menon','2026-07-14',null,'AMC scope dispute, RO water — escalated, renewal at risk'),
    ('SR-2026-3316','customer_dispute','workmanship_dispute','schedule_revisit','open','revenue_at_risk',30000.00,'Kavya Iyer','2026-07-15',null,'SpO2 module dispute — replacement evaluation'),
    ('SR-2026-3305','amc_visit_unacknowledged','customer_unavailable','resend_digital_otp','verification_pending','internal_only',0.00,'Amit Sharma','2026-07-09',null,'AMC report awaiting sign-off; OTP resent'),
    ('SR-2026-3310','signoff_pending_aging','engineer_delay_submission','retrain_engineer','open','internal_only',0.00,'Vikram Singh','2026-07-11',null,'Report stuck in draft — engineer coaching on same-day submission'),
    ('SR-2026-3313','low_customer_rating','coordinator_followup_gap','correct_report_details','closed','none',5000.00,'Rahul Gupta','2026-07-12','2026-07-13','Follow-up on spare warranty closed; report corrected'),
    ('SR-2026-3314','signoff_pending_aging','otp_delivery_failure','update_customer_contacts','verification_pending','sla_breach',0.00,'Rahul Gupta','2026-07-13',null,'OTP not delivered — updated customer mobile, resending')
  ) as q(rptno, fc, rc, ca, cst, bi, amt, ownr, tcd, acd, nt)
  join public.svc_report_signoff_r3432 e
    on e.organization_id = v_org_id and e.report_number = q.rptno;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Report status distribution
create or replace function public.founder_r3432_report_status_rollup()
returns table(report_status text, reports bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.svc_report_signoff_r3432)
  select l.report_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.svc_report_signoff_r3432 l
  group by l.report_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_report_status_rollup() from public, anon;
grant execute on function public.founder_r3432_report_status_rollup() to authenticated;

-- 2) Engineer sign-off scorecard
create or replace function public.founder_r3432_engineer_scorecard()
returns table(
  engineer_name text,
  total_reports bigint,
  signed bigint,
  disputed_cnt bigint,
  rejected bigint,
  avg_customer_rating numeric,
  avg_signoff_lag_hours numeric,
  signed_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.report_status = 'customer_signed')::bigint,
    count(*) filter (where l.disputed = true)::bigint,
    count(*) filter (where l.report_status = 'rejected')::bigint,
    round(avg(l.customer_rating), 2),
    round(avg(l.signoff_lag_hours), 1),
    round(100.0 * count(*) filter (where l.report_status = 'customer_signed')::numeric / nullif(count(*),0), 1)
  from public.svc_report_signoff_r3432 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3432_engineer_scorecard() to authenticated;

-- 3) Service-type × report-status matrix
create or replace function public.founder_r3432_service_type_status_matrix()
returns table(
  service_type text,
  report_status text,
  reports bigint,
  avg_customer_rating numeric,
  avg_signoff_lag_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_type, l.report_status, count(*)::bigint,
    round(avg(l.customer_rating), 2),
    round(avg(l.signoff_lag_hours), 1)
  from public.svc_report_signoff_r3432 l
  group by l.service_type, l.report_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_service_type_status_matrix() from public, anon;
grant execute on function public.founder_r3432_service_type_status_matrix() to authenticated;

-- 4) Monthly sign-off trend
create or replace function public.founder_r3432_monthly_signoff_trend()
returns table(
  signoff_month date,
  reports bigint,
  signed bigint,
  disputed_cnt bigint,
  avg_signoff_lag_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.visit_date)::date,
    count(*)::bigint,
    count(*) filter (where l.report_status = 'customer_signed')::bigint,
    count(*) filter (where l.disputed = true)::bigint,
    round(avg(l.signoff_lag_hours), 1)
  from public.svc_report_signoff_r3432 l
  group by date_trunc('month', l.visit_date)
  order by date_trunc('month', l.visit_date) desc;
end;
$$;

revoke all on function public.founder_r3432_monthly_signoff_trend() from public, anon;
grant execute on function public.founder_r3432_monthly_signoff_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3432_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.svc_report_signoff_capa_actions_r3432 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_capa_status_board() from public, anon;
grant execute on function public.founder_r3432_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3432_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.svc_report_signoff_capa_actions_r3432)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.svc_report_signoff_capa_actions_r3432 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3432_root_cause_pareto() to authenticated;

-- 7) Sign-off lag / dispute impact digest
create or replace function public.founder_r3432_signoff_impact_digest()
returns table(
  service_type text,
  reports bigint,
  disputed_cnt bigint,
  unsigned bigint,
  avg_signoff_lag_hours numeric,
  max_signoff_lag_hours integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_type,
    count(*)::bigint,
    count(*) filter (where l.disputed = true)::bigint,
    count(*) filter (where l.signoff_date is null)::bigint,
    round(avg(l.signoff_lag_hours), 1),
    max(l.signoff_lag_hours)
  from public.svc_report_signoff_r3432 l
  group by l.service_type
  order by count(*) filter (where l.disputed = true) desc, count(*) desc;
end;
$$;

revoke all on function public.founder_r3432_signoff_impact_digest() from public, anon;
grant execute on function public.founder_r3432_signoff_impact_digest() to authenticated;

-- 8) High-risk queue (unsigned / aging / disputed)
create or replace function public.founder_r3432_high_risk_queue()
returns table(
  engineer_name text,
  report_number text,
  hospital_name text,
  service_type text,
  report_status text,
  signoff_method text,
  visit_date date,
  signoff_lag_hours integer,
  customer_rating integer,
  disputed boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.report_number, l.hospital_name, l.service_type, l.report_status,
    l.signoff_method, l.visit_date, l.signoff_lag_hours, l.customer_rating, l.disputed, l.notes
  from public.svc_report_signoff_r3432 l
  where l.report_status in ('draft','submitted','disputed','rejected')
     or l.disputed = true
     or l.signoff_method = 'pending'
     or l.signoff_date is null
     or coalesce(l.signoff_lag_hours, 0) >= 48
     or coalesce(l.customer_rating, 5) <= 2
     or l.followup_required = true
  order by l.disputed desc, l.signoff_lag_hours desc nulls last, l.visit_date desc;
end;
$$;

revoke all on function public.founder_r3432_high_risk_queue() from public, anon;
grant execute on function public.founder_r3432_high_risk_queue() to authenticated;
