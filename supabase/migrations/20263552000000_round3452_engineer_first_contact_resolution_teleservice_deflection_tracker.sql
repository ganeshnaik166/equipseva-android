-- Round 3452: Engineer First-Contact-Resolution / Teleservice Deflection Tracker
-- Remote/tele-service FCR + onsite-visit deflection tracker — engineer × channel × issue type ×
-- resolution × first-contact-resolved × handle time × onsite-avoidance × CAPA closure

-- =============================================================================
-- TABLE 1: first_contact_resolution_r3452 — per-ticket teleservice FCR log
-- =============================================================================
create table if not exists public.first_contact_resolution_r3452 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  ticket_code text not null,
  hospital_name text not null,
  device_model text not null,
  channel text not null check (channel in (
    'phone','remote_session','email','chat','self_service'
  )),
  issue_type text not null check (issue_type in (
    'config','user_error','software','calibration','minor_hardware','network','consumable'
  )),
  resolution text not null check (resolution in (
    'resolved_remote','deflected_onsite','escalated','pending','no_fault_found'
  )),
  first_contact_resolved boolean not null,
  handle_time_min int not null,
  onsite_avoided boolean not null,
  contact_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_contact_resolution_r3452 enable row level security;

create index if not exists idx_fcr_r3452_org on public.first_contact_resolution_r3452(organization_id);
create index if not exists idx_fcr_r3452_date on public.first_contact_resolution_r3452(contact_date);
create index if not exists idx_fcr_r3452_resolution on public.first_contact_resolution_r3452(resolution);

-- =============================================================================
-- TABLE 2: first_contact_resolution_capa_actions_r3452 — CAPA & deflection actions
-- =============================================================================
create table if not exists public.first_contact_resolution_capa_actions_r3452 (
  id uuid primary key default gen_random_uuid(),
  ticket_log_id uuid not null references public.first_contact_resolution_r3452(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_fcr_rate','excessive_onsite_dispatch','repeat_contact','long_handle_time',
    'escalation_spike','remote_tooling_gap','knowledge_base_gap','no_fault_dispatch'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_remote_access','missing_diagnostic_tooling','inadequate_kb_article',
    'engineer_skill_gap','customer_training_gap','network_restriction','device_offline',
    'spare_part_dependency','process_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'deploy_remote_access_tool','author_kb_article','engineer_training','customer_training',
    'enable_device_telemetry','update_triage_script','provision_spare_kit','escalate_to_oem','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_saved_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_contact_resolution_capa_actions_r3452 enable row level security;

create index if not exists idx_fcr_capa_r3452_log on public.first_contact_resolution_capa_actions_r3452(ticket_log_id);
create index if not exists idx_fcr_capa_r3452_status on public.first_contact_resolution_capa_actions_r3452(capa_status);

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

  -- 16 teleservice FCR rows
  insert into public.first_contact_resolution_r3452 (
    organization_id, engineer_name, ticket_code, hospital_name, device_model,
    channel, issue_type, resolution, first_contact_resolved, handle_time_min,
    onsite_avoided, contact_date, notes
  )
  select v_org_id, q.eng, q.tkt, q.hosp, q.dev,
    q.chan, q.issue, q.res, q.fcr, q.htm,
    q.onsite, q.cdate::date, q.nt
  from (values
    ('Rahul Verma','FCR-APL-1001','Apollo Chennai','Draeger Fabius GS','remote_session','config','resolved_remote',true,25,true,'2026-07-03','Ventilator alarm limits reconfigured over remote session — no dispatch'),
    ('Rahul Verma','FCR-APL-1002','Apollo Chennai','GE CARESCAPE B650','phone','user_error','resolved_remote',true,12,true,'2026-07-02','Monitor lead placement guided over phone — user error, resolved'),
    ('Sneha Iyer','FCR-FRT-1003','Fortis Gurgaon','Philips IntelliVue MX550','remote_session','software','resolved_remote',true,40,true,'2026-07-01','Firmware parameter reset via remote — patch pushed, resolved first contact'),
    ('Sneha Iyer','FCR-FRT-1004','Fortis Gurgaon','Mindray BeneVision N22','chat','calibration','deflected_onsite',false,35,false,'2026-06-30','SpO2 calibration drift — needed onsite calibration, dispatched'),
    ('Amit Nair','FCR-MNP-1005','Manipal Bengaluru','Siemens Atellica','email','minor_hardware','deflected_onsite',false,55,false,'2026-06-29','Sample probe replacement required onsite — deflected to visit'),
    ('Amit Nair','FCR-MNP-1006','Manipal Bengaluru','Draeger Evita V500','remote_session','network','resolved_remote',true,30,true,'2026-06-28','Hospital VLAN reachability fixed remotely with biomed IT'),
    ('Priya Menon','FCR-AIM-1007','AIIMS Delhi','GE Logiq E10','self_service','user_error','no_fault_found',true,8,true,'2026-06-27','Guided via KB article self-service — no fault found, user setup'),
    ('Priya Menon','FCR-AIM-1008','AIIMS Delhi','Philips Azurion 7','phone','minor_hardware','escalated',false,48,false,'2026-06-26','Detector fault beyond remote scope — escalated to OEM engineer'),
    ('Karthik Rao','FCR-CMC-1009','CMC Vellore','Nihon Kohden BSM-6000','chat','config','resolved_remote',true,18,true,'2026-06-15','Central station config restored via chat session, no visit'),
    ('Karthik Rao','FCR-CMC-1010','CMC Vellore','Mindray Resona 7','remote_session','software','pending',false,22,false,'2026-06-14','Awaiting vendor patch, remote session paused — pending'),
    ('Divya Pillai','FCR-KIM-1011','KIMS Hyderabad','Draeger Perseus A500','phone','consumable','resolved_remote',true,10,true,'2026-06-13','Soda-lime canister guidance over phone, consumable swap by staff'),
    ('Divya Pillai','FCR-KIM-1012','KIMS Hyderabad','GE CARESCAPE R860','remote_session','calibration','deflected_onsite',false,42,false,'2026-06-12','Flow sensor calibration needed physical reference — onsite dispatch'),
    ('Rahul Verma','FCR-YSH-1013','Yashoda Hyderabad','Philips IntelliVue MX750','email','user_error','no_fault_found',true,9,true,'2026-05-28','Alarm silence misunderstanding clarified by email — no fault'),
    ('Sneha Iyer','FCR-KKB-1014','Kokilaben Mumbai','Siemens Acuson Sequoia','remote_session','software','escalated',false,50,false,'2026-05-27','Probe recognition firmware bug — escalated to R&D, repeat contact'),
    ('Amit Nair','FCR-KKB-1015','Kokilaben Mumbai','Mindray BeneHeart D6','chat','minor_hardware','deflected_onsite',false,38,false,'2026-05-26','Defib paddle connector damaged — onsite replacement dispatched'),
    ('Priya Menon','FCR-APL-1016','Apollo Chennai','Draeger Fabius GS','remote_session','network','resolved_remote',true,20,true,'2026-05-25','Gateway reconfigured remotely, telemetry restored — no dispatch')
  ) as q(eng, tkt, hosp, dev, chan, issue, res, fcr, htm, onsite, cdate, nt);

  -- CAPA seed — attach to specific tickets via ticket_code
  insert into public.first_contact_resolution_capa_actions_r3452 (
    ticket_log_id, finding_category, root_cause, corrective_action,
    capa_status, owner, target_closure_date, actual_closure_date,
    estimated_cost_saved_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FCR-FRT-1004','excessive_onsite_dispatch','missing_diagnostic_tooling','deploy_remote_access_tool','in_progress','Sneha Iyer','2026-07-08',null,18000.00,'Remote calibration tool being provisioned to cut onsite SpO2 trips'),
    ('FCR-MNP-1005','no_fault_dispatch','spare_part_dependency','provision_spare_kit','open','Amit Nair','2026-07-10',null,12000.00,'Stage sample-probe spares at site to avoid future dispatch'),
    ('FCR-AIM-1008','escalation_spike','engineer_skill_gap','engineer_training','escalated','Priya Menon','2026-07-05',null,26000.00,'Detector diagnostics training scheduled — recurring escalations'),
    ('FCR-CMC-1010','long_handle_time','inadequate_kb_article','author_kb_article','verification_pending','Karthik Rao','2026-07-06',null,7000.00,'KB article drafted for patch workflow — verify handle-time drop'),
    ('FCR-KIM-1012','excessive_onsite_dispatch','device_offline','enable_device_telemetry','open','Divya Pillai','2026-07-12',null,15000.00,'Enable telemetry to allow remote flow-sensor cal in future'),
    ('FCR-KKB-1014','repeat_contact','process_gap','update_triage_script','overdue','Sneha Iyer','2026-06-30',null,9000.00,'Triage script update overdue — repeat firmware contacts persist'),
    ('FCR-KKB-1015','excessive_onsite_dispatch','spare_part_dependency','provision_spare_kit','closed','Amit Nair','2026-06-05','2026-06-02',11000.00,'Defib paddle spares kit staged — future connector swaps onsite-free'),
    ('FCR-AIM-1007','knowledge_base_gap','customer_training_gap','customer_training','closed','Priya Menon','2026-06-20','2026-06-18',5000.00,'Self-service KB improved; staff trained on alarm setup')
  ) as q(tkt, fc, rc, ca, cst, own, tcd, acd, cost, nt)
  join public.first_contact_resolution_r3452 e
    on e.organization_id = v_org_id and e.ticket_code = q.tkt;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Resolution distribution
create or replace function public.founder_r3452_resolution_rollup()
returns table(resolution text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_contact_resolution_r3452)
  select l.resolution, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.first_contact_resolution_r3452 l
  group by l.resolution
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_resolution_rollup() from public, anon;
grant execute on function public.founder_r3452_resolution_rollup() to authenticated;

-- 2) Channel scorecard
create or replace function public.founder_r3452_channel_scorecard()
returns table(
  channel text,
  total_tickets bigint,
  fcr_count bigint,
  resolved_remote bigint,
  deflected bigint,
  escalated bigint,
  onsite_avoided bigint,
  avg_handle_time_min numeric,
  fcr_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel,
    count(*)::bigint,
    count(*) filter (where l.first_contact_resolved = true)::bigint,
    count(*) filter (where l.resolution = 'resolved_remote')::bigint,
    count(*) filter (where l.resolution = 'deflected_onsite')::bigint,
    count(*) filter (where l.resolution = 'escalated')::bigint,
    count(*) filter (where l.onsite_avoided = true)::bigint,
    round(avg(l.handle_time_min), 1),
    round(100.0 * count(*) filter (where l.first_contact_resolved = true)::numeric / nullif(count(*),0), 1)
  from public.first_contact_resolution_r3452 l
  group by l.channel
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_channel_scorecard() from public, anon;
grant execute on function public.founder_r3452_channel_scorecard() to authenticated;

-- 3) Issue-type × resolution matrix
create or replace function public.founder_r3452_issue_resolution_matrix()
returns table(issue_type text, resolution text, tickets bigint, fcr_count bigint, avg_handle_time_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_type, l.resolution, count(*)::bigint,
    count(*) filter (where l.first_contact_resolved = true)::bigint,
    round(avg(l.handle_time_min), 1)
  from public.first_contact_resolution_r3452 l
  group by l.issue_type, l.resolution
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_issue_resolution_matrix() from public, anon;
grant execute on function public.founder_r3452_issue_resolution_matrix() to authenticated;

-- 4) Monthly FCR trend
create or replace function public.founder_r3452_monthly_fcr_trend()
returns table(month text, tickets bigint, fcr_count bigint, onsite_avoided bigint, deflected bigint, fcr_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.contact_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.first_contact_resolved = true)::bigint,
    count(*) filter (where l.onsite_avoided = true)::bigint,
    count(*) filter (where l.resolution = 'deflected_onsite')::bigint,
    round(100.0 * count(*) filter (where l.first_contact_resolved = true)::numeric / nullif(count(*),0), 1)
  from public.first_contact_resolution_r3452 l
  group by to_char(l.contact_date, 'YYYY-MM')
  order by to_char(l.contact_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3452_monthly_fcr_trend() from public, anon;
grant execute on function public.founder_r3452_monthly_fcr_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3452_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_saved_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_saved_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.first_contact_resolution_capa_actions_r3452 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_capa_status_board() from public, anon;
grant execute on function public.founder_r3452_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3452_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_saved_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_contact_resolution_capa_actions_r3452)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_saved_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.first_contact_resolution_capa_actions_r3452 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3452_root_cause_pareto() to authenticated;

-- 7) Onsite-avoidance impact digest (by issue type)
create or replace function public.founder_r3452_onsite_avoidance_impact_digest()
returns table(
  issue_type text,
  tickets bigint,
  onsite_avoided bigint,
  dispatched bigint,
  avg_handle_time_min numeric,
  avoidance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_type,
    count(*)::bigint,
    count(*) filter (where l.onsite_avoided = true)::bigint,
    count(*) filter (where l.onsite_avoided = false)::bigint,
    round(avg(l.handle_time_min), 1),
    round(100.0 * count(*) filter (where l.onsite_avoided = true)::numeric / nullif(count(*),0), 1)
  from public.first_contact_resolution_r3452 l
  group by l.issue_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3452_onsite_avoidance_impact_digest() from public, anon;
grant execute on function public.founder_r3452_onsite_avoidance_impact_digest() to authenticated;

-- 8) High-risk queue (unresolved / escalated / repeat / dispatched)
create or replace function public.founder_r3452_high_risk_queue()
returns table(
  hospital_name text,
  ticket_code text,
  engineer_name text,
  device_model text,
  channel text,
  issue_type text,
  resolution text,
  handle_time_min int,
  contact_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ticket_code, l.engineer_name, l.device_model, l.channel,
    l.issue_type, l.resolution, l.handle_time_min, l.contact_date, l.notes
  from public.first_contact_resolution_r3452 l
  where l.resolution in ('deflected_onsite','escalated','pending')
     or l.first_contact_resolved = false
     or l.onsite_avoided = false
  order by l.contact_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3452_high_risk_queue() from public, anon;
grant execute on function public.founder_r3452_high_risk_queue() to authenticated;
