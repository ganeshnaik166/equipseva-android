-- Round 3369: Founder ROC/MCA Secretarial & Statutory-Compliance Calendar Board
-- Compliance calendar — obligation × category × due-date × days-to-due × filing frequency × responsible × preparation status × late-fee exposure × board-approval × compliance verdict × CAPA

-- =============================================================================
-- TABLE 1: roc_compliance_r3369 — per statutory-compliance obligation
-- =============================================================================
create table if not exists public.roc_compliance_r3369 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  compliance_ref text not null,
  obligation text not null check (obligation in (
    'annual_return_mgt7','financial_statements_aoc4','board_meeting','agm','din_kyc_dir3',
    'dpt3_deposits','msme_return','statutory_registers_update','auditor_appointment_adt1','significant_beneficial_owner'
  )),
  category text not null check (category in (
    'roc_filing','board_governance','statutory_register','director_compliance','auditor_compliance'
  )),
  form_reference text not null,
  responsible_officer text not null,
  responsible text not null check (responsible in (
    'company_secretary','cfo','founder','auditor'
  )),
  financial_year text not null,
  due_date date not null,
  days_to_due int not null,
  filing_frequency text not null check (filing_frequency in (
    'annual','quarterly','half_yearly','event_based'
  )),
  preparation_status text not null check (preparation_status in (
    'not_started','in_progress','ready_to_file','filed','overdue'
  )),
  late_fee_exposure_rupees numeric(12,2),
  dependency_pending boolean not null default false,
  board_approval_needed boolean not null default false,
  compliance_verdict text not null check (compliance_verdict in (
    'on_track','due_soon','preparation_needed','overdue_penalty','escalate_board'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roc_compliance_r3369 enable row level security;

create index if not exists idx_roc_compliance_r3369_org on public.roc_compliance_r3369(organization_id);
create index if not exists idx_roc_compliance_r3369_due on public.roc_compliance_r3369(due_date);
create index if not exists idx_roc_compliance_r3369_verdict on public.roc_compliance_r3369(compliance_verdict);

-- =============================================================================
-- TABLE 2: roc_compliance_capa_actions_r3369 — preparation / filing / escalation actions
-- =============================================================================
create table if not exists public.roc_compliance_capa_actions_r3369 (
  id uuid primary key default gen_random_uuid(),
  compliance_id uuid not null references public.roc_compliance_r3369(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'document_gap','board_resolution_pending','digital_signature_expired','auditor_signoff_pending',
    'data_reconciliation_error','late_filing_penalty','director_kyc_lapse','register_not_updated',
    'beneficial_owner_undeclared','filing_deadline_risk'
  )),
  root_cause text not null check (root_cause in (
    'delayed_financials','cs_bandwidth','auditor_delay','dsc_renewal_missed','board_calendar_slip',
    'data_entry_error','policy_ambiguity','pending_investigation','vendor_portal_downtime','director_unresponsive'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_financial_closure','convene_board_meeting','renew_digital_signature','obtain_auditor_signoff',
    'reconcile_and_refile','pay_late_fee_and_file','complete_director_kyc','update_statutory_register',
    'file_bo_declaration','engage_practising_cs','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'mca_penalty','roc_prosecution','director_disqualification','none','internal_only','additional_fee_per_day'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roc_compliance_capa_actions_r3369 enable row level security;

create index if not exists idx_roc_capa_r3369_compliance on public.roc_compliance_capa_actions_r3369(compliance_id);
create index if not exists idx_roc_capa_r3369_status on public.roc_compliance_capa_actions_r3369(capa_status);

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

  -- 14 compliance-obligation rows
  insert into public.roc_compliance_r3369 (
    organization_id, entity_name, compliance_ref, obligation, category,
    form_reference, responsible_officer, responsible, financial_year, due_date,
    days_to_due, filing_frequency, preparation_status, late_fee_exposure_rupees,
    dependency_pending, board_approval_needed, compliance_verdict, notes
  )
  select v_org_id, q.entity, q.ref, q.obl, q.cat,
    q.form, q.officer, q.resp, q.fy, q.due::date,
    q.dtd::int, q.freq, q.prep, q.latefee::numeric,
    q.deppend, q.boardappr, q.verdict, q.nt
  from (values
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-AGM-2526','agm','board_governance',
     'AGM','Lakshmi Narayanan (CS)','company_secretary','FY2025-26','2026-09-30',
     74,'annual','in_progress',0.00,
     true,true,'preparation_needed','AGM notice drafting; depends on audited accounts sign-off'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-AOC4-2526','financial_statements_aoc4','roc_filing',
     'AOC-4','Rajesh Menon (CFO)','cfo','FY2025-26','2026-10-29',
     103,'annual','not_started',0.00,
     true,false,'on_track','Filing window opens 30 days post-AGM; awaiting audit'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-MGT7-2526','annual_return_mgt7','roc_filing',
     'MGT-7','Lakshmi Narayanan (CS)','company_secretary','FY2025-26','2026-11-28',
     133,'annual','not_started',0.00,
     false,false,'on_track','Annual return due 60 days from AGM'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-DIRKYC-2526','din_kyc_dir3','director_compliance',
     'DIR-3 KYC','Sneha Agarwal (CS)','company_secretary','FY2025-26','2026-09-30',
     74,'annual','in_progress',0.00,
     false,false,'due_soon','3 directors pending DSC-linked DIR-3 KYC upload'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-DPT3-2526','dpt3_deposits','roc_filing',
     'DPT-3','Rajesh Menon (CFO)','cfo','FY2025-26','2026-06-30',
     -18,'annual','overdue',15000.00,
     false,false,'overdue_penalty','DPT-3 not filed by 30 Jun; additional fee accruing'),
    ('EquipSeva Services Pvt Ltd','ROC-SVC-MSME-2627H1','msme_return','roc_filing',
     'MSME-1','Sneha Agarwal (CS)','company_secretary','FY2026-27 H1','2026-10-31',
     105,'half_yearly','not_started',0.00,
     true,false,'on_track','Awaiting >45-day MSME creditor ageing from finance'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-BM-2627Q2','board_meeting','board_governance',
     'Board Meeting Q2','Lakshmi Narayanan (CS)','company_secretary','FY2026-27 Q2','2026-08-05',
     18,'quarterly','ready_to_file',0.00,
     false,false,'due_soon','Notice + agenda circulated; 118-day gap since last meeting'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-REG-2526','statutory_registers_update','statutory_register',
     'MGT-1 / SH-3','Sneha Agarwal (CS)','company_secretary','FY2025-26','2026-07-25',
     7,'event_based','in_progress',0.00,
     false,false,'due_soon','Register of members not updated after Jun rights issue'),
    ('EquipSeva Diagnostics Pvt Ltd','ROC-DIAG-ADT1-2526','auditor_appointment_adt1','auditor_compliance',
     'ADT-1','BSR & Co LLP (Statutory Auditor)','auditor','FY2025-26','2026-10-15',
     89,'event_based','not_started',0.00,
     true,true,'preparation_needed','ADT-1 pending AGM ratification of BSR & Co appointment'),
    ('EquipSeva Services Pvt Ltd','ROC-SVC-BEN2-2526','significant_beneficial_owner','director_compliance',
     'BEN-2','Karthik Subramanian (Founder)','founder','FY2025-26','2026-08-20',
     33,'event_based','in_progress',5000.00,
     true,false,'preparation_needed','SBO declaration from holding LLP awaited before BEN-2'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-AOC4-2425','financial_statements_aoc4','roc_filing',
     'AOC-4','Rajesh Menon (CFO)','cfo','FY2024-25','2025-10-29',
     -262,'annual','filed',0.00,
     false,false,'on_track','FY24-25 AOC-4 filed on time; SRN acknowledged'),
    ('EquipSeva Technologies Pvt Ltd','ROC-TECH-MGT7-2425','annual_return_mgt7','roc_filing',
     'MGT-7','Lakshmi Narayanan (CS)','company_secretary','FY2024-25','2025-11-28',
     -232,'annual','filed',0.00,
     false,false,'on_track','FY24-25 annual return filed and acknowledged'),
    ('EquipSeva Diagnostics Pvt Ltd','ROC-DIAG-BM-2627Q1','board_meeting','board_governance',
     'Board Meeting Q1','Sneha Agarwal (CS)','company_secretary','FY2026-27 Q1','2026-06-25',
     -23,'quarterly','overdue',0.00,
     true,false,'escalate_board','Q1 board meeting lapsed; 120-day gap risk under s.173'),
    ('EquipSeva Foundation','ROC-FDN-DIRKYC-2425','din_kyc_dir3','director_compliance',
     'DIR-3 KYC','Karthik Subramanian (Founder)','founder','FY2024-25','2025-09-30',
     -291,'annual','overdue',5000.00,
     false,false,'overdue_penalty','DIN deactivated; INR 5000 reactivation fee per director')
  ) as q(entity, ref, obl, cat, form, officer, resp, fy, due, dtd, freq, prep, latefee, deppend, boardappr, verdict, nt);

  -- CAPA seed — attach to specific obligations by compliance_ref
  insert into public.roc_compliance_capa_actions_r3369 (
    compliance_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('ROC-TECH-DPT3-2526','late_filing_penalty','board_calendar_slip','pay_late_fee_and_file','escalated','additional_fee_per_day','2026-07-25',null,15000.00,'DPT-3 overdue since 30 Jun; additional fee INR 100/day accruing'),
    ('ROC-TECH-REG-2526','register_not_updated','cs_bandwidth','update_statutory_register','in_progress','internal_only','2026-07-24',null,8000.00,'Register of members pending post rights-issue allotment entry'),
    ('ROC-DIAG-ADT1-2526','auditor_signoff_pending','auditor_delay','obtain_auditor_signoff','open','mca_penalty','2026-10-10',null,25000.00,'ADT-1 blocked on AGM ratification of BSR & Co appointment'),
    ('ROC-SVC-BEN2-2526','beneficial_owner_undeclared','pending_investigation','file_bo_declaration','in_progress','roc_prosecution','2026-08-18',null,5000.00,'SBO chain through holding LLP being traced for BEN-2'),
    ('ROC-DIAG-BM-2627Q1','board_resolution_pending','board_calendar_slip','convene_board_meeting','escalated','mca_penalty','2026-07-22',null,0.00,'Q1 board meeting lapsed; convene within s.173 120-day window'),
    ('ROC-FDN-DIRKYC-2425','director_kyc_lapse','director_unresponsive','complete_director_kyc','overdue','director_disqualification','2026-07-10',null,5000.00,'DIN deactivated; founder DIR-3 KYC + INR 5000 fee pending'),
    ('ROC-TECH-DIRKYC-2526','digital_signature_expired','dsc_renewal_missed','renew_digital_signature','verification_pending','internal_only','2026-08-15','2026-07-15',3000.00,'Two directors DSC renewed; KYC upload verification pending')
  ) as q(ref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.roc_compliance_r3369 e
    on e.organization_id = v_org_id and e.compliance_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3369_compliance_verdict_rollup()
returns table(compliance_verdict text, obligations bigint, total_late_fee_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roc_compliance_r3369)
  select l.compliance_verdict, count(*)::bigint,
         coalesce(sum(l.late_fee_exposure_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.roc_compliance_r3369 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3369_compliance_verdict_rollup() to authenticated;

-- 2) Entity-level compliance scorecard
create or replace function public.founder_r3369_entity_scorecard()
returns table(
  entity_name text,
  total_obligations bigint,
  filed bigint,
  overdue bigint,
  due_soon bigint,
  dependency_pending bigint,
  board_approval_pending bigint,
  total_late_fee_rupees numeric,
  on_track_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.preparation_status = 'filed')::bigint,
    count(*) filter (where l.preparation_status = 'overdue' or l.compliance_verdict in ('overdue_penalty','escalate_board'))::bigint,
    count(*) filter (where l.compliance_verdict = 'due_soon')::bigint,
    count(*) filter (where l.dependency_pending)::bigint,
    count(*) filter (where l.board_approval_needed)::bigint,
    coalesce(sum(l.late_fee_exposure_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'on_track')::numeric / nullif(count(*),0), 1)
  from public.roc_compliance_r3369 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_entity_scorecard() from public, anon;
grant execute on function public.founder_r3369_entity_scorecard() to authenticated;

-- 3) Category × responsible matrix
create or replace function public.founder_r3369_category_responsible_matrix()
returns table(category text, responsible text, obligations bigint, overdue bigint, avg_days_to_due numeric, total_late_fee_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.responsible, count(*)::bigint,
    count(*) filter (where l.preparation_status = 'overdue' or l.compliance_verdict in ('overdue_penalty','escalate_board'))::bigint,
    round(avg(l.days_to_due), 1),
    coalesce(sum(l.late_fee_exposure_rupees),0)::numeric
  from public.roc_compliance_r3369 l
  group by l.category, l.responsible
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_category_responsible_matrix() from public, anon;
grant execute on function public.founder_r3369_category_responsible_matrix() to authenticated;

-- 4) Due-date trend
create or replace function public.founder_r3369_due_date_trend()
returns table(due_date date, obligations bigint, overdue bigint, due_soon bigint, board_approval_needed bigint, total_late_fee_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.due_date,
    count(*)::bigint,
    count(*) filter (where l.preparation_status = 'overdue' or l.compliance_verdict in ('overdue_penalty','escalate_board'))::bigint,
    count(*) filter (where l.compliance_verdict = 'due_soon')::bigint,
    count(*) filter (where l.board_approval_needed)::bigint,
    coalesce(sum(l.late_fee_exposure_rupees),0)::numeric
  from public.roc_compliance_r3369 l
  group by l.due_date
  order by l.due_date desc;
end;
$$;

revoke execute on function public.founder_r3369_due_date_trend() from public, anon;
grant execute on function public.founder_r3369_due_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3369_capa_status_board()
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
  from public.roc_compliance_capa_actions_r3369 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_capa_status_board() from public, anon;
grant execute on function public.founder_r3369_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3369_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roc_compliance_capa_actions_r3369)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.roc_compliance_capa_actions_r3369 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3369_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3369_regulatory_impact_digest()
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
  from public.roc_compliance_capa_actions_r3369 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3369_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3369_regulatory_impact_digest() to authenticated;

-- 8) High-risk compliance queue (top obligations needing action)
create or replace function public.founder_r3369_high_risk_queue()
returns table(
  entity_name text,
  obligation text,
  category text,
  due_date date,
  days_to_due int,
  responsible text,
  preparation_status text,
  late_fee_exposure_rupees numeric,
  compliance_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.obligation, l.category, l.due_date, l.days_to_due,
    l.responsible, l.preparation_status, l.late_fee_exposure_rupees, l.compliance_verdict, l.notes
  from public.roc_compliance_r3369 l
  where l.compliance_verdict in ('due_soon','preparation_needed','overdue_penalty','escalate_board')
     or l.preparation_status = 'overdue'
     or l.dependency_pending
     or l.board_approval_needed
  order by case l.compliance_verdict
             when 'escalate_board' then 0
             when 'overdue_penalty' then 1
             when 'preparation_needed' then 2
             when 'due_soon' then 3
             else 4
           end,
           l.due_date;
end;
$$;

revoke execute on function public.founder_r3369_high_risk_queue() from public, anon;
grant execute on function public.founder_r3369_high_risk_queue() to authenticated;
