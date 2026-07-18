-- Round 3212: Engineer Referral-Program Effectiveness & New-Engineer Ramp Tracker
-- Referral+ramp log — referrer × referred × bonus stage × 30/60/90-day jobs × quality × retention × ramp verdict × CAPA

-- =============================================================================
-- TABLE 1: referral_ramp_r3212 — individual referral + ramp records
-- =============================================================================
create table if not exists public.referral_ramp_r3212 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  referrer_engineer_name text not null,
  referred_engineer_name text not null,
  referral_code text not null,
  referral_date date not null,
  onboarded_at timestamptz,
  specialization text not null check (specialization in (
    'ventilators','defibrillators','patient_monitors','anesthesia_workstations',
    'ct_mri_imaging','dialysis_machines','infusion_pumps','autoclave_csd'
  )),
  referral_source text not null check (referral_source in (
    'whatsapp_link','in_app_code','field_meetup','training_batch',
    'ex_employer_network','hospital_biomedical_dept'
  )),
  bonus_stage text not null check (bonus_stage in (
    'pending_kyc','signup_verified','first_job_done','thirty_day_active',
    'ninety_day_retained','bonus_paid_full','clawback'
  )),
  onboarding_week int not null,
  jobs_first_30_days int not null,
  jobs_first_60_days int,
  jobs_first_90_days int,
  quality_score numeric(4,2),
  first_job_at timestamptz,
  retention_flag boolean not null default false,
  bonus_amount_rupees numeric(10,2),
  ramp_verdict text not null check (ramp_verdict in (
    'fast_ramp','on_track','slow_ramp','stalled','churned','star_performer','pending_first_job'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.referral_ramp_r3212 enable row level security;

create index if not exists idx_referral_ramp_r3212_org on public.referral_ramp_r3212(organization_id);
create index if not exists idx_referral_ramp_r3212_date on public.referral_ramp_r3212(referral_date);
create index if not exists idx_referral_ramp_r3212_verdict on public.referral_ramp_r3212(ramp_verdict);

-- =============================================================================
-- TABLE 2: referral_ramp_capa_actions_r3212 — CAPA & program actions
-- =============================================================================
create table if not exists public.referral_ramp_capa_actions_r3212 (
  id uuid primary key default gen_random_uuid(),
  referral_ramp_id uuid not null references public.referral_ramp_r3212(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'slow_ramp','no_first_job','quality_complaints','bonus_dispute',
    'kyc_stuck','ghosting_after_signup','duplicate_referral','territory_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_onboarding_training','low_job_supply_in_city','pricing_expectations_mismatch',
    'app_usability_gap','referrer_overselling','document_verification_delay',
    'competing_full_time_job','skill_gap_specialization','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_ramp_buddy','priority_job_routing','refresher_training','expedite_kyc',
    'adjust_bonus_milestones','territory_reassignment','deactivate_referral',
    'one_on_one_founder_call','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','payout_compliance','tds_gst_implication','kyc_aml_flag','labor_compliance'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.referral_ramp_capa_actions_r3212 enable row level security;

create index if not exists idx_referral_capa_r3212_ramp on public.referral_ramp_capa_actions_r3212(referral_ramp_id);
create index if not exists idx_referral_capa_r3212_status on public.referral_ramp_capa_actions_r3212(capa_status);

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

  -- 14 referral + ramp rows
  insert into public.referral_ramp_r3212 (
    organization_id, hospital_name, referrer_engineer_name, referred_engineer_name, referral_code,
    referral_date, onboarded_at, specialization, referral_source, bonus_stage,
    onboarding_week, jobs_first_30_days, jobs_first_60_days, jobs_first_90_days,
    quality_score, first_job_at, retention_flag, bonus_amount_rupees, ramp_verdict, notes
  )
  select v_org_id, q.hosp, q.refr, q.refd, q.code,
    q.rd::date, q.ob::timestamptz, q.spec, q.src, q.stage,
    q.wk, q.j30, q.j60, q.j90,
    q.qs, q.fj::timestamptz, q.ret, q.bonus, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','Sandeep Verma','REF-3212-001','2026-04-02','2026-04-05 10:00:00+05:30',
     'ventilators','in_app_code','ninety_day_retained',1,9,21,34,4.60,'2026-04-08 11:30:00+05:30',true,15000.00,'star_performer','Fast ramp — 9 jobs in first month, strong hospital feedback'),
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','Mohan Das','REF-3212-002','2026-05-14','2026-05-20 09:30:00+05:30',
     'patient_monitors','whatsapp_link','thirty_day_active',2,4,9,null,4.10,'2026-05-26 14:00:00+05:30',true,5000.00,'on_track','Steady ramp, mostly monitor calibration jobs'),
    ('Fortis Bannerghatta Bengaluru','Priya Nair','Arjun Shetty','REF-3212-003','2026-05-02','2026-05-04 11:00:00+05:30',
     'ct_mri_imaging','field_meetup','first_job_done',1,2,5,8,3.80,'2026-05-12 10:15:00+05:30',true,2500.00,'slow_ramp','Imaging jobs scarce in his zone — needs routing help'),
    ('Fortis Bannerghatta Bengaluru','Priya Nair','Kiran Rao','REF-3212-004','2026-06-01',null,
     'dialysis_machines','training_batch','pending_kyc',0,0,null,null,null,null,false,null,'stalled','KYC pending 3 weeks — Aadhaar name mismatch'),
    ('Manipal Whitefield Bengaluru','Suresh Babu','Vikram Joshi','REF-3212-005','2026-04-18','2026-04-21 10:30:00+05:30',
     'anesthesia_workstations','ex_employer_network','ninety_day_retained',1,7,16,26,4.45,'2026-04-24 09:00:00+05:30',true,15000.00,'fast_ramp','Ex-OEM engineer, minimal handholding needed'),
    ('Manipal Whitefield Bengaluru','Suresh Babu','Deepak Iyer','REF-3212-006','2026-05-25','2026-06-02 12:00:00+05:30',
     'infusion_pumps','in_app_code','signup_verified',3,1,null,null,2.90,'2026-06-20 16:00:00+05:30',false,null,'slow_ramp','Single job with a quality complaint — retraining planned'),
    ('AIIMS New Delhi Ansari Nagar','Anita Sharma','Rahul Mehta','REF-3212-007','2026-04-10','2026-04-12 09:00:00+05:30',
     'defibrillators','hospital_biomedical_dept','ninety_day_retained',1,8,18,29,4.70,'2026-04-15 10:00:00+05:30',true,15000.00,'star_performer','Defib AMC cluster around AIIMS keeps him fully booked'),
    ('AIIMS New Delhi Ansari Nagar','Anita Sharma','Nikhil Bansal','REF-3212-008','2026-06-08','2026-06-10 10:00:00+05:30',
     'ventilators','whatsapp_link','first_job_done',1,3,null,null,4.00,'2026-06-15 11:00:00+05:30',true,2500.00,'on_track','First month tracking to plan'),
    ('KIMS Secunderabad','Ganesh Reddy','Srinivas Rao','REF-3212-009','2026-05-06','2026-05-09 09:30:00+05:30',
     'autoclave_csd','field_meetup','clawback',2,2,2,2,2.40,'2026-05-18 15:00:00+05:30',false,-2500.00,'churned','Went dark after week 5 — bonus clawback initiated'),
    ('KIMS Secunderabad','Ganesh Reddy','Farhan Ali','REF-3212-010','2026-06-20','2026-06-24 10:00:00+05:30',
     'patient_monitors','training_batch','signup_verified',1,0,null,null,null,null,false,null,'pending_first_job','Onboarded last week — awaiting first assignment'),
    ('Care Hospitals Banjara Hills','Ravi Kumar','Lakshmi Prasad','REF-3212-011','2026-05-30','2026-06-03 11:30:00+05:30',
     'dialysis_machines','in_app_code','thirty_day_active',2,5,11,null,4.25,'2026-06-07 09:45:00+05:30',true,5000.00,'on_track','Dialysis preventive-maintenance regular'),
    ('Yashoda Somajiguda Hyderabad','Priya Nair','Imran Khan','REF-3212-012','2026-04-25','2026-04-28 09:00:00+05:30',
     'ct_mri_imaging','ex_employer_network','bonus_paid_full',1,6,14,23,4.35,'2026-05-02 10:30:00+05:30',true,20000.00,'fast_ramp','Full referral bonus paid at 90-day mark'),
    ('St John''s Bengaluru','Suresh Babu','Thomas George','REF-3212-013','2026-06-12','2026-06-16 10:00:00+05:30',
     'infusion_pumps','hospital_biomedical_dept','first_job_done',2,2,null,null,3.60,'2026-06-25 14:30:00+05:30',true,2500.00,'slow_ramp','Part-time availability limiting job intake'),
    ('Rainbow Children''s Hyderabad','Anita Sharma','Kavya Menon','REF-3212-014','2026-05-18','2026-05-22 09:30:00+05:30',
     'patient_monitors','whatsapp_link','thirty_day_active',1,5,10,null,4.50,'2026-05-25 11:00:00+05:30',true,5000.00,'on_track','NICU monitor specialist — strong hospital feedback')
  ) as q(hosp, refr, refd, code, rd, ob, spec, src, stage, wk, j30, j60, j90, qs, fj, ret, bonus, verdict, nt);

  -- CAPA seed — attach to specific referrals by referral_code
  insert into public.referral_ramp_capa_actions_r3212 (
    referral_ramp_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('REF-3212-004','kyc_stuck','document_verification_delay','expedite_kyc','2026-07-20',null,'in_progress','kyc_aml_flag',0.00,'Manual verification escalated to KYC vendor'),
    ('REF-3212-006','quality_complaints','skill_gap_specialization','refresher_training','2026-07-25',null,'open','internal_only',3500.00,'Infusion-pump servicing refresher batch scheduled'),
    ('REF-3212-009','ghosting_after_signup','competing_full_time_job','deactivate_referral','2026-06-30','2026-06-28','closed','payout_compliance',2500.00,'Clawback recovered against pending payout'),
    ('REF-3212-003','slow_ramp','low_job_supply_in_city','priority_job_routing','2026-07-15',null,'verification_pending','none',0.00,'Imaging jobs pinned to top of his feed for 2 weeks'),
    ('REF-3212-010','no_first_job','low_job_supply_in_city','assign_ramp_buddy','2026-07-10',null,'overdue','internal_only',1500.00,'Buddy assignment missed SLA — escalate to city lead'),
    ('REF-3212-013','slow_ramp','pricing_expectations_mismatch','one_on_one_founder_call','2026-07-22',null,'escalated','labor_compliance',0.00,'Wants higher payout floor — founder call booked')
  ) as q(code_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.referral_ramp_r3212 e
    on e.organization_id = v_org_id and e.referral_code = q.code_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Ramp verdict distribution
create or replace function public.founder_r3212_ramp_verdict_rollup()
returns table(ramp_verdict text, referrals bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.referral_ramp_r3212)
  select r.ramp_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.referral_ramp_r3212 r
  group by r.ramp_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_ramp_verdict_rollup() from public, anon;
grant execute on function public.founder_r3212_ramp_verdict_rollup() to authenticated;

-- 2) Referrer-level scorecard
create or replace function public.founder_r3212_referrer_scorecard()
returns table(
  referrer_engineer_name text,
  total_referrals bigint,
  retained bigint,
  churned bigint,
  avg_jobs_30d numeric,
  avg_quality_score numeric,
  total_bonus_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.referrer_engineer_name,
    count(*)::bigint,
    count(*) filter (where r.retention_flag)::bigint,
    count(*) filter (where r.ramp_verdict = 'churned')::bigint,
    round(avg(r.jobs_first_30_days)::numeric, 1),
    round(avg(r.quality_score), 2),
    coalesce(sum(r.bonus_amount_rupees),0)::numeric
  from public.referral_ramp_r3212 r
  group by r.referrer_engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_referrer_scorecard() from public, anon;
grant execute on function public.founder_r3212_referrer_scorecard() to authenticated;

-- 3) Referral source × specialization matrix
create or replace function public.founder_r3212_source_specialization_matrix()
returns table(referral_source text, specialization text, referrals bigint, retained bigint, avg_jobs_90d numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.referral_source, r.specialization, count(*)::bigint,
    count(*) filter (where r.retention_flag)::bigint,
    round(avg(r.jobs_first_90_days)::numeric, 1)
  from public.referral_ramp_r3212 r
  group by r.referral_source, r.specialization
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_source_specialization_matrix() from public, anon;
grant execute on function public.founder_r3212_source_specialization_matrix() to authenticated;

-- 4) Referral daily trend
create or replace function public.founder_r3212_referral_daily_trend()
returns table(referral_date date, referrals bigint, onboarded bigint, retained bigint, avg_quality numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.referral_date,
    count(*)::bigint,
    count(*) filter (where r.onboarded_at is not null)::bigint,
    count(*) filter (where r.retention_flag)::bigint,
    round(avg(r.quality_score), 2)
  from public.referral_ramp_r3212 r
  group by r.referral_date
  order by r.referral_date desc;
end;
$$;

revoke execute on function public.founder_r3212_referral_daily_trend() from public, anon;
grant execute on function public.founder_r3212_referral_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3212_capa_status_board()
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
  from public.referral_ramp_capa_actions_r3212 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_capa_status_board() from public, anon;
grant execute on function public.founder_r3212_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3212_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.referral_ramp_capa_actions_r3212)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.referral_ramp_capa_actions_r3212 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3212_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3212_regulatory_impact_digest()
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
  from public.referral_ramp_capa_actions_r3212 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3212_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3212_regulatory_impact_digest() to authenticated;

-- 8) Stalled-ramp priority queue (referrals needing intervention)
create or replace function public.founder_r3212_stalled_ramp_queue()
returns table(
  hospital_name text,
  referrer_engineer_name text,
  referred_engineer_name text,
  referral_code text,
  referral_date date,
  bonus_stage text,
  jobs_first_30_days int,
  quality_score numeric,
  ramp_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.hospital_name, r.referrer_engineer_name, r.referred_engineer_name, r.referral_code,
    r.referral_date, r.bonus_stage, r.jobs_first_30_days, r.quality_score, r.ramp_verdict, r.notes
  from public.referral_ramp_r3212 r
  where r.ramp_verdict in ('slow_ramp','stalled','churned','pending_first_job')
     or r.bonus_stage in ('pending_kyc','clawback')
     or r.quality_score < 3.5
  order by r.referral_date desc, r.hospital_name;
end;
$$;

revoke execute on function public.founder_r3212_stalled_ramp_queue() from public, anon;
grant execute on function public.founder_r3212_stalled_ramp_queue() to authenticated;
