-- Round 3120: Customer Hospital Operating Room Surgical Smoke Evacuator Capture Efficiency Audit
-- Monthly OT surgical smoke evacuator audit: capture velocity × filter loading × surgical-team exposure × NIOSH-compliance × replacement queue.

create table if not exists ot_smoke_evacuator_audits_r3120 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  evacuator_asset_tag text not null,
  evacuator_make text not null,
  evacuator_model text not null,
  audit_month date not null,
  audited_by_engineer_id uuid references engineers(id) on delete set null,
  capture_velocity_fpm numeric(6,2) not null check (capture_velocity_fpm >= 0 and capture_velocity_fpm <= 500),
  niosh_target_velocity_fpm numeric(6,2) not null default 100.00 check (niosh_target_velocity_fpm > 0),
  velocity_compliance_status text not null check (velocity_compliance_status in ('compliant','marginal','non_compliant','critical_fail')),
  ulpa_filter_loading_pct numeric(5,2) not null check (ulpa_filter_loading_pct >= 0 and ulpa_filter_loading_pct <= 100),
  carbon_filter_loading_pct numeric(5,2) not null check (carbon_filter_loading_pct >= 0 and carbon_filter_loading_pct <= 100),
  prefilter_loading_pct numeric(5,2) not null check (prefilter_loading_pct >= 0 and prefilter_loading_pct <= 100),
  filter_replacement_recommended boolean not null default false,
  filter_replacement_urgency text not null check (filter_replacement_urgency in ('none','routine','priority','urgent','immediate')),
  surgical_team_exposure_ppm numeric(8,3) not null check (surgical_team_exposure_ppm >= 0),
  niosh_exposure_limit_ppm numeric(8,3) not null default 0.500 check (niosh_exposure_limit_ppm > 0),
  exposure_compliance_status text not null check (exposure_compliance_status in ('compliant','marginal','non_compliant','hazardous')),
  surgeries_per_month integer not null check (surgeries_per_month >= 0),
  evacuator_usage_hours numeric(7,2) not null check (evacuator_usage_hours >= 0),
  niosh_overall_grade text not null check (niosh_overall_grade in ('A','B','C','D','F')),
  audit_outcome text not null check (audit_outcome in ('pass','conditional_pass','fail','condemned')),
  remediation_status text not null check (remediation_status in ('not_required','planned','in_progress','completed','overdue')),
  remediation_estimate_rupees numeric(12,2) not null default 0 check (remediation_estimate_rupees >= 0),
  audit_notes text,
  audited_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists ot_smoke_evacuator_replacement_queue_r3120 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references ot_smoke_evacuator_audits_r3120(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  component_type text not null check (component_type in ('ulpa_filter','carbon_filter','prefilter','capture_wand','suction_motor','full_unit')),
  component_part_number text not null,
  queue_priority text not null check (queue_priority in ('low','medium','high','urgent','emergency')),
  estimated_unit_cost_rupees numeric(12,2) not null check (estimated_unit_cost_rupees >= 0),
  quantity_required integer not null check (quantity_required > 0),
  total_cost_rupees numeric(14,2) not null check (total_cost_rupees >= 0),
  supplier_name text not null,
  supplier_lead_time_days integer not null check (supplier_lead_time_days >= 0),
  scheduled_replacement_date date,
  assigned_engineer_id uuid references engineers(id) on delete set null,
  queue_status text not null check (queue_status in ('queued','po_raised','dispatched','in_transit','received','scheduled','installed','cancelled')),
  niosh_risk_if_delayed text not null check (niosh_risk_if_delayed in ('low','moderate','high','severe','catastrophic')),
  surgeon_complaint_flag boolean not null default false,
  surgeon_complaint_count integer not null default 0 check (surgeon_complaint_count >= 0),
  queue_notes text,
  queued_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists ot_smoke_audits_r3120_org_month_idx on ot_smoke_evacuator_audits_r3120(organization_id, audit_month);
create index if not exists ot_smoke_audits_r3120_outcome_idx on ot_smoke_evacuator_audits_r3120(audit_outcome);
create index if not exists ot_smoke_queue_r3120_status_idx on ot_smoke_evacuator_replacement_queue_r3120(queue_status, queue_priority);
create index if not exists ot_smoke_queue_r3120_org_idx on ot_smoke_evacuator_replacement_queue_r3120(organization_id);

alter table ot_smoke_evacuator_audits_r3120 enable row level security;
alter table ot_smoke_evacuator_replacement_queue_r3120 enable row level security;

do $seed$
declare
  v_org_id uuid;
  v_audit_1 uuid;
  v_audit_2 uuid;
  v_audit_3 uuid;
  v_audit_4 uuid;
  v_audit_5 uuid;
  v_audit_6 uuid;
begin
  select id into v_org_id from organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  insert into ot_smoke_evacuator_audits_r3120 (
    organization_id, hospital_name, ot_room_code, evacuator_asset_tag, evacuator_make, evacuator_model,
    audit_month, capture_velocity_fpm, niosh_target_velocity_fpm, velocity_compliance_status,
    ulpa_filter_loading_pct, carbon_filter_loading_pct, prefilter_loading_pct, filter_replacement_recommended,
    filter_replacement_urgency, surgical_team_exposure_ppm, niosh_exposure_limit_ppm, exposure_compliance_status,
    surgeries_per_month, evacuator_usage_hours, niosh_overall_grade, audit_outcome,
    remediation_status, remediation_estimate_rupees, audit_notes
  ) values
    (v_org_id, 'Apollo Hospitals Jubilee Hills', 'OT-3 Cardiac', 'EVAC-APL-OT3-001', 'Buffalo Filter', 'ViroSafe Pro',
     '2026-05-01', 112.50, 100.00, 'compliant', 42.30, 38.10, 55.20, false,
     'none', 0.180, 0.500, 'compliant', 84, 168.50, 'A', 'pass',
     'not_required', 0, 'Excellent capture velocity, filters within normal loading.'),
    (v_org_id, 'Yashoda Hospitals Secunderabad', 'OT-5 Ortho', 'EVAC-YSH-OT5-014', 'Stryker', 'Neptune 3 Smoke',
     '2026-05-01', 88.20, 100.00, 'marginal', 71.40, 68.90, 82.50, true,
     'priority', 0.420, 0.500, 'marginal', 62, 132.00, 'B', 'conditional_pass',
     'planned', 28500.00, 'ULPA at 71%, prefilter at 82%, schedule replacement before next month.'),
    (v_org_id, 'KIMS Hospitals Kondapur', 'OT-7 Gen Surgery', 'EVAC-KIM-OT7-022', 'Medtronic', 'RapidVac',
     '2026-05-01', 64.80, 100.00, 'non_compliant', 88.60, 91.20, 96.40, true,
     'urgent', 0.780, 0.500, 'non_compliant', 96, 198.30, 'D', 'fail',
     'in_progress', 64200.00, 'Severe filter loading, exposure exceeds NIOSH REL. Immediate filter swap in progress.'),
    (v_org_id, 'AIG Hospitals Gachibowli', 'OT-2 Bariatric', 'EVAC-AIG-OT2-008', 'CONMED', 'AirSeal IFS',
     '2026-05-01', 105.40, 100.00, 'compliant', 35.20, 28.40, 48.60, false,
     'none', 0.220, 0.500, 'compliant', 48, 102.00, 'A', 'pass',
     'not_required', 0, 'New unit installed Q1, performing well.'),
    (v_org_id, 'Continental Hospitals Nanakramguda', 'OT-1 Neuro', 'EVAC-CNT-OT1-005', 'Buffalo Filter', 'PlumePort ES',
     '2026-05-01', 42.10, 100.00, 'critical_fail', 95.80, 97.30, 99.10, true,
     'immediate', 1.240, 0.500, 'hazardous', 38, 84.50, 'F', 'condemned',
     'overdue', 142000.00, 'Unit condemned. Surgeons reported visible plume during craniotomy. Replace full unit.'),
    (v_org_id, 'Sunshine Hospitals Paradise', 'OT-4 ENT', 'EVAC-SUN-OT4-017', 'Olympus', 'UHI-4',
     '2026-05-01', 96.30, 100.00, 'marginal', 62.10, 58.80, 74.20, true,
     'routine', 0.380, 0.500, 'marginal', 71, 145.20, 'B', 'conditional_pass',
     'planned', 18900.00, 'Prefilter approaching threshold, schedule routine swap.'),
    (v_org_id, 'St John''s Hospital Bangalore', 'OT-6 Gyn', 'EVAC-STJ-OT6-031', 'ERBE', 'IES 2',
     '2026-05-01', 78.40, 100.00, 'non_compliant', 81.20, 76.50, 89.30, true,
     'urgent', 0.620, 0.500, 'non_compliant', 58, 124.80, 'C', 'fail',
     'in_progress', 52800.00, 'LEEP and laparoscopic loads heavy. Filter set replacement queued.');

  select id into v_audit_1 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-YSH-OT5-014' limit 1;
  select id into v_audit_2 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-KIM-OT7-022' limit 1;
  select id into v_audit_3 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-CNT-OT1-005' limit 1;
  select id into v_audit_4 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-SUN-OT4-017' limit 1;
  select id into v_audit_5 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-STJ-OT6-031' limit 1;
  select id into v_audit_6 from ot_smoke_evacuator_audits_r3120 where evacuator_asset_tag = 'EVAC-APL-OT3-001' limit 1;

  insert into ot_smoke_evacuator_replacement_queue_r3120 (
    audit_id, organization_id, hospital_name, ot_room_code, component_type, component_part_number,
    queue_priority, estimated_unit_cost_rupees, quantity_required, total_cost_rupees,
    supplier_name, supplier_lead_time_days, scheduled_replacement_date, queue_status,
    niosh_risk_if_delayed, surgeon_complaint_flag, surgeon_complaint_count, queue_notes
  ) values
    (v_audit_1, v_org_id, 'Yashoda Hospitals Secunderabad', 'OT-5 Ortho', 'ulpa_filter', 'BFI-ULPA-VSP-100',
     'high', 14500.00, 1, 14500.00, 'Buffalo Filter India Pvt Ltd', 7, '2026-06-12'::date, 'po_raised',
     'moderate', false, 0, 'Standard ULPA cartridge swap.'),
    (v_audit_1, v_org_id, 'Yashoda Hospitals Secunderabad', 'OT-5 Ortho', 'prefilter', 'BFI-PREF-VSP-200',
     'medium', 3200.00, 4, 12800.00, 'Buffalo Filter India Pvt Ltd', 5, '2026-06-12'::date, 'po_raised',
     'low', false, 0, '4-pack prefilter bundle.'),
    (v_audit_2, v_org_id, 'KIMS Hospitals Kondapur', 'OT-7 Gen Surgery', 'ulpa_filter', 'MDT-ULPA-RV-700',
     'urgent', 21500.00, 1, 21500.00, 'Medtronic India', 4, '2026-06-04'::date, 'dispatched',
     'high', true, 2, 'OT lead surgeon escalation. Expedited shipment.'),
    (v_audit_2, v_org_id, 'KIMS Hospitals Kondapur', 'OT-7 Gen Surgery', 'carbon_filter', 'MDT-CARB-RV-720',
     'urgent', 8400.00, 1, 8400.00, 'Medtronic India', 4, '2026-06-04'::date, 'dispatched',
     'high', true, 2, 'Carbon module saturated, paired with ULPA swap.'),
    (v_audit_3, v_org_id, 'Continental Hospitals Nanakramguda', 'OT-1 Neuro', 'full_unit', 'BFI-VSP-FULL-UNIT',
     'emergency', 425000.00, 1, 425000.00, 'Buffalo Filter India Pvt Ltd', 14, '2026-06-18'::date, 'queued',
     'catastrophic', true, 5, 'Condemned unit, neuro OT operating without compliant evacuation. Loaner requested.'),
    (v_audit_4, v_org_id, 'Sunshine Hospitals Paradise', 'OT-4 ENT', 'prefilter', 'OLY-PREF-UHI4-300',
     'low', 2800.00, 6, 16800.00, 'Olympus Medical Systems India', 10, '2026-06-25'::date, 'queued',
     'low', false, 0, 'Routine 6-pack restock.'),
    (v_audit_5, v_org_id, 'St John''s Hospital Bangalore', 'OT-6 Gyn', 'ulpa_filter', 'ERB-ULPA-IES2-100',
     'high', 16200.00, 1, 16200.00, 'ERBE Elektromedizin India', 9, '2026-06-15'::date, 'in_transit',
     'moderate', true, 1, 'Gyn surgeon flagged plume during LEEP.'),
    (v_audit_5, v_org_id, 'St John''s Hospital Bangalore', 'OT-6 Gyn', 'capture_wand', 'ERB-WAND-IES2-A1',
     'medium', 6800.00, 2, 13600.00, 'ERBE Elektromedizin India', 9, '2026-06-15'::date, 'in_transit',
     'moderate', false, 0, 'Reusable wand replacement, paired with filter swap.'),
    (v_audit_6, v_org_id, 'Apollo Hospitals Jubilee Hills', 'OT-3 Cardiac', 'prefilter', 'BFI-PREF-VSP-200',
     'low', 3200.00, 2, 6400.00, 'Buffalo Filter India Pvt Ltd', 5, '2026-07-10'::date, 'scheduled',
     'low', false, 0, 'Preventive top-up.'),
    (v_audit_3, v_org_id, 'Continental Hospitals Nanakramguda', 'OT-1 Neuro', 'suction_motor', 'BFI-MOTOR-PP-A2',
     'emergency', 58000.00, 1, 58000.00, 'Buffalo Filter India Pvt Ltd', 12, '2026-06-20'::date, 'queued',
     'severe', true, 5, 'Motor bearings worn, contributing to low capture velocity.'),
    (v_audit_2, v_org_id, 'KIMS Hospitals Kondapur', 'OT-7 Gen Surgery', 'prefilter', 'MDT-PREF-RV-740',
     'high', 2950.00, 8, 23600.00, 'Medtronic India', 4, '2026-06-04'::date, 'received',
     'moderate', false, 0, 'Bulk prefilter restock landed in central stores.'),
    (v_audit_4, v_org_id, 'Sunshine Hospitals Paradise', 'OT-4 ENT', 'carbon_filter', 'OLY-CARB-UHI4-320',
     'medium', 7200.00, 1, 7200.00, 'Olympus Medical Systems India', 10, '2026-06-25'::date, 'queued',
     'moderate', false, 0, 'Carbon cartridge swap bundled with prefilter shipment.');
end
$seed$;

create or replace function founder_ot_smoke_audit_overview_r3120()
returns table (
  total_audits bigint,
  hospitals_audited bigint,
  ot_rooms_audited bigint,
  passed_audits bigint,
  conditional_passes bigint,
  failed_audits bigint,
  condemned_units bigint,
  avg_capture_velocity numeric,
  avg_exposure_ppm numeric,
  total_remediation_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    count(*)::bigint,
    count(distinct hospital_name)::bigint,
    count(distinct ot_room_code)::bigint,
    count(*) filter (where audit_outcome = 'pass')::bigint,
    count(*) filter (where audit_outcome = 'conditional_pass')::bigint,
    count(*) filter (where audit_outcome = 'fail')::bigint,
    count(*) filter (where audit_outcome = 'condemned')::bigint,
    round(avg(capture_velocity_fpm), 2),
    round(avg(surgical_team_exposure_ppm), 3),
    coalesce(sum(remediation_estimate_rupees), 0)
  from ot_smoke_evacuator_audits_r3120;
end;
$$;

revoke execute on function founder_ot_smoke_audit_overview_r3120() from public, anon;
grant execute on function founder_ot_smoke_audit_overview_r3120() to authenticated;

create or replace function founder_ot_smoke_velocity_compliance_r3120()
returns table (
  velocity_compliance_status text,
  audit_count bigint,
  avg_velocity_fpm numeric,
  min_velocity_fpm numeric,
  hospitals_affected bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    a.velocity_compliance_status,
    count(*)::bigint,
    round(avg(a.capture_velocity_fpm), 2),
    round(min(a.capture_velocity_fpm), 2),
    count(distinct a.hospital_name)::bigint
  from ot_smoke_evacuator_audits_r3120 a
  group by a.velocity_compliance_status
  order by case a.velocity_compliance_status
    when 'critical_fail' then 1
    when 'non_compliant' then 2
    when 'marginal' then 3
    when 'compliant' then 4
  end;
end;
$$;

revoke execute on function founder_ot_smoke_velocity_compliance_r3120() from public, anon;
grant execute on function founder_ot_smoke_velocity_compliance_r3120() to authenticated;

create or replace function founder_ot_smoke_filter_loading_r3120()
returns table (
  hospital_name text,
  ot_room_code text,
  ulpa_loading_pct numeric,
  carbon_loading_pct numeric,
  prefilter_loading_pct numeric,
  replacement_urgency text,
  niosh_grade text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    a.hospital_name,
    a.ot_room_code,
    a.ulpa_filter_loading_pct,
    a.carbon_filter_loading_pct,
    a.prefilter_loading_pct,
    a.filter_replacement_urgency,
    a.niosh_overall_grade
  from ot_smoke_evacuator_audits_r3120 a
  order by greatest(a.ulpa_filter_loading_pct, a.carbon_filter_loading_pct, a.prefilter_loading_pct) desc;
end;
$$;

revoke execute on function founder_ot_smoke_filter_loading_r3120() from public, anon;
grant execute on function founder_ot_smoke_filter_loading_r3120() to authenticated;

create or replace function founder_ot_smoke_exposure_risk_r3120()
returns table (
  hospital_name text,
  ot_room_code text,
  surgical_team_exposure_ppm numeric,
  niosh_exposure_limit_ppm numeric,
  exceedance_ratio numeric,
  exposure_compliance_status text,
  surgeries_per_month integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    a.hospital_name,
    a.ot_room_code,
    a.surgical_team_exposure_ppm,
    a.niosh_exposure_limit_ppm,
    round(a.surgical_team_exposure_ppm / nullif(a.niosh_exposure_limit_ppm, 0), 2),
    a.exposure_compliance_status,
    a.surgeries_per_month
  from ot_smoke_evacuator_audits_r3120 a
  order by a.surgical_team_exposure_ppm desc;
end;
$$;

revoke execute on function founder_ot_smoke_exposure_risk_r3120() from public, anon;
grant execute on function founder_ot_smoke_exposure_risk_r3120() to authenticated;

create or replace function founder_ot_smoke_niosh_grade_r3120()
returns table (
  niosh_overall_grade text,
  audit_count bigint,
  hospitals_at_grade bigint,
  avg_velocity numeric,
  avg_exposure numeric,
  total_remediation_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    a.niosh_overall_grade,
    count(*)::bigint,
    count(distinct a.hospital_name)::bigint,
    round(avg(a.capture_velocity_fpm), 2),
    round(avg(a.surgical_team_exposure_ppm), 3),
    coalesce(sum(a.remediation_estimate_rupees), 0)
  from ot_smoke_evacuator_audits_r3120 a
  group by a.niosh_overall_grade
  order by a.niosh_overall_grade;
end;
$$;

revoke execute on function founder_ot_smoke_niosh_grade_r3120() from public, anon;
grant execute on function founder_ot_smoke_niosh_grade_r3120() to authenticated;

create or replace function founder_ot_smoke_replacement_queue_r3120()
returns table (
  hospital_name text,
  ot_room_code text,
  component_type text,
  queue_priority text,
  quantity_required integer,
  total_cost_rupees numeric,
  supplier_name text,
  queue_status text,
  niosh_risk_if_delayed text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    q.hospital_name,
    q.ot_room_code,
    q.component_type,
    q.queue_priority,
    q.quantity_required,
    q.total_cost_rupees,
    q.supplier_name,
    q.queue_status,
    q.niosh_risk_if_delayed
  from ot_smoke_evacuator_replacement_queue_r3120 q
  order by case q.queue_priority
    when 'emergency' then 1
    when 'urgent' then 2
    when 'high' then 3
    when 'medium' then 4
    when 'low' then 5
  end, q.total_cost_rupees desc;
end;
$$;

revoke execute on function founder_ot_smoke_replacement_queue_r3120() from public, anon;
grant execute on function founder_ot_smoke_replacement_queue_r3120() to authenticated;

create or replace function founder_ot_smoke_supplier_spend_r3120()
returns table (
  supplier_name text,
  line_items bigint,
  total_quantity bigint,
  total_spend_rupees numeric,
  avg_lead_time_days numeric,
  emergency_lines bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    q.supplier_name,
    count(*)::bigint,
    sum(q.quantity_required)::bigint,
    coalesce(sum(q.total_cost_rupees), 0),
    round(avg(q.supplier_lead_time_days), 1),
    count(*) filter (where q.queue_priority = 'emergency')::bigint
  from ot_smoke_evacuator_replacement_queue_r3120 q
  group by q.supplier_name
  order by sum(q.total_cost_rupees) desc;
end;
$$;

revoke execute on function founder_ot_smoke_supplier_spend_r3120() from public, anon;
grant execute on function founder_ot_smoke_supplier_spend_r3120() to authenticated;

create or replace function founder_ot_smoke_surgeon_complaints_r3120()
returns table (
  hospital_name text,
  ot_room_code text,
  component_type text,
  surgeon_complaint_count integer,
  queue_priority text,
  queue_status text,
  scheduled_replacement_date date,
  niosh_risk_if_delayed text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    q.hospital_name,
    q.ot_room_code,
    q.component_type,
    q.surgeon_complaint_count,
    q.queue_priority,
    q.queue_status,
    q.scheduled_replacement_date,
    q.niosh_risk_if_delayed
  from ot_smoke_evacuator_replacement_queue_r3120 q
  where q.surgeon_complaint_flag = true
  order by q.surgeon_complaint_count desc;
end;
$$;

revoke execute on function founder_ot_smoke_surgeon_complaints_r3120() from public, anon;
grant execute on function founder_ot_smoke_surgeon_complaints_r3120() to authenticated;
