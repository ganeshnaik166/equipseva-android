-- Round 3674: Founder Records-Retention / Document-Archival Compliance Board
-- Records-retention ops — record class × owning function × retention years × archival % × destruction schedule × legal holds × storage medium × storage cost × CAPA

-- =============================================================================
-- TABLE 1: records_retention_r3674 — per record-class retention/archival compliance
-- =============================================================================
create table if not exists public.records_retention_r3674 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  record_code text not null,
  record_class text not null,
  owning_function text not null,
  period_month date not null,
  retention_years int not null,
  records_active int not null,
  records_due_archival int not null,
  archived_pct numeric(5,2),
  destruction_due int not null,
  destroyed_on_schedule int not null,
  legal_hold_count int not null,
  storage_cost_rupees numeric(12,2),
  last_audit_date date,
  storage_medium text not null check (storage_medium in (
    'physical_vault','onsite_cabinet','cloud_archive','offsite_vendor','hybrid'
  )),
  retention_status text not null check (retention_status in (
    'compliant','archival_backlog','destruction_overdue','legal_hold','untracked'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.records_retention_r3674 enable row level security;

create index if not exists idx_records_retention_r3674_org on public.records_retention_r3674(organization_id);
create index if not exists idx_records_retention_r3674_month on public.records_retention_r3674(period_month);
create index if not exists idx_records_retention_r3674_status on public.records_retention_r3674(retention_status);

-- =============================================================================
-- TABLE 2: records_retention_capa_actions_r3674 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.records_retention_capa_actions_r3674 (
  id uuid primary key default gen_random_uuid(),
  retention_row_id uuid not null references public.records_retention_r3674(id) on delete cascade,
  root_cause text not null check (root_cause in (
    'retention_schedule_not_mapped','scanning_vendor_backlog','legal_hold_unreleased',
    'destruction_approval_pending','index_metadata_missing','storage_capacity_full',
    'policy_awareness_gap','vendor_sla_breach'
  )),
  corrective_action text not null check (corrective_action in (
    'map_retention_schedule','add_scanning_shift','escalate_vendor_sla',
    'expedite_destruction_approval','rebuild_index_metadata','procure_storage_capacity',
    'train_record_owners','review_legal_hold','digitize_and_archive','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.records_retention_capa_actions_r3674 enable row level security;

create index if not exists idx_records_retention_capa_r3674_row on public.records_retention_capa_actions_r3674(retention_row_id);
create index if not exists idx_records_retention_capa_r3674_status on public.records_retention_capa_actions_r3674(capa_status);

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

  -- 16 retention/archival rows
  insert into public.records_retention_r3674 (
    organization_id, site_name, record_code, record_class, owning_function, period_month,
    retention_years, records_active, records_due_archival, archived_pct,
    destruction_due, destroyed_on_schedule, legal_hold_count, storage_cost_rupees,
    last_audit_date, storage_medium, retention_status, trend_dir, notes
  )
  select v_org_id, q.site, q.rcode, q.rclass, q.ofn, q.pm::date,
    q.ry, q.ract, q.rdue, q.apct,
    q.ddue, q.dsch, q.lhold, q.cost,
    q.laud::date, q.med, q.rst, q.tdir, q.nt
  from (values
    ('Mumbai HQ','RR-MUM-BMR-01','batch_manufacturing_record','quality_assurance','2026-07-01',
     10,4820,310,93.60,120,118,0,182000.00,'2026-06-18','onsite_cabinet','compliant','stable','BMR archival on schedule; QA cabinet fully indexed'),
    ('Mumbai HQ','RR-MUM-DHR-02','device_history_record','quality_assurance','2026-07-01',
     15,6150,540,71.20,0,0,2,244000.00,'2026-06-18','hybrid','archival_backlog','worsening','DHR scanning backlog after line-3 production ramp-up'),
    ('Mumbai HQ','RR-MUM-FIN-03','finance_invoice_ledger','finance','2026-07-01',
     8,12400,880,96.10,640,610,0,96000.00,'2026-05-30','cloud_archive','compliant','improving','Tally invoice exports auto-archived to cloud nightly'),
    ('Chennai Branch','RR-CHN-CAL-04','calibration_certificate','service_operations','2026-07-01',
     7,2380,190,88.40,85,60,0,41000.00,'2026-06-10','onsite_cabinet','destruction_overdue','worsening','2018 batch certificates past destruction window'),
    ('Chennai Branch','RR-CHN-SRV-05','service_report','service_operations','2026-07-01',
     5,5210,420,90.50,300,296,0,52000.00,'2026-06-10','cloud_archive','compliant','stable','Field service PDFs synced to archive nightly'),
    ('Delhi Warehouse','RR-DEL-POD-06','courier_pod_register','supply_chain','2026-07-01',
     3,8900,1450,58.70,760,410,0,68000.00,'2026-04-22','physical_vault','archival_backlog','worsening','POD registers piling up; scanning vendor slot missed'),
    ('Delhi Warehouse','RR-DEL-IMP-07','import_license_file','regulatory_affairs','2026-07-01',
     12,640,20,97.80,0,0,4,38000.00,'2026-06-25','physical_vault','legal_hold','stable','CDSCO import files under DRI inquiry hold'),
    ('Pune Plant','RR-PUN-DHF-08','design_history_file','regulatory_affairs','2026-07-01',
     15,310,10,99.00,0,0,0,26000.00,'2026-06-28','hybrid','compliant','stable','DHF master index verified in June internal audit'),
    ('Pune Plant','RR-PUN-TRN-09','training_record','human_resources','2026-07-01',
     5,3480,260,82.30,140,90,0,22000.00,'2026-05-15','onsite_cabinet','destruction_overdue','stable','Pre-2021 training files await destruction approval'),
    ('Bengaluru R&D Office','RR-BLR-LAB-10','lab_notebook','research_development','2026-07-01',
     10,1240,85,91.70,0,0,1,33000.00,'2026-06-05','hybrid','compliant','improving','E-lab notebook migration completed in Q1'),
    ('Bengaluru R&D Office','RR-BLR-VEN-11','vendor_agreement','legal','2026-07-01',
     8,720,60,64.20,35,12,3,19000.00,'2026-03-12','offsite_vendor','legal_hold','stable','Three agreements frozen pending arbitration'),
    ('Hyderabad Service Hub','RR-HYD-AMC-12','amc_contract_file','service_operations','2026-07-01',
     6,980,110,55.40,60,18,0,24000.00,null,'onsite_cabinet','untracked','worsening','No retention schedule mapped for AMC files yet'),
    ('Mumbai HQ','RR-MUM-PAY-13','payroll_register','human_resources','2026-06-01',
     8,5600,410,94.80,220,216,0,45000.00,'2026-05-20','cloud_archive','compliant','stable','Payroll ledger archival within SLA all quarter'),
    ('Chennai Branch','RR-CHN-QCF-14','quality_complaint_file','quality_assurance','2026-06-01',
     10,860,95,76.90,30,22,1,29000.00,'2026-04-30','offsite_vendor','archival_backlog','improving','Offsite vendor pickup resumed after SLA escalation'),
    ('Delhi Warehouse','RR-DEL-STK-15','stock_transfer_register','supply_chain','2026-06-01',
     5,4100,520,61.30,280,120,0,57000.00,'2026-02-14','physical_vault','destruction_overdue','worsening','Destruction memo pending CFO sign-off since March'),
    ('Pune Plant','RR-PUN-ENV-16','environmental_monitoring_log','quality_assurance','2026-06-01',
     7,2750,150,89.20,90,88,0,31000.00,'2026-06-01','hybrid','compliant','stable','EMS logs archived monthly with checksum verification')
  ) as q(site, rcode, rclass, ofn, pm, ry, ract, rdue, apct, ddue, dsch, lhold, cost, laud, med, rst, tdir, nt);

  -- CAPA seed — attach to specific retention rows via record_code
  insert into public.records_retention_capa_actions_r3674 (
    retention_row_id, root_cause, corrective_action, capa_status,
    impact_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RR-MUM-DHR-02','scanning_vendor_backlog','add_scanning_shift','in_progress',88000.00,'Meera Kulkarni','2026-08-20',null,'Second scanning shift onboarded; DHR backlog burning down'),
    ('RR-CHN-CAL-04','destruction_approval_pending','expedite_destruction_approval','open',26000.00,'S. Raghavan','2026-08-25',null,'2018 calibration certs listed; destruction memo with QA head'),
    ('RR-DEL-POD-06','vendor_sla_breach','escalate_vendor_sla','escalated',54000.00,'Anil Chauhan','2026-08-12',null,'Scanning vendor missed two pickup slots — penalty clause invoked'),
    ('RR-DEL-IMP-07','legal_hold_unreleased','review_legal_hold','verification_pending',15000.00,'Nisha Mehta','2026-09-05',null,'DRI inquiry hold reviewed with counsel; release checklist drafted'),
    ('RR-PUN-TRN-09','destruction_approval_pending','expedite_destruction_approval','closed',9000.00,'Kavita Joshi','2026-07-15','2026-07-11','Pre-2021 training files shredded with certificate on record'),
    ('RR-BLR-VEN-11','index_metadata_missing','rebuild_index_metadata','in_progress',21000.00,'Rohit Shetty','2026-08-30',null,'Vendor agreement index rebuilt for 2019-2022 folders'),
    ('RR-HYD-AMC-12','retention_schedule_not_mapped','map_retention_schedule','open',32000.00,'Prakash Iyer','2026-08-18',null,'AMC file class added to retention schedule draft v3'),
    ('RR-DEL-STK-15','storage_capacity_full','procure_storage_capacity','overdue',47000.00,'Anil Chauhan','2026-07-31',null,'Vault racks at 97 percent — offsite slot procurement delayed')
  ) as q(rcode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.records_retention_r3674 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Retention status distribution
create or replace function public.founder_r3674_retention_status_rollup()
returns table(retention_status text, record_rows bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.records_retention_r3674)
  select l.retention_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.records_retention_r3674 l
  group by l.retention_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3674_retention_status_rollup() from public, anon;
grant execute on function public.founder_r3674_retention_status_rollup() to authenticated;

-- 2) Owning-function compliance scorecard
create or replace function public.founder_r3674_owning_function_scorecard()
returns table(
  owning_function text,
  total_rows bigint,
  compliant bigint,
  backlog bigint,
  overdue_destruction bigint,
  legal_holds bigint,
  untracked bigint,
  avg_archived_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owning_function,
    count(*)::bigint,
    count(*) filter (where l.retention_status = 'compliant')::bigint,
    count(*) filter (where l.retention_status = 'archival_backlog')::bigint,
    count(*) filter (where l.retention_status = 'destruction_overdue')::bigint,
    count(*) filter (where l.retention_status = 'legal_hold')::bigint,
    count(*) filter (where l.retention_status = 'untracked')::bigint,
    round(avg(l.archived_pct), 1),
    round(100.0 * count(*) filter (where l.retention_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.records_retention_r3674 l
  group by l.owning_function
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3674_owning_function_scorecard() from public, anon;
grant execute on function public.founder_r3674_owning_function_scorecard() to authenticated;

-- 3) Storage medium × retention status matrix
create or replace function public.founder_r3674_storage_medium_status_matrix()
returns table(storage_medium text, retention_status text, record_rows bigint, records_active_total bigint, avg_archived_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.storage_medium, l.retention_status, count(*)::bigint,
    sum(l.records_active)::bigint,
    round(avg(l.archived_pct), 1)
  from public.records_retention_r3674 l
  group by l.storage_medium, l.retention_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3674_storage_medium_status_matrix() from public, anon;
grant execute on function public.founder_r3674_storage_medium_status_matrix() to authenticated;

-- 4) Monthly archival trend
create or replace function public.founder_r3674_monthly_archival_trend()
returns table(
  period_month date,
  record_rows bigint,
  records_active_total bigint,
  due_archival_total bigint,
  avg_archived_pct numeric,
  destruction_due_total bigint,
  destroyed_on_schedule_total bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    sum(l.records_active)::bigint,
    sum(l.records_due_archival)::bigint,
    round(avg(l.archived_pct), 1),
    sum(l.destruction_due)::bigint,
    sum(l.destroyed_on_schedule)::bigint
  from public.records_retention_r3674 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3674_monthly_archival_trend() from public, anon;
grant execute on function public.founder_r3674_monthly_archival_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3674_capa_status_board()
returns table(capa_status text, actions bigint, avg_impact_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.records_retention_capa_actions_r3674 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3674_capa_status_board() from public, anon;
grant execute on function public.founder_r3674_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3674_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.records_retention_capa_actions_r3674)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.records_retention_capa_actions_r3674 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3674_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3674_root_cause_pareto() to authenticated;

-- 7) Backlog digest by record class
create or replace function public.founder_r3674_backlog_digest()
returns table(
  record_class text,
  rows_tracked bigint,
  due_archival_total bigint,
  destruction_due_total bigint,
  legal_hold_total bigint,
  storage_cost_total_rupees numeric,
  avg_archived_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.record_class,
    count(*)::bigint,
    sum(l.records_due_archival)::bigint,
    sum(l.destruction_due)::bigint,
    sum(l.legal_hold_count)::bigint,
    coalesce(sum(l.storage_cost_rupees),0)::numeric,
    round(avg(l.archived_pct), 1)
  from public.records_retention_r3674 l
  group by l.record_class
  order by sum(l.records_due_archival) desc;
end;
$$;

revoke all on function public.founder_r3674_backlog_digest() from public, anon;
grant execute on function public.founder_r3674_backlog_digest() to authenticated;

-- 8) High-risk retention queue (untracked / destruction-overdue / low archival / worsening)
create or replace function public.founder_r3674_high_risk_queue()
returns table(
  site_name text,
  record_code text,
  record_class text,
  owning_function text,
  period_month date,
  retention_status text,
  archived_pct numeric,
  destruction_due int,
  legal_hold_count int,
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
  select l.site_name, l.record_code, l.record_class, l.owning_function, l.period_month,
    l.retention_status, l.archived_pct, l.destruction_due, l.legal_hold_count,
    l.trend_dir, l.notes
  from public.records_retention_r3674 l
  where l.retention_status in ('untracked','destruction_overdue')
     or l.archived_pct < 60
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.archived_pct asc;
end;
$$;

revoke all on function public.founder_r3674_high_risk_queue() from public, anon;
grant execute on function public.founder_r3674_high_risk_queue() to authenticated;
