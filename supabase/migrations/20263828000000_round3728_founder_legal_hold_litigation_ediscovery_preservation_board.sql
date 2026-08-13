-- Round 3728: Founder Legal-Hold / Litigation E-Discovery Preservation Board
-- Legal-hold notices and litigation e-discovery preservation obligations — matter × custodian ×
-- period × data sources under hold × custodian acknowledgment × preservation confirmation ×
-- release/expiry tracking × spoliation risk × outside-counsel involvement & CAPA remediation.
-- Distinct from any legal-matter/contract-review dispute-exposure page — this tracks hold and
-- preservation mechanics specifically, not disputes/matters generally.

-- =============================================================================
-- TABLE 1: legal_hold_r3728 — per-matter legal-hold & preservation facts
-- =============================================================================
create table if not exists public.legal_hold_r3728 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  matter_ref text not null,
  custodian_name text not null,
  period_month date not null,
  hold_issued_date date,
  hold_scope text,
  data_sources_count int,
  custodian_acknowledged boolean not null,
  preservation_confirmed boolean not null,
  hold_release_date date,
  days_active int,
  spoliation_risk boolean not null,
  outside_counsel_involved boolean not null,
  matter_class text not null check (matter_class in (
    'litigation','regulatory_inquiry','internal_investigation','ip_dispute','employment_claim'
  )),
  hold_status text not null check (hold_status in (
    'active_compliant','active_gap','pending_acknowledgment','released','spoliation_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_hold_r3728 enable row level security;

create index if not exists idx_legal_hold_r3728_org on public.legal_hold_r3728(organization_id);
create index if not exists idx_legal_hold_r3728_month on public.legal_hold_r3728(period_month);
create index if not exists idx_legal_hold_r3728_status on public.legal_hold_r3728(hold_status);

-- =============================================================================
-- TABLE 2: legal_hold_capa_actions_r3728 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.legal_hold_capa_actions_r3728 (
  id uuid primary key default gen_random_uuid(),
  legal_hold_id uuid references public.legal_hold_r3728(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.legal_hold_capa_actions_r3728 enable row level security;

create index if not exists idx_legal_hold_capa_r3728_hold on public.legal_hold_capa_actions_r3728(legal_hold_id);
create index if not exists idx_legal_hold_capa_r3728_status on public.legal_hold_capa_actions_r3728(capa_status);

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

  -- 16 legal-hold rows
  insert into public.legal_hold_r3728 (
    organization_id, matter_ref, custodian_name, period_month, hold_issued_date, hold_scope,
    data_sources_count, custodian_acknowledged, preservation_confirmed, hold_release_date,
    days_active, spoliation_risk, outside_counsel_involved, matter_class, hold_status, trend_dir, notes
  )
  select v_org_id, q.mref, q.cust, q.pm::date, q.hid::date, q.scp,
    q.dsc, q.ack, q.pconf, q.hrd::date,
    q.days, q.spol, q.oc, q.mcls, q.hst, q.trd, q.nt
  from (values
    ('MAT-2026-0101','Rohan Mehta','2026-05-01','2026-05-03','Email, Slack workspace, laptop forensic image — vendor supply contract dispute',
     4,true,true,null,102,false,true,'litigation','active_compliant','stable','Hold current; custodian confirmed device imaging complete'),
    ('MAT-2026-0102','Priya Nair','2026-05-01','2026-05-05','Email archive, CRM opportunity records',
     3,true,false,null,100,true,true,'litigation','active_gap','worsening','IT has not confirmed CRM export preserved — escalated to outside counsel'),
    ('MAT-2026-0103','Arjun Verma','2026-06-01','2026-06-02','Trading logs, email, chat transcripts — SEBI inquiry',
     5,false,false,null,72,false,true,'regulatory_inquiry','pending_acknowledgment','stable','Custodian on leave; hold notice re-sent via HR'),
    ('MAT-2026-0104','Sneha Kulkarni','2026-06-01','2026-06-04','Compliance database extract, email — RBI KYC audit',
     3,true,true,null,70,false,true,'regulatory_inquiry','active_compliant','improving','Weekly compliance sync confirms scope unchanged'),
    ('MAT-2026-0105','Vikram Rao','2026-04-01','2026-04-06','Expense management system export, email, laptop image',
     4,true,true,'2026-07-20',105,false,false,'internal_investigation','released','stable','Investigation closed; hold released after findings report filed'),
    ('MAT-2026-0106','Anita Desai','2026-07-01','2026-07-02','Email, HR case management system, mobile phone backup',
     2,true,true,null,41,false,false,'internal_investigation','active_compliant','stable','HR investigation ongoing; custodian fully cooperative'),
    ('MAT-2026-0107','Karan Malhotra','2026-03-01','2026-03-10','Design files, source-code repository, engineering email',
     6,true,true,null,156,true,true,'ip_dispute','spoliation_risk','worsening','Repository auto-purge policy ran before suspension — forensic recovery underway'),
    ('MAT-2026-0108','Neha Iyer','2026-05-01','2026-05-15','Marketing creative assets, brand email threads',
     2,true,false,null,90,false,true,'ip_dispute','active_gap','worsening','Marketing DAM export still pending from vendor'),
    ('MAT-2026-0109','Suresh Pillai','2026-06-01','2026-06-05','Email, performance review records, manager notes',
     3,true,true,null,69,false,false,'employment_claim','active_compliant','stable','Documentation preserved ahead of tribunal filing'),
    ('MAT-2026-0110','Meera Bhatt','2026-07-01',null,'Email, Slack direct messages, calendar records',
     2,false,false,null,30,false,false,'employment_claim','pending_acknowledgment','worsening','Custodian yet to sign acknowledgment; second reminder sent'),
    ('MAT-2026-0111','Rohan Mehta','2026-07-01','2026-07-03','Signed contracts, email, vendor invoices',
     3,true,true,null,40,false,true,'litigation','active_compliant','stable','Breach-of-contract matter — scope confirmed with outside counsel'),
    ('MAT-2026-0112','Priya Nair','2026-02-01','2026-02-05','Email, CRM, customer-support call recordings',
     5,true,false,null,185,true,true,'litigation','spoliation_risk','worsening','Call-recording retention lapsed at 180 days before hold applied'),
    ('MAT-2026-0113','Arjun Verma','2026-07-01','2026-07-08','Import documentation, customs correspondence email',
     3,true,true,'2026-08-01',24,false,false,'regulatory_inquiry','released','stable','Customs audit closed with no findings; hold lifted'),
    ('MAT-2026-0114','Sneha Kulkarni','2026-07-01','2026-07-01','Email, endpoint activity logs, laptop image',
     5,false,true,null,43,false,true,'internal_investigation','pending_acknowledgment','improving','New custodian being onboarded to hold-notification platform'),
    ('MAT-2026-0115','Vikram Rao','2026-01-01','2026-01-10','Source-code repository, email, Slack, laptop image',
     4,true,true,null,216,false,true,'ip_dispute','active_compliant','improving','Trade-secret matter — quarterly preservation review completed'),
    ('MAT-2026-0116','Anita Desai','2026-04-01','2026-04-12','Payroll records, email correspondence',
     2,true,true,'2026-06-30',79,false,false,'employment_claim','released','stable','Wage-dispute matter settled; hold released post-settlement')
  ) as q(mref, cust, pm, hid, scp, dsc, ack, pconf, hrd, days, spol, oc, mcls, hst, trd, nt);

  -- CAPA seed — attach to specific matters via matter_ref
  insert into public.legal_hold_capa_actions_r3728 (
    legal_hold_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('MAT-2026-0102','custodian_did_not_confirm_receipt','reissue_hold_notice_and_confirm_receipt','open','Legal Ops Counsel','2026-08-20',null,'Litigation hold re-issued via courier with read receipt required'),
    ('MAT-2026-0103','acknowledgment_pending_beyond_sla','escalate_to_manager_for_signoff','in_progress','Compliance Counsel','2026-08-18',null,'Manager co-signing acknowledgment while custodian is on leave'),
    ('MAT-2026-0107','repository_auto_purge_not_suspended','suspend_retention_policy_and_forensic_image','open','Outside Counsel - IP Team','2026-08-25',null,'Forensic imaging vendor engaged to attempt recovery of purged commits'),
    ('MAT-2026-0108','preservation_not_confirmed_by_it','it_to_verify_backup_snapshot_taken','overdue','IT Security Lead','2026-07-30',null,'DAM export confirmation now well past target date'),
    ('MAT-2026-0110','custodian_unresponsive_to_hold_notice','hr_to_hand_deliver_notice_and_track','in_progress','HR Business Partner','2026-08-22',null,'Third reminder hand-delivered with acknowledgment form attached'),
    ('MAT-2026-0112','call_recording_retention_expired_before_hold','notify_court_of_gap_and_remediate_process','closed','General Counsel','2026-07-10','2026-07-08','Court notified of retention gap; retention policy extended to 365 days'),
    ('MAT-2026-0114','new_custodian_not_onboarded_to_hold_tool','add_custodian_to_legal_hold_platform','closed','Legal Ops Counsel','2026-07-15','2026-07-12','Custodian added to platform; acknowledgment captured same day'),
    ('MAT-2026-0101','quarterly_review_reminder','confirm_continued_relevance_of_hold','open','Legal Ops Counsel','2026-09-01',null,'Routine quarterly review scheduled to confirm hold still required')
  ) as q(mref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.legal_hold_r3728 e
    on e.organization_id = v_org_id and e.matter_ref = q.mref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Hold-status distribution
create or replace function public.founder_r3728_hold_status_rollup()
returns table(hold_status text, holds bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_hold_r3728)
  select l.hold_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.legal_hold_r3728 l
  group by l.hold_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3728_hold_status_rollup() from public, anon;
grant execute on function public.founder_r3728_hold_status_rollup() to authenticated;

-- 2) Custodian scorecard
create or replace function public.founder_r3728_custodian_scorecard()
returns table(
  custodian_name text,
  total_holds bigint,
  active_compliant bigint,
  active_gap bigint,
  pending_acknowledgment bigint,
  released bigint,
  spoliation_risk_count bigint,
  ack_pct numeric,
  avg_days_active numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.custodian_name,
    count(*)::bigint,
    count(*) filter (where l.hold_status = 'active_compliant')::bigint,
    count(*) filter (where l.hold_status = 'active_gap')::bigint,
    count(*) filter (where l.hold_status = 'pending_acknowledgment')::bigint,
    count(*) filter (where l.hold_status = 'released')::bigint,
    count(*) filter (where l.hold_status = 'spoliation_risk')::bigint,
    round((count(*) filter (where l.custodian_acknowledged)::numeric / nullif(count(*),0)) * 100.0, 1),
    round(avg(l.days_active), 1)
  from public.legal_hold_r3728 l
  group by l.custodian_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3728_custodian_scorecard() from public, anon;
grant execute on function public.founder_r3728_custodian_scorecard() to authenticated;

-- 3) Matter-class × hold-status matrix
create or replace function public.founder_r3728_matter_class_status_matrix()
returns table(matter_class text, hold_status text, holds bigint, avg_days_active numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.matter_class, l.hold_status, count(*)::bigint, round(avg(l.days_active), 1)
  from public.legal_hold_r3728 l
  group by l.matter_class, l.hold_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3728_matter_class_status_matrix() from public, anon;
grant execute on function public.founder_r3728_matter_class_status_matrix() to authenticated;

-- 4) Monthly hold-issuance trend
create or replace function public.founder_r3728_monthly_hold_issuance_trend()
returns table(
  period_month date,
  holds bigint,
  acknowledged bigint,
  preservation_confirmed bigint,
  spoliation_risk_count bigint,
  worsening_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.custodian_acknowledged)::bigint,
    count(*) filter (where l.preservation_confirmed)::bigint,
    count(*) filter (where l.hold_status = 'spoliation_risk')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.legal_hold_r3728 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3728_monthly_hold_issuance_trend() from public, anon;
grant execute on function public.founder_r3728_monthly_hold_issuance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3728_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.legal_hold_capa_actions_r3728 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3728_capa_status_board() from public, anon;
grant execute on function public.founder_r3728_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3728_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.legal_hold_capa_actions_r3728)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.legal_hold_capa_actions_r3728 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3728_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3728_root_cause_pareto() to authenticated;

-- 7) Spoliation-risk digest by matter class
create or replace function public.founder_r3728_spoliation_risk_digest()
returns table(
  matter_class text,
  holds bigint,
  spoliation_risk_holds bigint,
  unacknowledged_holds bigint,
  unconfirmed_preservation_holds bigint,
  outside_counsel_involved_holds bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.matter_class,
    count(*)::bigint,
    count(*) filter (where l.spoliation_risk)::bigint,
    count(*) filter (where not l.custodian_acknowledged)::bigint,
    count(*) filter (where not l.preservation_confirmed)::bigint,
    count(*) filter (where l.outside_counsel_involved)::bigint
  from public.legal_hold_r3728 l
  where l.spoliation_risk = true
     or l.hold_status = 'spoliation_risk'
     or l.custodian_acknowledged = false
     or l.preservation_confirmed = false
  group by l.matter_class
  order by count(*) filter (where l.spoliation_risk) desc;
end;
$$;

revoke all on function public.founder_r3728_spoliation_risk_digest() from public, anon;
grant execute on function public.founder_r3728_spoliation_risk_digest() to authenticated;

-- 8) High-risk hold queue (spoliation risk / active gaps, worst first)
create or replace function public.founder_r3728_high_risk_queue()
returns table(
  matter_ref text,
  custodian_name text,
  matter_class text,
  hold_status text,
  period_month date,
  days_active int,
  data_sources_count int,
  spoliation_risk boolean,
  outside_counsel_involved boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.matter_ref, l.custodian_name, l.matter_class, l.hold_status, l.period_month,
    l.days_active, l.data_sources_count, l.spoliation_risk, l.outside_counsel_involved, l.notes
  from public.legal_hold_r3728 l
  where l.hold_status in ('spoliation_risk','active_gap')
  order by l.spoliation_risk desc, l.days_active desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3728_high_risk_queue() from public, anon;
grant execute on function public.founder_r3728_high_risk_queue() to authenticated;
