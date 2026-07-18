-- Round 3196: Engineer Documentation-Quality (DSR/Photo/Checklist) Completeness Score Tracker
-- Doc-quality review log — DSR completeness × photo evidence × checklist × customer signature × parts documentation × doc score × CAPA

-- =============================================================================
-- TABLE 1: doc_quality_r3196 — per-job documentation quality reviews
-- =============================================================================
create table if not exists public.doc_quality_r3196 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  job_reference text not null,
  job_type text not null check (job_type in (
    'breakdown_repair','preventive_maintenance','installation','calibration',
    'amc_visit','warranty_repair','inspection_audit','decommissioning'
  )),
  review_date date not null,
  dsr_completeness text not null check (dsr_completeness in (
    'complete','partial','missing','illegible','template_only'
  )),
  photo_evidence text not null check (photo_evidence in (
    'both_present','before_only','after_only','missing','blurry_unusable'
  )),
  checklist_status text not null check (checklist_status in (
    'fully_filled','partially_filled','blank','wrong_template','not_attached'
  )),
  customer_signature text not null check (customer_signature in (
    'signed_stamped','signed_only','digital_signed','missing','disputed'
  )),
  parts_documentation text not null check (parts_documentation in (
    'fully_documented','partial','missing','mismatch_invoice','not_applicable'
  )),
  doc_score int not null check (doc_score >= 0 and doc_score <= 100),
  rework_required boolean not null default false,
  review_verdict text not null check (review_verdict in (
    'approved','approved_with_notes','needs_rework','rejected','escalated','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_quality_r3196 enable row level security;

create index if not exists idx_doc_quality_r3196_org on public.doc_quality_r3196(organization_id);
create index if not exists idx_doc_quality_r3196_date on public.doc_quality_r3196(review_date);
create index if not exists idx_doc_quality_r3196_verdict on public.doc_quality_r3196(review_verdict);

-- =============================================================================
-- TABLE 2: doc_quality_capa_actions_r3196 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.doc_quality_capa_actions_r3196 (
  id uuid primary key default gen_random_uuid(),
  doc_quality_id uuid not null references public.doc_quality_r3196(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dsr_missing','photo_evidence_gap','checklist_blank','signature_missing',
    'parts_mismatch','score_below_threshold','repeat_offender','template_misuse',
    'data_fabrication_suspected','late_submission'
  )),
  root_cause text not null check (root_cause in (
    'engineer_training_gap','app_upload_failure','time_pressure_backlog',
    'customer_unavailable_signature','camera_hardware_issue','process_not_defined',
    'template_confusion','connectivity_offline_loss','negligence','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','resubmit_documentation','field_revisit_photos',
    'enable_offline_capture','enforce_signature_workflow','update_checklist_template',
    'escalate_to_ops_head','issue_warning_letter','buddy_review_next_jobs','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','customer_contract_breach'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_quality_capa_actions_r3196 enable row level security;

create index if not exists idx_doc_quality_capa_r3196_log on public.doc_quality_capa_actions_r3196(doc_quality_id);
create index if not exists idx_doc_quality_capa_r3196_status on public.doc_quality_capa_actions_r3196(capa_status);

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

  -- 13 doc-quality review rows
  insert into public.doc_quality_r3196 (
    organization_id, hospital_name, engineer_name, job_reference, job_type,
    review_date, dsr_completeness, photo_evidence, checklist_status,
    customer_signature, parts_documentation, doc_score, rework_required,
    review_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.jref, q.jt,
    q.rd::date, q.dsr, q.pe, q.cl,
    q.sig, q.pd, q.score, q.rw,
    q.rv, q.nt
  from (values
    ('Apollo Hospitals Jubilee Hills Hyderabad','Ramesh Kumar','RPR-31001','breakdown_repair',
     '2026-07-10','complete','both_present','fully_filled','signed_stamped','fully_documented',96,false,
     'approved','Exemplary DSR with annotated before/after photos'),
    ('Apollo Hospitals Jubilee Hills Hyderabad','Ramesh Kumar','PM-31002','preventive_maintenance',
     '2026-07-11','complete','after_only','fully_filled','signed_only','not_applicable',82,false,
     'approved_with_notes','Before photo skipped on PM visit — coached on spot'),
    ('Fortis Bannerghatta Bengaluru','Sandeep Reddy','RPR-31003','breakdown_repair',
     '2026-07-11','partial','missing','partially_filled','missing','partial',41,true,
     'needs_rework','No photos uploaded and customer signature missing'),
    ('Fortis Bannerghatta Bengaluru','Sandeep Reddy','CAL-31004','calibration',
     '2026-07-12','complete','both_present','fully_filled','digital_signed','fully_documented',91,false,
     'approved','Calibration certificates attached to DSR'),
    ('Manipal Whitefield Bengaluru','Arjun Nair','INS-31005','installation',
     '2026-07-12','template_only','before_only','blank','missing','missing',18,true,
     'rejected','DSR is an unfilled template — full resubmission mandated'),
    ('Manipal Whitefield Bengaluru','Priya Sharma','AMC-31006','amc_visit',
     '2026-07-13','complete','both_present','fully_filled','signed_stamped','fully_documented',99,false,
     'approved','Best-in-class documentation this week'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','WTY-31007','warranty_repair',
     '2026-07-13','partial','blurry_unusable','partially_filled','signed_only','mismatch_invoice',47,true,
     'needs_rework','Parts list does not match invoice — photos blurred'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','PM-31008','preventive_maintenance',
     '2026-07-14','complete','both_present','fully_filled','signed_stamped','not_applicable',93,false,
     'approved','Clean PM record with filter-change photos'),
    ('KIMS Secunderabad','Mohammed Faisal','RPR-31009','breakdown_repair',
     '2026-07-14','missing','missing','not_attached','missing','missing',5,true,
     'escalated','No documentation uploaded 72h after job closure'),
    ('Care Hospitals Banjara Hills Hyderabad','Anita Desai','INSP-31010','inspection_audit',
     '2026-07-15','complete','both_present','fully_filled','digital_signed','fully_documented',88,false,
     'approved_with_notes','Checklist v2 used; minor annotation gaps on photos'),
    ('Yashoda Hospitals Somajiguda Hyderabad','Suresh Babu','RPR-31011','breakdown_repair',
     '2026-07-15','illegible','after_only','wrong_template','signed_only','partial',39,true,
     'needs_rework','Handwritten DSR illegible; wrong checklist template used'),
    ('St John''s Medical College Bengaluru','Priya Sharma','DEC-31012','decommissioning',
     '2026-07-16','complete','both_present','fully_filled','signed_stamped','fully_documented',95,false,
     'approved','Decommissioning certificate and disposal photos complete'),
    ('Rainbow Children''s Hospital Hyderabad','Karthik Iyer','CAL-31013','calibration',
     '2026-07-16','partial','before_only','partially_filled','disputed','partial',52,true,
     'pending_review','Customer disputes signature on report — under review')
  ) as q(hosp, eng, jref, jt, rd, dsr, pe, cl, sig, pd, score, rw, rv, nt);

  -- 6 CAPA action rows — attach via job_reference tag
  insert into public.doc_quality_capa_actions_r3196 (
    doc_quality_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.tcd::date, q.acd::date, q.cst, q.ri,
    q.cost, q.nt
  from (values
    ('RPR-31003','photo_evidence_gap','time_pressure_backlog','field_revisit_photos',
     '2026-07-20',null,'in_progress','internal_only',1800.00,'Revisit scheduled to capture equipment photos'),
    ('INS-31005','dsr_missing','engineer_training_gap','retrain_engineer',
     '2026-07-22',null,'open','customer_contract_breach',3500.00,'Installation report rework blocks invoice release'),
    ('WTY-31007','parts_mismatch','process_not_defined','update_checklist_template',
     '2026-07-25',null,'verification_pending','iso_13485_deviation',2200.00,'Parts reconciliation SOP being drafted'),
    ('RPR-31009','data_fabrication_suspected','negligence','issue_warning_letter',
     '2026-07-18',null,'escalated','nabh_finding',0.00,'Ops head reviewing engineer conduct — jobs paused'),
    ('RPR-31011','template_misuse','template_confusion','update_checklist_template',
     '2026-07-19','2026-07-17','closed','internal_only',500.00,'Correct template pushed to engineer app'),
    ('CAL-31013','signature_missing','customer_unavailable_signature','enforce_signature_workflow',
     '2026-07-14',null,'overdue','customer_contract_breach',1200.00,'Digital signature capture mandated at job close')
  ) as q(jref, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.doc_quality_r3196 e
    on e.organization_id = v_org_id and e.job_reference = q.jref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Review verdict distribution
create or replace function public.founder_r3196_verdict_rollup()
returns table(review_verdict text, reviews bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_quality_r3196)
  select d.review_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.doc_quality_r3196 d
  group by d.review_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3196_verdict_rollup() from public, anon;
grant execute on function public.founder_r3196_verdict_rollup() to authenticated;

-- 2) Engineer documentation scorecard
create or replace function public.founder_r3196_engineer_scorecard()
returns table(
  engineer_name text,
  total_reviews bigint,
  approved bigint,
  needs_rework bigint,
  rejected bigint,
  rework_flagged bigint,
  avg_doc_score numeric,
  approval_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.engineer_name,
    count(*)::bigint,
    count(*) filter (where d.review_verdict in ('approved','approved_with_notes'))::bigint,
    count(*) filter (where d.review_verdict = 'needs_rework')::bigint,
    count(*) filter (where d.review_verdict = 'rejected')::bigint,
    count(*) filter (where d.rework_required)::bigint,
    round(avg(d.doc_score)::numeric, 1),
    round(100.0 * count(*) filter (where d.review_verdict in ('approved','approved_with_notes'))::numeric / nullif(count(*),0), 1)
  from public.doc_quality_r3196 d
  group by d.engineer_name
  order by round(avg(d.doc_score)::numeric, 1) desc;
end;
$$;

revoke execute on function public.founder_r3196_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3196_engineer_scorecard() to authenticated;

-- 3) Job type × DSR completeness matrix
create or replace function public.founder_r3196_job_dsr_matrix()
returns table(job_type text, dsr_completeness text, reviews bigint, rework_count bigint, avg_doc_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.job_type, d.dsr_completeness, count(*)::bigint,
    count(*) filter (where d.rework_required)::bigint,
    round(avg(d.doc_score)::numeric, 1)
  from public.doc_quality_r3196 d
  group by d.job_type, d.dsr_completeness
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3196_job_dsr_matrix() from public, anon;
grant execute on function public.founder_r3196_job_dsr_matrix() to authenticated;

-- 4) Daily doc-score trend
create or replace function public.founder_r3196_daily_trend()
returns table(review_date date, reviews bigint, avg_doc_score numeric, approved bigint, needs_rework bigint, rejected bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.review_date, count(*)::bigint,
    round(avg(d.doc_score)::numeric, 1),
    count(*) filter (where d.review_verdict in ('approved','approved_with_notes'))::bigint,
    count(*) filter (where d.review_verdict = 'needs_rework')::bigint,
    count(*) filter (where d.review_verdict = 'rejected')::bigint
  from public.doc_quality_r3196 d
  group by d.review_date
  order by d.review_date desc;
end;
$$;

revoke execute on function public.founder_r3196_daily_trend() from public, anon;
grant execute on function public.founder_r3196_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3196_capa_status_board()
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
  from public.doc_quality_capa_actions_r3196 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3196_capa_status_board() from public, anon;
grant execute on function public.founder_r3196_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3196_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_quality_capa_actions_r3196)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.doc_quality_capa_actions_r3196 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3196_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3196_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3196_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.doc_quality_capa_actions_r3196 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3196_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3196_regulatory_impact_digest() to authenticated;

-- 8) High-risk documentation queue
create or replace function public.founder_r3196_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  job_reference text,
  review_date date,
  doc_score int,
  review_verdict text,
  dsr_completeness text,
  customer_signature text,
  rework_required boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.hospital_name, d.engineer_name, d.job_reference, d.review_date,
    d.doc_score, d.review_verdict, d.dsr_completeness, d.customer_signature,
    d.rework_required, d.notes
  from public.doc_quality_r3196 d
  where d.review_verdict in ('needs_rework','rejected','escalated','pending_review')
     or d.doc_score < 60
     or d.rework_required
  order by d.doc_score asc, d.review_date desc;
end;
$$;

revoke execute on function public.founder_r3196_high_risk_queue() from public, anon;
grant execute on function public.founder_r3196_high_risk_queue() to authenticated;
