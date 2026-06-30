-- Round 3128: Customer Hospital MRI Scanner Quench Helium Boil-Off Cryogen Field-Stability Audit
-- Quarterly MRI cryogen audit tracking: helium level, boil-off rate, field stability (ppm),
-- ramp events, quench risk, cryogen-supplier SLA, and CAPA workflow.

create extension if not exists pgcrypto;

-- ==========================================================================
-- TABLE 1: mri_cryogen_audits_r3128
-- One row per quarterly cryogen audit per MRI scanner per hospital.
-- ==========================================================================
create table if not exists public.mri_cryogen_audits_r3128 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  city text not null,
  scanner_model text not null,
  scanner_serial text not null,
  field_strength_tesla numeric(3,1) not null check (field_strength_tesla in (1.5, 3.0, 7.0)),
  install_year integer not null check (install_year between 2005 and 2030),
  magnet_type text not null check (magnet_type in ('superconducting_helium_bath','zero_boil_off','sealed_magnet','dry_magnet')),
  audit_quarter text not null check (audit_quarter in ('2025-Q4','2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  audit_date date not null,
  helium_level_pct numeric(5,2) not null check (helium_level_pct between 0 and 100),
  helium_fill_threshold_pct numeric(5,2) not null check (helium_fill_threshold_pct between 0 and 100),
  helium_boil_off_lph numeric(6,3) not null check (helium_boil_off_lph between 0 and 100),
  field_stability_ppm numeric(6,3) not null check (field_stability_ppm between 0 and 50),
  field_stability_spec_ppm numeric(6,3) not null check (field_stability_spec_ppm between 0 and 50),
  ramp_events_last_year integer not null check (ramp_events_last_year between 0 and 20),
  quench_events_lifetime integer not null check (quench_events_lifetime between 0 and 10),
  cold_head_runtime_hours integer not null check (cold_head_runtime_hours between 0 and 200000),
  cold_head_replacement_due_hours integer not null check (cold_head_replacement_due_hours between 0 and 200000),
  shield_temp_kelvin numeric(5,2) not null check (shield_temp_kelvin between 0 and 300),
  vacuum_pressure_mbar numeric(8,5) not null check (vacuum_pressure_mbar between 0 and 1),
  quench_risk_score numeric(4,2) not null check (quench_risk_score between 0 and 10),
  risk_band text not null check (risk_band in ('low','moderate','elevated','high','critical')),
  capa_status text not null check (capa_status in ('not_required','open','in_progress','verified','closed','overdue')),
  audit_outcome text not null check (audit_outcome in ('pass','pass_with_observation','conditional','fail','escalate_oem')),
  next_audit_due_date date not null,
  field_engineer_id uuid references public.engineers(id) on delete set null,
  audited_by_profile uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_cryo_audit_r3128_org on public.mri_cryogen_audits_r3128(organization_id);
create index if not exists idx_cryo_audit_r3128_qtr on public.mri_cryogen_audits_r3128(audit_quarter);
create index if not exists idx_cryo_audit_r3128_band on public.mri_cryogen_audits_r3128(risk_band);
create index if not exists idx_cryo_audit_r3128_outcome on public.mri_cryogen_audits_r3128(audit_outcome);

alter table public.mri_cryogen_audits_r3128 enable row level security;

-- ==========================================================================
-- TABLE 2: mri_cryogen_supplier_sla_r3128
-- Helium / cryogen supplier SLA tracking tied to a parent audit.
-- ==========================================================================
create table if not exists public.mri_cryogen_supplier_sla_r3128 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.mri_cryogen_audits_r3128(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  supplier_city text not null,
  cryogen_type text not null check (cryogen_type in ('liquid_helium','liquid_nitrogen','helium_gas_purge','mixed_cryogen')),
  contract_tier text not null check (contract_tier in ('platinum','gold','silver','bronze','spot_buy')),
  sla_response_hours integer not null check (sla_response_hours between 1 and 240),
  actual_response_hours integer not null check (actual_response_hours between 0 and 720),
  delivery_window_days integer not null check (delivery_window_days between 1 and 60),
  actual_delivery_days integer not null check (actual_delivery_days between 0 and 120),
  quoted_price_per_litre_rupees numeric(10,2) not null check (quoted_price_per_litre_rupees between 0 and 50000),
  delivered_litres numeric(8,2) not null check (delivered_litres between 0 and 5000),
  purity_pct numeric(5,3) not null check (purity_pct between 0 and 100),
  purity_spec_pct numeric(5,3) not null check (purity_spec_pct between 0 and 100),
  sla_breach text not null check (sla_breach in ('none','minor','material','severe','terminated')),
  penalty_levied_rupees integer not null check (penalty_levied_rupees between 0 and 5000000),
  next_fill_scheduled date,
  supplier_rating numeric(3,2) not null check (supplier_rating between 0 and 5),
  remediation_status text not null check (remediation_status in ('not_required','planned','in_progress','completed','escalated')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_cryo_sla_r3128_audit on public.mri_cryogen_supplier_sla_r3128(audit_id);
create index if not exists idx_cryo_sla_r3128_tier on public.mri_cryogen_supplier_sla_r3128(contract_tier);
create index if not exists idx_cryo_sla_r3128_breach on public.mri_cryogen_supplier_sla_r3128(sla_breach);

alter table public.mri_cryogen_supplier_sla_r3128 enable row level security;

-- ==========================================================================
-- SEED DATA — 12+ rows across both tables
-- ==========================================================================
do $seed$
declare
  v_org uuid;
  v_audit_ids uuid[];
  v_a1 uuid; v_a2 uuid; v_a3 uuid; v_a4 uuid;
  v_a5 uuid; v_a6 uuid; v_a7 uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  if v_org is null then
    return;
  end if;

  insert into public.mri_cryogen_audits_r3128 (
    organization_id, hospital_name, city, scanner_model, scanner_serial, field_strength_tesla,
    install_year, magnet_type, audit_quarter, audit_date, helium_level_pct,
    helium_fill_threshold_pct, helium_boil_off_lph, field_stability_ppm, field_stability_spec_ppm,
    ramp_events_last_year, quench_events_lifetime, cold_head_runtime_hours,
    cold_head_replacement_due_hours, shield_temp_kelvin, vacuum_pressure_mbar,
    quench_risk_score, risk_band, capa_status, audit_outcome, next_audit_due_date, notes
  ) values
    (v_org, 'Apollo Hospitals Jubilee Hills', 'Hyderabad', 'Siemens Magnetom Aera', 'SMA-JH-2019-014',
     1.5, 2019, 'superconducting_helium_bath', '2026-Q2', '2026-04-12', 88.40,
     70.00, 0.045, 0.180, 0.250, 2, 0, 18420, 25000, 45.20, 0.00010,
     2.30, 'low', 'not_required', 'pass', '2026-07-12',
     '1.5T running clean; boil-off well within Siemens spec.'),
    (v_org, 'Manipal Hospital Whitefield', 'Bangalore', 'GE Signa Pioneer 3.0T', 'GE-WHF-2017-007',
     3.0, 2017, 'zero_boil_off', '2026-Q2', '2026-04-18', 96.10,
     85.00, 0.005, 0.090, 0.150, 1, 0, 24105, 30000, 42.10, 0.00008,
     1.40, 'low', 'not_required', 'pass', '2026-07-18',
     'ZBO unit; ColdHead nominal.'),
    (v_org, 'Fortis Memorial Research Institute', 'Gurugram', 'Philips Ingenia 3.0T', 'PHI-FMR-2016-003',
     3.0, 2016, 'superconducting_helium_bath', '2026-Q1', '2026-02-22', 62.30,
     65.00, 0.380, 0.420, 0.300, 4, 1, 32480, 30000, 51.80, 0.00045,
     6.80, 'elevated', 'in_progress', 'conditional', '2026-05-22',
     'Boil-off above spec; cold head past replacement window; quench-prone.'),
    (v_org, 'St John''s Medical College Hospital', 'Bangalore', 'Siemens Magnetom Skyra 3.0T', 'SMS-SJM-2018-021',
     3.0, 2018, 'superconducting_helium_bath', '2026-Q2', '2026-05-03', 78.50,
     70.00, 0.120, 0.220, 0.250, 3, 0, 21380, 28000, 46.50, 0.00015,
     3.10, 'moderate', 'open', 'pass_with_observation', '2026-08-03',
     'Stability drift trending up; schedule shim service.'),
    (v_org, 'AIIMS New Delhi MRI Suite C', 'New Delhi', 'GE Discovery MR750w', 'GE-AIIMS-2015-002',
     3.0, 2015, 'superconducting_helium_bath', '2026-Q1', '2026-03-08', 42.10,
     60.00, 0.620, 0.510, 0.300, 6, 2, 41250, 35000, 58.40, 0.00080,
     8.90, 'critical', 'overdue', 'fail', '2026-04-08',
     'Critical: helium at 42%; two prior quenches; cold head 41250h vs 35000h spec; immediate fill + cold head swap required.'),
    (v_org, 'Tata Memorial Hospital Imaging', 'Mumbai', 'Siemens Magnetom Vida 3.0T', 'SMV-TMH-2021-029',
     3.0, 2021, 'zero_boil_off', '2026-Q3', '2026-07-15', 94.80,
     85.00, 0.008, 0.110, 0.150, 0, 0, 9820, 30000, 41.50, 0.00006,
     1.10, 'low', 'not_required', 'pass', '2026-10-15',
     'ZBO performing to spec; quietest scanner in fleet.'),
    (v_org, 'CMC Vellore Radiology Block', 'Vellore', 'Philips Achieva 1.5T', 'PHI-CMC-2014-018',
     1.5, 2014, 'superconducting_helium_bath', '2026-Q1', '2026-01-30', 55.20,
     70.00, 0.280, 0.340, 0.300, 5, 1, 36780, 32000, 49.10, 0.00038,
     5.70, 'elevated', 'in_progress', 'conditional', '2026-04-30',
     '12-year-old magnet; boil-off elevated; CAPA: fill + vacuum service Q2.'),
    (v_org, 'Kokilaben Dhirubhai Ambani Hospital', 'Mumbai', 'GE Signa Premier 3.0T', 'GE-KDA-2022-031',
     3.0, 2022, 'zero_boil_off', '2026-Q3', '2026-08-02', 97.30,
     85.00, 0.004, 0.080, 0.150, 0, 0, 6210, 30000, 40.80, 0.00005,
     0.90, 'low', 'not_required', 'pass', '2026-11-02',
     'Brand new ZBO; baseline established.'),
    (v_org, 'Medanta The Medicity', 'Gurugram', 'Siemens Magnetom Prisma 3.0T', 'SMP-MED-2020-024',
     3.0, 2020, 'superconducting_helium_bath', '2026-Q2', '2026-06-11', 81.60,
     70.00, 0.090, 0.190, 0.250, 1, 0, 15630, 28000, 44.20, 0.00012,
     2.60, 'low', 'not_required', 'pass', '2026-09-11',
     'Research-grade Prisma; tight stability.'),
    (v_org, 'KIMS Hospital Secunderabad', 'Hyderabad', 'Philips Ingenia Ambition 1.5T', 'PHI-KIM-2019-016',
     1.5, 2019, 'sealed_magnet', '2026-Q2', '2026-05-20', 99.10,
     90.00, 0.002, 0.150, 0.250, 0, 0, 14250, 40000, 43.50, 0.00007,
     1.20, 'low', 'not_required', 'pass', '2026-08-20',
     'Sealed Ambition magnet; near zero helium loss.'),
    (v_org, 'PGI Chandigarh MRI Wing', 'Chandigarh', 'GE Signa HDxt 1.5T', 'GE-PGI-2012-001',
     1.5, 2012, 'superconducting_helium_bath', '2026-Q1', '2026-02-05', 48.30,
     65.00, 0.510, 0.460, 0.300, 7, 3, 48920, 32000, 56.20, 0.00065,
     8.20, 'high', 'overdue', 'escalate_oem', '2026-05-05',
     'OEM escalation: 14-year-old magnet, three lifetime quenches, runtime well past cold-head spec.'),
    (v_org, 'Narayana Health City Cardiac MRI', 'Bangalore', 'Siemens Magnetom Sola 1.5T', 'SMS-NAR-2023-035',
     1.5, 2023, 'dry_magnet', '2026-Q3', '2026-07-28', 100.00,
     95.00, 0.000, 0.120, 0.250, 0, 0, 4180, 50000, 42.00, 0.00004,
     0.60, 'low', 'not_required', 'pass', '2026-10-28',
     'Dry magnet Sola — zero helium consumption.');

  select array_agg(id order by audit_date) into v_audit_ids
    from public.mri_cryogen_audits_r3128;

  v_a1 := v_audit_ids[1];  -- CMC Vellore 2026-01-30
  v_a2 := v_audit_ids[2];  -- PGI Chandigarh 2026-02-05
  v_a3 := v_audit_ids[3];  -- Fortis 2026-02-22
  v_a4 := v_audit_ids[4];  -- AIIMS 2026-03-08
  v_a5 := v_audit_ids[5];  -- Apollo 2026-04-12
  v_a6 := v_audit_ids[6];  -- Manipal 2026-04-18
  v_a7 := v_audit_ids[7];  -- St John''s 2026-05-03

  insert into public.mri_cryogen_supplier_sla_r3128 (
    audit_id, organization_id, supplier_name, supplier_city, cryogen_type, contract_tier,
    sla_response_hours, actual_response_hours, delivery_window_days, actual_delivery_days,
    quoted_price_per_litre_rupees, delivered_litres, purity_pct, purity_spec_pct,
    sla_breach, penalty_levied_rupees, next_fill_scheduled, supplier_rating,
    remediation_status, notes
  ) values
    (v_a4, v_org, 'INOX Air Products Pvt Ltd', 'New Delhi', 'liquid_helium', 'platinum',
     24, 72, 7, 14, 4250.00, 380.00, 99.985, 99.990,
     'severe', 285000, '2026-04-25', 2.60,
     'escalated', 'AIIMS critical fill delayed 7 days — penalty levied; supplier on PIP.'),
    (v_a3, v_org, 'Linde India Limited', 'Mumbai', 'liquid_helium', 'gold',
     48, 60, 10, 12, 4080.00, 220.00, 99.993, 99.990,
     'minor', 18000, '2026-05-30', 4.10,
     'completed', 'Fortis fill 2-day late; minor SLA hit; supplier issued credit note.'),
    (v_a1, v_org, 'Sterling Gases (Cryo Logistics)', 'Chennai', 'liquid_helium', 'gold',
     48, 52, 14, 16, 4180.00, 180.00, 99.991, 99.990,
     'minor', 12000, '2026-05-15', 4.00,
     'completed', 'CMC Vellore fill marginally late; quality OK.'),
    (v_a2, v_org, 'INOX Air Products Pvt Ltd', 'Chandigarh', 'liquid_helium', 'silver',
     72, 168, 14, 28, 4520.00, 320.00, 99.980, 99.990,
     'material', 95000, '2026-05-30', 2.90,
     'in_progress', 'PGI: purity 99.980 vs 99.990 spec — material breach; second supplier shortlisted.'),
    (v_a5, v_org, 'Linde India Limited', 'Hyderabad', 'liquid_helium', 'platinum',
     24, 22, 7, 6, 4100.00, 60.00, 99.995, 99.990,
     'none', 0, '2026-10-12', 4.80,
     'not_required', 'Apollo top-up: clean delivery; gold-standard supplier.'),
    (v_a6, v_org, 'Praxair India (Linde)', 'Bangalore', 'helium_gas_purge', 'gold',
     48, 40, 10, 8, 1800.00, 0.00, 99.999, 99.995,
     'none', 0, '2026-10-18', 4.50,
     'not_required', 'Manipal ZBO purge gas only; no LHe required.'),
    (v_a7, v_org, 'Sterling Gases (Cryo Logistics)', 'Bangalore', 'liquid_helium', 'silver',
     72, 96, 14, 18, 4220.00, 140.00, 99.988, 99.990,
     'minor', 22000, '2026-08-10', 3.70,
     'planned', 'St John''s fill: purity just below spec; supplier briefed.'),
    (v_a4, v_org, 'Bhuruka Gases Ltd', 'Bangalore', 'liquid_nitrogen', 'bronze',
     24, 36, 3, 5, 95.00, 800.00, 99.500, 99.000,
     'minor', 8000, '2026-04-18', 3.80,
     'completed', 'AIIMS shield LN2 fill; minor delay.');
end
$seed$;

-- ==========================================================================
-- RPC 1 — Quarterly audit roll-up
-- ==========================================================================
create or replace function public.r3128_quarterly_audit_summary()
returns table (
  audit_quarter text,
  total_audits bigint,
  passed bigint,
  conditional_or_observation bigint,
  failed_or_escalated bigint,
  avg_helium_pct numeric,
  avg_boil_off_lph numeric,
  avg_field_stability_ppm numeric
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
    a.audit_quarter,
    count(*)::bigint,
    count(*) filter (where a.audit_outcome = 'pass')::bigint,
    count(*) filter (where a.audit_outcome in ('pass_with_observation','conditional'))::bigint,
    count(*) filter (where a.audit_outcome in ('fail','escalate_oem'))::bigint,
    round(avg(a.helium_level_pct), 2),
    round(avg(a.helium_boil_off_lph), 4),
    round(avg(a.field_stability_ppm), 3)
  from public.mri_cryogen_audits_r3128 a
  group by a.audit_quarter
  order by a.audit_quarter;
end;
$$;

revoke execute on function public.r3128_quarterly_audit_summary() from public, anon;
grant execute on function public.r3128_quarterly_audit_summary() to authenticated;

-- ==========================================================================
-- RPC 2 — Risk-band breakdown
-- ==========================================================================
create or replace function public.r3128_risk_band_breakdown()
returns table (
  risk_band text,
  scanner_count bigint,
  avg_quench_risk numeric,
  avg_helium_pct numeric,
  capa_open bigint,
  capa_overdue bigint
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
    a.risk_band,
    count(*)::bigint,
    round(avg(a.quench_risk_score), 2),
    round(avg(a.helium_level_pct), 2),
    count(*) filter (where a.capa_status in ('open','in_progress'))::bigint,
    count(*) filter (where a.capa_status = 'overdue')::bigint
  from public.mri_cryogen_audits_r3128 a
  group by a.risk_band
  order by
    case a.risk_band
      when 'critical' then 1
      when 'high' then 2
      when 'elevated' then 3
      when 'moderate' then 4
      when 'low' then 5
    end;
end;
$$;

revoke execute on function public.r3128_risk_band_breakdown() from public, anon;
grant execute on function public.r3128_risk_band_breakdown() to authenticated;

-- ==========================================================================
-- RPC 3 — Top critical scanners (helium / quench risk)
-- ==========================================================================
create or replace function public.r3128_critical_scanners_top()
returns table (
  hospital_name text,
  city text,
  scanner_model text,
  field_strength_tesla numeric,
  helium_level_pct numeric,
  helium_boil_off_lph numeric,
  quench_risk_score numeric,
  risk_band text,
  audit_outcome text,
  next_audit_due_date date
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
    a.hospital_name, a.city, a.scanner_model, a.field_strength_tesla,
    a.helium_level_pct, a.helium_boil_off_lph, a.quench_risk_score,
    a.risk_band, a.audit_outcome, a.next_audit_due_date
  from public.mri_cryogen_audits_r3128 a
  where a.risk_band in ('elevated','high','critical')
     or a.audit_outcome in ('conditional','fail','escalate_oem')
  order by a.quench_risk_score desc, a.helium_level_pct asc;
end;
$$;

revoke execute on function public.r3128_critical_scanners_top() from public, anon;
grant execute on function public.r3128_critical_scanners_top() to authenticated;

-- ==========================================================================
-- RPC 4 — Magnet-type performance
-- ==========================================================================
create or replace function public.r3128_magnet_type_performance()
returns table (
  magnet_type text,
  scanner_count bigint,
  avg_boil_off_lph numeric,
  avg_helium_pct numeric,
  avg_quench_risk numeric,
  pass_rate_pct numeric
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
    a.magnet_type,
    count(*)::bigint,
    round(avg(a.helium_boil_off_lph), 4),
    round(avg(a.helium_level_pct), 2),
    round(avg(a.quench_risk_score), 2),
    round(100.0 * count(*) filter (where a.audit_outcome = 'pass') / nullif(count(*), 0), 2)
  from public.mri_cryogen_audits_r3128 a
  group by a.magnet_type
  order by avg(a.quench_risk_score) asc;
end;
$$;

revoke execute on function public.r3128_magnet_type_performance() from public, anon;
grant execute on function public.r3128_magnet_type_performance() to authenticated;

-- ==========================================================================
-- RPC 5 — Cold-head replacement aging
-- ==========================================================================
create or replace function public.r3128_cold_head_aging_alerts()
returns table (
  hospital_name text,
  scanner_model text,
  field_strength_tesla numeric,
  cold_head_runtime_hours integer,
  cold_head_replacement_due_hours integer,
  hours_over_spec integer,
  install_year integer,
  risk_band text
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
    a.hospital_name, a.scanner_model, a.field_strength_tesla,
    a.cold_head_runtime_hours, a.cold_head_replacement_due_hours,
    (a.cold_head_runtime_hours - a.cold_head_replacement_due_hours)::integer,
    a.install_year, a.risk_band
  from public.mri_cryogen_audits_r3128 a
  where a.cold_head_runtime_hours >= (a.cold_head_replacement_due_hours * 0.85)
  order by (a.cold_head_runtime_hours - a.cold_head_replacement_due_hours) desc;
end;
$$;

revoke execute on function public.r3128_cold_head_aging_alerts() from public, anon;
grant execute on function public.r3128_cold_head_aging_alerts() to authenticated;

-- ==========================================================================
-- RPC 6 — Supplier SLA scorecard
-- ==========================================================================
create or replace function public.r3128_supplier_sla_scorecard()
returns table (
  supplier_name text,
  contract_tier text,
  fills_count bigint,
  avg_response_hours numeric,
  avg_delivery_days numeric,
  total_litres_delivered numeric,
  total_penalty_rupees bigint,
  avg_supplier_rating numeric,
  breaches bigint
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
    s.supplier_name,
    s.contract_tier,
    count(*)::bigint,
    round(avg(s.actual_response_hours), 1),
    round(avg(s.actual_delivery_days), 1),
    round(sum(s.delivered_litres), 2),
    sum(s.penalty_levied_rupees)::bigint,
    round(avg(s.supplier_rating), 2),
    count(*) filter (where s.sla_breach <> 'none')::bigint
  from public.mri_cryogen_supplier_sla_r3128 s
  group by s.supplier_name, s.contract_tier
  order by sum(s.penalty_levied_rupees) desc, avg(s.supplier_rating) asc;
end;
$$;

revoke execute on function public.r3128_supplier_sla_scorecard() from public, anon;
grant execute on function public.r3128_supplier_sla_scorecard() to authenticated;

-- ==========================================================================
-- RPC 7 — SLA breach detail with audit context
-- ==========================================================================
create or replace function public.r3128_sla_breach_detail()
returns table (
  hospital_name text,
  supplier_name text,
  cryogen_type text,
  contract_tier text,
  sla_response_hours integer,
  actual_response_hours integer,
  delivery_window_days integer,
  actual_delivery_days integer,
  purity_pct numeric,
  purity_spec_pct numeric,
  sla_breach text,
  penalty_levied_rupees integer,
  remediation_status text
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
    a.hospital_name, s.supplier_name, s.cryogen_type, s.contract_tier,
    s.sla_response_hours, s.actual_response_hours,
    s.delivery_window_days, s.actual_delivery_days,
    s.purity_pct, s.purity_spec_pct,
    s.sla_breach, s.penalty_levied_rupees, s.remediation_status
  from public.mri_cryogen_supplier_sla_r3128 s
  join public.mri_cryogen_audits_r3128 a on a.id = s.audit_id
  where s.sla_breach <> 'none'
  order by
    case s.sla_breach
      when 'terminated' then 1
      when 'severe' then 2
      when 'material' then 3
      when 'minor' then 4
      else 5
    end,
    s.penalty_levied_rupees desc;
end;
$$;

revoke execute on function public.r3128_sla_breach_detail() from public, anon;
grant execute on function public.r3128_sla_breach_detail() to authenticated;

-- ==========================================================================
-- RPC 8 — CAPA workflow status
-- ==========================================================================
create or replace function public.r3128_capa_workflow_status()
returns table (
  capa_status text,
  scanner_count bigint,
  avg_quench_risk numeric,
  avg_days_to_next_audit numeric,
  failed_scanners bigint
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
    a.capa_status,
    count(*)::bigint,
    round(avg(a.quench_risk_score), 2),
    round(avg(a.next_audit_due_date - a.audit_date), 1),
    count(*) filter (where a.audit_outcome in ('fail','escalate_oem'))::bigint
  from public.mri_cryogen_audits_r3128 a
  group by a.capa_status
  order by
    case a.capa_status
      when 'overdue' then 1
      when 'open' then 2
      when 'in_progress' then 3
      when 'verified' then 4
      when 'closed' then 5
      when 'not_required' then 6
    end;
end;
$$;

revoke execute on function public.r3128_capa_workflow_status() from public, anon;
grant execute on function public.r3128_capa_workflow_status() to authenticated;

-- ==========================================================================
-- RPC 9 — Field-stability drift watchlist
-- ==========================================================================
create or replace function public.r3128_field_stability_drift()
returns table (
  hospital_name text,
  scanner_model text,
  field_strength_tesla numeric,
  field_stability_ppm numeric,
  field_stability_spec_ppm numeric,
  drift_over_spec_ppm numeric,
  ramp_events_last_year integer,
  audit_outcome text
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
    a.hospital_name, a.scanner_model, a.field_strength_tesla,
    a.field_stability_ppm, a.field_stability_spec_ppm,
    (a.field_stability_ppm - a.field_stability_spec_ppm)::numeric,
    a.ramp_events_last_year, a.audit_outcome
  from public.mri_cryogen_audits_r3128 a
  where a.field_stability_ppm > a.field_stability_spec_ppm
     or a.ramp_events_last_year >= 3
  order by (a.field_stability_ppm - a.field_stability_spec_ppm) desc nulls last,
           a.ramp_events_last_year desc;
end;
$$;

revoke execute on function public.r3128_field_stability_drift() from public, anon;
grant execute on function public.r3128_field_stability_drift() to authenticated;
