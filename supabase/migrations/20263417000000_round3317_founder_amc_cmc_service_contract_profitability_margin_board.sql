-- Round 3317: Founder AMC/CMC Service-Contract Portfolio Profitability & Margin Governance Board
-- Finance board — contract type × equipment scope × contract value × cost-to-serve × gross margin × margin % × SLA penalty × renewal due × CAPA repricing/rescoping

-- =============================================================================
-- TABLE 1: amc_cmc_contract_r3317 — per-contract profitability & margin ledger
-- =============================================================================
create table if not exists public.amc_cmc_contract_r3317 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  contract_code text not null,
  contract_type text not null check (contract_type in (
    'amc_labour_only','cmc_comprehensive','warranty_extension','pay_per_call','uptime_guarantee'
  )),
  equipment_scope text not null check (equipment_scope in (
    'imaging','lab','ot','critical_care','mixed_fleet','single_modality'
  )),
  contract_value_rupees numeric(14,2) not null,
  visits_contracted int not null,
  visits_consumed int not null,
  parts_cost_rupees numeric(14,2) not null,
  labour_cost_rupees numeric(14,2) not null,
  travel_cost_rupees numeric(14,2) not null,
  cost_to_serve_rupees numeric(14,2) not null,
  gross_margin_rupees numeric(14,2) not null,
  margin_pct numeric(6,2) not null,
  sla_penalty_paid_rupees numeric(14,2) not null,
  renewal_due_date date,
  contract_verdict text not null check (contract_verdict in (
    'healthy_margin','thin_margin','loss_making','over_serviced','renegotiate_renewal','exit_candidate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.amc_cmc_contract_r3317 enable row level security;

create index if not exists idx_amc_cmc_contract_r3317_org on public.amc_cmc_contract_r3317(organization_id);
create index if not exists idx_amc_cmc_contract_r3317_renewal on public.amc_cmc_contract_r3317(renewal_due_date);
create index if not exists idx_amc_cmc_contract_r3317_verdict on public.amc_cmc_contract_r3317(contract_verdict);

-- =============================================================================
-- TABLE 2: amc_cmc_contract_capa_actions_r3317 — repricing / rescoping / cost-control actions
-- =============================================================================
create table if not exists public.amc_cmc_contract_capa_actions_r3317 (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.amc_cmc_contract_r3317(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'margin_erosion','over_servicing','parts_cost_overrun','sla_penalty_leakage',
    'underpriced_renewal','scope_creep','travel_cost_overrun','loss_making_contract'
  )),
  root_cause text not null check (root_cause in (
    'underpriced_at_signing','visit_frequency_too_high','parts_inflation','distance_travel_burden',
    'sla_uptime_shortfall','scope_expanded_no_repricing','aging_equipment_high_failure','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_at_renewal','rescope_visits_to_actual','shift_to_pay_per_call','renegotiate_parts_inclusion',
    'add_sla_cap_clause','consolidate_travel_routing','exit_non_viable_contract','escalate_to_management','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  margin_risk_tier text not null check (margin_risk_tier in (
    'critical','high','moderate','low','watch'
  )),
  target_closure_date date,
  actual_closure_date date,
  projected_margin_gain_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.amc_cmc_contract_capa_actions_r3317 enable row level security;

create index if not exists idx_amc_cmc_capa_r3317_contract on public.amc_cmc_contract_capa_actions_r3317(contract_id);
create index if not exists idx_amc_cmc_capa_r3317_status on public.amc_cmc_contract_capa_actions_r3317(capa_status);

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

  -- 14 contract profitability rows
  insert into public.amc_cmc_contract_r3317 (
    organization_id, hospital_name, contract_code, contract_type, equipment_scope,
    contract_value_rupees, visits_contracted, visits_consumed,
    parts_cost_rupees, labour_cost_rupees, travel_cost_rupees, cost_to_serve_rupees,
    gross_margin_rupees, margin_pct, sla_penalty_paid_rupees, renewal_due_date,
    contract_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ctype, q.scope,
    q.cval, q.vc::int, q.vcons::int,
    q.parts, q.labour, q.travel, q.cts,
    q.gm, q.mpct, q.sla, q.rdd::date,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','AMC-APL-CHN-01','cmc_comprehensive','imaging',
     4800000.00,24,20,900000.00,1200000.00,300000.00,2400000.00,2400000.00,50.0,0.00,'2026-09-30','healthy_margin','FY26 CMC imaging fleet — margin healthy at 50 pct, renew at par'),
    ('Fortis Gurgaon','AMC-FRT-GGN-02','amc_labour_only','lab',
     1200000.00,12,11,120000.00,700000.00,150000.00,970000.00,210000.00,17.5,20000.00,'2026-08-15','thin_margin','Labour-only lab AMC — SLA penalty eroding thin margin'),
    ('Manipal Bengaluru Old Airport Rd','CMC-MNP-BLR-03','cmc_comprehensive','critical_care',
     3600000.00,36,44,1100000.00,1800000.00,500000.00,3400000.00,150000.00,4.2,50000.00,'2026-10-31','over_serviced','44 visits vs 36 contracted — over-serviced ICU fleet'),
    ('AIIMS Delhi Ansari Nagar','UPT-AIMS-DEL-04','uptime_guarantee','imaging',
     6000000.00,48,52,1800000.00,2400000.00,600000.00,4800000.00,800000.00,13.3,400000.00,'2026-08-31','renegotiate_renewal','Uptime SLA penalties 4L — renegotiate cap before renewal'),
    ('CMC Vellore','CMC-CMC-VEL-05','cmc_comprehensive','mixed_fleet',
     5200000.00,40,38,1400000.00,2000000.00,700000.00,4100000.00,1100000.00,21.2,0.00,'2026-11-30','healthy_margin','Mixed-fleet CMC tracking to 21 pct margin — stable'),
    ('KIMS Hyderabad','PPC-KIMS-HYD-06','pay_per_call','single_modality',
     800000.00,8,8,200000.00,350000.00,120000.00,670000.00,130000.00,16.3,0.00,'2026-09-15','thin_margin','Pay-per-call CT — thin but positive, watch parts cost'),
    ('Narayana Health Bengaluru','CMC-NHC-BLR-07','cmc_comprehensive','ot',
     2400000.00,24,30,900000.00,1300000.00,400000.00,2600000.00,-260000.00,-10.8,60000.00,'2026-08-20','loss_making','Cost-to-serve exceeds value — underpriced at signing'),
    ('Medanta Gurgaon','UPT-MDT-GGN-08','uptime_guarantee','critical_care',
     7200000.00,60,58,2000000.00,2800000.00,700000.00,5500000.00,1550000.00,21.5,150000.00,'2027-01-31','healthy_margin','Flagship uptime deal — 21.5 pct margin after penalties'),
    ('Kokilaben Mumbai','CMC-KKB-MUM-09','cmc_comprehensive','imaging',
     4000000.00,30,41,1600000.00,2100000.00,500000.00,4200000.00,-280000.00,-7.0,80000.00,'2026-08-10','exit_candidate','Aging MRI fleet — 41 visits, loss-making, exit at renewal'),
    ('Tata Memorial Mumbai','AMC-TMH-MUM-10','amc_labour_only','lab',
     1500000.00,18,16,150000.00,800000.00,200000.00,1150000.00,350000.00,23.3,0.00,'2026-12-15','healthy_margin','Oncology lab AMC — 23 pct margin, model contract'),
    ('Max Saket Delhi','WEX-MAX-DEL-11','warranty_extension','single_modality',
     600000.00,4,3,90000.00,250000.00,80000.00,420000.00,180000.00,30.0,0.00,'2026-09-30','healthy_margin','Warranty extension cath-lab — 30 pct margin, low touch'),
    ('Aster Kochi','PPC-AST-KOC-12','pay_per_call','mixed_fleet',
     1000000.00,10,14,300000.00,500000.00,250000.00,1050000.00,-50000.00,-5.0,0.00,'2026-08-25','over_serviced','14 calls vs 10 expected — shift to true pay-per-call pricing'),
    ('SGPGI Lucknow','CMC-SGPGI-LKO-13','cmc_comprehensive','imaging',
     4500000.00,36,35,1300000.00,1900000.00,800000.00,4000000.00,380000.00,8.4,120000.00,'2026-10-15','renegotiate_renewal','High parts plus travel cost — renegotiate parts inclusion'),
    ('Yashoda Hyderabad','AMC-YSH-HYD-14','amc_labour_only','ot',
     1800000.00,20,19,200000.00,950000.00,250000.00,1400000.00,370000.00,20.6,30000.00,'2026-11-15','healthy_margin','OT labour AMC — 20.6 pct margin, healthy')
  ) as q(hosp, code, ctype, scope, cval, vc, vcons, parts, labour, travel, cts, gm, mpct, sla, rdd, verdict, nt);

  -- CAPA seed — attach to at-risk contracts via contract_code
  insert into public.amc_cmc_contract_capa_actions_r3317 (
    contract_id, finding_category, root_cause, corrective_action,
    capa_status, margin_risk_tier, target_closure_date, actual_closure_date,
    projected_margin_gain_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.tier, q.tcd::date, q.acd::date,
    q.gain, q.nt
  from (values
    ('CMC-MNP-BLR-03','over_servicing','visit_frequency_too_high','rescope_visits_to_actual','in_progress','high','2026-09-15',null,400000.00,'Rescope PM schedule from 36 to actual 30 visits — save approx 4L'),
    ('UPT-AIMS-DEL-04','sla_penalty_leakage','sla_uptime_shortfall','add_sla_cap_clause','open','high','2026-08-20',null,350000.00,'Add penalty cap plus backup-unit clause to cut 4L SLA leakage'),
    ('CMC-NHC-BLR-07','loss_making_contract','underpriced_at_signing','reprice_at_renewal','escalated','critical','2026-08-10',null,520000.00,'Contract underwater — reprice plus 25 pct or exit; escalated to mgmt'),
    ('CMC-KKB-MUM-09','margin_erosion','aging_equipment_high_failure','exit_non_viable_contract','overdue','critical','2026-08-05',null,300000.00,'Aging MRI failure rate — recommend non-renewal, stop-loss 3L'),
    ('PPC-AST-KOC-12','scope_creep','scope_expanded_no_repricing','shift_to_pay_per_call','in_progress','moderate','2026-08-25',null,120000.00,'Convert flat pay-per-call to metered per-visit billing'),
    ('CMC-SGPGI-LKO-13','parts_cost_overrun','parts_inflation','renegotiate_parts_inclusion','verification_pending','moderate','2026-10-01',null,250000.00,'Carve high-cost tubes out of parts inclusion at renewal'),
    ('AMC-FRT-GGN-02','underpriced_renewal','underpriced_at_signing','reprice_at_renewal','closed','low','2026-08-01','2026-07-15',180000.00,'Renewal repriced plus 15 pct — margin restored, CAPA closed')
  ) as q(code, fc, rc, ca, cst, tier, tcd, acd, gain, nt)
  join public.amc_cmc_contract_r3317 e
    on e.organization_id = v_org_id and e.contract_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Contract verdict distribution
create or replace function public.founder_r3317_contract_verdict_rollup()
returns table(contract_verdict text, contracts bigint, total_value_rupees numeric, total_margin_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.amc_cmc_contract_r3317)
  select l.contract_verdict, count(*)::bigint,
         coalesce(sum(l.contract_value_rupees),0)::numeric,
         coalesce(sum(l.gross_margin_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.amc_cmc_contract_r3317 l
  group by l.contract_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3317_contract_verdict_rollup() from public, anon;
grant execute on function public.founder_r3317_contract_verdict_rollup() to authenticated;

-- 2) Hospital-level margin scorecard
create or replace function public.founder_r3317_hospital_scorecard()
returns table(
  hospital_name text,
  contracts bigint,
  total_value_rupees numeric,
  total_cost_to_serve_rupees numeric,
  total_margin_rupees numeric,
  avg_margin_pct numeric,
  loss_making bigint,
  exit_candidates bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    coalesce(sum(l.contract_value_rupees),0)::numeric,
    coalesce(sum(l.cost_to_serve_rupees),0)::numeric,
    coalesce(sum(l.gross_margin_rupees),0)::numeric,
    round(avg(l.margin_pct), 1),
    count(*) filter (where l.contract_verdict = 'loss_making')::bigint,
    count(*) filter (where l.contract_verdict = 'exit_candidate')::bigint
  from public.amc_cmc_contract_r3317 l
  group by l.hospital_name
  order by coalesce(sum(l.gross_margin_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3317_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3317_hospital_scorecard() to authenticated;

-- 3) Contract type × equipment scope matrix
create or replace function public.founder_r3317_type_scope_matrix()
returns table(contract_type text, equipment_scope text, contracts bigint, total_value_rupees numeric, avg_margin_pct numeric, loss_making bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_type, l.equipment_scope, count(*)::bigint,
    coalesce(sum(l.contract_value_rupees),0)::numeric,
    round(avg(l.margin_pct), 1),
    count(*) filter (where l.contract_verdict in ('loss_making','exit_candidate'))::bigint
  from public.amc_cmc_contract_r3317 l
  group by l.contract_type, l.equipment_scope
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3317_type_scope_matrix() from public, anon;
grant execute on function public.founder_r3317_type_scope_matrix() to authenticated;

-- 4) Renewal-due date trend
create or replace function public.founder_r3317_renewal_due_trend()
returns table(renewal_due_date date, contracts bigint, total_value_rupees numeric, total_margin_rupees numeric, loss_making bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.renewal_due_date,
    count(*)::bigint,
    coalesce(sum(l.contract_value_rupees),0)::numeric,
    coalesce(sum(l.gross_margin_rupees),0)::numeric,
    count(*) filter (where l.contract_verdict in ('loss_making','exit_candidate'))::bigint
  from public.amc_cmc_contract_r3317 l
  group by l.renewal_due_date
  order by l.renewal_due_date asc;
end;
$$;

revoke execute on function public.founder_r3317_renewal_due_trend() from public, anon;
grant execute on function public.founder_r3317_renewal_due_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3317_capa_status_board()
returns table(capa_status text, findings bigint, avg_projected_gain_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.projected_margin_gain_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.amc_cmc_contract_capa_actions_r3317 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3317_capa_status_board() from public, anon;
grant execute on function public.founder_r3317_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3317_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_projected_gain_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.amc_cmc_contract_capa_actions_r3317)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.projected_margin_gain_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.amc_cmc_contract_capa_actions_r3317 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3317_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3317_root_cause_pareto() to authenticated;

-- 7) Margin-risk digest (cost/risk digest by tier)
create or replace function public.founder_r3317_margin_risk_digest()
returns table(margin_risk_tier text, findings bigint, open_findings bigint, total_projected_gain_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.margin_risk_tier, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.projected_margin_gain_rupees),0)::numeric
  from public.amc_cmc_contract_capa_actions_r3317 c
  group by c.margin_risk_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3317_margin_risk_digest() from public, anon;
grant execute on function public.founder_r3317_margin_risk_digest() to authenticated;

-- 8) High-risk contract queue (at-risk contracts)
create or replace function public.founder_r3317_high_risk_queue()
returns table(
  hospital_name text,
  contract_code text,
  contract_type text,
  equipment_scope text,
  contract_value_rupees numeric,
  cost_to_serve_rupees numeric,
  margin_pct numeric,
  sla_penalty_paid_rupees numeric,
  renewal_due_date date,
  contract_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.contract_code, l.contract_type, l.equipment_scope,
    l.contract_value_rupees, l.cost_to_serve_rupees, l.margin_pct, l.sla_penalty_paid_rupees,
    l.renewal_due_date, l.contract_verdict, l.notes
  from public.amc_cmc_contract_r3317 l
  where l.contract_verdict in ('thin_margin','loss_making','over_serviced','renegotiate_renewal','exit_candidate')
     or l.margin_pct < 15.0
     or l.sla_penalty_paid_rupees > 0
     or l.visits_consumed > l.visits_contracted
  order by l.margin_pct asc, l.renewal_due_date asc;
end;
$$;

revoke execute on function public.founder_r3317_high_risk_queue() from public, anon;
grant execute on function public.founder_r3317_high_risk_queue() to authenticated;
