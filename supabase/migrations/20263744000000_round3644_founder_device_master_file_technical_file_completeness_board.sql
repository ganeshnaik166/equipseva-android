-- Round 3644: Device Master File / Technical File Completeness Board
-- MDF/Technical File (design dossier) section-completeness per device — device × class × file section ×
-- sections total/complete/outdated × completeness % × review cadence × change controls × version × file status
-- × trend × CAPA closure. Founder-gated regulatory-compliance board (CDSCO / MDR 2017 / ISO 13485 / ISO 14971).

-- =============================================================================
-- TABLE 1: device_mdf_r3644 — per-device technical-file section completeness
-- =============================================================================
create table if not exists public.device_mdf_r3644 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  file_ref text not null,
  device_name text not null,
  device_class text not null check (device_class in (
    'class_a','class_b','class_c','class_d'
  )),
  period_month date not null,
  file_section text not null check (file_section in (
    'design_inputs','risk_management','vv_testing','sterilization','clinical','labeling','post_market'
  )),
  sections_total int not null,
  sections_complete int not null,
  sections_outdated int not null,
  completeness_pct numeric(5,2),
  last_review_date date,
  next_review_due date,
  change_controls_open int not null,
  version_no text not null,
  file_status text not null check (file_status in (
    'current','minor_update_due','major_gap','outdated','not_started'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_mdf_r3644 enable row level security;

create index if not exists idx_device_mdf_r3644_org on public.device_mdf_r3644(organization_id);
create index if not exists idx_device_mdf_r3644_month on public.device_mdf_r3644(period_month);
create index if not exists idx_device_mdf_r3644_status on public.device_mdf_r3644(file_status);

-- =============================================================================
-- TABLE 2: device_mdf_capa_actions_r3644 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.device_mdf_capa_actions_r3644 (
  id uuid primary key default gen_random_uuid(),
  mdf_id uuid not null references public.device_mdf_r3644(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_design_inputs','outdated_risk_analysis','incomplete_vv_testing','sterilization_validation_expired',
    'clinical_evidence_gap','labeling_noncompliance','post_market_data_gap','change_control_backlog','file_not_started'
  )),
  root_cause text not null check (root_cause in (
    'design_change_not_documented','standard_updated','test_report_pending','supplier_data_pending',
    'regulatory_requirement_changed','resource_constraint','process_gap','legacy_file_not_migrated','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'author_design_inputs','update_risk_file','complete_vv_testing','revalidate_sterilization',
    'update_clinical_evaluation','revise_labeling','update_pms_report','close_change_controls','migrate_legacy_file','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','mdr_2017_deviation','iso_13485_deviation','iso_14971_gap','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.device_mdf_capa_actions_r3644 enable row level security;

create index if not exists idx_device_mdf_capa_r3644_mdf on public.device_mdf_capa_actions_r3644(mdf_id);
create index if not exists idx_device_mdf_capa_r3644_status on public.device_mdf_capa_actions_r3644(capa_status);

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

  -- 16 technical-file section rows
  insert into public.device_mdf_r3644 (
    organization_id, file_ref, device_name, device_class, period_month, file_section,
    sections_total, sections_complete, sections_outdated, completeness_pct,
    last_review_date, next_review_due, change_controls_open, version_no, file_status, trend_dir, notes
  )
  select v_org_id, q.fref, q.dname, q.dclass, q.pmonth::date, q.fsec,
    q.stot, q.scomp, q.sout, q.cpct,
    q.lrev::date, q.ndue::date, q.cco, q.vno, q.fstat, q.tdir, q.nt
  from (values
    ('MDF-0001','ICU Ventilator V500','class_c','2026-07-01','design_inputs',
     48,48,0,100.0,'2026-06-05','2026-12-05',0,'v4.1','current','stable','Design input requirements complete and traced to VV'),
    ('MDF-0002','ICU Ventilator V500','class_c','2026-07-01','risk_management',
     36,28,5,77.8,'2026-04-20','2026-08-20',3,'v4.1','minor_update_due','worsening','ISO 14971 risk file pending update after 3 field complaints'),
    ('MDF-0003','Infusion Pump IP-200','class_c','2026-07-01','vv_testing',
     54,39,6,72.2,'2026-03-15','2026-07-15',4,'v2.7','major_gap','worsening','Verification protocols for occlusion alarm incomplete'),
    ('MDF-0004','Patient Monitor PM-90','class_b','2026-07-01','labeling',
     22,22,0,100.0,'2026-06-18','2027-06-18',0,'v5.0','current','stable','IFU and labeling compliant with MDR 2017 schedule'),
    ('MDF-0005','Hemodialysis Machine HD-4','class_c','2026-06-01','sterilization',
     18,11,3,61.1,'2026-01-10','2026-07-10',2,'v1.9','outdated','worsening','Sterilization validation report expired; fluid-path revalidation due'),
    ('MDF-0006','Defibrillator DF-Bi','class_c','2026-06-01','clinical',
     26,17,4,65.4,'2026-02-22','2026-08-22',2,'v3.0','major_gap','stable','Clinical evaluation report lacks post-2024 literature review'),
    ('MDF-0007','C-Arm Imaging CX-9','class_c','2026-06-01','design_inputs',
     40,36,2,90.0,'2026-05-28','2026-11-28',1,'v2.2','minor_update_due','improving','Design inputs updated for new detector; awaiting sign-off'),
    ('MDF-0008','Syringe Pump SP-50','class_c','2026-07-01','post_market',
     20,20,0,100.0,'2026-06-30','2026-12-30',0,'v4.4','current','improving','PMS and PSUR data current, no open trends'),
    ('MDF-0009','Anesthesia Workstation AW-7','class_c','2026-07-01','vv_testing',
     60,45,7,75.0,'2026-04-05','2026-08-05',3,'v1.5','minor_update_due','stable','VV testing gaps in vaporizer accuracy tests'),
    ('MDF-0010','ECG Machine EC-12','class_b','2026-06-01','labeling',
     16,9,3,56.3,'2025-12-15','2026-06-15',1,'v2.0','outdated','worsening','Labeling not updated to current symbol standard EN ISO 15223'),
    ('MDF-0011','Ultrasound Scanner US-3','class_b','2026-07-01','clinical',
     28,26,1,92.9,'2026-06-12','2027-06-12',0,'v6.1','current','stable','Clinical evidence dossier complete'),
    ('MDF-0012','Electrosurgical Unit ESU-4','class_c','2026-05-01','risk_management',
     34,19,6,55.9,'2025-11-30','2026-05-30',4,'v1.2','major_gap','worsening','Risk file incomplete; HF leakage hazards not fully assessed'),
    ('MDF-0013','Phototherapy Unit PT-2','class_b','2026-07-01','design_inputs',
     24,23,0,95.8,'2026-06-20','2027-06-20',0,'v3.3','current','stable','Design inputs complete for LED variant'),
    ('MDF-0014','Infant Warmer IW-5','class_b','2026-06-01','sterilization',
     14,0,0,0.0,'2026-06-01','2026-09-01',1,'v0.9','not_started','stable','Sterilization section not started for reusable probe accessory'),
    ('MDF-0015','Blood Pressure Monitor BP-1','class_a','2026-07-01','post_market',
     12,12,0,100.0,'2026-06-25','2027-06-25',0,'v2.5','current','stable','Class A device, PMS file complete'),
    ('MDF-0016','Nebulizer NB-3','class_a','2026-06-01','vv_testing',
     15,10,2,66.7,'2026-03-01','2026-07-01',1,'v1.1','major_gap','worsening','VV testing of aerosol output rate incomplete')
  ) as q(fref, dname, dclass, pmonth, fsec, stot, scomp, sout, cpct, lrev, ndue, cco, vno, fstat, tdir, nt);

  -- CAPA seed — attach to specific files via file_ref
  insert into public.device_mdf_capa_actions_r3644 (
    mdf_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MDF-0002','outdated_risk_analysis','standard_updated','update_risk_file','in_progress','iso_14971_gap','2026-08-15',null,45000.00,'Risk file refresh after field complaints; verification pending'),
    ('MDF-0003','incomplete_vv_testing','test_report_pending','complete_vv_testing','open','mdr_2017_deviation','2026-08-10',null,120000.00,'Occlusion alarm VV protocols to be executed by test lab'),
    ('MDF-0005','sterilization_validation_expired','regulatory_requirement_changed','revalidate_sterilization','escalated','cdsco_notifiable','2026-07-25',null,210000.00,'Sterilization revalidation overdue; CDSCO notifiable if not closed'),
    ('MDF-0006','clinical_evidence_gap','resource_constraint','update_clinical_evaluation','open','mdr_2017_deviation','2026-09-01',null,85000.00,'CER literature review update outsourced to consultant'),
    ('MDF-0010','labeling_noncompliance','standard_updated','revise_labeling','verification_pending','iso_13485_deviation','2026-07-20',null,18000.00,'Labeling updated to EN ISO 15223; awaiting DHF sign-off'),
    ('MDF-0012','outdated_risk_analysis','process_gap','update_risk_file','overdue','iso_14971_gap','2026-06-30',null,60000.00,'HF leakage hazard assessment overdue past target'),
    ('MDF-0014','file_not_started','resource_constraint','revalidate_sterilization','open','internal_only','2026-09-15',null,32000.00,'Sterilization section authoring not yet started'),
    ('MDF-0016','incomplete_vv_testing','test_report_pending','complete_vv_testing','closed','none','2026-07-15','2026-07-10',27000.00,'Aerosol output VV completed and closed')
  ) as q(fref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.device_mdf_r3644 e
    on e.organization_id = v_org_id and e.file_ref = q.fref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) File status distribution
create or replace function public.founder_r3644_file_status_rollup()
returns table(file_status text, files bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_mdf_r3644)
  select l.file_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.device_mdf_r3644 l
  group by l.file_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_file_status_rollup() from public, anon;
grant execute on function public.founder_r3644_file_status_rollup() to authenticated;

-- 2) Device-class completeness scorecard
create or replace function public.founder_r3644_device_class_scorecard()
returns table(
  device_class text,
  total_files bigint,
  files_current bigint,
  minor_update bigint,
  major_gap bigint,
  outdated_files bigint,
  change_controls_open bigint,
  avg_completeness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class,
    count(*)::bigint,
    count(*) filter (where l.file_status = 'current')::bigint,
    count(*) filter (where l.file_status = 'minor_update_due')::bigint,
    count(*) filter (where l.file_status = 'major_gap')::bigint,
    count(*) filter (where l.file_status in ('outdated','not_started'))::bigint,
    coalesce(sum(l.change_controls_open),0)::bigint,
    round(avg(l.completeness_pct), 1)
  from public.device_mdf_r3644 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3644_device_class_scorecard() to authenticated;

-- 3) File-section × file-status matrix
create or replace function public.founder_r3644_section_status_matrix()
returns table(file_section text, file_status text, files bigint, avg_completeness_pct numeric, total_outdated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.file_section, l.file_status, count(*)::bigint,
    round(avg(l.completeness_pct), 1),
    coalesce(sum(l.sections_outdated),0)::bigint
  from public.device_mdf_r3644 l
  group by l.file_section, l.file_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_section_status_matrix() from public, anon;
grant execute on function public.founder_r3644_section_status_matrix() to authenticated;

-- 4) Monthly completeness trend
create or replace function public.founder_r3644_monthly_completeness_trend()
returns table(period_month date, files bigint, avg_completeness_pct numeric, major_gap bigint, outdated_files bigint, worsening bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.completeness_pct), 1),
    count(*) filter (where l.file_status = 'major_gap')::bigint,
    count(*) filter (where l.file_status in ('outdated','not_started'))::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.device_mdf_r3644 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3644_monthly_completeness_trend() from public, anon;
grant execute on function public.founder_r3644_monthly_completeness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3644_capa_status_board()
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
  from public.device_mdf_capa_actions_r3644 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_capa_status_board() from public, anon;
grant execute on function public.founder_r3644_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3644_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.device_mdf_capa_actions_r3644)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.device_mdf_capa_actions_r3644 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3644_root_cause_pareto() to authenticated;

-- 7) Gap regulatory-impact digest
create or replace function public.founder_r3644_gap_impact_digest()
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
  from public.device_mdf_capa_actions_r3644 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3644_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3644_gap_impact_digest() to authenticated;

-- 8) High-risk file queue (outdated / major_gap / not_started)
create or replace function public.founder_r3644_high_risk_queue()
returns table(
  device_name text,
  file_ref text,
  device_class text,
  file_section text,
  period_month date,
  file_status text,
  completeness_pct numeric,
  change_controls_open int,
  next_review_due date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.file_ref, l.device_class, l.file_section, l.period_month,
    l.file_status, l.completeness_pct, l.change_controls_open, l.next_review_due, l.notes
  from public.device_mdf_r3644 l
  where l.file_status in ('outdated','major_gap','not_started','minor_update_due')
     or l.completeness_pct < 80
     or l.change_controls_open >= 2
     or l.trend_dir = 'worsening'
     or l.sections_outdated > 0
  order by l.period_month desc, l.completeness_pct asc;
end;
$$;

revoke execute on function public.founder_r3644_high_risk_queue() from public, anon;
grant execute on function public.founder_r3644_high_risk_queue() to authenticated;
