-- Round r3087 — Hospital Chain Quarterly Burn-Unit Hydrotherapy Tub Calibration & Disinfection Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seed rows

-- =====================================================
-- Table 1: burn_unit_tub_calibrations_r3087
-- =====================================================
create table if not exists public.burn_unit_tub_calibrations_r3087 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_branch text not null,
  burn_unit_code text not null,
  tub_asset_tag text not null,
  manufacturer text not null,
  quarter_label text not null check (quarter_label in ('Q1-FY26','Q2-FY26','Q3-FY26','Q4-FY26','Q1-FY27','Q2-FY27')),
  calibration_status text not null check (calibration_status in ('passed','minor_drift','major_drift','failed','re_test_required')),
  disinfection_grade text not null check (disinfection_grade in ('A','B','C','D','quarantined')),
  temperature_drift_celsius numeric(6,2) not null,
  jet_pressure_drift_psi numeric(6,2) not null,
  chlorine_residual_ppm numeric(6,3) not null,
  atp_swab_rlu int not null,
  calibrated_by_engineer_id uuid references public.engineers(id),
  audited_by_profile_id uuid references public.profiles(id),
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  next_due_at timestamptz not null,
  remediation_cost_rupees int not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.burn_unit_tub_calibrations_r3087 enable row level security;

drop policy if exists burn_unit_tub_calibrations_r3087_founder_select on public.burn_unit_tub_calibrations_r3087;
create policy burn_unit_tub_calibrations_r3087_founder_select on public.burn_unit_tub_calibrations_r3087
  for select to authenticated using (public.is_founder());

revoke all on public.burn_unit_tub_calibrations_r3087 from public, anon;
grant select on public.burn_unit_tub_calibrations_r3087 to authenticated;

insert into public.burn_unit_tub_calibrations_r3087
  (chain_name, hospital_branch, burn_unit_code, tub_asset_tag, manufacturer, quarter_label, calibration_status, disinfection_grade, temperature_drift_celsius, jet_pressure_drift_psi, chlorine_residual_ppm, atp_swab_rlu, scheduled_at, completed_at, next_due_at, remediation_cost_rupees, notes)
values
  ('Apollo Burn Network','Hyderabad Jubilee','BU-HYD-01','TUB-A1142','Arjo','Q2-FY27','passed','A',0.20,1.20,1.450,18,'2026-06-02T09:00:00Z'::timestamptz,'2026-06-02T11:30:00Z'::timestamptz,'2026-09-02T09:00:00Z'::timestamptz,0,'within all tolerances'),
  ('Apollo Burn Network','Bengaluru Bannerghatta','BU-BLR-02','TUB-A1143','Arjo','Q2-FY27','minor_drift','B',0.80,2.40,1.180,42,'2026-06-04T08:30:00Z'::timestamptz,'2026-06-04T12:10:00Z'::timestamptz,'2026-09-04T08:30:00Z'::timestamptz,4500,'temp probe recal scheduled'),
  ('Fortis Trauma','Mumbai Mulund','BU-MUM-03','TUB-F2201','EWAC','Q2-FY27','passed','A',0.15,0.90,1.520,12,'2026-06-05T10:00:00Z'::timestamptz,'2026-06-05T12:00:00Z'::timestamptz,'2026-09-05T10:00:00Z'::timestamptz,0,'flawless'),
  ('Fortis Trauma','Delhi Vasant Kunj','BU-DEL-04','TUB-F2202','EWAC','Q2-FY27','major_drift','C',1.90,4.80,0.620,180,'2026-06-06T07:30:00Z'::timestamptz,'2026-06-06T13:45:00Z'::timestamptz,'2026-07-06T07:30:00Z'::timestamptz,22000,'jet pump impeller replaced'),
  ('Manipal Hospitals','Bengaluru Whitefield','BU-BLR-05','TUB-M3301','Whitehall','Q2-FY27','passed','A',0.30,1.50,1.380,22,'2026-06-07T09:00:00Z'::timestamptz,'2026-06-07T11:15:00Z'::timestamptz,'2026-09-07T09:00:00Z'::timestamptz,0,'on time'),
  ('Manipal Hospitals','Pune Baner','BU-PNE-06','TUB-M3302','Whitehall','Q1-FY27','re_test_required','C',1.20,3.10,0.880,95,'2026-03-08T08:00:00Z'::timestamptz,'2026-03-08T12:30:00Z'::timestamptz,'2026-06-08T08:00:00Z'::timestamptz,8500,'awaiting retest sweep'),
  ('Max Healthcare','Saket Delhi','BU-DEL-07','TUB-X4401','SilverCross','Q2-FY27','failed','D',2.40,5.50,0.310,420,'2026-06-09T07:00:00Z'::timestamptz,'2026-06-09T14:20:00Z'::timestamptz,'2026-06-23T07:00:00Z'::timestamptz,48000,'tub quarantined, replacement ordered'),
  ('Max Healthcare','Mohali','BU-MOH-08','TUB-X4402','SilverCross','Q2-FY27','passed','B',0.55,1.90,1.220,38,'2026-06-10T08:30:00Z'::timestamptz,'2026-06-10T10:50:00Z'::timestamptz,'2026-09-10T08:30:00Z'::timestamptz,1200,'minor chlorine top-up'),
  ('Narayana Health','Bengaluru HSR','BU-BLR-09','TUB-N5501','Arjo','Q2-FY27','passed','A',0.10,0.80,1.490,9,'2026-06-11T09:00:00Z'::timestamptz,'2026-06-11T10:45:00Z'::timestamptz,'2026-09-11T09:00:00Z'::timestamptz,0,'gold standard'),
  ('Narayana Health','Kolkata Mukundapur','BU-KOL-10','TUB-N5502','Arjo','Q1-FY27','minor_drift','B',0.70,2.10,1.310,33,'2026-03-12T08:30:00Z'::timestamptz,'2026-03-12T11:05:00Z'::timestamptz,'2026-06-12T08:30:00Z'::timestamptz,3000,'jet seal worn'),
  ('AIIMS Burns Wing','New Delhi','BU-DEL-11','TUB-A6601','EWAC','Q2-FY27','passed','A',0.25,1.10,1.470,15,'2026-06-13T07:00:00Z'::timestamptz,'2026-06-13T09:30:00Z'::timestamptz,'2026-09-13T07:00:00Z'::timestamptz,0,'training tub also clean'),
  ('Kokilaben Hospitals','Mumbai Andheri','BU-MUM-12','TUB-K7701','Whitehall','Q2-FY27','major_drift','C',1.70,4.20,0.710,140,'2026-06-14T08:00:00Z'::timestamptz,'2026-06-14T13:10:00Z'::timestamptz,'2026-07-14T08:00:00Z'::timestamptz,18500,'thermostat module swap'),
  ('CMC Vellore','Vellore TN','BU-VLR-13','TUB-C8801','Arjo','Q2-FY27','passed','A',0.18,1.05,1.510,11,'2026-06-15T07:30:00Z'::timestamptz,'2026-06-15T09:50:00Z'::timestamptz,'2026-09-15T07:30:00Z'::timestamptz,0,'academic protocol followed'),
  ('Aster DM','Kochi','BU-KOC-14','TUB-D9901','SilverCross','Q2-FY27','minor_drift','B',0.65,2.00,1.260,46,'2026-06-16T08:00:00Z'::timestamptz,'2026-06-16T10:35:00Z'::timestamptz,'2026-09-16T08:00:00Z'::timestamptz,2200,'pH balance correction'),
  ('Tata Memorial','Mumbai Parel','BU-MUM-15','TUB-T1010','EWAC','Q2-FY27','passed','A',0.22,1.30,1.430,17,'2026-06-17T09:00:00Z'::timestamptz,'2026-06-17T11:20:00Z'::timestamptz,'2026-09-17T09:00:00Z'::timestamptz,0,'oncology burn unit pristine'),
  ('Apollo Burn Network','Chennai Greams Road','BU-CHN-16','TUB-A1144','Arjo','Q2-FY27','failed','quarantined',2.80,6.10,0.180,560,'2026-06-18T07:00:00Z'::timestamptz,'2026-06-18T15:00:00Z'::timestamptz,'2026-06-25T07:00:00Z'::timestamptz,62000,'biofilm in jet line, tub OOS'),
  ('Fortis Trauma','Kolkata Anandapur','BU-KOL-17','TUB-F2203','EWAC','Q2-FY27','passed','B',0.40,1.70,1.290,28,'2026-06-19T08:30:00Z'::timestamptz,'2026-06-19T10:45:00Z'::timestamptz,'2026-09-19T08:30:00Z'::timestamptz,800,'soap dispenser refill'),
  ('Manipal Hospitals','Jaipur','BU-JAI-18','TUB-M3303','Whitehall','Q1-FY27','re_test_required','C',1.30,2.90,0.940,85,'2026-03-20T08:00:00Z'::timestamptz,'2026-03-20T12:00:00Z'::timestamptz,'2026-06-20T08:00:00Z'::timestamptz,7400,'retest overdue'),
  ('Max Healthcare','Patparganj Delhi','BU-DEL-19','TUB-X4403','SilverCross','Q2-FY27','passed','A',0.28,1.25,1.460,19,'2026-06-21T07:30:00Z'::timestamptz,'2026-06-21T09:40:00Z'::timestamptz,'2026-09-21T07:30:00Z'::timestamptz,0,'clean sweep'),
  ('Narayana Health','Ahmedabad','BU-AHM-20','TUB-N5503','Arjo','Q2-FY27','minor_drift','B',0.75,2.30,1.150,52,'2026-06-22T08:00:00Z'::timestamptz,null,'2026-09-22T08:00:00Z'::timestamptz,3600,'completion pending sign-off');

-- =====================================================
-- Table 2: burn_unit_disinfection_findings_r3087
-- =====================================================
create table if not exists public.burn_unit_disinfection_findings_r3087 (
  id uuid primary key default gen_random_uuid(),
  calibration_id uuid references public.burn_unit_tub_calibrations_r3087(id) on delete cascade,
  finding_code text not null,
  severity text not null check (severity in ('info','low','medium','high','critical')),
  category text not null check (category in ('chemistry','microbiology','mechanical','sop_drift','documentation','environmental')),
  description text not null,
  pathogen_detected text check (pathogen_detected in ('none','pseudomonas_aeruginosa','acinetobacter_baumannii','staph_aureus_mrsa','candida_auris','enterococcus_vre','legionella')),
  cfu_per_ml int,
  remediation_owner text not null,
  remediation_due_at timestamptz not null,
  closed_at timestamptz,
  closure_evidence_url text,
  created_at timestamptz not null default now()
);

alter table public.burn_unit_disinfection_findings_r3087 enable row level security;

drop policy if exists burn_unit_disinfection_findings_r3087_founder_select on public.burn_unit_disinfection_findings_r3087;
create policy burn_unit_disinfection_findings_r3087_founder_select on public.burn_unit_disinfection_findings_r3087
  for select to authenticated using (public.is_founder());

revoke all on public.burn_unit_disinfection_findings_r3087 from public, anon;
grant select on public.burn_unit_disinfection_findings_r3087 to authenticated;

insert into public.burn_unit_disinfection_findings_r3087
  (finding_code, severity, category, description, pathogen_detected, cfu_per_ml, remediation_owner, remediation_due_at, closed_at, closure_evidence_url)
values
  ('FND-3087-001','critical','microbiology','Pseudomonas bloom in jet manifold, post-clean swab failed','pseudomonas_aeruginosa',4200,'Chain ICU Lead','2026-06-25T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-002','high','chemistry','Free chlorine 0.18 ppm — below 0.5 minimum','none',null,'Disinfection Tech','2026-06-22T12:00:00Z'::timestamptz,'2026-06-20T15:00:00Z'::timestamptz,'https://docs/r3087/fnd2.pdf'),
  ('FND-3087-003','medium','mechanical','Jet pump impeller worn, 4.8 psi drift','none',null,'Field Engineer','2026-06-30T17:00:00Z'::timestamptz,'2026-06-18T11:00:00Z'::timestamptz,'https://docs/r3087/fnd3.pdf'),
  ('FND-3087-004','low','sop_drift','Nurse skipped temp-log entry on 2 of 14 sessions','none',null,'Burn Unit Charge Nurse','2026-06-28T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-005','info','documentation','Calibration cert filed 1 day late','none',null,'QA Coordinator','2026-06-30T17:00:00Z'::timestamptz,'2026-06-21T10:00:00Z'::timestamptz,'https://docs/r3087/fnd5.pdf'),
  ('FND-3087-006','high','microbiology','Acinetobacter baumannii detected in tub seal','acinetobacter_baumannii',1850,'Infection Control','2026-06-26T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-007','critical','microbiology','Candida auris colonies on drain interior','candida_auris',620,'Chief Microbiologist','2026-06-24T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-008','medium','environmental','Humidity in burn ICU 78% — above 65% spec','none',null,'Facilities','2026-07-02T17:00:00Z'::timestamptz,'2026-06-19T16:00:00Z'::timestamptz,'https://docs/r3087/fnd8.pdf'),
  ('FND-3087-009','low','chemistry','pH drift to 8.4 from 7.6 baseline','none',null,'Disinfection Tech','2026-06-27T17:00:00Z'::timestamptz,'2026-06-20T12:00:00Z'::timestamptz,'https://docs/r3087/fnd9.pdf'),
  ('FND-3087-010','high','mechanical','Temperature probe drift 2.4 C','none',null,'Field Engineer','2026-06-23T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-011','medium','microbiology','MRSA trace on outer rim, not patient-contact zone','staph_aureus_mrsa',45,'Infection Control','2026-06-29T17:00:00Z'::timestamptz,'2026-06-21T14:00:00Z'::timestamptz,'https://docs/r3087/fnd11.pdf'),
  ('FND-3087-012','critical','microbiology','Legionella in supply line — system flush ordered','legionella',280,'Facilities Director','2026-06-24T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-013','low','documentation','Cleaning checklist v3 still in use, v4 mandated','none',null,'QA Coordinator','2026-07-05T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-014','medium','sop_drift','PPE doffing sequence error logged 3x','none',null,'Burn Unit Charge Nurse','2026-07-01T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-015','info','environmental','HEPA filter due in 14 days','none',null,'Facilities','2026-07-08T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-016','high','microbiology','VRE on hydraulic lift control','enterococcus_vre',680,'Infection Control','2026-06-26T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-017','medium','chemistry','ATP swab 180 RLU — threshold 30','none',null,'Disinfection Tech','2026-06-28T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-018','low','mechanical','Drain seal weeping, no contamination yet','none',null,'Field Engineer','2026-07-03T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-019','info','documentation','Audit photos missing for 1 of 20 sites','none',null,'QA Coordinator','2026-07-10T17:00:00Z'::timestamptz,null,null),
  ('FND-3087-020','medium','sop_drift','Calibration interval skipped 1 quarter at Jaipur','none',null,'Chain Compliance Lead','2026-06-30T17:00:00Z'::timestamptz,null,null);

-- =====================================================
-- RPC 1: chain summary
-- =====================================================
create or replace function public.r3087_chain_summary()
returns table (
  chain_name text,
  total_tubs int,
  passed int,
  failed_or_quarantined int,
  major_drift int,
  total_remediation_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      c.chain_name,
      count(*)::int as total_tubs,
      (count(*) filter (where c.calibration_status = 'passed'))::int as passed,
      (count(*) filter (where c.calibration_status = 'failed' or c.disinfection_grade = 'quarantined'))::int as failed_or_quarantined,
      (count(*) filter (where c.calibration_status = 'major_drift'))::int as major_drift,
      coalesce(sum(c.remediation_cost_rupees), 0)::bigint as total_remediation_cost_rupees
    from public.burn_unit_tub_calibrations_r3087 c
    group by c.chain_name
    order by total_remediation_cost_rupees desc;
end;
$$;

revoke all on function public.r3087_chain_summary() from public, anon;
grant execute on function public.r3087_chain_summary() to authenticated;

-- =====================================================
-- RPC 2: failing tubs
-- =====================================================
create or replace function public.r3087_failing_tubs()
returns table (
  tub_asset_tag text,
  chain_name text,
  hospital_branch text,
  calibration_status text,
  disinfection_grade text,
  temperature_drift_celsius numeric,
  jet_pressure_drift_psi numeric,
  next_due_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      c.tub_asset_tag, c.chain_name, c.hospital_branch,
      c.calibration_status, c.disinfection_grade,
      c.temperature_drift_celsius, c.jet_pressure_drift_psi, c.next_due_at
    from public.burn_unit_tub_calibrations_r3087 c
    where c.calibration_status in ('major_drift','failed','re_test_required')
       or c.disinfection_grade in ('C','D','quarantined')
    order by c.next_due_at asc;
end;
$$;

revoke all on function public.r3087_failing_tubs() from public, anon;
grant execute on function public.r3087_failing_tubs() to authenticated;

-- =====================================================
-- RPC 3: pathogen breakdown
-- =====================================================
create or replace function public.r3087_pathogen_breakdown()
returns table (
  pathogen_detected text,
  finding_count int,
  critical_count int,
  open_count int,
  max_cfu int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      f.pathogen_detected,
      count(*)::int as finding_count,
      (count(*) filter (where f.severity = 'critical'))::int as critical_count,
      (count(*) filter (where f.closed_at is null))::int as open_count,
      coalesce(max(f.cfu_per_ml), 0)::int as max_cfu
    from public.burn_unit_disinfection_findings_r3087 f
    where f.pathogen_detected is not null
    group by f.pathogen_detected
    order by critical_count desc, finding_count desc;
end;
$$;

revoke all on function public.r3087_pathogen_breakdown() from public, anon;
grant execute on function public.r3087_pathogen_breakdown() to authenticated;

-- =====================================================
-- RPC 4: open findings
-- =====================================================
create or replace function public.r3087_open_findings()
returns table (
  finding_code text,
  severity text,
  category text,
  description text,
  remediation_owner text,
  remediation_due_at timestamptz,
  days_until_due int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      f.finding_code, f.severity, f.category, f.description,
      f.remediation_owner, f.remediation_due_at,
      extract(day from (f.remediation_due_at - now()))::int as days_until_due
    from public.burn_unit_disinfection_findings_r3087 f
    where f.closed_at is null
    order by
      case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end,
      f.remediation_due_at asc;
end;
$$;

revoke all on function public.r3087_open_findings() from public, anon;
grant execute on function public.r3087_open_findings() to authenticated;

-- =====================================================
-- RPC 5: quarter throughput
-- =====================================================
create or replace function public.r3087_quarter_throughput()
returns table (
  quarter_label text,
  tubs_audited int,
  passed int,
  pass_rate_pct numeric,
  avg_temp_drift numeric,
  avg_chlorine_ppm numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      c.quarter_label,
      count(*)::int as tubs_audited,
      (count(*) filter (where c.calibration_status = 'passed'))::int as passed,
      round(
        (count(*) filter (where c.calibration_status = 'passed'))::numeric * 100.0
        / nullif(count(*), 0)::numeric, 2
      ) as pass_rate_pct,
      round(avg(c.temperature_drift_celsius), 3) as avg_temp_drift,
      round(avg(c.chlorine_residual_ppm), 3) as avg_chlorine_ppm
    from public.burn_unit_tub_calibrations_r3087 c
    group by c.quarter_label
    order by c.quarter_label;
end;
$$;

revoke all on function public.r3087_quarter_throughput() from public, anon;
grant execute on function public.r3087_quarter_throughput() to authenticated;

-- =====================================================
-- RPC 6: branch hotlist
-- =====================================================
create or replace function public.r3087_branch_hotlist()
returns table (
  hospital_branch text,
  chain_name text,
  tub_count int,
  worst_grade text,
  open_critical_findings int,
  next_due_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      c.hospital_branch,
      max(c.chain_name) as chain_name,
      count(*)::int as tub_count,
      max(c.disinfection_grade) as worst_grade,
      (
        select count(*)::int
        from public.burn_unit_disinfection_findings_r3087 ff
        join public.burn_unit_tub_calibrations_r3087 cc on cc.id = ff.calibration_id
        where cc.hospital_branch = c.hospital_branch
          and ff.severity = 'critical'
          and ff.closed_at is null
      ) as open_critical_findings,
      min(c.next_due_at) as next_due_at
    from public.burn_unit_tub_calibrations_r3087 c
    group by c.hospital_branch
    order by open_critical_findings desc, next_due_at asc;
end;
$$;

revoke all on function public.r3087_branch_hotlist() from public, anon;
grant execute on function public.r3087_branch_hotlist() to authenticated;

-- =====================================================
-- RPC 7: severity rollup
-- =====================================================
create or replace function public.r3087_severity_rollup()
returns table (
  severity text,
  total int,
  open_count int,
  closed_count int,
  oldest_open_due timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
    select
      f.severity,
      count(*)::int as total,
      (count(*) filter (where f.closed_at is null))::int as open_count,
      (count(*) filter (where f.closed_at is not null))::int as closed_count,
      min(f.remediation_due_at) filter (where f.closed_at is null) as oldest_open_due
    from public.burn_unit_disinfection_findings_r3087 f
    group by f.severity
    order by
      case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end;
$$;

revoke all on function public.r3087_severity_rollup() from public, anon;
grant execute on function public.r3087_severity_rollup() to authenticated;
