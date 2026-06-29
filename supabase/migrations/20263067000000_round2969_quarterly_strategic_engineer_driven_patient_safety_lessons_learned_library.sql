-- Round r2969 — Founder Quarterly Strategic Engineer-Driven Patient-Safety Lessons-Learned Library

create table if not exists patient_safety_lessons_r2969 (
  id uuid primary key default gen_random_uuid(),
  quarter text not null,
  lesson_title text not null,
  device_category text not null check (device_category in ('ventilator','infusion_pump','dialysis','imaging','monitor','anesthesia','defib','surgical')),
  severity text not null check (severity in ('near_miss','minor','moderate','severe','sentinel')),
  root_cause text not null,
  corrective_action text not null,
  engineer_user_id uuid,
  hospital_org_id uuid,
  incidents_prevented int not null default 0,
  status text not null check (status in ('draft','published','archived')) default 'published',
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists patient_safety_lesson_endorsements_r2969 (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references patient_safety_lessons_r2969(id) on delete cascade,
  endorser_role text not null check (endorser_role in ('engineer','biomed','hospital_admin','founder','regulator')),
  endorsement_weight int not null check (endorsement_weight between 1 and 5),
  comment text,
  endorsed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table patient_safety_lessons_r2969 enable row level security;
alter table patient_safety_lesson_endorsements_r2969 enable row level security;

drop policy if exists psl_r2969_founder_all on patient_safety_lessons_r2969;
create policy psl_r2969_founder_all on patient_safety_lessons_r2969 for all using (is_founder()) with check (is_founder());

drop policy if exists psle_r2969_founder_all on patient_safety_lesson_endorsements_r2969;
create policy psle_r2969_founder_all on patient_safety_lesson_endorsements_r2969 for all using (is_founder()) with check (is_founder());

insert into patient_safety_lessons_r2969 (quarter, lesson_title, device_category, severity, root_cause, corrective_action, incidents_prevented, status, published_at) values
('2026-Q1','Ventilator PEEP valve sticking after deep clean','ventilator','severe','Chlorhexidine residue crystallized in valve seat','Switch to enzymatic cleaner + dry-cycle SOP',14,'published', now() - interval '180 days'),
('2026-Q1','Syringe pump siphoning on power loss','infusion_pump','sentinel','Pole height >120cm + no anti-siphon set','Mandate anti-siphon sets above 80cm pole',7,'published', now() - interval '175 days'),
('2026-Q1','Dialysis conductivity alarm masked','dialysis','moderate','Alarm priority set to low by ward','Lock alarm priorities at biomed level',22,'published', now() - interval '170 days'),
('2026-Q2','MRI quench valve corrosion','imaging','severe','Coastal humidity + missed annual swab','Quarterly swab + coating reapply',3,'published', now() - interval '120 days'),
('2026-Q2','Patient monitor SpO2 cable wear','monitor','minor','Re-use beyond 18 months','Cable replacement at 12 months hard cutoff',45,'published', now() - interval '115 days'),
('2026-Q2','Anesthesia vaporizer key-fill cross-pour','anesthesia','sentinel','Generic adapter used during shortage','Vendor-specific adapter audit Q2',2,'published', now() - interval '110 days'),
('2026-Q2','Defib pad expiry on crash cart','defib','severe','Crash cart audit skipped 3 months','Weekly cart audit + photo-log',9,'published', now() - interval '105 days'),
('2026-Q3','Laparoscope insulation breach','surgical','severe','Reprocessing brush abrasion','Replace brushes every 20 cycles',6,'published', now() - interval '70 days'),
('2026-Q3','BiPAP humidifier scale buildup','ventilator','moderate','Hard water + no descale SOP','Monthly citric descale',18,'published', now() - interval '65 days'),
('2026-Q3','Infusion pump free-flow on door','infusion_pump','severe','Worn door latch springs','Spring replacement at 5 years',11,'published', now() - interval '60 days'),
('2026-Q3','CT contrast injector air-detect false negative','imaging','severe','Firmware regression v3.4.1','Roll back to v3.3.7 fleet-wide',4,'published', now() - interval '55 days'),
('2026-Q3','Patient monitor ECG lead miswire','monitor','minor','New nursing staff training gap','Color-code wall chart in every bay',31,'published', now() - interval '50 days'),
('2026-Q4','Anesthesia O2 flush valve leak','anesthesia','moderate','O-ring degraded by sevoflurane spill','Sevoflurane spill SOP + O-ring kit',8,'published', now() - interval '20 days'),
('2026-Q4','Defib biphasic energy delivery drift','defib','severe','Capacitor aging at 7 years','Replace capacitors at year 7',5,'published', now() - interval '15 days'),
('2026-Q4','Dialysis reverse osmosis bacterial spike','dialysis','sentinel','Loop disinfection skipped during shortage','Mandatory monthly endotoxin assay',3,'published', now() - interval '10 days'),
('2026-Q4','Surgical drill bearing seizure mid-case','surgical','severe','Autoclave overrun damaging lubricant','Cycle-count enforced via RFID tag',6,'published', now() - interval '5 days'),
('2026-Q4','Patient warming blanket overheat','monitor','moderate','Sensor calibration drift','Annual sensor swap',12,'published', now() - interval '3 days'),
('2026-Q4','Imaging contrast warmer scald risk','imaging','minor','Thermostat stuck high','Quarterly thermostat verification',9,'published', now() - interval '2 days');

insert into patient_safety_lesson_endorsements_r2969 (lesson_id, endorser_role, endorsement_weight, comment)
select id, 'engineer', 5, 'Witnessed at site' from patient_safety_lessons_r2969 limit 6;
insert into patient_safety_lesson_endorsements_r2969 (lesson_id, endorser_role, endorsement_weight, comment)
select id, 'biomed', 4, 'Adopted in our facility' from patient_safety_lessons_r2969 limit 5;
insert into patient_safety_lesson_endorsements_r2969 (lesson_id, endorser_role, endorsement_weight, comment)
select id, 'hospital_admin', 3, 'Policy updated' from patient_safety_lessons_r2969 limit 4;
insert into patient_safety_lesson_endorsements_r2969 (lesson_id, endorser_role, endorsement_weight, comment)
select id, 'regulator', 5, 'Aligned with NABH' from patient_safety_lessons_r2969 limit 3;

create or replace function founder_psl_r2969_overview()
returns table(total_lessons int, total_endorsements int, total_incidents_prevented int, sentinel_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select
    (select count(*) from patient_safety_lessons_r2969)::int,
    (select count(*) from patient_safety_lesson_endorsements_r2969)::int,
    coalesce((select sum(incidents_prevented) from patient_safety_lessons_r2969),0)::int,
    (select count(*) filter (where severity = 'sentinel') from patient_safety_lessons_r2969)::int;
end $$;

create or replace function founder_psl_r2969_by_quarter()
returns table(quarter text, lesson_count int, incidents_prevented int, sentinel_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.quarter, count(*)::int, coalesce(sum(l.incidents_prevented),0)::int,
    (count(*) filter (where l.severity='sentinel'))::int
  from patient_safety_lessons_r2969 l
  group by l.quarter
  order by l.quarter desc;
end $$;

create or replace function founder_psl_r2969_by_category()
returns table(device_category text, lesson_count int, incidents_prevented int, avg_endorsement numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.device_category, count(*)::int, coalesce(sum(l.incidents_prevented),0)::int,
    coalesce((select avg(e.endorsement_weight) from patient_safety_lesson_endorsements_r2969 e
             join patient_safety_lessons_r2969 l2 on l2.id=e.lesson_id where l2.device_category=l.device_category),0)::numeric(10,2)
  from patient_safety_lessons_r2969 l
  group by l.device_category
  order by count(*) desc;
end $$;

create or replace function founder_psl_r2969_by_severity()
returns table(severity text, lesson_count int, incidents_prevented int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.severity, count(*)::int, coalesce(sum(l.incidents_prevented),0)::int
  from patient_safety_lessons_r2969 l
  group by l.severity
  order by case l.severity when 'sentinel' then 1 when 'severe' then 2 when 'moderate' then 3 when 'minor' then 4 else 5 end;
end $$;

create or replace function founder_psl_r2969_top_lessons()
returns table(lesson_title text, device_category text, severity text, incidents_prevented int, endorsement_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.lesson_title, l.device_category, l.severity, l.incidents_prevented,
    (select count(*) from patient_safety_lesson_endorsements_r2969 e where e.lesson_id=l.id)::int
  from patient_safety_lessons_r2969 l
  order by l.incidents_prevented desc
  limit 10;
end $$;

create or replace function founder_psl_r2969_endorsement_breakdown()
returns table(endorser_role text, endorsement_count int, avg_weight numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select e.endorser_role, count(*)::int, avg(e.endorsement_weight)::numeric(10,2)
  from patient_safety_lesson_endorsements_r2969 e
  group by e.endorser_role
  order by count(*) desc;
end $$;

create or replace function founder_psl_r2969_recent_published()
returns table(lesson_title text, device_category text, severity text, published_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.lesson_title, l.device_category, l.severity, l.published_at
  from patient_safety_lessons_r2969 l
  where l.status='published'
  order by l.published_at desc
  limit 12;
end $$;

create or replace function founder_psl_r2969_sentinel_focus()
returns table(lesson_title text, device_category text, root_cause text, corrective_action text, incidents_prevented int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select l.lesson_title, l.device_category, l.root_cause, l.corrective_action, l.incidents_prevented
  from patient_safety_lessons_r2969 l
  where l.severity='sentinel'
  order by l.published_at desc;
end $$;

revoke all on function founder_psl_r2969_overview() from public, anon;
revoke all on function founder_psl_r2969_by_quarter() from public, anon;
revoke all on function founder_psl_r2969_by_category() from public, anon;
revoke all on function founder_psl_r2969_by_severity() from public, anon;
revoke all on function founder_psl_r2969_top_lessons() from public, anon;
revoke all on function founder_psl_r2969_endorsement_breakdown() from public, anon;
revoke all on function founder_psl_r2969_recent_published() from public, anon;
revoke all on function founder_psl_r2969_sentinel_focus() from public, anon;

grant execute on function founder_psl_r2969_overview() to authenticated;
grant execute on function founder_psl_r2969_by_quarter() to authenticated;
grant execute on function founder_psl_r2969_by_category() to authenticated;
grant execute on function founder_psl_r2969_by_severity() to authenticated;
grant execute on function founder_psl_r2969_top_lessons() to authenticated;
grant execute on function founder_psl_r2969_endorsement_breakdown() to authenticated;
grant execute on function founder_psl_r2969_recent_published() to authenticated;
grant execute on function founder_psl_r2969_sentinel_focus() to authenticated;
