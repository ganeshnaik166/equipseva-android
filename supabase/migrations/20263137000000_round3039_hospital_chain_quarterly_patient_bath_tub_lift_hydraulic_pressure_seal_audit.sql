-- Round r3039 — Hospital Chain Quarterly Patient-Bath Tub Lift Hydraulic Pressure & Seal Audit
-- HEAVY ★★★★

set local statement_timeout = '120s';

-- =====================================================================
-- TABLE 1: bath_lift_hydraulic_audits_r3039
-- =====================================================================
create table if not exists public.bath_lift_hydraulic_audits_r3039 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  hospital_site text not null,
  lift_asset_tag text not null,
  ward_zone text not null check (ward_zone in ('icu','ortho','geriatric','rehab','burns','maternity','palliative','general')),
  quarter_label text not null check (quarter_label in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4','2027-Q1')),
  audit_date date not null,
  rated_pressure_bar numeric(6,2) not null check (rated_pressure_bar between 50 and 250),
  measured_pressure_bar numeric(6,2) not null check (measured_pressure_bar between 0 and 300),
  pressure_drop_pct numeric(5,2) not null check (pressure_drop_pct between -50 and 100),
  seal_condition text not null check (seal_condition in ('intact','weeping','cracked','sheared','replaced')),
  cylinder_creep_mm numeric(6,2) not null check (cylinder_creep_mm between 0 and 50),
  fluid_grade text not null check (fluid_grade in ('iso_vg32','iso_vg46','iso_vg68','bio_synthetic')),
  fluid_ph numeric(4,2) not null check (fluid_ph between 4 and 10),
  patient_load_capacity_kg int not null check (patient_load_capacity_kg between 100 and 400),
  verdict text not null check (verdict in ('pass','watch','remediate','condemn')),
  remediation_cost_rupees int not null default 0 check (remediation_cost_rupees between 0 and 5000000),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bath_lift_hydraulic_audits_r3039 enable row level security;

drop policy if exists r3039_audits_founder_select on public.bath_lift_hydraulic_audits_r3039;
create policy r3039_audits_founder_select on public.bath_lift_hydraulic_audits_r3039
  for select using (public.is_founder());

revoke all on public.bath_lift_hydraulic_audits_r3039 from public, anon;
grant select on public.bath_lift_hydraulic_audits_r3039 to authenticated;

insert into public.bath_lift_hydraulic_audits_r3039
  (chain_code, hospital_site, lift_asset_tag, ward_zone, quarter_label, audit_date,
   rated_pressure_bar, measured_pressure_bar, pressure_drop_pct, seal_condition,
   cylinder_creep_mm, fluid_grade, fluid_ph, patient_load_capacity_kg, verdict,
   remediation_cost_rupees, notes)
values
  ('APOLLO','Apollo Hyderabad Jubilee Hills','BL-AP-JH-014','icu','2026-Q2','2026-04-12'::date,160,158.40,1.00,'intact',0.40,'iso_vg46',7.10,250,'pass',0,'Steady baseline; seal kit last replaced 2025-11'),
  ('APOLLO','Apollo Chennai Greams Road','BL-AP-CH-022','ortho','2026-Q2','2026-04-15'::date,160,144.20,9.88,'weeping',1.80,'iso_vg46',6.40,250,'watch',18500,'Static-side weep at gland; tighten + monitor 30d'),
  ('FORTIS','Fortis Bangalore Bannerghatta','BL-FR-BG-031','geriatric','2026-Q2','2026-04-18'::date,140,108.50,22.50,'cracked',4.20,'iso_vg32',5.90,200,'remediate',82000,'Rod seal cracked; sched downtime Q2 wk-10'),
  ('FORTIS','Fortis Mumbai Mulund','BL-FR-MU-007','rehab','2026-Q2','2026-04-22'::date,180,176.40,2.00,'intact',0.20,'iso_vg68',7.30,300,'pass',0,'Heavy-duty rehab unit; nominal'),
  ('MANIPAL','Manipal Bangalore Old Airport','BL-MN-BL-019','burns','2026-Q2','2026-04-25'::date,200,142.00,29.00,'sheared',9.80,'iso_vg46',5.10,300,'condemn',420000,'Catastrophic seal shear; lift removed from service same-day'),
  ('MANIPAL','Manipal Jaipur Sirsi Road','BL-MN-JP-004','maternity','2026-Q2','2026-04-28'::date,140,138.60,1.00,'intact',0.30,'iso_vg32',7.00,200,'pass',0,'Quiet operation; clean inspection'),
  ('MAX','Max Saket New Delhi','BL-MX-SK-011','palliative','2026-Q2','2026-05-02'::date,160,151.20,5.50,'weeping',1.10,'iso_vg46',6.80,250,'watch',12200,'Minor drift, hospital chain wants quarterly reseal'),
  ('MAX','Max Patparganj East Delhi','BL-MX-PP-025','general','2026-Q2','2026-05-05'::date,140,112.00,20.00,'cracked',3.60,'iso_vg32',5.80,200,'remediate',74500,'Seal replaced; retest scheduled Q3'),
  ('AIIMS','AIIMS New Delhi Trauma Block','BL-AI-DL-002','icu','2026-Q2','2026-05-08'::date,200,196.00,2.00,'intact',0.15,'bio_synthetic',7.40,400,'pass',0,'Bio-synthetic baseline'),
  ('AIIMS','AIIMS Bhubaneswar','BL-AI-BH-016','ortho','2026-Q2','2026-05-12'::date,160,128.00,20.00,'cracked',4.50,'iso_vg46',6.10,250,'remediate',88000,'Rod gland scoring; cylinder hone + new seal'),
  ('NARAYANA','Narayana Bangalore Bommasandra','BL-NA-BL-009','rehab','2026-Q2','2026-05-15'::date,180,165.60,8.00,'weeping',2.10,'iso_vg68',6.60,300,'watch',19800,'Heat-cycle weep; monitor'),
  ('NARAYANA','Narayana Kolkata RTIICS','BL-NA-KO-013','geriatric','2026-Q2','2026-05-18'::date,140,98.00,30.00,'sheared',11.40,'iso_vg32',4.80,200,'condemn',390000,'Fluid degraded; full assembly replacement'),
  ('KIMS','KIMS Secunderabad','BL-KM-SE-006','burns','2026-Q2','2026-05-22'::date,200,194.00,3.00,'intact',0.50,'bio_synthetic',7.20,400,'pass',0,'Burns ward; bio-synthetic mandatory'),
  ('KIMS','KIMS Kondapur Hyderabad','BL-KM-KO-018','icu','2026-Q3','2026-07-06'::date,160,155.20,3.00,'intact',0.60,'iso_vg46',7.05,250,'pass',0,'Q3 baseline; nominal'),
  ('YASHODA','Yashoda Somajiguda Hyderabad','BL-YA-SO-021','general','2026-Q3','2026-07-09'::date,140,124.60,11.00,'weeping',2.40,'iso_vg32',6.30,200,'watch',16400,'Seal kit on order'),
  ('YASHODA','Yashoda Malakpet Hyderabad','BL-YA-MA-027','palliative','2026-Q3','2026-07-12'::date,160,116.80,27.00,'cracked',5.10,'iso_vg46',5.70,250,'remediate',96000,'Cracked end-cap seal; replaced same week'),
  ('MEDANTA','Medanta Gurugram','BL-MD-GU-005','ortho','2026-Q3','2026-07-15'::date,180,172.80,4.00,'intact',0.40,'iso_vg68',7.15,300,'pass',0,'Ortho heavy unit; clean'),
  ('MEDANTA','Medanta Lucknow','BL-MD-LK-012','maternity','2026-Q3','2026-07-19'::date,140,132.30,5.50,'weeping',1.20,'iso_vg32',6.70,200,'watch',13900,'Marginal seal weep'),
  ('COLUMBIA','Columbia Asia Whitefield','BL-CO-WH-010','rehab','2026-Q3','2026-07-22'::date,180,124.20,31.00,'sheared',12.60,'iso_vg68',4.50,300,'condemn',445000,'Hydraulic fluid contaminated; complete rebuild'),
  ('COLUMBIA','Columbia Asia Hebbal','BL-CO-HE-024','geriatric','2026-Q3','2026-07-25'::date,140,114.80,18.00,'cracked',3.90,'iso_vg32',5.95,200,'remediate',78500,'Seal cracked; rod re-chromed'),
  ('RAINBOW','Rainbow Children Hyderabad','BL-RB-HY-003','maternity','2026-Q3','2026-07-29'::date,140,138.60,1.00,'intact',0.20,'bio_synthetic',7.30,200,'pass',0,'Pediatric ward; bio-synthetic'),
  ('RAINBOW','Rainbow Children Bangalore','BL-RB-BL-028','icu','2026-Q3','2026-08-02'::date,160,146.40,8.50,'weeping',1.90,'iso_vg46',6.50,250,'watch',17200,'NICU lift; cautious watch'),
  ('CARE','Care Banjara Hills Hyderabad','BL-CA-BA-017','burns','2026-Q3','2026-08-05'::date,200,118.00,41.00,'sheared',14.20,'iso_vg46',4.20,300,'condemn',478000,'Severe contamination; chain incident report filed'),
  ('CARE','Care Hi-Tech City Hyderabad','BL-CA-HT-020','general','2026-Q3','2026-08-08'::date,140,134.40,4.00,'intact',0.50,'iso_vg32',7.00,200,'pass',0,'General ward; nominal'),
  ('RELIANCE','Reliance Foundation Mumbai','BL-RE-MU-008','palliative','2026-Q3','2026-08-12'::date,160,148.80,7.00,'weeping',1.50,'bio_synthetic',6.85,250,'watch',14800,'Reseal scheduled Q4'),
  ('RELIANCE','Reliance Foundation Navi Mumbai','BL-RE-NV-026','ortho','2026-Q3','2026-08-15'::date,180,144.00,20.00,'cracked',4.80,'iso_vg68',5.85,300,'remediate',92400,'Cylinder hone + seal kit installed');

-- =====================================================================
-- TABLE 2: bath_lift_remediation_workorders_r3039
-- =====================================================================
create table if not exists public.bath_lift_remediation_workorders_r3039 (
  id uuid primary key default gen_random_uuid(),
  audit_asset_tag text not null,
  chain_code text not null,
  workorder_ref text not null,
  raised_on date not null,
  scheduled_on date,
  closed_on date,
  remediation_type text not null check (remediation_type in ('seal_replace','cylinder_hone','full_assembly','fluid_flush','rod_rechrome','recommission')),
  technician_grade text not null check (technician_grade in ('L1','L2','L3','OEM','external')),
  parts_cost_rupees int not null default 0 check (parts_cost_rupees between 0 and 4000000),
  labour_cost_rupees int not null default 0 check (labour_cost_rupees between 0 and 800000),
  downtime_hours numeric(6,2) not null default 0 check (downtime_hours between 0 and 720),
  retest_pressure_bar numeric(6,2) check (retest_pressure_bar between 0 and 300),
  retest_verdict text check (retest_verdict in ('pass','retry','escalate','pending')),
  status text not null check (status in ('open','scheduled','in_progress','retest','closed','escalated')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bath_lift_remediation_workorders_r3039 enable row level security;

drop policy if exists r3039_wo_founder_select on public.bath_lift_remediation_workorders_r3039;
create policy r3039_wo_founder_select on public.bath_lift_remediation_workorders_r3039
  for select using (public.is_founder());

revoke all on public.bath_lift_remediation_workorders_r3039 from public, anon;
grant select on public.bath_lift_remediation_workorders_r3039 to authenticated;

insert into public.bath_lift_remediation_workorders_r3039
  (audit_asset_tag, chain_code, workorder_ref, raised_on, scheduled_on, closed_on,
   remediation_type, technician_grade, parts_cost_rupees, labour_cost_rupees,
   downtime_hours, retest_pressure_bar, retest_verdict, status, notes)
values
  ('BL-AP-CH-022','APOLLO','WO-AP-2026-0412','2026-04-15'::date,'2026-04-22'::date,'2026-04-22'::date,'seal_replace','L2',12500,6000,4.5,156.80,'pass','closed','Gland reseal; in-house team'),
  ('BL-FR-BG-031','FORTIS','WO-FR-2026-0418','2026-04-18'::date,'2026-05-04'::date,'2026-05-06'::date,'cylinder_hone','L3',58000,24000,18.0,138.40,'pass','closed','Hone + new seals; bench-tested'),
  ('BL-FR-MU-007','FORTIS','WO-FR-2026-0501','2026-04-22'::date,null,null,'fluid_flush','L1',2400,1200,1.5,null,null,'open','Preventive flush scheduled Q3'),
  ('BL-MN-BL-019','MANIPAL','WO-MN-2026-0425','2026-04-25'::date,'2026-05-02'::date,null,'full_assembly','OEM',360000,60000,96.0,null,'pending','retest','OEM rebuild; awaiting load test'),
  ('BL-MX-SK-011','MAX','WO-MX-2026-0502','2026-05-02'::date,'2026-05-09'::date,'2026-05-10'::date,'seal_replace','L2',8800,3400,3.0,150.20,'pass','closed','Quarterly reseal commitment'),
  ('BL-MX-PP-025','MAX','WO-MX-2026-0505','2026-05-05'::date,'2026-05-12'::date,'2026-05-14'::date,'rod_rechrome','external',52000,22500,36.0,136.80,'pass','closed','External vendor rechrome; cleared'),
  ('BL-AI-BH-016','AIIMS','WO-AI-2026-0512','2026-05-12'::date,'2026-05-20'::date,null,'cylinder_hone','OEM',64000,24000,24.0,null,'retry','retest','First retest failed; second attempt scheduled'),
  ('BL-NA-BL-009','NARAYANA','WO-NA-2026-0515','2026-05-15'::date,'2026-05-29'::date,'2026-05-30'::date,'seal_replace','L2',13800,5800,5.0,166.40,'pass','closed','Heat-cycle reseal'),
  ('BL-NA-KO-013','NARAYANA','WO-NA-2026-0518','2026-05-18'::date,'2026-06-03'::date,null,'full_assembly','OEM',324000,66000,108.0,null,'pending','in_progress','Contaminated fluid; full strip-rebuild'),
  ('BL-YA-SO-021','YASHODA','WO-YA-2026-0709','2026-07-09'::date,'2026-07-18'::date,'2026-07-19'::date,'seal_replace','L1',11200,4800,4.0,132.40,'pass','closed','Routine reseal'),
  ('BL-YA-MA-027','YASHODA','WO-YA-2026-0712','2026-07-12'::date,'2026-07-21'::date,'2026-07-23'::date,'cylinder_hone','L3',62000,28000,20.0,155.20,'pass','closed','End-cap honed'),
  ('BL-MD-LK-012','MEDANTA','WO-MD-2026-0719','2026-07-19'::date,null,null,'seal_replace','L2',9400,4200,3.5,null,null,'scheduled','Booked for Q3 wk-8'),
  ('BL-CO-WH-010','COLUMBIA','WO-CO-2026-0722','2026-07-22'::date,'2026-08-12'::date,null,'full_assembly','OEM',378000,67000,144.0,null,'pending','in_progress','Contamination rebuild — chain-level escalation'),
  ('BL-CO-HE-024','COLUMBIA','WO-CO-2026-0725','2026-07-25'::date,'2026-08-04'::date,'2026-08-06'::date,'rod_rechrome','external',54000,24500,40.0,138.20,'pass','closed','External rechrome; passed retest'),
  ('BL-CA-BA-017','CARE','WO-CA-2026-0805','2026-08-05'::date,'2026-08-25'::date,null,'full_assembly','OEM',408000,70000,160.0,null,'escalate','escalated','Chain-level incident; safety review triggered'),
  ('BL-RE-MU-008','RELIANCE','WO-RE-2026-0812','2026-08-12'::date,null,null,'seal_replace','L2',10200,4400,3.5,null,null,'open','Q4 reseal queued'),
  ('BL-RE-NV-026','RELIANCE','WO-RE-2026-0815','2026-08-15'::date,'2026-08-26'::date,'2026-08-28'::date,'cylinder_hone','L3',60000,32400,22.0,148.40,'pass','closed','Hone + seal kit'),
  ('BL-RB-BL-028','RAINBOW','WO-RB-2026-0802','2026-08-02'::date,'2026-08-10'::date,'2026-08-10'::date,'recommission','L1',2200,1800,1.5,148.60,'pass','closed','NICU recommission inspection');

-- =====================================================================
-- RPC 1 — chain rollup
-- =====================================================================
create or replace function public.r3039_chain_rollup()
returns table(
  chain_code text,
  audits_total int,
  passes int,
  watches int,
  remediates int,
  condemns int,
  avg_pressure_drop_pct numeric,
  remediation_cost_total_rupees bigint
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
    a.chain_code,
    count(*)::int as audits_total,
    (count(*) filter (where a.verdict = 'pass'))::int as passes,
    (count(*) filter (where a.verdict = 'watch'))::int as watches,
    (count(*) filter (where a.verdict = 'remediate'))::int as remediates,
    (count(*) filter (where a.verdict = 'condemn'))::int as condemns,
    round(avg(a.pressure_drop_pct)::numeric, 2) as avg_pressure_drop_pct,
    sum(a.remediation_cost_rupees)::bigint as remediation_cost_total_rupees
  from public.bath_lift_hydraulic_audits_r3039 a
  group by a.chain_code
  order by remediation_cost_total_rupees desc, a.chain_code;
end;
$$;

revoke all on function public.r3039_chain_rollup() from public, anon;
grant execute on function public.r3039_chain_rollup() to authenticated;

-- =====================================================================
-- RPC 2 — condemnation list
-- =====================================================================
create or replace function public.r3039_condemnation_list()
returns table(
  hospital_site text,
  chain_code text,
  lift_asset_tag text,
  ward_zone text,
  audit_date date,
  pressure_drop_pct numeric,
  cylinder_creep_mm numeric,
  remediation_cost_rupees int
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
  select a.hospital_site, a.chain_code, a.lift_asset_tag, a.ward_zone,
         a.audit_date, a.pressure_drop_pct, a.cylinder_creep_mm, a.remediation_cost_rupees
  from public.bath_lift_hydraulic_audits_r3039 a
  where a.verdict = 'condemn'
  order by a.remediation_cost_rupees desc;
end;
$$;

revoke all on function public.r3039_condemnation_list() from public, anon;
grant execute on function public.r3039_condemnation_list() to authenticated;

-- =====================================================================
-- RPC 3 — ward zone risk
-- =====================================================================
create or replace function public.r3039_ward_zone_risk()
returns table(
  ward_zone text,
  audits int,
  avg_pressure_drop_pct numeric,
  avg_creep_mm numeric,
  high_risk_count int
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
    a.ward_zone,
    count(*)::int as audits,
    round(avg(a.pressure_drop_pct)::numeric,2) as avg_pressure_drop_pct,
    round(avg(a.cylinder_creep_mm)::numeric,2) as avg_creep_mm,
    (count(*) filter (where a.verdict in ('remediate','condemn')))::int as high_risk_count
  from public.bath_lift_hydraulic_audits_r3039 a
  group by a.ward_zone
  order by high_risk_count desc, a.ward_zone;
end;
$$;

revoke all on function public.r3039_ward_zone_risk() from public, anon;
grant execute on function public.r3039_ward_zone_risk() to authenticated;

-- =====================================================================
-- RPC 4 — workorder status board
-- =====================================================================
create or replace function public.r3039_workorder_status_board()
returns table(
  status text,
  workorders int,
  total_parts_cost_rupees bigint,
  total_labour_cost_rupees bigint,
  total_downtime_hours numeric
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
  select w.status,
         count(*)::int as workorders,
         sum(w.parts_cost_rupees)::bigint as total_parts_cost_rupees,
         sum(w.labour_cost_rupees)::bigint as total_labour_cost_rupees,
         round(sum(w.downtime_hours)::numeric,2) as total_downtime_hours
  from public.bath_lift_remediation_workorders_r3039 w
  group by w.status
  order by total_parts_cost_rupees desc, w.status;
end;
$$;

revoke all on function public.r3039_workorder_status_board() from public, anon;
grant execute on function public.r3039_workorder_status_board() to authenticated;

-- =====================================================================
-- RPC 5 — fluid grade performance
-- =====================================================================
create or replace function public.r3039_fluid_grade_performance()
returns table(
  fluid_grade text,
  audits int,
  avg_pressure_drop_pct numeric,
  avg_ph numeric,
  pass_rate_pct numeric
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
  select a.fluid_grade,
         count(*)::int as audits,
         round(avg(a.pressure_drop_pct)::numeric,2) as avg_pressure_drop_pct,
         round(avg(a.fluid_ph)::numeric,2) as avg_ph,
         round((100.0 * (count(*) filter (where a.verdict = 'pass'))::numeric / nullif(count(*),0))::numeric,2) as pass_rate_pct
  from public.bath_lift_hydraulic_audits_r3039 a
  group by a.fluid_grade
  order by pass_rate_pct desc, a.fluid_grade;
end;
$$;

revoke all on function public.r3039_fluid_grade_performance() from public, anon;
grant execute on function public.r3039_fluid_grade_performance() to authenticated;

-- =====================================================================
-- RPC 6 — quarter trend
-- =====================================================================
create or replace function public.r3039_quarter_trend()
returns table(
  quarter_label text,
  audits int,
  condemns int,
  remediates int,
  avg_pressure_drop_pct numeric,
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
  select a.quarter_label,
         count(*)::int as audits,
         (count(*) filter (where a.verdict = 'condemn'))::int as condemns,
         (count(*) filter (where a.verdict = 'remediate'))::int as remediates,
         round(avg(a.pressure_drop_pct)::numeric,2) as avg_pressure_drop_pct,
         sum(a.remediation_cost_rupees)::bigint as total_remediation_cost_rupees
  from public.bath_lift_hydraulic_audits_r3039 a
  group by a.quarter_label
  order by a.quarter_label;
end;
$$;

revoke all on function public.r3039_quarter_trend() from public, anon;
grant execute on function public.r3039_quarter_trend() to authenticated;

-- =====================================================================
-- RPC 7 — open escalations
-- =====================================================================
create or replace function public.r3039_open_escalations()
returns table(
  workorder_ref text,
  chain_code text,
  audit_asset_tag text,
  remediation_type text,
  status text,
  raised_on date,
  parts_cost_rupees int,
  downtime_hours numeric
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
  select w.workorder_ref, w.chain_code, w.audit_asset_tag, w.remediation_type,
         w.status, w.raised_on, w.parts_cost_rupees, w.downtime_hours
  from public.bath_lift_remediation_workorders_r3039 w
  where w.status in ('open','scheduled','in_progress','retest','escalated')
  order by w.parts_cost_rupees desc, w.raised_on;
end;
$$;

revoke all on function public.r3039_open_escalations() from public, anon;
grant execute on function public.r3039_open_escalations() to authenticated;

-- =====================================================================
-- RPC 8 — closure efficiency
-- =====================================================================
create or replace function public.r3039_closure_efficiency()
returns table(
  technician_grade text,
  closed_workorders int,
  avg_days_to_close numeric,
  avg_downtime_hours numeric,
  total_labour_cost_rupees bigint
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
  select w.technician_grade,
         (count(*) filter (where w.status = 'closed'))::int as closed_workorders,
         round(avg(extract(epoch from (w.closed_on::timestamptz - w.raised_on::timestamptz))/86400.0)::numeric,2) as avg_days_to_close,
         round(avg(w.downtime_hours)::numeric,2) as avg_downtime_hours,
         sum(w.labour_cost_rupees)::bigint as total_labour_cost_rupees
  from public.bath_lift_remediation_workorders_r3039 w
  where w.status = 'closed'
  group by w.technician_grade
  order by avg_days_to_close, w.technician_grade;
end;
$$;

revoke all on function public.r3039_closure_efficiency() from public, anon;
grant execute on function public.r3039_closure_efficiency() to authenticated;
