-- Round 3661: IT Security-Awareness / Phishing-Simulation Board
-- Internal IT security governance — department × campaign type × click rate × credential submission × reporting rate × training completion × repeat clickers × awareness status × trend × CAPA

-- =============================================================================
-- TABLE 1: phish_awareness_r3661 — per-department phishing-simulation campaign results
-- =============================================================================
create table if not exists public.phish_awareness_r3661 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  department text not null,
  campaign_ref text not null,
  period_month date not null,
  staff_targeted int not null,
  emails_opened int not null,
  links_clicked int not null,
  credentials_submitted int not null,
  reported_to_it int not null,
  click_rate_pct numeric(5,2),
  report_rate_pct numeric(5,2),
  training_completion_pct numeric(5,2),
  repeat_clickers int not null,
  campaign_date date not null,
  campaign_type text not null check (campaign_type in (
    'phishing_email','smishing','vishing','usb_drop','awareness_module'
  )),
  awareness_status text not null check (awareness_status in (
    'strong','improving','vulnerable','high_risk','untrained'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.phish_awareness_r3661 enable row level security;

create index if not exists idx_phish_awareness_r3661_org on public.phish_awareness_r3661(organization_id);
create index if not exists idx_phish_awareness_r3661_month on public.phish_awareness_r3661(period_month);
create index if not exists idx_phish_awareness_r3661_status on public.phish_awareness_r3661(awareness_status);

-- =============================================================================
-- TABLE 2: phish_awareness_capa_actions_r3661 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.phish_awareness_capa_actions_r3661 (
  id uuid primary key default gen_random_uuid(),
  campaign_log_id uuid not null references public.phish_awareness_r3661(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'credential_submission','high_click_rate','low_reporting_rate','training_incomplete',
    'repeat_clicker_cluster','usb_policy_violation','vishing_disclosure','slow_incident_reporting'
  )),
  root_cause text not null check (root_cause in (
    'no_prior_training','lookalike_domain_convincing','mobile_device_context',
    'process_gap_vendor_verification','new_joiner_cohort_untrained','policy_not_enforced',
    'alert_fatigue','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'targeted_retraining','mandatory_awareness_module','enable_mfa_enforcement',
    'block_lookalike_domains','usb_port_lockdown','vendor_callback_procedure',
    'phish_report_button_rollout','disciplinary_counseling','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.phish_awareness_capa_actions_r3661 enable row level security;

create index if not exists idx_phish_awareness_capa_r3661_log on public.phish_awareness_capa_actions_r3661(campaign_log_id);
create index if not exists idx_phish_awareness_capa_r3661_status on public.phish_awareness_capa_actions_r3661(capa_status);

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

  -- 16 campaign result rows
  insert into public.phish_awareness_r3661 (
    organization_id, department, campaign_ref, period_month,
    staff_targeted, emails_opened, links_clicked, credentials_submitted, reported_to_it,
    click_rate_pct, report_rate_pct, training_completion_pct, repeat_clickers,
    campaign_date, campaign_type, awareness_status, trend_dir, notes
  )
  select v_org_id, q.dept, q.cref, q.pmon::date,
    q.tgt, q.opened, q.clicked, q.creds, q.rept,
    q.crate, q.rrate, q.trng, q.repeatc,
    q.cdate::date, q.ctype, q.astat, q.tdir, q.nt
  from (values
    ('Sales','PHSH-2606-SLS','2026-06-01',48,39,17,6,5,35.4,10.4,62.5,4,'2026-06-04',
     'phishing_email','high_risk','worsening','Fake GST-invoice lure — 6 credentials submitted on lookalike O365 page'),
    ('Field Service','PHSH-2606-FLD','2026-06-01',62,41,12,2,11,19.4,17.7,71.0,3,'2026-06-05',
     'smishing','vulnerable','stable','Courier-OTP smishing — field engineers clicked from personal phones'),
    ('Finance','PHSH-2606-FIN','2026-06-01',18,14,3,1,9,16.7,50.0,88.9,1,'2026-06-06',
     'phishing_email','improving','improving','CFO-spoof payment-release lure — one repeat clicker in AP team'),
    ('HR','PHSH-2606-HR','2026-06-01',12,9,2,0,6,16.7,50.0,91.7,0,'2026-06-09',
     'phishing_email','improving','improving','Resume-attachment lure — no credential loss, healthy reporting'),
    ('IT & Infra','PHSH-2606-IT','2026-06-01',10,6,0,0,8,0.0,80.0,100.0,0,'2026-06-10',
     'vishing','strong','stable','Fake OEM support-desk vishing call — all agents verified caller and reported'),
    ('Supply Chain','PHSH-2606-SCM','2026-06-01',26,20,9,3,3,34.6,11.5,57.7,2,'2026-06-11',
     'phishing_email','high_risk','worsening','Vendor bank-detail-change lure — 3 credential submits on fake ERP login'),
    ('Warehouse & Logistics','PHSH-2606-WHL','2026-06-01',22,13,7,2,1,31.8,4.5,40.9,3,'2026-06-12',
     'usb_drop','untrained','worsening','USB drop at Bhiwandi warehouse — 7 devices plugged in, training pending'),
    ('Customer Support','PHSH-2606-CSP','2026-06-01',30,24,8,1,7,26.7,23.3,76.7,2,'2026-06-13',
     'phishing_email','vulnerable','stable','Fake ticket-escalation lure on CRM lookalike domain'),
    ('Regulatory Affairs','PHSH-2606-REG','2026-06-01',8,5,1,0,4,12.5,50.0,100.0,0,'2026-06-16',
     'awareness_module','strong','improving','CDSCO-circular themed module — completion 100 pct, quiz avg 92'),
    ('Sales','PHSH-2607-SLS','2026-07-01',48,35,11,2,12,22.9,25.0,79.2,2,'2026-07-07',
     'phishing_email','improving','improving','Post-retraining rerun — click rate down from 35.4 to 22.9 pct'),
    ('Field Service','PHSH-2607-FLD','2026-07-01',62,38,9,1,16,14.5,25.8,83.9,2,'2026-07-08',
     'smishing','improving','improving','Second smishing wave — reporting up after WhatsApp advisory'),
    ('Finance','PHSH-2607-FIN','2026-07-01',18,12,1,0,11,5.6,61.1,94.4,0,'2026-07-09',
     'phishing_email','strong','improving','UPI-refund lure — near-clean result, one hover-only open'),
    ('Supply Chain','PHSH-2607-SCM','2026-07-01',26,19,6,1,6,23.1,23.1,73.1,2,'2026-07-10',
     'phishing_email','vulnerable','improving','Rerun after vendor-fraud briefing — credential submits down to 1'),
    ('Warehouse & Logistics','PHSH-2607-WHL','2026-07-01',22,15,5,1,3,22.7,13.6,63.6,2,'2026-07-14',
     'phishing_email','vulnerable','improving','First email drill post USB incident — supervisors reporting now'),
    ('Marketing','PHSH-2607-MKT','2026-07-01',14,11,6,2,2,42.9,14.3,50.0,2,'2026-07-15',
     'phishing_email','high_risk','worsening','Fake event-sponsorship lure — highest click rate this quarter'),
    ('Admin & Facilities','PHSH-2607-ADM','2026-07-01',9,6,3,1,1,33.3,11.1,44.4,1,'2026-07-16',
     'vishing','untrained','stable','Fake bank KYC vishing — module not yet assigned to admin staff')
  ) as q(dept, cref, pmon, tgt, opened, clicked, creds, rept, crate, rrate, trng, repeatc, cdate, ctype, astat, tdir, nt);

  -- CAPA seed — attach to specific campaigns via campaign_ref
  insert into public.phish_awareness_capa_actions_r3661 (
    campaign_log_id, finding_category, root_cause, corrective_action,
    capa_status, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PHSH-2606-SLS','credential_submission','lookalike_domain_convincing','enable_mfa_enforcement','in_progress','CISO Office — R. Nair','2026-07-15',null,85000.00,'MFA enforced for sales OU; password resets done for 6 affected accounts'),
    ('PHSH-2606-SCM','credential_submission','process_gap_vendor_verification','vendor_callback_procedure','verification_pending','IT Security — A. Kulkarni','2026-07-20',null,20000.00,'Vendor bank-change callback SOP issued; verification drill scheduled'),
    ('PHSH-2606-WHL','usb_policy_violation','policy_not_enforced','usb_port_lockdown','open','IT Infra — S. Reddy','2026-08-10',null,64000.00,'Endpoint USB lockdown GPO rollout for warehouse desktops in progress'),
    ('PHSH-2606-WHL','training_incomplete','no_prior_training','mandatory_awareness_module','in_progress','HR L&D — P. Iyer','2026-08-05',null,18000.00,'Hindi and Marathi awareness module assigned to all warehouse staff'),
    ('PHSH-2606-FLD','high_click_rate','mobile_device_context','phish_report_button_rollout','closed','IT Security — A. Kulkarni','2026-07-10','2026-07-08',12000.00,'Report-phish button added to Outlook mobile; smishing advisory sent'),
    ('PHSH-2607-MKT','high_click_rate','new_joiner_cohort_untrained','targeted_retraining','open','CISO Office — R. Nair','2026-08-14',null,9500.00,'Three of six clickers joined last quarter — onboarding module gap'),
    ('PHSH-2606-CSP','low_reporting_rate','alert_fatigue','block_lookalike_domains','overdue','IT Infra — S. Reddy','2026-07-25',null,15000.00,'CRM lookalike domain takedown pending with registrar — chasing'),
    ('PHSH-2607-ADM','vishing_disclosure','no_prior_training','mandatory_awareness_module','escalated','HR L&D — P. Iyer','2026-08-08',null,7500.00,'Admin staff disclosed employee ID on vishing call — escalated to management')
  ) as q(cref, fc, rc, ca, cst, ownr, tcd, acd, cost, nt)
  join public.phish_awareness_r3661 e
    on e.organization_id = v_org_id and e.campaign_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Awareness status distribution
create or replace function public.founder_r3661_awareness_status_rollup()
returns table(awareness_status text, campaigns bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.phish_awareness_r3661)
  select l.awareness_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.phish_awareness_r3661 l
  group by l.awareness_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3661_awareness_status_rollup() from public, anon;
grant execute on function public.founder_r3661_awareness_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3661_department_scorecard()
returns table(
  department text,
  total_campaigns bigint,
  staff_targeted_total bigint,
  links_clicked_total bigint,
  credentials_submitted_total bigint,
  reported_total bigint,
  avg_click_rate_pct numeric,
  avg_report_rate_pct numeric,
  avg_training_completion_pct numeric,
  high_risk_campaigns bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.staff_targeted),0)::bigint,
    coalesce(sum(l.links_clicked),0)::bigint,
    coalesce(sum(l.credentials_submitted),0)::bigint,
    coalesce(sum(l.reported_to_it),0)::bigint,
    round(avg(l.click_rate_pct), 1),
    round(avg(l.report_rate_pct), 1),
    round(avg(l.training_completion_pct), 1),
    count(*) filter (where l.awareness_status in ('high_risk','untrained'))::bigint
  from public.phish_awareness_r3661 l
  group by l.department
  order by round(avg(l.click_rate_pct), 1) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3661_department_scorecard() from public, anon;
grant execute on function public.founder_r3661_department_scorecard() to authenticated;

-- 3) Campaign-type × awareness-status matrix
create or replace function public.founder_r3661_campaign_type_status_matrix()
returns table(campaign_type text, awareness_status text, campaigns bigint, avg_click_rate_pct numeric, avg_report_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.campaign_type, l.awareness_status, count(*)::bigint,
    round(avg(l.click_rate_pct), 1),
    round(avg(l.report_rate_pct), 1)
  from public.phish_awareness_r3661 l
  group by l.campaign_type, l.awareness_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3661_campaign_type_status_matrix() from public, anon;
grant execute on function public.founder_r3661_campaign_type_status_matrix() to authenticated;

-- 4) Monthly click-rate trend
create or replace function public.founder_r3661_monthly_click_rate_trend()
returns table(period_month date, campaigns bigint, staff_targeted_total bigint, links_clicked_total bigint, credentials_submitted_total bigint, repeat_clickers_total bigint, avg_click_rate_pct numeric, avg_report_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.staff_targeted),0)::bigint,
    coalesce(sum(l.links_clicked),0)::bigint,
    coalesce(sum(l.credentials_submitted),0)::bigint,
    coalesce(sum(l.repeat_clickers),0)::bigint,
    round(avg(l.click_rate_pct), 1),
    round(avg(l.report_rate_pct), 1)
  from public.phish_awareness_r3661 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3661_monthly_click_rate_trend() from public, anon;
grant execute on function public.founder_r3661_monthly_click_rate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3661_capa_status_board()
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
  from public.phish_awareness_capa_actions_r3661 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3661_capa_status_board() from public, anon;
grant execute on function public.founder_r3661_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3661_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.phish_awareness_capa_actions_r3661)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.phish_awareness_capa_actions_r3661 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3661_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3661_root_cause_pareto() to authenticated;

-- 7) Repeat-clicker digest
create or replace function public.founder_r3661_repeat_clicker_digest()
returns table(department text, campaigns bigint, repeat_clickers_total bigint, credentials_submitted_total bigint, avg_click_rate_pct numeric, worsening_campaigns bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, count(*)::bigint,
    coalesce(sum(l.repeat_clickers),0)::bigint,
    coalesce(sum(l.credentials_submitted),0)::bigint,
    round(avg(l.click_rate_pct), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.phish_awareness_r3661 l
  where l.repeat_clickers > 0 or l.credentials_submitted > 0
  group by l.department
  order by coalesce(sum(l.repeat_clickers),0) desc, coalesce(sum(l.credentials_submitted),0) desc;
end;
$$;

revoke execute on function public.founder_r3661_repeat_clicker_digest() from public, anon;
grant execute on function public.founder_r3661_repeat_clicker_digest() to authenticated;

-- 8) High-risk awareness queue (high_risk / untrained departments)
create or replace function public.founder_r3661_high_risk_queue()
returns table(
  department text,
  campaign_ref text,
  campaign_type text,
  campaign_date date,
  awareness_status text,
  trend_dir text,
  click_rate_pct numeric,
  report_rate_pct numeric,
  credentials_submitted int,
  repeat_clickers int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.campaign_ref, l.campaign_type, l.campaign_date,
    l.awareness_status, l.trend_dir, l.click_rate_pct, l.report_rate_pct,
    l.credentials_submitted, l.repeat_clickers, l.notes
  from public.phish_awareness_r3661 l
  where l.awareness_status in ('high_risk','untrained')
     or l.credentials_submitted > 0
     or l.trend_dir = 'worsening'
     or l.training_completion_pct < 60
  order by l.campaign_date desc, l.department;
end;
$$;

revoke execute on function public.founder_r3661_high_risk_queue() from public, anon;
grant execute on function public.founder_r3661_high_risk_queue() to authenticated;
