-- Round 3680: Founder Pollution-Consent (CTE/CTO) / PCB Compliance Board
-- State pollution-control consents — facility × state board × consent class × validity × condition compliance × returns filing × notices × CAPA

-- =============================================================================
-- TABLE 1: pcb_consent_r3680 — per-consent PCB compliance ledger
-- =============================================================================
create table if not exists public.pcb_consent_r3680 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  facility_name text not null,
  state_board text not null,
  period_month date not null,
  consent_no text not null,
  valid_till date not null,
  days_to_expiry int not null,
  category_band text not null,
  conditions_total int not null,
  conditions_met int not null,
  condition_compliance_pct numeric(5,2) not null,
  returns_filed boolean not null,
  notices_open int not null,
  consent_class text not null check (consent_class in (
    'cte_new','cto_operate','renewal','white_category_exempt','hazwaste_authorization'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','renewal_due','condition_gap','returns_pending','notice_received'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pcb_consent_r3680 enable row level security;

create index if not exists idx_pcb_consent_r3680_org on public.pcb_consent_r3680(organization_id);
create index if not exists idx_pcb_consent_r3680_month on public.pcb_consent_r3680(period_month);
create index if not exists idx_pcb_consent_r3680_status on public.pcb_consent_r3680(compliance_status);

-- =============================================================================
-- TABLE 2: pcb_consent_capa_actions_r3680 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pcb_consent_capa_actions_r3680 (
  id uuid primary key default gen_random_uuid(),
  consent_id uuid not null references public.pcb_consent_r3680(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'renewal_application_delayed','condition_monitoring_lapse','etp_stp_underperformance',
    'returns_filing_backlog','consultant_dependency','fee_payment_missed',
    'document_records_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','install_online_monitoring','upgrade_etp_capacity',
    'clear_returns_backlog','engage_environment_consultant','pay_fees_and_penalty',
    'close_condition_gaps','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  penalty_exposure_rupees numeric(12,2),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pcb_consent_capa_actions_r3680 enable row level security;

create index if not exists idx_pcb_consent_capa_r3680_consent on public.pcb_consent_capa_actions_r3680(consent_id);
create index if not exists idx_pcb_consent_capa_r3680_status on public.pcb_consent_capa_actions_r3680(capa_status);

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

  -- 16 consent-compliance rows
  insert into public.pcb_consent_r3680 (
    organization_id, facility_name, state_board, period_month, consent_no,
    valid_till, days_to_expiry, category_band, conditions_total, conditions_met,
    condition_compliance_pct, returns_filed, notices_open,
    consent_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.fac, q.brd, q.pm::date, q.cno,
    q.vtill::date, q.dexp, q.cat, q.ctot, q.cmet,
    q.cpct::numeric, q.rfil, q.nop,
    q.ccls, q.cstat, q.trd, q.nt
  from (values
    ('EquipSeva Mumbai HQ','MPCB (Maharashtra)','2026-07-01','MPCB/CTO/2026/48211',
     '2027-03-31',234,'orange',18,18,'100.00',true,0,
     'cto_operate','compliant','stable','CTO operate current; all 18 conditions verified in July self-audit'),
    ('EquipSeva Mumbai HQ','MPCB (Maharashtra)','2026-07-01','MPCB/HWA/2026/09314',
     '2026-09-30',52,'orange',12,10,'83.33',true,0,
     'hazwaste_authorization','renewal_due','stable','Hazwaste authorization expires September — renewal dossier under preparation'),
    ('EquipSeva Chennai Service Hub','TNPCB (Tamil Nadu)','2026-07-01','TNPCB/CTO/2026/22871',
     '2028-06-30',691,'green',14,11,'78.57',false,1,
     'cto_operate','returns_pending','worsening','Water cess return for Q1 not filed; TNPCB reminder letter received'),
    ('EquipSeva Chennai Service Hub','TNPCB (Tamil Nadu)','2026-07-01','TNPCB/CTE/2026/30125',
     '2026-12-31',144,'orange',10,8,'80.00',true,0,
     'cte_new','condition_gap','improving','CTE for service-bay expansion; two construction-phase conditions pending'),
    ('EquipSeva Delhi Warehouse','DPCC (Delhi)','2026-07-01','DPCC/CTO/2026/17402',
     '2027-01-15',160,'green',9,9,'100.00',true,0,
     'cto_operate','compliant','improving','Warehouse CTO fully compliant; battery-storage condition closed'),
    ('EquipSeva Delhi Warehouse','DPCC (Delhi)','2026-07-01','DPCC/WCE/2026/00987',
     '2027-12-31',510,'white',4,4,'100.00',true,0,
     'white_category_exempt','compliant','stable','White-category exemption acknowledgment on record for office block'),
    ('EquipSeva Bengaluru Refurb Center','KSPCB (Karnataka)','2026-07-01','KSPCB/CTO/2026/55118',
     '2026-08-20',41,'red',22,16,'72.73',true,2,
     'cto_operate','notice_received','worsening','Show-cause notice on ETP outlet BOD exceedance; renewal window open'),
    ('EquipSeva Bengaluru Refurb Center','KSPCB (Karnataka)','2026-07-01','KSPCB/RNW/2026/61240',
     '2026-08-20',41,'red',22,17,'77.27',true,1,
     'renewal','renewal_due','improving','CTO renewal application filed with bank guarantee; hearing awaited'),
    ('EquipSeva Mumbai HQ','MPCB (Maharashtra)','2026-06-01','MPCB/CTO/2026/48210',
     '2027-03-31',264,'orange',18,17,'94.44',true,0,
     'cto_operate','compliant','improving','June audit — one housekeeping condition closed mid-month'),
    ('EquipSeva Chennai Service Hub','TNPCB (Tamil Nadu)','2026-06-01','TNPCB/CTO/2026/22870',
     '2028-06-30',721,'green',14,12,'85.71',true,0,
     'cto_operate','compliant','stable','June self-monitoring within limits; returns filed on time'),
    ('EquipSeva Delhi Warehouse','DPCC (Delhi)','2026-06-01','DPCC/CTO/2026/17401',
     '2027-01-15',190,'green',9,8,'88.89',false,0,
     'cto_operate','returns_pending','stable','Annual environmental statement Form V pending upload on DPCC portal'),
    ('EquipSeva Bengaluru Refurb Center','KSPCB (Karnataka)','2026-06-01','KSPCB/CTO/2026/55117',
     '2026-08-20',71,'red',22,15,'68.18',true,2,
     'cto_operate','condition_gap','worsening','ETP sludge disposal manifest gaps; two consent conditions open'),
    ('EquipSeva Mumbai HQ','MPCB (Maharashtra)','2026-05-01','MPCB/CTE/2026/40566',
     '2026-11-30',175,'orange',8,6,'75.00',true,0,
     'cte_new','condition_gap','stable','CTE for refurb-line addition; rainwater-harvesting condition pending'),
    ('EquipSeva Chennai Service Hub','TNPCB (Tamil Nadu)','2026-05-01','TNPCB/HWA/2026/28714',
     '2027-05-31',358,'orange',11,11,'100.00',true,0,
     'hazwaste_authorization','compliant','stable','E-waste and used-oil authorization compliant; manifests reconciled'),
    ('EquipSeva Delhi Warehouse','DPCC (Delhi)','2026-05-01','DPCC/RNW/2026/00841',
     '2026-07-31',45,'green',9,9,'100.00',true,0,
     'renewal','renewal_due','stable','Warehouse CTO renewal filed 120 days ahead; deemed-renewal expected'),
    ('EquipSeva Bengaluru Refurb Center','KSPCB (Karnataka)','2026-05-01','KSPCB/HWA/2026/58903',
     '2026-10-15',130,'red',15,12,'80.00',false,1,
     'hazwaste_authorization','notice_received','worsening','Direction issued on Form 4 filing delay for lead-acid battery scrap')
  ) as q(fac, brd, pm, cno, vtill, dexp, cat, ctot, cmet, cpct, rfil, nop, ccls, cstat, trd, nt);

  -- CAPA seed — attach to specific consents via consent_no
  insert into public.pcb_consent_capa_actions_r3680 (
    consent_id, root_cause, corrective_action, capa_status,
    penalty_exposure_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.pen::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('KSPCB/CTO/2026/55118','etp_stp_underperformance','upgrade_etp_capacity','escalated',
     '450000.00','Plant Head - Bengaluru','2026-08-10',null,'ETP aeration upgrade PO released; interim tanker disposal in place'),
    ('KSPCB/RNW/2026/61240','renewal_application_delayed','file_renewal_application','verification_pending',
     '120000.00','EHS Manager - Karnataka','2026-08-05',null,'Renewal filed with consent fee; awaiting KSPCB hearing outcome'),
    ('TNPCB/CTO/2026/22871','returns_filing_backlog','clear_returns_backlog','in_progress',
     '15000.00','Compliance Officer - Chennai','2026-07-25',null,'Q1 water cess return drafted; CA certification underway'),
    ('TNPCB/CTE/2026/30125','condition_monitoring_lapse','close_condition_gaps','open',
     '80000.00','Project Lead - Chennai','2026-09-15',null,'Construction-phase dust screens and STP tie-in pending'),
    ('DPCC/CTO/2026/17401','document_records_gap','clear_returns_backlog','closed',
     '0.00','Warehouse Manager - Delhi','2026-06-30','2026-06-24','Form V uploaded on DPCC portal; acknowledgment archived'),
    ('MPCB/HWA/2026/09314','renewal_application_delayed','file_renewal_application','in_progress',
     '60000.00','EHS Manager - Mumbai','2026-08-20',null,'Hazwaste renewal dossier 80 pct ready; CTO copy and layout pending'),
    ('KSPCB/HWA/2026/58903','fee_payment_missed','pay_fees_and_penalty','overdue',
     '95000.00','Finance Controller','2026-07-15',null,'Form 4 late fee unpaid past target; direction response drafted'),
    ('MPCB/CTE/2026/40566','consultant_dependency','engage_environment_consultant','open',
     '40000.00','Admin Head - Mumbai','2026-08-30',null,'Rainwater-harvesting design awarded to empanelled consultant')
  ) as q(cno, rc, ca, cst, pen, own, tcd, acd, nt)
  join public.pcb_consent_r3680 e
    on e.organization_id = v_org_id and e.consent_no = q.cno;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3680_compliance_status_rollup()
returns table(compliance_status text, consents bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pcb_consent_r3680)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pcb_consent_r3680 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3680_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3680_compliance_status_rollup() to authenticated;

-- 2) State-board scorecard
create or replace function public.founder_r3680_state_board_scorecard()
returns table(
  state_board text,
  total_consents bigint,
  compliant bigint,
  renewal_due bigint,
  condition_gap bigint,
  notices_received bigint,
  notices_open_total bigint,
  avg_condition_compliance_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.state_board,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'condition_gap')::bigint,
    count(*) filter (where l.compliance_status = 'notice_received')::bigint,
    coalesce(sum(l.notices_open),0)::bigint,
    round(avg(l.condition_compliance_pct), 1),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.pcb_consent_r3680 l
  group by l.state_board
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3680_state_board_scorecard() from public, anon;
grant execute on function public.founder_r3680_state_board_scorecard() to authenticated;

-- 3) Consent-class × compliance-status matrix
create or replace function public.founder_r3680_class_status_matrix()
returns table(consent_class text, compliance_status text, consents bigint, avg_days_to_expiry numeric, avg_condition_compliance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.consent_class, l.compliance_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 0),
    round(avg(l.condition_compliance_pct), 1)
  from public.pcb_consent_r3680 l
  group by l.consent_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3680_class_status_matrix() from public, anon;
grant execute on function public.founder_r3680_class_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3680_monthly_compliance_trend()
returns table(period_month date, consents bigint, compliant bigint, notices_received bigint, returns_pending bigint, avg_condition_compliance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'notice_received')::bigint,
    count(*) filter (where l.compliance_status = 'returns_pending')::bigint,
    round(avg(l.condition_compliance_pct), 1)
  from public.pcb_consent_r3680 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3680_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3680_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3680_capa_status_board()
returns table(capa_status text, findings bigint, avg_penalty_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.penalty_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.pcb_consent_capa_actions_r3680 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3680_capa_status_board() from public, anon;
grant execute on function public.founder_r3680_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3680_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pcb_consent_capa_actions_r3680)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.penalty_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pcb_consent_capa_actions_r3680 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3680_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3680_root_cause_pareto() to authenticated;

-- 7) Condition-gap digest by category band
create or replace function public.founder_r3680_condition_gap_digest()
returns table(category_band text, consents bigint, conditions_total_sum bigint, conditions_met_sum bigint, open_condition_gaps bigint, avg_condition_compliance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category_band, count(*)::bigint,
    coalesce(sum(l.conditions_total),0)::bigint,
    coalesce(sum(l.conditions_met),0)::bigint,
    coalesce(sum(l.conditions_total - l.conditions_met),0)::bigint,
    round(avg(l.condition_compliance_pct), 1)
  from public.pcb_consent_r3680 l
  group by l.category_band
  order by coalesce(sum(l.conditions_total - l.conditions_met),0) desc;
end;
$$;

revoke all on function public.founder_r3680_condition_gap_digest() from public, anon;
grant execute on function public.founder_r3680_condition_gap_digest() to authenticated;

-- 8) High-risk consent queue
create or replace function public.founder_r3680_high_risk_queue()
returns table(
  facility_name text,
  state_board text,
  consent_no text,
  consent_class text,
  period_month date,
  valid_till date,
  days_to_expiry int,
  compliance_status text,
  notices_open int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.facility_name, l.state_board, l.consent_no, l.consent_class, l.period_month,
    l.valid_till, l.days_to_expiry, l.compliance_status, l.notices_open, l.trend_dir, l.notes
  from public.pcb_consent_r3680 l
  where l.compliance_status in ('notice_received','condition_gap')
     or l.notices_open > 0
     or l.days_to_expiry <= 60
     or l.returns_filed = false
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.days_to_expiry asc;
end;
$$;

revoke all on function public.founder_r3680_high_risk_queue() from public, anon;
grant execute on function public.founder_r3680_high_risk_queue() to authenticated;
