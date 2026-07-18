-- Round 3164: Engineer Per-Visit Customer NPS & Service-Quality Feedback Tracker
-- Per-visit feedback log — engineer × visit type × NPS 0-10 × segment × punctuality × fix-first-time
--   × cleanliness × would-rebook × sentiment × verdict + follow-up/CAPA actions

-- =============================================================================
-- TABLE 1: engineer_nps_r3164 — one customer feedback row per engineer visit
-- =============================================================================
create table if not exists public.engineer_nps_r3164 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  visit_ref text not null,
  hospital_name text not null,
  hospital_city text not null,
  engineer_name text not null,
  engineer_code text not null,
  visit_date date not null,
  visit_type text not null check (visit_type in (
    'preventive_maintenance','breakdown_repair','installation','warranty_claim',
    'amc_scheduled','calibration','emergency_callout','commissioning'
  )),
  equipment_domain text not null check (equipment_domain in (
    'imaging_radiology','operating_theatre','icu_critical_care','laboratory_diagnostics',
    'sterilization_cssd','patient_monitoring','dialysis_renal','general_biomedical'
  )),
  nps_score int not null check (nps_score between 0 and 10),
  nps_segment text not null check (nps_segment in ('promoter','passive','detractor')),
  punctuality_rating text not null check (punctuality_rating in (
    'early','on_time','slightly_late','very_late','no_show'
  )),
  fix_first_time boolean not null default false,
  cleanliness_rating text check (cleanliness_rating in (
    'excellent','good','fair','poor','unacceptable'
  )),
  would_rebook text not null check (would_rebook in (
    'definitely','probably','unsure','probably_not','definitely_not'
  )),
  sentiment text check (sentiment in (
    'delighted','satisfied','neutral','frustrated','angry'
  )),
  communication_rating text check (communication_rating in (
    'excellent','good','fair','poor','unacceptable'
  )),
  resolution_hours numeric(6,2),
  feedback_channel text not null check (feedback_channel in (
    'sms_survey','whatsapp','phone_call','email','in_app','paper_form'
  )),
  feedback_status text not null check (feedback_status in (
    'celebrate','routine','coach_engineer','service_recovery',
    'escalate_manager','churn_risk','pending_review'
  )),
  survey_submitted_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_nps_r3164 enable row level security;

create index if not exists idx_engineer_nps_r3164_org on public.engineer_nps_r3164(organization_id);
create index if not exists idx_engineer_nps_r3164_date on public.engineer_nps_r3164(visit_date);
create index if not exists idx_engineer_nps_r3164_status on public.engineer_nps_r3164(feedback_status);

-- =============================================================================
-- TABLE 2: engineer_nps_capa_actions_r3164 — follow-up / CAPA / service recovery
-- =============================================================================
create table if not exists public.engineer_nps_capa_actions_r3164 (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.engineer_nps_r3164(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'late_arrival','repeat_visit_needed','poor_cleanliness','communication_gap',
    'unresolved_fault','billing_dispute','rude_behavior','parts_delay',
    'safety_concern','excellent_service'
  )),
  root_cause text not null check (root_cause in (
    'engineer_skill_gap','scheduling_overload','spare_parts_stockout','traffic_logistics',
    'unclear_scope','tooling_shortage','customer_expectation_mismatch','process_gap',
    'pending_investigation','none_identified'
  )),
  corrective_action text not null check (corrective_action in (
    'engineer_coaching','reassign_senior_engineer','revisit_scheduled','apology_call_made',
    'parts_expedited','process_update','goodwill_credit_issued','route_optimization',
    'none_required','recognition_awarded'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','sla_breach','contract_penalty','churn_risk_flag','reputation_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_nps_capa_actions_r3164 enable row level security;

create index if not exists idx_engineer_nps_capa_r3164_feedback on public.engineer_nps_capa_actions_r3164(feedback_id);
create index if not exists idx_engineer_nps_capa_r3164_status on public.engineer_nps_capa_actions_r3164(capa_status);

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

  -- 14 per-visit feedback rows
  insert into public.engineer_nps_r3164 (
    organization_id, visit_ref, hospital_name, hospital_city, engineer_name, engineer_code,
    visit_date, visit_type, equipment_domain, nps_score, nps_segment, punctuality_rating,
    fix_first_time, cleanliness_rating, would_rebook, sentiment, communication_rating,
    resolution_hours, feedback_channel, feedback_status, survey_submitted_at, notes
  )
  select v_org_id, q.ref, q.hosp, q.city, q.eng, q.code,
    q.vd::date, q.vtype, q.edom, q.nps, q.seg, q.punc,
    q.fft, q.clean, q.rebook, q.sent, q.comm,
    q.reshrs, q.chan, q.status, q.subat::timestamptz, q.nt
  from (values
    ('V-APL-0001','Apollo Hospitals Jubilee Hills','Hyderabad','Ravi Teja Konda','ENG-APL-11',
     '2026-07-16','preventive_maintenance','imaging_radiology',10,'promoter','on_time',
     true,'excellent','definitely','delighted','excellent',
     1.50,'whatsapp','celebrate','2026-07-16 12:30:00+05:30','CT gantry PM done ahead of schedule, staff delighted'),
    ('V-APL-0002','Apollo Hospitals Jubilee Hills','Hyderabad','Suresh Babu Y','ENG-APL-04',
     '2026-07-15','breakdown_repair','operating_theatre',8,'passive','slightly_late',
     true,'good','probably','satisfied','good',
     3.25,'sms_survey','routine','2026-07-15 18:10:00+05:30','OT light driver replaced, arrived 20 min late'),
    ('V-FRT-0007','Fortis Bannerghatta','Bengaluru','Anil Kumar Reddy','ENG-FRT-09',
     '2026-07-15','breakdown_repair','icu_critical_care',3,'detractor','very_late',
     false,'fair','probably_not','frustrated','fair',
     6.50,'phone_call','service_recovery','2026-07-15 20:45:00+05:30','Ventilator still alarming after visit, needs revisit'),
    ('V-FRT-0008','Fortis Bannerghatta','Bengaluru','Anil Kumar Reddy','ENG-FRT-09',
     '2026-07-14','amc_scheduled','patient_monitoring',2,'detractor','no_show',
     false,'poor','definitely_not','angry','poor',
     null,'in_app','escalate_manager','2026-07-14 17:00:00+05:30','Engineer no-show on scheduled AMC slot, customer angry'),
    ('V-MNP-0021','Manipal Hospital Whitefield','Bengaluru','Deepa Nair','ENG-MNP-02',
     '2026-07-14','installation','laboratory_diagnostics',9,'promoter','early',
     true,'excellent','definitely','delighted','excellent',
     4.00,'email','celebrate','2026-07-14 15:20:00+05:30','Analyzer install smooth, lab head very happy'),
    ('V-MNP-0022','Manipal Hospital Whitefield','Bengaluru','Deepa Nair','ENG-MNP-02',
     '2026-07-13','calibration','patient_monitoring',7,'passive','on_time',
     true,'good','probably','satisfied','good',
     2.00,'sms_survey','routine','2026-07-13 11:40:00+05:30','Monitor calibration done, minor documentation delay'),
    ('V-AIM-0033','AIIMS Ansari Nagar','New Delhi','Vikram Singh Rana','ENG-AIM-06',
     '2026-07-13','breakdown_repair','dialysis_renal',4,'detractor','slightly_late',
     false,'fair','unsure','frustrated','fair',
     5.75,'phone_call','coach_engineer','2026-07-13 19:30:00+05:30','Dialysis unit leak not fully fixed, second engineer needed'),
    ('V-AIM-0034','AIIMS Ansari Nagar','New Delhi','Vikram Singh Rana','ENG-AIM-06',
     '2026-07-12','emergency_callout','icu_critical_care',10,'promoter','on_time',
     true,'excellent','definitely','delighted','excellent',
     1.25,'whatsapp','celebrate','2026-07-12 03:15:00+05:30','Night emergency vent fixed fast, ICU grateful'),
    ('V-KIM-0011','KIMS Hospital','Secunderabad','Naveen Chandra','ENG-KIM-03',
     '2026-07-12','warranty_claim','sterilization_cssd',2,'detractor','very_late',
     false,'unacceptable','definitely_not','angry','poor',
     8.00,'in_app','churn_risk','2026-07-12 21:10:00+05:30','Autoclave warranty claim mishandled, threatening to switch vendor'),
    ('V-KIM-0012','KIMS Hospital','Secunderabad','Naveen Chandra','ENG-KIM-03',
     '2026-07-11','preventive_maintenance','general_biomedical',6,'passive','slightly_late',
     true,'fair','unsure','neutral','fair',
     2.50,'sms_survey','coach_engineer','2026-07-11 16:00:00+05:30','Routine PM ok but engineer rushed, mixed feedback'),
    ('V-CAR-0005','Care Hospitals Banjara Hills','Hyderabad','Lakshmi Prasad','ENG-CAR-07',
     '2026-07-11','commissioning','operating_theatre',9,'promoter','on_time',
     true,'excellent','definitely','delighted','good',
     3.00,'email','celebrate','2026-07-11 14:05:00+05:30','New OT integration commissioned, team satisfied'),
    ('V-YSH-0018','Yashoda Hospital Somajiguda','Hyderabad','Mahesh Goud','ENG-YSH-05',
     '2026-07-10','breakdown_repair','imaging_radiology',7,'passive','on_time',
     true,'good','probably','satisfied','good',
     4.50,'whatsapp','routine','2026-07-10 13:20:00+05:30','MRI chiller repaired, wants faster future response'),
    ('V-STJ-0003','St John''s Medical College','Bengaluru','Thomas Mathew','ENG-STJ-08',
     '2026-07-10','breakdown_repair','laboratory_diagnostics',3,'detractor','very_late',
     false,'poor','probably_not','frustrated','poor',
     7.25,'phone_call','service_recovery','2026-07-10 22:00:00+05:30','Centrifuge repair delayed by parts, lab downtime'),
    ('V-RBW-0009','Rainbow Children''s Hospital','Hyderabad','Sridevi Rao','ENG-RBW-10',
     '2026-07-09','installation','patient_monitoring',10,'promoter','early',
     true,'excellent','definitely','delighted','excellent',
     2.75,'in_app','celebrate','2026-07-09 10:30:00+05:30','Neonatal monitor install flawless, NICU thrilled')
  ) as q(ref, hosp, city, eng, code, vd, vtype, edom, nps, seg, punc,
         fft, clean, rebook, sent, comm, reshrs, chan, status, subat, nt);

  -- CAPA / follow-up seed — attach to specific visits by visit_ref
  insert into public.engineer_nps_capa_actions_r3164 (
    feedback_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.status, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('V-FRT-0007','repeat_visit_needed','engineer_skill_gap','reassign_senior_engineer',
     'in_progress','sla_breach','2026-07-19',null,3500.00,'Senior ICU engineer assigned for ventilator revisit'),
    ('V-FRT-0008','late_arrival','scheduling_overload','route_optimization',
     'escalated','contract_penalty','2026-07-18',null,0.00,'AMC no-show escalated, route and slot planning revised'),
    ('V-AIM-0033','unresolved_fault','spare_parts_stockout','parts_expedited',
     'in_progress','sla_breach','2026-07-20',null,12000.00,'Dialysis membrane kit expedited from Delhi warehouse'),
    ('V-KIM-0011','billing_dispute','customer_expectation_mismatch','apology_call_made',
     'open','churn_risk_flag','2026-07-21',null,25000.00,'Warranty claim reviewed, goodwill and apology call planned'),
    ('V-STJ-0003','parts_delay','spare_parts_stockout','parts_expedited',
     'verification_pending','sla_breach','2026-07-17','2026-07-16',6800.00,'Centrifuge rotor sourced, downtime credit under review'),
    ('V-KIM-0012','communication_gap','engineer_skill_gap','engineer_coaching',
     'closed','internal_only','2026-07-15','2026-07-14',1500.00,'Engineer coached on customer communication and pacing')
  ) as q(ref_key, fc, rc, ca, status, ri, tcd, acd, cost, nt)
  join public.engineer_nps_r3164 e
    on e.organization_id = v_org_id and e.visit_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Feedback status / verdict distribution
create or replace function public.founder_r3164_feedback_status_rollup()
returns table(feedback_status text, visits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_nps_r3164)
  select l.feedback_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_nps_r3164 l
  group by l.feedback_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_feedback_status_rollup() from public, anon;
grant execute on function public.founder_r3164_feedback_status_rollup() to authenticated;

-- 2) Hospital-level NPS scorecard
create or replace function public.founder_r3164_hospital_scorecard()
returns table(
  hospital_name text,
  visits bigint,
  promoters bigint,
  passives bigint,
  detractors bigint,
  avg_nps numeric,
  nps_net numeric,
  fix_first_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.nps_segment = 'promoter')::bigint,
    count(*) filter (where l.nps_segment = 'passive')::bigint,
    count(*) filter (where l.nps_segment = 'detractor')::bigint,
    round(avg(l.nps_score), 2),
    round(100.0 * (count(*) filter (where l.nps_segment = 'promoter')
                   - count(*) filter (where l.nps_segment = 'detractor'))::numeric
          / nullif(count(*),0), 1),
    round(100.0 * count(*) filter (where l.fix_first_time)::numeric / nullif(count(*),0), 1)
  from public.engineer_nps_r3164 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3164_hospital_scorecard() to authenticated;

-- 3) Visit-type × equipment-domain matrix
create or replace function public.founder_r3164_visit_equipment_matrix()
returns table(visit_type text, equipment_domain text, visits bigint, avg_nps numeric, detractors bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.visit_type, l.equipment_domain, count(*)::bigint,
    round(avg(l.nps_score), 2),
    count(*) filter (where l.nps_segment = 'detractor')::bigint
  from public.engineer_nps_r3164 l
  group by l.visit_type, l.equipment_domain
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_visit_equipment_matrix() from public, anon;
grant execute on function public.founder_r3164_visit_equipment_matrix() to authenticated;

-- 4) Daily NPS trend
create or replace function public.founder_r3164_nps_daily_trend()
returns table(visit_date date, visits bigint, avg_nps numeric, promoters bigint, detractors bigint, nps_net numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.visit_date, count(*)::bigint,
    round(avg(l.nps_score), 2),
    count(*) filter (where l.nps_segment = 'promoter')::bigint,
    count(*) filter (where l.nps_segment = 'detractor')::bigint,
    round(100.0 * (count(*) filter (where l.nps_segment = 'promoter')
                   - count(*) filter (where l.nps_segment = 'detractor'))::numeric
          / nullif(count(*),0), 1)
  from public.engineer_nps_r3164 l
  group by l.visit_date
  order by l.visit_date desc;
end;
$$;

revoke execute on function public.founder_r3164_nps_daily_trend() from public, anon;
grant execute on function public.founder_r3164_nps_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3164_capa_status_board()
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
  from public.engineer_nps_capa_actions_r3164 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_capa_status_board() from public, anon;
grant execute on function public.founder_r3164_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3164_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_nps_capa_actions_r3164)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_nps_capa_actions_r3164 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3164_root_cause_pareto() to authenticated;

-- 7) Regulatory / service-impact digest
create or replace function public.founder_r3164_impact_digest()
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
  from public.engineer_nps_capa_actions_r3164 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3164_impact_digest() from public, anon;
grant execute on function public.founder_r3164_impact_digest() to authenticated;

-- 8) High-risk / priority feedback queue
create or replace function public.founder_r3164_priority_queue()
returns table(
  hospital_name text,
  engineer_name text,
  visit_date date,
  visit_type text,
  nps_score int,
  nps_segment text,
  feedback_status text,
  punctuality_rating text,
  would_rebook text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.visit_date, l.visit_type,
    l.nps_score, l.nps_segment, l.feedback_status, l.punctuality_rating, l.would_rebook, l.notes
  from public.engineer_nps_r3164 l
  where l.nps_segment = 'detractor'
     or l.feedback_status in ('service_recovery','escalate_manager','churn_risk','coach_engineer','pending_review')
     or l.would_rebook in ('probably_not','definitely_not')
     or l.punctuality_rating in ('very_late','no_show')
  order by l.nps_score asc, l.visit_date desc;
end;
$$;

revoke execute on function public.founder_r3164_priority_queue() from public, anon;
grant execute on function public.founder_r3164_priority_queue() to authenticated;
