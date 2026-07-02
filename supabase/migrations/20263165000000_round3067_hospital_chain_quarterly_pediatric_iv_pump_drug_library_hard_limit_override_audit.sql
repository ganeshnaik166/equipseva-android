-- Round 3067 — Hospital Chain Quarterly Pediatric IV-Pump Drug-Library Hard-Limit Override Audit

create table if not exists public.pediatric_iv_pump_hard_limit_overrides_r3067 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  hospital_site text not null,
  pump_serial text not null,
  drug_name text not null,
  patient_weight_kg numeric(5,2) not null check (patient_weight_kg between 0.5 and 80.0),
  programmed_rate_mg_per_kg_per_hr numeric(7,3) not null check (programmed_rate_mg_per_kg_per_hr >= 0),
  library_hard_limit_mg_per_kg_per_hr numeric(7,3) not null check (library_hard_limit_mg_per_kg_per_hr >= 0),
  override_percent_over_limit numeric(6,2) not null check (override_percent_over_limit >= 0),
  override_reason_code text not null check (override_reason_code in ('clinical_judgment','escalating_seizure','sepsis_bundle','sedation_titration','code_blue','protocol_variance','other')),
  override_outcome text not null check (override_outcome in ('safe','adverse_event','near_miss','no_harm_documented','death')),
  prescriber_seniority text not null check (prescriber_seniority in ('attending','fellow','resident','np_pa')),
  reviewed_by_pharmacy boolean not null default false,
  overridden_at timestamptz not null,
  quarter text not null check (quarter in ('2026Q1','2026Q2','2026Q3','2026Q4'))
);

create table if not exists public.pediatric_iv_pump_chain_audit_findings_r3067 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  finding_severity text not null check (finding_severity in ('critical','major','minor','observation')),
  finding_category text not null check (finding_category in ('library_currency','training_gap','documentation','governance','metric_breach','reporting')),
  finding_summary text not null,
  recommended_action text not null,
  owner_role text not null check (owner_role in ('chief_pharmacy_officer','chief_nursing_officer','biomedical_director','quality_director','it_director')),
  target_close_date date,
  status text not null check (status in ('open','in_progress','closed','accepted_risk')),
  quarter text not null check (quarter in ('2026Q1','2026Q2','2026Q3','2026Q4'))
);

alter table public.pediatric_iv_pump_hard_limit_overrides_r3067 enable row level security;
alter table public.pediatric_iv_pump_chain_audit_findings_r3067 enable row level security;

drop policy if exists r3067_overrides_founder_select on public.pediatric_iv_pump_hard_limit_overrides_r3067;
create policy r3067_overrides_founder_select on public.pediatric_iv_pump_hard_limit_overrides_r3067 for select to authenticated using (is_founder());

drop policy if exists r3067_findings_founder_select on public.pediatric_iv_pump_chain_audit_findings_r3067;
create policy r3067_findings_founder_select on public.pediatric_iv_pump_chain_audit_findings_r3067 for select to authenticated using (is_founder());

insert into public.pediatric_iv_pump_hard_limit_overrides_r3067 (chain_code, hospital_site, pump_serial, drug_name, patient_weight_kg, programmed_rate_mg_per_kg_per_hr, library_hard_limit_mg_per_kg_per_hr, override_percent_over_limit, override_reason_code, override_outcome, prescriber_seniority, reviewed_by_pharmacy, overridden_at, quarter) values
('APOLLO-PEDS','Apollo Hyd PICU','PMP-001A','Fentanyl',3.20,5.500,4.000,37.50,'sedation_titration','no_harm_documented','attending',true,'2026-04-04 02:14:00+05:30'::timestamptz,'2026Q2'),
('APOLLO-PEDS','Apollo Chennai NICU','PMP-002A','Midazolam',1.10,0.450,0.300,50.00,'escalating_seizure','safe','fellow',true,'2026-04-09 22:30:00+05:30'::timestamptz,'2026Q2'),
('APOLLO-PEDS','Apollo Bglr PICU','PMP-003A','Vancomycin',12.50,22.000,18.000,22.22,'sepsis_bundle','safe','attending',true,'2026-04-15 11:00:00+05:30'::timestamptz,'2026Q2'),
('FORTIS-PEDS','Fortis Gurgaon PICU','PMP-101F','Norepinephrine',8.40,0.180,0.100,80.00,'code_blue','no_harm_documented','attending',false,'2026-05-02 03:45:00+05:30'::timestamptz,'2026Q2'),
('FORTIS-PEDS','Fortis Mumbai NICU','PMP-102F','Dopamine',2.80,15.000,10.000,50.00,'code_blue','near_miss','resident',false,'2026-05-08 04:20:00+05:30'::timestamptz,'2026Q2'),
('FORTIS-PEDS','Fortis Noida PICU','PMP-103F','Morphine',14.00,0.080,0.050,60.00,'clinical_judgment','adverse_event','resident',false,'2026-05-12 18:00:00+05:30'::timestamptz,'2026Q2'),
('MAX-PEDS','Max Saket PICU','PMP-201M','Propofol',22.00,4.200,4.000,5.00,'sedation_titration','safe','attending',true,'2026-05-20 09:00:00+05:30'::timestamptz,'2026Q2'),
('MAX-PEDS','Max Patparganj NICU','PMP-202M','Caffeine',1.80,8.500,5.000,70.00,'protocol_variance','no_harm_documented','fellow',true,'2026-05-25 14:30:00+05:30'::timestamptz,'2026Q2'),
('MAX-PEDS','Max Shalimar PICU','PMP-203M','Adrenaline',5.50,0.150,0.100,50.00,'code_blue','safe','attending',true,'2026-06-01 07:15:00+05:30'::timestamptz,'2026Q2'),
('NARAYANA-PEDS','Narayana Bglr PICU','PMP-301N','Heparin',11.00,28.000,20.000,40.00,'clinical_judgment','near_miss','np_pa',false,'2026-06-04 16:45:00+05:30'::timestamptz,'2026Q2'),
('NARAYANA-PEDS','Narayana Kolkata PICU','PMP-302N','Insulin',9.80,0.120,0.100,20.00,'protocol_variance','safe','attending',true,'2026-06-08 10:00:00+05:30'::timestamptz,'2026Q2'),
('NARAYANA-PEDS','Narayana Jaipur NICU','PMP-303N','Ampicillin',1.50,55.000,50.000,10.00,'sepsis_bundle','safe','fellow',true,'2026-06-10 13:20:00+05:30'::timestamptz,'2026Q2'),
('MEDANTA-PEDS','Medanta Gurgaon PICU','PMP-401X','Ketamine',18.00,3.500,2.000,75.00,'sedation_titration','adverse_event','resident',false,'2026-06-12 19:00:00+05:30'::timestamptz,'2026Q2'),
('MEDANTA-PEDS','Medanta Lucknow PICU','PMP-402X','Furosemide',7.20,1.800,1.000,80.00,'clinical_judgment','no_harm_documented','attending',true,'2026-06-14 08:30:00+05:30'::timestamptz,'2026Q2'),
('AIIMS-PEDS','AIIMS Delhi PICU','PMP-501A','Meropenem',13.50,42.000,40.000,5.00,'sepsis_bundle','safe','attending',true,'2026-06-15 11:45:00+05:30'::timestamptz,'2026Q2'),
('AIIMS-PEDS','AIIMS Jodhpur NICU','PMP-502A','Surfactant',2.10,110.000,100.000,10.00,'protocol_variance','safe','attending',true,'2026-06-17 04:00:00+05:30'::timestamptz,'2026Q2'),
('AIIMS-PEDS','AIIMS Patna PICU','PMP-503A','Phenytoin',16.00,3.200,2.000,60.00,'escalating_seizure','near_miss','fellow',false,'2026-06-18 21:30:00+05:30'::timestamptz,'2026Q2'),
('KIMS-PEDS','KIMS Hyd PICU','PMP-601K','Diazepam',9.40,0.520,0.300,73.33,'escalating_seizure','adverse_event','resident',false,'2026-06-19 05:15:00+05:30'::timestamptz,'2026Q2'),
('KIMS-PEDS','KIMS Vizag NICU','PMP-602K','Gentamicin',1.90,9.500,7.500,26.67,'sepsis_bundle','safe','attending',true,'2026-06-20 12:00:00+05:30'::timestamptz,'2026Q2'),
('MANIPAL-PEDS','Manipal Bglr PICU','PMP-701P','Lorazepam',20.00,0.180,0.100,80.00,'escalating_seizure','death','resident',false,'2026-06-20 23:50:00+05:30'::timestamptz,'2026Q2');

insert into public.pediatric_iv_pump_chain_audit_findings_r3067 (chain_code, finding_severity, finding_category, finding_summary, recommended_action, owner_role, target_close_date, status, quarter) values
('APOLLO-PEDS','minor','library_currency','3 sites still on v4.2 drug library; v4.5 released 2026-03-01','Force-push v4.5 to all 38 pumps by quarter end','chief_pharmacy_officer','2026-09-30'::date,'in_progress','2026Q2'),
('APOLLO-PEDS','observation','documentation','15% overrides lack second-signoff note','Hard-block override save without note field','it_director','2026-09-15'::date,'open','2026Q2'),
('FORTIS-PEDS','critical','metric_breach','Norepi override 80% over limit with no pharmacy review','Mandate real-time pharmacy ping for vasopressor overrides','chief_pharmacy_officer','2026-07-31'::date,'open','2026Q2'),
('FORTIS-PEDS','major','training_gap','Resident override rate 3.2x attending rate','Mandatory smart-pump recert for all PGY-1/2','chief_nursing_officer','2026-08-15'::date,'in_progress','2026Q2'),
('FORTIS-PEDS','major','reporting','Adverse event from morphine override not filed in QSR','File retrospective QSR and root-cause analysis','quality_director','2026-07-15'::date,'open','2026Q2'),
('MAX-PEDS','minor','governance','Caffeine 70% override on neonate — protocol variance unsigned','Tighten neonatal caffeine protocol; reaffirm signers','chief_pharmacy_officer','2026-08-30'::date,'in_progress','2026Q2'),
('MAX-PEDS','observation','library_currency','Propofol limit set at adult value 4.0','Add pediatric-specific propofol limit per weight band','biomedical_director','2026-09-30'::date,'open','2026Q2'),
('NARAYANA-PEDS','major','metric_breach','Heparin 40% override by NP without attending co-sign','Restrict anticoag overrides to attending-level only','chief_pharmacy_officer','2026-08-01'::date,'open','2026Q2'),
('NARAYANA-PEDS','minor','documentation','3 overrides reason_code = other with free text','Expand reason code taxonomy; deprecate "other"','it_director','2026-09-15'::date,'in_progress','2026Q2'),
('MEDANTA-PEDS','critical','metric_breach','Ketamine 75% over limit adverse event in 18kg child','Halt ketamine overrides pending committee review','chief_pharmacy_officer','2026-07-10'::date,'open','2026Q2'),
('MEDANTA-PEDS','major','training_gap','Furosemide 80% override with no diuresis goal documented','CME module on pediatric diuretic dosing','chief_nursing_officer','2026-08-30'::date,'in_progress','2026Q2'),
('AIIMS-PEDS','observation','library_currency','Surfactant limit aligned with 2024 NRP — update to 2026','Refresh NRP-aligned library q4','biomedical_director','2026-09-30'::date,'open','2026Q2'),
('AIIMS-PEDS','major','reporting','Phenytoin near-miss not surfaced in monthly chain rollup','Add near-miss flag to chain executive dashboard','quality_director','2026-08-15'::date,'in_progress','2026Q2'),
('KIMS-PEDS','critical','metric_breach','Diazepam 73% override with adverse event in seizure case','Replace diazepam with weight-band lorazepam protocol','chief_pharmacy_officer','2026-07-20'::date,'open','2026Q2'),
('KIMS-PEDS','minor','governance','Gentamicin overrides clustered to single attending','Peer-review cluster pattern with chair','quality_director','2026-09-01'::date,'in_progress','2026Q2'),
('MANIPAL-PEDS','critical','metric_breach','Lorazepam 80% override resulted in patient death','Sentinel event review; freeze involved pump line','chief_pharmacy_officer','2026-06-30'::date,'open','2026Q2'),
('MANIPAL-PEDS','major','training_gap','Resident-led overrides outside ICU hours unsupervised','Mandate attending tele-supervision after 10pm','chief_nursing_officer','2026-08-15'::date,'open','2026Q2'),
('MANIPAL-PEDS','major','governance','No quarterly P&T committee review of overrides','Reinstate quarterly P&T audit of all overrides','chief_pharmacy_officer','2026-09-30'::date,'open','2026Q2');

revoke all on public.pediatric_iv_pump_hard_limit_overrides_r3067 from public, anon;
revoke all on public.pediatric_iv_pump_chain_audit_findings_r3067 from public, anon;
grant select on public.pediatric_iv_pump_hard_limit_overrides_r3067 to authenticated;
grant select on public.pediatric_iv_pump_chain_audit_findings_r3067 to authenticated;

create or replace function public.r3067_chain_override_rollup()
returns table(chain_code text, total_overrides int, critical_overrides int, adverse_events int, near_misses int, deaths int, avg_pct_over numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.chain_code,
         count(*)::int,
         (count(*) filter (where o.override_percent_over_limit >= 50))::int,
         (count(*) filter (where o.override_outcome = 'adverse_event'))::int,
         (count(*) filter (where o.override_outcome = 'near_miss'))::int,
         (count(*) filter (where o.override_outcome = 'death'))::int,
         round(avg(o.override_percent_over_limit), 2)
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  group by o.chain_code
  order by 5 desc, 4 desc, 3 desc;
end $$;

create or replace function public.r3067_drug_risk_ranking()
returns table(drug_name text, overrides int, max_pct_over numeric, adverse_or_death int, unreviewed_by_pharmacy int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.drug_name,
         count(*)::int,
         max(o.override_percent_over_limit),
         (count(*) filter (where o.override_outcome in ('adverse_event','death')))::int,
         (count(*) filter (where o.reviewed_by_pharmacy = false))::int
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  group by o.drug_name
  order by 4 desc, 3 desc;
end $$;

create or replace function public.r3067_seniority_breakdown()
returns table(prescriber_seniority text, overrides int, avg_pct numeric, adverse_events int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.prescriber_seniority,
         count(*)::int,
         round(avg(o.override_percent_over_limit), 2),
         (count(*) filter (where o.override_outcome in ('adverse_event','death')))::int
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  group by o.prescriber_seniority
  order by 4 desc, 2 desc;
end $$;

create or replace function public.r3067_reason_distribution()
returns table(override_reason_code text, overrides int, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total from public.pediatric_iv_pump_hard_limit_overrides_r3067;
  return query
  select o.override_reason_code,
         count(*)::int,
         round((count(*)::numeric / nullif(total,0)) * 100, 2)
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  group by o.override_reason_code
  order by 2 desc;
end $$;

create or replace function public.r3067_findings_open_by_chain()
returns table(chain_code text, critical_open int, major_open int, minor_open int, total_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.chain_code,
         (count(*) filter (where f.finding_severity = 'critical' and f.status in ('open','in_progress')))::int,
         (count(*) filter (where f.finding_severity = 'major' and f.status in ('open','in_progress')))::int,
         (count(*) filter (where f.finding_severity = 'minor' and f.status in ('open','in_progress')))::int,
         (count(*) filter (where f.status in ('open','in_progress')))::int
  from public.pediatric_iv_pump_chain_audit_findings_r3067 f
  group by f.chain_code
  order by 2 desc, 3 desc, 4 desc;
end $$;

create or replace function public.r3067_critical_overrides_detail()
returns table(chain_code text, hospital_site text, drug_name text, pct_over numeric, outcome text, prescriber_seniority text, overridden_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.chain_code, o.hospital_site, o.drug_name, o.override_percent_over_limit, o.override_outcome, o.prescriber_seniority, o.overridden_at
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  where o.override_percent_over_limit >= 50 or o.override_outcome in ('adverse_event','death','near_miss')
  order by o.overridden_at desc;
end $$;

create or replace function public.r3067_quarterly_kpis()
returns table(quarter text, total_overrides int, critical_pct numeric, adverse_or_death int, pharmacy_review_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.quarter,
         count(*)::int,
         round(((count(*) filter (where o.override_percent_over_limit >= 50))::numeric / nullif(count(*),0)) * 100, 2),
         (count(*) filter (where o.override_outcome in ('adverse_event','death')))::int,
         round(((count(*) filter (where o.reviewed_by_pharmacy = true))::numeric / nullif(count(*),0)) * 100, 2)
  from public.pediatric_iv_pump_hard_limit_overrides_r3067 o
  group by o.quarter
  order by 1;
end $$;

revoke all on function public.r3067_chain_override_rollup() from public, anon;
revoke all on function public.r3067_drug_risk_ranking() from public, anon;
revoke all on function public.r3067_seniority_breakdown() from public, anon;
revoke all on function public.r3067_reason_distribution() from public, anon;
revoke all on function public.r3067_findings_open_by_chain() from public, anon;
revoke all on function public.r3067_critical_overrides_detail() from public, anon;
revoke all on function public.r3067_quarterly_kpis() from public, anon;

grant execute on function public.r3067_chain_override_rollup() to authenticated;
grant execute on function public.r3067_drug_risk_ranking() to authenticated;
grant execute on function public.r3067_seniority_breakdown() to authenticated;
grant execute on function public.r3067_reason_distribution() to authenticated;
grant execute on function public.r3067_findings_open_by_chain() to authenticated;
grant execute on function public.r3067_critical_overrides_detail() to authenticated;
grant execute on function public.r3067_quarterly_kpis() to authenticated;
