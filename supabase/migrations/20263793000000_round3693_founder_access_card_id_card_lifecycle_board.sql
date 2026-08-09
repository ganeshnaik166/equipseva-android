-- Round 3693: Founder Access-Card / ID-Card Lifecycle Board
-- Own-premises access/ID-card lifecycle — issuance × exit returns × lost-card deactivation SLA × temp-card sprawl × visitor-card returns per site × CAPA

-- =============================================================================
-- TABLE 1: access_card_r3693 — per-site per-batch card lifecycle metrics
-- =============================================================================
create table if not exists public.access_card_r3693 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  card_batch text not null,
  site_name text not null,
  period_month date not null,
  cards_active int not null,
  cards_issued int not null,
  cards_returned_on_exit int not null,
  exit_return_pct numeric(5,2),
  cards_lost int not null,
  lost_deactivated_within_sla int,
  deactivation_sla_pct numeric(5,2),
  temp_cards_outstanding int not null,
  visitor_cards_unreturned int not null,
  audit_current boolean not null,
  card_class text not null check (card_class in (
    'employee_card','contractor_card','temp_card','visitor_card','vehicle_tag'
  )),
  lifecycle_status text not null check (lifecycle_status in (
    'controlled','exit_gap','lost_card_exposure','temp_card_sprawl','uncontrolled'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.access_card_r3693 enable row level security;

create index if not exists idx_access_card_r3693_org on public.access_card_r3693(organization_id);
create index if not exists idx_access_card_r3693_month on public.access_card_r3693(period_month);
create index if not exists idx_access_card_r3693_status on public.access_card_r3693(lifecycle_status);

-- =============================================================================
-- TABLE 2: access_card_capa_actions_r3693 — CAPA & lifecycle-control actions
-- =============================================================================
create table if not exists public.access_card_capa_actions_r3693 (
  id uuid primary key default gen_random_uuid(),
  card_log_id uuid not null references public.access_card_r3693(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'exit_return_gap','lost_card_sla_breach','temp_card_sprawl',
    'visitor_card_unreturned','vehicle_tag_unreconciled','audit_lapsed','batch_issuance_error'
  )),
  root_cause text not null check (root_cause in (
    'exit_clearance_not_enforced','hr_offboarding_delay','security_desk_understaffed',
    'no_expiry_on_temp_cards','visitor_log_manual','deactivation_request_lag',
    'vendor_supervisor_negligence','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'link_card_return_to_full_and_final','auto_expiry_temp_cards','deactivate_on_hr_exit_trigger',
    'front_desk_return_bin_and_log','weekly_reconciliation_report','retrain_security_staff',
    'replace_with_mobile_credential','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  security_impact text not null check (security_impact in (
    'credential_exposure','tailgating_risk','after_hours_access_risk',
    'audit_finding','internal_only','none'
  )),
  estimated_exposure_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.access_card_capa_actions_r3693 enable row level security;

create index if not exists idx_access_card_capa_r3693_log on public.access_card_capa_actions_r3693(card_log_id);
create index if not exists idx_access_card_capa_r3693_status on public.access_card_capa_actions_r3693(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Lifecycle status distribution
create or replace function public.founder_r3693_lifecycle_status_rollup()
returns table(lifecycle_status text, batches bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.access_card_r3693)
  select l.lifecycle_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.access_card_r3693 l
  group by l.lifecycle_status
  order by count(*) desc;
end;
$$;

-- 2) Site lifecycle scorecard
create or replace function public.founder_r3693_site_scorecard()
returns table(
  site_name text,
  total_batches bigint,
  cards_active_total bigint,
  cards_issued_total bigint,
  cards_lost_total bigint,
  temp_outstanding_total bigint,
  visitor_unreturned_total bigint,
  avg_exit_return_pct numeric,
  avg_deactivation_sla_pct numeric,
  controlled bigint,
  at_risk bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    sum(l.cards_active)::bigint,
    sum(l.cards_issued)::bigint,
    sum(l.cards_lost)::bigint,
    sum(l.temp_cards_outstanding)::bigint,
    sum(l.visitor_cards_unreturned)::bigint,
    round(avg(l.exit_return_pct), 1),
    round(avg(l.deactivation_sla_pct), 1),
    count(*) filter (where l.lifecycle_status = 'controlled')::bigint,
    count(*) filter (where l.lifecycle_status in ('exit_gap','lost_card_exposure','temp_card_sprawl','uncontrolled'))::bigint
  from public.access_card_r3693 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Card class × lifecycle status matrix
create or replace function public.founder_r3693_card_class_status_matrix()
returns table(card_class text, lifecycle_status text, batches bigint, cards_lost_total bigint, avg_deactivation_sla_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.card_class, l.lifecycle_status, count(*)::bigint,
    sum(l.cards_lost)::bigint,
    round(avg(l.deactivation_sla_pct), 1)
  from public.access_card_r3693 l
  group by l.card_class, l.lifecycle_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly issuance trend
create or replace function public.founder_r3693_monthly_issuance_trend()
returns table(
  period_month date,
  batches bigint,
  cards_issued_total bigint,
  cards_returned_total bigint,
  cards_lost_total bigint,
  avg_exit_return_pct numeric,
  avg_deactivation_sla_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    sum(l.cards_issued)::bigint,
    sum(l.cards_returned_on_exit)::bigint,
    sum(l.cards_lost)::bigint,
    round(avg(l.exit_return_pct), 1),
    round(avg(l.deactivation_sla_pct), 1)
  from public.access_card_r3693 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3693_capa_status_board()
returns table(capa_status text, findings bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.access_card_capa_actions_r3693 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3693_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.access_card_capa_actions_r3693)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.access_card_capa_actions_r3693 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Security-exposure digest
create or replace function public.founder_r3693_exposure_digest()
returns table(security_impact text, findings bigint, open_findings bigint, total_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.security_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_exposure_rupees),0)::numeric
  from public.access_card_capa_actions_r3693 c
  group by c.security_impact
  order by count(*) desc;
end;
$$;

-- 8) High-risk queue (uncontrolled / lost-card exposure batches)
create or replace function public.founder_r3693_high_risk_queue()
returns table(
  card_batch text,
  site_name text,
  card_class text,
  period_month date,
  lifecycle_status text,
  cards_lost int,
  deactivation_sla_pct numeric,
  temp_cards_outstanding int,
  visitor_cards_unreturned int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.card_batch, l.site_name, l.card_class, l.period_month,
    l.lifecycle_status, l.cards_lost, l.deactivation_sla_pct,
    l.temp_cards_outstanding, l.visitor_cards_unreturned, l.trend_dir, l.notes
  from public.access_card_r3693 l
  where l.lifecycle_status in ('uncontrolled','lost_card_exposure')
     or (l.cards_lost > 0 and l.deactivation_sla_pct is not null and l.deactivation_sla_pct < 100)
     or (l.audit_current = false and l.trend_dir = 'worsening')
  order by l.period_month desc, l.site_name;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated only
-- =============================================================================
revoke all on function public.founder_r3693_lifecycle_status_rollup() from public, anon;
revoke all on function public.founder_r3693_site_scorecard() from public, anon;
revoke all on function public.founder_r3693_card_class_status_matrix() from public, anon;
revoke all on function public.founder_r3693_monthly_issuance_trend() from public, anon;
revoke all on function public.founder_r3693_capa_status_board() from public, anon;
revoke all on function public.founder_r3693_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3693_exposure_digest() from public, anon;
revoke all on function public.founder_r3693_high_risk_queue() from public, anon;

grant execute on function public.founder_r3693_lifecycle_status_rollup() to authenticated;
grant execute on function public.founder_r3693_site_scorecard() to authenticated;
grant execute on function public.founder_r3693_card_class_status_matrix() to authenticated;
grant execute on function public.founder_r3693_monthly_issuance_trend() to authenticated;
grant execute on function public.founder_r3693_capa_status_board() to authenticated;
grant execute on function public.founder_r3693_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3693_exposure_digest() to authenticated;
grant execute on function public.founder_r3693_high_risk_queue() to authenticated;

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

  -- 16 card lifecycle batch rows
  insert into public.access_card_r3693 (
    organization_id, card_batch, site_name, period_month,
    cards_active, cards_issued, cards_returned_on_exit, exit_return_pct,
    cards_lost, lost_deactivated_within_sla, deactivation_sla_pct,
    temp_cards_outstanding, visitor_cards_unreturned, audit_current,
    card_class, lifecycle_status, trend_dir, notes
  )
  select v_org_id, q.cb, q.site, q.pm::date,
    q.act, q.iss, q.ret, q.retpct,
    q.lost, q.deact, q.slapct,
    q.tmpout, q.visun, q.aud,
    q.cls, q.st, q.trd, q.nt
  from (values
    ('ACB-MUM-EMP-07','Mumbai HQ','2026-07-01',412,18,9,90.0,2,2,100.0,4,3,true,
     'employee_card','controlled','stable','Employee base steady; both lost cards deactivated within 24h SLA'),
    ('ACB-MUM-CON-07','Mumbai HQ','2026-07-01',86,12,5,62.5,3,1,33.3,6,0,false,
     'contractor_card','exit_gap','worsening','3 of 8 contractor leavers kept cards — exit clearance not enforced'),
    ('ACB-MUM-VIS-07','Mumbai HQ','2026-07-01',60,145,0,null,1,1,100.0,0,14,false,
     'visitor_card','temp_card_sprawl','worsening','14 visitor cards unreturned at month end — manual front-desk log'),
    ('ACB-CHN-EMP-07','Chennai Branch','2026-07-01',158,6,4,100.0,1,1,100.0,2,1,true,
     'employee_card','controlled','improving','All exit cards recovered; single lost card deactivated in 4h'),
    ('ACB-CHN-TMP-07','Chennai Branch','2026-07-01',24,15,3,60.0,0,null,null,11,0,false,
     'temp_card','temp_card_sprawl','worsening','11 temp cards outstanding beyond 7-day validity window'),
    ('ACB-DEL-EMP-07','Delhi Warehouse','2026-07-01',72,4,1,33.3,4,1,25.0,3,2,false,
     'employee_card','lost_card_exposure','worsening','4 cards lost; only 1 deactivated within SLA — request lag'),
    ('ACB-DEL-VEH-07','Delhi Warehouse','2026-07-01',38,5,2,100.0,2,0,0.0,0,0,false,
     'vehicle_tag','uncontrolled','worsening','Vehicle RFID tags lost; gate registers unreconciled with tag master'),
    ('ACB-BLR-EMP-07','Bengaluru Refurb Center','2026-07-01',96,8,5,83.3,1,1,100.0,2,1,true,
     'employee_card','controlled','stable','Refurb center lifecycle clean; monthly audit current'),
    ('ACB-BLR-CON-07','Bengaluru Refurb Center','2026-07-01',44,9,2,50.0,2,1,50.0,5,0,false,
     'contractor_card','exit_gap','stable','Housekeeping vendor exits missing card-return sign-off'),
    ('ACB-MUM-EMP-06','Mumbai HQ','2026-06-01',405,14,8,88.9,1,1,100.0,3,2,true,
     'employee_card','controlled','stable','June employee lifecycle nominal; audit register current'),
    ('ACB-MUM-CON-06','Mumbai HQ','2026-06-01',82,10,4,66.7,2,1,50.0,4,0,false,
     'contractor_card','exit_gap','worsening','Contractor return gap emerging in June batch'),
    ('ACB-CHN-EMP-06','Chennai Branch','2026-06-01',155,7,3,75.0,2,2,100.0,2,2,true,
     'employee_card','controlled','stable','Both June lost cards deactivated same day'),
    ('ACB-DEL-EMP-06','Delhi Warehouse','2026-06-01',70,6,2,66.7,3,1,33.3,2,1,false,
     'employee_card','lost_card_exposure','worsening','Lost-card deactivation lag began in June'),
    ('ACB-DEL-TMP-06','Delhi Warehouse','2026-06-01',18,12,2,66.7,1,0,0.0,8,0,false,
     'temp_card','temp_card_sprawl','worsening','Temp cards issued at gate without expiry programming'),
    ('ACB-BLR-EMP-06','Bengaluru Refurb Center','2026-06-01',94,5,3,100.0,0,null,null,1,0,true,
     'employee_card','controlled','improving','No lost cards; clean June audit'),
    ('ACB-CHN-VIS-06','Chennai Branch','2026-06-01',40,88,0,null,0,null,null,0,6,true,
     'visitor_card','controlled','improving','Visitor returns reconciled weekly; 6 pending at cutoff')
  ) as q(cb, site, pm, act, iss, ret, retpct, lost, deact, slapct, tmpout, visun, aud, cls, st, trd, nt);

  -- CAPA seed — attach to specific batches via card_batch
  insert into public.access_card_capa_actions_r3693 (
    card_log_id, finding_category, root_cause, corrective_action,
    capa_status, security_impact, estimated_exposure_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.exp, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('ACB-MUM-CON-07','exit_return_gap','exit_clearance_not_enforced','link_card_return_to_full_and_final',
     'in_progress','credential_exposure',45000.00,'Admin Head Mumbai','2026-08-20',null,
     'Card return added to contractor full-and-final settlement checklist'),
    ('ACB-DEL-EMP-07','lost_card_sla_breach','deactivation_request_lag','deactivate_on_hr_exit_trigger',
     'escalated','after_hours_access_risk',120000.00,'Security Lead Delhi','2026-08-12',null,
     '3 lost cards live beyond 24h window — escalated to IT security head'),
    ('ACB-DEL-VEH-07','vehicle_tag_unreconciled','pending_investigation','weekly_reconciliation_report',
     'open','tailgating_risk',60000.00,'Warehouse Manager Delhi','2026-08-25',null,
     'Gate register vs vehicle-tag master mismatch under investigation'),
    ('ACB-CHN-TMP-07','temp_card_sprawl','no_expiry_on_temp_cards','auto_expiry_temp_cards',
     'verification_pending','internal_only',15000.00,'IT Admin Chennai','2026-08-10',null,
     '7-day auto-expiry pushed to access controller — verifying purge'),
    ('ACB-MUM-VIS-07','visitor_card_unreturned','visitor_log_manual','front_desk_return_bin_and_log',
     'in_progress','audit_finding',8000.00,'Front Office Mumbai','2026-08-18',null,
     'Digital visitor log with card-return checkpoint being piloted'),
    ('ACB-BLR-CON-07','exit_return_gap','vendor_supervisor_negligence','retrain_security_staff',
     'open','internal_only',12000.00,'Facility Lead Bengaluru','2026-08-22',null,
     'Vendor supervisor briefed; card-return sign-off format reissued'),
    ('ACB-DEL-TMP-06','temp_card_sprawl','no_expiry_on_temp_cards','auto_expiry_temp_cards',
     'closed','internal_only',10000.00,'IT Admin Delhi','2026-07-15','2026-07-11',
     'June temp-card sprawl cleared; expiry now programmed at issue'),
    ('ACB-MUM-CON-06','exit_return_gap','hr_offboarding_delay','deactivate_on_hr_exit_trigger',
     'closed','credential_exposure',30000.00,'Admin Head Mumbai','2026-07-20','2026-07-18',
     'HRMS exit event now auto-raises card deactivation ticket')
  ) as q(cb, fc, rc, ca, cst, si, exp, own, tcd, acd, nt)
  join public.access_card_r3693 e
    on e.organization_id = v_org_id and e.card_batch = q.cb;
end;
$seed$;
