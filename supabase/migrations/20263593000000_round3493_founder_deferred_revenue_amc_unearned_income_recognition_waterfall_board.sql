-- Round 3493: Founder Deferred-Revenue / AMC Unearned-Income Recognition-Waterfall Board
-- Deferred/unearned AMC & CMC revenue — contract × customer segment × contract value × recognized-to-date × deferred balance × monthly recognition × months remaining × recognition % × recognition status × period × trend × CAPA

-- =============================================================================
-- TABLE 1: deferred_revenue_r3493 — per-contract AMC/CMC recognition waterfall
-- =============================================================================
create table if not exists public.deferred_revenue_r3493 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contract_code text not null,
  customer_segment text not null,
  contract_type text not null check (contract_type in (
    'amc','cmc','comprehensive_amc','warranty_extension'
  )),
  contract_value_rupees numeric(14,2),
  recognized_to_date_rupees numeric(14,2),
  deferred_balance_rupees numeric(14,2),
  monthly_recognition_rupees numeric(14,2),
  months_remaining int,
  recognition_pct numeric(5,2),
  recognition_status text not null check (recognition_status in (
    'on_schedule','ahead','behind','stalled','fully_recognized'
  )),
  period_month date not null,
  contract_end_date date,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.deferred_revenue_r3493 enable row level security;

create index if not exists idx_deferred_revenue_r3493_org on public.deferred_revenue_r3493(organization_id);
create index if not exists idx_deferred_revenue_r3493_status on public.deferred_revenue_r3493(recognition_status);
create index if not exists idx_deferred_revenue_r3493_period on public.deferred_revenue_r3493(period_month);

-- =============================================================================
-- TABLE 2: deferred_revenue_capa_actions_r3493 — recognition CAPA & remediation
-- =============================================================================
create table if not exists public.deferred_revenue_capa_actions_r3493 (
  id uuid primary key default gen_random_uuid(),
  contract_ref_id uuid not null references public.deferred_revenue_r3493(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'recognition_behind_schedule','recognition_stalled','deferred_balance_mismatch',
    'schedule_not_set_up','contract_renewal_pending','billing_recognition_gap',
    'early_recognition_error','contract_amendment_unposted','revenue_leakage','audit_reconciliation_gap'
  )),
  root_cause text not null check (root_cause in (
    'service_delivery_delay','milestone_not_recorded','erp_schedule_misconfigured',
    'contract_data_entry_error','renewal_negotiation_delay','manual_journal_pending',
    'system_integration_gap','pending_investigation','customer_dispute','policy_misapplication'
  )),
  corrective_action text not null check (corrective_action in (
    'true_up_recognition_journal','reconfigure_recognition_schedule','accelerate_service_delivery',
    'post_manual_adjustment','escalate_renewal_to_sales','correct_contract_master_data',
    'reconcile_with_billing','write_off_uncollectible','audit_and_restate','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  revenue_at_risk_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.deferred_revenue_capa_actions_r3493 enable row level security;

create index if not exists idx_deferred_revenue_capa_r3493_ref on public.deferred_revenue_capa_actions_r3493(contract_ref_id);
create index if not exists idx_deferred_revenue_capa_r3493_status on public.deferred_revenue_capa_actions_r3493(capa_status);

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

  -- 16 contract recognition rows
  insert into public.deferred_revenue_r3493 (
    organization_id, contract_code, customer_segment, contract_type,
    contract_value_rupees, recognized_to_date_rupees, deferred_balance_rupees,
    monthly_recognition_rupees, months_remaining, recognition_pct,
    recognition_status, period_month, contract_end_date, trend_dir, notes
  )
  select v_org_id, q.ccode, q.seg, q.ctype,
    q.cval, q.recto, q.defbal,
    q.monrec, q.monsrem, q.recpct,
    q.recstat, q.permon::date, q.cend::date, q.trnd, q.nt
  from (values
    ('AMC-APL-2401','corporate_hospital_chain','comprehensive_amc',2400000,1600000,800000,200000,4,66.67,'on_schedule','2026-07-01','2026-11-30','stable','Apollo chain CT/MRI comprehensive AMC recognizing on schedule'),
    ('AMC-FRT-2402','corporate_hospital_chain','amc',1200000,300000,900000,100000,9,25.00,'on_schedule','2026-07-01','2027-04-30','stable','Fortis multi-modality AMC early in term, recognition tracking to plan'),
    ('CMC-AIM-2403','government_hospital','cmc',3600000,1200000,2400000,300000,8,33.33,'behind','2026-07-01','2027-03-31','worsening','AIIMS CMC lab analysers — PM service visits lagging, recognition behind'),
    ('AMC-CMC-2404','medical_college','comprehensive_amc',1800000,1800000,0,0,0,100.00,'fully_recognized','2026-07-01','2026-06-30','stable','CMC Vellore teaching-hospital AMC fully recognized at term end'),
    ('CMC-KIM-2405','corporate_hospital_chain','cmc',960000,240000,720000,80000,9,25.00,'on_schedule','2026-07-01','2027-04-30','improving','KIMS ventilator fleet CMC recognizing on schedule'),
    ('AMC-MNP-2406','corporate_hospital_chain','amc',1500000,500000,1000000,125000,8,33.33,'stalled','2026-07-01','2027-03-31','worsening','Manipal dialysis AMC stalled — renewal amendment unposted in ERP'),
    ('WEXT-YSH-2407','standalone_nursing_home','warranty_extension',360000,90000,270000,30000,9,25.00,'on_schedule','2026-07-01','2027-04-30','stable','Yashoda warranty extension on ultrasound recognizing to plan'),
    ('CMC-GOV-2408','government_hospital','cmc',4800000,900000,3900000,400000,10,18.75,'behind','2026-07-01','2027-05-31','worsening','District hospital CMC — recognition behind due to delayed PM visits'),
    ('AMC-DEF-2409','defence_hospital','comprehensive_amc',2200000,1650000,550000,275000,2,75.00,'ahead','2026-07-01','2026-09-30','improving','Defence hospital OT-integration AMC recognizing ahead of schedule'),
    ('AMC-TRU-2410','trust_charitable_hospital','amc',600000,350000,250000,50000,5,58.33,'on_schedule','2026-07-01','2026-12-31','stable','Charitable trust hospital biomedical AMC on track'),
    ('CMC-DGL-2411','diagnostic_lab_chain','cmc',2880000,960000,1920000,240000,8,33.33,'on_schedule','2026-07-01','2027-03-31','improving','Diagnostic lab chain analyser CMC recognizing on schedule'),
    ('AMC-STN-2412','standalone_nursing_home','amc',420000,70000,350000,35000,10,16.67,'stalled','2026-07-01','2027-05-31','worsening','Nursing home AMC stalled — recognition schedule not configured'),
    ('WEXT-MED-2413','medical_college','warranty_extension',780000,585000,195000,65000,3,75.00,'on_schedule','2026-07-01','2026-10-31','stable','Medical college simulation-lab warranty extension on track'),
    ('AMC-COR-2414','corporate_hospital_chain','comprehensive_amc',5400000,4050000,1350000,450000,3,75.00,'ahead','2026-07-01','2026-10-31','improving','Large corporate cath-lab AMC recognizing ahead of schedule'),
    ('CMC-GOV-2415','government_hospital','cmc',3000000,250000,2750000,250000,11,8.33,'behind','2026-07-01','2027-06-30','worsening','State govt CMC newly started, large deferred balance, recognition behind'),
    ('AMC-DGL-2416','diagnostic_lab_chain','amc',1080000,1080000,0,0,0,100.00,'fully_recognized','2026-07-01','2026-06-30','stable','Lab chain imaging AMC fully recognized at term end')
  ) as q(ccode, seg, ctype, cval, recto, defbal, monrec, monsrem, recpct, recstat, permon, cend, trnd, nt);

  -- CAPA seed — attach to specific contracts via contract_code
  insert into public.deferred_revenue_capa_actions_r3493 (
    contract_ref_id, finding_category, root_cause, corrective_action,
    capa_status, revenue_at_risk_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rar, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('CMC-AIM-2403','recognition_behind_schedule','service_delivery_delay','accelerate_service_delivery','in_progress',2400000,'K. Ramaswamy','2026-08-15',null,'Expedite pending PM visits to catch up deferred recognition'),
    ('AMC-MNP-2406','contract_amendment_unposted','manual_journal_pending','post_manual_adjustment','open',1000000,'S. Desai','2026-08-10',null,'Post renewal amendment and true-up recognition schedule'),
    ('CMC-GOV-2408','recognition_behind_schedule','erp_schedule_misconfigured','reconfigure_recognition_schedule','escalated',3900000,'A. Bose','2026-08-05',null,'ERP recognition schedule misconfigured — escalated to finance systems'),
    ('AMC-STN-2412','schedule_not_set_up','system_integration_gap','reconfigure_recognition_schedule','open',350000,'P. Nair','2026-08-20',null,'Recognition schedule never configured for this contract'),
    ('CMC-GOV-2415','recognition_behind_schedule','service_delivery_delay','accelerate_service_delivery','open',2750000,'A. Bose','2026-08-25',null,'Large deferred govt CMC — service ramp-up plan required'),
    ('CMC-AIM-2403','audit_reconciliation_gap','policy_misapplication','audit_and_restate','verification_pending',500000,'M. Iyer','2026-07-30',null,'Recognition policy applied inconsistently — under audit review'),
    ('AMC-MNP-2406','recognition_stalled','renewal_negotiation_delay','escalate_renewal_to_sales','overdue',1000000,'S. Desai','2026-07-10',null,'Renewal stalled beyond target date — escalated to sales'),
    ('AMC-DEF-2409','early_recognition_error','policy_misapplication','post_manual_adjustment','closed',150000,'R. Menon','2026-07-05','2026-07-08','Corrected early-recognition overstatement via reversing journal')
  ) as q(ccode, fc, rc, ca, cst, rar, own, tcd, acd, nt)
  join public.deferred_revenue_r3493 e
    on e.organization_id = v_org_id and e.contract_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recognition-status distribution
create or replace function public.founder_r3493_recognition_status_rollup()
returns table(recognition_status text, contracts bigint, deferred_balance_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.deferred_revenue_r3493)
  select l.recognition_status, count(*)::bigint,
         coalesce(sum(l.deferred_balance_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.deferred_revenue_r3493 l
  group by l.recognition_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3493_recognition_status_rollup() from public, anon;
grant execute on function public.founder_r3493_recognition_status_rollup() to authenticated;

-- 2) Customer-segment recognition scorecard
create or replace function public.founder_r3493_customer_segment_scorecard()
returns table(
  customer_segment text,
  contracts bigint,
  total_contract_value_rupees numeric,
  recognized_to_date_rupees numeric,
  deferred_balance_rupees numeric,
  avg_recognition_pct numeric,
  behind_or_stalled bigint,
  recognition_health_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment,
    count(*)::bigint,
    coalesce(sum(l.contract_value_rupees),0)::numeric,
    coalesce(sum(l.recognized_to_date_rupees),0)::numeric,
    coalesce(sum(l.deferred_balance_rupees),0)::numeric,
    round(avg(l.recognition_pct), 2),
    count(*) filter (where l.recognition_status in ('behind','stalled'))::bigint,
    round(100.0 * count(*) filter (where l.recognition_status in ('on_schedule','ahead','fully_recognized'))::numeric / nullif(count(*),0), 1)
  from public.deferred_revenue_r3493 l
  group by l.customer_segment
  order by coalesce(sum(l.deferred_balance_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3493_customer_segment_scorecard() from public, anon;
grant execute on function public.founder_r3493_customer_segment_scorecard() to authenticated;

-- 3) Segment × recognition-status matrix
create or replace function public.founder_r3493_segment_status_matrix()
returns table(customer_segment text, recognition_status text, contracts bigint, deferred_balance_rupees numeric, avg_recognition_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.recognition_status, count(*)::bigint,
    coalesce(sum(l.deferred_balance_rupees),0)::numeric,
    round(avg(l.recognition_pct), 2)
  from public.deferred_revenue_r3493 l
  group by l.customer_segment, l.recognition_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3493_segment_status_matrix() from public, anon;
grant execute on function public.founder_r3493_segment_status_matrix() to authenticated;

-- 4) Monthly recognition trend
create or replace function public.founder_r3493_monthly_recognition_trend()
returns table(
  period_month date,
  contracts bigint,
  monthly_recognition_rupees numeric,
  recognized_to_date_rupees numeric,
  deferred_balance_rupees numeric,
  avg_recognition_pct numeric
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
    coalesce(sum(l.monthly_recognition_rupees),0)::numeric,
    coalesce(sum(l.recognized_to_date_rupees),0)::numeric,
    coalesce(sum(l.deferred_balance_rupees),0)::numeric,
    round(avg(l.recognition_pct), 2)
  from public.deferred_revenue_r3493 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3493_monthly_recognition_trend() from public, anon;
grant execute on function public.founder_r3493_monthly_recognition_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3493_capa_status_board()
returns table(capa_status text, findings bigint, revenue_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.revenue_at_risk_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.deferred_revenue_capa_actions_r3493 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3493_capa_status_board() from public, anon;
grant execute on function public.founder_r3493_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3493_root_cause_pareto()
returns table(root_cause text, occurrences bigint, revenue_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.deferred_revenue_capa_actions_r3493)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.revenue_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.deferred_revenue_capa_actions_r3493 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3493_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3493_root_cause_pareto() to authenticated;

-- 7) Deferred-balance impact digest (by trend direction)
create or replace function public.founder_r3493_deferred_balance_impact_digest()
returns table(
  trend_dir text,
  contracts bigint,
  deferred_balance_rupees numeric,
  monthly_recognition_rupees numeric,
  avg_months_remaining numeric,
  avg_recognition_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir,
    count(*)::bigint,
    coalesce(sum(l.deferred_balance_rupees),0)::numeric,
    coalesce(sum(l.monthly_recognition_rupees),0)::numeric,
    round(avg(l.months_remaining), 1),
    round(avg(l.recognition_pct), 2)
  from public.deferred_revenue_r3493 l
  group by l.trend_dir
  order by coalesce(sum(l.deferred_balance_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3493_deferred_balance_impact_digest() from public, anon;
grant execute on function public.founder_r3493_deferred_balance_impact_digest() to authenticated;

-- 8) High-risk recognition queue (stalled / behind / large deferred)
create or replace function public.founder_r3493_high_risk_queue()
returns table(
  contract_code text,
  customer_segment text,
  contract_type text,
  recognition_status text,
  contract_value_rupees numeric,
  recognized_to_date_rupees numeric,
  deferred_balance_rupees numeric,
  months_remaining int,
  recognition_pct numeric,
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
  select l.contract_code, l.customer_segment, l.contract_type, l.recognition_status,
    l.contract_value_rupees, l.recognized_to_date_rupees, l.deferred_balance_rupees,
    l.months_remaining, l.recognition_pct, l.trend_dir, l.notes
  from public.deferred_revenue_r3493 l
  where l.recognition_status in ('behind','stalled')
     or l.trend_dir = 'worsening'
     or l.deferred_balance_rupees >= 2000000
  order by l.deferred_balance_rupees desc, l.contract_code;
end;
$$;

revoke execute on function public.founder_r3493_high_risk_queue() from public, anon;
grant execute on function public.founder_r3493_high_risk_queue() to authenticated;
