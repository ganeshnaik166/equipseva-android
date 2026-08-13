-- Round 3719: Founder Controlled-Document / SOP Version-Governance Board
-- Controlled documents (SOPs, work instructions, form templates, policies, adopted external
-- standards) — version currency, review-due dates, obsolete-copy control in the field, staff
-- training-on-revision closure. Distinct from any QMS MANAGEMENT-REVIEW MEETING board — this
-- ship tracks individual document version-control state, not committee meetings/actions.

-- =============================================================================
-- TABLE 1: doc_control_r3719 — per-document version-control state
-- =============================================================================
create table if not exists public.doc_control_r3719 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  document_ref text not null,
  owner_department text not null,
  period_month date not null,
  current_version text not null,
  last_review_date date,
  next_review_due date,
  days_overdue int,
  obsolete_copies_found int,
  staff_trained_on_revision_pct numeric,
  controlled_distribution boolean not null,
  review_overdue boolean not null,
  doc_class text not null check (doc_class in (
    'sop','work_instruction','form_template','policy','external_standard'
  )),
  control_status text not null check (control_status in (
    'current','review_due_soon','review_overdue','obsolete_in_circulation','under_revision'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_control_r3719 enable row level security;

create index if not exists idx_doc_control_r3719_org on public.doc_control_r3719(organization_id);
create index if not exists idx_doc_control_r3719_next_review on public.doc_control_r3719(next_review_due);
create index if not exists idx_doc_control_r3719_status on public.doc_control_r3719(control_status);

-- =============================================================================
-- TABLE 2: doc_control_capa_actions_r3719 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.doc_control_capa_actions_r3719 (
  id uuid primary key default gen_random_uuid(),
  doc_control_id uuid references public.doc_control_r3719(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_control_capa_actions_r3719 enable row level security;

create index if not exists idx_doc_control_capa_actions_r3719_doc on public.doc_control_capa_actions_r3719(doc_control_id);
create index if not exists idx_doc_control_capa_actions_r3719_status on public.doc_control_capa_actions_r3719(capa_status);

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

  -- 16 controlled-document rows
  insert into public.doc_control_r3719 (
    organization_id, document_ref, owner_department, period_month, current_version,
    last_review_date, next_review_due, days_overdue, obsolete_copies_found,
    staff_trained_on_revision_pct, controlled_distribution, review_overdue,
    doc_class, control_status, trend_dir, notes
  )
  select v_org_id, q.dref, q.dept, q.pmonth::date, q.ver,
    q.lrd::date, q.nrd::date, q.dov, q.ocf,
    q.stp::numeric, q.cdist, q.rov,
    q.dcls, q.cstat, q.trend, q.nt
  from (values
    ('SOP-QMS-001','Quality Assurance','2026-07-01','v4.2',
     '2026-01-15','2027-01-15',0,0,98.0,true,false,
     'sop','current','stable',
     'Corrective action SOP reviewed on schedule; distribution controlled via QMS portal.'),
    ('SOP-BIO-014','Biomedical Service','2026-07-01','v2.1',
     '2025-08-05','2026-08-05',3,2,86.0,true,true,
     'sop','review_overdue','worsening',
     'Ventilator PM SOP review lapsed by 3 days; two obsolete field copies found at branch stores.'),
    ('WI-FLD-022','Field Engineering','2026-07-01','v1.5',
     '2026-06-01','2026-12-01',0,0,91.0,true,false,
     'work_instruction','current','stable',
     'Compressor commissioning work instruction current; training refresher completed.'),
    ('WI-CAL-009','Calibration Lab','2026-07-01','v3.0',
     '2026-05-20','2026-07-20',12,1,72.0,true,true,
     'work_instruction','review_overdue','worsening',
     'Torque-wrench calibration WI overdue for review by 12 days; one obsolete copy on bench.'),
    ('FRM-QC-033','Quality Control','2026-07-01','v1.2',
     '2026-06-10','2026-09-10',0,0,95.0,true,false,
     'form_template','current','improving',
     'Incoming inspection form template revised for imaging-parts checklist; rollout complete.'),
    ('FRM-HR-007','Human Resources','2026-07-01','v2.0',
     '2026-04-01','2026-07-01',30,3,58.0,false,true,
     'form_template','obsolete_in_circulation','worsening',
     'Onboarding checklist form superseded but old printed copies still circulating at branch offices.'),
    ('POL-EHS-002','EHS','2026-07-01','v5.1',
     '2026-02-14','2027-02-14',0,0,99.0,true,false,
     'policy','current','stable',
     'Workplace safety policy current; annual refresher training closed out for all staff.'),
    ('POL-INFO-011','IT & Security','2026-07-01','v3.3',
     null,'2026-08-15',0,0,40.0,true,false,
     'policy','under_revision','stable',
     'Information-security policy under revision to align with updated data-retention clause.'),
    ('STD-ISO-13485','Quality Assurance','2026-07-01','2016-Amd1',
     '2026-03-01','2027-03-01',0,0,88.0,true,false,
     'external_standard','current','stable',
     'Adopted ISO 13485 amendment tracked; gap-analysis training closed for QA team.'),
    ('STD-AERB-004','Radiology Compliance','2026-07-01','Rev.2024',
     '2025-09-01','2026-09-01',0,0,65.0,true,false,
     'external_standard','review_due_soon','stable',
     'AERB radiation-safety guideline review approaching; scheduling refresher for radiology techs.'),
    ('SOP-AMC-018','AMC Operations','2026-07-01','v2.4',
     '2026-06-15','2026-12-15',0,0,93.0,true,false,
     'sop','current','improving',
     'AMC renewal SOP updated with new escalation matrix; distribution acknowledgements collected.'),
    ('WI-DIAL-026','Dialysis Service','2026-08-01','v1.8',
     '2026-01-10','2026-07-10',22,4,54.0,true,true,
     'work_instruction','review_overdue','worsening',
     'Dialysis-machine disinfection WI badly overdue; four obsolete laminated copies pulled from wards.'),
    ('FRM-SVC-041','Field Engineering','2026-08-01','v1.0',
     '2026-07-05','2026-10-05',0,0,89.0,true,false,
     'form_template','current','stable',
     'Service-report form template rolled out on tablets; legacy paper form retired cleanly.'),
    ('POL-QMS-003','Quality Assurance','2026-08-01','v6.0',
     '2026-07-20','2027-07-20',0,0,97.0,true,false,
     'policy','current','improving',
     'Quality manual policy re-issued with revised org chart; training closure at 97%.'),
    ('SOP-CAPA-006','Quality Assurance','2026-08-01','v3.1',
     '2026-08-01',null,0,0,20.0,false,false,
     'sop','under_revision','worsening',
     'CAPA-handling SOP pulled for revision after audit finding; distribution suspended during rewrite.'),
    ('STD-CE-MDR','Regulatory Affairs','2026-08-01','2017/745',
     '2025-06-01','2026-06-01',63,1,49.0,true,true,
     'external_standard','review_overdue','worsening',
     'EU MDR adoption record badly overdue for review; one obsolete annex copy found with distributor.')
  ) as q(dref, dept, pmonth, ver, lrd, nrd, dov, ocf, stp, cdist, rov, dcls, cstat, trend, nt);

  -- CAPA seed — attach to specific documents via document_ref
  insert into public.doc_control_capa_actions_r3719 (
    doc_control_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SOP-BIO-014','Review reminder not escalated in QMS tracker','Escalate overdue review to department head automatically','in_progress',
     'QA Document Controller','2026-08-20',null,'Reminder workflow escalation rule added; awaiting sign-off from biomedical head.'),
    ('WI-CAL-009','Calibration lab supervisor on extended leave delayed review','Reassign review ownership to deputy supervisor','closed',
     'Calibration Lab Lead','2026-07-30','2026-07-28','Deputy supervisor completed review; document re-issued at v3.1.'),
    ('FRM-HR-007','Obsolete printed copies not recalled after digital rollout','Recall and destroy all printed onboarding checklists at branches','open',
     'HR Document Controller','2026-08-25',null,'Recall notice issued to all branch HR desks; destruction confirmation pending.'),
    ('WI-DIAL-026','Ward staff retained laminated copies past revision date','Physically recall laminated copies and issue new version with tamper seal','overdue',
     'Dialysis Service Manager','2026-08-05',null,'Recall visits to wards behind schedule due to service backlog; escalated to service manager.'),
    ('STD-CE-MDR','Regulatory tracker missed EU MDR annex update cycle','Rebuild regulatory review calendar with quarterly checkpoints','in_progress',
     'Regulatory Affairs Lead','2026-09-10',null,'New quarterly checkpoint calendar drafted; first checkpoint scheduled this month.'),
    ('STD-AERB-004','Refresher training for radiology techs not yet scheduled','Schedule AERB refresher training before review due date','open',
     'Radiology Compliance Officer','2026-08-28',null,'Training vendor shortlisted; session dates awaiting confirmation.'),
    ('SOP-CAPA-006','Audit finding required full rewrite of escalation clauses','Complete SOP rewrite and re-circulate for training closure','in_progress',
     'QA Document Controller','2026-09-01',null,'Draft v3.2 under internal review; training closure to follow publication.'),
    ('POL-INFO-011','Data-retention clause outdated against new regulatory guidance','Update policy clause and re-train IT and security staff','open',
     'IT & Security Lead','2026-08-30',null,'Legal review of updated clause in progress before staff re-training.')
  ) as q(dref, rc, ca, cst, own, tcd, acd, nt)
  join public.doc_control_r3719 e
    on e.organization_id = v_org_id and e.document_ref = q.dref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Control status rollup
create or replace function public.founder_r3719_control_status_rollup()
returns table(control_status text, documents bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_control_r3719)
  select l.control_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.doc_control_r3719 l
  group by l.control_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3719_control_status_rollup() from public, anon;
grant execute on function public.founder_r3719_control_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3719_department_scorecard()
returns table(
  owner_department text,
  total_documents bigint,
  current_docs bigint,
  review_due_soon bigint,
  review_overdue bigint,
  obsolete_in_circulation bigint,
  under_revision bigint,
  avg_training_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_department,
    count(*)::bigint,
    count(*) filter (where l.control_status = 'current')::bigint,
    count(*) filter (where l.control_status = 'review_due_soon')::bigint,
    count(*) filter (where l.control_status = 'review_overdue')::bigint,
    count(*) filter (where l.control_status = 'obsolete_in_circulation')::bigint,
    count(*) filter (where l.control_status = 'under_revision')::bigint,
    round(avg(l.staff_trained_on_revision_pct), 1)
  from public.doc_control_r3719 l
  group by l.owner_department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3719_department_scorecard() from public, anon;
grant execute on function public.founder_r3719_department_scorecard() to authenticated;

-- 3) Doc class x control status matrix
create or replace function public.founder_r3719_doc_class_status_matrix()
returns table(doc_class text, control_status text, documents bigint, avg_days_overdue numeric, obsolete_copies bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.doc_class, l.control_status, count(*)::bigint,
    round(avg(l.days_overdue), 1),
    coalesce(sum(l.obsolete_copies_found), 0)::bigint
  from public.doc_control_r3719 l
  group by l.doc_class, l.control_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3719_doc_class_status_matrix() from public, anon;
grant execute on function public.founder_r3719_doc_class_status_matrix() to authenticated;

-- 4) Monthly review-due trend
create or replace function public.founder_r3719_monthly_review_due_trend()
returns table(period_month date, documents bigint, review_due_soon bigint, review_overdue bigint, avg_days_overdue numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.control_status = 'review_due_soon')::bigint,
    count(*) filter (where l.control_status = 'review_overdue')::bigint,
    round(avg(l.days_overdue), 1)
  from public.doc_control_r3719 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3719_monthly_review_due_trend() from public, anon;
grant execute on function public.founder_r3719_monthly_review_due_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3719_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.doc_control_capa_actions_r3719 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3719_capa_status_board() from public, anon;
grant execute on function public.founder_r3719_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3719_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_control_capa_actions_r3719)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.doc_control_capa_actions_r3719 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3719_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3719_root_cause_pareto() to authenticated;

-- 7) Obsolete-copy digest
create or replace function public.founder_r3719_obsolete_copy_digest()
returns table(doc_class text, docs_with_obsolete_copies bigint, total_obsolete_copies bigint, avg_training_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.doc_class,
    count(*)::bigint,
    coalesce(sum(l.obsolete_copies_found), 0)::bigint,
    round(avg(l.staff_trained_on_revision_pct), 1)
  from public.doc_control_r3719 l
  where l.obsolete_copies_found > 0
  group by l.doc_class
  order by sum(l.obsolete_copies_found) desc;
end;
$$;

revoke execute on function public.founder_r3719_obsolete_copy_digest() from public, anon;
grant execute on function public.founder_r3719_obsolete_copy_digest() to authenticated;

-- 8) High-risk queue (review overdue / obsolete in circulation)
create or replace function public.founder_r3719_high_risk_queue()
returns table(
  document_ref text,
  owner_department text,
  doc_class text,
  current_version text,
  next_review_due date,
  days_overdue int,
  obsolete_copies_found int,
  control_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.document_ref, l.owner_department, l.doc_class, l.current_version,
    l.next_review_due, l.days_overdue, l.obsolete_copies_found, l.control_status, l.notes
  from public.doc_control_r3719 l
  where l.control_status in ('review_overdue','obsolete_in_circulation')
  order by l.days_overdue desc nulls last
  limit 20;
end;
$$;

revoke execute on function public.founder_r3719_high_risk_queue() from public, anon;
grant execute on function public.founder_r3719_high_risk_queue() to authenticated;
