-- Round 3289: Founder Tender EMD / Bank-Guarantee / Performance-Security Governance Board
-- Commercial finance board — tender EMD, bid-security, BG & performance-security capital locked in
-- govt/hospital tenders: instrument verdict × customer entity × type/outcome matrix × validity
-- expiry trend × reclaim/renew/forfeit-prevention CAPA. Founder-gated.

-- =============================================================================
-- TABLE 1: tender_emd_bg_r3289 — one row per EMD / bid-security / BG instrument
-- =============================================================================
create table if not exists public.tender_emd_bg_r3289 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  tender_ref text not null,
  customer_entity text not null check (customer_entity in (
    'govt_hospital','private_chain','medical_college','state_health_dept','defence_hospital'
  )),
  instrument_type text not null check (instrument_type in (
    'emd_dd','emd_bg','bid_security','performance_bank_guarantee','security_deposit','retention_money'
  )),
  issuing_bank text not null,
  amount_rupees numeric(14,2) not null,
  issue_date date not null,
  validity_end date not null,
  tender_outcome text not null check (tender_outcome in (
    'pending','won','lost','disqualified','cancelled'
  )),
  reclaim_status text not null check (reclaim_status in (
    'locked_active','reclaim_due','reclaimed','forfeited','bg_invoked'
  )),
  margin_money_blocked_rupees numeric(14,2),
  bg_commission_rupees numeric(12,2),
  days_to_expiry int,
  instrument_verdict text not null check (instrument_verdict in (
    'healthy','reclaim_now','expiring_soon','forfeit_risk','overdue_reclaim'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tender_emd_bg_r3289 enable row level security;

create index if not exists idx_tender_emd_bg_r3289_org on public.tender_emd_bg_r3289(org_id);
create index if not exists idx_tender_emd_bg_r3289_validity on public.tender_emd_bg_r3289(validity_end);
create index if not exists idx_tender_emd_bg_r3289_verdict on public.tender_emd_bg_r3289(instrument_verdict);

-- =============================================================================
-- TABLE 2: tender_emd_bg_capa_actions_r3289 — reclaim / renewal / forfeit-prevention actions
-- =============================================================================
create table if not exists public.tender_emd_bg_capa_actions_r3289 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  instrument_id uuid not null references public.tender_emd_bg_r3289(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'reclaim_overdue','validity_expiring','bg_renewal_due','forfeiture_risk',
    'excess_margin_blocked','commission_overcharge','document_missing','duplicate_instrument'
  )),
  root_cause text not null check (root_cause in (
    'tender_result_delayed','bank_processing_delay','internal_tracking_gap','customer_non_release',
    'performance_dispute','documentation_error','renewal_missed','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_reclaim_request','renew_bank_guarantee','escalate_to_customer','release_margin_money',
    'negotiate_commission','submit_documents','invoke_legal_recourse','write_off_forfeiture','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_impact text not null check (exposure_impact in (
    'capital_locked','commission_bleed','forfeiture_loss','none','audit_flag','cashflow_critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tender_emd_bg_capa_actions_r3289 enable row level security;

create index if not exists idx_tender_emd_bg_capa_r3289_instrument on public.tender_emd_bg_capa_actions_r3289(instrument_id);
create index if not exists idx_tender_emd_bg_capa_r3289_status on public.tender_emd_bg_capa_actions_r3289(capa_status);

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

  -- 14 instrument rows
  insert into public.tender_emd_bg_r3289 (
    org_id, tender_ref, customer_entity, instrument_type, issuing_bank,
    amount_rupees, issue_date, validity_end, tender_outcome, reclaim_status,
    margin_money_blocked_rupees, bg_commission_rupees, days_to_expiry, instrument_verdict, notes
  )
  select v_org_id, q.tref, q.cust, q.itype, q.bank,
    q.amt, q.idt::date, q.ved::date, q.outcome, q.reclaim,
    q.margin, q.comm, q.dte, q.verdict, q.nt
  from (values
    ('TND-AIIMS-2026-014','govt_hospital','emd_bg','State Bank of India',
     500000.00,'2026-01-10','2026-08-10','won','reclaim_due',125000.00,6250.00,23,'reclaim_now',
     'Tender awarded — EMD BG reclaim due post-award, filed with SBI'),
    ('TND-APLC-2026-088','private_chain','performance_bank_guarantee','HDFC Bank',
     1800000.00,'2026-03-01','2027-03-01','won','locked_active',450000.00,27000.00,226,'healthy',
     'PBG for 5-yr CSSD AMC at Apollo Chennai — active and healthy'),
    ('TND-FRTG-2026-051','private_chain','bid_security','ICICI Bank',
     300000.00,'2026-04-15','2026-07-25','lost','reclaim_due',0.00,3600.00,7,'reclaim_now',
     'Bid lost at Fortis Gurgaon — bid-security reclaim due, follow up with tender cell'),
    ('TND-AIIMS-2026-009','govt_hospital','emd_dd','Punjab National Bank',
     200000.00,'2025-12-05','2026-06-05','lost','reclaimed',0.00,null,-43,'healthy',
     'EMD DD refunded by AIIMS after result — closed clean'),
    ('TND-MNPL-2026-033','private_chain','security_deposit','Axis Bank',
     750000.00,'2026-02-20','2027-02-20','won','locked_active',187500.00,null,217,'healthy',
     'Security deposit for Manipal Bengaluru radiology turnkey — locked per contract'),
    ('TND-CMCV-2026-072','medical_college','emd_bg','Indian Bank',
     400000.00,'2026-01-25','2026-07-22','won','reclaim_due',100000.00,5000.00,4,'expiring_soon',
     'CMC Vellore EMD BG expiring in 4 days — reclaim or renew before validity_end'),
    ('TND-MHFW-2026-118','state_health_dept','performance_bank_guarantee','Bank of Baroda',
     3200000.00,'2026-05-10','2027-05-10','won','locked_active',800000.00,48000.00,296,'healthy',
     'PBG for Maharashtra statewide ventilator supply — high value, active'),
    ('TND-KIMS-2026-060','private_chain','emd_bg','Kotak Mahindra Bank',
     350000.00,'2026-03-18','2026-09-18','disqualified','forfeited',87500.00,4200.00,62,'forfeit_risk',
     'KIMS Hyderabad bid disqualified on technical grounds — EMD forfeited by procurer'),
    ('TND-ARHR-2026-025','defence_hospital','performance_bank_guarantee','State Bank of India',
     2500000.00,'2025-11-01','2026-11-01','won','bg_invoked',625000.00,37500.00,106,'forfeit_risk',
     'Army R&R PBG invoked over SLA breach dispute — legal review underway'),
    ('TND-GMCN-2026-104','medical_college','bid_security','Union Bank of India',
     250000.00,'2026-06-20','2026-09-20','pending','locked_active',0.00,3000.00,64,'healthy',
     'GMC Nagpur bid under evaluation — bid-security locked pending result'),
    ('TND-FRTG-2025-201','private_chain','retention_money','HDFC Bank',
     600000.00,'2025-06-30','2026-06-30','won','reclaim_due',600000.00,null,-18,'overdue_reclaim',
     'Fortis Gurgaon retention release overdue 18 days post defect-liability — escalate'),
    ('TND-TNMS-2026-077','state_health_dept','emd_dd','Indian Overseas Bank',
     150000.00,'2026-05-05','2026-08-05','cancelled','reclaim_due',0.00,null,18,'reclaim_now',
     'Tamil Nadu tender cancelled by dept — EMD DD refund due, claim filed'),
    ('TND-APLC-2026-045','private_chain','emd_bg','ICICI Bank',
     450000.00,'2025-12-15','2026-06-15','won','reclaimed',112500.00,5400.00,-33,'healthy',
     'Apollo Chennai EMD BG released after PBG substitution — closed'),
    ('TND-AIIMS-2026-020','govt_hospital','security_deposit','State Bank of India',
     900000.00,'2026-04-01','2028-04-01','won','locked_active',225000.00,54000.00,623,'healthy',
     'AIIMS security deposit for 2-yr comprehensive AMC — long lock, healthy')
  ) as q(tref, cust, itype, bank, amt, idt, ved, outcome, reclaim, margin, comm, dte, verdict, nt);

  -- CAPA seed — attach to at-risk instruments via tender_ref
  insert into public.tender_emd_bg_capa_actions_r3289 (
    org_id, instrument_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.exp, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TND-FRTG-2026-051','reclaim_overdue','tender_result_delayed','file_reclaim_request','in_progress','capital_locked','2026-07-24',null,300000.00,'Bid-security reclaim filed with ICICI, awaiting release'),
    ('TND-CMCV-2026-072','validity_expiring','renewal_missed','renew_bank_guarantee','open','capital_locked','2026-07-21',null,5000.00,'BG expiring in days — renew or reclaim before validity_end via Indian Bank'),
    ('TND-KIMS-2026-060','forfeiture_risk','documentation_error','invoke_legal_recourse','escalated','forfeiture_loss','2026-08-01',null,350000.00,'EMD forfeited on technical DQ — contesting via written representation'),
    ('TND-ARHR-2026-025','forfeiture_risk','performance_dispute','invoke_legal_recourse','escalated','cashflow_critical','2026-08-15',null,2500000.00,'PBG invoked over SLA dispute — arbitration notice issued, counsel engaged'),
    ('TND-FRTG-2025-201','reclaim_overdue','customer_non_release','escalate_to_customer','overdue','capital_locked','2026-07-10',null,600000.00,'Retention release 18 days overdue — escalated to Fortis projects head'),
    ('TND-TNMS-2026-077','reclaim_overdue','tender_result_delayed','file_reclaim_request','in_progress','capital_locked','2026-07-28',null,150000.00,'Tender cancelled — EMD DD refund claim submitted to TN medical services'),
    ('TND-AIIMS-2026-014','document_missing','internal_tracking_gap','submit_documents','closed','audit_flag','2026-07-15','2026-07-16',0.00,'Reclaim documentation gap closed — reconciliation done, awaiting SBI margin credit')
  ) as q(tref, fc, rc, ca, cst, exp, tcd, acd, cost, nt)
  join public.tender_emd_bg_r3289 e
    on e.org_id = v_org_id and e.tender_ref = q.tref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Instrument verdict distribution
create or replace function public.founder_r3289_instrument_verdict_rollup()
returns table(instrument_verdict text, instruments bigint, total_amount_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tender_emd_bg_r3289)
  select l.instrument_verdict, count(*)::bigint,
         coalesce(sum(l.amount_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tender_emd_bg_r3289 l
  group by l.instrument_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_instrument_verdict_rollup() from public, anon;
grant execute on function public.founder_r3289_instrument_verdict_rollup() to authenticated;

-- 2) Customer-entity scorecard
create or replace function public.founder_r3289_customer_scorecard()
returns table(
  customer_entity text,
  total_instruments bigint,
  won bigint,
  lost bigint,
  pending bigint,
  reclaim_due bigint,
  forfeited bigint,
  total_amount_rupees numeric,
  blocked_capital_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_entity,
    count(*)::bigint,
    count(*) filter (where l.tender_outcome = 'won')::bigint,
    count(*) filter (where l.tender_outcome in ('lost','disqualified'))::bigint,
    count(*) filter (where l.tender_outcome = 'pending')::bigint,
    count(*) filter (where l.reclaim_status = 'reclaim_due')::bigint,
    count(*) filter (where l.reclaim_status in ('forfeited','bg_invoked'))::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    coalesce(sum(l.margin_money_blocked_rupees),0)::numeric
  from public.tender_emd_bg_r3289 l
  group by l.customer_entity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_customer_scorecard() from public, anon;
grant execute on function public.founder_r3289_customer_scorecard() to authenticated;

-- 3) Instrument-type × tender-outcome matrix
create or replace function public.founder_r3289_type_outcome_matrix()
returns table(instrument_type text, tender_outcome text, instruments bigint, total_amount_rupees numeric, blocked_capital_rupees numeric, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, l.tender_outcome, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    coalesce(sum(l.margin_money_blocked_rupees),0)::numeric,
    round(avg(l.days_to_expiry), 1)
  from public.tender_emd_bg_r3289 l
  group by l.instrument_type, l.tender_outcome
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_type_outcome_matrix() from public, anon;
grant execute on function public.founder_r3289_type_outcome_matrix() to authenticated;

-- 4) Validity-expiry trend (by validity_end date)
create or replace function public.founder_r3289_validity_expiry_trend()
returns table(validity_end date, instruments bigint, total_amount_rupees numeric, reclaim_due bigint, forfeit_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.validity_end,
    count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    count(*) filter (where l.reclaim_status = 'reclaim_due')::bigint,
    count(*) filter (where l.instrument_verdict in ('forfeit_risk','overdue_reclaim'))::bigint
  from public.tender_emd_bg_r3289 l
  group by l.validity_end
  order by l.validity_end;
end;
$$;

revoke execute on function public.founder_r3289_validity_expiry_trend() from public, anon;
grant execute on function public.founder_r3289_validity_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3289_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.tender_emd_bg_capa_actions_r3289 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_capa_status_board() from public, anon;
grant execute on function public.founder_r3289_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3289_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tender_emd_bg_capa_actions_r3289)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tender_emd_bg_capa_actions_r3289 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3289_root_cause_pareto() to authenticated;

-- 7) Exposure / cost-risk digest
create or replace function public.founder_r3289_exposure_impact_digest()
returns table(exposure_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.exposure_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.tender_emd_bg_capa_actions_r3289 c
  group by c.exposure_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3289_exposure_impact_digest() from public, anon;
grant execute on function public.founder_r3289_exposure_impact_digest() to authenticated;

-- 8) High-risk instrument queue (reclaim / forfeit / expiry concerns)
create or replace function public.founder_r3289_high_risk_queue()
returns table(
  tender_ref text,
  customer_entity text,
  instrument_type text,
  issuing_bank text,
  amount_rupees numeric,
  validity_end date,
  tender_outcome text,
  reclaim_status text,
  days_to_expiry int,
  instrument_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tender_ref, l.customer_entity, l.instrument_type, l.issuing_bank,
    l.amount_rupees, l.validity_end, l.tender_outcome, l.reclaim_status,
    l.days_to_expiry, l.instrument_verdict, l.notes
  from public.tender_emd_bg_r3289 l
  where l.instrument_verdict in ('reclaim_now','expiring_soon','forfeit_risk','overdue_reclaim')
     or l.reclaim_status in ('reclaim_due','forfeited','bg_invoked')
     or l.tender_outcome in ('lost','disqualified')
  order by l.days_to_expiry asc, l.validity_end;
end;
$$;

revoke execute on function public.founder_r3289_high_risk_queue() from public, anon;
grant execute on function public.founder_r3289_high_risk_queue() to authenticated;
