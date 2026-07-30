-- Round 3647: Medical-Device Biocompatibility (ISO 10993) Evaluation Board
-- Biocompatibility evaluation per device — contact category × contact duration × endpoint coverage (required/tested/passed)
-- × coverage % × test reports attached × evaluation/reassessment dates × biological risk score × status × trend × CAPA

-- =============================================================================
-- TABLE 1: biocompat_r3647 — per-device ISO 10993 biocompatibility evaluation
-- =============================================================================
create table if not exists public.biocompat_r3647 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  evaluation_ref text not null,
  device_name text not null,
  contact_category text not null,
  period_month date not null,
  endpoints_required int not null,
  endpoints_tested int not null,
  endpoints_passed int not null,
  coverage_pct numeric(5,2),
  test_reports_attached int,
  evaluation_date date,
  reassessment_due date,
  biological_risk_score numeric(5,2),
  contact_duration text not null check (contact_duration in (
    'limited','prolonged','permanent'
  )),
  biocompat_status text not null check (biocompat_status in (
    'compliant','testing_gap','endpoint_fail','under_evaluation','not_started'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biocompat_r3647 enable row level security;

create index if not exists idx_biocompat_r3647_org on public.biocompat_r3647(organization_id);
create index if not exists idx_biocompat_r3647_month on public.biocompat_r3647(period_month);
create index if not exists idx_biocompat_r3647_status on public.biocompat_r3647(biocompat_status);

-- =============================================================================
-- TABLE 2: biocompat_capa_actions_r3647 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.biocompat_capa_actions_r3647 (
  id uuid primary key default gen_random_uuid(),
  eval_id uuid not null references public.biocompat_r3647(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'endpoint_not_tested','cytotoxicity_fail','sensitization_fail','irritation_fail',
    'systemic_toxicity_fail','genotoxicity_fail','implantation_fail','hemocompatibility_fail',
    'test_report_missing','reassessment_overdue'
  )),
  root_cause text not null check (root_cause in (
    'material_change_unassessed','supplier_material_change','sterilization_residual','test_lab_backlog',
    'missing_chemical_characterization','insufficient_extractables_data','process_contamination',
    'documentation_gap','pending_investigation','expired_test_data'
  )),
  corrective_action text not null check (corrective_action in (
    'conduct_missing_endpoint_test','chemical_characterization_iso10993_18','toxicological_risk_assessment',
    'change_material_supplier','revalidate_sterilization','update_biological_evaluation_report',
    'attach_test_reports','requalify_device','schedule_reassessment','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'iso_10993_deviation','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biocompat_capa_actions_r3647 enable row level security;

create index if not exists idx_biocompat_capa_r3647_eval on public.biocompat_capa_actions_r3647(eval_id);
create index if not exists idx_biocompat_capa_r3647_status on public.biocompat_capa_actions_r3647(capa_status);

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

  -- 16 biocompatibility evaluation rows
  insert into public.biocompat_r3647 (
    organization_id, evaluation_ref, device_name, contact_category, period_month,
    endpoints_required, endpoints_tested, endpoints_passed, coverage_pct, test_reports_attached,
    evaluation_date, reassessment_due, biological_risk_score,
    contact_duration, biocompat_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.dev, q.cat, q.pm::date,
    q.ereq, q.etst, q.epass, q.cov, q.reps,
    q.edate::date, q.rdue::date, q.risk,
    q.dur, q.stat, q.trend, q.nt
  from (values
    ('BIO-DIAL-01','Hemodialysis blood tubing set','external_communicating','2026-07-01',
     10,10,10,100.0,10,'2026-06-20','2027-06-20',1.2,'prolonged','compliant','stable','Full ISO 10993 endpoint battery complete — BER current'),
    ('BIO-CVC-02','Central venous catheter','external_communicating','2026-07-01',
     12,12,11,91.7,11,'2026-06-18','2027-06-18',2.4,'prolonged','testing_gap','improving','Hemocompatibility complement-activation retest pending'),
    ('BIO-STENT-03','Coronary drug-eluting stent','implant','2026-06-01',
     14,14,14,100.0,14,'2026-05-15','2028-05-15',1.8,'permanent','compliant','stable','Implant permanent-contact full battery complete'),
    ('BIO-BONE-04','Orthopedic titanium bone screw','implant','2026-06-01',
     11,9,8,72.7,8,'2026-05-20','2028-05-20',3.6,'permanent','testing_gap','worsening','Genotoxicity and implantation endpoints outstanding'),
    ('BIO-ECG-05','ECG electrode gel pad','surface_device','2026-07-01',
     5,5,5,100.0,5,'2026-06-25','2027-06-25',0.5,'limited','compliant','stable','Intact-skin limited contact — cytotox/sensitization/irritation done'),
    ('BIO-WND-06','Hydrocolloid wound dressing','surface_device','2026-07-01',
     7,6,5,71.4,6,'2026-06-22','2027-06-22',2.1,'prolonged','testing_gap','stable','Breached-surface prolonged — sub-chronic toxicity data gap'),
    ('BIO-URI-07','Silicone urinary catheter','external_communicating','2026-06-01',
     9,5,3,55.6,5,'2026-05-28','2027-05-28',4.2,'prolonged','endpoint_fail','worsening','Irritation endpoint failed — extractables above limit'),
    ('BIO-ETT-08','Endotracheal tube','external_communicating','2026-06-01',
     9,9,8,88.9,9,'2026-05-30','2027-05-30',2.6,'prolonged','testing_gap','improving','Mucosal-contact resin change — cytotox retest scheduled'),
    ('BIO-SUT-09','Absorbable surgical suture','implant','2026-06-01',
     12,7,5,58.3,7,'2026-05-12','2028-05-12',3.9,'permanent','endpoint_fail','worsening','Implantation 12-week histopathology adverse — CAPA raised'),
    ('BIO-DENT-10','Titanium dental implant','implant','2026-05-01',
     13,13,13,100.0,13,'2026-04-18','2028-04-18',1.5,'permanent','compliant','stable','Permanent bone-contact full ISO 10993 battery complete'),
    ('BIO-OXY-11','Blood oxygenator membrane','external_communicating','2026-07-01',
     13,10,9,76.9,10,'2026-06-15','2027-06-15',3.1,'limited','under_evaluation','improving','Circulating-blood hemocompatibility panel under review'),
    ('BIO-NEB-12','Nebulizer face mask','surface_device','2026-07-01',
     5,5,4,80.0,5,'2026-06-24','2027-06-24',1.0,'prolonged','testing_gap','stable','Sensitization retest after supplier resin change'),
    ('BIO-HIP-13','Hip prosthesis acetabular liner','implant','2026-05-01',
     14,8,6,57.1,8,'2026-04-10','2028-04-10',4.5,'permanent','endpoint_fail','worsening','Wear-debris particulate toxicology adverse — requalify'),
    ('BIO-LENS-14','Soft contact lens','surface_device','2026-07-01',
     6,0,0,0.0,0,null,'2027-06-30',2.0,'prolonged','not_started','stable','New mucosal-contact SKU — biological evaluation not initiated'),
    ('BIO-DLZ-15','Dialyzer hollow-fiber membrane','external_communicating','2026-06-01',
     11,11,10,90.9,11,'2026-05-22','2027-05-22',2.3,'limited','compliant','improving','Blood-path limited-contact battery complete post-remediation'),
    ('BIO-IVSET-16','IV administration set','external_communicating','2026-06-01',
     8,8,8,100.0,8,'2026-05-25','2027-05-25',1.1,'limited','compliant','stable','Indirect blood-path IV set fully evaluated')
  ) as q(ref, dev, cat, pm, ereq, etst, epass, cov, reps, edate, rdue, risk, dur, stat, trend, nt);

  -- CAPA seed — attach to specific evaluations via evaluation_ref
  insert into public.biocompat_capa_actions_r3647 (
    eval_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BIO-URI-07','irritation_fail','sterilization_residual','revalidate_sterilization','in_progress','iso_10993_deviation','Dr. Meera Nair','2026-08-20',null,145000.00,'EtO residual reduction and irritation retest per ISO 10993-10'),
    ('BIO-SUT-09','implantation_fail','material_change_unassessed','toxicological_risk_assessment','escalated','patient_safety_alert','Dr. Rajesh Kumar','2026-08-15',null,320000.00,'Adverse 12-week implantation histopathology — TRA and requalification'),
    ('BIO-HIP-13','systemic_toxicity_fail','insufficient_extractables_data','chemical_characterization_iso10993_18','open','cdsco_notifiable','Anil Deshmukh','2026-09-05',null,480000.00,'Wear-debris extractables characterization per ISO 10993-18'),
    ('BIO-BONE-04','endpoint_not_tested','test_lab_backlog','conduct_missing_endpoint_test','in_progress','iso_13485_deviation','Priya Sharma','2026-08-25',null,210000.00,'Genotoxicity and implantation endpoints queued at NABL lab'),
    ('BIO-CVC-02','hemocompatibility_fail','missing_chemical_characterization','conduct_missing_endpoint_test','verification_pending','internal_only','Suresh Iyer','2026-08-18',null,95000.00,'Complement-activation SC5b-9 retest awaiting verification'),
    ('BIO-WND-06','endpoint_not_tested','test_lab_backlog','conduct_missing_endpoint_test','open','iso_10993_deviation','Kavya Menon','2026-08-28',null,72000.00,'Sub-chronic systemic toxicity data gap for breached-surface prolonged'),
    ('BIO-LENS-14','test_report_missing','documentation_gap','update_biological_evaluation_report','open','iso_13485_deviation','Vikram Rao','2026-09-10',null,60000.00,'Initiate biological evaluation plan for new mucosal-contact SKU'),
    ('BIO-DENT-10','reassessment_overdue','expired_test_data','schedule_reassessment','closed','internal_only','Anjali Gupta','2026-06-30','2026-06-28',40000.00,'Periodic reassessment completed — BER updated and closed')
  ) as q(ref, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.biocompat_r3647 e
    on e.organization_id = v_org_id and e.evaluation_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Biocompatibility status distribution
create or replace function public.founder_r3647_biocompat_status_rollup()
returns table(biocompat_status text, evaluations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biocompat_r3647)
  select l.biocompat_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.biocompat_r3647 l
  group by l.biocompat_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3647_biocompat_status_rollup() from public, anon;
grant execute on function public.founder_r3647_biocompat_status_rollup() to authenticated;

-- 2) Contact-category scorecard
create or replace function public.founder_r3647_contact_category_scorecard()
returns table(
  contact_category text,
  total_evaluations bigint,
  compliant bigint,
  testing_gap bigint,
  endpoint_fail bigint,
  under_evaluation bigint,
  not_started bigint,
  avg_coverage_pct numeric,
  avg_risk_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contact_category,
    count(*)::bigint,
    count(*) filter (where l.biocompat_status = 'compliant')::bigint,
    count(*) filter (where l.biocompat_status = 'testing_gap')::bigint,
    count(*) filter (where l.biocompat_status = 'endpoint_fail')::bigint,
    count(*) filter (where l.biocompat_status = 'under_evaluation')::bigint,
    count(*) filter (where l.biocompat_status = 'not_started')::bigint,
    round(avg(l.coverage_pct), 1),
    round(avg(l.biological_risk_score), 2)
  from public.biocompat_r3647 l
  group by l.contact_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3647_contact_category_scorecard() from public, anon;
grant execute on function public.founder_r3647_contact_category_scorecard() to authenticated;

-- 3) Contact-duration × biocompat-status matrix
create or replace function public.founder_r3647_duration_status_matrix()
returns table(contact_duration text, biocompat_status text, evaluations bigint, avg_coverage_pct numeric, avg_risk_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contact_duration, l.biocompat_status, count(*)::bigint,
    round(avg(l.coverage_pct), 1),
    round(avg(l.biological_risk_score), 2)
  from public.biocompat_r3647 l
  group by l.contact_duration, l.biocompat_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3647_duration_status_matrix() from public, anon;
grant execute on function public.founder_r3647_duration_status_matrix() to authenticated;

-- 4) Monthly evaluation trend
create or replace function public.founder_r3647_monthly_evaluation_trend()
returns table(period_month date, evaluations bigint, compliant bigint, testing_gap bigint, endpoint_fail bigint, avg_coverage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.biocompat_status = 'compliant')::bigint,
    count(*) filter (where l.biocompat_status = 'testing_gap')::bigint,
    count(*) filter (where l.biocompat_status = 'endpoint_fail')::bigint,
    round(avg(l.coverage_pct), 1)
  from public.biocompat_r3647 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3647_monthly_evaluation_trend() from public, anon;
grant execute on function public.founder_r3647_monthly_evaluation_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3647_capa_status_board()
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
  from public.biocompat_capa_actions_r3647 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3647_capa_status_board() from public, anon;
grant execute on function public.founder_r3647_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3647_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biocompat_capa_actions_r3647)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.biocompat_capa_actions_r3647 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3647_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3647_root_cause_pareto() to authenticated;

-- 7) Endpoint-gap digest by contact category
create or replace function public.founder_r3647_endpoint_gap_digest()
returns table(
  contact_category text,
  devices bigint,
  endpoints_required bigint,
  endpoints_tested bigint,
  endpoints_passed bigint,
  endpoint_gap bigint,
  avg_coverage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contact_category,
    count(*)::bigint,
    coalesce(sum(l.endpoints_required),0)::bigint,
    coalesce(sum(l.endpoints_tested),0)::bigint,
    coalesce(sum(l.endpoints_passed),0)::bigint,
    coalesce(sum(l.endpoints_required - l.endpoints_tested),0)::bigint,
    round(avg(l.coverage_pct), 1)
  from public.biocompat_r3647 l
  group by l.contact_category
  order by coalesce(sum(l.endpoints_required - l.endpoints_tested),0) desc;
end;
$$;

revoke execute on function public.founder_r3647_endpoint_gap_digest() from public, anon;
grant execute on function public.founder_r3647_endpoint_gap_digest() to authenticated;

-- 8) High-risk queue (endpoint_fail / testing_gap and other concerns)
create or replace function public.founder_r3647_high_risk_queue()
returns table(
  device_name text,
  evaluation_ref text,
  contact_category text,
  contact_duration text,
  period_month date,
  biocompat_status text,
  coverage_pct numeric,
  endpoints_required int,
  endpoints_tested int,
  endpoints_passed int,
  biological_risk_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.evaluation_ref, l.contact_category, l.contact_duration, l.period_month,
    l.biocompat_status, l.coverage_pct, l.endpoints_required, l.endpoints_tested, l.endpoints_passed,
    l.biological_risk_score, l.notes
  from public.biocompat_r3647 l
  where l.biocompat_status in ('endpoint_fail','testing_gap','not_started','under_evaluation')
     or l.coverage_pct < 80
     or l.trend_dir = 'worsening'
     or l.biological_risk_score >= 3.5
  order by l.biological_risk_score desc nulls last, l.coverage_pct asc nulls first;
end;
$$;

revoke execute on function public.founder_r3647_high_risk_queue() from public, anon;
grant execute on function public.founder_r3647_high_risk_queue() to authenticated;
