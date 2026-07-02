-- Round 3124 — Customer Hospital Infusion Pump Free-Flow Anti-Bolus Pediatric Dose Library Compliance Audit
-- Smart pump dose library: drug × concentration × min/max bolus × pediatric hard-limit × overrides × CAPA

-- =========================================================================
-- Table 1: dose library entries (drug × concentration × pediatric limit)
-- =========================================================================
create table if not exists pump_dose_library_entries_r3124 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_unit text not null check (hospital_unit in ('picu','nicu','pediatric_ward','pediatric_or','pediatric_ed','step_down')),
  pump_make_model text not null,
  pump_serial text not null,
  drug_name text not null,
  drug_class text not null check (drug_class in ('vasoactive','sedative','analgesic','paralytic','antibiotic','electrolyte','inotrope','anticoagulant','insulin','chemotherapy')),
  concentration_mg_per_ml numeric(10,4) not null check (concentration_mg_per_ml > 0),
  diluent text not null check (diluent in ('ns','d5w','d10w','d25w','sterile_water','d5_half_ns','lactated_ringers')),
  weight_band_kg_min numeric(6,2) not null check (weight_band_kg_min >= 0),
  weight_band_kg_max numeric(6,2) not null check (weight_band_kg_max > 0),
  age_band text not null check (age_band in ('neonate_0_28d','infant_1_12m','toddler_1_3y','child_3_12y','adolescent_12_18y','all_pediatric')),
  soft_min_dose_per_kg_per_hr numeric(12,4) check (soft_min_dose_per_kg_per_hr >= 0),
  soft_max_dose_per_kg_per_hr numeric(12,4) check (soft_max_dose_per_kg_per_hr > 0),
  hard_max_dose_per_kg_per_hr numeric(12,4) check (hard_max_dose_per_kg_per_hr > 0),
  bolus_min_mcg_per_kg numeric(12,4) check (bolus_min_mcg_per_kg is null or bolus_min_mcg_per_kg >= 0),
  bolus_max_mcg_per_kg numeric(12,4) check (bolus_max_mcg_per_kg is null or bolus_max_mcg_per_kg > 0),
  free_flow_protection_kind text not null check (free_flow_protection_kind in ('gravity_clamp','anti_freeflow_set','cassette_lock','none')),
  free_flow_test_pass boolean not null default false,
  free_flow_last_test_at timestamptz,
  library_version text not null,
  library_signed_off_by_pharmd boolean not null default false,
  library_signed_off_at timestamptz,
  status text not null check (status in ('draft','active','retired','quarantined')),
  audit_window_start date not null,
  audit_window_end date not null,
  created_at timestamptz not null default now(),
  check (weight_band_kg_max > weight_band_kg_min),
  check (soft_max_dose_per_kg_per_hr >= soft_min_dose_per_kg_per_hr),
  check (hard_max_dose_per_kg_per_hr >= soft_max_dose_per_kg_per_hr),
  check (audit_window_end >= audit_window_start)
);

create index if not exists idx_pdle_r3124_org on pump_dose_library_entries_r3124(organization_id);
create index if not exists idx_pdle_r3124_status on pump_dose_library_entries_r3124(status);

-- =========================================================================
-- Table 2: override events + CAPA
-- =========================================================================
create table if not exists pump_dose_override_events_r3124 (
  id uuid primary key default gen_random_uuid(),
  library_entry_id uuid not null references pump_dose_library_entries_r3124(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  event_at timestamptz not null default now(),
  patient_pseudo_id text not null,
  patient_weight_kg numeric(6,2) not null check (patient_weight_kg > 0),
  patient_age_band text not null check (patient_age_band in ('neonate_0_28d','infant_1_12m','toddler_1_3y','child_3_12y','adolescent_12_18y')),
  programmed_dose_per_kg_per_hr numeric(12,4) not null check (programmed_dose_per_kg_per_hr >= 0),
  override_kind text not null check (override_kind in ('soft_min_under','soft_max_over','hard_max_over','bolus_over','free_flow_bypass','no_library_entry','wrong_concentration')),
  override_pct_over_hard numeric(8,2) check (override_pct_over_hard is null or override_pct_over_hard >= 0),
  override_reason_code text not null check (override_reason_code in ('clinical_judgment','rapid_titration','code_blue','transport','none_given','wrong_drug_selected','library_outdated','training_gap')),
  prescriber_role text not null check (prescriber_role in ('attending','fellow','resident','np','rn','pharmd')),
  patient_outcome text not null check (patient_outcome in ('no_harm','near_miss','minor_harm','serious_harm','sentinel','unknown')),
  capa_status text not null check (capa_status in ('not_required','open','in_progress','closed','escalated_to_qc','reported_to_cdsco')),
  capa_owner_user_id uuid references profiles(id) on delete set null,
  capa_due_date date,
  capa_closed_at timestamptz,
  severity text not null check (severity in ('low','medium','high','critical')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_pdoe_r3124_lib on pump_dose_override_events_r3124(library_entry_id);
create index if not exists idx_pdoe_r3124_capa on pump_dose_override_events_r3124(capa_status);

-- =========================================================================
-- Seed data
-- =========================================================================
with first_org as (select id from organizations order by created_at asc limit 1)
insert into pump_dose_library_entries_r3124 (
  organization_id, hospital_unit, pump_make_model, pump_serial, drug_name, drug_class,
  concentration_mg_per_ml, diluent, weight_band_kg_min, weight_band_kg_max, age_band,
  soft_min_dose_per_kg_per_hr, soft_max_dose_per_kg_per_hr, hard_max_dose_per_kg_per_hr,
  bolus_min_mcg_per_kg, bolus_max_mcg_per_kg, free_flow_protection_kind, free_flow_test_pass,
  free_flow_last_test_at, library_version, library_signed_off_by_pharmd, library_signed_off_at,
  status, audit_window_start, audit_window_end
)
select (select id from first_org), q.unit, q.pump, q.serial, q.drug, q.cls, q.conc, q.dil,
       q.wmin, q.wmax, q.age, q.smin, q.smax, q.hmax, q.bmin, q.bmax, q.ff, q.ffp,
       q.fft::timestamptz, q.ver, q.sgn, q.sgnat::timestamptz, q.st, q.ws::date, q.we::date
from (values
  ('picu','BBraun Infusomat Space','BB-PICU-2201','Adrenaline','vasoactive',0.0500,'ns',3.00,15.00,'toddler_1_3y',0.0500,0.5000,1.0000,1.0000,10.0000,'anti_freeflow_set',true,'2026-06-15 09:00:00+05:30','v4.2',true,'2026-06-10 11:00:00+05:30','active','2026-06-01','2026-06-30'),
  ('nicu','Medfusion 4000','MF-NICU-1108','Dopamine','inotrope',0.4000,'d5w',0.50,5.00,'neonate_0_28d',2.5000,15.0000,20.0000,null,null,'cassette_lock',true,'2026-06-12 14:30:00+05:30','v4.2',true,'2026-06-10 11:05:00+05:30','active','2026-06-01','2026-06-30'),
  ('picu','BBraun Infusomat Space','BB-PICU-2202','Midazolam','sedative',1.0000,'ns',3.00,15.00,'child_3_12y',0.0500,0.3000,0.5000,50.0000,200.0000,'anti_freeflow_set',true,'2026-06-14 10:15:00+05:30','v4.2',true,'2026-06-10 11:10:00+05:30','active','2026-06-01','2026-06-30'),
  ('picu','Smiths Medical CADD','SM-PICU-3301','Fentanyl','analgesic',0.0100,'ns',5.00,25.00,'child_3_12y',0.5000,2.0000,4.0000,0.5000,2.0000,'cassette_lock',true,'2026-06-13 16:45:00+05:30','v4.2',true,'2026-06-10 11:15:00+05:30','active','2026-06-01','2026-06-30'),
  ('nicu','Medfusion 4000','MF-NICU-1109','Vecuronium','paralytic',0.1000,'ns',0.50,5.00,'neonate_0_28d',0.0500,0.1000,0.2000,null,null,'anti_freeflow_set',false,'2026-06-08 12:00:00+05:30','v4.1',false,null,'quarantined','2026-06-01','2026-06-30'),
  ('pediatric_ward','BBraun Perfusor Space','BB-WARD-4401','Vancomycin','antibiotic',5.0000,'d5w',5.00,40.00,'child_3_12y',10.0000,15.0000,20.0000,null,null,'gravity_clamp',true,'2026-06-11 09:30:00+05:30','v4.2',true,'2026-06-10 11:20:00+05:30','active','2026-06-01','2026-06-30'),
  ('pediatric_or','Smiths Medical CADD','SM-OR-3302','Rocuronium','paralytic',1.0000,'ns',10.00,30.00,'child_3_12y',null,null,12.0000,300.0000,600.0000,'cassette_lock',true,'2026-06-09 08:00:00+05:30','v4.2',true,'2026-06-10 11:25:00+05:30','active','2026-06-01','2026-06-30'),
  ('picu','BBraun Infusomat Space','BB-PICU-2203','Norepinephrine','vasoactive',0.0640,'ns',3.00,15.00,'toddler_1_3y',0.0500,0.5000,1.0000,null,null,'anti_freeflow_set',true,'2026-06-16 13:00:00+05:30','v4.2',true,'2026-06-10 11:30:00+05:30','active','2026-06-01','2026-06-30'),
  ('nicu','Medfusion 4000','MF-NICU-1110','Insulin','insulin',1.0000,'ns',0.50,5.00,'neonate_0_28d',0.0100,0.1000,0.2000,null,null,'cassette_lock',true,'2026-06-12 15:45:00+05:30','v4.2',true,'2026-06-10 11:35:00+05:30','active','2026-06-01','2026-06-30'),
  ('pediatric_ed','BBraun Perfusor Space','BB-ED-5501','Potassium Chloride','electrolyte',0.1000,'ns',10.00,30.00,'child_3_12y',0.1000,0.5000,1.0000,null,null,'anti_freeflow_set',true,'2026-06-15 17:00:00+05:30','v4.2',true,'2026-06-10 11:40:00+05:30','active','2026-06-01','2026-06-30'),
  ('step_down','Smiths Medical CADD','SM-SD-3303','Morphine','analgesic',1.0000,'ns',10.00,40.00,'adolescent_12_18y',0.0100,0.0500,0.1000,50.0000,150.0000,'cassette_lock',true,'2026-06-14 11:20:00+05:30','v4.2',true,'2026-06-10 11:45:00+05:30','active','2026-06-01','2026-06-30'),
  ('picu','BBraun Infusomat Space','BB-PICU-2204','Heparin','anticoagulant',100.0000,'ns',3.00,15.00,'toddler_1_3y',10.0000,20.0000,28.0000,null,null,'anti_freeflow_set',true,'2026-06-13 14:00:00+05:30','v4.2',true,'2026-06-10 11:50:00+05:30','active','2026-06-01','2026-06-30'),
  ('picu','BBraun Infusomat Space','BB-PICU-2205','Cisatracurium','paralytic',2.0000,'ns',3.00,15.00,'child_3_12y',1.0000,3.0000,5.0000,null,null,'anti_freeflow_set',false,'2026-06-05 10:00:00+05:30','v4.0',false,null,'draft','2026-06-01','2026-06-30')
) as q(unit,pump,serial,drug,cls,conc,dil,wmin,wmax,age,smin,smax,hmax,bmin,bmax,ff,ffp,fft,ver,sgn,sgnat,st,ws,we);

-- override events seed (FK to first lib row)
with first_lib as (select id, organization_id from pump_dose_library_entries_r3124 order by created_at asc limit 1)
insert into pump_dose_override_events_r3124 (
  library_entry_id, organization_id, event_at, patient_pseudo_id, patient_weight_kg, patient_age_band,
  programmed_dose_per_kg_per_hr, override_kind, override_pct_over_hard, override_reason_code,
  prescriber_role, patient_outcome, capa_status, capa_due_date, capa_closed_at, severity, notes
)
select (select id from first_lib), (select organization_id from first_lib),
       q.evt::timestamptz, q.pid, q.wt, q.ageb, q.prog, q.ok, q.pct, q.rsn, q.role, q.out,
       q.capa, q.due::date, q.closed::timestamptz, q.sev, q.nt
from (values
  ('2026-06-12 02:14:00+05:30','PT-2026-0014',8.50,'toddler_1_3y',1.2000,'hard_max_over',20.00,'code_blue','attending','near_miss','closed','2026-06-20','2026-06-19 18:00:00+05:30','high','Code blue resuscitation; reviewed by QC committee'),
  ('2026-06-13 11:32:00+05:30','PT-2026-0021',12.00,'child_3_12y',0.8000,'soft_max_over',null,'clinical_judgment','attending','no_harm','not_required',null,null,'low','Within hard limit, soft override only'),
  ('2026-06-14 04:51:00+05:30','PT-2026-0033',3.20,'neonate_0_28d',1.5000,'hard_max_over',50.00,'wrong_drug_selected','resident','minor_harm','escalated_to_qc','2026-06-25',null,'critical','Wrong concentration selected; CDSCO 24h report filed'),
  ('2026-06-15 09:18:00+05:30','PT-2026-0041',14.00,'child_3_12y',0.4000,'bolus_over',null,'rapid_titration','fellow','no_harm','in_progress','2026-06-28',null,'medium','Bolus exceeded library max; pharmacy review'),
  ('2026-06-16 13:42:00+05:30','PT-2026-0055',9.80,'toddler_1_3y',0.6000,'free_flow_bypass',null,'none_given','rn','near_miss','open','2026-06-30',null,'high','Gravity clamp not engaged during transport'),
  ('2026-06-17 19:05:00+05:30','PT-2026-0062',11.50,'child_3_12y',1.1000,'hard_max_over',10.00,'library_outdated','attending','no_harm','reported_to_cdsco','2026-06-22',null,'critical','Library v4.1 still loaded on unit pump'),
  ('2026-06-18 07:28:00+05:30','PT-2026-0078',6.40,'infant_1_12m',0.3500,'no_library_entry',null,'training_gap','np','minor_harm','open','2026-07-02',null,'medium','Drug not in library; manual entry permitted'),
  ('2026-06-19 22:11:00+05:30','PT-2026-0084',13.20,'child_3_12y',1.0500,'hard_max_over',5.00,'clinical_judgment','attending','no_harm','closed','2026-06-21','2026-06-20 10:00:00+05:30','medium','Reviewed within threshold tolerance')
) as q(evt,pid,wt,ageb,prog,ok,pct,rsn,role,out,capa,due,closed,sev,nt);

-- =========================================================================
-- RPCs
-- =========================================================================

create or replace function r3124_summary()
returns table(total_entries bigint, active_entries bigint, quarantined bigint, draft bigint, signed_off bigint, freeflow_failing bigint, total_overrides bigint, capa_open bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select
    (select count(*) from pump_dose_library_entries_r3124),
    (select count(*) from pump_dose_library_entries_r3124 where status='active'),
    (select count(*) from pump_dose_library_entries_r3124 where status='quarantined'),
    (select count(*) from pump_dose_library_entries_r3124 where status='draft'),
    (select count(*) from pump_dose_library_entries_r3124 where library_signed_off_by_pharmd),
    (select count(*) from pump_dose_library_entries_r3124 where not free_flow_test_pass),
    (select count(*) from pump_dose_override_events_r3124),
    (select count(*) from pump_dose_override_events_r3124 where capa_status in ('open','in_progress','escalated_to_qc'));
end $$;

create or replace function r3124_library_by_unit()
returns table(hospital_unit text, entries bigint, active bigint, ff_fail bigint, signed_off bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.hospital_unit, count(*)::bigint,
    count(*) filter (where e.status='active')::bigint,
    count(*) filter (where not e.free_flow_test_pass)::bigint,
    count(*) filter (where e.library_signed_off_by_pharmd)::bigint
  from pump_dose_library_entries_r3124 e
  group by e.hospital_unit order by count(*) desc;
end $$;

create or replace function r3124_library_by_drug_class()
returns table(drug_class text, entries bigint, avg_hard_max numeric, avg_soft_max numeric, ff_protected bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.drug_class, count(*)::bigint,
    round(avg(e.hard_max_dose_per_kg_per_hr),4),
    round(avg(e.soft_max_dose_per_kg_per_hr),4),
    count(*) filter (where e.free_flow_protection_kind <> 'none')::bigint
  from pump_dose_library_entries_r3124 e
  group by e.drug_class order by count(*) desc;
end $$;

create or replace function r3124_overrides_by_kind()
returns table(override_kind text, events bigint, avg_pct_over numeric, critical_events bigint, capa_open bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.override_kind, count(*)::bigint,
    round(avg(coalesce(o.override_pct_over_hard,0)),2),
    count(*) filter (where o.severity='critical')::bigint,
    count(*) filter (where o.capa_status in ('open','in_progress','escalated_to_qc'))::bigint
  from pump_dose_override_events_r3124 o
  group by o.override_kind order by count(*) desc;
end $$;

create or replace function r3124_overrides_by_reason()
returns table(override_reason_code text, events bigint, near_miss bigint, harm_events bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.override_reason_code, count(*)::bigint,
    count(*) filter (where o.patient_outcome='near_miss')::bigint,
    count(*) filter (where o.patient_outcome in ('minor_harm','serious_harm','sentinel'))::bigint
  from pump_dose_override_events_r3124 o
  group by o.override_reason_code order by count(*) desc;
end $$;

create or replace function r3124_overrides_by_prescriber()
returns table(prescriber_role text, events bigint, hard_max_over_events bigint, avg_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.prescriber_role, count(*)::bigint,
    count(*) filter (where o.override_kind='hard_max_over')::bigint,
    round(avg(coalesce(o.override_pct_over_hard,0)),2)
  from pump_dose_override_events_r3124 o
  group by o.prescriber_role order by count(*) desc;
end $$;

create or replace function r3124_capa_aging()
returns table(capa_status text, events bigint, avg_age_days numeric, oldest_days numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.capa_status, count(*)::bigint,
    round(avg(extract(epoch from (now() - o.event_at))/86400)::numeric,1),
    round(max(extract(epoch from (now() - o.event_at))/86400)::numeric,1)
  from pump_dose_override_events_r3124 o
  group by o.capa_status order by count(*) desc;
end $$;

create or replace function r3124_critical_events()
returns table(event_at timestamptz, patient_pseudo_id text, override_kind text, override_pct_over_hard numeric, override_reason_code text, patient_outcome text, capa_status text, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select o.event_at, o.patient_pseudo_id, o.override_kind, o.override_pct_over_hard,
    o.override_reason_code, o.patient_outcome, o.capa_status, o.severity
  from pump_dose_override_events_r3124 o
  where o.severity in ('high','critical')
  order by o.event_at desc;
end $$;

create or replace function r3124_pump_freeflow_status()
returns table(pump_make_model text, total_pumps bigint, ff_failing bigint, last_test_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select e.pump_make_model, count(distinct e.pump_serial)::bigint,
    count(distinct e.pump_serial) filter (where not e.free_flow_test_pass)::bigint,
    max(e.free_flow_last_test_at)
  from pump_dose_library_entries_r3124 e
  group by e.pump_make_model order by count(distinct e.pump_serial) desc;
end $$;

-- Grants
revoke execute on function r3124_summary() from public, anon;
revoke execute on function r3124_library_by_unit() from public, anon;
revoke execute on function r3124_library_by_drug_class() from public, anon;
revoke execute on function r3124_overrides_by_kind() from public, anon;
revoke execute on function r3124_overrides_by_reason() from public, anon;
revoke execute on function r3124_overrides_by_prescriber() from public, anon;
revoke execute on function r3124_capa_aging() from public, anon;
revoke execute on function r3124_critical_events() from public, anon;
revoke execute on function r3124_pump_freeflow_status() from public, anon;

grant execute on function r3124_summary() to authenticated;
grant execute on function r3124_library_by_unit() to authenticated;
grant execute on function r3124_library_by_drug_class() to authenticated;
grant execute on function r3124_overrides_by_kind() to authenticated;
grant execute on function r3124_overrides_by_reason() to authenticated;
grant execute on function r3124_overrides_by_prescriber() to authenticated;
grant execute on function r3124_capa_aging() to authenticated;
grant execute on function r3124_critical_events() to authenticated;
grant execute on function r3124_pump_freeflow_status() to authenticated;
