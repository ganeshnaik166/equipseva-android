-- Round 3396: Engineer Field CSAT Survey-Capture & Response-Rate Integrity Tracker
-- Survey ops — service type × channel × sent/completed × response time × CSAT × NPS category × verbatim × gaming flag × response verdict × CAPA

-- =============================================================================
-- TABLE 1: csat_survey_capture_r3396 — per-job survey capture records
-- =============================================================================
create table if not exists public.csat_survey_capture_r3396 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null check (region in ('north','south','east','west','central')),
  service_type text not null check (service_type in (
    'breakdown_repair','preventive_maintenance','installation','calibration','amc_visit'
  )),
  job_code text not null,
  survey_channel text not null check (survey_channel in (
    'sms','email','whatsapp','ivr','paper','in_person'
  )),
  survey_date date not null,
  survey_sent boolean not null,
  survey_completed boolean not null,
  response_time_hours numeric(7,2),
  csat_score int check (csat_score between 1 and 5),
  nps_category text not null check (nps_category in (
    'promoter','passive','detractor','not_scored'
  )),
  verbatim_captured boolean not null,
  follow_up_flag boolean not null,
  gaming_flag boolean not null,
  response_verdict text not null check (response_verdict in (
    'captured_clean','low_response','gaming_suspected','bias_risk','not_sent'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.csat_survey_capture_r3396 enable row level security;

create index if not exists idx_csat_survey_capture_r3396_org on public.csat_survey_capture_r3396(organization_id);
create index if not exists idx_csat_survey_capture_r3396_date on public.csat_survey_capture_r3396(survey_date);
create index if not exists idx_csat_survey_capture_r3396_verdict on public.csat_survey_capture_r3396(response_verdict);

-- =============================================================================
-- TABLE 2: csat_survey_capture_capa_actions_r3396 — CAPA & process actions
-- =============================================================================
create table if not exists public.csat_survey_capture_capa_actions_r3396 (
  id uuid primary key default gen_random_uuid(),
  survey_log_id uuid not null references public.csat_survey_capture_r3396(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'survey_not_sent','low_response_rate','gaming_suspected','sample_bias',
    'detractor_no_followup','verbatim_missing','channel_ineffective','response_delay'
  )),
  root_cause text not null check (root_cause in (
    'process_gap','wrong_contact_details','engineer_influence','channel_mismatch',
    'timing_issue','followup_backlog','system_integration_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'enforce_auto_send','update_contact_capture','anti_gaming_controls','diversify_channels',
    'optimize_send_timing','clear_followup_backlog','fix_integration','coach_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cx_impact text not null check (cx_impact in (
    'high','moderate','low','none','trust_risk','data_integrity_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.csat_survey_capture_capa_actions_r3396 enable row level security;

create index if not exists idx_csat_survey_capa_r3396_log on public.csat_survey_capture_capa_actions_r3396(survey_log_id);
create index if not exists idx_csat_survey_capa_r3396_status on public.csat_survey_capture_capa_actions_r3396(capa_status);

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

  insert into public.csat_survey_capture_r3396 (
    organization_id, engineer_name, hospital_name, region, service_type, job_code, survey_channel, survey_date,
    survey_sent, survey_completed, response_time_hours, csat_score, nps_category,
    verbatim_captured, follow_up_flag, gaming_flag, response_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.region, q.stype, q.jobcode, q.channel, q.sdate::date,
    q.sent, q.completed, q.rt, q.csat, q.nps,
    q.verbatim, q.followup, q.gaming, q.rv, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','south','breakdown_repair','JOB-APL-8801','whatsapp','2026-07-03',
     true,true,4.5,5,'promoter',true,false,false,'captured_clean','WhatsApp survey completed, promoter with verbatim'),
    ('Anita Desai','Fortis Gurgaon','north','amc_visit','JOB-FRT-8802','email','2026-07-02',
     true,true,20.0,4,'passive',false,false,false,'captured_clean','Email survey completed, passive score'),
    ('Suresh Nair','Manipal Bengaluru','south','installation','JOB-MNP-8803','sms','2026-07-02',
     true,false,null,null,'not_scored',false,false,false,'low_response','SMS survey sent, no response — low response pattern for SMS'),
    ('Priya Menon','AIIMS Delhi','central','preventive_maintenance','JOB-AIM-8804','ivr','2026-07-01',
     true,true,6.0,2,'detractor',true,true,false,'captured_clean','IVR detractor with verbatim — follow-up flagged'),
    ('Vikram Rao','CMC Vellore','south','breakdown_repair','JOB-CMC-8805','whatsapp','2026-07-01',
     true,true,1.0,5,'promoter',false,false,true,'gaming_suspected','Suspiciously fast 5-star with no verbatim — possible engineer influence'),
    ('Deepa Iyer','KIMS Hyderabad','south','calibration','JOB-KIM-8806','email','2026-06-30',
     true,true,30.0,4,'passive',true,false,false,'captured_clean','Email survey completed with comments'),
    ('Arjun Shah','Yashoda Hyderabad','south','amc_visit','JOB-YSH-8807','sms','2026-06-30',
     false,false,null,null,'not_scored',false,false,false,'not_sent','Survey not triggered — contact number missing in system'),
    ('Ravi Kumar','Apollo Chennai','south','preventive_maintenance','JOB-APL-8808','in_person','2026-06-29',
     true,true,0.5,5,'promoter',true,false,true,'gaming_suspected','In-person survey collected by same engineer — bias risk'),
    ('Anita Desai','Fortis Gurgaon','north','breakdown_repair','JOB-FRT-8809','whatsapp','2026-06-29',
     true,true,3.0,3,'detractor',true,false,false,'captured_clean','WhatsApp detractor with detailed verbatim'),
    ('Suresh Nair','Manipal Bengaluru','south','installation','JOB-MNP-8810','sms','2026-06-28',
     true,false,null,null,'not_scored',false,false,false,'low_response','SMS non-response — channel ineffective for this segment'),
    ('Priya Menon','AIIMS Delhi','central','amc_visit','JOB-AIM-8811','email','2026-06-28',
     true,true,18.0,5,'promoter',true,false,false,'captured_clean','Email promoter with verbatim'),
    ('Vikram Rao','CMC Vellore','south','calibration','JOB-CMC-8812','ivr','2026-06-27',
     true,true,48.0,2,'detractor',false,false,false,'bias_risk','Only detractors responding via IVR — sample bias flagged'),
    ('Deepa Iyer','KIMS Hyderabad','south','breakdown_repair','JOB-KIM-8813','whatsapp','2026-06-27',
     true,true,2.5,4,'passive',true,false,false,'captured_clean','WhatsApp passive with comments'),
    ('Arjun Shah','Kokilaben Mumbai','west','preventive_maintenance','JOB-KKB-8814','sms','2026-06-26',
     false,false,null,null,'not_scored',false,false,false,'not_sent','Survey automation failed — integration gap not sending SMS')
  ) as q(eng, hosp, region, stype, jobcode, channel, sdate, sent, completed, rt, csat, nps, verbatim, followup, gaming, rv, nt);

  insert into public.csat_survey_capture_capa_actions_r3396 (
    survey_log_id, finding_category, root_cause, corrective_action,
    capa_status, cx_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-CMC-8805','gaming_suspected','engineer_influence','anti_gaming_controls','in_progress','data_integrity_risk','2026-07-06',null,0.00,'Enable independent survey link, block engineer-collected scores'),
    ('JOB-APL-8808','sample_bias','engineer_influence','anti_gaming_controls','open','data_integrity_risk','2026-07-05',null,0.00,'In-person surveys to move to independent channel'),
    ('JOB-YSH-8807','survey_not_sent','wrong_contact_details','update_contact_capture','open','moderate','2026-07-05',null,0.00,'Capture verified mobile at job close'),
    ('JOB-KKB-8814','survey_not_sent','system_integration_gap','fix_integration','escalated','trust_risk','2026-07-04',null,12000.00,'SMS automation integration failure escalated to IT'),
    ('JOB-AIM-8804','detractor_no_followup','followup_backlog','clear_followup_backlog','verification_pending','high','2026-07-05',null,0.00,'Detractor follow-up call completed — verify recovery'),
    ('JOB-CMC-8812','sample_bias','channel_mismatch','diversify_channels','overdue','moderate','2026-06-30',null,0.00,'IVR sample bias — add WhatsApp for balanced response'),
    ('JOB-MNP-8810','low_response_rate','channel_mismatch','diversify_channels','open','low','2026-07-08',null,0.00,'SMS low response — shift installation segment to WhatsApp')
  ) as q(jobcode, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.csat_survey_capture_r3396 e
    on e.organization_id = v_org_id and e.job_code = q.jobcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3396_response_verdict_rollup()
returns table(response_verdict text, records bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.csat_survey_capture_r3396)
  select l.response_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.csat_survey_capture_r3396 l group by l.response_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_response_verdict_rollup() from public, anon;
grant execute on function public.founder_r3396_response_verdict_rollup() to authenticated;

create or replace function public.founder_r3396_engineer_scorecard()
returns table(
  engineer_name text, jobs bigint, surveys_sent bigint, completed bigint, response_rate_pct numeric,
  avg_csat numeric, detractors bigint, gaming_flags bigint, clean_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, count(*)::bigint,
    count(*) filter (where l.survey_sent = true)::bigint,
    count(*) filter (where l.survey_completed = true)::bigint,
    round(100.0 * count(*) filter (where l.survey_completed = true)::numeric / nullif(count(*) filter (where l.survey_sent = true),0), 1),
    round(avg(l.csat_score), 2),
    count(*) filter (where l.nps_category = 'detractor')::bigint,
    count(*) filter (where l.gaming_flag = true)::bigint,
    round(100.0 * count(*) filter (where l.response_verdict = 'captured_clean')::numeric / nullif(count(*),0), 1)
  from public.csat_survey_capture_r3396 l group by l.engineer_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3396_engineer_scorecard() to authenticated;

create or replace function public.founder_r3396_channel_service_matrix()
returns table(survey_channel text, service_type text, records bigint, completed bigint, response_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.survey_channel, l.service_type, count(*)::bigint,
    count(*) filter (where l.survey_completed = true)::bigint,
    round(100.0 * count(*) filter (where l.survey_completed = true)::numeric / nullif(count(*) filter (where l.survey_sent = true),0), 1)
  from public.csat_survey_capture_r3396 l group by l.survey_channel, l.service_type order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_channel_service_matrix() from public, anon;
grant execute on function public.founder_r3396_channel_service_matrix() to authenticated;

create or replace function public.founder_r3396_daily_response_trend()
returns table(survey_date date, records bigint, completed bigint, detractors bigint, gaming_flags bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.survey_date, count(*)::bigint,
    count(*) filter (where l.survey_completed = true)::bigint,
    count(*) filter (where l.nps_category = 'detractor')::bigint,
    count(*) filter (where l.gaming_flag = true)::bigint
  from public.csat_survey_capture_r3396 l group by l.survey_date order by l.survey_date desc;
end;
$$;
revoke execute on function public.founder_r3396_daily_response_trend() from public, anon;
grant execute on function public.founder_r3396_daily_response_trend() to authenticated;

create or replace function public.founder_r3396_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.csat_survey_capture_capa_actions_r3396 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_capa_status_board() from public, anon;
grant execute on function public.founder_r3396_capa_status_board() to authenticated;

create or replace function public.founder_r3396_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.csat_survey_capture_capa_actions_r3396)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.csat_survey_capture_capa_actions_r3396 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3396_root_cause_pareto() to authenticated;

create or replace function public.founder_r3396_cx_impact_digest()
returns table(cx_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.cx_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.csat_survey_capture_capa_actions_r3396 c group by c.cx_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3396_cx_impact_digest() from public, anon;
grant execute on function public.founder_r3396_cx_impact_digest() to authenticated;

create or replace function public.founder_r3396_high_risk_queue()
returns table(
  hospital_name text, engineer_name text, job_code text, service_type text, survey_channel text,
  survey_date date, csat_score int, nps_category text, response_verdict text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.job_code, l.service_type, l.survey_channel,
    l.survey_date, l.csat_score, l.nps_category, l.response_verdict, l.notes
  from public.csat_survey_capture_r3396 l
  where l.response_verdict in ('low_response','gaming_suspected','bias_risk','not_sent')
     or l.nps_category = 'detractor'
     or l.gaming_flag = true
     or l.follow_up_flag = true
     or (l.survey_sent = true and l.survey_completed = false)
  order by
    case l.response_verdict when 'gaming_suspected' then 0 when 'bias_risk' then 1 when 'not_sent' then 2 else 3 end,
    l.survey_date desc;
end;
$$;
revoke execute on function public.founder_r3396_high_risk_queue() from public, anon;
grant execute on function public.founder_r3396_high_risk_queue() to authenticated;
