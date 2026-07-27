-- Round 3492: Engineer Customer-Complaint Severity-Triage / Response-TAT Tracker
-- Customer complaint severity triage + response/resolution TAT (turnaround) tracker —
-- engineer × hospital × device model × severity × category × triage status × response TAT ×
-- resolution TAT × SLA breach × CAPA closure

-- =============================================================================
-- TABLE 1: complaint_triage_tat_r3492 — per-complaint severity triage & TAT log
-- =============================================================================
create table if not exists public.complaint_triage_tat_r3492 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  complaint_code text not null,
  device_model text not null,
  severity text not null check (severity in (
    'critical_safety','major','moderate','minor','cosmetic'
  )),
  category text not null check (category in (
    'device_malfunction','service_delay','part_quality','billing','staff_conduct','documentation','other'
  )),
  triage_status text not null check (triage_status in (
    'new','acknowledged','investigating','resolved','escalated','closed'
  )),
  response_tat_hours numeric(8,2),
  resolution_tat_hours numeric(8,2),
  sla_hours int,
  sla_breached boolean not null,
  raised_date date not null,
  resolved_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.complaint_triage_tat_r3492 enable row level security;

create index if not exists idx_complaint_triage_tat_r3492_org on public.complaint_triage_tat_r3492(organization_id);
create index if not exists idx_complaint_triage_tat_r3492_raised on public.complaint_triage_tat_r3492(raised_date);
create index if not exists idx_complaint_triage_tat_r3492_severity on public.complaint_triage_tat_r3492(severity);

-- =============================================================================
-- TABLE 2: complaint_triage_tat_capa_actions_r3492 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.complaint_triage_tat_capa_actions_r3492 (
  id uuid primary key default gen_random_uuid(),
  complaint_log_id uuid not null references public.complaint_triage_tat_r3492(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'response_sla_breach','resolution_delay','recurring_defect','part_quality_issue',
    'communication_gap','documentation_gap','safety_incident','billing_dispute',
    'staff_conduct_issue','root_cause_pending'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_staffing','spare_part_unavailable','faulty_component','process_gap',
    'training_gap','vendor_delay','communication_breakdown','documentation_error',
    'pending_investigation','design_defect'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_spare_dispatch','add_field_engineer','replace_faulty_component','revise_sla_process',
    'retrain_staff','escalate_to_oem','improve_communication_protocol','update_documentation',
    'issue_credit_note','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.complaint_triage_tat_capa_actions_r3492 enable row level security;

create index if not exists idx_complaint_triage_capa_r3492_log on public.complaint_triage_tat_capa_actions_r3492(complaint_log_id);
create index if not exists idx_complaint_triage_capa_r3492_status on public.complaint_triage_tat_capa_actions_r3492(capa_status);

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

  -- 16 complaint rows
  insert into public.complaint_triage_tat_r3492 (
    organization_id, engineer_name, hospital_name, complaint_code, device_model,
    severity, category, triage_status, response_tat_hours, resolution_tat_hours,
    sla_hours, sla_breached, raised_date, resolved_date, notes
  )
  select v_org_id, q.eng, q.hosp, q.ccode, q.model,
    q.sev, q.cat, q.tstat, q.rtat, q.restat,
    q.sla, q.breach, q.rdate::date, q.resdate::date, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','CMP-APL-1001','Philips IntelliVue MX550','major','device_malfunction','resolved',
     2.5,18.0,8,false,'2026-07-02','2026-07-03','Monitor rebooted intermittently; firmware patched'),
    ('Anita Desai','Apollo Chennai','CMP-APL-1002','GE Carescape B650','moderate','service_delay','closed',
     6.0,40.0,12,true,'2026-07-01','2026-07-03','Response delayed due to engineer travel; SLA missed'),
    ('Suresh Nair','Fortis Gurgaon','CMP-FRT-1003','Drager Fabius GS','critical_safety','device_malfunction','escalated',
     1.0,null,4,false,'2026-07-05',null,'Anesthesia machine O2 sensor fault — escalated to OEM'),
    ('Priya Menon','Fortis Gurgaon','CMP-FRT-1004','Mindray BeneVision N22','minor','documentation','resolved',
     3.5,20.0,24,false,'2026-07-04','2026-07-05','Missing calibration certificate reissued'),
    ('Ravi Kumar','Manipal Bengaluru','CMP-MNP-1005','Nihon Kohden BSM-6000','major','part_quality','investigating',
     4.0,null,8,false,'2026-07-06',null,'ECG lead connector failing repeatedly — part quality suspected'),
    ('Karthik Rao','Manipal Bengaluru','CMP-MNP-1006','Siemens SC7000','moderate','billing','closed',
     5.0,72.0,48,true,'2026-06-28','2026-07-01','Billing dispute over AMC scope resolved with credit note'),
    ('Anita Desai','AIIMS Delhi','CMP-AIM-1007','Philips Efficia CM120','critical_safety','device_malfunction','escalated',
     0.5,null,4,false,'2026-07-07',null,'Defib monitor failed self-test in trauma bay — urgent'),
    ('Suresh Nair','AIIMS Delhi','CMP-AIM-1008','GE Datex-Ohmeda Aisys','minor','staff_conduct','resolved',
     8.0,30.0,24,false,'2026-07-03','2026-07-04','Complaint about technician conduct; counseled'),
    ('Priya Menon','CMC Vellore','CMP-CMC-1009','Mindray uMEC12','moderate','service_delay','acknowledged',
     10.0,null,8,true,'2026-07-06',null,'Delayed acknowledgement — engineer bandwidth constrained'),
    ('Karthik Rao','CMC Vellore','CMP-CMC-1010','Schiller Argus LCM','cosmetic','other','closed',
     12.0,48.0,72,false,'2026-06-25','2026-06-28','Display bezel scratch — cosmetic, replaced during PM'),
    ('Ravi Kumar','KIMS Hyderabad','CMP-KIM-1011','Philips IntelliVue MX450','major','device_malfunction','resolved',
     3.0,22.0,8,false,'2026-07-02','2026-07-03','NIBP module drift corrected and recalibrated'),
    ('Anita Desai','KIMS Hyderabad','CMP-KIM-1012','GE Carescape R860','critical_safety','part_quality','investigating',
     1.5,null,4,true,'2026-07-01',null,'Ventilator expiratory valve fault — SLA breached, investigating'),
    ('Suresh Nair','Yashoda Hyderabad','CMP-YSH-1013','Drager Evita V300','moderate','documentation','new',
     null,null,12,false,'2026-07-07',null,'New complaint — service report not filed, awaiting triage'),
    ('Priya Menon','Yashoda Hyderabad','CMP-YSH-1014','Mindray BeneHeart D6','minor','billing','resolved',
     6.5,26.0,24,false,'2026-06-30','2026-07-01','Duplicate invoice corrected'),
    ('Karthik Rao','Kokilaben Mumbai','CMP-KKB-1015','Philips IntelliVue MX800','critical_safety','device_malfunction','escalated',
     0.8,null,4,true,'2026-07-05',null,'Central station data loss during code blue — patient safety'),
    ('Ravi Kumar','Kokilaben Mumbai','CMP-KKB-1016','GE Carescape B450','major','service_delay','closed',
     7.0,60.0,12,true,'2026-06-27','2026-06-30','Repeat visit needed for spare; SLA missed, resolved')
  ) as q(eng, hosp, ccode, model, sev, cat, tstat, rtat, restat, sla, breach, rdate, resdate, nt);

  -- CAPA seed — attach to specific complaints via complaint_code
  insert into public.complaint_triage_tat_capa_actions_r3492 (
    complaint_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CMP-APL-1002','response_sla_breach','inadequate_staffing','add_field_engineer','in_progress','internal_only',
     'Ops Lead - Chennai','2026-07-10',null,25000.00,'Adding a second field engineer to Chennai zone to meet SLA'),
    ('CMP-FRT-1003','safety_incident','faulty_component','escalate_to_oem','escalated','cdsco_notifiable',
     'QA Manager - North','2026-07-09',null,48000.00,'O2 sensor fault escalated to Drager; CDSCO notifiable review'),
    ('CMP-MNP-1005','recurring_defect','faulty_component','replace_faulty_component','open','iso_13485_deviation',
     'Service Head - South','2026-07-12',null,12000.00,'Recurring ECG connector defect — batch replacement planned'),
    ('CMP-MNP-1006','billing_dispute','process_gap','issue_credit_note','closed','none',
     'Finance - South','2026-07-01','2026-07-01',5000.00,'Credit note issued; AMC scope clarified with customer'),
    ('CMP-AIM-1007','safety_incident','design_defect','escalate_to_oem','escalated','patient_safety_alert',
     'QA Manager - North','2026-07-08',null,60000.00,'Defib self-test failure — patient safety alert raised with OEM'),
    ('CMP-CMC-1009','resolution_delay','inadequate_staffing','revise_sla_process','overdue','internal_only',
     'Ops Lead - South','2026-07-06',null,0.00,'SLA process revision overdue — pending management sign-off'),
    ('CMP-KIM-1012','recurring_defect','spare_part_unavailable','expedite_spare_dispatch','verification_pending','cdsco_notifiable',
     'Service Head - South','2026-07-09',null,35000.00,'Expiratory valve replaced; verifying no recurrence'),
    ('CMP-KKB-1015','safety_incident','faulty_component','replace_faulty_component','closed','patient_safety_alert',
     'QA Manager - West','2026-07-08','2026-07-07',72000.00,'Central station module replaced and validated post-incident')
  ) as q(ccode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.complaint_triage_tat_r3492 e
    on e.organization_id = v_org_id and e.complaint_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Triage status distribution
create or replace function public.founder_r3492_triage_status_rollup()
returns table(triage_status text, complaints bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.complaint_triage_tat_r3492)
  select l.triage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.complaint_triage_tat_r3492 l
  group by l.triage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_triage_status_rollup() from public, anon;
grant execute on function public.founder_r3492_triage_status_rollup() to authenticated;

-- 2) Severity scorecard
create or replace function public.founder_r3492_severity_scorecard()
returns table(
  severity text,
  total_complaints bigint,
  resolved bigint,
  unresolved bigint,
  escalated bigint,
  sla_breached bigint,
  avg_response_tat_hours numeric,
  avg_resolution_tat_hours numeric,
  sla_breach_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.severity,
    count(*)::bigint,
    count(*) filter (where l.triage_status in ('resolved','closed'))::bigint,
    count(*) filter (where l.triage_status in ('new','acknowledged','investigating','escalated'))::bigint,
    count(*) filter (where l.triage_status = 'escalated')::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.response_tat_hours), 2),
    round(avg(l.resolution_tat_hours), 2),
    round(100.0 * count(*) filter (where l.sla_breached = true)::numeric / nullif(count(*),0), 1)
  from public.complaint_triage_tat_r3492 l
  group by l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_severity_scorecard() from public, anon;
grant execute on function public.founder_r3492_severity_scorecard() to authenticated;

-- 3) Severity × category matrix
create or replace function public.founder_r3492_severity_category_matrix()
returns table(severity text, category text, complaints bigint, sla_breached bigint, avg_resolution_tat_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.severity, l.category, count(*)::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.resolution_tat_hours), 2)
  from public.complaint_triage_tat_r3492 l
  group by l.severity, l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_severity_category_matrix() from public, anon;
grant execute on function public.founder_r3492_severity_category_matrix() to authenticated;

-- 4) Monthly complaint trend
create or replace function public.founder_r3492_monthly_complaint_trend()
returns table(month text, complaints bigint, resolved bigint, escalated bigint, sla_breached bigint, avg_resolution_tat_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.raised_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.triage_status in ('resolved','closed'))::bigint,
    count(*) filter (where l.triage_status = 'escalated')::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.resolution_tat_hours), 2)
  from public.complaint_triage_tat_r3492 l
  group by to_char(l.raised_date, 'YYYY-MM')
  order by to_char(l.raised_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3492_monthly_complaint_trend() from public, anon;
grant execute on function public.founder_r3492_monthly_complaint_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3492_capa_status_board()
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
  from public.complaint_triage_tat_capa_actions_r3492 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_capa_status_board() from public, anon;
grant execute on function public.founder_r3492_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3492_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.complaint_triage_tat_capa_actions_r3492)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.complaint_triage_tat_capa_actions_r3492 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3492_root_cause_pareto() to authenticated;

-- 7) TAT-impact digest (by complaint category)
create or replace function public.founder_r3492_tat_impact_digest()
returns table(
  category text,
  complaints bigint,
  sla_breached bigint,
  avg_response_tat_hours numeric,
  avg_resolution_tat_hours numeric,
  max_resolution_tat_hours numeric,
  breach_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.response_tat_hours), 2),
    round(avg(l.resolution_tat_hours), 2),
    round(max(l.resolution_tat_hours), 2),
    round(100.0 * count(*) filter (where l.sla_breached = true)::numeric / nullif(count(*),0), 1)
  from public.complaint_triage_tat_r3492 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3492_tat_impact_digest() from public, anon;
grant execute on function public.founder_r3492_tat_impact_digest() to authenticated;

-- 8) High-risk complaint queue (critical-safety / SLA-breached / aging-open)
create or replace function public.founder_r3492_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  complaint_code text,
  device_model text,
  severity text,
  category text,
  triage_status text,
  response_tat_hours numeric,
  resolution_tat_hours numeric,
  sla_breached boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.complaint_code, l.device_model,
    l.severity, l.category, l.triage_status,
    l.response_tat_hours, l.resolution_tat_hours, l.sla_breached, l.notes
  from public.complaint_triage_tat_r3492 l
  where l.severity = 'critical_safety'
     or l.sla_breached = true
     or l.triage_status in ('new','acknowledged','investigating','escalated')
  order by
    case when l.severity = 'critical_safety' then 0 else 1 end,
    l.raised_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3492_high_risk_queue() from public, anon;
grant execute on function public.founder_r3492_high_risk_queue() to authenticated;
