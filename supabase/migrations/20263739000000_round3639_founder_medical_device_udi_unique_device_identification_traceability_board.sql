-- Round 3639: Medical-Device UDI (Unique Device Identification) Traceability Board
-- UDI traceability log — device × class × period × DI/PI assignment × label compliance × CDSCO-database upload × batch-lot linkage × GTIN × direct marking × UDI status × trend × CAPA

-- =============================================================================
-- TABLE 1: udi_trace_r3639 — per-device UDI assignment & compliance metrics
-- =============================================================================
create table if not exists public.udi_trace_r3639 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_name text not null,
  device_code text not null,
  device_class text not null check (device_class in (
    'class_a','class_b','class_c','class_d'
  )),
  period_month date not null,
  udi_di text,
  labels_compliant_pct numeric(5,2),
  database_uploaded_pct numeric(5,2),
  batch_lot_linked_pct numeric(5,2),
  units_covered int,
  gtin_assigned boolean not null,
  direct_marking_required boolean not null,
  udi_status text not null check (udi_status in (
    'fully_compliant','labeling_gap','database_gap','not_assigned','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.udi_trace_r3639 enable row level security;

create index if not exists idx_udi_trace_r3639_org on public.udi_trace_r3639(organization_id);
create index if not exists idx_udi_trace_r3639_period on public.udi_trace_r3639(period_month);
create index if not exists idx_udi_trace_r3639_status on public.udi_trace_r3639(udi_status);

-- =============================================================================
-- TABLE 2: udi_trace_capa_actions_r3639 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.udi_trace_capa_actions_r3639 (
  id uuid primary key default gen_random_uuid(),
  udi_log_id uuid not null references public.udi_trace_r3639(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'di_not_assigned','pi_not_encoded','label_missing_udi','database_upload_pending',
    'batch_lot_not_linked','gtin_not_assigned','direct_marking_missing',
    'label_format_noncompliant','human_readable_missing','data_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'vendor_gs1_registration_pending','labeling_artwork_not_updated','erp_integration_gap',
    'cdsco_portal_upload_backlog','barcode_printer_issue','process_not_defined',
    'staff_training_gap','legacy_stock_unmarked','data_entry_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_di_via_gs1','encode_pi_barcode','update_label_artwork','upload_to_cdsco_database',
    'link_batch_lot_records','assign_gtin','apply_direct_marking','reprint_compliant_labels',
    'fix_erp_integration','retrain_labeling_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','mdr_2017_deviation','iso_13485_deviation','gs1_standard_deviation',
    'internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.udi_trace_capa_actions_r3639 enable row level security;

create index if not exists idx_udi_trace_capa_r3639_log on public.udi_trace_capa_actions_r3639(udi_log_id);
create index if not exists idx_udi_trace_capa_r3639_status on public.udi_trace_capa_actions_r3639(capa_status);

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

  -- 16 device UDI rows
  insert into public.udi_trace_r3639 (
    organization_id, device_name, device_code, device_class, period_month,
    udi_di, labels_compliant_pct, database_uploaded_pct, batch_lot_linked_pct,
    units_covered, gtin_assigned, direct_marking_required, udi_status, trend_dir, notes
  )
  select v_org_id, q.dname, q.dcode, q.dclass, q.pmon::date,
    q.di, q.labpct, q.dbpct, q.btlpct,
    q.units, q.gtin, q.dmark, q.ust, q.trd, q.nt
  from (values
    ('ICU Ventilator','VENT-CL-D-01','class_d','2026-07-01',
     '08901234500017',100,100,98.5,120,true,false,'fully_compliant','stable','DI/PI assigned, labels compliant, CDSCO upload complete'),
    ('Infusion Pump','INFP-CL-C-02','class_c','2026-07-01',
     '08901234500024',96.0,88.0,90.0,340,true,false,'labeling_gap','improving','Minor label artwork gap on ~4% of infusion pump units'),
    ('Patient Monitor','PMON-CL-C-03','class_c','2026-07-01',
     '08901234500031',92.5,70.0,85.0,260,true,false,'database_gap','improving','CDSCO database upload backlog for latest batches'),
    ('Dialysis Machine','DIAL-CL-C-04','class_c','2026-07-01',
     '08901234500048',100,100,100,60,true,true,'fully_compliant','stable','Full UDI compliance including direct part marking'),
    ('Defibrillator','DEFB-CL-D-05','class_d','2026-07-01',
     '08901234500055',88.0,60.0,72.0,90,true,false,'database_gap','worsening','PI encoded but CDSCO database uploads slipping'),
    ('C-arm Imaging System','CARM-CL-C-06','class_c','2026-06-01',
     null,0,0,0,15,false,true,'not_assigned','worsening','GS1 DI not yet assigned — vendor registration pending'),
    ('Syringe Pump','SYRP-CL-B-07','class_b','2026-06-01',
     '08901234500079',98.0,95.0,96.0,420,true,false,'fully_compliant','improving','Near-full UDI compliance across syringe pump fleet'),
    ('ECG Machine','ECGM-CL-B-08','class_b','2026-06-01',
     '08901234500086',80.0,55.0,60.0,210,true,false,'labeling_gap','stable','Legacy stock labels not yet updated with UDI'),
    ('Ultrasound Scanner','USND-CL-B-09','class_b','2026-06-01',
     '08901234500093',100,98.0,97.0,45,true,false,'fully_compliant','stable','Compliant; minor batch-lot linkage pending'),
    ('Anesthesia Workstation','ANES-CL-C-10','class_c','2026-06-01',
     '08901234500109',65.0,40.0,50.0,30,true,true,'non_compliant','worsening','Multiple gaps — labels, database and direct marking'),
    ('Surgical Laser','LASR-CL-D-11','class_d','2026-05-01',
     '08901234500116',90.0,85.0,88.0,20,true,true,'labeling_gap','improving','Direct marking applied, residual label format issue'),
    ('Patient Warmer','WARM-CL-B-12','class_b','2026-05-01',
     '08901234500123',100,100,99.0,150,true,false,'fully_compliant','stable','Fully compliant patient warmer fleet'),
    ('Pulse Oximeter','POXM-CL-A-13','class_a','2026-05-01',
     '08901234500130',94.0,90.0,92.0,800,true,false,'labeling_gap','improving','High volume — small labeling gap on older units'),
    ('CT Scanner','CTSC-CL-C-14','class_c','2026-05-01',
     null,0,0,0,8,false,true,'not_assigned','worsening','DI not assigned for imported CT scanner units'),
    ('Blood Gas Analyzer','BGAN-CL-B-15','class_b','2026-05-01',
     '08901234500154',72.0,48.0,55.0,40,true,false,'non_compliant','worsening','Below threshold across labeling and database upload'),
    ('Digital X-ray','XRAY-CL-C-16','class_c','2026-06-01',
     '08901234500161',97.0,92.0,94.0,55,true,false,'database_gap','improving','Small residual CDSCO database upload gap')
  ) as q(dname, dcode, dclass, pmon, di, labpct, dbpct, btlpct, units, gtin, dmark, ust, trd, nt);

  -- CAPA seed — attach to specific devices via device_code
  insert into public.udi_trace_capa_actions_r3639 (
    udi_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CARM-CL-C-06','di_not_assigned','vendor_gs1_registration_pending','assign_di_via_gs1','in_progress','cdsco_notifiable','2026-08-15',null,45000.00,'GS1 registration in progress for C-arm DI assignment'),
    ('CTSC-CL-C-14','di_not_assigned','vendor_gs1_registration_pending','assign_di_via_gs1','open','mdr_2017_deviation','2026-08-20',null,38000.00,'Imported CT scanner units awaiting DI assignment'),
    ('INFP-CL-C-02','label_format_noncompliant','labeling_artwork_not_updated','update_label_artwork','verification_pending','internal_only','2026-08-05',null,12000.00,'Label artwork update for ~4% of infusion pumps'),
    ('PMON-CL-C-03','database_upload_pending','cdsco_portal_upload_backlog','upload_to_cdsco_database','in_progress','iso_13485_deviation','2026-08-10',null,8000.00,'Clearing CDSCO upload backlog for patient monitors'),
    ('ANES-CL-C-10','label_missing_udi','process_not_defined','reprint_compliant_labels','escalated','cdsco_notifiable','2026-08-01',null,60000.00,'Multiple UDI gaps on anesthesia workstations — escalated'),
    ('BGAN-CL-B-15','database_upload_pending','erp_integration_gap','fix_erp_integration','open','mdr_2017_deviation','2026-08-12',null,25000.00,'ERP-to-CDSCO integration gap for blood gas analyzers'),
    ('ECGM-CL-B-08','label_missing_udi','legacy_stock_unmarked','reprint_compliant_labels','closed','internal_only','2026-07-10','2026-07-08',15000.00,'Legacy ECG stock relabeled with UDI barcodes'),
    ('DEFB-CL-D-05','database_upload_pending','cdsco_portal_upload_backlog','upload_to_cdsco_database','overdue','cdsco_notifiable','2026-07-05',null,30000.00,'Defibrillator database uploads overdue — Class D device')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.udi_trace_r3639 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) UDI status distribution
create or replace function public.founder_r3639_udi_status_rollup()
returns table(udi_status text, devices bigint, units_covered bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.udi_trace_r3639)
  select l.udi_status, count(*)::bigint,
         coalesce(sum(l.units_covered),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.udi_trace_r3639 l
  group by l.udi_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_udi_status_rollup() from public, anon;
grant execute on function public.founder_r3639_udi_status_rollup() to authenticated;

-- 2) Device-class scorecard
create or replace function public.founder_r3639_device_class_scorecard()
returns table(
  device_class text,
  total_devices bigint,
  fully_compliant bigint,
  labeling_gap bigint,
  database_gap bigint,
  not_assigned bigint,
  non_compliant bigint,
  avg_labels_pct numeric,
  avg_database_pct numeric,
  compliant_pct numeric
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
    count(*) filter (where l.udi_status = 'fully_compliant')::bigint,
    count(*) filter (where l.udi_status = 'labeling_gap')::bigint,
    count(*) filter (where l.udi_status = 'database_gap')::bigint,
    count(*) filter (where l.udi_status = 'not_assigned')::bigint,
    count(*) filter (where l.udi_status = 'non_compliant')::bigint,
    round(avg(l.labels_compliant_pct), 1),
    round(avg(l.database_uploaded_pct), 1),
    round(100.0 * count(*) filter (where l.udi_status = 'fully_compliant')::numeric / nullif(count(*),0), 1)
  from public.udi_trace_r3639 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3639_device_class_scorecard() to authenticated;

-- 3) Device-class × UDI-status matrix
create or replace function public.founder_r3639_class_status_matrix()
returns table(device_class text, udi_status text, devices bigint, units_covered bigint, avg_labels_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class, l.udi_status, count(*)::bigint,
    coalesce(sum(l.units_covered),0)::bigint,
    round(avg(l.labels_compliant_pct), 1)
  from public.udi_trace_r3639 l
  group by l.device_class, l.udi_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_class_status_matrix() from public, anon;
grant execute on function public.founder_r3639_class_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3639_monthly_compliance_trend()
returns table(
  period_month date,
  devices bigint,
  fully_compliant bigint,
  avg_labels_pct numeric,
  avg_database_pct numeric,
  avg_batch_lot_pct numeric
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
    count(*) filter (where l.udi_status = 'fully_compliant')::bigint,
    round(avg(l.labels_compliant_pct), 1),
    round(avg(l.database_uploaded_pct), 1),
    round(avg(l.batch_lot_linked_pct), 1)
  from public.udi_trace_r3639 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3639_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3639_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3639_capa_status_board()
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
  from public.udi_trace_capa_actions_r3639 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_capa_status_board() from public, anon;
grant execute on function public.founder_r3639_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3639_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.udi_trace_capa_actions_r3639)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.udi_trace_capa_actions_r3639 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3639_root_cause_pareto() to authenticated;

-- 7) Labeling-gap digest
create or replace function public.founder_r3639_labeling_gap_digest()
returns table(
  device_class text,
  devices_with_gap bigint,
  units_affected bigint,
  avg_labels_pct numeric,
  avg_database_pct numeric,
  avg_batch_lot_pct numeric
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
    coalesce(sum(l.units_covered),0)::bigint,
    round(avg(l.labels_compliant_pct), 1),
    round(avg(l.database_uploaded_pct), 1),
    round(avg(l.batch_lot_linked_pct), 1)
  from public.udi_trace_r3639 l
  where l.udi_status <> 'fully_compliant'
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3639_labeling_gap_digest() from public, anon;
grant execute on function public.founder_r3639_labeling_gap_digest() to authenticated;

-- 8) High-risk UDI queue (not_assigned / non_compliant / worsening)
create or replace function public.founder_r3639_high_risk_queue()
returns table(
  device_name text,
  device_code text,
  device_class text,
  period_month date,
  udi_di text,
  udi_status text,
  labels_compliant_pct numeric,
  database_uploaded_pct numeric,
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
  select l.device_name, l.device_code, l.device_class, l.period_month, l.udi_di,
    l.udi_status, l.labels_compliant_pct, l.database_uploaded_pct, l.trend_dir, l.notes
  from public.udi_trace_r3639 l
  where l.udi_status in ('not_assigned','non_compliant','database_gap','labeling_gap')
     or l.gtin_assigned = false
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.device_name;
end;
$$;

revoke execute on function public.founder_r3639_high_risk_queue() from public, anon;
grant execute on function public.founder_r3639_high_risk_queue() to authenticated;
