-- Round 3733: Founder Cyber-Insurance Claim Readiness / Breach-Response Drill Board
-- Insurance claim readiness & tabletop drills — scenario type × scenario class × drill status ×
-- response-time SLA × policy coverage gaps × claim-documentation readiness × CAPA
-- Distinct from technical DR/backup-posture boards — this is INSURANCE claim readiness plus
-- breach-response drill exercises specifically, not backup mechanics.

-- =============================================================================
-- TABLE 1: cyber_drill_r3733 — tabletop drill & claim-readiness facts
-- =============================================================================
create table if not exists public.cyber_drill_r3733 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  drill_name text not null,
  scenario_type text not null,
  period_month date not null,
  drill_date date,
  participants_count int,
  response_time_minutes numeric,
  target_response_minutes numeric,
  gaps_identified int,
  policy_coverage_adequate boolean not null,
  claim_documentation_ready boolean not null,
  insurer_notified_within_hours numeric,
  lessons_captured boolean not null,
  scenario_class text not null check (scenario_class in (
    'ransomware','data_breach','ddos','insider_threat','third_party_vendor_breach'
  )),
  drill_status text not null check (drill_status in (
    'passed_within_sla','passed_with_gaps','failed_sla','not_conducted','remediation_in_progress'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cyber_drill_r3733 enable row level security;

create index if not exists idx_cyber_drill_r3733_org on public.cyber_drill_r3733(organization_id);
create index if not exists idx_cyber_drill_r3733_month on public.cyber_drill_r3733(period_month);
create index if not exists idx_cyber_drill_r3733_status on public.cyber_drill_r3733(drill_status);

-- =============================================================================
-- TABLE 2: cyber_drill_capa_actions_r3733 — CAPA for drill gaps
-- =============================================================================
create table if not exists public.cyber_drill_capa_actions_r3733 (
  id uuid primary key default gen_random_uuid(),
  drill_id uuid references public.cyber_drill_r3733(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cyber_drill_capa_actions_r3733 enable row level security;

create index if not exists idx_cyber_drill_capa_r3733_drill on public.cyber_drill_capa_actions_r3733(drill_id);
create index if not exists idx_cyber_drill_capa_r3733_status on public.cyber_drill_capa_actions_r3733(capa_status);

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

  -- 16 drill rows
  insert into public.cyber_drill_r3733 (
    organization_id, drill_name, scenario_type, period_month, drill_date,
    participants_count, response_time_minutes, target_response_minutes, gaps_identified,
    policy_coverage_adequate, claim_documentation_ready, insurer_notified_within_hours,
    lessons_captured, scenario_class, drill_status, trend_dir, notes
  )
  select v_org_id, q.dn, q.st, q.pm::date, q.dd::date,
    q.pc::int, q.rtm::numeric, q.trm::numeric, q.gi::int,
    q.pca, q.cdr, q.inh::numeric,
    q.lc, q.sc, q.ds, q.td, q.nt
  from (values
    ('Q3 Ransomware Tabletop','tabletop_exercise','2026-07-01','2026-07-12',
     18,42.0,60.0,2,true,true,3.5,true,'ransomware','passed_within_sla','improving','Encryption-lockout scenario — legal & comms desk drilled jointly with IT'),
    ('Vendor API Breach Simulation','tabletop_exercise','2026-07-01','2026-07-18',
     14,95.0,60.0,5,false,false,9.0,true,'third_party_vendor_breach','passed_with_gaps','stable','Third-party logistics API key leak — vendor contract lacks breach-notice SLA clause'),
    ('DDoS Load-Shedding Drill','functional_exercise','2026-06-01','2026-06-05',
     10,28.0,45.0,1,true,true,2.0,true,'ddos','passed_within_sla','stable','CDN failover validated — insurer notified within window comfortably'),
    ('Customer PII Data-Breach Drill','tabletop_exercise','2026-06-01','2026-06-20',
     22,140.0,90.0,7,false,false,18.0,false,'data_breach','failed_sla','worsening','Notification chain broke at DPO handoff — claim documentation not started for 3 days'),
    ('Insider Threat Walkthrough','tabletop_exercise','2026-05-01','2026-05-14',
     12,55.0,60.0,3,true,true,6.0,true,'insider_threat','passed_within_sla','improving','Privileged-access revocation drill — SIEM alert-to-action time cut in half since Q1'),
    ('Ransomware Full-Scale Simulation','full_scale_exercise','2026-05-01','2026-05-28',
     30,180.0,120.0,9,false,false,24.0,true,'ransomware','failed_sla','worsening','Backup restore desynced with claim narrative — insurer notice missed 24-hour clause'),
    ('Q2 DDoS Tabletop','tabletop_exercise','2026-05-01','2026-05-09',
     9,38.0,45.0,0,true,true,3.0,true,'ddos','passed_within_sla','stable','Clean run — no gaps identified, used as new-hire onboarding reference'),
    ('Vendor Breach Notification Drill','tabletop_exercise','2026-06-01','2026-06-11',
     11,70.0,60.0,4,true,false,10.0,true,'third_party_vendor_breach','passed_with_gaps','stable','Notification met SLA but claim evidence pack still missing vendor SOC2 attestation'),
    ('Insider Exfiltration Tabletop','tabletop_exercise','2026-07-01','2026-07-22',
     15,48.0,60.0,2,true,true,4.5,true,'insider_threat','passed_within_sla','improving','DLP alert triage improved — legal sign-off obtained same day'),
    ('Data-Breach Claim Readiness Review','desktop_review','2026-07-01','2026-07-05',
     8,null,90.0,6,false,false,null,false,'data_breach','not_conducted','worsening','Scheduled drill postponed twice — claim-documentation template still in draft'),
    ('Ransomware Remediation Follow-up','functional_exercise','2026-06-01','2026-06-25',
     16,75.0,60.0,4,false,true,8.0,true,'ransomware','remediation_in_progress','improving','Backup-immutability gap from May drill being closed; re-test scheduled next cycle'),
    ('DDoS Insurer Coordination Drill','tabletop_exercise','2026-07-01','2026-07-08',
     13,33.0,45.0,1,true,true,2.5,true,'ddos','passed_within_sla','stable','Broker joined live — coverage confirmed adequate for volumetric-attack scenario'),
    ('Third-Party SaaS Breach Tabletop','tabletop_exercise','2026-05-01','2026-05-19',
     17,110.0,60.0,6,false,false,15.0,false,'third_party_vendor_breach','failed_sla','worsening','Sub-processor chain unclear — claim docs cannot establish vendor liability split'),
    ('Insider Threat Access-Abuse Drill','tabletop_exercise','2026-06-01','2026-06-30',
     10,58.0,60.0,2,true,true,5.0,true,'insider_threat','passed_within_sla','stable','HR-IT joint runbook held up well — minor logging gap on shared service accounts'),
    ('Ransomware Policy Coverage Audit','desktop_review','2026-06-01','2026-06-08',
     6,null,120.0,8,false,false,null,true,'ransomware','not_conducted','worsening','Renewal review found sub-limit for business interruption inadequate for current revenue'),
    ('Data-Breach Rapid-Response Drill','functional_exercise','2026-07-01','2026-07-26',
     20,80.0,90.0,3,true,true,7.0,true,'data_breach','passed_within_sla','improving','Call-tree and forensics-vendor activation both inside target window this cycle')
  ) as q(dn, st, pm, dd, pc, rtm, trm, gi, pca, cdr, inh, lc, sc, ds, td, nt);

  -- 8 CAPA rows — attach to drills via drill_name
  insert into public.cyber_drill_capa_actions_r3733 (
    drill_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Vendor API Breach Simulation','No breach-notification SLA clause in vendor contract','Add 24-hour breach-notice clause to all vendor MSAs','in_progress','Vendor Risk Manager','2026-08-20',null,'Legal redlining logistics vendor contract this cycle'),
    ('Customer PII Data-Breach Drill','DPO handoff step undocumented in incident runbook','Publish revised runbook with named DPO escalation path','open','CISO','2026-08-25',null,'Runbook gap traced to Feb reorg — DPO role never updated in playbook'),
    ('Ransomware Full-Scale Simulation','Backup-restore timeline not linked to claim narrative template','Integrate restore-log export into claim documentation kit','overdue','IT Director','2026-08-05',null,'Insurer flagged missing timestamps in prior claim submission'),
    ('Vendor Breach Notification Drill','Vendor SOC2 attestation not centrally tracked','Stand up vendor-attestation register with renewal alerts','closed','Vendor Risk Manager','2026-07-20','2026-07-18','Register live in GRC tool — all top-20 vendors backfilled'),
    ('Data-Breach Claim Readiness Review','Claim-documentation template stuck in draft ownership limbo','Assign template ownership to Legal with fixed review date','open','General Counsel','2026-08-30',null,'Draft has sat for 6 weeks without a named owner'),
    ('Third-Party SaaS Breach Tabletop','Sub-processor liability chain not mapped','Commission sub-processor liability map for top SaaS vendors','in_progress','Vendor Risk Manager','2026-08-22',null,'Mapping 12 sub-processors across 4 critical SaaS vendors'),
    ('Ransomware Policy Coverage Audit','Business-interruption sub-limit set from stale revenue figures','Renegotiate BI sub-limit at next renewal using current revenue','open','CFO','2026-09-10',null,'Broker requested updated revenue figures for re-quote'),
    ('Insider Threat Access-Abuse Drill','Shared service-account activity not individually logged','Enforce per-user credential issuance for shared service accounts','in_progress','IT Security Lead','2026-08-18',null,'Rollout in progress across finance and ops shared accounts')
  ) as q(dn, rc, ca, cst, ownr, tcd, acd, nt)
  join public.cyber_drill_r3733 e
    on e.organization_id = v_org_id and e.drill_name = q.dn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Drill-status distribution
create or replace function public.founder_r3733_drill_status_rollup()
returns table(drill_status text, drills bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cyber_drill_r3733)
  select l.drill_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cyber_drill_r3733 l
  group by l.drill_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_drill_status_rollup() from public, anon;
grant execute on function public.founder_r3733_drill_status_rollup() to authenticated;

-- 2) Scenario-type scorecard
create or replace function public.founder_r3733_scenario_type_scorecard()
returns table(
  scenario_type text,
  drills bigint,
  passed_within_sla bigint,
  failed_sla bigint,
  avg_response_time_minutes numeric,
  avg_target_response_minutes numeric,
  coverage_gaps bigint,
  documentation_not_ready bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scenario_type,
    count(*)::bigint,
    count(*) filter (where l.drill_status = 'passed_within_sla')::bigint,
    count(*) filter (where l.drill_status = 'failed_sla')::bigint,
    round(avg(l.response_time_minutes), 1),
    round(avg(l.target_response_minutes), 1),
    count(*) filter (where l.policy_coverage_adequate = false)::bigint,
    count(*) filter (where l.claim_documentation_ready = false)::bigint
  from public.cyber_drill_r3733 l
  group by l.scenario_type
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_scenario_type_scorecard() from public, anon;
grant execute on function public.founder_r3733_scenario_type_scorecard() to authenticated;

-- 3) Scenario-class × drill-status matrix
create or replace function public.founder_r3733_scenario_class_status_matrix()
returns table(scenario_class text, drill_status text, drills bigint, avg_response_time_minutes numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scenario_class, l.drill_status, count(*)::bigint,
    round(avg(l.response_time_minutes), 1)
  from public.cyber_drill_r3733 l
  group by l.scenario_class, l.drill_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_scenario_class_status_matrix() from public, anon;
grant execute on function public.founder_r3733_scenario_class_status_matrix() to authenticated;

-- 4) Monthly response-time trend
create or replace function public.founder_r3733_monthly_response_time_trend()
returns table(
  period_month date,
  drills bigint,
  avg_response_time_minutes numeric,
  avg_target_response_minutes numeric,
  gaps_identified_total bigint,
  worsening_drills bigint
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
    round(avg(l.response_time_minutes), 1),
    round(avg(l.target_response_minutes), 1),
    coalesce(sum(l.gaps_identified),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.cyber_drill_r3733 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3733_monthly_response_time_trend() from public, anon;
grant execute on function public.founder_r3733_monthly_response_time_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3733_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.cyber_drill_capa_actions_r3733 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_capa_status_board() from public, anon;
grant execute on function public.founder_r3733_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3733_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cyber_drill_capa_actions_r3733)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cyber_drill_capa_actions_r3733 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3733_root_cause_pareto() to authenticated;

-- 7) Coverage-gap digest (policy coverage inadequate or documentation not ready)
create or replace function public.founder_r3733_coverage_gap_digest()
returns table(
  scenario_class text,
  drills bigint,
  coverage_inadequate bigint,
  documentation_not_ready bigint,
  avg_insurer_notified_within_hours numeric,
  lessons_not_captured bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scenario_class,
    count(*)::bigint,
    count(*) filter (where l.policy_coverage_adequate = false)::bigint,
    count(*) filter (where l.claim_documentation_ready = false)::bigint,
    round(avg(l.insurer_notified_within_hours), 1),
    count(*) filter (where l.lessons_captured = false)::bigint
  from public.cyber_drill_r3733 l
  where l.policy_coverage_adequate = false or l.claim_documentation_ready = false
  group by l.scenario_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3733_coverage_gap_digest() from public, anon;
grant execute on function public.founder_r3733_coverage_gap_digest() to authenticated;

-- 8) High-risk drill queue (failed SLA / not conducted, worst first)
create or replace function public.founder_r3733_high_risk_queue()
returns table(
  drill_name text,
  scenario_type text,
  scenario_class text,
  period_month date,
  drill_date date,
  drill_status text,
  response_time_minutes numeric,
  target_response_minutes numeric,
  policy_coverage_adequate boolean,
  claim_documentation_ready boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.drill_name, l.scenario_type, l.scenario_class, l.period_month, l.drill_date,
    l.drill_status, l.response_time_minutes, l.target_response_minutes,
    l.policy_coverage_adequate, l.claim_documentation_ready, l.notes
  from public.cyber_drill_r3733 l
  where l.drill_status in ('failed_sla','not_conducted')
  order by l.drill_date desc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3733_high_risk_queue() from public, anon;
grant execute on function public.founder_r3733_high_risk_queue() to authenticated;
