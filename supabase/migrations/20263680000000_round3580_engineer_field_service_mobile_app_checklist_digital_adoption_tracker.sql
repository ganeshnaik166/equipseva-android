-- Round 3580: Engineer Field-Service Mobile-App Checklist / Digital-Adoption Tracker
-- Paperless job execution — engineer × region × feature × digital-adoption % × checklist completion × photo capture × offline sync lag × adoption status × CAPA

-- =============================================================================
-- TABLE 1: field_app_adoption_r3580 — per-engineer/feature mobile-app adoption metrics
-- =============================================================================
create table if not exists public.field_app_adoption_r3580 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_ref text not null,
  engineer_name text not null,
  region text not null,
  period_month date not null,
  feature text not null check (feature in (
    'checklist','photo','signature','parts_scan','gps','knowledge_base'
  )),
  jobs_total int not null,
  jobs_via_app int not null,
  digital_adoption_pct numeric(5,2),
  checklist_completion_pct numeric(5,2),
  photo_capture_pct numeric(5,2),
  offline_sync_lag_hrs numeric(6,2),
  adoption_status text not null check (adoption_status in (
    'champion','adopter','partial','laggard','non_user'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_app_adoption_r3580 enable row level security;

create index if not exists idx_field_app_adoption_r3580_org on public.field_app_adoption_r3580(organization_id);
create index if not exists idx_field_app_adoption_r3580_month on public.field_app_adoption_r3580(period_month);
create index if not exists idx_field_app_adoption_r3580_status on public.field_app_adoption_r3580(adoption_status);

-- =============================================================================
-- TABLE 2: field_app_adoption_capa_actions_r3580 — CAPA & digital-adoption actions
-- =============================================================================
create table if not exists public.field_app_adoption_capa_actions_r3580 (
  id uuid primary key default gen_random_uuid(),
  adoption_id uuid not null references public.field_app_adoption_r3580(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_digital_adoption','incomplete_checklist','missing_photo_capture','no_signature_capture',
    'parts_scan_not_used','gps_not_enabled','offline_sync_delay','knowledge_base_unused',
    'app_not_installed','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_training','poor_network_coverage','device_hardware_issue','app_usability_friction',
    'resistance_to_change','workload_pressure','unclear_sop','app_bug',
    'pending_investigation','no_incentive'
  )),
  corrective_action text not null check (corrective_action in (
    'on_site_training','refresher_webinar','device_upgrade','offline_mode_enablement',
    'app_update_rollout','sop_clarification','buddy_mentoring','incentive_program',
    'field_coaching','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  adoption_impact text not null check (adoption_impact in (
    'sla_risk','warranty_evidence_gap','audit_finding','customer_experience',
    'none','internal_only','data_quality_risk'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  expected_adoption_gain_pct numeric(5,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_app_adoption_capa_actions_r3580 enable row level security;

create index if not exists idx_field_app_adoption_capa_r3580_link on public.field_app_adoption_capa_actions_r3580(adoption_id);
create index if not exists idx_field_app_adoption_capa_r3580_status on public.field_app_adoption_capa_actions_r3580(capa_status);

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

  -- 16 engineer/feature adoption rows
  insert into public.field_app_adoption_r3580 (
    organization_id, entry_ref, engineer_name, region, period_month, feature,
    jobs_total, jobs_via_app, digital_adoption_pct, checklist_completion_pct,
    photo_capture_pct, offline_sync_lag_hrs, adoption_status, notes
  )
  select v_org_id, q.ref, q.eng, q.rgn, q.pm::date, q.feat,
    q.jt, q.jva, q.dap, q.ccp,
    q.pcp, q.osl, q.ast, q.nt
  from (values
    ('FA-0501','Ravi Kumar','South','2026-07-01','checklist',
     48,46,95.8,98.0,92.0,0.5,'champion','Consistent paperless job execution, full checklist adoption'),
    ('FA-0502','Anil Sharma','North','2026-07-01','photo',
     52,50,96.2,94.0,97.0,0.8,'champion','Strong photo-capture discipline on every job'),
    ('FA-0503','Priya Nair','South','2026-07-01','signature',
     40,34,85.0,88.0,80.0,1.2,'adopter','Digital signature capture improving steadily'),
    ('FA-0504','Vikram Singh','North','2026-07-01','parts_scan',
     44,30,68.2,72.0,65.0,2.5,'partial','Parts-scan skipped on rush jobs, needs coaching'),
    ('FA-0505','Deepa Iyer','West','2026-07-01','gps',
     38,20,52.6,60.0,48.0,4.0,'laggard','GPS tagging often disabled, low app usage'),
    ('FA-0506','Suresh Reddy','South','2026-07-01','knowledge_base',
     30,5,16.7,20.0,10.0,8.0,'non_user','Rarely opens app, mostly paper-based reporting'),
    ('FA-0507','Meena Joshi','West','2026-07-01','checklist',
     46,42,91.3,95.0,88.0,0.9,'champion','High checklist completion across preventive-maintenance jobs'),
    ('FA-0508','Arjun Menon','South','2026-06-01','photo',
     50,41,82.0,84.0,86.0,1.5,'adopter','Photo capture consistent, sync lag occasional'),
    ('FA-0509','Kavya Rao','East','2026-06-01','signature',
     36,22,61.1,66.0,58.0,3.2,'partial','Signature capture inconsistent, network gaps in region'),
    ('FA-0510','Manoj Verma','North','2026-06-01','parts_scan',
     42,15,35.7,40.0,30.0,6.5,'laggard','Parts-scan barely used, spare-part traceability at risk'),
    ('FA-0511','Sunita Das','East','2026-06-01','gps',
     28,3,10.7,12.0,8.0,10.0,'non_user','No app adoption, all jobs logged on paper'),
    ('FA-0512','Rahul Bose','West','2026-06-01','checklist',
     45,40,88.9,90.0,85.0,1.1,'adopter','Good checklist habit, photo capture lagging'),
    ('FA-0513','Nisha Pillai','South','2026-05-01','knowledge_base',
     34,28,82.4,86.0,79.0,1.8,'adopter','Uses knowledge base for troubleshooting frequently'),
    ('FA-0514','Gopal Krishnan','North','2026-05-01','parts_scan',
     40,26,65.0,70.0,60.0,2.8,'partial','Partial parts-scan adoption, improving month on month'),
    ('FA-0515','Lakshmi Menon','West','2026-05-01','gps',
     32,9,28.1,34.0,22.0,7.5,'laggard','Low GPS and checklist compliance, remote territory'),
    ('FA-0516','Farhan Sheikh','East','2026-05-01','photo',
     26,2,7.7,10.0,5.0,12.0,'non_user','Not using mobile app; escalated for onboarding')
  ) as q(ref, eng, rgn, pm, feat, jt, jva, dap, ccp, pcp, osl, ast, nt);

  -- CAPA seed — attach to specific adoption rows via entry_ref
  insert into public.field_app_adoption_capa_actions_r3580 (
    adoption_id, finding_category, root_cause, corrective_action,
    capa_status, adoption_impact, owner, target_closure_date, actual_closure_date,
    expected_adoption_gain_pct, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date,
    q.gain, q.nt
  from (values
    ('FA-0505','low_digital_adoption','insufficient_training','on_site_training','in_progress','sla_risk','Ops Trainer - West','2026-08-10',null,25.0,'On-site refresher scheduled for Deepa Iyer, GPS module focus'),
    ('FA-0506','app_not_installed','resistance_to_change','buddy_mentoring','open','customer_experience','Region Lead - South','2026-08-15',null,40.0,'Suresh Reddy paired with champion mentor, app reinstalled'),
    ('FA-0510','parts_scan_not_used','app_usability_friction','app_update_rollout','verification_pending','warranty_evidence_gap','Product Ops','2026-08-05',null,30.0,'Parts-scan UX friction fixed in v4.2, monitoring Manoj Verma usage'),
    ('FA-0511','no_signature_capture','poor_network_coverage','offline_mode_enablement','escalated','data_quality_risk','Field Ops - East','2026-07-30',null,35.0,'Offline mode enabled for Sunita Das, network coverage escalated'),
    ('FA-0516','app_not_installed','resistance_to_change','field_coaching','open','audit_finding','Region Lead - East','2026-08-20',null,45.0,'Farhan Sheikh onboarding escalated, field coaching planned'),
    ('FA-0515','low_digital_adoption','poor_network_coverage','device_upgrade','overdue','sla_risk','IT Asset Team','2026-07-20',null,28.0,'Rugged device with better connectivity overdue for Lakshmi Menon'),
    ('FA-0504','parts_scan_not_used','workload_pressure','field_coaching','closed','internal_only','Region Lead - North','2026-07-15','2026-07-14',20.0,'Vikram Singh coached on parts-scan; adoption improving, closed'),
    ('FA-0509','incomplete_checklist','unclear_sop','sop_clarification','in_progress','data_quality_risk','Ops Trainer - East','2026-08-08',null,22.0,'SOP clarified for Kavya Rao signature and checklist steps')
  ) as q(ref, fc, rc, ca, cst, imp, own, tcd, acd, gain, nt)
  join public.field_app_adoption_r3580 e
    on e.organization_id = v_org_id and e.entry_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adoption-status distribution
create or replace function public.founder_r3580_adoption_status_rollup()
returns table(adoption_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_app_adoption_r3580)
  select l.adoption_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.field_app_adoption_r3580 l
  group by l.adoption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_adoption_status_rollup() from public, anon;
grant execute on function public.founder_r3580_adoption_status_rollup() to authenticated;

-- 2) Region-level adoption scorecard
create or replace function public.founder_r3580_region_scorecard()
returns table(
  region text,
  total_entries bigint,
  champions bigint,
  adopters bigint,
  partial bigint,
  laggards bigint,
  non_users bigint,
  avg_adoption_pct numeric,
  avg_checklist_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.adoption_status = 'champion')::bigint,
    count(*) filter (where l.adoption_status = 'adopter')::bigint,
    count(*) filter (where l.adoption_status = 'partial')::bigint,
    count(*) filter (where l.adoption_status = 'laggard')::bigint,
    count(*) filter (where l.adoption_status = 'non_user')::bigint,
    round(avg(l.digital_adoption_pct), 1),
    round(avg(l.checklist_completion_pct), 1)
  from public.field_app_adoption_r3580 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_region_scorecard() from public, anon;
grant execute on function public.founder_r3580_region_scorecard() to authenticated;

-- 3) Feature × adoption-status matrix
create or replace function public.founder_r3580_feature_adoption_matrix()
returns table(feature text, adoption_status text, entries bigint, avg_adoption_pct numeric, avg_checklist_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.feature, l.adoption_status, count(*)::bigint,
    round(avg(l.digital_adoption_pct), 1),
    round(avg(l.checklist_completion_pct), 1)
  from public.field_app_adoption_r3580 l
  group by l.feature, l.adoption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_feature_adoption_matrix() from public, anon;
grant execute on function public.founder_r3580_feature_adoption_matrix() to authenticated;

-- 4) Monthly adoption trend
create or replace function public.founder_r3580_monthly_adoption_trend()
returns table(period_month date, entries bigint, avg_adoption_pct numeric, avg_checklist_pct numeric, avg_photo_pct numeric, laggards bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.digital_adoption_pct), 1),
    round(avg(l.checklist_completion_pct), 1),
    round(avg(l.photo_capture_pct), 1),
    count(*) filter (where l.adoption_status in ('laggard','non_user'))::bigint
  from public.field_app_adoption_r3580 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3580_monthly_adoption_trend() from public, anon;
grant execute on function public.founder_r3580_monthly_adoption_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3580_capa_status_board()
returns table(capa_status text, findings bigint, avg_gain_pct numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.expected_adoption_gain_pct)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.field_app_adoption_capa_actions_r3580 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_capa_status_board() from public, anon;
grant execute on function public.founder_r3580_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3580_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_gain_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_app_adoption_capa_actions_r3580)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.expected_adoption_gain_pct),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.field_app_adoption_capa_actions_r3580 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3580_root_cause_pareto() to authenticated;

-- 7) Adoption-impact digest
create or replace function public.founder_r3580_adoption_impact_digest()
returns table(adoption_impact text, findings bigint, open_findings bigint, total_gain_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.adoption_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.expected_adoption_gain_pct),0)::numeric
  from public.field_app_adoption_capa_actions_r3580 c
  group by c.adoption_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3580_adoption_impact_digest() from public, anon;
grant execute on function public.founder_r3580_adoption_impact_digest() to authenticated;

-- 8) High-risk adoption queue (laggard / non-user / low completion)
create or replace function public.founder_r3580_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  period_month date,
  feature text,
  adoption_status text,
  digital_adoption_pct numeric,
  checklist_completion_pct numeric,
  photo_capture_pct numeric,
  offline_sync_lag_hrs numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.period_month, l.feature, l.adoption_status,
    l.digital_adoption_pct, l.checklist_completion_pct, l.photo_capture_pct, l.offline_sync_lag_hrs, l.notes
  from public.field_app_adoption_r3580 l
  where l.adoption_status in ('partial','laggard','non_user')
     or l.digital_adoption_pct < 70
     or l.checklist_completion_pct < 75
     or l.offline_sync_lag_hrs > 4
  order by l.digital_adoption_pct asc, l.region;
end;
$$;

revoke execute on function public.founder_r3580_high_risk_queue() from public, anon;
grant execute on function public.founder_r3580_high_risk_queue() to authenticated;
